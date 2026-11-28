--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ease = require(Shared:WaitForChild("Ease"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))
local HudContract = require(Shared:WaitForChild("HudContract"))
local UiKit = require(script.Parent.Parent.UiKit)

-- Where notes enter, as a fraction of the screen's height, unless a HUD panel
-- above the lanes reaches lower; then they start just under it.
local TRACK_TOP = 0.22
local AVOID_GAP = 8
local AVOID_ROLES = { "ScoreGroup", "PauseButton" }
local TRACK_GROW_SECONDS = 0.35
local TRACK_WIDTH_SCALE = 0.82
local TRACK_COLOR = Color3.fromRGB(24, 10, 34)
-- Each lane is a dark shade of its own colour that fades in from the top, so
-- the four lanes read as the four colours rather than as grey slabs.
local TRACK_LANE_SHADE = 0.22
local TRACK_TRANSPARENCY = 0.35
local TRACK_STROKE_TRANSPARENCY = 0.55
local BEAT_LINE_TRANSPARENCY = 0.85
local BAR_LINE_TRANSPARENCY = 0.7
-- Notes are arrows in their lane's colour, pointing their lane's way, the same
-- size as the receptor they land on, as in Friday Night Funkin'.
local NOTE_SCALE = 0.76
local MINE_COLOR = Color3.fromRGB(150, 24, 48)
-- A hold's tail runs up from its arrow as a bar narrower than the arrow.
local TAIL_WIDTH = 0.36
local TAIL_TRANSPARENCY = 0.3
local TAIL_HOLDING_TRANSPARENCY = 0.05
local TAIL_DROPPED_TRANSPARENCY = 0.6
local TAIL_CORE_WIDTH = 0.4
local TAIL_SHIMMER = 0.12
local TAIL_SHIMMER_RATE = 18
local MISS_GREY = 0.85
-- Each authored key shows a grey arrow in place of its letter: the receptor a
-- note lands on. Keys never move; the receptor does the reacting. It warms to
-- its lane colour as a note comes in, shrinks into a darker shade while held,
-- and pops bright when it confirms a hit, with a glow behind the key.
local KEY_IDLE = Color3.fromRGB(150, 146, 165)
local KEYCAP_IDLE = Color3.fromRGB(90, 86, 104)
local KEY_APPROACH_TINT = 0.6
local KEY_HELD_TINT = 0.6
local KEY_HELD_DARKEN = 0.25
local RECEPTOR_SCALE = 0.76
local RECEPTOR_PRESSED_SCALE = 0.66
local RECEPTOR_CONFIRM_SCALE = 0.88
-- An underdamped spring, so a released key overshoots a little and settles.
local RECEPTOR_STIFFNESS = 900
local RECEPTOR_DAMPING = 26
local SPRING_STEP = 1 / 120
local RECEPTOR_BEAT_BUMP = 0.04
local GLOW_SCALE = 1.25
local GLOW_BURST_SCALE = 1.5
local GLOW_START_TRANSPARENCY = 0.1
local SUSTAIN_GLOW_TRANSPARENCY = 0.4
local CONFIRM_SECONDS = 0.22
local PERFECT_CONFIRM_SECONDS = 0.32
-- A good hit throws a ring and a splash of lane-coloured squares off the key,
-- sized by the grade. Everything comes from fixed pools.
local SPLASH_PIECES = { Perfect = 8, Great = 5, Good = 0 }
local SPLASH_RING_SCALE = { Perfect = 1.9, Great = 1.55, Good = 1.25 }
local SPLASH_RING_STRENGTH = { Perfect = 1, Great = 0.8, Good = 0.45 }
local SPLASH_SECONDS = 0.3
local SPLASH_DISTANCE = 0.9
local SPLASH_PIECE_SIZE = 0.14
local RING_SECONDS = 0.28
local RING_THICKNESS = 0.07
local PARTICLE_POOL = 40
local RING_POOL = 8
local SPARKLE_INTERVAL = 0.07
local SPARKLE_SECONDS = 0.35
local SPARKLE_RISE = 0.8
local SPARKLE_SIZE = 0.09
local STROKE_BEAT_TRANSPARENCY = 0.2
-- Fractions of the scroll: how quickly a new note fades and grows in, and how
-- far a missed note keeps falling past its key before it is gone.
local FADE_IN = 0.1
local SPAWN_SCALE = 0.6
local PAST_TRAVEL = 0.12
-- The panel behind the keys breathes with the music: dimmest just before a
-- beat, full brightness on it.
local PULSE_DEPTH = 0.18
local METER_HIT_SECONDS = 0.2

-- Only used when the place has no authored lane keys.
local FALLBACK_KEY_SIZE = 76
local FALLBACK_GAP = 10
local FALLBACK_MARGIN = 28

-- tail is a hold's length in the same units as progress (0 for a tap); state
-- is "holding" while its key is kept down, or "dropped" once let go early.
export type Note = {
	lane: number,
	progress: number,
	kind: string,
	tail: number?,
	state: string?,
}

