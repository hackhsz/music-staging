--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local TimeRewards = require(Shared:WaitForChild("Catalogs"):WaitForChild("TimeRewards"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

return {
	["gifts come later and pay more down the ladder"] = function()
		local seen: { [string]: boolean } = {}

		for index, tier in TimeRewards.Tiers do
			assert(not seen[tier.id], "duplicate id " .. tier.id)
			seen[tier.id] = true

			local previous = TimeRewards.Tiers[index - 1]

			if previous ~= nil then
				assert(tier.minutes > previous.minutes, tier.id .. " unlocks no later than " .. previous.id)
				assert(tier.coins > previous.coins, tier.id .. " pays no more than " .. previous.id)
			end
		end
	end,

	["every gift has an icon and any item it gives exists"] = function()
		for _, tier in TimeRewards.Tiers do
			assert(tier.glyph ~= "", tier.id .. " has no glyph")

			if tier.cosmeticId ~= nil then
				assert(CosmeticsCatalog.getItem(tier.cosmeticId) ~= nil, tier.id .. " gives an unknown item")
			end
		end
	end,

	["a reward id names its tier and nothing else does"] = function()
		for _, tier in TimeRewards.Tiers do
			expect(TimeRewards.fromRewardId(TimeRewards.RewardPrefix .. tier.id), tier, tier.id)
		end

		expect(TimeRewards.fromRewardId(TimeRewards.Tiers[1].id), nil, "no prefix")
		expect(TimeRewards.fromRewardId(TimeRewards.RewardPrefix .. "t1000"), nil, "unknown tier")
		expect(TimeRewards.fromRewardId("social:like"), nil, "another reward")
	end,

	["the countdown reaches zero and stays there"] = function()
		local tier = TimeRewards.Tiers[1]

		expect(TimeRewards.secondsLeft(tier, 0), tier.minutes * 60, "at join")
		expect(TimeRewards.secondsLeft(tier, tier.minutes * 60), 0, "on time")
		expect(TimeRewards.secondsLeft(tier, tier.minutes * 60 + 100), 0, "after")
	end,
}
