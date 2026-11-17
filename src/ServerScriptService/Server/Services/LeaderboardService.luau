local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LeaderboardConfig = require(Shared:WaitForChild("Catalogs"):WaitForChild("LeaderboardConfig"))
local DataStoreRetry = require(script.Parent.DataStoreRetry)

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local RETRY_OPTIONS: DataStoreRetry.Options = {
	attempts = 3,
	baseDelaySeconds = 0.4,
}
local TOP_ENTRY_COUNT = 10
local SORT_PAGE_SIZE = 100
local SECONDS_PER_DAY = 86400
local STORE_NAME_PREFIX = "DanceDanceStepBoard_"
local OWN_VALUE_CACHE_SECONDS = 300
local NAME_RETRY_SECONDS = 300

-- ISO 8601 year-week suffix (e.g. "2026-W24") for rotating weekly boards:
-- a week belongs to the year that contains its Thursday.
local function getWeeklyKeySuffix(timestamp: number): string
	local date = os.date("!*t", timestamp)
	local isoWeekday = (date.wday + 5) % 7 + 1 -- Monday = 1 ... Sunday = 7
	local thursday = os.date("!*t", timestamp + (4 - isoWeekday) * SECONDS_PER_DAY)
	local week = math.floor((thursday.yday - 1) / 7) + 1

	return ("%04d-W%02d"):format(thursday.year, week)
end

local function getMetricValue(board: any, summary: any): number
	if board.metric == "score" then
		return tonumber(summary.score) or 0
	elseif board.metric == "perfects" then
		return tonumber(summary.perfects) or 0
	end

	return 0
end

-- Weekly perfect counts accumulate across runs; high scores keep the max.
local function isAccumulating(board: any): boolean
	return board.metric == "perfects"
end

function LeaderboardService.new()
	return setmetatable({
		nameCache = {},
		nameRetryAt = {},
		ownValueCache = {},
		-- Studio (no DataStore API access) falls back to in-memory boards so
		-- play tests render the wall without error spam.
		memoryBoards = {},
	}, LeaderboardService)
end

function LeaderboardService:getPeriodKey(board: any): string?
	if board.period == "weekly" then
		return getWeeklyKeySuffix(os.time())
	end

	return nil
end

function LeaderboardService:getStore(board: any)
	-- One OrderedDataStore per board; weekly boards rotate via the ISO
	-- year-week scope so a fresh board starts every Monday (UTC).
	return DataStoreService:GetOrderedDataStore(STORE_NAME_PREFIX .. board.id, self:getPeriodKey(board) or "all")
end

function LeaderboardService:getMemoryBoard(board: any)
	local key = board.id .. "/" .. (self:getPeriodKey(board) or "all")
	local memory = self.memoryBoards[key]

	if memory == nil then
		memory = {}
		self.memoryBoards[key] = memory
	end

	return memory
end

function LeaderboardService:record(board: any, userId: number, value: number): boolean
	if value <= 0 then
		return true
	end

	local cached = self.ownValueCache[userId]

	if cached ~= nil then
		cached[board.id] = nil
	end

	if RunService:IsStudio() then
		local memory = self:getMemoryBoard(board)

		if isAccumulating(board) then
			memory[userId] = (memory[userId] or 0) + value
		else
			memory[userId] = math.max(memory[userId] or 0, value)
		end

		return true
	end

	local store = self:getStore(board)

	local ok, err = DataStoreRetry.run(Enum.DataStoreRequestType.SetIncrementSortedAsync, RETRY_OPTIONS, function()
		store:UpdateAsync(tostring(userId), function(previous)
			previous = tonumber(previous) or 0

			if isAccumulating(board) then
				return previous + value
			end

			if value > previous then
				return value
			end

			-- No improvement: returning nil cancels the write.
			return nil
		end)
	end)

	if not ok then
		warn(("[DanceDanceStep] Failed to record %s for user %d: %s"):format(board.id, userId, tostring(err)))
	end

	return ok
end

-- Song-complete hook: records every configured board metric (all-time high
-- score and weekly perfect count) for the finished run.
function LeaderboardService:recordSongSummary(player: Player, summary: any): boolean
	local ok = true

	for _, board in LeaderboardConfig.Boards do
		ok = self:record(board, player.UserId, getMetricValue(board, summary)) and ok
	end

	return ok
end

-- Level boards rank total XP, so they count runs that used abilities and are
-- recorded on join too, where a player already has XP from before the board.
function LeaderboardService:recordXp(player: Player, xp: number)
	for _, board in LeaderboardConfig.Boards do
		if board.metric == "xp" then
			self:record(board, player.UserId, xp)
		end
	end
end