-- A line across all lanes on a beat; strong on the first beat of a bar.
export type BeatLine = {
	progress: number,
	strong: boolean,
}

-- The bar under an authored key: an image whose gradient's opaque part shows
-- how full it is. The fill is set by rewriting that gradient's transparency.
type Meter = {
	fill: ImageLabel,
	gradient: UIGradient,
	restTransparency: NumberSequence,
	restColor: Color3,
	hitUntil: number,
}

type Particle = {
	frame: Frame,
	live: boolean,
	bornAt: number,
	seconds: number,
	from: Vector2,
	travel: Vector2,
	size: number,
	rotation: number,
	spin: number,
}

type Ring = {
	frame: Frame,
	stroke: UIStroke,
	live: boolean,
	bornAt: number,
	center: Vector2,
	from: number,
	to: number,
	strength: number,
}

type Lane = {
	key: GuiObject,
	keyColor: Color3?,
	authoredPosition: UDim2,
	authoredAnchor: Vector2,
	legend: TextLabel?,
	meter: Meter?,
	track: Frame,
	trackStroke: UIStroke,
	receptor: ImageLabel?,
	glow: ImageLabel?,
	approach: number,
	held: boolean,
	sustain: boolean,
	receptorScale: number,
	receptorVelocity: number,
	nextSparkle: number,
	confirmColor: Color3,
	confirmAt: number,
	confirmSeconds: number,
}

type Fields = {
	gui: ScreenGui?,
	layer: Frame,
	lanes: { Lane },
	panel: ImageLabel?,
	panelColor: Color3,
	layout: UIListLayout?,
	frozen: boolean,
	avoid: { GuiObject },
	shownAt: number,
	lastFrame: number,
	notePool: { Frame },
	beatPool: { Frame },
	particles: { Particle },
	rings: { Ring },
	beatPhase: number,
	fontFace: Font?,
	touches: { [InputObject]: number },
	onPress: ((lane: number) -> ())?,
	onRelease: ((lane: number) -> ())?,
}

-- Friday Night Funkin' style lanes inside the HUD's own key panel: arrows fall
-- down each lane onto a receptor arrow set into the authored keycap, on the
-- beat. On touch the whole lane is the button. Drawing only: the controller
-- decides what is on it.
local NoteHighway = {}
NoteHighway.__index = NoteHighway

export type NoteHighway = typeof(setmetatable({} :: Fields, NoteHighway))

local function fontOf(key: Instance): Font?
	local label = key:FindFirstChildWhichIsA("TextLabel", true)

	return if label ~= nil then label.FontFace else nil
end

local function applyFont(label: TextLabel, fontFace: Font?)
	if fontFace ~= nil then
		label.FontFace = fontFace
	else
		label.FontFace = UiKit.FontFace
	end
end

local function isImage(instance: Instance): boolean
	return instance:IsA("ImageLabel") or instance:IsA("ImageButton")
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function meterOf(key: GuiObject): Meter?
	for _, inst in key:GetDescendants() do
		if inst:IsA("UIGradient") then
			local fill = inst.Parent

			if fill ~= nil and fill:IsA("ImageLabel") then
				return {
					fill = fill,
					gradient = inst,
					restTransparency = inst.Transparency,
					restColor = fill.ImageColor3,
					hitUntil = 0,
				}
			end
		end
	end

	return nil
end

-- Opaque from the left edge up to `fill`, clear after it.
local function fillSequence(fill: number): NumberSequence
	if fill <= 0 then
		return NumberSequence.new(1)
	elseif fill >= 1 then
		return NumberSequence.new(0)
	end

	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(fill, 0),
		NumberSequenceKeypoint.new(math.min(fill + 0.001, 1), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function avoidedPanels(host: Instance): { GuiObject }
	local panels = {}

	for _, inst in CollectionService:GetTagged(HudContract.Tag) do
		local role = inst:GetAttribute(HudContract.RoleAttribute)

		if inst:IsA("GuiObject") and inst:IsDescendantOf(host) and table.find(AVOID_ROLES, role) ~= nil then
			table.insert(panels, inst)
		end
	end

	return panels
end

local function arrowImage(parent: Instance, name: string, lane: number, zIndex: number): ImageLabel
	return UiKit.create("ImageLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = HighwayLanes.ArrowImage,
		Rotation = HighwayLanes.get(lane).rotation,
		ZIndex = zIndex,
	}, parent)
end

