--!strict
-- Drives the authored in-run HUD from the place, in place of the code-built RunHud.
--
-- It presents the same surface RunController already calls, so HUDController
-- swaps between them with one flag. Every readout goes through HudBinder, so
-- nothing here knows an instance name and the art can be renamed or reparented
-- freely.
--
-- Where the place has not authored an element the method is a no-op rather than
-- an error: the contract reports those once at startup and a half-built HUD
-- should still run rather than take the game down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HighwayLanes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HighwayLanes"))
local TextStyles = require(script.Parent.TextStyles)
local HudBinder = require(script.Parent.HudBinder)
local PadHud = require(script.Parent.Screens.PadHud)
local TweenSlots = require(script.Parent.TweenSlots)
local UiKit = require(script.Parent.UiKit)

local SCREEN_NAME = "Derail"
local RUN_FRAME = "HUD"
-- The ability cards; AbilityBar shows and hides them, so the HUD's own
-- show-everything and hide-on-pad passes leave them alone.
local ABILITY_FRAME = "HudFrame"
local GRADE_CLEAR_SECONDS = 0.5
-- Behind the code-built overlays (shop, settings, song select) so they still win.
local DISPLAY_ORDER = -1

local SCALE_NAME = "HudScale"
local SLIDE_DISTANCE = 0.5
local TOP_ROW = 0.22
local BOTTOM_ROW = 0.75
local INTRO_SECONDS = 0.45
local INTRO_STAGGER = 0.05
local OUTRO_SECONDS = 0.3
local BANNER_POP_FROM = 0.7
local BANNER_POP_SECONDS = 0.12
local BANNER_OUT_SECONDS = 0.12
-- A grade slams in from bigger than it settles, harder the better it is.
local GRADE_PUNCH: { [string]: number } = {
	Perfect = 1.6,
	Great = 1.4,
	Good = 1.2,
	Bad = 0.8,
	Miss = 0.8,
}
local MISS_SPIN_DEGREES = 12
local COMBO_BUMP = 1.18
local COMBO_MILESTONE_BUMP = 1.35
local COMBO_FIRST_MILESTONE = 10
local COMBO_MILESTONE = 25
local COMBO_BREAK_SHOWN_FROM = 10
local COMBO_APPEAR_FROM = 0.3
local COMBO_BUMP_SECONDS = 0.2
local SHAKE_DEGREES = 8
local SHAKE_SECONDS = 0.05
local SHAKE_REPEATS = 2
local DROP_SECONDS = 0.22
local SCORE_COUNT_SECONDS = 0.35
local LIFE_TWEEN_SECONDS = 0.25
local LOW_LIFE = 0.25
local LOW_LIFE_PULSE = 1.05
local LOW_LIFE_PULSE_SECONDS = 0.35
-- The highway owns the bottom right, the dancer the middle and the song bar the
-- top centre. The grade sits above the dancer's head and the combo beside it,
-- so both land where the eye already is.
local HIGHWAY_BANNER_POSITION = UDim2.fromScale(0.5, 0.25)
local HIGHWAY_COMBO_POSITION = UDim2.fromScale(0.32, 0.42)
-- The authored keycaps are sized for a glance; in the highway they are the
-- whole game, so they grow, pinned at the corner the art puts them in.
local HIGHWAY_KEYS_SCALE = 1.35
-- On the pad the authored panels give way to PadHud's top block, which keeps
-- the floor clear and has its own pause button.
local PAD_GRADE_PUNCH = 1.3
local PAD_COUNTDOWN_PUNCH = 1.4
-- The multiplier and the shield ride on the combo burst, so they move with it.
local BADGE_ATTRIBUTE = "ComboBadge"
local BADGE_SIZE = UDim2.fromScale(0.42, 0.17)
local BADGE_FILL = Color3.fromRGB(24, 10, 40)
local BADGE_POP = 1.6
local BADGE_POP_SECONDS = 0.3
local MULTIPLIER_BADGE = "ComboMultiplier"
local MULTIPLIER_POSITION = UDim2.fromScale(0.82, 0.88)
local MULTIPLIER_COLOR = Color3.fromRGB(255, 214, 90)
local SHIELD_BADGE = "ComboShield"
local SHIELD_POSITION = UDim2.fromScale(0.82, 0.1)
local SHIELD_COLOR = Color3.fromRGB(90, 220, 255)
-- A combo break or a shield save takes the combo's place for a moment.
local CALLOUT_SIZE = UDim2.fromScale(0.27, 0.18)
local CALLOUT_FILL_TRANSPARENCY = 0.2
local CALLOUT_POP_FROM = 0.4
local CALLOUT_POP_SECONDS = 0.25
local CALLOUT_HOLD_SECONDS = 0.9
local CALLOUT_OUT_SECONDS = 0.3
local COMBO_BREAK_CALLOUT_FROM = 5
local REASON_TEXT: { [string]: string } = {
	late = "LATE",
	wrong_tile = "WRONG TILE",
	danger = "DANGER",
	freeze = "MOVED",
	outside_zone = "OFF THE ZONE",
	no_position = "OFF THE FLOOR",
	released = "LET GO",
	pose_broken = "MOVED",
	not_on_tile = "OFF THE TILE",
	no_clap = "NO CLAP",
	missed_run = "MISSED RUN",
	dodged = "DODGED!",
	stood_early = "EARLY - LAND ON THE BEAT",
}
local MILESTONE_BIG_COMBO = 100
local MILESTONE_BIG_GROW = 0.5
local MILESTONE_BIG_HOLD_SECONDS = 0.6
local MILESTONE_TILT_DEGREES = 8
local FLASH_FROM_TRANSPARENCY = 0.88
local MILESTONE_POSITION = UDim2.fromScale(0.5, 0.3)
local MILESTONE_SIZE = UDim2.fromScale(0.6, 0.12)
local MILESTONE_POP_FROM = 0.3
local MILESTONE_POP_SECONDS = 0.25
local MILESTONE_HOLD_SECONDS = 0.9
local MILESTONE_OUT_SECONDS = 0.3
local MILESTONE_TOP = Color3.fromRGB(255, 250, 170)
local MILESTONE_BOTTOM = Color3.fromRGB(255, 150, 40)
local MILESTONE_STROKE = Color3.fromRGB(110, 20, 90)
local FLASH_SECONDS = 0.25
-- The highway HUD moves with the music the way Friday Night Funkin's does,
-- using FNF's own numbers (PlayState, HealthIcon, PopUpStuff). Its pixel
-- values are for a 720 px tall screen, so they are kept as fractions of that.
-- Every bar the whole HUD zooms in 3% and eases back by 0.95 per 1/60 s.
local HUD_ZOOM_BUMP = 0.03
local HUD_ZOOM_EVERY_BEATS = 4
local HUD_ZOOM_DECAY = 0.95
-- Every beat the text bops up and settles, and the panels rock to the other side.
local TEXT_BOP = 0.12
local TEXT_BOP_SECONDS = 0.2
local PANEL_SWAY_DEGREES = 2
local PANEL_SWAY_SECONDS = 0.12
-- A grade is thrown up and falls back under gravity, as FNF's rating sprite is.
local GRADE_RISE = 155 / 720
local GRADE_GRAVITY = 550 / 720
local GRADE_SPIN_DEGREES = 4
local BOP_ROLES = { "ScoreValue", "ComboValue", "SongTitle", "SongDifficulty" }
local SWAY_ROLES = { "ScoreGroup", "LifeGroup", "SongTitle" }
local GROOVE_NAME = "Groove"
-- The HUD's panel art is painted, but every label is plain white, so colour
-- goes on the text: each grade has its own, and the combo climbs through
-- colours as the streak grows. top and bottom make a vertical gradient.
type TextStyle = TextStyles.TextStyle

