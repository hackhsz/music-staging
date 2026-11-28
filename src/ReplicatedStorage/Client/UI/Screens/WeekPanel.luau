--!strict
local MenuLife = require(script.Parent.Parent.MenuLife)
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "home"
local LEAGUE_ROWS = 6
local LADDER_STEPS = 3
local UPCOMING_ROWS = 2
local DAILY_ROWS = 3
local STREAK_DOTS = 7
local TRACK_COLUMNS = 6
-- How many tiers before the player's own the pass track opens on.
local TRACK_LEAD = 2
-- One view at a time, picked by the tab of the same position on the window's edge; a fresh
-- open shows the first.
local VIEWS = { "Live", "League", "Pass", "Daily", "Shop" }
-- A lit row or tile can need different text; the authored instance says which in these.
local LIT_TEXT = "LitText"
local REST_TEXT = "RestText"

export type Hero = { title: string, sticker: string?, day: string, time: string, status: string, blurb: string }
export type UpcomingRow = { day: string, title: string }
export type Player = { name: string, rank: string, coins: string, xp: string, fill: number }
export type LeagueRow = { rank: number, name: string, value: number, you: boolean }
export type League = {
	tier: string,
	place: string,
	of: string,
	rule: string,
	rows: { LeagueRow },
	-- The promotion line sits under this row; nil hides it.
	lineAfter: number?,
	gap: string,
	resets: string,
	ends: string,
	best: string,
	-- The player's tier first, then the ones above it.
	ladder: { string },
	payUp: string,
	payStay: string,
	payDown: string,
}
-- state: "claimed", "ready", "locked" (tier not reached) or "pass" (needs the pass).
export type PassCell = { name: string, icon: string, state: string }
export type PassTier = { free: PassCell, pass: PassCell }
export type Pass = {
	header: string,
	tier: string,
	points: string,
	note: string,
	fill: number,
	-- The tier the player is on; 0 before the first.
	current: number,
	tiers: { PassTier },
	button: string,
}
export type DailyRow = { name: string, progress: string, fill: number, reward: string, done: boolean }
export type Daily = { rows: { DailyRow }, done: string, streak: string, lit: number, bonus: string }
-- state: "claimed", "next" or "later".
export type ShopStep = { icon: string, price: string, state: string }
export type ShopCard = { name: string, blurb: string, price: string, icon: string, sticker: string? }
export type Shop = { title: string, steps: { ShopStep }, collected: string, fill: number, cards: { ShopCard } }

type Fields = {
	menu: MenuScreen.MenuScreen,
	window: GuiObject?,
	pass: Pass?,
	trackStart: number,
	onShop: (() -> ())?,
	onPass: (() -> ())?,
	onQuests: (() -> ())?,
	onFollow: (() -> ())?,
}

-- The This Week board, authored in StarterGui.Menu's Week. Five views: Live (the player
-- card, the league summary, the hero event, what is up next and the streak), League, Pass,
-- Daily and Shop. Drawing only; WeekController hands it each view's rows.
local WeekPanel = {}
WeekPanel.__index = WeekPanel

export type WeekPanel = typeof(setmetatable({} :: Fields, WeekPanel))

local function setText(root: Instance?, path: string, text: string)
	local label = UiKit.authored(root, path, "TextLabel")

	if label ~= nil then
		label.Text = text
	end
end

local function setImage(root: Instance?, path: string, image: string)
	local art = UiKit.authored(root, path, "ImageLabel")

	if art ~= nil then
		art.Image = image
	end
end

local function setFill(root: Instance?, path: string, share: number)
	local fill = UiKit.authored(root, path, "GuiObject")

	if fill ~= nil then
		fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end
end

local function setShown(root: Instance?, path: string, shown: boolean)
	local part = UiKit.authored(root, path, "GuiObject")

	if part ~= nil then
		part.Visible = shown
	end
end

-- Lights a row or tile and gives its labels the text colour that reads on it.
local function setLit(part: GuiObject?, lit: boolean)
	if part == nil then
		return
	end

	UiKit.setLit(part, lit)

	local color = part:GetAttribute(if lit then LIT_TEXT else REST_TEXT)

	if typeof(color) ~= "Color3" then
		return
	end

	for _, child in part:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextColor3 = color
		end
	end
end

local function bindButton(root: Instance?, path: string, callback: () -> ())
	local button = UiKit.authored(root, path, "GuiButton")

	if button ~= nil then
		UiKit.bindHover(button)
		button.Activated:Connect(callback)
	end
