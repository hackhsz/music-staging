--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "stagePass"
local COIN_ICON = "rbxassetid://90381087302472"
local DIM_TRANSPARENCY = 0.55
local CLAIMED_TRANSPARENCY = 0.35
local TIERS_BEFORE_CURRENT = 2
local MAX_WEEKS = 6
local ROW_NAMES = { free = "FREE", pass = "PASS" }
-- What the preview's button says for a reward that cannot be claimed yet.
local STATE_TEXT = { claimed = "CLAIMED", pass = "NEEDS THE PASS" }
-- The window's pop-in scales it for this long; the scroll waits so the canvas is measured at rest.
local OPEN_SETTLE_SECONDS = 0.35
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

type Fields = {
	menu: MenuScreen.MenuScreen,
	window: GuiObject?,
	track: ScrollingFrame?,
	template: GuiObject?,
	columns: { GuiObject },
	onClaim: ((tier: number, row: string) -> ())?,
	onUnlock: (() -> ())?,
	unlockText: string,
	unlockOpen: boolean,
	passOwned: boolean,
	lastTier: number,
	snapshot: any,
	-- The reward in the preview; nil until the first snapshot picks one.
	pickedTier: number?,
	pickedRow: string,
}

-- The Stage Pass window, authored in StarterGui.Menu's Pass: the season line and its weeks,
-- the tier bar, a column per tier with its free and pass reward, and a preview of the tapped
-- reward with its claim button. Drawing only; StagePassController feeds it the server's
-- snapshot and sends the claims.
local StagePassPanel = {}
StagePassPanel.__index = StagePassPanel

export type StagePassPanel = typeof(setmetatable({} :: Fields, StagePassPanel))

local function setText(root: Instance?, path: string, text: string)
	local label = UiKit.authored(root, path, "TextLabel")

	if label ~= nil then
		label.Text = text
	end
end

local function withCommas(value: number): string
	local formatted, count = tostring(math.floor(value)), 0

	repeat
		formatted, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return formatted
end

local function rewardLook(reward: any): (string, string)
	if reward.kind == "coins" then
		return COIN_ICON, ("+%s COINS"):format(withCommas(reward.amount or 0))
	end

	local item = CosmeticsCatalog.getItem(reward.cosmeticId)

	if item == nil then
		return "", "REWARD"
	end

	return item.icon or "", string.upper(item.displayName)
end

function StagePassPanel.new(menu: MenuScreen.MenuScreen): StagePassPanel
	local window = menu:window(WINDOW)
	local track = UiKit.authored(window, "Track", "ScrollingFrame")
	local template = UiKit.authored(track, "ColumnTemplate", "GuiObject")

	if template ~= nil then
		template.Visible = false
	end

	local self = setmetatable({
		menu = menu,
		window = window,
		track = track,
		template = template,
		columns = {},
		onClaim = nil,
		onUnlock = nil,
		unlockText = "UNLOCK PASS · COMING SOON",
		unlockOpen = false,
		passOwned = false,
		lastTier = -1,
		snapshot = nil,
		pickedTier = nil,
		pickedRow = "free",
	} :: Fields, StagePassPanel)

	local claim = UiKit.authored(window, "Preview.ClaimButton", "GuiButton")

	if claim ~= nil then
		UiKit.bindHover(claim)
		claim.Activated:Connect(function()
			local entry = self:_picked()

			if entry ~= nil and entry[self.pickedRow .. "State"] == "ready" and self.onClaim ~= nil then
				self.onClaim(entry.tier, self.pickedRow)
			else
				UiKit.playSound("uiDenied")
			end
		end)
	end

	local unlock = UiKit.authored(window, "UnlockButton", "ImageButton")

	if unlock ~= nil then
		UiKit.bindHover(unlock)
		unlock.Activated:Connect(function()
			if self.unlockOpen and not self.passOwned and self.onUnlock ~= nil then
				self.onUnlock()
			else
				UiKit.playSound("uiDenied")
			end
		end)
	end

	local close = UiKit.authored(window, "CloseButton", "GuiButton")

	if close ~= nil then
		UiKit.bindHover(close)
		close.Activated:Connect(function()
			self:setVisible(false)
		end)
	end

	return self
end

function StagePassPanel.bindClaim(self: StagePassPanel, callback: (tier: number, row: string) -> ())
	self.onClaim = callback
end

function StagePassPanel.bindUnlock(self: StagePassPanel, callback: () -> ())
	self.onUnlock = callback
end

