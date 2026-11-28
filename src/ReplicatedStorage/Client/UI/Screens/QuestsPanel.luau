--!strict
local MenuLife = require(script.Parent.Parent.MenuLife)
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "quests"
local TABS = { "Daily", "Achievements" }
local DAILY_ROWS = 3
local STREAK_DOTS = 7
-- The medal road: this many medals to a row, each row this share of the road's height. The
-- road snakes, so every other row runs right to left.
local MEDALS_PER_ROW = 3
local ROW_SHARE = 0.36
local MEDAL_INSET = 0.17
local LINE_PIXELS = 6
local CAPTIONS = { earned = "EARNED", progress = "NEXT UP", locked = "LOCKED" }
local DIM = 0.55

-- state: "progress", "claim" (finished, reward waiting) or "done" (reward paid).
export type DailyQuest = {
	id: string,
	name: string,
	icon: string,
	progress: string,
	fraction: number,
	reward: string,
	state: string,
}
export type Today = { done: string, coins: string, streak: string, lit: number, bonus: string }
-- state: "earned", "progress" or "locked".
export type Achievement = {
	id: string,
	name: string,
	goal: string,
	progress: string,
	fraction: number,
	reward: string,
	rewardIcon: string?,
	badge: string,
	state: string,
}
export type Level = { level: number, name: string, maxed: boolean, into: number, need: number }

type Fields = {
	menu: MenuScreen.MenuScreen,
	window: GuiObject?,
	tab: number,
	daily: { DailyQuest },
	achievements: { Achievement },
	medals: { GuiObject },
	lines: { GuiObject },
	picked: string?,
	onClaim: ((questId: string) -> ())?,
}

-- The Quests window, authored in StarterGui.Menu's Quests. Daily: today's challenges as rows
-- with a claim button, the streak and the first-song bonus. Achievements: a road of medals,
-- one per achievement in the catalog's order, that grows by itself as achievements are added.
-- Drawing only; QuestController builds the rows and sends the claims.
local QuestsPanel = {}
QuestsPanel.__index = QuestsPanel

export type QuestsPanel = typeof(setmetatable({} :: Fields, QuestsPanel))

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

function QuestsPanel.new(menu: MenuScreen.MenuScreen): QuestsPanel
	local window = menu:window(WINDOW)
	local self = setmetatable({
		menu = menu,
		window = window,
		tab = 1,
		daily = {},
		achievements = {},
		medals = {},
		lines = {},
		picked = nil,
		onClaim = nil,
	} :: Fields, QuestsPanel)

	for index in TABS do
		local button = UiKit.authored(window, "Tabs.Tab" .. index, "GuiButton")

		if button ~= nil then
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.tab = index
				self:_showTab(true)
			end)
		end
	end

	for index = 1, DAILY_ROWS do
		local claim = UiKit.authored(window, ("Daily.Row%d.ClaimButton"):format(index), "GuiButton")

		if claim ~= nil then
			UiKit.bindHover(claim)
			claim.Activated:Connect(function()
				local quest = self.daily[index]

				if quest ~= nil and quest.state == "claim" and self.onClaim ~= nil then
					self.onClaim(quest.id)
				else
					UiKit.playSound("uiDenied")
				end
			end)
		end
	end

	local template = UiKit.authored(window, "Achievements.Road.Canvas.MedalTemplate", "GuiObject")

	if template ~= nil then
		template.Visible = false
	end

	local close = UiKit.authored(window, "CloseButton", "GuiButton")

	if close ~= nil then
		UiKit.bindHover(close)
		close.Activated:Connect(function()
			self:setVisible(false)
		end)
	end

	self:_showTab(false)

	return self
end

function QuestsPanel.bindClaim(self: QuestsPanel, callback: (questId: string) -> ())
	self.onClaim = callback
end

