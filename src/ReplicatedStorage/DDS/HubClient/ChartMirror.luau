local FLASH_BEATS = 0.6

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DDS = ReplicatedStorage:WaitForChild("DDS")
local Config = require(DDS:WaitForChild("Config"))
local Maid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Maid"))

local ChartMirror = {}
ChartMirror.__index = ChartMirror

local function colorForKind(kind: string): Color3
	if kind == "SHAPE" then
		return Config.SHAPE_COLOR
	end
	if kind == "DANGER" then
		return Config.DANGER_COLOR
	end
	if kind == "ITEM" then
		return Config.ITEM_COLOR
	end
	return Config.TARGET_COLOR
end

local function isEvenTile(tile: BasePart): boolean
	return (tile:GetAttribute("Row") + tile:GetAttribute("Col")) % 2 == 0
end

function ChartMirror.new(pad: Model, chart, songStartAt: number)
	local self = setmetatable({}, ChartMirror)
	self.maid = Maid.new()
	self.chart = chart
	self.songStartAt = songStartAt
	self.beatSec = 60 / chart.bpm
	self.lead = chart.W or Config.TELEGRAPH_LEAD
	self.eventIndex = 1
	self.tiles = {}

	for _, tile in pad:GetDescendants() do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		if tile:IsA("BasePart") and row ~= nil and col ~= nil then
			self.tiles[row * Config.GRID_SIZE + col] = tile
		end
	end

	self.maid:GiveTask(RunService.Heartbeat:Connect(function()
		self:Render()
	end))
	self.maid:GiveTask(function()
		self:ApplyLobbyLook()
	end)
	return self
end

function ChartMirror:Render()
	local events = self.chart.events
	local songTime = workspace:GetServerTimeNow() - self.songStartAt
	local beat = (songTime - (self.chart.firstBeatSec or 0)) / self.beatSec
	while events[self.eventIndex] and events[self.eventIndex].beat < beat - FLASH_BEATS do
		self.eventIndex += 1
	end

	local painted = {}
	for index = self.eventIndex, #events do
		local event = events[index]
		local beatsAway = event.beat - beat
		if beatsAway > self.lead then
			break
		end

		local color, strength
		if beatsAway <= 0 then
			if event.kind == "DANGER" then
				continue
			end
			color, strength = Config.HIT_COLOR, 1 + beatsAway / FLASH_BEATS
		else
			local progress = 1 - beatsAway / self.lead
			color, strength = colorForKind(event.kind), Config.TELEGRAPH_MIN_ALPHA + (1 - Config.TELEGRAPH_MIN_ALPHA) * progress * progress
		end
		for _, rowCol in event.tiles do
			local key = rowCol[1] * Config.GRID_SIZE + rowCol[2]
			if not painted[key] then
				painted[key] = { color = color, strength = strength }
			end
		end
	end

	for key, tile in self.tiles do
		local idle = if isEvenTile(tile) then Config.IDLE_COLOR else Config.IDLE_COLOR_ALT
		local paint = painted[key]
		tile.Color = if paint then idle:Lerp(paint.color, paint.strength) else idle
		tile.Material = if paint and paint.strength > 0.6 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

function ChartMirror:ApplyLobbyLook()
	for _, tile in self.tiles do
		tile.Color = if isEvenTile(tile) then Config.LOBBY_COLOR_A else Config.LOBBY_COLOR_B
		tile.Material = Enum.Material.SmoothPlastic
	end
end

function ChartMirror:Destroy()
	self.maid:DoCleaning()
end

return ChartMirror
