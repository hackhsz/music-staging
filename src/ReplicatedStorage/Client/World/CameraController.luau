local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local StageLighting = require(script.Parent:WaitForChild("StageLighting"))

local CameraController = {}
CameraController.__index = CameraController

-- The pad shot: low enough to see the dancer, high enough that the far row
-- stays in frame, framed for a 40-stud floor and scaled to the active layout's.
local PAD_EYE = Vector3.new(0, 17, 29.5)
local PAD_LOOK = Vector3.new(0, 1, 1.5)
local PAD_REFERENCE_STUDS = 40
local OVERVIEW_FOV = 50
local PUNCH_FOV = 2.5
local PUNCH_IN_SECONDS = 0.05
local PUNCH_OUT_SECONDS = 0.12

-- During a pad run the shot leans after the dancer and moves with the song.
-- Each energy sets how far it sways (studs), how far it swings round the pad
-- (radians), how much it zooms (FOV) and how hard it pulses on the beat.
local PAD_FOLLOW_X = 0.2
local PAD_FOLLOW_Z = 0.08
local PAD_SWAY_BEATS = 8
local PAD_ORBIT_BEATS = 16
local PAD_BOB_STUDS = 0.35
local PAD_PULSE_FOV = 0.7
local PAD_DOWNBEAT_BOOST = 1.6
local PAD_COMBO_ZOOM_FOV = 1.5
local PAD_COMBO_FULL = 50
local PAD_FEVER_ROLL = 0.025
local PAD_ENERGY_RATE = 1.5
local PAD_ENERGY = {
	calm = { sway = 0.6, orbit = 0, zoom = 0, pulse = 0.4 },
	build = { sway = 0.8, orbit = 0.03, zoom = 0.8, pulse = 0.7 },
	chorus = { sway = 1.3, orbit = 0.06, zoom = 1.2, pulse = 1 },
	drop = { sway = 1.5, orbit = 0.08, zoom = 1.8, pulse = 1.4 },
	fever = { sway = 1.5, orbit = 0.12, zoom = 2, pulse = 1.4 },
}
local SHAKE_STUDS = 0.6
local SHAKE_DECAY = 10
-- Ages are clamped: before the first shake the age is infinite, sin(inf) is NaN,
-- and NaN times a zero amount would still poison the camera's CFrame.
local SHAKE_SETTLED_SECONDS = 2
-- A landing nudges the shot down and back up, so each hop has weight.
local LAND_STUDS = 0.18
local LAND_SECONDS = 0.16

-- Pad moments, each eased by a critically damped spring (rate = its omega, 1/s).
-- A green hold is a showcase: the shot dollies in on the dancer, drops a little
-- and orbits slowly, but never so far the pad leaves frame, and it lets go a
-- beat before the hold ends so the next target is in view again.
local HOLD_RATE = 1.8
local HOLD_OUT_RATE = 3.5
local HOLD_DOLLY = 0.4
local HOLD_LOWER = 0.1
local HOLD_LOOK_SHARE = 0.35
-- Closing in, the aim slides toward the near edge: that is what keeps the near
-- row in frame while the dancer grows.
local HOLD_LOOK_NEAR = 7
local HOLD_ORBIT_RATE = 1.2
local HOLD_ORBIT_PER_BEAT = 0.02
local HOLD_ORBIT_MAX = 0.08
local HOLD_RELEASE_BEATS = 1
local PAD_SAFE_REACH = 0.88
local PAD_FIT_STEPS = 5
-- On a phone the HUD and the keys leave a smaller free area, so the shot pulls
-- back and turns until the whole pad, rim included, fills FILL of that area,
-- leaving the rest for the moments, which are cut back to stay inside it.
local AREA_FILL = 0.98
local AREA_RIM_STUDS = 1.5
local AREA_PULL_MIN = 0.6
local AREA_PULL_MAX = 6
local AREA_PULL_STEPS = 14
local AREA_TURN_PASSES = 2
local RUN_RATE = 3
local RUN_PULL = 0.08
local RUN_LEAD_STUDS = 2.5
-- Kicks: a spring at rest given a velocity peaks at speed / (rate * e).
local SWEEP_RATE = 2.4
local SWEEP_YAW_SPEED = 0.9
local SWEEP_FOV_SPEED = 10
local MILESTONE_RATE = 7
local MILESTONE_FOV_SPEED = 45
local MILESTONE_FULL_COMBO = 100