-- The code-built stand-in for the authored keys: four dark boxes at the bottom
-- right, where the art puts them.
local function buildFallbackKeys(layer: Frame): { GuiObject }
	local keys: { GuiObject } = {}

	for lane = 1, HighwayLanes.Count do
		local fromRight = (HighwayLanes.Count - lane) * (FALLBACK_KEY_SIZE + FALLBACK_GAP)

		local key: Frame = UiKit.create("Frame", {
			Name = "FallbackKey" .. lane,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -FALLBACK_MARGIN - fromRight, 1, -FALLBACK_MARGIN),
			Size = UDim2.fromOffset(FALLBACK_KEY_SIZE, FALLBACK_KEY_SIZE),
			BackgroundColor3 = TRACK_COLOR,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, layer)
		UiKit.create("UICorner", { CornerRadius = UDim.new(0.18, 0) }, key)

		table.insert(keys, key)
	end

	return keys
end

function NoteHighway.new(authoredKeys: { GuiObject }): NoteHighway
	local useAuthored = #authoredKeys == HighwayLanes.Count
	local host: Instance? = if useAuthored then authoredKeys[1]:FindFirstAncestorOfClass("ScreenGui") else nil
	local gui: ScreenGui? = nil

	if host == nil then
		useAuthored = false
		gui = UiKit.create("ScreenGui", {
			Name = "DanceDanceStepHighway",
			ResetOnSpawn = false,
			DisplayOrder = 5,
		}, Players.LocalPlayer:WaitForChild("PlayerGui"))
		host = gui
	end

	-- Lives in the same ScreenGui as the keys, so their absolute positions and
	-- the notes' share one coordinate space whatever the inset settings are.
	local layer: Frame = UiKit.create("Frame", {
		Name = "HighwayLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Visible = false,
	}, host)

	local keys: { GuiObject } = if useAuthored then authoredKeys else buildFallbackKeys(layer)
	local lanes = {}

	for lane, key in keys do
		local laneColor = HighwayLanes.get(lane).color
		local track: Frame = UiKit.create("Frame", {
			Name = "Track" .. lane,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = TRACK_COLOR:Lerp(laneColor, TRACK_LANE_SHADE),
			BackgroundTransparency = TRACK_TRANSPARENCY,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, layer)
		UiKit.create("UICorner", { CornerRadius = UDim.new(0, 10) }, track)
		UiKit.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.4),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, track)
		local trackStroke: UIStroke = UiKit.create("UIStroke", {
			Color = HighwayLanes.get(lane).color,
			Thickness = 2,
			Transparency = TRACK_STROKE_TRANSPARENCY,
		}, track)

		local legend = if useAuthored then key:FindFirstChildWhichIsA("TextLabel") else nil

		table.insert(lanes, {
			key = key,
			keyColor = if isImage(key) then (key :: any).ImageColor3 else nil,
			authoredPosition = key.Position,
			authoredAnchor = key.AnchorPoint,
			legend = legend,
			meter = if useAuthored then meterOf(key) else nil,
			track = track,
			trackStroke = trackStroke,
			-- The stand-in keys carry their receptor from the start.
			receptor = if useAuthored then nil else arrowImage(key, "Receptor", lane, 3),
			glow = nil,
			approach = 0,
			held = false,
			sustain = false,
			receptorScale = RECEPTOR_SCALE,
			receptorVelocity = 0,
			nextSparkle = 0,
			confirmColor = Color3.new(1, 1, 1),
			confirmAt = -math.huge,
			confirmSeconds = CONFIRM_SECONDS,
		})
	end

	local panelParent = if useAuthored then keys[1].Parent else nil
	local panel: ImageLabel? = if panelParent ~= nil and panelParent:IsA("ImageLabel") then panelParent else nil

	local fields: Fields = {
		gui = gui,
		layer = layer,
		lanes = lanes,
		panel = panel,
		panelColor = if panel ~= nil then panel.ImageColor3 else Color3.new(1, 1, 1),
		layout = if panel ~= nil then panel:FindFirstChildWhichIsA("UIListLayout") else nil,
		frozen = false,
		avoid = if useAuthored and host ~= nil then avoidedPanels(host) else {},
		shownAt = 0,
		lastFrame = os.clock(),
		notePool = {},
		beatPool = {},
		particles = {},
		rings = {},
		beatPhase = 1,
		fontFace = fontOf(keys[1]),
		touches = {},
		onPress = nil,
		onRelease = nil,
	}
	local self = setmetatable(fields, NoteHighway)

	for lane, entry in lanes do
		for _, target in { entry.key, entry.track } do
			target.InputBegan:Connect(function(input: InputObject)
				if isPointer(input) and self.layer.Visible then
					self.touches[input] = lane

					if self.onPress ~= nil then
						self.onPress(lane)
					end
				end
			end)
		end
	end

	-- Released wherever the finger lifts, which is often off the key it began on.
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local lane = self.touches[input]

		if lane ~= nil then
			self.touches[input] = nil

			if self.onRelease ~= nil then
				self.onRelease(lane)
			end
		end
	end)

	return self
end

-- Whether the notes land on the place's own keys rather than drawn stand-ins.
function NoteHighway.usesAuthoredKeys(self: NoteHighway): boolean
	return self.gui == nil
end

