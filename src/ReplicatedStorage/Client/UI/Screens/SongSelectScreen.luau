--!strict
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local DIFFICULTIES = { "easy", "normal", "hard", "expert" }
local DIFFICULTY_LABELS: { [string]: string } = {
	easy = "EASY",
	normal = "NORMAL",
	hard = "HARD",
	expert = "EXPERT",
}
local DIFFICULTY_STARS: { [string]: number } = { easy = 1, normal = 2, hard = 3, expert = 4 }

local PINK = Color3.fromRGB(255, 85, 255)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local SELECTED_STAR_OFF = Color3.fromRGB(186, 186, 186)
local ROW_STAR_OFF = Color3.fromRGB(70, 70, 92)
-- What is not there yet reads grey: an empty rank box and a locked song.
local EMPTY_RANK_FADE = 0.55
local EMPTY_RANK_TEXT = Color3.fromRGB(130, 130, 140)
local LOCKED_TINT = Color3.fromRGB(120, 120, 130)

local STAR_IMAGE = "rbxassetid://81973069496048"
local SLIDE_DISTANCE = 0.6
local OPEN_SECONDS = 0.5
local CLOSE_SECONDS = 0.2
local SLIDE_STAGGER = 0.05
local FADE_SECONDS = 0.25
local ROW_STAGGER = 0.035
local TILE_STAGGER = 0.035
local POP_SECONDS = 0.3
local POP_FROM = 0.6
local HOVER_SCALE = 1.04
local HOVER_SECONDS = 0.1
local BADGE_SMALL = 1.9
-- The picked badge grows, but stays clear of the bars above and below it.
local BADGE_BIG = 2.3
local BADGE_SECONDS = 0.22
local BEAT_BUMP = 0.06
-- A row line longer than this many characters would wrap in its box, so it is
-- sized onto one line instead; shorter ones keep the authored scaling.
local LONG_LINE_CHARS = 12
local LINE_HEIGHT_FILL = 0.85
local LINE_WIDTH_FILL = 0.95
local MIN_TEXT_SIZE = 9
-- Box changes smaller than this many pixels are layout jitter, not a new box.
local FIT_STEP = 4
local HOVER_TINT = Color3.fromRGB(255, 85, 255)
local BADGE_HOVER = 0.08
local CONTINUE_HOVER = 0.06
local MARQUEE_LOOP_SECONDS = 26
local MARQUEE_WIDTH = 1.2
local SPARKLE_SPIN = 25
-- The right side moves too: a bounce runs along the title's letters each beat,
-- the panels rock slowly, and the backdrop's colour drifts.
local LETTER_BOUNCE = 0.18
-- SELECT's letters bounce in a wave every other beat; the selected row's number
-- shimmers and its lit stars take turns to twinkle; PREVIEW blinks on the beat
-- like a recording light; the A SONG tag wobbles; the goal counts up to a new value.
local SELECT_BOUNCE = 0.14
local SELECT_WAVE_STEP = 0.08
local NUMBER_SHIMMER = 0.35
local STAR_TWINKLE = 0.35
local PREVIEW_BLINK = 0.55
local TAG_WOBBLE_DEGREES = 4
local COUNT_SECONDS = 0.45
local LETTER_WAVE_STEP = 0.06
local PANEL_ROCK_DEGREES = 1.5
local BADGE_ROCK_DEGREES = 5
local BACKDROP_DRIFT = 0.35
local MAX_TITLE_TILES = 22
local LOCKED_FADE = 0.45
local LIST_GAP = 8
local DEFAULT_BPM = 120
local LAUNCH_SECONDS = 0.45
local LAUNCH_TITLE_SCALE = 1.45
local LAUNCH_TITLE_Y = 0.44
local LAUNCH_INFO_Y = 0.6
local LAUNCH_WAVE = 1.3
-- The cover holds at least this long, so a quick server still shows the launch,
-- and gives up after the timeout if the run never starts.
local LAUNCH_HOLD_SECONDS = 0.8
local LAUNCH_TIMEOUT_SECONDS = 10
-- The run starts: the screen leans in, the title's tiles burst away one after
-- another, and the picker fades through to the stage.
local REVEAL_SECONDS = 0.55
local REVEAL_STAGGER = 0.03
local REVEAL_TILE_SCALE = 1.8
local REVEAL_TILE_SPIN = 14
local REVEAL_ZOOM = 1.08
local READY_TEXT = "GET READY"
-- With the preview playing, the bars are its loudness: the newest level in the
-- middle, older ones rippling out to the sides, measured against a slowly
-- falling peak so quiet and loud songs both fill the box.
local LEVEL_SAMPLE_SECONDS = 1 / 30
local LEVEL_PEAK_DECAY = 0.995
local LEVEL_MIN_PEAK = 40
local LEVEL_ATTACK = 0.6
local LEVEL_RELEASE = 0.18
-- Above 1 the quiet stretches sit low and the hits stand out.
local LEVEL_CONTRAST = 1.7
-- The outer bars reach this much less than the middle, a meter's even shape.
local LEVEL_EDGE_FALLOFF = 0.4
-- A jump in the preview's level this big is a hit: the preview box jolts and
-- two backdrop stars burst. Hits closer together than the gap are one hit.
local KICK_JUMP = 0.22
local KICK_GAP_SECONDS = 0.15
local KICK_SCALE = 1.04
local KICK_SECONDS = 0.22
-- On every beat one backdrop star pops; every few beats one title tile spins.
local SPARKLE_POP = 1.8
local TILE_SPIN_EVERY_BEATS = 4
local TILE_SPIN_SECONDS = 0.45
-- A new song deals its right side in again, panel by panel.
local SWAP_DISTANCE = 0.05
local SWAP_STAGGER = 0.045
local SWAP_PANELS = { "SongsPanel2", "EncoreOriginalBpmPanel", "SongsFrame4", "BestPanel" }
local BAR_REST = 0.08
local BAR_KICK = 0.75
local BAR_SNARE = 0.55
local BAR_SHIMMER = 0.1
local TAB_SHAKE_DEGREES = 8
local TAB_HOVER_SCALE = 1.08
local TAB_HOVER_TILT = -3
local PRESS_SCALE = 0.92
local PRESS_SECONDS = 0.06
local TAB_SOON_SECONDS = 1.2
local TAB_SOON_TEXT = "SOON"

type Chart = {
	index: number,
	difficulty: string,
	entry: any,
}

type Song = {
	id: string,
	title: string,
	artist: string,
	bpm: number,
	pack: number,
	charts: { Chart },
	picked: number,
}

type Tab = {
	button: GuiButton,
	label: TextLabel?,
	pop: UIScale,
	pack: number,
	text: string,
	image: UiKit.ImageState?,
	busy: boolean,
}

type Row = {
	normal: GuiButton,
	selected: GuiButton,
	normalScale: UIScale,
	selectedScale: UIScale,
	numberGradient: UIGradient?,
	starScales: { UIScale },
}

type Badge = {
	button: GuiButton,
	label: TextLabel?,
	stars: GuiObject?,
	scale: UIScale,
	difficulty: string?,
}

type Slide = {
	object: GuiObject,
	home: UDim2,
	side: number,
}

type Best = {
	kind: TextLabel?,
	rank: TextLabel?,
	score: TextLabel?,
	combo: TextLabel?,
	status: TextLabel?,
}

