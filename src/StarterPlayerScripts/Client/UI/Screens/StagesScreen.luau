--!strict
local TweenService = game:GetService("TweenService")

local PanelMotion = require(script.Parent.Parent.PanelMotion)
local UiKit = require(script.Parent.Parent.UiKit)

local STAGE_MODE = "StageChallenge"
local FREE_MODE = "FreePlay"
local MODE_NAMES = { [STAGE_MODE] = "STAGE CHALLENGE", [FREE_MODE] = "FREE PLAY" }
local MODE_TILES: { [string]: string } = { StageChallengeTile = STAGE_MODE, FreePlayTile = FREE_MODE }
local FREE_PLAY_LINE = "ANY OPEN SONG"
local LOWER_SET_LINE = "OLDER STAGES PAY 50% XP"
local MAX_REVEAL_CARDS = 4
local POP_SECONDS = 0.3
local POP_FROM = 1.4
local POP_NAME = "Pop"
local PORTRAIT_SPRITE = "Stage_Portrait"
local MODE_ICONS = { [STAGE_MODE] = "Stage_IconStages", [FREE_MODE] = "Stage_IconNote" }

export type Snapshot = { [string]: any }
export type StageUp = {
	rank: number,
	name: string,
	stages: Snapshot,
	challenge: { [string]: any }?,
	opens: { string },
}

type TextStyle = { color: Color3 }
type PipStyle = { background: Color3, transparency: number, text: Color3, stroke: boolean }
type TileStyle = { image: UiKit.ImageState?, title: Color3, line: Color3, line2: Color3 }

type Fields = {
	gui: ScreenGui?,
	lobby: GuiObject?,
	modeList: GuiObject?,
	setlist: GuiObject?,
	stageUp: GuiObject?,
	list: GuiObject?,
	rowTemplate: GuiObject?,
	selectedTemplate: GuiObject?,
	challengerRow: GuiObject?,
	rows: { GuiObject },
	cardTemplate: GuiObject?,
	cards: { GuiObject },
	pipStyles: { [string]: PipStyle },
	tileStyles: { [string]: TileStyle },
	snapshot: Snapshot?,
	selected: string?,
	lobbyShown: boolean,
	covered: boolean,
	motion: PanelMotion.PanelMotion,
	setlistOpen: boolean,
	modeListOpen: boolean,
	lobbyUp: boolean,
	onPlay: ((chartId: string?) -> ())?,
	onAllSongs: (() -> ())?,
	onMode: ((modeId: string) -> ())?,
	onSeen: ((what: string, rank: number) -> ())?,
	onRoadmap: (() -> ())?,
	onLobbyShown: (() -> ())?,
	onSetlistOpened: (() -> ())?,
	stageUpRank: number?,
	finishStageUp: (() -> ())?,
}

-- The Stages handoff screens, authored in StarterGui.Stages: the lobby's mode tile and
-- PLAY, the mode list, the setlist board and the stage-up reveal. Drawing only; the
-- snapshot comes from the server through StagesController.
local StagesScreen = {}
StagesScreen.__index = StagesScreen

export type StagesScreen = typeof(setmetatable({} :: Fields, StagesScreen))

local function withCommas(value: number): string
	local text = tostring(math.floor(value))
	local formatted, count = text, 0

	repeat
		formatted, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return formatted
end

local function scoreText(score: number): string
	return ("%s.%02d"):format(withCommas(score), math.floor(score * 100 + 0.5) % 100)
end

local function setText(root: Instance?, path: string, text: string)
	local label = UiKit.authored(root, path, "TextLabel")

	if label ~= nil then
		label.Text = text
	end
end

local function setVisible(root: Instance?, path: string, visible: boolean)
	local gui = UiKit.authored(root, path, "GuiObject")

	if gui ~= nil then
		gui.Visible = visible
	end
end

local function bind(root: Instance?, path: string, callback: () -> ())
	local button = UiKit.authored(root, path, "GuiButton")

	if button ~= nil then
		UiKit.bindHover(button)
		button.Activated:Connect(callback)
	end
end

