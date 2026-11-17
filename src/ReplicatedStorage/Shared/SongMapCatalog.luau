local GeneratedDoYouReadMe = require(script.Parent.Songs.GeneratedDoYouReadMe)
local GeneratedIDontWait = require(script.Parent.Songs.GeneratedIDontWait)
local GeneratedJustALittleStatic = require(script.Parent.Songs.GeneratedJustALittleStatic)
local GeneratedOurHearts = require(script.Parent.Songs.GeneratedOurHearts)
local GeneratedUnderTheStarlight = require(script.Parent.Songs.GeneratedUnderTheStarlight)
local SongSchema = require(script.Parent.SongSchema)
local StraightSteps = require(script.Parent.StraightSteps)
local Timing = require(script.Parent.Timing)
local TutorialChart = require(script.Parent.TutorialChart)

local SongMapCatalog = {}

local DIFFICULTY_ORDER = { easy = 1, normal = 2, hard = 3, expert = 4 }
-- Star rating: notes a second, scaled by tempo (a faster song asks more of the same
-- density), plus a step per difficulty for its shorter travel window, then cut into
-- one to five stars. Items and danger tiles are not notes you step for.
local STAR_TEMPO = 120
local STAR_DIFFICULTY_STEP = 0.8
local STAR_THRESHOLDS = { 1.15, 2.3, 3.2, 4.1 }
local NOT_NOTES = { item = true, danger = true }

-- The songs in play; the others wait in ServerStorage.ArchivedSongs. The first
-- is the default. pack is the song picker tab a song is listed under.
local SONGS = {
	{ id = "our-hearts", mainDifficulty = "normal", pack = 1, charts = GeneratedOurHearts },
	{ id = "i-dont-wait", mainDifficulty = "normal", pack = 1, charts = GeneratedIDontWait },
	{ id = "under-the-starlight", mainDifficulty = "normal", pack = 1, charts = GeneratedUnderTheStarlight },
	{ id = "just-a-little-static", mainDifficulty = "normal", pack = 2, charts = GeneratedJustALittleStatic },
	{ id = "do-you-read-me", mainDifficulty = "normal", pack = 2, charts = GeneratedDoYouReadMe },
}

-- Each song's main chart is listed under the song's id and each other difficulty
-- right after it as "<song id>-<difficulty>", all on the same audio.
local function buildMaps(): { any }
	local maps = {}

	for _, song in SONGS do
		local main = song.mainDifficulty
		local charts = table.clone(song.charts)

		table.sort(charts, function(a, b)
			local first = a.difficulty == main and b.difficulty ~= main

			return first or (b.difficulty ~= main and (DIFFICULTY_ORDER[a.difficulty] or 9) < (DIFFICULTY_ORDER[b.difficulty] or 9))
		end)

		for _, chart in charts do
			local map = table.clone(chart)
			map.id = if chart.difficulty == main then song.id else song.id .. "-" .. chart.difficulty
			map.pack = song.pack

			local cornerBeats = Timing.getCornerStepBeats(chart.difficulty)

			if cornerBeats ~= nil then
				map.steps = StraightSteps.apply(map, cornerBeats)
			end
			table.insert(maps, map)
		end
	end

	return maps
end

function SongMapCatalog.starRating(map: any): number
	local notes = 0

	for _, step in map.steps or {} do
		if not NOT_NOTES[step.type] then
			notes += 1
		end
	end

	local seconds = math.max(tonumber(map.durationSeconds) or 0, 1)
	local tempo = (tonumber(map.bpm) or STAR_TEMPO) / STAR_TEMPO
	local level = (DIFFICULTY_ORDER[map.difficulty] or 2) - 1
	local weight = notes / seconds * tempo + level * STAR_DIFFICULTY_STEP
	local stars = 1

	for _, threshold in STAR_THRESHOLDS do
		if weight >= threshold then
			stars += 1
		end
	end

	return stars
end

SongMapCatalog.Maps = buildMaps()
-- The first-join lesson's drills, never listed or picked.
SongMapCatalog.TutorialDrills = {}

for drill = 1, TutorialChart.DrillCount do
	table.insert(SongMapCatalog.TutorialDrills, TutorialChart.build(drill))
end

-- A lesson drill by its chart id (TutorialChart.drillId), or nil.
function SongMapCatalog.getTutorialDrill(chartId: string)
	local drill = TutorialChart.drillOf(chartId)

	return if drill ~= nil then SongMapCatalog.TutorialDrills[drill] else nil
end

function SongMapCatalog.getMap(songId: string)
	for _, map in SongMapCatalog.Maps do
		if map.id == songId then
			return map
		end
	end

	return nil
end

function SongMapCatalog.getDefaultMap()
	return SongMapCatalog.Maps[1]
end

function SongMapCatalog.listSongs()
	local songs = {}

	for index, map in SongMapCatalog.Maps do
		table.insert(songs, {
			index = index,
			id = map.id,
			title = map.title,
			artist = map.artist,
			difficulty = map.difficulty,
			bpm = map.bpm,
			durationSeconds = map.durationSeconds,
			visualTheme = map.visualTheme,
			performanceGoal = map.performanceGoal,
			pack = map.pack,
			stars = SongMapCatalog.starRating(map),
		})
	end

	return songs
end

function SongMapCatalog.validateAll(): (boolean, string)
	local maps = table.clone(SongMapCatalog.Maps)
	table.move(SongMapCatalog.TutorialDrills, 1, #SongMapCatalog.TutorialDrills, #maps + 1, maps)

	for _, map in maps do
		local ok, reason = SongSchema.validate(map)

		if not ok then
			return false, ("%s: %s"):format(map.id or "unknown", reason)
		end
	end

	return true, "ok"
end

return SongMapCatalog
