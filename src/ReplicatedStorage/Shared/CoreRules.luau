--!strict
-- The three core-loop modes, as data and one pure function.
--
-- The loop today grades how long you stood still, which means arriving early and
-- waiting is always the best play and there is no timing skill. These modes exist
-- to be compared in the real game; the active one is the Workspace attribute
-- `CoreMode`, read at song start. See docs/GAMEPLAY_PLAN.md section 5.
--
-- Pure: no services, no state, so it can be unit-tested without a runtime.

local Timing = require(script.Parent.Timing)

local CoreRules = {}

CoreRules.Modes = {
	StandWait = "standWait",
	ArriveOnTime = "arriveOnTime",
	OnBeat = "onBeat",
	-- Funky Friday style: notes scroll up four lanes and the press is the input.
	-- The character stays on stage and dances, so nothing is judged by position.
	Highway = "highway",
}

CoreRules.Default = CoreRules.Modes.OnBeat

-- onBeat: standing off a danger tile when its beat lands, or standing on in a
-- lava or spotlight zone without stepping into it on this beat.
local DODGE_GRADE: Judgement = "Great"
CoreRules.DodgeGrade = DODGE_GRADE

-- onBeat: standing on the target when its beat lands without a timed press, or
-- getting there early. Perfect is kept for a step that lands on the beat; a
-- difficulty may relax that here.
local STAND_GRADE: Judgement = "Great"
CoreRules.StandGrade = STAND_GRADE

function CoreRules.standGrade(_difficulty: string?): Judgement
	return STAND_GRADE
end

export type Mode = string

export type Judgement = "Perfect" | "Great" | "Good" | "Bad" | "Miss"

-- One step the player made, by when it landed and, when known, when it was
-- pressed. Without a press time it was pressed one step-time before landing.
export type Landing = {
	x: number,
	y: number,
	at: number,
	pressAt: number?,
	used: boolean,
}

export type ClapPress = {
	at: number,
	used: boolean,
}

export type OnBeatPlacement ="onTile" | "late" | "off" | "unknown"

export type OnBeatKind = "press" | "stand" | "late" | "miss"

export type OnBeatVerdict = {
	grade: Judgement,
	kind: OnBeatKind,
	pressOffset: number?,
}

export type MissReason =
	"late"
	| "wrong_tile"
	| "danger"
	| "freeze"
	| "outside_zone"
	| "no_position"
	| "released"
	| "missed_run"

local MISS_REASONS: { [string]: MissReason } = {
	too_late = "late",
	late_step = "late",
	expired = "late",
	no_press = "late",
	not_on_tile = "wrong_tile",
	danger_tile = "danger",
	hit_mine = "danger",
	freeze_broken = "freeze",
	pose_broken = "freeze",
	no_clap = "late",
	outside_zone = "outside_zone",
	no_position = "no_position",
	hold_released_early = "released",
	hold_released_too_early = "released",
	missed_run = "missed_run",
}

local GRADE_RANK: { [string]: number } = { Miss = 0, Bad = 1, Good = 2, Great = 3, Perfect = 4 }

function CoreRules.isKnownMode(mode: string?): boolean
	if mode == nil then
		return false
	end

	for _, known in CoreRules.Modes do
		if known == mode then
			return true
		end
	end

	return false
end

function CoreRules.resolveMode(mode: string?): Mode
	return if CoreRules.isKnownMode(mode) then (mode :: Mode) else CoreRules.Default
end

function CoreRules.bandFor(difficulty: string?): { early: number, late: number }
	local scale = Timing.getArriveBandScale(difficulty)

	return {
		early = Timing.ArriveBand.perfectEarly * scale,
		late = Timing.ArriveBand.perfectLate * scale,
	}
end

-- What the judge compares with the beat. In onBeat that is the press plus a
-- constant land delay, so the step animation's length never moves the target.
function CoreRules.judgedOffset(mode: string?, landingOffset: number, difficulty: string?): number
	if CoreRules.resolveMode(mode) == CoreRules.Modes.OnBeat then
		return landingOffset - Timing.getStepSeconds(difficulty) + Timing.OnBeatLandDelay
	end

	return landingOffset
end

function CoreRules.pressOf(landing: Landing, difficulty: string?): number
	return landing.pressAt or landing.at - Timing.getStepSeconds(difficulty)
