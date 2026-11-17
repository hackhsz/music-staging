local EarlySupporterProgram = {}

EarlySupporterProgram.Status = "defined_not_enabled"
EarlySupporterProgram.LaunchGate = "enable_after_private_alpha_feedback_window"

EarlySupporterProgram.Eligibility = {
	privateAlphaTester = true,
	groupMemberBeforePublicLaunch = true,
	firstWeekPlayer = true,
	feedbackContributor = true,
}

EarlySupporterProgram.Rewards = {
	{
		id = "founder-pixel-badge",
		displayName = "Founder Pixel Badge",
		type = "badge",
		competitiveAdvantage = false,
		grantMethod = "manual_or_eligibility_snapshot",
	},
	{
		id = "early-supporter-title",
		displayName = "Early Supporter",
		type = "title",
		competitiveAdvantage = false,
		grantMethod = "manual_or_eligibility_snapshot",
	},
	{
		id = "alpha-glow-trail",
		displayName = "Alpha Glow Trail",
		type = "cosmetic_trail",
		competitiveAdvantage = false,
		grantMethod = "manual_or_eligibility_snapshot",
	},
}

function EarlySupporterProgram.getReward(rewardId: string)
	for _, reward in EarlySupporterProgram.Rewards do
		if reward.id == rewardId then
			return reward
		end
	end

	return nil
end

return EarlySupporterProgram