local GRADE_STYLES = TextStyles.Grades
local SHIELD_STYLE: TextStyle = {
	top = Color3.fromRGB(210, 250, 255),
	bottom = SHIELD_COLOR,
	stroke = Color3.fromRGB(10, 40, 90),
}
local COUNTDOWN_STYLE: TextStyle = {
	top = Color3.new(1, 1, 1),
	bottom = UiKit.Colors.Yellow,
	stroke = Color3.fromRGB(60, 10, 70),
}

-- Highest threshold first. The last tier is the rainbow.
local COMBO_TIERS: { TextStyles.Tier } = {
	{ at = 100, style = nil },
	{ at = 50, style = { top = Color3.fromRGB(255, 242, 140), bottom = Color3.fromRGB(255, 140, 30), stroke = Color3.fromRGB(110, 40, 10) } },
	{ at = 25, style = { top = Color3.fromRGB(180, 255, 160), bottom = Color3.fromRGB(30, 210, 110), stroke = Color3.fromRGB(10, 70, 40) } },
	{ at = 10, style = { top = Color3.fromRGB(170, 240, 255), bottom = Color3.fromRGB(60, 140, 255), stroke = Color3.fromRGB(14, 36, 110) } },
	{ at = 0, style = { top = Color3.new(1, 1, 1), bottom = Color3.fromRGB(255, 196, 245), stroke = Color3.fromRGB(60, 10, 70) } },
}
local TEXT_STROKE_THICKNESS = 2.5
local TIER_UP_BUMP = 1.5
local STYLE_NAME = "HighwayStyle"
-- The highway names its grades the way Friday Night Funkin' does, minus the
-- one word Roblox's filter would not allow.
local HIGHWAY_GRADE_NAMES: { [string]: string } = {
	Perfect = "SICK!",
	Great = "GOOD!",
	Good = "OK",
	Bad = "BAD",
	Miss = "MISS",
}
local COMBO_SHAKE = "comboShake"
local KEPT_AFTER_RUN = { "ScoreValue", "SongTitle" }

type Fields = {
	binder: HudBinder.HudBinder,
	screen: ScreenGui?,
	runFrame: GuiObject?,
	gradeToken: number,
	comboToken: number,
	homes: { [GuiObject]: UDim2 },
	tilts: { [GuiObject]: number },
	tweens: TweenSlots.TweenSlots,
	shownCombo: number,
	scoreCounter: NumberValue,
	lifeLow: boolean,
	keysRestore: { size: UDim2, anchor: Vector2, home: UDim2 }?,
	comboHome: UDim2?,
	highwayGrades: boolean,
	padActive: boolean,
	pad: PadHud.PadHud?,
	songTitle: string,
	songDifficulty: string,
	flash: Frame?,
	zoom: UIScale?,
	hudZoom: number,
	lastBeat: number,
	beatAt: number,
	swaySide: number,
	lastGroove: number,
	gradeAt: number?,
	gradeSpin: number,
	comboTier: number,
	feverEndsAt: number,
	milestone: TextLabel?,
	milestoneToken: number,
	shownMultiplier: number,
	shownShield: boolean,
	callout: Frame?,
	calloutToken: number,
	styled: { [TextLabel]: { strokeTransparency: number, uiStroke: UIStroke?, strokeColor: Color3?, strokeThickness: number? } },
}

local AuthoredRunHud = {}
AuthoredRunHud.__index = AuthoredRunHud

export type AuthoredRunHud = typeof(setmetatable({} :: Fields, AuthoredRunHud))

local function comma(value: number): string
	local out = tostring(math.floor(value))
	local count

	repeat
		out, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return out
end

local function slideOffset(home: UDim2): UDim2
	if home.Y.Scale < TOP_ROW then
		return UDim2.fromScale(0, -SLIDE_DISTANCE)
	elseif home.Y.Scale > BOTTOM_ROW then
		return UDim2.fromScale(0, SLIDE_DISTANCE)
	elseif home.X.Scale < 0.5 then
		return UDim2.fromScale(-SLIDE_DISTANCE, 0)
	end

	return UDim2.fromScale(SLIDE_DISTANCE, 0)
end

-- padGui is the authored StarterGui.PadHud, which draws the run on the pad.
function AuthoredRunHud.new(playerGui: Instance?, padGui: ScreenGui?): AuthoredRunHud
	local root = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = root:WaitForChild(SCREEN_NAME, 10)
	local runFrame = nil

	if screen ~= nil and screen:IsA("ScreenGui") then
		screen.Enabled = true
		screen.DisplayOrder = DISPLAY_ORDER
		screen.ResetOnSpawn = false

		-- The authored screen ships with every frame hidden; the run HUD is the
		-- only one this drives, so the others stay as the place left them.
		local frame = screen:FindFirstChild(RUN_FRAME)

		if frame ~= nil and frame:IsA("GuiObject") then
			runFrame = frame
		end
	else
		warn("[AuthoredRunHud] " .. SCREEN_NAME .. " ScreenGui not found; the run HUD will not draw")
	end

	local binder = HudBinder.new(if screen ~= nil then screen else root)
	binder:logReport()

	local fields: Fields = {
		binder = binder,
		screen = screen :: ScreenGui?,
		runFrame = runFrame,
		gradeToken = 0,
		comboToken = 0,
		homes = {},
		tilts = {},
		tweens = TweenSlots.new(),
		shownCombo = 0,
		scoreCounter = Instance.new("NumberValue"),
		lifeLow = false,
		keysRestore = nil,
		comboHome = nil,
		highwayGrades = false,
		padActive = false,
		pad = nil,
		songTitle = "",
		songDifficulty = "",
		flash = nil,
		zoom = nil,
		hudZoom = 1,
		lastBeat = -1,
		beatAt = -math.huge,
		swaySide = 1,
		lastGroove = os.clock(),
		gradeAt = nil,
		gradeSpin = 0,
		comboTier = 0,
		feverEndsAt = 0,
		milestone = nil,
		milestoneToken = 0,
		shownMultiplier = 1,
		shownShield = false,
		callout = nil,
		calloutToken = 0,
		styled = {},
	}
	local self = setmetatable(fields, AuthoredRunHud)

	if runFrame ~= nil then
		for _, child in runFrame:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= ABILITY_FRAME then
				self.homes[child] = child.Position
				self.tilts[child] = child.Rotation
			end
		end
	end

	-- The HUD zooms from its middle, so it is centred rather than pinned at the
	-- top left; it fills the screen either way.
	if runFrame ~= nil then
		runFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		runFrame.Position = UDim2.fromScale(0.5, 0.5)
		self.zoom = UiKit.create("UIScale", { Name = GROOVE_NAME }, runFrame)
	end

	if padGui ~= nil then
		self.pad = PadHud.new(padGui, {
			grades = GRADE_STYLES,
			comboTiers = COMBO_TIERS,
			shield = SHIELD_STYLE,
			plain = COUNTDOWN_STYLE,
		})
	end

	self.scoreCounter.Changed:Connect(function(value: number)
		self.binder:setText("ScoreValue", comma(value))

		if self.pad ~= nil then
			self.pad:setScore(comma(value))
		end
	end)

	self:setIdle(true)

	return self
