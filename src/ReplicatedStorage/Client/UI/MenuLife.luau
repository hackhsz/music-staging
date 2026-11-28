--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

-- An authored instance asks for an idle loop by naming it in this attribute.
local LIFE = "Life"
local SCALE_NAME = "Life"
local FILL_NAME = "Fill"
local FILL_SECONDS = 0.6
local FILL_DELAY_SECONDS = 0.18

type Loop = (gui: GuiObject) -> ()

local function loopInfo(seconds: number): TweenInfo
	return TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
end

local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild(SCALE_NAME)

	if existing ~= nil and existing:IsA("UIScale") then
		return existing
	end

	local scale = Instance.new("UIScale")

	scale.Name = SCALE_NAME
	scale.Parent = gui

	return scale
end

local LOOPS: { [string]: Loop } = {
	pulse = function(gui)
		TweenService:Create(scaleOf(gui), loopInfo(0.5), { Scale = 1.04 }):Play()
	end,
	flicker = function(gui)
		gui.Rotation -= 2
		TweenService:Create(gui, loopInfo(0.4), { Rotation = gui.Rotation + 4 }):Play()
		TweenService:Create(scaleOf(gui), loopInfo(0.3), { Scale = 1.07 }):Play()
	end,
	wobble = function(gui)
		gui.Rotation -= 1
		TweenService:Create(gui, loopInfo(1.6), { Rotation = gui.Rotation + 2 }):Play()
	end,
	bob = function(gui)
		TweenService:Create(scaleOf(gui), loopInfo(1.8), { Scale = 1.03 }):Play()
	end,
	spin = function(gui)
		TweenService:Create(
			gui,
			TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Rotation = gui.Rotation + 360 }
		):Play()
	end,
}

-- Motion inside a menu window: its bars fill up when it opens, and anything authored with a
-- Life attribute (pulse, flicker, wobble, bob or spin) keeps moving.
-- Tweens only; nothing here knows what the window is for.
local MenuLife = {}

local started: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function startLoops(root: GuiObject)
	for _, descendant in root:GetDescendants() do
		local kind = descendant:GetAttribute(LIFE)
		local loop = if type(kind) == "string" then LOOPS[kind] else nil

		if loop ~= nil and descendant:IsA("GuiObject") and not started[descendant] then
			started[descendant] = true
			loop(descendant)
		end
	end
end

local function growBars(root: GuiObject)
	for _, descendant in root:GetDescendants() do
		if descendant.Name ~= FILL_NAME or not descendant:IsA("GuiObject") then
			continue
		end

		local size = descendant.Size

		if size.X.Scale <= 0 then
			continue
		end

		descendant.Size = UDim2.new(0, 0, size.Y.Scale, size.Y.Offset)
		TweenService:Create(
			descendant,
			TweenInfo.new(FILL_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, FILL_DELAY_SECONDS),
			{ Size = size }
		):Play()
	end
end

-- root: a window, or the view inside one that has just been switched to.
function MenuLife.enter(root: GuiObject?)
	if root == nil or GuiService.ReducedMotionEnabled then
		return
	end

	startLoops(root)
	growBars(root)
end

return MenuLife