-- A challenger's picture is the Stage_Portrait sprite named after them.
local function setPortrait(root: Instance?, path: string, name: string?)
	local image = UiKit.authored(root, path, "ImageLabel")

	if image == nil then
		return
	end

	image.Visible = name ~= nil

	if name ~= nil then
		UiKit.setImage(image, PORTRAIT_SPRITE .. string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2)))
	end
end

local function pipStyle(pip: GuiObject?): PipStyle?
	local label = UiKit.authored(pip, "Label", "TextLabel")

	if pip == nil or label == nil then
		return nil
	end

	local stroke = pip:FindFirstChildOfClass("UIStroke")

	return {
		background = pip.BackgroundColor3,
		transparency = pip.BackgroundTransparency,
		text = label.TextColor3,
		stroke = stroke ~= nil and stroke.Enabled,
	}
end

local function tileStyle(tile: GuiObject?): TileStyle?
	local title = UiKit.authored(tile, "TitleLabel", "TextLabel")
	local line = UiKit.authored(tile, "LineLabel", "TextLabel")
	local line2 = UiKit.authored(tile, "Line2Label", "TextLabel")

	if tile == nil or title == nil or line == nil or line2 == nil then
		return nil
	end

	return {
		image = if tile:IsA("ImageButton") then UiKit.imageState(tile) else nil,
		title = title.TextColor3,
		line = line.TextColor3,
		line2 = line2.TextColor3,
	}
end

local function previewLine(xp: any): string
	local text = ("XP AT GRADE %s: %d + %d"):format(xp.grade, xp.finish, xp.bonus)

	if xp.payClass == "LOWER" then
		text = ("XP AT GRADE %s: (%d + %d) × 50%%"):format(xp.grade, xp.finish, xp.bonus)
	end

	if xp.first > 0 then
		text ..= (" + NEW %d"):format(xp.first)
	end

	return ("%s = %d"):format(text, xp.total)
end

function StagesScreen.new(gui: ScreenGui?): StagesScreen
	local setlist = UiKit.authored(gui, "Setlist", "GuiObject")
	local stageUp = UiKit.authored(gui, "StageUp", "GuiObject")
	local modeList = UiKit.authored(gui, "ModeList", "GuiObject")
	local list = UiKit.authored(setlist, "List", "GuiObject")
	local pips = UiKit.authored(setlist, "Pips", "GuiObject")
	local tiles = UiKit.authored(modeList, "Panel.Tiles", "GuiObject")
	local fields: Fields = {
		gui = gui,
		lobby = UiKit.authored(gui, "Lobby", "GuiObject"),
		modeList = modeList,
		setlist = setlist,
		stageUp = stageUp,
		list = list,
		rowTemplate = UiKit.authored(list, "Row1", "GuiObject"),
		selectedTemplate = UiKit.authored(list, "RowSelected", "GuiObject"),
		challengerRow = UiKit.authored(list, "ChallengerRow", "GuiObject"),
		rows = {},
		cardTemplate = UiKit.authored(stageUp, "Cards.Card1", "GuiObject"),
		cards = {},
		pipStyles = {
			done = pipStyle(UiKit.authored(pips, "Pip1", "GuiObject")) :: PipStyle,
			current = pipStyle(UiKit.authored(pips, "Pip3", "GuiObject")) :: PipStyle,
			locked = pipStyle(UiKit.authored(pips, "Pip4", "GuiObject")) :: PipStyle,
		},
		tileStyles = {
			picked = tileStyle(UiKit.authored(tiles, "StageChallengeTile", "GuiObject")) :: TileStyle,
			resting = tileStyle(UiKit.authored(tiles, "FreePlayTile", "GuiObject")) :: TileStyle,
		},
		snapshot = nil,
		selected = nil,
		lobbyShown = false,
		covered = false,
		motion = PanelMotion.new(),
		setlistOpen = false,
		modeListOpen = false,
		lobbyUp = false,
		onPlay = nil,
		onAllSongs = nil,
		onMode = nil,
		onSeen = nil,
		onRoadmap = nil,
		onLobbyShown = nil,
		onSetlistOpened = nil,
		stageUpRank = nil,
		finishStageUp = nil,
	}
	local self = setmetatable(fields, StagesScreen)

	if gui ~= nil then
		gui.Enabled = true
	end

	if list ~= nil then
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end

	local cards = UiKit.authored(stageUp, "Cards", "GuiObject")

	if cards ~= nil then
		for _, child in cards:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end

	for _, hidden in { "Friends", "Detail.Difficulty", "Tabs.LeagueTab" } do
		setVisible(setlist, hidden, false)
	end

	for _, hidden in { "LeagueTile", "StageBadge", "StageCard", "StagesNotice", "DailyChip" } do
		setVisible(fields.lobby, hidden, false)
	end

	setVisible(tiles, "WeeklyLeagueTile", false)

	for _, root in { fields.lobby, modeList, setlist, stageUp } :: { GuiObject? } do
		if root ~= nil then
			root.Visible = false
		end
	end

	self:_bindButtons(tiles)

	return self