end

function WeekPanel.new(menu: MenuScreen.MenuScreen): WeekPanel
	local window = menu:window(WINDOW)
	local self = setmetatable({
		menu = menu,
		window = window,
		pass = nil,
		trackStart = 1,
		onShop = nil,
		onPass = nil,
		onQuests = nil,
		onFollow = nil,
	} :: Fields, WeekPanel)

	local function openShop()
		if self.onShop ~= nil then
			self.onShop()
		end
	end

	local function openPass()
		if self.onPass ~= nil then
			self.onPass()
		end
	end

	bindButton(window, "CloseButton", function()
		self:setVisible(false)
	end)
	bindButton(window, "Live.Hero.FollowButton", function()
		if self.onFollow ~= nil then
			self.onFollow()
		end
	end)
	self:setFollow(nil)
	bindButton(window, "Pass.PassButton", openPass)
	bindButton(window, "Pass.Track.OpenButton", openPass)
	bindButton(window, "Pass.PrevButton", function()
		self:_slideTrack(-1)
	end)
	bindButton(window, "Pass.NextButton", function()
		self:_slideTrack(1)
	end)
	bindButton(window, "Daily.QuestsButton", function()
		if self.onQuests ~= nil then
			self.onQuests()
		end
	end)
	bindButton(window, "Shop.OpenButton", openShop)
	bindButton(window, "Shop.Hero.OpenButton", openShop)

	for index, view in VIEWS do
		bindButton(window, "Views.Tab" .. index, function()
			self:showView(view)
		end)
	end

	self:showView(VIEWS[1])

	return self
end

function WeekPanel.showView(self: WeekPanel, name: string)
	for index, view in VIEWS do
		local card = UiKit.authored(self.window, view, "GuiObject")

		if card ~= nil then
			card.Visible = view == name

			-- An open board plays the view in; a closed one is played in by the menu as it opens.
			if view == name and self:isVisible() then
				MenuLife.enter(card)
			end
		end

		setLit(UiKit.authored(self.window, "Views.Tab" .. index, "GuiButton"), view == name)
	end
end

function WeekPanel.bindShop(self: WeekPanel, callback: () -> ())
	self.onShop = callback
end

function WeekPanel.bindPass(self: WeekPanel, callback: () -> ())
	self.onPass = callback
end

function WeekPanel.bindQuests(self: WeekPanel, callback: () -> ())
	self.onQuests = callback
end

function WeekPanel.bindFollow(self: WeekPanel, callback: () -> ())
	self.onFollow = callback
end

-- nil hides the button: there is no Roblox event to follow.
function WeekPanel.setFollow(self: WeekPanel, following: boolean?)
	local button = UiKit.authored(self.window, "Live.Hero.FollowButton", "GuiObject")

	if button ~= nil then
		button.Visible = following ~= nil
	end

	setText(button, "Label", if following == true then "FOLLOWING" else "FOLLOW EVENT")
end

