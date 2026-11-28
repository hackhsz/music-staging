--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PadHud = require(script.Parent.PadHud)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

local GRID_BUTTON_SIZE = 72
local BUTTON_GAP = 6
local MARGIN = 16
local IDLE_TRANSPARENCY = 0.4
local PRESSED_TRANSPARENCY = 0.05

local KEYS_NAME = "Keys"
local FIT_NAME = "Fit"
local PRESS_NAME = "Press"
local KEY_SIZE = 58
local DESKTOP_KEY_SCALE = 0.11
local DESKTOP_KEY_MIN = 64
local DESKTOP_KEY_MAX = 120
local TOUCH_KEY_SCALE = 0.13
local TOUCH_KEY_MIN = 64
local TOUCH_KEY_MAX = 104
local PHONE_KEY_SCALE = 0.12
local PHONE_KEY_MIN = 44
local PHONE_KEY_MAX = 54
-- The gap the pad shot keeps between the keys and the floor.
local KEY_EDGE = 12
local KEY_COLOR = Color3.fromRGB(26, 26, 30)
local KEY_STROKE = Color3.fromRGB(175, 175, 182)
local CAP_IDLE_TRANSPARENCY = 0
local GUIDE_COLOR = Color3.fromRGB(255, 64, 160)
local CLAP_GUIDE_COLOR = Color3.fromRGB(255, 214, 40)
-- The guided key fills from the bottom with the same level as its tile on the
-- floor, full on the beat, then turns white for the press itself.
local GUIDE_TICK_BEATS = 0.3
local GUIDE_DIM_MIX = 0.2
local GUIDE_HIT_BEATS = 0.12
local GUIDE_HIT_MIX = 0.7
local FLASH_TRANSPARENCY = 0.55
local PRESS_SCALE = 0.86
local PRESS_INFO = TweenInfo.new(0.03, Enum.EasingStyle.Linear)
local RELEASE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type KeySpec = { name: string, dx: number, dy: number, clap: boolean? }

local KEYS: { KeySpec } = {
	{ name = "Clap", dx = 0, dy = 0, clap = true },
	{ name = "Up", dx = 0, dy = -1 },
	{ name = "Left", dx = -1, dy = 0 },
	{ name = "Down", dx = 0, dy = 1 },
	{ name = "Right", dx = 1, dy = 0 },
}

-- One authored copy of a key, in one layout.
type KeyPart = {
	button: GuiButton,
	back: GuiObject,
	fill: GuiObject,
	cap: ImageLabel,
	flash: GuiObject,
	press: UIScale,
	letter: GuiObject?,
}

-- A key the player sees: the same key in every layout, lit together.
type Key = {
	dx: number,
	dy: number,
	clap: boolean?,
	parts: { KeyPart },
}

type GridButton = { button: GuiButton, tile: { x: number, y: number } }

type Fields = {
	gui: ScreenGui?,
	clusters: { GuiObject },
	layoutOf: { [GuiObject]: GuiObject },
	looseKeys: { { button: GuiButton, size: Vector2 } },
	keys: { [string]: Key },
	clapKey: Key?,
	frame: Frame,
	grid: { GridButton },
	gridActive: boolean,
	held: { [InputObject]: Key | GridButton },
	guided: { Key },
	clapEnabled: boolean,
	visible: boolean,
	keyScale: number,
	onDirection: ((dx: number?, dy: number?) -> ())?,
	onTile: ((x: number, y: number) -> ())?,
	onClap: (() -> ())?,
}

-- The on-screen pad. By default the WASD keys authored in StarterGui.PadHud
-- under the left thumb and CLAP under the right; as a grid, built here, it mirrors
-- the floor tile for tile, so on a 3x3 pad a diagonal is one tap.
local StepPad = {}
StepPad.__index = StepPad

export type StepPad = typeof(setmetatable({} :: Fields, StepPad))

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function directionKey(dx: number, dy: number): string
	return ("%d,%d"):format(dx, dy)
end

