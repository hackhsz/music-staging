--!strict
local PanelMotion = require(script.Parent.Parent.PanelMotion)
local UiKit = require(script.Parent.Parent.UiKit)

local MAX_ROADMAP_STAGES = 5
local PORTRAIT_SPRITE = "Stage_Portrait"
local DIFFICULTY_TABS: { [string]: { string } } = {
	EasyTab = { "EASY" },
	NormalTab = { "NORMAL" },
	HardTab = { "HARD", "EXPERT" },
}
local FILTER_TABS: { [string]: string } = { AllTab = "all", StageTab = "stage", OlderTab = "older", NewTab = "new" }
local FILTER_STATES: { [string]: string } = { stage = "current", older = "done" }
local SECTION_TITLES = {
	current = "STAGE %d SETLIST · FULL XP",
	done = "STAGE %d · 50%% XP",
	locked = "STAGE %d · LOCKED",
}

export type Snapshot = { [string]: any }

type LookState = { background: Color3, transparency: number, image: Color3?, stroke: Color3?, labels: { [string]: Color3 } }

type Fields = {
	songs: GuiObject?,
	roadmap: GuiObject?,
	prompt: GuiObject?,
	results: GuiObject?,
	list: GuiObject?,
	templates: { [string]: GuiObject },
	rows: { Instance },
	tabLooks: { picked: UiKit.ImageState?, resting: UiKit.ImageState? },
	nodeLooks: { [string]: LookState },
	cardLooks: { [string]: LookState },
	snapshot: Snapshot?,
	filter: string,
	difficulty: string?,
	selected: string?,
	onPlay: ((chartId: string) -> ())?,
	onSetlist: (() -> ())?,
	onSeen: ((what: string, rank: number) -> ())?,
	onAccept: (() -> ())?,
	onOpenChanged: ((open: boolean) -> ())?,
	motion: PanelMotion.PanelMotion,
	songsOpen: boolean,
	roadmapOpen: boolean,
	promptOpen: boolean,
	resultsUp: boolean,
}

-- The rest of the Stages handoff, authored in StarterGui.Stages: the song browser
-- with XP chips, the stages roadmap, the challenge prompt and the results XP panel.
-- Drawing only; StagesController feeds it the snapshot and takes its taps.
local StagePanels = {}
StagePanels.__index = StagePanels

export type StagePanels = typeof(setmetatable({} :: Fields, StagePanels))

local function withCommas(value: number): string
	local formatted, count = tostring(math.floor(value)), 0

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

local function lookOf(gui: GuiObject?): LookState?
	if gui == nil then
		return nil
	end

	local labels: { [string]: Color3 } = {}

	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			labels[child.Name] = child.TextColor3
		end
	end

	local stroke = gui:FindFirstChildOfClass("UIStroke")

	return {
		background = gui.BackgroundColor3,
		transparency = gui.BackgroundTransparency,
		image = if gui:IsA("ImageButton") or gui:IsA("ImageLabel") then gui.ImageColor3 else nil,
		stroke = if stroke ~= nil then stroke.Color else nil,
		labels = labels,
	}
end

local function applyLook(gui: GuiObject, look: LookState?)
	if look == nil then
		return
	end

	local stroke = gui:FindFirstChildOfClass("UIStroke")

	gui.BackgroundColor3 = look.background
	gui.BackgroundTransparency = look.transparency

	if stroke ~= nil and look.stroke ~= nil then
		stroke.Color = look.stroke
	end

	if look.image ~= nil and (gui:IsA("ImageButton") or gui:IsA("ImageLabel")) then
		(gui :: any).ImageColor3 = look.image
	end

	for name, color in look.labels do
		local label = gui:FindFirstChild(name)

		if label ~= nil and label:IsA("TextLabel") then
			label.TextColor3 = color
		end
	end
end

