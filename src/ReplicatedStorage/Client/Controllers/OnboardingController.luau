--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local OnboardingCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("OnboardingCatalog"))
local TutorialChart = require(Shared:WaitForChild("TutorialChart"))
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

-- Set by the loading screen (ReplicatedFirst) once it has faded out.
local LOADING_DONE_ATTRIBUTE = "LoadingDone"
local LOADING_WAIT_SECONDS = 60
local TICK_SECONDS = 0.25
local VERDICT_SECONDS = 2
local CHEER_SECONDS = 3.5
-- The server turns a drill down mid-match; the card gives up after this and the
-- lesson tries again a while later.
local START_WAIT_SECONDS = 8
local START_RETRY_SECONDS = 20

type Phase = "waiting" | "idle" | "drill" | "verdict" | "timing" | "firstSong" | "tip"

type Deps = {
	remotes: any,
	hud: any,
	run: any,
	lobby: any,
	hub: any,
	guide: any,
	calibration: any,
	sfx: any,
	vfx: any,
}

type Fields = {
	deps: Deps,
	phase: Phase,
	known: boolean,
	tutorialDone: boolean,
	drillsPassed: number,
	done: { [string]: boolean },
	stops: { [string]: Vector3 },
	profile: any,
	drill: number,
	tip: OnboardingCatalog.Tip?,
	firstSongOffered: boolean,
	retryAt: number,
	beatTimes: { number },
	taps: { number },
	tries: { [number]: boolean },
	tryTotal: number,
}

-- A first join, after the loading screen: the lesson's drills (TutorialChart),
-- each repeated until it lands, then a timing check, then the first real song;
-- after that each tip (OnboardingCatalog) once it is useful. Everything can be
-- skipped. The server keeps what is done and says so through OnboardingState.
local OnboardingController = {}
OnboardingController.__index = OnboardingController

export type OnboardingController = typeof(setmetatable({} :: Fields, OnboardingController))

function OnboardingController.new(deps: Deps): OnboardingController
	return setmetatable({
		deps = deps,
		phase = "waiting",
		known = false,
		tutorialDone = true,
		drillsPassed = 0,
		done = {},
		stops = {},
		profile = nil,
		drill = 0,
		tip = nil,
		firstSongOffered = false,
		retryAt = 0,
		beatTimes = {},
		taps = {},
		tries = {},
		tryTotal = 0,
	} :: Fields, OnboardingController)
end

function OnboardingController.start(self: OnboardingController)
	local deps = self.deps

	deps.run:bindTutorial({
		onDone = function(result)
			self:_onDrillDone(result)
		end,
		onStep = function(index, total, grade, reason)
			self:_onDrillStep(index, total, grade, reason)
		end,
	})
	deps.hud.tutorial:bindSkip(function()
		self:skip()
	end)
	deps.hud.tutorial:bindTap(function()
		self:tap()
	end)
	Remotes.listen(deps.remotes.OnboardingState, function(payload)
		self:_onState(payload)
	end)
	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		self.profile = payload
	end)

	task.spawn(function()
		local player = Players.LocalPlayer
		local deadline = os.clock() + LOADING_WAIT_SECONDS

		while player:GetAttribute(LOADING_DONE_ATTRIBUTE) ~= true and os.clock() < deadline do
			task.wait(TICK_SECONDS)
		end

		Telemetry.step("onboarding", "loaded")
		self.phase = "idle"

		while true do
			self:_tick()
			task.wait(TICK_SECONDS)
		end
	end)
end

function OnboardingController.isTimingCheck(self: OnboardingController): boolean
	return self.phase == "timing"
end

