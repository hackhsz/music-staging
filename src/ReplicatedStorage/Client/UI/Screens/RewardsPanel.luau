--!strict

local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "rewards"
local OK_COLOR = Color3.fromRGB(120, 235, 150)
local FAIL_COLOR = Color3.fromRGB(255, 110, 130)
local CLAIMED_DIM = 0.55

export type GiftState = "waiting" | "ready" | "claimed"
export type GiftSpec = { id: string, timeText: string, glyph: string, icon: string? }
-- coins is false for a gift that is an item, which hides the coin icon.
export type GiftPrize = { text: string, coins: boolean, color: Color3 }

type Tile = { frame: GuiObject, claimButton: GuiButton?, claimLabel: TextLabel?, state: GiftState }

type Fields = {
	menu: MenuScreen.MenuScreen,
	played: TextLabel?,
	gifts: GuiObject?,
	template: GuiObject?,
	tiles: { [string]: Tile },
	codeBox: TextBox?,
	codeResult: TextLabel?,
	onRedeem: ((code: string) -> ())?,
	onClaim: ((giftId: string) -> ())?,
}

-- The Rewards window, authored in StarterGui.Menu's Rewards: the play-time gifts
-- (Gifts, one tile per gift from Templates.GiftTile unless one is authored under
-- the gift's id) and the code box. Drawing and taps only; RewardsController asks
-- the server for each claim.
local RewardsPanel = {}
RewardsPanel.__index = RewardsPanel

export type RewardsPanel = typeof(setmetatable({} :: Fields, RewardsPanel))

function RewardsPanel.new(menu: MenuScreen.MenuScreen): RewardsPanel
	local window = menu:window(WINDOW)

	local fields: Fields = {
		menu = menu,
		played = UiKit.authored(window, "PlayedChip.Label", "TextLabel"),
		gifts = UiKit.authored(window, "Gifts", "GuiObject"),
		template = UiKit.authored(window, "Templates.GiftTile", "GuiObject"),
		tiles = {},
		codeBox = UiKit.authored(window, "CodeField.CodeBox", "TextBox"),
		codeResult = UiKit.authored(window, "CodeResult", "TextLabel"),
		onRedeem = nil,
		onClaim = nil,
	}
	local self = setmetatable(fields, RewardsPanel)
	local redeem = UiKit.authored(window, "RedeemButton", "GuiButton")

	local function submit()
		local box = self.codeBox

		if box ~= nil and box.Text ~= "" and self.onRedeem ~= nil then
			self.onRedeem(box.Text)
		end
	end

	if redeem ~= nil then
		UiKit.bindHover(redeem)
		redeem.Activated:Connect(submit)
	end

	if fields.codeBox ~= nil then
		fields.codeBox.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed then
				submit()
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

	self:setCodeResult("", true)

	return self
end

function RewardsPanel.isVisible(self: RewardsPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function RewardsPanel.setVisible(self: RewardsPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function RewardsPanel.bindRedeem(self: RewardsPanel, callback: (code: string) -> ())
	self.onRedeem = callback
end

function RewardsPanel.bindClaim(self: RewardsPanel, callback: (giftId: string) -> ())
	self.onClaim = callback
end

-- How long this visit has run, which is what the gifts count from.
function RewardsPanel.setPlayed(self: RewardsPanel, text: string)
	if self.played ~= nil then
		self.played.Text = text
	end
end

function RewardsPanel.setCodeResult(self: RewardsPanel, text: string, ok: boolean)
	if self.codeResult ~= nil then
		self.codeResult.Text = text
		self.codeResult.TextColor3 = if ok then OK_COLOR else FAIL_COLOR
	end

	if ok and text ~= "" and self.codeBox ~= nil then
		self.codeBox.Text = ""
	end
end

-- One tile per gift, in order; called once with the catalog.
function RewardsPanel.setGifts(self: RewardsPanel, specs: { GiftSpec })
	local gifts = self.gifts

	if gifts == nil then
		return
	end

	for order, spec in specs do
		local authored = gifts:FindFirstChild(spec.id)
		local frame: GuiObject? = if authored ~= nil and authored:IsA("GuiObject") then authored else nil

		if frame == nil and self.template ~= nil then
			frame = self.template:Clone()
			frame.Name = spec.id
			frame.LayoutOrder = order
			frame.Visible = true
			frame.Parent = gifts
		end

		if frame == nil then
			continue
		end

		local timeLabel = UiKit.child(frame, "TimeLabel", "TextLabel")
		local glyph = UiKit.child(UiKit.child(frame, "IconTile", "GuiObject"), "Glyph", "TextLabel")
		local claim = UiKit.child(frame, "ClaimButton", "GuiButton")

		if timeLabel ~= nil then
			timeLabel.Text = spec.timeText
		end

		UiKit.setIcon(glyph, spec.glyph, spec.icon)

		self.tiles[spec.id] = {
			frame = frame,
			claimButton = claim,
			claimLabel = UiKit.child(claim, "ClaimLabel", "TextLabel"),
			state = "waiting",
		}

		local function tryClaim()
			local tile = self.tiles[spec.id]

			if tile.state == "waiting" then
				UiKit.playSound("uiDenied")
			elseif tile.state == "ready" and self.onClaim ~= nil then
				-- Until the server answers; the next redraw puts it back if the claim failed.
				tile.state = "claimed"
				self.onClaim(spec.id)
			end
		end

		if claim ~= nil then
			UiKit.bindHover(claim)
			claim.Activated:Connect(tryClaim)
		end

		-- The pill is small on a phone, so a tap anywhere on a ready tile claims it.
		frame.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch and self.tiles[spec.id].state == "ready" then
				tryClaim()
			end
		end)
	end
end

function RewardsPanel.setGiftPrize(self: RewardsPanel, id: string, prize: GiftPrize)
	local tile = self.tiles[id]

	if tile == nil then
		return
	end

	local rewardLabel = UiKit.child(tile.frame, "RewardLabel", "TextLabel")
	local coin = UiKit.child(tile.frame, "CoinIcon", "GuiObject")

	if rewardLabel ~= nil then
		rewardLabel.Text = prize.text
		rewardLabel.TextColor3 = prize.color
	end

	if coin ~= nil then
		coin.Visible = prize.coins
	end
end

-- label is the countdown while waiting; ready shows CLAIM and claimed DONE.
function RewardsPanel.setGiftState(self: RewardsPanel, id: string, state: GiftState, label: string)
	local tile = self.tiles[id]

	if tile == nil then
		return
	end

	tile.state = state

	if tile.claimLabel ~= nil then
		tile.claimLabel.Text = label
	end

	if tile.claimButton ~= nil then
		UiKit.setLit(tile.claimButton, state == "ready")
	end

	UiKit.setLit(tile.frame, state == "ready")

	local tick = UiKit.child(tile.frame, "Tick", "GuiObject")
	local lock = UiKit.child(tile.frame, "Lock", "GuiObject")
	local art = UiKit.child(tile.frame, "Art", "ImageLabel")

	if tick ~= nil then
		tick.Visible = state == "claimed"
	end

	if lock ~= nil then
		lock.Visible = state == "waiting"
	end

	if art ~= nil then
		art.ImageTransparency = if state == "claimed" then CLAIMED_DIM else 0
	end
end

return RewardsPanel
