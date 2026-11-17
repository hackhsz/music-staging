local SongMapCatalog = require(script.Parent.SongMapCatalog)
local LiveOpsPlan = require(script.Parent.Catalogs.LiveOpsPlan)
local RankCatalog = require(script.Parent.Catalogs.RankCatalog)

local SongCollection = {}

SongCollection.UnlockRules = {
	-- Playtest switch: every song and difficulty is open. Set false to bring back
	-- the unlock rules below.
	UnlockAll = true,
	-- Separate from UnlockAll: charts open by rank (RankCatalog) even while that is on.
	RankGate = true,
	DefaultUnlocked = {
		"our-hearts",
		-- The first song after the lesson (TutorialChart.FirstSongId).
		"our-hearts-easy",
	},
	SoftCurrencyUnlock = true,
	AchievementUnlock = true,
	HardCurrencyUnlock = false,
	Songs = {
		["first-playable-001"] = {
			type = "soft_currency",
			price = 150,
			requirementText = "UNLOCK 150 BEAT COINS",
		},
		["neon-idol-rush"] = {
			type = "achievement",
			achievementId = "rank-b-practice",
			requirementText = "EARN RANK B ON ANY TRACK",
		},
	},
}

function SongCollection.getFeaturedDrop(songId: string)
	for _, drop in LiveOpsPlan.WeeklySongDrops do
		if table.find(drop.featuredSongIds, songId) ~= nil then
			return drop
		end
	end

	return nil
end

function SongCollection.getRule(songId: string)
	return SongCollection.UnlockRules.Songs[songId]
end

function SongCollection.isRankLocked(songId: string, profile: any?): boolean
	local rank = RankCatalog.clampRank(if type(profile) == "table" then profile.rank else nil)

	return SongCollection.UnlockRules.RankGate and rank < RankCatalog.requiredRank(songId)
end

function SongCollection.isUnlocked(songId: string, profile: any?): boolean
	if SongCollection.isRankLocked(songId, profile) then
		return false
	end

	if SongCollection.UnlockRules.UnlockAll or table.find(SongCollection.UnlockRules.DefaultUnlocked, songId) ~= nil then
		return true
	end

	if type(profile) ~= "table" then
		return false
	end

	-- Soft-currency purchases persist into the profile's unlocked song list.
	if type(profile.unlockedSongs) == "table" and table.find(profile.unlockedSongs, songId) ~= nil then
		return true
	end

	local rule = SongCollection.getRule(songId)

	if rule ~= nil and rule.type == "achievement" and SongCollection.UnlockRules.AchievementUnlock then
		local achievements = type(profile.achievements) == "table" and profile.achievements or {}

		return achievements[rule.achievementId] == true
	end

	return false
end

function SongCollection.getRequirementText(songId: string): string
	local rule = SongCollection.getRule(songId)

	return if rule ~= nil and rule.requirementText ~= nil then rule.requirementText else "LOCKED"
end

-- Per-player catalog payload: every song carries its locked state plus how
-- to unlock it, so the client can gray out entries and offer shop unlocks.
function SongCollection.buildCatalogPayload(profile: any?)
	local songs = SongMapCatalog.listSongs()
	local stats = if type(profile) == "table" then profile.stats else nil
	local bests = if type(stats) == "table" and type(stats.songBests) == "table" then stats.songBests else {}

	for _, song in songs do
		local best = bests[song.id]

		if type(best) == "table" then
			song.bestRank = best.rank
			song.bestScore = best.score
			song.bestCombo = best.combo
		end

		local rule = SongCollection.getRule(song.id)
		local drop = SongCollection.getFeaturedDrop(song.id)

		song.locked = not SongCollection.isUnlocked(song.id, profile)
		song.unlockType = if rule ~= nil then rule.type else nil
		song.price = if rule ~= nil then rule.price else nil
		song.requirementText = if SongCollection.isRankLocked(song.id, profile)
			then RankCatalog.unlockText(song.id)
			elseif rule ~= nil then rule.requirementText
			else nil
		song.featured = drop ~= nil
		song.liveOpsWeekKey = if drop ~= nil then drop.weekKey else nil
		song.liveOpsChallenge = if drop ~= nil then drop.challenge else nil
		song.liveOpsStatus = if drop ~= nil then drop.status else nil
	end

	return {
		songs = songs,
		cadence = LiveOpsPlan.Cadence,
		weeklyDrops = LiveOpsPlan.WeeklySongDrops,
	}
end

return SongCollection
