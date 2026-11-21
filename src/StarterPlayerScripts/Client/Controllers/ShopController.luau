--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local ShopCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("ShopCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

local COMING_SOON_HINT = "COMING SOON - ROBUX SALES OPEN AT LAUNCH"
local SET_ROAD_DONE = "SET COMPLETE"
local STEP_DONE_MARK = "✓ "
local STEP_NEXT_MARK = "▶ "
local STEP_LATER_MARK = "· "
local PURCHASE_HINTS = {
	purchased = "PURCHASED!",
	claimed = "REWARD CLAIMED!",
	cooldown_active = "REWARD COOLDOWN ACTIVE",
	already_claimed = "ALREADY CLAIMED",
	unknown_reward = "UNKNOWN REWARD",
	achievement_claimed = "REWARD CLAIMED!",
	starter_granted = "STARTER GIFT CLAIMED!",
	insufficient_funds = "NOT ENOUGH COINS",
	already_owned = "ALREADY OWNED",
	already_unlocked = "ALREADY UNLOCKED",
	locked_requirement = "LOCKED - CLEAR THE REQUIREMENT FIRST",
	not_purchasable = "NOT FOR SALE",
	not_in_group = "JOIN THE GROUP FIRST, THEN CLAIM",
}

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	sfx: any,
	openPass: () -> (),
}

type Fields = {
	deps: Deps,
	profile: any?,
	songs: { any },
}

-- Everything about buying and equipping: the profile mirror the server pushes, the
-- shop sections built from it, and the purchase remotes.
local ShopController = {}
ShopController.__index = ShopController

export type ShopController = typeof(setmetatable({} :: Fields, ShopController))

function ShopController.new(deps: Deps): ShopController
	local fields: Fields = {
		deps = deps,
		profile = nil,
		songs = {},
	}

	return setmetatable(fields, ShopController)
end

function ShopController.start(self: ShopController)
	local deps = self.deps

	deps.hud.menu:bindShop(function()
		self:toggle()
	end)
	deps.hud.shop:bindItemPicked(function()
		Telemetry.step("shop", "item_viewed")
	end)
	deps.hud.shop:bindItemActivated(function(entry)
		self:_onItemActivated(entry)
	end)
	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		self:_onProfileSync(payload)
	end)
	deps.remotes.PurchaseResult.OnClientEvent:Connect(function(payload)
		self:_onPurchaseResult(payload)
	end)
end

function ShopController.setSongCatalog(self: ShopController, songs: { any })
	self.songs = songs
	self:_refresh()
end

function ShopController.toggle(self: ShopController)
	if self.deps.hud.shop:isVisible() then
		self.deps.hud.shop:setVisible(false)
	else
		self:open()
	end
end

function ShopController.open(self: ShopController)
	local shop = self.deps.hud.shop

	shop:setPreviewSource(Players.LocalPlayer.Character)
	shop:render(self:_buildSections())
	shop:setVisible(true)
	Telemetry.track("shop_opened")
	Telemetry.step("shop", "opened")
end

function ShopController._refresh(self: ShopController)
	if self.deps.hud.shop:isVisible() then
		self.deps.hud.shop:render(self:_buildSections())
	end
end

function ShopController._setBalance(self: ShopController, amount: number?)
	self.deps.hud.menu:updateBalance(amount)
	self.deps.hud.shop:updateBalance(amount)
end

-- Whether the player already has what a Robux offer sells, from the server's profile.
local function ownsOffer(profile: any, offer: any): boolean
	if profile == nil then
		return false
	end

	if offer.grants ~= nil and offer.grants.stagePass == true then
		return type(profile.stagePass) == "table" and profile.stagePass.passOwned == true
	end

	local passes = profile.passes or {}
	local bought = profile.boughtOffers or {}

	return passes[offer.id] == true or (offer.oneTime == true and bought[offer.id] == true)
end

-- A Robux offer's shop row; kind is "pass", "bundle" or "coin_pack".
local function robuxEntry(offer: any, kind: string, profile: any?): any
	local marketId = if kind == "pass" then offer.passId else offer.productId

	return {
		kind = kind,
		id = offer.id,
		marketId = marketId,
		displayName = string.upper(offer.displayName),
		glyph = offer.glyph,
		icon = offer.icon,
		rarity = offer.rarity,
		category = if kind == "pass"
			then "game pass"
			elseif kind == "coin_pack" then ("%d coins"):format(offer.coins or 0)
			else "bundle",
		robux = offer.robux,
		wasRobux = offer.wasRobux,
		includes = offer.includes,
		description = offer.description,
		badge = offer.badge,
		hero = offer.hero,
		oneTime = offer.oneTime,
		coins = offer.coins,
		bonus = offer.bonus,
		stateText = if offer.oneTime == true then "ONE-TIME OFFER" elseif kind == "pass" then "YOURS FOREVER" else "",
		owned = ownsOffer(profile, offer),
		opensPass = offer.opensPass,
		comingSoon = offer.comingSoon == true or not ShopCatalog.RobuxSalesOpen or marketId == nil,
	}