end

-- Only for elements no layout positions: a UIScale changes the size a layout
-- sees and would shove the siblings around.
function AuthoredRunHud._scaleOf(_self: AuthoredRunHud, gui: GuiObject): UIScale
	return UiKit.scaleOf(gui, SCALE_NAME)
end

function AuthoredRunHud._group(self: AuthoredRunHud, role: string): GuiObject?
	local inst = self.binder:get(role)

	return if inst ~= nil and inst:IsA("GuiObject") then inst else nil
end

-- The banner behind the judgement text, or the text itself where the place has
-- not tagged one.
function AuthoredRunHud._banner(self: AuthoredRunHud): GuiObject?
	return self:_group("JudgementGroup") or self:_group("JudgementText")
end

function AuthoredRunHud._topLevel(self: AuthoredRunHud, inst: Instance?): GuiObject?
	local runFrame = self.runFrame

	while inst ~= nil and runFrame ~= nil and inst.Parent ~= runFrame do
		inst = inst.Parent
	end

	if inst == nil or not inst:IsA("GuiObject") then
		return nil
	end

	local home: UDim2? = self.homes[inst]

	return if home ~= nil then inst else nil
end

-- The pad's thin time and versus lines, for SongBar to drive.
function AuthoredRunHud.padLines(self: AuthoredRunHud): { PadHud.Lines }
	return if self.pad ~= nil then self.pad:lines() else {}
end

function AuthoredRunHud._slidingPanels(self: AuthoredRunHud): { GuiObject }
	local banner = self:_topLevel(self:_banner())
	local panels = {}

	for panel in self.homes do
		if panel ~= banner then
			table.insert(panels, panel)
		end
	end

	table.sort(panels, function(a, b)
		return self.homes[a].Y.Scale < self.homes[b].Y.Scale
	end)

	return panels
end

function AuthoredRunHud._resetMotion(self: AuthoredRunHud)
	self.tweens:cancelAll()

	for panel, home in self.homes do
		panel.Position = home
		panel.Rotation = self.tilts[panel] or 0

		local scale = panel:FindFirstChild(SCALE_NAME)

		if scale ~= nil and scale:IsA("UIScale") then
			scale.Scale = 1
		end
	end

	local banner = self:_banner()

	if banner ~= nil then
		self:_scaleOf(banner).Scale = 1
	end

	self.lifeLow = false
end

function AuthoredRunHud._hideBanner(self: AuthoredRunHud)
	self.binder:setText("JudgementText", "")
	self.binder:setText("TimingDelta", "")
	self.binder:setVisible("JudgementGroup", false)
end