end

-- pressOffset is the press against the beat, negative being early.
function CoreRules.gradeOnBeatPress(pressOffset: number, difficulty: string?): Judgement
	if pressOffset > Timing.OnBeatLateGrace then
		return "Miss"
	end

	local windows = Timing.getOnBeatWindows(difficulty)
	local judged = pressOffset + Timing.OnBeatLandDelay
	local offset = math.abs(judged)

	if offset <= windows.perfectWindow then
		return "Perfect"
	end

	if judged < 0 then
		return CoreRules.standGrade(difficulty)
	end

	return if offset <= windows.greatWindow then "Great" else "Good"
end

-- Inside the great window: a press timed to the beat rather than an early stand.
function CoreRules.isTimedPress(pressOffset: number, difficulty: string?): boolean
	return math.abs(pressOffset + Timing.OnBeatLandDelay) <= Timing.getOnBeatWindows(difficulty).greatWindow
end

--[[
	The grade of a plain onBeat note, from findOnBeatLanding's answer. Standing
	on the tile when the beat lands is never a Miss: an early arrival, a landing
	an earlier note already used, or a spawn tile only the server saw them on
	all stand for a Great. A press inside the windows earns its own grade.
	pressOffset is set for "press" and "late", never for a stand.
]]
function CoreRules.judgeOnBeatNote(
	landing: Landing?,
	placement: OnBeatPlacement,
	beatAt: number,
	difficulty: string?,
	seenOnTile: boolean
): OnBeatVerdict
	if landing ~= nil and placement == "late" then
		local pressOffset = CoreRules.pressOf(landing, difficulty) - beatAt
		local grade: Judgement = CoreRules.gradeOnBeatPress(pressOffset, difficulty)

		if grade ~= "Miss" then
			return { grade = grade, kind = "late", pressOffset = pressOffset }
		end
	end

	if landing ~= nil and placement == "onTile" and not landing.used then
		local pressOffset = CoreRules.pressOf(landing, difficulty) - beatAt

		if CoreRules.isTimedPress(pressOffset, difficulty) then
			return { grade = CoreRules.gradeOnBeatPress(pressOffset, difficulty), kind = "press", pressOffset = pressOffset }
		end
	end

	-- The server's own view wins over a report it is missing or never matched:
	-- a player it saw on the tile at the beat was standing there.
	if placement == "onTile" or seenOnTile then
		return { grade = CoreRules.standGrade(difficulty), kind = "stand" }
	end

	return { grade = "Miss", kind = "miss" }
end

-- A Miss whose player stepped onto the tile after the late grace closed, but
-- within a beat of it, was late rather than lost.
function CoreRules.arrivedLate(
	landings: { Landing },
	x: number,
	y: number,
	beatAt: number,
	beatSeconds: number,
	difficulty: string?
): boolean
	for _, landing in landings do
		local press = CoreRules.pressOf(landing, difficulty)

		if landing.x == x and landing.y == y and press > beatAt + Timing.OnBeatLateGrace and press <= beatAt + beatSeconds then
			return true
		end
	end

	return false
end

function CoreRules.missReason(reason: string?): MissReason?
	return if reason ~= nil then MISS_REASONS[reason] else nil
end

--[[
	Which of the player's landings decides an onBeat note on (x, y) at beatAt.
	"onTile": their last step pressed by the beat put them on the tile; the
	landing is the first unused one of that stay, so stepping in place cannot
	re-time an early arrival. "late": they stepped onto it within the late grace.
	"off": they were elsewhere. "unknown": no landing at or before the beat.
]]
function CoreRules.findOnBeatLanding(
	landings: { Landing },
	x: number,
	y: number,
	beatAt: number,
	difficulty: string?
): (Landing?, OnBeatPlacement)
	local sorted = table.clone(landings)
	table.sort(sorted, function(a, b)
		return a.at < b.at
	end)

	local last = 0

	for index, landing in sorted do
		if CoreRules.pressOf(landing, difficulty) <= beatAt then
			last = index
		end
	end

	local current = sorted[last]

	if current ~= nil and current.x == x and current.y == y then
		local first = last

		while first > 1 and sorted[first - 1].x == x and sorted[first - 1].y == y do
			first -= 1
		end

		for index = first, last do
			if not sorted[index].used then
				return sorted[index], "onTile"
			end
		end

		return current, "onTile"
	end

	for index = last + 1, #sorted do
		local landing = sorted[index]

		if CoreRules.pressOf(landing, difficulty) > beatAt + Timing.OnBeatLateGrace then
			break
		end

		if landing.x == x and landing.y == y then
			return landing, "late"
		end
	end

	return nil, if current ~= nil then "off" else "unknown"
