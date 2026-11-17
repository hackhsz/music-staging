--!strict
local LEVEL_CAP = 50
local XP_TO_NEXT = { 100, 140, 180, 230, 280, 340, 400, 470, 540, 620, 700, 790, 880, 980 }
local XP_TO_NEXT_GROWTH = 100
local RUN_XP_BASE = 40
local RUN_XP_FIRST_CLEAR = 50
local RUN_XP_RANK = { S = 60, A = 40, B = 25, C = 10 }
local CROWN_ORDER = { "CLEAR", "FULL GROOVE", "PERFECT GROOVE" }
local CROWN_POINTS = { CLEAR = 1, ["FULL GROOVE"] = 2, ["PERFECT GROOVE"] = 3 }
local DEFAULT_MAX_STARS = 1

local LevelUnlocks = require(script.LevelUnlocks)
local SongPacks = require(script.SongPacks)
local DanceGrades = require(script.DanceGrades)

local Progression = {}
Progression.LEVEL_CAP = LEVEL_CAP
Progression.CROWN_ORDER = CROWN_ORDER
Progression.LevelUnlocks = LevelUnlocks
Progression.SongPacks = SongPacks
Progression.DanceGrades = DanceGrades

function Progression.xpToNext(level: number): number
	if level >= LEVEL_CAP then
		return 0
	end
	if level <= #XP_TO_NEXT then
		return XP_TO_NEXT[level]
	end
	return XP_TO_NEXT[#XP_TO_NEXT] + XP_TO_NEXT_GROWTH * (level - #XP_TO_NEXT)
end

function Progression.totalXpForLevel(level: number): number
	local total = 0
	for index = 1, math.clamp(level, 1, LEVEL_CAP) - 1 do
		total += Progression.xpToNext(index)
	end
	return total
end

function Progression.levelForXp(totalXp: number)
	local level = 1
	local remaining = math.max(0, totalXp)
	while level < LEVEL_CAP and remaining >= Progression.xpToNext(level) do
		remaining -= Progression.xpToNext(level)
		level += 1
	end

	if level == LEVEL_CAP then
		return { level = level, xpIntoLevel = 0, xpToNext = 0 }
	end
	return { level = level, xpIntoLevel = remaining, xpToNext = Progression.xpToNext(level) }
end

function Progression.xpForRun(run: { rank: string?, firstClear: boolean?, xpMultiplier: number? }): number
	if not run.rank then
		return 0
	end
	local base = RUN_XP_BASE + (RUN_XP_RANK[run.rank] or 0) + (if run.firstClear then RUN_XP_FIRST_CLEAR else 0)
	return math.floor(base * math.max(0, run.xpMultiplier or 1))
end

function Progression.crownTier(crown: string?): number
	return if crown then table.find(CROWN_ORDER, crown) or 0 else 0
end

function Progression.crownPoints(crown: string?): number
	return if crown then CROWN_POINTS[crown] or 0 else 0
end

function Progression.crownPointGain(previousCrown: string?, newCrown: string?): number
	return math.max(0, Progression.crownPoints(newCrown) - Progression.crownPoints(previousCrown))
end

function Progression.songKey(songId: string, difficulty: string): string
	return songId .. ":" .. difficulty
end

function Progression.encodeCrowns(crowns: { [string]: string }): string
	local parts = {}
	for key, crown in crowns do
		table.insert(parts, key .. "=" .. crown)
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function Progression.decodeCrowns(text: string?): { [string]: string }
	local crowns = {}
	for key, crown in string.gmatch(text or "", "([^;=]+)=([^;]+)") do
		crowns[key] = crown
	end
	return crowns
end

function Progression.bestCrownForSong(crowns: { [string]: string }, songId: string): string?
	local best, bestTier = nil, 0
	for key, crown in crowns do
		if string.sub(key, 1, #songId + 1) == songId .. ":" and Progression.crownTier(crown) > bestTier then
			best, bestTier = crown, Progression.crownTier(crown)
		end
	end
	return best
end

function Progression.chartStars(chart, config): number
	return chart.stars or config.DIFFICULTY_STARS[chart.difficulty] or 1
end

function Progression.unlocksAt(level: number)
	local reached = {}
	for _, unlock in LevelUnlocks do
		if unlock.level == level then
			table.insert(reached, unlock)
		end
	end
	return reached
end

function Progression.hasUnlock(level: number, unlockId: string): boolean
	for _, unlock in LevelUnlocks do
		if unlock.id == unlockId then
			return level >= unlock.level
		end
	end
	return false
end

function Progression.unlockLevel(unlockId: string): number?
	for _, unlock in LevelUnlocks do
		if unlock.id == unlockId then
			return unlock.level
		end
	end
	return nil
end

function Progression.maxStars(level: number): number
	local stars = DEFAULT_MAX_STARS
	for _, unlock in LevelUnlocks do
		if unlock.maxStars and level >= unlock.level then
			stars = math.max(stars, unlock.maxStars)
		end
	end
	return stars
end

function Progression.starsUnlockLevel(stars: number): number?
	for _, unlock in LevelUnlocks do
		if unlock.maxStars and unlock.maxStars >= stars then
			return unlock.level
		end
	end
	return nil
end

function Progression.itemSlots(level: number, gradeIndex: number): number
	local slots = 0
	for _, unlock in LevelUnlocks do
		if unlock.itemSlots and level >= unlock.level then
			slots = math.max(slots, unlock.itemSlots)
		end
	end
	for index = 1, math.clamp(gradeIndex, 0, #DanceGrades) do
		slots = math.max(slots, DanceGrades[index].itemSlots or 0)
	end
	return slots
end

function Progression.packFor(songId: string)
	for name, pack in SongPacks do
		if table.find(pack.songs, songId) then
			return name, pack
		end
	end
	return nil, nil
end

function Progression.songUnlockPoints(songId: string): number
	local _, pack = Progression.packFor(songId)
	return if pack then pack.threshold else 0
end

function Progression.isSongUnlocked(songId: string, crownPoints: number): boolean
	return crownPoints >= Progression.songUnlockPoints(songId)
end

function Progression.gradeName(gradeIndex: number): string?
	local grade = DanceGrades[gradeIndex]
	return if grade then grade.name else nil
end

return Progression
