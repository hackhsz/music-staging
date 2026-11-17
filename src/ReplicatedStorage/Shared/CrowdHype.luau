local CrowdHype = {}

CrowdHype.Max = 100
CrowdHype.PerfectGain = 8
CrowdHype.GreatGain = 6
CrowdHype.GoodGain = 3
CrowdHype.BadGain = 1
CrowdHype.MissLoss = 12
CrowdHype.ItemGain = 10
CrowdHype.MilestoneGain = 15
CrowdHype.ScoreBonusThreshold = 60
CrowdHype.ScoreBonusMultiplier = 1.1

function CrowdHype.applyGrade(current: number, grade: string): number
	if grade == "Perfect" then
		return math.clamp(current + CrowdHype.PerfectGain, 0, CrowdHype.Max)
	elseif grade == "Great" then
		return math.clamp(current + CrowdHype.GreatGain, 0, CrowdHype.Max)
	elseif grade == "Good" then
		return math.clamp(current + CrowdHype.GoodGain, 0, CrowdHype.Max)
	elseif grade == "Bad" then
		return math.clamp(current + CrowdHype.BadGain, 0, CrowdHype.Max)
	end

	return math.clamp(current - CrowdHype.MissLoss, 0, CrowdHype.Max)
end

function CrowdHype.boost(current: number, amount: number): number
	return math.clamp(current + amount, 0, CrowdHype.Max)
end

function CrowdHype.hasScoreBonus(current: number): boolean
	return current >= CrowdHype.ScoreBonusThreshold
end

return CrowdHype

