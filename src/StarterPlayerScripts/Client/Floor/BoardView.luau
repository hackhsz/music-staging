local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local PerformanceBudget = require(Shared:WaitForChild("PerformanceBudget"))
local TileState = require(Shared:WaitForChild("TileState"))
local StageCue = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("StageCue"))
local StreamedModel = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("StreamedModel"))

local BoardView = {}
BoardView.__index = BoardView

-- Dark tiles on a lighter underlay, so the gaps read as a thin grid, and one
-- pink rim. The tiles stay dark so the lit target is what the eye finds.
-- The readable ladder, darkest to brightest: room floor, pad, resting tile,
-- grid seam, next target, current target. Every rung has to be separable or the
-- player cannot count tiles to plan a route.
local PIXEL_COLORS = {
	Grid = Color3.fromRGB(92, 82, 142),
	Rim = Color3.fromRGB(255, 127, 191),
	Tile = Color3.fromRGB(32, 28, 54),
	Home = Color3.fromRGB(150, 74, 124),
}

local APPROACH_MAX_GROWTH = Vector3.new(1.2, 0.3, 1.2)
-- The telegraph still brightens toward the beat, but it starts legible. The
-- player has 1-4 beats to walk there, so the target has to be readable the
-- moment it appears or the route cannot be planned; it used to be the faintest
-- thing on screen exactly when it mattered most. The on-beat moment is carried
-- by the size jump, the white lerp and the flash, not by finally being visible.
local APPROACH_START_TRANSPARENCY = 0.38
local APPROACH_END_TRANSPARENCY = 0.04
local APPROACH_WHITE_LERP = 0.45
local HOLD_MAX_GROWTH = Vector3.new(1.7, 0.55, 1.7)
local SETTLE_RING_THICKNESS = 0.12
local SETTLE_RING_LIFT = 0.5
local SETTLE_OUTLINE_TRANSPARENCY = 0.55
local SETTLE_FILL_TRANSPARENCY = 0.1
-- The approach frame lands exactly on its tile on the beat, so timing is read
-- from where the frame is rather than from a brightness.
local APPROACH_FRAME_THICKNESS = 0.45
local APPROACH_FRAME_HEIGHT = 0.15
local APPROACH_FRAME_LIFT = 0.55
local APPROACH_FRAME_START_SCALE = 2.4
local APPROACH_FRAME_FADE = 0.25
-- Lane layouts get a highway behind the tiles for the frames to travel down.
local HIGHWAY_LENGTH = 30
local FLOOR_TEMPLATE_NAME = "DanceFloor"
-- The highway mode's floor show: notes about to land glow on the tile beside
-- the dancer, presses flash it, Perfects ripple out across the whole floor.
local STAGE_GLOW_MIN = 0.15
local STAGE_GLOW_MAX = 0.8
local STAGE_CENTER_MIX = 0.3
local STAGE_FEVER_MIX = 0.45
local STAGE_FLASH_GROWTH = Vector3.new(1.2, 0.45, 1.2)
local STAGE_RIPPLE_TILES_PER_SECOND = 14
local STAGE_RIPPLE_SECONDS = 0.4
local STAGE_RIPPLE_WIDTH = 0.9
-- The onBeat pad: a still, dark checker under the targets, so the next target
-- is the one bright, changing thing on the floor.
local PAD_IDLE = Color3.fromRGB(14, 12, 16)
local PAD_IDLE_ALT = Color3.fromRGB(24, 21, 28)
-- Only the tile to reach now is lit, in its kind's colour (the run legend's pink
-- step, blue any-tile, purple hold, yellow clap, red danger), with an icon too; the
-- one after it is a faint outline, so a busy stretch never reads as several targets.
local PAD_STEP_COLOR = Color3.fromRGB(255, 70, 170)
local PAD_SHAPE_COLOR = Color3.fromRGB(70, 200, 255)
local PAD_HOLD_COLOR = Color3.fromRGB(175, 110, 255)
local PAD_CLAP_COLOR = Color3.fromRGB(255, 220, 60)
local PAD_NEXT_COLOR = Color3.fromRGB(120, 112, 140)
local PAD_NEXT_OUTLINE_THICKNESS = 0.25
-- One colour for every ability pickup, so none passes for a step or a bonus.
local PAD_PICKUP_COLOR = Color3.fromRGB(80, 235, 130)
local PAD_PICKUP_LABEL_STUDS = Vector2.new(9, 2.2)
local PAD_PICKUP_LABEL_LIFT = 3.5
local PAD_KIND_COLORS: { [string]: Color3 } = {
	single = PAD_STEP_COLOR,
	slide = PAD_STEP_COLOR,
	shape = PAD_SHAPE_COLOR,
	danger = Color3.fromRGB(255, 70, 50),
	item = Color3.fromRGB(255, 200, 87),
	pose = PAD_STEP_COLOR,
	hold = PAD_HOLD_COLOR,
	clap = PAD_CLAP_COLOR,
	rush = PAD_STEP_COLOR,
}
local PAD_DANGER_FILL = Color3.fromRGB(58, 10, 8)
local PAD_DANGER_LEVEL = Color3.fromRGB(190, 34, 24)
-- Fill is the one timing cue: a note's tile fills from its near edge as its beat
-- nears and is full on the beat. The unfilled part shows the colour dimly.
local PAD_FILL_DIM = 0.3
local PAD_HIT_COLOR = Color3.new(1, 1, 1)
local PAD_GOLD = Color3.fromRGB(255, 200, 87)
local PAD_ENERGY_TINTS: { [string]: Color3 } = {
	calm = Color3.fromRGB(150, 130, 220),
	build = Color3.fromRGB(255, 140, 90),
	chorus = Color3.fromRGB(255, 130, 210),
	drop = Color3.new(1, 1, 1),
	fever = PAD_GOLD,
}
local PAD_RIM_TINT_MIX = 0.25
local PAD_PULSE_SHARPNESS = 3
-- A hit is one short flash on its tile, gone the moment the dancer steps off.
local PAD_FLASH_HOLD_SECONDS = 0.1
local PAD_FLASH_FADE_SECONDS = 0.15
local PAD_OWN_FLASH: { [string]: boolean } = { danger = true, hold = true, pose = true, clap = true }
local PAD_RANK_SAME_BEATS = 0.01
-- The target lights up early, but its beats-left number only counts down the last few.
local PAD_COUNT_FROM = 3
local PAD_DIP_STUDS = 0.32
local PAD_DIP_SECONDS = 0.07
-- TextScaled stops at 100 px, so a coarse surface is what lets the number fill most of the tile.
local PAD_COUNT_PIXELS_PER_STUD = 16
local PAD_COUNT_SCALE = 0.9
local PAD_COUNT_STROKE = Color3.fromRGB(40, 10, 30)
local PAD_COUNT_STROKE_THICKNESS = 4
local PAD_COUNT_ROTATION = 90
-- Each note colour is a two-tone pair, the deep end at the bottom of the fill
-- and the bright end at its rising edge, so the edge is the brightest line.
local PAD_KIND_TONES: { [string]: { deep: Color3, bright: Color3 } } = {
	single = { deep = Color3.fromRGB(225, 25, 120), bright = Color3.fromRGB(255, 150, 225) },
	shape = { deep = Color3.fromRGB(10, 110, 200), bright = Color3.fromRGB(140, 235, 255) },
	hold = { deep = Color3.fromRGB(100, 40, 200), bright = Color3.fromRGB(215, 170, 255) },
	clap = { deep = Color3.fromRGB(210, 150, 0), bright = Color3.fromRGB(255, 245, 140) },
	danger = { deep = Color3.fromRGB(120, 6, 6), bright = Color3.fromRGB(255, 95, 40) },
}
local PAD_KIND_ALIASES: { [string]: string } = { slide = "single", pose = "single", rush = "single" }
-- A plain step has no icon; the others carry one so they read without colour.
local PAD_KIND_ICONS: { [string]: string } = {
	shape = "Diamond",
	hold = "Pause",
	pose = "Pause",
	clap = "Clap",
}
-- Icons drawn across the middle of the tile fade back when the number is on it.
local PAD_ICON_UNDER_COUNT: { [string]: boolean } = { Clap = true }
local PAD_ICON_UNDER_COUNT_FADE = 0.55
local PAD_ICON_DARK_MIX = 0.7
local PAD_ICON_OUTLINE_LAYERS = {
	{ pad = 0, thickness = 11, role = "dark", base = 0.3 },
	{ pad = 3, thickness = 5, role = "light", base = 0 },
}
local PAD_WASH_TRANSPARENCY = 0.8
local PAD_FILL_EDGE_PIXELS = 3
local PAD_GLOW_RINGS = {
	{ inset = 0, thickness = 4, transparency = 0 },
	{ inset = 4, thickness = 5, transparency = 0.5 },
	{ inset = 9, thickness = 6, transparency = 0.78 },
}
local PAD_GUI_BRIGHTNESS = 1.4
-- Outlines, arrows and marks are flat bars resting on the tile lights.
local PAD_BAR_HEIGHT = 0.1
local PAD_BAR_LIFT = 0.42
local PAD_OUTLINE_THICKNESS = 0.4
local PAD_ARROW_THICKNESS = 0.45
local PAD_ARROW_START = 0.25
local PAD_ARROW_HEAD_LENGTH = 2.1
local PAD_ARROW_HEAD_ANGLE = math.rad(41)
local PAD_CROSS_THICKNESS = 0.7
local PAD_CROSS_REACH = 0.5
local PAD_ITEM_SIZE = 1.6
local PAD_POSE_FLASH_BEATS = 0.6
local PAD_CLAP_RAYS = 8
local PAD_CLAP_RAY_THICKNESS = 0.85
local PAD_CLAP_CORE_THICKNESS = 0.32
local PAD_CLAP_CORE_WHITE = 0.75
local PAD_CLAP_CORE_LIFT = Vector3.new(0, 0.03, 0)
-- The rays start outside the beats-left digit so they never cover it.
local PAD_CLAP_RAY_INNER = 0.2
local PAD_CLAP_RAY_OUTER = 0.62
local PAD_CLAP_RAY_SHORT = 0.75

