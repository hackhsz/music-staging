local WARMUP_TAPS = 4
local TARGET_SAMPLES = 16
local MIN_SAMPLES = 8
local MAX_BEATS = 56
local CONSISTENT_SPREAD_MS = 35

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DDS = script.Parent
local Config = require(DDS.Config)
local BeatClock = require(DDS.BeatClock)
local SongCatalog = require(DDS.SongCatalog)
local AudioOffset = require(DDS.AudioOffset)
local Maid = require(ReplicatedStorage.Shared.Util.Maid)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local function medianOf(sorted: { number }): number
	local count = #sorted
	if count % 2 == 1 then
		return sorted[(count + 1) / 2]
	end
	return (sorted[count / 2] + sorted[count / 2 + 1]) / 2
end

local Calibration = {}
Calibration.__index = Calibration

function Calibration.new()
	local self = setmetatable({}, Calibration)
	self.maid = Maid.new()
	self.samples = {}
	self.tapCount = 0
	self.done = false
	self.Progress = self.maid:GiveTask(Signal.new())
	self.Finished = self.maid:GiveTask(Signal.new())
	return self
end

function Calibration:Start()
	local song = SongCatalog.byId(Config.CALIBRATION_SONG_ID) or SongCatalog.songs[1]
	self.chart = require(song.charts).normal
	self.expectedMs = AudioOffset.get() + (self.chart.audioOffsetMs or 0)

	local rig = self.maid:GiveTask(DDS.Templates.MusicRig:Clone())
	rig.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
	rig.Music.AssetId = song.sound.SoundId

	self.clock = BeatClock.new()
	self.maid:GiveTask(function()
		self.clock:stop()
	end)
	self.clock:start({ bpm = self.chart.bpm, firstBeatSec = self.chart.firstBeatSec or 0, sound = rig.Music })

	self.maid:GiveTask(RunService.Heartbeat:Connect(function()
		if self.clock:getPlayheadBeat() > MAX_BEATS then
			self:Finish()
		end
	end))
end

function Calibration:RegisterTap()
	if self.done or not self.clock or not self.clock.confirmed then
		return
	end
	local landing = self.clock:getPlayheadTime() + Config.JUDGE_LAND_MS / 1000
	local centered = landing - self.expectedMs / 1000
	local beat = math.floor((centered - self.clock.firstBeatSec) / self.clock.beatSec + 0.5)
	if beat < 0 then
		return
	end
	local deltaMs = (landing - self.clock:beatToTime(beat)) * 1000
	self.tapCount += 1
	if self.tapCount <= WARMUP_TAPS then
		self.Progress:Fire(0, TARGET_SAMPLES, nil)
		return
	end
	table.insert(self.samples, deltaMs)
	self.Progress:Fire(#self.samples, TARGET_SAMPLES, deltaMs - self.expectedMs)
	if #self.samples >= TARGET_SAMPLES then
		self:Finish()
	end
end

function Calibration:Finish()
	if self.done then
		return
	end
	self.done = true
	self.clock:stop()
	if #self.samples < MIN_SAMPLES then
		self.Finished:Fire(nil, "Not enough taps")
		return
	end
	local sorted = table.clone(self.samples)
	table.sort(sorted)
	local median = medianOf(sorted)
	local deviations = {}
	for _, sample in sorted do
		table.insert(deviations, math.abs(sample - median))
	end
	table.sort(deviations)
	local spreadMs = medianOf(deviations)
	self.Finished:Fire({
		offsetMs = median - (self.chart.audioOffsetMs or 0),
		spreadMs = spreadMs,
		samples = #sorted,
		consistent = spreadMs <= CONSISTENT_SPREAD_MS,
	}, nil)
end

function Calibration:Destroy()
	self.done = true
	self.maid:DoCleaning()
end

return Calibration
