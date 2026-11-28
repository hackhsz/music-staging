--!strict
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent
local Surface = ArenaPalette.Surface

-- One row of fans between the dance floors and the stage. It is in frame from
-- every floor, and it keeps clear of the tiles so a fan never covers a target.
local ROW_Z = -33
local ROW_HALF_WIDTH = 55
-- A stand of fans on a riser beside the player's floor, facing it, close
-- enough to be in the pad shot. Two rows, the back one raised.
local STAND_FRONT_X = 28
local STAND_ROW_GAP = 4.5
local STAND_RISER = 1.4
local STAND_Z_FROM = -16
local STAND_Z_TO = 5
local STAND_TURN = math.pi / 2
local STAND_MARGIN = 2

local ARM_REST_LIFT = 0.6
local FEVER_LIFT = 1.2
local MISS_DROP = -1
local CHEER_LIFT = 0.4
local LIFT_RATE = 10
local BOUNCING_ENERGY = { chorus = true, drop = true, fever = true }

-- How hard the row bounces and how far the lightsticks swing, by how the run
-- is going. The sway takes two beats, so a row of sticks reads as one wave.
local IDLE: Level = { bounce = 0.08, sway = math.rad(8) }
local CHEER: Level = { bounce = 0.25, sway = math.rad(22) }
local PARTY: Level = { bounce = 0.55, sway = math.rad(34) }
local FEVER: Level = { bounce = 0.8, sway = math.rad(40) }
local SWAY_BEATS = 2
-- Each fan is a little behind the one before, so the sticks ripple.
local FAN_SPREAD = 0.04
local ARM_SWAY_SHARE = 0.6
-- A combo this long gets the row up to party level on its own.
local FULL_HYPE_COMBO = 40

-- A milestone sends a stadium wave down the row.
local WAVE_STEP_SECONDS = 0.045
local WAVE_JUMP = 2.2
local WAVE_SECONDS = 0.45

-- The row plays along with the floor. Crowd hype decides how many fans are on
-- their feet; the rest sit still with their sticks dim. A hold lifts every
-- stick and keeps it up, a run sends a wave down the row as it goes, a clap
-- gets a clap back, and finishing either gets the whole row jumping.
local SEATED_SHARE = 0.3
local SEATED_MOTION = 0.25
local HYPE_MAX = 100
local SEAT_SPREAD = 7
local HOLD_LIFT = 1.6
local HOLD_SWAY = math.rad(5)
local POP_STAGGER_STEP = 0.013
local POP_STAGGER_SECONDS = 0.08
local DROP_SECONDS = 0.6
local CLAP_SECONDS = 0.22
local CLAP_ANGLE = math.rad(160)
-- Every hit sends a hop out from the middle of the row, bigger as the combo
-- climbs, and flashes the sticks it passes. From PUMP_FROM the free arm starts
-- fist pumping on the beat, all the way up by PUMP_FULL. Fever turns the
-- sticks into a rainbow running down the row.
local HIT_HOP = 0.9
local HIT_HOP_SECONDS = 0.25
local HIT_RIPPLE_SECONDS = 0.18
local HIT_FLASH_SECONDS = 0.1
local PUMP_FROM = 10
local PUMP_FULL = 40
local PUMP_ANGLE = math.rad(150)
local RAINBOW_SPEED = 0.5

-- A full house on bleachers around the floor. Each row is one see-through panel
-- with a SurfaceGui of silhouettes, so a whole row costs one part; the
-- silhouettes dance with the fans above, moved in pixels.
local WALL_PIXELS_PER_STUD = 10
local WALL_HEIGHT = 9
local WALL_SLOT = 2.4
local WALL_FAN_SIZE = Vector2.new(22, 60)
local WALL_SCALE_FROM = 0.85
local WALL_SCALE_TO = 1.1
local WALL_GUI_NAME = "Crowd"
local WALLS: { Wall } = {
	{ center = Vector3.new(-30, 0, -5), length = 26, alongZ = true, face = Enum.NormalId.Right, riser = 0 },
	{ center = Vector3.new(-33.5, 1.6, -5), length = 26, alongZ = true, face = Enum.NormalId.Right, riser = 3.5 },
	{ center = Vector3.new(-37, 3.2, -5), length = 26, alongZ = true, face = Enum.NormalId.Right, riser = 3.5 },
	{ center = Vector3.new(36.5, 2.8, -5), length = 26, alongZ = true, face = Enum.NormalId.Left, riser = 4 },
	{ center = Vector3.new(40.5, 4.2, -5), length = 26, alongZ = true, face = Enum.NormalId.Left, riser = 4 },
	{ center = Vector3.new(0, 1.5, -36.5), length = 96, alongZ = false, face = Enum.NormalId.Back, riser = 3 },
}