function AuthoredRunHud._popBanner(self: AuthoredRunHud, from: number?)
	local banner = self:_banner()

	if banner == nil then
		return
	end

	self.binder:setVisible("JudgementGroup", true)

	local scale = self:_scaleOf(banner)
	scale.Scale = from or BANNER_POP_FROM
	self.tweens:play(scale, TweenInfo.new(BANNER_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function AuthoredRunHud._dropBanner(self: AuthoredRunHud, token: number)
	local banner = self:_banner()

	if banner == nil then
		self:_hideBanner()
		return
	end

	local tween = self.tweens:play(
		self:_scaleOf(banner),
		TweenInfo.new(BANNER_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0 }
	)

	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and self.gradeToken == token then
			self:_hideBanner()
		end
	end)
end

function AuthoredRunHud.setIdle(self: AuthoredRunHud, idle: boolean)
	local visible = not idle
	local runFrame = self.runFrame

	if idle then
		self:_resetMotion()
	elseif runFrame ~= nil and runFrame.Visible then
		return
	end

	if runFrame ~= nil then
		runFrame.Visible = visible
	end

	self.binder:setVisible("ScoreGroup", visible)
	self.binder:setVisible("LifeGroup", visible)
	self.binder:setVisible("ProgressGroup", visible and not self:_songBarShown())
	self.binder:setVisible("NewRecord", false)
	self.gradeToken += 1
	self:_hideBanner()

	if idle then
		self.binder:setVisible("ComboGroup", false)
		self.shownCombo = 0
	end

	self:_hideAuthoredOnPad()

	-- The pad HUD only belongs to a run; padActive outlives it until the next one.
	if idle and self.pad ~= nil then
		self.pad:setVisible(false)
	end
end

-- Panels slide in from their nearest edge as the run starts; when it ends the
-- ones that only matter mid-run slide back out and the song and score stay
-- beside the results.
function AuthoredRunHud.setRunActive(self: AuthoredRunHud, active: boolean)
	if active then
		self:setIdle(false)
		self:_resetMotion()
		self:_breakComboNow()
		self.gradeToken += 1
		self:_hideBanner()
		self.binder:setVisible("NewRecord", false)
		self:setComboExtras(1, false)
		self:_hideCallout()

		if self.pad ~= nil then
			self.pad:reset()
		end

		for index, panel in self:_slidingPanels() do
			local home = self.homes[panel]
			panel.Position = home + slideOffset(home)
			self.tweens:play(
				panel,
				TweenInfo.new(
					INTRO_SECONDS,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out,
					0,
					false,
					(index - 1) * INTRO_STAGGER
				),
				{ Position = home }
			)
		end

		self:_hideAuthoredOnPad()

		return
	end

	self:_stopGroove()

	if self.pad ~= nil and self.padActive then
		self.pad:reset()
		self.pad:setVisible(false)
	end

	local keep: { [GuiObject]: boolean } = {}

	for _, role in KEPT_AFTER_RUN do
		local panel = self:_topLevel(self.binder:get(role))

		if panel ~= nil then
			keep[panel] = true
		end
	end

	self:_setLifeLow(false)

	for _, panel in self:_slidingPanels() do
		if not keep[panel] then
			local home = self.homes[panel]
			self.tweens:play(
				panel,
				TweenInfo.new(OUTRO_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = home + slideOffset(home) }
			)
		end
	end

	self.gradeToken += 1
	self:_dropBanner(self.gradeToken)
end

-- The highway's lane keys, left to right, or none unless all are authored.
function AuthoredRunHud.abilityFrame(self: AuthoredRunHud): GuiObject?
	local runFrame = self.runFrame
	local frame = if runFrame ~= nil then runFrame:FindFirstChild(ABILITY_FRAME) else nil

	return if frame ~= nil and frame:IsA("GuiObject") then frame else nil
end

-- "Desktop" or "PhoneLandscape": the pad layout on screen, or nil without the pad HUD.
function AuthoredRunHud.padLayoutName(self: AuthoredRunHud): string?
	return if self.pad ~= nil then self.pad:layoutName() else nil
end

-- An ability going off: its name called out where the grade line or callout sits.
function AuthoredRunHud.showAbility(self: AuthoredRunHud, title: string, detail: string?, color: Color3)
	local style: TextStyle = { top = color:Lerp(Color3.new(1, 1, 1), 0.55), bottom = color, stroke = Color3.fromRGB(20, 12, 40) }

	if self.padActive and self.pad ~= nil then
		self.pad:showLine(title, detail, style, 1.4, 1)
	else
		self:_showCallout(title, detail, style)
	end

	self:flashScreen(color)
end

function AuthoredRunHud.getLaneKeys(self: AuthoredRunHud): { GuiObject }
	local keys = {}

	for lane = 1, HighwayLanes.Count do
		local key = self.binder:get("LaneKey" .. lane)

		if key == nil or not key:IsA("GuiObject") then
			return {}
		end

		table.insert(keys, key)
	end

	return keys
end

-- Grows the lane keys' panel up and to the left so its bottom-right corner
-- stays where the art put it, and makes that its new home for the slides.
function AuthoredRunHud._sizeKeys(self: AuthoredRunHud, active: boolean)
	local panel = self:_topLevel(self.binder:get("HighwayGroup"))
	local parent = if panel ~= nil then panel.Parent else nil

	if panel == nil or parent == nil or not parent:IsA("GuiObject") then
		return
	end

	local restore = self.keysRestore

	if not active then
		if restore ~= nil then
			panel.Size = restore.size
			panel.AnchorPoint = restore.anchor
			panel.Position = restore.home
			self.homes[panel] = restore.home
			self.keysRestore = nil
		end

		return
	end

	local area = parent.AbsoluteSize

	if restore ~= nil or area.X <= 0 or area.Y <= 0 then
		return
	end

	local home = self.homes[panel]
	local size = panel.AbsoluteSize
	local anchor = panel.AnchorPoint
	local cornerX = home.X.Scale * area.X + home.X.Offset + size.X * (1 - anchor.X)
	local cornerY = home.Y.Scale * area.Y + home.Y.Offset + size.Y * (1 - anchor.Y)
	local original = panel.Size
	local grownHome = UDim2.fromScale(cornerX / area.X, cornerY / area.Y)

	self.keysRestore = { size = original, anchor = anchor, home = home }
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Size = UDim2.new(
		original.X.Scale * HIGHWAY_KEYS_SCALE,
		original.X.Offset * HIGHWAY_KEYS_SCALE,
		original.Y.Scale * HIGHWAY_KEYS_SCALE,
		original.Y.Offset * HIGHWAY_KEYS_SCALE
	)
	self.homes[panel] = grownHome

	-- The run's slide-in is already heading for the old home; send it here.
	self.tweens:play(panel, TweenInfo.new(INTRO_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = grownHome,
	})
end

-- Paints a label with a vertical gradient and a bold outline. The label's
-- own outline settings are remembered so _unstyleText can hand them back.
function AuthoredRunHud._styleText(self: AuthoredRunHud, label: TextLabel, style: TextStyle)
	local remembered = self.styled[label]

	if remembered == nil then
		local stroke = label:FindFirstChildOfClass("UIStroke")
		remembered = {
			strokeTransparency = label.TextStrokeTransparency,
			uiStroke = stroke,
			strokeColor = if stroke ~= nil then stroke.Color else nil,
			strokeThickness = if stroke ~= nil then stroke.Thickness else nil,
		}
		self.styled[label] = remembered
	end

	local gradient = label:FindFirstChild(STYLE_NAME)

	if gradient == nil or not gradient:IsA("UIGradient") then
		gradient = UiKit.create("UIGradient", { Name = STYLE_NAME, Rotation = 90 }, label)
	end

	(gradient :: UIGradient).Color = ColorSequence.new(style.top, style.bottom)

	local stroke = remembered.uiStroke

	if stroke == nil then
		local created = label:FindFirstChild(STYLE_NAME .. "Stroke")
		stroke = if created ~= nil and created:IsA("UIStroke")
			then created
			else UiKit.create("UIStroke", { Name = STYLE_NAME .. "Stroke" }, label)
	end

	local uiStroke = stroke :: UIStroke
	uiStroke.Color = style.stroke
	uiStroke.Thickness = TEXT_STROKE_THICKNESS
	label.TextStrokeTransparency = 1
end

function AuthoredRunHud._unstyleText(self: AuthoredRunHud)
	for label, remembered in self.styled do
		local gradient = label:FindFirstChild(STYLE_NAME)

		if gradient ~= nil then
			gradient:Destroy()
		end

		local created = label:FindFirstChild(STYLE_NAME .. "Stroke")

		if created ~= nil then
			created:Destroy()
		end

		local stroke = remembered.uiStroke

		if stroke ~= nil and remembered.strokeColor ~= nil and remembered.strokeThickness ~= nil then
			stroke.Color = remembered.strokeColor
			stroke.Thickness = remembered.strokeThickness
		end

		label.TextStrokeTransparency = remembered.strokeTransparency
	end

	table.clear(self.styled)
	self.comboTier = 0
end

-- Every label in the combo burst, so the number and the word change together.
function AuthoredRunHud._comboLabels(self: AuthoredRunHud): { TextLabel }
	local labels = {}
	local panel = self:_topLevel(self.binder:get("ComboGroup") or self.binder:get("ComboValue"))

	if panel ~= nil then
		for _, inst in panel:GetDescendants() do
			if inst:IsA("TextLabel") and inst:GetAttribute(BADGE_ATTRIBUTE) == nil then
				table.insert(labels, inst)
			end
		end
	end

	return labels
end

-- Colours the combo for its streak; a climb to a new tier gets a big bump.
function AuthoredRunHud._colorCombo(self: AuthoredRunHud, combo: number)
	local tier = TextStyles.tierFor(COMBO_TIERS, combo)
	local style = COMBO_TIERS[tier].style

	if style ~= nil then
		for _, label in self:_comboLabels() do
			self:_styleText(label, style)
		end
	end

	local climbed = self.comboTier ~= 0 and tier < self.comboTier
	self.comboTier = tier

	local group = self:_group("ComboGroup")

	if climbed and group ~= nil then
		local scale = self:_scaleOf(group)
		scale.Scale = TIER_UP_BUMP
		self.tweens:play(scale, TweenInfo.new(COMBO_BUMP_SECONDS * 1.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	end
end

-- The top tier's colours run through the rainbow, every frame.
function AuthoredRunHud._paintRainbow(self: AuthoredRunHud, now: number)
	if COMBO_TIERS[self.comboTier] == nil or COMBO_TIERS[self.comboTier].style ~= nil then
		return
	end

	local style = TextStyles.rainbow(now)

	for _, label in self:_comboLabels() do
		self:_styleText(label, style)
	end
end

function AuthoredRunHud._grooveScale(_self: AuthoredRunHud, inst: Instance): UIScale
	return UiKit.scaleOf(inst, GROOVE_NAME)
end

-- Called every frame of a run with the song's beat (fractional) and how loud
-- the song is (PlaybackLoudness).
function AuthoredRunHud.groove(self: AuthoredRunHud, beat: number, loudness: number?)
	local now = os.clock()

	if self.padActive and self.pad ~= nil then
		self.pad:groove(beat, now < self.feverEndsAt, loudness or 0)
		return
	end

	local dt = math.clamp(now - self.lastGroove, 0, 0.1)
	self.lastGroove = now

	local whole = math.floor(beat)

	if whole ~= self.lastBeat and beat >= 0 then
		self.lastBeat = whole
		self.beatAt = now
		self.swaySide = -self.swaySide

		local zoomEvery = if now < self.feverEndsAt then 1 else HUD_ZOOM_EVERY_BEATS

		if whole % zoomEvery == 0 then
			self.hudZoom += HUD_ZOOM_BUMP
		end
	end

	self.hudZoom = 1 + (self.hudZoom - 1) * HUD_ZOOM_DECAY ^ (dt * 60)
	self:_paintRainbow(now)

	if self.zoom ~= nil then
		self.zoom.Scale = self.hudZoom
	end

	local sinceBeat = now - self.beatAt
	local bop = (1 - math.clamp(sinceBeat / TEXT_BOP_SECONDS, 0, 1)) ^ 2

	for _, role in BOP_ROLES do
		local label = self.binder:get(role)

		if label ~= nil then
			self:_grooveScale(label).Scale = 1 + TEXT_BOP * bop
		end
	end

	-- The panels rock: on each beat they swing from one side to the other.
	local swing = 1 - (1 - math.clamp(sinceBeat / PANEL_SWAY_SECONDS, 0, 1)) ^ 3
	local tilt = PANEL_SWAY_DEGREES * (-self.swaySide + 2 * self.swaySide * swing)

	for _, role in SWAY_ROLES do
		local panel = self:_topLevel(self.binder:get(role))

		if panel ~= nil then
			panel.Rotation = (self.tilts[panel] or 0) + tilt
		end
	end

	local banner = self:_topLevel(self:_banner())
	local gradeAt = self.gradeAt

	if banner ~= nil and gradeAt ~= nil and self.highwayGrades then
		local t = now - gradeAt
		local rise = -GRADE_RISE * t + 0.5 * GRADE_GRAVITY * t * t

		banner.Position = HIGHWAY_BANNER_POSITION + UDim2.fromScale(0, rise)
		banner.Rotation = (self.tilts[banner] or 0) + self.gradeSpin * math.min(t * 4, 1)
	end
end

function AuthoredRunHud._stopGroove(self: AuthoredRunHud)
	self:_unstyleText()
	self.feverEndsAt = 0
	self.hudZoom = 1
	self.gradeAt = nil
	self.lastBeat = -1

	if self.zoom ~= nil then
		self.zoom.Scale = 1
	end

	for _, role in BOP_ROLES do
		local label = self.binder:get(role)
		local scale = if label ~= nil then label:FindFirstChild(GROOVE_NAME) else nil

		if scale ~= nil and scale:IsA("UIScale") then
			scale.Scale = 1
		end
	end

	for _, role in SWAY_ROLES do
		local panel = self:_topLevel(self.binder:get(role))

		if panel ~= nil then
			panel.Rotation = self.tilts[panel] or 0
		end
	end
end

function AuthoredRunHud._songBarShown(self: AuthoredRunHud): boolean
	return self.highwayGrades or self.padActive
end

local function grown(size: UDim2, factor: number): UDim2
	return UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
end

-- Every authored panel gives way to the pad's top block. Run after anything
-- that shows an authored role, since those calls do not know about the pad.
function AuthoredRunHud._hideAuthoredOnPad(self: AuthoredRunHud)
	if self.pad ~= nil then
		self.pad:setVisible(self.padActive)
	end

	if not self.padActive or self.pad == nil then
		return
	end

	for panel in self.homes do
		panel.Visible = false
	end
end

function AuthoredRunHud._restoreAuthored(self: AuthoredRunHud)
	for panel in self.homes do
		panel.Visible = true
	end

	self:_hideBanner()
	self.binder:setVisible("ComboGroup", self.shownCombo > 0)
	self.binder:setVisible("NewRecord", false)
	self.binder:setVisible("HighwayGroup", self.highwayGrades)
	self.binder:setVisible("ProgressGroup", not self:_songBarShown())
end

function AuthoredRunHud.setPadActive(self: AuthoredRunHud, active: boolean)
	local was = self.padActive
	self.padActive = active
	self.binder:setVisible("ProgressGroup", not self:_songBarShown())
	self:_hideCallout()
	self:_hideMilestone()

	if active then
		if self.pad ~= nil then
			self.pad:setSong(self.songTitle, self.songDifficulty)
		end

		self:_hideAuthoredOnPad()
	elseif was then
		self:_hideAuthoredOnPad()
		self:_restoreAuthored()
	end
end

-- The life bar and the versus meter share a spot; a 1v1 takes it.
function AuthoredRunHud.setPadLifeShown(self: AuthoredRunHud, shown: boolean)
	if self.pad ~= nil then
		self.pad:setLifeShown(shown)
	end
end

-- The pad's top block picks its authored layout for the screen.
function AuthoredRunHud.setPadLayout(self: AuthoredRunHud, viewport: Vector2, topInset: number)
	if self.pad ~= nil then
		self.pad:applyLayout(viewport, topInset)
	end
end

-- See PadHud.footprint.
function AuthoredRunHud.padFootprint(self: AuthoredRunHud, origin: Vector2, size: Vector2): (number, number, number)
	if self.pad == nil then
		return 0, 0, 0
	end

	return self.pad:footprint(origin, size)
end

-- The grade line's top and height in pixels, where a floor event's banner goes.
function AuthoredRunHud.padLineSpot(self: AuthoredRunHud, origin: Vector2): (number, number)
	if self.pad == nil then
		return 0, 0
	end

	return self.pad:lineSpot(origin)
end

function AuthoredRunHud.setHighwayActive(self: AuthoredRunHud, active: boolean)
	self.binder:setVisible("HighwayGroup", active)
	self.highwayGrades = active
	self.binder:setVisible("ProgressGroup", not self:_songBarShown())
	self:_sizeKeys(active)
	self:_moveCombo(active)

	if not active then
		self:_stopGroove()
	end

	local panel = self:_topLevel(self:_banner())

	if panel ~= nil then
		panel.Position = if active then HIGHWAY_BANNER_POSITION else self.homes[panel]
	end
end

-- The run's slide-in may already be heading for the old home, so the move is
-- a tween to the new one rather than a jump.
function AuthoredRunHud._moveCombo(self: AuthoredRunHud, active: boolean)
	local panel = self:_group("ComboGroup")

	if panel == nil then
		return
	end

	local saved = self.comboHome

	if active and not saved then
		self.comboHome = self.homes[panel]
		self.homes[panel] = HIGHWAY_COMBO_POSITION
	elseif not active and saved then
		self.homes[panel] = saved
		self.comboHome = nil
	else
		return
	end

	self.tweens:play(panel, TweenInfo.new(INTRO_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = self.homes[panel],
	})
end

function AuthoredRunHud.setSong(self: AuthoredRunHud, title: string?, artist: string?, difficulty: string?)
	self.songTitle = title or self.songTitle
	self.songDifficulty = difficulty or self.songDifficulty

	if self.pad ~= nil then
		self.pad:setSong(self.songTitle, self.songDifficulty)
	end

	if title ~= nil then
		self.binder:setText("SongTitle", string.upper(title))
	end

	if artist ~= nil then
		self.binder:setText("SongArtist", artist)
	end

	if difficulty ~= nil then
		self.binder:setText("SongDifficulty", string.upper(difficulty))
	end
end

function AuthoredRunHud._countScore(self: AuthoredRunHud, score: number)
	local counter = self.scoreCounter

	if score <= counter.Value then
		self.tweens:stop(counter)
		counter.Value = score
		self.binder:setText("ScoreValue", comma(score))
		return
	end

	self.tweens:play(counter, TweenInfo.new(SCORE_COUNT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = score,
	})
end

function AuthoredRunHud._bumpCombo(self: AuthoredRunHud, combo: number)
	local group = self:_group("ComboGroup")
	local wasShown = self.shownCombo > 0

	self.comboToken += 1
	self.shownCombo = combo
	self.binder:setText("ComboValue", tostring(combo))

	if not self:_songBarShown() and next(self.styled) ~= nil then
		self:_unstyleText()
	end
	self.binder:setVisible("ComboGroup", true)

	if group == nil then
		return
	end

	self.tweens:stop(COMBO_SHAKE)
	group.Rotation = self.tilts[group] or 0

	local scale = self:_scaleOf(group)
	scale.Scale = if not wasShown
		then COMBO_APPEAR_FROM
		elseif combo == COMBO_FIRST_MILESTONE or combo % COMBO_MILESTONE == 0 then COMBO_MILESTONE_BUMP
		else COMBO_BUMP
	self.tweens:play(scale, TweenInfo.new(COMBO_BUMP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function AuthoredRunHud._breakComboNow(self: AuthoredRunHud)
	self.comboToken += 1
	self.shownCombo = 0
	self.binder:setText("ComboValue", "0")
	self.binder:setVisible("ComboGroup", false)

	if not self:_songBarShown() then
		self:_unstyleText()
	end
end

-- The lost number stays on screen while it shakes and drops, so the player
-- sees what they lost.
function AuthoredRunHud._breakCombo(self: AuthoredRunHud)
	if self.shownCombo == 0 then
		return
	end

	local group = self:_group("ComboGroup")

	if group == nil then
		self:_breakComboNow()
		return
	end

	if self.shownCombo >= COMBO_BREAK_SHOWN_FROM then
		for _, label in self:_comboLabels() do
			self:_styleText(label, GRADE_STYLES.Miss)
		end

		self.comboTier = 0
	end

	self.comboToken += 1
	self.shownCombo = 0

	local token = self.comboToken
	local scale = self:_scaleOf(group)

	local tilt = self.tilts[group] or 0
	group.Rotation = tilt - SHAKE_DEGREES

	local shake = self.tweens:play(
		group,
		TweenInfo.new(SHAKE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, SHAKE_REPEATS, true),
		{ Rotation = tilt + SHAKE_DEGREES },
		COMBO_SHAKE
	)

	shake.Completed:Connect(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or self.comboToken ~= token then
			return
		end

		group.Rotation = tilt

		local drop = self.tweens:play(
			scale,
			TweenInfo.new(DROP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		)

		drop.Completed:Connect(function(dropState: Enum.PlaybackState)
			if dropState == Enum.PlaybackState.Completed and self.comboToken == token then
				self:_breakComboNow()
				scale.Scale = 1
			end
		end)
	end)
end

function AuthoredRunHud.showPredictedCombo(self: AuthoredRunHud, combo: number)
	if self.padActive and self.pad ~= nil then
		self.shownCombo = math.max(combo, 0)
		self.pad:setCombo(combo)
	end
end

function AuthoredRunHud.updateScore(self: AuthoredRunHud, score: number, combo: number, _hype: number?)
	self:_countScore(score)

	if self.padActive and self.pad ~= nil then
		self.shownCombo = math.max(combo, 0)
		self.pad:setCombo(combo)
		return
	end

	if combo <= 0 then
		self:_breakCombo()
	elseif combo ~= self.shownCombo then
		self:_bumpCombo(combo)
	end

	if self:_songBarShown() and combo > 0 then
		self:_colorCombo(combo)
	end
end

function AuthoredRunHud._badge(self: AuthoredRunHud, name: string, position: UDim2, color: Color3): TextLabel?
	local panel = self:_group("ComboGroup")

	if panel == nil then
		return nil
	end

	local existing = panel:FindFirstChild(name)

	if existing ~= nil and existing:IsA("TextLabel") then
		return existing
	end

	local badge: TextLabel = UiKit.create("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = BADGE_SIZE,
		BackgroundColor3 = BADGE_FILL,
		BackgroundTransparency = 0.1,
		FontFace = UiKit.FontFace,
		TextScaled = true,
		TextColor3 = color,
		Visible = false,
		ZIndex = 8,
	}, panel)
	badge:SetAttribute(BADGE_ATTRIBUTE, true)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.45, 0) }, badge)
	UiKit.create("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	UiKit.create("UIPadding", {
		PaddingLeft = UDim.new(0.1, 0),
		PaddingRight = UDim.new(0.1, 0),
		PaddingTop = UDim.new(0.12, 0),
		PaddingBottom = UDim.new(0.12, 0),
	}, badge)

	return badge
end

function AuthoredRunHud._popBadge(self: AuthoredRunHud, badge: GuiObject)
	local scale = self:_scaleOf(badge)
	scale.Scale = BADGE_POP
	self.tweens:play(scale, TweenInfo.new(BADGE_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

-- The score multiplier the streak has earned and whether the combo shield is
-- charged, both straight from the server's verdict.
function AuthoredRunHud.setComboExtras(self: AuthoredRunHud, multiplier: number, shieldReady: boolean)
	if self.pad ~= nil then
		self.pad:setExtras(multiplier, shieldReady)
	end

	local badge = self:_badge(MULTIPLIER_BADGE, MULTIPLIER_POSITION, MULTIPLIER_COLOR)

	if badge ~= nil then
		badge.Text = "x" .. tostring(multiplier)
		badge.Visible = multiplier > 1

		if multiplier > self.shownMultiplier then
			self:_popBadge(badge)
		end
	end

	local shield = self:_badge(SHIELD_BADGE, SHIELD_POSITION, SHIELD_COLOR)

	if shield ~= nil then
		shield.Text = "SHIELD"
		shield.Visible = shieldReady

		if shieldReady and not self.shownShield then
			self:_popBadge(shield)
		end
	end

	self.shownMultiplier = multiplier
	self.shownShield = shieldReady
end

function AuthoredRunHud._calloutFrame(self: AuthoredRunHud): Frame?
	local runFrame = self.runFrame

	if self.callout ~= nil or runFrame == nil then
		return self.callout
	end

	local frame: Frame = UiKit.create("Frame", {
		Name = "ComboCallout",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = CALLOUT_SIZE,
		BackgroundColor3 = BADGE_FILL,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
	}, runFrame)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0.2, 0) }, frame)
	UiKit.create("UIPadding", {
		PaddingLeft = UDim.new(0.06, 0),
		PaddingRight = UDim.new(0.06, 0),
		PaddingTop = UDim.new(0.08, 0),
		PaddingBottom = UDim.new(0.08, 0),
	}, frame)

	local rows: { { name: string, top: number, height: number } } = {
		{ name = "Title", top = 0, height = 0.62 },
		{ name = "Detail", top = 0.62, height = 0.38 },
	}

	for _, row in rows do
		local label = UiKit.create("TextLabel", {
			Name = row.name,
			Position = UDim2.fromScale(0, row.top),
			Size = UDim2.fromScale(1, row.height),
			BackgroundTransparency = 1,
			FontFace = UiKit.FontFace,
			TextScaled = true,
			ZIndex = 9,
		}, frame)
		UiKit.create("UIStroke", { Thickness = TEXT_STROKE_THICKNESS }, label)
	end

	self.callout = frame

	return frame
