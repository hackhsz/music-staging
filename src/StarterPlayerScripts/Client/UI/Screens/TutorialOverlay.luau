--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors
local GUI_NAME = "Lesson"
-- Off a run the card sits up top, clear of the lobby's bottom hints.
local CARD_TOP = 0.13
local POP_SECONDS = 0.25
local HIGHLIGHT_THICKNESS = 4
local HIGHLIGHT_PULSE_SECONDS = 0.6
local TAP_POP = 1.15
local CALLOUT_POP = 1.15
local CALLOUT_POP_SECONDS = 0.2

-- The floor's own colours for each kind of step, so the demo matches the pad.
local KIND_COLORS: { [string]: Color3 } = {
	tap = Colors.Pink,
	shape = Colors.Cyan,
	hold = Colors.Purple,
	clap = Colors.Yellow,
	danger = Colors.Red,
}
local DEMO_BEAT_SECONDS = 0.55
local DEMO_GRID = 3
local DEMO_HOME = Vector2.new(2, 2)
local TEXT_LABELS = { "Step", "Title", "Body", "Hint" }

type Fields = {
	ready: boolean,
	gui: ScreenGui?,
	paused: boolean,
	covered: boolean,
	card: GuiObject,
	cardAnchor: Vector2,
	cardPosition: UDim2,
	scale: UIScale,
	step: TextLabel,
	title: TextLabel,
	body: TextLabel,
	hint: TextLabel,
	hintColor: Color3,
	hintScale: UIScale,
	texts: { [TextLabel]: UDim2 },
	textShift: number,
	tries: GuiObject,
	pip: GuiObject,
	skip: GuiButton,
	action: TextButton,
	demo: GuiObject,
	demoTiles: { [number]: GuiObject },
	demoDancer: GuiObject,
	demoLabel: TextLabel,
	demoToken: number,
	tapPad: GuiObject,
	tapButton: TextButton,
	tapCount: TextLabel,
	tapScale: UIScale,
	highlighted: UIStroke?,
	highlightTween: Tween?,
	onAction: (() -> ())?,
	onTap: (() -> ())?,
}

-- The first-join cards, authored in StarterGui.Lesson: a lesson drill's card with
-- a looping demo of its move and a pip per try, the timing check's tap pad, a
-- card with one action (PLAY), and the tips, which can ring a lobby button.
-- Drawing only; OnboardingController drives it.
local TutorialOverlay = {}
TutorialOverlay.__index = TutorialOverlay

export type TutorialOverlay = typeof(setmetatable({} :: Fields, TutorialOverlay))

function TutorialOverlay.new(playerGui: Instance): TutorialOverlay
	local gui = UiKit.authoredGui(playerGui, GUI_NAME)
	local card = UiKit.authored(gui, "Card", "GuiObject")
	local demo = UiKit.authored(card, "Demo", "GuiObject")
	local tapPad = UiKit.authored(gui, "TapPad", "GuiObject")
	local tapButton = UiKit.authored(tapPad, "Tap", "TextButton")
	local tries = UiKit.authored(card, "Tries", "GuiObject")
	local fields = {
		ready = false,
		gui = gui,
		paused = false,
		covered = false,
		texts = {},
		textShift = 0,
		demoTiles = {},
		demoToken = 0,
		highlighted = nil,
		highlightTween = nil,
		onAction = nil,
		onTap = nil,
	} :: any
	local self = setmetatable(fields :: Fields, TutorialOverlay)

	if card == nil or demo == nil or tapPad == nil or tapButton == nil or tries == nil then
		return self
	end

	self.card = card
	self.cardAnchor = card.AnchorPoint
	self.cardPosition = card.Position
	self.scale = UiKit.scaleOf(card, "Pop")
	self.step = UiKit.authored(card, "Step", "TextLabel")
	self.title = UiKit.authored(card, "Title", "TextLabel")
	self.body = UiKit.authored(card, "Body", "TextLabel")
	self.hint = UiKit.authored(card, "Hint", "TextLabel")
	self.skip = UiKit.authored(card, "Skip", "GuiButton")
	self.action = UiKit.authored(card, "Action", "TextButton")
	self.tries = tries
	self.pip = UiKit.authored(tries, "Pip", "GuiObject")
	self.demo = demo
	self.demoDancer = UiKit.authored(demo, "Dancer", "GuiObject")
	self.demoLabel = UiKit.authored(demo, "Label", "TextLabel")
	self.tapPad = tapPad
	self.tapButton = tapButton
	self.tapCount = UiKit.authored(tapPad, "Count", "TextLabel")
	self.tapScale = UiKit.scaleOf(tapButton, "Pop")

	for y = 1, DEMO_GRID do
		for x = 1, DEMO_GRID do
			self.demoTiles[(y - 1) * DEMO_GRID + x] = UiKit.authored(demo, ("Tile%d%d"):format(x, y), "GuiObject")
		end
	end

	for _, name in TEXT_LABELS do
		local label = UiKit.authored(card, name, "TextLabel")

		if label == nil then
			return self
		end

		self.texts[label] = label.Position
	end

	if self.hint == nil or self.skip == nil or self.action == nil or self.pip == nil or self.demoLabel == nil then
		return self
	end

	-- Without the demo the text moves over into its place.
	self.textShift = self.step.Position.X.Scale - demo.Position.X.Scale
	self.hintColor = self.hint.TextColor3
	self.hintScale = UiKit.scaleOf(self.hint, "Pop")
	self.pip.Visible = false
	card.Visible = false
	tapPad.Visible = false
	self.ready = true

	UiKit.bindSounds(self.skip)
	UiKit.bindSounds(self.action)
	self.action.Activated:Connect(function()
		if self.onAction ~= nil then
			self.onAction()
		end
	end)
	tapButton.Activated:Connect(function()
		if self.onTap ~= nil then
			self.onTap()
		end
	end)

	return self
