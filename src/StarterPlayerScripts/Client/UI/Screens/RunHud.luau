--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

-- Judgement popup per grade: PERFECT pops gold, GOOD stays cool cyan, MISS
-- flashes red with a shake.
local GRADE_STYLES = {
	PERFECT = {
		color = Colors.Amber,
		strokeColor = Color3.fromRGB(120, 78, 16),
		scalePunch = 1.3,
	},
	GREAT = {
		color = Colors.Green,
		strokeColor = Color3.fromRGB(20, 82, 40),
		scalePunch = 1.2,
	},
	GOOD = {
		color = Color3.fromRGB(86, 222, 255),
		strokeColor = Color3.fromRGB(20, 64, 92),
		scalePunch = 1.1,
	},
	BAD = {
		color = Color3.fromRGB(168, 132, 150),
		strokeColor = Color3.fromRGB(58, 40, 48),
		shake = true,
	},
	MISS = {
		color = Colors.Red,
		strokeColor = Color3.fromRGB(92, 18, 26),
		shake = true,
	},
}

local GRADE_BASE_SIZE = UDim2.fromScale(0.22, 0.055)
local FLASH_COOLDOWN_SECONDS = 0.2

-- Pixel offsets down from the GUI inset; the column never overlaps itself.
local LAYOUT = {
	score = { y = 12, height = 40 },
	life = { y = 56, height = 18 },
	progress = { y = 78, height = 26 },
	goal = { y = 108, height = 28 },
	gradeY = 142,
	deltaY = 188,
	feverY = 216,
	comboBreakY = 262,
}

type Fields = {
	scoreLabel: TextLabel,
	lifeBar: Frame,
	lifeFill: Frame,
	lifeLabel: TextLabel,
	progressLabel: TextLabel,
	goalTrack: Frame,
	goalFill: Frame,
	goalLabel: TextLabel,
	gradeLabel: TextLabel,
	comboBreakLabel: TextLabel,
	timingDeltaLabel: TextLabel,
	feverLabel: TextLabel,
	countdownLabel: TextLabel,
	screenFlash: Frame,
	lastFlashAt: number,
	goalWasVisible: boolean,
}

local RunHud = {}
RunHud.__index = RunHud

export type RunHud = typeof(setmetatable({} :: Fields, RunHud))

function RunHud.new(parent: Instance): RunHud
	local scoreLabel = UiKit.label(parent, "ScoreCombo", "SCORE 0  COMBO 0", Colors.Yellow, {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Colors.Panel,
		TextWrapped = true,
	})

	local lifeBar = UiKit.create("Frame", {
		Name = "LifeBar",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Colors.Panel,
		BorderSizePixel = 0,
	}, parent)
	local lifeFill = UiKit.create("Frame", {
		Name = "LifeFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Green,
		BorderSizePixel = 0,
	}, lifeBar)
	local lifeLabel = UiKit.label(lifeBar, "LifeLabel", "LIFE", Colors.White, {
		Size = UDim2.fromScale(1, 1),
	})

	local screenFlash = UiKit.create("Frame", {
		Name = "ScreenFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Active = false,
	}, parent)

	local progressLabel = UiKit.label(parent, "SongProgress", "READY", Colors.Cyan, {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Colors.Track,
		TextWrapped = true,
	})

	local goalTrack = UiKit.create("Frame", {
		Name = "PerformanceGoalTrack",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, parent)
	local goalFill = UiKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Yellow,
		BorderSizePixel = 0,
	}, goalTrack)
	local goalLabel = UiKit.label(goalTrack, "Label", "", Colors.White, {
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.15,
		TextStrokeColor3 = Colors.Panel,
		TextWrapped = true,
	})

	local gradeLabel = UiKit.label(parent, "Grade", "", Colors.Green, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = GRADE_BASE_SIZE,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Colors.Panel,
	})

	local comboBreakLabel = UiKit.label(parent, "ComboBreak", "", Colors.Red, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.26, 0.05),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(60, 10, 16),
		Visible = false,
	})

	local timingDeltaLabel = UiKit.label(parent, "TimingDelta", "", Colors.Cyan, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.18, 0.032),
		TextStrokeTransparency = 0.35,
		TextStrokeColor3 = Colors.Panel,
	})

	local feverLabel = UiKit.label(parent, "Fever", "", Colors.White, {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.12,
		BackgroundColor3 = Colors.Fever,
		TextStrokeTransparency = 0.15,
		TextStrokeColor3 = Colors.Panel,
		TextWrapped = true,
		Visible = false,
	})

	local countdownLabel = UiKit.label(parent, "Countdown", "", Colors.Yellow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.24, 0.18),
		TextStrokeColor3 = Colors.Panel,
		TextStrokeTransparency = 0,
		Visible = false,
	})

	local fields: Fields = {
		scoreLabel = scoreLabel,
		lifeBar = lifeBar,
		lifeFill = lifeFill,
		lifeLabel = lifeLabel,
		progressLabel = progressLabel,
		goalTrack = goalTrack,
		goalFill = goalFill,
		goalLabel = goalLabel,
		gradeLabel = gradeLabel,
		comboBreakLabel = comboBreakLabel,
		timingDeltaLabel = timingDeltaLabel,
		feverLabel = feverLabel,
		countdownLabel = countdownLabel,
		screenFlash = screenFlash,
		lastFlashAt = 0,
		goalWasVisible = false,
	}

	return setmetatable(fields, RunHud)