-- callback receives the lane of a key or lane that was tapped or clicked.
function NoteHighway.bindPress(self: NoteHighway, callback: (lane: number) -> ())
	self.onPress = callback
end

-- callback receives the lane when the finger or mouse that pressed it lets go.
function NoteHighway.bindRelease(self: NoteHighway, callback: (lane: number) -> ())
	self.onRelease = callback
end

-- The glow has to sit behind its key, so it is a sibling of the keys in the
-- panel. The panel's list layout would line it up with the keys, so while the
-- highway runs the keys are pinned exactly where the layout put them and the
-- layout steps aside. Each key also swaps its letter for a receptor arrow.
-- Hiding hands all of it back.
function NoteHighway._freezeKeys(self: NoteHighway)
	local panel = self.panel
	local layout = self.layout

	if self.frozen or panel == nil or layout == nil then
		return
	end

	local origin = panel.AbsolutePosition
	local area = panel.AbsoluteSize

	if area.X <= 0 or area.Y <= 0 then
		return
	end

	-- Measure every key before anything changes: adding a glow to the panel
	-- while the layout is still in it would re-flow the row mid-measurement.
	local positions: { UDim2 } = {}

	for lane, entry in self.lanes do
		local key = entry.key
		local center = key.AbsolutePosition + key.AbsoluteSize / 2 - origin
		positions[lane] = UDim2.fromScale(center.X / area.X, center.Y / area.Y)
	end

	layout.Parent = nil
	self.frozen = true

	for lane, entry in self.lanes do
		local key = entry.key
		local position = positions[lane]
		local size = key.Size

		key.AnchorPoint = Vector2.new(0.5, 0.5)
		key.Position = position

		local glow: ImageLabel = UiKit.create("ImageLabel", {
			Name = "HighwayGlow" .. lane,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.new(size.X.Scale * GLOW_SCALE, 0, size.Y.Scale * GLOW_SCALE, 0),
			BackgroundTransparency = 1,
			Image = if isImage(key) then (key :: any).Image else "",
			ImageColor3 = HighwayLanes.get(lane).color,
			ImageTransparency = 1,
			ZIndex = key.ZIndex - 1,
		}, panel)
		entry.glow = glow

		-- The aspect constraint the key carries keeps its glow the key's shape.
		local aspect = key:FindFirstChildWhichIsA("UIAspectRatioConstraint")

		if aspect ~= nil then
			aspect:Clone().Parent = glow
		end

		if entry.legend ~= nil then
			entry.legend.Visible = false
		end

		local receptor = arrowImage(key, "HighwayReceptor", lane, key.ZIndex + 1)
		UiKit.create("UIAspectRatioConstraint", { AspectRatio = 1 }, receptor)
		entry.receptor = receptor
	end
end

function NoteHighway._unfreezeKeys(self: NoteHighway)
	local panel = self.panel
	local layout = self.layout

	if not self.frozen then
		return
	end

	for _, entry in self.lanes do
		if entry.glow ~= nil then
			entry.glow:Destroy()
			entry.glow = nil
		end

		if entry.receptor ~= nil then
			entry.receptor:Destroy()
			entry.receptor = nil
		end

		if entry.legend ~= nil then
			entry.legend.Visible = true
		end

		entry.key.Position = entry.authoredPosition
		entry.key.AnchorPoint = entry.authoredAnchor
	end

	if panel ~= nil and layout ~= nil then
		layout.Parent = panel
	end

	self.frozen = false
end

-- Showing grows the lanes up out of the keys and sets the receptors in place;
-- hiding hands the authored pieces back exactly as the art had them.
function NoteHighway.setVisible(self: NoteHighway, visible: boolean)
	if visible and not self.layer.Visible then
		self.shownAt = os.clock()
		self:_freezeKeys()
	end

	self.layer.Visible = visible

	if visible then
		self:_animateKeys(os.clock())
	else
		self:_restoreArt()
	end
end

function NoteHighway._restoreArt(self: NoteHighway)
	for _, entry in self.lanes do
		if entry.keyColor ~= nil then
			(entry.key :: any).ImageColor3 = entry.keyColor
		end

		entry.approach = 0
		entry.held = false
		entry.sustain = false
		entry.receptorScale = RECEPTOR_SCALE
		entry.receptorVelocity = 0
		entry.confirmAt = -math.huge
		entry.trackStroke.Transparency = TRACK_STROKE_TRANSPARENCY

		local meter = entry.meter

		if meter ~= nil then
			meter.gradient.Transparency = meter.restTransparency
			meter.fill.ImageColor3 = meter.restColor
			meter.hitUntil = 0
		end
	end

	for _, particle in self.particles do
		particle.live = false
		particle.frame.Visible = false
	end

	for _, ring in self.rings do
		ring.live = false
		ring.frame.Visible = false
	end

	self.beatPhase = 1
	table.clear(self.touches)
	self:_unfreezeKeys()

	if self.panel ~= nil then
		self.panel.ImageColor3 = self.panelColor
	end
