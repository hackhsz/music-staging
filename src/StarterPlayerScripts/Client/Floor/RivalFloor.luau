--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "DanceDanceStepRivalBot"
local TILE_SIZE = 4
local TILE_HEIGHT = 0.24
local TILE_INSET = 0.3
-- A podium like the main stage: a solid deck a little wider than the tiles, its top
-- edge trimmed in the rival's colour.
local DECK_BORDER = 2
local DECK_DEPTH = 4
local DECK_COLOR = Color3.fromRGB(44, 38, 76)
local TRIM_WIDTH = 0.4
local TRIM_HEIGHT = 0.3
local TILE_A = Color3.fromRGB(34, 20, 52)
local TILE_B = Color3.fromRGB(24, 14, 38)
local TARGET_DIM = 0.55
local FLASH_SECONDS = 0.4
local FLASH_INFO = TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FALLBACK_LIFT = 3
local TAG_OFFSET = Vector3.new(0, 3.2, 0)
local TAG_SIZE = UDim2.fromOffset(150, 28)
local TAG_FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local TAG_STROKE = Color3.fromRGB(20, 8, 30)

-- hair, shirt and pants are free Roblox-made catalog asset ids, so a bot
-- looks like any other player on the platform.
export type Look = {
	name: string,
	color: Color3,
	skin: Color3,
	outfit: Color3,
	legs: Color3,
	hair: number?,
	shirt: number?,
	pants: number?,
}

type Fields = {
	folder: Folder,
	origin: Vector3,
	columns: number,
	rows: number,
	tiles: { BasePart },
	baseColors: { Color3 },
	tweens: { Tween? },
	litUntil: { number },
	rig: Model?,
	root: BasePart?,
	lift: number,
	shown: boolean,
}

-- The rival bot's own small floor beside the player's, and the rig dancing on
-- it. Drawing only: RivalController decides where it goes and what it scores.
local RivalFloor = {}
RivalFloor.__index = RivalFloor

export type RivalFloor = typeof(setmetatable({} :: Fields, RivalFloor))

