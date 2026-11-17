--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local InputStrategy = require(Shared:WaitForChild("InputStrategy"))
local StepPlanner = require(Shared:WaitForChild("StepPlanner"))
local Timing = require(Shared:WaitForChild("Timing"))

type Coord = Board.TileCoord

type Step = {
	from: Vector3,
	to: Vector3,
	look: Vector3,
	coord: Coord,
	startedAt: number,
	duration: number,
	pressedAt: number,
}

export type StartedCallback = (coord: Coord, pressedAt: number) -> ()

type Callbacks = {
	onStepStarted: StartedCallback,
}

type Bounce = {
	dx: number,
	dz: number,
	origin: Vector3,
	startedAt: number,
	stumble: boolean,
}

type Landing = {
	at: number,
	base: Vector3,
	look: Vector3,
}

-- pressedAt is the os.clock() of the press that asked for the step, which for a
-- buffered press is earlier than the step's start.
export type LandedCallback = (coord: Coord, landedAt: number, pressedAt: number) -> ()

type Fields = {
	callbacks: Callbacks,
	onStepLanded: LandedCallback?,
	origin: Vector3,
	queue: { Coord },
	pressTimes: { number },
	current: Step?,
	stepSeconds: number,
	coord: Coord?,
	enteredAt: number,
	restY: number?,
	dance: Bounce?,
	landing: Landing?,
	landedAt: number,
	facesAudience: boolean,
	freeWalk: boolean,
	connection: RBXScriptConnection?,
}

local StepMover = {}
StepMover.__index = StepMover

export type StepMover = typeof(setmetatable({} :: Fields, StepMover))

-- The camera looks down -Z, so facing +Z faces the audience.
local AUDIENCE = Vector3.new(0, 0, 1)
local PLAYER_MODULE_WAIT = 5
local WALK_SPEED_ATTRIBUTE = "IslandWalkSpeed"

local function getRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root ~= nil and root:IsA("BasePart") then
		return root
	end

	return nil
end

-- The server judges the replicated character position, so the client owns the
-- character and moves it tile to tile itself; Roblox's own WASD and thumbstick
-- walking would fight that. Off the stage in a hub place they come back on.
local function setDefaultControls(enabled: boolean)
	local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local module = playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_WAIT)

	-- Some places run Roblox's controls without a PlayerModule; setWalking covers them.
	if module == nil then
		return
	end

	local ok, err = pcall(function()
		local playerModule: any = (require :: any)(module)
		local controls = playerModule:GetControls()

		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)

	if not ok then
		warn("[DanceDanceStep] Could not switch default controls: " .. tostring(err))
	end
end

-- The controls being off does not stop every jump (the touch button, a respawn),
-- nor every walk where a place has no PlayerModule, so on the stage the character
-- itself can neither walk nor jump. The pad's steps move it directly.
local function setWalking(character: Model?, enabled: boolean)
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil

	if humanoid == nil then
		return
	end

	local saved = humanoid:GetAttribute(WALK_SPEED_ATTRIBUTE)

	if enabled then
		if type(saved) == "number" then
			humanoid.WalkSpeed = saved
		end
	elseif humanoid.WalkSpeed > 0 then
		humanoid:SetAttribute(WALK_SPEED_ATTRIBUTE, humanoid.WalkSpeed)
		humanoid.WalkSpeed = 0
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
end

-- The root stays unanchored on purpose: an assembly the client anchors stops
-- replicating its position, and the server judges that position.
local function bendCoord(from: Coord?, to: Coord, dx: number, dy: number): Coord?
	if from == nil then
		return nil
	end

	local bent = { x = to.x + dx, y = to.y + dy }
	local moveX, moveY = bent.x - from.x, bent.y - from.y

	if math.abs(moveX) ~= 1 or math.abs(moveY) ~= 1 or not Board.isLegalMove(moveX, moveY) then
		return nil
	end

	return if Board.isValidCoord(bent.x, bent.y) then bent else nil
end

local function place(root: BasePart, position: Vector3, look: Vector3)
	root.CFrame = CFrame.lookAt(position, position + look)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function currentLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	return if flat.Magnitude > 0.01 then flat.Unit else AUDIENCE
end