-- A hold's tile counts down the beats left while the dancer stands on it, and
-- flashes white when it is held to the end.
local PAD_HOLD_TICK_EPSILON = 1e-3
local PAD_OUTLINE_SIDES = { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) }
-- Floor-wide events repaint the idle pad.
local PAD_EVENT_FADE_SECONDS = 0.3
local PAD_LAVA_DARK = Color3.fromRGB(48, 8, 4)
local PAD_LAVA_HOT = Color3.fromRGB(135, 38, 6)
local PAD_LAVA_BUBBLE_SPEED = 2.6
local PAD_LAVA_BEAT_LIFT = 0.25
local PAD_SAFE_COLOR = Color3.fromRGB(70, 255, 130)
local PAD_SAFE_MIX = 0.6
local PAD_SAFE_PULSE = 0.25
local PAD_DARK = Color3.fromRGB(4, 4, 7)
local PAD_SPOT_COLOR = Color3.fromRGB(255, 214, 150)
local PAD_SPOT_MIX = 0.5
local PAD_SPOT_PULSE = 0.15
local PAD_SPOT_MAX = 6
local PAD_SPOT_HEIGHT = 16
local PAD_SPOT_WIDTH = 0.9
local PAD_SPOT_TRANSPARENCY = 0.86
local PAD_MEMORY_COLOR = Color3.fromRGB(176, 120, 255)
local PAD_MEMORY_FLASH_BEATS = 0.7
local PAD_MEMORY_WHITE = 0.4
local PAD_MEMORY_PULSE = 0.1
local PAD_ICE = Color3.fromRGB(120, 176, 230)
local PAD_ICE_MIX = 0.45
local PAD_FROST_SPEED = 1.7
local PAD_FROST_SHARPNESS = 6
local PAD_FROST_MIX = 0.35
local PAD_CRACK_COLOR = Color3.fromRGB(255, 40, 40)
local PAD_EVENT_RIMS: { [string]: Color3 } = {
	lava = Color3.fromRGB(255, 96, 24),
	spotlight = Color3.fromRGB(120, 96, 64),
	memory = PAD_MEMORY_COLOR,
	freeze = Color3.fromRGB(190, 230, 255),
}

export type PadTelegraph = {
	x: number,
	y: number,
	beatsAway: number,
	lead: number,
	kind: string,
	span: number?,
	path: { any }?,
	hidden: boolean?,
	tiles: { { x: number, y: number } }?,
	holdBeats: number?,
	index: number?,
	poseBeats: number?,
	progress: number?,
	runLeft: number?,
}

type PadBar = { cframe: CFrame, size: Vector3, color: Color3, transparency: number? }
type PadLevel = { amount: number, color: Color3 }
type PadMark = { kind: string }
type PadIconPart = { inst: Instance, role: string, base: number }
type PadDeco = {
	fillGradient: UIGradient,
	wash: Frame,
	washGradient: UIGradient,
	glow: { UIStroke },
	icons: { [string]: Frame },
	iconParts: { [string]: { PadIconPart } },
}

-- Sizes follow the active layout, which can change between songs.
local function lightBaseSize(): Vector3
	return Vector3.new(Board.TileSize - 1.65, 0.35, Board.TileSize - 1.65)
end

local function settleRingDiameter(): number
	return Board.TileSize - 2
end

local function startCoord(): { x: number, y: number }
	return Board.centerCoord()
end

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = false
	part.Parent = parent

	return part
end

local function getStepTileState(step: any): string
	local promptType = step.type or "tap"

	if promptType == "hold" then
		return TileState.States.Hold
	elseif promptType == "bonus" then
		return TileState.States.Bonus
	elseif promptType == "danger" then
		return TileState.States.Danger
	elseif promptType == "slide" then
		return TileState.States.SlideEnd
	end

	return TileState.States.Active
end

local templateModel: Model? = nil

-- The fixed part of a floor: underlay, rims, lane tracks and the tiles. Returns how many
-- parts it made.
local function buildGeometry(parent: Instance, origin: Vector3, highway: number): number
	local count = 0

	local function part(partParent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?)
		count += 1
		return createPart(partParent, name, size, position, color, material)
	end

	local boardWidth = Board.Columns * Board.TileSize
	local boardDepth = Board.Rows * Board.TileSize
	-- The frame around the floor also wraps the highway, which runs away from
	-- the camera behind the tiles.
	local frameDepth = boardDepth + highway
	local frameZ = -highway / 2
	part(
		parent,
		"pixel_floor_underlay",
		Vector3.new(boardWidth + 7, 0.28, frameDepth + 7),
		origin + Vector3.new(0, -0.1, frameZ),
		PIXEL_COLORS.Grid,
		Enum.Material.SmoothPlastic
	)
	part(
		parent,
		"pixel_floor_front_rim",
		Vector3.new(boardWidth + 8, 0.6, 1),
		origin + Vector3.new(0, 0.15, boardDepth / 2 + 3.6),
		PIXEL_COLORS.Rim,
		Enum.Material.Neon
	)
	part(
		parent,
		"pixel_floor_back_rim",
		Vector3.new(boardWidth + 8, 0.6, 1),
		origin + Vector3.new(0, 0.15, -boardDepth / 2 - highway - 3.6),
		PIXEL_COLORS.Rim,
		Enum.Material.Neon
	)
	part(
		parent,
		"pixel_floor_left_rim",
		Vector3.new(1, 0.6, frameDepth + 8),
		origin + Vector3.new(-boardWidth / 2 - 3.6, 0.15, frameZ),
		PIXEL_COLORS.Rim,
		Enum.Material.Neon
	)
	part(
		parent,
		"pixel_floor_right_rim",
		Vector3.new(1, 0.6, frameDepth + 8),
		origin + Vector3.new(boardWidth / 2 + 3.6, 0.15, frameZ),
		PIXEL_COLORS.Rim,
		Enum.Material.Neon
	)

	if highway > 0 then
		for x = 1, Board.Columns do
			local laneStart = Board.coordToWorld(x, 1, origin)

			part(
				parent,
				"pixel_lane_track",
				Vector3.new(Board.TileSize - 0.35, 0.22, highway),
				Vector3.new(laneStart.X, origin.Y, laneStart.Z - Board.TileSize / 2 - highway / 2),
				PIXEL_COLORS.Tile,
				Enum.Material.SmoothPlastic
			)
		end
	end

	local home = Board.homeCoord()

	for x = 1, Board.Columns do
		for y = 1, Board.Rows do
			local center = Board.coordToWorld(x, y, origin)
			local tileFolder = Instance.new("Folder")
			tileFolder.Name = ("Tile_%d_%d"):format(x, y)
			tileFolder.Parent = parent

			part(
				tileFolder,
				"pixel_tile_base",
				Vector3.new(Board.TileSize - 0.35, 0.24, Board.TileSize - 0.35),
				center,
				if home ~= nil and home.x == x and home.y == y then PIXEL_COLORS.Home else PIXEL_COLORS.Tile,
				Enum.Material.SmoothPlastic
			)

			part(
				tileFolder,
				"pixel_tile_light",
				lightBaseSize(),
				center + Vector3.new(0, 0.2, 0),
				TileState.getColor(TileState.States.Inactive),
				Enum.Material.Neon
			)
		end
	end

	return count
end

-- Workspace.DanceFloor is the 5x5 authored in the place (BoardView.authorFloor), so it can
-- be seen and restyled in Studio. Each floor is a copy snapped to its own origin, so moving
-- the model never moves where a step is judged; the original leaves the world once found.
local function floorTemplate(): Model?
	if templateModel == nil then
		local found = StreamedModel.find(FLOOR_TEMPLATE_NAME)

		if found ~= nil and found:IsA("Model") then
			templateModel = found
			found.Parent = nil
		end
	end

	local template = templateModel

	return if template ~= nil and template:GetAttribute("Layout") == Board.getLayoutId() then template else nil
end

local function placeTemplate(template: Model, folder: Instance, origin: Vector3): number
	local copy = template:Clone()
	local count = 0

	copy:PivotTo(CFrame.new(origin))

	for _, child in copy:GetChildren() do
		child.Parent = folder
	end

	copy:Destroy()

	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