type Level = { bounce: number, sway: number }
type Rest = { part: Part, rest: CFrame }
type Wall = { center: Vector3, length: number, alongZ: boolean, face: Enum.NormalId, riser: number }
type Seat = { along: number, seat: number, jumpAt: number }

type Fan = {
	along: number,
	seat: number,
	jumpAt: number,
	body: Part,
	lightstick: Part,
	bodyColor: Color3,
	bodyParts: { Rest },
	leftArm: Rest?,
	rightArm: Rest?,
	stick: Rest?,
	stickColor: Color3?,
}

type WallFan = {
	along: number,
	seat: number,
	jumpAt: number,
	root: GuiObject,
	rest: UDim2,
	body: GuiObject,
	arm: GuiObject,
	armPivot: GuiObject,
	stick: GuiObject,
	stickPivot: GuiObject,
	bodyColor: Color3,
	stickColor: Color3?,
}

local ArenaCrowd = {}

export type ArenaCrowd = {
	setMood: (mood: string, combo: number) -> (),
	setHype: (hype: number?) -> (),
	cue: (cue: string, value: any) -> (),
	onBeat: (phase: number, beatIndex: number) -> (),
	setEnergy: (energy: string) -> (),
	milestone: () -> (),
}

-- turn spins the fan about its own centre; 0 faces the floors from behind them.
local function addFan(kit: ArenaKit.ArenaKit, name: string, base: Vector3, bodyColor: Color3, turn: number?)
	local spin = CFrame.Angles(0, turn or 0, 0)
	local lift = Vector3.new(0, ARM_REST_LIFT, 0)

	local function place(part: Part, offset: Vector3)
		part.CFrame = CFrame.new(base + spin:VectorToWorldSpace(offset)) * spin
	end

	place(kit:box(name .. "_body", Vector3.new(2.2, 3.4, 1.2), base, bodyColor), Vector3.new(0, 1.7, 0))
	place(kit:ball(name .. "_head", 2, base, Surface.Structure), Vector3.new(0, 4.4, 0))
	place(kit:box(name .. "_left_arm", Vector3.new(0.55, 2.6, 0.6), base, bodyColor), Vector3.new(-1.5, 2.1, 0) + lift)
	place(kit:box(name .. "_right_arm", Vector3.new(0.55, 2.6, 0.6), base, bodyColor), Vector3.new(1.5, 2.1, 0) + lift)
	place(
		kit:box(name .. "_lightstick", Vector3.new(0.45, 2.2, 0.45), base, Accent.Lilac, Enum.Material.Neon),
		Vector3.new(2.2, 4, 0) + lift
	)
end

