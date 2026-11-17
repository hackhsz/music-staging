--!strict
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.Parent.UiKit)

local ROOT_NAME = "Result"
local POP_NAME = "Pop"

local SLASH_IN_SECONDS = 0.5
local SLASH_FROM = UDim2.fromScale(-0.6, 0)
local SLASH_TILT = -8
local BANNER_DELAY = 0.25
local COUNT_DELAY = 0.3
local COUNT_SECONDS = 1.1
local RANK_DELAY = 1.0
local RANK_FROM_SCALE = 3
local RANK_SPIN = -30
local RANK_SECONDS = 0.45
local STATS_DELAY = 1.15
local XP_DELAY = 1.3
local XP_FILL_SECONDS = 0.9
local XP_REFILL_SECONDS = 0.5
local GAINS_DELAY = 1.2
-- A tap this soon after the song ends is the player still dancing, not a skip.
local SKIP_GUARD_SECONDS = 0.4
local NO_XP_TEXT = "FINISH WITH 30% OR MORE FOR XP"
local BUTTONS_DELAY = 1.35
local BUTTON_STAGGER = 0.08
local BUTTON_RISE = 0.25
local POP_SECONDS = 0.35
-- After the reveal: the rank sways and the way on breathes, so the screen never sits dead.
local RANK_SWAY_DEGREES = 4
local RANK_SWAY_SPEED = 1.6
local NEXT_PULSE = 0.04
local NEXT_PULSE_SPEED = 3
local CLOSE_SECONDS = 0.3

type RevealStep = { run: () -> (), done: boolean }
type Later = (number, () -> ()) -> ()

type Fields = {
	root: GuiObject?,
	slash: GuiObject?,
	banner: GuiObject?,
	bannerLabel: TextLabel?,
	scoreLabel: TextLabel?,
	rankTag: TextLabel?,
	subLabel: TextLabel?,
	rankBadge: GuiObject?,
	rankLabel: TextLabel?,
	counts: GuiObject?,
	perfectLabel: TextLabel?,
	goodLabel: TextLabel?,
	missLabel: TextLabel?,
	comboPanel: GuiObject?,
	comboLabel: TextLabel?,
	accuracyPanel: GuiObject?,
	accuracyLabel: TextLabel?,
	xpFrame: GuiObject?,
	xpLabel: TextLabel?,
	xpBreakdown: TextLabel?,
	levelLabel: TextLabel?,
	levelMask: UIGradient?,
	gainPanel: GuiObject?,
	newBest: GuiObject?,
	newBestLabel: TextLabel?,
	coinsRow: GuiObject?,
	coinsLabel: TextLabel?,
	goalLabel: TextLabel?,
	crate: GuiObject?,
	nextButton: GuiButton?,
	replayButton: GuiButton?,
	backButton: GuiButton?,
	backLabel: TextLabel?,
	homes: { [GuiObject]: UDim2 },
	tilts: { [GuiObject]: number },
	counter: NumberValue,
	counterTween: Tween?,
	revealSteps: { RevealStep }?,
	revealStarted: number,
	finalScore: number,
	onRevealDone: (() -> ())?,
	showing: boolean,
	photoMode: boolean,
	backBound: boolean,
	revealToken: number,
	idle: RBXScriptConnection?,
	releaseHovers: { () -> () },
	nextHovered: boolean,
}

-- The run's results, drawn on the authored StarterGui.Derail.Result: score, rank,
-- grade counts, XP and the ways on. Everything is found by name, and a missing
-- piece is skipped rather than breaking the screen.
local ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

export type ResultsScreen = typeof(setmetatable({} :: Fields, ResultsScreen))

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	return (formatted:gsub("^,", ""))
end

local function find(root: Instance?, path: string, className: string): any
	if root == nil then
		return nil
	end

	local node: Instance? = root

	for _, name in string.split(path, ".") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end

	return if node ~= nil and node:IsA(className) then node else nil
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

