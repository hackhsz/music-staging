--!strict
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "quests"
local TAB_KEYS = { "daily", "achievements" }
local DONE_TRANSPARENCY = 0.45
-- The tag UIStyles' Design sheet keys a finished card's look on.
local DONE_TAG = "Done"
local ROW_GAP = 8
-- A styled (Pill) tab shows it is picked with this tag.
local PICKED_TAG = "Primary"
local FILL_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Quest = {
	glyph: string,
	icon: string?,
	name: string,
	progressText: string,
	fraction: number,
	rewardText: string,
	rewardGlyph: string?,
	rewardIcon: string?,
	done: boolean,
}

export type Level = { level: number, name: string, into: number, need: number, maxed: boolean }

type Tab = { button: GuiButton, key: string, count: TextLabel? }

type Fields = {
	menu: MenuScreen.MenuScreen,
	tabs: { Tab },
	tabImage: string?,
	pickedTabImage: string?,
	list: ScrollingFrame?,
	rowTemplate: GuiObject?,
	rows: { GuiObject },
	levelGlyph: TextLabel?,
	levelName: TextLabel?,
	xpLabel: TextLabel?,
	xpFill: GuiObject?,
	resetLabel: TextLabel?,
	quests: { [string]: { Quest } },
	tab: string,
}

-- The Quests window, authored in StarterGui.Menu's Quests: the daily challenges
-- and the achievements as rows with a progress bar, and the player's level and XP
-- on the right. Drawing only; QuestController builds the rows from the profile.
local QuestsPanel = {}
QuestsPanel.__index = QuestsPanel

export type QuestsPanel = typeof(setmetatable({} :: Fields, QuestsPanel))

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

function QuestsPanel.new(menu: MenuScreen.MenuScreen): QuestsPanel
	local window = menu:window(WINDOW)
	local tabsFrame = UiKit.authored(window, "Tabs", "GuiObject")
	local list = UiKit.authored(window, "Grid.List", "ScrollingFrame")

	local fields: Fields = {
		menu = menu,
		tabs = {},
		tabImage = attribute(tabsFrame, "TabImage"),
		pickedTabImage = attribute(tabsFrame, "PickedTabImage"),
		list = list,
		rowTemplate = UiKit.authored(list, "RowTemplate", "GuiObject"),
		rows = {},
		levelGlyph = UiKit.authored(window, "LevelBadge.Glyph", "TextLabel"),
		levelName = UiKit.authored(window, "DetailName", "TextLabel"),
		xpLabel = UiKit.authored(window, "XpLabel", "TextLabel"),
		xpFill = UiKit.authored(window, "XpBar.Fill", "GuiObject"),
		resetLabel = UiKit.authored(window, "ResetLabel", "TextLabel"),
		quests = {},
		tab = TAB_KEYS[1],
	}
	local self = setmetatable(fields, QuestsPanel)

	if fields.rowTemplate ~= nil then
		fields.rowTemplate.Visible = false
	end

	for index, key in TAB_KEYS do
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")

		if button ~= nil then
			table.insert(fields.tabs, { button = button, key = key, count = UiKit.child(button, "Count", "TextLabel") })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.tab = key
				self:_draw()
			end)
		end
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

