--!strict
local Timing = require(script.Parent.Timing)

export type AudioClock = {
	anchored: boolean,
	playhead: number,
	at: number,
	lastReading: number,
	drift: number,
	readings: number,
}

-- Where the music is, read from Sound.TimePosition. TimePosition moves in
-- chunks, so the playhead runs on the local clock from the first reading that
-- proves the audio is moving, and later readings only correct it.
local AudioClock = {}

function AudioClock.new(): AudioClock
	return {
		anchored = false,
		playhead = 0,
		at = 0,
		lastReading = -1,
		drift = 0,
		readings = 0,
	}
end

function AudioClock.reset(clock: AudioClock)
	clock.anchored = false
	clock.playhead = 0
	clock.at = 0
	clock.lastReading = -1
	clock.drift = 0
	clock.readings = 0
end

function AudioClock.observe(clock: AudioClock, now: number, reading: number, playing: boolean)
	if not playing then
		AudioClock.reset(clock)
		return
	end

	if not clock.anchored then
		if reading > 0 and clock.lastReading >= 0 and reading ~= clock.lastReading then
			clock.anchored = true
			clock.playhead = reading
			clock.at = now
		end

		clock.lastReading = reading
		return
	end

	local dt = math.max(now - clock.at, 0)
	clock.playhead += dt
	clock.at = now

	if reading ~= clock.lastReading and reading > 0 then
		clock.lastReading = reading

		local err = reading - clock.playhead

		if math.abs(err) > Timing.AudioSnapSeconds then
			clock.playhead = reading
			clock.drift = 0
			clock.readings = 0
			return
		end

		-- Each reading is up to a chunk off, so the playhead follows their running
		-- average rather than any one of them: the mean of the first few, then a
		-- slow average that still tracks drift.
		clock.readings += 1
		clock.drift += (err - clock.drift) * math.max(1 / clock.readings, Timing.AudioSmoothing)
	end

	local slew = Timing.AudioSlewPerSecond * dt
	local step = math.clamp(clock.drift, -slew, slew)
	clock.playhead += step
	clock.drift -= step
end

function AudioClock.read(clock: AudioClock, now: number): number?
	if not clock.anchored then
		return nil
	end

	return clock.playhead + (now - clock.at)
end

return AudioClock
