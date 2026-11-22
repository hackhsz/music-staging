--!strict
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local LeagueCatalog = require(Catalogs:WaitForChild("LeagueCatalog"))
local DataStoreRetry = require(script.Parent.DataStoreRetry)

local STORE_PREFIX = "DanceDanceStepLeague_"
local RETRY_OPTIONS: DataStoreRetry.Options = { attempts = 3, baseDelaySeconds = 1 }
local BOARD_CACHE_SECONDS = 60
-- A group is read this deep: enough to rank everyone in a full group.
local READ_DEPTH = 100

type Row = { userId: number, value: number }
type Cached = { at: number, rows: { Row } }

local LeagueService = {}
LeagueService.__index = LeagueService

export type LeagueService = typeof(setmetatable(
	{} :: {
		playerDataService: any,
		leaderboardService: any,
		memory: { [string]: { [number]: number } },
		cache: { [string]: Cached },
		settling: { [Player]: boolean },
	},
	LeagueService
))

local function boardKey(week: number, tier: number, group: number): string
	return ("W%d_T%d_G%d"):format(week, tier, group)
end

function LeagueService.new(playerDataService: any, leaderboardService: any): LeagueService
	return setmetatable({
		playerDataService = playerDataService,
		leaderboardService = leaderboardService,
		memory = {},
		cache = {},
		settling = {},
	}, LeagueService)
end

local function stateOf(profile: any): any
	local state = profile.league

	if type(state) ~= "table" then
		state = { week = -1, tier = 1, best = {}, points = 0 }
		profile.league = state
	end

	state.tier = LeagueCatalog.clampTier(state.tier)
	-- Older saves kept a plain list of scores; best is now keyed by song.
	state.best = if type(state.best) == "table" and #state.best == 0 then state.best else {}
	state.points = tonumber(state.points) or 0
	state.week = tonumber(state.week) or -1

	return state
end

function LeagueService._write(self: LeagueService, key: string, userId: number, points: number)
	self.cache[key] = nil

	if RunService:IsStudio() then
		self.memory[key] = self.memory[key] or {}
		self.memory[key][userId] = points
		return
	end

	local store = DataStoreService:GetOrderedDataStore(STORE_PREFIX .. key)
	-- Points only grow within a week; keeping the higher value means two runs saving out of
	-- order cannot leave the lower total on the board.
	local ok, err = DataStoreRetry.run(Enum.DataStoreRequestType.SetIncrementSortedAsync, RETRY_OPTIONS, function()
		store:UpdateAsync(tostring(userId), function(previous)
			return if (tonumber(previous) or 0) >= points then nil else points
		end)
	end)

	if not ok then
		warn(("[DanceDanceStep] League write failed for %d: %s"):format(userId, tostring(err)))
	end
end

-- The group's standings, highest first, and whether they were read; cached for a minute.
function LeagueService._read(self: LeagueService, key: string, fresh: boolean?): ({ Row }, boolean)
	local cached = self.cache[key]

	if not fresh and cached ~= nil and os.clock() - cached.at < BOARD_CACHE_SECONDS then
		return cached.rows, true
	end

	local rows: { Row } = {}

	if RunService:IsStudio() then
		for userId, value in self.memory[key] or {} do
			table.insert(rows, { userId = userId, value = value })
		end
	else
		local store = DataStoreService:GetOrderedDataStore(STORE_PREFIX .. key)
		local ok, page = DataStoreRetry.run(Enum.DataStoreRequestType.GetSortedAsync, RETRY_OPTIONS, function()
			return store:GetSortedAsync(false, READ_DEPTH):GetCurrentPage()
		end)

		if not ok then
			warn("[DanceDanceStep] League read failed: " .. tostring(page))
			return if cached ~= nil then cached.rows else rows, false
		end

		for _, entry in page do
			table.insert(rows, { userId = tonumber(entry.key) or 0, value = tonumber(entry.value) or 0 })
		end
	end

	table.sort(rows, function(a, b)
		return a.value > b.value
	end)

	self.cache[key] = { at = os.clock(), rows = rows }

	return rows, true
