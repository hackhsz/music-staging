--!strict
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FunnelCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("FunnelCatalog"))

local SHOP_FUNNEL = "shop"
local SHOP_OPENED = "opened"

type Fields = {
	playerDataService: any,
	shopSessions: { [Player]: string },
}

-- Logs FunnelCatalog's funnels to the Creator Dashboard. The onboarding funnel is
-- remembered on the profile so a step is logged once per player across visits;
-- the shop and run funnels log one session per visit and per run.
local FunnelService = {}
FunnelService.__index = FunnelService

export type FunnelService = typeof(setmetatable({} :: Fields, FunnelService))

function FunnelService.new(playerDataService: any): FunnelService
	return setmetatable({
		playerDataService = playerDataService,
		shopSessions = {},
	} :: Fields, FunnelService)
end

function FunnelService.newSessionId(): string
	return HttpService:GenerateGUID(false)
end

-- Studio playtests print the step instead: AnalyticsService only records live servers.
local function log(player: Player, funnelName: string, sessionId: string?, index: number, stepId: string)
	if RunService:IsStudio() then
		print(("[DanceDanceStep][Funnel] %s %s #%d %s"):format(player.Name, funnelName, index, stepId))
	end

	local ok, err = pcall(function()
		if funnelName == FunnelCatalog.Onboarding then
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, stepId)
		else
			AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, index, stepId)
		end
	end)

	if not ok then
		warn(("[DanceDanceStep] Funnel step %s/%s not logged: %s"):format(funnelName, stepId, tostring(err)))
	end
end

function FunnelService.onboarding(self: FunnelService, player: Player, stepId: string)
	local index = FunnelCatalog.stepIndex(FunnelCatalog.Onboarding, stepId)
	local profile = self.playerDataService:get(player)

	if index == nil or profile == nil or type(profile.onboarding) ~= "table" then
		return
	end

	local logged = profile.onboarding.funnelLogged

	if logged[stepId] == true then
		return
	end

	logged[stepId] = true
	self.playerDataService:markDirty(player)
	log(player, FunnelCatalog.Onboarding, nil, index, stepId)
end

function FunnelService.step(self: FunnelService, player: Player, funnelName: string, sessionId: string, stepId: string)
	local index = FunnelCatalog.stepIndex(funnelName, stepId)

	if index ~= nil then
		log(player, funnelName, sessionId, index, stepId)
	end
end

-- A shop step joins the visit opened last; opening the shop starts a new one.
function FunnelService.shop(self: FunnelService, player: Player, stepId: string)
	if stepId == SHOP_OPENED then
		self.shopSessions[player] = FunnelService.newSessionId()
	end

	local sessionId = self.shopSessions[player]

	if sessionId ~= nil then
		self:step(player, SHOP_FUNNEL, sessionId, stepId)
	end
end

-- From ReportFunnelStep: only the steps FunnelCatalog says the client reports.
function FunnelService.report(self: FunnelService, player: Player, funnelName: string, stepId: string)
	if not FunnelCatalog.isClientStep(funnelName, stepId) then
		return
	end

	if funnelName == FunnelCatalog.Onboarding then
		self:onboarding(player, stepId)
	elseif funnelName == SHOP_FUNNEL then
		self:shop(player, stepId)
	end
end

function FunnelService.clear(self: FunnelService, player: Player)
	self.shopSessions[player] = nil
end

return FunnelService
