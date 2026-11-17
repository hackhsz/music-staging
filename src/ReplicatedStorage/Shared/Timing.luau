local Timing = {}

Timing.PerfectWindow = 0.08
Timing.GreatWindow = 0.13
Timing.GoodWindow = 0.18
Timing.BadWindow = 0.28
Timing.DefaultDifficulty = "normal"
Timing.DefaultDevice = "keyboard"

Timing.DifficultyProfiles = {
	easy = {
		id = "easy",
		arriveBandScale = 1.3,
		perfectWindow = 0.1,
		greatWindow = 0.16,
		goodWindow = 0.22,
		badWindow = 0.32,
		maxBeatTravel = 1,
		travelWindowBeats = 4,
		cornerStepBeats = 1,
		onBeatPerfectWindow = 0.07,
		onBeatGreatWindow = 0.16,
		stepSeconds = 0.12,
		highwayLeadSeconds = 1.15,
		description = "Onboarding charts with forgiving timing and one-tile movement.",
	},
	normal = {
		id = "normal",
		arriveBandScale = 1.0,
		perfectWindow = Timing.PerfectWindow,
		greatWindow = Timing.GreatWindow,
		goodWindow = Timing.GoodWindow,
		badWindow = Timing.BadWindow,
		maxBeatTravel = 2,
		travelWindowBeats = 3,
		cornerStepBeats = 1,
		onBeatPerfectWindow = 0.06,
		onBeatGreatWindow = 0.14,
		stepSeconds = 0.1,
		highwayLeadSeconds = 1.0,
		description = "Default first playable target with short route planning.",
	},
	hard = {
		id = "hard",
		arriveBandScale = 0.8,
		perfectWindow = 0.065,
		greatWindow = 0.11,
		goodWindow = 0.15,
		badWindow = 0.24,
		maxBeatTravel = 2,
		travelWindowBeats = 3,
		onBeatPerfectWindow = 0.055,
		onBeatGreatWindow = 0.125,
		stepSeconds = 0.09,
		highwayLeadSeconds = 0.85,
		description = "Tighter timing with denser patterns and more edge routing.",
	},
	expert = {
		id = "expert",
		arriveBandScale = 0.65,
		perfectWindow = 0.055,
		greatWindow = 0.095,
		goodWindow = 0.13,
		badWindow = 0.21,
		maxBeatTravel = 2,
		travelWindowBeats = 3,
		onBeatPerfectWindow = 0.05,
		onBeatGreatWindow = 0.11,
		stepSeconds = 0.08,
		highwayLeadSeconds = 0.72,
		description = "Tightest timing with near-continuous patterns at full speed.",
	},
}

