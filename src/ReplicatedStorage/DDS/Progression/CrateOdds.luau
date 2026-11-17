--!strict
local TIER_ORDER = { "Rare", "Uncommon", "Common" }
local S_RARE_MULTIPLIER = 2

local CrateOdds = {
	TIER_ORDER = TIER_ORDER,
	ByRank = {
		C = { Common = 80, Uncommon = 17, Rare = 3 },
		B = { Common = 72, Uncommon = 23, Rare = 5 },
		A = { Common = 64, Uncommon = 28, Rare = 8 },
	},
	Rewards = {
		Common = { Coins = 25 },
		Uncommon = { Coins = 75 },
		Rare = { ShopItem = true, FallbackCoins = 200 },
	},
}

local rankA = CrateOdds.ByRank.A
CrateOdds.ByRank.S = {
	Common = rankA.Common - rankA.Rare * (S_RARE_MULTIPLIER - 1),
	Uncommon = rankA.Uncommon,
	Rare = rankA.Rare * S_RARE_MULTIPLIER,
}

function CrateOdds.oddsFor(rank: string?)
	return CrateOdds.ByRank[rank or ""]
end

function CrateOdds.roll(rank: string?, random: Random): string?
	local odds = CrateOdds.oddsFor(rank)
	if not odds then
		return nil
	end

	local total = 0
	for _, tier in TIER_ORDER do
		total += odds[tier]
	end

	local pick = random:NextNumber() * total
	for _, tier in TIER_ORDER do
		pick -= odds[tier]
		if pick < 0 then
			return tier
		end
	end
	return TIER_ORDER[#TIER_ORDER]
end

return CrateOdds