end

--[[
	A rush is a run: its first tile is timed like any note, and every later tile
	counts once the dancer steps onto it after the tile before it, by the run's
	deadline. afterAt is when the run reached the tile before; the landing found
	becomes the next tile's afterAt.
]]
function CoreRules.runDeadline(lastBeatAt: number): number
	return lastBeatAt + Timing.OnBeatLateGrace
end

function CoreRules.runStartAt(firstLanding: Landing?, firstBeatAt: number): number
	return if firstLanding ~= nil then firstLanding.at else firstBeatAt
end

function CoreRules.findRunLanding(
	landings: { Landing },
	x: number,
	y: number,
	afterAt: number,
	deadline: number,
	difficulty: string?
): Landing?
	local found: Landing? = nil

	for _, landing in landings do
		local inRun = landing.x == x
			and landing.y == y
			and not landing.used
			and landing.at > afterAt
			and CoreRules.pressOf(landing, difficulty) <= deadline

		if inRun and (found == nil or landing.at < found.at) then
			found = landing
		end
	end

	return found
end

function CoreRules.gradeRunTile(reached: boolean): Judgement
	return if reached then "Perfect" else "Miss"
end

-- A lava or spotlight beat asks for any tile of its zone. Standing on one wins
-- over stepping onto another late; "off" and "unknown" are the same for every tile.
function CoreRules.findZoneLanding(
	landings: { Landing },
	tiles: { { x: number, y: number } },
	beatAt: number,
	difficulty: string?
): (Landing?, OnBeatPlacement)
	local lateLanding: Landing? = nil
	local fallback: OnBeatPlacement = "unknown"

	for _, tile in tiles do
		local landing, placement = CoreRules.findOnBeatLanding(landings, tile.x, tile.y, beatAt, difficulty)

		if placement == "onTile" then
			return landing, placement
		end

		if placement == "late" and lateLanding == nil then
			lateLanding = landing
		elseif placement == "off" then
			fallback = "off"
		end
	end

	if lateLanding ~= nil then
		return lateLanding, "late"
	end

	return nil, fallback
end

-- In a zone, stepping in on the beat earns the press's grade and already
-- standing there earns the dodge's, whichever is better. seenOnTile is the
-- server's own view of a player with no step reported by the beat.
function CoreRules.gradeZone(
	placement: OnBeatPlacement,
	pressOffset: number?,
	difficulty: string?,
	seenOnTile: boolean?
): Judgement
	if placement == "late" and pressOffset ~= nil then
		return CoreRules.gradeOnBeatPress(pressOffset, difficulty)
	end

	if placement ~= "onTile" and seenOnTile == true then
		return CoreRules.standGrade(difficulty)
	end

	if placement ~= "onTile" then
		return "Miss"
	end

	local pressGrade: Judgement = if pressOffset ~= nil then CoreRules.gradeOnBeatPress(pressOffset, difficulty) else "Miss"

	local stand: Judgement = CoreRules.standGrade(difficulty)

	if GRADE_RANK[pressGrade] > GRADE_RANK[stand] then
		return pressGrade
	end

	return stand
end

-- A freeze beat covers the presses since the beat before it, less the late
-- grace, so a late press on the note before the freeze does not break it.
function CoreRules.freezeWindow(beatAt: number, beatSeconds: number): (number, number)
	return beatAt - beatSeconds + Timing.OnBeatLateGrace, beatAt
end

function CoreRules.brokeFreeze(landings: { Landing }, fromAt: number, toAt: number, difficulty: string?): boolean
	for _, landing in landings do
		local press = CoreRules.pressOf(landing, difficulty)

		if press > fromAt and press <= toAt then
			return true
		end
	end

	return false
end

function CoreRules.gradeFreeze(moved: boolean): Judgement
	return if moved then "Miss" else "Perfect"
end