function WeekPanel.isVisible(self: WeekPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function WeekPanel.setVisible(self: WeekPanel, visible: boolean)
	if visible then
		self:showView(VIEWS[1])
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function WeekPanel.toggle(self: WeekPanel)
	self:setVisible(not self:isVisible())
end

function WeekPanel.drawWeek(self: WeekPanel, label: string)
	setText(self.window, "WeekLabel", label)
end

function WeekPanel.drawPlayer(self: WeekPanel, player: Player)
	local card = UiKit.authored(self.window, "Live.Player", "GuiObject")

	setText(card, "NameLabel", player.name)
	setText(card, "RankLabel", player.rank)
	setText(card, "CoinLabel", player.coins)
	setText(card, "XpLabel", player.xp)
	setFill(card, "Bar.Fill", player.fill)
end

function WeekPanel.setAvatar(self: WeekPanel, image: string)
	setImage(self.window, "Live.Player.Avatar", image)
end

function WeekPanel.drawHero(self: WeekPanel, hero: Hero)
	local card = UiKit.authored(self.window, "Live.Hero", "GuiObject")
	local sticker = UiKit.authored(card, "SongArt.NewSticker", "GuiObject")

	setText(card, "TitleLabel", hero.title)
	setText(card, "DayLabel", hero.day)
	setText(card, "TimeLabel", hero.time)
	setText(card, "BlurbLabel", hero.blurb)
	setText(card, "StatusChip.Label", hero.status)

	if sticker ~= nil then
		sticker.Visible = hero.sticker ~= nil
		setText(sticker, "Label", hero.sticker or "")
	end
end

function WeekPanel.drawUpcoming(self: WeekPanel, rows: { UpcomingRow })
	local card = UiKit.authored(self.window, "Live.Upcoming", "GuiObject")

	for index = 1, UPCOMING_ROWS do
		local row = UiKit.child(card, "Row" .. index, "GuiObject")
		local entry = rows[index]

		if row == nil then
			continue
		end

		row.Visible = entry ~= nil

		if entry ~= nil then
			setText(row, "DayLabel", entry.day)
			setText(row, "TitleLabel", entry.title)
		end
	end
end

function WeekPanel.drawLeague(self: WeekPanel, league: League)
	local card = UiKit.authored(self.window, "League", "GuiObject")
	local summary = UiKit.authored(self.window, "Live.Summary", "GuiObject")
	local tier = string.upper(league.tier)

	setText(summary, "TierChip.Label", tier)
	setText(summary, "PlaceLabel", if league.of ~= "" then league.place .. " " .. league.of else league.place)
	setText(summary, "GapLabel", league.gap)

	setText(card, "TierChip.Label", tier)
	setText(card, "PlaceLabel", league.place)
	setText(card, "OfLabel", league.of)
	setText(card, "RuleLabel", league.rule)
	setText(card, "GapLabel", league.gap)
	setText(card, "ResetLabel", league.resets)
	setText(card, "EndsChip.Label", league.ends)
	setText(card, "BestLabel", league.best)
	setText(card, "Payouts.Up.Label", league.payUp)
	setText(card, "Payouts.Stay.Label", league.payStay)
	setText(card, "Payouts.Down.Label", league.payDown)

	for index = 1, LADDER_STEPS do
		local step = UiKit.authored(card, "Ladder.Step" .. index, "GuiObject")
		local name = league.ladder[index]

		if step ~= nil then
			step.Visible = name ~= nil
			setText(step, "Label", string.upper(name or ""))
			setLit(step, index == 1)
		end
	end

	local line = UiKit.authored(card, "PromotionLine", "GuiObject")
	local first = UiKit.authored(card, "Row1", "GuiObject")
	local second = UiKit.authored(card, "Row2", "GuiObject")

	if line ~= nil then
		line.Visible = league.lineAfter ~= nil and league.lineAfter < #league.rows

		-- Rows are evenly spaced, so the line sits halfway between its row and the next.
		if league.lineAfter ~= nil and first ~= nil and second ~= nil then
			local step = second.Position.Y.Scale - first.Position.Y.Scale
			local y = first.Position.Y.Scale + step * league.lineAfter - (step - first.Size.Y.Scale) / 2
			line.Position = UDim2.fromScale(line.Position.X.Scale, y)
		end
	end

	for index = 1, LEAGUE_ROWS do
		local row = UiKit.authored(card, "Row" .. index, "GuiObject")
		local entry = league.rows[index]

		if row == nil then
			continue
		end

		row.Visible = entry ~= nil

		if entry ~= nil then
			setText(row, "RankLabel", tostring(entry.rank))
			setText(row, "NameLabel", string.upper(entry.name))
			setText(row, "ValueLabel", tostring(entry.value))
			setLit(row, entry.you)
		end
	end
end

function WeekPanel._drawCell(_self: WeekPanel, cell: GuiObject?, reward: PassCell?)
	if cell == nil then
		return
	end

	cell.Visible = reward ~= nil

	if reward == nil then
		return
	end

	setText(cell, "NameLabel", reward.name)
	setImage(cell, "Icon", reward.icon)
	setShown(cell, "Check", reward.state == "claimed")
	setShown(cell, "Claim", reward.state == "ready")
	setShown(cell, "Lock", reward.state == "pass")
end

function WeekPanel._drawTrack(self: WeekPanel)
	local pass = self.pass
	local track = UiKit.authored(self.window, "Pass.Track", "GuiObject")

	if pass == nil or track == nil then
		return
	end

	for column = 1, TRACK_COLUMNS do
		local tier = self.trackStart + column - 1
		local entry = pass.tiers[tier]
		local slot = UiKit.authored(track, "Col" .. column, "GuiObject")

		if slot == nil then
			continue
		end

		slot.Visible = entry ~= nil

		if entry ~= nil then
			setText(slot, "NumberLabel", if tier == pass.current then ("%d · YOU"):format(tier) else tostring(tier))
			setLit(slot, tier == pass.current)
			self:_drawCell(UiKit.authored(slot, "Free", "GuiObject"), entry.free)
			self:_drawCell(UiKit.authored(slot, "Pass", "GuiObject"), entry.pass)
		end
	end
end

function WeekPanel._slideTrack(self: WeekPanel, by: number)
	local pass = self.pass

	if pass == nil then
		return
	end

	self.trackStart = math.clamp(self.trackStart + by, 1, math.max(#pass.tiers - TRACK_COLUMNS + 1, 1))
	self:_drawTrack()
end

function WeekPanel.drawPass(self: WeekPanel, pass: Pass)
	local card = UiKit.authored(self.window, "Pass", "GuiObject")
	local moved = self.pass == nil or self.pass.current ~= pass.current

	setText(card, "Header", pass.header)
	setText(card, "TierLabel", pass.tier)
	setText(card, "PointsLabel", pass.points)
	setText(card, "NoteLabel", pass.note)
	setFill(card, "Bar.Fill", pass.fill)
	setText(card, "PassButton.Label", pass.button)

	self.pass = pass

	-- The window follows the player's tier, but not a scroll they made themselves.
	if moved then
		self.trackStart = math.clamp(pass.current - TRACK_LEAD, 1, math.max(#pass.tiers - TRACK_COLUMNS + 1, 1))
	end

	self:_drawTrack()
end

function WeekPanel.drawDaily(self: WeekPanel, daily: Daily)
	local card = UiKit.authored(self.window, "Daily", "GuiObject")
	local strip = UiKit.authored(self.window, "Live.Streak", "GuiObject")

	setText(strip, "Bonus.ValueLabel", daily.bonus)
	setText(strip, "Streak.ValueLabel", daily.streak)
	setText(card, "DoneLabel", daily.done)
	setText(card, "Streak.ValueLabel", daily.streak)
	setText(card, "Bonus.ValueLabel", daily.bonus)

	for index = 1, STREAK_DOTS do
		setLit(UiKit.authored(card, "Streak.Dot" .. index, "GuiObject"), index <= daily.lit)
	end

	for index = 1, DAILY_ROWS do
		local row = UiKit.authored(card, "Row" .. index, "GuiObject")
		local entry = daily.rows[index]

		if row == nil then
			continue
		end

		row.Visible = entry ~= nil

		if entry ~= nil then
			setText(row, "NameLabel", string.upper(entry.name))
			setText(row, "ProgressLabel", entry.progress)
			setText(row, "RewardLabel", entry.reward)
			setFill(row, "Bar.Fill", entry.fill)
			setShown(row, "DoneMark", entry.done)
		end
	end
end

function WeekPanel.drawReset(self: WeekPanel, text: string)
	setText(self.window, "Daily.ResetChip.Label", text)
end

function WeekPanel.drawShop(self: WeekPanel, shop: Shop)
	local card = UiKit.authored(self.window, "Shop", "GuiObject")
	local hero = UiKit.authored(card, "Hero", "GuiObject")

	setText(hero, "TitleLabel", shop.title)
	setText(hero, "CollectedLabel", shop.collected)
	setFill(hero, "Bar.Fill", shop.fill)

	for index, step in shop.steps do
		local slot = UiKit.child(hero, "Step" .. index, "GuiObject")

		if slot ~= nil then
			setImage(slot, "Icon", step.icon)
			setText(slot, "PriceLabel", step.price)
			setShown(slot, "Check", step.state == "claimed")
			setShown(slot, "NextTag", step.state == "next")
			setLit(slot, step.state == "next")
		end
	end

	local index = 1

	while true do
		local slot = UiKit.child(card, "Card" .. index, "GuiObject")

		if slot == nil then
			break
		end

		local entry = shop.cards[index]

		slot.Visible = entry ~= nil

		if entry ~= nil then
			setImage(slot, "Icon", entry.icon)
			setText(slot, "NameLabel", entry.name)
			setText(slot, "BlurbLabel", entry.blurb)
			setText(slot, "Price.Label", entry.price)
			setShown(slot, "Sticker", entry.sticker ~= nil)
			setText(slot, "Sticker.Label", entry.sticker or "")
		end

		index += 1
	end
end

return WeekPanel