end

function StagesScreen._bindButtons(self: StagesScreen, tiles: GuiObject?)
	bind(self.lobby, "ModeTile", function()
		self:_setModeListOpen(true)
	end)
	bind(self.lobby, "PlayButton", function()
		self:_playMode()
	end)
	bind(self.modeList, "Dimmer", function()
		self:_setModeListOpen(false)
	end)
	bind(self.modeList, "Panel.BackButton", function()
		self:_setModeListOpen(false)
	end)

	for tileName, modeId in MODE_TILES do
		bind(tiles, tileName, function()
			self:_setModeListOpen(false)

			if self.onMode ~= nil then
				self.onMode(modeId)
			end
		end)
	end

	bind(self.setlist, "CloseButton", function()
		self:closeSetlist()
	end)
	bind(self.setlist, "Notice.CloseButton", function()
		local snapshot = self.snapshot

		setVisible(self.setlist, "Notice", false)

		if self.onSeen ~= nil and snapshot ~= nil then
			self.onSeen("notice", snapshot.rank)
		end
	end)
	bind(self.setlist, "Tabs.RoadmapTab", function()
		self:closeSetlist()

		if self.onRoadmap ~= nil then
			self.onRoadmap()
		end
	end)
	bind(self.setlist, "Tabs.AllSongsTab", function()
		self:closeSetlist()

		if self.onAllSongs ~= nil then
			self.onAllSongs()
		end
	end)
	bind(self.setlist, "Detail.PlayButton", function()
		local chartId = self.selected

		self:closeSetlist()

		if self.onPlay ~= nil then
			self.onPlay(chartId)
		end
	end)
	if self.challengerRow ~= nil and self.challengerRow:IsA("GuiButton") then
		UiKit.bindSounds(self.challengerRow)
		self.challengerRow.Activated:Connect(function()
			local challenger = if self.snapshot ~= nil then self.snapshot.challenger else nil

			if challenger ~= nil then
				self:_select(challenger.chartId)
			end
		end)
	end

	bind(self.stageUp, "TapCatcher", function()
		self:_endStageUp(nil)
	end)
	bind(self.stageUp, "Footer.SetlistButton", function()
		self:_endStageUp(function()
			self:openSetlist()
		end)
	end)
	bind(self.stageUp, "PlayButton", function()
		local snapshot = self.snapshot

		self:_endStageUp(function()
			if self.onPlay ~= nil and snapshot ~= nil then
				self.onPlay(snapshot.nextChart)
			end
		end)
	end)
end

function StagesScreen.bindPlay(self: StagesScreen, callback: (chartId: string?) -> ())
	self.onPlay = callback
end

function StagesScreen.bindAllSongs(self: StagesScreen, callback: () -> ())
	self.onAllSongs = callback
end

function StagesScreen.bindMode(self: StagesScreen, callback: (modeId: string) -> ())
	self.onMode = callback
end

function StagesScreen.bindSeen(self: StagesScreen, callback: (what: string, rank: number) -> ())
	self.onSeen = callback
end

