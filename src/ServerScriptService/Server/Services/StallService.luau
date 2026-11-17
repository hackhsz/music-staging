--!strict
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UGCCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("UGCCatalog"))

-- Product info is refreshed this often, so an item taken off sale stops selling.
local INFO_TTL_SECONDS = 600
local CREATIONS_TTL_SECONDS = 30
local MAX_ASSET_ID = 2 ^ 53

type Info = {
	name: string,
	price: number?,
	assetTypeId: number,
	forSale: boolean,
	creatorType: string,
	creatorId: number,
	fetchedAt: number,
}
type Creation = { assetId: number, name: string, price: number?, saleLocation: string }
type Fields = {
	playerDataService: any,
	stateRemote: RemoteEvent,
	resultRemote: RemoteEvent,
	owners: { [string]: Player },
	stallOf: { [Player]: string },
	sales: { [string]: number },
	info: { [number]: Info },
	pending: { [Player]: { assetId: number, stallId: string } },
	creations: { [Player]: { items: { Creation }, fetchedAt: number } },
}

-- Player market stalls. Only avatar items the player (or a group they own) created
-- and has on sale can be listed; buyers pay through Roblox, so nothing here moves
-- currency.
local StallService = {}
StallService.__index = StallService

export type StallService = typeof(setmetatable({} :: Fields, StallService))

function StallService.new(playerDataService: any, stateRemote: RemoteEvent, resultRemote: RemoteEvent): StallService
	return setmetatable({
		playerDataService = playerDataService,
		stateRemote = stateRemote,
		resultRemote = resultRemote,
		owners = {},
		stallOf = {},
		sales = {},
		info = {},
		pending = {},
		creations = {},
	} :: Fields, StallService)
end

local function anchorOf(stallId: string): BasePart?
	local stations = Workspace:FindFirstChild(UGCCatalog.StationsFolder)

	if stations == nil then
		return nil
	end

	for _, station in stations:GetChildren() do
		if station:GetAttribute(UGCCatalog.StallAttribute) == stallId then
			local anchor = station:FindFirstChild(UGCCatalog.AnchorName, true)

			return if anchor ~= nil and anchor:IsA("BasePart") then anchor else nil
		end
	end

	return nil
end

local function isNear(player: Player, stallId: string): boolean
	local anchor = anchorOf(stallId)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	if anchor == nil or root == nil or not root:IsA("BasePart") then
		return false
	end

	return (root.Position - anchor.Position).Magnitude <= UGCCatalog.ClaimDistance
end

-- Product info for an asset; nil when Roblox could not be reached, so the caller can
-- tell a failed lookup from a refused item. Only listed items are kept in the cache.
function StallService._lookup(self: StallService, assetId: number): Info?
	local cached = self.info[assetId]

	if cached ~= nil and os.clock() - cached.fetchedAt < INFO_TTL_SECONDS then
		return cached
	end

	local ok, result = pcall(function()
		return MarketplaceService:GetProductInfoAsync(assetId, Enum.InfoType.Asset)
	end)

	if not ok or type(result) ~= "table" then
		warn(("[DanceDanceStep] Product info for %d failed: %s"):format(assetId, tostring(result)))
		return nil
	end

	local creator = if type(result.Creator) == "table" then result.Creator else {}
	local info: Info = {
		name = tostring(result.Name or "Item"),
		price = if type(result.PriceInRobux) == "number" then result.PriceInRobux else nil,
		assetTypeId = tonumber(result.AssetTypeId) or 0,
		forSale = result.IsForSale == true,
		creatorType = tostring(creator.CreatorType or ""),
		creatorId = tonumber(creator.CreatorTargetId) or 0,
		fetchedAt = os.clock(),
	}

	if cached ~= nil then
		self.info[assetId] = info
	end

	return info
end

local function listableAvatarTypes(): { Enum.AvatarAssetType }
	local types = {}

	for _, item in Enum.AvatarAssetType:GetEnumItems() do
		if UGCCatalog.ListableAssetTypes[item.Value] ~= nil then
			table.insert(types, item)
		end
	end

	return types
end

local LISTABLE_AVATAR_TYPES = listableAvatarTypes()

