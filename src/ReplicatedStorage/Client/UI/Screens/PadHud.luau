--!strict
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local GradeLine = require(script.Parent.Parent.GradeLine)
local HudFx = require(script.Parent.Parent.HudFx)
local HudWave = require(script.Parent.Parent.HudWave)
local NeonPanel = require(script.Parent.Parent.NeonPanel)
local TextStyles = require(script.Parent.Parent.TextStyles)
local TweenSlots = require(script.Parent.Parent.TweenSlots)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors
local since = HudFx.since
local setFade = HudFx.setFade
local showFrame = HudFx.showFrame

export type TextStyle = TextStyles.TextStyle
export type Styles = {
	grades: { [string]: TextStyle },
	comboTiers: { TextStyles.Tier },
	shield: TextStyle,
	plain: TextStyle,
}
-- "Desktop" or "PhoneLandscape": the authored frames.
export type LayoutName = string
-- The thin time and versus lines along the top edge, which SongBar drives.
export type Lines = {
	time: GuiObject,
	timeStroke: UIStroke?,
	timeFill: GuiObject,
	timeGradient: UIGradient?,
	timeRest: ColorSequence?,
	head: GuiObject,
	headScale: UIScale,
	elapsed: TextLabel?,
	total: TextLabel?,
	versus: GuiObject,
	rivalFill: GuiObject,
	ownIcon: GuiObject,
	ownFace: ImageLabel,
	ownInitial: TextLabel,
	ownScale: UIScale,
	rivalIcon: GuiObject,
	rivalFace: ImageLabel,
	rivalInitial: TextLabel,
	rivalScale: UIScale,
}

local GUI_NAME = "PadHud"
local SHOWN_ATTRIBUTES = { "BlockShown", "KeysShown" }
local POP_NAME = "Pop"
local BOP_NAME = "Bop"
local BEAT_NAME = "Beat"
local GLOW_NAMES = { "Fever", "Danger", "Break" }

-- The combo beats on the heartbeat, harder as it climbs and hardest in Fever.
local HEART_BUMP = 0.07
local HEART_COMBO_BUMP = 0.09
local HEART_FEVER_BUMP = 0.07
-- Every hit kicks the combo: the burst spins on, the number tilts and shines,
-- the row bounces and a burst of diamonds in the combo's colour goes off.
local BURST_SPIN_PER_BEAT = 10
local BURST_HEAT_SPIN = 2
local BURST_KICK_DEGREES = 30
local BURST_FOLLOW = 12
local BURST_FEVER_FLASH = 0.6
local HIT_BURST_SECONDS = 0.4
local HIT_KICK_DEGREES = 6
local HIT_KICK_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIT_ROW_BUMP = 1.08
local SHINE_FROM = 0.6
local SHINE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TEXT_SHIMMER = 0.2
local MILESTONE_WOBBLE_DEGREES = 14
local MILESTONE_WOBBLE_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

-- The combo's effects (beat ring, sparkle, shatter, hit burst) and the edge
-- glows are placeholders: whatever art sits inside them is faded and scaled.
local RING_FROM = 0.85
local RING_TO = 1.3
local RING_ALPHA = 0.15
local RING_HEAT_ALPHA = 0.2
local SPARKLE_SECONDS = 0.8
local SPARKLE_FROM = 0.4
local SPARKLE_TO = 1.5
local SPARKLE_SPIN_DEGREES = 120
local TIER_SPARKLE = 0.7
local SHATTER_SECONDS = 0.45
local FEVER_GLOW_REST = 0.1
local FEVER_GLOW_PEAK = 0.35
local DANGER_GLOW = 0.3
local BREAK_GLOW = 0.45
local BREAK_GLOW_SECONDS = 0.6

-- The hotter the combo, the harder the panels bop and shake, the number
-- sways, the burst throbs with the music and the screen edges glow.
local PANEL_BOP = 0.06
local PANEL_LOUD = 0.03
local SCORE_POP = 0.12
local SCORE_POP_SECONDS = 0.25
local HYPE_SHAKE_DEGREES = 3
local HYPE_SHAKE_SECONDS = 0.3
local HYPE_SHAKE_SPEED = 55
local NUMBER_SWAY_DEGREES = 8
local BURST_THROB = 0.18
local BURST_THROB_COLD = 0.3
local HYPE_GLOW = 0.2
local PAUSE_BOP = 0.08

-- A shine runs along the life bar every two beats. A hit shakes the panel and
-- flashes the bar, and the life lost lingers as a Ghost before draining away.
local LIFE_SHINE_BEATS = 2
local LIFE_FLASH_SECONDS = 0.3
local LIFE_SHAKE_DEGREES = 4
local LIFE_SHAKE_SECONDS = 0.35
local LIFE_GHOST_DELAY = 0.35
local LIFE_GHOST_SECONDS = 0.45
local LIFE_TWEEN_SECONDS = 0.25
local LOW_LIFE = 0.25
local LOW_LIFE_PULSE_SECONDS = 0.35

local COMBO_SHOWN_FROM = 2
local COMBO_BREAK_LINE_FROM = 5
local BUMP = 1.15
local MILESTONE_BUMP = 1.5
local TIER_UP_BUMP = 1.35
local APPEAR_FROM = 0.4
local BUMP_SECONDS = 0.2
local MILESTONE_HOLD_SECONDS = 1.1
local SHAKE_DEGREES = 9
local SHAKE_SECONDS = 0.05
local SHAKE_REPEATS = 3
local DROP_SECONDS = 0.25
local LINE_POP_SECONDS = 0.12
local LINE_CLEAR_SECONDS = 0.5
local LINE_HOLD_SECONDS = 1
local LINE_FADE_SECONDS = 0.15
local LINE_SLAM_DEGREES = -8
local LINE_SLAM_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LINE_SHINE_FROM = 0.45
local LINE_SHINE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Roblox caps TextSize here.
local MAX_TEXT_SIZE = 100
-- Outlines follow the text size, so small phone text is not smothered and the
-- big combo number still reads as outlined.
local STROKE_PER_TEXT = 0.08
local NUMBER_STROKE_PER_HEIGHT = 0.045
local STROKE_MIN = 1
local STROKE_MAX = 6
-- On a phone the block takes the top bar's row too, so the song card starts
-- this far past Roblox's own buttons.
local TOPBAR_GAP = 8

