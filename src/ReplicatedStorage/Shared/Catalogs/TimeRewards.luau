--!strict
-- Play-time gifts: each one unlocks after that many minutes in one visit and is
-- claimed once per visit. The server times the visit; leaving starts them over.

-- A tier with a cosmeticId gives that item; coins are paid instead when it is owned.
export type Tier = { id: string, minutes: number, coins: number, glyph: string, icon: string?, cosmeticId: string? }

local TimeRewards = {}

TimeRewards.RewardPrefix = "time:"

TimeRewards.Tiers = {
	{ id = "t5", icon = "Icon_Coin", minutes = 5, coins = 25, glyph = "💵" },
	{ id = "t10", icon = "Icon_CoinStack", minutes = 10, coins = 40, glyph = "💸" },
	{ id = "t15", icon = "Icon_Wand", minutes = 15, coins = 60, glyph = "✨", cosmeticId = "mint-wand-001" },
	{ id = "t20", icon = "Icon_CoinStack", minutes = 20, coins = 75, glyph = "💰" },
	{ id = "t30", icon = "Icon_Trail", minutes = 30, coins = 125, glyph = "🎶", cosmeticId = "trail-equalizer-001" },
	{ id = "t45", icon = "Icon_Gift", minutes = 45, coins = 150, glyph = "🎁" },
	{ id = "t60", icon = "Icon_Wand", minutes = 60, coins = 200, glyph = "🌅", cosmeticId = "sunset-wand-001" },
	{ id = "t90", icon = "Icon_Wand", minutes = 90, coins = 400, glyph = "🌙", cosmeticId = "midnight-wand-001" },
} :: { Tier }

-- The tier a ClaimReward id names ("time:t5"), or nil.
function TimeRewards.fromRewardId(rewardId: string): Tier?
	local prefix = TimeRewards.RewardPrefix

	if string.sub(rewardId, 1, #prefix) ~= prefix then
		return nil
	end

	local id = string.sub(rewardId, #prefix + 1)

	for _, tier in TimeRewards.Tiers do
		if tier.id == id then
			return tier
		end
	end

	return nil
end

function TimeRewards.secondsLeft(tier: Tier, playedSeconds: number): number
	return math.max(0, tier.minutes * 60 - playedSeconds)
end

return TimeRewards
