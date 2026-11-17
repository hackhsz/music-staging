--!strict
local ScoreSummary = require(script.Parent.Parent.ScoreSummary)

export type SetChart = { chartId: string, songTitle: string, difficulty: string }
export type RankUp = { chartId: string, songTitle: string, difficulty: string, grade: string, challenger: string }
export type Rank = { name: string, xp: number, rankUp: RankUp?, opens: { string }, set: { SetChart }, lowerNotice: string? }
export type RunContext = { firstFinish: boolean, friendHere: boolean, firstToday: boolean, rank: number? }
export type XpParts = {
	finish: number,
	grade: number,
	first: number,
	friend: number,
	doubled: boolean,
	multiplier: number,
	payClass: string,
	scaled: number,
}
export type XpPreview = { grade: string, finish: number, bonus: number, first: number, total: number, payClass: string }
export type StageRow = {
	chartId: string,
	songTitle: string,
	difficulty: string,
	finished: boolean,
	grade: string?,
	xp: XpPreview,
	challenger: string?,
}
export type StageEntry = {
	rank: number,
	name: string,
	xp: number,
	state: string,
	challenger: string?,
	need: string,
	opens: { string },
	charts: { StageRow },
}
export type StageChallenger = StageRow & {
	name: string,
	needGrade: string,
	target: number,
	state: string,
	attempts: number,
	bestScore: number,
}
export type Stages = {
	rank: number,
	name: string,
	xp: number,
	threshold: number?,
	toChallenge: number,
	cleared: number,
	rows: { StageRow },
	challenger: StageChallenger?,
	nextChart: string?,
	nextOpens: { string },
	ranks: { { name: string, xp: number } },
	dailyAvailable: boolean,
	playMode: string,
	opens: { string },
	beaten: { [string]: any }?,
	revealPending: boolean,
	showNotice: boolean,
	lowerNotice: string?,
	stageList: { StageEntry },
}
export type Progress = {
	rank: number,
	name: string,
	total: number,
	into: number,
	need: number,
	maxed: boolean,
	ready: boolean,
	nextName: string?,
	nextOpens: string?,
	rankUp: RankUp?,
}

local DEFAULT_RANK = 1
-- SongMapCatalog lists a song's normal chart under the bare song id.
local MAIN_DIFFICULTY = "normal"
local PREVIEW_GRADE = "B"
local GRADE_ORDER = { C = 1, B = 2, A = 3, S = 4 }
local LOCKED_SUFFIXES = { "easy", "normal", "hard", "expert" }

local RankCatalog = {}

RankCatalog.Ranks = {
	{
		name = "TRAINEE I",
		xp = 0,
		opens = { "SONGS ON EASY" },
		set = {
			{ chartId = "i-dont-wait-easy", songTitle = "I DON'T WAIT", difficulty = "EASY" },
			{ chartId = "just-a-little-static-easy", songTitle = "JUST A LITTLE STATIC", difficulty = "EASY" },
			{ chartId = "do-you-read-me-easy", songTitle = "DO YOU READ ME", difficulty = "EASY" },
		},
	},
	{
		name = "TRAINEE II",
		xp = 200,
		rankUp = { chartId = "our-hearts-easy", songTitle = "OUR HEARTS", difficulty = "EASY", grade = "B", challenger = "HANA" },
		opens = { "NORMAL DIFFICULTY" },
		lowerNotice = "EASY CHARTS NOW PAY 50% XP",
		set = {
			{ chartId = "our-hearts", songTitle = "OUR HEARTS", difficulty = "NORMAL" },
			{ chartId = "just-a-little-static", songTitle = "JUST A LITTLE STATIC", difficulty = "NORMAL" },
			{ chartId = "do-you-read-me", songTitle = "DO YOU READ ME", difficulty = "NORMAL" },
		},
	},
	{
		name = "TRAINEE III",
		xp = 600,
		rankUp = { chartId = "i-dont-wait", songTitle = "I DON'T WAIT", difficulty = "NORMAL", grade = "B", challenger = "MIRA" },
		opens = { "UNDER THE STARLIGHT" },
		lowerNotice = "EASY AND NORMAL ON THE FIRST FOUR SONGS NOW PAY 50% XP",
		set = { { chartId = "under-the-starlight-easy", songTitle = "UNDER THE STARLIGHT", difficulty = "EASY" } },
	},
	{
		name = "RISING STAR I",
		xp = 1200,
		rankUp = {
			chartId = "under-the-starlight",
			songTitle = "UNDER THE STARLIGHT",
			difficulty = "NORMAL",
			grade = "A",
			challenger = "SOL",
		},
		opens = { "HARD DIFFICULTY", "EXPERT DIFFICULTY" },
		lowerNotice = "EASY AND NORMAL CHARTS NOW PAY 50% XP",
		set = {
			{ chartId = "our-hearts-hard", songTitle = "OUR HEARTS", difficulty = "HARD" },
			{ chartId = "i-dont-wait-hard", songTitle = "I DON'T WAIT", difficulty = "HARD" },
			{ chartId = "under-the-starlight-hard", songTitle = "UNDER THE STARLIGHT", difficulty = "HARD" },
			{ chartId = "our-hearts-expert", songTitle = "OUR HEARTS", difficulty = "EXPERT" },
			{ chartId = "i-dont-wait-expert", songTitle = "I DON'T WAIT", difficulty = "EXPERT" },
			{ chartId = "under-the-starlight-expert", songTitle = "UNDER THE STARLIGHT", difficulty = "EXPERT" },
			{ chartId = "just-a-little-static-hard", songTitle = "JUST A LITTLE STATIC", difficulty = "HARD" },
			{ chartId = "do-you-read-me-hard", songTitle = "DO YOU READ ME", difficulty = "HARD" },
			{ chartId = "just-a-little-static-expert", songTitle = "JUST A LITTLE STATIC", difficulty = "EXPERT" },
			{ chartId = "do-you-read-me-expert", songTitle = "DO YOU READ ME", difficulty = "EXPERT" },
		},
	},
} :: { Rank }

