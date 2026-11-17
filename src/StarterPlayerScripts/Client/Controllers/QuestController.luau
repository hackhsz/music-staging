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
local DAILY_GLYPH = "📜"
local COIN_GLYPH = "💵"
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

-- The Quests window: the day's challenges and every achievement, built from the
-- profile the server pushes, with the rank and the time until the challenges reset.
local QuestController = {}
QuestController.__index = QuestController

export type QuestController = typeof(setmetatable({} :: Fields, QuestController))

function QuestController.new(deps: Deps): QuestController
	return setmetatable({ deps = deps } :: Fields, QuestController)
end

function QuestController.start(self: QuestController)
	local hud = self.deps.hud

	hud.menu:bindQuests(function()
		hud.quests:setVisible(not hud.quests:isVisible())
	end)
	Remotes.listen(self.deps.remotes.ProfileSync, function(payload)
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

	return ("NEW CHALLENGES IN %dH %02dM"):format(left // 3600, (left % 3600) // 60)
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

	hud.quests:render({
		daily = QuestController._daily(payload.daily),
		achievements = QuestController._achievements(payload.achievements, payload.stats),
	})
end

function QuestController._daily(list: any): { QuestsPanel.Quest }
	local quests: { QuestsPanel.Quest } = {}

	for _, daily in if type(list) == "table" then list else {} do
		local target = math.max(tonumber(daily.target) or 1, 1)
		local value = math.min(tonumber(daily.value) or 0, target)
		local done = daily.done == true

		table.insert(quests, {
			glyph = if type(daily.glyph) == "string" then daily.glyph else DAILY_GLYPH,
			icon = if type(daily.icon) == "string" then daily.icon else nil,
			name = tostring(daily.name or ""),
			progressText = if done then "DONE" else ("%d/%d"):format(value, target),
			fraction = if done then 1 else value / target,
			rewardText = ("+%d"):format(tonumber(daily.reward) or 0),
			done = done,
		})
	end

	return quests
end

local function rewardItem(achievement: any): any
	local cosmeticId = string.match(tostring(achievement.reward or ""), "^cosmetic:(.+)$")

	return if cosmeticId ~= nil then CosmeticsCatalog.getItem(cosmeticId) else nil
end

local function rewardText(achievement: any, item: any): string
	if item ~= nil then
		return string.upper(item.displayName)
	end

	return ("+%d"):format(tonumber(achievement.rewardAmount) or 0)
end

function QuestController._achievements(earned: any, stats: any): { QuestsPanel.Quest }
	local quests: { QuestsPanel.Quest } = {}
	local done = if type(earned) == "table" then earned else {}
	local profileStats = if type(stats) == "table" then stats else {}

	for _, achievement in AchievementCatalog.Achievements do
		local target = math.max(tonumber(achievement.target) or 1, 1)
		local isDone = done[achievement.id] == true
		local measure = STAT_PROGRESS[achievement.metric]
		local value = if isDone then target elseif measure ~= nil then math.min(measure(profileStats), target) else 0
		local item = rewardItem(achievement)

		table.insert(quests, {
			glyph = achievement.glyph or COIN_GLYPH,
			icon = achievement.icon,
			name = achievement.displayName,
			progressText = if isDone then "DONE" else ("%d/%d"):format(value, target),
			fraction = value / target,
			rewardText = rewardText(achievement, item),
			rewardGlyph = if item ~= nil then item.glyph else nil,
			rewardIcon = if item ~= nil then item.icon else nil,
			done = isDone,
		})
	end

	return quests
end

return QuestController
