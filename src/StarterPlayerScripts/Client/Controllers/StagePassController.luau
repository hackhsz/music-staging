--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("ShopCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local PASS_OFFER_ID = "stage-pass"

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
}

type Fields = {
	deps: Deps,
}

-- The Stage Pass window: the season track the server pushes with the profile, and the
-- claims sent back. The server decides every claim; this only asks.
local StagePassController = {}
StagePassController.__index = StagePassController

export type StagePassController = typeof(setmetatable({} :: Fields, StagePassController))

function StagePassController.new(deps: Deps): StagePassController
	return setmetatable({ deps = deps } :: Fields, StagePassController)
end

function StagePassController.start(self: StagePassController)
	local hud = self.deps.hud
	local remotes = self.deps.remotes

	hud.menu:bindPass(function()
		hud.stagePass:setVisible(not hud.stagePass:isVisible())
	end)
	local offer = ShopCatalog.getOffer(PASS_OFFER_ID)
	local productId = if offer ~= nil then offer.productId else nil

	hud.stagePass:setUnlockOffer(
		if offer ~= nil then offer.robux else 0,
		ShopCatalog.RobuxSalesOpen and productId ~= nil
	)
	hud.stagePass:bindUnlock(function()
		local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)

		if not ok then
			warn("[DanceDanceStep] Stage Pass prompt failed: " .. tostring(err))
		end
	end)
	hud.stagePass:bindClaim(function(tier, row)
		remotes.ClaimPassTier:FireServer({ tier = tier, row = row })
	end)
	Remotes.listen(remotes.ProfileSync, function(payload)
		if type(payload) == "table" then
			hud.stagePass:update(payload.stagePass)
		end
	end)
end

function StagePassController.open(self: StagePassController)
	self.deps.hud.stagePass:setVisible(true)
end

return StagePassController