end

function AuthoredRunHud._hideCallout(self: AuthoredRunHud)
	self.calloutToken += 1

	if self.callout ~= nil then
		self.callout.Visible = false
	end
end

function AuthoredRunHud._showCallout(self: AuthoredRunHud, title: string, detail: string?, style: TextStyle)
	local frame = self:_calloutFrame()

	if frame == nil then
		return
	end

	local panel = self:_group("ComboGroup")
	local labels: { TextLabel } = {}

	for _, name in { "Title", "Detail" } do
		local label = frame:FindFirstChild(name) :: TextLabel
		local stroke = label:FindFirstChildOfClass("UIStroke")
		label.TextTransparency = 0
		label.TextColor3 = if name == "Title" then style.top else Color3.new(1, 1, 1)

		if stroke ~= nil then
			stroke.Color = style.stroke
			stroke.Transparency = 0
		end

		table.insert(labels, label)
	end

	labels[1].Text = title
	labels[2].Text = detail or ""
	frame.Position = if panel ~= nil then self.homes[panel] or panel.Position else HIGHWAY_COMBO_POSITION
	frame.BackgroundTransparency = CALLOUT_FILL_TRANSPARENCY
	frame.Visible = true

	local scale = self:_scaleOf(frame)
	scale.Scale = CALLOUT_POP_FROM
	self.tweens:play(scale, TweenInfo.new(CALLOUT_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })

	self.calloutToken += 1
	local token = self.calloutToken

	task.delay(CALLOUT_POP_SECONDS + CALLOUT_HOLD_SECONDS, function()
		if self.calloutToken ~= token then
			return
		end

		self.tweens:play(frame, TweenInfo.new(CALLOUT_OUT_SECONDS), { BackgroundTransparency = 1 })

		for _, label in labels do
			self.tweens:play(label, TweenInfo.new(CALLOUT_OUT_SECONDS), { TextTransparency = 1 })

			local stroke = label:FindFirstChildOfClass("UIStroke")

			if stroke ~= nil then
				self.tweens:play(stroke, TweenInfo.new(CALLOUT_OUT_SECONDS), { Transparency = 1 })
			end
		end

		task.delay(CALLOUT_OUT_SECONDS, function()
			if self.calloutToken == token then
				frame.Visible = false
			end
		end)
	end)