local function bindPart(button: Instance): KeyPart?
	local back = button:FindFirstChild("Back")
	local fill = if back ~= nil then back:FindFirstChild("Fill") else nil
	local cap = button:FindFirstChild("Cap")
	local flash = button:FindFirstChild("Flash")

	if
		not button:IsA("GuiButton")
		or back == nil
		or not back:IsA("GuiObject")
		or fill == nil
		or not fill:IsA("GuiObject")
		or cap == nil
		or not cap:IsA("ImageLabel")
		or flash == nil
		or not flash:IsA("GuiObject")
	then
		warn("[DanceDanceStep] PadHud key " .. button:GetFullName() .. " is missing Back, Back.Fill, Cap or Flash")
		return nil
	end

	local letter = button:FindFirstChild("Letter")

	return {
		button = button,
		back = back,
		fill = fill,
		cap = cap,
		flash = flash,
		press = UiKit.scaleOf(button, PRESS_NAME),
		letter = if letter ~= nil and letter:IsA("GuiObject") then letter else nil,
	}
end

local function setRim(part: KeyPart, color: Color3, lit: boolean)
	part.cap.ImageColor3 = color
	part.cap.ImageTransparency = if lit then 0 else CAP_IDLE_TRANSPARENCY
end

local function unpaintGuide(key: Key)
	for _, part in key.parts do
		setRim(part, KEY_STROKE, false)
		part.back.BackgroundColor3 = KEY_COLOR
		part.fill.Visible = false
	end
end

local function paintGuide(key: Key, color: Color3, level: number, beatsAway: number?)
	local amount = math.clamp(level, 0, 1)
	local tick, hit = 0, 0

	if beatsAway ~= nil then
		tick = math.max(1 - (math.ceil(beatsAway) - beatsAway) / GUIDE_TICK_BEATS, 0) ^ 2
		hit = math.clamp(1 - beatsAway / GUIDE_HIT_BEATS, 0, 1)
	end

	for _, part in key.parts do
		setRim(part, color:Lerp(Colors.White, math.max(tick * 0.5, hit)), true)
		part.back.BackgroundColor3 = KEY_COLOR:Lerp(color, GUIDE_DIM_MIX)
		part.fill.Visible = amount > 0
		part.fill.Size = UDim2.fromScale(1, amount)
		part.fill.BackgroundColor3 = color:Lerp(Colors.White, GUIDE_HIT_MIX * hit)
	end
end

-- gui is the authored PadHud; without it only the grid can draw.
function StepPad.new(parent: Instance, gui: ScreenGui?): StepPad
	local frame = UiKit.create("Frame", {
		Name = "StepPad",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN, 1, -MARGIN),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)

	local fields: Fields = {
		gui = gui,
		clusters = {},
		layoutOf = {},
		looseKeys = {},
		keys = {},
		clapKey = nil,
		frame = frame,
		grid = {},
		gridActive = false,
		held = {},
		guided = {},
		clapEnabled = false,
		visible = false,
		keyScale = 1,
		onDirection = nil,
		onTile = nil,
		onClap = nil,
	}
	local self = setmetatable(fields, StepPad)

	if gui ~= nil then
		self:_bindKeys(gui)
	end

	-- Each finger is tracked on its own, so chords and fast alternation never
	-- drop a press, and a finger that slides off a key still releases it.
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local entry = self.held[input]

		if entry == nil then
			return
		end

		self.held[input] = nil

		if not self:_isHeld(entry) then
			self:_light(entry, false)
		end

		if next(self.held) == nil and self.onDirection ~= nil then
			self.onDirection(nil, nil)
		end
	end)

	UiKit.onViewportChanged(function()
		self:_fitKeys()
	end)
	self:_applyVisible()

	return self
end

