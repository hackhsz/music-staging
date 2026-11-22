--!strict
-- Daily challenges (retention hook). Each UTC day picks a deterministic set of 3
-- challenges from a template pool; progress accumulates over the day and rewards
-- Beat Coins when a target is hit. Pure functions so the logic is unit-checkable.

local DailyChallenges = {}

DailyChallenges.DailyCount = 3

-- art is the flat icon the Quests window shows on the challenge's tile.
-- metric = key accumulated in the per-day progress table; target = amount to reach.
-- Cumulative metrics (plays/clears/perfects/greatPlus) sum across the day; "best"
-- metrics (bestCombo/bestScore) keep the day's max. Both compare progress >= target.
DailyChallenges.Templates = {
	{ id = "play-5", art = "rbxassetid://110566197397498", icon = "Icon_QuestPlay", glyph = "🎵", name = "Play 5 songs", metric = "plays", target = 5, reward = 50 },
	{ id = "clear-3", art = "rbxassetid://111667487510179", icon = "Icon_QuestClear", glyph = "✅", name = "Clear 3 songs", metric = "clears", target = 3, reward = 60 },
	{ id = "perfect-50", art = "rbxassetid://130771749257205", icon = "Icon_QuestPerfect", glyph = "💯", name = "Land 50 Perfects", metric = "perfects", target = 50, reward = 70 },
	{ id = "greatplus-40", art = "rbxassetid://124261961477505", icon = "Icon_QuestAim", glyph = "🎯", name = "Land 40 Great-or-better", metric = "greatPlus", target = 40, reward = 60 },
	{ id = "combo-25", art = "rbxassetid://79191973447065", icon = "Icon_QuestCombo", glyph = "🔗", name = "Reach a 25 combo", metric = "bestCombo", target = 25, reward = 50 },
	{ id = "score-9000", art = "rbxassetid://126441945473415", icon = "Icon_QuestScore", glyph = "🏅", name = "Score 9000 in one song", metric = "bestScore", target = 9000, reward = 80 },
}

function DailyChallenges.dayKey(unixSeconds: number?): number
	return math.floor((unixSeconds or 0) / 86400)
end

local function nextSeed(seed: number): number
	return (seed * 1103515245 + 12345) % 2147483648
end

-- Deterministic per-day selection of DailyCount distinct templates.
function DailyChallenges.rollDaily(dayKey: number)
	local templates = DailyChallenges.Templates
	local n = #templates
	local order = {}
	for i = 1, n do
		order[i] = i
	end

	local seed = (math.abs(dayKey) % 2147483648) + 1
	for i = n, 2, -1 do
		seed = nextSeed(seed)
		local j = (seed % i) + 1
		order[i], order[j] = order[j], order[i]
	end

	local selected = {}
	for i = 1, math.min(DailyChallenges.DailyCount, n) do
		table.insert(selected, templates[order[i]])
	end
	return selected
end

function DailyChallenges.emptyProgress()
	return { plays = 0, clears = 0, perfects = 0, greatPlus = 0, bestCombo = 0, bestScore = 0 }
end

-- Fold one song summary into the day's progress table (mutates + returns it).
function DailyChallenges.advance(progress: any, summary: any)
	progress = progress or DailyChallenges.emptyProgress()
	summary = summary or {}

	progress.plays = (progress.plays or 0) + 1
	if summary.cleared ~= false then
		progress.clears = (progress.clears or 0) + 1
	end
	progress.perfects = (progress.perfects or 0) + (tonumber(summary.perfects) or 0)
	progress.greatPlus = (progress.greatPlus or 0) + (tonumber(summary.perfects) or 0) + (tonumber(summary.greats) or 0)
	progress.bestCombo = math.max(progress.bestCombo or 0, tonumber(summary.maxCombo) or 0)
	progress.bestScore = math.max(progress.bestScore or 0, tonumber(summary.score) or 0)

	return progress
end

function DailyChallenges.isComplete(template: any, progress: any): boolean
	return (progress and (progress[template.metric] or 0) or 0) >= template.target
end

return DailyChallenges