function OnboardingController._onState(self: OnboardingController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	self.known = true
	self.tutorialDone = payload.tutorialDone == true
	self.drillsPassed = tonumber(payload.drillsPassed) or 0
	self.done = if type(payload.done) == "table" then payload.done else {}
	self.stops = if type(payload.stops) == "table" then payload.stops else {}

	-- Left from the pause menu, the lesson is over with no result to show.
	local inLesson = self.phase == "drill" or self.phase == "verdict"

	if inLesson and self.tutorialDone and not self.deps.run:hasSession() then
		self.phase = "idle"
		self.deps.hud.tutorial:hide()
		self.deps.hud:setLessonFocus(false)
	end
end

-- Whether nothing else has the player's attention: no run, no results, no window.
function OnboardingController._free(self: OnboardingController): boolean
	local deps = self.deps

	return not deps.run:hasSession() and not deps.hud.windows:isOpen() and not deps.hud:isShowingResults()
end

function OnboardingController._tick(self: OnboardingController)
	-- A tip points at the windows, so only it stays over them.
	self.deps.hud.tutorial:setCovered(self.phase ~= "tip" and self.deps.hud.windows:isOpen())

	if self.phase == "tip" then
		self:_checkTip()
		return
	end

	if self.phase ~= "idle" or not self.known or not self:_free() then
		return
	end

	if not self.tutorialDone then
		if os.clock() >= self.retryAt then
			self:_startDrill(math.min(self.drillsPassed + 1, TutorialChart.DrillCount))
		end
	elseif not self.done[OnboardingCatalog.TimingCheck.id] then
		self:_startTimingCheck()
	elseif OnboardingCatalog.Enabled and not self.firstSongOffered and self:_songsCompleted() == 0 then
		self:_offerFirstSong()
	else
		self:_startTip()
	end
end

function OnboardingController._songsCompleted(self: OnboardingController): number
	local stats = if type(self.profile) == "table" then self.profile.stats else nil

	return if type(stats) == "table" then tonumber(stats.songsCompleted) or 0 else 0
end

function OnboardingController._startDrill(self: OnboardingController, drill: number)
	local spec = TutorialChart.Drills[drill]

	self.phase = "drill"
	self.drill = drill
	self.tryTotal = #TutorialChart.build(drill).steps
	table.clear(self.tries)
	self.deps.hud:setLessonFocus(true)
	self.deps.hud.tutorial:show({
		title = spec.title,
		text = spec.text,
		hint = spec.hint,
		progress = ("LESSON %d / %d"):format(drill, TutorialChart.DrillCount),
		low = true,
		demo = spec.kind,
		tries = { total = self.tryTotal, landed = self.tries },
	})
	self.deps.remotes.StartTutorial:FireServer({ drill = drill })

	task.delay(START_WAIT_SECONDS, function()
		if self.phase == "drill" and self.drill == drill and not self.deps.run:hasSession() then
			self.phase = "idle"
			self.retryAt = os.clock() + START_RETRY_SECONDS
			self.deps.hud.tutorial:hide()
			self.deps.hud:setLessonFocus(false)
			self.deps.run:resetToLobby()
		end
	end)
end

-- Each judged try lights its pip and calls it, and the demo gives way to the real thing.
function OnboardingController._onDrillStep(
	self: OnboardingController,
	index: number,
	total: number,
	grade: string,
	reason: string?
)
	if self.phase ~= "drill" then
		return
	end

	local tutorial = self.deps.hud.tutorial
	local spec = TutorialChart.Drills[self.drill]

	self.tryTotal = total
	self.tries[index] = grade ~= "Miss"
	tutorial:stopDemo()
	tutorial:setTries(total, self.tries)
	tutorial:setHint(TutorialChart.callout(spec.kind, grade, reason), grade ~= "Miss")
end

function OnboardingController._onDrillDone(self: OnboardingController, result: any)
	local deps = self.deps
	local drill = self.drill
	local passed = type(result) == "table" and result.passed == true
	local landed = if type(result) == "table" then tonumber(result.landed) or 0 else 0
	local total = if type(result) == "table" then tonumber(result.total) or 0 else 0

	self.phase = "verdict"

	if type(result) == "table" and result.tutorialDone == true then
		local gift = tonumber(result.gift) or 0

		deps.sfx:play("songComplete")
		deps.vfx:playConfetti()
		deps.hud.tutorial:show({
			title = "LESSON COMPLETE!",
			text = if gift > 0 then ("STARTER GIFT: +%d COINS"):format(gift) else "YOU KNOW EVERY MOVE",
			hint = "SPEND THEM ON A WAND IN THE SHOP",
			skippable = false,
		})
		self.tutorialDone = true

		task.delay(CHEER_SECONDS, function()
			deps.hud.tutorial:hide()
			deps.hud:setLessonFocus(false)
			deps.lobby:leaveStage()
			self.phase = "idle"
		end)

		return
	end

	local tries = { total = self.tryTotal, landed = self.tries }
	local nextDrill = TutorialChart.Drills[drill + 1]

	if type(result) ~= "table" then
		deps.hud.tutorial:show({ title = "ONE MORE TIME", text = TutorialChart.Drills[drill].text, low = true })
	elseif passed then
		deps.sfx:play("crowdPop")
		deps.hud.tutorial:show({
			title = if landed == total then "FLAWLESS!" else "NICE!",
			text = ("%d OF %d LANDED"):format(landed, total),
			hint = if nextDrill ~= nil then "NEXT: " .. nextDrill.title else "LAST ONE DONE",
			low = true,
			tries = tries,
		})
	else
		deps.hud.tutorial:show({
			title = "TRY AGAIN",
			text = ("%d OF %d LANDED - NEED %d"):format(landed, total, math.ceil(total * TutorialChart.PassShare)),
			hint = TutorialChart.Drills[drill].hint,
			demo = TutorialChart.Drills[drill].kind,
			low = true,
			tries = tries,
		})
	end

	task.delay(VERDICT_SECONDS, function()
		if self.phase ~= "verdict" then
			return
		end

		self:_startDrill(if passed then math.min(drill + 1, TutorialChart.DrillCount) else drill)
	end)
end

function OnboardingController._startTimingCheck(self: OnboardingController)
	local deps = self.deps
	local check = OnboardingCatalog.TimingCheck
	local beat = 60 / check.bpm
	local start = os.clock() + beat

	self.phase = "timing"
	table.clear(self.taps)
	table.clear(self.beatTimes)
	deps.hud.tutorial:show({
		title = check.title,
		text = check.text,
		hint = "SPACE, OR TAP THE YELLOW BUTTON",
		progress = "ALMOST READY",
	})
	deps.hud.tutorial:showTapPad(true)
	deps.hud.tutorial:setTapCount("LISTEN...")

	task.spawn(function()
		for index = 1, check.countIn + check.beats do
			local at = start + (index - 1) * beat
			local wait = at - os.clock()

			if wait > 0 then
				task.wait(wait)
			end

			if self.phase ~= "timing" then
				return
			end

			local counting = index <= check.countIn

			deps.sfx:play(if counting then "countdownTick" else "countdownGo")
			deps.hud.tutorial:pulseTap(counting)
			deps.hud.tutorial:setTapCount(
				if counting then tostring(check.countIn - index + 1) else ("%d / %d"):format(index - check.countIn, check.beats)
			)

			if not counting then
				table.insert(self.beatTimes, at)
			end
		end

		task.wait(beat)

		if self.phase == "timing" then
			self:_finishTimingCheck()
		end
	end)
end

function OnboardingController.tap(self: OnboardingController)
	if self.phase == "timing" then
		table.insert(self.taps, os.clock())
		self.deps.hud.tutorial:pulseTap(false)
	end
end

-- Each tap against its nearest beat; the median of the near ones is the offset.
function OnboardingController._finishTimingCheck(self: OnboardingController)
	local deps = self.deps
	local check = OnboardingCatalog.TimingCheck
	local errors = {}

	for _, tapAt in self.taps do
		local best: number? = nil

		for _, beatAt in self.beatTimes do
			local offset = tapAt - beatAt

			if best == nil or math.abs(offset) < math.abs(best) then
				best = offset
			end
		end

		if best ~= nil and math.abs(best) <= check.maxErrorSeconds then
			table.insert(errors, best)
		end
	end

	deps.hud.tutorial:showTapPad(false)

	if #errors < check.minTaps then
		self.phase = "verdict"
		deps.hud.tutorial:show({
			title = "ONE MORE TIME",
			text = "TAP ALONG WITH EVERY BEAT",
			hint = "THE BUTTON TURNS YELLOW ON THE BEAT",
		})

		task.delay(VERDICT_SECONDS, function()
			if self.phase == "verdict" then
				self:_startTimingCheck()
			end
		end)

		return
	end

	table.sort(errors)

	local middle = #errors // 2
	local median = if #errors % 2 == 1 then errors[middle + 1] else (errors[middle] + errors[middle + 1]) / 2
	local ms = math.floor(median * 1000 + 0.5)

	deps.calibration:setOffset(median)
	deps.remotes.CompleteOnboardingStep:FireServer({ step = check.id })
	self.done[check.id] = true
	self.phase = "verdict"
	deps.sfx:play("crowdPop")
	deps.hud.tutorial:show({
		title = "TIMING SET",
		text = if math.abs(ms) < 15 then "SPOT ON!" else ("YOUR TAPS LAND %d MS %s"):format(math.abs(ms), if ms > 0 then "LATE" else "EARLY"),
		hint = "THE GAME NOW JUDGES YOU WITH THAT IN MIND",
		skippable = false,
	})

	task.delay(VERDICT_SECONDS, function()
		if self.phase == "verdict" then
			deps.hud.tutorial:hide()
			self.phase = "idle"
		end
	end)
end

function OnboardingController._offerFirstSong(self: OnboardingController)
	local deps = self.deps
	local card = OnboardingCatalog.FirstSong

	self.phase = "firstSong"
	self.firstSongOffered = true
	deps.hud.tutorial:show({
		title = card.title,
		text = card.text,
		hint = "AN EASY ONE TO START",
		action = card.button,
		onAction = function()
			deps.hud.tutorial:hide()
			self.phase = "idle"
			deps.remotes.RequestSong:FireServer({ songId = TutorialChart.FirstSongId })
		end,
	})
end

function OnboardingController._triggered(self: OnboardingController, tip: OnboardingCatalog.Tip): boolean
	local profile = self.profile

	if type(profile) ~= "table" then
		return false
	end

	local owned = if type(profile.cosmetics) == "table" then profile.cosmetics else {}
	local coins = tonumber(profile.softCurrency) or 0

	if tip.trigger == "firstClear" then
		return self:_songsCompleted() > 0
	end

	for _, item in CosmeticsCatalog.Items do
		if item.unlock ~= "soft_currency" then
			continue
		end

		if tip.trigger == "firstPurchase" and owned[item.id] == true then
			return true
		elseif tip.trigger == "canAfford" and owned[item.id] ~= true and coins >= (item.price or math.huge) then
			return true
		end
	end

	return false
end

function OnboardingController._startTip(self: OnboardingController)
	local deps = self.deps

	-- Tips lead around the island, so they wait until the player is on it.
	if not deps.hub:isHub() or deps.hub:isOnStage() then
		return
	end

	for _, tip in OnboardingCatalog.Tips do
		if self.done[tip.id] or not self:_triggered(tip) then
			continue
		end

		self.phase = "tip"
		self.tip = tip
		deps.hud.tutorial:show({ title = tip.title, text = tip.text })

		local position = self.stops[tip.id]

		if position ~= nil then
			deps.guide:pointTo(position, tip.title)
		end

		if tip.button ~= nil then
			deps.hud.tutorial:highlight(deps.hud.menu:navButton(tip.button))
		end

		return
	end
end

function OnboardingController._checkTip(self: OnboardingController)
	local tip = self.tip

	if tip ~= nil and self.deps.hud.windows:isOpen(tip.window) then
		self:_finishTip()
	end
end

function OnboardingController._finishTip(self: OnboardingController)
	local tip = self.tip

	self.deps.guide:clear()
	self.deps.hud.tutorial:hide()
	self.phase = "idle"
	self.tip = nil

	if tip ~= nil then
		self.done[tip.id] = true
		self.deps.remotes.CompleteOnboardingStep:FireServer({ step = tip.id })
	end
end

function OnboardingController.skip(self: OnboardingController)
	local deps = self.deps
	local phase = self.phase

	if phase == "drill" or (phase == "verdict" and not self.tutorialDone) then
		self.phase = "idle"
		self.tutorialDone = true
		deps.hud.tutorial:hide()
		deps.hud:setLessonFocus(false)
		deps.remotes.SkipTutorial:FireServer({})
		deps.lobby:leaveStage()
	elseif phase == "timing" then
		self.phase = "idle"
		self.done[OnboardingCatalog.TimingCheck.id] = true
		deps.hud.tutorial:hide()
		deps.remotes.CompleteOnboardingStep:FireServer({ step = OnboardingCatalog.TimingCheck.id })
	elseif phase == "firstSong" then
		self.phase = "idle"
		deps.hud.tutorial:hide()
	elseif phase == "tip" then
		self:_finishTip()
	end
end

return OnboardingController
