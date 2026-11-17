--!strict
local Players = game:GetService("Players")

local PadHud = require(script.Parent.PadHud)
local UiKit = require(script.Parent.Parent.UiKit)

-- The highway's top bar, after Friday Night Funkin's: a time bar with the
-- song's clock, and in a 1v1 the tug-of-war bar under it, where the split
-- between the two players' colours follows the score and both faces ride it.
local BAR_WIDTH = 0.4
local BAR_TOP = 8
local TIME_HEIGHT = 24
local STATS_GAP = 6
local STATS_HEIGHT = 20
local VERSUS_GAP = 20
local VERSUS_HEIGHT = 18
local ICON_SIZE = 56
local NAME_HEIGHT = 18
-- On the pad the bar is the thin time and versus lines authored in the
-- PadHud, so the screen's top belongs to the combo.
local THIN_STROKE = 1
local ICON_BOP = 0.2
local ICON_BOP_SECONDS = 0.25
local SPLIT_RATE = 6
local SPLIT_MIN = 0.06
local LOSING_TINT = Color3.fromRGB(120, 120, 130)
local BACK_COLOR = Color3.fromRGB(20, 8, 30)
local STROKE_COLOR = Color3.fromRGB(255, 120, 230)
local TIME_FROM = Color3.fromRGB(255, 90, 210)
local TIME_TO = Color3.fromRGB(80, 230, 255)
local OWN_COLOR = Color3.fromRGB(70, 230, 110)
local RIVAL_COLOR = Color3.fromRGB(240, 60, 80)
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local STATS_COLOR = Color3.fromRGB(235, 225, 255)
local MISS_COLOR = Color3.fromRGB(255, 120, 140)
local RANK_COLORS: { [string]: Color3 } = {
	S = UiKit.Colors.Yellow,
	A = UiKit.Colors.Green,
	B = UiKit.Colors.Cyan,
	C = Color3.fromRGB(201, 188, 230),
}
local RANK_GROW = 0.6
local RANK_POP = 1.6
local RANK_POP_SECONDS = 0.3
local FEVER_GOLD = UiKit.Colors.Amber
local FEVER_PINK = UiKit.Colors.Fever
local FEVER_PULSE_HZ = 4
local FEVER_GLOW_GROW = 10
local FEVER_GLOW_TRANSPARENCY = 0.35
local FEVER_STROKE_THICKNESS = 4

type Icon = {
	frame: GuiObject,
	image: ImageLabel,
	initial: TextLabel,
	scale: UIScale,
	userId: number?,
}

type Fields = {
	root: Frame,
	time: Frame,
	timeStroke: UIStroke,
	timeFill: Frame,
	timeGradient: UIGradient,
	timeLabel: TextLabel,
	feverGlow: Frame,
	stats: Frame,
	accuracyLabel: TextLabel,
	rankLabel: TextLabel,
	rankScale: UIScale,
	missLabel: TextLabel,
	rank: string?,
	rankAt: number,
	feverEndsAt: number,
	head: Frame,
	headScale: UIScale,
	versus: Frame,
	versusStroke: UIStroke,
	rivalFill: Frame,
	ownIcon: Icon,
	rivalIcon: Icon,
	rivalName: TextLabel,
	ownName: TextLabel,
	thin: boolean,
	visible: boolean,
	versusShown: boolean,
	playerRival: boolean,
	onPlayerRival: ((boolean) -> ())?,
	thinLines: { PadHud.Lines },
	thinIcons: { { own: Icon, rival: Icon } },
	split: number,
	targetSplit: number,
	lastBeat: number,
	beatAt: number,
	lastFrame: number,
}

local SongBar = {}
SongBar.__index = SongBar

export type SongBar = typeof(setmetatable({} :: Fields, SongBar))

local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)

	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function bar(parent: Instance, name: string, top: number, height: number): Frame
	local frame: Frame = UiKit.create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, top),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = BACK_COLOR,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	UiKit.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = STROKE_COLOR,
		Thickness = 2.5,
	}, frame)

	return frame
end

