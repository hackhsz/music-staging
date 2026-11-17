--!strict
-- Pure judging tier logic. landDelta = beatTime - landedAt, seconds (positive = early, negative = late).
-- Position gate and the late-grace cutoff are the caller's job; this only tiers a positioned player.

local JudgeLogic = {}

function JudgeLogic.tier(landDelta: number, config: { PERFECT_LAND_MS: number, GREAT_LAND_MS: number }): string
	local offset = math.abs(landDelta)
	if offset <= config.PERFECT_LAND_MS / 1000 then
		return "PERFECT"
	end
	if offset <= config.GREAT_LAND_MS / 1000 then
		return "GREAT"
	end
	return "GOOD"
end

-- When a step counts as started (os.clock seconds). Inputs that are recognised after the
-- player committed (a tap on release, a swipe once it travels) pass their touch-down time
-- as pressedAt. Never earlier than the previous step's end or maxBackdateSec ago, never later than now.
function JudgeLogic.stepStart(now: number, pressedAt: number?, earliest: number, maxBackdateSec: number): number
	local start = math.min(pressedAt or now, now)
	return math.max(start, earliest, now - maxBackdateSec)
end

return JudgeLogic
