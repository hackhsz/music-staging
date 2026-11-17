local MonetizationPolicy = {}

MonetizationPolicy.Gacha = {
	enabled = false,
	cosmeticOnly = true,
	requiresOddsDisclosureReview = true,
	requiresRegionalComplianceReview = true,
	directPurchaseAlternativeRequired = true,
	noCompetitiveAdvantage = true,
	receiptValidationRequired = true,
	duplicateHandling = "convert_to_soft_currency",
	pityRule = {
		enabled = true,
		guaranteedRareWithinPulls = 10,
	},
	odds = {
		common = 0.7,
		rare = 0.24,
		epic = 0.055,
		legendary = 0.005,
	},
	allowedRewardKinds = {
		"cosmetic",
		"trail",
		"emote",
		"ending_pose",
	},
	blockedRewardKinds = {
		"score_multiplier",
		"competitive_skill",
		"leaderboard_advantage",
	},
}

function MonetizationPolicy.canEnableGacha(review: any): boolean
	if MonetizationPolicy.Gacha.enabled ~= true then
		return false
	end

	return type(review) == "table"
		and review.oddsDisclosureApproved == true
		and review.regionalComplianceApproved == true
		and review.receiptValidationImplemented == true
		and review.directPurchaseAlternativeAvailable == true
end

return MonetizationPolicy
