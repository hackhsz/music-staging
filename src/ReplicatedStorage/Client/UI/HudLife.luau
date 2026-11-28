--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)

local SCALE_NAME = "Life"
local ICON_HOVER_SCALE = 1.12
local ICON_HOVER_TILT = -4
local ICON_HOVER_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ICON_REST_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOP_RISE = UDim2.fromScale(0, -0.12)
local HOP_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local HOP_STAGGER_SECONDS = 0.09
local HOP_EVERY_SECONDS = 5
local DOT_SCALE = 1.35
local DOT_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Motion for the layered lobby HUD: under the pointer a tile's icon pops and its pink Glow rim
-- lights; icons hop in a wave now and then and notification dots pulse. Tweens only; no game rules.
local HudLife = {}

local function iconOf(button: Instance): GuiObject?
	return UiKit.child(button, "Icon", "GuiObject")
end

local function bindIconPop(button: GuiButton, icon: GuiObject)
	local scale = UiKit.scaleOf(icon, SCALE_NAME)
	local rest = icon.Rotation
	local glow = UiKit.child(button, "Glow", "ImageLabel")

	local function light(on: boolean)
		if glow ~= nil then
			TweenService:Create(glow, ICON_REST_INFO, { ImageTransparency = if on then 0 else 1 }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, ICON_HOVER_INFO, { Scale = ICON_HOVER_SCALE }):Play()
		TweenService:Create(icon, ICON_HOVER_INFO, { Rotation = rest + ICON_HOVER_TILT }):Play()
		light(true)
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, ICON_REST_INFO, { Scale = 1 }):Play()
		TweenService:Create(icon, ICON_REST_INFO, { Rotation = rest }):Play()
		light(false)
	end)
end

local function inOrder(buttons: { GuiButton }): { GuiButton }
	table.sort(buttons, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	return buttons
end

local function hopWave(row: { GuiObject })
	for index, icon in row do
		task.delay((index - 1) * HOP_STAGGER_SECONDS, function()
			if icon.Parent ~= nil then
				TweenService:Create(icon, HOP_INFO, { Position = icon.Position + HOP_RISE }):Play()
			end
		end)
	end
end

-- groups: containers whose buttons carry an Icon layer (the lobby's side column, dock and top row).
function HudLife.attach(groups: { Instance? })
	local rows: { { GuiObject } } = {}

	for _, group in groups do
		if group == nil then
			continue
		end

		local buttons: { GuiButton } = {}

		for _, child in group:GetChildren() do
			if child:IsA("GuiButton") and iconOf(child) ~= nil then
				table.insert(buttons, child)
			end
		end

		local row: { GuiObject } = {}

		for _, button in inOrder(buttons) do
			local icon = iconOf(button) :: GuiObject

			bindIconPop(button, icon)
			table.insert(row, icon)

			local dot = UiKit.child(button, "Dot", "GuiObject")

			if dot ~= nil then
				TweenService:Create(UiKit.scaleOf(dot, SCALE_NAME), DOT_INFO, { Scale = DOT_SCALE }):Play()
			end
		end

		table.insert(rows, row)
	end

	task.spawn(function()
		while true do
			for _, row in rows do
				task.wait(HOP_EVERY_SECONDS / math.max(#rows, 1))
				hopWave(row)
			end
		end
	end)
end

return HudLife