end

-- The combo shield caught a miss: the streak is kept and the shield is spent.
function AuthoredRunHud.showShieldSave(self: AuthoredRunHud, _combo: number)
	if self.padActive and self.pad ~= nil then
		self.pad:showShieldSave()
		return
	end

	self:_showCallout("SHIELD!", "COMBO SAVED", SHIELD_STYLE)
end

function AuthoredRunHud._setLifeLow(self: AuthoredRunHud, low: boolean)
	if self.lifeLow == low then
		return
	end

	self.lifeLow = low

	local group = self:_group("LifeGroup")

	if group == nil then
		return
	end

	local scale = self:_scaleOf(group)

	if low then
		self.tweens:play(
			scale,
			TweenInfo.new(LOW_LIFE_PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = LOW_LIFE_PULSE }
		)
	else
		self.tweens:stop(scale)
		scale.Scale = 1
	end
end

function AuthoredRunHud.updateLife(self: AuthoredRunHud, life: number?, maxLife: number?)
	local total = maxLife or 100

	if life == nil or total <= 0 then
		return
	end

	local fraction = math.clamp(life / total, 0, 1)

	if self.pad ~= nil then
		self.pad:setLife(fraction)
	end

	local fills: { Instance } = self.binder.elements["LifeFill"] or {}

	for _, inst in fills do
		if inst:IsA("GuiObject") then
			self.tweens:play(inst, TweenInfo.new(LIFE_TWEEN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(fraction, 0, inst.Size.Y.Scale, inst.Size.Y.Offset),
			})
		end
	end

	self:_setLifeLow(fraction > 0 and fraction < LOW_LIFE)
