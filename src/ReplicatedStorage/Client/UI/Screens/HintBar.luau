--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

local HINT_TRANSPARENCY = 0.2
local ONBOARDING_TRANSPARENCY = 0.12
local STROKE_TRANSPARENCY = 0.35
local FADE_SECONDS = 0.2
local RISE_PIXELS = 12
local LOBBY_HINT_POSITION = UDim2.fromScale(0.5, 0.94)
local LOBBY_ONBOARDING_POSITION = UDim2.fromScale(0.5, 0.36)
local LOBBY_ONBOARDING_SIZE = UDim2.fromScale(0.64, 0.15)
-- The results buttons own the bottom right, so the hint moves to the bottom left.
local RESULTS_HINT_POSITION = UDim2.fromScale(0.185, 0.975)
local RESULTS_HINT_SIZE = UDim2.fromScale(0.34, 0.05)
-- The authored results fill the bottom with the XP bar and the buttons; the top
-- centre is the clear strip.
local RESULTS_AUTHORED_HINT_POSITION = UDim2.fromScale(0.5, 0.17)

-- A label, the frame that shows and hides it (the label itself, or the authored
-- bar it sits in) and the look it fades back to.
type Slot = {
	label: TextLabel,
	root: GuiObject,
	home: UDim2,
	background: number,
	stroke: number,
	image: number?,
	muted: boolean?,
}

type Fields = {
	hint: Slot,
	onboarding: Slot,
	runHint: Slot?,
	runOnboarding: Slot?,
	hintAuthored: boolean,
	lobbyHintHome: UDim2,
	isSmall: boolean,
	isTouch: boolean,
	isPhone: boolean,
	runLayout: boolean,
	resultsLayout: boolean,
}

-- The controls hint and the onboarding tip. During a run they are the labels
-- authored in StarterGui.GameHud.RunHint; in the lobby and on the results
-- screen they are the bars authored in StarterGui.Lobby, or built here when a
-- place has none.
local HintBar = {}
HintBar.__index = HintBar

export type HintBar = typeof(setmetatable({} :: Fields, HintBar))

local function pill(label: TextLabel)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0, 10) }, label)
	UiKit.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Colors.Fever,
		Thickness = 2,
		Transparency = STROKE_TRANSPARENCY,
	}, label)
	UiKit.create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, label)
end

local function authoredSlot(label: TextLabel?): Slot?
	if label == nil then
		return nil
	end

	local stroke = label:FindFirstChildWhichIsA("UIStroke")
	label.Visible = false

	return {
		label = label,
		root = label,
		home = label.Position,
		background = label.BackgroundTransparency,
		stroke = if stroke ~= nil then stroke.Transparency else 1,
	}
end

-- An authored bar with its text in a child label.
local function authoredBar(bar: GuiObject?, labelName: string): Slot?
	local label = UiKit.authored(bar, labelName, "TextLabel")

	if bar == nil or label == nil then
		return nil
	end

	bar.Visible = false

	return {
		label = label,
		root = bar,
		home = bar.Position,
		background = bar.BackgroundTransparency,
		stroke = 1,
		image = if bar:IsA("ImageLabel") then bar.ImageTransparency else nil,
		-- A designer can switch a bar off in Studio without touching the code.
		muted = bar:GetAttribute("Muted") == true,
	}
end

local function codeSlot(label: TextLabel, home: UDim2, background: number): Slot
	return {
		label = label,
		root = label,
		home = home,
		background = background,
		stroke = STROKE_TRANSPARENCY,
	}
end

-- Fades the label in and lifts it into place, or fades it out and hides it.
local function fade(slot: Slot, show: boolean)
	local label, root = slot.label, slot.root
	local stroke = root:FindFirstChildWhichIsA("UIStroke")
	local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if show and slot.muted then
		show = false
	end

	if show then
		if not root.Visible then
			label.TextTransparency = 1
			root.BackgroundTransparency = 1
			root.Position = slot.home + UDim2.fromOffset(0, RISE_PIXELS)

			if slot.image ~= nil then
				(root :: ImageLabel).ImageTransparency = 1
			end
		end

		root.Visible = true
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
		TweenService:Create(root, info, { BackgroundTransparency = slot.background, Position = slot.home }):Play()

		if slot.image ~= nil then
			TweenService:Create(root, info, { ImageTransparency = slot.image }):Play()
		end

		if stroke ~= nil then
			TweenService:Create(stroke, TweenInfo.new(FADE_SECONDS), { Transparency = slot.stroke }):Play()
		end

		return
	end

	if not root.Visible then
		return
	end

	local goal: { [string]: any } = { BackgroundTransparency = 1 }

	if slot.image ~= nil then
		goal.ImageTransparency = 1
	end

	local tween = TweenService:Create(root, TweenInfo.new(FADE_SECONDS), goal)

	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			root.Visible = false
		end
	end)
	tween:Play()
	TweenService:Create(label, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1 }):Play()

	if stroke ~= nil then
		TweenService:Create(stroke, TweenInfo.new(FADE_SECONDS), { Transparency = 1 }):Play()
	end
end