type View = {
	name: LayoutName,
	frame: GuiObject,
	lines: Lines,
	songCard: GuiObject,
	songHome: UDim2,
	songBeat: UIScale,
	title: TextLabel,
	pill: GuiObject,
	pillText: TextLabel,
	scorePanel: GuiObject,
	scoreBeat: UIScale,
	scoreValue: TextLabel,
	lifePanel: GuiObject,
	lifeBeat: UIScale,
	lifeFill: GuiObject,
	lifeGhost: GuiObject?,
	lifeShine: UIGradient?,
	pause: GuiButton,
	pauseBeat: UIScale,
	neons: { NeonPanel.NeonPanel },
	waves: { HudWave.Wave },
	combo: GuiObject,
	comboBeat: UIScale,
	body: GuiObject,
	bodyScale: UIScale,
	number: TextLabel,
	numberShine: UIGradient?,
	burst: GuiObject?,
	burstBeat: UIScale?,
	burstColor: Color3,
	row: GuiObject,
	rowScale: UIScale,
	rowShine: { UIGradient },
	label: TextLabel,
	multiplier: TextLabel,
	shield: TextLabel,
	line: GuiObject,
	lineScale: UIScale,
	gradeLine: GradeLine.GradeLine,
	ring: HudFx.Effect?,
	sparkle: HudFx.Effect?,
	shatter: HudFx.Effect?,
	hitBurst: HudFx.Effect?,
	glows: { [string]: HudFx.Fade },
	edges: GuiObject?,
}

type ScaleField = "bodyScale" | "rowScale" | "lineScale"

type Fields = {
	gui: ScreenGui,
	views: { View },
	active: View,
	styles: Styles,
	tweens: TweenSlots.TweenSlots,
	viewport: Vector2?,
	blockShown: boolean,
	lifeShown: boolean,
	lineShown: boolean,
	comboShown: boolean,
	milestoneShowing: boolean,
	combo: number,
	multiplierValue: number,
	tier: number,
	comboToken: number,
	lineToken: number,
	milestoneToken: number,
	rainbow: RBXScriptConnection?,
	listener: HudWave.Listener,
	lastBeat: number,
	lastGrooveAt: number,
	burstAngle: number,
	burstTarget: number,
	hitAt: number,
	hitColor: Color3,
	shakeAt: number,
	sparkleAt: number,
	sparkleSize: number,
	breakAt: number,
	scoreAt: number,
	scoreText: string,
	life: number,
	lifeLow: boolean,
	lifeHitAt: number,
}

-- Drives the pad's top block, authored in StarterGui.PadHud with one frame per
-- layout. Every call updates them all, so switching layout is only a matter
-- of which frame is visible.
local PadHud = {}
PadHud.__index = PadHud
PadHud.Layouts = { "Desktop", "PhoneLandscape" } :: { LayoutName }

export type PadHud = typeof(setmetatable({} :: Fields, PadHud))

function PadHud.findGui(playerGui: Instance): ScreenGui?
	return UiKit.authoredGui(playerGui, GUI_NAME)
end

-- The game is landscape only. A phone is too short for a centre block above
-- the pad, so its combo goes in the column under the score.
function PadHud.layoutFor(viewport: Vector2): LayoutName
	return if UiKit.isPhoneViewport(viewport) then "PhoneLandscape" else "Desktop"
end

function PadHud.showLayout(gui: ScreenGui, viewport: Vector2): LayoutName
	local chosen = PadHud.layoutFor(viewport)

	for _, name in PadHud.Layouts do
		local frame = gui:FindFirstChild(name)

		if frame ~= nil and frame:IsA("GuiObject") then
			frame.Visible = name == chosen
		end
	end

	return chosen
end

-- The block and the keys hide on their own; the gui is off when both are.
function PadHud.setShown(gui: ScreenGui, part: string, shown: boolean)
	gui:SetAttribute(part, shown)

	local any = false

	for _, attribute in SHOWN_ATTRIBUTES do
		any = any or gui:GetAttribute(attribute) == true
	end

	gui.Enabled = any
end

-- A top-level element may sit in a designer's group, so it is found anywhere
-- in the layout; its parts are found under it by path.
local function find(root: Instance, path: string, missing: { string }): any
	local names = string.split(path, ".")
	local node: Instance? = root:FindFirstChild(names[1], true)

	for index = 2, #names do
		node = if node ~= nil then node:FindFirstChild(names[index]) else nil
	end

	if node == nil then
		table.insert(missing, path)
	end

	return node
end