end

-- While a hold is being kept down its receptor stays lit and its glow stays on.
function NoteHighway.setSustain(self: NoteHighway, lane: number, active: boolean)
	local entry = self.lanes[lane]

	if entry ~= nil then
		entry.sustain = active
	end
end

-- Holding is separate from pressing: a press is the instant the key goes
-- down, held is until it comes back up.
function NoteHighway.setHeld(self: NoteHighway, lane: number, held: boolean)
	local entry = self.lanes[lane]

	if entry ~= nil then
		entry.held = held
	end
end

-- Each receptor's look, worked out fresh every frame from four inputs: how
-- close its next note is, whether it is held, whether a hold is being kept,
-- and how long ago it confirmed a hit.
function NoteHighway._animateKeys(self: NoteHighway, now: number)
	local dt = math.clamp(now - self.lastFrame, 0, 0.1)
	self.lastFrame = now

	for lane, entry in self.lanes do
		local laneColor = HighwayLanes.get(lane).color
		local confirm = (now - entry.confirmAt) / entry.confirmSeconds
		local confirming = if confirm >= 0 and confirm < 1 then 1 - confirm else 0

		local color = KEY_IDLE:Lerp(laneColor, entry.approach * KEY_APPROACH_TINT)

		if entry.sustain then
			color = laneColor
		elseif entry.held then
			color = color:Lerp(laneColor, KEY_HELD_TINT):Lerp(Color3.new(0, 0, 0), KEY_HELD_DARKEN)
		end

		color = color:Lerp(entry.confirmColor, confirming ^ 2)

		local receptor = entry.receptor

		if receptor ~= nil then
			receptor.ImageColor3 = color

			local target = if entry.held and confirming <= 0 then RECEPTOR_PRESSED_SCALE else RECEPTOR_SCALE
			local remaining = dt

			while remaining > 0 do
				local step = math.min(remaining, SPRING_STEP)
				local force = RECEPTOR_STIFFNESS * (target - entry.receptorScale)
				entry.receptorVelocity += (force - RECEPTOR_DAMPING * entry.receptorVelocity) * step
				entry.receptorScale += entry.receptorVelocity * step
				remaining -= step
			end

			local bump = RECEPTOR_BEAT_BUMP * (1 - self.beatPhase) ^ 3
			local scale = entry.receptorScale + (RECEPTOR_CONFIRM_SCALE - RECEPTOR_SCALE) * confirming + bump
			receptor.Size = UDim2.fromScale(scale, scale)
		end

		if entry.sustain and now >= entry.nextSparkle then
			entry.nextSparkle = now + SPARKLE_INTERVAL
			self:_sparkle(lane, now)
		end

		if entry.keyColor ~= nil then
			(entry.key :: any).ImageColor3 = KEYCAP_IDLE:Lerp(color, 0.35)
		end

		local glow = entry.glow

		if glow ~= nil then
			local grow = GLOW_SCALE + (GLOW_BURST_SCALE - GLOW_SCALE) * (1 - confirming)
			local size = entry.key.Size
			glow.Size = UDim2.new(size.X.Scale * grow, 0, size.Y.Scale * grow, 0)
			glow.ImageColor3 = if confirming > 0 then entry.confirmColor else laneColor

			local burst = if confirming > 0
				then GLOW_START_TRANSPARENCY + (1 - GLOW_START_TRANSPARENCY) * (1 - confirming)
				else 1
			glow.ImageTransparency = if entry.sustain then math.min(burst, SUSTAIN_GLOW_TRANSPARENCY) else burst
		end
	end

	self:_animateEffects(now)
end

function NoteHighway._animateEffects(self: NoteHighway, now: number)
	for _, particle in self.particles do
		if not particle.live then
			continue
		end

		local t = (now - particle.bornAt) / particle.seconds

		if t >= 1 then
			particle.live = false
			particle.frame.Visible = false
			continue
		end

		local eased = Ease.outQuad(t)
		local position = particle.from + particle.travel * eased
		local side = particle.size * (1 - 0.7 * t)
		local frame = particle.frame
		frame.Position = UDim2.fromOffset(position.X, position.Y)
		frame.Size = UDim2.fromOffset(side, side)
		frame.Rotation = particle.rotation + particle.spin * t
		frame.BackgroundTransparency = t ^ 2
	end

	for _, ring in self.rings do
		if not ring.live then
			continue
		end

		local t = (now - ring.bornAt) / RING_SECONDS

		if t >= 1 then
			ring.live = false
			ring.frame.Visible = false
			continue
		end

		local eased = 1 - (1 - t) ^ 3
		local side = ring.from + (ring.to - ring.from) * eased
		ring.frame.Position = UDim2.fromOffset(ring.center.X, ring.center.Y)
		ring.frame.Size = UDim2.fromOffset(side, side)
		ring.stroke.Thickness = math.max(side * RING_THICKNESS * (1 - t), 1)
		ring.stroke.Transparency = 1 - ring.strength * (1 - t)
	end
