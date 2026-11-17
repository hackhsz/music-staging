--!strict
local CollectionService = game:GetService("CollectionService")

local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "community"
local READY_TAG = "Primary"
-- The authored rows are named after the SocialRewards action they claim.
local SOCIAL_ROWS = { like = "Like", favorite = "Favorite", community = "Community" }

export type Social = { id: string, rewardText: string, claimed: boolean }
export type Gift = { ready: boolean, rewardText: string, stateText: string }

type SocialRow = { claimButton: GuiButton?, claimLabel: TextLabel?, reward: TextLabel? }

type Fields = {
	menu: MenuScreen.MenuScreen,
	socialRows: { [string]: SocialRow },
	socials: { [string]: Social },
	giftButton: GuiButton?,
	giftLabel: TextLabel?,
	giftReward: TextLabel?,
	giftState: TextLabel?,
	giftReady: boolean,
	groupPerks: TextLabel?,
	onClaim: ((socialId: string) -> ())?,
	onGift: (() -> ())?,
}

-- The Community window, authored in StarterGui.Menu's Community: the thank-you coin
-- rows (Socials' Like, Favorite and Community, with GroupPerks under them) and the
-- daily gift card. Drawing and taps only; CommunityController sends the claims.
local CommunityPanel = {}
CommunityPanel.__index = CommunityPanel

export type CommunityPanel = typeof(setmetatable({} :: Fields, CommunityPanel))

local function paintReady(button: GuiButton?, ready: boolean)
	if button == nil then
		return
	elseif ready then
		CollectionService:AddTag(button, READY_TAG)
	else
		CollectionService:RemoveTag(button, READY_TAG)
	end
end

function CommunityPanel.new(menu: MenuScreen.MenuScreen): CommunityPanel
	local window = menu:window(WINDOW)
	local socials = UiKit.authored(window, "Socials", "GuiObject")

	local fields: Fields = {
		menu = menu,
		socialRows = {},
		socials = {},
		giftButton = UiKit.authored(window, "GiftCard.GiftButton", "GuiButton"),
		giftLabel = UiKit.authored(window, "GiftCard.GiftButton.GiftLabel", "TextLabel"),
		giftReward = UiKit.authored(window, "GiftCard.GiftReward", "TextLabel"),
		giftState = UiKit.authored(window, "GiftCard.GiftState", "TextLabel"),
		giftReady = false,
		groupPerks = UiKit.authored(window, "GroupPerks", "TextLabel"),
		onClaim = nil,
		onGift = nil,
	}
	local self = setmetatable(fields, CommunityPanel)

	for id, rowName in SOCIAL_ROWS do
		local row = UiKit.authored(socials, rowName, "GuiObject")
		local claim = UiKit.child(row, "ClaimButton", "GuiButton")

		fields.socialRows[id] = {
			claimButton = claim,
			claimLabel = UiKit.child(claim, "ClaimLabel", "TextLabel"),
			reward = UiKit.child(row, "RewardLabel", "TextLabel"),
		}

		if claim ~= nil then
			UiKit.bindHover(claim)
			claim.Activated:Connect(function()
				local social = self.socials[id]

				if social == nil or social.claimed then
					UiKit.playSound("uiDenied")
				elseif self.onClaim ~= nil then
					self.onClaim(id)
				end
			end)
		end
	end

	local gift = fields.giftButton

	if gift ~= nil then
		UiKit.bindHover(gift)
		gift.Activated:Connect(function()
			if not self.giftReady then
				UiKit.playSound("uiDenied")
			elseif self.onGift ~= nil then
				self.onGift()
			end
		end)
	end

	local close = UiKit.authored(window, "CloseButton", "GuiButton")

	if close ~= nil then
		UiKit.bindHover(close)
		close.Activated:Connect(function()
			menu:close(WINDOW)
		end)
	end

	return self
end

function CommunityPanel.isVisible(self: CommunityPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function CommunityPanel.setVisible(self: CommunityPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function CommunityPanel.bindClaim(self: CommunityPanel, callback: (socialId: string) -> ())
	self.onClaim = callback
end

function CommunityPanel.bindGift(self: CommunityPanel, callback: () -> ())
	self.onGift = callback
end

function CommunityPanel.renderSocials(self: CommunityPanel, socials: { Social })
	self.socials = {}

	for _, social in socials do
		self.socials[social.id] = social

		local row = self.socialRows[social.id]

		if row == nil then
			continue
		end

		if row.reward ~= nil then
			row.reward.Text = social.rewardText
		end

		if row.claimLabel ~= nil then
			row.claimLabel.Text = if social.claimed then "DONE" else "CLAIM"
		end

		paintReady(row.claimButton, not social.claimed)
	end
end

function CommunityPanel.setGroupPerks(self: CommunityPanel, text: string)
	if self.groupPerks ~= nil then
		self.groupPerks.Text = text
	end
end

function CommunityPanel.renderGift(self: CommunityPanel, gift: Gift)
	self.giftReady = gift.ready

	if self.giftReward ~= nil then
		self.giftReward.Text = gift.rewardText
	end

	if self.giftState ~= nil then
		self.giftState.Text = gift.stateText
	end

	if self.giftLabel ~= nil then
		self.giftLabel.Text = if gift.ready then "OPEN" else "WAIT"
	end

	paintReady(self.giftButton, gift.ready)
end

return CommunityPanel
