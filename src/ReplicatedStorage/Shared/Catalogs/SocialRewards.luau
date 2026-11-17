local SocialRewards = {}

-- The community group. While it is nil the group reward is a thank-you anyone can
-- claim; once set, the server checks membership before it pays, and members get
-- the group perks below.
SocialRewards.GroupId = nil :: number?
SocialRewards.GroupCosmeticId = "group-star-aura-001"
SocialRewards.GroupDailyGiftMultiplier = 2
SocialRewards.GroupPerks = { "+150 BEAT COINS", "GROUP STAR AURA", "2X DAILY GIFT" }

SocialRewards.Actions = {
	Like = {
		id = "like",
		displayName = "Like the Experience",
		rewardSoftCurrency = 50,
		requiresManualClaim = true,
		promptMoment = "after_first_song_clear",
		policyNote = "Do not require proof if Roblox APIs cannot verify; present as a thank-you CTA.",
	},
	Favorite = {
		id = "favorite",
		displayName = "Favorite for Later",
		rewardSoftCurrency = 50,
		requiresManualClaim = true,
		promptMoment = "after_rank_b_or_better",
		policyNote = "Never block core progression behind favorite actions.",
	},
	Community = {
		id = "community",
		displayName = "Join the Group",
		rewardSoftCurrency = 150,
		requiresManualClaim = true,
		promptMoment = "lobby_leaderboard_wall",
		policyNote = "Community/group prompt must stay optional and non-spammy.",
	},
}

SocialRewards.Policy = "Prompt politely; never block core gameplay behind social actions."
SocialRewards.LaunchPrompt = "LIKE, FAVORITE, AND JOIN THE COMMUNITY FOR OPTIONAL BONUS COINS"

function SocialRewards.getAction(id: string)
	for _, action in SocialRewards.Actions do
		if action.id == id or ("social:" .. action.id) == id then
			return action
		end
	end

	return nil
end

return SocialRewards