-- Edit mode: lays the current layout's floor out at Board.Origin as Workspace.DanceFloor.
function BoardView.authorFloor(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = FLOOR_TEMPLATE_NAME
	buildGeometry(model, Board.Origin, 0)
	model.WorldPivot = CFrame.new(Board.Origin)
	model:SetAttribute("Layout", Board.getLayoutId())
	model.Parent = parent

	return model
end

-- A floor at an origin. The player's own floor and a rival's ghost floor are two
-- of these, told apart by folder name.
function BoardView.new(origin: Vector3?, folderName: string?)
	local self = setmetatable({
		tiles = {},
		currentCoord = startCoord(),
		activeStep = nil,
		upcomingStep = nil,
		origin = origin or Board.Origin,
		folderName = folderName or "DanceDanceStepBoard",
	}, BoardView)

	self:_build()

	return self
end

function BoardView:destroy()
	if self.folder ~= nil then
		self.folder:Destroy()
		self.folder = nil
	end
end

-- Moves the floor, which means building it again at the new origin.
function BoardView:setOrigin(origin: Vector3, force: boolean?)
	if origin == self.origin and not force then
		return
	end

	self.origin = origin
	self:rebuild()
end

-- Builds the floor again in place, for when the layout changes under it.
function BoardView:rebuild()
	self.activeStep = nil
	self.upcomingStep = nil
	self.flashCoord = nil
	self.flashUntil = nil
	self.currentCoord = startCoord()
	self:_build()
end

function BoardView:_highwayLength(): number
	return if Board.Layout.approach == "slide" then HIGHWAY_LENGTH else 0
end

function BoardView:_build()
	local origin = self.origin
	local existing = workspace:FindFirstChild(self.folderName)

	if existing ~= nil then
		existing:Destroy()
	end

	self.tiles = {}
	self.lightHomes = {}
	self.pickupGui = nil
	self.padCounts = {}
	self.padFills = {}
	self.padDecos = {}
	self.padSpots = {}
	self.padSpotCount = 0

	local folder = Instance.new("Folder")
	folder.Name = self.folderName
	folder.Parent = workspace
	self.folder = folder
	self.stageFlashes = {}
	self.stageRipples = {}
	local runtimePartCount = 0

	local function countedPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?)
		runtimePartCount += 1
		return createPart(parent, name, size, position, color, material)
	end

	local highway = self:_highwayLength()
	local template = if highway == 0 then floorTemplate() else nil

	runtimePartCount += if template ~= nil then placeTemplate(template, folder, origin) else buildGeometry(folder, origin, highway)

	-- Rim parts that pulse to the drum beat (dynamic floor without touching tiles).
	self.beatParts = {
		folder:FindFirstChild("pixel_floor_front_rim"),
		folder:FindFirstChild("pixel_floor_back_rim"),
		folder:FindFirstChild("pixel_floor_left_rim"),
		folder:FindFirstChild("pixel_floor_right_rim"),
	}
	self.beatBaseSizes = {}
	for _, part in self.beatParts do
		if part ~= nil then
			self.beatBaseSizes[part] = part.Size
		end
	end

	for x = 1, Board.Columns do
		self.tiles[x] = {}
		self.lightHomes[x] = {}

		for y = 1, Board.Rows do
			local tileFolder = folder:FindFirstChild(("Tile_%d_%d"):format(x, y))
			local light = tileFolder and tileFolder:FindFirstChild("pixel_tile_light") :: BasePart

			self.tiles[x][y] = light
			self.lightHomes[x][y] = light.Position
		end
	end

	-- "Get here in N beats" countdown floating over the target tile. This is the
	-- key stand-and-wait read from the design prototype: the player sees where to
	-- go AND how long until the beat lands, so they pre-position and stand instead
	-- of chasing a lit tile.
	local countdownAnchor = createPart(
		folder,
		"target_countdown_anchor",
		Vector3.new(0.2, 0.2, 0.2),
		origin + Vector3.new(0, 4, 0),
		PIXEL_COLORS.Tile
	)
	countdownAnchor.Transparency = 1
	countdownAnchor.CanCollide = false
	countdownAnchor.CanQuery = false
	countdownAnchor.CanTouch = false

	local countdownGui = Instance.new("BillboardGui")
	countdownGui.Name = "TargetCountdown"
	countdownGui.Adornee = countdownAnchor
	countdownGui.Size = UDim2.fromScale(3.4, 3.4)
	countdownGui.AlwaysOnTop = true
	countdownGui.Enabled = false
	countdownGui.Parent = countdownAnchor

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Count"
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Size = UDim2.fromScale(1, 1)
	countdownLabel.Font = Enum.Font.Arcade
	countdownLabel.TextScaled = true
	countdownLabel.TextColor3 = Color3.fromRGB(255, 244, 232)
	countdownLabel.TextStrokeColor3 = Color3.fromRGB(40, 18, 38)
	countdownLabel.TextStrokeTransparency = 0.15
	countdownLabel.Text = ""
	countdownLabel.Parent = countdownGui

	self.countdownAnchor = countdownAnchor
	self.countdownGui = countdownGui
	self.countdownLabel = countdownLabel

	-- Stand-and-wait made visible: the fill grows while the player stands on the
	-- target and is full when the settle time for a Perfect has been reached.
	local function createSettlePart(name: string)
		local part = countedPart(
			folder,
			name,
			Vector3.new(SETTLE_RING_THICKNESS, settleRingDiameter(), settleRingDiameter()),
			origin,
			Color3.new(1, 1, 1),
			Enum.Material.Neon
		)
		part.Shape = Enum.PartType.Cylinder
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false

		return part
	end

	self.settleOutline = createSettlePart("settle_outline")
	self.settleFill = createSettlePart("settle_fill")

	local approachAnchor = createPart(folder, "approach_anchor", Vector3.new(0.2, 0.2, 0.2), origin, PIXEL_COLORS.Tile)
	approachAnchor.Transparency = 1
	approachAnchor.CanCollide = false
	approachAnchor.CanQuery = false
	approachAnchor.CanTouch = false
	self.approachAnchor = approachAnchor
	self.approachFrames = {}
	self.padBars = {}

	self:_showPlayerCoord(self.currentCoord.x, self.currentCoord.y)

	if self.padLook then
		self:_applyPadLook()
	end

	if runtimePartCount > PerformanceBudget.Targets.maxDanceFloorParts then
		warn(("[DanceDanceStep] Dance floor part count %d exceeds budget %d"):format(runtimePartCount, PerformanceBudget.Targets.maxDanceFloorParts))
	end
end

function BoardView:setTileState(x: number, y: number, state: string)
	local column = self.tiles[x]
	local tile = column and column[y]

	if tile == nil then
		return
	end

	tile.Color = TileState.getColor(state)
end

function BoardView:resetTiles()
	self.padPainted = {}

	local flashCoord = self.flashCoord
	local flashActive = flashCoord ~= nil and self.flashUntil ~= nil and os.clock() < self.flashUntil

	for x = 1, Board.Columns do
		for y = 1, Board.Rows do
			local tile = self.tiles[x][y]

			-- Keep the grade flash visible even when the next step is
			-- telegraphed immediately after the previous one resolves.
			if not (flashActive and flashCoord.x == x and flashCoord.y == y) then
				tile.Color = TileState.getColor(TileState.States.Inactive)
			end

			tile.Size = lightBaseSize()
			tile.Transparency = 0
		end
	end
end

function BoardView:applyUpcomingTint()
	local step = self.upcomingStep

	if step == nil then
		return
	end

	local active = self.activeStep

	if active ~= nil and active.x == step.x and active.y == step.y then
		return
	end

	if self.currentCoord ~= nil and self.currentCoord.x == step.x and self.currentCoord.y == step.y then
		return
	end

	self:setTileState(step.x, step.y, TileState.States.Upcoming)
end

function BoardView:setUpcomingStep(step: any?)
	self.upcomingStep = step
	self:applyUpcomingTint()
end

-- Show the beats-until-the-beat countdown over the target tile (stand-and-wait
-- read). beatsLeft <= 0 (or no step) hides it -- the on-beat flash is the light
-- "turning on".
function BoardView:setTargetCountdown(step: any?, beatsLeft: number?)
	local gui = self.countdownGui

	if gui == nil then
		return
	end

	if step == nil or beatsLeft == nil or beatsLeft <= 0 then
		gui.Enabled = false
		return
	end

	local center = Board.coordToWorld(step.x, step.y, self.origin)
	self.countdownAnchor.Position = center + Vector3.new(0, 4, 0)
	self.countdownLabel.Text = tostring(math.ceil(beatsLeft))
	gui.Enabled = true
end

function BoardView:hideCountdown()
	if self.countdownGui ~= nil then
		self.countdownGui.Enabled = false
	end

	self:setSettleProgress(nil)
end

-- progress is settled time over the settle time a Perfect needs; nil hides the ring.
function BoardView:setSettleProgress(progress: number?)
	local step = self.activeStep

	if progress == nil or step == nil then
		self.settleOutline.Transparency = 1
		self.settleFill.Transparency = 1
		return
	end

	local clamped = math.clamp(progress, 0, 1)
	local center = Board.coordToWorld(step.x, step.y, self.origin) + Vector3.new(0, SETTLE_RING_LIFT, 0)
	local flat = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	local diameter = math.max(settleRingDiameter() * clamped, 0.05)

	self.settleOutline.CFrame = flat
	self.settleOutline.Transparency = SETTLE_OUTLINE_TRANSPARENCY
	self.settleFill.Size = Vector3.new(SETTLE_RING_THICKNESS, diameter, diameter)
	self.settleFill.CFrame = flat + Vector3.new(0, SETTLE_RING_THICKNESS / 2, 0)
	self.settleFill.Color = Color3.new(1, 1, 1):Lerp(TileState.getColor(TileState.States.Perfect), clamped)
	self.settleFill.Transparency = SETTLE_FILL_TRANSPARENCY
end

local function createFrameBar(parent: Instance, anchor: BasePart): BoxHandleAdornment
	local bar = Instance.new("BoxHandleAdornment")
	-- Drawn over the avatar, or a frame landing on the player's own tile would
	-- vanish behind them at the one moment it matters.
	bar.AlwaysOnTop = true
	bar.ZIndex = 1
	bar.Adornee = anchor
	bar.Visible = false
	bar.Parent = parent

	return bar
end

function BoardView:_approachFrame(index: number): { BoxHandleAdornment }
	local frame = self.approachFrames[index]

	if frame == nil then
		frame = {}

		for side = 1, 4 do
			frame[side] = createFrameBar(self.folder, self.approachAnchor)
		end

		self.approachFrames[index] = frame
	end

	return frame
end

-- markers: one per upcoming step, each { x, y, progress, kind }, where progress
-- runs from 0 when the step is first shown to 1 on its beat.
function BoardView:setApproachMarkers(markers: { any })
	if self.approachAnchor == nil then
		return
	end

	local slide = Board.Layout.approach == "slide"
	local inner = Board.TileSize - 0.6
	local anchorPosition = self.approachAnchor.Position

	for index, marker in markers do
		local progress = math.clamp(marker.progress, 0, 1)
		local center = Board.coordToWorld(marker.x, marker.y, self.origin) + Vector3.new(0, APPROACH_FRAME_LIFT, 0)
		local sideX = inner + ((marker.width or 1) - 1) * Board.TileSize
		local sideZ = inner + ((marker.depth or 1) - 1) * Board.TileSize

		if slide then
			center -= Vector3.new(0, 0, HIGHWAY_LENGTH * (1 - progress))
		else
			local grow = inner * ((marker.startScale or APPROACH_FRAME_START_SCALE) - 1) * (1 - progress)
			sideX += grow
			sideZ += grow
		end

		local thickness = marker.thickness or APPROACH_FRAME_THICKNESS
		local offset = center - anchorPosition
		local halfX = (sideX - thickness) / 2
		local halfZ = (sideZ - thickness) / 2
		local color = marker.color or TileState.getColor(getStepTileState({ type = marker.kind }))
		local transparency = marker.transparency or math.clamp(1 - progress / APPROACH_FRAME_FADE, 0, 0.85)
		local bars = self:_approachFrame(index)
		local layout = {
			{ Vector3.new(sideX, APPROACH_FRAME_HEIGHT, thickness), Vector3.new(0, 0, -halfZ) },
			{ Vector3.new(sideX, APPROACH_FRAME_HEIGHT, thickness), Vector3.new(0, 0, halfZ) },
			{ Vector3.new(thickness, APPROACH_FRAME_HEIGHT, sideZ), Vector3.new(-halfX, 0, 0) },
			{ Vector3.new(thickness, APPROACH_FRAME_HEIGHT, sideZ), Vector3.new(halfX, 0, 0) },
		}

		for barIndex, bar in bars do
			bar.Size = layout[barIndex][1]
			bar.CFrame = CFrame.new(offset + layout[barIndex][2])
			bar.Color3 = color
			bar.Transparency = transparency
			bar.Visible = true
		end
	end

	for index = #markers + 1, #self.approachFrames do
		for _, bar in self.approachFrames[index] do
			bar.Visible = false
		end
	end
end

function BoardView:stageFlash(x: number, y: number, color: Color3, seconds: number)
	if not Board.isValidCoord(x, y) then
		return
	end

	table.insert(self.stageFlashes, { x = x, y = y, color = color, startedAt = os.clock(), seconds = seconds })
end

function BoardView:stageRipple(color: Color3)
	table.insert(self.stageRipples, { color = color, startedAt = os.clock() })
end

function BoardView:clearStage()
	table.clear(self.stageFlashes)
	table.clear(self.stageRipples)
	self:resetTiles()
end

