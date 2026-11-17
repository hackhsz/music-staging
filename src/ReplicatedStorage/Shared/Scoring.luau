local Scoring = {}

Scoring.Points = {
	Perfect = 1000,
	Great = 700,
	Good = 500,
	Bad = 150,
	Miss = 0,
}

Scoring.ComboBonusPerHit = 10
Scoring.ItemBonus = 500
Scoring.ComboMilestones = { 10, 25, 50 }
Scoring.ComboMilestoneEvery = 100
Scoring.StepTypeBonus = {
	bonus = 300,
	hold = 150,
	slide = 150,
	danger = 200,
	shape = 200,
	pose = 200,
	clap = 100,
	rush = 50,
}

Scoring.ComboMultipliers = {
	{ combo = 100, multiplier = 1.5 },
	{ combo = 50, multiplier = 1.25 },
	{ combo = 25, multiplier = 1.1 },
}

-- From this combo on, each milestone charges a shield that absorbs one Miss.
Scoring.ShieldCombo = 50

export type ScoreState = {
	score: number,
	combo: number,
	maxCombo: number,
	perfects: number,
	greats: number,
	goods: number,
	bads: number,
	misses: number,
	feverBonusScore: number,
	itemsCollected: number,
	itemBonusScore: number,
	shieldReady: boolean,
}

function Scoring.createState(): ScoreState
	return {
		score = 0,
		combo = 0,
		maxCombo = 0,
		perfects = 0,
		greats = 0,
		goods = 0,
		bads = 0,
		misses = 0,
		feverBonusScore = 0,
		itemsCollected = 0,
		itemBonusScore = 0,
		shieldReady = false,
	}
end

-- An item adds score and nothing else: combo and the grade counts stay as they were.
function Scoring.applyItem(state: ScoreState): number
	state.score += Scoring.ItemBonus
	state.itemsCollected += 1
	state.itemBonusScore += Scoring.ItemBonus

	return Scoring.ItemBonus
end

function Scoring.isComboMilestone(combo: number): boolean
	if combo <= 0 then
		return false
	end

	if combo % Scoring.ComboMilestoneEvery == 0 then
		return true
	end

	return table.find(Scoring.ComboMilestones, combo) ~= nil
end

function Scoring.multiplierFor(combo: number): number
	for _, tier in Scoring.ComboMultipliers do
		if combo >= tier.combo then
			return tier.multiplier
		end
	end

	return 1
end

-- The second return is true when a charged shield absorbed this Miss: it still
-- counts as a Miss, but the combo survives.
function Scoring.applyGrade(state: ScoreState, grade: string, step: any?): (ScoreState, boolean)
	if grade == "Miss" then
		state.misses += 1

		if state.shieldReady and state.combo >= Scoring.ShieldCombo then
			state.shieldReady = false
			return state, true
		end

		state.combo = 0
		state.shieldReady = false
		return state, false
	end

	state.combo += 1
	state.maxCombo = math.max(state.maxCombo, state.combo)

	if state.combo >= Scoring.ShieldCombo and Scoring.isComboMilestone(state.combo) then
		state.shieldReady = true
	end

	local points = (Scoring.Points[grade] or 0) + (state.combo * Scoring.ComboBonusPerHit)

	if step ~= nil and step.type ~= nil then
		points += Scoring.StepTypeBonus[step.type] or 0
	end

	state.score += math.floor(points * Scoring.multiplierFor(state.combo))

	if grade == "Perfect" then
		state.perfects += 1
	elseif grade == "Great" then
		state.greats += 1
	elseif grade == "Good" then
		state.goods += 1
	elseif grade == "Bad" then
		state.bads += 1
	end

	return state, false
end

return Scoring
