--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local CoreRules = require(Shared:WaitForChild("CoreRules"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))
local RhythmSession = require(Shared:WaitForChild("RhythmSession"))
local ScoreSummary = require(Shared:WaitForChild("ScoreSummary"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local SongSchema = require(Shared:WaitForChild("SongSchema"))
local Timing = require(Shared:WaitForChild("Timing"))
local StepMover = require(script.Parent.Parent.Input.StepMover)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)
local HUDController = require(script.Parent.Parent.UI.HUDController)
local UiKit = require(script.Parent.Parent.UI.UiKit)
local CalibrationController = require(script.Parent.CalibrationController)
local FloorController = require(script.Parent.FloorController)
local FloorEventController = require(script.Parent.FloorEventController)
local HighwayController = require(script.Parent.HighwayController)

local TELEGRAPH_MIN_LEAD_SECONDS = 0.9
local TELEGRAPH_LEAD_BEATS = 2
local HOLD_START_MIN_SETTLE_SECONDS = 0.08
local DEFAULT_COUNTDOWN_SECONDS = 3
-- A finished song rings out over the results; quitting fades it quickly.
local SONG_END_FADE_SECONDS = 3
local QUIT_FADE_SECONDS = 0.5
local HINT_SWAP_DELAY_SECONDS = 4
local MAX_APPROACH_MARKERS = 6
-- A frame stays on its tile this long after the beat, so a late press still
-- has something to aim at.
local APPROACH_LINGER_SECONDS = 0.08
-- onBeat on the 5x5 floor plays as a dance pad: tiles count down to their beat.
local PAD_LAYOUT_ID = "grid5"
local PAD_PREVIEW_LEAD_MULT = 1.5
local PATTERN_PATH_MAX_TILES = 12
-- A zone bigger than this is too much to read ahead, so nothing previews it.
local PREVIEW_MAX_ZONE_TILES = 4
local SAME_BEAT_SECONDS = 0.001
local DEFAULT_HOLD_SECONDS = 0.35
local PAD_PERFECT_FLASH = Color3.fromRGB(255, 214, 150)
local PUNCH_COMBO_FROM = 7
local MILESTONE_SHAKE_COMBO = 100
local DEFAULT_PAD_ENERGY = "calm"
local FEVER_PAD_ENERGY = "fever"
local STEP_HIT_GROUP = "Hihat"
local ITEM_FLASH = Color3.fromRGB(255, 220, 90)
local MAX_LANDINGS = 32
local MAX_CLAP_PRESSES = 16
local CLAP_HIT_GROUP = "Clap"
-- Like an osu! mapper's section volumes: hit sounds sit back in the calm parts.
local HIT_ENERGY_VOLUME = { calm = 0.6, build = 0.8, chorus = 1, drop = 1, fever = 1 }
-- osu! only plays the combo break past a real combo; losing a few is quiet.
local COMBO_BREAK_SOUND_FROM = 20
-- A combo is heard in the hits themselves: each layer joins every step's hit from
-- its combo on, so a long streak sounds like the player adding to the track.
local COMBO_HIT_LAYERS = {
	{ from = 25, group = "Tamb", volume = 0.55 },
	{ from = 50, group = "Drum", volume = 0.45 },
}
-- Between the milestone cheers the crowd answers every this many combo.
local CROWD_POP_EVERY = 10

local PAD_LEGEND = {
	{ "PINK", UiKit.Colors.Pink, "STEP" },
	{ "BLUE", UiKit.Colors.Cyan, "ANY" },
	{ "PURPLE", UiKit.Colors.Purple, "HOLD" },
	{ "YELLOW", UiKit.Colors.Yellow, "CLAP" },
	{ "RED", UiKit.Colors.Red, "AVOID" },
}
local BOARD_LEGEND = {
	{ "PURPLE", UiKit.Colors.Purple, "HOLD" },
	{ "BLUE", UiKit.Colors.Cyan, "SLIDE" },
	{ "GOLD", UiKit.Colors.Amber, "BONUS" },
	{ "RED", UiKit.Colors.Red, "DANGER" },
}
-- The charts whose floor draws a path from the dancer to the next target.
local ONBOARDING = {
	standWait = "WALK TO THE LIT TILE AND STAND STILL - THE BEAT LANDS ON YOU",
	arriveOnTime = "REACH THE LIT TILE JUST BEFORE THE BEAT",
	onBeat = "STEP ONTO THE LIT TILE ON THE BEAT - WHEN THE FRAME LANDS",
	pad = "LAND ON THE LIT TILE AS ITS COUNT HITS 0 - FOLLOW THE ARROW",
	highway = "HIT EACH ARROW AS IT LANDS ON ITS MATCH - YOUR DANCER DOES THE REST",
}

local HIGHWAY_HINTS: { [string]: string } = {
	keyboard = "W A S D  OR  ARROW KEYS",
	touch = "TAP THE ARROWS",
	gamepad = "D-PAD OR X A Y B",
}

local LAYOUT_HINTS: { [string]: { [string]: string } } = {
	pad3 = {
		keyboard = "PANELS: Q W E / A S D / Z X C  OR NUMPAD",
		touch = "TAP THE MATCHING PANEL",
		gamepad = "PANELS: LEFT STICK, A FOR THE CENTRE",
	},
	lanes4 = {
		keyboard = "LANES: D F J K  OR  ARROWS",
		touch = "TAP A LANE",
		gamepad = "LANES: D-PAD",
	},
}

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	boardView: any,
	stepMover: StepMover.StepMover,
	audio: any,
	vfx: any,
	sfx: any,
	avatar: any,
	calibration: CalibrationController.CalibrationController,
	floors: FloorController.FloorController,
	highway: HighwayController.HighwayController,
	deviceMode: any,
	camera: any?,
	dancer: any?,
	rival: any?,
	hub: any?,
}

type Fields = {
	deps: Deps,
	session: any,
	paused: boolean,
	pauseStartedAt: number?,
	pendingStepIndex: number?,
	previewedStepIndex: number?,
	shownPattern: number?,
	holdSubmitElapsed: number?,
	songDurationSeconds: number?,
	performanceGoal: any,
	firstHitTracked: boolean,
	firstMissTracked: boolean,
	lastCombo: number,
	predictedCombo: number,
	lastPredictedIndex: number,
	gradeCounts: { [string]: number },
	lastSyncBonus: number,
	lastBeatInt: number,
	isGuest: boolean,
	stageBeat: BindableEvent,
	coreMode: string,
	padMode: boolean,
	clappedStepIndex: number,
	landings: { CoreRules.Landing },
	clapPresses: { CoreRules.ClapPress },
	posedIndex: number,
	heldIndex: number,
	hold: HoldTrack?,
	rushInfo: { [number]: RushInfo },
	runAfter: { [any]: number },
	runFailed: { [any]: boolean },
	predictIndex: number,
	predicted: { [number]: string },
	beatCoords: { [number]: { x: number, y: number } | false },
	serverResolvedIndex: number,
	items: { any },
	itemIndex: number,
	collectedItems: { [number]: boolean },
	sections: any,
	padEnergy: string?,
	feverEndsAt: number,
	lastStepCoord: { x: number, y: number }?,
	rivalActive: boolean,
	floorEvents: FloorEventController.FloorEventController,
	tutorial: boolean,
	tutorialHooks: TutorialHooks?,
}

type TutorialHooks = {
	onDone: (result: any) -> (),
	onStep: (index: number, total: number, grade: string, reason: string?) -> (),
}

type RushInfo = {
	id: any,
	rushIndex: number,
	rushCount: number,
	tiles: { { x: number, y: number } },
	firstIndex: number,
	lastIndex: number,
}

type HoldTrack = {
	index: number,
	x: number,
	y: number,
	startAt: number,
	endAt: number,
	landed: boolean,
	beat: number,
}

type Guide = {
	clap: boolean,
	dx: number,
	dy: number,
	fill: number,
	beatsAway: number?,
	color: Color3?,
}

-- One run from countdown to results: the local session clock, the telegraph the
-- player reads, and the feedback for each verdict the server sends back. It
-- decides nothing; the server judges every step.
local RunController = {}
RunController.__index = RunController

export type RunController = typeof(setmetatable({} :: Fields, RunController))

local function legend(entries: { { any } }): string
	local parts = {}

	for _, entry in entries do
		table.insert(parts, UiKit.tint(entry[1], entry[2]) .. " " .. entry[3])
	end

	return table.concat(parts, "  ")
end

-- The dancer, the rival and the pad's newer effects are optional, so a missing
-- dep or method is skipped rather than taking the run down.
local function tryCall(target: any, method: string, ...: any)
	if target ~= nil and type(target[method]) == "function" then
		target[method](target, ...)
	end
end

function RunController.new(deps: Deps): RunController
	-- The lowpoly concert renderer subscribes to this and pulses the lights with
	-- the playing song.
	local stageBeat = Instance.new("BindableEvent")
	stageBeat.Name = "DanceDanceStepStageBeat"
	stageBeat.Parent = ReplicatedStorage

	local fields: Fields = {
		deps = deps,
		session = nil,
		paused = false,
		pauseStartedAt = nil,
		pendingStepIndex = nil,
		previewedStepIndex = nil,
		shownPattern = nil,
		holdSubmitElapsed = nil,
		songDurationSeconds = nil,
		performanceGoal = nil,
		firstHitTracked = false,
		firstMissTracked = false,
		lastCombo = 0,
		predictedCombo = 0,
		lastPredictedIndex = 0,
		gradeCounts = {},
		lastSyncBonus = 0,
		lastBeatInt = -1,
		isGuest = false,
		stageBeat = stageBeat,
		coreMode = CoreRules.Default,
		padMode = false,
		clappedStepIndex = 0,
		landings = {},
		clapPresses = {},
		posedIndex = 0,
		heldIndex = 0,
		hold = nil,
		rushInfo = {},
		runAfter = {},
		runFailed = {},
		predictIndex = 1,
		predicted = {},
		beatCoords = {},
		serverResolvedIndex = 0,
		items = {},
		itemIndex = 1,
		collectedItems = {},
		sections = nil,
		padEnergy = nil,
		feverEndsAt = 0,
		lastStepCoord = nil,
		rivalActive = false,
		floorEvents = FloorEventController.new({ boardView = deps.boardView, hud = deps.hud, sfx = deps.sfx }),
		tutorial = false,
		tutorialHooks = nil,
	}

	return setmetatable(fields, RunController)
end

