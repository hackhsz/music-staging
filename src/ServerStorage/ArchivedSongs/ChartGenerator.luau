--!strict
-- Composes a chart for a track with no score to read. The song takes a pop
-- shape (calm verses, builds, choruses, a closing drop), each bar takes a rhythm
-- that thickens with the energy, and the dancer moves in BeatPatterns figures
-- turned to fit the pad. Every move stays inside the difficulty's travel budget
-- and step time, so the chart is reachable at its own difficulty.

local BeatPatterns = require(script.Parent.BeatPatterns)
local Timing = require(script.Parent.Parent.Timing)

local ChartGenerator = {}

type Coord = { x: number, y: number }
type Rhythm = { number }
type Section = { beat: number, energy: string }

local BEATS_PER_BAR = 4
local PHRASE_BEATS = 16
local LEAD_IN_BEATS = 2
local REST_BEFORE_LIFT_BEATS = 1.5
local HOLD_MIN_GAP_BEATS = 1.5
local HOLD_RELEASE_BEATS = 0.75
local HOLD_MAX_BEATS = 2
local ITEM_WINDOW_BEATS = 16
local EPSILON = 1e-4
local CENTRE = { x = 3, y = 3 }

local SONG_SHAPE = { "calm", "calm", "build", "chorus", "chorus", "calm", "build", "chorus", "drop", "drop", "calm" }
local ENERGY_RANK = { calm = 1, build = 2, chorus = 3, drop = 4 }

local RHYTHMS: { [string]: { Rhythm } } = {
	calm = { { 0, 2 }, { 0, 1, 2 }, { 0, 2, 3 } },
	build = { { 0, 1, 2, 3 }, { 0, 1, 2 }, { 0, 1.5, 2, 3 } },
	chorus = { { 0, 1, 2, 3 }, { 0, 1, 1.5, 2, 3 }, { 0, 0.5, 1, 2, 3 }, { 0, 1, 2, 2.5, 3 } },
	drop = { { 0, 0.5, 1, 2, 2.5, 3 }, { 0, 1, 1.5, 2, 3, 3.5 }, { 0, 1, 2, 3 } },
}

local EASY_RHYTHMS: { [string]: { Rhythm } } = {
	calm = { { 0, 2 } },
	build = { { 0, 2 }, { 0, 1, 2 } },
	chorus = { { 0, 1, 2 }, { 0, 2, 3 } },
	drop = { { 0, 1, 2, 3 }, { 0, 1, 2 } },
}

local ORIENTATIONS: { (number, number) -> (number, number) } = {
	function(dx, dy) return dx, dy end,
	function(dx, dy) return -dx, dy end,
	function(dx, dy) return dx, -dy end,
	function(dx, dy) return -dx, -dy end,
	function(dx, dy) return dy, dx end,
	function(dx, dy) return -dy, dx end,
	function(dx, dy) return dy, -dx end,
	function(dx, dy) return -dy, -dx end,
}

export type GenerateOptions = {
	id: string,
	title: string,
	bpm: number?,
	difficulty: string?,
	artist: string?,
	targetBeats: number?,
	holdEvery: number?,
	visualTheme: any?,
	performanceGoal: any?,
}

local function newRandom(text: string): () -> number
	local state = 7

	for index = 1, #text do
		state = (state * 31 + string.byte(text, index)) % 2147483647
	end

	return function()
		state = (state * 48271) % 2147483647

		return state / 2147483647
	end
end

local function inBounds(x: number, y: number): boolean
	return x >= 1 and x <= BeatPatterns.BoardSize and y >= 1 and y <= BeatPatterns.BoardSize
end

local function distance(a: Coord, b: Coord): number
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- A move of n tiles is n presses, the last on the beat, and the dancer has to
-- be off a hold before leaving it.
local function moveFits(
	tiles: number,
	gapBeats: number,
	beatSeconds: number,
	profile: any,
	freeSeconds: number?
): boolean
	if tiles == 0 or tiles / gapBeats > profile.maxBeatTravel + EPSILON then
		return false
	end

	local free = freeSeconds or gapBeats * beatSeconds

	return (tiles + 1) * profile.stepSeconds <= free
end

