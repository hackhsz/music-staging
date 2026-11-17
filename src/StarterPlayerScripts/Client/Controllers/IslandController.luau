--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local IslandCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("IslandCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local IslandsPanel = require(script.Parent.Parent.UI.Screens.IslandsPanel)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local STATIONS_FOLDER = "Stations"
local ANCHOR_NAME = "Anchor"
-- Within this many studs of a station's anchor counts as being on that island.
local HERE_STUDS = 60
local TRAVEL_HINT = "TRAVELLING..."
local HOME_ISLAND = "spawn"
local STAGE_HINT = "LEAVE THE STAGE FIRST"

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	hub: any,
	-- Per window key, how to open it; each window's controller fills it first.
	openers: { [string]: (prompt: ProximityPrompt) -> () },
}

type Fields = {
	deps: Deps,
}

-- The Travel window and the station prompts. The window lists IslandCatalog's
-- places on the main island and the sky islands, and asks the server for a trip; a station prompt (made by StationService, carrying
-- a Window attribute) opens that window.
local IslandController = {}
IslandController.__index = IslandController

export type IslandController = typeof(setmetatable({} :: Fields, IslandController))

function IslandController.new(deps: Deps): IslandController
	return setmetatable({ deps = deps } :: Fields, IslandController)
end

function IslandController.start(self: IslandController)
	local deps = self.deps

	deps.hud.menu:bindIslands(function()
		self:toggle()
	end)
	deps.hud.islands:bindTravel(function(islandId: string)
		self:_travel(islandId)
	end)
	-- Home closes the windows (HUDController) and walks the player back to spawn.
	deps.hud.menu:bindHome(function()
		self:_goHome()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local window = prompt:GetAttribute("Window")
		local open = if type(window) == "string" then deps.openers[window] else nil

		if player == Players.LocalPlayer and open ~= nil then
			open(prompt)
		end
	end)
end

function IslandController.toggle(self: IslandController)
	if self.deps.hud.islands:isVisible() then
		self.deps.hud.islands:setVisible(false)
	else
		self:open()
	end
end

function IslandController.open(self: IslandController)
	self.deps.hud.islands:render(IslandCatalog.Areas, self:_entries())
	self.deps.hud.islands:setVisible(true)
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Streaming may not have sent a far station, so a missing anchor just means
-- the player is not there.
local function anchorPosition(stationName: string): Vector3?
	local stations = Workspace:FindFirstChild(STATIONS_FOLDER)
	local station = if stations ~= nil then stations:FindFirstChild(stationName) else nil
	local anchor = if station ~= nil then station:FindFirstChild(ANCHOR_NAME) else nil

	return if anchor ~= nil and anchor:IsA("BasePart") then anchor.Position else nil
end

function IslandController._entries(_self: IslandController): { IslandsPanel.Island }
	local position = rootPosition()
	local entries: { IslandsPanel.Island } = {}

	for _, island in IslandCatalog.Islands do
		local anchor = anchorPosition(island.station)

		table.insert(entries, {
			id = island.id,
			name = island.name,
			blurb = island.blurb,
			glyph = island.glyph,
			icon = island.icon,
			area = island.area,
			here = position ~= nil and anchor ~= nil and (position - anchor).Magnitude <= HERE_STUDS,
		})
	end

	return entries
end

function IslandController._goHome(self: IslandController)
	local deps = self.deps

	if not deps.hub:isHub() or deps.hub:isOnStage() then
		return
	end

	for _, island in self:_entries() do
		if island.id == HOME_ISLAND and island.here then
			return
		end
	end

	self:_travel(HOME_ISLAND)
end

function IslandController._travel(self: IslandController, islandId: string)
	local deps = self.deps

	if deps.hub:isOnStage() then
		deps.hud.hints:setHint(STAGE_HINT)
		return
	end

	deps.hud.islands:setVisible(false)
	deps.hud.hints:setHint(TRAVEL_HINT)
	deps.remotes.TravelToIsland:FireServer({ islandId = islandId })
end

return IslandController