function StepPad._bindKeys(self: StepPad, gui: ScreenGui)
	for _, spec in KEYS do
		local key: Key = { dx = spec.dx, dy = spec.dy, clap = spec.clap, parts = {} }

		if spec.clap then
			self.clapKey = key
		else
			self.keys[directionKey(spec.dx, spec.dy)] = key
		end
	end

	for _, layoutName in PadHud.Layouts do
		local layout = gui:FindFirstChild(layoutName)
		local cluster = if layout ~= nil then layout:FindFirstChild(KEYS_NAME, true) else nil

		if layout == nil or not layout:IsA("GuiObject") or cluster == nil or not cluster:IsA("GuiObject") then
			warn("[DanceDanceStep] PadHud." .. layoutName .. " has no Keys")
			continue
		end

		table.insert(self.clusters, cluster)
		self.layoutOf[cluster] = layout

		-- A layout may put a key outside the cluster: CLAP sits under the other thumb.
		for _, spec in KEYS do
			local button = cluster:FindFirstChild(spec.name) or layout:FindFirstChild(spec.name, true)
			local part = if button ~= nil then bindPart(button) else nil
			local key = if spec.clap then self.clapKey else self.keys[directionKey(spec.dx, spec.dy)]

			if part ~= nil and key ~= nil then
				table.insert(key.parts, part)

				if not part.button:IsDescendantOf(cluster) then
					local size = part.button.Size
					local authored = Vector2.new(size.X.Offset, size.Y.Offset)
					table.insert(self.looseKeys, { button = part.button, size = authored })
				end

				self:_track(part.button, key)
				unpaintGuide(key)
				part.flash.BackgroundTransparency = 1
			end
		end
	end

	self:setClapEnabled(false)
end

function StepPad.setVisible(self: StepPad, visible: boolean)
	self.visible = visible
	self:_applyVisible()

	if not visible then
		self:_releaseAll()
	end
end

-- callback receives the pressed direction, or nil when every finger has lifted.
function StepPad.bind(self: StepPad, callback: (dx: number?, dy: number?) -> ())
	self.onDirection = callback
end

-- callback receives the tile a grid button stands for.
function StepPad.bindTiles(self: StepPad, callback: (x: number, y: number) -> ())
	self.onTile = callback
end

function StepPad.bindClap(self: StepPad, callback: () -> ())
	self.onClap = callback
end

-- The CLAP key only shows where claps are charted: the dance pad.
function StepPad.setClapEnabled(self: StepPad, enabled: boolean)
	self.clapEnabled = enabled
	self:_applyClapVisible()

	if not enabled then
		self:setClapGuide(nil)
	end
end

-- A grid of columns x rows tile buttons, or the WASD keys when nil.
-- labels, if given, are read column by column, then row by row.
function StepPad.setGrid(self: StepPad, columns: number?, rows: number?, labels: { string }?)
	self:_clearGrid()

	if columns == nil or rows == nil then
		self.gridActive = false
		self:_applyVisible()
		return
	end

	self.gridActive = true
	self.frame.Size = UDim2.fromOffset(
		GRID_BUTTON_SIZE * columns + BUTTON_GAP * (columns - 1),
		GRID_BUTTON_SIZE * rows + BUTTON_GAP * (rows - 1)
	)

	local index = 0

	for x = 1, columns do
		for y = 1, rows do
			index += 1

			local text = if labels ~= nil then labels[index] or "" else ""
			local button = UiKit.button(self.frame, ("Pad_%d_%d"):format(x, y), text, Colors.White, {
				BackgroundTransparency = IDLE_TRANSPARENCY,
				Position = UDim2.fromOffset((x - 1) * (GRID_BUTTON_SIZE + BUTTON_GAP), (y - 1) * (GRID_BUTTON_SIZE + BUTTON_GAP)),
				Size = UDim2.fromOffset(GRID_BUTTON_SIZE, GRID_BUTTON_SIZE),
			})
			local entry: GridButton = { button = button, tile = { x = x, y = y } }

			table.insert(self.grid, entry)
			self:_track(button, entry)
		end
	end

	self:_applyVisible()
end

function StepPad._applyClapVisible(self: StepPad)
	local clapKey = self.clapKey

	if clapKey == nil then
		return
	end

	for _, part in clapKey.parts do
		part.button.Visible = self.clapEnabled and self:_keysShown()
	end
end

function StepPad._keysShown(self: StepPad): boolean
	return self.visible and not self.gridActive and #self.clusters > 0
end

function StepPad._applyVisible(self: StepPad)
	local keysShown = self:_keysShown()
	self.frame.Visible = self.visible and self.gridActive

	for _, cluster in self.clusters do
		cluster.Visible = keysShown
	end

	self:_applyClapVisible()

	local gui = self.gui

	if gui ~= nil then
		PadHud.setShown(gui, "KeysShown", keysShown)
	end
