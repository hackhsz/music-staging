local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))

local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new(playerDataService)
	return setmetatable({
		playerDataService = playerDataService,
	}, InventoryService)
end

local function getCosmetic(cosmeticId: string)
	return CosmeticsCatalog.getItem(cosmeticId)
end

-- Server-authoritative purchase: validates the item, checks its unlock
-- condition (soft-currency price or achievement gate), deducts Beat Coins
-- from the profile and persists ownership. Returns (ok, reason).
function InventoryService:purchase(player: Player, cosmeticId: string): (boolean, string)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return false, "profile_not_loaded"
	end

	local item = getCosmetic(cosmeticId)

	if item == nil then
		return false, "unknown_cosmetic"
	end

	if profile.cosmetics[cosmeticId] then
		return false, "already_owned"
	end

	if item.unlock == "soft_currency" then
		local price = tonumber(item.price) or 0

		if (profile.softCurrency or 0) < price then
			return false, "insufficient_funds"
		end

		profile.softCurrency -= price
		profile.cosmetics[cosmeticId] = true
		self.playerDataService:markDirty(player)

		return true, "purchased"
	end

	if item.unlockAchievementId ~= nil then
		-- Achievement rewards are normally auto-granted by RewardService;
		-- this claim path covers profiles where the achievement is recorded
		-- but the cosmetic is missing.
		if profile.achievements[item.unlockAchievementId] == true then
			profile.cosmetics[cosmeticId] = true
			self.playerDataService:markDirty(player)

			return true, "achievement_claimed"
		end

		return false, "locked_requirement"
	end

	if item.unlock == "starter" then
		profile.cosmetics[cosmeticId] = true
		self.playerDataService:markDirty(player)

		return true, "starter_granted"
	end

	return false, "not_purchasable"
end

-- Clears a slot. Only a category some catalog item uses counts as a slot.
function InventoryService:unequip(player: Player, category: string): (boolean, string)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return false, "profile_not_loaded"
	end

	local known = false

	for _, item in CosmeticsCatalog.Items do
		if item.category == category then
			known = true
			break
		end
	end

	if not known then
		return false, "unknown_category"
	end

	if profile.equipped[category] == nil then
		return false, "nothing_equipped"
	end

	profile.equipped[category] = nil
	self.playerDataService:markDirty(player)

	return true, "unequipped"
end

function InventoryService:equip(player: Player, cosmeticId: string): (boolean, string)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return false, "profile_not_loaded"
	end

	local item = getCosmetic(cosmeticId)

	if item == nil then
		return false, "unknown_cosmetic"
	end

	if not profile.cosmetics[cosmeticId] then
		return false, "not_owned"
	end

	profile.equipped[item.category] = cosmeticId
	self.playerDataService:markDirty(player)

	return true, "equipped"
end

return InventoryService