function RunController.start(self: RunController)
	local deps = self.deps
	local remotes = deps.remotes

	-- The mover knows exactly when a step finished; the server only sees the
	-- replicated position, which lands 140-300 ms later. Report the landing on
	-- the shared server clock so a beat can be graded against it.
	deps.stepMover:setOnStepLanded(function(coord, landedAt, pressedAt)
		if not self:isRunning() then
			return
		end

		deps.boardView:dipTile(coord)

		-- Moving is silent, as in osu!: only a caught note makes a sound, and
		-- that one is laid on the beat, so nothing off the grid covers the song.
		if self.padMode then
			tryCall(deps.camera, "land", 1)
		end

		if self.coreMode == CoreRules.Modes.OnBeat then
			self:_recordLanding(coord, landedAt, pressedAt)
		end

		local session = self.session
		local toServer = Workspace:GetServerTimeNow() - os.clock()
		remotes.ReportArrival:FireServer({
			x = coord.x,
			y = coord.y,
			t = landedAt + toServer,
			p = pressedAt + toServer,
			s = session:toShared(landedAt, toServer) - (landedAt + toServer),
		})
	end)

	deps.boardView:setOnPlayerStep(function(coord)
		self:_onStepCommitted(coord)
	end)

	deps.hud:bindPauseToggle(function()
		self:togglePause()
	end)
	deps.hud.pause:bindRestart(function()
		self:requestReplay()
	end)
	deps.hud.results:bindReplay(function()
		self:requestReplay()
	end)

	remotes.StartSong.OnClientEvent:Connect(function(payload)
		self:_onStartSong(payload)
	end)
	remotes.HitResult.OnClientEvent:Connect(function(payload)
		self:_onHitResult(payload)
	end)

	local itemResult: RemoteEvent? = (remotes :: any).ItemResult

	if itemResult ~= nil then
		itemResult.OnClientEvent:Connect(function(payload)
			self:_onItemResult(payload)
		end)
	end
	remotes.SongComplete.OnClientEvent:Connect(function(payload)
		self:_onSongComplete(payload)
	end)
	remotes.PauseState.OnClientEvent:Connect(function(payload)
		self:_onPauseState(payload)
	end)
	remotes.MultiplayerStatus.OnClientEvent:Connect(function(payload)
		self:_onMultiplayerStatus(payload)
	end)
	remotes.EmoteApproved.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.emoteId) == "string" then
			-- Playing on the local Animator replicates the dance to everyone.
			deps.avatar:playLocalEmote(payload.emoteId)
		end
	end)

	RunService.RenderStepped:Connect(function()
		self:_tick(os.clock())
	end)
end

-- A lesson drill's result, for the onboarding.
function RunController.bindTutorial(self: RunController, hooks: TutorialHooks)
	self.tutorialHooks = hooks
end

function RunController.isRunning(self: RunController): boolean
	return self.session ~= nil and not self.session:isFinished()
end

-- Still on a run, its steps done or not, until the results or a leave clear it.
function RunController.hasSession(self: RunController): boolean
	return self.session ~= nil
end

function RunController.getBeatSeconds(self: RunController): number
	return self:_beatSeconds()
end

-- The server's meters after an instant ability, between verdicts.
function RunController.applyMeters(self: RunController, meters: any)
	if self.session == nil or type(meters) ~= "table" then
		return
	end

	local hud = self.deps.hud
	local score = tonumber(meters.score) or 0
	hud.run:updateScore(score, tonumber(meters.combo) or 0, tonumber(meters.hype) or 0)
	hud.run:updateLife(meters.life, meters.maxLife)
	hud.run:updatePerformanceGoal(score, self.performanceGoal)
	hud.run:updateFever(meters.fever)
	hud.songBar:setFever(meters.fever)
end