end

function StepPad._releaseAll(self: StepPad)
	table.clear(self.held)

	for _, key in self.keys do
		self:_light(key, false)
	end

	if self.clapKey ~= nil then
		self:_light(self.clapKey, false)
	end

	for _, entry in self.grid do
		self:_light(entry, false)
	end
end

function StepPad._clearGrid(self: StepPad)
	for _, entry in self.grid do
		entry.button:Destroy()
	end

	table.clear(self.grid)
	table.clear(self.held)
end

function StepPad._keySize(self: StepPad): number
	local viewport = UiKit.viewportSize()
	local short = math.min(viewport.X, viewport.Y)

	local scale = if UiKit.isTouch() then self.keyScale else 1

	if UiKit.isPhoneViewport(viewport) then
		return math.floor(math.clamp(short * PHONE_KEY_SCALE, PHONE_KEY_MIN, PHONE_KEY_MAX) * scale)
	elseif not UiKit.isTouch() then
		return math.floor(math.clamp(viewport.Y * DESKTOP_KEY_SCALE, DESKTOP_KEY_MIN, DESKTOP_KEY_MAX))
	end

	return math.floor(math.clamp(short * TOUCH_KEY_SCALE, TOUCH_KEY_MIN, TOUCH_KEY_MAX) * scale)
end

-- The Settings window's button size, on touch screens only.
function StepPad.setKeyScale(self: StepPad, scale: number)
	self.keyScale = scale
	self:_fitKeys()
end

-- The keys are authored at KEY_SIZE and scaled to the screen, or to the thumb on touch.
function StepPad._fitKeys(self: StepPad)
	local gui = self.gui

	if gui == nil then
		return
	end

	PadHud.showLayout(gui, UiKit.viewportSize())

	local scale = self:_keySize() / KEY_SIZE
	local letters = not UiKit.isTouch()

	for _, cluster in self.clusters do
		UiKit.scaleOf(cluster, FIT_NAME).Scale = scale
	end

	-- A key outside the cluster already has a Press UIScale, and a second one on it would be ignored.
	for _, loose in self.looseKeys do
		loose.button.Size = UDim2.fromOffset(loose.size.X * scale, loose.size.Y * scale)
	end

	for _, key in self:_allKeys() do
		for _, part in key.parts do
			if part.letter ~= nil then
				part.letter.Visible = letters
			end
		end
	end
end

local ACTION_DELTAS: { [string]: { number } } = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

-- Writes a rebound key on its pad key in every layout; action is "up", "down",
-- "left", "right" or "clap".
function StepPad.setKeyLetter(self: StepPad, action: string, text: string)
	local delta = ACTION_DELTAS[action]

	for _, key in self:_allKeys() do
		local matches = if action == "clap"
			then key.clap == true
			else delta ~= nil and not key.clap and key.dx == delta[1] and key.dy == delta[2]

		if matches then
			for _, part in key.parts do
				if part.letter ~= nil and part.letter:IsA("TextLabel") then
					part.letter.Text = text
				end
			end
		end
	end
end

function StepPad._allKeys(self: StepPad): { Key }
	local all = {}

	for _, key in self.keys do
		table.insert(all, key)
	end

	if self.clapKey ~= nil then
		table.insert(all, self.clapKey)
	end

	return all
end

-- The corner the step keys take at the bottom left of a screen at origin, size
-- big, with a margin on the floor's side, so the pad can be framed clear of
-- it; zero while they are hidden.
function StepPad.footprint(self: StepPad, origin: Vector2, size: Vector2): Vector2
	if not self:_keysShown() then
		return Vector2.zero
	end

	for _, cluster in self.clusters do
		if self.layoutOf[cluster].Visible then
			local reach = cluster.AbsolutePosition + cluster.AbsoluteSize - origin
			return Vector2.new(reach.X, size.Y - (cluster.AbsolutePosition.Y - origin.Y)) + Vector2.one * KEY_EDGE
		end
	end

	return Vector2.zero
end

