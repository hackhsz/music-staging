--!strict
local TIERS = { "PERFECT", "GREAT", "GOOD", "MISS" }

local ScoreFormula = {}
ScoreFormula.TIERS = TIERS

function ScoreFormula.lifeDelta(tier: string, config: any): number
	if tier == "MISS" then
		return config.LIFE_MISS
	end
	if tier == "GOOD" then
		return config.LIFE_GOOD
	end
	return config.LIFE_HIT
end

function ScoreFormula.totalJudgements(counts: { [string]: number }): number
	local total = 0
	for _, tier in TIERS do
		total += counts[tier] or 0
	end
	return total
end

function ScoreFormula.noteCount(chart): number
	local count = 0
	for _, event in chart.events do
		if event.kind ~= "ITEM" then
			count += 1
		end
	end
	return count
end

function ScoreFormula.earnedWeight(counts: { [string]: number }, config: any): number
	local earned = 0
	for _, tier in TIERS do
		earned += (counts[tier] or 0) * config.JUDGE_WEIGHT[tier]
	end
	return earned
end

function ScoreFormula.accuracy(counts: { [string]: number }, config: any): number
	local total = ScoreFormula.totalJudgements(counts)
	if total == 0 then
		return 0
	end
	return ScoreFormula.earnedWeight(counts, config) / total * 100
end

function ScoreFormula.comboBonus(comboBreaks: number, config: any): number
	return math.max(0, config.SCORE_COMBO_MAX - config.SCORE_COMBO_BREAK * comboBreaks)
end

function ScoreFormula.rawScore(counts: { [string]: number }, comboBreaks: number, config: any): number
	if ScoreFormula.totalJudgements(counts) == 0 then
		return 0
	end
	return math.floor(config.SCORE_ACCURACY_MAX * ScoreFormula.accuracy(counts, config) / 100 + ScoreFormula.comboBonus(comboBreaks, config))
end

function ScoreFormula.finalScore(rawScore: number, scoreMultiplier: number): number
	return math.floor(rawScore * scoreMultiplier)
end

function ScoreFormula.liveScore(earnedWeight: number, noteCount: number, scoreMultiplier: number, config: any): number
	if noteCount <= 0 then
		return 0
	end
	return math.floor(config.SCORE_ACCURACY_MAX * earnedWeight / noteCount * scoreMultiplier)
end

function ScoreFormula.rank(rawScore: number, config: any): string
	for _, entry in config.RANKS do
		if rawScore >= entry.minRaw then
			return entry.rank
		end
	end
	return config.RANKS[#config.RANKS].rank
end

function ScoreFormula.summarize(counts: { [string]: number }, comboBreaks: number, scoreMultiplier: number, cleared: boolean, config: any)
	local raw = ScoreFormula.rawScore(counts, comboBreaks, config)
	return {
		accuracy = ScoreFormula.accuracy(counts, config),
		raw = raw,
		final = ScoreFormula.finalScore(raw, scoreMultiplier),
		rank = if cleared then ScoreFormula.rank(raw, config) else nil,
		total = ScoreFormula.totalJudgements(counts),
	}
end

return ScoreFormula