type Fields = {
	gui: ScreenGui?,
	root: GuiObject?,
	background: ImageLabel?,
	list: ScrollingFrame?,
	rowTemplate: GuiButton?,
	selectedTemplate: GuiButton?,
	titleFrame: GuiObject?,
	tileTemplates: { GuiObject },
	tiles: { GuiObject },
	marquees: { GuiObject },
	sparkles: { GuiObject },
	badgeHover: GuiButton?,
	continueHover: boolean,
	info: TextLabel?,
	infoPanel: GuiObject?,
	bestPanel: GuiObject?,
	backdrop: GuiObject?,
	backdropGradient: UIGradient?,
	letterScales: { UIScale },
	selectLetterScales: { UIScale },
	previewLabel: TextLabel?,
	songTag: GuiObject?,
	scoreValue: NumberValue,
	homes: { [GuiObject]: UDim2 },
	kickScale: UIScale?,
	lastKick: number,
	lastLevel: number,
	lastBeat: number,
	scoreTween: Tween?,
	launchScale: UIScale?,
	zoom: UIScale?,
	fades: { { object: Instance, property: string, value: number } },
	launching: boolean,
	launchedAt: number,
	badges: { Badge },
	best: Best,
	continueButton: GuiButton?,
	continueScale: UIScale?,
	backButton: GuiButton?,
	slides: { Slide },
	letters: { UIScale },
	songs: { Song },
	allSongs: { Song },
	pack: number,
	tabs: { Tab },
	rows: { Row },
	signature: string,
	selected: number,
	open: boolean,
	closeToken: number,
	openedAt: number,
	beatConnection: RBXScriptConnection?,
	onChosen: ((index: number) -> ())?,
	onBack: (() -> ())?,
	onSetlist: (() -> ())?,
	onFocused: ((index: number) -> ())?,
	audioState: (() -> (number?, number))?,
	levelPeak: number,
	level: number,
	levels: { number },
	levelAt: number,
	bars: { GuiObject },
}

-- The song picker, authored in StarterGui.Songs. The catalog lists every chart
-- on its own; the picker groups them into one row per song (SongButton, or
-- SongButton2 when selected) and one badge per difficulty in SongsFrame4.
local SongSelectScreen = {}
SongSelectScreen.__index = SongSelectScreen

export type SongSelectScreen = typeof(setmetatable({} :: Fields, SongSelectScreen))

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, delay: number?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out, 0, false, delay or 0)
	local playing = TweenService:Create(object, info, goal)
	playing:Play()
	return playing
end

local function withCommas(value: number): string
	local reversed = string.reverse(tostring(math.floor(value)))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1,")

	return (string.gsub(string.reverse(grouped), "^,", ""))
end

local function songLength(seconds: any): string
	local total = math.floor(tonumber(seconds) or 0)

	return ("%d:%02d"):format(total // 60, total % 60)
end

-- "<song id>-<difficulty>" is that song's other chart; the bare id is its main one.
local function baseIdOf(entry: any): string
	local id = tostring(entry.id)
	local suffix = "-" .. tostring(entry.difficulty)

	if #id > #suffix and string.sub(id, -#suffix) == suffix then
		return string.sub(id, 1, -#suffix - 1)
	end

	return id
end

local function groupSongs(entries: { any }): { Song }
	local songs: { Song } = {}
	local byId: { [string]: Song } = {}

	for index, entry in entries do
		if type(entry) ~= "table" or entry.id == nil then
			continue
		end

		local id = baseIdOf(entry)
		local song = byId[id]

		if song == nil then
			song = {
				id = id,
				title = string.upper(tostring(entry.title or id)),
				artist = string.upper(tostring(entry.artist or "")),
				bpm = tonumber(entry.bpm) or DEFAULT_BPM,
				pack = tonumber(entry.pack) or 1,
				charts = {},
				picked = 1,
			}
			byId[id] = song
			table.insert(songs, song)
		end

		table.insert(song.charts, { index = index, difficulty = string.lower(tostring(entry.difficulty or "normal")), entry = entry })
	end

	for _, song in songs do
		local main = song.charts[1]

		table.sort(song.charts, function(a, b)
			return (table.find(DIFFICULTIES, a.difficulty) or 9) < (table.find(DIFFICULTIES, b.difficulty) or 9)
		end)

		-- A song opens on its main chart, or on its easiest open one while that is locked.
		if main.entry.locked == true then
			for _, chart in song.charts do
				if chart.entry.locked ~= true then
					main = chart
					break
				end
			end
		end

		song.picked = table.find(song.charts, main) or 1
	end

	return songs
end

local function childLabel(parent: Instance, predicate: (TextLabel) -> boolean): TextLabel?
	for _, child in parent:GetChildren() do
		if child:IsA("TextLabel") and predicate(child) then
			return child
		end
	end

	return nil
end

local function byLayout(a: GuiObject, b: GuiObject): boolean
	if a.LayoutOrder ~= b.LayoutOrder then
		return a.LayoutOrder < b.LayoutOrder
	end

	return a.Name < b.Name
end

-- The chart's own rating from the catalog, or its difficulty's when it has none.
local function chartStars(chart: Chart?): number
	if chart == nil then
		return DIFFICULTY_STARS.normal
	end

	return tonumber(chart.entry.stars) or DIFFICULTY_STARS[chart.difficulty] or 1
end

local function starsIn(container: Instance): { ImageLabel }
	local stars = {}

	for _, child in container:GetChildren() do
		if child:IsA("ImageLabel") and child.Image == STAR_IMAGE then
			table.insert(stars, child)
		end
	end

	table.sort(stars, byLayout)

	return stars
end

local function paintStars(container: Instance?, lit: number, on: Color3, off: Color3)
	if container == nil then
		return
	end

	for index, star in starsIn(container) do
		star.ImageColor3 = if index <= lit then on else off
	end
end

local function fade(row: GuiButton, transparency: number)
	if row:IsA("ImageButton") then
		row.ImageTransparency = transparency
	end

	for _, child in row:GetDescendants() do
		if child:IsA("TextLabel") then
			child.TextTransparency = transparency
		end
	end
end

-- The UIScales between a label and the screen, multiplied: a hover or pop scales
-- the row, and the text with it, so the fit works in unscaled pixels.
local function scaleOf(instance: Instance): number
	local scale = 1
	local node: Instance? = instance

	while node ~= nil and not node:IsA("LayerCollector") do
		for _, child in node:GetChildren() do
			if child:IsA("UIScale") then
				scale *= child.Scale
			end
		end

		node = node.Parent
	end

	return math.max(scale, 0.01)
end

local function setLine(label: TextLabel, text: string)
	label.Text = text

	-- A row may be filled before it is laid out, so the size follows its box.
	if label:GetAttribute("FitsLine") == nil then
		label:SetAttribute("FitsLine", true)
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setLine(label, label.Text)
		end)
	end

	if (utf8.len(text) or #text) <= LONG_LINE_CHARS then
		label.TextScaled = true
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label:SetAttribute("FitFor", nil)
		return
	end

	local scale = scaleOf(label)
	local box = label.AbsoluteSize / scale

	if box.X <= 0 or box.Y <= 0 then
		return
	end

	-- Only a new title or a new box refits; a hover or pop only rescales it.
	local key = ("%s|%d|%d"):format(text, math.floor(box.X / FIT_STEP), math.floor(box.Y / FIT_STEP))

	if label:GetAttribute("FitFor") == key then
		return
	end

	label:SetAttribute("FitFor", key)

	-- TextBounds reports the truncated width, and only once the text has been
	-- laid out, so it is measured untruncated a frame after the size is set.
	local fullSize = math.floor(box.Y * LINE_HEIGHT_FILL)

	label.TextScaled = false
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.None
	label.TextSize = fullSize

	task.spawn(function()
		RunService.Heartbeat:Wait()

		if label:GetAttribute("FitFor") ~= key then
			return
		end

		local width = label.TextBounds.X / scaleOf(label)

		-- A hidden label measures nothing; forget the fit so showing it refits.
		if width <= 0 then
			label:SetAttribute("FitFor", nil)
			return
		end

		if width > box.X * LINE_WIDTH_FILL then
			label.TextSize = math.max(math.floor(fullSize * box.X * LINE_WIDTH_FILL / width), MIN_TEXT_SIZE)
		end

		label.TextTruncate = Enum.TextTruncate.AtEnd
	end)
end

local function popIn(scale: UIScale, delay: number)
	scale.Scale = POP_FROM
	tween(scale, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, delay)
end

function SongSelectScreen.new(gui: ScreenGui?): SongSelectScreen
	local root = UiKit.authored(gui, "Songs", "GuiObject")
	local list = UiKit.authored(root, "Holder.HolderFrame.HolderframeList", "ScrollingFrame")
	local bestPanel = UiKit.authored(root, "BestPanel", "GuiObject")
	local continueButton = UiKit.authored(root, "ContinueButton", "GuiButton")
	local titleFrame = UiKit.authored(root, "SongsFrame", "GuiObject")
	local infoPanel = UiKit.authored(root, "EncoreOriginalBpmPanel", "GuiObject")

	local fields: Fields = {
		gui = gui,
		root = root,
		background = UiKit.authored(root, "SongsPanel", "ImageLabel"),
		list = list,
		rowTemplate = UiKit.authored(list, "SongButton", "GuiButton"),
		selectedTemplate = UiKit.authored(list, "SongButton2", "GuiButton"),
		titleFrame = titleFrame,
		tileTemplates = {},
		tiles = {},
		marquees = {},
		sparkles = {},
		badgeHover = nil,
		continueHover = false,
		info = UiKit.authored(infoPanel, "EncoreOriginalBpmLabel", "TextLabel"),
		infoPanel = infoPanel,
		bestPanel = bestPanel,
		backdrop = UiKit.authored(root, "Backdrop", "GuiObject"),
		backdropGradient = UiKit.authored(root, "Backdrop.UIGradient", "UIGradient"),
		letterScales = {},
		selectLetterScales = {},
		previewLabel = UiKit.authored(root, "SongsPanel2.PreviewLabel", "TextLabel"),
		songTag = UiKit.authored(root, "ASongPanel", "GuiObject"),
		scoreValue = Instance.new("NumberValue"),
		homes = {},
		kickScale = nil,
		lastKick = 0,
		lastLevel = 0,
		lastBeat = -1,
		scoreTween = nil,
		launchScale = if titleFrame ~= nil then UiKit.scaleOf(titleFrame, "Launch") else nil,
		zoom = if root ~= nil then UiKit.scaleOf(root, "Zoom") else nil,
		fades = {},
		launching = false,
		launchedAt = 0,
		badges = {},
		best = {
			kind = UiKit.authored(bestPanel, "BestLabel", "TextLabel"),
			rank = UiKit.authored(bestPanel, "ALabel", "TextLabel"),
			score = UiKit.authored(bestPanel, "BestpanelLabel", "TextLabel"),
			combo = UiKit.authored(bestPanel, "ComboLabel", "TextLabel"),
			status = UiKit.authored(bestPanel, "ClearLabel", "TextLabel"),
		},
		continueButton = continueButton,
		continueScale = if continueButton ~= nil then UiKit.scaleOf(continueButton, "Beat") else nil,
		backButton = UiKit.authored(root, "BackButton", "GuiButton"),
		slides = {},
		letters = {},
		songs = {},
		allSongs = {},
		pack = 1,
		tabs = {},
		rows = {},
		signature = "",
		selected = 1,
		open = false,
		closeToken = 0,
		openedAt = 0,
		beatConnection = nil,
		onChosen = nil,
		onBack = nil,
		onSetlist = nil,
		onFocused = nil,
		audioState = nil,
		levelPeak = LEVEL_MIN_PEAK,
		level = 0,
		levels = {},
		levelAt = 0,
		bars = {},
	}

	local self = setmetatable(fields, SongSelectScreen)

	if gui == nil or root == nil then
		return self
	end

	-- The picker keeps its own state across respawns, as the run HUD does.
	gui.ResetOnSpawn = false
	root.Visible = false

	self:_bindList()
	self:_bindTitle()
	self:_bindBadges()
	self:_bindSlides()
	self:_bindVisualizer()
	self:_bindTabs()

	local preview = root:FindFirstChild("SongsPanel2")

	if preview ~= nil then
		self.kickScale = UiKit.scaleOf(preview, "Kick")
	end

	self.scoreValue.Changed:Connect(function(value)
		if self.best.score ~= nil then
			self.best.score.Text = withCommas(value)
		end
	end)
	self:_bindBackdrop()
	self:_bindFades()

	if continueButton ~= nil then
		UiKit.bindSounds(continueButton)
		continueButton.Activated:Connect(function()
			self:confirm()
		end)
		continueButton.MouseEnter:Connect(function()
			self.continueHover = true
		end)
		continueButton.MouseLeave:Connect(function()
			self.continueHover = false
		end)
	end

	local backButton = self.backButton

	if backButton ~= nil then
		local pop = UiKit.scaleOf(backButton, "Pop")

		UiKit.bindSounds(backButton)
		backButton.Activated:Connect(function()
			if self.onBack ~= nil then
				self.onBack()
			end
		end)
		backButton.MouseEnter:Connect(function()
			tween(pop, HOVER_SECONDS, { Scale = HOVER_SCALE + BADGE_HOVER / 2 }, Enum.EasingStyle.Back)
		end)
		backButton.MouseLeave:Connect(function()
			tween(pop, HOVER_SECONDS, { Scale = 1 })
		end)
	end

	local setlistButton = UiKit.authored(root, "SetlistButton", "GuiButton")

	if setlistButton ~= nil then
		UiKit.bindHover(setlistButton)
		setlistButton.Activated:Connect(function()
			if self.onSetlist ~= nil then
				self.onSetlist()
			end
		end)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_coverScreen()
		self:_fitTitle()
	end)

	return self
end

function SongSelectScreen._bindList(self: SongSelectScreen)
	local list = self.list

	if list == nil then
		return
	end

	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") and string.match(child.Name, "^SongButton%d+$") and child ~= self.selectedTemplate then
			child:Destroy()
		end
	end

	if self.rowTemplate ~= nil then
		self.rowTemplate.Parent = nil
	end

	if self.selectedTemplate ~= nil then
		self.selectedTemplate.Parent = nil
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")

	if layout == nil then
		return
	end

	-- A scale gap would be measured against the canvas it decides, so it is a
	-- plain pixel gap, and the canvas follows the rows.
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, LIST_GAP)
	list.AutomaticCanvasSize = Enum.AutomaticSize.None

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local padding = list:FindFirstChildOfClass("UIPadding")
		local edges = if padding ~= nil then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + edges + LIST_GAP)
	end)