-- Paints the whole floor for one frame of the highway mode. glows are
-- { x, y, color, strength } with strength 0 to 1; palette, when given, is what
-- the floor cycles through on the beat during Fever.
function BoardView:renderStage(now: number, glows: { any }, beat: number, palette: { Color3 }?)
	local center = startCoord()
	local base = TileState.getColor(TileState.States.Inactive)
	local centerColor = base:Lerp(TileState.getColor(TileState.States.Preview), STAGE_CENTER_MIX)
	local colors: { { Color3 } } = {}
	local growth: { { number } } = {}

	for x = 1, Board.Columns do
		colors[x] = {}
		growth[x] = {}

		for y = 1, Board.Rows do
			local color = if x == center.x and y == center.y then centerColor else base

			if palette ~= nil and #palette > 0 then
				color = color:Lerp(palette[(x + y + math.floor(beat)) % #palette + 1], STAGE_FEVER_MIX)
			end

			colors[x][y] = color
			growth[x][y] = 0
		end
	end

	for _, glow in glows do
		if Board.isValidCoord(glow.x, glow.y) then
			local mix = STAGE_GLOW_MIN + (STAGE_GLOW_MAX - STAGE_GLOW_MIN) * math.clamp(glow.strength, 0, 1)
			colors[glow.x][glow.y] = colors[glow.x][glow.y]:Lerp(glow.color, mix)
		end
	end

	for index = #self.stageRipples, 1, -1 do
		local ripple = self.stageRipples[index]
		local age = now - ripple.startedAt

		if age >= STAGE_RIPPLE_SECONDS then
			table.remove(self.stageRipples, index)
			continue
		end

		local radius = age * STAGE_RIPPLE_TILES_PER_SECOND
		local fade = 1 - age / STAGE_RIPPLE_SECONDS

		for x = 1, Board.Columns do
			for y = 1, Board.Rows do
				local distance = math.sqrt((x - center.x) ^ 2 + (y - center.y) ^ 2)
				local band = 1 - math.abs(distance - radius) / STAGE_RIPPLE_WIDTH

				if band > 0 then
					colors[x][y] = colors[x][y]:Lerp(ripple.color, band * fade)
				end
			end
		end
	end

	for index = #self.stageFlashes, 1, -1 do
		local flash = self.stageFlashes[index]
		local age = (now - flash.startedAt) / flash.seconds

		if age >= 1 then
			table.remove(self.stageFlashes, index)
			continue
		end

		local strength = 1 - age
		colors[flash.x][flash.y] = colors[flash.x][flash.y]:Lerp(flash.color, strength)
		growth[flash.x][flash.y] = math.max(growth[flash.x][flash.y], strength)
	end

	for x = 1, Board.Columns do
		for y = 1, Board.Rows do
			local tile = self.tiles[x][y]
			tile.Color = colors[x][y]
			tile.Size = lightBaseSize() + STAGE_FLASH_GROWTH * growth[x][y]
			tile.Transparency = 0
		end
	end
end

function BoardView:setActiveStep(step: any?)
	self.activeStep = step
	self:resetTiles()

	if step ~= nil then
		local promptType = step.type or "tap"

		if promptType == "slide" and type(step.path) == "table" then
			for _, coord in step.path do
				if coord.x ~= step.x or coord.y ~= step.y then
					self:setTileState(coord.x, coord.y, TileState.States.SlidePath)
				end
			end

			self:setTileState(step.x, step.y, TileState.States.SlideEnd)
		else
			self:setTileState(step.x, step.y, getStepTileState(step))
		end
	end

	self:_showPlayerCoord(self.currentCoord.x, self.currentCoord.y)
end

function BoardView:getActiveTile()
	local step = self.activeStep

	if step == nil then
		return nil
	end

	local column = self.tiles[step.x]

	return column and column[step.y]
end

function BoardView:setApproach(progress: number)
	local step = self.activeStep
	local tile = self:getActiveTile()

	if step == nil or tile == nil then
		return
	end

	local clamped = math.clamp(progress, 0, 1)
	local baseColor = TileState.getColor(getStepTileState(step))

	tile.Color = baseColor:Lerp(Color3.new(1, 1, 1), APPROACH_WHITE_LERP * clamped)
	tile.Size = lightBaseSize() + APPROACH_MAX_GROWTH * clamped
	tile.Transparency = APPROACH_START_TRANSPARENCY
		+ (APPROACH_END_TRANSPARENCY - APPROACH_START_TRANSPARENCY) * clamped
end

function BoardView:setHoldProgress(progress: number)
	local step = self.activeStep
	local tile = self:getActiveTile()

	if step == nil or tile == nil then
		return
	end

	local clamped = math.clamp(progress, 0, 1)
	local baseColor = TileState.getColor(TileState.States.Hold)

	tile.Color = baseColor:Lerp(TileState.getColor(TileState.States.Perfect), clamped)
	tile.Size = lightBaseSize() + HOLD_MAX_GROWTH * clamped
	tile.Transparency = 0
end

-- Quick "landing" pop on the tile the player steps onto: a snappy scale-up then
-- settle, so every move reads as a hop with a flash (dynamic feel).
function BoardView:stepPop(x: number, y: number)
	local column = self.tiles[x]
	local tile = column and column[y]

	if tile == nil then
		return
	end

	tile.Size = lightBaseSize()
	tile.Transparency = 0

	local up = TweenService:Create(tile, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = lightBaseSize() + Vector3.new(1.2, 0.5, 1.2),
	})

	up.Completed:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Size = lightBaseSize(),
		}):Play()
	end)

	up:Play()
end

-- Drum-beat pulse: the floor rim briefly swells on each beat so the stage feels
-- alive without lighting idle tiles (readability stays intact).
function BoardView:pulseBeat()
	if self.padLook then
		return
	end

	for _, part in self.beatParts or {} do
		if part ~= nil then
			local base = self.beatBaseSizes[part] or part.Size
			part.Size = base
			local up = TweenService:Create(part, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = base + Vector3.new(0, base.Y * 0.45, 0),
			})
			up.Completed:Connect(function()
				TweenService:Create(part, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Size = base }):Play()
			end)
			up:Play()
		end
	end
end

-- callback hears every step the player commits to, the instant it starts.
-- Main hands step starts to the floor, so this is where a run can hear them.
function BoardView:setOnPlayerStep(callback: ((coord: { x: number, y: number }) -> ())?)
	self.onPlayerStep = callback
end

function BoardView:setPlayerCoord(x: number, y: number)
	if not Board.isValidCoord(x, y) then
		return
	end

	self:_showPlayerCoord(x, y)

	if self.onPlayerStep ~= nil then
		self.onPlayerStep({ x = x, y = y })
	end
end

function BoardView:_showPlayerCoord(x: number, y: number)
	if not Board.isValidCoord(x, y) then
		return
	end

	if self.padLook then
		self.currentCoord = { x = x, y = y }
		return
	end

	local previous = self.currentCoord
	local moved = previous == nil or previous.x ~= x or previous.y ~= y

	if previous ~= nil then
		self:setTileState(previous.x, previous.y, TileState.States.Inactive)
	end

	self.currentCoord = { x = x, y = y }
	self:setTileState(x, y, TileState.States.Preview)

	if self.activeStep ~= nil then
		self:setTileState(self.activeStep.x, self.activeStep.y, getStepTileState(self.activeStep))
		self:setTileState(x, y, TileState.States.Preview)
	end

	self:applyUpcomingTint()

	if moved then
		self:stepPop(x, y)
	end
end

function BoardView:flashResult(step: any, grade: string, feverActive: boolean?)
	if step == nil then
		return
	end

	-- The beat has landed: hide the countdown; this flash is the light "turning on".
	self:hideCountdown()

	self.flashCoord = { x = step.x, y = step.y }
	self.flashUntil = os.clock() + 0.14
	self:setTileState(step.x, step.y, feverActive and TileState.States.Fever or grade)

	-- Impact bounce on the judged tile.
	local column = self.tiles[step.x]
	local tile = column and column[step.y]
	if tile ~= nil then
		tile.Size = lightBaseSize()
		local pop = TweenService:Create(tile, TweenInfo.new(0.07, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = lightBaseSize() + Vector3.new(1.2, 0.45, 1.2),
		})
		pop.Completed:Connect(function()
			TweenService:Create(tile, TweenInfo.new(0.1), { Size = lightBaseSize() }):Play()
		end)
		pop:Play()
	end

	task.delay(0.14, function()
		self.flashCoord = nil
		self.flashUntil = nil

		-- Repaint the current telegraph (active, slide path, upcoming and
		-- player tiles) instead of blanking the flashed tile directly. The
		-- caller clears activeStep before flashing when the resolved step was
		-- the one on display, so a stale prompt never repaints here.
		self:setActiveStep(self.activeStep)
	end)
end

local function padIdleColor(x: number, y: number): Color3
	return if (x + y) % 2 == 0 then PAD_IDLE else PAD_IDLE_ALT
end

local function stepTiles(step: any): { { x: number, y: number } }
	local tiles = { { x = step.x, y = step.y } }

	if type(step.path) == "table" then
		for _, coord in step.path do
			if type(coord) == "table" and (coord.x ~= step.x or coord.y ~= step.y) then
				table.insert(tiles, { x = coord.x, y = coord.y })
			end
		end
	end

	return tiles
end

local function padTiles(telegraph: PadTelegraph): { { x: number, y: number } }
	return telegraph.tiles or { { x = telegraph.x, y = telegraph.y } }
end

local function padCount(beatsAway: number): number?
	local count = math.ceil(beatsAway)
	return if count <= PAD_COUNT_FROM then count else nil
end

local function padLevel(telegraph: PadTelegraph): number
	return 1 - math.clamp(telegraph.beatsAway / math.max(telegraph.span or telegraph.lead, 1e-3), 0, 1)
end

-- 1 is the next beat to stand on and 2 the beat after it; notes on one beat
-- share a rank. Dangers, pickups, hidden steps and landed notes take none.
local function padRanks(telegraphs: { PadTelegraph }): { [number]: number }
	local ranks = {}
	local rank = 0
	local rankBeats: number? = nil

	for index, telegraph in telegraphs do
		local landed = telegraph.beatsAway <= 0 and telegraph.runLeft == nil

		if telegraph.kind == "danger" or telegraph.kind == "item" or telegraph.hidden or landed then
			continue
		end

		if rankBeats == nil or telegraph.beatsAway - rankBeats > PAD_RANK_SAME_BEATS then
			if rank == 2 then
				break
			end

			rank += 1
			rankBeats = telegraph.beatsAway
		end

		ranks[index] = rank
	end

	return ranks
end