-- Stand-and-wait feel (core loop redesign, Zhong's #1 priority). Instead of
-- tapping on the beat, the player walks to the telegraphed target during a
-- multi-beat travel window and STANDS there; the beat is then judged by where
-- they are standing and how early they settled. These are the settle thresholds.
Timing.StandPerfectBeatFraction = 0.5 -- settled for >= 50% of a beat before it lands -> Perfect
Timing.StandGreatSeconds = 0.15 -- settled for >= 150 ms -> Great; anything less but on-tile -> Good

-- Late-arrival grace: if the player is not on the tile the instant the beat
-- lands, they get this long afterward to still arrive (counts as Good) before
-- it misses. 0.14s is grounded in the ~135-150 ms outer "still counts" hit
-- window common to osu!/osu!mania/taiko, adapted for a movement (walk-to-tile)
-- game where hitting the exact instant is impossible.
Timing.LateArriveGrace = 0.14

-- onBeat: the judged moment is the press plus this delay, never the step
-- animation, so a faster or slower step never moves the timing target. Zero
-- because players aim the press, not the landing, at the beat they hear: the
-- Music Game's 80 ms here was cancelled by its 100 ms default audio offset.
Timing.OnBeatLandDelay = 0
-- onBeat: a step pressed this long after the beat onto the target still counts,
-- judged by its landing time.
Timing.OnBeatLateGrace = 0.2
-- A clap press counts toward a clap beat from this many beats before it.
Timing.ClapEarlyBeats = 0.5

-- Letting go of a hold early keeps a Good if at least this much of it was
-- held; less is a Miss.
Timing.HoldGoodFraction = 0.6
-- Letting go this close to the end of a hold still counts as holding it all
-- the way, so the release does not have to be frame-perfect.
Timing.HoldReleaseGrace = 0.1
-- A hold or slide not started by the Bad window expires this much later.
Timing.HoldStartExpiryGrace = 0.05

Timing.CountdownSeconds = 3
-- The lesson's card already says what is coming, so its drills count in faster.
Timing.LessonCountdownSeconds = 2
-- The player's input-latency offset is clamped to this either way.
Timing.MaxTimingOffsetSeconds = 0.25
Timing.MinTileDwellSeconds = 0.06
-- Headroom over the fastest step time before a move counts as impossible travel.
Timing.MaxTravelSpeedSlack = 1.25

-- Mode A, as fractions of one beat before the target beat. Landing inside the
-- band is Perfect; landing earlier than perfectEarly is a rushed Great, and
-- cutting it finer than perfectLate is also a Great. A band, not a point.
Timing.ArriveBand = {
	perfectEarly = 0.5,
	perfectLate = 0.15,
}

-- How the server trusts the client's landing reports (ArrivalLedger.Config).
-- band is how far a claimed landing may sit from this player's running delay
-- estimate before it is rejected. It caps what shifting a claim can buy a
-- cheater, so it stays tight once the estimate has settled. A report may reach
-- the server before the position it describes; confirmSeconds is how long it
-- may wait for that position before it is thrown out.
Timing.Arrival = {
	band = 0.08,
	warmupBand = 0.25,
	warmupReports = 5,
	smoothing = 0.2,
	confirmSeconds = 0.5,
	keepSeconds = 3,
	futureTolerance = 0.05,
}

-- How long the report of a highway press may take to reach the server before
-- the note is called a Miss.
Timing.PressReportAllowance = 0.3
-- onBeat waits for every step pressed by the beat to be reported: the landing,
-- then this player's usual report latency (the default until it is measured),
-- then a margin.
Timing.OnBeatDefaultLatency = 0.15
Timing.OnBeatReportMargin = 0.05
Timing.OnBeatStepTolerance = 0.03
-- The longest a reported press may sit before its landing: a step plus a buffered press.
Timing.OnBeatMaxPressLead = 0.5
-- Until a player's replication delay is measured, a move the server sees this
-- long after its step is taken to belong to it, for freeze judging.
Timing.FreezeDefaultDelay = 0.25
-- Where the server saw a player is looked up this long after a beat, the
-- replication delay, clamped; until that delay is measured the default is used.
Timing.SeenDelayDefault = 0.2
Timing.SeenDelayMin = 0.1
Timing.SeenDelayMax = 0.35

Timing.FeverDurationSeconds = 6
Timing.FeverCooldownSeconds = 12
Timing.FeverItemExtendSeconds = 1

-- The song clock follows the music's playhead. Sound.TimePosition moves in
-- chunks of about 21 ms, each reading up to 15 ms off, so the clock snaps only
-- past AudioSnapSeconds and otherwise slews, at most AudioSlewPerSecond, toward
-- the readings' running average, which weighs each new one by AudioSmoothing.
Timing.AudioSnapSeconds = 0.15
Timing.AudioSmoothing = 0.05
Timing.AudioSlewPerSecond = 0.18
-- How far the music may pull the run clock later (it starts late) or earlier
-- than the server's start. Past either the music is seeked onto the clock.
-- The lead stays small: a clock ahead of the server makes reports look future.
Timing.AudioFollowLimitSeconds = 0.25
Timing.AudioLeadLimitSeconds = 0.03

-- After a run the player's offset moves gain of the way toward the median of
-- their timed presses, at most maxStepSeconds, once there are minPresses of
-- them and the median is at least deadbandSeconds off the beat.
Timing.AutoTune = {
	minPresses = 12,
	deadbandSeconds = 0.012,
	gain = 0.7,
	maxStepSeconds = 0.06,
}

-- defaultOffsetSeconds is the latency a device adds between the music reaching
-- the speakers and a press being read, used until the player calibrates.
Timing.DeviceProfiles = {
	keyboard = {
		id = "keyboard",
		defaultOffsetSeconds = 0.02,
		offsetToleranceSeconds = 0.02,
		qaPriority = "primary_desktop",
	},
	touch = {
		id = "touch",
		defaultOffsetSeconds = 0.05,
		offsetToleranceSeconds = 0.04,
		qaPriority = "primary_mobile",
	},
	gamepad = {
		id = "gamepad",
		defaultOffsetSeconds = 0.03,
		offsetToleranceSeconds = 0.04,
		qaPriority = "secondary_console",
	},
}

local function getDifficultyProfile(difficulty: string?)
	return Timing.DifficultyProfiles[difficulty or Timing.DefaultDifficulty] or Timing.DifficultyProfiles[Timing.DefaultDifficulty]
end

local function getDeviceProfile(device: string?)
	return Timing.DeviceProfiles[device or Timing.DefaultDevice] or Timing.DeviceProfiles[Timing.DefaultDevice]
end

-- One beat in seconds; a missing or broken tempo reads as 120 bpm.
function Timing.beatSeconds(bpm: any): number
	local value = tonumber(bpm)

	return if value ~= nil and value > 0 then 60 / value else 0.5
end

function Timing.beatToSeconds(beat: number, bpm: number): number
	return (beat - 1) * Timing.beatSeconds(bpm)
end

function Timing.getWindows(difficulty: string?, device: string?)
	local difficultyProfile = getDifficultyProfile(difficulty)
	local deviceProfile = getDeviceProfile(device)

	return {
		perfectWindow = difficultyProfile.perfectWindow,
		greatWindow = difficultyProfile.greatWindow,
		goodWindow = difficultyProfile.goodWindow,
		badWindow = difficultyProfile.badWindow,
		deviceDefaultOffsetSeconds = deviceProfile.defaultOffsetSeconds,
		offsetToleranceSeconds = deviceProfile.offsetToleranceSeconds,
		maxBeatTravel = difficultyProfile.maxBeatTravel,
	}
end

function Timing.gradeWithWindows(hitTime: number, targetTime: number, windows: any): string
	local delta = math.abs(hitTime - targetTime)

	if delta <= windows.perfectWindow then
		return "Perfect"
	end

	-- Great and Bad are optional tiers; when a caller omits their windows we
	-- fall back to the three-tier ladder so older callers keep working.
	if windows.greatWindow ~= nil and delta <= windows.greatWindow then
		return "Great"
	end

	if delta <= windows.goodWindow then
		return "Good"
	end

	if windows.badWindow ~= nil and delta <= windows.badWindow then
		return "Bad"
	end

	return "Miss"
end

function Timing.grade(hitTime: number, targetTime: number): string
	return Timing.gradeWithWindows(hitTime, targetTime, {
		perfectWindow = Timing.PerfectWindow,
		greatWindow = Timing.GreatWindow,
		goodWindow = Timing.GoodWindow,
		badWindow = Timing.BadWindow,
	})
end

-- Beats between consecutive targets for a difficulty: the "travel window" the
-- player has to walk to the next tile and settle (easy 4 / normal 2 / hard 1 / expert 1).
function Timing.getTravelWindowBeats(difficulty: string?): number
	local profile = getDifficultyProfile(difficulty)
	return profile.travelWindowBeats or 2
end

-- Difficulties with a corner gap keep every target on the dancer's row or
-- column (StraightSteps); nil leaves diagonal targets in.
function Timing.getCornerStepBeats(difficulty: string?): number?
	local profile = Timing.DifficultyProfiles[difficulty or Timing.DefaultDifficulty]
	return if profile ~= nil then profile.cornerStepBeats else nil
end

-- Expert wants a tighter arrive band than easy. Multiplies both edges.
function Timing.getArriveBandScale(difficulty: string?): number
	return getDifficultyProfile(difficulty).arriveBandScale
end

-- How long a note takes to travel the highway to its key. Shorter on harder
-- difficulties, so notes move faster and less is visible at once. These match
-- Friday Night Funkin' at its usual chart speeds (FNF moves notes 0.45 px per
-- ms times the chart's scroll speed on a 720 px screen).
function Timing.getHighwayLeadSeconds(difficulty: string?): number
	local profile = getDifficultyProfile(difficulty)
	return profile.highwayLeadSeconds or 1.0
end

-- Seconds the avatar takes to cross one tile; faster difficulties snap harder.
function Timing.getStepSeconds(difficulty: string?): number
	local profile = getDifficultyProfile(difficulty)
	return profile.stepSeconds or 0.12
end

-- onBeat tiers: within perfect is Perfect, within great is Great, anything
-- else that still counts is Good. There is no Bad and early never misses.
function Timing.getOnBeatWindows(difficulty: string?): { perfectWindow: number, greatWindow: number }
	local profile = getDifficultyProfile(difficulty)

	return {
		perfectWindow = profile.onBeatPerfectWindow or 0.06,
		greatWindow = profile.onBeatGreatWindow or 0.14,
	}
end

-- Stand-and-wait grade: judged by whether the player is standing on the target
-- tile when the beat lands, and how long they were settled there beforehand.
-- settleSeconds is time spent on the tile before the beat; beatSeconds = 60/bpm.
function Timing.gradeStandAndWait(onTile: boolean, settleSeconds: number, beatSeconds: number): string
	if not onTile then
		return "Miss"
	end

	if settleSeconds >= Timing.StandPerfectBeatFraction * beatSeconds then
		return "Perfect"
	end

	if settleSeconds >= Timing.StandGreatSeconds then
		return "Great"
	end

	return "Good"
end

function Timing.analyzeMap(map: any, difficulty: string?)
	local profile = getDifficultyProfile(difficulty or map.difficulty)
	local warnings = {}
	local previous = nil
	local maxObservedTravel = 0

	for index, step in map.steps or {} do
		if previous ~= nil then
			local beatGap = math.max(step.beat - previous.beat, 0.001)
			local travel = math.abs(step.x - previous.x) + math.abs(step.y - previous.y)
			local travelPerBeat = travel / beatGap
			maxObservedTravel = math.max(maxObservedTravel, travelPerBeat)

			if travelPerBeat > profile.maxBeatTravel then
				table.insert(warnings, {
					index = index,
					beat = step.beat,
					reason = "travel_budget_exceeded",
					travelPerBeat = travelPerBeat,
					maxBeatTravel = profile.maxBeatTravel,
				})
			end
		end

		previous = step
	end

	return {
		difficulty = profile.id,
		stepCount = #(map.steps or {}),
		maxObservedTravel = maxObservedTravel,
		maxBeatTravel = profile.maxBeatTravel,
		warnings = warnings,
		ok = #warnings == 0,
	}
end

return Timing
