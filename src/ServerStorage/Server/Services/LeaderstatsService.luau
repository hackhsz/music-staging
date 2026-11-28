--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("RankCatalog"))

local FOLDER_NAME = "leaderstats"
local RANK_NAME = "Rank"
local BEST_NAME = "Best"

local LeaderstatsService = {}
LeaderstatsService.__index = LeaderstatsService

type Stats = {
	folder: Folder,
	rank: IntValue,
	best: IntValue,
}

export type LeaderstatsService = typeof(setmetatable(
	{} :: {
		playerDataService: any,
		stats: { [Player]: Stats },
	},
	LeaderstatsService
))

local function newValue(name: string, parent: Instance): IntValue
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent

	return value
end

function LeaderstatsService.new(playerDataService: any): LeaderstatsService
	return setmetatable({
		playerDataService = playerDataService,
		stats = {},
	}, LeaderstatsService)
end

function LeaderstatsService.add(self: LeaderstatsService, player: Player)
	if self.stats[player] ~= nil then
		self:refresh(player)
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	self.stats[player] = {
		folder = folder,
		rank = newValue(RANK_NAME, folder),
		best = newValue(BEST_NAME, folder),
	}

	self:refresh(player)
	folder.Parent = player
end

function LeaderstatsService.refresh(self: LeaderstatsService, player: Player)
	local stats = self.stats[player]
	local profile = self.playerDataService:get(player)

	if stats == nil or profile == nil then
		return
	end

	local bestScore = if type(profile.stats) == "table" then tonumber(profile.stats.bestScore) else nil

	stats.rank.Value = RankCatalog.clampRank(profile.rank)
	stats.best.Value = math.floor(bestScore or 0)
end

function LeaderstatsService.clear(self: LeaderstatsService, player: Player)
	local stats = self.stats[player]

	if stats == nil then
		return
	end

	stats.folder:Destroy()
	self.stats[player] = nil
end

return LeaderstatsService
