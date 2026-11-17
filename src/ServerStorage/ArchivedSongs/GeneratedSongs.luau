--!strict
-- Extra generated tracks + difficulty variants (issue 037), all built from the
-- BeatPatterns vocabulary via ChartGenerator so the catalog reaches a launch-credible
-- size with real Easy/Normal/Hard variety.

local ChartGenerator = require(script.Parent.ChartGenerator)

local function starlightTheme()
	return { name = "Neon Idol Night", primary = "violet", accent = "cyan", mood = "driving_authored_patterns" }
end

local function auroraTheme()
	return { name = "Aurora Salon", primary = "teal", accent = "rose", mood = "flowing_authored_patterns" }
end

local GeneratedSongs = {}

GeneratedSongs.List = {
	ChartGenerator.generate({
		id = "auto-starlight-run",
		title = "Starlight Run (Auto)",
		artist = "Generated",
		difficulty = "normal",
		bpm = 128,
		targetBeats = 200,
		holdEvery = 16,
		visualTheme = starlightTheme(),
		performanceGoal = { label = "PATTERN RUN GOAL", targetScore = 12000 },
	}),

	-- Hard variant of the Starlight track: faster + denser + tighter holds.
	ChartGenerator.generate({
		id = "auto-starlight-run-hard",
		title = "Starlight Run (Auto) - Hard",
		artist = "Generated",
		difficulty = "hard",
		bpm = 150,
		targetBeats = 240,
		holdEvery = 12,
		visualTheme = starlightTheme(),
		performanceGoal = { label = "HARD RUN GOAL", targetScore = 16000 },
	}),

	-- A second track, Normal.
	ChartGenerator.generate({
		id = "auto-aurora-drive",
		title = "Aurora Drive (Auto)",
		artist = "Generated",
		difficulty = "normal",
		bpm = 120,
		targetBeats = 180,
		holdEvery = 16,
		visualTheme = auroraTheme(),
		performanceGoal = { label = "DRIVE GOAL", targetScore = 11000 },
	}),

	-- Easy variant of the second track: slower, fewer beats, gentle.
	ChartGenerator.generate({
		id = "auto-aurora-drive-easy",
		title = "Aurora Drive (Auto) - Easy",
		artist = "Generated",
		difficulty = "easy",
		bpm = 100,
		targetBeats = 120,
		holdEvery = 0,
		visualTheme = auroraTheme(),
		performanceGoal = { label = "EASY GOAL", targetScore = 6000 },
	}),
}

return GeneratedSongs