local function bindLines(frame: GuiObject, missing: { string }): Lines?
	local time = find(frame, "TimeLine", missing)
	local head = find(frame, "TimeLine.Head", missing)
	local fill = find(frame, "TimeLine.Fill", missing)
	local gradient = if fill ~= nil then fill:FindFirstChildOfClass("UIGradient") else nil
	local own = find(frame, "VersusLine.You", missing)
	local rival = find(frame, "VersusLine.Rival", missing)
	local lines = {
		time = time,
		timeStroke = if time ~= nil then time:FindFirstChildOfClass("UIStroke") else nil,
		timeFill = fill,
		timeGradient = gradient,
		timeRest = if gradient ~= nil then gradient.Color else nil,
		head = head,
		headScale = if head ~= nil then UiKit.scaleOf(head, BOP_NAME) else nil,
		elapsed = if time ~= nil then time:FindFirstChild("Elapsed") else nil,
		total = if time ~= nil then time:FindFirstChild("Total") else nil,
		versus = find(frame, "VersusLine", missing),
		rivalFill = find(frame, "VersusLine.RivalFill", missing),
		ownIcon = own,
		ownFace = find(frame, "VersusLine.You.Face", missing),
		ownInitial = find(frame, "VersusLine.You.Initial", missing),
		ownScale = if own ~= nil then UiKit.scaleOf(own, BOP_NAME) else nil,
		rivalIcon = rival,
		rivalFace = find(frame, "VersusLine.Rival.Face", missing),
		rivalInitial = find(frame, "VersusLine.Rival.Initial", missing),
		rivalScale = if rival ~= nil then UiKit.scaleOf(rival, BOP_NAME) else nil,
	}

	return if #missing == 0 then lines :: any else nil
end

-- Everything optional: a layout without one of these simply skips it.
local function bindExtras(view: View)
	view.neons = {}
	view.waves = {}

	for _, panel in { view.songCard, view.scorePanel } do
		local outline = UiKit.child(panel, "Outline", "ImageLabel")

		if outline ~= nil and panel:IsA("ImageLabel") then
			table.insert(view.neons, NeonPanel.bind(panel, panel, outline, panel))
		end
	end

	for _, panel in { view.songCard, view.scorePanel, view.lifePanel } do
		local wave = HudWave.bind(panel)

		if wave ~= nil then
			table.insert(view.waves, wave)
		end
	end

	view.lifeGhost = UiKit.child(view.lifeFill.Parent, "Ghost", "GuiObject")
	view.lifeShine = UiKit.child(view.lifeFill, "Shine", "UIGradient")
	view.burst = UiKit.child(view.body, "Burst", "GuiObject")
	view.burstBeat = if view.burst ~= nil then UiKit.scaleOf(view.burst, BEAT_NAME) else nil
	view.burstColor = if view.burst ~= nil and view.burst:IsA("ImageLabel") then view.burst.ImageColor3 else Colors.White
	view.numberShine = view.number:FindFirstChildOfClass("UIGradient")
	view.ring = HudFx.effectOf(view.combo:FindFirstChild("BeatRing"))
	view.sparkle = HudFx.effectOf(view.combo:FindFirstChild("Sparkle"))
	view.shatter = HudFx.effectOf(view.combo:FindFirstChild("Shatter"))
	view.hitBurst = HudFx.effectOf(view.combo:FindFirstChild("HitBurst"))
	view.rowShine = {}

	for _, label in { view.label, view.multiplier, view.shield } do
		local gradient = label:FindFirstChildOfClass("UIGradient")

		if gradient ~= nil then
			table.insert(view.rowShine, gradient)
		end
	end

	view.edges = UiKit.child(view.frame, "EdgeGlow", "GuiObject")
	view.glows = {}

	for _, name in GLOW_NAMES do
		local fade = HudFx.fadeOf(if view.edges ~= nil then view.edges:FindFirstChild(name) else nil)

		if fade ~= nil then
			view.glows[name] = fade
		end
	end
end

local function bindView(name: LayoutName, frame: GuiObject): View?
	local missing = {}
	local lines = bindLines(frame, missing)
	local body = find(frame, "Combo.Body", missing)
	local row = find(frame, "Combo.Row", missing)
	local line = find(frame, "GradeLine", missing)
	local grade = find(frame, "GradeLine.Grade", missing)
	local detail = find(frame, "GradeLine.Detail", missing)
	local view = {
		name = name,
		frame = frame,
		lines = lines,
		songCard = find(frame, "SongCard", missing),
		title = find(frame, "SongCard.Title", missing),
		pill = find(frame, "SongCard.Difficulty", missing),
		pillText = find(frame, "SongCard.Difficulty.Label", missing),
		scorePanel = find(frame, "ScorePanel", missing),
		scoreValue = find(frame, "ScorePanel.Value", missing),
		lifePanel = find(frame, "LifePanel", missing),
		lifeFill = find(frame, "LifePanel.Track.Fill", missing),
		pause = find(frame, "Pause", missing),
		combo = find(frame, "Combo", missing),
		body = body,
		number = find(frame, "Combo.Body.Number", missing),
		row = row,
		label = find(frame, "Combo.Row.Label", missing),
		multiplier = find(frame, "Combo.Row.Multiplier", missing),
		shield = find(frame, "Combo.Row.Shield", missing),
		line = line,
	}

	if #missing > 0 then
		local list = table.concat(missing, ", ")
		warn(("[DanceDanceStep] PadHud.%s is missing %s; that layout will not draw"):format(name, list))
		return nil
	end

	local bound = view :: any
	bound.songHome = view.songCard.Position
	bound.bodyScale = UiKit.scaleOf(body, POP_NAME)
	bound.rowScale = UiKit.scaleOf(row, POP_NAME)
	bound.lineScale = UiKit.scaleOf(line, POP_NAME)
	bound.gradeLine = GradeLine.bind(line, bound.lineScale, grade, detail)
	-- A UIScale only takes effect alone, so the beat scales the parents of the
	-- parts that already pop.
	bound.comboBeat = UiKit.scaleOf(view.combo, BEAT_NAME)
	bound.songBeat = UiKit.scaleOf(view.songCard, BEAT_NAME)
	bound.scoreBeat = UiKit.scaleOf(view.scorePanel, BEAT_NAME)
	bound.lifeBeat = UiKit.scaleOf(view.lifePanel, BEAT_NAME)
	bound.pauseBeat = UiKit.scaleOf(view.pause, BEAT_NAME)
	UiKit.fitSliceToHeight(view.lifePanel)
	bindExtras(bound)

	return bound