-- Position is not judged on a clap, so the mark follows wherever the dancer is.
local function clapSpot(telegraph: PadTelegraph, dancer: { x: number, y: number }?): { x: number, y: number }
	if dancer ~= nil and Board.isValidCoord(dancer.x, dancer.y) then
		return { x = dancer.x, y = dancer.y }
	end

	return { x = telegraph.x, y = telegraph.y }
end

local function nearestTile(tiles: { { x: number, y: number } }, from: { x: number, y: number }): { x: number, y: number }
	local best, bestDistance = tiles[1], math.huge

	for _, tile in tiles do
		local distance = math.abs(tile.x - from.x) + math.abs(tile.y - from.y)

		if distance < bestDistance then
			best, bestDistance = tile, distance
		end
	end

	return best
end

local function standsOn(tiles: { { x: number, y: number } }, coord: { x: number, y: number }?): boolean

	if coord == nil then
		return false
	end

	for _, tile in tiles do
		if tile.x == coord.x and tile.y == coord.y then
			return true
		end
	end

	return false
end

local function flatRotate(vector: Vector3, angle: number): Vector3
	local cos, sin = math.cos(angle), math.sin(angle)

	return Vector3.new(vector.X * cos - vector.Z * sin, 0, vector.X * sin + vector.Z * cos)
end

-- Neighbours off the board are looked up too, so the key cannot wrap rows.
local function groupKey(x: number, y: number): number
	return x * 64 + y
end

local function addBar(bars: { PadBar }, from: Vector3, to: Vector3, thickness: number, color: Color3)
	local length = (to - from).Magnitude

	if length < 1e-3 then
		return
	end

	table.insert(bars, {
		cframe = CFrame.lookAt((from + to) / 2, to),
		size = Vector3.new(thickness, PAD_BAR_HEIGHT, length),
		color = color,
	})
end

local function padTones(kind: string?): { deep: Color3, bright: Color3 }?
	if kind == nil then
		return nil
	end

	return PAD_KIND_TONES[PAD_KIND_ALIASES[kind] or kind]
end