local function previewLine(xp: any): string
	local sum = ("%d + %d"):format(xp.finish, xp.bonus)
	local text = if xp.payClass == "LOWER" then ("GRADE %s: (%s) × 50%%"):format(xp.grade, sum) else ("GRADE %s: %s"):format(xp.grade, sum)

	if xp.first > 0 then
		text ..= (" + NEW %d"):format(xp.first)
	end

	return ("%s = %d XP"):format(text, xp.total)
end

function StagePanels.new(gui: ScreenGui?): StagePanels
	local songs = UiKit.authored(gui, "SongSelect", "GuiObject")
	local roadmap = UiKit.authored(gui, "Roadmap", "GuiObject")
	local list = UiKit.authored(songs, "List", "GuiObject")
	local path = UiKit.authored(roadmap, "Path", "GuiObject")
	local templates: { [string]: GuiObject } = {}

	if list ~= nil then
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
				templates[child.Name] = child
			end
		end
	end

	local picked = UiKit.authored(songs, "Filters.AllTab", "GuiObject")
	local resting = UiKit.authored(songs, "Filters.StageTab", "GuiObject")
	local fields: Fields = {
		songs = songs,
		roadmap = roadmap,
		prompt = UiKit.authored(gui, "ChallengePrompt", "GuiObject"),
		results = UiKit.authored(gui, "Results", "GuiObject"),
		list = list,
		templates = templates,
		rows = {},
		tabLooks = {
			picked = if picked ~= nil and picked:IsA("ImageButton") then UiKit.imageState(picked) else nil,
			resting = if resting ~= nil and resting:IsA("ImageButton") then UiKit.imageState(resting) else nil,
		},
		nodeLooks = {
			done = lookOf(UiKit.authored(path, "Node1", "GuiObject")) :: LookState,
			current = lookOf(UiKit.authored(path, "Node3", "GuiObject")) :: LookState,
			locked = lookOf(UiKit.authored(path, "Node4", "GuiObject")) :: LookState,
		},
		cardLooks = {
			done = lookOf(UiKit.authored(roadmap, "Card1", "GuiObject")) :: LookState,
			current = lookOf(UiKit.authored(roadmap, "Card3", "GuiObject")) :: LookState,
			locked = lookOf(UiKit.authored(roadmap, "Card4", "GuiObject")) :: LookState,
		},
		snapshot = nil,
		filter = "all",
		difficulty = nil,
		selected = nil,
		onPlay = nil,
		onSetlist = nil,
		onSeen = nil,
		onAccept = nil,
		onOpenChanged = nil,
		motion = PanelMotion.new(),
		songsOpen = false,
		roadmapOpen = false,
		promptOpen = false,
		resultsUp = false,
	}
	local self = setmetatable(fields, StagePanels)

	for _, name in { "ZoneGate", "WorldChallenger" } do
		setVisible(gui, name, false)
	end

	setVisible(songs, "Filters.LeagueTab", false)

	setVisible(fields.results, "XpPanel.HubButton", false)
	self:closeAll()
	self:hideResults()
	self:_bindButtons()

	return self
end