end

function NoteHighway._takeParticle(self: NoteHighway): Particle?
	for _, particle in self.particles do
		if not particle.live then
			return particle
		end
	end

	if #self.particles >= PARTICLE_POOL then
		return nil
	end

	local frame: Frame = UiKit.create("Frame", {
		Name = "Splash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ZIndex = 6,
		Visible = false,
	}, self.layer)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.25, 0) }, frame)

	local particle: Particle = {
		frame = frame,
		live = false,
		bornAt = 0,
		seconds = 1,
		from = Vector2.zero,
		travel = Vector2.zero,
		size = 0,
		rotation = 0,
		spin = 0,
	}
	table.insert(self.particles, particle)

	return particle
end

function NoteHighway._emit(
	self: NoteHighway,
	now: number,
	from: Vector2,
	travel: Vector2,
	size: number,
	color: Color3,
	seconds: number
)
	local particle = self:_takeParticle()

	if particle == nil then
		return
	end

	particle.live = true
	particle.bornAt = now
	particle.seconds = seconds
	particle.from = from
	particle.travel = travel
	particle.size = size
	particle.rotation = math.random() * 90
	particle.spin = 90 + math.random() * 90
	particle.frame.BackgroundColor3 = color
	particle.frame.Visible = true
end

function NoteHighway._takeRing(self: NoteHighway): Ring?
	for _, ring in self.rings do
		if not ring.live then
			return ring
		end
	end

	if #self.rings >= RING_POOL then
		return nil
	end

	local frame: Frame = UiKit.create("Frame", {
		Name = "SplashRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Visible = false,
	}, self.layer)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)

	local ring: Ring = {
		frame = frame,
		stroke = UiKit.create("UIStroke", { Thickness = 2 }, frame),
		live = false,
		bornAt = 0,
		center = Vector2.zero,
		from = 0,
		to = 0,
		strength = 1,
	}
	table.insert(self.rings, ring)

	return ring
end

-- While a hold is kept, small sparks drift up the lane off the receptor.
function NoteHighway._sparkle(self: NoteHighway, lane: number, now: number)
	local center, size = self:_keySpot(lane)
	local side = math.min(size.X, size.Y)
	local from = center + Vector2.new((math.random() - 0.5) * side * 0.5, -side * 0.2)
	local travel = Vector2.new((math.random() - 0.5) * side * 0.3, -side * SPARKLE_RISE)
	local color = HighwayLanes.get(lane).color:Lerp(Color3.new(1, 1, 1), 0.5)

	self:_emit(now, from, travel, side * SPARKLE_SIZE, color, SPARKLE_SECONDS)
end

-- Where a lane's key sits inside the layer: its centre and size.
function NoteHighway._keySpot(self: NoteHighway, lane: number): (Vector2, Vector2)
	local key = self.lanes[lane].key
	local center = key.AbsolutePosition - self.layer.AbsolutePosition + key.AbsoluteSize / 2

	return center, key.AbsoluteSize
end

-- A note is an unrotated holder so its tail always runs up the lane, with the
-- arrow turned to its direction inside it.
function NoteHighway._buildNote(self: NoteHighway): Frame
	local note: Frame = UiKit.create("Frame", {
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, self.layer)

	local tail: Frame = UiKit.create("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		BorderSizePixel = 0,
		ZIndex = 3,
		Visible = false,
	}, note)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, tail)

	local core: Frame = UiKit.create("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(TAIL_CORE_WIDTH, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Visible = false,
	}, tail)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, core)

	arrowImage(note, "Arrow", 1, 4)

	local mark: TextLabel = UiKit.create("TextLabel", {
		Name = "Mark",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		ZIndex = 5,
	}, note)
	applyFont(mark, self.fontFace)

	return note
end

