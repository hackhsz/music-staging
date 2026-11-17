--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputStrategy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputStrategy"))

local DeviceMode = {}

function DeviceMode.detect(): any
	return InputStrategy.getModeForCapabilities(
		UserInputService.TouchEnabled,
		UserInputService.KeyboardEnabled,
		UserInputService.GamepadEnabled
	)
end

return DeviceMode
