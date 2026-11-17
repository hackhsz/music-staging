--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local IslandCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("IslandCatalog"))

local HUB_ATTRIBUTE = "DanceHub"
local STATIONS_FOLDER = "Stations"
local SOLO_KIND = "Solo"
local PAD_NAME = "PadA"
local CENTER_TILE = "Tile_2_2"
local PROMPT_DISTANCE = 12
local ANCHOR_NAME = "Anchor"
-- Attributes a station copies onto its window prompt for the client to read.
local WINDOW_ATTRIBUTES = { "Window", "Stall" }
-- Back on the pad, a little above it so the character lands rather than clips.
local RETURN_LIFT = Vector3.new(0, 4, 0)

-- In a hub place (Workspace.DanceHub) the song picker opens from a station on the
-- map instead of on join. Each Solo station gets a prompt; the station a player
-- used is where leaving the stage puts them back. A station with a Window
-- attribute gets a prompt on its Anchor part that opens that lobby window, and
-- the Islands window travels to a station's Anchor.
local StationService = {}
StationService.__index = StationService

export type StationService = typeof(setmetatable(
	{} :: {
		openPicker: RemoteEvent,
		returnPoints: { [Player]: CFrame },
		lastTravel: { [Player]: number },
	},
	StationService
))

function StationService.new(openPicker: RemoteEvent): StationService
	return setmetatable({
		openPicker = openPicker,
		returnPoints = {},
		lastTravel = {},
	}, StationService)
end

function StationService.isHub(): boolean
	return Workspace:GetAttribute(HUB_ATTRIBUTE) == true
end

function StationService.start(self: StationService)
	if not StationService.isHub() then
		return
	end

	local stations = Workspace:FindFirstChild(STATIONS_FOLDER)

	if stations == nil then
		warn("[DanceDanceStep] DanceHub is set but Workspace has no Stations folder")
		return
	end

	for _, station in stations:GetChildren() do
		if station:GetAttribute("Kind") == SOLO_KIND then
			self:_addPrompt(station)
		end

		if type(station:GetAttribute("Window")) == "string" then
			self:_addWindowPrompt(station)
		end
	end
end

local function anchorOf(station: Instance?): BasePart?
	if station == nil then
		return nil
	end

	local pad = station:FindFirstChild(PAD_NAME)
	local anchor = station:FindFirstChild(ANCHOR_NAME) or (if pad ~= nil then pad:FindFirstChild(CENTER_TILE) else nil)

	return if anchor ~= nil and anchor:IsA("BasePart") then anchor else nil
end

function StationService._addWindowPrompt(_self: StationService, station: Instance)
	local anchor = station:FindFirstChild(ANCHOR_NAME)

	if anchor == nil or not anchor:IsA("BasePart") then
		warn(("[DanceDanceStep] Station %s has a Window but no %s part"):format(station.Name, ANCHOR_NAME))
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenWindowPrompt"
	prompt.ActionText = tostring(station:GetAttribute("Prompt") or "Open")
	prompt.ObjectText = tostring(station:GetAttribute("DisplayName") or station.Name)
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false

	for _, name in WINDOW_ATTRIBUTES do
		prompt:SetAttribute(name, station:GetAttribute(name))
	end

	prompt.Parent = anchor
end

-- Moves a player to an island's station; the caller has already checked they are
-- not in a run. Returns (ok, reason).
function StationService.travel(self: StationService, player: Player, islandId: string): (boolean, string)
	if not StationService.isHub() then
		return false, "not_a_hub"
	end

	local island = IslandCatalog.get(islandId)

	if island == nil then
		return false, "unknown_island"
	end

	local now = os.clock()
	local last = self.lastTravel[player]

	if last ~= nil and now - last < IslandCatalog.TravelCooldownSeconds then
		return false, "travel_cooldown"
	end

	local stations = Workspace:FindFirstChild(STATIONS_FOLDER)
	local anchor = anchorOf(if stations ~= nil then stations:FindFirstChild(island.station) else nil)
	local character = player.Character

	if anchor == nil then
		return false, "no_station"
	end

	if character == nil or character:FindFirstChild("HumanoidRootPart") == nil then
		return false, "no_character"
	end

	self.lastTravel[player] = now
	character:PivotTo(anchor.CFrame + RETURN_LIFT)

	return true, "travelled"
end

function StationService._addPrompt(self: StationService, station: Instance)
	local pad = station:FindFirstChild(PAD_NAME)
	local anchor = if pad ~= nil then pad:FindFirstChild(CENTER_TILE) else nil

	if anchor == nil or not anchor:IsA("BasePart") then
		warn(("[DanceDanceStep] Station %s has no %s.%s for its prompt"):format(station.Name, PAD_NAME, CENTER_TILE))
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickSongPrompt"
	prompt.ActionText = "Pick a Song"
	prompt.ObjectText = tostring(station:GetAttribute("DisplayName") or station.Name)
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	local returnPoint = anchor.CFrame + RETURN_LIFT

	prompt.Triggered:Connect(function(player: Player)
		self.returnPoints[player] = returnPoint
		self.openPicker:FireClient(player, {})
	end)
end

-- Puts a player who has left the stage back at the station they came from, or at
-- the place's spawn when they never used one.
function StationService.returnToHub(self: StationService, player: Player)
	if not StationService.isHub() then
		return
	end

	local character = player.Character

	if character == nil then
		return
	end

	local point: CFrame? = self.returnPoints[player]

	if point == nil then
		local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation")
		point = if spawn ~= nil then spawn.CFrame + RETURN_LIFT else nil
	end

	if point ~= nil then
		character:PivotTo(point)
	end
end

function StationService.clear(self: StationService, player: Player)
	self.returnPoints[player] = nil
	self.lastTravel[player] = nil
end

return StationService