function NoteHighway._buildBeatLine(self: NoteHighway): Frame
	return UiKit.create("Frame", {
		Name = "BeatLine",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, self.layer)
end

local function fadeFor(progress: number): number
	if progress < FADE_IN then
		return 1 - progress / FADE_IN
	elseif progress > 1 then
		return math.min((progress - 1) / PAST_TRAVEL, 1)
	end

	return 0
end

local function spawnScale(progress: number): number
	if progress >= FADE_IN then
		return 1
	end

	local t = math.max(progress, 0) / FADE_IN

	return SPAWN_SCALE + (1 - SPAWN_SCALE) * Ease.outQuad(t)
end

-- Where notes enter: below any HUD panel hanging over the lanes, and grown up
-- from the keys while the highway first appears.
function NoteHighway._trackTop(self: NoteHighway, left: number, right: number, keyTop: number): number
	local origin = self.layer.AbsolutePosition
	local top = self.layer.AbsoluteSize.Y * TRACK_TOP

	for _, panel in self.avoid do
		local panelLeft = panel.AbsolutePosition.X - origin.X

		if panel.Visible and panelLeft < right and panelLeft + panel.AbsoluteSize.X > left then
			top = math.max(top, panel.AbsolutePosition.Y - origin.Y + panel.AbsoluteSize.Y + AVOID_GAP)
		end
	end

	local grow = math.clamp((os.clock() - self.shownAt) / TRACK_GROW_SECONDS, 0, 1)
	local eased = 1 - (1 - grow) ^ 3

	return keyTop - (keyTop - math.min(top, keyTop)) * eased
end

local function setNoteLook(note: Frame, data: Note, fade: number)
	local style = HighwayLanes.get(data.lane)
	local mine = data.kind == "danger"
	local arrow = note:FindFirstChild("Arrow")

	if arrow ~= nil and arrow:IsA("ImageLabel") then
		local color = if mine then MINE_COLOR elseif data.state == "dropped" then KEY_IDLE else style.color

		-- A note sliding past its key unhit greys out as it goes.
		if data.progress > 1 and data.state ~= "holding" then
			color = color:Lerp(KEY_IDLE, MISS_GREY * math.min((data.progress - 1) / PAST_TRAVEL, 1))
		end

		arrow.Rotation = style.rotation
		arrow.ImageColor3 = color
		arrow.ImageTransparency = fade
	end

	local mark = note:FindFirstChild("Mark")

	if mark ~= nil and mark:IsA("TextLabel") then
		mark.Text = if mine then "X" else ""
		mark.TextTransparency = fade
	end
end

-- room is how far the arrow is below the top of the lane, so a long tail is
-- cut off where the lane begins rather than hanging above it.
function NoteHighway._drawTail(self: NoteHighway, note: Frame, data: Note, room: number, lanePixels: number)
	local tail = note:FindFirstChild("Tail")

	if tail == nil or not tail:IsA("Frame") then
		return
	end

	local length = math.min((data.tail or 0) * lanePixels, math.max(room, 0))

	if length <= 1 then
		tail.Visible = false
		return
	end

	local holding = data.state == "holding"
	local shimmer = if holding then TAIL_SHIMMER * (0.5 + 0.5 * math.sin(os.clock() * TAIL_SHIMMER_RATE)) else 0

	tail.Size = UDim2.new(TAIL_WIDTH, 0, 0, length)
	tail.BackgroundColor3 = if data.state == "dropped" then KEY_IDLE else HighwayLanes.get(data.lane).color
	tail.BackgroundTransparency = if holding
		then TAIL_HOLDING_TRANSPARENCY + shimmer
		elseif data.state == "dropped" then TAIL_DROPPED_TRANSPARENCY
		else TAIL_TRANSPARENCY
	tail.Visible = true

	local core = tail:FindFirstChild("Core")

	if core ~= nil and core:IsA("Frame") then
		core.Visible = holding
		core.BackgroundTransparency = 0.35 + shimmer
	end
end

-- progress runs from 0 when something enters at the top to 1 when it sits on
-- its key, which is the beat.
function NoteHighway.render(self: NoteHighway, notes: { Note }, beatLines: { BeatLine })
	local left, right, keyTop, keyCenterY = math.huge, -math.huge, math.huge, 0

	for lane in self.lanes do
		local center, size = self:_keySpot(lane)
		local width = size.X * TRACK_WIDTH_SCALE

		left = math.min(left, center.X - width / 2)
		right = math.max(right, center.X + width / 2)
		keyTop = math.min(keyTop, center.Y - size.Y / 2)
		keyCenterY = center.Y
	end

	local top = self:_trackTop(left, right, keyTop)

	for lane, entry in self.lanes do
		local center, size = self:_keySpot(lane)
		entry.track.Position = UDim2.fromOffset(center.X, top)
		entry.track.Size = UDim2.fromOffset(size.X * TRACK_WIDTH_SCALE, math.max(keyTop - top, 0))
	end

	local shown = 0

	for _, line in beatLines do
		local y = top + (keyCenterY - top) * line.progress

		-- Lines stop above the keys; the keys themselves stay clean.
		if line.progress < 0 or y > keyTop then
			continue
		end

		shown += 1

		local existing: Frame? = self.beatPool[shown]
		local frame: Frame = if existing ~= nil then existing else self:_buildBeatLine()
		self.beatPool[shown] = frame

		local base = if line.strong then BAR_LINE_TRANSPARENCY else BEAT_LINE_TRANSPARENCY
		frame.Position = UDim2.fromOffset(left, y)
		frame.Size = UDim2.fromOffset(math.max(right - left, 0), if line.strong then 3 else 2)
		frame.BackgroundTransparency = base + (1 - base) * fadeFor(line.progress)
		frame.Visible = true
	end

	for index = shown + 1, #self.beatPool do
		self.beatPool[index].Visible = false
	end

	shown = 0

	for _, note in notes do
		if note.progress > 1 + PAST_TRAVEL or self.lanes[note.lane] == nil then
			continue
		end

		shown += 1

		local existing: Frame? = self.notePool[shown]
		local frame: Frame = if existing ~= nil then existing else self:_buildNote()
		self.notePool[shown] = frame

		local center, size = self:_keySpot(note.lane)
		local side = math.min(size.X, size.Y) * NOTE_SCALE * spawnScale(note.progress)
		local y = top + (center.Y - top) * note.progress

		frame.Position = UDim2.fromOffset(center.X, y)
		frame.Size = UDim2.fromOffset(side, side)
		setNoteLook(frame, note, fadeFor(note.progress))
		self:_drawTail(frame, note, y - top, center.Y - top)
		frame.Visible = true
	end

	for index = shown + 1, #self.notePool do
		self.notePool[index].Visible = false
	end

	self:_animateKeys(os.clock())
end

-- fills: per lane, 0 to 1, how close that lane's next note is to its beat.
-- The bar under each key fills in the lane colour and is full on the beat,
-- and the receptor warms toward the same colour.
function NoteHighway.setMeters(self: NoteHighway, fills: { number })
	local now = os.clock()

	for lane, entry in self.lanes do
		local fill = math.clamp(fills[lane] or 0, 0, 1)
		entry.approach = fill

		local meter = entry.meter

		if meter ~= nil and now >= meter.hitUntil then
			meter.gradient.Transparency = fillSequence(fill)
			meter.fill.ImageColor3 = meter.restColor:Lerp(HighwayLanes.get(lane).color, fill)
		end
	end
end

-- beatPhase is how far through the current beat the song is, 0 on the beat.
function NoteHighway.pulse(self: NoteHighway, beatPhase: number)
	local phase = math.clamp(beatPhase, 0, 1)
	local panel = self.panel
	self.beatPhase = phase

	if panel ~= nil then
		local dim = PULSE_DEPTH * phase ^ 2
		panel.ImageColor3 = self.panelColor:Lerp(Color3.new(0, 0, 0), dim)
	end

	local edge = STROKE_BEAT_TRANSPARENCY + (TRACK_STROKE_TRANSPARENCY - STROKE_BEAT_TRANSPARENCY) * (1 - (1 - phase) ^ 3)

	for _, entry in self.lanes do
		entry.trackStroke.Transparency = edge
	end
end

-- A press that caught a note confirms it: the receptor pops bright in its
-- lane colour, a glow bursts out behind the key, and the bar under it flashes
-- full. A press that caught nothing gets only the pressed look.
function NoteHighway.flashLane(self: NoteHighway, lane: number, caughtNote: boolean)
	local entry = self.lanes[lane]

	if entry == nil or not caughtNote then
		return
	end

	entry.confirmColor = HighwayLanes.get(lane).color:Lerp(Color3.new(1, 1, 1), 0.25)
	entry.confirmAt = os.clock()
	entry.confirmSeconds = CONFIRM_SECONDS

	local meter = entry.meter

	if meter ~= nil then
		meter.hitUntil = os.clock() + METER_HIT_SECONDS
		meter.gradient.Transparency = fillSequence(1)
		meter.fill.ImageColor3 = Color3.new(1, 1, 1)
	end
end

-- grade is "Perfect" (the default), "Great" or "Good". A Perfect also gets a
-- longer, whiter confirm, the way lane games mark their best hits.
function NoteHighway.splash(self: NoteHighway, lane: number, grade: string?)
	local entry = self.lanes[lane]
	local tier = grade or "Perfect"

	if entry == nil or SPLASH_RING_SCALE[tier] == nil then
		return
	end

	local now = os.clock()
	local color = HighwayLanes.get(lane).color

	if tier == "Perfect" then
		entry.confirmColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
		entry.confirmAt = now
		entry.confirmSeconds = PERFECT_CONFIRM_SECONDS
	end

	local center, size = self:_keySpot(lane)
	local side = math.min(size.X, size.Y)
	local ring = self:_takeRing()

	if ring ~= nil then
		ring.live = true
		ring.bornAt = now
		ring.center = center
		ring.from = side * RECEPTOR_SCALE
		ring.to = side * SPLASH_RING_SCALE[tier]
		ring.strength = SPLASH_RING_STRENGTH[tier]
		ring.stroke.Color = color:Lerp(Color3.new(1, 1, 1), 0.3)
		ring.frame.Visible = true
	end

	local pieces = SPLASH_PIECES[tier]
	local reach = side * SPLASH_DISTANCE
	local piece = side * SPLASH_PIECE_SIZE

	for index = 1, pieces do
		local angle = (index / pieces) * math.pi * 2 + math.random() * 0.5
		local travel = Vector2.new(math.cos(angle), math.sin(angle)) * reach

		self:_emit(now, center, travel, piece, color, SPLASH_SECONDS)
	end
end

return NoteHighway