end

-- The labels in a row size to their text, so their size follows the row's
-- authored height rather than TextScaled, which would make each its own size.
local function fitRow(row: GuiObject, scale: UIScale, labels: { TextLabel })
	if scale.Scale < 0.05 then
		return
	end

	local height = row.AbsoluteSize.Y / scale.Scale

	if height <= 0 then
		return
	end

	for _, label in labels do
		label.TextSize = math.min(math.floor(height + 0.5), MAX_TEXT_SIZE)

		local stroke = label:FindFirstChildOfClass("UIStroke")

		if stroke ~= nil then
			stroke.Thickness = math.clamp(label.TextSize * STROKE_PER_TEXT, STROKE_MIN, STROKE_MAX)
		end
	end
end

-- The number draws under a UIScale, which scales its outline too.
local function fitNumberStroke(number: TextLabel)
	local stroke = number:FindFirstChildOfClass("UIStroke")
	local fit = number:FindFirstChildOfClass("UIScale")
	local scale = if fit ~= nil and fit.Scale > 0 then fit.Scale else 1

	if stroke ~= nil and number.AbsoluteSize.Y > 0 then
		local shown = math.clamp(number.AbsoluteSize.Y * NUMBER_STROKE_PER_HEIGHT, STROKE_MIN, STROKE_MAX)
		stroke.Thickness = shown / scale
	end
end

local function fitText(view: View)
	fitNumberStroke(view.number)
	fitRow(view.row, view.rowScale, { view.label, view.multiplier, view.shield })
	GradeLine.fit(view.gradeLine)
end

local function coverScreen(view: View, gui: ScreenGui)
	if view.edges ~= nil then
		UiKit.coverScreen(view.edges, gui)
	end
end

-- Everything that moves goes back to rest.
local function clearMotion(view: View)
	for _, effect: HudFx.Effect? in { view.ring, view.sparkle, view.shatter, view.hitBurst } do
		if effect ~= nil then
			setFade(effect.fade, 0)
		end
	end

	for _, glow in view.glows do
		setFade(glow, 0)
	end

	for _, wave in view.waves do
		HudWave.rest(wave)
	end

	for _, scale in { view.songBeat, view.scoreBeat, view.lifeBeat, view.pauseBeat, view.comboBeat } do
		scale.Scale = 1
	end

	if view.burstBeat ~= nil then
		view.burstBeat.Scale = 1
	end

	for _, part in { view.songCard, view.scorePanel, view.lifePanel, view.number, view.body } do
		part.Rotation = 0
	end
end

local function paint(label: TextLabel, style: TextStyle)
	local gradient = label:FindFirstChildOfClass("UIGradient")
	local stroke = label:FindFirstChildOfClass("UIStroke")
	label.TextColor3 = Color3.new(1, 1, 1)

	if gradient ~= nil then
		gradient.Color = ColorSequence.new(style.top, style.bottom)
	end

	if stroke ~= nil then
		stroke.Color = style.stroke
	end
end

-- nil when the place has no PadHud or none of its layouts is complete.
function PadHud.new(gui: ScreenGui, styles: Styles): PadHud?
	local views: { View } = {}

	for _, name in PadHud.Layouts do
		local frame = gui:FindFirstChild(name)

		if frame == nil or not frame:IsA("GuiObject") then
			warn("[DanceDanceStep] PadHud has no " .. name .. " layout")
			continue
		end

		local view = bindView(name, frame)

		if view ~= nil then
			table.insert(views, view)
		end
	end

	if #views == 0 then
		return nil
	end

	local fields: Fields = {
		gui = gui,
		views = views,
		active = views[1],
		styles = styles,
		tweens = TweenSlots.new(),
		viewport = nil,
		blockShown = false,
		lifeShown = true,
		lineShown = false,
		comboShown = false,
		milestoneShowing = false,
		combo = 0,
		multiplierValue = 1,
		tier = 0,
		comboToken = 0,
		lineToken = 0,
		milestoneToken = 0,
		rainbow = nil,
		listener = HudWave.newListener(),
		lastBeat = 0,
		lastGrooveAt = os.clock(),
		burstAngle = 0,
		burstTarget = 0,
		hitAt = -math.huge,
		hitColor = Colors.White,
		shakeAt = -math.huge,
		sparkleAt = -math.huge,
		sparkleSize = 1,
		breakAt = -math.huge,
		scoreAt = -math.huge,
		scoreText = "",
		life = 1,
		lifeLow = false,
		lifeHitAt = -math.huge,
	}
	local self = setmetatable(fields, PadHud)

	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		if self.viewport ~= nil then
			self:applyLayout(self.viewport)
		end
	end)

	for _, view in views do
		view.lines.time.Visible = false
		view.lines.versus.Visible = false
		fitText(view)
		view.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			fitText(view)
			coverScreen(view, gui)
		end)
	end

	self:setSong("", "")
	self:setScore("0")
	self:reset()
	self:setVisible(false)

	return self
end

function PadHud.layoutName(self: PadHud): string
	return self.active.name
end

-- viewport is the whole screen in pixels.
function PadHud.applyLayout(self: PadHud, viewport: Vector2, _topInset: number?)
	local chosen = PadHud.showLayout(self.gui, viewport)
	self.viewport = viewport
	local phone = chosen == "PhoneLandscape"
	self.gui.ScreenInsets = if phone then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets

	for _, view in self.views do
		if view.name == chosen then
			self.active = view
		end

		local home = view.songHome
		local clear = GuiService.TopbarInset.Min.X - view.frame.AbsolutePosition.X + TOPBAR_GAP
		local x = if phone then math.max(home.X.Offset, clear) else home.X.Offset
		view.songCard.Position = UDim2.new(home.X.Scale, x, home.Y.Scale, home.Y.Offset)
		fitText(view)
		coverScreen(view, self.gui)
	end