end

function RunHud.applyLayout(self: RunHud, isSmall: boolean, insetY: number)
	local wide = if isSmall then 0.46 else 0.34

	local function place(label: GuiObject, row: { y: number, height: number }, width: number)
		label.Position = UDim2.new(0.5, 0, 0, insetY + row.y)
		label.Size = UDim2.new(width, 0, 0, row.height)
	end

	place(self.scoreLabel, LAYOUT.score, wide)
	place(self.lifeBar, LAYOUT.life, wide)
	place(self.progressLabel, LAYOUT.progress, if isSmall then 0.34 else 0.26)
	place(self.goalTrack, LAYOUT.goal, wide)

	self.gradeLabel.Position = UDim2.new(0.5, 0, 0, insetY + LAYOUT.gradeY)
	self.timingDeltaLabel.Position = UDim2.new(0.5, 0, 0, insetY + LAYOUT.deltaY)
	self.feverLabel.Position = UDim2.new(0.5, 0, 0, insetY + LAYOUT.feverY)
	self.feverLabel.Size = if isSmall then UDim2.fromScale(0.44, 0.052) else UDim2.fromScale(0.3, 0.05)
	self.comboBreakLabel.Position = UDim2.new(0.5, 0, 0, insetY + LAYOUT.comboBreakY)
end

-- The score column belongs to a run. Sitting at zero over the song list it is
-- just noise, so the whole column leaves the screen between runs.
-- The code-built HUD has no lane keys; the highway draws its own.
function RunHud.getLaneKeys(_self: RunHud): { GuiObject }
	return {}
end

function RunHud.setHighwayActive(_self: RunHud, _active: boolean) end

function RunHud.groove(_self: RunHud, _beat: number) end

function RunHud.setRunActive(_self: RunHud, _active: boolean) end

-- The code-built HUD has no pause button of its own; PauseOverlay's stands in.
function RunHud.bindPause(_self: RunHud, _callback: () -> ()): boolean
	return false
end

function RunHud.setSong(_self: RunHud, _title: string?, _artist: string?, _difficulty: string?) end

function RunHud.setIdle(self: RunHud, idle: boolean)
	local visible = not idle

	self.scoreLabel.Visible = visible
	self.lifeBar.Visible = visible
	self.progressLabel.Visible = visible
	self.goalTrack.Visible = visible and self.goalWasVisible

	if not idle then
		return
	end

	for _, label in { self.gradeLabel, self.comboBreakLabel, self.timingDeltaLabel, self.feverLabel, self.countdownLabel } do
		label.Text = ""
	end