end

function SongSelectScreen._bindTitle(self: SongSelectScreen)
	local titleFrame = self.titleFrame

	if titleFrame == nil then
		return
	end

	local templates: { GuiObject } = {}

	for _, child in titleFrame:GetChildren() do
		if child:IsA("ImageLabel") then
			table.insert(templates, child)
		end
	end

	for _, template in templates do
		template.Parent = nil
	end

	self.tileTemplates = templates

	local layout = titleFrame:FindFirstChildOfClass("UIListLayout")

	if layout ~= nil then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
end

function SongSelectScreen._bindBadges(self: SongSelectScreen)
	local frame = UiKit.authored(self.root, "SongsFrame4", "GuiObject")

	if frame == nil then
		return
	end

	local buttons: { GuiButton } = {}
	local starRow: GuiObject? = nil

	for _, child in frame:GetChildren() do
		if child:IsA("GuiButton") then
			table.insert(buttons, child)

			for _, part in child:GetChildren() do
				if starRow == nil and part:IsA("Frame") and #starsIn(part) > 0 then
					starRow = part
				end
			end
		end
	end

	local layout = frame:FindFirstChildOfClass("UIListLayout")

	if layout ~= nil then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	-- Copied before any badge loses its own stars, the template's included.
	local starTemplate = if starRow ~= nil then starRow:Clone() else nil

	for order, button in buttons do
		-- Every badge gets the same centred star row, sized for its difficulty.
		local stars: GuiObject? = nil

		if starRow ~= nil and starTemplate ~= nil then
			local row = starTemplate:Clone()
			row.Name = "Stars"
			row.AnchorPoint = Vector2.new(0.5, 0.5)
			row.Position = UDim2.fromScale(0.5, starRow.Position.Y.Scale)
			row.Size = UDim2.fromScale(1, starRow.Size.Y.Scale)

			local rowLayout = row:FindFirstChildOfClass("UIListLayout")

			if rowLayout ~= nil then
				rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			end

			stars = row
		end

		for _, part in button:GetChildren() do
			if (part:IsA("Frame") and #starsIn(part) > 0) or (part:IsA("ImageLabel") and part.Image == STAR_IMAGE) then
				part:Destroy()
			end
		end

		if stars ~= nil then
			stars.Parent = button
		end

		button.LayoutOrder = order

		local badge: Badge = {
			button = button,
			label = childLabel(button, function()
				return true
			end),
			stars = stars,
			scale = UiKit.scaleOf(button, "Beat"),
			difficulty = nil,
		}
		table.insert(self.badges, badge)

		UiKit.bindSounds(button)
		button.Activated:Connect(function()
			self:_pickDifficulty(badge.difficulty)
		end)
		button.MouseEnter:Connect(function()
			self.badgeHover = button
		end)
		button.MouseLeave:Connect(function()
			if self.badgeHover == button then
				self.badgeHover = nil
			end
		end)
	end
end

function SongSelectScreen._bindSlides(self: SongSelectScreen)
	local root = self.root

	if root == nil then
		return
	end

	-- Each panel slides from the edge nearest where the designer put it.
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") and child ~= self.background and child ~= self.backdrop then
			table.insert(self.slides, { object = child, home = child.Position, side = if child.Position.X.Scale < 0.5 then -1 else 1 })
			self.homes[child] = child.Position
		end
	end

	local select = root:FindFirstChild("SongsFrame3")

	if select ~= nil then
		local letters = {}

		for _, child in select:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(letters, child)
			end
		end

		table.sort(letters, byLayout)

		for _, letter in letters do
			table.insert(self.letters, UiKit.scaleOf(letter, "Pop"))

			local label = letter:FindFirstChildOfClass("TextLabel")

			if label ~= nil then
				table.insert(self.selectLetterScales, UiKit.scaleOf(label, "Beat"))
			end
		end
	end
end

-- SongsPanel2.Visualizer's Bar frames, left to right, bounce to the highlighted
-- song's beat: the low bars on the beat, the high ones between.
function SongSelectScreen._bindVisualizer(self: SongSelectScreen)
	local visualizer = UiKit.authored(self.root, "SongsPanel2.Visualizer", "GuiObject")

	if visualizer == nil then
		return
	end

	local bars = {}

	for _, child in visualizer:GetChildren() do
		if child:IsA("GuiObject") and child.Name == "Bar" then
			table.insert(bars, child)
		end
	end

	table.sort(bars, function(a, b)
		return a.Position.X.Scale < b.Position.X.Scale
	end)

	self.bars = bars
end

-- SongsPanel.BackgroundFx fills the empty background: its Marquee rows of text
-- drift, alternately left and right, and its Sparkle stars twinkle and turn.
function SongSelectScreen._bindBackdrop(self: SongSelectScreen)
	local fx = UiKit.authored(self.background, "BackgroundFx", "GuiObject")

	if fx == nil then
		return
	end

	for _, child in fx:GetChildren() do
		if child:IsA("GuiObject") and child.Name == "Marquee" then
			table.insert(self.marquees, child)
		elseif child:IsA("GuiObject") and child.Name == "Sparkle" then
			table.insert(self.sparkles, child)
		end
	end

	table.sort(self.marquees, byLayout)
	table.sort(self.sparkles, byLayout)
end

-- Each tab lists one pack of songs; the open one wears the first tab's art and
-- the others the second's. A tab with no songs yet only answers that they are coming.
function SongSelectScreen._bindTabs(self: SongSelectScreen)
	local frame = UiKit.authored(self.root, "SongsFrame2", "GuiObject")

	if frame == nil then
		return
	end

	local buttons = {}
	local childOrder: { [Instance]: number } = {}

	for index, child in frame:GetChildren() do
		if child:IsA("GuiButton") then
			table.insert(buttons, child)
			childOrder[child] = index
		end
	end

	-- In the order the list layout shows them, which for equal LayoutOrders is
	-- the Explorer's, not the names'.
	table.sort(buttons, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end

		return childOrder[a] < childOrder[b]
	end)

	for order, button in buttons do
		local label = button:FindFirstChildOfClass("TextLabel")
		local tab: Tab = {
			button = button,
			label = label,
			pop = UiKit.scaleOf(button, "Pop"),
			pack = order,
			text = if label ~= nil then label.Text else "",
			image = if button:IsA("ImageButton") then UiKit.imageState(button) else nil,
			busy = false,
		}
		table.insert(self.tabs, tab)

		UiKit.bindSounds(button)
		button.MouseEnter:Connect(function()
			tween(tab.pop, HOVER_SECONDS, { Scale = TAB_HOVER_SCALE }, Enum.EasingStyle.Back)
			tween(button, HOVER_SECONDS, { Rotation = TAB_HOVER_TILT }, Enum.EasingStyle.Back)
		end)
		button.MouseLeave:Connect(function()
			tween(tab.pop, HOVER_SECONDS, { Scale = 1 })
			tween(button, HOVER_SECONDS, { Rotation = 0 })
		end)
		button.MouseButton1Down:Connect(function()
			tween(tab.pop, PRESS_SECONDS, { Scale = PRESS_SCALE })
		end)
		button.Activated:Connect(function()
			tween(tab.pop, POP_SECONDS, { Scale = TAB_HOVER_SCALE }, Enum.EasingStyle.Back)

			if #self:_packSongs(tab.pack) > 0 then
				self:_setPack(tab.pack)
			else
				self:_tabSoon(tab)
			end
		end)
	end
end

function SongSelectScreen._tabSoon(self: SongSelectScreen, tab: Tab)
	if tab.busy then
		return
	end

	tab.busy = true
	tab.button.Rotation = TAB_SHAKE_DEGREES
	tween(tab.button, POP_SECONDS, { Rotation = 0 }, Enum.EasingStyle.Elastic)

	if tab.label ~= nil then
		tab.label.Text = TAB_SOON_TEXT
	end

	task.delay(TAB_SOON_SECONDS, function()
		tab.busy = false

		if tab.label ~= nil then
			tab.label.Text = tab.text
		end
	end)
end

function SongSelectScreen._paintTabs(self: SongSelectScreen)
	local active = self.tabs[1]
	local idle = self.tabs[2]

	for _, tab in self.tabs do
		local button = tab.button

		local image = if tab.pack == self.pack then active and active.image else idle and idle.image

		if image == nil or #self:_packSongs(tab.pack) == 0 then
			continue
		end

		UiKit.setImage(button, image)
	end
end

function SongSelectScreen._packSongs(self: SongSelectScreen, pack: number): { Song }
	local songs = {}

	for _, song in self.allSongs do
		if song.pack == pack then
			table.insert(songs, song)
		end
	end

	return songs
end

-- Lists the open pack's songs, rebuilding the rows only when they changed.
function SongSelectScreen._useSongs(self: SongSelectScreen)
	local songs = self:_packSongs(self.pack)
	local ids = { tostring(self.pack) }

	for _, song in songs do
		table.insert(ids, song.id .. ":" .. #song.charts)
	end

	local signature = table.concat(ids, ",")

	if signature ~= self.signature then
		self.signature = signature
		self:_buildRows(songs)
	else
		self.songs = songs
	end

	self.selected = math.clamp(self.selected, 1, math.max(#self.songs, 1))
end

function SongSelectScreen._setPack(self: SongSelectScreen, pack: number)
	if pack == self.pack or not self.open then
		return
	end

	self.pack = pack
	self.selected = 1
	self:_useSongs()
	self:_paintTabs()
	self:_refresh(true)
	self:_dealRight()

	for index, row in self.rows do
		popIn(row.normalScale, index * ROW_STAGGER)
	end
end

-- Everything that fades out when the run starts, with the transparency it
-- comes back to for the next open.
function SongSelectScreen._bindFades(self: SongSelectScreen)
	local function add(object: Instance?, property: string)
		if object ~= nil then
			table.insert(self.fades, { object = object, property = property, value = (object :: any)[property] })
		end
	end

	add(self.background, "ImageTransparency")
	add(self.backdrop, "BackgroundTransparency")
	add(self.info, "TextTransparency")

	if self.infoPanel ~= nil and self.infoPanel:IsA("ImageLabel") then
		add(self.infoPanel, "ImageTransparency")
	end

	local fx = if self.background ~= nil then self.background:FindFirstChild("BackgroundFx") else nil
	local parts: { Instance } = if fx ~= nil then fx:GetDescendants() else {}

	for _, part in parts do
		if part:IsA("TextLabel") then
			add(part, "TextTransparency")
		elseif part:IsA("ImageLabel") then
			add(part, "ImageTransparency")
		end
	end
end

function SongSelectScreen._coverScreen(self: SongSelectScreen)
	for _, layer in { self.backdrop, self.background :: GuiObject? } do
		if layer ~= nil and self.gui ~= nil then
			layer.AnchorPoint = Vector2.zero
			UiKit.coverScreen(layer, self.gui)
		end
	end
end

function SongSelectScreen.applyLayout(self: SongSelectScreen, _isSmall: boolean)
	-- Touch has no key to reopen the picker, so it never closes there.
	if self.backButton ~= nil then
		self.backButton.Visible = not UiKit.isTouch()
	end

	self:_coverScreen()
end

function SongSelectScreen.bindChosen(self: SongSelectScreen, callback: (index: number) -> ())
	self.onChosen = callback
end

function SongSelectScreen.bindBack(self: SongSelectScreen, callback: () -> ())
	self.onBack = callback
end

function SongSelectScreen.bindSetlist(self: SongSelectScreen, callback: () -> ())
	self.onSetlist = callback
end

-- callback hears the catalog index of each chart the picker highlights.
-- provider answers the playing preview's beat on its own grid, or nil, and its loudness.
function SongSelectScreen.bindAudio(self: SongSelectScreen, provider: () -> (number?, number))
	self.audioState = provider
end

function SongSelectScreen.bindFocused(self: SongSelectScreen, callback: (index: number) -> ())
	self.onFocused = callback
end

function SongSelectScreen._focus(self: SongSelectScreen)
	local song = self.songs[self.selected]

	if song ~= nil and self.onFocused ~= nil and self.open then
		self.onFocused(song.charts[song.picked].index)
	end
end

function SongSelectScreen.isVisible(self: SongSelectScreen): boolean
	return self.open
end

function SongSelectScreen.show(self: SongSelectScreen, entries: any)
	local root = self.root

	if root == nil then
		return
	end

	local picks = {}

	for _, song in self.allSongs do
		picks[song.id] = song.picked
	end

	local all = groupSongs(if type(entries) == "table" then entries else {})

	for _, song in all do
		song.picked = math.clamp(picks[song.id] or song.picked, 1, #song.charts)
	end

	self.allSongs = all

	if #self:_packSongs(self.pack) == 0 and all[1] ~= nil then
		self.pack = all[1].pack
	end

	local opening = not self.open

	self:_useSongs()
	self:_paintTabs()
	self.open = true
	self.closeToken += 1
	root.Visible = true

	if opening then
		self:_playOpen()
	end

	self:_refresh(opening)
	self:_startBeat()
end

function SongSelectScreen.hide(self: SongSelectScreen)
	local root = self.root

	if root ~= nil and self.launching then
		local token = self.closeToken

		task.delay(math.max(LAUNCH_HOLD_SECONDS - (os.clock() - self.launchedAt), 0), function()
			if self.closeToken == token then
				self:_reveal()
			end
		end)

		return
	end

	if root == nil or not self.open then
		return
	end

	self.open = false
	self.closeToken += 1

	local token = self.closeToken

	for _, slide in self.slides do
		local home = slide.home
		tween(slide.object, CLOSE_SECONDS, {
			Position = UDim2.new(home.X.Scale + SLIDE_DISTANCE * slide.side, home.X.Offset, home.Y.Scale, home.Y.Offset),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	if self.background ~= nil then
		tween(self.background, CLOSE_SECONDS, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	task.delay(CLOSE_SECONDS, function()
		if self.closeToken ~= token then
			return
		end

		root.Visible = false

		if self.beatConnection ~= nil then
			self.beatConnection:Disconnect()
			self.beatConnection = nil
		end
	end)
end

-- A song was picked: everything but its title clears away, the title grows in
-- the middle and holds the screen until the run starts and hide() reveals it.
function SongSelectScreen.launch(self: SongSelectScreen)
	local root = self.root

	if root == nil or not self.open then
		return
	end

	self.open = false
	self.launching = true
	self.launchedAt = os.clock()
	self.closeToken += 1

	local song = self.songs[self.selected]

	if self.info ~= nil and song ~= nil then
		local difficulty = song.charts[song.picked].difficulty
		self.info.Text = READY_TEXT .. " - " .. (DIFFICULTY_LABELS[difficulty] or string.upper(difficulty))
	end

	local token = self.closeToken

	for _, slide in self.slides do
		local object = slide.object
		local home = slide.home

		if object == self.titleFrame then
			tween(object, LAUNCH_SECONDS, { Position = UDim2.fromScale(0.5, LAUNCH_TITLE_Y) }, Enum.EasingStyle.Back)
		elseif object == self.infoPanel then
			tween(object, LAUNCH_SECONDS, { Position = UDim2.fromScale(0.5, LAUNCH_INFO_Y) }, Enum.EasingStyle.Back)
		else
			tween(object, CLOSE_SECONDS, {
				Position = UDim2.new(home.X.Scale + SLIDE_DISTANCE * slide.side, home.X.Offset, home.Y.Scale, home.Y.Offset),
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end

	if self.launchScale ~= nil then
		tween(self.launchScale, LAUNCH_SECONDS, { Scale = LAUNCH_TITLE_SCALE }, Enum.EasingStyle.Back)
	end

	for index, tile in self.tiles do
		local pop = UiKit.scaleOf(tile, "Pop")
		pop.Scale = LAUNCH_WAVE
		tween(pop, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, LAUNCH_SECONDS + index * TILE_STAGGER)
	end

	task.delay(LAUNCH_TIMEOUT_SECONDS, function()
		if self.closeToken == token and self.launching then
			self:_reveal()
		end
	end)
end

-- The launch cover sweeps off to the left onto the stage.
function SongSelectScreen._reveal(self: SongSelectScreen)
	local root = self.root

	if root == nil or not self.launching then
		return
	end

	self.launching = false
	self.closeToken += 1

	local token = self.closeToken

	-- The fade owns every transparency from here, so the beat loop stops.
	if self.beatConnection ~= nil then
		self.beatConnection:Disconnect()
		self.beatConnection = nil
	end

	if self.zoom ~= nil then
		tween(self.zoom, REVEAL_SECONDS, { Scale = REVEAL_ZOOM }, Enum.EasingStyle.Quad)
	end

	for index, tile in self.tiles do
		local delay = (index - 1) * REVEAL_STAGGER
		local spin = (if index % 2 == 0 then 1 else -1) * REVEAL_TILE_SPIN
		local letter = tile:FindFirstChildOfClass("TextLabel")

		local style, direction = Enum.EasingStyle.Quad, Enum.EasingDirection.In

		tween(UiKit.scaleOf(tile, "Pop"), REVEAL_SECONDS, { Scale = REVEAL_TILE_SCALE }, style, direction, delay)
		tween(tile, REVEAL_SECONDS, { Rotation = spin }, style, direction, delay)

		if tile:IsA("ImageLabel") then
			tween(tile, REVEAL_SECONDS, { ImageTransparency = 1 }, style, direction, delay)
		end

		if letter ~= nil then
			tween(letter, REVEAL_SECONDS, { TextTransparency = 1 }, style, direction, delay)
		end
	end

	for _, fade in self.fades do
		tween(fade.object, REVEAL_SECONDS, { [fade.property] = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	task.delay(REVEAL_SECONDS + #self.tiles * REVEAL_STAGGER, function()
		if self.closeToken ~= token then
			return
		end

		root.Visible = false

		if self.launchScale ~= nil then
			self.launchScale.Scale = 1
		end

		if self.zoom ~= nil then
			self.zoom.Scale = 1
		end

		for _, fade in self.fades do
			(fade.object :: any)[fade.property] = fade.value
		end
	end)
end

-- index is the catalog entry the lobby last played; the picker opens on its song and chart.
function SongSelectScreen.setSelected(self: SongSelectScreen, index: number?)
	if index == nil then
		return
	end

	for _, song in self.allSongs do
		for chartIndex, chart in song.charts do
			if chart.index == index then
				song.picked = chartIndex

				if song.pack ~= self.pack then
					self.pack = song.pack
					self:_useSongs()
					self:_paintTabs()
				end

				self:_select(table.find(self.songs, song) or 1, false)
				return
			end
		end
	end
end

function SongSelectScreen.moveSong(self: SongSelectScreen, delta: number)
	if self.open and #self.songs > 0 then
		self:_select((self.selected - 1 + delta) % #self.songs + 1, true)
	end
end

function SongSelectScreen.moveDifficulty(self: SongSelectScreen, delta: number)
	local song = self.songs[self.selected]

	if self.open and song ~= nil then
		local picked = math.clamp(song.picked + delta, 1, #song.charts)
		self:_pickDifficulty(song.charts[picked].difficulty)
	end
end

function SongSelectScreen.confirm(self: SongSelectScreen)
	local song = self.songs[self.selected]

	if not self.open or song == nil or self.onChosen == nil then
		return
	end

	local continueScale = self.continueScale

	if continueScale ~= nil then
		continueScale.Scale = 0.9
		tween(continueScale, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	self.onChosen(song.charts[song.picked].index)
end

function SongSelectScreen._buildRows(self: SongSelectScreen, songs: { Song })
	for _, row in self.rows do
		row.normal:Destroy()
		row.selected:Destroy()
	end

	self.rows = {}
	self.songs = songs

	local list = self.list
	local rowTemplate = self.rowTemplate
	local selectedTemplate = self.selectedTemplate

	if list == nil or rowTemplate == nil or selectedTemplate == nil then
		return
	end

	for index in songs do
		local normal = rowTemplate:Clone() :: GuiButton
		local selected = selectedTemplate:Clone() :: GuiButton

		normal.Name = "Song" .. index
		selected.Name = "Song" .. index .. "Selected"
		normal.LayoutOrder = index
		selected.LayoutOrder = index
		selected.Visible = false

		local numberLabel = childLabel(selected, function(label)
			return label:FindFirstChildOfClass("UIGradient") ~= nil
		end)
		local starScales = {}

		for _, part in selected:GetChildren() do
			if part:IsA("Frame") then
				for _, star in starsIn(part) do
					table.insert(starScales, UiKit.scaleOf(star, "Twinkle"))
				end
			end
		end

		local row: Row = {
			normal = normal,
			selected = selected,
			normalScale = UiKit.scaleOf(normal, "Pop"),
			selectedScale = UiKit.scaleOf(selected, "Pop"),
			numberGradient = if numberLabel ~= nil then numberLabel:FindFirstChildOfClass("UIGradient") else nil,
			starScales = starScales,
		}

		UiKit.bindSounds(normal)
		normal.Activated:Connect(function()
			self:_select(index, true)
		end)
		selected.Activated:Connect(function()
			self:confirm()
		end)
		local title = normal:FindFirstChild("SongLabel")
		local titleColor = if title ~= nil and title:IsA("TextLabel") then title.TextColor3 else WHITE

		normal.MouseEnter:Connect(function()
			tween(row.normalScale, HOVER_SECONDS, { Scale = HOVER_SCALE }, Enum.EasingStyle.Back)

			if title ~= nil and title:IsA("TextLabel") then
				tween(title, HOVER_SECONDS, { TextColor3 = HOVER_TINT })
			end
		end)
		normal.MouseButton1Down:Connect(function()
			tween(row.normalScale, PRESS_SECONDS, { Scale = PRESS_SCALE })
		end)
		normal.MouseLeave:Connect(function()
			tween(row.normalScale, HOVER_SECONDS, { Scale = 1 })

			if title ~= nil and title:IsA("TextLabel") then
				tween(title, HOVER_SECONDS, { TextColor3 = titleColor })
			end
		end)

		normal.Parent = list
		selected.Parent = list
		self.rows[index] = row
	end
end

function SongSelectScreen._select(self: SongSelectScreen, index: number, animate: boolean)
	if self.songs[index] == nil then
		return
	end

	local changed = index ~= self.selected
	self.selected = index

	if self.open then
		self:_refresh(animate and changed)

		if animate and changed then
			self:_dealRight()
		end
	end
end

-- The right side's panels come in again from the right, one after another.
function SongSelectScreen._dealRight(self: SongSelectScreen)
	local root = self.root

	if root == nil then
		return
	end

	for order, name in SWAP_PANELS do
		local panel = root:FindFirstChild(name)
		local home = if panel ~= nil and panel:IsA("GuiObject") then self.homes[panel] else nil

		if panel ~= nil and panel:IsA("GuiObject") and home ~= nil then
			panel.Position = home + UDim2.fromScale(SWAP_DISTANCE, 0)
			tween(panel, POP_SECONDS, { Position = home }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, (order - 1) * SWAP_STAGGER)
		end
	end
end

function SongSelectScreen._pickDifficulty(self: SongSelectScreen, difficulty: string?)
	local song = self.songs[self.selected]

	if song == nil or difficulty == nil then
		return
	end

	for chartIndex, chart in song.charts do
		if chart.difficulty == difficulty and chartIndex ~= song.picked then
			song.picked = chartIndex
			self:_paintRows(false)
			self:_paintBadges(true)
			self:_paintBest()
			self:_focus()
			return
		end
	end
end

function SongSelectScreen._refresh(self: SongSelectScreen, animate: boolean)
	local song = self.songs[self.selected]

	self:_paintRows(animate)
	self:_buildTitle(if song ~= nil then song.title else "LOADING", animate)
	self:_paintBadges(animate)
	self:_paintBest()

	if self.info ~= nil then
		self.info.Text = if song ~= nil
			then (if song.artist ~= "" then song.artist .. " - " else "") .. ("%d BPM"):format(song.bpm)
			else ""
	end

	task.defer(function()
		self:_scrollToSelected()
	end)

	self:_focus()
end

function SongSelectScreen._fillRow(self: SongSelectScreen, row: GuiButton, song: Song, number: number, isSelected: boolean)
	local chart = song.charts[song.picked]
	local entry = if chart ~= nil then chart.entry else {}
	local locked = entry.locked == true
	local numberLabel = childLabel(row, function(label)
		return label:FindFirstChildOfClass("UIGradient") ~= nil
	end)
	local title = row:FindFirstChild("SongLabel")
	local info = childLabel(row, function(label)
		return string.find(label.Name, "Bpm", 1, true) ~= nil
	end)
	local rank = row:FindFirstChild("APanel")
	local rankLabel = if rank ~= nil then rank:FindFirstChildOfClass("TextLabel") else nil

	if numberLabel ~= nil then
		numberLabel.Text = ("%02d"):format(number)
	end

	if title ~= nil and title:IsA("TextLabel") then
		setLine(title, song.title)
	end

	if info ~= nil then
		local bpm = ("%d BPM"):format(song.bpm)

		setLine(
			info,
			if locked
				then string.upper(tostring(entry.requirementText or "LOCKED"))
				else bpm
		)
	end

	local hasRank = type(entry.bestRank) == "string" and entry.bestRank ~= ""

	if rankLabel ~= nil then
		if rankLabel:GetAttribute("RankColor") == nil then
			rankLabel:SetAttribute("RankColor", rankLabel.TextColor3)
		end

		rankLabel.Text = if hasRank then entry.bestRank else "-"
		rankLabel.TextColor3 = if hasRank then rankLabel:GetAttribute("RankColor") :: Color3 else EMPTY_RANK_TEXT
	end

	if rank ~= nil and rank:IsA("ImageLabel") then
		rank.ImageTransparency = if hasRank then 0 else EMPTY_RANK_FADE
	end

	if row:IsA("ImageButton") then
		row.ImageColor3 = if locked then LOCKED_TINT else WHITE
	end

	for _, child in row:GetChildren() do
		if child:IsA("Frame") and #starsIn(child) > 0 then
			local lit = chartStars(chart)
			paintStars(child, lit, if isSelected then PINK else WHITE, if isSelected then SELECTED_STAR_OFF else ROW_STAR_OFF)
		end
	end

	fade(row, if locked then LOCKED_FADE else 0)
end

function SongSelectScreen._paintRows(self: SongSelectScreen, animate: boolean)
	for index, row in self.rows do
		local song = self.songs[index]
		local isSelected = index == self.selected
		local wasSelected = row.selected.Visible

		-- Shown first, so the row that just turned visible measures its own text.
		row.normal.Visible = not isSelected
		row.selected.Visible = isSelected
		self:_fillRow(row.normal, song, index, false)
		self:_fillRow(row.selected, song, index, true)

		if isSelected and (animate or not wasSelected) then
			popIn(row.selectedScale, 0)
		elseif not isSelected and wasSelected then
			row.normalScale.Scale = 1
		end
	end
end

function SongSelectScreen._buildTitle(self: SongSelectScreen, text: string, animate: boolean)
	local titleFrame = self.titleFrame
	local templates = self.tileTemplates

	if titleFrame == nil or #templates == 0 then
		return
	end

	for _, tile in self.tiles do
		tile:Destroy()
	end

	self.tiles = {}
	self.letterScales = {}

	local count = 0

	for character in string.gmatch(string.sub(text, 1, MAX_TITLE_TILES), utf8.charpattern) do
		count += 1

		local tile: GuiObject

		if character == " " then
			tile = Instance.new("Frame")
			tile.BackgroundTransparency = 1
			tile.Size = UDim2.fromScale(0.25, 0.25)
			tile.SizeConstraint = Enum.SizeConstraint.RelativeYY
		else
			tile = templates[(count - 1) % #templates + 1]:Clone() :: GuiObject

			local label = tile:FindFirstChildOfClass("TextLabel")

			if label ~= nil then
				label.Text = character
			end
		end

		tile.Name = "Tile" .. count
		tile.LayoutOrder = count
		tile:SetAttribute("BaseSize", tile.Size.Y.Scale)

		tile.Parent = titleFrame
		table.insert(self.tiles, tile)

		local letter = tile:FindFirstChildOfClass("TextLabel")

		if letter ~= nil then
			table.insert(self.letterScales, UiKit.scaleOf(letter, "Beat"))
		end

		if animate and character ~= " " then
			local pop = UiKit.scaleOf(tile, "Pop")
			pop.Scale = 0
			tween(pop, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, (count - 1) * TILE_STAGGER)
		end
	end

	self:_fitTitle()
end

-- Long titles shrink every tile until the row fits the frame.
function SongSelectScreen._fitTitle(self: SongSelectScreen)
	local titleFrame = self.titleFrame

	if titleFrame == nil or #self.tiles == 0 then
		return
	end

	local width, height = titleFrame.AbsoluteSize.X, titleFrame.AbsoluteSize.Y

	if width <= 0 or height <= 0 then
		return
	end

	local needed = 0

	for _, tile in self.tiles do
		local base = tile:GetAttribute("BaseSize") :: number? or 0.65
		local aspect = tile:FindFirstChildOfClass("UIAspectRatioConstraint")
		needed += base * height * (if aspect ~= nil then aspect.AspectRatio else 1)
	end

	local fit = math.min(1, width / math.max(needed, 1))

	for _, tile in self.tiles do
		local base = tile:GetAttribute("BaseSize") :: number? or 0.65
		tile.Size = UDim2.fromScale(base * fit, base * fit)
	end
end

function SongSelectScreen._paintBadges(self: SongSelectScreen, animate: boolean)
	local song = self.songs[self.selected]

	for order, badge in self.badges do
		local chart = if song ~= nil then song.charts[order] else nil
		local button = badge.button

		badge.difficulty = if chart ~= nil then chart.difficulty else nil
		button.Visible = chart ~= nil

		if chart == nil or song == nil then
			continue
		end

		local isPicked = order == song.picked
		local locked = chart.entry.locked == true
		local size = if isPicked then BADGE_BIG else BADGE_SMALL

		if badge.label ~= nil then
			badge.label.Text = DIFFICULTY_LABELS[chart.difficulty] or string.upper(chart.difficulty)
			badge.label.TextColor3 = if isPicked then WHITE else BLACK
		end

		if button:IsA("ImageButton") then
			button.ImageColor3 = if isPicked then BLACK else WHITE
			button.ImageTransparency = if locked then LOCKED_FADE else 0
		end

		local stars = badge.stars

		local have = if badge.stars ~= nil then starsIn(badge.stars) else {}

		if stars ~= nil and #have > 0 then
			local wanted = chartStars(chart)

			for index = #have + 1, wanted do
				local star = have[1]:Clone()
				star.Name = "Star" .. index
				star.LayoutOrder = index
				star.Parent = stars
			end

			for index, star in starsIn(stars) do
				star.LayoutOrder = index
				star.Visible = index <= wanted
				star.ImageColor3 = if isPicked then PINK else BLACK
			end
		end

		if animate then
			tween(button, BADGE_SECONDS, { Size = UDim2.fromScale(size, size) }, Enum.EasingStyle.Back)
		else
			button.Size = UDim2.fromScale(size, size)
		end
	end
end

function SongSelectScreen._paintBest(self: SongSelectScreen)
	local song = self.songs[self.selected]
	local best = self.best

	if song == nil then
		return
	end

	local entry = song.charts[song.picked].entry
	local hasBest = type(entry.bestScore) == "number" and entry.bestScore > 0
	local goal = if type(entry.performanceGoal) == "table" then tonumber(entry.performanceGoal.targetScore) else nil

	local score = if hasBest then entry.bestScore elseif goal ~= nil then goal else nil

	if self.scoreTween ~= nil then
		self.scoreTween:Cancel()
		self.scoreTween = nil
	end

	if score ~= nil then
		self.scoreTween = tween(self.scoreValue, COUNT_SECONDS, { Value = score }, Enum.EasingStyle.Quad)
	elseif best.score ~= nil then
		best.score.Text = "-"
	end

	local texts: { { label: TextLabel?, text: string } } = {
		{ label = best.kind, text = if hasBest then "BEST" else "GOAL" },
		{ label = best.rank, text = if hasBest and type(entry.bestRank) == "string" then entry.bestRank else "-" },
		{
			label = best.combo,
			text = if hasBest and tonumber(entry.bestCombo) ~= nil
				then ("COMBO %d"):format(entry.bestCombo)
				else songLength(entry.durationSeconds),
		},
		{ label = best.status, text = if entry.locked == true then "LOCKED" elseif hasBest then "CLEAR" else "NEW" },
	}

	for _, item in texts do
		if item.label ~= nil then
			item.label.Text = item.text
		end
	end
end

function SongSelectScreen._scrollToSelected(self: SongSelectScreen)
	local list = self.list
	local row = self.rows[self.selected]

	if list == nil or row == nil or not self.open then
		return
	end

	local target = row.selected
	local top = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
	local wanted = top - (list.AbsoluteSize.Y - target.AbsoluteSize.Y) / 2
	local limit = math.max(list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y, 0)

	tween(list, POP_SECONDS, { CanvasPosition = Vector2.new(0, math.clamp(wanted, 0, limit)) })
end

function SongSelectScreen._playOpen(self: SongSelectScreen)
	self:_coverScreen()
	self.openedAt = os.clock()

	if self.background ~= nil then
		self.background.ImageTransparency = 1
		tween(self.background, FADE_SECONDS, { ImageTransparency = 0 }, Enum.EasingStyle.Quad)
	end

	for order, slide in self.slides do
		local home = slide.home
		slide.object.Position = UDim2.new(home.X.Scale + SLIDE_DISTANCE * slide.side, home.X.Offset, home.Y.Scale, home.Y.Offset)
		tween(slide.object, OPEN_SECONDS, { Position = home }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, (order % 6) * SLIDE_STAGGER)
	end

	for order, letter in self.letters do
		popIn(letter, 0.1 + order * TILE_STAGGER)
	end

	for index, row in self.rows do
		popIn(row.normalScale, 0.12 + index * ROW_STAGGER)
	end
end

-- While open the picker breathes with the selected song: CONTINUE and the
-- picked badge bump on its beat, and the backdrop drifts.
function SongSelectScreen._startBeat(self: SongSelectScreen)
	if self.beatConnection ~= nil then
		return
	end

	self.beatConnection = RunService.RenderStepped:Connect(function()
		local song = self.songs[self.selected]
		local audioBeats, loudness = nil, 0

		if self.audioState ~= nil then
			audioBeats, loudness = self.audioState()
		end

		local beats = audioBeats or (os.clock() - self.openedAt) * (if song ~= nil then song.bpm else DEFAULT_BPM) / 60
		local bump = (1 - beats % 1) ^ 3 * BEAT_BUMP

		if self.continueScale ~= nil then
			self.continueScale.Scale = 1 + bump + (if self.continueHover then CONTINUE_HOVER else 0)
		end

		for _, badge in self.badges do
			local picked = song ~= nil and badge.difficulty == song.charts[song.picked].difficulty
			local hovered = self.badgeHover == badge.button
			badge.scale.Scale = 1 + (if picked then bump else 0) + (if hovered then BADGE_HOVER else 0)
		end

		local elapsed = os.clock() - self.openedAt
		local drift = (elapsed / MARQUEE_LOOP_SECONDS) % 1

		for index, marquee in self.marquees do
			local x = if index % 2 == 1 then -drift * MARQUEE_WIDTH else (drift - 1) * MARQUEE_WIDTH
			marquee.Position = UDim2.new(x, 0, marquee.Position.Y.Scale, marquee.Position.Y.Offset)
		end

		for index, sparkle in self.sparkles do
			local twinkle = 0.5 + 0.5 * math.sin(elapsed * 2 + index * 1.3)

			if sparkle:IsA("ImageLabel") then
				sparkle.ImageTransparency = 0.15 + 0.7 * twinkle
			end

			sparkle.Rotation = elapsed * SPARKLE_SPIN * (if index % 2 == 0 then 1 else -1)
		end

		local beatInt = math.floor(beats)

		if beatInt ~= self.lastBeat then
			self.lastBeat = beatInt
			self:_onBeat(beatInt)
		end

		for index, letterScale in self.selectLetterScales do
			local phase = (beats / 2 - (index - 1) * SELECT_WAVE_STEP) % 1
			letterScale.Scale = 1 + SELECT_BOUNCE * math.max(1 - phase * 4, 0) ^ 2
		end

		local row = self.rows[self.selected]

		if row ~= nil and song ~= nil then
			local lit = chartStars(song.charts[song.picked])
			local turn = math.floor(beats) % lit + 1

			if row.numberGradient ~= nil then
				row.numberGradient.Offset = Vector2.new(0, math.sin(os.clock() * 2.2) * NUMBER_SHIMMER)
			end

			for index, scale in row.starScales do
				scale.Scale = if index == turn then 1 + STAR_TWINKLE * math.max(1 - (beats % 1) * 3, 0) else 1
			end
		end

		if self.previewLabel ~= nil then
			self.previewLabel.TextTransparency = PREVIEW_BLINK * math.min((beats % 1) * 2, 1)
		end

		if self.songTag ~= nil then
			self.songTag.Rotation = math.sin(os.clock() * 1.8) * TAG_WOBBLE_DEGREES
		end

		for index, letterScale in self.letterScales do
			local phase = (beats - (index - 1) * LETTER_WAVE_STEP) % 1
			letterScale.Scale = 1 + LETTER_BOUNCE * math.max(1 - phase * 4, 0) ^ 2
		end

		for index, badge in self.badges do
			local picked = song ~= nil and badge.difficulty == song.charts[song.picked].difficulty
			badge.button.Rotation = if picked then 0 else math.sin(elapsed * 1.6 + index * 1.9) * BADGE_ROCK_DEGREES
		end

		for index, panel in { self.infoPanel, self.bestPanel, self.continueButton :: GuiObject? } do
			if panel ~= nil and not self.launching then
				panel.Rotation = math.sin(elapsed * (1 + index * 0.25) + index) * PANEL_ROCK_DEGREES
			end
		end

		if self.backdropGradient ~= nil then
			self.backdropGradient.Offset = Vector2.new(math.sin(elapsed * 0.4) * BACKDROP_DRIFT, 0)
		end

		local count = #self.bars

		if audioBeats ~= nil and count > 0 then
			self:_paintLevels(loudness)
			return
		end

		local kick = (1 - beats % 1) ^ 3
		local snare = (1 - (beats + 0.5) % 1) ^ 3

		for index, bar in self.bars do
			local along = if count > 1 then (index - 1) / (count - 1) else 0
			local weight = 0.6 + 0.4 * math.abs(math.sin(index * 1.7))
			local shimmer = math.sin(beats * math.pi * 2 + index * 0.9) * BAR_SHIMMER
			local height = BAR_REST + (BAR_KICK * kick * (1 - along) + BAR_SNARE * snare * along) * weight + shimmer
			bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, math.clamp(height, BAR_REST * 0.5, 1), 0)
		end
	end)
end

function SongSelectScreen._kick(self: SongSelectScreen)
	local kickScale = self.kickScale

	if kickScale ~= nil then
		kickScale.Scale = KICK_SCALE
		tween(kickScale, KICK_SECONDS, { Scale = 1 }, Enum.EasingStyle.Quad)
	end

	for _ = 1, 2 do
		local sparkle: GuiObject? = self.sparkles[math.random(1, math.max(#self.sparkles, 1))]

		if sparkle ~= nil then
			local pop = UiKit.scaleOf(sparkle, "Pop")
			pop.Scale = SPARKLE_POP
			tween(pop, KICK_SECONDS * 2, { Scale = 1 }, Enum.EasingStyle.Quad)
		end
	end
end

-- Once per beat: a backdrop star pops in turn, and every few beats a title tile spins.
function SongSelectScreen._onBeat(self: SongSelectScreen, beat: number)
	if #self.sparkles > 0 then
		local pop = UiKit.scaleOf(self.sparkles[beat % #self.sparkles + 1], "Pop")
		pop.Scale = SPARKLE_POP
		tween(pop, KICK_SECONDS * 2, { Scale = 1 }, Enum.EasingStyle.Quad)
	end

	if beat % TILE_SPIN_EVERY_BEATS ~= 0 or #self.tiles == 0 then
		return
	end

	local tile = self.tiles[(beat // TILE_SPIN_EVERY_BEATS) % #self.tiles + 1]

	if tile:IsA("ImageLabel") then
		tile.Rotation = 0
		local spin = tween(tile, TILE_SPIN_SECONDS, { Rotation = 360 }, Enum.EasingStyle.Back)

		spin.Completed:Connect(function()
			tile.Rotation = 0
		end)
	end
end

function SongSelectScreen._paintLevels(self: SongSelectScreen, loudness: number)
	local now = os.clock()

	self.levelPeak = math.max(self.levelPeak * LEVEL_PEAK_DECAY, loudness, LEVEL_MIN_PEAK)

	local target = math.clamp(loudness / self.levelPeak, 0, 1) ^ LEVEL_CONTRAST
	local blend = if target > self.level then LEVEL_ATTACK else LEVEL_RELEASE
	self.level += (target - self.level) * blend

	if target - self.lastLevel >= KICK_JUMP and now - self.lastKick >= KICK_GAP_SECONDS then
		self.lastKick = now
		self:_kick()
	end

	self.lastLevel = target

	local count = #self.bars
	local half = math.ceil(count / 2)

	if now - self.levelAt >= LEVEL_SAMPLE_SECONDS then
		self.levelAt = now
		table.insert(self.levels, 1, self.level)

		while #self.levels > half do
			table.remove(self.levels)
		end
	end

	local centre = (count + 1) / 2

	for index, bar in self.bars do
		local away = math.floor(math.abs(index - centre))
		local level = self.levels[away + 1] or 0
		local weight = 1 - LEVEL_EDGE_FALLOFF * away / math.max(half, 1)
		local height = BAR_REST + (1 - BAR_REST) * level * weight
		bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, math.clamp(height, BAR_REST * 0.5, 1), 0)
	end
end

return SongSelectScreen