-- The unlock button's price and whether it can be pressed; the pass row's purchase.
function StagePassPanel.setUnlockOffer(self: StagePassPanel, robux: number, onSale: boolean)
	self.unlockOpen = onSale
	self.unlockText = if onSale then ("UNLOCK PASS · R$ %d"):format(robux) else "UNLOCK PASS · COMING SOON"
end

function StagePassPanel.isVisible(self: StagePassPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function StagePassPanel.setVisible(self: StagePassPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
		task.delay(OPEN_SETTLE_SECONDS, function()
			self:_scrollToCurrent()
		end)
	else
		self.menu:close(WINDOW)
	end
end

function StagePassPanel.update(self: StagePassPanel, snapshot: any)
	local window = self.window

	if window == nil or type(snapshot) ~= "table" or type(snapshot.tiers) ~= "table" then
		return
	end

	local nextTier = math.min(snapshot.tier + 1, #snapshot.tiers)
	local intoTier = snapshot.points - snapshot.tier * snapshot.pointsPerTier
	local maxed = snapshot.tier >= #snapshot.tiers
	local fill = UiKit.authored(window, "TierCard.Bar.Fill", "GuiObject")

	local ends = os.date("!*t", snapshot.endsUtc) :: any

	setText(
		window,
		"SeasonLabel",
		("%s · ENDS %s %d %s"):format(
			snapshot.seasonName,
			WEEKDAYS[ends.wday],
			ends.day,
			MONTHS[ends.month]
		)
	)
	setText(window, "TierCard.TierLabel", ("TIER %d"):format(snapshot.tier))
	setText(window, "TierCard.OfLabel", ("OF %d"):format(#snapshot.tiers))

	for week = 1, MAX_WEEKS do
		local marker = UiKit.child(UiKit.authored(window, "Weeks", "GuiObject"), "Week" .. week, "GuiObject")

		if marker ~= nil then
			marker.Visible = week <= snapshot.weeks
			UiKit.setLit(marker, week == snapshot.week)
		end
	end

	local last = snapshot.tiers[#snapshot.tiers]
	local looks, coins = 0, 0

	for _, entry in snapshot.tiers do
		if entry.pass.kind == "coins" then
			coins += entry.pass.amount or 0
		else
			looks += 1
		end
	end

	if last ~= nil then
		local icon, name = rewardLook(last.pass)
		local art = UiKit.authored(window, "TierCard.FinalIcon", "ImageLabel")

		if art ~= nil then
			art.Image = icon
		end

		setText(window, "TierCard.FinalLabel", ("TIER %d · %s"):format(last.tier, name))
	end

	setText(window, "SummaryLabel", ("PASS ROW: %d LOOKS + %s COINS"):format(looks, withCommas(coins)))
	setText(
		window,
		"TierCard.PointsLabel",
		if maxed
			then "EVERY TIER REACHED"
			else ("%s / %s POINTS TO TIER %d"):format(withCommas(intoTier), withCommas(snapshot.pointsPerTier), nextTier)
	)
	setText(window, "TierCard.RuleLabel", ("+%d points for every finished song."):format(snapshot.pointsPerSong))
	setText(
		window,
		"UnlockButton.Label",
		if snapshot.passOwned then "PASS UNLOCKED" else self.unlockText
	)

	if fill ~= nil then
		fill.Size = UDim2.fromScale(if maxed then 1 else math.clamp(intoTier / snapshot.pointsPerTier, 0, 1), 1)
	end

	local unlock = UiKit.authored(window, "UnlockButton", "ImageButton")

	if unlock ~= nil then
		UiKit.setButtonEnabled(unlock, self.unlockOpen and not snapshot.passOwned)
	end

	self.passOwned = snapshot.passOwned == true
	self.snapshot = snapshot

	if self.pickedTier == nil then
		self.pickedTier, self.pickedRow = self:_firstPick(snapshot)
	end

	self:_drawColumns(snapshot)
	self:_drawPreview()

	if snapshot.tier ~= self.lastTier then
		self.lastTier = snapshot.tier
		self:_scrollToCurrent()
	end
end

function StagePassPanel._drawColumns(self: StagePassPanel, snapshot: any)
	local track, template = self.track, self.template

	if track == nil or template == nil then
		return
	end

	for _, column in self.columns do
		column:Destroy()
	end

	self.columns = {}

	for _, entry in snapshot.tiers do
		local column = template:Clone()
		local current = entry.tier == math.max(snapshot.tier, 1)

		column.Name = "Tier" .. entry.tier
		column.LayoutOrder = entry.tier
		column.Visible = true
		setText(column, "TierNumber", if current then ("%d · YOU"):format(entry.tier) else tostring(entry.tier))

		local glow = UiKit.authored(column, "CurrentGlow", "GuiObject")

		if glow ~= nil then
			glow.Visible = current
		end

		self:_drawCard(UiKit.authored(column, "Free", "GuiButton"), entry.free, entry.freeState, entry.tier, "free")
		self:_drawCard(UiKit.authored(column, "Pass", "GuiButton"), entry.pass, entry.passState, entry.tier, "pass")
		column.Parent = track
		table.insert(self.columns, column)
	end
end

function StagePassPanel._drawCard(self: StagePassPanel, card: GuiButton?, reward: any, state: string, tier: number, row: string)
	if card == nil then
		return
	end

	local icon, name = rewardLook(reward)
	local art = UiKit.authored(card, "Icon", "ImageLabel")
	local ready = state == "ready"

	if art ~= nil then
		art.Image = icon
		art.ImageTransparency = if state == "claimed" then CLAIMED_TRANSPARENCY elseif ready then 0 else DIM_TRANSPARENCY
	end

	setText(card, "NameLabel", name)

	for _, part in { "Claim", "Tick", "Lock" } do
		local mark = UiKit.authored(card, part, "GuiObject")

		if mark ~= nil then
			mark.Visible = (part == "Claim" and ready)
				or (part == "Tick" and state == "claimed")
				or (part == "Lock" and (state == "locked" or state == "pass"))
		end
	end

	UiKit.setLit(card, ready)

	local pick = UiKit.child(card, "Pick", "GuiObject")

	if pick ~= nil then
		pick.Visible = tier == self.pickedTier and row == self.pickedRow
	end

	UiKit.bindHover(card)
	card.Activated:Connect(function()
		self.pickedTier, self.pickedRow = tier, row
		self:_markPicked()
		self:_drawPreview()
	end)
end

-- The preview opens on something worth claiming, else on the player's own tier.
function StagePassPanel._firstPick(_self: StagePassPanel, snapshot: any): (number, string)
	for _, entry in snapshot.tiers do
		for _, row in { "free", "pass" } do
			if entry[row .. "State"] == "ready" then
				return entry.tier, row
			end
		end
	end

	return math.max(snapshot.tier, 1), "free"
end

function StagePassPanel._picked(self: StagePassPanel): any
	local snapshot = self.snapshot

	return if snapshot ~= nil and self.pickedTier ~= nil then snapshot.tiers[self.pickedTier] else nil
end

function StagePassPanel._markPicked(self: StagePassPanel)
	for index, column in self.columns do
		for row, name in { free = "Free", pass = "Pass" } do
			local pick = UiKit.child(UiKit.child(column, name, "GuiObject"), "Pick", "GuiObject")

			if pick ~= nil then
				pick.Visible = index == self.pickedTier and row == self.pickedRow
			end
		end
	end
end

function StagePassPanel._drawPreview(self: StagePassPanel)
	local entry = self:_picked()
	local preview = UiKit.authored(self.window, "Preview", "GuiObject")

	if entry == nil or preview == nil then
		return
	end

	local row = self.pickedRow
	local state = entry[row .. "State"]
	local icon, name = rewardLook(entry[row])
	local art = UiKit.authored(preview, "Icon", "ImageLabel")

	if art ~= nil then
		art.Image = icon
	end

	setText(preview, "NameLabel", name)
	setText(preview, "RowChip.Label", ("%s · TIER %d"):format(ROW_NAMES[row] or "", entry.tier))
	setText(
		preview,
		"ClaimButton.Label",
		if state == "ready" then "CLAIM" else STATE_TEXT[state] or ("REACH TIER %d"):format(entry.tier)
	)
	UiKit.setLit(UiKit.authored(preview, "ClaimButton", "GuiObject"), state == "ready")
end

-- Keeps the player's tier in view with two earlier tiers beside it. Worked out as a share of
-- the canvas, so the window's open animation scaling it does not throw the position off.
function StagePassPanel._scrollToCurrent(self: StagePassPanel)
	local track = self.track
	local count = #self.columns

	if track == nil or count == 0 then
		return
	end

	local first = math.max(self.lastTier - TIERS_BEFORE_CURRENT, 1)
	local canvas = track.AbsoluteCanvasSize.X
	local most = math.max(canvas - track.AbsoluteWindowSize.X, 0)

	track.CanvasPosition = Vector2.new(math.clamp((first - 1) / count * canvas, 0, most), 0)
end

return StagePassPanel