-- The highway's stage shot: low and close in front of the dancer, who is held
-- at DANCER_SCREEN (scale coordinates of the middle of their body) whatever
-- the zoom or aspect: centred below the judgement banner, between the combo on
-- the left and the lanes on the right.
local STAGE_OFFSET = Vector3.new(0, 3.6, 12.5)
local DANCER_SCREEN = Vector2.new(0.48, 0.68)
local DANCER_MIDDLE_HEIGHT = 2.6
local STAGE_FOV = 52
local SWAY_STUDS = 0.5
local SWAY_BEATS = 8
local BOB_STUDS = 0.08
local BEAT_PUNCH_FOV = 1
local COMBO_ZOOM_FOV = 4
local COMBO_FULL = 60
local KICK_FOV = 2
local KICK_SECONDS = 0.18
local FEVER_ORBIT_RADIANS = 0.28
local FEVER_ORBIT_BEATS = 16
-- The results shot: close in front of the dancer, turning slowly about them, so
-- the screen over it (and photo mode under it) has the avatar to look at.
local RESULTS_OFFSET = Vector3.new(0, 1.2, 10)
local RESULTS_LOOK_LIFT = Vector3.new(0, 0.6, 0)
local RESULTS_FOV = 40
local RESULTS_ORBIT_RADIANS = 0.35
local RESULTS_ORBIT_SECONDS = 14
-- Handing back to Roblox's camera on the island: it carries on from whatever angle it
-- is given, so it starts behind the character, looking the way they face (which the
-- place's spawn sets).
local ISLAND_CAMERA_BACK = 12
local ISLAND_CAMERA_UP = 4
local ISLAND_CAMERA_LOOK_UP = 2
-- Roblox's camera controller can start up after the hand-back and set its own angle
-- on its first update, so the framing is repeated once it has settled.
local ISLAND_FRAME_SETTLE_SECONDS = 0.5
-- How quickly the camera eases toward its shot, per second. Slow enough that
-- moving between the overview and the stage reads as a camera move, not a cut.
local FOLLOW_RATE = 4

type Spring = { x: number, v: number }
-- The free area in screen terms: its centre and half size, -1..1 from the
-- middle of the screen, y up.
type Area = { center: Vector2, half: Vector2 }

local function newSpring(): Spring
	return { x = 0, v = 0 }
end

local function stepSpring(spring: Spring, target: number, rate: number, dt: number)
	local offset = spring.x - target
	local decay = math.exp(-rate * dt)
	local carry = (spring.v + rate * offset) * dt
	spring.x = target + (offset + carry) * decay
	spring.v = (spring.v - rate * carry) * decay
end

function CameraController.new()
	local self = setmetatable({
		connections = {},
		focus = Board.Origin,
		performance = false,
		beat = 0,
		combo = 0,
		fever = false,
		orbit = 0,
		kickAt = -math.huge,
		kickStrength = 0,
		punchAt = -math.huge,
		padLive = false,
		motion = true,
		results = false,
		resultsAt = 0,
		energy = "calm",
		sway = PAD_ENERGY.calm.sway,
		orbitAmount = PAD_ENERGY.calm.orbit,
		zoom = PAD_ENERGY.calm.zoom,
		pulse = PAD_ENERGY.calm.pulse,
		follow = Vector3.zero,
		shakeAt = -math.huge,
		shakeStrength = 0,
		landAt = -math.huge,
		landStrength = 0,
		moment = nil,
		holdX = 0,
		holdFrom = 0,
		holdUntil = 0,
		holdSide = 1,
		runLead = Vector3.zero,
		holdSpring = newSpring(),
		holdOrbit = newSpring(),
		runSpring = newSpring(),
		leadX = newSpring(),
		leadZ = newSpring(),
		sweepYaw = newSpring(),
		sweepFov = newSpring(),
		milestoneFov = newSpring(),
		sweepSide = 1,
		padArea = nil,
		active = true,
		pull = 1,
		current = nil,
		baseFov = OVERVIEW_FOV,
		freeFov = if Workspace.CurrentCamera ~= nil then Workspace.CurrentCamera.FieldOfView else nil,
		lastFrame = os.clock(),
	}, CameraController)

	self:apply()
	RunService:BindToRenderStep("DanceDanceStepCamera", Enum.RenderPriority.Camera.Value + 1, function()
		self:apply()
	end)

	local player = Players.LocalPlayer
	table.insert(self.connections, player.CharacterAdded:Connect(function()
		task.wait(0.2)
		self.current = nil
		self:apply()

		if not self.active then
			self:_frameCharacter()
		end
	end))

	return self
end

-- Off the stage in a hub place the player's own camera follows them; this one
-- takes over again for the next run.
function CameraController:setActive(active: boolean)
	if self.active == active then
		return
	end

	self.active = active
	self.results = false
	self.current = nil

	local camera = Workspace.CurrentCamera

	-- The stage shots set their own field of view; Roblox's camera never resets it.
	if active and camera ~= nil then
		self.freeFov = camera.FieldOfView
	end
	local focus = Lighting:FindFirstChild(StageLighting.FocusName)

	if focus ~= nil and focus:IsA("DepthOfFieldEffect") then
		focus.Enabled = false
	end

	if not active and camera ~= nil then
		local character = Players.LocalPlayer.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil

		camera.CameraType = Enum.CameraType.Custom

		if self.freeFov ~= nil then
			camera.FieldOfView = self.freeFov
		end

		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end

		self:_frameCharacter()
		task.delay(ISLAND_FRAME_SETTLE_SECONDS, function()
			if not self.active then
				self:_frameCharacter()
			end
		end)
	end
end

function CameraController:_frameCharacter()
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if camera == nil or root == nil or not root:IsA("BasePart") then
		return
	end

	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)

	if flat.Magnitude < 0.01 then
		return
	end

	local look = flat.Unit
	local eye = root.Position - look * ISLAND_CAMERA_BACK + Vector3.new(0, ISLAND_CAMERA_UP, 0)

	camera.CFrame = CFrame.lookAt(eye, root.Position + Vector3.new(0, ISLAND_CAMERA_LOOK_UP, 0))
