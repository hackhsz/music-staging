--!strict
-- BeatClock v3 — dt-accumulator song clock (RoBeats-kit architecture).
-- Sound.TimePosition updates in chunks, not per-frame, so we never chase it.
-- Accumulate Heartbeat dt from a playback-confirmed anchor; TimePosition is
-- consulted only as a stall guard: fresh readings that disagree by >150ms snap,
-- 50-150ms slew at 3ms/frame, smaller disagreement (chunk jitter) is ignored.
-- Playhead time is where the audio is (extrapolated past the last Heartbeat so input
-- stamps aren't a frame stale). Song time is playhead minus the calibrated offset: the
-- moment the player answers the music. onBeat fires on the playhead so sounds scheduled
-- from it share the music's output latency instead of stacking the offset on top.

local RunService = game:GetService("RunService")

local SNAP_ERR = 0.15
local SLEW_ERR = 0.05
local SLEW_PER_FRAME = 0.003

local BeatClock = {}
BeatClock.__index = BeatClock

function BeatClock.new()
	return setmetatable({
		bpm = 96,
		beatSec = 60 / 96,
		firstBeatSec = 0,
		accTime = 0,
		confirmed = false,
		lastTP = -1,
		startedAt = 0,
		running = false,
		sound = nil :: any, -- Sound or AudioPlayer (duck-typed: TimePosition/IsPlaying/PlaybackSpeed/Play/Stop)
		audioOffsetSec = 0,
		beatFns = {} :: { [number]: (number) -> () },
		nextFnId = 1,
		lastFiredBeat = -1,
		lastStepClock = 0,
		hbConn = nil :: RBXScriptConnection?,
	}, BeatClock)
end

function BeatClock.start(self, opts: { bpm: number, firstBeatSec: number?, sound: any })
	self.bpm = opts.bpm
	self.beatSec = 60 / opts.bpm
	self.firstBeatSec = opts.firstBeatSec or 0
	self.sound = opts.sound
	self.accTime = 0
	self.confirmed = opts.sound == nil
	self.lastTP = -1
	self.lastFiredBeat = -1
	self.running = true
	self.startedAt = os.clock()
	if opts.sound then
		opts.sound.TimePosition = 0
		opts.sound:Play()
	end

	self.hbConn = RunService.Heartbeat:Connect(function(dt)
		if not self.running then return end
		local snd = self.sound
		if snd then
			if not self.confirmed then
				local tp = snd.TimePosition
				if snd.IsPlaying and tp > 0 and tp ~= self.lastTP and self.lastTP >= 0 then
					self.accTime = tp
					self.confirmed = true
				elseif os.clock() - self.startedAt > 3 then
					warn("[DDS] BeatClock: audio never confirmed, silent fallback (RoBeats-style)")
					self.confirmed = true
				end
				self.lastTP = tp
				if not self.confirmed then return end
			end
			self.accTime += dt * snd.PlaybackSpeed
			if snd.IsPlaying then
				local tp = snd.TimePosition
				if tp ~= self.lastTP and tp > 0 then
					self.lastTP = tp
					local err = tp - self.accTime
					if math.abs(err) > SNAP_ERR then
						self.accTime = tp
					elseif math.abs(err) > SLEW_ERR then
						self.accTime += math.sign(err) * math.min(math.abs(err), SLEW_PER_FRAME)
					end
				end
			end
		else
			self.accTime += dt
		end
		self.lastStepClock = os.clock()
		local beatNow = math.floor(self:getPlayheadBeat())
		while self.lastFiredBeat < beatNow do
			self.lastFiredBeat += 1
			for _, fn in self.beatFns do
				task.spawn(fn, self.lastFiredBeat)
			end
		end
	end)
end

function BeatClock.stop(self)
	self.running = false
	if self.hbConn then self.hbConn:Disconnect(); self.hbConn = nil end
	if self.sound then self.sound:Stop() end
end

function BeatClock.getPlayheadTime(self): number
	if not self.running then return -math.huge end
	if not self.confirmed then return self.accTime end
	local speed = if self.sound then self.sound.PlaybackSpeed else 1
	return self.accTime + (os.clock() - self.lastStepClock) * speed
end

function BeatClock.getSongTime(self): number
	return self:getPlayheadTime() - self.audioOffsetSec
end

function BeatClock.getPlayheadBeat(self): number
	return (self:getPlayheadTime() - self.firstBeatSec) / self.beatSec
end

function BeatClock.getBeat(self): number
	return (self:getSongTime() - self.firstBeatSec) / self.beatSec
end

function BeatClock.beatToTime(self, beat: number): number
	return self.firstBeatSec + beat * self.beatSec
end

function BeatClock.onBeat(self, fn: (number) -> ())
	local id = self.nextFnId
	self.nextFnId += 1
	self.beatFns[id] = fn
	return { Disconnect = function() self.beatFns[id] = nil end }
end

return BeatClock
