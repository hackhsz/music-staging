--!strict
-- The first-join lesson: one short drill per kind of step, each a few tries on
-- Our Hearts' intro. A drill repeats until enough of its tries land, and only then
-- does the next one open. Drills play through the normal judge but cannot be
-- failed, pay nothing and never rank.
local TutorialChart = {}

TutorialChart.Id = "our-hearts-tutorial"
-- The real song played straight after the lesson, the easiest chart there is.
TutorialChart.FirstSongId = "our-hearts-easy"

local BPM = 120.98
-- Our Hearts' downbeats sit this far past each whole beat of the chart grid.
local BEAT_PHASE = 0.2205
-- Easy telegraphs four beats ahead, so the first target lights as the song starts.
local FIRST_STEP_BEAT = 5
local STEP_GAP = 4
local HOLD_SECONDS = 1
local OUTRO_BEATS = 4
local DRILL_ID_PATTERN = "^our%-hearts%-tutorial%-(%d+)$"

type Coord = { x: number, y: number }
type Spec = { at: Coord, type: string?, zone: { Coord }?, danger: Coord? }
export type Drill = {
	kind: string,
	title: string,
	text: string,
	hint: string,
	funnelStep: string,
	steps: { Spec },
}

local function coord(x: number, y: number): Coord
	return { x = x, y = y }
end

-- Every drill starts with the dancer on the middle tile (3, 3) and visits it at
-- most once more, so standing still never passes one.
TutorialChart.Drills = {
	{
		kind = "tap",
		title = "STEP",
		text = "LAND ON THE PINK TILE AS IT HITS 0",
		hint = "FOLLOW THE ARROW ON THE FLOOR",
		funnelStep = "drill_step",
		steps = {
			{ at = coord(3, 2) },
			{ at = coord(4, 2) },
			{ at = coord(4, 3) },
			{ at = coord(3, 3) },
		},
	},
	{
		kind = "shape",
		title = "ANY TILE",
		text = "BLUE: EITHER TILE COUNTS",
		hint = "PICK THE CLOSER ONE",
		funnelStep = "drill_any",
		steps = {
			{ at = coord(3, 2), type = "shape", zone = { coord(3, 2), coord(2, 2) } },
			{ at = coord(4, 2), type = "shape", zone = { coord(4, 2), coord(4, 1) } },
			{ at = coord(4, 3), type = "shape", zone = { coord(4, 3), coord(5, 3) } },
			{ at = coord(3, 4), type = "shape", zone = { coord(3, 4), coord(4, 4) } },
		},
	},
	{
		kind = "hold",
		title = "HOLD",
		text = "LAND ON PURPLE, THEN STAY",
		hint = "IT DRAINS AS YOU HOLD - WAIT TILL IT'S EMPTY",
		funnelStep = "drill_hold",
		steps = {
			{ at = coord(3, 2), type = "hold" },
			{ at = coord(4, 2), type = "hold" },
			{ at = coord(4, 3), type = "hold" },
			{ at = coord(3, 3), type = "hold" },
		},
	},
	{
		kind = "clap",
		title = "CLAP",
		text = "YELLOW: CLAP ON THE BEAT",
		hint = "SPACE, OR THE CLAP BUTTON",
		funnelStep = "drill_clap",
		steps = {
			{ at = coord(3, 3), type = "clap" },
			{ at = coord(3, 3), type = "clap" },
			{ at = coord(3, 3), type = "clap" },
			{ at = coord(3, 3), type = "clap" },
		},
	},
	{
		kind = "danger",
		title = "AVOID",
		text = "RED: GET OFF IT BEFORE 0",
		hint = "MOVE TO THE PINK TILE IN TIME",
		funnelStep = "drill_avoid",
		steps = {
			{ at = coord(3, 2), danger = coord(3, 3) },
			{ at = coord(3, 3), danger = coord(3, 2) },
			{ at = coord(4, 3), danger = coord(3, 3) },
			{ at = coord(3, 3), danger = coord(4, 3) },
		},
	},
} :: { Drill }

TutorialChart.DrillCount = #TutorialChart.Drills
-- The share of a drill's steps that must not be missed for it to pass.
TutorialChart.PassShare = 0.75

-- The card's call-out after a try, by the server's miss reason
-- (CoreRules.MissReason), with a drill kind's own word where it says it better.
local MISS_CALLOUTS: { [string]: string } = {
	late = "TOO LATE",
	wrong_tile = "WRONG TILE",
	outside_zone = "MISSED THE BLUE",
	released = "LET GO TOO SOON",
	danger = "ON THE RED!",
	no_position = "OFF THE FLOOR",
	freeze = "MOVED",
}
local KIND_MISS_CALLOUTS: { [string]: { [string]: string } } = {
	clap = { late = "CLAP ON 0" },
	shape = { wrong_tile = "MISSED THE BLUE" },
}

function TutorialChart.callout(kind: string, grade: string, reason: string?): string
	if grade == "Perfect" then
		return "PERFECT!"
	elseif grade ~= "Miss" then
		return "NICE!"
	end

	local own = KIND_MISS_CALLOUTS[kind]
	local line = if own ~= nil and reason ~= nil then own[reason] else nil

	return line or (if reason ~= nil then MISS_CALLOUTS[reason] else nil) or MISS_CALLOUTS.late
end

local function onGrid(beat: number): number
	return beat + BEAT_PHASE
end

function TutorialChart.drillId(drill: number): string
	return ("%s-%d"):format(TutorialChart.Id, drill)
end

-- The drill a chart id names, or nil when it is not a lesson chart.
function TutorialChart.drillOf(chartId: string): number?
	local drill = tonumber((chartId:match(DRILL_ID_PATTERN)))

	return if drill ~= nil and TutorialChart.Drills[drill] ~= nil then drill else nil
end

local function buildStep(spec: Spec, beat: number): { [string]: any }
	local step: { [string]: any } = { beat = onGrid(beat), x = spec.at.x, y = spec.at.y }

	if spec.type ~= nil then
		step.type = spec.type
	end

	if spec.type == "hold" then
		step.holdSeconds = HOLD_SECONDS
	elseif spec.type == "shape" then
		step.zone = spec.zone
	end

	return step
end

-- The map RhythmService plays for one drill, in the shape SongSchema.validate
-- expects, plus the drill's card for the client.
function TutorialChart.build(drill: number): any
	local spec = TutorialChart.Drills[drill]
	local steps = {}
	local beat = FIRST_STEP_BEAT

	for index, step in spec.steps do
		if index > 1 then
			beat += STEP_GAP
		end

		table.insert(steps, buildStep(step, beat))

		if step.danger ~= nil then
			table.insert(steps, { beat = onGrid(beat), x = step.danger.x, y = step.danger.y, type = "danger" })
		end
	end

	return {
		id = TutorialChart.drillId(drill),
		title = "Dance Lesson",
		artist = "Derail Games",
		difficulty = "easy",
		bpm = BPM,
		durationSeconds = math.ceil(onGrid(beat + OUTRO_BEATS) * 60 / BPM),
		previewBeats = 1,
		performanceGoal = { label = "LESSON", targetScore = 1 },
		steps = steps,
		tutorial = true,
		drill = drill,
		drillCount = TutorialChart.DrillCount,
		lesson = { kind = spec.kind, title = spec.title, text = spec.text, hint = spec.hint },
	}
end

-- A drill passes when most of its steps were not missed.
function TutorialChart.passed(summary: any): boolean
	local total = tonumber(summary.totalSteps) or 0
	local misses = tonumber(summary.misses) or total

	return total > 0 and (total - misses) / total >= TutorialChart.PassShare
end

return TutorialChart
