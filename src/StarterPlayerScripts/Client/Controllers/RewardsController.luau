--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local CosmeticsCatalog = require(Catalogs:WaitForChild("CosmeticsCatalog"))
local TimeRewards = require(Catalogs:WaitForChild("TimeRewards"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local RewardsPanel = require(script.Parent.Parent.UI.Screens.RewardsPanel)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

-- Once a second while the window is open, so the countdowns tick; slower behind it,
-- only for the lobby button's dot.
local COIN_COLOR = Color3.fromRGB(255, 214, 64)
local OPEN_TICK_SECONDS = 1
local CLOSED_TICK_SECONDS = 5
local CODE_RESULTS = {
	code_redeemed = "CODE REDEEMED! +%d COINS",
	unknown_code = "THAT CODE DOESN'T EXIST",
	already_redeemed = "YOU ALREADY USED THAT CODE",
	code_expired = "THAT CODE HAS EXPIRED",
}

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	sfx: any,
}

type Fields = {
	deps: Deps,
	startedAt: number?,
	claimed: { [string]: boolean },
	owned: { [string]: boolean },
}

-- The Rewards window: the play-time gifts and promo codes. The server times the
-- visit and pays every gift; this only draws the countdowns and asks.
local RewardsController = {}
RewardsController.__index = RewardsController

export type RewardsController = typeof(setmetatable({} :: Fields, RewardsController))

function RewardsController.new(deps: Deps): RewardsController
	return setmetatable({ deps = deps, startedAt = nil, claimed = {}, owned = {} } :: Fields, RewardsController)
end

local function countdown(seconds: number): string
	local whole = math.ceil(seconds)

	return ("%d:%02d"):format(whole // 60, whole % 60)
end

function RewardsController.start(self: RewardsController)
	local deps = self.deps
	local rewards = deps.hud.rewards
	local specs: { RewardsPanel.GiftSpec } = {}

	for _, tier in TimeRewards.Tiers do
		table.insert(specs, { id = tier.id, timeText = ("%d MIN"):format(tier.minutes), glyph = tier.glyph, icon = tier.icon })
	end

	rewards:setGifts(specs)
	self:_drawPrizes()

	deps.hud.menu:bindDaily(function()
		if rewards:isVisible() then
			rewards:setVisible(false)
		else
			self:open()
		end
	end)
	rewards:bindRedeem(function(code: string)
		rewards:setCodeResult("CHECKING...", true)
		deps.remotes.RedeemCode:FireServer({ code = code })
	end)
	rewards:bindClaim(function(giftId: string)
		deps.remotes.ClaimReward:FireServer({ rewardId = TimeRewards.RewardPrefix .. giftId })
		Telemetry.track("time_reward_requested", giftId)
	end)

	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		if type(payload) ~= "table" or type(payload.timeRewards) ~= "table" then
			return
		end

		self.owned = if type(payload.cosmetics) == "table" then payload.cosmetics else {}
		self:_drawPrizes()

		local visit = payload.timeRewards

		self.startedAt = tonumber(visit.startedAt)
		self.claimed = if type(visit.claimed) == "table" then visit.claimed else {}
		self:_draw()
	end)
	deps.remotes.PurchaseResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		if payload.kind == "code" then
			self:_onCodeResult(payload)
		elseif payload.kind == "reward" and type(payload.itemId) == "string" then
			if TimeRewards.fromRewardId(payload.itemId) ~= nil then
				deps.sfx:play(if payload.ok == true then "uiBuy" else "uiDenied")
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(if rewards:isVisible() then OPEN_TICK_SECONDS else CLOSED_TICK_SECONDS)
			self:_draw()
		end
	end)
end

function RewardsController.open(self: RewardsController)
	self:_draw()
	self.deps.hud.rewards:setVisible(true)
end

function RewardsController._onCodeResult(self: RewardsController, payload: any)
	local reward = if type(payload.reward) == "table" then tonumber(payload.reward.amount) or 0 else 0
	local text = (CODE_RESULTS[payload.reason] or "COULDN'T REDEEM THAT CODE"):format(reward)

	self.deps.hud.rewards:setCodeResult(text, payload.ok == true)
	self.deps.sfx:play(if payload.ok == true then "uiBuy" else "uiDenied")
	Telemetry.track(if payload.ok == true then "code_redeemed" else "code_rejected", payload.reason)
end

-- An item gift shows the item until the player owns it, then the coins it pays instead.
function RewardsController._drawPrizes(self: RewardsController)
	for _, tier in TimeRewards.Tiers do
		local item = if tier.cosmeticId ~= nil then CosmeticsCatalog.getItem(tier.cosmeticId) else nil

		if item ~= nil and self.owned[item.id] ~= true then
			local rarity = CosmeticsCatalog.Rarities[item.rarity]

			self.deps.hud.rewards:setGiftPrize(tier.id, {
				text = string.upper(item.displayName),
				coins = false,
				color = if rarity ~= nil then rarity.color else COIN_COLOR,
			})
		else
			self.deps.hud.rewards:setGiftPrize(tier.id, { text = ("+%d"):format(tier.coins), coins = true, color = COIN_COLOR })
		end
	end
end

function RewardsController._draw(self: RewardsController)
	local startedAt = self.startedAt

	if startedAt == nil then
		return
	end

	local played = Workspace:GetServerTimeNow() - startedAt
	local anyReady = false

	self.deps.hud.rewards:setPlayed(("PLAYED %d MIN THIS VISIT"):format(math.max(played, 0) // 60))

	for _, tier in TimeRewards.Tiers do
		local left = TimeRewards.secondsLeft(tier, played)

		if self.claimed[tier.id] == true then
			self.deps.hud.rewards:setGiftState(tier.id, "claimed", "DONE")
		elseif left <= 0 then
			anyReady = true
			self.deps.hud.rewards:setGiftState(tier.id, "ready", "CLAIM")
		else
			self.deps.hud.rewards:setGiftState(tier.id, "waiting", countdown(left))
		end
	end

	self.deps.hud.menu:setGiftReady(anyReady)
end

return RewardsController