function CoreRules.poseWindow(beatAt: number, poseBeats: number, beatSeconds: number): (number, number)
	return beatAt, beatAt + poseBeats * beatSeconds
end

function CoreRules.brokePose(
	landings: { Landing },
	beatAt: number,
	poseBeats: number,
	beatSeconds: number,
	difficulty: string?
): boolean
	local fromAt, toAt = CoreRules.poseWindow(beatAt, poseBeats, beatSeconds)

	return CoreRules.brokeFreeze(landings, fromAt, toAt, difficulty)
end

function CoreRules.gradePose(onTile: boolean, moved: boolean): Judgement
	return if onTile and not moved then "Perfect" else "Miss"
end

function CoreRules.findClapPress(presses: { ClapPress }, beatAt: number, beatSeconds: number): ClapPress?
	local earliest = beatAt - Timing.ClapEarlyBeats * beatSeconds
	local latest = beatAt + Timing.OnBeatLateGrace
	local best: ClapPress? = nil
	local bestDistance = math.huge

	for _, press in presses do
		local distance = math.abs(press.at - beatAt)

		if not press.used and press.at >= earliest and press.at <= latest and distance < bestDistance then
			best = press
			bestDistance = distance
		end
	end

	return best
end

-- A clap is graded like a step's press, but the press is the clap itself, so
-- no land delay applies.
function CoreRules.gradeClap(pressOffset: number?, difficulty: string?): Judgement
	if pressOffset == nil or pressOffset > Timing.OnBeatLateGrace then
		return "Miss"
	end

	local windows = Timing.getOnBeatWindows(difficulty)
	local offset = math.abs(pressOffset)

	if offset <= windows.perfectWindow then
		return "Perfect"
	end

	if pressOffset < 0 then
		return CoreRules.standGrade(difficulty)
	end

	return if offset <= windows.greatWindow then "Great" else "Good"
end

local function gradeArriveOnTime(landingOffset: number, beatSeconds: number, difficulty: string?): Judgement
	local band = CoreRules.bandFor(difficulty)
	local early = -band.early * beatSeconds
	local late = -band.late * beatSeconds

	if landingOffset >= early and landingOffset <= late then
		return "Perfect"
	end

	-- Landed well before the window, or cut it finer than the window allows.
	if landingOffset < early or landingOffset <= 0 then
		return "Great"
	end

	if landingOffset <= Timing.LateArriveGrace then
		return "Good"
	end

	return "Miss"
end

-- An item is a pickup, collected where a note on its tile would be hit: on the
-- tile when its beat landed, stepped onto inside the late grace, or, with no
-- step reported by then, seen standing there by the server.
function CoreRules.collectsItem(placement: string, seenOnTile: boolean): boolean
	return placement == "onTile" or placement == "late" or (placement == "unknown" and seenOnTile)
end

-- A hold's final grade from the grade its head earned and how much of it was
-- held: all of it keeps the head's grade, most of it is a Good, less is a Miss.
function CoreRules.gradeHold(headGrade: Judgement, heldFraction: number): Judgement
	if headGrade == "Miss" or heldFraction >= 1 then
		return headGrade
	end

	return if heldFraction >= Timing.HoldGoodFraction then "Good" else "Miss"
end

--[[
	landingOffset is seconds between landing on the tile and the target beat:
	negative is early, nil means the player never got there.
	standSeconds is how long they had been settled when the beat landed.
]]
function CoreRules.grade(
	mode: string?,
	landingOffset: number?,
	standSeconds: number,
	beatSeconds: number,
	difficulty: string?
): Judgement
	if landingOffset == nil then
		return "Miss"
	end

	local resolved = CoreRules.resolveMode(mode)

	if resolved == CoreRules.Modes.ArriveOnTime then
		return gradeArriveOnTime(landingOffset, beatSeconds, difficulty)
	end

	if resolved == CoreRules.Modes.OnBeat then
		return CoreRules.gradeOnBeatPress(landingOffset - Timing.getStepSeconds(difficulty), difficulty)
	end

	if resolved == CoreRules.Modes.Highway then
		return Timing.gradeWithWindows(landingOffset, 0, Timing.getWindows(difficulty)) :: Judgement
	end

	return Timing.gradeStandAndWait(true, standSeconds, beatSeconds) :: Judgement
end

return CoreRules