local function padFrame(parent: Instance, name: string, zIndex: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = zIndex
	frame.Parent = parent

	return frame
end

local function padStroke(parent: Instance, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness
	stroke.Parent = parent

	return stroke
end

local function padCorner(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

-- A solid light bar with a dark edge, readable on the dim tile and on a full fill.
local function iconBar(
	parts: { PadIconPart },
	parent: Instance,
	position: UDim2,
	size: UDim2,
	rotation: number,
	radius: UDim?
)
	local bar = padFrame(parent, "Bar", 1)
	bar.Position = position
	bar.Size = size
	bar.Rotation = rotation

	if radius ~= nil then
		padCorner(bar, radius)
	end

	table.insert(parts, { inst = bar, role = "light", base = 0.05 })
	table.insert(parts, { inst = padStroke(bar, 3), role = "dark", base = 0.15 })
end

-- An outline shape: a thin light line on a wider dark one.
local function iconOutline(parts: { PadIconPart }, parent: Instance, scale: number, rotation: number, radius: UDim)
	for _, layer in PAD_ICON_OUTLINE_LAYERS do
		local frame = padFrame(parent, "Outline", 1)
		frame.Size = UDim2.new(scale, layer.pad * 2, scale, layer.pad * 2)
		frame.Rotation = rotation
		padCorner(frame, radius)
		table.insert(parts, { inst = padStroke(frame, layer.thickness), role = layer.role, base = layer.base })
	end
end

local function buildPadIcons(area: Frame): ({ [string]: Frame }, { [string]: { PadIconPart } })
	local icons: { [string]: Frame } = {}
	local iconParts: { [string]: { PadIconPart } } = {}

	local function icon(name: string): ({ PadIconPart }, Frame)
		local frame = padFrame(area, name, 5)
		frame.Visible = false
		icons[name] = frame
		iconParts[name] = {}

		return iconParts[name], frame
	end

	local diamondParts, diamond = icon("Diamond")
	iconOutline(diamondParts, diamond, 0.6, 45, UDim.new(0, 3))

	local pauseParts, pause = icon("Pause")

	for _, side in { 0.14, 0.86 } do
		iconBar(pauseParts, pause, UDim2.fromScale(side, 0.5), UDim2.fromScale(0.13, 0.62), 0, UDim.new(0, 3))
	end

	local clapParts, clap = icon("Clap")

	for _, side in { -1, 1 } do
		local palm = UDim2.fromScale(0.5 + side * 0.13, 0.56)
		iconBar(clapParts, clap, palm, UDim2.fromScale(0.17, 0.5), side * 16, UDim.new(0.5, 0))
	end

	for _, spark in { { 0.5, 0.14, 0 }, { 0.3, 0.2, -35 }, { 0.7, 0.2, 35 } } do
		local position = UDim2.fromScale(spark[1], spark[2])
		iconBar(clapParts, clap, position, UDim2.fromScale(0.05, 0.12), spark[3], UDim.new(0.5, 0))
	end

	return icons, iconParts
end

local function buildPadDeco(area: Frame, fill: Frame): PadDeco
	local wash = padFrame(area, "Wash", 1)
	wash.BackgroundColor3 = PAD_HIT_COLOR
	wash.BackgroundTransparency = PAD_WASH_TRANSPARENCY
	wash.Visible = false
	local washGradient = Instance.new("UIGradient")
	washGradient.Rotation = 45
	washGradient.Parent = wash

	fill.ZIndex = 2
	fill.BackgroundColor3 = PAD_HIT_COLOR
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BorderSizePixel = 0
	edge.BackgroundColor3 = PAD_HIT_COLOR
	edge.Size = UDim2.new(1, 0, 0, PAD_FILL_EDGE_PIXELS)
	edge.ZIndex = 3
	edge.Parent = fill

	local glow = {}

	for _, ring in PAD_GLOW_RINGS do
		local frame = padFrame(area, "Glow", 4)
		local edgeInset = (ring.inset + ring.thickness) * 2
		frame.Size = UDim2.new(1, -edgeInset, 1, -edgeInset)
		frame.Visible = false
		local stroke = padStroke(frame, ring.thickness)
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Transparency = ring.transparency
		table.insert(glow, stroke)
	end

	local icons, iconParts = buildPadIcons(area)

	return {
		fillGradient = fillGradient,
		wash = wash,
		washGradient = washGradient,
		glow = glow,
		icons = icons,
		iconParts = iconParts,
	}
end

local function paintIcon(parts: { PadIconPart }, tones: { deep: Color3, bright: Color3 }, fade: number)
	local light = tones.bright:Lerp(PAD_HIT_COLOR, 0.75)
	local dark = tones.deep:Lerp(Color3.new(), PAD_ICON_DARK_MIX)

	for _, part in parts do
		local transparency = part.base + (1 - part.base) * fade
		local color = if part.role == "light" then light else dark
		local inst = part.inst

		if inst:IsA("UIStroke") then
			inst.Color = color
			inst.Transparency = transparency
		elseif inst:IsA("Frame") then
			inst.BackgroundColor3 = color
			inst.BackgroundTransparency = transparency
		end
	end
end

-- A tile's look for one note kind: the two-tone wash, the neon rim and its icon.
local function applyPadDeco(deco: PadDeco, mark: PadMark?, counted: boolean)
	local tones = if mark ~= nil then padTones(mark.kind) else nil
	local iconName = if mark ~= nil and tones ~= nil then PAD_KIND_ICONS[mark.kind] else nil

	deco.wash.Visible = tones ~= nil

	for index, stroke in deco.glow do
		(stroke.Parent :: Frame).Visible = tones ~= nil

		if tones ~= nil then
			stroke.Color = tones.bright:Lerp(tones.deep, (index - 1) / math.max(#deco.glow - 1, 1))
		end
	end

	if tones ~= nil then
		deco.washGradient.Color = ColorSequence.new(tones.deep, tones.bright)
	end

	for name, icon in deco.icons do
		icon.Visible = name == iconName
	end

	if iconName == nil or tones == nil then
		return
	end

	local fade = if counted and PAD_ICON_UNDER_COUNT[iconName] then PAD_ICON_UNDER_COUNT_FADE else 0
	paintIcon(deco.iconParts[iconName], tones, fade)
end

local function fillSequence(color: Color3, kind: string?): ColorSequence
	local tones = padTones(kind)

	if tones == nil then
		return ColorSequence.new(color)
	end

	if color == PAD_HIT_COLOR then
		return ColorSequence.new(PAD_HIT_COLOR, tones.bright:Lerp(PAD_HIT_COLOR, 0.35))
	end

	return ColorSequence.new(tones.bright, tones.deep)
end

function BoardView:_padCount(x: number, y: number): TextLabel?
	local column = self.padCounts[x]
	local existing = column and column[y]

	if existing ~= nil then
		return existing
	end

	local tile = self.tiles[x] and self.tiles[x][y]

	if tile == nil then
		return nil
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PadCountdown"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PAD_COUNT_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = PAD_GUI_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Adornee = tile
	gui.Parent = tile

	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(PAD_COUNT_SCALE, PAD_COUNT_SCALE)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = PAD_HIT_COLOR
	label.Text = ""
	-- A tile's top face runs its text along the floor's X axis, which is
	-- sideways to the pad camera looking down -Z; turning it reads upright.
	label.Rotation = PAD_COUNT_ROTATION
	label.ZIndex = 2
	label.Parent = gui

	local area = Instance.new("Frame")
	area.Name = "FillArea"
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromScale(1, 1)
	area.Rotation = PAD_COUNT_ROTATION
	area.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.Visible = false
	fill.Parent = area

	local stroke = Instance.new("UIStroke")
	stroke.Color = PAD_COUNT_STROKE
	stroke.Thickness = PAD_COUNT_STROKE_THICKNESS
	stroke.Parent = label

	self.padCounts[x] = column or {}
	self.padCounts[x][y] = label
	self.padFills[x] = self.padFills[x] or {}
	self.padFills[x][y] = fill
	self.padDecos[x] = self.padDecos[x] or {}
	self.padDecos[x][y] = buildPadDeco(area, fill)

	return label
end

-- The onBeat pad look: the dark checker, numbers on the tiles, and no
-- approach frames, settle ring or floating countdown. Off restores the rest.
-- An arrow on the floor from the dancer to the next target, for the easier charts.
function BoardView:setPathArrows(active: boolean)
	self.padPathArrows = active
end

function BoardView:setPadLook(active: boolean)
	self.padLook = active
	self.padFlashes = {}
	self.padEnergy = "calm"
	self.padBeatAt = nil
	self.padBeatSeconds = nil
	self.padEvent = nil
	self.padEventOut = nil
	self.padHold = nil
	self:_paintSpots(nil, 0)
	self:_applyPadLook()

	if not active and self.padCuedArena then
		self.padCuedArena = false
		StageCue.fire("energy", "none")
	end
end

function BoardView:padBeat(_beatIndex: number, beatSeconds: number)
	self.padBeatSeconds = beatSeconds
	self.padBeatAt = os.clock()
end

function BoardView:setPadEnergy(energy: string)
	if PAD_ENERGY_TINTS[energy] == nil or energy == self.padEnergy then
		return
	end

	self.padEnergy = energy
	self.padCuedArena = true
	StageCue.fire("energy", energy)
end

function BoardView:padMilestone(combo: number)
	StageCue.fire("milestone", combo)
end

function BoardView:padCollect(coord: { x: number, y: number })
	if self.padLook and type(coord) == "table" and Board.isValidCoord(coord.x, coord.y) then
		self:_padTileFlash(coord.x, coord.y, PAD_GOLD)
	end
end

function BoardView:_padTileFlash(x: number, y: number, color: Color3)
	self:_clearPadFlashes(x, y)
	table.insert(self.padFlashes, {
		x = x,
		y = y,
		color = color,
		startedAt = os.clock(),
	})
end

function BoardView:padRunTileHit(_coord: { x: number, y: number }, index: number, count: number)
	local progress = if type(index) == "number" and type(count) == "number" and count > 1
		then math.clamp((index - 1) / (count - 1), 0, 1)
		else 1

	StageCue.fire("run", progress)
end

function BoardView:padRunDone(_coord: { x: number, y: number }, perfect: boolean)
	StageCue.fire(if perfect then "runDone" else "runFail", nil)
end

function BoardView:padHoldStart(seconds: number)
	StageCue.fire("holdStart", seconds)
end

function BoardView:padHoldDrop()
	StageCue.fire("holdDrop", nil)
end

function BoardView:padHoldDone(_coord: { x: number, y: number })
	StageCue.fire("holdDone", nil)
end

function BoardView:padClapHit(coord: { x: number, y: number }, grade: string)
	StageCue.fire("clap", grade)

	if self.padLook and type(coord) == "table" and Board.isValidCoord(coord.x, coord.y) then
		self:_padTileFlash(coord.x, coord.y, PAD_HIT_COLOR)
	end
end

function BoardView:_padBeatSeconds(): number
	return self.padBeatSeconds or 0.5
end

function BoardView:_applyPadLook()
	local active = self.padLook == true
	self.padPainted = {}
	self:_setRimColor(PIXEL_COLORS.Rim)
	self:setApproachMarkers({})
	self:_paintPadBars({})

	if active then
		self:hideCountdown()
		self.activeStep = nil
		self.upcomingStep = nil
	end

	for x = 1, Board.Columns do
		for y = 1, Board.Rows do
			local tile = self.tiles[x][y]
			local count = if active then self:_padCount(x, y) else self.padCounts[x] and self.padCounts[x][y]

			if count ~= nil then
				count.Text = ""
			end

			local deco = self.padDecos[x] and self.padDecos[x][y]

			if deco ~= nil and not active then
				applyPadDeco(deco, nil, false)
				self.padFills[x][y].Visible = false
			end

			tile.Size = lightBaseSize()
			tile.Position = self.lightHomes[x][y]
			tile.Transparency = 0
			tile.Material = if active then Enum.Material.SmoothPlastic else Enum.Material.Neon
			tile.Color = if active then padIdleColor(x, y) else TileState.getColor(TileState.States.Inactive)
		end
	end

	if not active then
		self:_showPlayerCoord(self.currentCoord.x, self.currentCoord.y)
	end
end

-- The tile under the player sinks for a moment when a step lands on it.
function BoardView:dipTile(coord: { x: number, y: number })
	if not Board.isValidCoord(coord.x, coord.y) then
		return
	end

	if self.padLook then
		if self.padEvent ~= nil and self.padEvent.kind == "freeze" then
			self:_padTileFlash(coord.x, coord.y, PAD_CRACK_COLOR)
		end

		return
	end

	local tile = self.tiles[coord.x][coord.y]
	local home = self.lightHomes[coord.x][coord.y]
	tile.Position = home - Vector3.new(0, PAD_DIP_STUDS, 0)

	task.delay(PAD_DIP_SECONDS, function()
		if tile.Parent ~= nil then
			tile.Position = home
		end
	end)
end

-- A hit flashes its tile white; a hold, pose or clap flashes its own, and a miss
-- or a dodged danger shows nothing on the pad.
function BoardView:padVerdict(step: any, grade: string)
	if not self.padLook or type(step) ~= "table" or grade == "Miss" or PAD_OWN_FLASH[step.type] then
		return
	end

	for _, coord in if type(step.zone) == "table" then step.zone else stepTiles(step) do
		if Board.isValidCoord(coord.x, coord.y) then
			self:_padTileFlash(coord.x, coord.y, PAD_HIT_COLOR)
		end
	end
end

function BoardView:_clearPadFlashes(x: number, y: number)
	for index = #self.padFlashes, 1, -1 do
		local flash = self.padFlashes[index]

		if flash.x == x and flash.y == y then
			table.remove(self.padFlashes, index)
		end
	end
end

-- A hold on its beat: solid pink with the beats left on it. Only one hold runs
-- at a time. Returns whether the dancer is standing on it.
function BoardView:_paintHold(
	telegraph: PadTelegraph,
	dancer: { x: number, y: number }?,
	rise: (number, number, Color3, number, Color3?) -> (),
	counts: { { number? } },
	mark: (number, number, string) -> ()
): boolean
	local holdBeats = math.max(telegraph.holdBeats or 0, 1e-3)
	local remaining = holdBeats + telegraph.beatsAway
	local x, y = telegraph.x, telegraph.y
	local state = self.padHold

	if state == nil or state.index ~= telegraph.index then
		state = { index = telegraph.index, landed = false, done = false }
		self.padHold = state
	end

	if state.done then
		return false
	end

	local onTile = dancer ~= nil and dancer.x == x and dancer.y == y

	if remaining <= 0 or (state.landed and not onTile) then
		state.done = true

		if state.landed and remaining <= 0 then
			self:_padTileFlash(x, y, PAD_HIT_COLOR)
		end

		return false
	end

	state.landed = state.landed or onTile
	-- Full on its beat, it drains as it is held and is empty when it is done.
	rise(x, y, PAD_KIND_COLORS.hold, math.clamp(remaining / holdBeats, 0, 1), PAD_KIND_COLORS.hold)
	mark(x, y, "hold")
	counts[x][y] = math.ceil(remaining - PAD_HOLD_TICK_EPSILON)

	return onTile
end

-- A floor-wide event takes over the idle pad until it is called with nil.
-- lava: info.safe glows green on bubbling lava. spotlight: only info.lit shows,
-- under a warm light. memory: info.phase "watch" flashes info.sequence one tile
-- per info.beatSeconds from this call; "play" dims the pad and hidden targets
-- draw nothing. freeze: ice, and every landing cracks its tile red. Calling
-- again with the same kind updates the tiles without restarting the fade.
function BoardView:setPadEvent(kind: string?, info: { [string]: any }?)
	local now = os.clock()
	local current = self.padEvent

	if kind == nil then
		if current ~= nil then
			current.endedAt = now
			self.padEventOut = current
		end

		self.padEvent = nil
		return
	end

	if PAD_EVENT_RIMS[kind] == nil then
		warn(("[DanceDanceStep] Unknown pad event %s"):format(tostring(kind)))
		return
	end

	local details = info or {}
	local sameKind = current ~= nil and current.kind == kind
	local samePhase = sameKind and current.info.phase == details.phase

	self.padEventOut = nil
	self.padEvent = {
		kind = kind,
		info = details,
		startedAt = if sameKind then current.startedAt else now,
		phaseAt = if samePhase then current.phaseAt else now,
	}
end

function BoardView:_padEventState(now: number): (any, number)
	local event = self.padEvent

	if event ~= nil then
		return event, math.clamp((now - event.startedAt) / PAD_EVENT_FADE_SECONDS, 0, 1)
	end

	local out = self.padEventOut

	if out == nil then
		return nil, 0
	end

	local mix = 1 - (now - out.endedAt) / PAD_EVENT_FADE_SECONDS

	if mix <= 0 then
		self.padEventOut = nil
		return nil, 0
	end

	return out, mix
end

function BoardView:_padPulse(now: number): number
	local beatSeconds = self:_padBeatSeconds()
	local beatAge = if self.padBeatAt ~= nil then now - self.padBeatAt else math.huge

	if beatAge >= beatSeconds then
		return 0
	end

	return (1 - beatAge / beatSeconds) ^ PAD_PULSE_SHARPNESS
end

local function tilePhase(x: number, y: number): number
	return (x * 73 + y * 151) % 97 / 97 * math.pi * 2
end

local function coordSet(list: any): { [number]: boolean }
	local set = {}

	if type(list) ~= "table" then
		return set
	end

	for _, coord in list do
		if type(coord) == "table" and type(coord.x) == "number" and type(coord.y) == "number" then
			set[coord.x * Board.Rows + coord.y] = true
		end
	end

	return set
end

-- One frame of an event as a function from a tile to its colour, whether it
-- glows, and a number to print on it.
function BoardView:_padEventLook(event: any, now: number): (x: number, y: number) -> (Color3, boolean, number?)
	local info = event.info
	local pulse = self:_padPulse(now)

	if event.kind == "lava" then
		local safe = coordSet(info.safe)

		return function(x: number, y: number)
			if safe[x * Board.Rows + y] then
				return padIdleColor(x, y):Lerp(PAD_SAFE_COLOR, PAD_SAFE_MIX + PAD_SAFE_PULSE * pulse), true, nil
			end

			local bubble = (1 + math.sin(now * PAD_LAVA_BUBBLE_SPEED + tilePhase(x, y))) / 2

			return PAD_LAVA_DARK:Lerp(PAD_LAVA_HOT, math.min(bubble * bubble + PAD_LAVA_BEAT_LIFT * pulse, 1)), false, nil
		end
	elseif event.kind == "spotlight" then
		local lit = coordSet(info.lit)

		return function(x: number, y: number)
			if lit[x * Board.Rows + y] then
				return padIdleColor(x, y):Lerp(PAD_SPOT_COLOR, PAD_SPOT_MIX + PAD_SPOT_PULSE * pulse), true, nil
			end

			return PAD_DARK, false, nil
		end
	elseif event.kind == "memory" and info.phase == "watch" then
		local beatSeconds = tonumber(info.beatSeconds) or self:_padBeatSeconds()
		local beats = (now - event.phaseAt) / beatSeconds
		local order = math.floor(beats) + 1
		local shown = if type(info.sequence) == "table" then info.sequence[order] else nil
		local age = (beats - (order - 1)) / PAD_MEMORY_FLASH_BEATS

		if type(shown) ~= "table" or age >= 1 then
			shown = nil
		end

		return function(x: number, y: number)
			if shown ~= nil and shown.x == x and shown.y == y then
				return PAD_MEMORY_COLOR:Lerp(PAD_HIT_COLOR, PAD_MEMORY_WHITE * (1 - age)), true, order
			end

			return PAD_DARK, false, nil
		end
	elseif event.kind == "memory" then
		return function(_x: number, _y: number)
			return PAD_DARK:Lerp(PAD_MEMORY_COLOR, PAD_MEMORY_PULSE * pulse), false, nil
		end
	end

	return function(x: number, y: number)
		local frost = math.max(math.sin(now * PAD_FROST_SPEED + tilePhase(x, y)), 0) ^ PAD_FROST_SHARPNESS
		local ice = padIdleColor(x, y):Lerp(PAD_ICE, PAD_ICE_MIX)

		return ice:Lerp(Color3.new(1, 1, 1), PAD_FROST_MIX * frost), false, nil
	end
end

-- Spotlight shafts are a small pool, made the first time a spotlight needs one.
function BoardView:_paintSpots(event: any, mix: number)
	local lit = if event ~= nil and event.kind == "spotlight" and type(event.info.lit) == "table" then event.info.lit else {}
	local spots = self.padSpots or {}
	local shown = 0

	for _, coord in lit do
		if shown >= PAD_SPOT_MAX then
			break
		end

		if type(coord) ~= "table" or not Board.isValidCoord(coord.x, coord.y) then
			continue
		end

		shown += 1

		local spot = spots[shown]

		if spot == nil then
			local width = Board.TileSize * PAD_SPOT_WIDTH
			spot = createPart(self.folder, "pad_spotlight", Vector3.new(PAD_SPOT_HEIGHT, width, width), self.origin, PAD_SPOT_COLOR, Enum.Material.Neon)
			spot.Shape = Enum.PartType.Cylinder
			spot.CanCollide = false
			spot.CanQuery = false
			spot.CanTouch = false
			spots[shown] = spot
		end

		local base = Board.coordToWorld(coord.x, coord.y, self.origin)
		spot.CFrame = CFrame.new(base + Vector3.new(0, PAD_SPOT_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		spot.Transparency = 1 - (1 - PAD_SPOT_TRANSPARENCY) * mix
	end

	for index = shown + 1, self.padSpotCount or 0 do
		spots[index].Transparency = 1
	end

	self.padSpots = spots
	self.padSpotCount = shown
end

function BoardView:_paintRim(event: any, eventMix: number)
	local tint = PAD_ENERGY_TINTS[self.padEnergy or "calm"] or PAD_ENERGY_TINTS.calm
	local color = PIXEL_COLORS.Rim:Lerp(tint, PAD_RIM_TINT_MIX)

	if event ~= nil then
		color = color:Lerp(PAD_EVENT_RIMS[event.kind], eventMix)
	end

	self:_setRimColor(color)
end

function BoardView:_setRimColor(color: Color3)
	if self.rimColor == color then
		return
	end

	self.rimColor = color

	for _, part in self.beatParts or {} do
		part.Color = color
	end
end

function BoardView:_barPoint(x: number, y: number): Vector3
	return Board.coordToWorld(x, y, self.origin) + Vector3.new(0, PAD_BAR_LIFT, 0)
end

-- One outline around a group of tiles: an edge wherever a tile has no
-- neighbour in the group, each stretched to meet the next edge round a corner.
function BoardView:_addOutline(bars: { PadBar }, tiles: { { x: number, y: number } }, color: Color3, width: number?)
	local inGroup: { [number]: boolean } = {}
	local unique = {}

	for _, tile in tiles do
		local key = groupKey(tile.x, tile.y)

		if Board.isValidCoord(tile.x, tile.y) and not inGroup[key] then
			inGroup[key] = true
			table.insert(unique, tile)
		end
	end

	local function has(x: number, y: number): boolean
		return inGroup[groupKey(x, y)] == true
	end

	local thickness = width or PAD_OUTLINE_THICKNESS
	local half = lightBaseSize().X / 2 + thickness / 2
	local convex = half + thickness / 2
	local straight = Board.TileSize / 2
	local concave = Board.TileSize - half + thickness / 2

	for _, tile in unique do
		local center = self:_barPoint(tile.x, tile.y)

		for _, side in PAD_OUTLINE_SIDES do
			if has(tile.x + side.X, tile.y + side.Y) then
				continue
			end

			local along = Vector2.new(math.abs(side.Y), math.abs(side.X))
			local reach = {}

			for index, direction in { -1, 1 } do
				local nextX, nextY = tile.x + along.X * direction, tile.y + along.Y * direction

				reach[index] = if has(nextX + side.X, nextY + side.Y)
					then concave
					elseif has(nextX, nextY) then straight
					else convex
			end

			local axis = Vector3.new(along.X, 0, along.Y)
			local middle = center + Vector3.new(side.X, 0, side.Y) * half
			addBar(bars, middle - axis * reach[1], middle + axis * reach[2], thickness, color)
		end
	end
end

-- An arrow on the floor from one tile to another along the route a player
-- walks: diagonally first where the floor allows it, then straight, otherwise
-- the long way first, so it bends at most once.
function BoardView:_addArrow(
	bars: { PadBar },
	from: { x: number, y: number },
	to: { x: number, y: number },
	color: Color3
)
	local dx, dy = to.x - from.x, to.y - from.y
	local across = math.min(math.abs(dx), math.abs(dy))
	local bend = if Board.isLegalMove(1, 1)
		then { x = from.x + math.sign(dx) * across, y = from.y + math.sign(dy) * across }
		elseif math.abs(dx) >= math.abs(dy) then { x = to.x, y = from.y }
		else { x = from.x, y = to.y }
	local straight = (bend.x == from.x and bend.y == from.y) or (bend.x == to.x and bend.y == to.y)
	local points = { self:_barPoint(from.x, from.y) }

	if not straight then
		table.insert(points, self:_barPoint(bend.x, bend.y))
	end

	local target = self:_barPoint(to.x, to.y)
	local lastDirection = (target - points[#points]).Unit
	local tip = target - lastDirection * lightBaseSize().X / 2
	local firstDirection = ((points[2] or target) - points[1]).Unit

	points[1] += firstDirection * Board.TileSize * PAD_ARROW_START
	table.insert(points, tip - lastDirection * PAD_ARROW_THICKNESS)

	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		-- Each leg runs half a bar past its bend so the corner is filled.
		local overrun = if index < #points - 1 then (b - a).Unit * PAD_ARROW_THICKNESS / 2 else Vector3.zero

		addBar(bars, a, b + overrun, PAD_ARROW_THICKNESS, color)
	end

	for _, sign in { -1, 1 } do
		local back = flatRotate(-lastDirection, sign * PAD_ARROW_HEAD_ANGLE)

		addBar(bars, tip, tip + back * PAD_ARROW_HEAD_LENGTH, PAD_ARROW_THICKNESS, color)
	end
end

function BoardView:_addCross(bars: { PadBar }, x: number, y: number)
	local center = self:_barPoint(x, y)
	local reach = lightBaseSize().X * PAD_CROSS_REACH

	for _, diagonal in { Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit } do
		addBar(bars, center - diagonal * reach, center + diagonal * reach, PAD_CROSS_THICKNESS, PAD_KIND_COLORS.danger)
	end
end

function BoardView:_addDiamond(bars: { PadBar }, x: number, y: number)
	table.insert(bars, {
		cframe = CFrame.new(self:_barPoint(x, y)) * CFrame.Angles(0, math.pi / 4, 0),
		size = Vector3.new(PAD_ITEM_SIZE, PAD_BAR_HEIGHT, PAD_ITEM_SIZE),
		color = PAD_KIND_COLORS.item,
	})
end

-- pickup is { x, y, glyph, name }, or nil to clear it.
function BoardView:setAbilityPickup(pickup: any)
	self.abilityPickup = pickup

	local tile = if pickup ~= nil and self.tiles[pickup.x] ~= nil then self.tiles[pickup.x][pickup.y] else nil
	local gui = self.pickupGui

	if tile == nil then
		if gui ~= nil then
			gui.Enabled = false
		end

		return
	end

	if gui == nil or gui.Parent == nil then
		gui = Instance.new("BillboardGui")
		gui.Name = "AbilityPickup"
		gui.Size = UDim2.fromScale(PAD_PICKUP_LABEL_STUDS.X, PAD_PICKUP_LABEL_STUDS.Y)
		gui.StudsOffsetWorldSpace = Vector3.new(0, PAD_PICKUP_LABEL_LIFT, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0

		local label = Instance.new("TextLabel")
		label.Name = "Name"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = PAD_PICKUP_COLOR
		label.TextStrokeColor3 = Color3.fromRGB(20, 10, 24)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		self.pickupGui = gui
	end

	local label = gui:FindFirstChild("Name") :: TextLabel
	label.Text = pickup.glyph .. " " .. pickup.name
	gui.Adornee = tile
	gui.Parent = tile
	gui.Enabled = true
end

function BoardView:_addClapMark(bars: { PadBar }, x: number, y: number, color: Color3)
	local center = self:_barPoint(x, y)
	local inner = Board.TileSize * PAD_CLAP_RAY_INNER
	local outer = Board.TileSize * PAD_CLAP_RAY_OUTER
	local core = color:Lerp(PAD_HIT_COLOR, PAD_CLAP_CORE_WHITE)

	for ray = 0, PAD_CLAP_RAYS - 1 do
		local angle = ray * 2 * math.pi / PAD_CLAP_RAYS
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local reach = if ray % 2 == 0 then outer else inner + (outer - inner) * PAD_CLAP_RAY_SHORT
		local start, tip = center + direction * inner, center + direction * reach

		addBar(bars, start, tip, PAD_CLAP_RAY_THICKNESS, color)
		addBar(bars, start + PAD_CLAP_CORE_LIFT, tip + PAD_CLAP_CORE_LIFT, PAD_CLAP_CORE_THICKNESS, core)
	end

	self:_addOutline(bars, { { x = x, y = y } }, color)
end

-- The bars are a pool of adornments, grown the first time a frame needs more.
function BoardView:_paintPadBars(bars: { PadBar })
	local pool = self.padBars
	local anchor = self.approachAnchor

	if pool == nil or anchor == nil then
		return
	end

	for index, bar in bars do
		local adornment = pool[index]

		if adornment == nil then
			adornment = Instance.new("BoxHandleAdornment")
			adornment.Name = "PadBar"
			adornment.Adornee = anchor
			adornment.Parent = self.folder
			pool[index] = adornment
		end

		adornment.CFrame = anchor.CFrame:ToObjectSpace(bar.cframe)
		adornment.Size = bar.size
		adornment.Color3 = bar.color
		adornment.Transparency = bar.transparency or 0
		adornment.Visible = true
	end

	for index = #bars + 1, #pool do
		pool[index].Visible = false
	end
end

function BoardView:padKindColor(kind: string): Color3
	return PAD_KIND_COLORS[kind] or PAD_KIND_COLORS.single
end

-- Paints the whole pad for one frame. telegraphs come soonest first. Only two
-- beats show: the next one pink, filling toward its beat with its beats-left
-- count and a line from the dancer, and the one after it plain white. Dangers
-- and pickups show only as far ahead as that second beat.
function BoardView:renderPad(now: number, telegraphs: { PadTelegraph }, dancer: { x: number, y: number }?)
	if not self.padLook then
		return
	end

	local event, eventMix = self:_padEventState(now)
	local eventLook = if event ~= nil then self:_padEventLook(event, now) else nil
	local activeKind = if self.padEvent ~= nil then self.padEvent.kind else nil
	local hideDanger = activeKind == "lava" or activeKind == "spotlight"
	local colors: { { Color3 } } = {}
	local neon: { { boolean } } = {}
	local counts: { { number? } } = {}
	local levels: { [number]: { [number]: PadLevel } } = {}
	local marks: { [number]: { [number]: PadMark } } = {}

	for x = 1, Board.Columns do
		colors[x], neon[x], counts[x], levels[x], marks[x] = {}, {}, {}, {}, {}

		for y = 1, Board.Rows do
			colors[x][y] = padIdleColor(x, y)
			neon[x][y] = false

			if eventLook ~= nil then
				local color, glow, count = eventLook(x, y)
				-- A numbered memory flash skips the fade so the first tile of
				-- the sequence is as bright as the rest.
				colors[x][y] = if count ~= nil then color else colors[x][y]:Lerp(color, eventMix)
				neon[x][y] = glow and (count ~= nil or eventMix >= 0.5)
				counts[x][y] = count
			end
		end
	end

	local function fill(x: number, y: number, color: Color3, glow: boolean)
		if Board.isValidCoord(x, y) then
			colors[x][y] = color
			neon[x][y] = glow
			levels[x][y] = nil
			marks[x][y] = nil
		end
	end

	local function mark(x: number, y: number, kind: string)
		if Board.isValidCoord(x, y) then
			marks[x][y] = { kind = kind }
		end
	end

	local function rise(x: number, y: number, color: Color3, amount: number, base: Color3?)
		if Board.isValidCoord(x, y) then
			colors[x][y] = base or padIdleColor(x, y):Lerp(color, PAD_FILL_DIM)
			neon[x][y] = false
			levels[x][y] = { amount = amount, color = color }
		end
	end

	local ranks = padRanks(telegraphs)
	local bars: { PadBar } = {}
	local nextGroup: { PadTelegraph } = {}
	local horizon: number? = nil

	for index, telegraph in telegraphs do
		if ranks[index] == 1 then
			table.insert(nextGroup, telegraph)
		elseif ranks[index] == 2 and telegraph.kind ~= "clap" then
			self:_addOutline(bars, padTiles(telegraph), PAD_NEXT_COLOR, PAD_NEXT_OUTLINE_THICKNESS)
		end

		if ranks[index] ~= nil then
			horizon = telegraph.beatsAway
		end
	end

	local holding = false

	for _, telegraph in telegraphs do
		if telegraph.kind == "hold" and telegraph.beatsAway <= 0 and Board.isValidCoord(telegraph.x, telegraph.y) then
			holding = self:_paintHold(telegraph, dancer, rise, counts, mark) or holding
		end
	end

	-- While a hold runs, the next note keeps its fill but points nowhere and
	-- shows no count, so nothing pulls the dancer off the hold.
	local lead = nextGroup[1]
	local from = if holding then nil else dancer
	local leadCounts = counts

	if holding then
		leadCounts = {}

		for x = 1, Board.Columns do
			leadCounts[x] = {}
		end
	end

	if lead ~= nil and (lead.kind == "pose" or lead.kind == "clap") then
		-- A clap on a hold's beat is the note to play while holding, so it keeps
		-- its fill and count, over the hold's pink.
		local clapInHold = holding and lead.kind == "clap"
		local color = PAD_KIND_COLORS[lead.kind]
		local spot = if lead.kind == "clap"
			then clapSpot(lead, if clapInHold then dancer else from)
			else { x = lead.x, y = lead.y }
		local spotCounts = if clapInHold then counts else leadCounts

		if Board.isValidCoord(spot.x, spot.y) then
			spotCounts[spot.x][spot.y] = padCount(lead.beatsAway)
		end

		rise(spot.x, spot.y, color, padLevel(lead), if clapInHold then PAD_KIND_COLORS.hold else nil)
		mark(spot.x, spot.y, lead.kind)

		if lead.kind == "clap" then
			self:_addClapMark(bars, spot.x, spot.y, color)
		end
	elseif lead ~= nil then
		local tiles = {}

		for _, telegraph in nextGroup do
			for _, tile in padTiles(telegraph) do
				table.insert(tiles, tile)
				rise(tile.x, tile.y, PAD_KIND_COLORS[telegraph.kind] or PAD_STEP_COLOR, padLevel(telegraph))
				mark(tile.x, tile.y, telegraph.kind)
			end
		end

		local arrived = standsOn(tiles, from)
		local path = if lead.kind == "slide" and type(lead.path) == "table" and #lead.path > 0 then lead.path else nil

		-- The count stays on after the dancer arrives: a step is Perfect when it lands
		-- on the beat, so standing early still has to watch for it.
		if lead.beatsAway > 0 and Board.isValidCoord(lead.x, lead.y) then
			leadCounts[lead.x][lead.y] = padCount(lead.beatsAway)
		end

		if path ~= nil then
			for index = 1, #path - 1 do
				self:_addArrow(bars, path[index], path[index + 1], PAD_STEP_COLOR)
			end
		elseif self.padPathArrows and from ~= nil and not arrived and #tiles > 0 then
			self:_addArrow(bars, from, nearestTile(tiles, from), PAD_KIND_COLORS[lead.kind] or PAD_STEP_COLOR)
		end
	end

	for _, telegraph in telegraphs do
		local x, y = telegraph.x, telegraph.y

		if telegraph.hidden or not Board.isValidCoord(x, y) then
			continue
		end

		local waiting = telegraph.beatsAway > 0 and telegraph.beatsAway <= telegraph.lead
		local inView = waiting and (horizon == nil or telegraph.beatsAway <= horizon + PAD_RANK_SAME_BEATS)

		if telegraph.kind == "danger" then
			if inView and not hideDanger then
				rise(x, y, PAD_DANGER_LEVEL, padLevel(telegraph), PAD_DANGER_FILL)
				mark(x, y, "danger")
				self:_addCross(bars, x, y)
			end
		elseif telegraph.kind == "item" then
			if inView then
				self:_addDiamond(bars, x, y)
			end
		elseif telegraph.kind == "pose" then
			local poseBeats = math.max(telegraph.poseBeats or 1, 1e-3)
			local over = -telegraph.beatsAway - poseBeats

			if telegraph.beatsAway > 0 or not (dancer == nil or (dancer.x == x and dancer.y == y)) then
				continue
			elseif over < 0 then
				local held = telegraph.progress or -telegraph.beatsAway / poseBeats
				rise(x, y, PAD_HIT_COLOR, math.clamp(held, 0, 1), PAD_KIND_COLORS.pose)
				mark(x, y, "pose")
			elseif over < PAD_POSE_FLASH_BEATS then
				fill(x, y, PAD_KIND_COLORS.pose:Lerp(PAD_HIT_COLOR, 1 - over / PAD_POSE_FLASH_BEATS), true)
			end
		end
	end

	local pickup = self.abilityPickup

	if pickup ~= nil and Board.isValidCoord(pickup.x, pickup.y) then
		fill(pickup.x, pickup.y, PAD_PICKUP_COLOR, true)
	end

	self:_paintPadBars(bars)
	self:_paintSpots(self.padEvent, eventMix)

	for index = #self.padFlashes, 1, -1 do
		local flash = self.padFlashes[index]
		local age = now - flash.startedAt
		local fade = math.max(age - PAD_FLASH_HOLD_SECONDS, 0) / PAD_FLASH_FADE_SECONDS

		if fade >= 1 or not standsOn({ flash }, dancer) then
			table.remove(self.padFlashes, index)
			continue
		end

		fill(flash.x, flash.y, flash.color:Lerp(colors[flash.x][flash.y], fade), true)
	end

	for x = 1, Board.Columns do
		for y = 1, Board.Rows do
			self:_paintPadTile(x, y, colors[x][y], neon[x][y], counts[x][y], levels[x][y], marks[x][y])
		end
	end

	self:_paintRim(event, eventMix)
end

function BoardView:_paintPadTile(
	x: number,
	y: number,
	color: Color3,
	neon: boolean,
	count: number?,
	level: PadLevel?,
	mark: PadMark?
)
	local key = x * Board.Rows + y
	local last = self.padPainted[key]

	if last == nil then
		last = { markKind = false }
		self.padPainted[key] = last
	end

	local tile = self.tiles[x][y]
	local material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic

	if last.color ~= color then
		last.color = color
		tile.Color = color
	end

	if last.material ~= material then
		last.material = material
		tile.Material = material
	end

	local label = self:_padCount(x, y)
	local deco = self.padDecos[x] and self.padDecos[x][y]
	local kind = if mark ~= nil then mark.kind else nil
	local counted = count ~= nil

	if deco == nil then
		return
	end

	if last.markKind ~= kind or last.counted ~= counted then
		last.markKind = kind
		last.counted = counted
		applyPadDeco(deco, mark, counted)
	end

	local amount = if level ~= nil then level.amount else 0
	local levelColor = if level ~= nil then level.color else nil
	local fillFrame = self.padFills[x][y]

	if last.level ~= amount then
		last.level = amount
		fillFrame.Visible = amount > 0
		fillFrame.Size = UDim2.fromScale(1, amount)
	end

	if levelColor ~= nil and (last.levelColor ~= levelColor or last.levelKind ~= kind) then
		last.levelColor = levelColor
		last.levelKind = kind
		deco.fillGradient.Color = fillSequence(levelColor, kind)
	end

	if last.count ~= count or not last.painted then
		last.painted = true
		last.count = count

		if label ~= nil then
			label.Text = if count ~= nil then tostring(count) else ""
		end
	end
end

return BoardView