function StagePanels._bindButtons(self: StagePanels)
	local songs = self.songs

	bind(songs, "BackButton", function()
		self:closeSongs()
	end)
	bind(songs, "Notice.CloseButton", function()
		local snapshot = self.snapshot

		setVisible(songs, "Notice", false)

		if self.onSeen ~= nil and snapshot ~= nil then
			self.onSeen("notice", snapshot.rank)
		end
	end)
	bind(songs, "Detail.SelectButton", function()
		self:_play(self.selected)
	end)
	bind(songs, "Detail.XpBox.FullXpLink", function()
		self:closeSongs()

		if self.onSetlist ~= nil then
			self.onSetlist()
		end
	end)

	for tabName, filter in FILTER_TABS do
		bind(songs, "Filters." .. tabName, function()
			self.filter = filter
			self:_renderSongs()
		end)
	end

	for tabName in DIFFICULTY_TABS do
		bind(songs, "Difficulty." .. tabName, function()
			self.difficulty = if self.difficulty == tabName then nil else tabName
			self:_renderSongs()
		end)
	end

	bind(self.roadmap, "CloseButton", function()
		self:closeRoadmap()
	end)
	bind(self.roadmap, "Goal.PlayButton", function()
		local goal = if self.snapshot ~= nil then self.snapshot.nextGoal else nil

		if goal ~= nil then
			self:_play(goal.chartId)
		end
	end)
	bind(self.roadmap, "Hero.ChallengeButton", function()
		local challenger = if self.snapshot ~= nil then self.snapshot.challenger else nil

		if challenger ~= nil and challenger.state ~= "PRACTICE" then
			self:_play(challenger.chartId)
		end
	end)
	bind(self.prompt, "Dimmer", function()
		self:_closePrompt(false)
	end)
	bind(self.prompt, "Panel.NotNowButton", function()
		self:_closePrompt(false)
	end)
	bind(self.prompt, "Panel.ChallengeButton", function()
		self:_closePrompt(true)
	end)
	bind(self.results, "XpPanel.ChallengeButton", function()
		local challenger = if self.snapshot ~= nil then self.snapshot.challenger else nil

		if challenger ~= nil then
			self:_play(challenger.chartId)
		end
	end)
end

function StagePanels.bindPlay(self: StagePanels, callback: (chartId: string) -> ())
	self.onPlay = callback
end

function StagePanels.bindSetlist(self: StagePanels, callback: () -> ())
	self.onSetlist = callback
end

function StagePanels.bindSeen(self: StagePanels, callback: (what: string, rank: number) -> ())
	self.onSeen = callback
end

-- Told whenever the browser or the roadmap opens or closes, so what sits under them can step aside.
function StagePanels.bindOpenChanged(self: StagePanels, callback: (open: boolean) -> ())
	self.onOpenChanged = callback
end

function StagePanels._openChanged(self: StagePanels)
	if self.onOpenChanged ~= nil then
		self.onOpenChanged(self:isOpen())
	end
end

function StagePanels._play(self: StagePanels, chartId: string?)
	if chartId ~= nil and self.onPlay ~= nil then
		self.onPlay(chartId)
	end
end

function StagePanels.update(self: StagePanels, snapshot: any)
	if type(snapshot) ~= "table" or type(snapshot.stageList) ~= "table" then
		return
	end

	self.snapshot = snapshot

	if self.songsOpen then
		self:_renderSongs()
	end

	if self.roadmapOpen then
		self:_renderRoadmap()
	end
end

function StagePanels.closeAll(self: StagePanels)
	self:closeSongs()
	self:closeRoadmap()
	self:_closePrompt(false)
end

-- Closes whichever panel is on top; false when none was open.
function StagePanels.closeTop(self: StagePanels): boolean
	if self.promptOpen then
		self:_closePrompt(false)
	elseif self.songsOpen then
		self:closeSongs()
	elseif self.roadmapOpen then
		self:closeRoadmap()
	else
		return false
	end

	return true
end

-- The prompt is a card over whatever is up, so it does not count as a panel being open.
function StagePanels.isOpen(self: StagePanels): boolean
	return self.songsOpen or self.roadmapOpen
end

function StagePanels.openSongs(self: StagePanels, chartId: string?)
	if self.songs == nil or self.snapshot == nil then
		return
	end

	self.selected = chartId or self.snapshot.nextChart
	self.songsOpen = true
	self:_renderSongs()
	self.motion:open(self.songs)
	self:_openChanged()
end

function StagePanels.closeSongs(self: StagePanels)
	if self.songs ~= nil and self.songsOpen then
		self.songsOpen = false
		self.motion:close(self.songs)
	end

	self:_openChanged()
end

function StagePanels._chartOf(self: StagePanels, chartId: string?): (any, any)
	local snapshot = self.snapshot

	if snapshot == nil or chartId == nil then
		return nil, nil
	end

	for _, stage in snapshot.stageList do
		for _, chart in stage.charts do
			if chart.chartId == chartId then
				return chart, stage
			end
		end
	end

	return nil, nil
end