end

-- The camera looks at whichever floor is the player's own.
function CameraController:setFocus(origin: Vector3)
	self.focus = origin
	self:apply()
end

-- getArea returns the part of the screen, in pixels, the pad must stay inside,
-- or nil to frame it for the whole screen.
function CameraController:setPadArea(getArea: () -> Rect?)
	self.padArea = getArea
end

-- The stage shot for the highway, or the overview of the floor.
function CameraController:setPerformance(active: boolean)
	self.performance = active

	if not active then
		self.combo = 0
		self.fever = false
	end
end

function CameraController:setBeat(beat: number)
	self.beat = beat
end

function CameraController:setCombo(combo: number)
	self.combo = combo
end

function CameraController:setFever(active: boolean)
	self.fever = active
end

-- A short zoom on a hit: positive pushes in, negative jolts out.
function CameraController:kick(strength: number)
	self.kickAt = os.clock()
	self.kickStrength = strength
end

-- A quick zoom in and back out on the pad shot, for a Perfect deep in a combo
-- or a combo milestone.
function CameraController:punch()
	self.punchAt = os.clock()
end

-- A pad run: the shot follows the dancer and moves with the music.
function CameraController:setPadLive(active: boolean)
	self.padLive = active

	if active then
		self.results = false
	end

	if not active then
		self.combo = 0
		self.fever = false
		self.energy = "calm"
		self.moment = nil

		local springs = {
			self.holdSpring,
			self.holdOrbit,
			self.runSpring,
			self.leadX,
			self.leadZ,
			self.sweepYaw,
			self.sweepFov,
			self.milestoneFov,
		}

		for _, spring in springs do
			spring.x = 0
			spring.v = 0
		end
	end
end