end

function TutorialOverlay.bindSkip(self: TutorialOverlay, callback: () -> ())
	if self.ready then
		self.skip.Activated:Connect(callback)
	end
end

function TutorialOverlay.bindTap(self: TutorialOverlay, callback: () -> ())
	self.onTap = callback
end

export type Card = {
	title: string,
	text: string,
	hint: string?,
	progress: string?,
	demo: string?,
	action: string?,
	onAction: (() -> ())?,
	skippable: boolean?,
	low: boolean?,
	tries: { total: number, landed: { [number]: boolean } }?,
}

function TutorialOverlay.show(self: TutorialOverlay, card: Card)
	if not self.ready then
		return
	end

	local changed = not self.card.Visible or self.title.Text ~= card.title

	self.title.Text = card.title
	self.body.Text = card.text
	self.hint.Text = card.hint or ""
	self.hint.TextColor3 = self.hintColor
	self.step.Text = card.progress or ""
	self.skip.Visible = card.skippable ~= false
	self.action.Visible = card.action ~= nil
	self.action.Text = card.action or ""
	self.onAction = card.onAction
	self:_place(card.low == true)
	self:_playDemo(card.demo)
	self:setTries(if card.tries ~= nil then card.tries.total else 0, if card.tries ~= nil then card.tries.landed else {})
	self.card.Visible = true

	if changed then
		self.scale.Scale = 0.85
		TweenService:Create(self.scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- One pip per try of a drill: green landed, red missed, dim still to come.
function TutorialOverlay.setTries(self: TutorialOverlay, total: number, landed: { [number]: boolean })
	if not self.ready then
		return
	end

	local tries = self.tries
	tries.Visible = total > 0

	for _, child in tries:GetChildren() do
		if child ~= self.pip and child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index = 1, total do
		local result = landed[index]
		local pip = self.pip:Clone()
		pip.Name = tostring(index)
		pip.LayoutOrder = index
		pip.BackgroundColor3 = if result == true then Colors.Green elseif result == false then Colors.Red else Colors.Track
		pip.Visible = true
		pip.Parent = tries
	end
end

function TutorialOverlay.stopDemo(self: TutorialOverlay)
	if self.ready and self.demo.Visible then
		self:_playDemo(nil)
	end
end

-- The call-out after each try, in the hint's place: green for a hit, red for a miss.
function TutorialOverlay.setHint(self: TutorialOverlay, text: string, good: boolean)
	if not self.ready then
		return
	end

	self.hint.Text = text
	self.hint.TextColor3 = if good then Colors.Green else Colors.Red
	self.hintScale.Scale = CALLOUT_POP
	TweenService:Create(self.hintScale, TweenInfo.new(CALLOUT_POP_SECONDS, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function TutorialOverlay._place(self: TutorialOverlay, low: boolean)
	if low then
		self.card.AnchorPoint = self.cardAnchor
		self.card.Position = self.cardPosition
	else
		self.card.AnchorPoint = Vector2.new(0.5, 0)
		self.card.Position = UDim2.fromScale(0.5, CARD_TOP)
	end
end

function TutorialOverlay.hide(self: TutorialOverlay)
	if not self.ready then
		return
	end

	self.card.Visible = false
	self.onAction = nil
	self:_playDemo(nil)
	self:showTapPad(false)
	self:highlight(nil)
end

-- The pause menu and the lobby windows cover the card's spot, so it steps aside
-- until they close.
function TutorialOverlay.setPaused(self: TutorialOverlay, paused: boolean)
	self.paused = paused
	self:_refreshEnabled()
end

function TutorialOverlay.setCovered(self: TutorialOverlay, covered: boolean)
	self.covered = covered
	self:_refreshEnabled()
end

function TutorialOverlay._refreshEnabled(self: TutorialOverlay)
	if self.gui ~= nil then
		self.gui.Enabled = not (self.paused or self.covered)
	end
end

function TutorialOverlay.isShowing(self: TutorialOverlay): boolean
	return self.ready and self.card.Visible
end

function TutorialOverlay.showTapPad(self: TutorialOverlay, visible: boolean)
	if self.ready then
		self.tapPad.Visible = visible
	end
end

function TutorialOverlay.setTapCount(self: TutorialOverlay, text: string)
	if self.ready and self.tapCount ~= nil then
		self.tapCount.Text = text
	end
end

-- The tap pad swells on each beat it asks for.
function TutorialOverlay.pulseTap(self: TutorialOverlay, counting: boolean)
	if not self.ready then
		return
	end

	self.tapButton.BackgroundColor3 = if counting then Colors.Track else Colors.Yellow
	self.tapScale.Scale = TAP_POP
	TweenService:Create(self.tapScale, TweenInfo.new(0.2), { Scale = 1 }):Play()
end

-- Rings one button in yellow; nil takes the ring off.
function TutorialOverlay.highlight(self: TutorialOverlay, target: GuiObject?)
	if self.highlightTween ~= nil then
		self.highlightTween:Cancel()
		self.highlightTween = nil
	end

	if self.highlighted ~= nil then
		self.highlighted:Destroy()
		self.highlighted = nil
	end

	if target == nil then
		return
	end

	local stroke = UiKit.create("UIStroke", {
		Name = "TutorialHighlight",
		Color = Colors.Yellow,
		Thickness = HIGHLIGHT_THICKNESS,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, target)
	local pulse = TweenService:Create(
		stroke,
		TweenInfo.new(HIGHLIGHT_PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	)
	pulse:Play()
	self.highlighted = stroke
	self.highlightTween = pulse
end

function TutorialOverlay._tile(self: TutorialOverlay, x: number, y: number): GuiObject
	return self.demoTiles[(y - 1) * DEMO_GRID + x]
end

function TutorialOverlay._moveDancer(self: TutorialOverlay, x: number, y: number, seconds: number)
	local cell = 1 / DEMO_GRID
	local goal = { Position = UDim2.fromScale((x - 0.5) * cell, (y - 0.5) * cell) }

	if seconds <= 0 then
		self.demoDancer.Position = goal.Position
	else
		TweenService:Create(self.demoDancer, TweenInfo.new(seconds, Enum.EasingStyle.Quad), goal):Play()
	end
end

-- One pass of a move on the mini floor: the target lights and counts down, the
-- dot dances it, and the label says what happened. Loops until the card changes.
function TutorialOverlay._demoPass(self: TutorialOverlay, kind: string, token: number)
	local beat = DEMO_BEAT_SECONDS
	local color = KIND_COLORS[kind] or Colors.Pink
	local home = DEMO_HOME
	local target = Vector2.new(2, 1)
	local other = Vector2.new(3, 1)

	local function alive(): boolean
		return self.demoToken == token
	end

	local function paint(at: Vector2, tint: Color3)
		self:_tile(at.X, at.Y).BackgroundColor3 = tint
	end

	for _, tile in self.demoTiles do
		tile.BackgroundColor3 = Colors.Track
		tile.BackgroundTransparency = 0
	end

	self:_moveDancer(home.X, home.Y, 0)
	self.demoLabel.Text = ""

	if kind == "clap" then
		target = home
	elseif kind == "danger" then
		paint(home, Colors.Red)
	end

	paint(target, color)

	if kind == "shape" then
		paint(other, color)
	end

	for count = 3, 1, -1 do
		self.demoLabel.Text = if kind == "danger" and count == 1 then "MOVE!" else tostring(count)
		task.wait(beat)

		if not alive() then
			return
		end

		if count == 2 and kind ~= "clap" then
			self:_moveDancer(target.X, target.Y, beat * 0.9)
		end
	end

	if kind == "clap" then
		self.demoLabel.Text = "CLAP!"
	elseif kind == "danger" then
		self.demoLabel.Text = "DODGED!"
		paint(home, Colors.Track)
	elseif kind == "hold" then
		for left = 3, 1, -1 do
			self.demoLabel.Text = "STAY " .. left
			self:_tile(target.X, target.Y).BackgroundTransparency = (3 - left) / 3

			task.wait(beat)

			if not alive() then
				return
			end
		end

		self:_tile(target.X, target.Y).BackgroundTransparency = 0
		self.demoLabel.Text = "PERFECT!"
	else
		self.demoLabel.Text = "PERFECT!"
	end

	task.wait(beat * 2)
end

function TutorialOverlay._playDemo(self: TutorialOverlay, kind: string?)
	self.demoToken += 1
	self.demo.Visible = kind ~= nil

	for label, home in self.texts do
		label.Position = if kind ~= nil then home else home - UDim2.fromScale(self.textShift, 0)
	end

	if kind == nil then
		return
	end

	local token = self.demoToken

	task.spawn(function()
		while self.demoToken == token do
			self:_demoPass(kind, token)
		end
	end)
end

return TutorialOverlay
