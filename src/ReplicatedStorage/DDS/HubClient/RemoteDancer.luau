local ROOT_OFFSET = Vector3.new(0, 3.5, 0)
local STEP_SEC = 0.1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DDS = ReplicatedStorage:WaitForChild("DDS")
local Config = require(DDS:WaitForChild("Config"))
local Maid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Maid"))

local RemoteDancer = {}
RemoteDancer.__index = RemoteDancer

function RemoteDancer.new(station: Model, role: string, pad: Model)
	local self = setmetatable({}, RemoteDancer)
	self.maid = Maid.new()
	self.station = station
	self.cellAttribute = "Cell" .. role
	self.idAttribute = if role == "A" then "HostId" else "RivalId"
	self.tiles = {}

	for _, tile in pad:GetDescendants() do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		if tile:IsA("BasePart") and row ~= nil and col ~= nil then
			self.tiles[row * Config.GRID_SIZE + col] = tile
		end
	end

	self.maid:GiveTask(station:GetAttributeChangedSignal(self.cellAttribute):Connect(function()
		self:Follow()
	end))
	self.maid:GiveTask(function()
		self:Release()
	end)
	return self
end

function RemoteDancer:RootPart(): BasePart?
	local userId = self.station:GetAttribute(self.idAttribute)
	if typeof(userId) ~= "number" or userId <= 0 then
		return nil
	end
	local dancer = Players:GetPlayerByUserId(userId)
	if not dancer or dancer == Players.LocalPlayer or not dancer.Character then
		return nil
	end
	return dancer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function RemoteDancer:Follow()
	local cell = self.station:GetAttribute(self.cellAttribute)
	local rootPart = self:RootPart()
	if typeof(cell) ~= "Vector2" or not rootPart then
		return
	end
	local tile = self.tiles[cell.X * Config.GRID_SIZE + cell.Y]
	if not tile then
		return
	end

	self.rootPart = rootPart
	rootPart.Anchored = true
	local target = tile.Position + ROOT_OFFSET
	local heading = (target - rootPart.Position) * Vector3.new(1, 0, 1)
	local look = if heading.Magnitude > 0.01 then CFrame.lookAt(target, target + heading.Unit) else CFrame.new(target) * rootPart.CFrame.Rotation
	TweenService:Create(rootPart, TweenInfo.new(STEP_SEC, Enum.EasingStyle.Linear), { CFrame = look }):Play()
end

function RemoteDancer:Release()
	if self.rootPart and self.rootPart.Parent then
		self.rootPart.Anchored = false
	end
end

function RemoteDancer:Destroy()
	self.maid:DoCleaning()
end

return RemoteDancer