-- The Camera Shake setting: off, the shot holds still under kicks, punches,
-- sweeps and shakes.
function CameraController:setMotion(enabled: boolean)
	self.motion = enabled
end

-- Frames the dancer from the front once a run's results are up, until the next
-- run starts or the player leaves the stage.
function CameraController:setResults(active: boolean)
	if self.results == active then
		return
	end

	self.results = active
	self.resultsAt = os.clock()
end

-- "hold" with { x, y, untilBeat } once the dancer is standing on a green hold;
-- "run" with { tiles, from } as each tile of a purple run is reached.
function CameraController:setPadMoment(kind: string?, info: { [string]: any }?)
	if kind == "hold" and info ~= nil then
		self.holdX = (Board.coordToWorld(info.x, info.y, self.focus) - self.focus).X
		self.holdFrom = self.beat
		self.holdUntil = (tonumber(info.untilBeat) or self.beat) - HOLD_RELEASE_BEATS
		self.holdSide = if self.holdX < 0 then -1 else 1
	elseif kind == "run" and info ~= nil then
		local tiles = info.tiles
		local from = tiles[info.from or 1]
		local to = tiles[#tiles]

		if from ~= nil and to ~= nil and (from.x ~= to.x or from.y ~= to.y) then
			self.runLead = Vector3.new(to.x - from.x, 0, to.y - from.y).Unit
		end
	elseif kind ~= nil then
		return
	end

	self.moment = kind
end

function CameraController:endPadMoment(kind: string)
	if self.moment == kind then
		self.moment = nil
	end
end

-- A quick swing round the pad and a dolly in, for a drop or a chorus coming in.
function CameraController:sweep(strength: number)
	self.sweepSide = -self.sweepSide
	self.sweepYaw.v += SWEEP_YAW_SPEED * strength * self.sweepSide
	self.sweepFov.v += SWEEP_FOV_SPEED * strength
end

function CameraController:milestone(combo: number)
	local strength = 0.6 + 0.4 * math.min(combo / MILESTONE_FULL_COMBO, 1)
	self.milestoneFov.v += MILESTONE_FOV_SPEED * strength
end

function CameraController:setEnergy(energy: string)
	if PAD_ENERGY[energy] ~= nil then
		self.energy = energy
	end
end

-- A jolt that dies away fast, for a miss or a drop.
function CameraController:shake(strength: number)
	self.shakeAt = os.clock()
	self.shakeStrength = strength
end

function CameraController:land(strength: number)
	self.landAt = os.clock()
	self.landStrength = strength
end

local function dancerOffset(focus: Vector3): Vector3
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return Vector3.zero
	end

	local offset = root.Position - focus
	local half = math.max(Board.Columns, Board.Rows) * Board.TileSize / 2

	return Vector3.new(math.clamp(offset.X, -half, half), 0, math.clamp(offset.Z, -half, half))
end

local function viewportSize(): Vector2
	local camera = Workspace.CurrentCamera

	return if camera ~= nil then camera.ViewportSize else Vector2.new(16, 9)
end

local function frustum(fov: number): (number, number)
	local viewport = viewportSize()
	local tanY = math.tan(math.rad(fov / 2))

	return tanY * (if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9), tanY
end

-- How far toward the frame's edge the pad's corner tiles sit, 1 being the edge.
local function padReach(shot: CFrame, fov: number, focus: Vector3): number
	local tanX, tanY = frustum(fov)
	local reach = 0

	for _, corner in { { 1, 1 }, { Board.Columns, 1 }, { 1, Board.Rows }, { Board.Columns, Board.Rows } } do
		local point = shot:PointToObjectSpace(Board.coordToWorld(corner[1], corner[2], focus))

		if point.Z > -1 then
			return math.huge
		end

		reach = math.max(reach, math.abs(point.X / (-point.Z * tanX)), math.abs(point.Y / (-point.Z * tanY)))
	end

	return reach
end

local function toArea(rect: Rect): Area?
	local viewport = viewportSize()

	if viewport.X <= 0 or viewport.Y <= 0 or rect.Width <= 0 or rect.Height <= 0 then
		return nil
	end

	local middle = (rect.Min + rect.Max) / 2

	return {
		center = Vector2.new(middle.X / viewport.X * 2 - 1, 1 - middle.Y / viewport.Y * 2),
		half = Vector2.new(rect.Width / viewport.X, rect.Height / viewport.Y),
	}
end

local function padCorners(focus: Vector3, scale: number): { Vector3 }
	local halfX = Board.Columns * Board.TileSize / 2 + AREA_RIM_STUDS * scale
	local halfZ = Board.Rows * Board.TileSize / 2 + AREA_RIM_STUDS * scale

	return {
		focus + Vector3.new(-halfX, 0, -halfZ),
		focus + Vector3.new(halfX, 0, -halfZ),
		focus + Vector3.new(-halfX, 0, halfZ),
		focus + Vector3.new(halfX, 0, halfZ),
	}
end

-- The corners' box on screen, -1..1 with y up; infinite when one is behind the camera.
local function screenBox(shot: CFrame, tanX: number, tanY: number, corners: { Vector3 }): (Vector2, Vector2)
	local low = Vector2.new(math.huge, math.huge)
	local high = -low

	for _, corner in corners do
		local point = shot:PointToObjectSpace(corner)

		if point.Z > -1 then
			return -Vector2.new(math.huge, math.huge), Vector2.new(math.huge, math.huge)
		end

		local screen = Vector2.new(point.X / (-point.Z * tanX), point.Y / (-point.Z * tanY))
		low = low:Min(screen)
		high = high:Max(screen)
	end

	return low, high
end

-- How far toward the area's edge the pad reaches, 1 being the edge.
local function areaReach(shot: CFrame, fov: number, corners: { Vector3 }, area: Area): number
	local tanX, tanY = frustum(fov)
	local low, high = screenBox(shot, tanX, tanY, corners)
	local center, half = area.center, area.half

	return math.max(
		math.max(center.X - low.X, high.X - center.X) / half.X,
		math.max(center.Y - low.Y, high.Y - center.Y) / half.Y
	)
end

-- The turn that centres the pad's box on the area.
local function aimAt(shot: CFrame, tanX: number, tanY: number, corners: { Vector3 }, area: Area): CFrame
	local turn = CFrame.identity

	for _ = 1, AREA_TURN_PASSES do
		local low, high = screenBox(shot * turn, tanX, tanY, corners)

		if math.abs(low.X) == math.huge then
			break
		end

		local middle = (low + high) / 2
		local yaw = math.atan(middle.X * tanX) - math.atan(area.center.X * tanX)
		local pitch = math.atan(middle.Y * tanY) - math.atan(area.center.Y * tanY)
		turn = turn * CFrame.Angles(0, -yaw, 0) * CFrame.Angles(pitch, 0, 0)
	end

	return turn
end

-- The least pull-back, and its turn, that fits the pad to AREA_FILL of the area.
local function fitArea(build: (pull: number) -> CFrame, fov: number, corners: { Vector3 }, area: Area): (number, CFrame)
	local tanX, tanY = frustum(fov)

	local function fits(pull: number): (boolean, CFrame)
		local shot = build(pull)
		local turn = aimAt(shot, tanX, tanY, corners, area)

		return areaReach(shot * turn, fov, corners, area) <= AREA_FILL, turn
	end

	local low, high = AREA_PULL_MIN, AREA_PULL_MAX

	for _ = 1, AREA_PULL_STEPS do
		local middle = (low + high) / 2

		if fits(middle) then
			high = middle
		else
			low = middle
		end
	end

	local _, turn = fits(high)

	return high, turn
end

function CameraController:_area(): Area?
	local getArea = self.padArea
	local rect = if getArea ~= nil then getArea() else nil

	return if rect ~= nil then toArea(rect) else nil
end

function CameraController:_padShot(dt: number): (CFrame, number)
	local scale = math.max(Board.Columns, Board.Rows) * Board.TileSize / PAD_REFERENCE_STUDS
	local area = self:_area()
	local corners = padCorners(self.focus, scale)
	self.pull = 1

	if not self.padLive then
		local look = self.focus + PAD_LOOK * scale

		local function still(pull: number): CFrame
			return CFrame.lookAt(look + PAD_EYE * scale * pull, look)
		end

		if area == nil then
			return still(1), OVERVIEW_FOV
		end

		local pull, turn = fitArea(still, OVERVIEW_FOV, corners, area)
		self.pull = pull

		return still(pull) * turn, OVERVIEW_FOV
	end

	local blend = 1 - math.exp(-PAD_ENERGY_RATE * dt)
	local target = PAD_ENERGY[self.energy]
	self.sway += (target.sway - self.sway) * blend
	self.orbitAmount += (target.orbit - self.orbitAmount) * blend
	self.zoom += (target.zoom - self.zoom) * blend
	self.pulse += (target.pulse - self.pulse) * blend

	local dancer = dancerOffset(self.focus)
	self.follow += (Vector3.new(dancer.X * PAD_FOLLOW_X, 0, dancer.Z * PAD_FOLLOW_Z) - self.follow) * (1 - math.exp(-FOLLOW_RATE * dt))

	local beat = self.beat
	local holding = self.moment == "hold" and beat < self.holdUntil
	local running = self.moment == "run"
	local orbitTarget = if holding
		then math.min((beat - self.holdFrom) * HOLD_ORBIT_PER_BEAT, HOLD_ORBIT_MAX) * self.holdSide
		else 0
	stepSpring(self.holdSpring, if holding then 1 else 0, if holding then HOLD_RATE else HOLD_OUT_RATE, dt)
	stepSpring(self.holdOrbit, orbitTarget, HOLD_ORBIT_RATE, dt)
	stepSpring(self.runSpring, if running then 1 else 0, RUN_RATE, dt)
	stepSpring(self.leadX, if running then self.runLead.X else 0, RUN_RATE, dt)
	stepSpring(self.leadZ, if running then self.runLead.Z else 0, RUN_RATE, dt)

	local hold = math.clamp(self.holdSpring.x, 0, 1)
	local run = self.runSpring.x
	local lead = Vector3.new(self.leadX.x, 0, self.leadZ.x) * RUN_LEAD_STUDS * scale
	local yaw = math.sin(beat / PAD_ORBIT_BEATS * math.pi * 2) * self.orbitAmount + self.holdOrbit.x
	local sway = math.sin(beat / PAD_SWAY_BEATS * math.pi * 2) * self.sway
	local fov = OVERVIEW_FOV - self.zoom - math.min(self.combo / PAD_COMBO_FULL, 1) * PAD_COMBO_ZOOM_FOV

	local function shot(share: number, pull: number): CFrame
		local held = hold * share
		local distance = (1 - held * HOLD_DOLLY + run * share * RUN_PULL) * pull
		local eye = PAD_EYE * scale
		eye = Vector3.new(eye.X, eye.Y * (1 - held * HOLD_LOWER), eye.Z) * distance + Vector3.new(sway, 0, 0)
		local showcase = Vector3.new(self.holdX * HOLD_LOOK_SHARE, 0, HOLD_LOOK_NEAR * scale)
		local centre = self.follow:Lerp(showcase, held) + lead * share
		local look = self.focus + PAD_LOOK * scale + centre

		return CFrame.lookAt(look + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(eye), look)
	end

	local framed: (share: number) -> CFrame = function(share)
		return shot(share, 1)
	end
	local reach: (frame: CFrame) -> number = function(frame)
		return padReach(frame, fov, self.focus)
	end
	local allowed = PAD_SAFE_REACH

	if area ~= nil then
		local pull, turn = fitArea(function(pull: number)
			return shot(0, pull)
		end, fov, corners, area)
		self.pull = pull
		framed = function(share)
			return shot(share, pull) * turn
		end
		reach = function(frame)
			return areaReach(frame, fov, corners, area)
		end
		allowed = 1
	end

	-- A moment is scaled back until every corner tile stays inside the safe
	-- frame, so a showcase never pushes a possible next target off screen.
	local full = framed(1)
	local limit = math.max(allowed, reach(framed(0)))

	if reach(full) <= limit then
		return full, fov
	end

	local low, high = 0, 1

	for _ = 1, PAD_FIT_STEPS do
		local middle = (low + high) / 2

		if reach(framed(middle)) <= limit then
			low = middle
		else
			high = middle
		end
	end

	return framed(low), fov
end

-- The beat bob, the shake and Fever's roll, in camera space. They sit on top of
-- the eased shot for the same reason the punches do.
function CameraController:_padJolt(now: number): CFrame
	if not self.padLive or self.performance then
		return CFrame.identity
	end

	local beat = self.beat
	local downbeat = if math.floor(beat) % 4 == 0 then PAD_DOWNBEAT_BOOST else 1
	local bob = (1 - beat % 1) ^ 3 * PAD_BOB_STUDS * self.pulse * downbeat
	local shakeAge = math.min(now - self.shakeAt, SHAKE_SETTLED_SECONDS)
	local shakeAmount = self.shakeStrength * SHAKE_STUDS * math.exp(-shakeAge * SHAKE_DECAY)
	local roll = if self.fever then math.sin(beat / PAD_SWAY_BEATS * math.pi * 2) * PAD_FEVER_ROLL else 0
	local landAge = (now - self.landAt) / LAND_SECONDS
	local land = if landAge < 1 then math.sin(landAge * math.pi) * LAND_STUDS * self.landStrength else 0

	return CFrame.new(math.sin(shakeAge * 90) * shakeAmount, math.cos(shakeAge * 77) * shakeAmount - bob - land, 0)
		* CFrame.Angles(0, 0, roll)
end

function CameraController:_padPunch(now: number): number
	local age = now - self.punchAt

	if age < PUNCH_IN_SECONDS then
		return age / PUNCH_IN_SECONDS * PUNCH_FOV
	end

	local out = (age - PUNCH_IN_SECONDS) / PUNCH_OUT_SECONDS

	return if out < 1 then (1 - out) ^ 2 * PUNCH_FOV else 0
end

-- The middle of the dancer's body: the tile's centre, at the height of the
-- character standing on it.
local function dancerMiddle(tile: Vector3): Vector3
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	if root == nil then
		return tile + Vector3.new(0, DANCER_MIDDLE_HEIGHT, 0)
	end

	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight

	return Vector3.new(tile.X, feet + DANCER_MIDDLE_HEIGHT, tile.Z)
end

function CameraController:_stageShot(camera: Camera, dt: number): (CFrame, number)
	local center = Board.centerCoord()
	local dancer = dancerMiddle(Board.coordToWorld(center.x, center.y, self.focus))
	local beat = self.beat
	local sinceBeat = beat % 1

	local targetOrbit = if self.fever then math.sin(beat / FEVER_ORBIT_BEATS * math.pi * 2) * FEVER_ORBIT_RADIANS else 0
	self.orbit += (targetOrbit - self.orbit) * (1 - math.exp(-FOLLOW_RATE * dt))

	local sway = math.sin(beat / SWAY_BEATS * math.pi * 2) * SWAY_STUDS
	local bob = (1 - sinceBeat) ^ 3 * BOB_STUDS
	local offset = CFrame.Angles(0, self.orbit, 0):VectorToWorldSpace(STAGE_OFFSET + Vector3.new(sway, -bob, 0))
	local eye = dancer + offset
	local fov = STAGE_FOV - math.min(self.combo / COMBO_FULL, 1) * COMBO_ZOOM_FOV

	-- Aim off the dancer by exactly the angle that puts them at DANCER_SCREEN.
	local facing = CFrame.lookAt(eye, dancer)
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfHeight = offset.Magnitude * math.tan(math.rad(fov / 2))
	local screenX = (DANCER_SCREEN.X * 2 - 1) * halfHeight * aspect
	local screenY = (1 - DANCER_SCREEN.Y * 2) * halfHeight
	local aim = dancer - facing.RightVector * screenX - facing.UpVector * screenY

	return CFrame.lookAt(eye, aim), fov
end

function CameraController:_resultsShot(): (CFrame, number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local middle = dancerMiddle(if root ~= nil and root:IsA("BasePart") then root.Position else self.focus)
	local turn = math.sin((os.clock() - self.resultsAt) / RESULTS_ORBIT_SECONDS * math.pi * 2) * RESULTS_ORBIT_RADIANS
	local eye = middle + CFrame.Angles(0, turn, 0):VectorToWorldSpace(RESULTS_OFFSET)

	return CFrame.lookAt(eye, middle + RESULTS_LOOK_LIFT), RESULTS_FOV
end

-- Punches sit on top of the eased shot rather than inside it, so they land on
-- the beat instead of being smoothed away.
function CameraController:_punch(now: number): number
	if not self.performance then
		local punch = self:_padPunch(now)

		if self.padLive then
			local downbeat = if math.floor(self.beat) % 4 == 0 then PAD_DOWNBEAT_BOOST else 1
			punch += (1 - self.beat % 1) ^ 4 * PAD_PULSE_FOV * self.pulse * downbeat
		end

		return punch
	end

	local punch = (1 - self.beat % 1) ^ 4 * BEAT_PUNCH_FOV
	local kickAge = now - self.kickAt

	if kickAge < KICK_SECONDS then
		punch += (1 - kickAge / KICK_SECONDS) * KICK_FOV * self.kickStrength
	end

	return punch
end

function CameraController:apply()
	local camera = Workspace.CurrentCamera

	if camera == nil or not self.active then
		return
	end

	local now = os.clock()
	local dt = math.clamp(now - self.lastFrame, 0, 0.1)
	self.lastFrame = now

	local target, fov

	if self.results then
		target, fov = self:_resultsShot()
	elseif self.performance then
		target, fov = self:_stageShot(camera, dt)
	else
		target, fov = self:_padShot(dt)
	end

	local blend = 1 - math.exp(-FOLLOW_RATE * dt)

	if self.current == nil then
		self.current = target
		self.baseFov = fov
	else
		self.current = self.current:Lerp(target, blend)
		self.baseFov += (fov - self.baseFov) * blend
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local swept = self:_sweep(self.current, dt)

	if self.motion then
		camera.CFrame = swept * self:_padJolt(now)
		camera.FieldOfView = self.baseFov - self:_punch(now) - self.sweepFov.x - self.milestoneFov.x
	else
		camera.CFrame = self.current
		camera.FieldOfView = self.baseFov
	end
	self:_focus(camera)
end

-- Keeps the depth of field's sharp band on the player's floor; the stage shot looks
-- elsewhere, and weak devices skip it, so both drop the blur.
function CameraController:_focus(camera: Camera)
	local focus = Lighting:FindFirstChild(StageLighting.FocusName)

	if focus == nil or not focus:IsA("DepthOfFieldEffect") then
		return
	end

	focus.Enabled = StageLighting.isFocusAllowed() and not self.performance
	focus.FocusDistance = if self.results
		then RESULTS_OFFSET.Magnitude
		else (camera.CFrame.Position - (self.focus or Board.Origin)).Magnitude
end

-- The sweep and the milestone dolly sit on top of the eased shot like the
-- punches do; the sweep turns the shot about the point it is looking at.
function CameraController:_sweep(shot: CFrame, dt: number): CFrame
	stepSpring(self.sweepYaw, 0, SWEEP_RATE, dt)
	stepSpring(self.sweepFov, 0, SWEEP_RATE, dt)
	stepSpring(self.milestoneFov, 0, MILESTONE_RATE, dt)

	if self.performance or not self.padLive then
		return shot
	end

	local scale = math.max(Board.Columns, Board.Rows) * Board.TileSize / PAD_REFERENCE_STUDS
	local pivot = shot.Position + shot.LookVector * (PAD_EYE * scale).Magnitude * self.pull

	return CFrame.new(pivot) * CFrame.Angles(0, self.sweepYaw.x, 0) * CFrame.new(-pivot) * shot
end

function CameraController:destroy()
	RunService:UnbindFromRenderStep("DanceDanceStepCamera")

	for _, connection in self.connections do
		connection:Disconnect()
	end

	self.connections = {}
end

return CameraController