local function quietPart(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function buildDescription(look: Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.outfit
	description.LeftLegColor = look.legs
	description.RightLegColor = look.legs
	description.BodyTypeScale = 0.3
	description.ProportionScale = 0.6
	description.HairAccessory = if look.hair ~= nil then tostring(look.hair) else ""
	description.Shirt = look.shirt or 0
	description.Pants = look.pants or 0

	return description
end

local function humanoidRig(look: Look): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(buildDescription(look), Enum.HumanoidRigType.R15)
	end)

	if not ok or model == nil then
		return nil
	end

	local animate = model:FindFirstChild("Animate")

	if animate ~= nil then
		animate:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return model
end

local function blockPart(model: Model, root: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = root.CFrame + offset
	quietPart(part)
	part.Massless = true
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

-- A plain figure for when the avatar service is unavailable.
local function blockRig(look: Look): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	quietPart(root)
	root.Parent = model
	model.PrimaryPart = root

	blockPart(model, root, "Torso", Vector3.new(2, 2, 1), Vector3.zero, look.outfit)
	blockPart(model, root, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), look.skin)
	blockPart(model, root, "LeftArm", Vector3.new(0.8, 1.9, 0.8), Vector3.new(-1.4, 0.05, 0), look.skin)
	blockPart(model, root, "RightArm", Vector3.new(0.8, 1.9, 0.8), Vector3.new(1.4, 0.05, 0), look.skin)
	blockPart(model, root, "LeftLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, -2, 0), look.legs)
	blockPart(model, root, "RightLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, -2, 0), look.legs)

	return model
end

-- Yields: the avatar service builds the rig from the description.
function RivalFloor.buildRig(look: Look): Model
	local model = humanoidRig(look) or blockRig(look)
	model.Name = look.name

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			quietPart(part)
		end
	end

	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?

	if root ~= nil then
		root.Anchored = true
	end

	local head = model:FindFirstChild("Head") :: BasePart?
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = TAG_SIZE
	tag.StudsOffsetWorldSpace = TAG_OFFSET
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	if head ~= nil then
		tag.Adornee = head
	elseif root ~= nil then
		tag.Adornee = root
	end
	tag.Parent = model

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = TAG_FONT
	label.Text = string.upper(look.name)
	label.TextColor3 = look.color
	label.TextScaled = true
	label.Parent = tag

	local stroke = Instance.new("UIStroke")
	stroke.Color = TAG_STROKE
	stroke.Thickness = 2
	stroke.Parent = label

	return model
end

function RivalFloor.new(origin: Vector3, columns: number, rows: number, look: Look): RivalFloor
	local existing = Workspace:FindFirstChild(FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local width = columns * TILE_SIZE + DECK_BORDER * 2
	local depth = rows * TILE_SIZE + DECK_BORDER * 2

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Anchored = true
	deck.Size = Vector3.new(width, DECK_DEPTH, depth)
	deck.Position = origin - Vector3.new(0, DECK_DEPTH / 2, 0)
	deck.Color = DECK_COLOR
	deck.Material = Enum.Material.SmoothPlastic
	quietPart(deck)
	deck.Parent = folder

	local edges: { { name: string, size: Vector3, offset: Vector3 } } = {
		{ name = "North", size = Vector3.new(width, TRIM_HEIGHT, TRIM_WIDTH), offset = Vector3.new(0, 0, -depth / 2) },
		{ name = "South", size = Vector3.new(width, TRIM_HEIGHT, TRIM_WIDTH), offset = Vector3.new(0, 0, depth / 2) },
		{ name = "West", size = Vector3.new(TRIM_WIDTH, TRIM_HEIGHT, depth), offset = Vector3.new(-width / 2, 0, 0) },
		{ name = "East", size = Vector3.new(TRIM_WIDTH, TRIM_HEIGHT, depth), offset = Vector3.new(width / 2, 0, 0) },
	}

	for _, edge in edges do
		local trim = Instance.new("Part")
		trim.Name = "Rim" .. edge.name
		trim.Anchored = true
		trim.Size = edge.size
		trim.Position = origin + edge.offset + Vector3.new(0, TRIM_HEIGHT / 2, 0)
		trim.Color = look.color
		trim.Material = Enum.Material.Neon
		quietPart(trim)
		trim.Parent = folder
	end

	local self = setmetatable({
		folder = folder,
		origin = origin,
		columns = columns,
		rows = rows,
		tiles = {},
		baseColors = {},
		tweens = {},
		litUntil = {},
		rig = nil,
		root = nil,
		lift = FALLBACK_LIFT,
		shown = true,
	} :: Fields, RivalFloor)

	for y = 1, rows do
		for x = 1, columns do
			local index = self:_index(x, y)
			local color = if (x + y) % 2 == 0 then TILE_A else TILE_B
			local tile = Instance.new("Part")
			tile.Name = string.format("Tile_%d_%d", x, y)
			tile.Anchored = true
			tile.Size = Vector3.new(TILE_SIZE - TILE_INSET, TILE_HEIGHT, TILE_SIZE - TILE_INSET)
			tile.Position = self:_tileCenter(x, y) + Vector3.new(0, TILE_HEIGHT / 2, 0)
			tile.Color = color
			tile.Material = Enum.Material.SmoothPlastic
			quietPart(tile)
			tile.Parent = folder

			self.tiles[index] = tile
			self.baseColors[index] = color
			self.litUntil[index] = 0
		end
	end

	folder.Parent = Workspace

	return self
end

function RivalFloor.footprint(columns: number, rows: number): Vector2
	return Vector2.new(columns * TILE_SIZE, rows * TILE_SIZE)
end

function RivalFloor.isShown(self: RivalFloor): boolean
	return self.shown
end

function RivalFloor._index(self: RivalFloor, x: number, y: number): number
	return (y - 1) * self.columns + x
end

function RivalFloor._tileCenter(self: RivalFloor, x: number, y: number): Vector3
	local offsetX = (x - (self.columns + 1) / 2) * TILE_SIZE
	local offsetZ = (y - (self.rows + 1) / 2) * TILE_SIZE

	return self.origin + Vector3.new(offsetX, 0, offsetZ)
end

-- Where the rig's root stands on a tile.
function RivalFloor.standPoint(self: RivalFloor, x: number, y: number): Vector3
	return self:_tileCenter(x, y) + Vector3.new(0, TILE_HEIGHT + self.lift, 0)
end

function RivalFloor.isValid(self: RivalFloor, x: number, y: number): boolean
	return x >= 1 and x <= self.columns and y >= 1 and y <= self.rows
end

function RivalFloor.setRig(self: RivalFloor, rig: Model)
	local root = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")

	self.rig = rig
	self.root = root

	if root ~= nil and humanoid ~= nil then
		self.lift = humanoid.HipHeight + root.Size.Y / 2
	end

	rig.Parent = self.folder
	self:_applyShown()
end

-- Hidden, the floor and the bot still dance, just without being drawn.
function RivalFloor.setShown(self: RivalFloor, shown: boolean)
	if self.shown == shown then
		return
	end

	self.shown = shown
	self:_applyShown()
end

function RivalFloor._applyShown(self: RivalFloor)
	local modifier = if self.shown then 0 else 1

	for _, item in self.folder:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = modifier
		elseif item:IsA("Decal") then
			item.LocalTransparencyModifier = modifier
		elseif item:IsA("BillboardGui") then
			item.Enabled = self.shown
		end
	end
end

function RivalFloor.getRig(self: RivalFloor): Model?
	return self.rig
end

function RivalFloor.placeRig(self: RivalFloor, cframe: CFrame)
	local root = self.root

	if root ~= nil then
		root.CFrame = cframe
	end
end

function RivalFloor._tint(self: RivalFloor, x: number, y: number, color: Color3, holdSeconds: number)
	if not self:isValid(x, y) then
		return
	end

	local index = self:_index(x, y)
	local tile = self.tiles[index]
	local running = self.tweens[index]

	if running ~= nil then
		running:Cancel()
	end

	tile.Color = color
	tile.Material = Enum.Material.Neon
	self.litUntil[index] = os.clock() + holdSeconds

	local tween = TweenService:Create(tile, FLASH_INFO, { Color = self.baseColors[index] })
	self.tweens[index] = tween
	tween:Play()
end

-- The tile the bot is about to hop onto, dimly in its own colour.
function RivalFloor.markTarget(self: RivalFloor, x: number, y: number, color: Color3)
	self:_tint(x, y, color:Lerp(self.baseColors[self:_index(x, y)] or TILE_A, TARGET_DIM), FLASH_SECONDS)
end

function RivalFloor.flash(self: RivalFloor, x: number, y: number, color: Color3)
	self:_tint(x, y, color, FLASH_SECONDS)
end

-- Neon only while a tile is lit, so the idle floor stays matte.
function RivalFloor.tick(self: RivalFloor, now: number)
	local litUntil = self.litUntil

	for index, tile in self.tiles do
		local untilAt = litUntil[index]

		if untilAt > 0 and now >= untilAt then
			litUntil[index] = 0
			tile.Material = Enum.Material.SmoothPlastic
		end
	end
end

function RivalFloor.destroy(self: RivalFloor)
	for _, tween in self.tweens do
		if tween ~= nil then
			tween:Cancel()
		end
	end

	table.clear(self.tweens)
	self.folder:Destroy()
	self.rig = nil
	self.root = nil
end

return RivalFloor