-- The player's own on-sale clothing and accessories from the catalog, which also
-- tells where each may be sold. Nil when the catalog could not be reached.
function StallService.creationsOf(self: StallService, player: Player): { Creation }?
	local cached = self.creations[player]

	if cached ~= nil and os.clock() - cached.fetchedAt < CREATIONS_TTL_SECONDS then
		return cached.items
	end

	local params = CatalogSearchParams.new()
	params.CreatorId = player.UserId
	params.CreatorType = Enum.CreatorTypeFilter.User
	params.IncludeOffSale = false
	params.AssetTypes = LISTABLE_AVATAR_TYPES
	params.Limit = UGCCatalog.CreationsShown

	local ok, result = pcall(function()
		return AvatarEditorService:SearchCatalogAsync(params):GetCurrentPage()
	end)

	if not ok or type(result) ~= "table" then
		warn(("[DanceDanceStep] Catalog search for %d failed: %s"):format(player.UserId, tostring(result)))
		return nil
	end

	local items = {}

	for _, entry in result do
		if type(entry) == "table" and type(entry.Id) == "number" then
			table.insert(items, {
				assetId = entry.Id,
				name = tostring(entry.Name or "Item"),
				price = if type(entry.Price) == "number" then entry.Price else nil,
				saleLocation = tostring(entry.SaleLocationType or ""),
			})
		end
	end

	self.creations[player] = { items = items, fetchedAt = os.clock() }

	return items
end

-- Nil when the item is not among the player's catalog results (a group's item, or
-- past the first page), which lets the listing through unchecked.
function StallService._saleLocation(self: StallService, player: Player, assetId: number): string?
	for _, creation in self:creationsOf(player) or {} do
		if creation.assetId == assetId then
			return creation.saleLocation
		end
	end

	return nil
end

local function madeBy(player: Player, info: Info): boolean
	if info.creatorType == "User" then
		return info.creatorId == player.UserId
	end

	if info.creatorType ~= "Group" then
		return false
	end

	local ok, group = pcall(function()
		return GroupService:GetGroupInfoAsync(info.creatorId)
	end)

	return ok and type(group) == "table" and type(group.Owner) == "table" and group.Owner.Id == player.UserId
end

function StallService._listings(self: StallService, player: Player): { number }?
	local profile = self.playerDataService:get(player)

	return if profile ~= nil then profile.ugcListings else nil
end

function StallService.payload(self: StallService): any
	local stalls = {}

	for _, stall in UGCCatalog.Stalls do
		local owner = self.owners[stall.id]
		local items = {}

		for _, assetId in (if owner ~= nil then self:_listings(owner) else nil) or {} do
			local info = self.info[assetId]

			table.insert(items, {
				assetId = assetId,
				name = if info ~= nil then info.name else "Item",
				price = if info ~= nil then info.price else nil,
				forSale = info ~= nil and info.forSale,
			})
		end

		table.insert(stalls, {
			id = stall.id,
			ownerUserId = if owner ~= nil then owner.UserId else nil,
			ownerName = if owner ~= nil then owner.DisplayName else nil,
			sales = self.sales[stall.id] or 0,
			items = items,
		})
	end

	return { open = UGCCatalog.isOpen(), stalls = stalls }
end

function StallService.broadcast(self: StallService)
	self.stateRemote:FireAllClients(self:payload())
end

function StallService.push(self: StallService, player: Player)
	self.stateRemote:FireClient(player, self:payload())
end

function StallService.reply(self: StallService, player: Player, ok: boolean, reason: string, assetId: number?)
	self.resultRemote:FireClient(player, { ok = ok, reason = reason, assetId = assetId })
end

function StallService.claim(self: StallService, player: Player, stallId: string): (boolean, string)
	if not UGCCatalog.isOpen() then
		return false, "market_closed"
	end

	if UGCCatalog.getStall(stallId) == nil then
		return false, "unknown_stall"
	end

	if self.owners[stallId] ~= nil then
		return false, "stall_taken"
	end

	if self.stallOf[player] ~= nil then
		return false, "already_have_stall"
	end

	if not isNear(player, stallId) then
		return false, "too_far"
	end

	self.owners[stallId] = player
	self.stallOf[player] = stallId
	self.sales[stallId] = 0
	self:broadcast()
	task.spawn(self._refreshListings, self, player, stallId)

	return true, "claimed"
end

-- Stops if the player lets the stall go while a lookup yields.
function StallService._refreshListings(self: StallService, player: Player, stallId: string)
	for _, assetId in table.clone(self:_listings(player) or {}) do
		if self.stallOf[player] ~= stallId then
			return
		end

		local info = self:_lookup(assetId)

		if info ~= nil then
			self.info[assetId] = info
		end
	end

	if self.stallOf[player] == stallId then
		self:broadcast()
	end
end

function StallService.release(self: StallService, player: Player): (boolean, string)
	local stallId = self.stallOf[player]

	if stallId == nil then
		return false, "no_stall"
	end

	self.stallOf[player] = nil
	self.owners[stallId] = nil
	self.sales[stallId] = nil
	self:broadcast()

	return true, "released"
end

