--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Catalogs"):WaitForChild("Economy"))
local OnboardingCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("OnboardingCatalog"))
local TutorialChart = require(Shared:WaitForChild("TutorialChart"))

local STATIONS_FOLDER = "Stations"
local ANCHOR_NAME = "Anchor"
-- Studio starts every playtest from a fresh profile; this Workspace attribute
-- lets it start past the lesson and the steps after it instead.
local STUDIO_SKIP_ATTRIBUTE = "SkipOnboarding"

export type DrillResult = {
	drill: number,
	passed: boolean,
	landed: number,
	total: number,
	tutorialDone: boolean,
	gift: number?,
}

type Fields = {
	playerDataService: any,
	funnels: any,
	stateRemote: RemoteEvent,
	syncProfile: (player: Player) -> (),
}

-- The first-join lesson and what follows it: which drills are passed, which
-- steps and tips are done (all on the profile), the one-time lesson gift, and the
-- state pushed to the client so it knows what to show next.
local OnboardingService = {}
OnboardingService.__index = OnboardingService

export type OnboardingService = typeof(setmetatable({} :: Fields, OnboardingService))

function OnboardingService.new(
	playerDataService: any,
	funnels: any,
	stateRemote: RemoteEvent,
	syncProfile: (player: Player) -> ()
): OnboardingService
	return setmetatable({
		playerDataService = playerDataService,
		funnels = funnels,
		stateRemote = stateRemote,
		syncProfile = syncProfile,
	} :: Fields, OnboardingService)
end

local function findPart(root: Instance, path: string): BasePart?
	local current: Instance? = root

	for name in path:gmatch("[^%.]+") do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end

	return if current ~= nil and current:IsA("BasePart") then current else nil
end

-- Read on the server, where the whole island is always loaded.
local function stopPositions(): { [string]: Vector3 }
	local stations = Workspace:FindFirstChild(STATIONS_FOLDER)
	local positions = {}

	if stations == nil then
		return positions
	end

	for _, tip in OnboardingCatalog.Tips do
		local station = if tip.station ~= nil then stations:FindFirstChild(tip.station) else nil
		local part = if station ~= nil then findPart(station, tip.part or ANCHOR_NAME) else nil

		if part ~= nil then
			positions[tip.id] = part.Position
		end
	end

	return positions
end

function OnboardingService._onboarding(self: OnboardingService, player: Player): any
	local profile = self.playerDataService:get(player)

	return if profile ~= nil and type(profile.onboarding) == "table" then profile.onboarding else nil
end

function OnboardingService.push(self: OnboardingService, player: Player)
	local onboarding = self:_onboarding(player)

	if onboarding == nil then
		return
	end

	if RunService:IsStudio() and Workspace:GetAttribute(STUDIO_SKIP_ATTRIBUTE) == true then
		onboarding.tutorialDone = true
		onboarding.done[OnboardingCatalog.TimingCheck.id] = true

		for _, tip in OnboardingCatalog.Tips do
			onboarding.done[tip.id] = true
		end
	end

	local done = onboarding.done

	if not OnboardingCatalog.Enabled then
		done = table.clone(done)
		done[OnboardingCatalog.TimingCheck.id] = true

		for _, tip in OnboardingCatalog.Tips do
			done[tip.id] = true
		end
	end

	self.stateRemote:FireClient(player, {
		tutorialDone = onboarding.tutorialDone == true or not OnboardingCatalog.Enabled,
		drillsPassed = tonumber(onboarding.drillsPassed) or 0,
		done = done,
		stops = stopPositions(),
	})
end

-- A drill may be replayed, or played once every drill before it has passed.
function OnboardingService.canStartDrill(self: OnboardingService, player: Player, drill: number): boolean
	local onboarding = self:_onboarding(player)

	if onboarding == nil or TutorialChart.Drills[drill] == nil then
		return false
	end

	return onboarding.tutorialDone == true or drill <= (tonumber(onboarding.drillsPassed) or 0) + 1
end

function OnboardingService.drillFinished(self: OnboardingService, player: Player, drill: number, summary: any): DrillResult?
	local onboarding = self:_onboarding(player)

	if onboarding == nil or TutorialChart.Drills[drill] == nil then
		return nil
	end

	local passed = TutorialChart.passed(summary)
	local total = tonumber(summary.totalSteps) or 0
	local result: DrillResult = {
		drill = drill,
		passed = passed,
		landed = total - (tonumber(summary.misses) or 0),
		total = total,
		tutorialDone = onboarding.tutorialDone == true,
		gift = nil,
	}

	-- Progress moves one drill at a time, so a lesson cannot be passed from its end.
	local advanced = passed and drill == (tonumber(onboarding.drillsPassed) or 0) + 1

	if advanced then
		onboarding.drillsPassed = drill
		self.playerDataService:markDirty(player)
		self.funnels:onboarding(player, TutorialChart.Drills[drill].funnelStep)
	end

	if advanced and drill == TutorialChart.DrillCount and onboarding.tutorialDone ~= true then
		result.gift = self:completeTutorial(player, true)
		result.tutorialDone = true
	end

	return result
end

-- Passing the last drill or skipping both end the lesson. Only passing pays the
-- gift, once, so a fresh account cannot skip its way to coins. Returns the coins paid.
function OnboardingService.completeTutorial(self: OnboardingService, player: Player, earned: boolean): number
	local profile = self.playerDataService:get(player)
	local onboarding = self:_onboarding(player)

	if profile == nil or onboarding == nil then
		return 0
	end

	local paid = 0

	if earned and onboarding.giftPaid ~= true then
		paid = Economy.Rewards.LessonGift
		onboarding.giftPaid = true
		profile.softCurrency = (profile.softCurrency or 0) + paid
	end

	onboarding.tutorialDone = true
	self.playerDataService:markDirty(player)
	self.funnels:onboarding(player, "tutorial_done")
	self:push(player)

	if paid > 0 then
		self.syncProfile(player)
	end

	return paid
end

function OnboardingService.completeStep(self: OnboardingService, player: Player, stepId: string)
	local onboarding = self:_onboarding(player)

	-- Everything after the lesson comes after it; a step cannot skip the lesson.
	if onboarding == nil or onboarding.tutorialDone ~= true or not OnboardingCatalog.isStep(stepId) then
		return
	end

	if onboarding.done[stepId] == true then
		return
	end

	onboarding.done[stepId] = true
	self.playerDataService:markDirty(player)
	self.funnels:onboarding(
		player,
		if stepId == OnboardingCatalog.TimingCheck.id then "timing_checked" else "tip_" .. stepId
	)
	self:push(player)
end

return OnboardingService