end

function RunHud.updateScore(self: RunHud, score: number, combo: number, hype: number?)
	self.scoreLabel.Text = ("SCORE %d  COMBO %d  HYPE %d"):format(score, combo, hype or 0)
end

function RunHud.updateLife(self: RunHud, life: number?, maxLife: number?)
	if life == nil then
		return
	end

	local ratio = math.clamp(life / (maxLife or 100), 0, 1)

	self.lifeFill.Size = UDim2.fromScale(ratio, 1)

	if ratio > 0.5 then
		self.lifeFill.BackgroundColor3 = Colors.Green
	elseif ratio > 0.25 then
		self.lifeFill.BackgroundColor3 = Colors.Amber
	else
		self.lifeFill.BackgroundColor3 = Colors.Red
	end

	self.lifeLabel.Text = ("LIFE %d"):format(math.floor(life + 0.5))
end

function RunHud.showGrade(self: RunHud, grade: string, deltaMs: number?)
	local gradeText = grade:upper()
	local style = GRADE_STYLES[gradeText]
	local label = self.gradeLabel

	label.Text = gradeText
	label.TextColor3 = if style ~= nil then style.color else Colors.White
	label.TextStrokeColor3 = if style ~= nil then style.strokeColor else Colors.Panel
	label.Size = GRADE_BASE_SIZE

	if style ~= nil and style.scalePunch ~= nil then
		label.Size = UDim2.fromScale(GRADE_BASE_SIZE.X.Scale * 0.6, GRADE_BASE_SIZE.Y.Scale * 0.6)

		local punch = TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(
				GRADE_BASE_SIZE.X.Scale * style.scalePunch,
				GRADE_BASE_SIZE.Y.Scale * style.scalePunch
			),
		})
		punch.Completed:Connect(function()
			TweenService:Create(label, TweenInfo.new(0.1), { Size = GRADE_BASE_SIZE }):Play()
		end)
		punch:Play()
	elseif style ~= nil and style.shake == true then
		local basePosition = label.Position

		task.spawn(function()
			for _, offset in { -6, 6, -3, 3, 0 } do
				label.Position = basePosition + UDim2.fromOffset(offset, 0)
				task.wait(0.03)
			end

			label.Position = basePosition
		end)
	end

	local deltaText = ""

	if deltaMs ~= nil then
		if deltaMs < 0 then
			deltaText = ("EARLY %dMS"):format(deltaMs)
			self.timingDeltaLabel.TextColor3 = Colors.Cyan
		elseif deltaMs > 0 then
			deltaText = ("LATE +%dMS"):format(deltaMs)
			self.timingDeltaLabel.TextColor3 = Colors.Pink
		else
			deltaText = "ON BEAT"
			self.timingDeltaLabel.TextColor3 = Colors.Green
		end
	end

	self.timingDeltaLabel.Text = deltaText

	task.delay(0.35, function()
		if label.Text == gradeText then
			label.Text = ""
		end

		if self.timingDeltaLabel.Text == deltaText then
			self.timingDeltaLabel.Text = ""
		end
	end)
end

function RunHud.showComboBreak(self: RunHud, lostCombo: number)
	local label = self.comboBreakLabel
	local text = if lostCombo >= 10 then ("COMBO BREAK %d"):format(lostCombo) else "COMBO BREAK"

	label.Text = text
	label.Visible = true
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0

	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fade.Completed:Connect(function()
		if label.Text == text then
			label.Visible = false
			label.Text = ""
		end
	end)
	fade:Play()
end

function RunHud.updateProgress(self: RunHud, elapsed: number, duration: number?)
	if duration == nil or duration <= 0 then
		self.progressLabel.Text = "PLAYING"
		return
	end

	self.progressLabel.Text = ("%02d SEC LEFT"):format(math.max(0, math.ceil(duration - elapsed)))
