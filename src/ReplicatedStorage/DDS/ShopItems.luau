local RUN_COINS_BASE = 10
local RUN_COINS_ACCURACY = 30
local RUN_COINS_EXHAUSTED = 3

local ShopItems = {
	CURRENCY_NAME = "Beat Coins",
	COINS_ATTRIBUTE = "BeatCoins",
	OWNED_ATTRIBUTE = "ShopOwned",
	DUEL_WIN_COINS = 50,
	DUEL_PLAY_COINS = 10,

	Items = {
		SakuraTrail = { DisplayName = "Sakura Trail", Description = "Petals follow your steps. (placeholder)", Category = "Effect", Price = 150, Order = 1 },
		NeonPadSkin = { DisplayName = "Neon Pad Skin", Description = "Your pad glows neon between songs. (placeholder)", Category = "Cosmetic", Price = 250, Order = 2 },
		StarHeadband = { DisplayName = "Star Headband", Description = "A sparkly headband. (placeholder)", Category = "Cosmetic", Price = 300, Order = 3 },
		VictorySpin = { DisplayName = "Victory Spin", Description = "Spin after a duel win. (placeholder)", Category = "Emote", Price = 400, Order = 4 },
		HeartBurst = { DisplayName = "Heart Burst", Description = "Hearts on every PERFECT. (placeholder)", Category = "Effect", Price = 500, Order = 5 },
		IdolPose = { DisplayName = "Idol Pose", Description = "Strike a pose on the results screen. (placeholder)", Category = "Emote", Price = 750, Order = 6 },
	},
}

function ShopItems.sorted()
	local list = {}
	for id, item in ShopItems.Items do
		table.insert(list, setmetatable({ Id = id }, { __index = item }))
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function ShopItems.parseOwned(text: string?): { [string]: boolean }
	local owned = {}
	for id in string.gmatch(text or "", "[^,]+") do
		owned[id] = true
	end
	return owned
end

function ShopItems.formatOwned(owned: { [string]: boolean }): string
	local ids = {}
	for id in owned do
		table.insert(ids, id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function ShopItems.coinsForRun(accuracy: number, coinMultiplier: number?, exhausted: boolean?): number
	local base = if exhausted then RUN_COINS_EXHAUSTED else RUN_COINS_BASE + RUN_COINS_ACCURACY * accuracy / 100
	return math.floor(base * (coinMultiplier or 1))
end

return ShopItems