local function fanColor(index: number): Color3
	return ArenaPalette.Silhouettes[index % #ArenaPalette.Silhouettes + 1]
end

-- Dark silhouettes with a lightstick each; bind makes them dance. The stand's
-- fans carry on the row's numbering, so a wave runs down the row and then the stand.
function ArenaCrowd.build(kit: ArenaKit.ArenaKit)
	kit:section("Crowd")

	local count = kit.quality.audiencePods

	for index = 1, count do
		local x = if count > 1 then -ROW_HALF_WIDTH + (index - 1) * (2 * ROW_HALF_WIDTH) / (count - 1) else 0

		addFan(kit, ("fan_%02d"):format(index), Vector3.new(x, 0, ROW_Z), fanColor(index))
	end

	ArenaCrowd.buildStand(kit, count + 1)
	ArenaCrowd.buildWalls(kit)
end

function ArenaCrowd.buildStand(kit: ArenaKit.ArenaKit, firstIndex: number)
	local perRow = math.ceil(kit.quality.standFans / 2)
	local spacing = if perRow > 1 then (STAND_Z_TO - STAND_Z_FROM) / (perRow - 1) else 0
	local backX = STAND_FRONT_X + STAND_ROW_GAP
	local nearZ, farZ = STAND_Z_FROM - STAND_MARGIN, STAND_Z_TO + spacing / 2 + STAND_MARGIN

	kit:box(
		"stand_riser",
		Vector3.new(STAND_ROW_GAP + STAND_MARGIN, STAND_RISER, farZ - nearZ),
		Vector3.new(backX, STAND_RISER / 2, (nearZ + farZ) / 2),
		Surface.Structure
	)

	for slot = 0, kit.quality.standFans - 1 do
		local row = slot // perRow
		local column = slot % perRow
		local z = STAND_Z_FROM + (column + row / 2) * spacing
		local base = Vector3.new(if row == 0 then STAND_FRONT_X else backX, if row == 0 then 0 else STAND_RISER, z)
		local index = firstIndex + slot

		addFan(kit, ("fan_%02d"):format(index), base, fanColor(index), STAND_TURN)
	end
end

local function frame(parent: Instance, name: string, color: Color3?): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BorderSizePixel = 0
	item.BackgroundColor3 = color or Color3.new()
	item.BackgroundTransparency = if color ~= nil then 0 else 1
	item.Parent = parent

	return item
end

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

-- A pivot turns its child about the pivot's centre: 0 points it up, 180 down.
local function limb(parent: Instance, name: string, position: UDim2, size: UDim2, rotation: number, color: Color3): Frame
	local pivot = frame(parent, name .. "Pivot")
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = position
	pivot.Size = size
	pivot.Rotation = rotation

	local child = frame(pivot, name, color)
	child.Size = UDim2.fromScale(1, 0.5)
	round(child, 0.5)

	return child
end

local function addWallFan(gui: SurfaceGui, name: string, x: number, scale: number, bodyColor: Color3)
	local root = frame(gui, name)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0, x, 1, 0)
	root.Size = UDim2.fromOffset(WALL_FAN_SIZE.X * scale, WALL_FAN_SIZE.Y * scale)

	local body = frame(root, "Body", bodyColor)
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(0.7, 0.42)
	round(body, 0.3)

	local head = frame(root, "Head", Surface.Structure)
	head.AnchorPoint = Vector2.new(0.5, 1)
	head.Position = UDim2.fromScale(0.5, 0.57)
	head.Size = UDim2.fromScale(0.55, 0.2)
	round(head, 0.5)

	limb(root, "Arm", UDim2.fromScale(0.2, 0.64), UDim2.fromScale(0.18, 0.38), 180, bodyColor)
	limb(root, "Stick", UDim2.fromScale(0.85, 0.62), UDim2.fromScale(0.18, 0.6), 0, Accent.Lilac)
end

function ArenaCrowd.buildWalls(kit: ArenaKit.ArenaKit)
	local fill = kit.quality.crowdWallFill
	local index = 0

	for wallIndex, wall in WALLS do
		local name = ("crowd_wall_%d"):format(wallIndex)
		local base = wall.center
		local span = wall.length + 1
		local depth = if wall.alongZ then Vector3.new(wall.riser, base.Y, span) else Vector3.new(span, base.Y, wall.riser)

		if base.Y > 0 then
			kit:box(name .. "_riser", depth, Vector3.new(base.X, base.Y / 2, base.Z), Surface.Structure)
		end

		local size = if wall.alongZ then Vector3.new(0.2, WALL_HEIGHT, wall.length) else Vector3.new(wall.length, WALL_HEIGHT, 0.2)
		local panel = kit:box(name, size, base + Vector3.new(0, WALL_HEIGHT / 2, 0), Surface.Void)
		panel.Transparency = 1

		local gui = Instance.new("SurfaceGui")
		gui.Name = WALL_GUI_NAME
		gui.Adornee = panel
		gui.Face = wall.face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = WALL_PIXELS_PER_STUD
		gui.Parent = panel

		local random = Random.new(wallIndex)
		local slots = math.floor(wall.length / WALL_SLOT)

		for slot = 1, slots do
			if math.floor(slot * fill) == math.floor((slot - 1) * fill) then
				continue
			end

			index += 1

			local x = ((slot - 0.5) * WALL_SLOT + random:NextNumber(-0.4, 0.4)) * WALL_PIXELS_PER_STUD
			local scale = random:NextNumber(WALL_SCALE_FROM, WALL_SCALE_TO)
			addWallFan(gui, ("Fan%03d"):format(slot), x, scale, fanColor(index))
		end
	end