function StagesScreen.bindRoadmap(self: StagesScreen, callback: () -> ())
	self.onRoadmap = callback
end

function StagesScreen.bindLobbyShown(self: StagesScreen, callback: () -> ())
	self.onLobbyShown = callback
end

function StagesScreen.bindSetlistOpened(self: StagesScreen, callback: () -> ())
	self.onSetlistOpened = callback
end

function StagesScreen.isLobbyShown(self: StagesScreen): boolean
	return self.lobbyShown
end

function StagesScreen.isShowingStageUp(self: StagesScreen): boolean
	return self.finishStageUp ~= nil
end

function StagesScreen.isOpen(self: StagesScreen): boolean
	return self.setlistOpen
end

-- The lobby pieces follow the lobby HUD on and off, and step aside for the board.
function StagesScreen.setLobbyShown(self: StagesScreen, shown: boolean)
	self.lobbyShown = shown

	if not shown then
		self:closeAll()
	end

	self:_refreshLobby()

	if shown and self.onLobbyShown ~= nil then
		self.onLobbyShown()
	end
end

-- Another full-screen stage panel is up, so the lobby pieces would only show through it.
function StagesScreen.setCovered(self: StagesScreen, covered: boolean)
	self.covered = covered
	self:_refreshLobby()
end

function StagesScreen._refreshLobby(self: StagesScreen)
	local up = self.lobbyShown and self.snapshot ~= nil and not self.covered and not self:isOpen()

	if self.lobby == nil or up == self.lobbyUp then
		return
	end

	self.lobbyUp = up

	if up then
		self.motion:open(self.lobby)
	else
		self.motion:close(self.lobby)
	end
end

function StagesScreen._setModeListOpen(self: StagesScreen, open: boolean)
	local up = open and self.snapshot ~= nil

	if self.modeList == nil or up == self.modeListOpen then
		return
	end

	self.modeListOpen = up

	if up then
		self.motion:open(self.modeList)
	else
		self.motion:close(self.modeList)
	end
end

function StagesScreen._playMode(self: StagesScreen)
	local snapshot = self.snapshot

	if snapshot == nil or self.onPlay == nil then
		return
	end

	self.onPlay(if snapshot.playMode == STAGE_MODE then snapshot.nextChart else nil)
end

function StagesScreen.openSetlist(self: StagesScreen)
	local snapshot = self.snapshot

	if self.setlist == nil or snapshot == nil then
		return
	end

	self:_setModeListOpen(false)
	self.selected = snapshot.nextChart
	self.setlistOpen = true
	self:_renderSetlist()
	self.motion:open(self.setlist)
	self:_refreshLobby()

	if self.onSetlistOpened ~= nil then
		self.onSetlistOpened()
	end
end

function StagesScreen.closeSetlist(self: StagesScreen)
	if self.setlist ~= nil and self.setlistOpen then
		self.setlistOpen = false
		self.motion:close(self.setlist)
	end

	self:_refreshLobby()
end

function StagesScreen.closeAll(self: StagesScreen)
	self:_setModeListOpen(false)
	self:closeSetlist()
end

-- Closes whichever of these screens is on top; false when none was open.
function StagesScreen.closeTop(self: StagesScreen): boolean
	if self:isShowingStageUp() then
		self:_endStageUp(nil)
	elseif self.modeListOpen then
		self:_setModeListOpen(false)
	elseif self:isOpen() then
		self:closeSetlist()
	else
		return false
	end

	return true
end

function StagesScreen.update(self: StagesScreen, snapshot: any)
	if type(snapshot) ~= "table" or type(snapshot.rows) ~= "table" then
		return
	end

	self.snapshot = snapshot
	self:_renderLobby()
	self:_renderModeList()

	if self:isOpen() then
		self:_renderSetlist()
	end

	self:_refreshLobby()
end

local function chartLine(row: any): string
	return ("%s %s"):format(tostring(row.songTitle), tostring(row.difficulty))
end

