--!strict
local SoundService = game:GetService("SoundService")

-- The volume groups the Settings window turns up and down. Every sound the game
-- plays sits in one of them, so a group's Volume scales all of it.
local SoundGroups = {}

local NAMES = {
	music = "DanceDanceStepMusic",
	effects = "DanceDanceStepEffects",
	steps = "DanceDanceStepSteps",
	menus = "DanceDanceStepMenus",
	crowd = "DanceDanceStepCrowd",
}
-- The song leads the mix: every other group sits under it at full slider, so a
-- step's sounds lay over the track instead of covering it.
local MIX = {
	music = 1,
	effects = 0.5,
	steps = 0.45,
	menus = 0.8,
	-- The crowd is the room around the song, so it sits closer to it than the cues.
	crowd = 0.9,
}

function SoundGroups.get(key: string): SoundGroup
	local name = NAMES[key] or NAMES.effects
	local existing = SoundService:FindFirstChild(name)

	if existing ~= nil and existing:IsA("SoundGroup") then
		return existing
	end

	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = MIX[key] or 1
	group.Parent = SoundService

	return group
end

-- level is the player's slider, 0 to 1.
function SoundGroups.setLevel(key: string, level: number)
	SoundGroups.get(key).Volume = level * (MIX[key] or 1)
end

return SoundGroups
