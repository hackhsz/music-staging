--!strict
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "home"
local DAILY_ROWS = 3
local LEAGUE_ROWS = 6

export type LiveShow = { day: string, time: string, status: string, blurb: string }
export type DailyRow = { name: string, value: number, target: number, done: boolean }
export type ShopPick = { name: string, icon: string, price: string }
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
}
export type Pass = { header: string, tier: string, week: string, fill: number, freeName: string, freeIcon: string, passName: string, passIcon: string }

type Fields = {
	menu: MenuScreen.MenuScreen,
	window: GuiObject?,
	onShop: (() -> ())?,
	onPass: (() -> ())?,
	onFollow: (() -> ())?,
}

-- The This Week board, authored in StarterGui.Menu's Week: the Saturday Live Show, today's
-- challenges, what is new in the shop, the weekly league and the Stage Pass. Drawing only;
-- WeekController hands it each card's rows.
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
		onShop = nil,
		onPass = nil,
		onFollow = nil,
	} :: Fields, WeekPanel)

	bindButton(window, "CloseButton", function()
		self:setVisible(false)
	end)
	bindButton(window, "Shop.ShopButton", function()
		if self.onShop ~= nil then
			self.onShop()
		end
	end)
	bindButton(window, "LiveShow.FollowButton", function()
		if self.onFollow ~= nil then
			self.onFollow()
		end
	end)
	self:setFollow(nil)
	bindButton(window, "Pass.PassButton", function()
		if self.onPass ~= nil then
			self.onPass()
		end
	end)

	return self
end

function WeekPanel.bindShop(self: WeekPanel, callback: () -> ())
	self.onShop = callback
end

function WeekPanel.bindPass(self: WeekPanel, callback: () -> ())
	self.onPass = callback
end

function WeekPanel.bindFollow(self: WeekPanel, callback: () -> ())
	self.onFollow = callback
end

-- nil hides the button: there is no Roblox event to follow.
function WeekPanel.setFollow(self: WeekPanel, following: boolean?)
	local button = UiKit.authored(self.window, "LiveShow.FollowButton", "GuiObject")

	if button ~= nil then
		button.Visible = following ~= nil
	end

	setText(button, "Label", if following == true then "FOLLOWING ✓" else "FOLLOW EVENT")
end

function WeekPanel.isVisible(self: WeekPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function WeekPanel.setVisible(self: WeekPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function WeekPanel.toggle(self: WeekPanel)
	self:setVisible(not self:isVisible())
end

function WeekPanel.drawLiveShow(self: WeekPanel, show: LiveShow)
	local card = UiKit.authored(self.window, "LiveShow", "GuiObject")

	setText(card, "DayLabel", show.day)
	setText(card, "TimeLabel", show.time)
	setText(card, "BlurbLabel", show.blurb)
	setText(card, "StatusChip.Label", show.status)
end

function WeekPanel.drawDaily(self: WeekPanel, rows: { DailyRow }, bonus: string, streak: string)
	local card = UiKit.authored(self.window, "Daily", "GuiObject")

	setText(card, "Bonus.ValueLabel", bonus)
	setText(card, "Streak.ValueLabel", streak)

	for index = 1, DAILY_ROWS do
		local row = UiKit.authored(card, "Row" .. index, "GuiObject")
		local entry = rows[index]

		if row == nil then
			continue
		end

		row.Visible = entry ~= nil

		if entry ~= nil then
			setText(row, "NameLabel", string.upper(entry.name))
			setText(row, "ProgressLabel", if entry.done then "DONE" else ("%d/%d"):format(entry.value, entry.target))
			setFill(row, "Bar.Fill", if entry.target > 0 then entry.value / entry.target else 0)
		end
	end
end

function WeekPanel.drawShop(self: WeekPanel, picks: { ShopPick })
	local card = UiKit.authored(self.window, "Shop", "GuiObject")
	local index = 1

	while true do
		local slot = UiKit.child(card, "Offer" .. index, "GuiObject")

		if slot == nil then
			break
		end

		local pick = picks[index]
		slot.Visible = pick ~= nil

		if pick ~= nil then
			setImage(slot, "Icon", pick.icon)
			setText(slot, "NameLabel", string.upper(pick.name))
			setText(slot, "PriceLabel", pick.price)
		end

		index += 1
	end
end

function WeekPanel.drawLeague(self: WeekPanel, league: League)
	local card = UiKit.authored(self.window, "League", "GuiObject")

	setText(card, "TierChip.Label", string.upper(league.tier))
	setText(card, "PlaceLabel", league.place)
	setText(card, "OfLabel", league.of)
	setText(card, "RuleLabel", league.rule)
	setText(card, "GapLabel", league.gap)
	setText(card, "ResetLabel", league.resets)

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
			UiKit.setLit(row, entry.you)
		end
	end
end

function WeekPanel.drawPass(self: WeekPanel, pass: Pass)
	local card = UiKit.authored(self.window, "Pass", "GuiObject")

	setText(card, "Header", pass.header)
	setText(card, "TierLabel", pass.tier)
	setText(card, "WeekChip.Label", pass.week)
	setFill(card, "Bar.Fill", pass.fill)
	setText(card, "NextFree.NameLabel", pass.freeName)
	setImage(card, "NextFree.Icon", pass.freeIcon)
	setText(card, "NextPass.NameLabel", pass.passName)
	setImage(card, "NextPass.Icon", pass.passIcon)
end

return WeekPanel