local function sectionEnergies(targetBeats: number): { Section }
	local phrases = math.max(1, math.ceil(targetBeats / PHRASE_BEATS))
	local sections = {}

	for phrase = 1, phrases do
		local shapeIndex = phrase

		if phrase == phrases then
			shapeIndex = #SONG_SHAPE
		elseif phrase >= #SONG_SHAPE then
			shapeIndex = 4 + (phrase - 4) % 6
		end

		local energy = SONG_SHAPE[shapeIndex]
		local previous = sections[#sections]

		if previous == nil or previous.energy ~= energy then
			table.insert(sections, { beat = 1 + (phrase - 1) * PHRASE_BEATS, energy = energy })
		end
	end

	return sections
end

local function energyAt(sections: { Section }, beat: number): string
	local energy = sections[1].energy

	for _, section in sections do
		if section.beat > beat + EPSILON then
			break
		end

		energy = section.energy
	end

	return energy
end

local function liftsAt(sections: { Section }, beat: number): boolean
	for index = 2, #sections do
		local section = sections[index]

		if beat < section.beat and beat >= section.beat - REST_BEFORE_LIFT_BEATS - EPSILON then
			local rank = ENERGY_RANK[section.energy]

			return rank >= ENERGY_RANK.chorus and rank > ENERGY_RANK[sections[index - 1].energy]
		end
	end

	return false
end

local function noteBeats(
	sections: { Section },
	targetBeats: number,
	difficulty: string,
	bpm: number,
	random: () -> number
): { number }
	local profile = Timing.DifficultyProfiles[difficulty] or Timing.DifficultyProfiles.normal
	local rhythms = if difficulty == "easy" then EASY_RHYTHMS else RHYTHMS
	local eighthSeconds = 30 / bpm
	local beats = {}
	local bar = 1 + LEAD_IN_BEATS

	while bar <= targetBeats do
		local energy = energyAt(sections, bar)
		local options = rhythms[energy]
		local rhythm = options[1 + math.floor(random() * #options)]
		local eighths = difficulty ~= "easy"
			and eighthSeconds >= 2 * profile.stepSeconds
			and (ENERGY_RANK[energy] >= ENERGY_RANK.chorus or (energy == "build" and difficulty ~= "normal"))

		for _, offset in rhythm do
			local beat = bar + offset
			local offBeat = offset % 1 ~= 0

			if beat <= targetBeats and (eighths or not offBeat) and not liftsAt(sections, beat) then
				table.insert(beats, beat)
			end
		end

		bar += BEATS_PER_BAR
	end

	return beats
end

local function chooseFigure(energy: string, last: string?, random: () -> number): string
	local names = BeatPatterns.EnergyMoves[energy]
	local total = 0

	for index, name in names do
		if name ~= last then
			total += 1 / index
		end
	end

	local roll = random() * total

	for index, name in names do
		if name ~= last then
			roll -= 1 / index

			if roll <= 0 then
				return name
			end
		end
	end

	return names[1]
end

local function layOut(
	beats: { number },
	holds: { [number]: number },
	sections: { Section },
	profile: any,
	beatSeconds: number,
	random: () -> number
): { Coord }
	local tiles: { Coord } = { CENTRE }
	local visits: { [string]: number } = { ["3:3"] = 1 }
	local lastFigure: string? = nil
	local index = 2

	local function tryMoves(moves: { { number } }): (number?, { Coord }?)
		local here = tiles[#tiles]
		local placed = {}
		local crowd = 0

		for offset, move in moves do
			local noteIndex = index + offset - 1

			if noteIndex > #beats then
				break
			end

			local gap = beats[noteIndex] - beats[noteIndex - 1]
			local held = holds[noteIndex - 1]
			local free = if held then gap * beatSeconds - held else nil
			local span = math.abs(move[1]) + math.abs(move[2])

			if (held and span > 1) or not moveFits(span, gap, beatSeconds, profile, free) then
				return nil, nil
			end

			local x, y = here.x + move[1], here.y + move[2]

			if not inBounds(x, y) then
				return nil, nil
			end

			here = { x = x, y = y }
			crowd += visits[x .. ":" .. y] or 0
			table.insert(placed, here)
		end

		if #placed == 0 then
			return nil, nil
		end

		return random() - 0.35 * crowd / math.max(1, #tiles / 25), placed
	end

	while index <= #beats do
		local energy = energyAt(sections, beats[index])
		local bestScore: number, bestPlaced: { Coord }?, bestName: string? = -math.huge, nil, nil

		for _ = 1, 4 do
			local name = chooseFigure(energy, lastFigure, random)

			for _, orient in ORIENTATIONS do
				local moves = {}

				for _, move in BeatPatterns.Moves[name] do
					local dx, dy = orient(move[1], move[2])
					table.insert(moves, { dx, dy })
				end

				local score, placed = tryMoves(moves)

				if score ~= nil and score > bestScore then
					bestScore, bestPlaced, bestName = score, placed, name
				end
			end

			if bestPlaced ~= nil then
				break
			end
		end

		if bestPlaced == nil then
			for _, move in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
				local score, placed = tryMoves({ move })

				if score ~= nil and score > bestScore then
					bestScore, bestPlaced, bestName = score, placed, nil
				end
			end
		end

		assert(bestPlaced ~= nil, "[DanceDanceStep] ChartGenerator found no playable move")

		for _, tile in bestPlaced do
			table.insert(tiles, tile)
			local key = tile.x .. ":" .. tile.y
			visits[key] = (visits[key] or 0) + 1
		end

		lastFigure = bestName
		index += #bestPlaced
	end

	return tiles
end

local function pickHolds(beats: { number }, holdEvery: number, beatSeconds: number): { [number]: number }
	local holds = {}

	if holdEvery <= 0 then
		return holds
	end

	for index = holdEvery, #beats - 1, holdEvery do
		local gap = beats[index + 1] - beats[index]

		if gap >= HOLD_MIN_GAP_BEATS then
			holds[index] = math.floor(math.min(gap - HOLD_RELEASE_BEATS, HOLD_MAX_BEATS) * beatSeconds * 1000) / 1000
		end
	end

	return holds
end

local function addItems(
	steps: { any },
	sections: { Section },
	targetBeats: number,
	difficulty: string,
	profile: any,
	beatSeconds: number
)
	local stride = if difficulty == "easy" then 1 else 0.5
	local items = {}

	for sectionIndex, section in sections do
		local stop = if sections[sectionIndex + 1] then sections[sectionIndex + 1].beat else targetBeats + 1

		if ENERGY_RANK[section.energy] < ENERGY_RANK.chorus then
			continue
		end

		for window = section.beat, stop - ITEM_WINDOW_BEATS / 2, ITEM_WINDOW_BEATS do
			local placed = false

			for index = 1, #steps - 1 do
				local here, there = steps[index], steps[index + 1]

				if placed or here.beat < window or there.beat > window + ITEM_WINDOW_BEATS or here.type == "hold" then
					continue
				end

				local beat = here.beat + stride

				while not placed and beat < there.beat - EPSILON do
					for x = 1, BeatPatterns.BoardSize do
						for y = 1, BeatPatterns.BoardSize do
							local tile = { x = x, y = y }
							local reach, onward = distance(here, tile), distance(tile, there)
							local offPath = reach + onward > distance(here, there)

							if not placed and offPath
								and moveFits(reach, beat - here.beat, beatSeconds, profile)
								and moveFits(onward, there.beat - beat, beatSeconds, profile)
							then
								table.insert(items, { beat = beat, x = x, y = y, type = "item" })
								placed = true
							end
						end
					end

					beat += stride
				end
			end
		end
	end

	for _, item in items do
		table.insert(steps, item)
	end

	table.sort(steps, function(a, b)
		return a.beat < b.beat
	end)
end

function ChartGenerator.generate(opts: GenerateOptions)
	local bpm = opts.bpm or 96
	local targetBeats = opts.targetBeats or 96
	local difficulty = opts.difficulty or "normal"
	local profile = Timing.DifficultyProfiles[difficulty] or Timing.DifficultyProfiles.normal
	local beatSeconds = Timing.beatSeconds(bpm)
	local random = newRandom(opts.id)
	local sections = sectionEnergies(targetBeats)
	local beats = noteBeats(sections, targetBeats, difficulty, bpm, random)
	local holds = pickHolds(beats, opts.holdEvery or 0, beatSeconds)
	local tiles = layOut(beats, holds, sections, profile, beatSeconds, random)
	local steps = {}

	for index, beat in beats do
		local step: any = { beat = beat, x = tiles[index].x, y = tiles[index].y }

		if holds[index] then
			step.type = "hold"
			step.holdSeconds = holds[index]
		end

		table.insert(steps, step)
	end

	addItems(steps, sections, targetBeats, difficulty, profile, beatSeconds)

	local lastBeat = #steps > 0 and steps[#steps].beat or 1
	local durationSeconds = math.ceil(Timing.beatToSeconds(lastBeat, bpm) + 2)

	return {
		id = opts.id,
		title = opts.title,
		artist = opts.artist or "Auto Chart",
		difficulty = difficulty,
		bpm = bpm,
		durationSeconds = durationSeconds,
		previewBeats = 1,
		generated = true,
		visualTheme = opts.visualTheme,
		performanceGoal = opts.performanceGoal,
		sections = sections,
		steps = steps,
	}
end

return ChartGenerator
