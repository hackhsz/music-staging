--!strict
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local EasterEggs = require(Catalogs:WaitForChild("EasterEggs"))
local SocialRewards = require(Catalogs:WaitForChild("SocialRewards"))
local CommunityPanel = require(script.Parent.Parent.UI.Screens.CommunityPanel)
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

local GIFT_ITEM_ID = "daily-lightstick-glow"
local GIFT_REFRESH_SECONDS = 30

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	sfx: any,
}

type Fields = {
	deps: Deps,
	claimed: { [string]: boolean },
	cooldowns: { [string]: number },
}

-- The Community window: the thank-you coins for liking, favouriting and joining the
-- group, and the daily gift. The server pays every one of them; this only asks.
local CommunityController = {}
CommunityController.__index = CommunityController

export type CommunityController = typeof(setmetatable({} :: Fields, CommunityController))

function CommunityController.new(deps: Deps): CommunityController
	return setmetatable({ deps = deps, claimed = {}, cooldowns = {} } :: Fields, CommunityController)
end

local function giftItem(): any
	return EasterEggs.getItem(GIFT_ITEM_ID)
end

local function waitText(seconds: number): string
	return ("NEXT GIFT IN %dH %02dM"):format(seconds // 3600, (seconds % 3600) // 60)
end

function CommunityController.start(self: CommunityController)
	local deps = self.deps
	local community = deps.hud.community

	deps.hud.menu:bindCommunity(function()
		if community:isVisible() then
			community:setVisible(false)
		else
			self:open()
		end
	end)
	community:bindClaim(function(socialId: string)
		deps.remotes.ClaimReward:FireServer({ rewardId = "social:" .. socialId })
		Telemetry.track("social_reward_requested", socialId)
	end)
	community:bindGift(function()
		local item = giftItem()

		if item ~= nil then
			deps.remotes.ClaimReward:FireServer({ rewardId = item.rewardId })
		end
	end)

	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		if type(payload) ~= "table" then
			return
		end

		self.claimed = if type(payload.claimedRewards) == "table" then payload.claimedRewards else {}
		self.cooldowns = if type(payload.rewardCooldowns) == "table" then payload.rewardCooldowns else {}
		self:_draw()
	end)
	deps.remotes.PurchaseResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or payload.kind ~= "reward" then
			return
		end

		if payload.reason == "not_in_group" then
			CommunityController._promptJoinGroup()
		elseif type(payload.itemId) == "string" and self:_isMine(payload.itemId) then
			deps.sfx:play(if payload.ok == true then "uiBuy" else "uiDenied")
		end
	end)

	community:setGroupPerks(table.concat(SocialRewards.GroupPerks, "  /  "))

	task.spawn(function()
		while true do
			task.wait(GIFT_REFRESH_SECONDS)
			self:_draw()
		end
	end)
end

-- Roblox's own join prompt; the player claims again once they have joined.
function CommunityController._promptJoinGroup()
	local groupId = SocialRewards.GroupId

	if groupId == nil then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			GroupService:PromptJoinAsync(groupId)
		end)

		if not ok then
			warn("[DanceDanceStep] Group join prompt failed: " .. tostring(err))
		end
	end)
end

function CommunityController._isMine(_self: CommunityController, rewardId: string): boolean
	local item = giftItem()

	return SocialRewards.getAction(rewardId) ~= nil or (item ~= nil and item.rewardId == rewardId)
end

function CommunityController.open(self: CommunityController)
	self:_draw()
	self.deps.hud.community:setVisible(true)
end

function CommunityController._draw(self: CommunityController)
	local socials: { CommunityPanel.Social } = {}

	for _, action in SocialRewards.Actions do
		table.insert(socials, {
			id = action.id,
			rewardText = ("+%d"):format(action.rewardSoftCurrency or 0),
			claimed = self.claimed["social:" .. action.id] == true,
		})
	end

	self.deps.hud.community:renderSocials(socials)

	local item = giftItem()

	if item == nil then
		return
	end

	local readyAt = tonumber(self.cooldowns[item.rewardId]) or 0
	local left = math.ceil(readyAt - Workspace:GetServerTimeNow())

	self.deps.hud.menu:setCommunityReady(left <= 0)
	self.deps.hud.community:renderGift({
		ready = left <= 0,
		rewardText = ("+%d COINS EVERY DAY, %dX IN THE GROUP"):format(
			item.rewardSoftCurrency or 0,
			SocialRewards.GroupDailyGiftMultiplier
		),
		stateText = if left <= 0 then "READY TO OPEN" else waitText(left),
	})
end

return CommunityController
