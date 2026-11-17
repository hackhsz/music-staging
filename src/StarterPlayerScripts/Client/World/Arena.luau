--!strict
local ArenaBackdrop = require(script.Parent.ArenaBackdrop)
local ArenaCrowd = require(script.Parent.ArenaCrowd)
local ArenaDisco = require(script.Parent.ArenaDisco)
local ArenaFloor = require(script.Parent.ArenaFloor)
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaLights = require(script.Parent.ArenaLights)
local ArenaScreens = require(script.Parent.ArenaScreens)
local ArenaSkyline = require(script.Parent.ArenaSkyline)
local ArenaStage = require(script.Parent.ArenaStage)
local ArenaStreet = require(script.Parent.ArenaStreet)

local Arena = {}

Arena.FolderName = "Arena"

export type Arena = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setMood: (mood: string, combo: number) -> (),
	setHype: (hype: number?) -> (),
	crowdCue: (cue: string, value: any) -> (),
	setEnergy: (energy: string) -> (),
	milestone: (combo: number) -> (),
	updateLeaderboard: (payload: any) -> (),
	partCount: number,
}

-- Authoring: lays the whole arena out as ordinary parts under parent, in a
-- folder per area. Run it once in Edit mode and the arena becomes part of the
-- place, where it can be moved and recoloured by hand. The game also runs it
-- when a place has no arena, so a fresh clone still plays.
function Arena.build(parent: Instance, quality: ArenaKit.Quality): Folder
	local root = Instance.new("Folder")
	root.Name = Arena.FolderName
	root.Parent = parent

	local kit = ArenaKit.new(root, quality)

	ArenaFloor.build(kit)
	ArenaLights.build(kit)
	ArenaBackdrop.build(kit)
	ArenaStage.build(kit)
	ArenaDisco.build(kit)
	ArenaSkyline.build(kit)
	ArenaCrowd.build(kit)
	ArenaScreens.build(kit)

	return root
end

-- Runtime: finds the arena's parts by name and returns what reacts to the beat
-- and to each verdict. A part that has been deleted by hand is simply skipped.
function Arena.bind(root: Instance): Arena
	local lights = ArenaLights.bind(root)
	local backdrop = ArenaBackdrop.bind(root)
	local stage = ArenaStage.bind(root)
	local disco = ArenaDisco.bind(root)
	local skyline = ArenaSkyline.bind(root)
	local crowd = ArenaCrowd.bind(root)
	local screens = ArenaScreens.bind(root)
	local streetStage = ArenaStreet.bind(root:FindFirstChild(ArenaStreet.FolderName))
	local partCount = 0

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end

	local function setMood(mood: string, combo: number)
		lights.setMood(mood, combo)
		stage.setMood(mood, combo)
		crowd.setMood(mood, combo)
		streetStage.setMood(mood, combo)
		disco.setMood(mood, combo)
	end

	setMood("idle", 0)

	return {
		onBeat = function(phase, beatIndex)
			lights.onBeat(phase, beatIndex)
			backdrop.onBeat(phase, beatIndex)
			crowd.onBeat(phase, beatIndex)
			streetStage.onBeat(phase, beatIndex)
			stage.onBeat(phase, beatIndex)
			disco.onBeat(phase, beatIndex)
			skyline.onBeat(phase, beatIndex)
		end,
		setMood = setMood,
		setHype = crowd.setHype,
		crowdCue = crowd.cue,
		setEnergy = function(energy)
			lights.setEnergy(energy)
			backdrop.setEnergy(energy)
			crowd.setEnergy(energy)
			streetStage.setEnergy(energy)
			disco.setEnergy(energy)
		end,
		milestone = function(_)
			lights.milestone()
			crowd.milestone()
			streetStage.milestone()
			disco.milestone()
		end,
		updateLeaderboard = screens.updateLeaderboard,
		partCount = partCount,
	}
end

return Arena