function LeaderboardService:resolveName(userId: number): string
	local cached = self.nameCache[userId]

	if cached ~= nil then
		return cached
	end

	local player = Players:GetPlayerByUserId(userId)

	if player ~= nil then
		self.nameCache[userId] = player.Name
		return player.Name
	end

	local fallback = "PLAYER " .. tostring(userId)
	local retryAt = self.nameRetryAt[userId]

	if retryAt ~= nil and os.clock() < retryAt then
		return fallback
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok and type(name) == "string" then
		self.nameCache[userId] = name
		self.nameRetryAt[userId] = nil
		return name
	end

	self.nameRetryAt[userId] = os.clock() + NAME_RETRY_SECONDS

	return fallback
end

-- First sorted page (top 100) for a board: enough for the wall's top-10 and
-- for resolving most players' own rank without extra rank lookups.
function LeaderboardService:getSortedPage(board: any): { { userId: number, value: number } }
	local entries = {}

	if RunService:IsStudio() then
		for userId, value in self:getMemoryBoard(board) do
			table.insert(entries, { userId = userId, value = value })
		end

		table.sort(entries, function(left, right)
			return left.value > right.value
		end)

		return entries
	end

	local store = self:getStore(board)

	DataStoreRetry.waitForBudget(Enum.DataStoreRequestType.GetSortedAsync)

	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, SORT_PAGE_SIZE)
		return pages:GetCurrentPage()
	end)

	if not ok then
		warn(("[DanceDanceStep] Failed to read leaderboard %s: %s"):format(board.id, tostring(result)))
		return entries
	end

	for _, entry in result do
		table.insert(entries, {
			userId = tonumber(entry.key) or 0,
			value = tonumber(entry.value) or 0,
		})
	end

	return entries
end

function LeaderboardService:getOwnValue(board: any, userId: number): number?
	if RunService:IsStudio() then
		return self:getMemoryBoard(board)[userId]
	end

	local cachedByBoard = self.ownValueCache[userId]

	if cachedByBoard == nil then
		cachedByBoard = {}
		self.ownValueCache[userId] = cachedByBoard
	end

	local cached = cachedByBoard[board.id]

	if cached ~= nil and os.clock() < cached.expiresAt and cached.periodKey == self:getPeriodKey(board) then
		return cached.value
	end

	DataStoreRetry.waitForBudget(Enum.DataStoreRequestType.GetAsync)

	local ok, value = pcall(function()
		return self:getStore(board):GetAsync(tostring(userId))
	end)

	if not ok then
		return if cached ~= nil then cached.value else nil
	end

	cachedByBoard[board.id] = {
		value = tonumber(value),
		periodKey = self:getPeriodKey(board),
		expiresAt = os.clock() + OWN_VALUE_CACHE_SECONDS,
	}

	return tonumber(value)
end

-- Level boards record profile.xp on every run and on join, so the profile is the
-- board's value without a read. Score boards only take clean cleared runs, so
-- the profile's best can be higher than what ranked.
local function getProfileValue(board: any, profile: any): number?
	if board.metric == "xp" and type(profile) == "table" then
		return tonumber(profile.xp)
	end

	return nil
end

-- Snapshot for the in-world wall: per board, top-10 entries with resolved
-- names plus a rank lookup map for personalizing each player's payload.
function LeaderboardService:buildSnapshot()
	local snapshot = { boards = {} }

	for _, board in LeaderboardConfig.Boards do
		local page = self:getSortedPage(board)
		local entries = {}
		local rankByUserId = {}

		for rank, entry in page do
			rankByUserId[entry.userId] = { rank = rank, value = entry.value }

			if rank <= TOP_ENTRY_COUNT then
				table.insert(entries, {
					rank = rank,
					userId = entry.userId,
					name = self:resolveName(entry.userId),
					avatarKey = "user:" .. tostring(entry.userId),
					value = entry.value,
				})
			end
		end

		table.insert(snapshot.boards, {
			id = board.id,
			displayName = board.displayName,
			period = board.period,
			periodKey = self:getPeriodKey(board),
			metric = board.metric,
			entries = entries,
			rankByUserId = rankByUserId,
		})
	end

	return snapshot
end

-- Per-player payload: the shared top-10 plus the requesting player's own
-- best. OrderedDataStore has no cheap rank lookup outside the sorted page,
-- so beyond the first page we send the value with no rank ("100+").
function LeaderboardService:buildPlayerPayload(snapshot: any, player: Player, profile: any?)
	local boards = {}

	for _, board in snapshot.boards do
		local own = board.rankByUserId[player.UserId]
		local you = nil

		if own ~= nil then
			you = { value = own.value, rank = own.rank }
		else
			local value = getProfileValue(board, profile) or self:getOwnValue(board, player.UserId)

			if value ~= nil and value > 0 then
				you = { value = value, rank = nil }
			end
		end

		table.insert(boards, {
			id = board.id,
			displayName = board.displayName,
			period = board.period,
			periodKey = board.periodKey,
			metric = board.metric,
			entries = board.entries,
			you = you,
		})
	end

	return { boards = boards }
end

function LeaderboardService:clear(player: Player)
	self.ownValueCache[player.UserId] = nil
end

return LeaderboardService