end

function AuthoredRunHud.updateProgress(self: AuthoredRunHud, elapsed: number, duration: number?)
	if duration == nil or duration <= 0 then
		return
	end

	self.binder:setFill("ProgressFill", elapsed / duration)
end

local function timingDetail(grade: string, deltaMs: number?, reason: string?): string
	if deltaMs ~= nil and grade ~= "Miss" then
		local sign = if deltaMs < 0 then "EARLY" else "LATE"

		return string.format("%s %dms", sign, math.abs(deltaMs))
	elseif reason ~= nil then
		return REASON_TEXT[reason] or ""
	end

	return ""
end

function AuthoredRunHud.showGrade(self: AuthoredRunHud, grade: string, deltaMs: number?, reason: string?)
	local delta = timingDetail(grade, deltaMs, reason)
	local style = GRADE_STYLES[grade]

	if self.padActive and self.pad ~= nil then
		self.pad:showGrade(string.upper(grade), delta, style or COUNTDOWN_STYLE, PAD_GRADE_PUNCH)
		return
	end

	self.gradeAt = os.clock()
	local spin = if grade == "Miss" or grade == "Bad" then MISS_SPIN_DEGREES else GRADE_SPIN_DEGREES
	self.gradeSpin = (math.random() * 2 - 1) * spin

	local name = if self.highwayGrades then HIGHWAY_GRADE_NAMES[grade] else nil
	self.binder:setText("JudgementText", name or (string.upper(grade) .. "!"))

	local judgement = self.binder:get("JudgementText")

	if self:_songBarShown() and style ~= nil and judgement ~= nil and judgement:IsA("TextLabel") then
		self:_styleText(judgement, style)
	end

	self.binder:setText("TimingDelta", delta)
	self:_popBanner(GRADE_PUNCH[grade])

	-- The spec gives a judgement half a second before it has to be gone.
	self.gradeToken += 1
	local token = self.gradeToken

	task.delay(GRADE_CLEAR_SECONDS, function()
		if self.gradeToken == token then
			self:_dropBanner(token)
		end
	end)