end

function RunHud.setProgressText(self: RunHud, text: string?)
	if text ~= nil and text ~= "" then
		self.progressLabel.Text = text
	end
end

function RunHud.updatePerformanceGoal(self: RunHud, score: number, goal: any?)
	if goal == nil or goal.targetScore == nil or goal.targetScore <= 0 then
		self.goalTrack.Visible = false
		self.goalFill.Size = UDim2.fromScale(0, 1)
		self.goalLabel.Text = ""
		return
	end

	local progress = math.clamp(score / goal.targetScore, 0, 1)

	self.goalTrack.Visible = true
	self.goalFill.Size = UDim2.fromScale(progress, 1)
	self.goalFill.BackgroundColor3 = if progress >= 1 then Colors.Green else Colors.Yellow
	self.goalLabel.Text = ("%s %d/%d"):format(goal.label or "GOAL", math.min(score, goal.targetScore), goal.targetScore)
end

function RunHud.updateFever(self: RunHud, fever: any?)
	if type(fever) ~= "table" or fever.active ~= true then
		self.feverLabel.Visible = false
		self.feverLabel.Text = ""
		return
	end

	local prefix = if fever.started then "FEVER START" else "FEVER"
	local bonus = fever.bonusScore or 0
	local seconds = fever.remainingSeconds or 0

	if bonus > 0 then
		self.feverLabel.Text = ("%s  +%d  %dS"):format(prefix, bonus, seconds)
	else
		self.feverLabel.Text = ("%s  %dS"):format(prefix, seconds)
	end

	self.feverLabel.Visible = true
end

function RunHud.showCountdown(self: RunHud, value: any)
	if value == nil or value == "" then
		self.countdownLabel.Visible = false
		self.countdownLabel.Text = ""
		return
	end

	self.countdownLabel.Visible = true
	self.countdownLabel.Text = tostring(value)
end

-- A soft accent, throttled so a dense run of Perfects cannot strobe the screen.
function RunHud.flashScreen(self: RunHud, color: Color3?)
	local now = os.clock()

	if now - self.lastFlashAt < FLASH_COOLDOWN_SECONDS then
		return
	end

	self.lastFlashAt = now
	self.screenFlash.BackgroundColor3 = color or Colors.White
	self.screenFlash.BackgroundTransparency = 0.88
	TweenService:Create(self.screenFlash, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	}):Play()
end

function RunHud.showFinal(self: RunHud, summary: any)
	self.gradeLabel.Text = ("RANK %s  ACC %d%%"):format(
		summary.rank or "?",
		math.floor((summary.accuracy or 0) * 100 + 0.5)
	)
	self.scoreLabel.Text = ("FINAL %d  MAX %d"):format(summary.score or 0, summary.maxCombo or 0)
	self.progressLabel.Text = "COMPLETE"
	self.goalTrack.Visible = summary.targetScore ~= nil

	if summary.targetScore == nil then
		return
	end

	local score = summary.score or 0

	self.goalFill.Size = UDim2.fromScale(if summary.goalPassed then 1 else math.clamp(score / summary.targetScore, 0, 1), 1)
	self.goalFill.BackgroundColor3 = if summary.goalPassed then Colors.Green else Color3.fromRGB(255, 92, 211)
	self.goalLabel.Text = ("%s %d/%d"):format(
		summary.goalLabel or "GOAL",
		math.min(score, summary.targetScore),
		summary.targetScore
	)
end

function RunHud.setPhotoMode(self: RunHud, active: boolean)
	if active then
		self.goalWasVisible = self.goalTrack.Visible
	end

	self.scoreLabel.Visible = not active
	self.progressLabel.Visible = not active
	self.gradeLabel.Visible = not active
	self.goalTrack.Visible = not active and self.goalWasVisible
	self.feverLabel.Visible = false
end

return RunHud
