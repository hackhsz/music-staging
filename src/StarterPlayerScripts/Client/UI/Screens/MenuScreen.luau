--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.Parent.UiKit)

local OPEN_SECONDS = 0.36
local OPEN_FROM = UDim2.fromScale(0, 0.06)
local SWITCH_SECONDS = 0.26
local SWITCH_FROM = UDim2.fromScale(0.035, 0)
local CLOSE_SECONDS = 0.18
local POP_FROM = 0.84
local PHONE_SUFFIX = "Phone"
local PHONE_SIZE = "PhoneSize"
local PHONE_ASPECT = "PhoneAspect"
-- A window with this attribute set stands alone: the rail hides while it is open.
local STANDALONE = "Standalone"
-- The camera reports a 1x1 viewport for its first frames; the layout waits this
-- long at most for the real one.
local VIEWPORT_WAIT_SECONDS = 2
local WINDOW_NAMES = {
	loadout = "Loadout",
	shop = "Shop",
	settings = "Settings",
	quests = "Quests",
	islands = "Islands",
	market = "Market",
	rewards = "Rewards",
	community = "Community",
	wardrobe = "Wardrobe",
	stagePass = "Pass",
}
local NAV_NAMES = {
	home = "HomeButton",
	song = "SongButton",
	loadout = "LoadoutButton",
	shop = "ShopButton",
	wardrobe = "WardrobeButton",
	quests = "QuestsButton",
	islands = "IslandsButton",
	settings = "SettingsButton",
}

type Fields = {
	root: GuiObject?,
	backdrop: GuiObject?,
	backdropRest: number,
	scale: UIScale?,
	rail: GuiObject?,
	windows: { [string]: GuiObject },
	nav: { [string]: GuiButton },
	current: string?,
	blocked: boolean,
	closeToken: number,
	homes: { [GuiObject]: UDim2 },
	onChanged: ((name: string?) -> ())?,
}

-- The lobby's windows, authored in StarterGui.Menu: one at a time beside the
-- designer's rail, over a dimmed backdrop. Each window's own screen fills it in;
-- this only opens, switches and closes them, and lights the open one on the rail.
-- On a phone or tablet a window authored as "<Name>Phone" replaces its desktop one, and
-- anything with a PhoneSize or PhoneAspect attribute takes that size or aspect.
-- A window marked Standalone opens without the rail.
local MenuScreen = {}
MenuScreen.__index = MenuScreen

export type MenuScreen = typeof(setmetatable({} :: Fields, MenuScreen))

local function settledViewport(): Vector2
	local deadline = os.clock() + VIEWPORT_WAIT_SECONDS
	local size = UiKit.viewportSize()

	while (size.X <= 1 or size.Y <= 1) and os.clock() < deadline do
		task.wait()
		size = UiKit.viewportSize()
	end

	return size
end

-- Everything with a PhoneSize or PhoneAspect, with its desktop size and aspect kept
-- so the layout can switch back.
type Resizable = {
	gui: GuiObject,
	desktopSize: UDim2,
	phoneSize: UDim2?,
	constraint: UIAspectRatioConstraint?,
	desktopAspect: number,
	phoneAspect: number?,
}

local function collectResizable(root: Instance): { Resizable }
	local found: { Resizable } = {}

	for _, gui in root:GetDescendants() do
		local size = gui:GetAttribute(PHONE_SIZE)
		local aspect = gui:GetAttribute(PHONE_ASPECT)
		local constraint = gui:FindFirstChildOfClass("UIAspectRatioConstraint")

		if gui:IsA("GuiObject") and (typeof(size) == "UDim2" or type(aspect) == "number") then
			table.insert(found, {
				gui = gui,
				desktopSize = gui.Size,
				phoneSize = if typeof(size) == "UDim2" then size else nil,
				constraint = constraint,
				desktopAspect = if constraint ~= nil then constraint.AspectRatio else 1,
				phoneAspect = if type(aspect) == "number" then aspect else nil,
			})
		end
	end

	return found
end

local function isPhone(viewport: Vector2): boolean
	local measured = viewport.X > 1 and viewport.Y > 1

	return (measured and UiKit.isPhoneViewport(viewport)) or (UiKit.isTouch() and not UserInputService.MouseEnabled)
end

local function applyLayout(resizable: { Resizable }, phone: boolean)
	for _, entry in resizable do
		entry.gui.Size = if phone and entry.phoneSize ~= nil then entry.phoneSize else entry.desktopSize

		if entry.constraint ~= nil then
			entry.constraint.AspectRatio = if phone and entry.phoneAspect ~= nil
				then entry.phoneAspect
				else entry.desktopAspect
		end
	end
end

function MenuScreen.new(gui: ScreenGui?): MenuScreen
	local root = UiKit.authored(gui, "Root", "GuiObject")
	local holder = UiKit.authored(root, "Holder", "GuiObject")
	local backdrop = UiKit.authored(root, "Backdrop", "GuiObject")
	local buttons = UiKit.authored(holder, "Rail.Buttons", "GuiObject")

	local fields: Fields = {
		root = root,
		backdrop = backdrop,
		backdropRest = if backdrop ~= nil then backdrop.BackgroundTransparency else 1,
		scale = if holder ~= nil then UiKit.scaleOf(holder, "Pop") else nil,
		rail = UiKit.authored(holder, "Rail", "GuiObject"),
		windows = {},
		nav = {},
		current = nil,
		blocked = false,
		closeToken = 0,
		homes = {},
		onChanged = nil,
	}
	local self = setmetatable(fields, MenuScreen)
	-- Tablets take the phone layout too: it is the one built for touch.
	local phone = isPhone(settledViewport())

	if root ~= nil then
		-- Play can start while the window is still sizing up, so the layout follows the
		-- viewport rather than deciding once.
		local resizable = collectResizable(root)

		UiKit.onViewportChanged(function()
			applyLayout(resizable, isPhone(UiKit.viewportSize()))
		end)
	end

	for key, name in WINDOW_NAMES do
		local desktop = UiKit.authored(holder, name, "GuiObject")
		local phoneWindow = if holder ~= nil then UiKit.child(holder, name .. PHONE_SUFFIX, "GuiObject") else nil
		local window = if phone and phoneWindow ~= nil then phoneWindow else desktop

		for _, variant in { desktop, phoneWindow } do
			if variant ~= nil then
				variant.Visible = false
			end
		end

		if window ~= nil then
			fields.windows[key] = window
		end
	end

	for key, name in NAV_NAMES do
		local button = UiKit.authored(buttons, name, "GuiButton")

		if button ~= nil then
			fields.nav[key] = button
			self:_bindNavGlow(key, button)
		end
	end

	if root ~= nil then
		root.Visible = false
	end

	return self
