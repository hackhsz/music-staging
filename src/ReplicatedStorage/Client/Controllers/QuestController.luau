--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local AchievementCatalog = require(Catalogs:WaitForChild("AchievementCatalog"))
local CosmeticsCatalog = require(Catalogs:WaitForChild("CosmeticsCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local QuestsPanel = require(script.Parent.Parent.UI.Screens.QuestsPanel)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local SECONDS_PER_DAY = 86400
local RESET_REFRESH_SECONDS = 30
local STREAK_DOTS = 7
-- The server's ClaimReward id for one of the day's challenges.
local DAILY_REWARD_PREFIX = "daily:"
-- The achievement metrics the profile's stats can show progress for.
local STAT_PROGRESS: { [string]: (stats: any) -> number } = {
	perfects = function(stats)
		return tonumber(stats.totalPerfects) or 0
	end,
	max_combo = function(stats)
		return tonumber(stats.bestCombo) or 0
	end,
	songs_completed = function(stats)
		return tonumber(stats.songsCompleted) or 0
	end,
	unique_songs_completed = function(stats)
		local count = 0

		for _ in if type(stats.completedSongs) == "table" then stats.completedSongs else {} do
			count += 1
		end

		return count
	end,
}

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
}

type Fields = {
	deps: Deps,
}

-- The Quests window: the day's challenges and their claims, the streak, and every achievement
-- in the catalog as a road of medals, built from the profile the server pushes. The server
-- decides every claim; this only asks.
local QuestController = {}
QuestController.__index = QuestController

export type QuestController = typeof(setmetatable({} :: Fields, QuestController))

function QuestController.new(deps: Deps): QuestController
	return setmetatable({ deps = deps } :: Fields, QuestController)
end

function QuestController.start(self: QuestController)
	local hud = self.deps.hud
	local remotes = self.deps.remotes

	hud.menu:bindQuests(function()
		hud.quests:setVisible(not hud.quests:isVisible())
	end)
	hud.quests:bindClaim(function(questId: string)
		remotes.ClaimReward:FireServer({ rewardId = DAILY_REWARD_PREFIX .. questId })
	end)
	Remotes.listen(remotes.ProfileSync, function(payload)
		self:_onProfile(payload)
	end)

	task.spawn(function()
		while true do
			hud.quests:setResetText(QuestController._resetText())
			task.wait(RESET_REFRESH_SECONDS)
		end
	end)
end

function QuestController.open(self: QuestController)
	self.deps.hud.quests:setVisible(true)
end

function QuestController._resetText(): string
	local left = SECONDS_PER_DAY - math.floor(Workspace:GetServerTimeNow()) % SECONDS_PER_DAY

	return ("NEW IN %dH %02dM"):format(left // 3600, (left % 3600) // 60)
end

function QuestController._onProfile(self: QuestController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local hud = self.deps.hud
	local progression = payload.progression

	if type(progression) == "table" then
		hud.quests:setLevel({
			level = tonumber(progression.rank) or 1,
			name = tostring(progression.name),
			maxed = progression.maxed == true,
			into = tonumber(progression.into) or 0,
			need = tonumber(progression.need) or 1,
		})
	end

	local daily, today, claimable = QuestController._daily(payload)

	hud.quests:render(daily, QuestController._achievements(payload.achievements, payload.stats))
	hud.quests:drawToday(today)
	hud.menu:setQuestsReady(claimable)
end

-- The day's challenges, the TODAY line built from them, and whether any reward is waiting.
function QuestController._daily(payload: any): ({ QuestsPanel.DailyQuest }, QuestsPanel.Today, boolean)
	local quests: { QuestsPanel.DailyQuest } = {}
	local finished, paid, total, claimable = 0, 0, 0, false

	for _, daily in if type(payload.daily) == "table" then payload.daily else {} do
		local target = math.max(tonumber(daily.target) or 1, 1)
		local value = math.min(tonumber(daily.value) or 0, target)
		local reward = tonumber(daily.reward) or 0
		local done = daily.done == true
		local state = if not done then "progress" elseif daily.rewarded == true then "done" else "claim"

		total += reward
		finished += if done then 1 else 0
		paid += if state == "done" then reward else 0
		claimable = claimable or state == "claim"

		table.insert(quests, {
			id = tostring(daily.id),
			name = tostring(daily.name or ""),
			icon = if type(daily.art) == "string" then daily.art else "",
			progress = ("%d / %d"):format(value, target),
			fraction = if done then 1 else value / target,
			reward = ("+%d"):format(reward),
			state = state,
		})
	end

	local streak = tonumber(payload.streakDays) or 0

	return quests,
		{
			done = ("%d OF %d DONE"):format(finished, #quests),
			coins = ("TODAY'S COINS: %d / %d"):format(paid, total),
			streak = if streak == 1 then "1 DAY" else ("%d DAYS"):format(streak),
			lit = math.min(streak, STREAK_DOTS),
			bonus = if payload.xpBonusReady == true then "2X XP · READY" else "2X XP · USED",
		},
		claimable
end

local function rewardItem(achievement: any): any
	local cosmeticId = string.match(tostring(achievement.reward or ""), "^cosmetic:(.+)$")

	return if cosmeticId ~= nil then CosmeticsCatalog.getItem(cosmeticId) else nil
end

function QuestController._achievements(earned: any, stats: any): { QuestsPanel.Achievement }
	local list: { QuestsPanel.Achievement } = {}
	local done = if type(earned) == "table" then earned else {}
	local profileStats = if type(stats) == "table" then stats else {}

	for _, achievement in AchievementCatalog.Achievements do
		local target = math.max(tonumber(achievement.target) or 1, 1)
		local isDone = done[achievement.id] == true
		local measure = STAT_PROGRESS[achievement.metric]
		local value = if isDone then target elseif measure ~= nil then math.min(measure(profileStats), target) else 0
		local item = rewardItem(achievement)

		table.insert(list, {
			id = achievement.id,
			name = achievement.displayName,
			goal = achievement.goal or "",
			progress = if isDone then "EARNED" else ("%d / %d"):format(value, target),
			fraction = value / target,
			reward = if item ~= nil then string.upper(item.displayName) else ("+%d"):format(tonumber(achievement.rewardAmount) or 0),
			rewardIcon = if item ~= nil then item.icon else nil,
			badge = achievement.badge or AchievementCatalog.DefaultBadge,
			state = if isDone then "earned" elseif value > 0 then "progress" else "locked",
		})
	end

	return list
end

return QuestController
