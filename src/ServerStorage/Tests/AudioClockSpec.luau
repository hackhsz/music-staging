--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioClock = require(Shared:WaitForChild("AudioClock"))
local Timing = require(Shared:WaitForChild("Timing"))

local function near(actual: number?, wanted: number, what: string)
	assert(actual ~= nil, what .. ": no playhead")
	assert(math.abs(actual - wanted) < 1e-6, string.format("%s: expected %.4f, got %.4f", what, wanted, actual))
end

return {
	["no playhead until the music is seen moving"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 10, 0.05, true)
		assert(AudioClock.read(clock, 10) == nil, "anchored on the first reading")
		AudioClock.observe(clock, 10.02, 0.05, true)
		assert(AudioClock.read(clock, 10.02) == nil, "anchored on a reading that did not move")
		AudioClock.observe(clock, 10.04, 0.07, true)
		near(AudioClock.read(clock, 10.04), 0.07, "anchor")
		near(AudioClock.read(clock, 10.1), 0.13, "extrapolated past the last reading")
	end,

	["one jittery reading among steady ones barely moves the playhead"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02, true)

		for frame = 2, 60 do
			AudioClock.observe(clock, frame * 0.016, 0.004 + frame * 0.016, true)
		end

		AudioClock.observe(clock, 0.976, 0.98 + 0.015, true)
		local moved = (AudioClock.read(clock, 0.976) :: number) - 0.98
		assert(moved > 0 and moved < 0.001, string.format("one reading moved the playhead %.4f", moved))
	end,

	["a steady offset in the readings is followed closely"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02, true)

		for frame = 2, 120 do
			AudioClock.observe(clock, frame * 0.016, 0.004 + frame * 0.016 + 0.012, true)
		end

		local playhead = AudioClock.read(clock, 120 * 0.016) :: number
		local reading = 0.004 + 120 * 0.016 + 0.012
		assert(math.abs(playhead - reading) < 0.001, string.format("playhead %.4f behind %.4f", playhead, reading))
	end,

	["readings that alternate around the music average out"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02 + 0.015, true)

		for frame = 2, 240 do
			local wobble = if frame % 2 == 0 then -0.015 else 0.015
			AudioClock.observe(clock, frame * 0.016, 0.004 + frame * 0.016 + wobble, true)
		end

		local playhead = AudioClock.read(clock, 240 * 0.016) :: number
		local music = 0.004 + 240 * 0.016
		assert(math.abs(playhead - music) < 0.002, string.format("playhead %.4f, music %.4f", playhead, music))
	end,

	["a reading past the snap distance snaps"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02, true)
		local jumped = 1.02 + Timing.AudioSnapSeconds + 0.1
		AudioClock.observe(clock, 1.016, jumped, true)
		near(AudioClock.read(clock, 1.016), jumped, "snap")
	end,

	["an error short of the snap slews by at most the slew rate"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02, true)
		local err = Timing.AudioSnapSeconds / 2
		AudioClock.observe(clock, 0.032, 0.036 + err, true)
		near(AudioClock.read(clock, 0.032), 0.036 + Timing.AudioSlewPerSecond * 0.016, "slew")
	end,

	["stopping the music drops the playhead"] = function()
		local clock = AudioClock.new()
		AudioClock.observe(clock, 0, 0.01, true)
		AudioClock.observe(clock, 0.016, 0.02, true)
		AudioClock.observe(clock, 0.032, 0.02, false)
		assert(AudioClock.read(clock, 0.032) == nil, "paused music still has a playhead")
	end,
}