end

local function rest(arena: Instance, name: string): Rest?
	local part = ArenaKit.findPart(arena, name)

	return if part ~= nil then { part = part, rest = part.CFrame } else nil
end

-- The part turned about the end of it at offsetY (its top or bottom), then lifted.
local function swung(entry: Rest, lift: number, angle: number, offsetY: number): CFrame
	local pivot = entry.rest * CFrame.new(0, offsetY, 0)

	return CFrame.new(0, lift, 0) * pivot * CFrame.Angles(0, 0, angle) * CFrame.new(0, -offsetY, 0)
end

local function bindWalls(arena: Instance): { WallFan }
	local wallFans: { WallFan } = {}

	for wallIndex in WALLS do
		local panel = ArenaKit.findPart(arena, ("crowd_wall_%d"):format(wallIndex))
		local gui = if panel ~= nil then panel:FindFirstChild(WALL_GUI_NAME) else nil

		if gui == nil then
			continue
		end

		local row: { WallFan } = {}

		for _, root in gui:GetChildren() do
			local body = root:FindFirstChild("Body")
			local armPivot = root:FindFirstChild("ArmPivot")
			local stickPivot = root:FindFirstChild("StickPivot")
			local arm = if armPivot ~= nil then armPivot:FindFirstChild("Arm") else nil
			local stick = if stickPivot ~= nil then stickPivot:FindFirstChild("Stick") else nil

			if
				not root:IsA("GuiObject")
				or not (body and body:IsA("GuiObject"))
				or not (arm and arm:IsA("GuiObject"))
				or not (armPivot and armPivot:IsA("GuiObject"))
				or not (stick and stick:IsA("GuiObject"))
				or not (stickPivot and stickPivot:IsA("GuiObject"))
			then
				continue
			end

			table.insert(row, {
				root = root,
				rest = root.Position,
				body = body,
				arm = arm,
				armPivot = armPivot,
				stick = stick,
				stickPivot = stickPivot,
				bodyColor = body.BackgroundColor3,
				stickColor = nil,
				along = 0,
				seat = 0,
				jumpAt = -math.huge,
			})
		end

		table.sort(row, function(a: WallFan, b: WallFan): boolean
			return a.rest.X.Offset < b.rest.X.Offset
		end)

		for fanIndex, fan in row do
			fan.along = if #row > 1 then (fanIndex - 1) / (#row - 1) else 0
			table.insert(wallFans, fan)
		end
	end

	return wallFans
end

