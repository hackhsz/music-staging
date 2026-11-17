local Players = game:GetService("Players")

local DDS = script.Parent
local Config = require(DDS.Config)

local saveRemote = DDS:WaitForChild("Remotes"):WaitForChild("SaveAudioOffset")
local player = Players.LocalPlayer

local AudioOffset = {}
AudioOffset.Changed = player:GetAttributeChangedSignal(Config.AUDIO_OFFSET_ATTRIBUTE)

function AudioOffset.clamp(ms: number): number
	return math.clamp(math.round(ms), Config.AUDIO_OFFSET_MIN_MS, Config.AUDIO_OFFSET_MAX_MS)
end

function AudioOffset.isCalibrated(): boolean
	return typeof(player:GetAttribute(Config.AUDIO_OFFSET_ATTRIBUTE)) == "number"
end

function AudioOffset.get(): number
	local ms = player:GetAttribute(Config.AUDIO_OFFSET_ATTRIBUTE)
	if typeof(ms) ~= "number" then
		return Config.AUDIO_OFFSET_MS_DEFAULT
	end
	return ms
end

function AudioOffset.set(ms: number): number
	local clamped = AudioOffset.clamp(ms)
	player:SetAttribute(Config.AUDIO_OFFSET_ATTRIBUTE, clamped)
	saveRemote:FireServer(clamped)
	return clamped
end

function AudioOffset.reset(): number
	return AudioOffset.set(Config.AUDIO_OFFSET_MS_DEFAULT)
end

return AudioOffset