function StagePanels._shows(self: StagePanels, stage: any, chart: any): boolean
	local filter: string = self.filter
	local state: string = stage.state
	local only = FILTER_STATES[filter]

	if only ~= nil and state ~= only then
		return false
	elseif filter == "new" and (chart.finished or state == "locked") then
		return false
	end

	local wanted = if self.difficulty ~= nil then DIFFICULTY_TABS[self.difficulty] else nil

	return wanted == nil or table.find(wanted, chart.difficulty) ~= nil
end

function StagePanels._setTab(self: StagePanels, tab: GuiObject?, picked: boolean)
	local look = if picked then self.tabLooks.picked else self.tabLooks.resting

	if tab ~= nil and look ~= nil then
		UiKit.setImage(tab, look)
	end
end

function StagePanels._addRow(self: StagePanels, templateName: string, order: number): GuiObject?
	local template: GuiObject? = self.templates[templateName]

	if template == nil then
		return nil
	end

	local row = template:Clone()

	row.Name = "Item"
	row.LayoutOrder = order
	row.Visible = true
	row.Parent = self.list
	table.insert(self.rows, row)

	return row
end

function StagePanels._renderSongs(self: StagePanels)
	local snapshot = self.snapshot :: Snapshot
	local songs = self.songs
	local challenger = snapshot.challenger
	local order = 0
	local number = 0

	for _, row in self.rows do
		row:Destroy()
	end

	table.clear(self.rows)

	for tabName, filter in FILTER_TABS do
		self:_setTab(UiKit.authored(songs, "Filters." .. tabName, "GuiObject"), self.filter == filter)
	end

	for tabName in DIFFICULTY_TABS do
		self:_setTab(UiKit.authored(songs, "Difficulty." .. tabName, "GuiObject"), self.difficulty == tabName)
	end

	setText(songs, "Filters.StageTab.Label", ("STAGE %d"):format(snapshot.rank))
	setVisible(songs, "Notice", snapshot.showNotice == true)
	setText(songs, "Notice.Label", tostring(snapshot.lowerNotice or ""))

	local stages = table.clone(snapshot.stageList)

	-- The player's own setlist first, then what they have left behind, then what is ahead.
	table.sort(stages, function(a: any, b: any)
		local rankA = if a.state == "current" then 0 elseif a.state == "done" then 1 else 2
		local rankB = if b.state == "current" then 0 elseif b.state == "done" then 1 else 2

		return if rankA ~= rankB then rankA < rankB elseif a.state == "done" then a.rank > b.rank else a.rank < b.rank
	end)

	for _, stage in stages do
		local shown = {}

		for _, chart in stage.charts do
			if self:_shows(stage, chart) then
				table.insert(shown, chart)
			end
		end

		if #shown > 0 then
			order += 1

			local header = self:_addRow("HeaderCurrent", order)

			if header ~= nil then
				local title = SECTION_TITLES[stage.state]:format(stage.rank)

				setText(header, "Label", if stage.state == "locked" then ("%s · %s"):format(title, stage.need) else title)
			end
		end

		for _, chart in shown do
			order += 1
			number += 1

			local locked = stage.state == "locked"
			local picked = chart.chartId == self.selected
			local templateName = if locked then "LockedRow"
				elseif picked then "RowSelected"
				elseif chart.xp.payClass == "LOWER" then "Row3"
				else "Row"
			local row = self:_addRow(templateName, order)

			if row == nil then
				continue
			end

			setText(row, "Number", ("%02d"):format(number))
			setText(row, "TitleLabel", ("%s · %s"):format(chart.songTitle, chart.difficulty))

			if locked then
				setText(row, "LockLabel", stage.need)
			else
				local attempt = challenger ~= nil and challenger.chartId == chart.chartId and challenger.state ~= "PRACTICE"

				setVisible(row, "Difficulties", false)
				setVisible(row, "GradeBox", chart.grade ~= nil)
				setVisible(row, "NewChip", not chart.finished)
				setVisible(row, "SolTag", chart.challenger ~= nil)
				setText(row, "SolTag.Label", if chart.challenger ~= nil then ("%s'S SONG"):format(chart.challenger) else "")
				setText(
					row,
					"XpChip.Label",
					if attempt then "CHALLENGE" elseif chart.xp.payClass == "LOWER" then "50% XP" else "FULL XP"
				)

				if chart.grade ~= nil then
					setText(row, "GradeBox.Grade", chart.grade)
				end
			end

			if row:IsA("GuiButton") then
				UiKit.bindSounds(row)
				row.Activated:Connect(function()
					if not locked and self.selected ~= chart.chartId then
						self.selected = chart.chartId
						self:_renderSongs()
					end
				end)
			end
		end
	end

	self:_renderSongDetail()