function StagesScreen._rowOf(self: StagesScreen, chartId: string?): any
	local snapshot = self.snapshot

	if snapshot == nil or chartId == nil then
		return nil
	end

	for _, row in snapshot.rows do
		if row.chartId == chartId then
			return row
		end
	end

	return if snapshot.challenger ~= nil and snapshot.challenger.chartId == chartId then snapshot.challenger else nil
end

function StagesScreen._progressLine(self: StagesScreen): string
	local snapshot = self.snapshot :: Snapshot
	local challenger = snapshot.challenger

	if challenger == nil then
		return ("%s XP"):format(withCommas(snapshot.xp))
	end

	local bar = ("%s / %s XP"):format(withCommas(snapshot.xp), withCommas(snapshot.threshold))

	return if challenger.state == "PRACTICE"
		then ("%s · %s XP TO %s"):format(bar, withCommas(snapshot.toChallenge), challenger.name)
		else ("%s · %s READY"):format(bar, challenger.name)
end

function StagesScreen._renderLobby(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot
	local tile = UiKit.authored(self.lobby, "ModeTile", "GuiObject")
	local challenger = snapshot.challenger
	local nextRow = self:_rowOf(snapshot.nextChart)
	local stageMode = snapshot.playMode == STAGE_MODE

	local icon = UiKit.authored(tile, "Icon", "ImageLabel")

	if icon ~= nil then
		UiKit.setImage(icon, MODE_ICONS[snapshot.playMode] or MODE_ICONS[STAGE_MODE])
	end

	setText(tile, "ModeLabel", MODE_NAMES[snapshot.playMode] or MODE_NAMES[STAGE_MODE])
	setText(
		tile,
		"Line1",
		if stageMode then ("STAGE %d · %d / %d CLEARED"):format(snapshot.rank, snapshot.cleared, #snapshot.rows) else FREE_PLAY_LINE
	)
	setText(
		tile,
		"Line2",
		if not stageMode then LOWER_SET_LINE
			elseif challenger ~= nil and challenger.state ~= "PRACTICE" then ("CHALLENGE %s · GRADE %s"):format(
				challenger.name,
				challenger.needGrade
			)
			elseif nextRow ~= nil then ("NEXT: %s"):format(chartLine(nextRow))
			else ""
	)
	setText(
		self.lobby,
		"PlayButton.Label",
		if stageMode and challenger ~= nil and challenger.state ~= "PRACTICE" then "CHALLENGE" else "PLAY"
	)
end

function StagesScreen._renderModeList(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot
	local tiles = UiKit.authored(self.modeList, "Panel.Tiles", "GuiObject")
	local challenger = snapshot.challenger
	local unfinished = snapshot.cleared < #snapshot.rows or (challenger ~= nil and not challenger.finished)
	local line = ("STAGE %d SETLIST · %d / %d"):format(snapshot.rank, snapshot.cleared, #snapshot.rows)

	if challenger ~= nil then
		line ..= if challenger.state == "PRACTICE"
			then (" · %s XP TO %s"):format(withCommas(snapshot.toChallenge), challenger.name)
			else (" · CHALLENGE %s"):format(challenger.name)
	end

	setText(tiles, "StageChallengeTile.LineLabel", line)
	setVisible(tiles, "StageChallengeTile.NewChip", unfinished)

	for tileName, modeId in MODE_TILES do
		local tile = UiKit.authored(tiles, tileName, "GuiObject")
		local picked = snapshot.playMode == modeId
		local style = self.tileStyles[if picked then "picked" else "resting"]

		if tile ~= nil and style ~= nil then
			if style.image ~= nil then
				UiKit.setImage(tile, style.image)
			end

			local colors: { [string]: Color3 } = { TitleLabel = style.title, LineLabel = style.line, Line2Label = style.line2 }

			for labelName, color in colors do
				local label = UiKit.authored(tile, labelName, "TextLabel")

				if label ~= nil then
					label.TextColor3 = color
				end
			end

			setVisible(tile, "SelectedTag", picked)
		end
	end
end

function StagesScreen._renderPips(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot
	local pips = UiKit.authored(self.setlist, "Pips", "GuiObject")

	if pips == nil then
		return
	end

	for _, pip in pips:GetChildren() do
		local index = tonumber(string.match(pip.Name, "^Pip(%d+)$"))
		local entry = if index ~= nil then snapshot.ranks[index] else nil

		if index ~= nil and pip:IsA("GuiObject") then
			local state = if index < snapshot.rank then "done" elseif index == snapshot.rank then "current" else "locked"
			local style = self.pipStyles[state]
			local label = UiKit.authored(pip, "Label", "TextLabel")
			local sub = UiKit.authored(pip, "Sub", "TextLabel")
			local stroke = pip:FindFirstChildOfClass("UIStroke")

			pip.Visible = entry ~= nil

			if entry ~= nil and style ~= nil and label ~= nil then
				pip.BackgroundColor3 = style.background
				pip.BackgroundTransparency = style.transparency
				label.TextColor3 = style.text
				label.Text = if state == "done" then ("%d ✓"):format(index)
					elseif state == "current" then tostring(index)
					else ("%d · %s"):format(index, withCommas(entry.xp))

				if sub ~= nil then
					sub.Visible = false
				end

				if stroke ~= nil then
					stroke.Enabled = style.stroke
				end
			end
		end
	end
end

function StagesScreen._fillRow(self: StagesScreen, gui: GuiObject, row: any, index: number)
	setText(gui, "Number", ("%02d"):format(index))
	setText(gui, "TitleLabel", ("%s · %s"):format(row.songTitle, row.difficulty))
	setVisible(gui, "GradeBox", row.grade ~= nil)
	setVisible(gui, "NewChip", not row.finished)

	if row.grade ~= nil then
		setText(gui, "GradeBox.Grade", row.grade)
	end
end

function StagesScreen._renderRows(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot

	for _, gui in self.rows do
		gui:Destroy()
	end

	table.clear(self.rows)

	for index, row in snapshot.rows do
		local template = if row.chartId == self.selected then self.selectedTemplate else self.rowTemplate

		if template ~= nil then
			local gui = template:Clone()

			gui.Name = "Row"
			gui.LayoutOrder = index
			gui.Visible = true
			self:_fillRow(gui, row, index)

			if gui:IsA("GuiButton") then
				UiKit.bindSounds(gui)
				gui.Activated:Connect(function()
					self:_select(row.chartId)
				end)
			end

			gui.Parent = self.list
			table.insert(self.rows, gui)
		end
	end

	local challenger = snapshot.challenger
	local gui = self.challengerRow

	if gui == nil then
		return
	end

	gui.Visible = challenger ~= nil
	gui.LayoutOrder = #snapshot.rows + 1

	if challenger == nil then
		return
	end

	setText(gui, "Number", ("%02d"):format(#snapshot.rows + 1))
	setPortrait(gui, "Portrait", challenger.name)
	setText(gui, "NameLabel", ("%s'S SONG"):format(challenger.name))
	setText(gui, "ChartLabel", ("%s · %s"):format(challenger.songTitle, challenger.difficulty))
	setText(
		gui,
		"StateTag.Label",
		if challenger.state == "PRACTICE" then ("PRACTISE · %s XP TO CHALLENGE"):format(withCommas(snapshot.toChallenge))
			elseif challenger.state == "OPEN" then ("CHALLENGE · GRADE %s"):format(challenger.needGrade)
			else ("BEST %s / %s · RETRY"):format(scoreText(challenger.bestScore), scoreText(challenger.target))
	)
	setVisible(gui, "SelectedMark", challenger.chartId == self.selected)
end

function StagesScreen._renderDetail(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot
	local detail = UiKit.authored(self.setlist, "Detail", "GuiObject")
	local row = self:_rowOf(self.selected)
	local challenger = snapshot.challenger
	local play = UiKit.authored(detail, "PlayButton", "GuiObject")

	if play ~= nil then
		play.Visible = row ~= nil
	end

	setVisible(detail, "XpPreview", row ~= nil)
	setVisible(detail, "ChallengerStrip", challenger ~= nil)

	if challenger ~= nil then
		local opens = if #snapshot.nextOpens > 0 then tostring(snapshot.nextOpens[1]) else ""

		setPortrait(detail, "ChallengerStrip.Portrait", challenger.name)
		setText(detail, "ChallengerStrip.HeaderLabel", ("NEXT CHALLENGER · %s"):format(challenger.name))
		setText(
			detail,
			"ChallengerStrip.TargetLabel",
			("GRADE %s · TARGET %s"):format(challenger.needGrade, scoreText(challenger.target))
		)
		setText(
			detail,
			"ChallengerStrip.OpensLabel",
			("BEAT %s → STAGE %d · %s"):format(challenger.name, snapshot.rank + 1, opens)
		)
	end

	if row == nil then
		return
	end

	local index = #snapshot.rows + 1

	for rowIndex, entry in snapshot.rows do
		if entry.chartId == row.chartId then
			index = rowIndex
		end
	end

	local attempt = challenger ~= nil and challenger.chartId == row.chartId and challenger.state ~= "PRACTICE"

	setText(detail, "IndexLabel", ("%02d"):format(index))
	setText(detail, "TitleLabel", tostring(row.songTitle))
	setText(detail, "ArtistLabel", tostring(row.difficulty))
	setText(detail, "XpPreview.Line1", previewLine(row.xp))
	setText(detail, "XpPreview.Line2", ("FIRST SONG TODAY ×2 = %d"):format(row.xp.total * 2))
	setVisible(detail, "XpPreview.Line2", snapshot.dailyAvailable == true)
	setText(detail, "PlayButton.Label", if attempt then "CHALLENGE" else "PLAY")
end

function StagesScreen._renderSetlist(self: StagesScreen)
	local snapshot = self.snapshot :: Snapshot
	local setlist = self.setlist
	local fill = UiKit.authored(setlist, "XpBar.Fill", "GuiObject")
	local challenger = snapshot.challenger

	if self:_rowOf(self.selected) == nil then
		self.selected = snapshot.nextChart
	end

	setText(setlist, "StageTitle.StageLabel", ("STAGE %d"):format(snapshot.rank))
	setText(setlist, "StageTitle.RankLabel", ("%s · SETLIST"):format(tostring(snapshot.name)))
	setText(setlist, "ClearedLabel", ("%d / %d CLEARED"):format(snapshot.cleared, #snapshot.rows))
	setText(setlist, "XpBar.XpLabel", self:_progressLine())
	setVisible(setlist, "Notice", snapshot.showNotice == true)
	setText(setlist, "Notice.Label", tostring(snapshot.lowerNotice or ""))
	setVisible(
		setlist,
		"ReplayNote",
		challenger ~= nil and challenger.state == "PRACTICE" and snapshot.cleared >= #snapshot.rows and challenger.finished
	)

	if fill ~= nil then
		local share = if snapshot.threshold ~= nil then snapshot.xp / math.max(snapshot.threshold, 1) else 1

		fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end

	self:_renderPips()
	self:_renderRows()
	self:_renderDetail()
end

function StagesScreen._select(self: StagesScreen, chartId: string)
	if self.selected == chartId then
		return
	end

	self.selected = chartId
	self:_renderRows()
	self:_renderDetail()
end

function StagesScreen._endStageUp(self: StagesScreen, after: (() -> ())?)
	local finish = self.finishStageUp

	if finish == nil then
		return
	end

	local rank = self.stageUpRank

	self.finishStageUp = nil
	self.stageUpRank = nil

	if self.stageUp ~= nil then
		self.motion:close(self.stageUp)
	end

	if self.onSeen ~= nil and rank ~= nil then
		self.onSeen("reveal", rank)
	end

	finish()

	if after ~= nil then
		after()
	end
end

-- Whatever is up goes at once; its callback still runs so the popup queue can end.
function StagesScreen.clear(self: StagesScreen)
	self:_endStageUp(nil)
end

function StagesScreen._renderCards(self: StagesScreen, snapshot: Snapshot)
	for _, card in self.cards do
		card:Destroy()
	end

	table.clear(self.cards)

	local template = self.cardTemplate
	local charts = table.clone(snapshot.rows)

	if snapshot.challenger ~= nil then
		table.insert(charts, snapshot.challenger)
	end

	if template == nil then
		return
	end

	for index = 1, math.min(#charts, MAX_REVEAL_CARDS) do
		local chart = charts[index]
		local card = template:Clone()

		card.Name = "Card"
		card.LayoutOrder = index
		card.Visible = true
		setText(card, "TitleLabel", tostring(chart.songTitle))
		setText(card, "DifficultyLabel", tostring(chart.difficulty))
		setText(card, "ArtistLabel", if chart.name ~= nil then ("%s'S SONG"):format(chart.name) else "")
		setVisible(card, "NewChip", not chart.finished)
		card.Parent = template.Parent
		table.insert(self.cards, card)
	end
end

function StagesScreen.showStageUp(self: StagesScreen, info: StageUp, done: () -> ())
	local root = self.stageUp
	local snapshot = info.stages

	if root == nil or type(snapshot) ~= "table" or type(snapshot.rows) ~= "table" then
		done()
		return
	end

	self:clear()
	self:update(snapshot)

	local challenge = info.challenge
	local nextChallenger = snapshot.challenger
	local fill = UiKit.authored(root, "XpRow.XpBar.Fill", "GuiObject")
	local nextRow = self:_rowOf(snapshot.nextChart)

	setText(root, "StageBadge.Body.Number", tostring(info.rank))
	setText(root, "Title.TitleLabel", info.name)
	setText(root, "XpRow.StageTag", ("STAGE %d"):format(info.rank))
	setText(
		root,
		"XpRow.XpBar.XpLabel",
		if snapshot.threshold ~= nil
			then ("%s / %s XP"):format(withCommas(snapshot.xp), withCommas(snapshot.threshold))
			else ("%s XP"):format(withCommas(snapshot.xp))
	)

	if fill ~= nil then
		local share = if snapshot.threshold ~= nil then snapshot.xp / math.max(snapshot.threshold, 1) else 1

		fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end

	setVisible(root, "NextChallenger", nextChallenger ~= nil)

	if nextChallenger ~= nil then
		setPortrait(root, "NextChallenger.Portrait", nextChallenger.name)
		setText(root, "NextChallenger.Label", ("NEXT: %s · AT %s XP"):format(nextChallenger.name, withCommas(snapshot.threshold)))
	end

	setVisible(root, "Beaten", challenge ~= nil)

	if challenge ~= nil then
		setPortrait(root, "Beaten.Portrait", tostring(challenge.name))
		setText(root, "Beaten.NameTag", tostring(challenge.name))
		setText(
			root,
			"Beaten.LineLabel",
			("%s · %s · %s · %s"):format(
				tostring(challenge.songTitle),
				tostring(challenge.difficulty),
				tostring(challenge.grade),
				scoreText(tonumber(challenge.score) or 0)
			)
		)
	end

	setVisible(root, "UnlockTag", #info.opens > 0)

	if #info.opens > 0 then
		setText(root, "UnlockTag.TitleLabel", ("%s UNLOCKED"):format(info.opens[1]))
		setText(root, "UnlockTag.LineLabel", table.concat(info.opens, " · ", 2))
	end

	setText(
		root,
		"Footer.FooterLabel",
		("STAGE %d SETLIST · %d CHART%s%s"):format(
			info.rank,
			#snapshot.rows,
			if #snapshot.rows == 1 then "" else "S",
			if nextChallenger ~= nil then " + " .. nextChallenger.name else ""
		)
	)
	setText(root, "PlayButton.Label", if nextRow ~= nil then ("PLAY %s"):format(tostring(nextRow.songTitle)) else "PLAY")
	self:_renderCards(snapshot)

	self.finishStageUp = done
	self.stageUpRank = info.rank
	self.motion:open(root)

	local title = UiKit.authored(root, "Title", "GuiObject")

	if title ~= nil then
		local scale = UiKit.scaleOf(title, POP_NAME)

		scale.Scale = POP_FROM
		TweenService:Create(scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

return StagesScreen
