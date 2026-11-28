--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("ShopCatalog"))

-- Receipts are kept so a retried ProcessReceipt never grants twice; the oldest go past this.
local MAX_RECEIPTS = 100

type Grant = { kind: string, offer: any?, step: number? }

local PurchaseService = {}
PurchaseService.__index = PurchaseService

export type PurchaseService = typeof(setmetatable(
	{} :: {
		playerDataService: any,
		rewardService: any,
		products: { [number]: Grant },
		passes: { [number]: any },
		onGranted: ((player: Player, itemId: string) -> ())?,
	},
	PurchaseService
))

local function productsFromCatalog(): { [number]: Grant }
	local products: { [number]: Grant } = {}

	for _, offer in ShopCatalog.Offers do
		if offer.kind == "bundle" and offer.productId ~= nil and offer.grants ~= nil then
			products[offer.productId] = { kind = "offer", offer = offer }
		end
	end

	for _, pack in ShopCatalog.CoinPacks do
		if pack.productId ~= nil then
			products[pack.productId] = { kind = "coins", offer = pack }
		end
	end

	for index, step in ShopCatalog.SetRoad.steps do
		if step.productId ~= nil then
			products[step.productId] = { kind = "set_road", step = index }
		end
	end

	return products
end

local function passesFromCatalog(): { [number]: any }
	local passes: { [number]: any } = {}

	for _, offer in ShopCatalog.Offers do
		if offer.kind == "pass" and offer.passId ~= nil and offer.comingSoon ~= true then
			passes[offer.passId] = offer
		end
	end

	return passes
end

function PurchaseService.new(playerDataService: any, rewardService: any): PurchaseService
	return setmetatable({
		playerDataService = playerDataService,
		rewardService = rewardService,
		products = productsFromCatalog(),
		passes = passesFromCatalog(),
		onGranted = nil,
	}, PurchaseService)
end

function PurchaseService.start(self: PurchaseService)
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:processReceipt(receipt)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local offer = self.passes[passId]

		if purchased and offer ~= nil then
			self:_markPass(player, offer, true)
		end
	end)
end

-- Roblox stays the judge of pass ownership; the saved flag only keeps the perk while it cannot answer.
function PurchaseService.refreshPasses(self: PurchaseService, player: Player)
	for passId, offer in self.passes do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)

		if ok and owns then
			self:_markPass(player, offer, false)
		elseif not ok then
			warn("[DanceDanceStep] Game pass check failed: " .. tostring(owns))
		end
	end
end

function PurchaseService._markPass(self: PurchaseService, player: Player, offer: any, announce: boolean)
	local profile = self.playerDataService:get(player)

	if profile == nil or profile.passes[offer.id] == true then
		return
	end

	profile.passes[offer.id] = true
	self.playerDataService:markDirty(player)

	if announce and self.onGranted ~= nil then
		self.onGranted(player, offer.id)
	end
end

function PurchaseService.processReceipt(self: PurchaseService, receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = if player ~= nil then self.playerDataService:get(player) else nil

	if player == nil or profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)

	-- Already granted in this profile; it only counts once that grant is saved.
	if profile.receipts[purchaseId] ~= nil then
		return if self.playerDataService:save(player, true)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grant = self.products[receipt.ProductId]

	if grant == nil then
		warn("[DanceDanceStep] Receipt for an unknown product: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local itemId = self:_grant(player, profile, grant)

	if itemId == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- The receipt stays recorded even if this save fails, so Roblox's retry saves the grant
	-- again rather than paying it twice.
	profile.receipts[purchaseId] = os.time()
	self:_pruneReceipts(profile)
	self.playerDataService:markDirty(player)

	if not self.playerDataService:save(player, true) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if self.onGranted ~= nil then
		self.onGranted(player, itemId)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService._grant(self: PurchaseService, player: Player, profile: any, grant: Grant): string?
	local rewards = self.rewardService

	if grant.kind == "coins" then
		profile.softCurrency += grant.offer.coins
		return grant.offer.id
	end

	if grant.kind == "set_road" then
		if rewards:grantSetRoadStep(player, grant.step :: number) == nil then
			return nil
		end

		return ("set-road:%d"):format(grant.step :: number)
	end

	local offer = grant.offer
	local grants = offer.grants

	profile.softCurrency += grants.coins or 0

	for _, cosmeticId in grants.cosmetics or {} do
		profile.cosmetics[cosmeticId] = true
	end

	if grants.stagePass == true then
		rewards:unlockStagePass(player)
	end

	if offer.oneTime == true then
		profile.boughtOffers[offer.id] = true
	end

	return offer.id
end

function PurchaseService._pruneReceipts(_self: PurchaseService, profile: any)
	local ids = {}

	for id in profile.receipts do
		table.insert(ids, id)
	end

	if #ids <= MAX_RECEIPTS then
		return
	end

	table.sort(ids, function(a, b)
		return profile.receipts[a] < profile.receipts[b]
	end)

	for index = 1, #ids - MAX_RECEIPTS do
		profile.receipts[ids[index]] = nil
	end
end

return PurchaseService