end

function StagePanels._renderSongDetail(self: StagePanels)
	local snapshot = self.snapshot :: Snapshot
	local detail = UiKit.authored(self.songs, "Detail", "GuiObject")
	local chart, stage = self:_chartOf(self.selected)
	local open = chart ~= nil and stage.state ~= "locked"

	for _, name in { "XpBox", "SelectButton", "IndexLabel", "TitleLabel", "ArtistLabel", "Art" } do
		setVisible(detail, name, open)
	end

	setVisible(detail, "BestLabel", open and chart.grade ~= nil)

	if not open then
		return
	end

	local lower = chart.xp.payClass == "LOWER"

	setText(detail, "IndexLabel", ("%02d"):format(stage.rank))
	setText(detail, "TitleLabel", tostring(chart.songTitle))
	setText(detail, "ArtistLabel", if chart.challenger ~= nil then ("%s · %s'S SONG"):format(chart.difficulty, chart.challenger) else chart.difficulty)
	setText(detail, "XpBox.Line1", ("STAGE %d CHART · %s"):format(stage.rank, if lower then "50% XP" else "FULL XP"))
	setText(detail, "XpBox.Line2", previewLine(chart.xp))
	setText(detail, "XpBox.Line3", ("FIRST SONG TODAY ×2 = %d"):format(chart.xp.total * 2))
	setVisible(detail, "XpBox.Line3", snapshot.dailyAvailable == true)
	setVisible(detail, "XpBox.FullXpLink", lower)
	setText(detail, "XpBox.FullXpLink.Label", ("FULL XP: STAGE %d SETLIST ›"):format(snapshot.rank))
	setText(detail, "BestLabel", ("BEST: %s"):format(tostring(chart.grade)))
end

function StagePanels.openRoadmap(self: StagePanels)
	if self.roadmap == nil or self.snapshot == nil then
		return
	end

	self.roadmapOpen = true
	self:_renderRoadmap()
	self.motion:open(self.roadmap)
	self:_openChanged()
end

function StagePanels.closeRoadmap(self: StagePanels)
	if self.roadmap ~= nil and self.roadmapOpen then
		self.roadmapOpen = false
		self.motion:close(self.roadmap)
	end

	self:_openChanged()
end

