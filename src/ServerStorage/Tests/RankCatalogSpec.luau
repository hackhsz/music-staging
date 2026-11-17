--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RankCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("RankCatalog"))
local ScoreSummary = require(Shared:WaitForChild("ScoreSummary"))

local NO_BONUS = { firstFinish = false, friendHere = false, firstToday = false }

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function summaryOf(perfects: number, greats: number, goods: number, misses: number): any
	return ScoreSummary.fromState({ perfects = perfects, greats = greats, goods = goods, misses = misses }, perfects + greats + goods + misses)
end

return {
	["accuracy weighs each grade and sets the letter"] = function()
		local summary = summaryOf(50, 50, 0, 0)

		expect(summary.accuracy, 0.85, "accuracy")
		expect(summary.rank, "A", "85% is an A")
		expect(summaryOf(95, 0, 0, 5).rank, "S", "95% is an S")
		expect(summaryOf(70, 0, 0, 30).rank, "B", "70% is a B")
		expect(summaryOf(30, 0, 0, 70).rank, "C", "30% is a C")
		expect(summaryOf(29, 0, 0, 71).rank, ScoreSummary.NoGrade, "under 30% has no grade")
	end,

	["the next grade counts the fewest upgrades to Perfect"] = function()
		local perfects, grade = ScoreSummary.perfectsToNextGrade(summaryOf(80, 0, 0, 20))

		expect(perfects, 5, "five misses become perfects")
		expect(grade, "A", "next is A")
		expect((ScoreSummary.perfectsToNextGrade(summaryOf(100, 0, 0, 0))), nil, "nothing above a perfect S")
	end,

	["a finished run adds its parts and the first of the day doubles them"] = function()
		local summary = { cleared = true, accuracy = 0.75, rank = "B" }

		expect((RankCatalog.xpForRun(summary, NO_BONUS)), 65, "base and grade")
		expect((RankCatalog.xpForRun(summary, { firstFinish = true, friendHere = true, firstToday = true })), 250, "all bonuses doubled")
	end,

	["a failed or idle run pays nothing"] = function()
		expect((RankCatalog.xpForRun({ cleared = false, accuracy = 0.9, rank = "A" }, NO_BONUS)), 0, "failed")
		expect((RankCatalog.xpForRun({ cleared = true, accuracy = 0.29, rank = "-" }, NO_BONUS)), 0, "under the floor")
	end,

	["the bar fills between ranks and waits for the rank-up song"] = function()
		local progress = RankCatalog.progress(500, 1)

		expect(progress.into, 200, "clamped to the bar")
		expect(progress.need, 200, "rank 2 needs 200")
		expect(progress.ready, true, "ready")
		expect(RankCatalog.progress(1999, #RankCatalog.Ranks).maxed, true, "top rank")
	end,

	["only the assigned song at its grade with a full bar ranks up"] = function()
		local pass = { cleared = true, songId = "our-hearts-easy", rank = "B" }

		expect(RankCatalog.passesRankUp(1, 200, pass), true, "passes")
		expect(RankCatalog.passesRankUp(1, 199, pass), false, "bar not full before the run")
		expect(RankCatalog.passesRankUp(1, 200, { cleared = true, songId = "our-hearts-easy", rank = "C" }), false, "grade too low")
		expect(RankCatalog.passesRankUp(1, 200, { cleared = true, songId = "i-dont-wait-easy", rank = "S" }), false, "wrong song")
		expect(RankCatalog.passesRankUp(1, 200, { cleared = false, songId = "our-hearts-easy", rank = "B" }), false, "failed")
	end,

	["charts open by difficulty and song"] = function()
		expect(RankCatalog.requiredRank("our-hearts-easy"), 1, "easy")
		expect(RankCatalog.requiredRank("our-hearts"), 2, "the bare id is the normal chart")
		expect(RankCatalog.requiredRank("our-hearts-hard"), 4, "hard")
		expect(RankCatalog.requiredRank("under-the-starlight-easy"), 3, "gated song")
		expect(RankCatalog.unlockText("our-hearts"), "UNLOCKS AT TRAINEE II", "text")
	end,

	["every stage's set and challenger open at that stage"] = function()
		for rank, entry in RankCatalog.Ranks do
			for _, chart in entry.set do
				expect(RankCatalog.requiredRank(chart.chartId), rank, chart.chartId .. " set rank")
			end

			if entry.rankUp ~= nil then
				expect(RankCatalog.requiredRank(entry.rankUp.chartId), rank - 1, entry.rankUp.chartId .. " challenger rank")
			end
		end
	end,

	["a chart from an older stage pays half of finish and grade, rounded up"] = function()
		local run = { cleared = true, accuracy = 0.75, rank = "B", songId = "our-hearts-easy" }
		local total, parts = RankCatalog.xpForRun(run, { firstFinish = true, friendHere = false, firstToday = false, rank = 2 })

		expect(parts.payClass, "LOWER", "pay class")
		expect(parts.scaled, 33, "65 halved rounds up")
		expect(total, 83, "the first finish is not halved")
		expect((RankCatalog.xpForRun(run, { firstFinish = false, friendHere = false, firstToday = true, rank = 2 })), 66, "then doubled")
		expect((RankCatalog.xpForRun(run, { firstFinish = false, friendHere = false, firstToday = false, rank = 1 })), 65, "own stage pays full")
		expect((RankCatalog.xpForRun({ cleared = true, accuracy = 0.9, rank = "A", songId = "our-hearts-easy" }, {
			firstFinish = false,
			friendHere = false,
			firstToday = false,
			rank = 3,
		})), 40, "80 halved stays whole")
	end,

	["a challenger's target is its grade on the difficulty's scale"] = function()
		expect(RankCatalog.targetScore(RankCatalog.Ranks[2].rankUp :: any), 700, "B on easy")
		expect(RankCatalog.targetScore(RankCatalog.Ranks[3].rankUp :: any), 875, "B on normal")
		expect(RankCatalog.targetScore(RankCatalog.Ranks[4].rankUp :: any), 1062.5, "A on normal")
		expect(RankCatalog.songScore(0.8125, "our-hearts-easy"), 812.5, "score")
	end,

	["the stages snapshot walks practice, open, failed and the top stage"] = function()
		local profile: any = { xp = 0, rank = 1, lastXpBonusDay = 7, stats = { songBests = {} }, challenge = { attempts = {}, best = {} } }
		local stages = RankCatalog.stages(profile, 7)
		local challenger = stages.challenger :: any

		expect(challenger.name, "HANA", "first challenger")
		expect(challenger.state, "PRACTICE", "below the bar")
		expect(stages.toChallenge, 200, "xp to go")
		expect(stages.nextChart, "i-dont-wait-easy", "first unfinished set chart")
		expect(stages.dailyAvailable, false, "bonus used today")
		expect(stages.rows[1].xp.total, 115, "40 + 25 + first 50")

		profile.xp = 230
		profile.stats.songBests["i-dont-wait-easy"] = { finished = true, rank = "B" }
		stages = RankCatalog.stages(profile, 8)
		expect((stages.challenger :: any).state, "OPEN", "bar full")
		expect(stages.nextChart, "our-hearts-easy", "the challenger's chart")
		expect(stages.cleared, 1, "cleared")
		expect(stages.dailyAvailable, true, "new day")

		profile.challenge.attempts["1"] = 2
		profile.challenge.best["1"] = 640
		expect((RankCatalog.stages(profile, 8).challenger :: any).state, "FAILED", "tried and missed")

		profile.rank = #RankCatalog.Ranks
		stages = RankCatalog.stages(profile, 8)
		expect(stages.challenger, nil, "no challenger at the top")
		expect(stages.threshold, nil, "no threshold at the top")
		expect(#stages.rows, 10, "the top stage's set")
		expect(#stages.stageList, #RankCatalog.Ranks, "every stage is listed")
		expect(stages.stageList[2].state, "done", "a stage already left")
		expect(stages.stageList[2].challenger, "MIRA", "who guards the way out of it")
		expect(stages.stageList[3].need, "600 XP + BEAT MIRA", "what opens stage 3")
		expect(stages.stageList[1].charts[1].xp.payClass, "LOWER", "older charts pay less")
	end,

	["a reveal and a notice wait until the stage they belong to is marked seen"] = function()
		local profile: any = { xp = 700, rank = 3, stats = { songBests = {} }, challenge = { best = { ["2"] = 900 } } }

		expect(RankCatalog.stages(profile, 1).revealPending, false, "a profile from before stages has nothing pending")

		profile.stageRevealSeen = 2
		profile.stageNoticeSeen = 2

		local stages = RankCatalog.stages(profile, 1)

		expect(stages.revealPending, true, "reveal pending")
		expect(stages.showNotice, true, "notice pending")
		expect((stages.beaten :: any).name, "MIRA", "who was beaten to get here")
		expect((stages.beaten :: any).score, 900, "with the best attempt")

		profile.stageRevealSeen = 3
		profile.stageNoticeSeen = 3
		stages = RankCatalog.stages(profile, 1)
		expect(stages.revealPending, false, "reveal seen")
		expect(stages.showNotice, false, "notice seen")
		expect(RankCatalog.stages({ xp = 0, rank = 1, stageNoticeSeen = 0, stats = {} }, 1).showNotice, false, "stage 1 has no notice")

		local ungraded: any = { xp = 0, rank = 1, stats = { songBests = {} } }

		for _, chart in RankCatalog.Ranks[1].set do
			ungraded.stats.songBests[chart.chartId] = { finished = true, rank = "-" }
		end

		ungraded.stats.songBests["our-hearts-easy"] = { finished = true }
		expect(RankCatalog.stages(ungraded, 1).nextChart ~= nil, true, "finished charts with no grade still pick a next chart")
	end,

	["only a full bar on the challenger's chart is an attempt"] = function()
		expect(RankCatalog.isChallengeAttempt(2, 600, "i-dont-wait"), true, "attempt")
		expect(RankCatalog.isChallengeAttempt(2, 599, "i-dont-wait"), false, "practice")
		expect(RankCatalog.isChallengeAttempt(2, 600, "our-hearts"), false, "another chart")
		expect(RankCatalog.isChallengeAttempt(#RankCatalog.Ranks, 9999, "our-hearts-hard"), false, "top stage")
	end,
}