end

-- What the block covers, in pixels from origin, the top-left of the screen the
-- caller measures in, size wide: the bottom of the song card on the left, the
-- width of the score column (score, pause and the life or versus slot) on the
-- right, and the bottom of the grade line under the combo.
function PadHud.footprint(self: PadHud, origin: Vector2, size: Vector2): (number, number, number)
	local view = self.active
	local song = view.songCard
	local left = math.min(
		view.scorePanel.AbsolutePosition.X,
		view.pause.AbsolutePosition.X,
		view.lifePanel.AbsolutePosition.X,
		view.lines.versus.AbsolutePosition.X
	)

	return song.AbsolutePosition.Y + song.AbsoluteSize.Y - origin.Y,
		origin.X + size.X - left,
		view.line.AbsolutePosition.Y + GradeLine.height(view.gradeLine) - origin.Y
end

-- Where a floor event's banner goes, in pixels from origin.Y: the grade line's
-- top and height.
function PadHud.lineSpot(self: PadHud, origin: Vector2): (number, number)
	local view = self.active

	return view.line.AbsolutePosition.Y - origin.Y, GradeLine.height(view.gradeLine)
end

function PadHud.lines(self: PadHud): { Lines }
	local lines = {}

	for _, view in self.views do
		table.insert(lines, view.lines)
	end

	return lines
end

-- Returns whether any layout has a pause button to bind.
function PadHud.bindPause(self: PadHud, callback: () -> ()): boolean
	for _, view in self.views do
		view.pause.Activated:Connect(callback)
	end

	return #self.views > 0
end

function PadHud.setVisible(self: PadHud, visible: boolean)
	self.blockShown = visible
	PadHud.setShown(self.gui, "BlockShown", visible)

	for _, view in self.views do
		for _, part in { view.songCard, view.scorePanel, view.pause, view.combo } do
			part.Visible = visible
		end

		view.lifePanel.Visible = visible and self.lifeShown
		view.line.Visible = visible and self.lineShown
	end

	if not visible then
		self:_setRainbow(false)

		for _, view in self.views do
			clearMotion(view)
		end
	elseif self:_rainbowTier() then
		self:_setRainbow(true)
	end
end

function PadHud._showCombo(self: PadHud, shown: boolean)
	self.comboShown = shown

	for _, view in self.views do
		view.body.Visible = shown
		view.row.Visible = shown
	end
end

local function scaleIn(view: View, field: ScaleField): UIScale
	return (view :: any)[field]
end

function PadHud._setScales(self: PadHud, field: ScaleField, value: number)
	for _, view in self.views do
		scaleIn(view, field).Scale = value
	end
end

