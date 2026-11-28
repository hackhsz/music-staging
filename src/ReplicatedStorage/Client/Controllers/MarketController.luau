--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UGCCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("UGCCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local MarketPanel = require(script.Parent.Parent.UI.Screens.MarketPanel)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)
local UiKit = require(script.Parent.Parent.UI.UiKit)
local StallBoards = require(script.Parent.Parent.World.StallBoards)

local THUMBNAIL = "rbxthumb://type=Asset&id=%d&w=150&h=150"

type Deps = {
	hud: HUDController.HUDController,
	remotes: Remotes.Remotes,
	boards: StallBoards.StallBoards,
}

type Fields = {
	deps: Deps,
	state: any?,
}

-- The UGC Market: the server's stall state drawn in the Market window and on the
-- island boards, and the requests to claim, list, leave and buy. The server opens
-- Roblox's purchase prompt, so nothing here touches currency or ownership.
local MarketController = {}
MarketController.__index = MarketController

export type MarketController = typeof(setmetatable({} :: Fields, MarketController))

function MarketController.new(deps: Deps): MarketController
	return setmetatable({ deps = deps, state = nil } :: Fields, MarketController)
end

function MarketController.start(self: MarketController)
	local remotes = self.deps.remotes
	local market = self.deps.hud.market

	market:bindActions({
		buy = function(assetId: number)
			self:_buy(assetId)
		end,
		claim = function(stallId: string)
			remotes.ClaimStall:FireServer({ stallId = stallId })
		end,
		remove = function(assetId: number)
			remotes.RemoveListing:FireServer({ assetId = assetId })
		end,
		add = function(text: string)
			local assetId = tonumber((text:match("%d+")))

			if assetId == nil then
				market:showNotice(UGCCatalog.reasonText("bad_asset_id"))
				UiKit.playSound("uiDenied")
				return
			end

			remotes.AddListing:FireServer({ assetId = assetId })
		end,
		release = function()
			remotes.ReleaseStall:FireServer({})
		end,
		browse = function()
			remotes.ListCreations:FireServer({})
		end,
	})

	remotes.CreationsList.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.items) ~= "table" then
			return
		end

		local items: { MarketPanel.Item } = {}

		for _, creation in payload.items do
			if type(creation) == "table" and type(creation.assetId) == "number" then
				table.insert(items, {
					name = tostring(creation.name or "Item"),
					glyph = "👕",
					icon = THUMBNAIL:format(creation.assetId),
					assetId = creation.assetId,
					price = if type(creation.price) == "number" then creation.price else nil,
					forSale = true,
					sellable = creation.saleLocation == UGCCatalog.SellableLocation,
				})
			end
		end

		market:showCreations(items)
	end)

	Remotes.listen(remotes.StallState, function(payload)
		if type(payload) == "table" and type(payload.stalls) == "table" then
			self.state = payload
			self:_render()
		end
	end)

	remotes.StallResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.reason) ~= "string" then
			return
		end

		market:showNotice(UGCCatalog.reasonText(payload.reason))
		UiKit.playSound(if payload.ok == true then "uiClick" else "uiDenied")

		if payload.ok == true and payload.reason == "listed" then
			market:clearIdBox()
		end

		Telemetry.track("market_" .. payload.reason, tostring(payload.assetId or ""))
	end)
end

-- stallId, when it names a stall, opens on that stall's rack.
function MarketController.open(self: MarketController, stallId: string?)
	local market = self.deps.hud.market

	self:_render()

	if type(stallId) == "string" then
		market:showStall(stallId)
	end

	market:setVisible(true)
	Telemetry.track("market_opened", stallId)
end

function MarketController._render(self: MarketController)
	local stalls, hasStall = self:_stalls()
	local open = if self.state ~= nil then self.state.open == true else UGCCatalog.isOpen()

	self.deps.hud.market:render(stalls, open, hasStall)
	self.deps.boards:render(stalls)
end

function MarketController._stalls(self: MarketController): ({ MarketPanel.Stall }, boolean)
	local byId: { [string]: any } = {}
	local userId = Players.LocalPlayer.UserId
	local hasStall = false

	for _, entry in if self.state ~= nil then self.state.stalls else {} do
		if type(entry) == "table" and type(entry.id) == "string" then
			byId[entry.id] = entry
		end
	end

	local stalls: { MarketPanel.Stall } = {}

	for _, stall in UGCCatalog.Stalls do
		local entry = byId[stall.id]
		local mine = entry ~= nil and entry.ownerUserId == userId
		local items: { MarketPanel.Item } = {}

		for _, item in if entry ~= nil and type(entry.items) == "table" then entry.items else {} do
			local listed = type(item) == "table" and type(item.assetId) == "number"

			if listed and (mine or item.forSale == true) then
				table.insert(items, {
					name = tostring(item.name or "Item"),
					glyph = stall.glyph,
					icon = THUMBNAIL:format(item.assetId),
					assetId = item.assetId,
					price = if type(item.price) == "number" then item.price else nil,
					forSale = item.forSale == true,
				})
			end
		end

		hasStall = hasStall or mine
		table.insert(stalls, {
			id = stall.id,
			name = stall.name,
			owner = if entry ~= nil and type(entry.ownerName) == "string" then entry.ownerName else nil,
			mine = mine,
			items = items,
		})
	end

	return stalls, hasStall
end

function MarketController._buy(self: MarketController, assetId: number)
	self.deps.remotes.BuyListing:FireServer({ assetId = assetId })
	Telemetry.track("market_purchase_requested", tostring(assetId))
end

return MarketController