function QuestsPanel.isVisible(self: QuestsPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function QuestsPanel.setVisible(self: QuestsPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
		task.defer(function()
			self:_fitCanvas()
		end)
	else
		self.menu:close(WINDOW)
	end
end

-- quests holds a list of rows per tab: daily and achievements.
function QuestsPanel.render(self: QuestsPanel, quests: { [string]: { Quest } })
	self.quests = quests
	self:_draw()
end

function QuestsPanel.setLevel(self: QuestsPanel, level: Level)
	local need = math.max(level.need, 1)

	if self.levelGlyph ~= nil then
		self.levelGlyph.Text = tostring(level.level)
	end

	if self.levelName ~= nil then
		self.levelName.Text = level.name
	end

	if self.xpLabel ~= nil then
		self.xpLabel.Text = if level.maxed then "TOP RANK" else ("%d / %d XP"):format(level.into, need)
	end

	if self.xpFill ~= nil then
		self.xpFill.Size = UDim2.fromScale(math.clamp(level.into / need, 0, 1), 1)
	end
end

function QuestsPanel.setResetText(self: QuestsPanel, text: string)
	if self.resetLabel ~= nil then
		self.resetLabel.Text = text
	end
end

function QuestsPanel._draw(self: QuestsPanel)
	for _, tab in self.tabs do
		local image = if tab.key == self.tab then self.pickedTabImage else self.tabImage

		if image ~= nil and tab.button:IsA("ImageButton") then
			UiKit.setImage(tab.button, image)
		elseif tab.key == self.tab then
			CollectionService:AddTag(tab.button, PICKED_TAG)
		else
			CollectionService:RemoveTag(tab.button, PICKED_TAG)
		end

		self:_drawCount(tab)
	end

	for _, row in self.rows do
		row:Destroy()
	end

	self.rows = {}

	local list, template = self.list, self.rowTemplate

	if list == nil or template == nil then
		return
	end

	for index, quest in QuestsPanel._openFirst(self.quests[self.tab] or {}) do
		local row = template:Clone()
		row.Name = "Quest" .. index
		row.LayoutOrder = index
		row.Visible = true
		self:_fillRow(row, quest)
		row.Parent = list
		table.insert(self.rows, row)
	end

	-- New rows have no size until the next layout pass.
	task.defer(function()
		self:_fitCanvas()
	end)
end

function QuestsPanel._openFirst(quests: { Quest }): { Quest }
	local ordered = {}

	for _, quest in quests do
		if not quest.done then
			table.insert(ordered, quest)
		end
	end

	for _, quest in quests do
		if quest.done then
			table.insert(ordered, quest)
		end
	end

	return ordered
end

function QuestsPanel._drawCount(self: QuestsPanel, tab: Tab)
	local count = tab.count
	local quests = self.quests[tab.key] or {}

	if count == nil then
		return
	end

	local done = 0

	for _, quest in quests do
		if quest.done then
			done += 1
		end
	end

	count.Text = ("%d/%d"):format(done, #quests)
	count.Visible = #quests > 0
end

function QuestsPanel._fillRow(_self: QuestsPanel, row: GuiObject, quest: Quest)
	local name = UiKit.child(row, "NameLabel", "TextLabel")
	local progress = UiKit.child(row, "ProgressLabel", "TextLabel")
	local reward = UiKit.child(row, "RewardLabel", "TextLabel")
	local fill = UiKit.child(row:FindFirstChild("Bar"), "Fill", "GuiObject")
	local doneMark = UiKit.child(row, "DoneMark", "GuiObject")
	local coin = UiKit.child(row, "CoinIcon", "GuiObject")

	UiKit.setIcon(UiKit.child(row, "Glyph", "TextLabel"), quest.glyph, quest.icon)
	UiKit.setIcon(UiKit.child(row, "RewardGlyph", "TextLabel"), quest.rewardGlyph, quest.rewardIcon)

	if coin ~= nil then
		coin.Visible = quest.rewardGlyph == nil and quest.rewardIcon == nil
	end

	if doneMark ~= nil then
		doneMark.Visible = quest.done
	end

	if quest.done then
		row:AddTag(DONE_TAG)
	end

	local doneColor = if progress ~= nil then progress:GetAttribute("DoneColor") else nil

	if quest.done and progress ~= nil and typeof(doneColor) == "Color3" then
		progress.TextColor3 = doneColor
	end

	if name ~= nil then
		name.Text = string.upper(quest.name)
		name.TextTransparency = if quest.done then DONE_TRANSPARENCY else 0
	end

	if progress ~= nil then
		progress.Text = quest.progressText
	end

	if reward ~= nil then
		reward.Text = quest.rewardText
	end

	if fill ~= nil then
		fill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(fill, FILL_TWEEN, { Size = UDim2.fromScale(math.clamp(quest.fraction, 0, 1), 1) }):Play()
	end
end

function QuestsPanel._fitCanvas(self: QuestsPanel)
	local list = self.list

	if list == nil then
		return
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")
	local padding = list:FindFirstChildOfClass("UIPadding")
	local height = 0

	-- The layout knows the real height, gaps included.
	if layout ~= nil then
		height = layout.AbsoluteContentSize.Y
	else
		for _, row in self.rows do
			height += row.AbsoluteSize.Y + ROW_GAP
		end
	end

	if padding ~= nil then
		height += padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	end

	list.CanvasSize = UDim2.fromOffset(0, height)
end

return QuestsPanel