function StallService.addListing(self: StallService, player: Player, assetId: number): (boolean, string)
	local listings = self:_listings(player)

	if not UGCCatalog.isOpen() then
		return false, "market_closed"
	end

	if listings == nil or self.stallOf[player] == nil then
		return false, "no_stall"
	end

	if assetId ~= math.floor(assetId) or assetId <= 0 or assetId > MAX_ASSET_ID then
		return false, "bad_asset_id"
	end

	if table.find(listings, assetId) ~= nil then
		return false, "already_listed"
	end

	if #listings >= UGCCatalog.MaxListings then
		return false, "stall_full"
	end

	local info = self:_lookup(assetId)

	if info == nil then
		return false, "lookup_failed"
	end

	if UGCCatalog.ListableAssetTypes[info.assetTypeId] == nil then
		return false, "not_avatar_item"
	end

	if not info.forSale then
		return false, "not_for_sale"
	end

	if not madeBy(player, info) then
		return false, "not_creator"
	end

	local saleLocation = self:_saleLocation(player, assetId)

	if saleLocation ~= nil and saleLocation ~= UGCCatalog.SellableLocation then
		return false, "wrong_sale_location"
	end

	-- The lookups above yield; the stall may have been let go or filled meanwhile.
	if self.stallOf[player] == nil then
		return false, "no_stall"
	elseif table.find(listings, assetId) ~= nil then
		return false, "already_listed"
	elseif #listings >= UGCCatalog.MaxListings then
		return false, "stall_full"
	end

	self.info[assetId] = info
	table.insert(listings, assetId)
	self.playerDataService:markDirty(player)
	self:broadcast()

	return true, "listed"
end

function StallService.removeListing(self: StallService, player: Player, assetId: number): (boolean, string)
	local listings = self:_listings(player)
	local index = if listings ~= nil then table.find(listings, assetId) else nil

	if listings == nil or index == nil then
		return false, "not_listed"
	end

	table.remove(listings, index)
	self.playerDataService:markDirty(player)
	self:broadcast()

	return true, "unlisted"
end

function StallService._stallSelling(self: StallService, assetId: number): (string?, Player?)
	for stallId, owner in self.owners do
		local listings = self:_listings(owner)

		if listings ~= nil and table.find(listings, assetId) ~= nil then
			return stallId, owner
		end
	end

	return nil, nil
end

-- The server opens the prompt itself, so only purchases started from a stall can
-- count as that stall's sales.
function StallService.buy(self: StallService, buyer: Player, assetId: number): (boolean, string)
	if not UGCCatalog.isOpen() then
		return false, "market_closed"
	end

	local stallId, owner = self:_stallSelling(assetId)

	if stallId == nil then
		return false, "not_on_stall"
	end

	if owner == buyer then
		return false, "own_item"
	end

	local info = self:_lookup(assetId)

	if info == nil or not info.forSale then
		return false, "not_for_sale"
	end

	self.pending[buyer] = { assetId = assetId, stallId = stallId :: string }

	local ok, err = pcall(function()
		MarketplaceService:PromptPurchase(buyer, assetId)
	end)

	if not ok then
		self.pending[buyer] = nil
		warn(("[DanceDanceStep] Purchase prompt for %d failed: %s"):format(assetId, tostring(err)))
		return false, "prompt_failed"
	end

	return true, "prompted"
end

-- PromptPurchaseFinished is not proof of a sale, so the buyer's ownership is checked
-- before it counts; free items never count.
function StallService.onPurchaseFinished(self: StallService, buyer: Player, assetId: number, purchased: boolean)
	local pending = self.pending[buyer]

	if pending == nil or pending.assetId ~= assetId then
		return
	end

	self.pending[buyer] = nil

	local info = self.info[assetId]

	if not purchased or info == nil or (info.price or 0) <= 0 then
		return
	end

	local owns, result = pcall(function()
		return MarketplaceService:PlayerOwnsAssetAsync(buyer, assetId)
	end)
	local owner = self.owners[pending.stallId]

	if not owns or result ~= true or owner == nil or owner == buyer then
		return
	end

	local profile = self.playerDataService:get(owner)

	if profile == nil then
		return
	end

	self.sales[pending.stallId] = (self.sales[pending.stallId] or 0) + 1
	profile.ugcSales = (profile.ugcSales or 0) + 1
	self.playerDataService:markDirty(owner)
	self:reply(owner, true, "sold", assetId)
	self:broadcast()
end

function StallService.clear(self: StallService, player: Player)
	self.pending[player] = nil
	self.creations[player] = nil

	if self.stallOf[player] ~= nil then
		self:release(player)
	end
end

return StallService