-- The corner the CLAP key takes at the bottom right, with the same margin;
-- zero while it is hidden.
function StepPad.clapReach(self: StepPad, origin: Vector2, size: Vector2): Vector2
	local clapKey = self.clapKey

	if clapKey == nil or not self.clapEnabled or not self:_keysShown() then
		return Vector2.zero
	end

	for _, cluster in self.clusters do
		local layout = self.layoutOf[cluster]

		if layout.Visible then
			for _, part in clapKey.parts do
				if part.button:IsDescendantOf(layout) then
					return origin + size - part.button.AbsolutePosition + Vector2.one * KEY_EDGE
				end
			end
		end
	end

	return Vector2.zero
end

-- Lights the key for a step taken from the keyboard, stick or a tap.
function StepPad.flashDirection(self: StepPad, dx: number, dy: number)
	for _, key in self:_keysFor(dx, dy) do
		self:_flash(key)
	end
end

-- A diagonal has no key of its own on the four-key pad: it is both of its keys.
function StepPad._keysFor(self: StepPad, dx: number, dy: number): { Key }
	local key = self.keys[directionKey(dx, dy)]

	if key ~= nil then
		return { key }
	end

	local keys = {}

	for _, axis in { directionKey(dx, 0), directionKey(0, dy) } do
		local axisKey = self.keys[axis]

		if axisKey ~= nil then
			table.insert(keys, axisKey)
		end
	end

	return keys
end

function StepPad.flashClap(self: StepPad)
	if self.clapKey ~= nil then
		self:_flash(self.clapKey)
	end
end

function StepPad._flash(self: StepPad, key: Key)
	self:_light(key, true)
	task.delay(PRESS_INFO.Time + 0.05, function()
		if not self:_isHeld(key) then
			self:_light(key, false)
		end
	end)
end

-- Fills the key that steps toward the next target to level 0..1, in color or
-- pink; beatsAway, when given, ticks it on the beat. nil clears it.
function StepPad.setGuide(self: StepPad, dx: number?, dy: number?, level: number, beatsAway: number?, color: Color3?)
	local keys = if dx ~= nil and dy ~= nil then self:_keysFor(dx, dy) else {}

	for _, previous in self.guided do
		if table.find(keys, previous) == nil then
			unpaintGuide(previous)
		end
	end

	self.guided = keys

	for _, key in keys do
		paintGuide(key, color or GUIDE_COLOR, level, beatsAway)
	end
end

-- Fills the CLAP key yellow while the next note is a clap, the same way the
-- step keys fill; nil clears it.
function StepPad.setClapGuide(self: StepPad, level: number?, beatsAway: number?)
	local key = self.clapKey

	if key == nil then
		return
	end

	if level == nil then
		unpaintGuide(key)
	else
		paintGuide(key, CLAP_GUIDE_COLOR, level, beatsAway)
	end
end

function StepPad._isHeld(self: StepPad, entry: Key | GridButton): boolean
	for _, held in self.held do
		if held == entry then
			return true
		end
	end

	return false
end

function StepPad._light(_self: StepPad, entry: Key | GridButton, on: boolean)
	local parts = (entry :: any).parts :: { KeyPart }?

	if parts == nil then
		(entry :: GridButton).button.BackgroundTransparency = if on then PRESSED_TRANSPARENCY else IDLE_TRANSPARENCY
		return
	end

	local info = if on then PRESS_INFO else RELEASE_INFO

	for _, part in parts do
		TweenService:Create(part.flash, info, { BackgroundTransparency = if on then FLASH_TRANSPARENCY else 1 }):Play()
		TweenService:Create(part.press, info, { Scale = if on then PRESS_SCALE else 1 }):Play()
	end
end

function StepPad._track(self: StepPad, button: GuiButton, entry: Key | GridButton)
	button.InputBegan:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end

		self.held[input] = entry
		self:_light(entry, true)

		local tile = (entry :: any).tile :: { x: number, y: number }?
		local key = entry :: Key

		if tile ~= nil then
			if self.onTile ~= nil then
				self.onTile(tile.x, tile.y)
			end
		elseif key.clap then
			if self.onClap ~= nil then
				self.onClap()
			end
		elseif self.onDirection ~= nil then
			self.onDirection(key.dx, key.dy)
		end
	end)
end

return StepPad