end

local function rankIn(rows: { Row }, userId: number): number?
	for rank, row in rows do
		if row.userId == userId then
			return rank
		end
	end

	return nil
end

-- A new week settles the one the player last played: their place there moves their
-- tier and pays the league coins, kept as result for the board to show.
function LeagueService._rollover(self: LeagueService, player: Player, profile: any, state: any)
	local week = LeagueCatalog.weekOf(os.time())

	if state.week == week or self.settling[player] then
		return
	end

	local lastWeek, lastTier, lastPoints = state.week, state.tier, state.points

	if lastWeek >= 0 and lastPoints > 0 then
		-- Claimed before the read yields, so a run finishing meanwhile cannot settle it again.
		self.settling[player] = true

		local rows, ok = self:_read(boardKey(lastWeek, lastTier, LeagueCatalog.groupOf(player.UserId)), true)

		self.settling[player] = nil

		-- Unread standings would count as a quiet "stay"; the week settles on a later try instead.
		if not ok then
			return
		end

		local rank = rankIn(rows, player.UserId)
		local move = LeagueCatalog.movement(rank, #rows)
		local coins = LeagueCatalog.CoinsFor[move]
		local step = if move == "up" then 1 elseif move == "down" then -1 else 0

		profile.softCurrency += coins
		state.result = { week = lastWeek, tier = lastTier, rank = rank, of = #rows, move = move, coins = coins }
		state.tier = LeagueCatalog.clampTier(lastTier + step)
	end

	state.week = week
	state.best = {}
	state.points = 0
	self.playerDataService:markDirty(player)
end

function LeagueService.refresh(self: LeagueService, player: Player)
	local profile = self.playerDataService:get(player)

	if profile ~= nil then
		self:_rollover(player, profile, stateOf(profile))
	end
end

function LeagueService.recordRun(self: LeagueService, player: Player, songId: string, score: number)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return
	end

	local state = stateOf(profile)

	self:_rollover(player, profile, state)

	-- Last week is still settling, or its read failed: this run waits for the next one.
	if state.week ~= LeagueCatalog.weekOf(os.time()) then
		return
	end

	local best, points = LeagueCatalog.addScore(state.best, songId, score)

	if points == state.points then
		return
	end

	state.best = best
	state.points = points
	self.playerDataService:markDirty(player)
	self:_write(boardKey(state.week, state.tier, LeagueCatalog.groupOf(player.UserId)), player.UserId, points)
end

-- What the This Week board shows: tier, place, the rows around the player and the
-- gap to the promotion line.
function LeagueService.snapshot(self: LeagueService, player: Player): { [string]: any }?
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return nil
	end

	local state = stateOf(profile)
	local week = LeagueCatalog.weekOf(os.time())
	local rows = self:_read(boardKey(week, state.tier, LeagueCatalog.groupOf(player.UserId)))
	local rank = if state.week == week then rankIn(rows, player.UserId) else nil
	local shown = LeagueCatalog.RowsShown
	local first = math.clamp((rank or 1) - math.floor(shown / 2), 1, math.max(#rows - shown + 1, 1))
	local list = {}

	for index = first, math.min(first + shown - 1, #rows) do
		local row = rows[index]

		table.insert(list, {
			rank = index,
			name = self.leaderboardService:resolveName(row.userId),
			value = row.value,
			you = row.userId == player.UserId,
		})
	end

	local line = rows[LeagueCatalog.MoveCount]

	return {
		tier = state.tier,
		tierName = LeagueCatalog.Tiers[state.tier].name,
		rank = rank,
		of = math.max(#rows, 1),
		points = if state.week == week then state.points else 0,
		rows = list,
		promoteLine = LeagueCatalog.MoveCount,
		toPromote = if rank ~= nil and rank > LeagueCatalog.MoveCount and line ~= nil then line.value - state.points + 1 else nil,
		resetsAt = LeagueCatalog.resetsAt(week),
		result = state.result,
	}
end

function LeagueService.clear(self: LeagueService, player: Player)
	self.settling[player] = nil
end

return LeagueService