end

-- The Set Road as one hero banner: its next step to buy, with every step listed and
-- the ones already taken ticked.
local function setRoadEntry(profile: any?): any
	local road = ShopCatalog.SetRoad
	local taken = if profile ~= nil and type(profile.setRoad) == "table" then profile.setRoad.step or 0 else 0
	local nextStep = road.steps[taken + 1]
	local lines = {}

	for index, step in road.steps do
		local item = CosmeticsCatalog.getItem(step.cosmeticId)
		local mark = if index <= taken then STEP_DONE_MARK elseif index == taken + 1 then STEP_NEXT_MARK else STEP_LATER_MARK
		local price = if step.robux == 0 then "FREE" else ("R$ %d"):format(step.robux)

		table.insert(lines, ("%s%s  %s"):format(mark, if item ~= nil then item.displayName else step.cosmeticId, price))
	end

	local nextItem = if nextStep ~= nil then CosmeticsCatalog.getItem(nextStep.cosmeticId) else nil

	return {
		kind = "set_road",
		id = road.id,
		hero = true,
		step = taken + 1,
		marketId = if nextStep ~= nil then nextStep.productId else nil,
		displayName = ("%s · STEP %d OF %d"):format(string.upper(road.displayName), math.min(taken + 1, #road.steps), #road.steps),
		icon = if nextItem ~= nil then nextItem.icon else road.icon,
		glyph = if nextItem ~= nil then nextItem.glyph else nil,
		badge = string.upper(road.subtitle),
		includes = lines,
		robux = if nextStep ~= nil then nextStep.robux else nil,
		owned = nextStep == nil,
		ownedText = SET_ROAD_DONE,
		comingSoon = nextStep ~= nil and nextStep.robux > 0 and (not ShopCatalog.RobuxSalesOpen or nextStep.productId == nil),
	}
end

-- Shop rows for the panel: Robux offers, ShopCatalog cosmetics with price, owned
-- and equipped state, the tracks the player has not unlocked yet, and coin packs.
function ShopController._buildSections(self: ShopController): { any }
	local profile = self.profile
	local cosmetics = if profile ~= nil then profile.cosmetics else {}
	local equipped = if profile ~= nil then profile.equipped else {}
	local achievements = if profile ~= nil then profile.achievements else {}
	local coins = if profile ~= nil then profile.softCurrency else 0
	local sections: { any } = {}

	for _, section in ShopCatalog.Sections do
		local entries: { any } = {}

		if section.setRoad == true then
			table.insert(entries, setRoadEntry(profile))
		end

		for _, offerId in section.offers or {} do
			local offer = ShopCatalog.getOffer(offerId)

			if offer ~= nil then
				table.insert(entries, robuxEntry(offer, offer.kind, profile))
			end
		end

		for _, cosmeticId in section.items do
			local item = CosmeticsCatalog.getItem(cosmeticId)

			if item == nil then
				continue
			end

			local owned = cosmetics[item.id] == true
			local isEquipped = owned and equipped[item.category] == item.id
			local achievementMet = item.unlockAchievementId ~= nil and achievements[item.unlockAchievementId] == true
			local stateText

			if isEquipped then
				stateText = "EQUIPPED"
			elseif owned then
				stateText = "OWNED - TAP TO EQUIP"
			elseif item.unlock == "soft_currency" then
				stateText = ("%d COINS"):format(item.price or 0)
			elseif achievementMet then
				stateText = "UNLOCKED - TAP TO CLAIM"
			else
				stateText = string.upper(item.requirementText or "LOCKED")
			end

			table.insert(entries, {
				kind = "cosmetic",
				id = item.id,
				displayName = string.upper(item.displayName),
				glyph = item.glyph,
				icon = item.icon,
				rarity = item.rarity,
				stateText = stateText,
				category = item.category,
				price = if item.unlock == "soft_currency" then item.price or 0 else nil,
				owned = owned,
				equipped = isEquipped,
				locked = not owned and item.unlock ~= "soft_currency" and not achievementMet,
				comingSoon = not owned and item.unlock == "coming_soon",
				affordable = item.unlock ~= "soft_currency" or coins >= (item.price or 0),
			})
		end

		if #entries == 0 then
			continue
		end

		table.insert(sections, {
			id = section.id,
			displayName = string.upper(section.displayName),
			entries = entries,
		})
	end

	local trackEntries: { any } = {}

	for _, song in self.songs do
		if song.locked ~= true then
			continue
		end

		local coinUnlock = song.unlockType == "soft_currency"

		table.insert(trackEntries, {
			kind = "song",
			id = song.id,
			glyph = "🎵",
			displayName = string.upper(song.title or song.id),
			stateText = if coinUnlock then ("%d COINS"):format(song.price or 0) else string.upper(song.requirementText or "LOCKED"),
			price = if coinUnlock then song.price or 0 else nil,
			locked = not coinUnlock,
			affordable = not coinUnlock or coins >= (song.price or 0),
		})
	end

	if #trackEntries > 0 then
		table.insert(sections, {
			id = ShopCatalog.TrackSection.id,
			displayName = string.upper(ShopCatalog.TrackSection.displayName),
			entries = trackEntries,
		})
	end

	local packEntries: { any } = {}

	for _, pack in ShopCatalog.CoinPacks do
		table.insert(packEntries, robuxEntry(pack, "coin_pack", profile))
	end

	table.insert(sections, {
		id = ShopCatalog.CoinPackSection.id,
		displayName = string.upper(ShopCatalog.CoinPackSection.displayName),
		entries = packEntries,
	})

	return sections
end

function ShopController._onItemActivated(self: ShopController, entry: any)
	local deps = self.deps

	if entry.kind == "song" then
		deps.remotes.PurchaseSong:FireServer({ songId = entry.id })
		Telemetry.track("song_purchase_requested", entry.id)
		return
	end

	if entry.opensPass == true then
		deps.openPass()
		return
	end

	if entry.kind == "set_road" and entry.robux == 0 then
		deps.remotes.ClaimReward:FireServer({ rewardId = ShopCatalog.SetRoad.freeRewardId })
		return
	end

	if entry.robux ~= nil then
		self:_promptRobux(entry)
		return
	end

	if entry.kind ~= "cosmetic" or entry.equipped then
		return
	end

	if entry.owned then
		-- Equip goes through the existing server-validated remote.
		deps.remotes.EquipCosmetic:FireServer({ cosmeticId = entry.id })
		deps.hud.hints:setHint("EQUIPPING " .. (entry.displayName or ""))
		Telemetry.track("cosmetic_equip_requested", entry.id)
	else
		deps.remotes.PurchaseCosmetic:FireServer({ cosmeticId = entry.id })
		Telemetry.track("cosmetic_purchase_requested", entry.id)
	end
end

-- Roblox's own prompt; the server grants the purchase, so this only asks.
function ShopController._promptRobux(self: ShopController, entry: any)
	if entry.comingSoon == true or entry.marketId == nil then
		self.deps.hud.hints:setHint(COMING_SOON_HINT)
		self.deps.sfx:play("uiDenied")
		return
	end

	local ok, err = pcall(function()
		if entry.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, entry.marketId)
		else
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, entry.marketId)
		end
	end)

	if not ok then
		warn("[DanceDanceStep] Robux purchase prompt failed: " .. tostring(err))
	end

	Telemetry.track("robux_purchase_prompted", entry.id)
end

function ShopController._onProfileSync(self: ShopController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	self.profile = payload
	self:_setBalance(payload.softCurrency or 0)
	self.deps.hud.menu:updateDaily(payload.daily)
	self.deps.hud.menu:updateStats(payload.stats)
	self:_refresh()
end

function ShopController._onPurchaseResult(self: ShopController, payload: any)
	-- Code results belong to the Rewards window.
	if type(payload) ~= "table" or payload.kind == "code" then
		return
	end

	if payload.softCurrency ~= nil then
		self:_setBalance(payload.softCurrency)

		if self.profile ~= nil then
			self.profile.softCurrency = payload.softCurrency
		end
	end

	local fallback = if payload.ok == true then "PURCHASED!" else "PURCHASE FAILED"

	self.deps.hud.hints:setHint(PURCHASE_HINTS[payload.reason] or fallback)
	self.deps.sfx:play(if payload.ok == true then "uiBuy" else "uiDenied")

	if payload.ok == true then
		self.deps.hud.shop:playBought()
	end
	self:_refresh()
	Telemetry.track(if payload.ok == true then "purchase_succeeded" else "purchase_failed", payload.itemId)
end

return ShopController