function ArenaCrowd.bind(arena: Instance): ArenaCrowd
	local fans: { Fan } = {}
	local index = 1

	while true do
		local name = ("fan_%02d"):format(index)
		local body = ArenaKit.findPart(arena, name .. "_body")
		local lightstick = ArenaKit.findPart(arena, name .. "_lightstick")

		if body == nil or lightstick == nil then
			break
		end

		local fan: Fan = {
			body = body,
			lightstick = lightstick,
			bodyColor = body.Color,
			bodyParts = {},
			leftArm = rest(arena, name .. "_left_arm"),
			rightArm = rest(arena, name .. "_right_arm"),
			stick = rest(arena, name .. "_lightstick"),
			along = 0,
			seat = 0,
			jumpAt = -math.huge,
			stickColor = nil,
		}

		for _, suffix in { "_body", "_head" } do
			local entry = rest(arena, name .. suffix)

			if entry ~= nil then
				table.insert(fan.bodyParts, entry)
			end
		end

		table.insert(fans, fan)
		index += 1
	end

	-- along is where the fan sits in the row, 0 to 1; seat orders who stands up
	-- first, spread out so a half-full row is not all on one side.
	for fanIndex, fan in fans do
		fan.along = if #fans > 1 then (fanIndex - 1) / (#fans - 1) else 0
		fan.seat = ((fanIndex - 1) * SEAT_SPREAD % #fans) / #fans
	end

	local wallFans = bindWalls(arena)

	for fanIndex, fan in wallFans do
		fan.seat = ((fanIndex - 1) * SEAT_SPREAD % #wallFans) / #wallFans
	end

	local everyone: { Seat } = {}

	for _, fan in fans do
		table.insert(everyone, fan)
	end

	for _, fan in wallFans do
		table.insert(everyone, fan)
	end

	local mood = "idle"
	local moodCombo = 0
	local bouncing = false
	local share = 1
	local holding = false
	local dropUntil = -math.huge
	local clapAt = -math.huge
	local runReached = -1
	local hitAt = -math.huge
	local lift = 0
	local lastFrame = os.clock()
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}

	local function paintBodies()
		local missed = mood == "miss"

		for _, fan in fans do
			fan.body.Color = if missed then Surface.Trim else fan.bodyColor
		end

		for _, fan in wallFans do
			local color = if missed then Surface.Trim else fan.bodyColor
			fan.body.BackgroundColor3 = color
			fan.arm.BackgroundColor3 = color
		end
	end

	local function level(fever: boolean): Level
		if fever then
			return FEVER
		elseif bouncing then
			return PARTY
		elseif mood ~= "cheer" then
			return IDLE
		end

		local hype = math.clamp(moodCombo / FULL_HYPE_COMBO, 0, 1)

		return {
			bounce = CHEER.bounce + (PARTY.bounce - CHEER.bounce) * hype,
			sway = CHEER.sway + (PARTY.sway - CHEER.sway) * hype,
		}
	end

	local function jumpAll(stagger: (fanIndex: number) -> number)
		local now = os.clock()

		for fanIndex, fan in everyone do
			fan.jumpAt = now + stagger(fanIndex)
		end
	end

	local function pop()
		jumpAll(function(fanIndex)
			return (fanIndex * POP_STAGGER_STEP) % POP_STAGGER_SECONDS
		end)
	end

	local function cue(name: string, value: any)
		if name == "holdStart" then
			holding = true
		elseif name == "holdDone" then
			holding = false
			pop()
		elseif name == "holdDrop" or name == "runFail" then
			holding = false
			dropUntil = os.clock() + DROP_SECONDS
		elseif name == "run" and type(value) == "number" then
			local from = if value <= 0 then -1 else runReached
			local now = os.clock()

			for _, fan in everyone do
				if fan.along > from and fan.along <= value then
					fan.jumpAt = now
				end
			end

			runReached = value
		elseif name == "runDone" then
			pop()
		elseif name == "clap" then
			clapAt = os.clock()
		end
	end

	-- Every frame: phase is how far through the beat the song is.
	local function animate(phase: number, beatIndex: number)
		local now = os.clock()
		local dt = math.clamp(now - lastFrame, 0, 0.1)
		lastFrame = now

		local accent = ArenaPalette.moodAccent(mood, moodCombo)
		local fever = accent == Accent.Gold
		local target = if mood == "miss" or now < dropUntil
			then MISS_DROP
			elseif holding then HOLD_LIFT
			elseif fever then FEVER_LIFT
			elseif mood == "cheer" then CHEER_LIFT
			else 0
		lift += (target - lift) * (1 - math.exp(-LIFT_RATE * dt))

		local style = level(fever)
		local beat = beatIndex + phase
		local sinceClap = now - clapAt
		local clap = if sinceClap >= 0 and sinceClap < CLAP_SECONDS
			then math.sin(math.pi * sinceClap / CLAP_SECONDS) * CLAP_ANGLE
			else 0
		local hype = if fever then 1 else math.clamp(moodCombo / FULL_HYPE_COMBO, 0, 1)
		local pump = if fever or bouncing
			then PUMP_ANGLE
			else PUMP_ANGLE * math.clamp((moodCombo - PUMP_FROM) / (PUMP_FULL - PUMP_FROM), 0, 1)
		local count = 0

		-- How one fan moves this frame: its hop, stick sway and arm lift in studs
		-- and radians, the clap and fist pump, and its stick's colour.
		local function pose(fanIndex: number, fan: Seat): (number, number, number, number, number, Color3)
			local standing = fan.seat < share
			local motion = if standing then 1 else SEATED_MOTION
			local offbeat = if (fever or bouncing) and fanIndex % 2 == 0 then 0.5 else 0
			local beatSwing = math.abs(math.sin(math.pi * (phase + offbeat)))
			local hop = style.bounce * motion * beatSwing
			local sinceJump = now - fan.jumpAt
			local jumping = sinceJump > 0 and sinceJump < WAVE_SECONDS
			local sinceHit = now - hitAt - math.abs(fan.along - 0.5) * 2 * HIT_RIPPLE_SECONDS
			local hit = standing and sinceHit > 0 and sinceHit < HIT_HOP_SECONDS

			if jumping then
				hop += WAVE_JUMP * math.sin(math.pi * sinceJump / WAVE_SECONDS)
			end

			if hit then
				hop += HIT_HOP * (0.4 + 0.6 * hype) * math.sin(math.pi * sinceHit / HIT_HOP_SECONDS)
			end

			local swing = if holding and standing then HOLD_SWAY else style.sway * motion
			local sway = swing * math.sin(2 * math.pi * (beat / SWAY_BEATS + fanIndex * FAN_SPREAD))
			local arms = hop + (if standing then lift else math.min(lift, 0))
			local clapping = if standing then clap else 0
			local pumping = if standing and not holding then pump * beatSwing else 0
			local stickColor = if jumping or (holding and standing) or (hit and sinceHit < HIT_FLASH_SECONDS)
				then Accent.White
				elseif standing and fever then Color3.fromHSV((now * RAINBOW_SPEED + fan.along) % 1, 0.6, 1)
				elseif standing then accent
				else Surface.Trim

			return hop, sway, arms, clapping, pumping, stickColor
		end

		for fanIndex, fan in fans do
			local hop, sway, arms, clapping, pumping, stickColor = pose(fanIndex, fan)

			if fan.stickColor ~= stickColor then
				fan.stickColor = stickColor
				fan.lightstick.Color = stickColor
			end

			for _, entry in fan.bodyParts do
				count += 1
				parts[count] = entry.part
				frames[count] = CFrame.new(0, hop, 0) * entry.rest
			end

			if fan.leftArm ~= nil then
				count += 1
				parts[count] = fan.leftArm.part
				frames[count] = swung(fan.leftArm, arms, clapping - pumping, fan.leftArm.part.Size.Y / 2)
			end

			if fan.rightArm ~= nil then
				count += 1
				parts[count] = fan.rightArm.part
				frames[count] = swung(fan.rightArm, arms, sway * ARM_SWAY_SHARE - clapping, fan.rightArm.part.Size.Y / 2)
			end

			if fan.stick ~= nil then
				count += 1
				parts[count] = fan.stick.part
				frames[count] = swung(fan.stick, arms, sway, -fan.stick.part.Size.Y / 2)
			end
		end

		for extra = count + 1, #parts do
			parts[extra] = nil
			frames[extra] = nil
		end

		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)

		for fanIndex, fan in wallFans do
			local hop, sway, _, clapping, pumping, stickColor = pose(fanIndex, fan)

			fan.root.Position = fan.rest - UDim2.fromOffset(0, hop * WALL_PIXELS_PER_STUD)
			fan.stickPivot.Rotation = math.deg(sway)
			fan.armPivot.Rotation = 180 - math.deg(math.max(pumping, clapping))

			if fan.stickColor ~= stickColor then
				fan.stickColor = stickColor
				fan.stick.BackgroundColor3 = stickColor
			end
		end
	end

	return {
		setMood = function(newMood, combo)
			mood = newMood
			moodCombo = combo
			paintBodies()

			if newMood ~= "miss" and newMood ~= "idle" then
				hitAt = os.clock()
			end
		end,
		setHype = function(hype)
			share = if hype == nil then 1 else SEATED_SHARE + (1 - SEATED_SHARE) * math.clamp(hype / HYPE_MAX, 0, 1)
		end,
		cue = cue,
		onBeat = animate,
		setEnergy = function(energy)
			bouncing = BOUNCING_ENERGY[energy] == true

			if energy == "none" then
				holding = false
			end
		end,
		milestone = function()
			jumpAll(function(fanIndex)
				return (fanIndex - 1) * WAVE_STEP_SECONDS
			end)
		end,
	}
end

return ArenaCrowd
