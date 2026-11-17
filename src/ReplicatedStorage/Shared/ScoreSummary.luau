local ScoreSummary = {}

local FULL_STEP_POINTS = 100
local STEP_POINTS = { perfects = FULL_STEP_POINTS, greats = 70, goods = 40, bads = 15 }
local RANK_ORDER = { C = 1, B = 2, A = 3, S = 4 }
local GRADE_CUTOFFS = {
	{ grade = "C", percent = 30 },
	{ grade = "B", percent = 70 },
	{ grade = "A", percent = 85 },
	{ grade = "S", percent = 95 },
}

ScoreSummary.NoGrade = "-"

local function pointsOf(counts: any): number
	local points = 0

	for key, value in STEP_POINTS do
		points += (counts[key] or 0) * value
	end

	return points
end

local function gradeFor(points: number, totalSteps: number): string
	local grade = ScoreSummary.NoGrade

	for _, cutoff in GRADE_CUTOFFS do
		if totalSteps > 0 and points >= cutoff.percent * totalSteps then
			grade = cutoff.grade
		end
	end

	return grade
end

-- Whether rank beats the best so far; any rank beats none.
function ScoreSummary.isBetterRank(rank: string?, best: string?): boolean
	return (RANK_ORDER[rank or ""] or 0) > (RANK_ORDER[best or ""] or 0)
end

function ScoreSummary.meetsGrade(rank: string?, required: string): boolean
	return (RANK_ORDER[rank or ""] or 0) >= RANK_ORDER[required]
end

-- The fewest steps turned into Perfects that reach the next grade, worst steps first.
function ScoreSummary.perfectsToNextGrade(summary: any): (number?, string?)
	local totalSteps = summary.totalSteps or 0
	local points = pointsOf(summary)

	for _, cutoff in GRADE_CUTOFFS do
		local missing = cutoff.percent * totalSteps - points

		if missing > 0 then
			local needed = 0

			for _, upgrade in {
				{ count = summary.misses or 0, gain = FULL_STEP_POINTS },
				{ count = summary.bads or 0, gain = FULL_STEP_POINTS - STEP_POINTS.bads },
				{ count = summary.goods or 0, gain = FULL_STEP_POINTS - STEP_POINTS.goods },
				{ count = summary.greats or 0, gain = FULL_STEP_POINTS - STEP_POINTS.greats },
			} do
				local taken = math.min(upgrade.count, math.ceil(missing / upgrade.gain))

				needed += taken
				missing -= taken * upgrade.gain

				if missing <= 0 then
					break
				end
			end

			return needed, cutoff.grade
		end
	end

	return nil, nil
end

function ScoreSummary.fromState(scoreState: any, totalSteps: number, performanceGoal: any?)
	local misses = scoreState.misses or 0
	local points = pointsOf(scoreState)
	local accuracy = if totalSteps > 0 then points / (FULL_STEP_POINTS * totalSteps) else 0
	local rank = gradeFor(points, totalSteps)
	local targetScore = performanceGoal and performanceGoal.targetScore or nil
	local goalPassed = targetScore ~= nil and (scoreState.score or 0) >= targetScore or nil

	return {
		score = scoreState.score or 0,
		maxCombo = scoreState.maxCombo or 0,
		perfects = scoreState.perfects or 0,
		greats = scoreState.greats or 0,
		goods = scoreState.goods or 0,
		bads = scoreState.bads or 0,
		misses = misses,
		totalSteps = totalSteps,
		accuracy = accuracy,
		rank = rank,
		feverActivations = scoreState.feverActivations or 0,
		feverBonusScore = scoreState.feverBonusScore or 0,
		itemsCollected = scoreState.itemsCollected or 0,
		targetScore = targetScore,
		goalPassed = goalPassed,
		goalLabel = performanceGoal and performanceGoal.label or nil,
	}
end

return ScoreSummary