local function fill(parent: Instance, name: string, color: Color3): Frame
	local frame: Frame = UiKit.create("Frame", {
		Name = name,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)

	return frame
end

local function icon(parent: Instance, name: string, color: Color3): Icon
	local frame: Frame = UiKit.create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		BackgroundColor3 = BACK_COLOR,
		ZIndex = 3,
	}, parent)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	UiKit.create("UIStroke", { Color = color, Thickness = 3 }, frame)

	local image: ImageLabel = UiKit.create("ImageLabel", {
		Name = "Face",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}, frame)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, image)

	local initial: TextLabel = UiKit.create("TextLabel", {
		Name = "Initial",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
		Text = "",
		TextColor3 = color,
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
	}, frame)
	UiKit.create("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.18, 0),
	}, initial)

	return {
		frame = frame,
		image = image,
		initial = initial,
		scale = UiKit.create("UIScale", {}, frame),
		userId = nil,
	}
end

-- Under the bar at its own end: the rival on the left, you on the right.
local function nameTag(parent: Instance, name: string, text: string, color: Color3, side: Enum.TextXAlignment): TextLabel
	local label: TextLabel = UiKit.create("TextLabel", {
		Name = name,
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(0.35, 0, 0, NAME_HEIGHT),
		AnchorPoint = Vector2.new(if side == Enum.TextXAlignment.Right then 1 else 0, 0),
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = side,
	}, parent)

	if side == Enum.TextXAlignment.Right then
		label.Position = UDim2.new(1, 0, 1, 4)
	end

	UiKit.create("UIStroke", { Color = BACK_COLOR, Thickness = 2 }, label)

	return label
end

local function statLabel(parent: Instance, name: string, x: number, width: number, color: Color3): TextLabel
	local label: TextLabel = UiKit.create("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(width, 1),
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "",
		TextColor3 = color,
		TextScaled = true,
	}, parent)
	UiKit.create("UIStroke", { Color = BACK_COLOR, Thickness = 2 }, label)

	return label
end

-- Thumbnails are a web request, so the face fills in when it arrives. With no
-- user behind the name (a bot), the icon shows the name's initial instead.
local function showFace(target: Icon, userId: number?, name: string?)
	target.initial.Visible = userId == nil
	target.initial.Text = if name ~= nil then string.upper(string.sub(name, 1, 1)) else ""

	if userId == nil then
		target.userId = nil
		target.image.Image = ""
		return
	end

	if userId == target.userId then
		return
	end

	target.userId = userId

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)

		if ok and target.userId == userId then
			target.image.Image = content
		end
	end)
end

