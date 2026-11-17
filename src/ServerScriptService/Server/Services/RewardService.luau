local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Catalogs"):WaitForChild("Economy"))
local Progression = require(Shared:WaitForChild("Catalogs"):WaitForChild("Progression"))
local RankCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("RankCatalog"))
local DailyChallenges = require(Shared:WaitForChild("Catalogs"):WaitForChild("DailyChallenges"))
local AchievementCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("AchievementCatalog"))
local EasterEggs = require(Shared:WaitForChild("Catalogs"):WaitForChild("EasterEggs"))
local SocialRewards = require(Shared:WaitForChild("Catalogs"):WaitForChild("SocialRewards"))
local TimeRewards = require(Shared:WaitForChild("Catalogs"):WaitForChild("TimeRewards"))
local ScoreSummary = require(Shared:WaitForChild("ScoreSummary"))

local RewardService = {}
RewardService.__index = RewardService

local GROUP_ACTION_ID = "community"
local NEXT_GOAL_MAX_PERFECTS = 5

-- Whether the player is in the community group; false while no group is set or
-- when Roblox cannot answer.
local function inGroup(player: Player): boolean
	local groupId = SocialRewards.GroupId

	if groupId == nil then
		return false
	end

	local ok, member = pcall(function()
		return player:IsInGroup(groupId)
	end)

	return ok and member == true
end

function RewardService.new(playerDataService)
	return setmetatable({
		playerDataService = playerDataService,
		-- When each player joined and the play-time gifts they took this visit; never saved.
		visits = {},
		knownFriends = {},
	}, RewardService)
end

function RewardService:startVisit(player: Player)
	self.visits[player] = { startedAt = Workspace:GetServerTimeNow(), claimed = {} }
end

function RewardService:clear(player: Player)
	self.visits[player] = nil
	self.knownFriends[player] = nil
end

-- What the client needs to draw the play-time gifts, in server time.
function RewardService:visitSnapshot(player: Player)
	local visit = self.visits[player]

	return if visit ~= nil then { startedAt = visit.startedAt, claimed = visit.claimed } else nil
end

function RewardService:_claimTimeReward(player: Player, profile: any, tier: TimeRewards.Tier)
	local visit = self.visits[player]

	if visit == nil then
		return false, "unknown_reward", nil
	elseif visit.claimed[tier.id] == true then
		return false, "already_claimed", nil
	end

	local secondsLeft = TimeRewards.secondsLeft(tier, Workspace:GetServerTimeNow() - visit.startedAt)

	if secondsLeft > 0 then
		return false, "cooldown_active", { secondsLeft = secondsLeft }
	end

	visit.claimed[tier.id] = true

	local cosmeticId = tier.cosmeticId

	if cosmeticId ~= nil and profile.cosmetics[cosmeticId] ~= true then
		profile.cosmetics[cosmeticId] = true
		self.playerDataService:markDirty(player)

		return true, "claimed", {
			type = "cosmetic",
			cosmeticId = cosmeticId,
			reason = TimeRewards.RewardPrefix .. tier.id,
			itemId = tier.id,
			softCurrency = profile.softCurrency,
		}
	end

	profile.softCurrency += tier.coins
	self.playerDataService:markDirty(player)

	return true, "claimed", {
		type = "soft_currency",
		amount = tier.coins,
		reason = TimeRewards.RewardPrefix .. tier.id,
		itemId = tier.id,
		softCurrency = profile.softCurrency,
	}
end

local function findAchievement(id: string)
	for _, achievement in AchievementCatalog.Achievements do
		if achievement.id == id then
			return achievement
		end
	end

	return nil
end

local function rankToScore(rank: string?): number
	if rank == "S" then
		return 4
	elseif rank == "A" then
		return 3
	elseif rank == "B" then
		return 2
	end

	return 1
end

local function recordBest(profile: any, songId: string, summary: any)
	if type(profile.stats.songBests) ~= "table" then
		profile.stats.songBests = {}
	end

	local best = profile.stats.songBests[songId] or {}
	local rank = if type(summary.rank) == "string" then summary.rank else nil

	if ScoreSummary.isBetterRank(rank, best.rank) then
		best.rank = rank
	end

	best.score = math.max(tonumber(best.score) or 0, tonumber(summary.score) or 0)
	best.combo = math.max(tonumber(best.combo) or 0, tonumber(summary.maxCombo) or 0)
	profile.stats.songBests[songId] = best
end