function PadHud._pop(self: PadHud, field: ScaleField, from: number, seconds: number?)
	local info = TweenInfo.new(seconds or BUMP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for _, view in self.views do
		local scale = scaleIn(view, field)
		scale.Scale = from
		self.tweens:play(scale, info, { Scale = 1 })
	end
end

function PadHud._setLabelText(self: PadHud, text: string)
	for _, view in self.views do
		view.label.Text = text
	end
end

function PadHud.reset(self: PadHud)
	self.tweens:cancelAll()
	self.comboToken += 1
	self.lineToken += 1
	self.milestoneToken += 1
	self.combo = 0
	self.tier = 0
	self.milestoneShowing = false
	self.sparkleAt = -math.huge
	self.breakAt = -math.huge
	self.hitAt = -math.huge
	self.shakeAt = -math.huge
	self.scoreAt = -math.huge
	self.lifeHitAt = -math.huge
	self.life = 1
	HudWave.resetListener(self.listener)
	self:_setRainbow(false)
	self:_showCombo(false)

	for _, view in self.views do
		clearMotion(view)
		view.lifeFill.Size = UDim2.fromScale(1, 1)

		if view.lifeGhost ~= nil then
			view.lifeGhost.Size = UDim2.fromScale(1, 1)
		end
	end

	self:_setScales("bodyScale", 1)
	self:_setScales("rowScale", 1)
	self:_setScales("lineScale", 1)
	self:_setLabelText("COMBO")
	self:setExtras(1, false)
	self:clearLine()
	self:_setLifeLow(false)
end

function PadHud.setSong(self: PadHud, title: string, difficulty: string)
	for _, view in self.views do
		view.title.Text = string.upper(title)
		view.pillText.Text = string.upper(difficulty)
		view.pill.Visible = difficulty ~= ""
	end
end

function PadHud.setScore(self: PadHud, text: string)
	if text ~= self.scoreText and self.blockShown then
		self.scoreAt = os.clock()
	end

	self.scoreText = text

	for _, view in self.views do
		view.scoreValue.Text = text
	end
end

function PadHud._setLifeLow(self: PadHud, low: boolean)
	if self.lifeLow == low then
		return
	end

	self.lifeLow = low

	for _, view in self.views do
		local fill = view.lifeFill
		local key = "lifePulse" .. view.name
		fill.BackgroundColor3 = if low then Colors.Red else Colors.Green

		if low then
			self.tweens:play(
				fill,
				TweenInfo.new(LOW_LIFE_PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.5 },
				key
			)
		else
			self.tweens:stop(key)
			fill.BackgroundTransparency = 0
		end
	end
end

function PadHud.setLifeShown(self: PadHud, shown: boolean)
	self.lifeShown = shown

	for _, view in self.views do
		view.lifePanel.Visible = self.blockShown and shown
	end
end

function PadHud.setLife(self: PadHud, fraction: number)
	local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	local lost = fraction < self.life

	if fraction ~= self.life and self.blockShown then
		self.lifeHitAt = os.clock()
	end

	self.life = fraction

	for _, view in self.views do
		self.tweens:play(view.lifeFill, TweenInfo.new(LIFE_TWEEN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,
		})

		local ghost = view.lifeGhost

		if ghost == nil then
			continue
		end

		if lost then
			self.tweens:play(
				ghost,
				TweenInfo.new(LIFE_GHOST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE_GHOST_DELAY),
				{ Size = size }
			)
		else
			self.tweens:stop(ghost)
			ghost.Size = size
		end
	end

	self:_setLifeLow(fraction > 0 and fraction < LOW_LIFE)
end

function PadHud._rainbowTier(self: PadHud): boolean
	local tier = self.styles.comboTiers[self.tier]

	return tier ~= nil and tier.style == nil
end

function PadHud._paintCombo(self: PadHud, style: TextStyle)
	for _, view in self.views do
		paint(view.number, style)
		paint(view.label, style)
	end
end

function PadHud._setRainbow(self: PadHud, active: boolean)
	if not active then
		if self.rainbow ~= nil then
			self.rainbow:Disconnect()
			self.rainbow = nil
		end

		return
	end

	if self.rainbow ~= nil then
		return
	end

	self.rainbow = RunService.Heartbeat:Connect(function()
		self:_paintCombo(TextStyles.rainbow(os.clock()))
	end)
end

-- 0 with no combo showing, 1 at the top combo tier.
function PadHud._heat(self: PadHud): number
	local tiers = #self.styles.comboTiers

	if not self.comboShown or self.tier < 1 or tiers < 2 then
		return 0
	end

	return (tiers - self.tier) / (tiers - 1)
end

-- Called every frame of a pad run with the song's beat (fractional) and how
-- loud the song is (PlaybackLoudness, 0 when there is no audio).
function PadHud.groove(self: PadHud, beat: number, fever: boolean, loudness: number?)
	if not self.blockShown or beat < 0 then
		return
	end

	local now = os.clock()
	local seconds = math.clamp(now - self.lastGrooveAt, 0, 0.1)
	local beats = math.clamp(beat - self.lastBeat, 0, 0.5)
	self.lastGrooveAt = now
	self.lastBeat = beat

	local phase = beat % 1
	local heat = self:_heat()
	local pulse = HudFx.heartbeat(phase)
	local hearing = HudWave.hear(self.listener, loudness or 0, seconds)
	local energy = hearing.energy or 0

	self.burstTarget += beats * BURST_SPIN_PER_BEAT * (1 + BURST_HEAT_SPIN * heat)
	self.burstAngle += (self.burstTarget - self.burstAngle) * math.min(seconds * BURST_FOLLOW, 1)

	self:_moveCombo(beat, pulse, heat, energy, fever)
	self:_movePanels(now, beat, pulse, heat, energy)
	self:_moveEffects(phase, pulse, heat, fever)
	HudWave.step(self.active.waves, beat, pulse, hearing, seconds)
end

function PadHud._moveCombo(self: PadHud, beat: number, pulse: number, heat: number, energy: number, fever: boolean)
	local bump = (HEART_BUMP + HEART_COMBO_BUMP * heat + (if fever then HEART_FEVER_BUMP else 0)) * pulse
	local flash = if fever then BURST_FEVER_FLASH * pulse else 0
	local throb = BURST_THROB * (BURST_THROB_COLD + (1 - BURST_THROB_COLD) * heat) * math.max(energy, pulse)
	local sway = math.sin(beat * math.pi) * NUMBER_SWAY_DEGREES * heat
	local shimmer = Vector2.new(0, math.sin(beat * math.pi) * TEXT_SHIMMER)

	for _, view in self.views do
		view.comboBeat.Scale = 1 + bump
		view.number.Rotation = sway

		local burst = view.burst

		if burst ~= nil then
			burst.Rotation = self.burstAngle % 360

			if view.burstBeat ~= nil then
				view.burstBeat.Scale = 1 + throb
			end

			if burst:IsA("ImageLabel") then
				burst.ImageColor3 = view.burstColor:Lerp(Colors.Fever, flash)
			end
		end

		for _, gradient in view.rowShine do
			gradient.Offset = shimmer
		end
	end
end

function PadHud._movePanels(self: PadHud, now: number, beat: number, pulse: number, heat: number, energy: number)
	local shaking = math.sin(now * HYPE_SHAKE_SPEED)
	local tilt = shaking * HYPE_SHAKE_DEGREES * heat * (1 - since(self.shakeAt, HYPE_SHAKE_SECONDS)) ^ 2
	local bop = heat * (PANEL_BOP * pulse + PANEL_LOUD * energy)
	local scorePop = SCORE_POP * (1 - since(self.scoreAt, SCORE_POP_SECONDS)) ^ 2
	local lifeShake = shaking * LIFE_SHAKE_DEGREES * (1 - since(self.lifeHitAt, LIFE_SHAKE_SECONDS)) ^ 2
	local lifeFlash = (1 - since(self.lifeHitAt, LIFE_FLASH_SECONDS)) ^ 2
	local lifeColor = (if self.lifeLow then Colors.Red else Colors.Green):Lerp(Colors.White, lifeFlash)
	local shine = Vector2.new((beat / LIFE_SHINE_BEATS) % 1 * 2 - 1, 0)
	local whole = math.floor(beat)

	for _, view in self.views do
		view.songBeat.Scale = 1 + bop
		view.songCard.Rotation = tilt
		view.scoreBeat.Scale = 1 + bop + scorePop
		view.scorePanel.Rotation = -tilt
		view.lifeBeat.Scale = 1 + bop
		view.lifePanel.Rotation = lifeShake
		view.lifeFill.BackgroundColor3 = lifeColor
		view.pauseBeat.Scale = 1 + PAUSE_BOP * pulse

		if view.lifeShine ~= nil then
			view.lifeShine.Offset = shine
		end

		for _, neon in view.neons do
			neon:onBeat(beat % 1, whole)
		end
	end
end

function PadHud._moveEffects(self: PadHud, phase: number, pulse: number, heat: number, fever: boolean)
	local ringAlpha = if self.comboShown then (1 - phase) ^ 2 * (RING_ALPHA + RING_HEAT_ALPHA * heat) else 0
	local ringScale = RING_FROM + (RING_TO - RING_FROM) * (1 - (1 - phase) ^ 2)
	local sparkle = since(self.sparkleAt, SPARKLE_SECONDS)
	local sparkleScale = (SPARKLE_FROM + (SPARKLE_TO - SPARKLE_FROM) * (1 - (1 - sparkle) ^ 3)) * self.sparkleSize
	local shattered = since(self.breakAt, SHATTER_SECONDS)
	local hit = since(self.hitAt, HIT_BURST_SECONDS)
	local glows = {
		Fever = if fever then FEVER_GLOW_REST + (FEVER_GLOW_PEAK - FEVER_GLOW_REST) * pulse else HYPE_GLOW * heat ^ 2 * pulse,
		Danger = if self.lifeLow then DANGER_GLOW * pulse else 0,
		Break = BREAK_GLOW * (1 - since(self.breakAt, BREAK_GLOW_SECONDS)) ^ 2,
	}

	for _, view in self.views do
		local ring = view.ring

		if ring ~= nil then
			ring.scale.Scale = ringScale
			setFade(ring.fade, ringAlpha)
		end

		local effect = view.sparkle

		if effect ~= nil then
			effect.scale.Scale = sparkleScale
			effect.fade.root.Rotation = SPARKLE_SPIN_DEGREES * sparkle
			setFade(effect.fade, if self.comboShown then (1 - sparkle) ^ 1.5 else 0)
			showFrame(effect, sparkle)
		end

		local shatter = view.shatter

		if shatter ~= nil then
			setFade(shatter.fade, if shattered < 1 then 1 else 0)
			showFrame(shatter, shattered)
		end

		local hitBurst = view.hitBurst

		if hitBurst ~= nil then
			setFade(hitBurst.fade, if self.comboShown and hit < 1 then 1 else 0)
			showFrame(hitBurst, hit)

			if hitBurst.sheet ~= nil then
				hitBurst.sheet.ImageColor3 = self.hitColor
			end
		end

		for name, glow in view.glows do
			setFade(glow, glows[name] or 0)
		end
	end
end

-- combo is the server's; a drop to zero is the break.
function PadHud.setCombo(self: PadHud, combo: number)
	if combo <= 0 then
		self:_breakCombo()
		return
	end

	if combo == self.combo then
		return
	end

	local wasShown = self.combo >= COMBO_SHOWN_FROM
	self.combo = combo
	self.comboToken += 1

	if combo < COMBO_SHOWN_FROM then
		self:_showCombo(false)
		return
	end

	for _, view in self.views do
		self.tweens:stop("comboShake" .. view.name)
		self.tweens:stop(view.rowScale)
		view.body.Rotation = 0
		view.number.Text = tostring(combo)
	end

	self:_setScales("rowScale", 1)
	self:_showCombo(true)

	local tier = TextStyles.tierFor(self.styles.comboTiers, combo)
	local climbed = wasShown and tier < self.tier

	if climbed then
		self.sparkleAt = os.clock()
		self.sparkleSize = TIER_SPARKLE
	end

	self.tier = tier

	local style = self.styles.comboTiers[tier].style
	self:_setRainbow(style == nil and self.blockShown)

	if style ~= nil then
		self:_paintCombo(style)
	end

	self:_showMultiplier()
	self:_pop("bodyScale", if not wasShown then APPEAR_FROM elseif climbed then TIER_UP_BUMP else BUMP)
	self:_hit(style)
end

function PadHud._hit(self: PadHud, style: TextStyle?)
	self.hitAt = os.clock()
	self.shakeAt = self.hitAt
	self.hitColor = (style or TextStyles.rainbow(self.hitAt)).bottom
	self.burstTarget += BURST_KICK_DEGREES
	self:_pop("rowScale", HIT_ROW_BUMP)

	local kick = if self.combo % 2 == 0 then HIT_KICK_DEGREES else -HIT_KICK_DEGREES

	for _, view in self.views do
		view.body.Rotation = kick
		self.tweens:play(view.body, HIT_KICK_INFO, { Rotation = 0 }, "comboKick" .. view.name)

		if view.numberShine ~= nil then
			view.numberShine.Offset = Vector2.new(0, SHINE_FROM)
			self.tweens:play(view.numberShine, SHINE_INFO, { Offset = Vector2.zero })
		end
	end
end

-- The lost number stays up while it shakes red and drops, so the player sees
-- what they lost.
function PadHud._breakCombo(self: PadHud)
	local lost = self.combo

	if lost >= COMBO_BREAK_LINE_FROM then
		self.breakAt = os.clock()
	end

	self.combo = 0
	self.tier = 0
	self.comboToken += 1
	self.milestoneToken += 1
	self.milestoneShowing = false
	self:_setRainbow(false)

	if lost < COMBO_SHOWN_FROM or not self.comboShown then
		self:_showCombo(false)
		return
	end

	local token = self.comboToken
	self:_paintCombo(self.styles.grades.Miss)
	self:_setLabelText("COMBO")

	for _, view in self.views do
		self.tweens:stop("comboKick" .. view.name)
		view.multiplier.Visible = false
		view.body.Rotation = -SHAKE_DEGREES

		local shake = self.tweens:play(
			view.body,
			TweenInfo.new(SHAKE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, SHAKE_REPEATS, true),
			{ Rotation = SHAKE_DEGREES },
			"comboShake" .. view.name
		)

		shake.Completed:Connect(function(state: Enum.PlaybackState)
			if state ~= Enum.PlaybackState.Completed or self.comboToken ~= token then
				return
			end

			view.body.Rotation = 0

			local info = TweenInfo.new(DROP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			self.tweens:play(view.rowScale, info, { Scale = 0 })
			local drop = self.tweens:play(view.bodyScale, info, { Scale = 0 })

			drop.Completed:Connect(function(dropState: Enum.PlaybackState)
				if dropState == Enum.PlaybackState.Completed and self.comboToken == token then
					view.body.Visible = false
					view.row.Visible = false
					view.bodyScale.Scale = 1
					view.rowScale.Scale = 1
					self.comboShown = false
				end
			end)
		end)
	end
end

function PadHud._showMultiplier(self: PadHud)
	local shown = self.multiplierValue > 1 and self.combo > 0 and not self.milestoneShowing

	for _, view in self.views do
		view.multiplier.Text = "x" .. tostring(self.multiplierValue)
		view.multiplier.Visible = shown
	end
end

function PadHud.setExtras(self: PadHud, multiplier: number, shieldReady: boolean)
	local sample = self.views[1]
	local multiplierWas = sample.multiplier.Visible
	local shieldWas = sample.shield.Visible

	self.multiplierValue = multiplier
	self:_showMultiplier()

	for _, view in self.views do
		view.shield.Visible = shieldReady
	end

	if (sample.multiplier.Visible and not multiplierWas) or (shieldReady and not shieldWas) then
		self:_pop("rowScale", MILESTONE_BUMP)
	end
end

-- The milestone is called out by the combo itself: the number and its label
-- swell, and the label reads the milestone until the next phrase.
function PadHud.showMilestone(self: PadHud, text: string)
	if not self.comboShown then
		return
	end

	self.milestoneToken += 1
	local token = self.milestoneToken
	self.milestoneShowing = true
	self.sparkleAt = os.clock()
	self.sparkleSize = 1
	self:_setLabelText(text)
	self:_showMultiplier()
	self:_pop("bodyScale", MILESTONE_BUMP, BUMP_SECONDS * 2)
	self:_pop("rowScale", MILESTONE_BUMP, BUMP_SECONDS * 2)

	for _, view in self.views do
		view.body.Rotation = -MILESTONE_WOBBLE_DEGREES
		self.tweens:play(view.body, MILESTONE_WOBBLE_INFO, { Rotation = 0 }, "comboKick" .. view.name)
	end

	task.delay(MILESTONE_HOLD_SECONDS, function()
		if self.milestoneToken == token then
			self.milestoneShowing = false
			self:_setLabelText("COMBO")
			self:_showMultiplier()
		end
	end)
end

function PadHud.clearLine(self: PadHud)
	self.lineToken += 1
	self.lineShown = false

	for _, view in self.views do
		GradeLine.set(view.gradeLine, "", nil, nil)
		view.line.Visible = false
	end
end

-- The grade slams in at a tilt as a shine sweeps it; hold nil keeps the line up
-- until the next one replaces it.
function PadHud.showLine(self: PadHud, text: string, detail: string?, style: TextStyle, punch: number, hold: number?)
	self.lineToken += 1
	local token = self.lineToken
	self.lineShown = true

	for _, view in self.views do
		local line = view.gradeLine
		GradeLine.restore(line, function(part)
			self.tweens:stop(part)
		end)
		GradeLine.set(line, text, detail, style)
		view.line.Visible = self.blockShown
		view.line.Rotation = LINE_SLAM_DEGREES
		self.tweens:play(view.line, LINE_SLAM_INFO, { Rotation = 0 })

		for _, gradient in line.shine do
			gradient.Offset = Vector2.new(0, LINE_SHINE_FROM)
			self.tweens:play(gradient, LINE_SHINE_INFO, { Offset = Vector2.zero })
		end
	end

	self:_pop("lineScale", punch, LINE_POP_SECONDS)

	if hold == nil then
		return
	end

	task.delay(hold, function()
		if self.lineToken ~= token then
			return
		end

		local info = TweenInfo.new(LINE_FADE_SECONDS)
		local fade: Tween? = nil

		for _, view in self.views do
			for _, part in view.gradeLine.fade.parts do
				fade = self.tweens:play(part.instance, info, { [part.property] = 1 }, part)
			end
		end

		if fade ~= nil then
			fade.Completed:Connect(function(state: Enum.PlaybackState)
				if state == Enum.PlaybackState.Completed and self.lineToken == token then
					self:clearLine()
				end
			end)
		end
	end)
end

function PadHud.showGrade(self: PadHud, text: string, detail: string?, style: TextStyle, punch: number)
	self:showLine(text, detail, style, punch, LINE_CLEAR_SECONDS)
end

-- Takes the grade's place when a real streak is lost; a short one is just the miss.
function PadHud.showComboBreak(self: PadHud, lostCombo: number, reason: string?)
	if lostCombo < COMBO_BREAK_LINE_FROM then
		return
	end

	self:showLine("COMBO BREAK", reason, self.styles.grades.Miss, 1.3, LINE_HOLD_SECONDS)
end

function PadHud.showShieldSave(self: PadHud)
	self:showLine("SHIELD!", "COMBO SAVED", self.styles.shield, 1.3, LINE_HOLD_SECONDS)
	self:_pop("bodyScale", MILESTONE_BUMP)
end

return PadHud