end

-- A rail button glows under the pointer and while its window is open. A sprite
-- name glows only atlas art: on a whole-image button it would stretch an atlas
-- cut of a different shape over it.
function MenuScreen._bindNavGlow(self: MenuScreen, key: string, button: GuiButton)
	if not button:IsA("ImageButton") then
		return
	end

	local rest = UiKit.imageState(button)
	local glow = button:GetAttribute("HoverImage")

	if type(glow) ~= "string" or (rest.size == Vector2.zero and not glow:match("^rbxassetid://")) then
		UiKit.bindHover(button)
		return
	end

	local hovered = false

	local function paint()
		UiKit.setImage(button, if (hovered or self.current == key) and type(glow) == "string" then glow else rest)
	end

	button:SetAttribute("RestImage", rest.image)
	UiKit.bindHover(button, function(active: boolean)
		hovered = active
		paint()
	end)
	button:GetAttributeChangedSignal("Lit"):Connect(paint)
end

function MenuScreen.window(self: MenuScreen, key: string): GuiObject?
	return self.windows[key]
end

function MenuScreen.navButton(self: MenuScreen, key: string): GuiButton?
	return self.nav[key]
end

function MenuScreen.isOpen(self: MenuScreen, key: string?): boolean
	if key == nil then
		return self.current ~= nil
	end

	return self.current == key
end

function MenuScreen.bindChanged(self: MenuScreen, callback: (name: string?) -> ())
	self.onChanged = callback
end

-- A run blocks the menu, and closes it if it is open.
function MenuScreen.setBlocked(self: MenuScreen, blocked: boolean)
	self.blocked = blocked

	if blocked then
		self:close()
	end
end

function MenuScreen.isBlocked(self: MenuScreen): boolean
	return self.blocked
end

function MenuScreen.open(self: MenuScreen, key: string)
	local root = self.root

	if self.blocked or root == nil or self.windows[key] == nil or self.current == key then
		return
	end

	local opening = self.current == nil

	for name, window in self.windows do
		window.Visible = name == key
	end

	if self.rail ~= nil then
		self.rail.Visible = self.windows[key]:GetAttribute(STANDALONE) ~= true
	end

	self.current = key
	self.closeToken += 1
	self:_lightNav()

	UiKit.playSound(if opening then "uiOpen" else "uiSwitch")

	local window = self.windows[key]
	local home = self.homes[window] or window.Position

	-- Read once, at rest: a window switched to mid-slide must still land where it was authored.
	self.homes[window] = home
	window.Position = home + (if opening then OPEN_FROM else SWITCH_FROM)
	self:_tween(
		window,
		if opening then OPEN_SECONDS else SWITCH_SECONDS,
		{ Position = home },
		nil,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)

	if opening then
		root.Visible = true
		self:_tween(self.scale, OPEN_SECONDS, { Scale = 1 }, POP_FROM, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		self:_tween(self.backdrop, OPEN_SECONDS, { BackgroundTransparency = self.backdropRest }, 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	if self.onChanged ~= nil then
		self.onChanged(key)
	end

	-- Deferred so the panel has drawn its cards before they pop.
	task.defer(UiKit.popIn, window)
end

-- Closes the menu, or only when key is the open window.
function MenuScreen.close(self: MenuScreen, key: string?)
	local root = self.root

	if self.current == nil or root == nil or (key ~= nil and self.current ~= key) then
		return
	end

	self.current = nil
	self.closeToken += 1
	self:_lightNav()

	local token = self.closeToken

	UiKit.playSound("uiClose")
	self:_tween(self.scale, CLOSE_SECONDS, { Scale = POP_FROM }, nil, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	self:_tween(self.backdrop, CLOSE_SECONDS, { BackgroundTransparency = 1 }, nil, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(CLOSE_SECONDS, function()
		if self.closeToken == token then
			root.Visible = false
		end
	end)

	if self.onChanged ~= nil then
		self.onChanged(nil)
	end
end

function MenuScreen.toggle(self: MenuScreen, key: string)
	if self.current == key then
		self:close()
	else
		self:open(key)
	end
end

function MenuScreen._lightNav(self: MenuScreen)
	for key, button in self.nav do
		button:SetAttribute("Lit", self.current == key)
	end
end

-- from, when given, is where the property starts before it eases to goal.
function MenuScreen._tween(
	_self: MenuScreen,
	instance: Instance?,
	seconds: number,
	goal: { [string]: any },
	from: number?,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection
)
	if instance == nil then
		return
	end

	if from ~= nil then
		for property in goal do
			(instance :: any)[property] = from
		end
	end

	TweenService:Create(instance, TweenInfo.new(seconds, style, direction), goal):Play()
end

return MenuScreen