local function recordChallengeAttempt(profile: any, rank: number, summary: any, beaten: boolean)
	local rankUp = RankCatalog.Ranks[rank + 1].rankUp
	local key = tostring(rank)
	local finished = summary.cleared ~= false and (tonumber(summary.accuracy) or 0) >= RankCatalog.Xp.MinAccuracy
	local score = if finished then RankCatalog.songScore(summary.accuracy, rankUp.chartId) else 0

	if type(profile.challenge) ~= "table" then
		profile.challenge = {}
	end

	local challenge = profile.challenge

	challenge.attempts = if type(challenge.attempts) == "table" then challenge.attempts else {}
	challenge.best = if type(challenge.best) == "table" then challenge.best else {}
	challenge.attempts[key] = (tonumber(challenge.attempts[key]) or 0) + 1
	challenge.best[key] = math.max(tonumber(challenge.best[key]) or 0, score)

	return {
		name = rankUp.challenger,
		songTitle = rankUp.songTitle,
		difficulty = rankUp.difficulty,
		grade = summary.rank,
		beaten = beaten,
		score = score,
		target = RankCatalog.targetScore(rankUp),
		attempts = challenge.attempts[key],
	}
end

function RewardService:_hasFriendHere(player: Player): boolean
	local known = self.knownFriends[player] or {}

	self.knownFriends[player] = known

	for _, other in Players:GetPlayers() do
		if other ~= player and known[other.UserId] == nil then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)

			if ok then
				known[other.UserId] = isFriend == true
			end
		end

		if other ~= player and known[other.UserId] == true then
			return true
		end
	end

	return false
end

function RewardService:applySongSummary(player: Player, summary: any)
	-- Yields, so it comes before the profile is read.
	local friendHere = self:_hasFriendHere(player)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return {}
	end

	local rewards = {}
	profile.softCurrency += Economy.Rewards.SongComplete
	table.insert(rewards, {
		type = "soft_currency",
		amount = Economy.Rewards.SongComplete,
		reason = "song_complete",
	})

	profile.stats.bestScore = math.max(profile.stats.bestScore, summary.score or 0)
	profile.stats.bestCombo = math.max(profile.stats.bestCombo, summary.maxCombo or 0)
	profile.stats.songsCompleted = (profile.stats.songsCompleted or 0) + 1
	profile.stats.totalPerfects += summary.perfects or 0
	profile.stats.totalGoods += summary.goods or 0
	profile.stats.totalMisses += summary.misses or 0
	if type(profile.stats.completedSongs) ~= "table" then
		profile.stats.completedSongs = {}
	end

	local songId = type(summary.songId) == "string" and summary.songId or "unknown"
	profile.stats.completedSongs[songId] = (profile.stats.completedSongs[songId] or 0) + 1
	local previousBest = profile.stats.songBests[songId]
	local previousScore = if previousBest ~= nil then tonumber(previousBest.score) else nil
	local firstFinish = previousBest == nil or previousBest.finished ~= true

	recordBest(profile, songId, summary)
	summary.newBest = summary.cleared ~= false and previousScore ~= nil and (tonumber(summary.score) or 0) > previousScore
	summary.previousBest = previousScore

	local uniqueSongsCompleted = 0
	for _, count in profile.stats.completedSongs do
		if (tonumber(count) or 0) > 0 then
			uniqueSongsCompleted += 1
		end
	end

	local unlocked = Progression.evaluate({
		perfects = summary.perfects or 0,
		max_combo = summary.maxCombo or 0,
		songs_completed = profile.stats.songsCompleted,
		song_completed = profile.stats.completedSongs[songId] or 0,
		songProgress = profile.stats.completedSongs,
		unique_songs_completed = uniqueSongsCompleted,
		rank_score = rankToScore(summary.rank),
	})

	local unlockedAchievements = {}

	for _, achievementId in unlocked do
		if not profile.achievements[achievementId] then
			profile.achievements[achievementId] = true

			local achievement = findAchievement(achievementId)

			if achievement ~= nil then
				if achievement.reward == "soft_currency" then
					profile.softCurrency += achievement.rewardAmount or 0
				elseif type(achievement.reward) == "string" and string.sub(achievement.reward, 1, 9) == "cosmetic:" then
					local cosmeticId = string.sub(achievement.reward, 10)
					profile.cosmetics[cosmeticId] = true
				end

				table.insert(rewards, {
					type = achievement.reward,
					amount = achievement.rewardAmount,
					reason = achievementId,
				})
				table.insert(unlockedAchievements, {
					name = achievement.displayName,
					detail = if achievement.reward == "soft_currency" then ("+%d"):format(achievement.rewardAmount or 0) else "NEW ITEM",
				})
			end
		end
	end

	local today = DailyChallenges.dayKey(os.time())
	local xpBefore = profile.xp or 0
	local rankBefore = RankCatalog.clampRank(profile.rank)
	local xpGained, xpParts = RankCatalog.xpForRun(summary, {
		firstFinish = firstFinish,
		friendHere = friendHere,
		firstToday = profile.lastXpBonusDay ~= today,
		rank = rankBefore,
	})

	if xpGained > 0 then
		profile.lastXpBonusDay = today
		profile.stats.songBests[songId].finished = true
	end

	profile.xp = xpBefore + xpGained
	table.insert(rewards, {
		type = "xp",
		amount = xpGained,
		reason = "song_complete",
	})

	local rankedUp = summary.flagged ~= true and RankCatalog.passesRankUp(rankBefore, xpBefore, summary)

	if rankedUp then
		local rank = RankCatalog.Ranks[rankBefore + 1]

		profile.rank = rankBefore + 1
		profile.softCurrency += Economy.Rewards.RankUp
		table.insert(rewards, {
			type = "soft_currency",
			amount = Economy.Rewards.RankUp,
			reason = "rank_up",
		})
		summary.rankOpens = rank.opens
		summary.rankCoins = Economy.Rewards.RankUp
	end

	if summary.flagged ~= true and RankCatalog.isChallengeAttempt(rankBefore, xpBefore, songId) then
		summary.challenge = recordChallengeAttempt(profile, rankBefore, summary, rankedUp)
	end

	local rankAfter = RankCatalog.progress(profile.xp, profile.rank)
	local perfects, nextGrade = ScoreSummary.perfectsToNextGrade(summary)

	summary.stages = RankCatalog.stages(profile, today)

	summary.xpGained = xpGained
	summary.xpParts = xpParts
	summary.rankBefore = RankCatalog.progress(xpBefore, rankBefore)
	summary.rankAfter = rankAfter
	summary.rankedUp = rankedUp

	if perfects ~= nil and perfects <= NEXT_GOAL_MAX_PERFECTS and summary.cleared ~= false then
		summary.nextGoal = { perfects = perfects, grade = nextGrade }
	end

	-- Daily challenges (retention). Reset on a new UTC day, fold this run in, and
	-- auto-grant coins for any challenge whose target was just hit.
	local dayKey = DailyChallenges.dayKey(os.time())
	if type(profile.daily) ~= "table" or profile.daily.key ~= dayKey then
		profile.daily = { key = dayKey, progress = DailyChallenges.emptyProgress(), rewarded = {} }
	end

	DailyChallenges.advance(profile.daily.progress, summary)

	local completedDaily = {}
	for _, challenge in DailyChallenges.rollDaily(dayKey) do
		if DailyChallenges.isComplete(challenge, profile.daily.progress) and not profile.daily.rewarded[challenge.id] then
			profile.daily.rewarded[challenge.id] = true
			profile.softCurrency += challenge.reward
			table.insert(rewards, {
				type = "soft_currency",
				amount = challenge.reward,
				reason = "daily:" .. challenge.id,
			})
			table.insert(completedDaily, { name = challenge.name, reward = challenge.reward })
		end
	end

	summary.dailyCompleted = completedDaily
	summary.achievements = unlockedAchievements

	local coinsGained = 0

	for _, reward in rewards do
		if reward.type == "soft_currency" then
			coinsGained += reward.amount or 0
		end
	end

	summary.coinsGained = coinsGained

	self.playerDataService:markDirty(player)

	return rewards