end

function AuthoredRunHud.showComboBreak(self: AuthoredRunHud, lostCombo: number, reason: string?)
	if self.padActive and self.pad ~= nil then
		self.pad:showComboBreak(lostCombo, if reason ~= nil then REASON_TEXT[reason] else nil)
		return
	end

	self:_breakCombo()

	if lostCombo >= COMBO_BREAK_CALLOUT_FROM then
		self:_showCallout("COMBO BREAK", if reason ~= nil then REASON_TEXT[reason] else nil, GRADE_STYLES.Miss)
	end
end

-- The count-in borrows the judgement slot, which is idle until the first beat,
-- rather than needing its own authored element.
function AuthoredRunHud.showCountdown(self: AuthoredRunHud, value: any)
	local pad = self.pad

	if self.padActive and pad ~= nil then
		if value == nil or value == "" then
			pad:clearLine()
		else
			pad:showLine(string.upper(tostring(value)), nil, COUNTDOWN_STYLE, PAD_COUNTDOWN_PUNCH)
		end

		return
	end

	self.gradeToken += 1

	if value == nil or value == "" then
		self:_dropBanner(self.gradeToken)
		return
	end

	self.binder:setText("JudgementText", string.upper(tostring(value)))
	self.binder:setText("TimingDelta", "")
	self:_popBanner()
end

function AuthoredRunHud.showFinal(self: AuthoredRunHud, summary: any)
	if type(summary) ~= "table" then
		return
	end

	self:_countScore(summary.score or 0)
	self.binder:setVisible("NewRecord", summary.newBest == true)
end

function AuthoredRunHud.setPhotoMode(self: AuthoredRunHud, active: boolean)
	if self.runFrame ~= nil then
		self.runFrame.Visible = not active
	end
end

-- Whether the place has a pause button to bind; the code-built one stands in
-- when it has not.
function AuthoredRunHud.bindPause(self: AuthoredRunHud, callback: () -> ()): boolean
	if self.pad ~= nil then
		self.pad:bindPause(callback)
	end

	return #self.binder:onActivated("PauseButton", callback) > 0
end

function AuthoredRunHud.refresh(self: AuthoredRunHud)
	self.binder:refresh()
end

function AuthoredRunHud.applyLayout(_self: AuthoredRunHud, _isSmall: boolean, _insetY: number?) end

-- Not authored yet. Kept so the controllers can call the same surface on either
-- HUD; each one lights up the moment its element exists and is tagged.

function AuthoredRunHud.setProgressText(_self: AuthoredRunHud, _text: string?) end

function AuthoredRunHud.updatePerformanceGoal(_self: AuthoredRunHud, _score: number, _goal: any?) end

-- Fever drives the groove: the whole HUD kicks on every beat, not every bar.
function AuthoredRunHud.updateFever(self: AuthoredRunHud, fever: any?)
	local active = type(fever) == "table" and fever.active == true
	self.feverEndsAt = if active then os.clock() + (tonumber((fever :: any).remainingSeconds) or 0) else 0
end

function AuthoredRunHud._milestoneLabel(self: AuthoredRunHud, screen: ScreenGui): TextLabel
	local existing = self.milestone

	if existing ~= nil then
		return existing
	end

	local label: TextLabel = UiKit.create("TextLabel", {
		Name = "ComboMilestone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = MILESTONE_POSITION,
		Size = MILESTONE_SIZE,
		BackgroundTransparency = 1,
		FontFace = UiKit.FontFace,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 11,
	}, screen)
	UiKit.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(MILESTONE_TOP, MILESTONE_BOTTOM) }, label)
	UiKit.create("UIStroke", { Color = MILESTONE_STROKE, Thickness = TEXT_STROKE_THICKNESS }, label)
	self.milestone = label

	return label
end

function AuthoredRunHud._hideMilestone(self: AuthoredRunHud)
	self.milestoneToken += 1

	if self.milestone ~= nil then
		self.milestone.Visible = false
	end
end

-- A call-out for a combo milestone, gone again before the next phrase: big in
-- the highway, and on the pad the combo block itself swells and reads it.
function AuthoredRunHud.showMilestone(self: AuthoredRunHud, text: string, combo: number?)
	local screen = self.screen

	if self.padActive and self.pad ~= nil then
		self.pad:showMilestone(text)
		return
	end

	if screen == nil then
		return
	end

	-- Bigger streaks get a bigger, longer call-out.
	local weight = math.clamp((combo or 0) / MILESTONE_BIG_COMBO, 0, 1)
	local label = self:_milestoneLabel(screen)
	local scale = self:_scaleOf(label)
	label.Text = text
	label.TextTransparency = 0
	label.Visible = true

	label.Position = MILESTONE_POSITION
	label.Size = grown(MILESTONE_SIZE, 1 + MILESTONE_BIG_GROW * weight)
	label.Rotation = -MILESTONE_TILT_DEGREES * weight
	scale.Scale = MILESTONE_POP_FROM
	self.tweens:play(scale, TweenInfo.new(MILESTONE_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	self.tweens:play(label, TweenInfo.new(MILESTONE_POP_SECONDS * 2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Rotation = 0,
	}, "milestoneTilt")

	self.milestoneToken += 1
	local token = self.milestoneToken

	task.delay(MILESTONE_POP_SECONDS + MILESTONE_HOLD_SECONDS + MILESTONE_BIG_HOLD_SECONDS * weight, function()
		if self.milestoneToken ~= token then
			return
		end

		local fade = self.tweens:play(label, TweenInfo.new(MILESTONE_OUT_SECONDS), { TextTransparency = 1 })

		fade.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and self.milestoneToken == token then
				label.Visible = false
			end
		end)
	end)
end

function AuthoredRunHud.flashScreen(self: AuthoredRunHud, color: Color3?)
	local screen = self.screen

	if screen == nil then
		return
	end

	local flash: Frame = self.flash or UiKit.create("Frame", {
		Name = "ScreenFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 10,
	}, screen)
	self.flash = flash
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = FLASH_FROM_TRANSPARENCY
	self.tweens:play(flash, TweenInfo.new(FLASH_SECONDS), { BackgroundTransparency = 1 })
end

return AuthoredRunHud