function StepMover.new(callbacks: Callbacks): StepMover
	local fields: Fields = {
		callbacks = callbacks,
		origin = Board.Origin,
		queue = {},
		pressTimes = {},
		current = nil,
		stepSeconds = Timing.getStepSeconds(nil),
		coord = nil,
		enteredAt = os.clock(),
		restY = nil,
		dance = nil,
		landing = nil,
		landedAt = -math.huge,
		facesAudience = false,
		freeWalk = false,
		connection = nil,
	}
	local self = setmetatable(fields, StepMover)

	self.connection = RunService.RenderStepped:Connect(function()
		self:_update(os.clock())
	end)
	self:_applyControls()
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		setWalking(character, self.freeWalk)
	end)

	return self
end

-- On a hub's island the player walks with Roblox's own controls, and the pad's
-- steps are switched off so a key press can never hop them to the stage.
function StepMover.setFreeWalk(self: StepMover, enabled: boolean)
	if self.freeWalk == enabled then
		return
	end

	self.freeWalk = enabled
	self:clearQueue()
	self:_applyControls()
end

-- Reads the flag only once the controls can be found, so a quick switch never
-- lands out of order.
function StepMover._applyControls(self: StepMover)
	setWalking(Players.LocalPlayer.Character, self.freeWalk)

	task.spawn(function()
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_WAIT)
		setDefaultControls(self.freeWalk)
	end)
end

-- Which floor this player dances on. Anything queued for the old floor is dropped.
function StepMover.setOrigin(self: StepMover, origin: Vector3)
	if origin == self.origin then
		return
	end

	self.origin = origin
	self.coord = nil
	self:clearQueue()
	self.current = nil
	self.landing = nil
end

function StepMover.getOrigin(self: StepMover): Vector3
	return self.origin
end

function StepMover.setStepSeconds(self: StepMover, seconds: number)
	self.stepSeconds = math.max(seconds, 0.03)
end

-- The mover is the only thing that knows exactly when a step finished, so the
-- judge gets its landing time from here rather than from a replicated position.
function StepMover.setOnStepLanded(self: StepMover, callback: LandedCallback?)
	self.onStepLanded = callback
end

function StepMover.getCoord(self: StepMover): Coord?
	return self.coord
end

function StepMover.getSettleSeconds(self: StepMover, now: number): number
	if self.coord == nil then
		return 0
	end

	return math.max(now - self.enteredAt, 0)
end

-- How far through its hop the character is, or nil on the ground, and when it
-- last landed, so a posed dancer can tuck in the air and absorb the landing.
function StepMover.getHop(self: StepMover, now: number): (number?, number)
	local step = self.current

	if step == nil then
		return nil, self.landedAt
	end

	return math.clamp((now - step.startedAt) / step.duration, 0, 1), self.landedAt
end

function StepMover.needsInput(self: StepMover): boolean
	return #self.queue == 0
end

function StepMover.clearQueue(self: StepMover)
	table.clear(self.queue)
	table.clear(self.pressTimes)
end

function StepMover.requestStep(self: StepMover, dx: number, dy: number): boolean
	if self.freeWalk then
		return false
	end

	local base = self:_baseCoord()

	if base == nil then
		return false
	end

	local pressedAt = os.clock()
	local home = Board.homeCoord()

	-- On a pad a direction names the panel beside home, wherever the player is.
	if home ~= nil and Board.hopsDirectly() then
		local target = StepPlanner.offset(home, dx, dy)

		return target ~= nil and self:_queueHop(target, pressedAt)
	end

	if not StepPlanner.enqueueStep(self.queue, base, dx, dy, InputStrategy.StepBufferSize) then
		return false
	end

	table.insert(self.pressTimes, pressedAt)
	self:_advance(pressedAt)

	return true
end

-- A second key pressed a moment after the first turns the step that press
-- asked for into a diagonal, rather than adding a step of its own. False when
-- that step has already landed or cannot bend that way.
function StepMover.bendStep(self: StepMover, dx: number, dy: number): boolean
	if self.freeWalk or Board.hopsDirectly() then
		return false
	end

	local queued = #self.queue

	if queued > 0 then
		local before = if queued > 1 then self.queue[queued - 1] else self:_baseCoordBehindQueue()
		local bent = bendCoord(before, self.queue[queued], dx, dy)

		if bent == nil then
			return false
		end

		self.queue[queued] = bent

		return true
	end

	local step = self.current

	if step == nil then
		return false
	end

	local bent = bendCoord(Board.worldToCoord(step.from, self.origin), step.coord, dx, dy)

	if bent == nil then
		return false
	end

	local center = Board.coordToWorld(bent.x, bent.y, self.origin)
	step.to = Vector3.new(center.X, step.from.Y, center.Z)
	step.coord = bent

	if not self.facesAudience then
		step.look = Vector3.new(step.to.X - step.from.X, 0, step.to.Z - step.from.Z).Unit
	end

	self.callbacks.onStepStarted(bent, step.pressedAt)

	return true
