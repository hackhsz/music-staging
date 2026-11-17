--!strict
local CoreRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CoreRules"))
local Timing = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Timing"))

local BEAT = 0.5

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function close(actual: number, wanted: number, what: string)
	assert(math.abs(actual - wanted) < 1e-9, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

return {
	["an unknown mode falls back to onBeat, the default"] = function()
		expect(CoreRules.Default, CoreRules.Modes.OnBeat, "default")
		expect(CoreRules.resolveMode("nonsense"), CoreRules.Modes.OnBeat, "unknown mode")
		expect(CoreRules.resolveMode(nil), CoreRules.Modes.OnBeat, "nil mode")
		expect(CoreRules.resolveMode("highway"), CoreRules.Modes.Highway, "highway stays selectable")
		expect(CoreRules.isKnownMode("onBeat"), true, "onBeat is known")
	end,

	["never arriving is a Miss in every mode"] = function()
		for _, mode in CoreRules.Modes do
			expect(CoreRules.grade(mode, nil, 0, BEAT, "normal"), "Miss", mode .. " with no landing")
		end
	end,

	["standWait still grades on how long you stood"] = function()
		local mode = CoreRules.Modes.StandWait
		expect(CoreRules.grade(mode, -0.3, BEAT * 0.5, BEAT, "normal"), "Perfect", "settled half a beat")
		expect(CoreRules.grade(mode, -0.3, Timing.StandGreatSeconds, BEAT, "normal"), "Great", "settled 150ms")
		expect(CoreRules.grade(mode, -0.3, 0, BEAT, "normal"), "Good", "just arrived")
	end,

	["arriveOnTime pays the band, not the wait"] = function()
		local mode = CoreRules.Modes.ArriveOnTime
		local band = CoreRules.bandFor("normal")

		-- Inside the band, regardless of how long they then stood.
		expect(CoreRules.grade(mode, -0.3 * BEAT, 0, BEAT, "normal"), "Perfect", "mid band")
		expect(CoreRules.grade(mode, -band.early * BEAT, 0, BEAT, "normal"), "Perfect", "early edge")
		expect(CoreRules.grade(mode, -band.late * BEAT, 0, BEAT, "normal"), "Perfect", "late edge")

		-- Standing longer must not buy a better grade; that is the whole point.
		expect(CoreRules.grade(mode, -0.9 * BEAT, 10, BEAT, "normal"), "Great", "rushed, stood forever")
	end,

	["arriveOnTime degrades either side of the band"] = function()
		local mode = CoreRules.Modes.ArriveOnTime
		expect(CoreRules.grade(mode, -0.9 * BEAT, 0, BEAT, "normal"), "Great", "landed too early")
		expect(CoreRules.grade(mode, -0.05 * BEAT, 0, BEAT, "normal"), "Great", "cut it fine")
		expect(CoreRules.grade(mode, 0, 0, BEAT, "normal"), "Great", "exactly on the beat")
		expect(CoreRules.grade(mode, 0.05, 0, BEAT, "normal"), "Good", "late inside the grace")
		expect(CoreRules.grade(mode, Timing.LateArriveGrace + 0.01, 0, BEAT, "normal"), "Miss", "past the grace")
	end,

	["the arrive band tightens as difficulty rises"] = function()
		local easy = CoreRules.bandFor("easy")
		local normal = CoreRules.bandFor("normal")
		local expert = CoreRules.bandFor("expert")

		assert(easy.early > normal.early, "easy should be wider than normal")
		assert(expert.early < normal.early, "expert should be tighter than normal")

		-- A landing that is Perfect on easy can fall out of the band on expert.
		local offset = -0.62 * BEAT
		expect(CoreRules.grade(CoreRules.Modes.ArriveOnTime, offset, 0, BEAT, "easy"), "Perfect", "easy accepts it")
		expect(CoreRules.grade(CoreRules.Modes.ArriveOnTime, offset, 0, BEAT, "expert"), "Great", "expert does not")
	end,

	["onBeat judges the press plus the land delay"] = function()
		local mode = CoreRules.Modes.OnBeat
		local hop = Timing.getStepSeconds("normal")
		local pressedOnTarget = hop - Timing.OnBeatLandDelay

		expect(CoreRules.grade(mode, pressedOnTarget, 0, BEAT, "normal"), "Perfect", "pressed a land delay early")
		close(CoreRules.judgedOffset(mode, pressedOnTarget, "normal"), 0, "judged offset")
		expect(CoreRules.grade(mode, pressedOnTarget + 0.055, 0, BEAT, "normal"), "Perfect", "55 ms late")
		expect(CoreRules.grade(mode, pressedOnTarget - 0.055, 0, BEAT, "normal"), "Perfect", "55 ms early")
		expect(CoreRules.grade(mode, pressedOnTarget + 0.1, 0, BEAT, "normal"), "Great", "100 ms late")
		expect(CoreRules.grade(mode, pressedOnTarget - 0.135, 0, BEAT, "normal"), "Great", "135 ms early")

		local hardTarget = Timing.getStepSeconds("hard") - Timing.OnBeatLandDelay
		expect(CoreRules.grade(mode, hardTarget - 0.1, 0, BEAT, "hard"), "Great", "100 ms early on hard")
	end,

	["onBeat step speed never moves the timing target"] = function()
		for _, difficulty in { "easy", "normal", "hard", "expert" } do
			local landing = -Timing.OnBeatLandDelay + Timing.getStepSeconds(difficulty)
			expect(CoreRules.grade(CoreRules.Modes.OnBeat, landing, 0, BEAT, difficulty), "Perfect", difficulty)
			close(CoreRules.judgedOffset(CoreRules.Modes.OnBeat, landing, difficulty), 0, difficulty .. " offset")
		end
	end,

	["an early arrival is a Great on every difficulty; Perfect needs the beat"] = function()
		local mode = CoreRules.Modes.OnBeat

		for _, difficulty in { "easy", "normal", "hard", "expert" } do
			local hop = Timing.getStepSeconds(difficulty)
			expect(CoreRules.grade(mode, hop - 0.4, 0, BEAT, difficulty), "Great", difficulty .. ": a beat early")
			expect(CoreRules.standGrade(difficulty), "Great", difficulty .. ": stand grade")
		end
	end,

	["standing on the target at its beat is never a Miss"] = function()
		local early: CoreRules.Landing = { x = 3, y = 3, at = 9, pressAt = 9, used = false }
		local landing: CoreRules.Landing?, placement: CoreRules.OnBeatPlacement =
			CoreRules.findOnBeatLanding({ early }, 3, 3, 10, "normal")
		local verdict = CoreRules.judgeOnBeatNote(landing, placement, 10, "normal", false)
		expect(verdict.grade, CoreRules.standGrade("normal"), "arrived early")
		expect(verdict.kind, "stand", "early is a stand")
		expect(verdict.pressOffset, nil, "a stand has no offset")

		early.used = true
		landing, placement = CoreRules.findOnBeatLanding({ early }, 3, 3, 11, "normal")
		verdict = CoreRules.judgeOnBeatNote(landing, placement, 11, "normal", false)
		expect(verdict.grade, CoreRules.standGrade("normal"), "previous note on the same tile")
		expect(CoreRules.judgeOnBeatNote(landing, placement, 11, "hard", false).grade, "Great", "a stand on hard")

		local spawn = CoreRules.judgeOnBeatNote(nil, "unknown", 10, "normal", true)
		expect(spawn.grade, CoreRules.standGrade("normal"), "spawn tile, seen there")
		expect(CoreRules.judgeOnBeatNote(nil, "unknown", 10, "normal", false).grade, "Miss", "nowhere to be seen")
		expect(CoreRules.judgeOnBeatNote(nil, "off", 10, "normal", false).grade, "Miss", "elsewhere")
		expect(CoreRules.judgeOnBeatNote(nil, "off", 10, "hard", true).grade, "Great", "report lost, seen on the tile")
	end,

	["a timed press still earns Perfect, a sloppy late one Good"] = function()
		local onBeat: CoreRules.Landing = { x = 3, y = 3, at = 10.2, pressAt = 10 - Timing.OnBeatLandDelay, used = false }
		local landing: CoreRules.Landing?, placement: CoreRules.OnBeatPlacement =
			CoreRules.findOnBeatLanding({ onBeat }, 3, 3, 10, "normal")
		local verdict = CoreRules.judgeOnBeatNote(landing, placement, 10, "normal", false)
		expect(verdict.grade, "Perfect", "on the beat")
		expect(verdict.kind, "press", "kind")
		expect(CoreRules.isTimedPress(-0.01, "normal"), true, "timed")
		expect(CoreRules.isTimedPress(-1, "normal"), false, "a stand")

		local sloppy: CoreRules.Landing = { x = 3, y = 3, at = 10.4, pressAt = 10 + Timing.OnBeatLateGrace - 0.01, used = false }
		local late = CoreRules.judgeOnBeatNote(sloppy, "late", 10, "normal", false)
		expect(late.grade, "Good", "late in the grace")
		expect(late.kind, "late", "late kind")
	end,

	["a Miss reads as late when they got there after the grace"] = function()
		local landings: { CoreRules.Landing } = { { x = 3, y = 3, at = 10.5, pressAt = 10.3, used = false } }
		expect(CoreRules.arrivedLate(landings, 3, 3, 10, BEAT, "normal"), true, "late")
		expect(CoreRules.arrivedLate(landings, 2, 3, 10, BEAT, "normal"), false, "other tile")
		expect(CoreRules.arrivedLate(landings, 3, 3, 9, BEAT, "normal"), false, "a later note")
		expect(CoreRules.missReason("too_late"), "late", "late")
		expect(CoreRules.missReason("not_on_tile"), "wrong_tile", "wrong tile")
		expect(CoreRules.missReason("danger_tile"), "danger", "danger")
		expect(CoreRules.missReason("freeze_broken"), "freeze", "freeze")
		expect(CoreRules.missReason("outside_zone"), "outside_zone", "zone")
		expect(CoreRules.missReason("no_position"), "no_position", "no position")
		expect(CoreRules.missReason("on_beat"), nil, "not a miss")
	end,

	["onBeat late grace counts until it closes"] = function()
		local mode = CoreRules.Modes.OnBeat
		local hop = Timing.getStepSeconds("normal")

		local justAfter = hop + Timing.getOnBeatWindows("normal").perfectWindow + 0.01 - Timing.OnBeatLandDelay
		expect(CoreRules.grade(mode, justAfter, 0, BEAT, "normal"), "Great", "pressed just after the beat")
		expect(CoreRules.grade(mode, hop + Timing.OnBeatLateGrace - 0.001, 0, BEAT, "normal"), "Good", "end of the grace")
		expect(CoreRules.grade(mode, hop + Timing.OnBeatLateGrace + 0.01, 0, BEAT, "normal"), "Miss", "past the grace")
	end,

	["onBeat dodging a danger tile is a Great"] = function()
		expect(CoreRules.DodgeGrade, "Great", "dodge grade")
	end,

	["onBeat finds the stay the beat landed on"] = function()
		local hop = Timing.getStepSeconds("normal")
		local landings: { CoreRules.Landing } = {
			{ x = 2, y = 3, at = 9.5, used = false },
			{ x = 3, y = 3, at = 9.9 + hop, used = false },
			{ x = 4, y = 3, at = 10.3 + hop, used = false },
		}

		local landing, placement = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(placement, "onTile", "placement")
		expect(landing, landings[2], "landing")

		local _, elsewhere = CoreRules.findOnBeatLanding(landings, 1, 1, 10, "normal")
		expect(elsewhere, "off", "elsewhere")

		local _, before = CoreRules.findOnBeatLanding(landings, 2, 3, 9, "normal")
		expect(before, "unknown", "nothing pressed by the beat")
	end,

	["onBeat takes a step pressed inside the late grace"] = function()
		local hop = Timing.getStepSeconds("normal")
		local landings: { CoreRules.Landing } = {
			{ x = 2, y = 3, at = 9, used = false },
			{ x = 3, y = 3, at = 10 + Timing.OnBeatLateGrace - 0.01 + hop, used = false },
		}

		local landing, placement = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(placement, "late", "inside the grace")
		expect(landing, landings[2], "late landing")

		landings[2].at += 0.02
		local _, missed = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(missed, "off", "past the grace")
	end,

	["an item is collected on its tile or inside the late grace"] = function()
		local hop = Timing.getStepSeconds("normal")
		local landings: { CoreRules.Landing } = {
			{ x = 2, y = 3, at = 9, used = false },
			{ x = 3, y = 3, at = 10 + Timing.OnBeatLateGrace - 0.01 + hop, used = false },
		}

		local _, late = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(CoreRules.collectsItem(late, false), true, "stepped on in the grace")

		local _, standing = CoreRules.findOnBeatLanding(landings, 2, 3, 10, "normal")
		expect(CoreRules.collectsItem(standing, false), true, "standing on it")

		local _, away = CoreRules.findOnBeatLanding(landings, 5, 5, 10, "normal")
		expect(CoreRules.collectsItem(away, true), false, "elsewhere")
		expect(CoreRules.collectsItem("unknown", true), true, "only the server saw them there")
		expect(CoreRules.collectsItem("unknown", false), false, "nobody saw them there")
		expect(landings[2].used, false, "an item never uses up a landing")
	end,

	["onBeat judges a reported press, not the landing"] = function()
		local hop = Timing.getStepSeconds("normal")
		local slow: CoreRules.Landing = { x = 3, y = 3, at = 10.3, pressAt = 9.92, used = false }

		expect(CoreRules.pressOf(slow, "normal"), 9.92, "reported press")
		close(CoreRules.pressOf({ x = 3, y = 3, at = 10.3, used = false }, "normal"), 10.3 - hop, "derived press")
		expect(CoreRules.gradeOnBeatPress(-Timing.OnBeatLandDelay, "normal"), "Perfect", "press a land delay early")
		expect(CoreRules.gradeOnBeatPress(Timing.OnBeatLateGrace + 0.01, "normal"), "Miss", "press past the grace")

		local landing, placement = CoreRules.findOnBeatLanding({ slow }, 3, 3, 10, "normal")
		expect(placement, "onTile", "a press before the beat puts them on the tile")
		expect(landing, slow, "landing")
	end,

	["onBeat judges a stay by its first unused landing"] = function()
		local landings: { CoreRules.Landing } = {
			{ x = 3, y = 3, at = 8, used = false },
			{ x = 3, y = 3, at = 9.98, used = false },
		}

		local first = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(first, landings[1], "arriving early cannot be re-timed")

		landings[1].used = true
		local second = CoreRules.findOnBeatLanding(landings, 3, 3, 10, "normal")
		expect(second, landings[2], "a repeat note takes the next landing")
	end,

	["only onBeat shifts the judged moment"] = function()
		expect(CoreRules.judgedOffset(CoreRules.Modes.ArriveOnTime, -0.2, "normal"), -0.2, "arriveOnTime")
		expect(CoreRules.judgedOffset(CoreRules.Modes.StandWait, -0.2, "normal"), -0.2, "standWait")
	end,

	["highway grades the press itself, with no hop to allow for"] = function()
		local mode = CoreRules.Modes.Highway
		local windows = Timing.getWindows("normal")

		expect(CoreRules.isKnownMode("highway"), true, "highway is known")
		expect(CoreRules.grade(mode, 0, 0, BEAT, "normal"), "Perfect", "dead on")
		expect(CoreRules.grade(mode, -windows.greatWindow * 0.95, 0, BEAT, "normal"), "Great", "early great")
		expect(CoreRules.grade(mode, windows.badWindow + 0.05, 0, BEAT, "normal"), "Miss", "way off")
		expect(CoreRules.judgedOffset(mode, 0.03, "normal"), 0.03, "judged as pressed")
	end,

	["a hold held to the end keeps its head's grade"] = function()
		expect(CoreRules.gradeHold("Perfect", 1), "Perfect", "full hold")
		expect(CoreRules.gradeHold("Great", 1.2), "Great", "held past the end")
	end,

	["letting go of a hold early costs the grade"] = function()
		expect(CoreRules.gradeHold("Perfect", Timing.HoldGoodFraction), "Good", "held just enough")
		expect(CoreRules.gradeHold("Perfect", Timing.HoldGoodFraction - 0.01), "Miss", "let go too soon")
		expect(CoreRules.gradeHold("Miss", 1), "Miss", "a missed head stays missed")
	end,

	["onBeat ignores standing entirely"] = function()
		local mode = CoreRules.Modes.OnBeat
		local a = CoreRules.grade(mode, 0.02, 0, BEAT, "normal")
		local b = CoreRules.grade(mode, 0.02, 5, BEAT, "normal")
		expect(a, b, "standing changed the grade")
	end,

	["expert windows are tighter than easy in onBeat"] = function()
		local mode = CoreRules.Modes.OnBeat
		local off = Timing.getOnBeatWindows("expert").perfectWindow + 0.005
		local function landingFor(difficulty: string): number
			return off - Timing.OnBeatLandDelay + Timing.getStepSeconds(difficulty)
		end

		expect(CoreRules.grade(mode, landingFor("easy"), 0, BEAT, "easy"), "Perfect", "easy still perfect")
		expect(CoreRules.grade(mode, landingFor("expert"), 0, BEAT, "expert"), "Great", "expert is not")
	end,

	["a zone beat takes any of its tiles"] = function()
		local zone = { { x = 1, y = 1 }, { x = 4, y = 4 } }
		local landings = { { x = 4, y = 4, at = 1.1, pressAt = 0.98, used = false } }
		local landing, placement = CoreRules.findZoneLanding(landings, zone, 1, "normal")
		expect(placement, "onTile", "on the second tile")
		expect(landing, landings[1], "its landing")

		local _, off = CoreRules.findZoneLanding({ { x = 3, y = 3, at = 0.5, used = false } }, zone, 1, "normal")
		expect(off, "off", "elsewhere")
		local _, unknown = CoreRules.findZoneLanding({}, zone, 1, "normal")
		expect(unknown, "unknown", "no steps at all")
	end,

	["a zone pays the press on the beat and the dodge for standing"] = function()
		local onBeat = -Timing.OnBeatLandDelay
		expect(CoreRules.gradeZone("onTile", onBeat, "normal"), "Perfect", "stepped in on the beat")
		expect(CoreRules.gradeZone("onTile", -2 * BEAT, "hard"), "Great", "stood there")
		expect(CoreRules.gradeZone("onTile", -2 * BEAT, "normal"), "Great", "stood there on normal")
		expect(CoreRules.gradeZone("onTile", nil, "hard"), "Great", "no press known")
		expect(CoreRules.gradeZone("late", Timing.OnBeatLateGrace + 0.01, "normal"), "Miss", "too late")
		expect(CoreRules.gradeZone("off", nil, "normal"), "Miss", "in the lava")
		expect(CoreRules.gradeZone("unknown", nil, "hard", true), "Great", "only the server saw them")
		expect(CoreRules.gradeZone("unknown", nil, "normal", false), "Miss", "nobody saw them")
	end,

	["a freeze breaks only on a step pressed during its beat"] = function()
		local fromAt, toAt = CoreRules.freezeWindow(2, BEAT)
		close(fromAt, 2 - BEAT + Timing.OnBeatLateGrace, "window start")
		close(toAt, 2, "window end")

		local lateOnTheNoteBefore = { x = 1, y = 1, at = 2, pressAt = 1.5 + Timing.OnBeatLateGrace, used = false }
		expect(CoreRules.brokeFreeze({ lateOnTheNoteBefore }, fromAt, toAt, "normal"), false, "late press before")
		local midFreeze = { x = 1, y = 1, at = 2, pressAt = 1.8, used = false }
		expect(CoreRules.brokeFreeze({ midFreeze }, fromAt, toAt, "normal"), true, "a step during it")
		expect(CoreRules.gradeFreeze(false), "Perfect", "held")
		expect(CoreRules.gradeFreeze(true), "Miss", "moved")
	end,

	["a pose breaks on any step pressed from its beat to its end"] = function()
		local fromAt, toAt = CoreRules.poseWindow(2, 2, BEAT)
		close(fromAt, 2, "window start")
		close(toAt, 3, "window end")

		local beforeTheBeat = { x = 1, y = 1, at = 1.9, pressAt = 1.8, used = false }
		expect(CoreRules.brokePose({ beforeTheBeat }, 2, 2, BEAT, "normal"), false, "the step onto the tile")
		local during = { x = 2, y = 1, at = 2.6, pressAt = 2.5, used = false }
		expect(CoreRules.brokePose({ during }, 2, 2, BEAT, "normal"), true, "a step mid pose")
		local after = { x = 2, y = 1, at = 3.2, pressAt = 3.1, used = false }
		expect(CoreRules.brokePose({ after }, 2, 2, BEAT, "normal"), false, "the step after it")
	end,

	["a pose is Perfect or a Miss"] = function()
		expect(CoreRules.gradePose(true, false), "Perfect", "held on the tile")
		expect(CoreRules.gradePose(true, true), "Miss", "moved")
		expect(CoreRules.gradePose(false, false), "Miss", "elsewhere")
	end,

	["a clap takes the nearest unused press near its beat"] = function()
		local early = { at = 2 - BEAT * 0.4, used = false }
		local close1 = { at = 2.03, used = false }
		local tooEarly = { at = 2 - BEAT * Timing.ClapEarlyBeats - 0.01, used = false }
		local tooLate = { at = 2 + Timing.OnBeatLateGrace + 0.01, used = false }

		expect(CoreRules.findClapPress({ early, close1 }, 2, BEAT), close1, "nearest")
		expect(CoreRules.findClapPress({ tooEarly, tooLate }, 2, BEAT), nil, "outside the window")
		close1.used = true
		expect(CoreRules.findClapPress({ early, close1 }, 2, BEAT), early, "a used press is skipped")
	end,

	["a clap is graded like a press, with no land delay"] = function()
		local windows = Timing.getOnBeatWindows("normal")
		expect(CoreRules.gradeClap(nil, "normal"), "Miss", "no clap")
		expect(CoreRules.gradeClap(0, "normal"), "Perfect", "on the beat")
		expect(CoreRules.gradeClap(-windows.perfectWindow, "normal"), "Perfect", "early edge")
		expect(CoreRules.gradeClap(-windows.greatWindow - 0.05, "normal"), CoreRules.standGrade("normal"), "very early")
		expect(CoreRules.gradeClap(windows.perfectWindow + 0.01, "normal"), "Great", "a little late")
		expect(CoreRules.gradeClap(windows.greatWindow + 0.01, "normal"), "Good", "late")
		expect(CoreRules.gradeClap(Timing.OnBeatLateGrace + 0.01, "normal"), "Miss", "past the grace")
	end,

	["the first tile of a rush is timed as a plain step"] = function()
		local landing = { x = 2, y = 1, at = 2 + Timing.getStepSeconds("normal"), pressAt = 2, used = false }
		local found, placement = CoreRules.findOnBeatLanding({ landing }, 2, 1, 2, "normal")
		local verdict = CoreRules.judgeOnBeatNote(found, placement :: CoreRules.OnBeatPlacement, 2, "normal", false)
		expect(verdict.grade, "Perfect", "on the beat")
		expect(CoreRules.missReason("pose_broken"), "freeze", "pose miss reason")
		expect(CoreRules.missReason("no_clap"), "late", "clap miss reason")

		local early = { x = 2, y = 1, at = 1.7, pressAt = 1.6, used = false }
		local _, earlyPlacement = CoreRules.findOnBeatLanding({ early }, 2, 1, 2, "normal")
		local stand = CoreRules.judgeOnBeatNote(early, earlyPlacement :: CoreRules.OnBeatPlacement, 2, "normal", false)
		expect(stand.grade, CoreRules.standGrade("normal"), "an early stand is not a Perfect")
		close(CoreRules.runStartAt(landing, 2), landing.at, "the run starts from the first landing")
		close(CoreRules.runStartAt(nil, 2), 2, "or from the first beat")
	end,

	["a run tile reached in order by the deadline is a Perfect"] = function()
		local deadline = CoreRules.runDeadline(3)
		close(deadline, 3 + Timing.OnBeatLateGrace, "deadline")

		local second = { x = 3, y = 1, at = 2.3, pressAt = 2.2, used = false }
		local third = { x = 4, y = 1, at = 2.45, pressAt = 2.35, used = false }
		local landings = { second, third }

		local found = CoreRules.findRunLanding(landings, 3, 1, 2.1, deadline, "normal")
		expect(found, second, "second tile")
		expect(CoreRules.gradeRunTile(found ~= nil), "Perfect", "reached early on is Perfect")
		expect(CoreRules.findRunLanding(landings, 4, 1, second.at, deadline, "normal"), third, "third tile, any speed")
	end,

	["a run tile skipped or reached out of order is a Miss"] = function()
		local deadline = CoreRules.runDeadline(3)
		local before = { x = 3, y = 1, at = 1.9, pressAt = 1.8, used = false }

		expect(CoreRules.findRunLanding({}, 3, 1, 2.1, deadline, "normal"), nil, "skipped")
		expect(CoreRules.findRunLanding({ before }, 3, 1, 2.1, deadline, "normal"), nil, "before the tile before it")
		expect(CoreRules.gradeRunTile(false), "Miss", "not reached")

		local used = { x = 3, y = 1, at = 2.3, pressAt = 2.2, used = true }
		expect(CoreRules.findRunLanding({ used }, 3, 1, 2.1, deadline, "normal"), nil, "a used landing")
		expect(CoreRules.missReason("missed_run"), "missed_run", "miss reason")
	end,

	["a run tile reached after the deadline is a Miss"] = function()
		local deadline = CoreRules.runDeadline(3)
		local onTime = { x = 4, y = 1, at = deadline + 0.05, pressAt = deadline, used = false }
		local late = { x = 4, y = 1, at = deadline + 0.15, pressAt = deadline + 0.01, used = false }

		expect(CoreRules.findRunLanding({ onTime }, 4, 1, 2.5, deadline, "normal"), onTime, "pressed on the deadline")
		expect(CoreRules.findRunLanding({ late }, 4, 1, 2.5, deadline, "normal"), nil, "pressed after it")
	end,
}
