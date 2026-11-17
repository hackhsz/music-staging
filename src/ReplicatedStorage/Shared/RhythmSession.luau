local Timing = require(script.Parent.Timing)

local RhythmSession = {}
RhythmSession.__index = RhythmSession

export type RhythmSession = typeof(setmetatable({} :: {
	map: any,
	startTime: number,
	anchorStart: number,
	sharedStart: number?,
	nextStepIndex: number,
}, RhythmSession))

-- startTime is song time zero on this machine's os.clock. sharedStart, when
-- known, is the same moment on the shared GetServerTimeNow clock: the server's
-- own start, which reports are mapped onto.
function RhythmSession.new(map: any, startTime: number, sharedStart: number?): RhythmSession
	return setmetatable({
		map = map,
		startTime = startTime,
		anchorStart = startTime,
		sharedStart = sharedStart,
		nextStepIndex = 1,
	}, RhythmSession)
end

function RhythmSession.localStartFromShared(sharedStart: number, localNow: number, sharedNow: number): number
	return sharedStart - sharedNow + localNow
end

function RhythmSession:getElapsed(now: number): number
	return now - self.startTime
end

-- Moves the whole run later, as a pause does, on both clocks.
function RhythmSession:shift(seconds: number)
	self.startTime += seconds
	self.anchorStart += seconds

	if self.sharedStart ~= nil then
		self.sharedStart += seconds
	end
end

-- Puts song time on the music's playhead, within the follow limits of the
-- server's start. Returns how far the music sits outside those limits, positive
-- when it is ahead; anything but zero means the music should be seeked.
function RhythmSession:followPlayhead(now: number, playhead: number): number
	-- Without the server's start the judge cannot follow the music, so neither may the clock.
	if self.sharedStart == nil then
		return 0
	end

	local wanted = now - playhead
	local earliest = self.anchorStart - Timing.AudioLeadLimitSeconds
	local latest = self.anchorStart + Timing.AudioFollowLimitSeconds

	self.startTime = math.clamp(wanted, earliest, latest)

	return self.startTime - wanted
end

-- A local os.clock time as the server should judge it: the same song time on
-- the server's start, so a clock following the music judges what was heard.
function RhythmSession:toShared(localTime: number, sharedMinusLocal: number): number
	if self.sharedStart == nil then
		return localTime + sharedMinusLocal
	end

	return self.sharedStart + self:getElapsed(localTime)
end

function RhythmSession:getCurrentStep()
	return self.map.steps[self.nextStepIndex]
end

function RhythmSession:getStep(index: number)
	return self.map.steps[index]
end

function RhythmSession:getStepTargetTime(step: any): number
	return Timing.beatToSeconds(step.beat, self.map.bpm)
end

function RhythmSession:getCurrentStepTargetTime(): number?
	local step = self:getCurrentStep()

	if step == nil then
		return nil
	end

	return self:getStepTargetTime(step)
end

function RhythmSession:advance()
	if not self:isFinished() then
		self.nextStepIndex += 1
	end
end

function RhythmSession:isFinished(): boolean
	return self.nextStepIndex > #self.map.steps
end

return RhythmSession