function SongBar.new(parent: Instance): SongBar
	local root: Frame = UiKit.create("Frame", {
		Name = "SongBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_TOP),
		Size = UDim2.new(BAR_WIDTH, 0, 0, TIME_HEIGHT + STATS_GAP + STATS_HEIGHT + VERSUS_GAP + VERSUS_HEIGHT + NAME_HEIGHT + 4),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)

	local feverGlow: Frame = UiKit.create("Frame", {
		Name = "FeverGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, TIME_HEIGHT / 2),
		Size = UDim2.new(1, FEVER_GLOW_GROW, 0, TIME_HEIGHT + FEVER_GLOW_GROW),
		BackgroundColor3 = FEVER_GOLD,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, root)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, feverGlow)

	local time = bar(root, "Time", 0, TIME_HEIGHT)
	local timeFill = fill(time, "Fill", Color3.new(1, 1, 1))
	local timeGradient: UIGradient = UiKit.create("UIGradient", { Color = ColorSequence.new(TIME_FROM, TIME_TO) }, timeFill)

	local head: Frame = UiKit.create("Frame", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(TIME_HEIGHT, TIME_HEIGHT),
		BackgroundColor3 = TIME_TO,
		ZIndex = 2,
	}, time)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, head)
	UiKit.create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, head)

	local timeLabel: TextLabel = UiKit.create("TextLabel", {
		Name = "Clock",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
		Text = "0:00 / 0:00",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = 3,
	}, time)
	UiKit.create("UIStroke", { Color = BACK_COLOR, Thickness = 2 }, timeLabel)

	local stats: Frame = UiKit.create("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TIME_HEIGHT + STATS_GAP),
		Size = UDim2.new(0.7, 0, 0, STATS_HEIGHT),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	local rankLabel = statLabel(stats, "Rank", 0.5, 0.2, RANK_COLORS.C)
	rankLabel.Position = UDim2.fromScale(0.5, -RANK_GROW / 2)
	rankLabel.Size = UDim2.fromScale(0.2, 1 + RANK_GROW)

	local versus = bar(root, "Versus", TIME_HEIGHT + STATS_GAP + STATS_HEIGHT + VERSUS_GAP, VERSUS_HEIGHT)
	versus.BackgroundColor3 = OWN_COLOR
	versus.BackgroundTransparency = 0
	versus.Visible = false
	local rivalFill = fill(versus, "Rival", RIVAL_COLOR)

	local rivalName = nameTag(versus, "RivalName", "", RIVAL_COLOR, Enum.TextXAlignment.Left)
	local ownName = nameTag(versus, "OwnName", "YOU", OWN_COLOR, Enum.TextXAlignment.Right)

	local self = setmetatable({
		root = root,
		time = time,
		timeStroke = time:FindFirstChildOfClass("UIStroke") :: UIStroke,
		timeFill = timeFill,
		timeGradient = timeGradient,
		timeLabel = timeLabel,
		feverGlow = feverGlow,
		stats = stats,
		accuracyLabel = statLabel(stats, "Accuracy", 0.2, 0.4, STATS_COLOR),
		rankLabel = rankLabel,
		rankScale = UiKit.create("UIScale", {}, rankLabel),
		missLabel = statLabel(stats, "Misses", 0.8, 0.4, MISS_COLOR),
		rank = nil,
		rankAt = -math.huge,
		feverEndsAt = 0,
		head = head,
		headScale = UiKit.create("UIScale", {}, head),
		versus = versus,
		versusStroke = versus:FindFirstChildOfClass("UIStroke") :: UIStroke,
		rivalFill = rivalFill,
		ownIcon = icon(versus, "You", OWN_COLOR),
		rivalIcon = icon(versus, "Rival", RIVAL_COLOR),
		rivalName = rivalName,
		ownName = ownName,
		thin = false,
		visible = false,
		versusShown = false,
		playerRival = false,
		onPlayerRival = nil,
		thinLines = {},
		thinIcons = {},
		split = 0.5,
		targetSplit = 0.5,
		lastBeat = -1,
		beatAt = -math.huge,
		lastFrame = os.clock(),
	} :: Fields, SongBar)

	showFace(self.ownIcon, Players.LocalPlayer.UserId)

	return self
end

function SongBar.setVisible(self: SongBar, visible: boolean)
	self.visible = visible
	self:_applyVisible()
	self.lastBeat = -1
	self.stats.Visible = false
	self.rank = nil
	self:_setFeverLook(false)
	self.feverEndsAt = 0
end

function SongBar._applyVisible(self: SongBar)
	self.root.Visible = self.visible and not self.thin

	for _, lines in self.thinLines do
		lines.time.Visible = self.visible and self.thin
		lines.versus.Visible = self.visible and self.thin and self.playerRival
	end
end

-- The authored thin lines, one set per PadHud layout.
function SongBar.bindThin(self: SongBar, lines: { PadHud.Lines })
	self.thinLines = lines
	table.clear(self.thinIcons)

	for _, set in lines do
		local own: Icon = {
			frame = set.ownIcon,
			image = set.ownFace,
			initial = set.ownInitial,
			scale = set.ownScale,
			userId = nil,
		}
		local rival: Icon = {
			frame = set.rivalIcon,
			image = set.rivalFace,
			initial = set.rivalInitial,
			scale = set.rivalScale,
			userId = nil,
		}
		table.insert(self.thinIcons, { own = own, rival = rival })
		showFace(own, Players.LocalPlayer.UserId)
	end

	self:_applyVisible()
end

-- thin is the pad's look: the authored lines in place of the bar.
function SongBar.setThin(self: SongBar, thin: boolean)
	self.thin = thin

	if thin then
		self.stats.Visible = false
	end

	self:_applyVisible()
end

-- Pixels from the top of the HUD to the bar's lower edge, and to the clock's.
function SongBar.bottom(self: SongBar): number
	return self.root.Position.Y.Offset + self.root.Size.Y.Offset
end

function SongBar.clockBottom(self: SongBar): number
	return self.root.Position.Y.Offset + self.time.Size.Y.Offset
end

-- The server's own numbers for the run so far: accuracy 0..1 and its rank.
function SongBar.setStats(self: SongBar, accuracy: number, rank: string, misses: number)
	self.stats.Visible = not self.thin
	self.accuracyLabel.Text = string.format("%.1f%%", math.clamp(accuracy, 0, 1) * 100)
	self.missLabel.Text = if misses == 1 then "1 MISS" else string.format("%d MISSES", misses)

	if rank == self.rank then
		return
	end

	self.rank = rank
	self.rankAt = os.clock()
	self.rankLabel.Text = rank
	self.rankLabel.TextColor3 = RANK_COLORS[rank] or STATS_COLOR
end

-- fever is the server's snapshot; the bar burns until its time runs out.
function SongBar.setFever(self: SongBar, fever: any)
	local active = type(fever) == "table" and fever.active == true

	if not active then
		self.feverEndsAt = 0
		self:_setFeverLook(false)
		return
	end

	self.feverEndsAt = os.clock() + (tonumber(fever.remainingSeconds) or 0)
	self:_setFeverLook(true)
end

function SongBar._setFeverLook(self: SongBar, active: boolean)
	if self.feverGlow.Visible == active then
		return
	end

	local gradient = if active then ColorSequence.new(FEVER_GOLD, FEVER_PINK) else ColorSequence.new(TIME_FROM, TIME_TO)
	self.feverGlow.Visible = active
	self.timeGradient.Color = gradient
	self.timeStroke.Color = STROKE_COLOR
	self.timeStroke.Thickness = 2.5
	self.timeLabel.TextColor3 = Color3.new(1, 1, 1)

	for _, lines in self.thinLines do
		if lines.timeGradient ~= nil then
			lines.timeGradient.Color = if active then gradient else lines.timeRest or gradient
		end

		if lines.timeStroke ~= nil then
			lines.timeStroke.Color = STROKE_COLOR
			lines.timeStroke.Thickness = THIN_STROKE
		end
	end
end

function SongBar._pulseFever(self: SongBar, now: number)
	local remaining = self.feverEndsAt - now

	if remaining <= 0 then
		self:_setFeverLook(false)
		return false
	end

	local wave = 0.5 + 0.5 * math.sin(now * FEVER_PULSE_HZ * 2 * math.pi)
	local strokeColor = FEVER_PINK:Lerp(FEVER_GOLD, wave)
	local grow = (FEVER_STROKE_THICKNESS - 2.5) * wave
	self.feverGlow.BackgroundTransparency = FEVER_GLOW_TRANSPARENCY + (1 - FEVER_GLOW_TRANSPARENCY) * 0.6 * wave
	self.feverGlow.BackgroundColor3 = FEVER_GOLD:Lerp(FEVER_PINK, wave)
	self.timeStroke.Color = strokeColor
	self.timeStroke.Thickness = 2.5 + grow
	self.timeLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(FEVER_GOLD, wave)
	self.timeLabel.Text = string.format("FEVER!  %d", math.ceil(remaining))

	for _, lines in self.thinLines do
		if lines.timeStroke ~= nil then
			lines.timeStroke.Color = strokeColor
			lines.timeStroke.Thickness = THIN_STROKE + grow
		end
	end

	return true
end

-- rivalName nil means no rival: the tug-of-war bar hides. On the pad only a
-- real player (one with a userId) gets the meter; the solo bot leaves the life bar.
function SongBar.setVersus(self: SongBar, ownScore: number, rivalScore: number, rivalName: string?, rivalUserId: number?)
	local playerRival = rivalName ~= nil and rivalUserId ~= nil
	local changed = playerRival ~= self.playerRival
	self.versusShown = rivalName ~= nil
	self.playerRival = playerRival
	self.versus.Visible = self.versusShown
	self:_applyVisible()

	if changed and self.onPlayerRival ~= nil then
		self.onPlayerRival(playerRival)
	end

	if rivalName == nil then
		return
	end

	self.rivalName.Text = string.upper(rivalName)
	showFace(self.rivalIcon, rivalUserId, rivalName)

	for _, icons in self.thinIcons do
		showFace(icons.rival, rivalUserId, rivalName)
	end

	local total = ownScore + rivalScore
	local rivalShare = if total > 0 then rivalScore / total else 0.5
	self.targetSplit = math.clamp(rivalShare, SPLIT_MIN, 1 - SPLIT_MIN)
end

local function tintIcons(own: Icon, rival: Icon, split: number, bop: number)
	local winning = split < 0.5
	own.scale.Scale = bop
	rival.scale.Scale = bop
	own.image.ImageColor3 = if winning or split == 0.5 then Color3.new(1, 1, 1) else LOSING_TINT
	rival.image.ImageColor3 = if winning then LOSING_TINT else Color3.new(1, 1, 1)
end

local function placeIcons(own: Icon, rival: Icon, split: number, bop: number, ownOffset: number, rivalOffset: number)
	own.frame.Position = UDim2.new(split, ownOffset, 0.5, 0)
	rival.frame.Position = UDim2.new(split, rivalOffset, 0.5, 0)
	tintIcons(own, rival, split, bop)
end

-- Called every frame of a run with the song clock and the beat (fractional).
function SongBar.update(self: SongBar, elapsed: number, duration: number?, beat: number)
	local now = os.clock()
	local dt = math.clamp(now - self.lastFrame, 0, 0.1)
	self.lastFrame = now

	local progress = if duration ~= nil and duration > 0 then math.clamp(elapsed / duration, 0, 1) else 0
	self.timeFill.Size = UDim2.fromScale(progress, 1)
	self.head.Position = UDim2.fromScale(progress, 0.5)

	if not self:_pulseFever(now) then
		self.timeLabel.Text = if duration ~= nil then clock(elapsed) .. " / " .. clock(duration) else clock(elapsed)
	end

	local sinceRank = math.clamp((now - self.rankAt) / RANK_POP_SECONDS, 0, 1)
	self.rankScale.Scale = 1 + (RANK_POP - 1) * (1 - sinceRank) ^ 3

	local whole = math.floor(beat)

	if whole ~= self.lastBeat and beat >= 0 then
		self.lastBeat = whole
		self.beatAt = now
	end

	local bop = 1 + ICON_BOP * (1 - math.clamp((now - self.beatAt) / ICON_BOP_SECONDS, 0, 1)) ^ 2
	self.headScale.Scale = bop

	for _, lines in self.thinLines do
		lines.timeFill.Size = UDim2.fromScale(progress, 1)
		lines.head.Position = UDim2.fromScale(progress, 0.5)
		lines.headScale.Scale = bop

		if lines.elapsed ~= nil then
			lines.elapsed.Text = clock(elapsed)
		end

		if lines.total ~= nil then
			lines.total.Text = if duration ~= nil then clock(duration) else ""
		end
	end

	if not self.versusShown then
		return
	end

	self.split += (self.targetSplit - self.split) * (1 - math.exp(-SPLIT_RATE * dt))
	self.rivalFill.Size = UDim2.fromScale(self.split, 1)
	placeIcons(self.ownIcon, self.rivalIcon, self.split, bop, ICON_SIZE / 2, -ICON_SIZE / 2)

	-- The authored icons sit at the meter's ends, where the layout put them.
	for index, lines in self.thinLines do
		lines.rivalFill.Size = UDim2.fromScale(self.split, 1)

		local icons = self.thinIcons[index]

		if icons ~= nil then
			tintIcons(icons.own, icons.rival, self.split, bop)
		end
	end
end

return SongBar