function StagePanels._renderRoadmap(self: StagePanels)
	local snapshot = self.snapshot :: Snapshot
	local roadmap = self.roadmap
	local hero = UiKit.authored(roadmap, "Hero", "GuiObject")
	local path = UiKit.authored(roadmap, "Path", "GuiObject")
	local challenger = snapshot.challenger
	local stages = snapshot.stageList
	local fill = UiKit.authored(hero, "XpBar.Fill", "GuiObject")
	local share = if snapshot.threshold ~= nil then snapshot.xp / math.max(snapshot.threshold, 1) else 1

	local following = stages[snapshot.rank + 1]

	setText(
		roadmap,
		"SubLabel",
		if snapshot.threshold ~= nil and following ~= nil
			then ("%s / %s XP TO %s"):format(withCommas(snapshot.xp), withCommas(snapshot.threshold), tostring(following.name))
			else "TOP STAGE REACHED"
	)
	setText(hero, "TitleLabel", if challenger ~= nil then string.upper(challenger.songTitle) else "TOP STAGE")
	setVisible(hero, "ToGoLabel", challenger ~= nil)
	setVisible(hero, "Line1", challenger ~= nil)
	setVisible(hero, "NameTag", challenger ~= nil)
	setVisible(hero, "XpBar", challenger ~= nil)
	setVisible(hero, "RetryTag", challenger ~= nil)
	setPortrait(hero, "Portrait", if challenger ~= nil then challenger.name else nil)
	setVisible(hero, "ChallengeButton", challenger ~= nil)

	if fill ~= nil then
		fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end

	if challenger ~= nil then
		local ready = challenger.state ~= "PRACTICE"
		local button = UiKit.authored(hero, "ChallengeButton", "ImageButton")

		setText(hero, "NameTag", ("%s · CHALLENGER"):format(challenger.name))
		setText(hero, "Line1", ("%s · GRADE %s · TARGET %s"):format(challenger.difficulty, challenger.needGrade, scoreText(challenger.target)))
		setText(
			hero,
			"ToGoLabel",
			if ready
				then ("%s IS READY"):format(challenger.name)
				else ("OPENS AT %s XP · %s TO GO"):format(withCommas(snapshot.threshold or 0), withCommas(snapshot.toChallenge))
		)
		setText(hero, "ChallengeButton.Label", if ready then ("CHALLENGE %s"):format(challenger.name) else "LOCKED")

		if button ~= nil then
			UiKit.setButtonEnabled(button, ready)
		end
	end

	self:_renderXpRules(snapshot.xpRules)
	self:_renderGoal(snapshot.nextGoal)

	local last = math.min(#stages, MAX_ROADMAP_STAGES)
	local track = UiKit.authored(path, "Track", "GuiObject")
	local done = UiKit.authored(path, "Done", "GuiObject")
	local first = UiKit.authored(path, "Node1", "GuiObject")
	local final = UiKit.authored(path, "Node" .. last, "GuiObject")
	local reached = UiKit.authored(path, "Node" .. math.min(snapshot.rank, last), "GuiObject")

	if track ~= nil and done ~= nil and first ~= nil and final ~= nil and reached ~= nil then
		track.Size = UDim2.new(final.Position.X.Scale - first.Position.X.Scale, 0, track.Size.Y.Scale, track.Size.Y.Offset)
		done.Size = UDim2.new(reached.Position.X.Scale - first.Position.X.Scale, 0, done.Size.Y.Scale, done.Size.Y.Offset)
	end

	for index = 1, MAX_ROADMAP_STAGES do
		local stage = stages[index]
		local node = UiKit.authored(path, "Node" .. index, "GuiObject")
		local card = UiKit.authored(roadmap, "Card" .. index, "GuiObject")

		if node ~= nil then
			node.Visible = stage ~= nil
		end

		if card ~= nil then
			card.Visible = stage ~= nil
		end

		if stage == nil or node == nil or card == nil then
			continue
		end

		local before = stages[index - 1]

		applyLook(node, self.nodeLooks[stage.state])
		applyLook(card, self.cardLooks[stage.state])
		setPortrait(node, "Portrait", if before ~= nil then before.challenger else nil)
		setText(node, "NameTag", if before ~= nil and before.challenger ~= nil then before.challenger else "START")
		setVisible(node, "Stamp", stage.state ~= "locked" and before ~= nil)
		setVisible(node, "YouTag", stage.state == "current")
		setVisible(node, "LockTag", stage.state == "locked")
		setText(node, "LockTag", ("%s XP"):format(withCommas(stage.xp)))
		setText(card, "TitleLabel", tostring(stage.name))
		setText(card, "SetHeader", if stage.need ~= "" then tostring(stage.need) else "START")
		setText(card, "SetLabel", table.concat(stage.opens, " · "))
	end
end

function StagePanels._renderXpRules(self: StagePanels, rules: any)
	local panel = UiKit.authored(self.roadmap, "XpRules", "GuiObject")

	if panel == nil or type(rules) ~= "table" then
		return
	end

	local grades = rules.grades or {}

	setText(panel, "Row1.Value", ("+%d"):format(rules.finish))
	setText(panel, "Row2.Value", ("+%d · %d · %d · %d"):format(grades.S or 0, grades.A or 0, grades.B or 0, grades.C or 0))
	setText(panel, "Row3.Value", ("+%d"):format(rules.first))
	setText(panel, "Row4.Value", ("+%d"):format(rules.friend))
	setText(panel, "Row5.Value", ("×%d"):format(rules.todayMultiplier))
end

function StagePanels._renderGoal(self: StagePanels, goal: any)
	local panel = UiKit.authored(self.roadmap, "Goal", "GuiObject")

	setText(panel, "Headline", if goal ~= nil then tostring(goal.headline) else "EVERY SONG AT S")
	setText(panel, "Detail", if goal ~= nil then tostring(goal.detail) else "NOTHING LEFT ON THIS STAGE")
	setText(panel, "Badge", if goal ~= nil and goal.grade ~= nil then tostring(goal.grade) else "")
	setVisible(panel, "Badge", goal ~= nil and goal.grade ~= nil)
	setVisible(panel, "PlayButton", goal ~= nil)
end

-- The card between pressing a challenger's chart and starting it.
function StagePanels.showPrompt(self: StagePanels, onAccept: () -> ())
	local snapshot = self.snapshot
	local challenger = if snapshot ~= nil then snapshot.challenger else nil
	local panel = UiKit.authored(self.prompt, "Panel", "GuiObject")

	if self.prompt == nil or snapshot == nil or challenger == nil then
		onAccept()
		return
	end

	local bar = ("%s / %s XP"):format(withCommas(snapshot.xp), withCommas(snapshot.threshold))

	setPortrait(panel, "Portrait", challenger.name)
	setText(panel, "NameTag", tostring(challenger.name))
	setText(panel, "SubLabel", ("%s · STAGE %d CHALLENGER"):format(challenger.name, snapshot.rank + 1))
	setText(panel, "Info.SongLabel", ("%s · %s"):format(challenger.songTitle, challenger.difficulty))
	setText(panel, "Info.NeedLabel", ("NEED GRADE %s OR BETTER"):format(challenger.needGrade))
	setText(
		panel,
		"Info.XpLabel",
		if challenger.state == "FAILED"
			then ("BEST %s · TRY %d"):format(scoreText(challenger.bestScore), challenger.attempts + 1)
			else ("%s · READY"):format(bar)
	)
	setText(panel, "Info.Target.Value", scoreText(challenger.target))
	self.onAccept = onAccept
	self.promptOpen = true
	self.motion:open(self.prompt)
end

function StagePanels._closePrompt(self: StagePanels, accepted: boolean)
	local onAccept = self.onAccept

	self.onAccept = nil

	if self.prompt ~= nil and self.promptOpen then
		self.promptOpen = false
		self.motion:close(self.prompt)
	end

	if accepted and onAccept ~= nil then
		onAccept()
	end
end

local function nextStep(summary: any, challenger: any, snapshot: Snapshot): string
	local outcome = summary.challenge

	if type(outcome) == "table" then
		return if outcome.beaten == true
			then ("%s BEATEN"):format(tostring(outcome.name))
			else ("BEST %s / %s · RETRY"):format(scoreText(tonumber(outcome.score) or 0), scoreText(tonumber(outcome.target) or 0))
	end

	if challenger == nil then
		return ""
	end

	return if challenger.state == "PRACTICE"
		then ("%s XP TO %s"):format(withCommas(snapshot.toChallenge), challenger.name)
		else "STAGE UP READY"
end

-- A finished run's XP, line by line, beside the results.
function StagePanels.showResults(self: StagePanels, summary: any)
	local root = self.results
	local panel = UiKit.authored(root, "XpPanel", "GuiObject")
	local parts = if type(summary) == "table" then summary.xpParts else nil
	local snapshot = if type(summary) == "table" then summary.stages else nil

	if root == nil or panel == nil or type(parts) ~= "table" or type(snapshot) ~= "table" or summary.tutorial == true then
		self:hideResults()
		return
	end

	self.snapshot = snapshot

	local lines = UiKit.authored(panel, "Lines", "GuiObject")
	local paid = (tonumber(summary.xpGained) or 0) > 0
	local lower = parts.payClass == "LOWER"
	local challenger = snapshot.challenger
	local before = if type(summary.rankBefore) == "table" then tonumber(summary.rankBefore.total) or 0 else 0
	local threshold = snapshot.threshold
	local fill = UiKit.authored(panel, "XpBar.Fill", "GuiObject")
	local gain = UiKit.authored(panel, "XpBar.GainFill", "GuiObject")

	setVisible(lines, "FinishLine", paid)
	setVisible(lines, "GradeLine", paid and parts.grade > 0)
	setVisible(lines, "LowerSetLine", paid and lower)
	setVisible(lines, "NewSongLine", paid and parts.first > 0)
	setVisible(lines, "FriendLine", paid and parts.friend > 0)
	setVisible(lines, "DailyLine", paid and parts.doubled == true)
	setText(lines, "FinishLine.Value", ("+%d"):format(parts.finish))
	setText(lines, "GradeLine.Label", ("GRADE %s"):format(tostring(summary.rank)))
	setText(lines, "GradeLine.Value", ("+%d"):format(parts.grade))
	setText(lines, "LowerSetLine.Label", "OLDER STAGE: 50% XP")
	setText(lines, "LowerSetLine.Value", ("+%d"):format(parts.scaled))
	setText(lines, "NewSongLine.Value", ("+%d"):format(parts.first))
	setText(lines, "FriendLine.Value", ("+%d"):format(parts.friend))
	setText(panel, "TotalBar.Label", if paid then "TOTAL" else "NO XP")
	setText(panel, "TotalBar.Value", if paid then ("+%d XP"):format(summary.xpGained) else "UNDER 30%")
	setText(panel, "StageTag", ("STAGE %d"):format(snapshot.rank))
	setText(
		panel,
		"XpBar.XpLabel",
		if threshold ~= nil
			then ("%s / %s XP"):format(withCommas(snapshot.xp), withCommas(threshold))
			else ("%s XP"):format(withCommas(snapshot.xp))
	)
	setText(panel, "GainLabel", ("%s BEFORE · +%d THIS RUN"):format(withCommas(before), tonumber(summary.xpGained) or 0))
	setPortrait(panel, "NextStep.Portrait", if challenger ~= nil then challenger.name else nil)
	setText(panel, "NextStep.Label", nextStep(summary, challenger, snapshot))
	setVisible(panel, "NextStep", challenger ~= nil or type(summary.challenge) == "table")
	setVisible(panel, "NextGrade", type(summary.nextGoal) == "table")

	if type(summary.nextGoal) == "table" then
		setText(panel, "NextGrade.Label", ("%d MORE PERFECTS FOR %s"):format(summary.nextGoal.perfects, tostring(summary.nextGoal.grade)))
	end

	setVisible(panel, "ChallengeButton", challenger ~= nil and challenger.state ~= "PRACTICE" and summary.rankedUp ~= true)

	if challenger ~= nil then
		setText(panel, "ChallengeButton.Label", ("%s %s"):format(if challenger.state == "FAILED" then "RETRY" else "CHALLENGE", challenger.name))
	end

	if fill ~= nil and gain ~= nil then
		local whole = math.max(threshold or snapshot.xp, 1)

		fill.Size = UDim2.fromScale(math.clamp(before / whole, 0, 1), 1)
		gain.Size = UDim2.fromScale(math.clamp(snapshot.xp / whole, 0, 1), 1)
	end

	if not self.resultsUp then
		self.resultsUp = true
		self.motion:open(root)
	end
end

function StagePanels.hideResults(self: StagePanels)
	if self.results ~= nil and self.resultsUp then
		self.resultsUp = false
		self.motion:close(self.results)
	end
end

return StagePanels