end

function StepMover.requestTile(self: StepMover, target: Coord)
	if self.freeWalk then
		return
	end

	local pressedAt = os.clock()

	if Board.hopsDirectly() then
		self:_queueHop(target, pressedAt)
		return
	end

	local base = self:_baseCoord()

	if base == nil then
		return
	end

	self:clearQueue()

	for _, coord in StepPlanner.pathTo(base, target) do
		table.insert(self.queue, coord)
		table.insert(self.pressTimes, pressedAt)
	end

	self:_advance(pressedAt)
end

-- A dance step on the spot: out toward (dx, dy) in floor directions and back,
-- never leaving the tile. It reports no landing, because nothing judges it.
function StepMover.bounce(self: StepMover, dx: number, dy: number)
	self:_startBounce(dx, dy, false)
end

function StepMover.stumble(self: StepMover)
	self:_startBounce(0, 0, true)
end

-- A dancer keeps facing the audience while hopping, so a step reads as a
-- dance move rather than a walk.
function StepMover.setFacesAudience(self: StepMover, enabled: boolean)
	self.facesAudience = enabled

	if enabled then
		self:faceAudience()
	end
end

function StepMover.faceAudience(self: StepMover)
	local root = getRoot()

	if root == nil or self.current ~= nil or self.dance ~= nil then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, root.Position + AUDIENCE)
end

function StepMover._startBounce(self: StepMover, dx: number, dy: number, stumble: boolean)
	local root = getRoot()

	if root == nil or self.current ~= nil or #self.queue > 0 then
		return
	end

	-- A new step mid-step starts from where the last one began, so quick
	-- presses never walk the character off its spot.
	local origin = if self.dance ~= nil then self.dance.origin else root.Position

	self.dance = {
		dx = dx,
		dz = dy,
		origin = origin,
		startedAt = os.clock(),
		stumble = stumble,
	}
end

function StepMover._updateBounce(self: StepMover, root: BasePart, bounce: Bounce, now: number)
	local duration = if bounce.stumble then InputStrategy.StumbleSeconds else InputStrategy.DanceStepSeconds
	local alpha = (now - bounce.startedAt) / duration

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if alpha >= 1 then
		root.CFrame = CFrame.lookAt(bounce.origin, bounce.origin + AUDIENCE)
		self.dance = nil
		return
	end

	local arc = math.sin(alpha * math.pi)

	if bounce.stumble then
		local tilt = math.sin(alpha * math.pi * 2) * InputStrategy.StumbleTiltRadians
		root.CFrame = CFrame.lookAt(bounce.origin, bounce.origin + AUDIENCE) * CFrame.Angles(0, 0, tilt)
		return
	end

	local position = bounce.origin
		+ Vector3.new(bounce.dx, 0, bounce.dz) * (InputStrategy.DanceStepStuds * arc)
		+ Vector3.new(0, InputStrategy.DanceStepHop * arc, 0)

	root.CFrame = CFrame.lookAt(position, position + AUDIENCE)
end

-- A quick sink on landing and back up, so each step reads as a stomp. A posed
-- dancer bends its knees instead, which keeps its feet on the floor.
function StepMover._updateLanding(self: StepMover, root: BasePart, landing: Landing, now: number)
	local down = InputStrategy.LandDipDownSeconds
	local up = InputStrategy.LandDipUpSeconds
	local age = now - landing.at

	if age >= down + up then
		place(root, landing.base, landing.look)
		self.landing = nil
		return
	end

	local depth = if age < down
		then age / down
		else (1 - (age - down) / up) ^ 2

	local studs = if self.facesAudience then 0 else InputStrategy.LandDipStuds
	place(root, landing.base - Vector3.new(0, depth * studs, 0), landing.look)
end

function StepMover.destroy(self: StepMover)
	if self.connection ~= nil then
		self.connection:Disconnect()
		self.connection = nil
	end

	self:clearQueue()
	self.current = nil
end

-- One press, one hop, however far. Hopping to the tile the player is already
-- on is a step in place, which is how a repeated note is played.
function StepMover._queueHop(self: StepMover, target: Coord, pressedAt: number): boolean
	if not Board.isValidCoord(target.x, target.y) or #self.queue >= InputStrategy.StepBufferSize then
		return false
	end

	table.insert(self.queue, { x = target.x, y = target.y })
	table.insert(self.pressTimes, pressedAt)
	self:_advance(pressedAt)

	return true