-- runHint is GameHud.RunHint, holding the ControlsHint and Onboarding labels;
-- lobby is StarterGui.Lobby, holding the Hint and Onboarding bars.
function HintBar.new(parent: Instance, runHint: Instance?, lobby: Instance?): HintBar
	local lobbyHint = authoredBar(UiKit.authored(lobby, "Hint", "GuiObject"), "HintLabel")
	local lobbyOnboarding = authoredBar(UiKit.authored(lobby, "Onboarding", "GuiObject"), "OnboardingLabel")
	local hint = lobbyHint
	local onboarding = lobbyOnboarding

	if hint == nil then
		local hintLabel = UiKit.label(parent, "ControlsHint", "", Colors.White, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = LOBBY_HINT_POSITION,
			BackgroundTransparency = HINT_TRANSPARENCY,
			BackgroundColor3 = Colors.Panel,
			TextWrapped = true,
		})
		pill(hintLabel)
		hint = codeSlot(hintLabel, LOBBY_HINT_POSITION, HINT_TRANSPARENCY)
	end

	if onboarding == nil then
		local onboardingLabel = UiKit.label(parent, "Onboarding", "", Colors.White, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = LOBBY_ONBOARDING_POSITION,
			Size = LOBBY_ONBOARDING_SIZE,
			BackgroundTransparency = ONBOARDING_TRANSPARENCY,
			BackgroundColor3 = Colors.Surface,
			TextWrapped = true,
			Visible = false,
		})
		pill(onboardingLabel)
		onboarding = codeSlot(onboardingLabel, LOBBY_ONBOARDING_POSITION, ONBOARDING_TRANSPARENCY)
	end

	local fields: Fields = {
		hint = hint :: Slot,
		onboarding = onboarding :: Slot,
		runHint = authoredSlot(UiKit.authored(runHint, "ControlsHint", "TextLabel")),
		runOnboarding = authoredSlot(UiKit.authored(runHint, "Onboarding", "TextLabel")),
		hintAuthored = lobbyHint ~= nil,
		lobbyHintHome = (hint :: Slot).home,
		isSmall = false,
		isTouch = false,
		isPhone = false,
		runLayout = false,
		resultsLayout = false,
	}

	return setmetatable(fields, HintBar)
end

function HintBar._hintSlot(self: HintBar): Slot
	return if self.runLayout and self.runHint ~= nil then self.runHint else self.hint
end

function HintBar._onboardingSlot(self: HintBar): Slot
	return if self.runLayout and self.runOnboarding ~= nil then self.runOnboarding else self.onboarding
end

function HintBar._allSlots(self: HintBar): { Slot }
	local slots = { self.hint, self.onboarding }

	for _, slot in { self.runHint, self.runOnboarding } do
		if slot ~= nil then
			table.insert(slots, slot)
		end
	end

	return slots
end

-- A phone's screen has no room for either bar beside the pad and its keys, so
-- during a run they stay hidden there.
function HintBar._muted(self: HintBar): boolean
	return self.runLayout and self.isPhone
end

-- Only the lobby hint is laid out here; the run's labels are the designer's, and
-- an authored lobby bar only moves out of the results' way. Touch keeps the
-- code-built hint narrower, clear of the result buttons.
function HintBar.applyLayout(self: HintBar, isSmall: boolean, isTouch: boolean, isPhone: boolean?)
	self.isSmall = isSmall
	self.isTouch = isTouch
	self.isPhone = isPhone == true

	if self:_muted() then
		for _, slot in self:_allSlots() do
			slot.root.Visible = false
		end
	end

	local hint = self.hint

	if self.hintAuthored then
		hint.home = if self.resultsLayout then RESULTS_AUTHORED_HINT_POSITION else self.lobbyHintHome
	elseif self.resultsLayout then
		hint.home = RESULTS_HINT_POSITION
		hint.label.Size = RESULTS_HINT_SIZE
	elseif isTouch then
		hint.home = LOBBY_HINT_POSITION
		hint.label.Size = UDim2.fromScale(0.5, if isSmall then 0.06 else 0.052)
	else
		hint.home = LOBBY_HINT_POSITION
		hint.label.Size = if isSmall then UDim2.fromScale(0.88, 0.06) else UDim2.fromScale(0.72, 0.052)
	end

	hint.root.Position = hint.home
end

-- Swapping between the run's labels and the lobby's hides the set going away;
-- the controllers set fresh text for the new one straight after.
function HintBar.setRunLayout(self: HintBar, active: boolean)
	if self.runLayout ~= active then
		for _, slot in { self:_hintSlot(), self:_onboardingSlot() } do
			slot.root.Visible = false
		end
	end

	self.runLayout = active
	self:applyLayout(self.isSmall, self.isTouch, self.isPhone)
end

function HintBar.setResultsLayout(self: HintBar, active: boolean)
	self.resultsLayout = active
	self:applyLayout(self.isSmall, self.isTouch, self.isPhone)
end

-- rich marks text that carries UiKit.tint colour tags; plain hints stay plain
-- so a song title with an ampersand is not read as markup.
function HintBar.setHint(self: HintBar, text: string?, rich: boolean?)
	local slot = self:_hintSlot()
	local show = text ~= nil and text ~= ""

	if show then
		slot.label.RichText = rich == true
		slot.label.Text = text :: string
	end

	fade(slot, show and not self:_muted())
end

-- Sets the text without changing whether the bar is showing.
function HintBar.setControlsHint(self: HintBar, text: string?)
	if text ~= nil and text ~= "" then
		local label = self:_hintSlot().label
		label.RichText = false
		label.Text = text
	end
end

function HintBar.showOnboarding(self: HintBar, text: string?)
	local slot = self:_onboardingSlot()
	local show = text ~= nil and text ~= ""

	if show then
		slot.label.Text = text :: string
	end

	fade(slot, show and not self:_muted())
end

return HintBar