end

function RewardService:claimReward(player: Player, rewardId: string, now: number?)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return false, "profile_not_loaded", nil
	end

	local tier = TimeRewards.fromRewardId(rewardId)

	if tier ~= nil then
		return self:_claimTimeReward(player, profile, tier)
	end

	local item = EasterEggs.getItem(rewardId)
	local socialAction = nil

	if item == nil then
		socialAction = SocialRewards.getAction(rewardId)
	end

	if item == nil and socialAction == nil then
		return false, "unknown_reward", nil
	end

	if type(profile.claimedRewards) ~= "table" then
		profile.claimedRewards = {}
	end

	if type(profile.rewardCooldowns) ~= "table" then
		profile.rewardCooldowns = {}
	end

	local isGroupReward = socialAction ~= nil and socialAction.id == GROUP_ACTION_ID

	if isGroupReward and SocialRewards.GroupId ~= nil and not inGroup(player) then
		return false, "not_in_group", nil
	end

	local actualRewardId = if item ~= nil then item.rewardId or item.id else "social:" .. socialAction.id
	local currentTime = now or os.time()

	if item ~= nil and item.repeatable == true then
		local nextAllowed = tonumber(profile.rewardCooldowns[actualRewardId]) or 0

		if currentTime < nextAllowed then
			return false, "cooldown_active", {
				nextAllowedAt = nextAllowed,
			}
		end

		profile.rewardCooldowns[actualRewardId] = currentTime + (tonumber(item.cooldownSeconds) or 0)
	elseif profile.claimedRewards[actualRewardId] == true then
		return false, "already_claimed", nil
	else
		profile.claimedRewards[actualRewardId] = true
	end

	local amount = if item ~= nil
		then tonumber(item.rewardSoftCurrency) or Economy.Rewards.EasterEggPickup
		else tonumber(socialAction.rewardSoftCurrency) or 0

	if item ~= nil and item.repeatable == true and inGroup(player) then
		amount *= SocialRewards.GroupDailyGiftMultiplier
	end

	if isGroupReward then
		profile.cosmetics[SocialRewards.GroupCosmeticId] = true
	end

	profile.softCurrency += amount
	self.playerDataService:markDirty(player)

	return true, "claimed", {
		type = "soft_currency",
		amount = amount,
		reason = actualRewardId,
		itemId = if item ~= nil then item.id else socialAction.id,
		softCurrency = profile.softCurrency,
	}
end

return RewardService
