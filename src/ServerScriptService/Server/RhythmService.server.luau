local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteContract = require(Shared:WaitForChild("RemoteContract"))
local RhythmSession = require(Shared:WaitForChild("RhythmSession"))
local Timing = require(Shared:WaitForChild("Timing"))
local Board = require(Shared:WaitForChild("Board"))
local BoardLayouts = require(Shared:WaitForChild("BoardLayouts"))
local HitValidator = require(Shared:WaitForChild("HitValidator"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local ScoreSummary = require(Shared:WaitForChild("ScoreSummary"))
local TutorialChart = require(Shared:WaitForChild("TutorialChart"))
local SongMapCatalog = require(Shared:WaitForChild("SongMapCatalog"))
local SongCollection = require(Shared:WaitForChild("SongCollection"))
local CrowdHype = require(Shared:WaitForChild("CrowdHype"))
local FeverSystem = require(Shared:WaitForChild("FeverSystem"))
local LifeGauge = require(Shared:WaitForChild("LifeGauge"))
local CoreRules = require(Shared:WaitForChild("CoreRules"))
local ArrivalLedger = require(Shared:WaitForChild("ArrivalLedger"))
local SongSchema = require(Shared:WaitForChild("SongSchema"))

local Services = script.Parent:WaitForChild("Services")
local RateLimiter = require(Services:WaitForChild("RateLimiter"))
local AbilityService = require(Services:WaitForChild("AbilityService"))

local remotes = ReplicatedStorage:WaitForChild(RemoteContract.FolderName)
local songCatalogRemote = remotes:WaitForChild(RemoteContract.Events.SongCatalog.name)
local startSongRemote = remotes:WaitForChild(RemoteContract.Events.StartSong.name)
local submitHitRemote = remotes:WaitForChild(RemoteContract.Events.SubmitHit.name)
local reportArrivalRemote = remotes:WaitForChild(RemoteContract.Events.ReportArrival.name)
local submitPressRemote = remotes:WaitForChild(RemoteContract.Events.SubmitPress.name)
local submitReleaseRemote = remotes:WaitForChild(RemoteContract.Events.SubmitRelease.name)
local submitClapRemote = remotes:WaitForChild(RemoteContract.Events.SubmitClap.name)
local hitResultRemote = remotes:WaitForChild(RemoteContract.Events.HitResult.name)
local itemResultRemote = remotes:WaitForChild(RemoteContract.Events.ItemResult.name)
local rivalResultRemote = remotes:WaitForChild(RemoteContract.Events.RivalResult.name)
local songCompleteRemote = remotes:WaitForChild(RemoteContract.Events.SongComplete.name)
local requestRestartRemote = remotes:WaitForChild(RemoteContract.Events.RequestRestart.name)
local returnToHubRemote = remotes:WaitForChild(RemoteContract.Events.ReturnToHub.name)
local requestPauseRemote = remotes:WaitForChild(RemoteContract.Events.RequestPause.name)
local pauseStateRemote = remotes:WaitForChild(RemoteContract.Events.PauseState.name)
local requestSongRemote = remotes:WaitForChild(RemoteContract.Events.RequestSong.name)
local setTimingOffsetRemote = remotes:WaitForChild(RemoteContract.Events.SetTimingOffset.name)
local timingOffsetSyncRemote = remotes:WaitForChild(RemoteContract.Events.TimingOffsetSync.name)
local abilityStateRemote = remotes:WaitForChild(RemoteContract.Events.AbilityState.name)
local startTutorialRemote = remotes:WaitForChild(RemoteContract.Events.StartTutorial.name)
local skipTutorialRemote = remotes:WaitForChild(RemoteContract.Events.SkipTutorial.name)

local sessions = {}
local timingOffsets = {}
local rateLimiter = RateLimiter.new()
local abilityService = AbilityService.new(abilityStateRemote)
local COORD_HISTORY_LENGTH = 48
-- Highway charts are the authored charts remapped onto four lanes.
local HIGHWAY_LAYOUT = "lanes4"
local HIGHWAY_LANES = BoardLayouts.get(HIGHWAY_LAYOUT).columns
local ARRIVAL_CONFIG: ArrivalLedger.Config = Timing.Arrival

local function maxTileTravelStudsPerSecond(): number
	return Board.longestStep() / Timing.getStepSeconds("expert") * Timing.MaxTravelSpeedSlack
end

-- Charts are authored for the default floor, so another layout plays a remapped
-- copy and the catalog's own map is never touched.
local function mapForLayout(map: any, layoutId: string): any
	if layoutId == BoardLayouts.Default then
		return map
	end

	-- A song charted for the highway follows its melody; only songs without
	-- one fall back to remapping the floor chart onto the lanes.
	if layoutId == HIGHWAY_LAYOUT and type(map.highwaySteps) == "table" and #map.highwaySteps > 0 then
		local copy = table.clone(map)
		copy.steps = (SongSchema.splitItems(map.highwaySteps))
		return copy
	end

	local source = BoardLayouts.get(BoardLayouts.Default)
	local copy = table.clone(map)
	copy.steps = BoardLayouts.remap(map.steps, layoutId, source.columns, source.rows)

	return copy
end

local function getBackend()
	return _G.DanceDanceStepBackend
end

-- The lesson counts toward the onboarding funnel; every other run is a session of
-- the run funnel.
local function logRunStep(player: Player, state: any, runStep: string, lessonStep: string?)
	local backend = getBackend()

	if backend == nil or backend.Funnels == nil then
		return
	end

	if not state.tutorial then
		backend.Funnels:step(player, "run", state.funnelSessionId, runStep)
	elseif lessonStep ~= nil then
		backend.Funnels:onboarding(player, lessonStep)
	end
end

local function getProfile(player: Player)
	local backend = getBackend()

	return backend ~= nil and backend.PlayerData ~= nil and backend.PlayerData:get(player) or nil
end

local function getCharacterParts(player: Player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	return character, rootPart, humanoid
end

local function getPlayerBoardCoord(player: Player, origin: Vector3)
	local _, rootPart = getCharacterParts(player)

	if rootPart ~= nil and Board.isWorldPointInside(rootPart.Position, origin) then
		return Board.worldToCoord(rootPart.Position, origin)
	end

	return nil
end

-- Every player judges against a floor of their own, so a run begins with the
-- player standing in the middle of it.
-- Onto the floor itself, standing on it: in a hub place the player arrives from
-- an island far above the stage, so their height is no guide.
local function moveToFloor(player: Player, origin: Vector3)
	local _, rootPart, humanoid = getCharacterParts(player)

	if rootPart == nil then
		return
	end

	local standing = (if humanoid ~= nil then humanoid.HipHeight else 2) + rootPart.Size.Y / 2

	rootPart.CFrame = CFrame.new(origin + Vector3.new(0, standing, 0)) * rootPart.CFrame.Rotation
	rootPart.AssemblyLinearVelocity = Vector3.zero
end

local function sameCoord(left: any?, right: any?): boolean
	return left ~= nil and right ~= nil and left.x == right.x and left.y == right.y
end

local function toMs(seconds: number): number
	return math.floor(seconds * 1000 + 0.5)
end

local function coordDistance(left: any, right: any): number
	local leftWorld = Board.coordToWorld(left.x, left.y)
	local rightWorld = Board.coordToWorld(right.x, right.y)

	return (Vector3.new(leftWorld.X, 0, leftWorld.Z) - Vector3.new(rightWorld.X, 0, rightWorld.Z)).Magnitude
end

local function recordSuspicious(state: any, reason: string)
	state.suspicious[reason] = (state.suspicious[reason] or 0) + 1
end

local function getTimingOffsetState(player: Player)
	local entry = timingOffsets[player]

	if entry == nil then
		entry = {
			offset = 0,
			calibrated = false,
			profileChecked = false,
		}
		timingOffsets[player] = entry
	end

	if not entry.profileChecked then
		local profile = getProfile(player)

		if profile ~= nil then
			entry.profileChecked = true

			local settings = type(profile.settings) == "table" and profile.settings or nil

			-- Restore a player-calibrated offset; never clobber an offset the
			-- player already set this session.
			if settings ~= nil and settings.timingOffsetCalibrated == true and not entry.calibrated then
				entry.offset = math.clamp(tonumber(settings.timingOffsetSeconds) or 0, -Timing.MaxTimingOffsetSeconds, Timing.MaxTimingOffsetSeconds)
				entry.calibrated = true
			end
		end
	end

	return entry
end

local function syncTimingOffset(player: Player)
	local entry = getTimingOffsetState(player)

	timingOffsetSyncRemote:FireClient(player, {
		offsetSeconds = entry.offset,
		calibrated = entry.calibrated,
	})
end

local function updatePositionAudit(player: Player, state: any, now: number)
	local coord = getPlayerBoardCoord(player, state.origin)

	if coord == nil then
		-- Off the board (or no character): reset dwell tracking so stepping
		-- off and back onto a tile cannot inflate accumulated dwell time.
		if state.currentCoord ~= nil and state.coordHistory ~= nil then
			table.insert(state.coordHistory, { at = now })
		end

		state.currentCoord = nil
		state.coordEnteredAt = nil

		return nil
	end

	if state.currentCoord == nil or not sameCoord(state.currentCoord, coord) then
		if state.currentCoord ~= nil and state.coordEnteredAt ~= nil then
			local elapsed = math.max(now - state.coordEnteredAt, 0.001)
			local maxDistance = (maxTileTravelStudsPerSecond() * elapsed) + Board.TileSize

			if coordDistance(state.currentCoord, coord) > maxDistance then
				recordSuspicious(state, "impossible_tile_travel")
			end
		end

		state.currentCoord = coord
		state.coordEnteredAt = now

		local history = state.coordHistory

		if history ~= nil then
			table.insert(history, { x = coord.x, y = coord.y, at = now })

			if #history > COORD_HISTORY_LENGTH then
				table.remove(history, 1)
			end
		end

		for _, reason in state.ledger:onPositionSeen(coord.x, coord.y, now) do
			recordSuspicious(state, reason)
		end
	end

	return coord
end

-- One line per run, so a playtest can be read back without instrumenting the
-- client. See docs/GAMEPLAY_PLAN.md section 8.
local function playtestLine(player: Player, state: any, summary: any): string
	local deltas = state.deltas or {}
	local count = #deltas
	local mean, spread = 0, 0

	if count > 0 then
		local total = 0

		for _, value in deltas do
			total += value
		end

		mean = total / count
		local variance = 0

		for _, value in deltas do
			variance += (value - mean) ^ 2
		end

		spread = math.sqrt(variance / count)
	end

	local misses = {}

	for reason, n in state.missReasons or {} do
		table.insert(misses, string.format("%s=%d", reason, n))
	end

	table.sort(misses)

	local flagged = {}

	for reason, n in state.suspicious or {} do
		table.insert(flagged, string.format("%s=%d", reason, n))
	end

	table.sort(flagged)

	return string.format(
		"[Playtest] %s mode=%s layout=%s song=%s diff=%s rank=%s score=%d acc=%.3f | P=%d G=%d g=%d B=%d M=%d | delta mean=%+.0fms sd=%.0fms n=%d | misses %s | delay=%s | items %d/%d | flagged %s",
		player.Name,
		tostring(state.coreMode),
		tostring(state.boardLayout),
		tostring(state.session.map.id),
		tostring(state.session.map.difficulty),
		tostring(summary.rank),
		summary.score or 0,
		summary.accuracy or 0,
		summary.perfects or 0,
		summary.greats or 0,
		summary.goods or 0,
		summary.bads or 0,
		summary.misses or 0,
		mean,
		spread,
		count,
		(if #misses > 0 then table.concat(misses, " ") else "none"),
		(if state.ledger:getDelay() ~= nil then string.format("%.0fms", state.ledger:getDelay() * 1000) else "unmeasured"),
		state.scoreState.itemsCollected or 0,
		#state.items,
		(if #flagged > 0 then table.concat(flagged, " ") else "none")
	)
end

local function finalizeStep(player: Player, state: any, step: any, stepIndex: number, result: any, now: number)
	abilityService:judge(state, result, step, now)
	local before = abilityService:before(state)

	if result.deltaMs ~= nil then
		table.insert(state.deltas, result.deltaMs)
	end

	if result.grade == "Miss" then
		local reason = tostring(result.reason or "unknown")
		state.missReasons[reason] = (state.missReasons[reason] or 0) + 1
	end

	-- Hold/slide type bonuses are only awarded on successful completion.
	local scoringStep = if result.withholdTypeBonus == true then nil else step

	local _, shielded = Scoring.applyGrade(state.scoreState, result.grade, scoringStep)
	state.hype = CrowdHype.applyGrade(state.hype, result.grade)

	local combo = state.scoreState.combo
	local milestone = if result.grade ~= "Miss" and Scoring.isComboMilestone(combo) then combo else nil

	if milestone ~= nil then
		state.hype = CrowdHype.boost(state.hype, CrowdHype.MilestoneGain)
	end

	local feverStarted = FeverSystem.tryActivate(state.feverState, state.scoreState.combo, state.hype, now)
	local feverBonus = FeverSystem.applyHitBonus(state.feverState, result.accepted, now)

	if feverBonus > 0 then
		state.scoreState.score += feverBonus
		state.scoreState.feverBonusScore = (state.scoreState.feverBonusScore or 0) + feverBonus
		state.hype = math.clamp(state.hype + FeverSystem.HypeBonusPerHit, 0, CrowdHype.Max)
	end

	state.scoreState.feverActivations = state.feverState.activations or 0

	-- Life gauge: drains on Miss/Bad, recovers on good hits (issue 040).
	state.life = LifeGauge.applyGrade(state.life, result.grade, state.session.map.difficulty)

	if abilityService:settle(player, state, result.grade, before, now) then
		shielded = true
		combo = state.scoreState.combo
	end

	local failed = not state.tutorial and LifeGauge.isFailed(state.life, state.session.map.difficulty)

	if result.grade ~= "Miss" and not state.funnelFirstHit then
		state.funnelFirstHit = true
		logRunStep(player, state, "first_hit")
	end

	if not state.funnelHalfway and stepIndex * 2 >= #state.session.map.steps then
		state.funnelHalfway = true
		logRunStep(player, state, "halfway")
	end

	local backend = getBackend()

	if backend ~= nil and backend.Multiplayer ~= nil then
		backend.Multiplayer:updateScore(player, state.scoreState.score, state.scoreState.combo, state.hype)
	end

	hitResultRemote:FireClient(player, {
		stepIndex = stepIndex,
		step = step,
		grade = result.grade,
		score = state.scoreState.score,
		combo = state.scoreState.combo,
		hype = state.hype,
		life = state.life,
		maxLife = LifeGauge.Max,
		fever = FeverSystem.snapshot(state.feverState, now, feverStarted, feverBonus),
		reason = if result.grade == "Miss" then CoreRules.missReason(result.reason) else nil,
		deltaMs = result.deltaMs,
		milestone = milestone,
		multiplier = Scoring.multiplierFor(combo),
		shielded = shielded,
		shieldReady = state.scoreState.shieldReady,
	})

	-- The rival watches this floor, so they get the verdict too.
	local rival = if backend ~= nil and backend.Multiplayer ~= nil then backend.Multiplayer:getRivalFor(player) else nil

	if rival ~= nil then
		rivalResultRemote:FireClient(rival, {
			x = step.x,
			y = step.y,
			grade = result.grade,
			fever = state.feverState.active == true,
		})
	end

	-- Complete on natural finish OR an early fail (life hit zero). Guard so the
	-- song only completes once.
	if not state.completed and (failed or state.session:isFinished()) then
		state.completed = true
		state.failedRun = failed

		if failed then
			-- Stop the heartbeat from judging any remaining steps.
			state.session.nextStepIndex = #state.session.map.steps + 1
		end

		local summary = ScoreSummary.fromState(state.scoreState, #state.session.map.steps, state.session.map.performanceGoal)
		summary.songId = state.session.map.id
		summary.songTitle = state.session.map.title
		summary.themeName = type(state.session.map.visualTheme) == "table" and state.session.map.visualTheme.name or nil
		summary.cleared = not failed
		summary.life = state.life
		summary.itemsTotal = #state.items
		summary.abilitiesUsed = if state.abilities ~= nil then state.abilities.activations else 0
		summary.tutorial = state.tutorial
		summary.drill = state.session.map.drill
		summary.suspicious = table.clone(state.suspicious)
		logRunStep(player, state, "finished")

		if not failed then
			logRunStep(player, state, "cleared")
		end

		if RunService:IsStudio() then
			print(playtestLine(player, state, summary))
		end
		local rewards = {}
		local multiplayerStatus = nil

		if backend ~= nil then
			rewards = backend.applySongComplete(player, summary)

			if backend.Multiplayer ~= nil then
				multiplayerStatus = backend.Multiplayer:buildStatusFor(player)
			end
		end

		songCompleteRemote:FireClient(player, {
			summary = summary,
			rewards = rewards,
			multiplayerStatus = multiplayerStatus,
			cleared = not failed,
		})
	end
end

-- Where the landing sat against the beat, in seconds, negative being early.
-- A claim counts only for the tile it named. With no claim, fall back to when
-- the server first saw the player, which runs late, so staying silent can never
-- earn a better grade than reporting honestly.
local function arrivalOffsetFor(state: any, step: any, targetTime: number, timingOffset: number, onTile: boolean): number?
	if not onTile then
		return nil
	end

	local targetClock = state.session.startTime + targetTime + timingOffset
	local arrival = state.ledger:arrivalOn(step.x, step.y, targetClock + Timing.LateArriveGrace)

	if arrival ~= nil then
		return arrival - targetClock
	end

	if state.coordEnteredAt ~= nil then
		return state.coordEnteredAt - targetClock
	end

	return nil
end

local function confirmedLandings(state: any): { CoreRules.Landing }
	local landings = {}

	for _, claim in state.ledger.claims do
		if claim.confirmed then
			table.insert(landings, claim)
		end
	end

	return landings
end

local function hasPendingLandingBy(state: any, latestLanding: number): boolean
	for _, claim in state.ledger.claims do
		if not claim.confirmed and claim.at <= latestLanding then
			return true
		end
	end

	return false
end

-- onBeat decides a note from where the player's steps put them when its beat
-- landed, so it waits until every step pressed by then (or within the late
-- grace) has been reported and confirmed. Returns nil while the note is open.
local function onBeatPlacement(state: any, step: any, beatClock: number, now: number): (any?, CoreRules.OnBeatPlacement?)
	if now < beatClock then
		return nil, nil
	end

	local difficulty = state.session.map.difficulty
	local stepSeconds = Timing.getStepSeconds(difficulty)
	local landing, placement = CoreRules.findOnBeatLanding(confirmedLandings(state), step.x, step.y, beatClock, difficulty)
	local latency = state.ledger.latency or Timing.OnBeatDefaultLatency
	local reportedBy = beatClock + stepSeconds + latency + Timing.OnBeatReportMargin
	local graceEnd = Timing.OnBeatLateGrace
	local pending = hasPendingLandingBy(state, beatClock + stepSeconds + graceEnd)

	if now >= beatClock + graceEnd + stepSeconds + Timing.Arrival.confirmSeconds then
		return landing, placement
	end

	if pending then
		return nil, nil
	end

	if placement == "late" or (placement == "onTile" and now >= reportedBy) or now >= reportedBy + graceEnd then
		return landing, placement
	end

	return nil, nil
end

-- With no step reported at or before the beat, only the server's own view can
-- place the player, and it never earns more than a stand's Great.
local function seenDelay(state: any): number
	local delay = state.ledger:getDelay() or Timing.SeenDelayDefault
	return math.clamp(delay, Timing.SeenDelayMin, Timing.SeenDelayMax)
end

local function seenOnTileBy(state: any, step: any, beatClock: number): boolean
	local seenAt = beatClock + seenDelay(state)
	local seen = nil

	for _, entry in state.coordHistory or {} do
		if entry.at > seenAt then
			break
		end

		seen = entry
	end

	return seen ~= nil and seen.x ~= nil and sameCoord(seen, step)
end

local function judgeOnBeatDanger(player: Player, state: any, step: any, stepIndex: number, beatClock: number, now: number): boolean
	local _, placement = onBeatPlacement(state, step, beatClock, now)

	if placement == nil then
		return false
	end

	local onDangerTile = placement == "onTile" or (placement == "unknown" and seenOnTileBy(state, step, beatClock))

	state.attemptedSteps[stepIndex] = true
	state.session:advance()
	finalizeStep(player, state, step, stepIndex, {
		accepted = not onDangerTile,
		grade = if onDangerTile then "Miss" else CoreRules.DodgeGrade,
		reason = if onDangerTile then "danger_tile" else "danger_avoided",
	}, now)

	return true
end

-- A zone beat resolves once a tile of it has the player on it, or once every
-- tile has been decided.
local function onBeatZonePlacement(state: any, zone: { any }, beatClock: number, now: number): (any?, CoreRules.OnBeatPlacement?)
	local open = false
	local lateLanding = nil
	local fallback: CoreRules.OnBeatPlacement = "unknown"

	for _, tile in zone do
		local landing, placement = onBeatPlacement(state, tile, beatClock, now)

		if placement == "onTile" then
			return landing, placement
		end

		if placement == nil then
			open = true
		elseif placement == "late" then
			lateLanding = lateLanding or landing
		elseif placement == "off" then
			fallback = "off"
		end
	end

	if open then
		return nil, nil
	end

	if lateLanding ~= nil then
		return lateLanding, "late"
	end

	return nil, fallback
end

local function judgeOnBeatZone(
	player: Player,
	state: any,
	step: any,
	stepIndex: number,
	zone: { any },
	beatClock: number,
	now: number
): boolean
	local landing, placement = onBeatZonePlacement(state, zone, beatClock, now)

	if placement == nil then
		return false
	end

	local difficulty = state.session.map.difficulty
	local result

	if landing ~= nil then
		landing.used = true

		local pressOffset = CoreRules.pressOf(landing, difficulty) - beatClock
		local grade = CoreRules.gradeZone(placement, pressOffset, difficulty)
		local pressed = placement == "late" or CoreRules.isTimedPress(pressOffset, difficulty)

		result = {
			accepted = grade ~= "Miss",
			grade = grade,
			reason = if pressed then "zone_step" else "zone_stand",
			deltaMs = if pressed then toMs(pressOffset + Timing.OnBeatLandDelay) else nil,
		}
	else
		local seen = false

		for _, tile in zone do
			seen = seen or (placement ~= "onTile" and seenOnTileBy(state, tile, beatClock))
		end

		local grade = CoreRules.gradeZone(placement, nil, difficulty, seen)
		local missed = if SongSchema.isShape(step) then "not_on_tile" else "outside_zone"

		result = {
			accepted = grade ~= "Miss",
			grade = grade,
			reason = if seen then "unreported_stand" elseif state.currentCoord == nil then "no_position" else missed,
		}
	end

	state.attemptedSteps[stepIndex] = true
	state.session:advance()
	finalizeStep(player, state, step, stepIndex, result, now)

	return true
end

-- A freeze beat is held when no step was pressed during it. The server's own
-- view backs the reports up: a move it saw with no step reported for it still
-- breaks the freeze, and is recorded.
local function judgeOnBeatFreeze(player: Player, state: any, step: any, stepIndex: number, beatClock: number, now: number): boolean
	local difficulty = state.session.map.difficulty
	local stepSeconds = Timing.getStepSeconds(difficulty)
	local latency = state.ledger.latency or Timing.OnBeatDefaultLatency
	local fromAt, toAt = CoreRules.freezeWindow(beatClock, Timing.beatSeconds(state.session.map.bpm))
	local deadline = toAt + Timing.OnBeatLateGrace + stepSeconds + Timing.Arrival.confirmSeconds

	if now < toAt + stepSeconds + latency + Timing.OnBeatReportMargin then
		return false
	end

	if hasPendingLandingBy(state, toAt + stepSeconds) and now < deadline then
		return false
	end

	local reported = CoreRules.brokeFreeze(confirmedLandings(state), fromAt, toAt, difficulty)
	local delay = (state.ledger:getDelay() or Timing.FreezeDefaultDelay) + Timing.Arrival.band
	local enteredAt = state.coordEnteredAt
	local seenMoving = enteredAt ~= nil and enteredAt > fromAt + stepSeconds + delay and enteredAt <= toAt + stepSeconds + delay

	if seenMoving and not reported then
		recordSuspicious(state, "unreported_move_in_freeze")
	end

	local grade = CoreRules.gradeFreeze(reported or seenMoving)

	if state.currentCoord == nil then
		grade = "Miss"
	end

	state.attemptedSteps[stepIndex] = true
	state.session:advance()
	finalizeStep(player, state, step, stepIndex, {
		accepted = grade ~= "Miss",
		grade = grade,
		reason = if state.currentCoord == nil then "no_position" elseif grade == "Miss" then "freeze_broken" else "freeze_held",
	}, now)

	return true
end

-- A pose is judged once it is over: on its tile when the beat landed, with no
-- step pressed until it ends. A move the server saw with no step reported
-- for it breaks the pose too, as it does a freeze.
local function judgeOnBeatPose(player: Player, state: any, step: any, stepIndex: number, beatClock: number, now: number): boolean
	local difficulty = state.session.map.difficulty
	local stepSeconds = Timing.getStepSeconds(difficulty)
	local beatSeconds = Timing.beatSeconds(state.session.map.bpm)
	local poseBeats = SongSchema.poseBeatsOf(step)
	local latency = state.ledger.latency or Timing.OnBeatDefaultLatency
	local fromAt, toAt = CoreRules.poseWindow(beatClock, poseBeats, beatSeconds)
	local deadline = toAt + Timing.OnBeatLateGrace + stepSeconds + Timing.Arrival.confirmSeconds

	if now < toAt + stepSeconds + latency + Timing.OnBeatReportMargin then
		return false
	end

	if hasPendingLandingBy(state, toAt + stepSeconds) and now < deadline then
		return false
	end

	local landings = confirmedLandings(state)
	local landing, placement = CoreRules.findOnBeatLanding(landings, step.x, step.y, beatClock, difficulty)
	local onTile = placement == "onTile" or seenOnTileBy(state, step, beatClock)
	local reported = CoreRules.brokePose(landings, beatClock, poseBeats, beatSeconds, difficulty)
	local delay = (state.ledger:getDelay() or Timing.FreezeDefaultDelay) + Timing.Arrival.band
	local enteredAt = state.coordEnteredAt
	local seenMoving = enteredAt ~= nil and enteredAt > fromAt + stepSeconds + delay and enteredAt <= toAt + stepSeconds + delay

	if seenMoving and not reported then
		recordSuspicious(state, "unreported_move_in_pose")
	end

	if landing ~= nil and placement == "onTile" then
		landing.used = true
	end

	local moved = reported or seenMoving
	local grade = if state.currentCoord == nil then "Miss" else CoreRules.gradePose(onTile, moved)
	local reason = "pose_held"

	if state.currentCoord == nil then
		reason = "no_position"
	elseif moved then
		reason = "pose_broken"
	elseif not onTile then
		reason = "not_on_tile"
	end

	state.attemptedSteps[stepIndex] = true
	state.session:advance()
	finalizeStep(player, state, step, stepIndex, {
		accepted = grade ~= "Miss",
		grade = grade,
		reason = reason,
	}, now)

	return true
end

-- A clap takes the nearest unused clap press; where the player stands does not matter.
local function judgeOnBeatClap(player: Player, state: any, step: any, stepIndex: number, beatClock: number, now: number): boolean
	local latency = state.ledger.latency or Timing.OnBeatDefaultLatency

	if now < beatClock + Timing.OnBeatLateGrace + latency + Timing.OnBeatReportMargin then
		return false
	end

	local press = CoreRules.findClapPress(state.ledger.claps, beatClock, Timing.beatSeconds(state.session.map.bpm))
	local offset = if press ~= nil then press.at - beatClock else nil
	local grade = CoreRules.gradeClap(offset, state.session.map.difficulty)

	if press ~= nil then
		press.used = true
	end

	state.attemptedSteps[stepIndex] = true
	state.session:advance()
	finalizeStep(player, state, step, stepIndex, {
		accepted = grade ~= "Miss",
		grade = grade,
		reason = if press ~= nil then "clap" else "no_clap",
		deltaMs = if offset ~= nil then toMs(offset) else nil,
	}, now)

	return true
end

local function onBeatResult(state: any, step: any, landing: any?, placement: CoreRules.OnBeatPlacement, beatClock: number): any
	local difficulty = state.session.map.difficulty
	local seen = placement ~= "onTile" and seenOnTileBy(state, step, beatClock)
	local verdict = CoreRules.judgeOnBeatNote(landing, placement, beatClock, difficulty, seen)

	if landing ~= nil then
		landing.used = true
	end

	if verdict.kind == "miss" then
		local late = CoreRules.arrivedLate(confirmedLandings(state), step.x, step.y, beatClock, Timing.beatSeconds(state.session.map.bpm), difficulty)

		return {
			accepted = false,
			grade = "Miss",
			reason = if state.currentCoord == nil then "no_position" elseif late then "too_late" else "not_on_tile",
		}
	end

	local standReason = if landing ~= nil then "on_tile_stand" else "unreported_stand"

	return {
		accepted = true,
		grade = verdict.grade,
		reason = if verdict.kind == "press" then "on_beat" elseif verdict.kind == "late" then "late_step" else standReason,
		deltaMs = if verdict.pressOffset ~= nil then toMs(verdict.pressOffset + Timing.OnBeatLandDelay) else nil,
	}
end

local function runFor(state: any, step: any, stepIndex: number): any?
	if not SongSchema.isRush(step) then
		return nil
	end

	local run = state.runs[step.rush]

	if run == nil then
		local group = SongSchema.rushGroup(state.session.map.steps, stepIndex)
		run = { first = group[1], last = group[#group], afterAt = nil }
		state.runs[step.rush] = run
	end

	return run
end

-- The server's own view of the run, for a step it never had reported.
local function seenRunLanding(state: any, step: any, afterAt: number, deadline: number): CoreRules.Landing?
	local delay = seenDelay(state)
	local seen = {}

	for _, entry in state.coordHistory or {} do
		if entry.x ~= nil then
			table.insert(seen, { x = entry.x, y = entry.y, at = entry.at - delay, used = false })
		end
	end

	return CoreRules.findRunLanding(seen, step.x, step.y, afterAt, deadline, state.session.map.difficulty)
end

-- A rush tile after the first is a hit the moment a confirmed landing reaches
-- it in order; a Miss waits for the run's deadline and every report due by then.
local function judgeRunTile(
	player: Player,
	state: any,
	step: any,
	stepIndex: number,
	run: any,
	timingOffset: number,
	now: number
): boolean
	local session = state.session
	local difficulty = session.map.difficulty

	local function clockOf(runStep: any): number
		return session.startTime + session:getStepTargetTime(runStep) + timingOffset
	end

	local deadline = CoreRules.runDeadline(clockOf(run.last))
	local afterAt = run.afterAt or clockOf(run.first)
	local landing = CoreRules.findRunLanding(confirmedLandings(state), step.x, step.y, afterAt, deadline, difficulty)

	if landing == nil then
		local stepSeconds = Timing.getStepSeconds(difficulty)
		local latency = state.ledger.latency or Timing.OnBeatDefaultLatency
		local reportedBy = deadline + stepSeconds + latency + Timing.OnBeatReportMargin
		local cutoff = deadline + stepSeconds + Timing.Arrival.confirmSeconds

		if now < cutoff and (now < reportedBy or hasPendingLandingBy(state, deadline + stepSeconds)) then
			return false
		end

		landing = seenRunLanding(state, step, afterAt, deadline)
	end

	if landing ~= nil then
		landing.used = true
		run.afterAt = landing.at
	end

	local reached = landing ~= nil

	state.attemptedSteps[stepIndex] = true
	session:advance()
	finalizeStep(player, state, step, stepIndex, {
		accepted = reached,
		grade = CoreRules.gradeRunTile(reached),
		reason = if reached then "run_reached" elseif state.currentCoord == nil then "no_position" else "missed_run",
	}, now)

	return true
end

-- Holds and slides start like any onBeat note, from the landing; a hold then
-- has to be stood on to its end and a slide must have crossed its whole path.
local function judgeOnBeat(
	player: Player,
	state: any,
	step: any,
	stepIndex: number,
	targetTime: number,
	timingOffset: number,
	now: number
): boolean
	local beatClock = state.session.startTime + targetTime + timingOffset

	if step.type == "danger" then
		return judgeOnBeatDanger(player, state, step, stepIndex, beatClock, now)
	end

	if SongSchema.isFreeze(step) then
		return judgeOnBeatFreeze(player, state, step, stepIndex, beatClock, now)
	end

	if SongSchema.isPose(step) then
		return judgeOnBeatPose(player, state, step, stepIndex, beatClock, now)
	end

	if SongSchema.isClap(step) then
		return judgeOnBeatClap(player, state, step, stepIndex, beatClock, now)
	end

	local zone = SongSchema.zoneOf(step)

	if zone ~= nil then
		return judgeOnBeatZone(player, state, step, stepIndex, zone, beatClock, now)
	end

	local run = runFor(state, step, stepIndex)

	if run ~= nil and run.first ~= step then
		return judgeRunTile(player, state, step, stepIndex, run, timingOffset, now)
	end

	local landing, placement = onBeatPlacement(state, step, beatClock, now)

	if placement == nil then
		return false
	end

	state.attemptedSteps[stepIndex] = true

	local result = onBeatResult(state, step, landing, placement, beatClock)

	if run ~= nil then
		run.afterAt = CoreRules.runStartAt(landing, beatClock)
	end

	if result.accepted and step.type == "hold" then
		state.holding = {
			step = step,
			stepIndex = stepIndex,
			grade = result.grade,
			deltaMs = result.deltaMs,
			startRawElapsed = targetTime + timingOffset,
			endRawElapsed = targetTime + (tonumber(step.holdSeconds) or 0.35) + timingOffset,
		}

		return true
	end

	if result.accepted and step.type == "slide" and type(step.path) == "table" then
		local tracking = state.slideTracking

		if tracking == nil or tracking.stepIndex ~= stepIndex or tracking.pathPos < #step.path then
			result = {
				accepted = true,
				grade = "Good",
				reason = "slide_path_incomplete",
				deltaMs = result.deltaMs,
				withholdTypeBonus = true,
			}
		end
	end

	state.session:advance()
	finalizeStep(player, state, step, stepIndex, result, now)

	return true
end

-- Highway notes are judged by the nearest press on their lane. A danger note is
-- a mine: pressing its lane near the beat is the Miss. Holds count as taps in
-- this prototype. Returns false while the note is still open.
local function judgeHighway(
	player: Player,
	state: any,
	step: any,
	stepIndex: number,
	targetTime: number,
	timingOffset: number,
	elapsed: number,
	now: number
): boolean
	local difficulty = state.session.map.difficulty
	local windows = Timing.getWindows(difficulty)
	local targetClock = state.session.startTime + targetTime + timingOffset
	local isMine = step.type == "danger"
	local holdSeconds = if step.type == "hold" then tonumber(step.holdSeconds) or 0 else 0
	local holding = state.highwayHold

	-- A hold whose head was pressed stays open until it is let go or runs out.
	if holding ~= nil and holding.stepIndex == stepIndex then
		local endClock = targetClock + holdSeconds
		local release = state.ledger:releaseBetween(step.x, holding.pressAt, endClock - Timing.HoldReleaseGrace)

		if release == nil and elapsed < targetTime + holdSeconds + Timing.HoldReleaseGrace then
			return false
		end

		local heldFraction = if release ~= nil
			then (release - math.max(holding.pressAt, targetClock)) / math.max(holdSeconds, 0.001)
			else 1
		local grade = CoreRules.gradeHold(holding.grade, heldFraction)

		state.highwayHold = nil
		state.attemptedSteps[stepIndex] = true
		state.session:advance()
		finalizeStep(player, state, step, stepIndex, {
			accepted = grade ~= "Miss",
			grade = grade,
			reason = if release ~= nil then "hold_released_early" else "hold_completed",
			deltaMs = holding.deltaMs,
			withholdTypeBonus = release ~= nil,
		}, now)

		return true
	end

	local window = if isMine then windows.perfectWindow else windows.goodWindow
	local press = state.ledger:nearestUnused(step.x, 1, targetClock, window)

	if press == nil and elapsed < targetTime + window + Timing.PressReportAllowance then
		return false
	end

	if press ~= nil then
		press.used = true
	end

	if press ~= nil and holdSeconds > 0 then
		local offset = press.at - targetClock

		state.highwayHold = {
			stepIndex = stepIndex,
			pressAt = press.at,
			grade = CoreRules.grade(CoreRules.Modes.Highway, offset, 0, Timing.beatSeconds(state.session.map.bpm), difficulty),
			deltaMs = toMs(offset),
		}

		return false
	end

	state.attemptedSteps[stepIndex] = true
	state.session:advance()

	local result

	if isMine then
		result = {
			accepted = press == nil,
			grade = if press == nil then "Perfect" else "Miss",
			reason = if press == nil then "mine_avoided" else "hit_mine",
		}
	else
		local offset = if press ~= nil then press.at - targetClock else nil
		local grade = CoreRules.grade(CoreRules.Modes.Highway, offset, 0, Timing.beatSeconds(state.session.map.bpm), difficulty)

		result = {
			accepted = grade ~= "Miss",
			grade = grade,
			reason = if press ~= nil then "pressed" else "no_press",
			deltaMs = if offset ~= nil then toMs(offset) else nil,
		}
	end

	finalizeStep(player, state, step, stepIndex, result, now)

	return true
end

-- Report times are plain server-clock times, so the arrival checks stay honest;
-- how far the player's music runs from the planned start moves the beat instead,
-- clamped to the client's own follow limits, as the timing offset is.
local function noteMusicShift(state: any, payload: any)
	local shift = tonumber(payload.s)

	if shift ~= nil and shift == shift then
		state.musicShift = math.clamp(shift, -Timing.AudioFollowLimitSeconds, Timing.AudioLeadLimitSeconds)
	end
end

local function judgedOffset(player: Player, state: any): number
	return getTimingOffsetState(player).offset - (state.musicShift or 0)
end

local function processDueSteps(player: Player, state: any, now: number)
	local timingOffset = judgedOffset(player, state)

	while not state.session:isFinished() do
		local step = state.session:getCurrentStep()

		if step == nil then
			return
		end

		-- Per-player latency calibration shifts every judgement, including
		-- the expired-miss deadline.
		local elapsed = state.session:getElapsed(now) - timingOffset
		local targetTime = state.session:getStepTargetTime(step)
		local stepIndex = state.session.nextStepIndex

		if state.coreMode == CoreRules.Modes.Highway then
			if not judgeHighway(player, state, step, stepIndex, targetTime, timingOffset, elapsed, now) then
				return
			end

			continue
		end

		if state.coreMode == CoreRules.Modes.OnBeat then
			if not judgeOnBeat(player, state, step, stepIndex, targetTime, timingOffset, now) or state.holding ~= nil then
				return
			end

			continue
		end

		if step.type == "danger" then
			-- Danger steps are judged by avoidance: once the beat lands, players
			-- standing clear of the danger tile succeed without needing an input.
			if elapsed < targetTime + Timing.PerfectWindow then
				return
			end

			state.attemptedSteps[stepIndex] = true
			state.session:advance()

			local onDangerTile = sameCoord(state.currentCoord, step)

			finalizeStep(player, state, step, stepIndex, {
				accepted = not onDangerTile,
				grade = onDangerTile and "Miss" or "Perfect",
				reason = onDangerTile and "danger_tile" or "danger_avoided",
			}, now)
		elseif step.type == "hold" or step.type == "slide" then
			-- Holds/slides still need the player to start them with an input; if
			-- none arrives by the Bad window, they expire as a miss.
			if elapsed <= targetTime + Timing.BadWindow + Timing.HoldStartExpiryGrace then
				return
			end

			state.attemptedSteps[stepIndex] = true
			state.session:advance()
			finalizeStep(player, state, step, stepIndex, {
				accepted = false,
				grade = "Miss",
				reason = "expired",
			}, now)
		else
			-- Plain "stand and wait" step: judged the moment the beat lands by
			-- where the player is standing and how long they settled there. No
			-- tap needed -- walk to the telegraphed tile during the travel window
			-- and let the beat land on you (Zhong's core-loop redesign).
			if elapsed < targetTime then
				return
			end

			local onTile = sameCoord(state.currentCoord, step)

			-- Late-arrival grace: if the player isn't on the tile the instant the
			-- beat lands, give them a short window (Timing.LateArriveGrace) to still
			-- arrive (counts as Good) before it misses -- grounded in the ~135-150 ms
			-- outer hit window common to osu!/mania, adapted for a movement game.
			-- A report for this tile not yet matched to a position means the
			-- player most likely got there; wait for the position to catch up.
			local reportPending = state.coreMode == CoreRules.Modes.ArriveOnTime
				and state.ledger:hasPending(step.x, step.y)

			if not onTile and (elapsed < targetTime + Timing.LateArriveGrace or reportPending) then
				return
			end

			state.attemptedSteps[stepIndex] = true
			state.session:advance()

			local settleSeconds = (onTile and state.coordEnteredAt ~= nil)
					and math.max(now - state.coordEnteredAt, 0)
				or 0
			local beatSeconds = Timing.beatSeconds(state.session.map.bpm)
			local mode = state.coreMode or CoreRules.Default
			local grade, landingOffset

			if mode == CoreRules.Modes.StandWait then
				grade = Timing.gradeStandAndWait(onTile, settleSeconds, beatSeconds)
			else
				landingOffset = arrivalOffsetFor(state, step, targetTime, timingOffset, onTile)
				grade = CoreRules.grade(mode, landingOffset, settleSeconds, beatSeconds, state.session.map.difficulty)
			end

			finalizeStep(player, state, step, stepIndex, {
				accepted = grade ~= "Miss",
				grade = grade,
				reason = onTile and "stand_hit" or "not_on_tile",
				deltaMs = if landingOffset ~= nil then toMs(landingOffset) else nil,
			}, now)
		end
	end
end

-- Items sit beside the notes and are judged like an onBeat note on their tile,
-- but a skipped one costs nothing and neither touches the combo.
local function processDueItems(player: Player, state: any, now: number)
	local timingOffset = judgedOffset(player, state)

	while true do
		local index = state.nextItemIndex
		local item = state.items[index]

		if item == nil then
			return
		end

		local beatClock = state.session.startTime + state.session:getStepTargetTime(item) + timingOffset
		local _, placement = onBeatPlacement(state, item, beatClock, now)

		if placement == nil then
			return
		end

		state.nextItemIndex = index + 1

		if not CoreRules.collectsItem(placement, seenOnTileBy(state, item, beatClock)) then
			itemResultRemote:FireClient(player, { itemIndex = index, x = item.x, y = item.y, collected = false })
			continue
		end

		local bonus = Scoring.applyItem(state.scoreState)
		state.hype = CrowdHype.boost(state.hype, CrowdHype.ItemGain)
		FeverSystem.extend(state.feverState, FeverSystem.ItemExtendSeconds, now)
		local feverStarted = FeverSystem.tryActivate(state.feverState, state.scoreState.combo, state.hype, now)
		state.scoreState.feverActivations = state.feverState.activations or 0

		local backend = getBackend()

		if backend ~= nil and backend.Multiplayer ~= nil then
			backend.Multiplayer:updateScore(player, state.scoreState.score, state.scoreState.combo, state.hype)
		end

		itemResultRemote:FireClient(player, {
			itemIndex = index,
			x = item.x,
			y = item.y,
			collected = true,
			bonus = bonus,
			score = state.scoreState.score,
			hype = state.hype,
			fever = FeverSystem.snapshot(state.feverState, now, feverStarted, 0),
		})
	end
end

local function updateHolding(player: Player, state: any, now: number)
	local holding = state.holding

	if holding == nil then
		return
	end

	local rawElapsed = state.session:getElapsed(now)

	if rawElapsed >= holding.endRawElapsed then
		-- Hold completed: finalize with the timing grade from the initial hit.
		state.holding = nil
		state.session:advance()
		finalizeStep(player, state, holding.step, holding.stepIndex, {
			accepted = true,
			grade = holding.grade,
			reason = "hold_completed",
			deltaMs = holding.deltaMs,
		}, now)

		return
	end

	if sameCoord(state.currentCoord, holding.step) then
		return
	end

	local requiredDuration = math.max(holding.endRawElapsed - holding.startRawElapsed, 0.001)
	local heldFraction = (rawElapsed - holding.startRawElapsed) / requiredDuration

	local grade = CoreRules.gradeHold(holding.grade, heldFraction)

	state.holding = nil
	state.session:advance()
	finalizeStep(player, state, holding.step, holding.stepIndex, {
		accepted = grade ~= "Miss",
		grade = grade,
		reason = if grade == "Miss" then "hold_released_too_early" else "hold_released_early",
		deltaMs = holding.deltaMs,
		withholdTypeBonus = grade ~= "Miss",
	}, now)
end

local function updateSlideTracking(state: any, now: number)
	local session = state.session
	local elapsed = session:getElapsed(now)
	local bpm = tonumber(session.map.bpm)
	local beatSeconds = Timing.beatSeconds(bpm)
	local leadSeconds = math.max(2 * beatSeconds, 0.9)

	-- Slide paths can start on tiles the player must cross while earlier
	-- steps are still current, so scan pending steps for the nearest slide
	-- whose telegraph window has opened instead of waiting for it to become
	-- the current step.
	local slideStep = nil
	local slideIndex = nil
	local index = session.nextStepIndex

	while true do
		local step = session:getStep(index)

		if step == nil or elapsed < session:getStepTargetTime(step) - leadSeconds then
			break
		end

		if step.type == "slide" and type(step.path) == "table" then
			slideStep = step
			slideIndex = index

			break
		end

		index += 1
	end

	if slideStep == nil then
		state.slideTracking = nil

		return
	end

	if state.slideTracking == nil or state.slideTracking.stepIndex ~= slideIndex then
		state.slideTracking = {
			stepIndex = slideIndex,
			pathPos = 0,
		}
	end

	local coord = state.currentCoord

	if coord == nil then
		return
	end

	local tracking = state.slideTracking
	local nextTile = slideStep.path[tracking.pathPos + 1]

	if sameCoord(coord, nextTile) then
		tracking.pathPos += 1
	end
end

-- Per-player payload: each song carries locked state + unlock requirement.
local function sendSongCatalog(player: Player)
	local backend = getBackend()

	if backend ~= nil and backend.sendSongCatalog ~= nil then
		backend.sendSongCatalog(player)
		return
	end

	songCatalogRemote:FireClient(player, SongCollection.buildCatalogPayload(nil))
end

-- A shared start time puts every player in a match on the same beat.
local function startSession(player: Player, songId: string?, sharedStartTime: number?)
	local map = if songId ~= nil then SongMapCatalog.getTutorialDrill(songId) or SongMapCatalog.getMap(songId) else nil

	if map == nil then
		map = SongMapCatalog.getDefaultMap()
	end

	local countdownSeconds = if map.tutorial == true then Timing.LessonCountdownSeconds else Timing.CountdownSeconds
	local startTime = sharedStartTime or (os.clock() + countdownSeconds)

	-- Set before any floor maths: the layout decides tile size and floor spacing.
	local layoutAttribute = Workspace:GetAttribute("BoardLayout")
	local layoutId = BoardLayouts.get(if type(layoutAttribute) == "string" then layoutAttribute else nil).id
	local coreMode = CoreRules.resolveMode(Workspace:GetAttribute("CoreMode"))
	Board.setLayout(layoutId)

	-- Items are pickups on the pad; every other floor and the highway play without them.
	local notes, items = SongSchema.splitItems(map.steps)

	if #items > 0 then
		map = table.clone(map)
		map.steps = notes
	end

	local padFloor = coreMode == CoreRules.Modes.OnBeat and layoutId == BoardLayouts.Default
	local events = if padFloor and type(map.events) == "table" then map.events else nil

	if not padFloor then
		items = {}

		map = table.clone(map)
		map.steps = SongSchema.withoutEvents(map.steps)
	end

	-- In the highway the floor is only the stage, so the chart goes onto lanes
	-- whatever shape the floor is.
	map = mapForLayout(map, if coreMode == CoreRules.Modes.Highway then HIGHWAY_LAYOUT else layoutId)

	local backend = getBackend()
	local multiplayer = if backend ~= nil then backend.Multiplayer else nil
	local now = os.clock()
	local slot, slotCount = 1, 1

	if multiplayer ~= nil then
		slot, slotCount = multiplayer:getFloorFor(player)
	end

	local origin = Board.originFor(slot, slotCount)
	local rivalOrigin = if slotCount == 2 then Board.originFor(3 - slot, slotCount) else nil

	moveToFloor(player, origin)

	sessions[player] = {
		origin = origin,
		session = RhythmSession.new(map, startTime),
		selectedSongId = map.id,
		scoreState = Scoring.createState(),
		feverState = FeverSystem.createState(),
		hype = 0,
		life = LifeGauge.Start,
		completed = false,
		paused = false,
		attemptedSteps = {},
		currentCoord = getPlayerBoardCoord(player, origin),
		coordEnteredAt = now,
		coordHistory = {},
		suspicious = {},
		coreMode = coreMode,
		boardLayout = layoutId,
		ledger = ArrivalLedger.new(ARRIVAL_CONFIG),
		highwayHold = nil,
		lastLandingAt = nil,
		deltas = {},
		missReasons = {},
		runs = {},
		items = items,
		nextItemIndex = 1,
		tutorial = map.tutorial == true,
		funnelSessionId = HttpService:GenerateGUID(false),
		funnelFirstHit = false,
		funnelHalfway = false,
	}

	local started = sessions[player]

	if started.currentCoord ~= nil then
		table.insert(started.coordHistory, { x = started.currentCoord.x, y = started.currentCoord.y, at = now })
	end

	startSongRemote:FireClient(player, {
		songId = map.id,
		title = map.title,
		artist = map.artist,
		bpm = map.bpm,
		difficulty = map.difficulty,
		steps = map.steps,
		durationSeconds = map.durationSeconds,
		countdownSeconds = countdownSeconds,
		serverStartTime = startTime,
		startSharedTime = startTime - os.clock() + Workspace:GetServerTimeNow(),
		performanceGoal = map.performanceGoal,
		slot = slot,
		slotCount = slotCount,
		boardOrigin = origin,
		rivalOrigin = rivalOrigin,
		boardLayout = layoutId,
		coreMode = sessions[player].coreMode,
		items = items,
		sections = map.sections,
		events = events,
		lesson = map.lesson,
		tutorial = started.tutorial,
	})

	local profile = getProfile(player)
	abilityService:begin(player, started, if profile ~= nil then profile.abilityLoadout else nil, not started.tutorial)
	logRunStep(player, started, "started", "tutorial_started")

	if not started.tutorial and backend ~= nil and backend.Funnels ~= nil then
		backend.Funnels:onboarding(player, "first_song_started")
	end

	if backend ~= nil and backend.Multiplayer ~= nil then
		backend.Multiplayer:updateScore(player, 0, 0, 0)
	end
end

-- Starts one song for everyone in a match, on the same start time.
local function startMatchSong(players: { Player }, songId: string?)
	local startTime = os.clock() + Timing.CountdownSeconds

	for _, matchPlayer in players do
		if matchPlayer.Parent == Players then
			startSession(matchPlayer, songId, startTime)
		end
	end
end

-- A rematch plays the host's last song again for both players.
local function ensureMatchHooks()
	local backend = getBackend()
	local multiplayer = if backend ~= nil then backend.Multiplayer else nil

	if multiplayer == nil or multiplayer.onRematch ~= nil then
		return
	end

	multiplayer.onRematch = function(players: { Player })
		local hostState = sessions[players[1]]

		startMatchSong(players, if hostState ~= nil then hostState.selectedSongId else nil)
	end
end

-- Only the host picks or restarts a song in a match; it starts for both players.
local function getMatchPlayers(player: Player): { Player }
	local backend = getBackend()

	if backend ~= nil and backend.Multiplayer ~= nil then
		return backend.Multiplayer:getMatchPlayers(player)
	end

	return { player }
end

Players.PlayerAdded:Connect(function(player)
	ensureMatchHooks()

	task.delay(1, function()
		if player.Parent == Players then
			sendSongCatalog(player)
			syncTimingOffset(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	timingOffsets[player] = nil
	rateLimiter:clear(player)
end)

requestRestartRemote.OnServerEvent:Connect(function(player)
	if not rateLimiter:allow(player, "RequestRestart", RemoteContract.Events.RequestRestart.rateLimitPerSecond) then
		return
	end

	if player.Parent ~= Players then
		return
	end

	local players = getMatchPlayers(player)
	local hostState = sessions[players[1]]
	local songId = if hostState ~= nil then hostState.selectedSongId else nil

	if #players == 1 then
		startSession(player, songId)
	elseif players[1] == player then
		startMatchSong(players, songId)
	end
end)

-- Leaving the stage in a hub place. A solo run left mid-song is dropped and pays
-- nothing; a match run cannot be left, or the rival would be stranded.
returnToHubRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ReturnToHub", RemoteContract.Events.ReturnToHub.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local state = sessions[player]
	local backend = getBackend()

	if state ~= nil and not state.completed then
		if #getMatchPlayers(player) > 1 then
			return
		end

		sessions[player] = nil

		-- Walking out of the lesson is skipping it.
		if state.tutorial and backend ~= nil and backend.Onboarding ~= nil then
			backend.Onboarding:completeTutorial(player, false)
		end
	end

	if backend ~= nil and backend.Stations ~= nil then
		backend.Stations:returnToHub(player)
	end
end)

-- Pause / resume (issue 041): freezes the beat timeline by shifting the session
-- start time forward by the paused duration. Server-authoritative; disallowed in
-- an active 2-player match.
requestPauseRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RequestPause", RemoteContract.Events.RequestPause.rateLimitPerSecond) then
		return
	end

	local state = sessions[player]

	if state == nil or state.completed or state.session:isFinished() then
		return
	end

	local backend = getBackend()

	if backend ~= nil and backend.Multiplayer ~= nil then
		local status = backend.Multiplayer:buildStatusFor(player)

		if type(status) == "table" and status.playerCount == 2 then
			-- No pausing in competitive/co-op play.
			pauseStateRemote:FireClient(player, { paused = false })
			return
		end
	end

	local wantPaused = type(payload) == "table" and payload.paused == true
	local now = os.clock()

	if wantPaused and not state.paused then
		state.paused = true
		state.pauseStartedAt = now
	elseif not wantPaused and state.paused then
		state.session.startTime += now - (state.pauseStartedAt or now)
		state.paused = false
		state.pauseStartedAt = nil
	end

	pauseStateRemote:FireClient(player, { paused = state.paused })
end)

requestSongRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RequestSong", RemoteContract.Events.RequestSong.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.songId) ~= "string" then
		return
	end

	if player.Parent ~= Players or SongMapCatalog.getMap(payload.songId) == nil then
		return
	end

	-- Locked songs are server-rejected; the client gates selection too.
	if not SongCollection.isUnlocked(payload.songId, getProfile(player)) then
		return
	end

	ensureMatchHooks()

	local players = getMatchPlayers(player)

	if #players == 1 then
		startSession(player, payload.songId)
		return
	end

	-- In a match the host picks, and the song has to be open to both players.
	if players[1] ~= player then
		return
	end

	for _, matchPlayer in players do
		if not SongCollection.isUnlocked(payload.songId, getProfile(matchPlayer)) then
			return
		end
	end

	startMatchSong(players, payload.songId)
end)

-- A first-join lesson drill: solo only, never over a run in progress, and only
-- the next drill not yet passed (or one already passed).
startTutorialRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "StartTutorial", RemoteContract.Events.StartTutorial.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.drill) ~= "number" or player.Parent ~= Players then
		return
	end

	local state = sessions[player]
	local backend = getBackend()

	if (state ~= nil and not state.completed) or #getMatchPlayers(player) > 1 then
		return
	end

	if backend == nil or backend.Onboarding == nil or not backend.Onboarding:canStartDrill(player, payload.drill) then
		return
	end

	startSession(player, TutorialChart.drillId(payload.drill))
end)

skipTutorialRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SkipTutorial", RemoteContract.Events.SkipTutorial.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local state = sessions[player]

	if state ~= nil and state.tutorial and not state.completed then
		sessions[player] = nil
	end

	local backend = getBackend()

	if backend ~= nil and backend.Onboarding ~= nil then
		backend.Onboarding:completeTutorial(player, false)
	end
end)

submitHitRemote.OnServerEvent:Connect(function(player, payload)
	local state = sessions[player]

	if state == nil or type(payload) ~= "table" then
		return
	end

	if not rateLimiter:allow(player, "SubmitHit", RemoteContract.Events.SubmitHit.rateLimitPerSecond) then
		return
	end

	-- onBeat starts holds and slides from the landing, like every other note.
	if state.coreMode == CoreRules.Modes.OnBeat then
		return
	end

	local now = os.clock()
	updatePositionAudit(player, state, now)
	updateSlideTracking(state, now)

	if tonumber(payload.stepIndex) ~= state.session.nextStepIndex then
		recordSuspicious(state, "stale_or_future_step_index")
		return
	end

	local step = state.session:getCurrentStep()

	if step == nil then
		return
	end

	-- Plain steps use stand-and-wait: they are judged by where the player is
	-- standing when the beat lands (see processDueSteps), so taps for them are
	-- ignored here. Only holds and slides are started via an input.
	if step.type ~= "hold" and step.type ~= "slide" then
		return
	end

	if state.attemptedSteps[state.session.nextStepIndex] then
		recordSuspicious(state, "repeated_step_attempt")
		return
	end

	state.attemptedSteps[state.session.nextStepIndex] = true

	local stepIndex = state.session.nextStepIndex
	local timingOffset = judgedOffset(player, state)
	local hitTime = state.session:getElapsed(now) - timingOffset
	local targetTime = state.session:getStepTargetTime(step)
	local hitCoord = state.currentCoord
	local result

	if hitCoord == nil then
		-- Never fabricate a coordinate for a player who is off the board or
		-- has no character; the submission is judged as a miss.
		result = {
			accepted = false,
			grade = "Miss",
			reason = "no_position",
		}
		recordSuspicious(state, "no_position")
	else
		result = HitValidator.validate(step, hitCoord, hitTime, targetTime)
	end

	local dwellTime = state.coordEnteredAt ~= nil and now - state.coordEnteredAt or 0

	if result.accepted and dwellTime < Timing.MinTileDwellSeconds then
		result = {
			accepted = false,
			grade = "Miss",
			reason = "tile_dwell_too_short",
		}
		recordSuspicious(state, "tile_dwell_too_short")
	end

	-- Signed early/late feedback for the HUD, after latency calibration.
	result.deltaMs = toMs(hitTime - targetTime)

	if result.accepted and step.type == "hold" then
		-- A hold is not finalized at tap time: the session heartbeat verifies
		-- the player stays on the tile until targetTime + holdSeconds and only
		-- then fires HitResult, so the session does not advance yet.
		local holdSeconds = tonumber(step.holdSeconds) or 0.35

		state.holding = {
			step = step,
			stepIndex = stepIndex,
			grade = result.grade,
			deltaMs = result.deltaMs,
			startRawElapsed = state.session:getElapsed(now),
			endRawElapsed = targetTime + holdSeconds + timingOffset,
		}

		return
	end

	if result.accepted and step.type == "slide" and type(step.path) == "table" then
		local tracking = state.slideTracking
		local pathComplete = tracking ~= nil
			and tracking.stepIndex == stepIndex
			and tracking.pathPos >= #step.path

		if not pathComplete then
			-- Reached the end tile in time but skipped path tiles: downgrade
			-- to Good and withhold the slide completion bonus.
			result = {
				accepted = true,
				grade = "Good",
				reason = "slide_path_incomplete",
				deltaMs = result.deltaMs,
				withholdTypeBonus = true,
			}
		end
	end

	state.session:advance()
	finalizeStep(player, state, step, stepIndex, result, now)
end)

-- The client reports when its own step landed, because the replicated position
-- the server watches arrives 140-300 ms late, far too coarse to grade against a
-- beat. The claim is only trusted when it sits close to this player's running
-- delay estimate, which caps what shifting a claim can buy.
reportArrivalRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ReportArrival", RemoteContract.Events.ReportArrival.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local x = tonumber(payload.x)
	local y = tonumber(payload.y)
	local claimedSync = tonumber(payload.t)

	if x == nil or y == nil or claimedSync == nil or claimedSync ~= claimedSync then
		return
	end

	if not Board.isValidCoord(x, y) then
		return
	end

	local state = sessions[player]

	if state == nil or state.completed or state.paused then
		return
	end

	noteMusicShift(state, payload)

	local now = os.clock()
	updatePositionAudit(player, state, now)

	-- GetServerTimeNow shares one base across server and clients; os.clock does
	-- not, so convert the claim into the clock the session is judged on.
	local clockShift = now - Workspace:GetServerTimeNow()
	local claimed = claimedSync + clockShift
	local onBeat = state.coreMode == CoreRules.Modes.OnBeat
	local stepSeconds = Timing.getStepSeconds(state.session.map.difficulty)
	local previousLanding = state.lastLandingAt

	-- onBeat judges the press, so a step quicker than a step-time would let a
	-- late press pass as an earlier one.
	if onBeat and previousLanding ~= nil and claimed - previousLanding < stepSeconds - Timing.OnBeatStepTolerance then
		recordSuspicious(state, "step_faster_than_step_time")
		return
	end

	local pressAt = nil
	local claimedPress = tonumber(payload.p)

	if onBeat and claimedPress ~= nil then
		local press = claimedPress + clockShift
		local lead = claimed - press

		if press ~= press or lead < stepSeconds - Timing.OnBeatStepTolerance or lead > Timing.OnBeatMaxPressLead then
			recordSuspicious(state, "implausible_press_time")
		else
			-- A buffered press counts from when its step could start, as in the
			-- Music Game, so pressing early into the buffer is never judged early.
			pressAt = if previousLanding ~= nil then math.max(press, previousLanding) else press
		end
	end

	local refused = state.ledger:submit(x, y, claimed, now, state.currentCoord, state.coordEnteredAt)

	if refused == nil then
		local claim = state.ledger.claims[#state.ledger.claims]
		state.lastLandingAt = claim.at
		claim.pressAt = if pressAt ~= nil then pressAt + (claim.at - claimed) else nil
	end

	if refused ~= nil then
		recordSuspicious(state, refused)
	end
end)

submitPressRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SubmitPress", RemoteContract.Events.SubmitPress.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local lane = tonumber(payload.lane)
	local claimedSync = tonumber(payload.t)

	if lane == nil or claimedSync == nil or claimedSync ~= claimedSync then
		return
	end

	if lane ~= math.floor(lane) or lane < 1 or lane > HIGHWAY_LANES then
		return
	end

	local state = sessions[player]

	if state == nil or state.completed or state.paused or state.coreMode ~= CoreRules.Modes.Highway then
		return
	end

	noteMusicShift(state, payload)

	local now = os.clock()
	local claimed = claimedSync + (now - Workspace:GetServerTimeNow())
	local refused = state.ledger:submitPress(lane, claimed, now)

	if refused ~= nil then
		recordSuspicious(state, refused)
	end
end)

submitReleaseRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SubmitRelease", RemoteContract.Events.SubmitRelease.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local lane = tonumber(payload.lane)
	local claimedSync = tonumber(payload.t)

	if lane == nil or claimedSync == nil or claimedSync ~= claimedSync then
		return
	end

	if lane ~= math.floor(lane) or lane < 1 or lane > HIGHWAY_LANES then
		return
	end

	local state = sessions[player]

	if state == nil or state.completed or state.paused or state.coreMode ~= CoreRules.Modes.Highway then
		return
	end

	noteMusicShift(state, payload)

	local now = os.clock()
	local claimed = claimedSync + (now - Workspace:GetServerTimeNow())
	local refused = state.ledger:submitRelease(lane, claimed, now)

	if refused ~= nil then
		recordSuspicious(state, refused)
	end
end)

submitClapRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SubmitClap", RemoteContract.Events.SubmitClap.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local claimedSync = tonumber(payload.t)

	if claimedSync == nil or claimedSync ~= claimedSync then
		return
	end

	local state = sessions[player]

	if state == nil or state.completed or state.paused then
		return
	end

	if state.coreMode ~= CoreRules.Modes.OnBeat or state.boardLayout ~= BoardLayouts.Default then
		recordSuspicious(state, "clap_off_pad")
		return
	end

	noteMusicShift(state, payload)

	local now = os.clock()
	local claimed = claimedSync + (now - Workspace:GetServerTimeNow())
	local refused = state.ledger:submitClap(claimed, now)

	if refused ~= nil then
		recordSuspicious(state, refused)
	end
end)

setTimingOffsetRemote.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then
		return
	end

	if not rateLimiter:allow(player, "SetTimingOffset", RemoteContract.Events.SetTimingOffset.rateLimitPerSecond) then
		return
	end

	local offset = tonumber(payload.offsetSeconds)

	if offset == nil or offset ~= offset then
		return
	end

	offset = math.clamp(offset, -Timing.MaxTimingOffsetSeconds, Timing.MaxTimingOffsetSeconds)

	local entry = getTimingOffsetState(player)

	if payload.deviceDefault == true then
		-- Device defaults never override a saved or manual calibration.
		if not entry.calibrated then
			entry.offset = offset
		end
	else
		entry.offset = offset
		entry.calibrated = true

		local profile = getProfile(player)

		if profile ~= nil then
			if type(profile.settings) ~= "table" then
				profile.settings = {}
			end

			profile.settings.timingOffsetSeconds = entry.offset
			profile.settings.timingOffsetCalibrated = true
			getBackend().PlayerData:markDirty(player)
		end
	end

	syncTimingOffset(player)
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for player, state in sessions do
		if player.Parent == Players and state.session ~= nil and not state.session:isFinished() and not state.paused then
			updatePositionAudit(player, state, now)

			for _, reason in state.ledger:expire(now) do
				recordSuspicious(state, reason)
			end

			processDueItems(player, state, now)
			abilityService:tick(player, state, now)

			if state.holding ~= nil then
				-- While a hold is in progress its step has not advanced yet,
				-- so expiry checks must wait for the hold to finalize.
				updateHolding(player, state, now)
			else
				updateSlideTracking(state, now)
				processDueSteps(player, state, now)
			end
		end
	end
end)

-- Backend may start after this script, so its run check is handed over once it exists.
task.spawn(function()
	while getBackend() == nil do
		task.wait(0.5)
	end

	getBackend().isInRun = function(player: Player): boolean
		local state = sessions[player]

		return state ~= nil and not state.completed
	end
end)

print("[DanceDanceStep] RhythmService started")