-- The CLAP press: the server judges it against the chart's claps by its time on
-- the shared clock, exactly as a landing report is timed.
function RunController.clap(self: RunController)
	local session = self.session

	if session == nil or not self.padMode or self.paused or session:isFinished() then
		return
	end

	local deps = self.deps
	local now = os.clock()
	local toServer = Workspace:GetServerTimeNow() - now
	local submitClap: RemoteEvent? = (deps.remotes :: any).SubmitClap

	if submitClap ~= nil then
		submitClap:FireServer({
			t = now + toServer,
			s = session:toShared(now, toServer) - (now + toServer),
		})
	end

	table.insert(self.clapPresses, {
		at = session:getElapsed(now) - deps.calibration:getOffsetSeconds(),
		used = false,
	})

	if #self.clapPresses > MAX_CLAP_PRESSES then
		table.remove(self.clapPresses, 1)
	end

	self:_clapFeedback(self.clapPresses[#self.clapPresses].at)
	deps.hud.pad:flashClap()
	tryCall(deps.dancer, "padClap")
end

function RunController.togglePause(self: RunController)
	if self:isRunning() then
		self.deps.remotes.RequestPause:FireServer({ paused = not self.paused })
	end
end

function RunController.requestReplay(self: RunController)
	-- In a match the host restarts the song for both players.
	if self.isGuest then
		self.deps.hud.hints:setHint("ASK PLAYER 1 TO RESTART THE SONG")
		return
	end

	self.deps.hud.hints:setHint("RESTARTING...")
	self.deps.hud:hideResults()
	Telemetry.track("replay_requested")
	self.deps.remotes.RequestRestart:FireServer()
end

-- Back to a clean slate with no run in progress.
function RunController.resetToLobby(self: RunController)
	local deps = self.deps

	self.session = nil
	self.tutorial = false
	self.paused = false
	self.pauseStartedAt = nil
	deps.hud.pause:setPaused(false)
	deps.hud.tutorial:setPaused(false)
	deps.highway:stop()
	deps.boardView:setApproachMarkers({})
	self.padMode = false
	self.floorEvents:stop()
	deps.boardView:setPadLook(false)
	deps.hud.pad:setClapEnabled(false)
	deps.floors:reset()
	deps.stepMover:clearQueue()
	deps.audio:fadeOut(QUIT_FADE_SECONDS)
	self:_stopPadExtras()
	tryCall(deps.camera, "setResults", false)
	deps.hud:setRunActive(false)
	deps.hud:applyDeviceLayout()
	deps.hud.run:updateScore(0, 0, 0)
	deps.hud.run:updateProgress(0, nil)
	deps.hud.run:updatePerformanceGoal(0, nil)
	deps.hud.run:updateFever(nil)
end

function RunController._beatSeconds(self: RunController): number
	local session = self.session

	return Timing.beatSeconds(if session ~= nil then session.map.bpm else nil)
end

function RunController._telegraphLeadSeconds(self: RunController): number
	local session = self.session
	local bpm = if session ~= nil then tonumber(session.map.bpm) else nil
	local beatSeconds = Timing.beatSeconds(bpm)

	-- Telegraph the target a full travel window ahead so the player can walk
	-- there and stand, instead of reacting on the beat.
	local leadBeats = TELEGRAPH_LEAD_BEATS

	if session ~= nil then
		leadBeats = math.max(leadBeats, Timing.getTravelWindowBeats(session.map.difficulty))
	end

	return math.max(leadBeats * beatSeconds, TELEGRAPH_MIN_LEAD_SECONDS)
end

function RunController._submitHit(self: RunController)
	local session = self.session

	if session == nil then
		return
	end

	-- A submission is already in flight for the current (or a later) step; never
	-- double-submit the same step index.
	if self.pendingStepIndex ~= nil and self.pendingStepIndex >= session.nextStepIndex then
		return
	end

	-- Set the guard synchronously before FireServer so re-entrant events in the
	-- same frame cannot race a second submission through.
	self.pendingStepIndex = session.nextStepIndex

	local step = session:getCurrentStep()

	if step ~= nil and step.type == "hold" then
		-- Drives the optimistic hold-progress visual until the server finalizes
		-- the hold with a HitResult.
		self.holdSubmitElapsed = session:getElapsed(os.clock())
	end

	self.deps.remotes.SubmitHit:FireServer({
		stepIndex = self.pendingStepIndex,
		clientHitTime = os.clock(),
	})
end

-- Holds and slides start by themselves: standing on the tile when the beat lands
-- is the input, the same as for plain steps.
function RunController._tryStartInputStep(self: RunController, step: any, targetTime: number, elapsed: number, now: number)
	if step.type ~= "hold" and step.type ~= "slide" then
		return
	end

	local stepMover = self.deps.stepMover
	local coord = stepMover:getCoord()

	if coord == nil or coord.x ~= step.x or coord.y ~= step.y then
		return
	end

	if stepMover:getSettleSeconds(now) < HOLD_START_MIN_SETTLE_SECONDS then
		return
	end

	-- The server grades the packet's arrival time, so send it one network hop early.
	local calibrated = elapsed - self.deps.calibration:getOffsetSeconds() + Players.LocalPlayer:GetNetworkPing()

	if calibrated >= targetTime and calibrated <= targetTime + Timing.BadWindow then
		self:_submitHit()
	end
end

-- In the press-judged modes the verdict trails the beat by a network trip, and a
-- dense chart puts the next note inside that gap, so the telegraph moves on as
-- soon as a note's press window has closed instead of waiting for the server.
-- The highway judges every note by its press; onBeat only its plain steps.
function RunController._skipClosedSteps(self: RunController, elapsed: number, everyType: boolean)
	local session = self.session
	local difficulty = session.map.difficulty
	local closesAfter = if everyType then Timing.getWindows(difficulty).goodWindow else Timing.OnBeatLateGrace

	while true do
		local step = session:getCurrentStep()
		local targetTime = session:getCurrentStepTargetTime()

		if step == nil or targetTime == nil then
			return
		end

		local runDeadline = self:_runDeadline(session.nextStepIndex)

		if runDeadline ~= nil then
			if self.predicted[session.nextStepIndex] == nil and elapsed < runDeadline then
				return
			end

			session:advance()
			continue
		end

		local skippable = step.type == nil
			or step.type == "tap"
			or step.type == "bonus"
			or step.type == "freeze"
			or SongSchema.isShape(step)
			or SongSchema.isRush(step)
			or SongSchema.isClap(step)
			or SongSchema.isPose(step)

		if not everyType and not skippable then
			return
		end

		local poseSeconds = SongSchema.poseBeatsOf(step) * self:_beatSeconds()

		if elapsed < targetTime + poseSeconds + closesAfter then
			return
		end

		session:advance()
	end
end

function RunController._updateApproachMarkers(self: RunController, elapsed: number, leadSeconds: number)
	local session = self.session
	local markers = {}
	local index = session.nextStepIndex

	while #markers < MAX_APPROACH_MARKERS do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		local untilBeat = session:getStepTargetTime(step) - elapsed

		if untilBeat > leadSeconds then
			break
		end

		if untilBeat >= -APPROACH_LINGER_SECONDS then
			table.insert(markers, {
				x = step.x,
				y = step.y,
				progress = 1 - untilBeat / leadSeconds,
				kind = step.type or "tap",
			})
		end

		index += 1
	end

	self.deps.boardView:setApproachMarkers(markers)
end

-- The tile the step guide and the floor arrow point at: the nearest tile of a
-- zone, the next tile along a slide's path, or the step's own tile.
local function guideTarget(step: any, coord: { x: number, y: number }): { x: number, y: number }
	local zone = SongSchema.zoneOf(step)

	if zone ~= nil then
		return Board.nearestTile(zone, coord)
	end

	local path = step.path

	if step.type ~= "slide" or type(path) ~= "table" or #path == 0 or (coord.x == step.x and coord.y == step.y) then
		return step
	end

	for index = 1, #path - 1 do
		if path[index].x == coord.x and path[index].y == coord.y then
			return path[index + 1]
		end
	end

	return path[1]
end

function RunController._padKind(self: RunController, index: number, step: any): string
	if step.type == "danger" or step.type == "hold" then
		return step.type
	end

	if SongSchema.isPose(step) or SongSchema.isClap(step) or SongSchema.isRush(step) then
		return step.type
	end

	if step.type == "slide" then
		return "slide"
	end

	if SongSchema.zoneOf(step) ~= nil then
		return "shape"
	end

	local session = self.session
	local targetTime = session:getStepTargetTime(step)

	for _, otherIndex in { index - 1, index + 1 } do
		local other = session:getStep(otherIndex)

		if other ~= nil and math.abs(session:getStepTargetTime(other) - targetTime) < SAME_BEAT_SECONDS then
			return "shape"
		end
	end

	return "single"
end

-- How many beats a note's fill takes: from the beat before it, the moment it
-- becomes the next note, to its own beat. After a hold it starts when the hold
-- ends; a clap on one of the hold's beats fills from the hold's start.
function RunController._fillSpan(self: RunController, index: number, beatSeconds: number, lead: number): number
	local session = self.session
	local targetTime = session:getStepTargetTime(session:getStep(index))
	local cap = lead * PAD_PREVIEW_LEAD_MULT

	for previousIndex = index - 1, 1, -1 do
		local previous = session:getStep(previousIndex)
		local previousTime = session:getStepTargetTime(previous)

		if previous.type ~= "danger" and targetTime - previousTime > SAME_BEAT_SECONDS then
			local holdEnd = previousTime + (tonumber(previous.holdSeconds) or DEFAULT_HOLD_SECONDS)
			local freeFrom = if previous.type == "hold" and targetTime >= holdEnd then holdEnd else previousTime

			return math.min(math.max(targetTime - freeFrom, SAME_BEAT_SECONDS) / beatSeconds, cap)
		end
	end

	return cap
end

-- The on-screen key for the next note: the step key toward its tile (both keys
-- of a diagonal where the floor has them, else the long way first), or the CLAP key for a clap; it fills in the note's colour with the
-- same level as its tile. A pose or hold guides nothing until it has been held to the end.
function RunController._nextGuide(self: RunController, elapsed: number, beatSeconds: number): Guide?
	local session = self.session
	local coord = self.deps.stepMover:getCoord()
	local lead = Timing.getTravelWindowBeats(session.map.difficulty)
	local index = session.nextStepIndex

	while coord ~= nil do
		local step = session:getStep(index)

		if step == nil then
			return nil
		end

		local beatsAway = (session:getStepTargetTime(step) - elapsed) / beatSeconds

		if beatsAway > lead then
			return nil
		end

		local pending = self.predicted[index] == nil
		local runDeadline = self:_runDeadline(index)
		local running = runDeadline ~= nil and elapsed < runDeadline

		local heldBeats = if step.type == "hold"
			then (tonumber(step.holdSeconds) or DEFAULT_HOLD_SECONDS) / beatSeconds
			else SongSchema.poseBeatsOf(step)

		if pending and heldBeats > 0 and beatsAway <= 0 and beatsAway > -heldBeats then
			return if step.type == "hold" then self:_clapGuideInHold(index, elapsed, beatSeconds, lead) else nil
		end

		if step.type ~= "danger" and pending and (beatsAway > 0 or running) then
			-- A memory step is the player's to remember and a freeze is to stand still.
			if step.hidden == true or SongSchema.isFreeze(step) then
				return nil
			end

			local fill = if running
				then 1
				else 1 - math.clamp(beatsAway / self:_fillSpan(index, beatSeconds, lead), 0, 1)

			if SongSchema.isClap(step) then
				return { clap = true, dx = 0, dy = 0, fill = fill, beatsAway = beatsAway }
			end

			local target = guideTarget(step, coord)
			local dx, dy = target.x - coord.x, target.y - coord.y

			if dx == 0 and dy == 0 then
				return nil
			end

			if dx ~= 0 and dy ~= 0 and Board.isLegalMove(1, 1) then
				dx, dy = if dx > 0 then 1 else -1, if dy > 0 then 1 else -1
			elseif math.abs(dx) >= math.abs(dy) then
				dx, dy = if dx > 0 then 1 else -1, 0
			else
				dx, dy = 0, if dy > 0 then 1 else -1
			end

			local color = self.deps.boardView:padKindColor(self:_padKind(index, step))
			local guideBeats = if running then nil else beatsAway

			return { clap = false, dx = dx, dy = dy, fill = fill, beatsAway = guideBeats, color = color }
		end

		index += 1
	end

	return nil
end

-- Standing on a hold, the only key to light is CLAP for a clap still to come.
function RunController._clapGuideInHold(
	self: RunController,
	holdIndex: number,
	elapsed: number,
	beatSeconds: number,
	lead: number
): Guide?
	local session = self.session
	local index = holdIndex + 1

	while true do
		local step = session:getStep(index)

		if step == nil or not SongSchema.isClap(step) then
			return nil
		end

		local beatsAway = (session:getStepTargetTime(step) - elapsed) / beatSeconds

		if beatsAway > lead then
			return nil
		end

		if self.predicted[index] == nil and beatsAway > 0 then
			local fill = 1 - math.clamp(beatsAway / self:_fillSpan(index, beatSeconds, lead), 0, 1)
			return { clap = true, dx = 0, dy = 0, fill = fill, beatsAway = beatsAway }
		end

		index += 1
	end
end

function RunController._updateStepGuide(self: RunController, elapsed: number, beatSeconds: number)
	local pad = self.deps.hud.pad
	local guide = self:_nextGuide(elapsed, beatSeconds)

	if guide == nil then
		pad:setGuide(nil, nil, 0)
		pad:setClapGuide(nil)
	elseif guide.clap then
		pad:setGuide(nil, nil, 0)
		pad:setClapGuide(guide.fill, guide.beatsAway)
	else
		pad:setGuide(guide.dx, guide.dy, guide.fill, guide.beatsAway, guide.color)
		pad:setClapGuide(nil)
	end
end

-- Groups each rush's steps once per run, so a telegraph can carry the whole path.
function RunController._indexRushes(self: RunController, session: any)
	local rushInfo = self.rushInfo
	local groups: { [any]: { number } } = {}
	local order: { any } = {}
	local index = 1

	table.clear(rushInfo)

	while true do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		if SongSchema.isRush(step) and step.rush ~= nil then
			if groups[step.rush] == nil then
				groups[step.rush] = {}
				table.insert(order, step.rush)
			end

			table.insert(groups[step.rush], index)
		end

		index += 1
	end

	for _, id in order do
		local indices = groups[id]
		local tiles = {}

		for _, stepIndex in indices do
			local step = session:getStep(stepIndex)
			table.insert(tiles, { x = step.x, y = step.y })
		end

		for rushIndex, stepIndex in indices do
			rushInfo[stepIndex] = {
				id = id,
				rushIndex = rushIndex,
				rushCount = #indices,
				tiles = tiles,
				firstIndex = indices[1],
				lastIndex = indices[#indices],
			}
		end
	end
end

-- Every rush tile after the first is a run tile, open until the run's deadline.
function RunController._runDeadline(self: RunController, index: number): number?
	local rush = self.rushInfo[index]

	if rush == nil or rush.rushIndex == 1 then
		return nil
	end

	local session = self.session
	return CoreRules.runDeadline(session:getStepTargetTime(session:getStep(rush.lastIndex)))
end

-- How much of a started run's time is left, from 1 on its first beat to 0 at its deadline.
function RunController._runLeft(self: RunController, index: number, elapsed: number): number?
	local rush = self.rushInfo[index]

	if rush == nil then
		return nil
	end

	local session = self.session
	local startAt = session:getStepTargetTime(session:getStep(rush.firstIndex))
	local deadline = CoreRules.runDeadline(session:getStepTargetTime(session:getStep(rush.lastIndex)))

	if elapsed < startAt or elapsed >= deadline then
		return nil
	end

	return (deadline - elapsed) / (deadline - startAt)
end

function RunController._runAfterAt(self: RunController, index: number): number
	local rush = self.rushInfo[index]
	local session = self.session
	return self.runAfter[rush.id] or session:getStepTargetTime(session:getStep(rush.firstIndex))
end

-- The tiles still to come in the pattern a note belongs to, however far ahead,
-- so the pad can draw the whole shape instead of only the next note.
function RunController._patternPath(self: RunController, index: number): { { x: number, y: number } }?
	local session = self.session
	local group = session:getStep(index).pattern

	if group == nil then
		return nil
	end

	local tiles = {}
	local nextIndex = index + 1

	while #tiles < PATTERN_PATH_MAX_TILES do
		local step = session:getStep(nextIndex)

		if step == nil then
			break
		end

		if step.type ~= "danger" and step.type ~= "item" then
			local zone = SongSchema.zoneOf(step)

			if step.pattern ~= group or (zone ~= nil and #zone > PREVIEW_MAX_ZONE_TILES) then
				break
			end

			for _, tile in zone or { step } do
				table.insert(tiles, { x = tile.x, y = tile.y })
			end
		end

		nextIndex += 1
	end

	return if #tiles > 0 then tiles else nil
end

-- Studio only: names each pattern in the output as it becomes the one to play.
function RunController._logPattern(self: RunController)
	local step = self.session:getCurrentStep()

	if step == nil or step.pattern == nil or step.pattern == self.shownPattern then
		return
	end

	self.shownPattern = step.pattern

	if RunService:IsStudio() then
		print(("[DanceDanceStep] pattern %s (#%d) from beat %.2f"):format(tostring(step.pid), step.pattern, step.beat))
	end
end

function RunController._padTelegraphs(self: RunController, elapsed: number, beatSeconds: number): { any }
	local session = self.session
	self:_logPattern()
	local lead = Timing.getTravelWindowBeats(session.map.difficulty)
	local telegraphs = {}
	local index = session.nextStepIndex

	while true do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		local beatsAway = (session:getStepTargetTime(step) - elapsed) / beatSeconds

		if beatsAway > lead * PAD_PREVIEW_LEAD_MULT then
			break
		end

		-- A run tile is done the moment it is reached, a network trip before the
		-- server's verdict moves the cursor past it.
		local ranAlready = self.rushInfo[index] ~= nil and self.predicted[index] ~= nil

		if not SongSchema.isFreeze(step) and not ranAlready then
			local poseBeats = SongSchema.poseBeatsOf(step)

			table.insert(telegraphs, {
				x = step.x,
				y = step.y,
				beatsAway = beatsAway,
				lead = lead,
				kind = self:_padKind(index, step),
				span = if step.type == "danger" then lead else self:_fillSpan(index, beatSeconds, lead),
				path = if step.type == "slide" then step.path else nil,
				hidden = if step.hidden == true then true else nil,
				tiles = SongSchema.zoneOf(step),
				holdBeats = if step.type == "hold"
					then (tonumber(step.holdSeconds) or DEFAULT_HOLD_SECONDS) / beatSeconds
					else nil,
				poseBeats = if poseBeats > 0 then poseBeats else nil,
				progress = if poseBeats > 0 then math.clamp(-beatsAway / poseBeats, 0, 1) else nil,
				runLeft = self:_runLeft(index, elapsed),
				patternPath = self:_patternPath(index),
				index = index,
			})
		end

		index += 1
	end

	-- Items go last so a pickup never paints over a live note's tile.
	for itemIndex = self.itemIndex, #self.items do
		local item = self.items[itemIndex]
		local beatsAway = (session:getStepTargetTime(item) - elapsed) / beatSeconds

		if beatsAway > lead * PAD_PREVIEW_LEAD_MULT then
			break
		end

		table.insert(telegraphs, {
			x = item.x,
			y = item.y,
			beatsAway = beatsAway,
			lead = lead,
			kind = "item",
			span = lead,
		})
	end

	return telegraphs
end

-- The hit sound plays the instant a step is committed onto a live target, so
-- the player hears their own timing; the grade still comes from the server.
function RunController._onStepCommitted(self: RunController, coord: { x: number, y: number })
	local previous = self.lastStepCoord or Board.centerCoord()
	self.lastStepCoord = { x = coord.x, y = coord.y }

	if not self.padMode or self.paused or not self:isRunning() then
		return
	end

	local grade, step = self:_clapTarget(coord)
	local kind = if step == nil
		then nil
		elseif SongSchema.isRush(step) then "rush"
		elseif SongSchema.zoneOf(step) ~= nil then "shape"
		else nil
	tryCall(self.deps.dancer, "padStep", coord.x - previous.x, coord.y - previous.y, grade, kind)
end

local function isClapTarget(step: any, coord: { x: number, y: number }): boolean
	if
		step.type == "danger"
		or SongSchema.isFreeze(step)
		or SongSchema.isPose(step)
		or SongSchema.isClap(step)
	then
		return false
	end

	local tiles: { any } = SongSchema.zoneOf(step) or { step }

	for _, tile in tiles do
		if tile.x == coord.x and tile.y == coord.y then
			return true
		end
	end

	return false
end

-- Claps the live target this step lands on and returns the grade its press is
-- heading for and the step, or nil when the step is onto no target.
function RunController._clapTarget(self: RunController, coord: { x: number, y: number }): (string?, any)
	local session = self.session
	local difficulty = session.map.difficulty
	local offset = self.deps.calibration:getOffsetSeconds()
	local elapsed = session:getElapsed(os.clock()) - offset
	local leadSeconds = Timing.getTravelWindowBeats(difficulty) * self:_beatSeconds()
	local index = math.max(session.nextStepIndex, self.clappedStepIndex + 1)

	while true do
		local step = session:getStep(index)

		if step == nil then
			return nil
		end

		local untilBeat = session:getStepTargetTime(step) - elapsed

		if untilBeat > leadSeconds then
			return nil
		end

		local runTile = self:_runDeadline(index) ~= nil

		if isClapTarget(step, coord) and (runTile or untilBeat >= -Timing.OnBeatLateGrace) then
			-- A step ticks a soft hi-hat; the clap sound is kept for clap notes.
			self.clappedStepIndex = index

			if runTile then
				self:_playHit(STEP_HIT_GROUP)
				return CoreRules.gradeRunTile(true), step
			end

			local pressOffset = -untilBeat

			if pressOffset < 0 and not CoreRules.isTimedPress(pressOffset, difficulty) then
				self:_hitOnBeat(coord, math.max(untilBeat - offset, 0))
			else
				self:_playHit(STEP_HIT_GROUP)
			end

			return CoreRules.gradeOnBeatPress(pressOffset, difficulty), step
		end

		index += 1
	end
end

-- An early arrival's hi-hat waits for the beat, so the hits laid over the song
-- stay on its grid however early the player walks there.
function RunController._hitOnBeat(self: RunController, coord: { x: number, y: number }, delaySeconds: number)
	local session = self.session

	task.delay(delaySeconds, function()
		local standing = self.deps.stepMover:getCoord()

		if self.session ~= session or self.paused or standing == nil or standing.x ~= coord.x or standing.y ~= coord.y then
			return
		end

		self:_playHit(STEP_HIT_GROUP)
	end)
end

function RunController._playHit(self: RunController, group: string)
	local scale = HIT_ENERGY_VOLUME[self.padEnergy] or 1
	self.deps.sfx:playHit(group, scale)

	if group ~= STEP_HIT_GROUP then
		return
	end

	for _, layer in COMBO_HIT_LAYERS do
		if self.lastCombo >= layer.from then
			self.deps.sfx:playHit(layer.group, scale * layer.volume)
		end
	end
end

function RunController._settleProgress(self: RunController, step: any, beatSeconds: number, now: number): number
	local stepMover = self.deps.stepMover
	local coord = stepMover:getCoord()

	if coord == nil or coord.x ~= step.x or coord.y ~= step.y then
		return 0
	end

	return stepMover:getSettleSeconds(now) / (Timing.StandPerfectBeatFraction * beatSeconds)
end

function RunController._tick(self: RunController, now: number)
	local session = self.session

	if session == nil or self.paused then
		return
	end

	local deps = self.deps
	local boardView = deps.boardView
	local playhead = deps.audio:getPlayhead(now)

	if playhead ~= nil and session:followPlayhead(now, playhead) ~= 0 then
		deps.audio:seek(session:getElapsed(now))
	end

	if session:isFinished() then
		boardView:setApproachMarkers({})
		boardView:renderPad(now, {})
		return
	end

	local bpm = tonumber(session.map.bpm) or 120
	local beatSeconds = Timing.beatSeconds(bpm)
	-- Sounds run on the music's own clock, since they reach the speakers with it.
	-- What is drawn runs on the judged clock, the music shifted by the player's
	-- offset, so the floor shows a beat exactly when the judge expects the press.
	local elapsed = session:getElapsed(now)
	local chartElapsed = elapsed - deps.calibration:getOffsetSeconds()
	local beats = math.max(chartElapsed, 0) / beatSeconds
	local beatInt = math.floor(beats)

	self.stageBeat:Fire(beats % 1, beatInt)

	if beatInt ~= self.lastBeatInt then
		self.lastBeatInt = beatInt
		boardView:pulseBeat()

		if self.padMode then
			tryCall(boardView, "padBeat", beatInt, beatSeconds)
		end
	end

	if self.padMode then
		self:_cuePose(chartElapsed, beatSeconds)
		self:_trackHold(chartElapsed, beatSeconds)
	end

	local onBeat = self.coreMode == CoreRules.Modes.OnBeat
	local highway = self.coreMode == CoreRules.Modes.Highway

	if onBeat or highway then
		self:_skipClosedSteps(chartElapsed, highway)
	end

	-- In the highway the floor is only the stage: nothing is telegraphed on it.
	if highway then
		deps.highway:update(elapsed)
		deps.hud.run:groove(beats, deps.audio:getLoudness())
		deps.hud.songBar:update(chartElapsed, self.songDurationSeconds, beats)
		return
	end

	if self.padMode then
		deps.hud.run:groove(beats, deps.audio:getLoudness())
		deps.hud.songBar:update(chartElapsed, self.songDurationSeconds, beats)
		deps.hud:updateRivalPortrait(beats)
		self:_predictOnBeat(elapsed)
		self:_predictItems(elapsed)
		self:_updatePadEnergy(now, beats)
		self.floorEvents:update(chartElapsed / beatSeconds + 1, beatSeconds)
		tryCall(deps.dancer, "setBeat", beats, beatSeconds)
		tryCall(deps.camera, "setBeat", beats)

		if self.rivalActive then
			tryCall(deps.rival, "update", beats, beatSeconds)
		end

		boardView:renderPad(now, self:_padTelegraphs(chartElapsed, beatSeconds), deps.stepMover:getCoord())
		self:_updateStepGuide(chartElapsed, beatSeconds)
		return
	end

	if onBeat then
		self:_predictOnBeat(elapsed)
	end

	local leadSeconds = self:_telegraphLeadSeconds()
	self:_updateApproachMarkers(chartElapsed, leadSeconds)

	local step = session:getCurrentStep()
	local targetTime = session:getCurrentStepTargetTime()

	if step == nil or targetTime == nil then
		return
	end

	deps.hud.run:updateProgress(chartElapsed, self.songDurationSeconds)

	if not onBeat then
		self:_tryStartInputStep(step, targetTime, elapsed, now)
	end

	if chartElapsed < targetTime - leadSeconds then
		return
	end

	if self.previewedStepIndex ~= session.nextStepIndex then
		boardView:setActiveStep(step)
		boardView:setUpcomingStep(session:getStep(session.nextStepIndex + 1))
		self.previewedStepIndex = session.nextStepIndex
	end

	local holdStarted = self.holdSubmitElapsed

	if step.type == "hold" and holdStarted ~= nil and self.pendingStepIndex == session.nextStepIndex then
		-- Hold in progress: grow and brighten the tile until the server finalizes
		-- at targetTime + holdSeconds.
		local holdEnd = targetTime + (tonumber(step.holdSeconds) or 0.35)
		local holdDuration = math.max(holdEnd - holdStarted, 0.05)

		boardView:setHoldProgress(math.clamp((elapsed - holdStarted) / holdDuration, 0, 1))
		return
	end

	boardView:setApproach(math.clamp(1 - ((targetTime - chartElapsed) / leadSeconds), 0, 1))

	-- Standing still is what onBeat removes, so it shows no stand-and-wait reads.
	if step.type == "hold" or step.type == "slide" or onBeat then
		return
	end

	-- How many beats until the light lands, so the player walks over and stands.
	boardView:setTargetCountdown(step, math.max(math.ceil((targetTime - chartElapsed) / beatSeconds), 0))

	if step.type ~= "danger" then
		boardView:setSettleProgress(self:_settleProgress(step, beatSeconds, now))
	end
end

function RunController._onStartSong(self: RunController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local deps = self.deps
	local hud = deps.hud
	local countdownSeconds = payload.countdownSeconds or DEFAULT_COUNTDOWN_SECONDS

	if deps.hub ~= nil then
		deps.hub:enterStage()
	end

	tryCall(deps.camera, "setResults", false)

	local sharedStart = tonumber(payload.startSharedTime)
	local startTime = if sharedStart ~= nil
		then RhythmSession.localStartFromShared(sharedStart, os.clock(), Workspace:GetServerTimeNow())
		else os.clock() + countdownSeconds
	local session = RhythmSession.new(payload, startTime, sharedStart)

	self.session = session
	self.paused = false
	self.pauseStartedAt = nil
	self.pendingStepIndex = nil
	self.previewedStepIndex = nil
	self.shownPattern = nil
	self.holdSubmitElapsed = nil
	self.firstHitTracked = false
	self.firstMissTracked = false
	self.lastCombo = 0
	self.predictedCombo = 0
	self.lastPredictedIndex = 0
	table.clear(self.gradeCounts)
	self.lastSyncBonus = 0
	self.lastBeatInt = -1
	self.clappedStepIndex = 0
	table.clear(self.landings)
	table.clear(self.clapPresses)
	self.posedIndex = 0
	self.heldIndex = 0
	self:_clearHold()
	self:_indexRushes(session)
	table.clear(self.runAfter)
	table.clear(self.runFailed)
	table.clear(self.predicted)
	table.clear(self.beatCoords)
	self.predictIndex = session.nextStepIndex
	self.serverResolvedIndex = 0
	self.songDurationSeconds = payload.durationSeconds
	self.performanceGoal = payload.performanceGoal
	self.items = if type(payload.items) == "table" then payload.items else {}
	self.itemIndex = 1
	table.clear(self.collectedItems)
	self.sections = payload.sections
	self.tutorial = payload.tutorial == true
	self.padEnergy = nil
	self.feverEndsAt = 0
	self.lastStepCoord = nil

	local ownOrigin = if typeof(payload.boardOrigin) == "Vector3" then payload.boardOrigin else Board.Origin
	local rivalOrigin = if typeof(payload.rivalOrigin) == "Vector3" then payload.rivalOrigin else nil
	local layoutId = if type(payload.boardLayout) == "string" then payload.boardLayout else nil

	self.coreMode = CoreRules.resolveMode(if type(payload.coreMode) == "string" then payload.coreMode else nil)
	deps.floors:setFloors(ownOrigin, rivalOrigin, layoutId)
	self.padMode = self.coreMode == CoreRules.Modes.OnBeat and Board.getLayoutId() == PAD_LAYOUT_ID
	deps.boardView:setApproachMarkers({})
	deps.boardView:hideCountdown()
	deps.boardView:setPadLook(self.padMode)
	hud.pad:setClapEnabled(self.padMode)
	deps.highway:stop()
	self:_stopPadExtras()

	if self.coreMode == CoreRules.Modes.Highway then
		hud.pad:setGrid(HighwayLanes.Count, 1, HighwayLanes.labels())
		deps.highway:begin(session)
	elseif Board.hopsDirectly() then
		hud.pad:setGrid(Board.Columns, Board.Rows)
	else
		hud.pad:setGrid(nil, nil)
	end
	hud.pause:setPaused(false)
	hud.tutorial:setPaused(false)
	deps.stepMover:setStepSeconds(Timing.getStepSeconds(session.map.difficulty))
	deps.stepMover:clearQueue()
	deps.vfx:setFeverActive(false)
	deps.avatar:reset()

	if self.padMode then
		self:_startPadExtras(session, payload.rivalOrigin == nil and (tonumber(payload.slotCount) or 1) <= 1)
		self.floorEvents:begin(payload.events, session.map.steps)
	else
		self.floorEvents:stop()
	end

	local hasAudio = deps.audio:prepare(payload.songId)
	deps.calibration:beginRun()

	hud:applyDeviceLayout()
	hud:hideSongSelect()
	hud:hideResults()
	hud:setRunActive(true)
	hud.run:setSong(payload.title, payload.artist, payload.difficulty)

	local highwayMode = self.coreMode == CoreRules.Modes.Highway
	local padMode = self.padMode
	hud:setRunLayout(highwayMode, padMode)

	-- The authored keys are the touch controls in the highway.
	if highwayMode and deps.highway:usesAuthoredKeys() then
		hud.pad:setVisible(false)
	end
	-- The lesson brings its own cards.
	hud.hints:showOnboarding(
		if self.tutorial
			then nil
			elseif padMode then ONBOARDING.pad
			else ONBOARDING[self.coreMode] or ONBOARDING.standWait
	)
	hud.run:updateScore(0, 0)
	hud.run:updateLife(100, 100)
	hud.run:updatePerformanceGoal(0, self.performanceGoal)
	hud.run:updateFever(nil)

	if hasAudio then
		hud.run:updateProgress(0, self.songDurationSeconds)
	else
		hud.run:setProgressText("SILENT PROTOTYPE")
	end

	local layoutHints = if self.coreMode == CoreRules.Modes.Highway
		then HIGHWAY_HINTS
		else LAYOUT_HINTS[Board.getLayoutId()]
	hud.hints:setHint(layoutHints and layoutHints[deps.deviceMode.id] or deps.deviceMode.controlHint)
	Telemetry.track("song_started", payload.songId)
	Telemetry.track("countdown_started", countdownSeconds)
	print(("[DanceDanceStep] Started song: %s"):format(payload.title or payload.songId))

	local function waitUntilSongTime(songSeconds: number): boolean
		local wait = session.startTime + songSeconds - os.clock()

		if wait > 0 then
			task.wait(wait)
		end

		return self.session == session
	end

	task.spawn(function()
		for second = math.floor(countdownSeconds), 1, -1 do
			if not waitUntilSongTime(-second) then
				return
			end

			hud.run:showCountdown(second)
			deps.sfx:play("countdownTick")
		end

		if not waitUntilSongTime(0) then
			return
		end

		hud.run:showCountdown("STEP!")
		deps.sfx:play("countdownGo")
		deps.sfx:play("cheerStart")
		task.wait(0.35)
		hud.run:showCountdown(nil)
		Telemetry.track("first_input_window_open")
	end)

	local untilStart = math.max(session.startTime - os.clock(), 0)

	task.delay(untilStart, function()
		if self.session ~= session then
			return
		end

		if not deps.audio:play(math.max(session:getElapsed(os.clock()), 0)) then
			hud.run:setProgressText("SILENT PROTOTYPE")
		end
	end)

	task.delay(untilStart + HINT_SWAP_DELAY_SECONDS, function()
		if self.session == session and not session:isFinished() then
			hud.hints:showOnboarding(nil)
			hud.hints:setHint(
				if highwayMode
					then nil
					elseif padMode then legend(PAD_LEGEND) .. UiKit.keyHint("   SPACE CLAP   R RESTART")
					else legend(BOARD_LEGEND) .. UiKit.keyHint("   R RESTART"),
				true
			)
		end
	end)
end

function RunController._onHitResult(self: RunController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local deps = self.deps
	local hud = deps.hud
	local session = self.session
	local resolvedStepIndex = tonumber(payload.stepIndex)

	if session ~= nil then
		if resolvedStepIndex ~= nil then
			-- Sync to the server's authoritative position (covers expired misses
			-- the server resolved while a submit was in flight).
			session.nextStepIndex = math.max(session.nextStepIndex, resolvedStepIndex + 1)
		else
			session:advance()
		end
	end

	-- Clear the in-flight guard only once the server has resolved that step (or
	-- advanced past it via an expired miss).
	if self.pendingStepIndex ~= nil and (resolvedStepIndex == nil or resolvedStepIndex >= self.pendingStepIndex) then
		self.pendingStepIndex = nil
		self.holdSubmitElapsed = nil
	end

	-- Drop the telegraph if it belonged to the step the server just resolved, so
	-- the stale prompt cannot light back up after the grade flash.
	if self.previewedStepIndex ~= nil and resolvedStepIndex ~= nil and resolvedStepIndex >= self.previewedStepIndex then
		deps.boardView:setActiveStep(nil)
		self.previewedStepIndex = nil
	end

	local fever = if type(payload.fever) == "table" then payload.fever else nil
	local feverActive = fever ~= nil and fever.active == true
	local combo = payload.combo or 0
	local grade = payload.grade or "Miss"

	local highway = self.coreMode == CoreRules.Modes.Highway

	if resolvedStepIndex ~= nil then
		self.serverResolvedIndex = math.max(self.serverResolvedIndex, resolvedStepIndex)
	end

	-- A verdict the client already predicted and showed is only confirmed; one
	-- that differs replaces it.
	local confirmed = resolvedStepIndex ~= nil and self.predicted[resolvedStepIndex] == grade

	if highway then
		local lane = if type(payload.step) == "table" then tonumber(payload.step.x) else nil
		deps.highway:onVerdict(payload.grade, lane, feverActive, combo)

		if payload.grade == "Miss" then
			deps.audio:stumble()
		end
	end

	-- The count already ran ahead on the predicted hits, so a result that agrees
	-- never pulls it back; one the server judged differently resets it.
	local predicted = if resolvedStepIndex ~= nil then self.predicted[resolvedStepIndex] else nil
	local contradicted = predicted ~= nil and predicted ~= grade
	local ahead = self.lastPredictedIndex > self.serverResolvedIndex
	local shownCombo = if combo > 0 and ahead and not contradicted then math.max(combo, self.predictedCombo) else combo
	self.predictedCombo = shownCombo
	hud.run:updateScore(payload.score or 0, shownCombo, payload.hype or 0)
	hud.run:updateLife(payload.life, payload.maxLife)
	hud.run:updatePerformanceGoal(payload.score or 0, self.performanceGoal)
	hud.run:updateFever(payload.fever)
	hud.songBar:setFever(payload.fever)
	self:_showRunningStats(grade)

	local missReason = if type(payload.reason) == "string" then payload.reason else nil

	if self.tutorial and self.tutorialHooks ~= nil and resolvedStepIndex ~= nil and session ~= nil then
		self.tutorialHooks.onStep(resolvedStepIndex, #session.map.steps, grade, missReason)
	end

	if not confirmed then
		self:_showVerdict(payload.step, grade, tonumber(payload.deltaMs), resolvedStepIndex, feverActive, missReason)
	end

	hud:setComboExtras(tonumber(payload.multiplier) or 1, payload.shieldReady == true)

	if payload.shielded == true then
		hud:showShieldSave(combo)
		deps.sfx:play("shieldSave")
	end

	local milestone = combo > self.lastCombo
		and (tonumber(payload.milestone) == combo or Scoring.isComboMilestone(combo))

	if self.padMode then
		if (grade == "Perfect" and combo >= PUNCH_COMBO_FROM) or milestone then
			self:_punchCamera()
		end

		tryCall(deps.dancer, "padVerdict", grade, combo)
		tryCall(deps.camera, "setCombo", combo)

		if self.rivalActive then
			tryCall(deps.rival, "setOwnScore", payload.score or 0)
		end
	end

	if milestone and not highway then
		self:_celebrateMilestone(combo)
	elseif combo > self.lastCombo and combo % CROWD_POP_EVERY == 0 then
		deps.sfx:play("crowdPop", 1 + math.min(combo / 200, 0.2))
	end

	if not self.padMode then
		deps.vfx:playComboMilestone(combo)
	end

	deps.avatar:onComboMilestone(combo)
	self:_applyFever(fever)

	-- Combo break feedback: only when a real streak was lost.
	if combo == 0 and self.lastCombo > 0 then
		hud.run:showComboBreak(self.lastCombo, missReason)

		if self.lastCombo >= COMBO_BREAK_SOUND_FROM then
			deps.sfx:play("comboBreak")
		end
	end

	self.lastCombo = combo

	if payload.grade == "Miss" and not self.firstMissTracked then
		Telemetry.track("first_miss")
		self.firstMissTracked = true
	elseif payload.grade ~= "Miss" and not self.firstHitTracked then
		Telemetry.track("first_hit", payload.grade)
		self.firstHitTracked = true
	end
end

-- The grade's feedback: popup, tile flash, burst, screen accent and sound.
function RunController._showVerdict(
	self: RunController,
	step: any,
	grade: string,
	deltaMs: number?,
	_stepIndex: number?,
	feverActive: boolean,
	missReason: string?
)
	local deps = self.deps
	local hud = deps.hud
	local highway = self.coreMode == CoreRules.Modes.Highway

	if self.padMode then
		deps.boardView:padVerdict(step, grade)

		if grade == "Miss" then
			tryCall(deps.camera, "shake", 0.6)
		end
	elseif not highway then
		deps.boardView:flashResult(step, grade, feverActive)
	end

	hud.run:showGrade(grade, deltaMs, if grade == "Miss" then missReason else self:_hitNote(step, grade, deltaMs))

	-- In the highway the burst goes off under the dancer, not on a lane's tile. The
	-- pad's own tile flash is the hit there, so a burst would only cover the targets.
	if not self.padMode then
		deps.vfx:playHitBurst(grade, if highway then Board.centerCoord() else step)
	end

	-- Perfect gets a soft screen accent; the juice stays low on purpose.
	if grade == "Perfect" then
		hud.run:flashScreen(if self.padMode then PAD_PERFECT_FLASH else Color3.fromRGB(255, 228, 236))
	end

	-- No cue on the verdict: it arrives a round trip after the beat, so it would
	-- always sound late. The hit sound on the press is the feedback, and a miss
	-- is told by the song muffling.
end

-- What a pad hit that is not a Miss teaches: a dodge is worth saying, and a
-- Great from standing early is where the Perfect went.
function RunController._hitNote(self: RunController, step: any, grade: string, deltaMs: number?): string?
	if not self.padMode or type(step) ~= "table" then
		return nil
	end

	if step.type == "danger" then
		return "dodged"
	end

	local timed = step.type == "clap" or step.type == "hold" or step.type == "pose"

	if grade == CoreRules.StandGrade and deltaMs == nil and not timed then
		return "stood_early"
	end

	return nil
end

-- Mirrors the server: a step buffered during the previous hop counts as
-- pressed when that hop landed, not when the key went down.
function RunController._recordLanding(
	self: RunController,
	coord: { x: number, y: number },
	landedAt: number,
	pressedAt: number
)
	local session = self.session
	local landings = self.landings
	local offset = self.deps.calibration:getOffsetSeconds()
	local press = session:getElapsed(pressedAt) - offset
	local previous = landings[#landings]

	table.insert(landings, {
		x = coord.x,
		y = coord.y,
		at = session:getElapsed(landedAt) - offset,
		pressAt = if previous ~= nil then math.max(press, previous.at) else press,
		used = false,
	})

	if #landings > MAX_LANDINGS then
		table.remove(landings, 1)
	end
end

local function isPlainStep(step: any): boolean
	return step.type == nil or step.type == "tap" or step.type == "bonus" or SongSchema.isRush(step)
end

-- The dancer strikes the pose on its beat when standing on its tile; whether it
-- was held is the prediction's call.
function RunController._cuePose(self: RunController, elapsed: number, beatSeconds: number)
	local session = self.session
	local index = math.max(session.nextStepIndex, self.posedIndex + 1)

	while true do
		local step = session:getStep(index)

		if step == nil or elapsed < session:getStepTargetTime(step) then
			return
		end

		if SongSchema.isPose(step) then
			self.posedIndex = index

			local coord = self.deps.stepMover:getCoord()

			if coord ~= nil and coord.x == step.x and coord.y == step.y then
				tryCall(self.deps.dancer, "padPose", SongSchema.poseBeatsOf(step) * beatSeconds)
			end
		end

		index += 1
	end
end

-- The server's onBeat verdict trails the beat by a network trip, so the client
-- grades its own landings by the same rules for instant feedback. HitResult
-- still decides; a different server grade replaces this one.
function RunController._predictOnBeat(self: RunController, elapsed: number)
	local session = self.session
	local difficulty = session.map.difficulty
	local stepSeconds = Timing.getStepSeconds(difficulty)
	local now = elapsed - self.deps.calibration:getOffsetSeconds()

	while true do
		local index = math.max(self.predictIndex, self.serverResolvedIndex + 1)
		local step = session:getStep(index)

		if step == nil then
			return
		end

		local targetTime = session:getStepTargetTime(step)
		local runDeadline = self:_runDeadline(index)

		if runDeadline ~= nil then
			if not self:_predictRunTile(index, step, runDeadline, now) then
				return
			end

			self.predictIndex = index + 1
			continue
		end

		if now < targetTime then
			return
		end

		local zone = SongSchema.zoneOf(step)
		local undecidedUntil = targetTime + Timing.OnBeatLateGrace + stepSeconds

		-- Where the dancer stood when the beat landed: the stand the server sees
		-- with no step reported, such as the spawn tile.
		if self.beatCoords[index] == nil then
			self.beatCoords[index] = self.deps.stepMover:getCoord() or false
		end

		if step.type == "danger" then
			local coord = self.deps.stepMover:getCoord()
			local onTile = coord ~= nil and coord.x == step.x and coord.y == step.y
			self:_predict(index, step, if onTile then "Miss" else CoreRules.DodgeGrade, nil, "danger")
		elseif SongSchema.isPose(step) then
			local beatSeconds = self:_beatSeconds()
			local poseBeats = SongSchema.poseBeatsOf(step)
			local moved = CoreRules.brokePose(self.landings, targetTime, poseBeats, beatSeconds, difficulty)

			-- A press near the end only shows up once its hop lands.
			if not moved and now < targetTime + poseBeats * beatSeconds + stepSeconds then
				return
			end

			local _, placement = CoreRules.findOnBeatLanding(self.landings, step.x, step.y, targetTime, difficulty)
			local onTile = placement == "onTile" or self:_stoodOnAtBeat(index, { step })
			local grade = CoreRules.gradePose(onTile, moved)
			self:_predict(index, step, grade, nil, if onTile then "pose_broken" else "not_on_tile")

			if grade ~= "Miss" then
				self.deps.sfx:play("poseShine")
			end
		elseif SongSchema.isClap(step) then
			local press = CoreRules.findClapPress(self.clapPresses, targetTime, self:_beatSeconds())
			local graceOpen = now < targetTime + Timing.OnBeatLateGrace
			local early = press ~= nil
				and press.at < targetTime - Timing.getOnBeatWindows(difficulty).perfectWindow

			-- An early press still open to a closer one waits for the grace to run out.
			if graceOpen and (press == nil or early) then
				return
			end

			local pressOffset = if press ~= nil then press.at - targetTime else nil

			if press ~= nil then
				press.used = true
				self.clappedStepIndex = math.max(self.clappedStepIndex, index)
			end

			self:_noteTimedPress(pressOffset, difficulty)

			local deltaMs = if pressOffset ~= nil then math.floor(pressOffset * 1000 + 0.5) else nil
			self:_predict(index, step, CoreRules.gradeClap(pressOffset, difficulty), deltaMs, "no_clap")
		elseif SongSchema.isFreeze(step) then
			if now < targetTime + stepSeconds then
				return
			end

			local fromAt, toAt = CoreRules.freezeWindow(targetTime, self:_beatSeconds())
			local moved = CoreRules.brokeFreeze(self.landings, fromAt, toAt, difficulty)
			self:_predict(index, step, CoreRules.gradeFreeze(moved), nil, "freeze")
		elseif zone ~= nil then
			local landing: CoreRules.Landing?, placement: CoreRules.OnBeatPlacement =
				CoreRules.findZoneLanding(self.landings, zone, targetTime, difficulty)
			local decided = placement == "onTile" or placement == "late"

			if not decided and now < undecidedUntil then
				return
			end

			local pressOffset = if landing ~= nil then CoreRules.pressOf(landing, difficulty) - targetTime else nil

			if landing ~= nil then
				landing.used = true
			end

			local seen = placement == "unknown" and self:_stoodOnAtBeat(index, zone)
			local grade = CoreRules.gradeZone(placement, pressOffset, difficulty, seen)
			self:_noteTimedPress(pressOffset, difficulty)
			local missed = if SongSchema.isShape(step) then "wrong_tile" else "outside_zone"
			self:_predict(index, step, grade, nil, missed)
		elseif isPlainStep(step) then
			local landing: CoreRules.Landing?, placement: CoreRules.OnBeatPlacement =
				CoreRules.findOnBeatLanding(self.landings, step.x, step.y, targetTime, difficulty)
			local decided = placement == "onTile" or placement == "late"

			if not decided and now < undecidedUntil then
				return
			end

			local seen = placement == "unknown" and self:_stoodOnAtBeat(index, { step })
			local verdict = CoreRules.judgeOnBeatNote(landing, placement, targetTime, difficulty, seen)

			if landing ~= nil then
				landing.used = true
			end

			local rush = self.rushInfo[index]

			if rush ~= nil then
				self.runAfter[rush.id] = CoreRules.runStartAt(landing, targetTime)
				self:_onRunTile(index, step, verdict.grade ~= "Miss")
			end

			local pressOffset = verdict.pressOffset
			local deltaMs = if pressOffset ~= nil
				then math.floor((pressOffset + Timing.OnBeatLandDelay) * 1000 + 0.5)
				else nil
			self:_noteTimedPress(pressOffset, difficulty)
			local late = verdict.kind == "miss"
				and CoreRules.arrivedLate(self.landings, step.x, step.y, targetTime, self:_beatSeconds(), difficulty)
			self:_predict(index, step, verdict.grade, deltaMs, if late then "late" else "wrong_tile")
		end

		self.predictIndex = index + 1
	end
end

-- A press inside the great window was aimed at the beat, so it shows where this
-- player hits; a far early stand or a scramble onto the tile says nothing.
function RunController._noteTimedPress(self: RunController, pressOffset: number?, difficulty: string?)
	if pressOffset ~= nil and CoreRules.isTimedPress(pressOffset, difficulty) then
		self.deps.calibration:notePress(pressOffset + Timing.OnBeatLandDelay)
	end
end

-- Mirrors the server's run: a tile after the first is a hit the moment the
-- dancer lands on it in order, and a Miss once the run's deadline has passed.
function RunController._predictRunTile(
	self: RunController,
	index: number,
	step: any,
	deadline: number,
	now: number
): boolean
	local difficulty = self.session.map.difficulty
	local afterAt = self:_runAfterAt(index)
	local landing = CoreRules.findRunLanding(self.landings, step.x, step.y, afterAt, deadline, difficulty)

	if landing == nil and now < deadline + Timing.getStepSeconds(difficulty) then
		return false
	end

	if landing ~= nil then
		landing.used = true
		self.runAfter[self.rushInfo[index].id] = landing.at
	end

	self:_predict(index, step, CoreRules.gradeRunTile(landing ~= nil), nil, "missed_run")
	self:_onRunTile(index, step, landing ~= nil)
	return true
end

-- The run's sound and flourish: a whoosh off the first tile, a blip climbing a
-- step per tile, a chord at the end, or one down-swoop at the first tile missed.
function RunController._onRunTile(self: RunController, index: number, step: any, reached: boolean)
	local rush = self.rushInfo[index]

	if rush == nil or self.runFailed[rush.id] then
		return
	end

	local deps = self.deps
	local coord = { x = step.x, y = step.y }

	if not reached then
		self.runFailed[rush.id] = true
		tryCall(deps.camera, "endPadMoment", "run")
		deps.sfx:play("runFail")
		tryCall(deps.boardView, "padRunDone", coord, false)
		tryCall(deps.dancer, "padRunDone", false)
		return
	end

	tryCall(deps.boardView, "padRunTileHit", coord, rush.rushIndex, rush.rushCount)
	tryCall(deps.dancer, "padRunStep", rush.rushIndex, rush.rushCount)

	if rush.rushIndex < rush.rushCount then
		tryCall(deps.camera, "setPadMoment", "run", { tiles = rush.tiles, from = rush.rushIndex })
	else
		tryCall(deps.camera, "endPadMoment", "run")
		deps.sfx:play("runDone")
		deps.sfx:play("crowdPop")
		tryCall(deps.boardView, "padRunDone", coord, true)
		tryCall(deps.dancer, "padRunDone", true)
	end
end

-- Mirrors the pad's hold drain on the same clock: held once the dancer stands
-- on it, dropped if they step off before it runs out.
function RunController._trackHold(self: RunController, elapsed: number, beatSeconds: number)
	local session = self.session
	local index = math.max(session.nextStepIndex, self.heldIndex + 1)

	while self.hold == nil do
		local step = session:getStep(index)

		if step == nil or elapsed < session:getStepTargetTime(step) then
			break
		end

		if step.type == "hold" then
			local startAt = session:getStepTargetTime(step)
			self.hold = {
				index = index,
				x = step.x,
				y = step.y,
				startAt = startAt,
				endAt = startAt + (tonumber(step.holdSeconds) or DEFAULT_HOLD_SECONDS),
				landed = false,
				beat = 0,
			}
		end

		self.heldIndex = index
		index += 1
	end

	local hold = self.hold

	if hold == nil then
		return
	end

	local deps = self.deps
	local coord = deps.stepMover:getCoord()
	local onTile = coord ~= nil and coord.x == hold.x and coord.y == hold.y
	local beat = math.floor((elapsed - hold.startAt) / beatSeconds)

	if elapsed >= hold.endAt then
		self:_clearHold()

		if hold.landed then
			deps.sfx:play("holdChime")
			deps.sfx:play("crowdPop")
			tryCall(deps.boardView, "padHoldDone", { x = hold.x, y = hold.y })
			tryCall(deps.dancer, "padHoldEnd", true)
		end
	elseif not hold.landed then
		if onTile then
			hold.landed = true
			hold.beat = beat
			tryCall(deps.dancer, "padHoldStart", hold.endAt - elapsed)
			tryCall(deps.boardView, "padHoldStart", hold.endAt - elapsed)
			local moment = { x = hold.x, y = hold.y, untilBeat = hold.endAt / beatSeconds }
			tryCall(deps.camera, "setPadMoment", "hold", moment)
		end
	elseif not onTile then
		self:_clearHold()
		deps.sfx:play("holdDrop")
		tryCall(deps.dancer, "padHoldEnd", false)
		tryCall(deps.boardView, "padHoldDrop")
	elseif beat > hold.beat then
		hold.beat = beat
	end
end

function RunController._clearHold(self: RunController)
	self.hold = nil
	self.deps.sfx:stop("holdSwell")
	tryCall(self.deps.camera, "endPadMoment", "hold")
end

-- The clap press sounds at once: a crisp clap and snap on the beat of a clap
-- still to judge, a plain clap when near it, a dull thud otherwise.
function RunController._clapFeedback(self: RunController, pressAt: number)
	local session = self.session
	local difficulty = session.map.difficulty
	local beatSeconds = self:_beatSeconds()
	local index = self.serverResolvedIndex + 1
	local grade: string? = nil
	local bestDistance = math.huge

	while true do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		local offset = pressAt - session:getStepTargetTime(step)

		if offset < -Timing.ClapEarlyBeats * beatSeconds then
			break
		end

		if SongSchema.isClap(step) and self.predicted[index] == nil and math.abs(offset) < bestDistance then
			bestDistance = math.abs(offset)
			grade = CoreRules.gradeClap(offset, difficulty)
		end

		index += 1
	end

	local deps = self.deps

	if grade == nil or grade == "Miss" then
		deps.sfx:play("clapThud")
		return
	end

	self:_playHit(CLAP_HIT_GROUP)

	if grade ~= "Perfect" and grade ~= "Great" then
		return
	end

	deps.sfx:play("clapSnap")

	local coord = deps.stepMover:getCoord()

	if coord ~= nil then
		tryCall(deps.boardView, "padClapHit", coord, grade)
	end
end

-- Items are predicted by the same rule the server collects them with, so the
-- sparkle and the ping land on the beat; ItemResult still has the final word.
function RunController._predictItems(self: RunController, elapsed: number)
	local session = self.session
	local difficulty = session.map.difficulty
	local graceEnd = Timing.OnBeatLateGrace + Timing.getStepSeconds(difficulty)
	local now = elapsed - self.deps.calibration:getOffsetSeconds()

	while true do
		local item = self.items[self.itemIndex]

		if item == nil then
			return
		end

		local targetTime = session:getStepTargetTime(item)

		if now < targetTime then
			return
		end

		local coord = self.deps.stepMover:getCoord()
		local standing = coord ~= nil and coord.x == item.x and coord.y == item.y
		local _, placement = CoreRules.findOnBeatLanding(self.landings, item.x, item.y, targetTime, difficulty)
		local collected = CoreRules.collectsItem(placement, standing)

		if not collected and now < targetTime + graceEnd then
			return
		end

		if collected then
			self:_collectItem(self.itemIndex, item)
		end

		self.itemIndex += 1
	end
end

function RunController._collectItem(self: RunController, index: number, item: any)
	if self.collectedItems[index] then
		return
	end

	self.collectedItems[index] = true

	local deps = self.deps
	local coord = { x = item.x, y = item.y }
	tryCall(deps.boardView, "padCollect", coord)
	deps.sfx:play("itemCollect")
	deps.hud.run:flashScreen(ITEM_FLASH)
end

function RunController._onItemResult(self: RunController, payload: any)
	if type(payload) ~= "table" or self.session == nil then
		return
	end

	local index = tonumber(payload.itemIndex)
	local item = if index ~= nil then self.items[index] else nil

	if index == nil or item == nil then
		return
	end

	self.itemIndex = math.max(self.itemIndex, index + 1)

	if payload.collected ~= true then
		return
	end

	self:_collectItem(index, item)

	local score = tonumber(payload.score) or 0
	self.deps.hud.run:updateScore(score, self.lastCombo, tonumber(payload.hype) or 0)
	self.deps.hud.run:updatePerformanceGoal(score, self.performanceGoal)

	if self.rivalActive then
		tryCall(self.deps.rival, "setOwnScore", score)
	end

	self:_applyFever(if type(payload.fever) == "table" then payload.fever else nil)
end

function RunController._applyFever(self: RunController, fever: any?)
	local deps = self.deps
	local active = fever ~= nil and fever.active == true

	self.feverEndsAt = if active then os.clock() + (tonumber(fever.remainingSeconds) or 0) else 0
	deps.vfx:setFeverActive(active)
	deps.avatar:setFeverActive(active)
	tryCall(deps.dancer, "setFever", active)

	if fever ~= nil and fever.started == true then
		deps.sfx:play("feverStart")
		deps.sfx:play("cheerFever")
	end
end

-- The floor follows the song's sections, and Fever takes it over while it lasts.
function RunController._updatePadEnergy(self: RunController, now: number, beats: number)
	local energy = if now < self.feverEndsAt
		then FEVER_PAD_ENERGY
		else SongSchema.energyAt(self.sections, beats + 1) or DEFAULT_PAD_ENERGY

	if energy ~= self.padEnergy then
		-- Coming out of Fever back into the same section is not a new section.
		local afterFever = self.padEnergy == FEVER_PAD_ENERGY
		self.padEnergy = energy
		tryCall(self.deps.boardView, "setPadEnergy", energy)
		tryCall(self.deps.camera, "setEnergy", energy)
		tryCall(self.deps.camera, "setFever", energy == FEVER_PAD_ENERGY)

		if afterFever then
			return
		elseif energy == "drop" then
			tryCall(self.deps.camera, "shake", 1)
			tryCall(self.deps.camera, "sweep", 1)
		elseif energy == "chorus" then
			tryCall(self.deps.camera, "sweep", 0.7)
		end
	end
end

function RunController._celebrateMilestone(self: RunController, combo: number)
	local deps = self.deps

	local multiplier = Scoring.multiplierFor(combo)
	local text = if multiplier > 1 then ("%d COMBO!  x%s"):format(combo, tostring(multiplier)) else ("%d COMBO!"):format(combo)
	deps.hud:showMilestone(text, combo)
	deps.sfx:play("cheerMilestone")
	deps.hud.run:flashScreen(PAD_PERFECT_FLASH)
	tryCall(deps.camera, "shake", math.min(combo / MILESTONE_SHAKE_COMBO, 1))

	if self.padMode then
		tryCall(deps.boardView, "padMilestone", combo)
		tryCall(deps.camera, "milestone", combo)
	end
end

function RunController._startPadExtras(self: RunController, session: any, solo: boolean)
	local deps = self.deps
	local dancer = deps.dancer

	tryCall(dancer, "padStart", tonumber(session.map.bpm) or 120)
	tryCall(deps.camera, "setPadLive", true)
	tryCall(deps.camera, "setCombo", 0)

	if dancer ~= nil and type(dancer.isRigged) == "function" then
		tryCall(deps.avatar, "setLiveDance", dancer:isRigged())
	end

	self:_updatePadEnergy(os.clock(), 0)

	-- The lesson is the player's alone; a rival would only pull the eye away.
	if solo and not self.tutorial and deps.rival ~= nil then
		self.rivalActive = true
		tryCall(deps.rival, "start", session.map, session.map.difficulty or Timing.DefaultDifficulty)
	end
end

function RunController._stopPadExtras(self: RunController)
	local deps = self.deps

	tryCall(deps.dancer, "padStop")
	self:_clearHold()
	deps.hud.pad:setGuide(nil, nil, 0)
	deps.hud.pad:setClapGuide(nil)
	tryCall(deps.camera, "setPadLive", false)
	tryCall(deps.avatar, "setLiveDance", false)

	if self.rivalActive then
		self.rivalActive = false
		tryCall(deps.rival, "stop")
	end
end

function RunController._stoodOnAtBeat(self: RunController, index: number, tiles: { { x: number, y: number } }): boolean
	local coord = self.beatCoords[index]

	if typeof(coord) ~= "table" then
		return false
	end

	for _, tile in tiles do
		if tile.x == coord.x and tile.y == coord.y then
			return true
		end
	end

	return false
end

-- missReason is the player-facing reason shown if the grade is a Miss.
function RunController._predict(
	self: RunController,
	index: number,
	step: any,
	grade: string,
	deltaMs: number?,
	missReason: string?
)
	self.predicted[index] = grade
	self.beatCoords[index] = nil
	self:_showVerdict(step, grade, deltaMs, index, false, if grade == "Miss" then missReason else nil)

	-- The combo moves with the step, not a round trip later, so it is felt on the beat.
	if self.padMode then
		self.predictedCombo = if grade == "Miss" then 0 else self.predictedCombo + 1
		self.lastPredictedIndex = math.max(self.lastPredictedIndex, index)
		tryCall(self.deps.hud.run, "showPredictedCombo", self.predictedCombo)
	end
end

function RunController._punchCamera(self: RunController)
	local camera = self.deps.camera

	if camera ~= nil and type(camera.punch) == "function" then
		camera:punch()
	end
end

function RunController._showRunningStats(self: RunController, grade: string)
	local counts = self.gradeCounts
	counts[grade] = (counts[grade] or 0) + 1

	local judged = 0

	for _, count in counts do
		judged += count
	end

	local live = ScoreSummary.fromState({
		perfects = counts.Perfect,
		greats = counts.Great,
		goods = counts.Good,
		bads = counts.Bad,
		misses = counts.Miss,
	}, judged)

	self.deps.hud.songBar:setStats(live.accuracy, live.rank, live.misses)
end

function RunController._onSongComplete(self: RunController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local deps = self.deps
	local summary = payload.summary

	deps.audio:fadeOut(SONG_END_FADE_SECONDS)
	deps.highway:stop()
	deps.boardView:setApproachMarkers({})
	deps.vfx:setFeverActive(false)

	-- Between drills the lesson stays on stage, so the lobby and the wide camera
	-- never flash up; the onboarding resets to the lobby when the lesson ends.
	if type(summary) == "table" and summary.tutorial == true and self.tutorialHooks ~= nil then
		self:_endLessonDrill()
		self.tutorialHooks.onDone(if type(payload.rewards) == "table" then payload.rewards.tutorial else nil)
		return
	end

	if type(summary) == "table" then
		summary.versus = self:_versusOf(payload)
	end

	self:_stopPadExtras()
	self.floorEvents:stop()
	deps.avatar:onSongComplete(if summary ~= nil then summary.rank else nil)
	deps.hud:setRunActive(false)
	-- The server has ended the run, so the local clock stops with it; otherwise its
	-- ticks and steps carry on under the results, and the picker thinks a run is on.
	self.session = nil
	deps.stepMover:clearQueue()

	if summary == nil then
		return
	end

	tryCall(deps.camera, "setResults", true)
	summary.rewards = payload.rewards
	summary.multiplayerStatus = payload.multiplayerStatus
	summary.timing = deps.calibration:tuneFromRun()
	deps.hud:showSummary(summary)
	deps.hud.run:updateFever(nil)
	deps.vfx:playConfetti()
	deps.sfx:play("songComplete")
	deps.sfx:play("cheerEnd")
	Telemetry.track("song_completed", summary.rank)
end

function RunController._endLessonDrill(self: RunController)
	local deps = self.deps

	self.tutorial = false
	self.session = nil
	self:_clearHold()
	deps.hud.pad:setGuide(nil, nil, 0)
	deps.hud.pad:setClapGuide(nil)
	deps.boardView:setActiveStep(nil)
	deps.stepMover:clearQueue()
	tryCall(deps.dancer, "padStop")
end

-- Who the run was a race against, for the results: the bot, read before it
-- stops, or a match's rival from the server's status.
function RunController._versusOf(self: RunController, payload: any): { name: string, score: number }?
	local rival = self.deps.rival

	if self.rivalActive and rival ~= nil then
		return { name = rival:getName(), score = rival:getScore() }
	end

	local status = payload.multiplayerStatus

	if type(status) == "table" and type(status.rivalName) == "string" then
		return { name = status.rivalName, score = tonumber(status.rivalScore) or 0 }
	end

	return nil
end

function RunController._onPauseState(self: RunController, payload: any)
	local deps = self.deps
	local wantPaused = type(payload) == "table" and payload.paused == true

	if wantPaused and not self.paused then
		self.paused = true
		self.pauseStartedAt = os.clock()
		deps.sfx:stop("holdSwell")
		deps.audio:pause()
		deps.hud.pause:setPaused(true)
		deps.hud.tutorial:setPaused(true)
	elseif not wantPaused and self.paused then
		if self.session ~= nil then
			-- Shift the local telegraph clock forward by the paused wall-time so it
			-- resumes from the exact beat it froze on.
			self.session:shift(os.clock() - (self.pauseStartedAt or os.clock()))
		end

		self.paused = false
		self.pauseStartedAt = nil
		deps.audio:resume()
		deps.hud.pause:setPaused(false)
		deps.hud.tutorial:setPaused(false)
	end
end

function RunController._onMultiplayerStatus(self: RunController, payload: any)
	if type(payload) == "table" then
		self.isGuest = (tonumber(payload.playerCount) or 1) > 1 and (tonumber(payload.playerSlot) or 1) ~= 1
	end

	if type(payload) == "table" and type(payload.modeId) == "string" then
		local syncBonus = tonumber(payload.syncBonus) or 0

		if syncBonus > self.lastSyncBonus then
			self.deps.vfx:playCoopSync(syncBonus)
		end

		self.lastSyncBonus = syncBonus
	end

	self.deps.hud.multiplayer:update(payload)

	if type(payload) == "table" and (tonumber(payload.playerCount) or 1) > 1 and self.rivalActive then
		self.rivalActive = false
		tryCall(self.deps.rival, "stop")
	end

	-- A solo run's versus bar belongs to the rival bot, which drives it itself.
	if type(payload) == "table" and not self.rivalActive then
		local rivalName = if type(payload.rivalName) == "string" then payload.rivalName else nil
		self.deps.hud.songBar:setVersus(
			tonumber(payload.ownScore) or 0,
			tonumber(payload.rivalScore) or 0,
			rivalName,
			tonumber(payload.rivalUserId)
		)
		self:_showPlayerRival(payload, rivalName)
	end
end

-- On the pad a real opponent gets the same reacting face as the bot.
function RunController._showPlayerRival(self: RunController, payload: any, rivalName: string?)
	local portrait = self.deps.hud.rivalPortrait

	if not self.padMode or rivalName == nil or tonumber(payload.rivalUserId) == nil then
		portrait:setRival(nil)
		return
	end

	local userId = tonumber(payload.rivalUserId) :: number

	if portrait:setRival({ name = rivalName }) then
		local rival = Players:GetPlayerByUserId(userId)
		portrait:setAvatar(if rival ~= nil then rival.Character else nil, userId)
	end

	portrait:setLead(tonumber(payload.ownScore) or 0, tonumber(payload.rivalScore) or 0)
end

return RunController