RankCatalog.DifficultyRanks = { easy = 1, normal = 2, hard = 4, expert = 4 } :: { [string]: number }
RankCatalog.SongRanks = { ["under-the-starlight"] = 3 } :: { [string]: number }

-- A chart from a stage the player has already left pays this share of finish + grade.
RankCatalog.LowerSetXpMultiplier = 0.5
RankCatalog.DifficultyFactor = { easy = 1, normal = 1.25, hard = 1.5, expert = 1.5 } :: { [string]: number }
RankCatalog.GradeAccuracy = { S = 0.95, A = 0.85, B = 0.7, C = 0.3 } :: { [string]: number }
RankCatalog.PlayModes = { StageChallenge = true, FreePlay = true } :: { [string]: boolean }
RankCatalog.DefaultPlayMode = "StageChallenge"

RankCatalog.Xp = {
	Finish = 40,
	FirstFinish = 50,
	Friend = 10,
	FirstTodayMultiplier = 2,
	MinAccuracy = 0.3,
	GradeBonus = { S = 60, A = 40, B = 25, C = 10 } :: { [string]: number },
}

function RankCatalog.clampRank(rank: any): number
	local value = math.floor(tonumber(rank) or DEFAULT_RANK)

	return math.clamp(value, DEFAULT_RANK, #RankCatalog.Ranks)
end

local function splitChartId(chartId: string): (string, string)
	for _, difficulty in LOCKED_SUFFIXES do
		local suffix = "-" .. difficulty

		if #chartId > #suffix and string.sub(chartId, -#suffix) == suffix then
			return string.sub(chartId, 1, -#suffix - 1), difficulty
		end
	end

	return chartId, MAIN_DIFFICULTY
end

-- The rank a chart opens at, which is also the stage whose set it belongs to.
function RankCatalog.requiredRank(chartId: string): number
	local songId, difficulty = splitChartId(chartId)

	return math.max(RankCatalog.DifficultyRanks[difficulty] or DEFAULT_RANK, RankCatalog.SongRanks[songId] or DEFAULT_RANK)
end

function RankCatalog.xpMultiplier(chartId: string, rankValue: any): (number, string)
	if RankCatalog.requiredRank(chartId) < RankCatalog.clampRank(rankValue) then
		return RankCatalog.LowerSetXpMultiplier, "LOWER"
	end

	return 1, "FULL"
end

-- The scale a challenger's target is set on: accuracy, weighted by difficulty, to 0.01.
function RankCatalog.songScore(accuracy: any, chartId: string): number
	local _, difficulty = splitChartId(chartId)
	local factor = RankCatalog.DifficultyFactor[difficulty] or 1

	return math.floor(math.clamp(tonumber(accuracy) or 0, 0, 1) * 1000 * factor * 100 + 0.5) / 100
end

function RankCatalog.targetScore(rankUp: RankUp): number
	return RankCatalog.songScore(RankCatalog.GradeAccuracy[rankUp.grade], rankUp.chartId)
end

function RankCatalog.unlockText(chartId: string): string
	return "UNLOCKS AT " .. RankCatalog.Ranks[RankCatalog.requiredRank(chartId)].name
end

function RankCatalog.progress(totalXp: any, rankValue: any): Progress
	local total = math.max(tonumber(totalXp) or 0, 0)
	local rank = RankCatalog.clampRank(rankValue)
	local current = RankCatalog.Ranks[rank]
	local following: Rank? = RankCatalog.Ranks[rank + 1]

	if following == nil then
		return { rank = rank, name = current.name, total = total, into = 1, need = 1, maxed = true, ready = false }
	end

	local need = following.xp - current.xp

	return {
		rank = rank,
		name = current.name,
		total = total,
		into = math.clamp(total - current.xp, 0, need),
		need = need,
		maxed = false,
		ready = total >= following.xp,
		nextName = following.name,
		nextOpens = following.opens[1],
		rankUp = following.rankUp,
	}
end

-- A failed run or one under the accuracy floor pays nothing, which stops idle farming.
function RankCatalog.xpForRun(summary: any, context: RunContext): (number, XpParts)
	local parts: XpParts = {
		finish = 0,
		grade = 0,
		first = 0,
		friend = 0,
		doubled = false,
		multiplier = 1,
		payClass = "NONE",
		scaled = 0,
	}
	local xp = RankCatalog.Xp

	if summary.cleared == false or (tonumber(summary.accuracy) or 0) < xp.MinAccuracy then
		return 0, parts
	end

	parts.finish = xp.Finish
	parts.grade = xp.GradeBonus[summary.rank] or 0
	parts.first = if context.firstFinish then xp.FirstFinish else 0
	parts.friend = if context.friendHere then xp.Friend else 0
	parts.doubled = context.firstToday
	parts.payClass = "FULL"

	if context.rank ~= nil and type(summary.songId) == "string" then
		parts.multiplier, parts.payClass = RankCatalog.xpMultiplier(summary.songId, context.rank)
	end

	-- The epsilon keeps a product that is already whole from rounding up a step.
	parts.scaled = math.ceil((parts.finish + parts.grade) * parts.multiplier - 1e-9)

	local total = parts.scaled + parts.first + parts.friend

	return if parts.doubled then total * xp.FirstTodayMultiplier else total, parts
end

-- The bar has to be full before the run starts, so the run that fills it can't also pass it.
function RankCatalog.isChallengeAttempt(rankValue: any, xpBeforeRun: any, chartId: any): boolean
	local progress = RankCatalog.progress(xpBeforeRun, rankValue)

	return progress.ready and progress.rankUp ~= nil and progress.rankUp.chartId == chartId
end

function RankCatalog.passesRankUp(rankValue: any, xpBeforeRun: any, summary: any): boolean
	local rankUp = RankCatalog.progress(xpBeforeRun, rankValue).rankUp

	return RankCatalog.isChallengeAttempt(rankValue, xpBeforeRun, summary.songId)
		and rankUp ~= nil
		and summary.cleared ~= false
		and ScoreSummary.meetsGrade(summary.rank, rankUp.grade)
end

local function bestOf(profile: any, chartId: string): any
	local stats = if type(profile) == "table" then profile.stats else nil
	local bests = if type(stats) == "table" then stats.songBests else nil
	local best = if type(bests) == "table" then bests[chartId] else nil

	return if type(best) == "table" then best else {}
end

local function stageRow(profile: any, chart: SetChart, rank: number): StageRow
	local best = bestOf(profile, chart.chartId)
	local finished = best.finished == true
	local grade = if finished and GRADE_ORDER[best.rank] ~= nil then best.rank else nil
	local multiplier, payClass = RankCatalog.xpMultiplier(chart.chartId, rank)
	local shown = grade or PREVIEW_GRADE
	local bonus = RankCatalog.Xp.GradeBonus[shown]
	local first = if finished then 0 else RankCatalog.Xp.FirstFinish

	return {
		chartId = chart.chartId,
		songTitle = chart.songTitle,
		difficulty = chart.difficulty,
		finished = finished,
		grade = grade,
		xp = {
			grade = shown,
			finish = RankCatalog.Xp.Finish,
			bonus = bonus,
			first = first,
			total = math.ceil((RankCatalog.Xp.Finish + bonus) * multiplier - 1e-9) + first,
			payClass = payClass,
		},
	}
end

-- What Stage Challenge plays next: the challenger once the bar is full, else the first
-- unfinished chart of the set, else the weakest grade.
local function nextStageChart(rows: { StageRow }, challenger: StageChallenger?): string?
	if challenger ~= nil and challenger.state ~= "PRACTICE" then
		return challenger.chartId
	end

	local all = table.clone(rows)

	if challenger ~= nil then
		table.insert(all, challenger)
	end

	local weakest: StageRow? = nil

	for _, row in all do
		if not row.finished then
			return row.chartId
		end

		if weakest == nil or (GRADE_ORDER[row.grade or ""] or 0) < (GRADE_ORDER[weakest.grade or ""] or 0) then
			weakest = row
		end
	end

	return if weakest ~= nil then weakest.chartId else nil
end

-- Every stage with its charts, for the roadmap and the song browser. A stage's
-- challenger is the one beaten to leave it.
local function stageList(profile: any, rank: number): { StageEntry }
	local list: { StageEntry } = {}

	for index, entry in RankCatalog.Ranks do
		local following: Rank? = RankCatalog.Ranks[index + 1]
		local rankUp = if following ~= nil then following.rankUp else nil
		local gate = entry.rankUp
		local charts: { StageRow } = {}

		for _, chart in entry.set do
			table.insert(charts, stageRow(profile, chart, rank))
		end

		if rankUp ~= nil then
			local row = stageRow(profile, rankUp, rank)

			row.challenger = rankUp.challenger
			table.insert(charts, row)
		end

		table.insert(list, {
			rank = index,
			name = entry.name,
			xp = entry.xp,
			state = if index < rank then "done" elseif index == rank then "current" else "locked",
			challenger = if rankUp ~= nil then rankUp.challenger else nil,
			need = if gate ~= nil then ("%d XP + BEAT %s"):format(entry.xp, gate.challenger) else "",
			opens = entry.opens,
			charts = charts,
		})
	end

	return list
end

-- Everything the Stages screens show, from the saved profile. today is the UTC day key
-- the first-song bonus is stamped with.
function RankCatalog.stages(profile: any, today: number): Stages
	local progress = RankCatalog.progress(profile.xp, profile.rank)
	local rank = progress.rank
	local rankUp = progress.rankUp
	local challenge = if type(profile.challenge) == "table" then profile.challenge else {}
	local attempts = if type(challenge.attempts) == "table" then tonumber(challenge.attempts[tostring(rank)]) or 0 else 0
	local bestScore = if type(challenge.best) == "table" then tonumber(challenge.best[tostring(rank)]) or 0 else 0
	local rows: { StageRow } = {}
	local cleared = 0

	for _, chart in RankCatalog.Ranks[rank].set do
		local row = stageRow(profile, chart, rank)

		cleared += if row.finished then 1 else 0
		table.insert(rows, row)
	end

	local challenger: StageChallenger? = nil
	local threshold: number? = nil

	if rankUp ~= nil then
		local row = stageRow(profile, rankUp, rank) :: any

		row.name = rankUp.challenger
		row.needGrade = rankUp.grade
		row.target = RankCatalog.targetScore(rankUp)
		row.state = if not progress.ready then "PRACTICE" elseif attempts == 0 then "OPEN" else "FAILED"
		row.attempts = attempts
		row.bestScore = bestScore
		challenger = row
		threshold = RankCatalog.Ranks[rank + 1].xp
	end

	local ranks = {}

	for _, entry in RankCatalog.Ranks do
		table.insert(ranks, { name = entry.name, xp = entry.xp })
	end

	local won = RankCatalog.Ranks[rank].rankUp
	local beaten = nil

	if won ~= nil then
		local wonBest = bestOf(profile, won.chartId)

		beaten = {
			name = won.challenger,
			songTitle = won.songTitle,
			difficulty = won.difficulty,
			grade = if GRADE_ORDER[wonBest.rank] ~= nil then wonBest.rank else won.grade,
			score = if type(challenge.best) == "table" then tonumber(challenge.best[tostring(rank - 1)]) or 0 else 0,
		}
	end

	local notice = RankCatalog.Ranks[rank].lowerNotice

	return {
		rank = rank,
		name = progress.name,
		xp = progress.total,
		threshold = threshold,
		toChallenge = if threshold ~= nil then math.max(threshold - progress.total, 0) else 0,
		cleared = cleared,
		rows = rows,
		challenger = challenger,
		nextChart = nextStageChart(rows, challenger),
		nextOpens = if progress.maxed then {} else RankCatalog.Ranks[rank + 1].opens,
		ranks = ranks,
		dailyAvailable = profile.lastXpBonusDay ~= today,
		playMode = if RankCatalog.PlayModes[profile.playMode] then profile.playMode else RankCatalog.DefaultPlayMode,
		opens = RankCatalog.Ranks[rank].opens,
		beaten = beaten,
		revealPending = rank > (tonumber(profile.stageRevealSeen) or rank),
		showNotice = notice ~= nil and rank > (tonumber(profile.stageNoticeSeen) or rank),
		lowerNotice = notice,
		stageList = stageList(profile, rank),
	}
end

return RankCatalog
