--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))

local FOLDER_NAME = "Arenas"
local SHOWN_NAME = "ArenaSkin"
local CROWD_NAME = "Crowd"
local BEAT_BOOST = 0.8
local FLASH_GROUPS = 3
local FLASH_DIM = 0.6

type PulsedLight = { light: Light, base: number }
type Animated = {
	part: BasePart,
	base: CFrame,
	baseTransparency: number,
	spin: number,
	axis: Vector3,
	sway: number,
	bob: number,
	flash: boolean,
	order: number,
	turned: number,
}

export type Look = { [string]: any }
export type ArenaSkins = {
	onBeat: (phase: number, beatIndex: number) -> (),
}

-- Swaps the environment around the dance floor for the arena the server names on
-- the local player. Arenas are models in ReplicatedStorage.Arenas, authored in
-- Studio with their pivot at the floor's centre; the default is Workspace.Arena.
-- The swap is local, so players on the same server can each see a different one.
-- An arena carries its own look (lighting attributes and a Sky) and animates any
-- part with a Spin, Sway, Bob or BeatFlash attribute; see docs/arenas.
local ArenaSkins = {}

local function lightsOf(model: Instance): { PulsedLight }
	local lights = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Light") then
			table.insert(lights, { light = descendant, base = descendant.Brightness })
		end
	end

	return lights
end

local function number(part: BasePart, name: string): number
	local value = part:GetAttribute(name)

	return if type(value) == "number" then value else 0
end

local function animatedOf(model: Instance): { Animated }
	local animated = {}

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		local entry: Animated = {
			part = descendant,
			base = descendant.CFrame,
			baseTransparency = descendant.Transparency,
			spin = number(descendant, "Spin"),
			axis = Vector3.yAxis,
			sway = number(descendant, "Sway"),
			bob = number(descendant, "Bob"),
			flash = descendant:GetAttribute("BeatFlash") == true,
			order = #animated,
			turned = 0,
		}

		local axis = descendant:GetAttribute("SpinAxis")

		if typeof(axis) == "Vector3" and axis.Magnitude > 0 then
			entry.axis = axis.Unit
		end

		if entry.spin ~= 0 or entry.sway ~= 0 or entry.bob ~= 0 or entry.flash then
			table.insert(animated, entry)
		end
	end

	return animated
end

-- PascalCase attributes on the arena model become StageLighting.Config keys.
local function lookOf(template: Instance): Look
	local look = {}

	for name, value in template:GetAttributes() do
		look[name:sub(1, 1):lower() .. name:sub(2)] = value
	end

	return look
end

function ArenaSkins.new(defaultRoot: Instance, onLook: (look: Look, sky: Sky?) -> ()): ArenaSkins
	local player = Players.LocalPlayer
	local crowd = defaultRoot:FindFirstChild(CROWD_NAME)
	local shown: Model? = nil
	local lights: { PulsedLight } = {}
	local animated: { Animated } = {}
	local phase = 0
	local beatIndex = 0

	local function clear()
		if shown == nil then
			return
		end

		if crowd ~= nil then
			crowd.Parent = defaultRoot
		end

		shown:Destroy()
		shown = nil
		lights = {}
		animated = {}
	end

	local function show(arenaId: string)
		clear()

		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		local template = if arenaId ~= CosmeticsCatalog.DefaultArenaId and folder ~= nil
			then folder:FindFirstChild(arenaId)
			else nil

		if arenaId ~= CosmeticsCatalog.DefaultArenaId and (template == nil or not template:IsA("Model")) then
			warn(("[DanceDanceStep] ReplicatedStorage.Arenas.%s not found; showing the default arena"):format(arenaId))
			template = nil
		end

		if template == nil then
			defaultRoot.Parent = Workspace
			onLook({}, nil)
			return
		end

		local skin = (template :: Model):Clone()
		skin.Name = SHOWN_NAME
		skin:PivotTo(CFrame.new(Board.Origin))
		skin.Parent = Workspace
		shown = skin
		lights = lightsOf(skin)
		animated = animatedOf(skin)

		if crowd ~= nil and skin:GetAttribute("Crowd") ~= false then
			crowd.Parent = skin
		end

		-- Only this client sees the change; the server still holds Workspace.Arena.
		defaultRoot.Parent = nil
		onLook(lookOf(template), skin:FindFirstChildOfClass("Sky"))
	end

	local function refresh()
		local arenaId = player:GetAttribute(CosmeticsCatalog.ArenaAttribute)

		show(if type(arenaId) == "string" then arenaId else CosmeticsCatalog.DefaultArenaId)
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local hop = (1 - phase) ^ 2
		local swing = math.sin((beatIndex + phase) * math.pi)
		local pulse = 1 + BEAT_BOOST * hop

		for _, entry in lights do
			entry.light.Brightness = entry.base * pulse
		end

		for _, entry in animated do
			entry.turned += math.rad(entry.spin) * deltaTime

			if entry.spin ~= 0 or entry.sway ~= 0 or entry.bob ~= 0 then
				entry.part.CFrame = CFrame.new(0, entry.bob * hop, 0)
					* entry.base
					* CFrame.Angles(0, 0, math.rad(entry.sway) * swing)
					* CFrame.fromAxisAngle(entry.axis, entry.turned)
			end

			if entry.flash then
				local lit = (beatIndex + entry.order) % FLASH_GROUPS == 0
				entry.part.Transparency = if lit then entry.baseTransparency else math.max(entry.baseTransparency, FLASH_DIM)
			end
		end
	end)

	player:GetAttributeChangedSignal(CosmeticsCatalog.ArenaAttribute):Connect(refresh)
	refresh()

	return {
		onBeat = function(newPhase: number, newBeatIndex: number)
			phase = newPhase
			beatIndex = newBeatIndex
		end,
	}
end

return ArenaSkins
