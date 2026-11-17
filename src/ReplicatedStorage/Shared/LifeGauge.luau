--!strict
-- Life / health gauge (issue 040). Gives a run a stake: it drains on Miss/Bad and
-- recovers on good hits; reaching zero fails the run early. Server-authoritative -
-- the client only renders the value the server computes.

local LifeGauge = {}

LifeGauge.Max = 100
LifeGauge.Start = 100

-- Per-difficulty tuning, in life points per judgement. Easy never fails;
-- normal takes a long streak of misses from full, so a bad patch is survivable.
LifeGauge.Profiles = {
	easy = { missDrain = 4, badDrain = 2, goodGain = 5, greatGain = 6, perfectGain = 8, canFail = false },
	normal = { missDrain = 6, badDrain = 3, goodGain = 4, greatGain = 5, perfectGain = 6, canFail = true },
	hard = { missDrain = 10, badDrain = 5, goodGain = 3, greatGain = 4, perfectGain = 4, canFail = true },
	expert = { missDrain = 14, badDrain = 7, goodGain = 2, greatGain = 3, perfectGain = 3, canFail = true },
}

LifeGauge.DefaultProfile = "normal"

local ALIASES = {
	beginner = "easy",
	onboarding = "easy",
}

function LifeGauge.getProfile(difficulty: string?)
	local key = difficulty ~= nil and (ALIASES[difficulty] or difficulty) or LifeGauge.DefaultProfile
	return LifeGauge.Profiles[key] or LifeGauge.Profiles[LifeGauge.DefaultProfile]
end

function LifeGauge.applyGrade(current: number, grade: string, difficulty: string?): number
	local profile = LifeGauge.getProfile(difficulty)
	local delta

	if grade == "Perfect" then
		delta = profile.perfectGain
	elseif grade == "Great" then
		delta = profile.greatGain
	elseif grade == "Good" then
		delta = profile.goodGain
	elseif grade == "Bad" then
		delta = -profile.badDrain
	else
		-- Miss (or any unknown grade) drains the most.
		delta = -profile.missDrain
	end

	return math.clamp(current + delta, 0, LifeGauge.Max)
end

function LifeGauge.isFailed(current: number, difficulty: string?): boolean
	return LifeGauge.getProfile(difficulty).canFail and current <= 0
end

return LifeGauge