local function pop(later: Later, gui: GuiObject?, delay: number, from: number?)
	if gui == nil then
		return
	end

	local scale = UiKit.scaleOf(gui, POP_NAME)
	scale.Scale = 0

	later(delay, function()
		scale.Scale = from or 0
		tween(scale, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

local function maskOffset(share: number): Vector2
	return Vector2.new(share - 0.5, 0)
end

local function shareOf(progress: any): number
	if progress.maxed == true then
		return 1
	end

	return math.clamp((tonumber(progress.into) or 0) / math.max(tonumber(progress.need) or 1, 1), 0, 1)
end

local function xpBreakdownText(summary: any, grade: string): string
	local parts = summary.xpParts

	if type(parts) ~= "table" or parts.finish == 0 then
		return NO_XP_TEXT
	end

	local text = ("BASE %d"):format(parts.finish)

	if parts.grade > 0 then
		text ..= ("  %s +%d"):format(grade, parts.grade)
	end

	if parts.payClass == "LOWER" then
		text ..= ("  OLDER STAGE 50%% = %d"):format(parts.scaled)
	end

	if parts.first > 0 then
		text ..= ("  FIRST +%d"):format(parts.first)
	end

	if parts.friend > 0 then
		text ..= ("  FRIEND +%d"):format(parts.friend)
	end

	return if parts.doubled then text .. "  X2 TODAY" else text
end

local function goalText(summary: any): string
	local goal = summary.nextGoal

	if type(goal) == "table" then
		local article = if goal.grade == "A" or goal.grade == "S" then "AN" else "A"

		return ("%d MORE PERFECT%s FOR %s %s"):format(goal.perfects, if goal.perfects == 1 then "" else "S", article, goal.grade)
	end

	local after = summary.rankAfter

	if type(after) ~= "table" or after.maxed == true then
		return ""
	end

	local challenger = if type(after.rankUp) == "table" then tostring(after.rankUp.challenger) else tostring(after.nextName)
	local challenge = summary.challenge

	if type(challenge) == "table" and challenge.beaten ~= true then
		return ("BEST %.2f / %.2f - RETRY %s"):format(tonumber(challenge.score) or 0, tonumber(challenge.target) or 0, challenger)
	end

	if after.ready == true then
		return ("CHALLENGE %s READY"):format(challenger)
	end

	return ("%d XP TO %s"):format((after.need or 0) - (after.into or 0), challenger)
end

function ResultsScreen.new(screen: ScreenGui?): ResultsScreen
	local root = UiKit.authored(screen, ROOT_NAME, "GuiObject")
	local scorePanel = "ResultPanel.ResultpanelPanel."

	local fields: Fields = {
		root = root,
		slash = find(root, "ResultPanel", "GuiObject"),
		banner = find(root, "ResultPanel.FullGrovePanel", "GuiObject"),
		bannerLabel = find(root, "ResultPanel.FullGrovePanel.FullGroveLabel", "TextLabel"),
		scoreLabel = find(root, scorePanel .. "ResultpanelpanelLabel", "TextLabel"),
		rankTag = find(root, scorePanel .. "SLabel", "TextLabel"),
		subLabel = find(root, scorePanel .. "AssistedRunLabel", "TextLabel"),
		rankBadge = find(root, "ResultPanel2", "GuiObject"),
		rankLabel = find(root, "ResultPanel2.SFrame.SLabel", "TextLabel"),
		counts = find(root, "PerfectPanel", "GuiObject"),
		perfectLabel = find(root, "PerfectPanel.PerfectLabel", "TextLabel"),
		goodLabel = find(root, "PerfectPanel.GoodLabel", "TextLabel"),
		missLabel = find(root, "PerfectPanel.MissLabel", "TextLabel"),
		comboPanel = find(root, "ResultPanel3", "GuiObject"),
		comboLabel = find(root, "ResultPanel3.StatLabel", "TextLabel"),
		accuracyPanel = find(root, "ResultPanel4", "GuiObject"),
		accuracyLabel = find(root, "ResultPanel4.StatLabel", "TextLabel"),
		xpFrame = find(root, "XpFrame", "GuiObject"),
		xpLabel = find(root, "XpFrame.XpLabel", "TextLabel"),
		xpBreakdown = find(root, "XpFrame.BaseRankSLabel", "TextLabel"),
		levelLabel = find(root, "XpFrame.XpframePanel.LvPanel.LvLabel", "TextLabel"),
		levelMask = find(root, "XpFrame.XpframePanel.LvPanel.UIGradient", "UIGradient"),
		gainPanel = find(root, "GainPanel", "GuiObject"),
		newBest = find(root, "GainPanel.NewBest", "GuiObject"),
		newBestLabel = find(root, "GainPanel.NewBest.NewBestLabel", "TextLabel"),
		coinsRow = find(root, "GainPanel.Coins", "GuiObject"),
		coinsLabel = find(root, "GainPanel.Coins.CoinsLabel", "TextLabel"),
		goalLabel = find(root, "GainPanel.GoalLabel", "TextLabel"),
		crate = find(root, "ResultCrateButton", "GuiObject"),
		nextButton = find(root, "NextSongButton", "GuiButton"),
		replayButton = find(root, "RetryButton", "GuiButton"),
		backButton = find(root, "HubButton", "GuiButton"),
		backLabel = find(root, "HubButton.HubLabel", "TextLabel"),
		homes = {},
		tilts = {},
		counter = Instance.new("NumberValue"),
		counterTween = nil,
		revealSteps = nil,
		revealStarted = 0,
		finalScore = 0,
		onRevealDone = nil,
		showing = false,
		photoMode = false,
		backBound = false,
		revealToken = 0,
		idle = nil,
		releaseHovers = {},
		nextHovered = false,
	}
	local self = setmetatable(fields, ResultsScreen)

	for _, gui in { fields.slash, fields.counts, fields.nextButton, fields.replayButton, fields.backButton, fields.rankBadge, fields.xpFrame } do
		if gui ~= nil then
			self.homes[gui] = gui.Position
			self.tilts[gui] = gui.Rotation
		end
	end

	for _, button in self:_buttons() do
		local onHover = if button == fields.nextButton
			then function(active: boolean)
				self.nextHovered = active
			end
			else nil

		table.insert(self.releaseHovers, UiKit.bindHover(button, onHover))
	end

	-- The old game's crates are not part of this one.
	if fields.crate ~= nil then
		fields.crate.Visible = false
	end

	if root ~= nil then
		root.Visible = false
	end

	if fields.backButton ~= nil then
		fields.backButton.Visible = false
	end

	fields.counter.Changed:Connect(function(value)
		if self.scoreLabel ~= nil then
			self.scoreLabel.Text = withCommas(value)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_skipReveal()
		end
	end)

	return self
end

-- The authored screen scales itself.
function ResultsScreen.applyLayout(_self: ResultsScreen, _isSmall: boolean) end

-- Runs once per results screen, when the reveal ends or the player skips it.
function ResultsScreen.bindRevealDone(self: ResultsScreen, callback: () -> ())
	self.onRevealDone = callback
end

function ResultsScreen.bindReplay(self: ResultsScreen, callback: () -> ())
	if self.replayButton ~= nil then
		self.replayButton.Activated:Connect(callback)
	end
end

function ResultsScreen.bindNext(self: ResultsScreen, callback: () -> ())
	if self.nextButton ~= nil then
		self.nextButton.Activated:Connect(callback)
	end
end

function ResultsScreen.setBackLabel(self: ResultsScreen, text: string)
	if self.backLabel ~= nil then
		self.backLabel.Text = text
	end
end

function ResultsScreen.bindBack(self: ResultsScreen, callback: () -> ())
	if self.backButton ~= nil then
		self.backButton.Activated:Connect(callback)
		self.backButton.Visible = true
	end

	self.backBound = true
end

function ResultsScreen.hasPhoto(self: ResultsScreen): boolean
	return self.showing
end

function ResultsScreen.hide(self: ResultsScreen)
	local onScreen = self.root ~= nil and self.root.Visible

	self.showing = false
	self.photoMode = false
	self.revealToken += 1
	self.revealSteps = nil
	self:_stopIdle()

	for _, release in self.releaseHovers do
		release()
	end

	if onScreen then
		self:_playClose()
	else
		self:_refresh()
	end
end

function ResultsScreen.setPhotoMode(self: ResultsScreen, active: boolean)
	self.photoMode = active
	self:_refresh()
end

function ResultsScreen.show(self: ResultsScreen, summary: any)
	local cleared = summary.cleared ~= false
	local rank = tostring(summary.rank or "?")
	local misses = summary.misses or 0
	local accuracy = math.floor((summary.accuracy or 0) * 1000 + 0.5) / 10
	local assisted = (summary.abilitiesUsed or 0) > 0

	self:_setText(self.bannerLabel, if not cleared then "STAGE FAILED" elseif misses == 0 then "FULL GROOVE" else "STAGE CLEAR")
	self:_setText(self.rankTag, rank)
	self:_setText(self.rankLabel, rank)
	self:_setText(self.subLabel, ("%s%.1f%% ACCURACY"):format(if assisted then "ASSISTED RUN  " else "", accuracy))
	self:_setText(self.perfectLabel, ("PERFECT %d"):format(summary.perfects or 0))
	self:_setText(self.goodLabel, ("GOOD %d"):format((summary.greats or 0) + (summary.goods or 0) + (summary.bads or 0)))
	self:_setText(self.missLabel, ("MISS %d"):format(misses))
	self:_setText(self.comboLabel, tostring(summary.maxCombo or 0))
	self:_setText(self.accuracyLabel, ("%.1f%%"):format(accuracy))

	self:_setText(self.xpLabel, ("+%d XP"):format(tonumber(summary.xpGained) or 0))
	self:_setText(self.xpBreakdown, xpBreakdownText(summary, rank))
	self:_setText(self.levelLabel, if type(summary.rankBefore) == "table" then tostring(summary.rankBefore.name) else "")
	self:_showGains(summary)

	self.showing = true
	self.photoMode = false
	self:_refresh()
	self:_reveal(summary)
end

function ResultsScreen._showGains(self: ResultsScreen, summary: any)
	local previous = tonumber(summary.previousBest)
	local coins = tonumber(summary.coinsGained) or 0

	if self.newBest ~= nil then
		self.newBest.Visible = summary.newBest == true
	end

	self:_setText(self.newBestLabel, if previous ~= nil then ("NEW BEST  WAS %s"):format(withCommas(previous)) else "NEW BEST")

	if self.coinsRow ~= nil then
		self.coinsRow.Visible = coins > 0
	end

	self:_setText(self.coinsLabel, ("+%s"):format(withCommas(coins)))
	self:_setText(self.goalLabel, goalText(summary))
end

function ResultsScreen._setText(_self: ResultsScreen, label: TextLabel?, text: string)
	if label ~= nil then
		label.Text = text
	end
end

-- Slash, banner, count, stamp, stats, XP, buttons: one beat after another, all
-- cancelled together if the screen closes early.
function ResultsScreen._reveal(self: ResultsScreen, summary: any)
	self.revealToken += 1

	local token = self.revealToken
	local steps: { RevealStep } = {}

	self.revealSteps = steps
	self.revealStarted = os.clock()

	local function later(delay: number, step: () -> ())
		local entry: RevealStep = { run = step, done = false }

		table.insert(steps, entry)
		task.delay(delay, function()
			if self.revealToken == token and self.showing and not entry.done then
				entry.done = true
				step()
			end
		end)
	end

	self:_stopIdle()

	local slash = self.slash

	if slash ~= nil then
		slash.Position = self.homes[slash] + SLASH_FROM
		slash.Rotation = self.tilts[slash] + SLASH_TILT
		tween(slash, SLASH_IN_SECONDS, { Position = self.homes[slash], Rotation = self.tilts[slash] }, Enum.EasingStyle.Back)
	end

	pop(later, self.banner, BANNER_DELAY, 1.4)

	self.counter.Value = 0
	self.finalScore = tonumber(summary.score) or 0
	later(COUNT_DELAY, function()
		local count = TweenService:Create(
			self.counter,
			TweenInfo.new(COUNT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = tonumber(summary.score) or 0 }
		)

		self.counterTween = count
		count:Play()
	end)

	local badge = self.rankBadge

	if badge ~= nil then
		local scale = UiKit.scaleOf(badge, POP_NAME)
		scale.Scale = 0

		later(RANK_DELAY, function()
			scale.Scale = RANK_FROM_SCALE
			badge.Rotation = self.tilts[badge] + RANK_SPIN
			tween(scale, RANK_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(badge, RANK_SECONDS, { Rotation = self.tilts[badge] }, Enum.EasingStyle.Back)
		end)
	end

	pop(later, self.rankTag, RANK_DELAY + 0.1, 2)

	local counts = self.counts

	if counts ~= nil then
		counts.Position = self.homes[counts] + UDim2.fromScale(0.5, 0)
		later(STATS_DELAY, function()
			tween(counts, POP_SECONDS, { Position = self.homes[counts] }, Enum.EasingStyle.Back)
		end)
	end

	pop(later, self.comboPanel, STATS_DELAY + 0.05)
	pop(later, self.accuracyPanel, STATS_DELAY + 0.12)
	pop(later, self.gainPanel, GAINS_DELAY)
	self:_fillXp(summary, later)

	-- A rank-up holds the buttons back, so Next can't skip past its card.
	local buttonsDelay = if summary.rankedUp == true then XP_DELAY + XP_FILL_SECONDS else BUTTONS_DELAY

	for index, button in self:_buttons() do
		local home: UDim2? = self.homes[button]

		if home ~= nil then
			button.Position = home + UDim2.fromScale(0, BUTTON_RISE)
			later(buttonsDelay + (index - 1) * BUTTON_STAGGER, function()
				tween(button, POP_SECONDS, { Position = home }, Enum.EasingStyle.Back)
			end)
		end
	end

	later(buttonsDelay + 0.4, function()
		self:_startIdle()
	end)

	later(XP_DELAY + XP_FILL_SECONDS, function()
		self.revealSteps = nil

		if self.onRevealDone ~= nil then
			self.onRevealDone()
		end
	end)
end

function ResultsScreen._skipReveal(self: ResultsScreen)
	local steps = self.revealSteps

	if steps == nil or not self.showing or os.clock() - self.revealStarted < SKIP_GUARD_SECONDS then
		return
	end

	self.revealSteps = nil

	if self.counterTween ~= nil then
		self.counterTween:Cancel()
	end

	for _, entry in steps do
		if not entry.done then
			entry.done = true
			entry.run()
		end
	end

	self.counter.Value = tonumber(self.finalScore) or self.counter.Value
end

-- The reveal played backwards and quicker; the screen only goes once it has.
function ResultsScreen._playClose(self: ResultsScreen)
	local token = self.revealToken
	local slash, counts = self.slash, self.counts

	if slash ~= nil then
		tween(slash, CLOSE_SECONDS, {
			Position = self.homes[slash] + SLASH_FROM,
			Rotation = self.tilts[slash] + SLASH_TILT,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end

	if counts ~= nil then
		tween(counts, CLOSE_SECONDS, { Position = self.homes[counts] + UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end

	for _, gui in { self.banner, self.rankBadge, self.rankTag, self.comboPanel, self.accuracyPanel, self.gainPanel } do
		if gui ~= nil then
			tween(UiKit.scaleOf(gui, POP_NAME), CLOSE_SECONDS, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
	end

	for _, button in self:_buttons() do
		local home: UDim2? = self.homes[button]

		if home ~= nil then
			tween(button, CLOSE_SECONDS, { Position = home + UDim2.fromScale(0, BUTTON_RISE) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
	end

	task.delay(CLOSE_SECONDS, function()
		if self.revealToken == token then
			self:_refresh()
		end
	end)
end

function ResultsScreen._buttons(self: ResultsScreen): { GuiButton }
	local buttons: { GuiButton } = {}

	for _, button in { self.backButton, self.replayButton, self.nextButton } do
		if button ~= nil then
			table.insert(buttons, button)
		end
	end

	return buttons
end

function ResultsScreen._fillXp(self: ResultsScreen, summary: any, later: Later)
	local mask = self.levelMask
	local before, after = summary.rankBefore, summary.rankAfter

	if mask == nil or type(before) ~= "table" or type(after) ~= "table" then
		return
	end

	local rankedUp = summary.rankedUp == true

	mask.Offset = maskOffset(shareOf(before))
	later(XP_DELAY, function()
		tween(mask, XP_FILL_SECONDS, { Offset = maskOffset(if rankedUp then 1 else shareOf(after)) })
	end)

	if rankedUp then
		later(XP_DELAY + XP_FILL_SECONDS, function()
			self:_setText(self.levelLabel, tostring(after.name))
			mask.Offset = maskOffset(0)
			tween(mask, XP_REFILL_SECONDS, { Offset = maskOffset(shareOf(after)) })
		end)
	end
end

function ResultsScreen._startIdle(self: ResultsScreen)
	local badge, nextButton = self.rankBadge, self.nextButton
	local started = os.clock()
	local nextScale = if nextButton ~= nil then UiKit.scaleOf(nextButton, POP_NAME) else nil

	self.idle = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started

		if badge ~= nil then
			badge.Rotation = self.tilts[badge] + RANK_SWAY_DEGREES * math.sin(t * RANK_SWAY_SPEED)
		end

		if nextScale ~= nil and not self.nextHovered then
			nextScale.Scale = 1 + NEXT_PULSE * math.sin(t * NEXT_PULSE_SPEED)
		end
	end)
end

function ResultsScreen._stopIdle(self: ResultsScreen)
	if self.idle ~= nil then
		self.idle:Disconnect()
		self.idle = nil
	end
end

function ResultsScreen._refresh(self: ResultsScreen)
	if self.root ~= nil then
		self.root.Visible = self.showing and not self.photoMode
	end
end

return ResultsScreen
