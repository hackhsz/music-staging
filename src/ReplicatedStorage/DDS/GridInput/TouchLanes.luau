--!strict
-- TouchLanes — RoBeats-style step lanes for touch: ◀ ▼ under the left thumb, ▲ ▶ under the right.
-- A lane fires on touch-down and stays lit while any finger holds it; each finger is tracked
-- separately so chords and fast alternation never drop a press.

local LANDSCAPE_CLUSTER_WIDTH = 0.3
local PORTRAIT_CLUSTER_WIDTH = 0.5
local CLUSTER_EDGE_PX = 12
local FLASH_TRANSPARENCY = 0.35
local PRESS_SCALE = 0.86
local PRESS_IN_SEC = 0.03
local RELEASE_SEC = 0.18

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Maid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utility"):WaitForChild("Maid"))

local PRESS_INFO = TweenInfo.new(PRESS_IN_SEC, Enum.EasingStyle.Linear)
local RELEASE_INFO = TweenInfo.new(RELEASE_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TouchLanes = {}
TouchLanes.__index = TouchLanes

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

function TouchLanes.new(template: ScreenGui, onPress: (string) -> ())
	local self = setmetatable({}, TouchLanes)
	self.Maid = Maid.new()
	self.onPress = onPress
	self.heldInputs = {} :: { [InputObject]: GuiButton }
	self.lanes = {} :: { GuiButton }

	local gui = self.Maid:GiveTask(template:Clone()) :: ScreenGui
	gui.Enabled = false
	self.gui = gui
	self.clusters = { gui:WaitForChild("Left") :: Frame, gui:WaitForChild("Right") :: Frame }

	for _, cluster in self.clusters do
		for _, lane in cluster:GetChildren() do
			if lane:IsA("GuiButton") then
				self:bindLane(lane)
			end
		end
	end

	self.Maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		local lane = self.heldInputs[input]
		if not lane then
			return
		end
		self.heldInputs[input] = nil
		if not self:isHeld(lane) then
			self:light(lane, false)
		end
	end))

	local camera = workspace.CurrentCamera
	self.Maid:GiveTask(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:fitToViewport()
	end))
	self:fitToViewport()

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return self
end

function TouchLanes.bindLane(self, lane: GuiButton)
	table.insert(self.lanes, lane)
	self.Maid:GiveTask(lane.InputBegan:Connect(function(input)
		if not self.gui.Enabled or not isPress(input) then
			return
		end
		self.heldInputs[input] = lane
		self:light(lane, true)
		self.onPress(lane.Name)
	end))
end

function TouchLanes.isHeld(self, lane: GuiButton): boolean
	for _, heldLane in self.heldInputs do
		if heldLane == lane then
			return true
		end
	end
	return false
end

function TouchLanes.light(self, lane: GuiButton, on: boolean)
	local flash = lane:FindFirstChild("Flash")
	local receptor = lane:FindFirstChild("Receptor")
	local pressScale = receptor and receptor:FindFirstChild("PressScale")
	local info = if on then PRESS_INFO else RELEASE_INFO
	if flash then
		TweenService:Create(flash, info, { BackgroundTransparency = if on then FLASH_TRANSPARENCY else 1 }):Play()
	end
	if pressScale then
		TweenService:Create(pressScale, info, { Scale = if on then PRESS_SCALE else 1 }):Play()
	end
end

function TouchLanes.fitToViewport(self)
	local viewport = workspace.CurrentCamera.ViewportSize
	local width = if viewport.Y > viewport.X then PORTRAIT_CLUSTER_WIDTH else LANDSCAPE_CLUSTER_WIDTH
	for _, cluster in self.clusters do
		cluster.Size = UDim2.new(width, -CLUSTER_EDGE_PX, cluster.Size.Y.Scale, cluster.Size.Y.Offset)
	end
end

function TouchLanes.topScale(self): number
	local cluster = self.clusters[1]
	return 1 - cluster.Size.Y.Scale
end

function TouchLanes.setEnabled(self, enabled: boolean)
	self.gui.Enabled = enabled
	if enabled then
		return
	end
	table.clear(self.heldInputs)
	for _, lane in self.lanes do
		self:light(lane, false)
	end
end

function TouchLanes.Destroy(self)
	self.Maid:DoCleaning()
end

return TouchLanes