end

-- Runs the mover at the press itself rather than on the next frame, so a press
-- with nothing in flight, or one just after the hop in flight was due to land,
-- starts its step this instant.
function StepMover._advance(self: StepMover, now: number)
	self:_update(now)
end

function StepMover._baseCoordBehindQueue(self: StepMover): Coord?
	if self.current ~= nil then
		return self.current.coord
	end

	return self.coord
end

function StepMover._baseCoord(self: StepMover): Coord?
	if self.current ~= nil then
		return self.current.coord
	end

	if self.coord ~= nil then
		return self.coord
	end

	local root = getRoot()

	return if root ~= nil then Board.worldToCoord(root.Position, self.origin) else nil
end

function StepMover._trackCoord(self: StepMover, root: BasePart, now: number)
	local position = root.Position

	if not Board.isWorldPointInside(position, self.origin) then
		self.coord = nil
		return
	end

	local coord = Board.worldToCoord(position, self.origin)
	local previous = self.coord

	if previous == nil or previous.x ~= coord.x or previous.y ~= coord.y then
		self.coord = coord
		self.enteredAt = now
	end
end

-- A step never starts before its press: one pressed after the previous hop was
-- due to land but before a frame noticed would otherwise be backdated.
function StepMover._beginStep(self: StepMover, root: BasePart, from: Vector3, coord: Coord, landedAt: number): Step
	local pressedAt = table.remove(self.pressTimes, 1) or landedAt
	local startedAt = math.max(landedAt, pressedAt)
	local center = Board.coordToWorld(coord.x, coord.y, self.origin)
	local to = Vector3.new(center.X, from.Y, center.Z)
	local heading = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local look = if heading.Magnitude > 0.01 then heading.Unit else currentLook(root)
	local step: Step = {
		from = from,
		to = to,
		look = if self.facesAudience then AUDIENCE else look,
		coord = coord,
		startedAt = startedAt,
		duration = self.stepSeconds,
		pressedAt = pressedAt,
	}

	self.landing = nil
	self.callbacks.onStepStarted(coord, pressedAt)

	return step
end

function StepMover._update(self: StepMover, now: number)
	local root = getRoot()

	if root == nil then
		self.current = nil
		self.coord = nil
		self.landing = nil
		self:clearQueue()
		return
	end

	self:_trackCoord(root, now)

	-- Walking freely: nothing here may place the character, or the dance bounce
	-- would pull them straight back after the server moves them off the stage.
	if self.freeWalk then
		self.current = nil
		self.landing = nil
		return
	end

	if self.current == nil and #self.queue == 0 then
		local landing = self.landing

		if landing ~= nil then
			self:_updateLanding(root, landing, now)
			return
		end

		local dance = self.dance

		if dance ~= nil then
			self:_updateBounce(root, dance, now)
			return
		end

		self.restY = root.Position.Y
		return
	end

	local restY = self.restY or root.Position.Y
	local from = Vector3.new(root.Position.X, restY, root.Position.Z)
	local startedAt = now

	-- A step that starts mid-dip starts from the tile, not the dipped height.
	if self.current == nil and self.landing ~= nil then
		from = self.landing.base
	end

	while true do
		local step: Step
		local inFlight = self.current

		if inFlight ~= nil then
			step = inFlight
		else
			local nextCoord = table.remove(self.queue, 1)

			if nextCoord == nil then
				return
			end

			step = self:_beginStep(root, from, nextCoord, startedAt)
			self.current = step
		end

		local alpha = (now - step.startedAt) / step.duration

		if alpha < 1 then
			local hop = math.sin(alpha * math.pi) * InputStrategy.StepHopHeight
			local travel = 1 - (1 - math.max(alpha, 0)) ^ InputStrategy.StepEaseOutPower
			place(root, step.from:Lerp(step.to, travel) + Vector3.new(0, hop, 0), step.look)
			return
		end

		place(root, step.to, step.look)
		self.current = nil
		self.restY = step.to.Y
		from = step.to
		startedAt = step.startedAt + step.duration
		self.landing = { at = startedAt, base = step.to, look = step.look }
		self.landedAt = startedAt

		-- The landing time is when the step was due to finish, not this frame:
		-- a late frame would otherwise report the player arriving late.
		local landed = self.onStepLanded

		if landed ~= nil then
			landed(step.coord, startedAt, step.pressedAt)
		end
	end
end

return StepMover
