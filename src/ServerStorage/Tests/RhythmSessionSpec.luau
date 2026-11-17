--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RhythmSession = require(Shared:WaitForChild("RhythmSession"))
local Timing = require(Shared:WaitForChild("Timing"))

local MAP = { bpm = 120, steps = { { beat = 1, x = 1, y = 1 } } }

local function near(actual: number, wanted: number, what: string)
	assert(math.abs(actual - wanted) < 1e-6, string.format("%s: expected %.4f, got %.4f", what, wanted, actual))
end

return {
	["the local start lands on the server's start, not on the message"] = function()
		local sharedStart = 1003
		local localStart = RhythmSession.localStartFromShared(sharedStart, 50.08, 1000.08)
		near(localStart, 53, "a message 80 ms in flight must not start the run 80 ms late")
	end,

	["the clock follows music that starts late"] = function()
		local session = RhythmSession.new(MAP, 10, 1010)
		local residual = session:followPlayhead(11, 0.93)
		near(residual, 0, "a 70 ms late start is followed, not seeked")
		near(session:getElapsed(11), 0.93, "song time is the playhead")
	end,

	["reports carry song time onto the server's start"] = function()
		local session = RhythmSession.new(MAP, 10, 1010)
		session:followPlayhead(11, 0.93)
		near(session:toShared(11.5, 990), 1010 + 1.43, "report on the shared clock")
	end,

	["music too far off is seeked rather than followed"] = function()
		local session = RhythmSession.new(MAP, 10, 1010)
		local late = session:followPlayhead(11, 1 - Timing.AudioFollowLimitSeconds - 0.1)
		near(late, -0.1, "music behind the follow limit")

		local early = session:followPlayhead(11, 1 + Timing.AudioLeadLimitSeconds + 0.05)
		near(early, 0.05, "music ahead of the lead limit")
	end,

	["without a shared start the clock stays put"] = function()
		local session = RhythmSession.new(MAP, 10)
		near(session:followPlayhead(11, 0.9), 0, "residual")
		near(session:getElapsed(11), 1, "clock moved")
		near(session:toShared(11, 990), 1001, "falls back to the plain clock shift")
	end,

	["a pause shifts both clocks"] = function()
		local session = RhythmSession.new(MAP, 10, 1010)
		session:shift(2)
		near(session:getElapsed(13), 1, "local clock")
		near(session:toShared(13, 990), 1013, "shared clock")
		near(session:followPlayhead(13, 0.95), 0, "follow limits move with the pause")
	end,
}
