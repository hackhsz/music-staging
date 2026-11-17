--!strict
-- GridInput — discrete 4-way step input.
-- Keyboard + gamepad D-pad: Input Action System (InputContext/InputAction, press-only).
-- Gamepad left stick: one step per flick (press past STICK_PRESS, re-arm below STICK_RELEASE).
-- Touch: RoBeats-style lanes (GridInput/TouchLanes) that step on touch-down.
-- Roblox's default thumbstick/jump are hidden while enabled so they can't eat touches.
-- Optional ability key (E / gamepad Y) for mods like Fever Step; touch uses the HUD button.

local STICK_PRESS = 0.6
local STICK_RELEASE = 0.35
local ABILITY_EDGE_PX = 24
local ABILITY_GAP_PX = 12

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local TouchLanes = require(script:WaitForChild("TouchLanes"))
local Templates = script.Parent:WaitForChild("Templates")

local GridInput = {}
GridInput.__index = GridInput

local BINDINGS = {
	StepUp = { Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp },
	StepDown = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown },
	StepLeft = { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft },
	StepRight = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight },
}
local ABILITY_BINDINGS = { Enum.KeyCode.E, Enum.KeyCode.ButtonY }
local DIRS = {
	StepUp = Vector2.new(-1, 0),
	StepDown = Vector2.new(1, 0),
	StepLeft = Vector2.new(0, -1),
	StepRight = Vector2.new(0, 1),
}

function GridInput.stickDirection(position: Vector2): Vector2
	if math.abs(position.X) > math.abs(position.Y) then
		return if position.X > 0 then DIRS.StepRight else DIRS.StepLeft
	end
	return if position.Y > 0 then DIRS.StepUp else DIRS.StepDown
end

function GridInput.new(parent: Instance, onStep: (Vector2) -> (), onAbility: (() -> ())?)
	local self = setmetatable({}, GridInput)
	self.enabled = false
	self.conns = {}
	self.touchEnabled = UserInputService.TouchEnabled

	local context = Instance.new("InputContext")
	context.Name = "DDSGameplay"
	context.Sink = true
	context.Priority = 2000
	context.Enabled = false
	context.Parent = parent
	self.context = context

	for actionName, keys in BINDINGS do
		local action = Instance.new("InputAction")
		action.Name = actionName
		action.Type = Enum.InputActionType.Bool
		action.Parent = context
		for i, key in keys do
			local binding = Instance.new("InputBinding")
			binding.Name = actionName .. "Binding" .. i
			binding.KeyCode = key
			binding.Parent = action
		end
		action.Pressed:Connect(function()
			onStep(DIRS[actionName])
		end)
	end

	if onAbility then
		local abilityAction = Instance.new("InputAction")
		abilityAction.Name = "Ability"
		abilityAction.Type = Enum.InputActionType.Bool
		abilityAction.Parent = context
		for i, key in ABILITY_BINDINGS do
			local binding = Instance.new("InputBinding")
			binding.Name = "AbilityBinding" .. i
			binding.KeyCode = key
			binding.Parent = abilityAction
		end
		abilityAction.Pressed:Connect(onAbility)
	end

	if self.touchEnabled then
		local touchLanes = TouchLanes.new(Templates:WaitForChild("TouchLanes") :: ScreenGui, function(actionName)
			if self.enabled then
				onStep(DIRS[actionName])
			end
		end)
		self.touchLanes = touchLanes

		local abilityButton = parent:FindFirstChild("AbilityButton")
		if abilityButton and abilityButton:IsA("GuiObject") then
			abilityButton.AnchorPoint = Vector2.new(0, 1)
			abilityButton.Position = UDim2.new(0, ABILITY_EDGE_PX, touchLanes:topScale(), -ABILITY_GAP_PX)
		end
	end

	local stickArmed = true
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
		if not self.enabled or input.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if position.Magnitude < STICK_RELEASE then
			stickArmed = true
			return
		end
		if not stickArmed or position.Magnitude < STICK_PRESS then return end
		stickArmed = false
		onStep(GridInput.stickDirection(position))
	end))

	return self
end

function GridInput.enable(self)
	self.enabled = true
	self.context.Enabled = true
	if self.touchLanes then
		self.touchLanes:setEnabled(true)
	end
	if self.touchEnabled then
		-- Hide Roblox's thumbstick/jump: the character is anchored during play and
		-- those controls would otherwise swallow touches in the thumb zones.
		UserInputService.ModalEnabled = true
		GuiService.TouchControlsEnabled = false
	end
end

function GridInput.disable(self)
	self.enabled = false
	self.context.Enabled = false
	if self.touchLanes then
		self.touchLanes:setEnabled(false)
	end
	if self.touchEnabled then
		UserInputService.ModalEnabled = false
		GuiService.TouchControlsEnabled = true
	end
end

function GridInput.destroy(self)
	self:disable()
	for _, conn in self.conns do
		conn:Disconnect()
	end
	table.clear(self.conns)
	if self.touchLanes then
		self.touchLanes:Destroy()
		self.touchLanes = nil
	end
	self.context:Destroy()
end

return GridInput
