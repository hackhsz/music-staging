--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PerformanceBudget = require(Shared:WaitForChild("PerformanceBudget"))
local RemoteContract = require(Shared:WaitForChild("RemoteContract"))
local Client = script.Parent.Parent
local StageLighting = require(Client:WaitForChild("World"):WaitForChild("StageLighting"))
local World = Client:WaitForChild("World")
local Arena = require(World:WaitForChild("Arena"))
local ArenaSkins = require(World:WaitForChild("ArenaSkins"))
local StageCue = require(World:WaitForChild("StageCue"))
local StreamedModel = require(World:WaitForChild("StreamedModel"))
local Remotes = require(Client:WaitForChild("Net"):WaitForChild("Remotes"))

local IDLE_BEAT_SECONDS = 60 / 72
local EXTERNAL_BEAT_TIMEOUT_SECONDS = 0.5

-- Brings the arena to life: the room breathes on a slow idle beat between songs
-- and follows the real beat during one, and the stage and crowd react to each
-- verdict. The arena itself is the Workspace.Arena folder, authored in Studio;
-- when a place has none it is built here from the same code.
-- A hub place lights the stage only while the player is on it (see HubController).
if workspace:GetAttribute("DanceHub") ~= true then
	StageLighting.apply()
end

local root = StreamedModel.find(Arena.FolderName)

if root == nil then
	root = Arena.build(workspace, PerformanceBudget.getDefaultQualityProfile())
	warn("[DanceDanceStep] Workspace.Arena was missing, so the arena was built at runtime")
end

local arena = Arena.bind(root)

if arena.partCount > PerformanceBudget.Targets.maxRuntimeStageParts then
	warn(("[DanceDanceStep] Arena part count %d exceeds budget %d"):format(arena.partCount, PerformanceBudget.Targets.maxRuntimeStageParts))
end

local skins = ArenaSkins.new(root, StageLighting.setLook)
local lastExternalBeatAt = 0

-- The pad cues the room: the song's energy, a burst on combo milestones, and
-- the holds, runs and claps the crowd plays along with.
StageCue.connect(function(cue: string, value: any)
	if cue == "stage" then
		StageLighting.setStage(value == true)
	elseif cue == "energy" and type(value) == "string" then
		arena.setEnergy(value)

		if value == "none" then
			arena.setHype(nil)
		end
	elseif cue == "milestone" and type(value) == "number" then
		arena.milestone(value)
	else
		arena.crowdCue(cue, value)
	end
end)

-- Main fires the beat phase while a song plays.
task.spawn(function()
	local beatSignal = ReplicatedStorage:WaitForChild("DanceDanceStepStageBeat", 10)

	if beatSignal ~= nil then
		(beatSignal :: BindableEvent).Event:Connect(function(phase: number, beatIndex: number)
			lastExternalBeatAt = os.clock()
			arena.onBeat(phase, beatIndex)
			skins.onBeat(phase, beatIndex)
		end)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	if now - lastExternalBeatAt < EXTERNAL_BEAT_TIMEOUT_SECONDS then
		return
	end

	local beats = now / IDLE_BEAT_SECONDS

	arena.onBeat(beats % 1, math.floor(beats))
	skins.onBeat(beats % 1, math.floor(beats))
end)

local remotes = ReplicatedStorage:WaitForChild(RemoteContract.FolderName, 10)

if remotes ~= nil then
	local leaderboardData = remotes:FindFirstChild(RemoteContract.Events.LeaderboardData.name)

	if leaderboardData ~= nil then
		Remotes.listen(leaderboardData :: RemoteEvent, arena.updateLeaderboard)
	end

	local hitResult = remotes:FindFirstChild(RemoteContract.Events.HitResult.name)

	if hitResult ~= nil then
		(hitResult :: RemoteEvent).OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end

			local fever = payload.fever
			local feverActive = type(fever) == "table" and fever.active == true
			local mood = if payload.grade == "Miss" then "miss" elseif feverActive then "fever" else "cheer"

			arena.setMood(mood, payload.combo or 0)

			if type(payload.hype) == "number" then
				arena.setHype(payload.hype)
			end
		end)
	end
end

print(("[DanceDanceStep] Arena ready (%d parts)"):format(arena.partCount))
