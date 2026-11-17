local MatchRules = {
	STATIONS_FOLDER = "Stations",
	PROMPT_TAG = "DDSPrompt",
	WATCH_ACTION = "Watch",
	PROMPT_STACK_ATTRIBUTE = "StackRank",

	STATE_IDLE = "Idle",
	STATE_CHOOSING = "Choosing",
	STATE_OPEN = "Open",
	STATE_PLAYING = "Playing",
	STATE_RESULTS = "Results",

	KIND_SOLO = "Solo",
	KIND_DUEL = "Duel",

	AI_RIVAL_ID = -1,
	AI_NAME = "Rival Bot",
	TIE = "Tie",

	CHOOSE_TIMEOUT_SEC = 30,
	JOIN_WINDOW_SEC = 10,
	SOLO_START_LEAD_SEC = 0.5,
	DUEL_START_LEAD_SEC = 2.5,
	FINISH_GRACE_SEC = 12,
	RESULTS_HOLD_SEC = 6,
	SCORE_REPORT_INTERVAL_SEC = 0.25,
	MATCH_RATE = 1,
	MAX_SCORE = 10000000,

	AI_SKILL = {
		easy = { hitChance = 0.93, perfectShare = 0.5, greatShare = 0.38, dodgeChance = 0.92, reactionJitterSec = 0.05 },
		normal = { hitChance = 0.86, perfectShare = 0.42, greatShare = 0.4, dodgeChance = 0.82, reactionJitterSec = 0.07 },
		hard = { hitChance = 0.78, perfectShare = 0.34, greatShare = 0.42, dodgeChance = 0.72, reactionJitterSec = 0.09 },
	},
}

function MatchRules.songStartAt(startAt: number, preRollMs: number): number
	return startAt + preRollMs * 0.75 / 1000
end

function MatchRules.eventTime(songStartAt: number, chart, beat: number): number
	return songStartAt + (chart.firstBeatSec or 0) + beat * 60 / chart.bpm
end

function MatchRules.chartLengthSec(chart): number
	local lastBeat = 0
	for _, event in chart.events do
		lastBeat = math.max(lastBeat, event.beat)
	end
	return (chart.firstBeatSec or 0) + lastBeat * 60 / chart.bpm
end

function MatchRules.waitUntil(serverTime: number)
	local remaining = serverTime - workspace:GetServerTimeNow()
	if remaining > 0 then
		task.wait(remaining)
	end
end

return MatchRules