function QuestsPanel.isVisible(self: QuestsPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function QuestsPanel.setVisible(self: QuestsPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function QuestsPanel._showTab(self: QuestsPanel, animate: boolean)
	for index, name in TABS do
		local page = UiKit.authored(self.window, name, "GuiObject")
		local button = UiKit.authored(self.window, "Tabs.Tab" .. index, "GuiButton")

		if page ~= nil then
			page.Visible = index == self.tab

			if animate and index == self.tab then
				MenuLife.enter(page)
			end
		end

		if button ~= nil then
			UiKit.setLit(button, index == self.tab)
		end
	end
end

function QuestsPanel.setResetText(self: QuestsPanel, text: string)
	setText(self.window, "Daily.ResetChip.Label", text)
end

function QuestsPanel.setLevel(self: QuestsPanel, level: Level)
	local strip = UiKit.authored(self.window, "Daily.Rank", "GuiObject")

	setText(strip, "NumberLabel", tostring(level.level))
	setText(strip, "NameLabel", string.upper(level.name))
	setText(strip, "XpLabel", if level.maxed then "MAX RANK" else ("%d / %d XP"):format(level.into, level.need))
	setFill(strip, "Bar.Fill", if level.maxed then 1 else level.into / math.max(level.need, 1))
end

function QuestsPanel.drawToday(self: QuestsPanel, today: Today)
	local page = UiKit.authored(self.window, "Daily", "GuiObject")

	setText(page, "TodayBar.DoneLabel", today.done)
	setText(page, "TodayBar.CoinsLabel", today.coins)
	setText(page, "Streak.ValueLabel", today.streak)
	setText(page, "Bonus.ValueLabel", today.bonus)

	for index = 1, STREAK_DOTS do
		local dot = UiKit.authored(page, "Streak.Dot" .. index, "GuiObject")

		if dot ~= nil then
			UiKit.setLit(dot, index <= today.lit)
		end
	end
end

function QuestsPanel.render(self: QuestsPanel, daily: { DailyQuest }, achievements: { Achievement })
	self.daily = daily
	self.achievements = achievements
	self:_drawDaily()
	self:_drawRoad()

	local done, earned = 0, 0

	for _, quest in daily do
		if quest.state ~= "progress" then
			done += 1
		end
	end

	for _, achievement in achievements do
		if achievement.state == "earned" then
			earned += 1
		end
	end

	setText(self.window, "Tabs.Tab1.Count", ("%d/%d"):format(done, #daily))
	setText(self.window, "Tabs.Tab2.Count", ("%d/%d"):format(earned, #achievements))
	setText(self.window, "Achievements.Summary.CountLabel", ("%d / %d"):format(earned, #achievements))
	setFill(self.window, "Achievements.Summary.Bar.Fill", if #achievements > 0 then earned / #achievements else 0)
end

function QuestsPanel._drawDaily(self: QuestsPanel)
	for index = 1, DAILY_ROWS do
		local row = UiKit.authored(self.window, "Daily.Row" .. index, "GuiObject")
		local quest = self.daily[index]

		if row == nil then
			continue
		end

		row.Visible = quest ~= nil

		if quest == nil then
			continue
		end

		local claimable = quest.state == "claim"

		setText(row, "NameLabel", string.upper(quest.name))

		if quest.icon ~= "" then
			setImage(row, "IconTile.Icon", quest.icon)
		end

		setText(row, "ProgressLabel", quest.progress)
		setFill(row, "Bar.Fill", quest.fraction)
		setText(row, "RewardLabel", quest.reward)
		setText(row, "ClaimButton.Label", if claimable then "CLAIM " .. quest.reward else quest.reward .. " CLAIMED")
		setShown(row, "ClaimButton", quest.state ~= "progress")
		setShown(row, "RewardChip", quest.state == "progress")
		setShown(row, "RewardLabel", quest.state == "progress")
		setShown(row, "DoneMark", quest.state == "done")
		UiKit.setLit(row, claimable)

		local claim = UiKit.authored(row, "ClaimButton", "GuiObject")

		if claim ~= nil then
			UiKit.setLit(claim, claimable)
		end
	end
end

-- The achievement the detail card opens on: the one closest to done, else the first locked.
function QuestsPanel._nextUp(self: QuestsPanel): Achievement?
	local best: Achievement? = nil

	for _, achievement in self.achievements do
		if achievement.state ~= "earned" and (best == nil or achievement.fraction > best.fraction) then
			best = achievement
		end
	end

	return best or self.achievements[#self.achievements]
end

-- Where medal number index sits on the road, as shares of the canvas.
local function medalSpot(index: number, rows: number): (number, number)
	local row = (index - 1) // MEDALS_PER_ROW
	local column = (index - 1) % MEDALS_PER_ROW
	local step = (1 - 2 * MEDAL_INSET) / math.max(MEDALS_PER_ROW - 1, 1)

	if row % 2 == 1 then
		column = MEDALS_PER_ROW - 1 - column
	end

	return MEDAL_INSET + column * step, (row + 0.5) / rows
end

function QuestsPanel._drawRoad(self: QuestsPanel)
	local canvas = UiKit.authored(self.window, "Achievements.Road.Canvas", "GuiObject")
	local template = UiKit.authored(canvas, "MedalTemplate", "GuiObject")
	local lineTemplate = UiKit.authored(canvas, "LineTemplate", "GuiObject")

	for _, old in self.medals do
		old:Destroy()
	end

	for _, old in self.lines do
		old:Destroy()
	end

	self.medals, self.lines = {}, {}

	if canvas == nil or template == nil then
		return
	end

	local count = #self.achievements
	local rows = math.max(math.ceil(count / MEDALS_PER_ROW), 1)

	canvas.Size = UDim2.fromScale(1, math.max(rows * ROW_SHARE, 1))

	for index, achievement in self.achievements do
		local x, y = medalSpot(index, rows)
		local medal = template:Clone()

		medal.Name = achievement.id
		medal.Position = UDim2.fromScale(x, y)
		medal.Visible = true
		setImage(medal, "Badge", achievement.badge)
		setText(medal, "NameLabel", ("%d. %s"):format(index, string.upper(achievement.name)))
		setText(medal, "RewardLabel", achievement.reward)
		setShown(medal, "Lock", achievement.state == "locked")

		local badge = UiKit.authored(medal, "Badge", "ImageLabel")

		if badge ~= nil then
			badge.ImageTransparency = if achievement.state == "locked" then DIM else 0
		end

		if medal:IsA("GuiButton") then
			UiKit.bindHover(medal)
			medal.Activated:Connect(function()
				self.picked = achievement.id
				self:_drawDetail()
			end)
		end

		medal.Parent = canvas
		table.insert(self.medals, medal)

		-- The stretch of road leading to this medal is lit once the one before it is earned.
		if index > 1 and lineTemplate ~= nil then
			local fromX, fromY = medalSpot(index - 1, rows)
			local line = lineTemplate:Clone()
			local sameRow = math.abs(fromY - y) < 0.001

			line.Name = "Line" .. index
			line.Visible = true
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromScale((fromX + x) / 2, (fromY + y) / 2)
			line.Size = if sameRow
				then UDim2.new(math.abs(x - fromX), 0, 0, LINE_PIXELS)
				else UDim2.new(0, LINE_PIXELS, math.abs(y - fromY), 0)
			UiKit.setLit(line, self.achievements[index - 1].state == "earned")
			line.Parent = canvas
			table.insert(self.lines, line)
		end
	end

	self:_drawDetail()
end

function QuestsPanel._drawDetail(self: QuestsPanel)
	local detail = UiKit.authored(self.window, "Achievements.Detail", "GuiObject")
	local shown: Achievement? = nil

	for _, achievement in self.achievements do
		if achievement.id == self.picked then
			shown = achievement
		end
	end

	shown = shown or self:_nextUp()

	if shown == nil then
		return
	end

	for index, medal in self.medals do
		UiKit.setLit(medal, self.achievements[index].id == shown.id)
	end

	setText(detail, "Caption.Label", CAPTIONS[shown.state] or "")
	setImage(detail, "Badge", shown.badge)
	setText(detail, "NameLabel", string.upper(shown.name))
	setText(detail, "GoalLabel", shown.goal)
	setText(detail, "ProgressLabel", shown.progress)
	setFill(detail, "Bar.Fill", shown.fraction)
	setText(detail, "Reward.Label", shown.reward)
	setImage(detail, "Reward.Icon", shown.rewardIcon or "")
end

return QuestsPanel
