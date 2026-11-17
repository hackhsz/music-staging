--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local InputStrategy = require(Shared:WaitForChild("InputStrategy"))

type Coord = Board.TileCoord

type Callbacks = {
	onStep: (dx: number, dy: number) -> (),
	onBendStep: (dx: number, dy: number) -> (),
	onTapTile: (coord: Coord) -> (),
	onPressLane: (lane: number) -> (),
	onReleaseLane: (lane: number) -> (),
	onClap: () -> (),
	needsInput: () -> boolean,
	getOrigin: () -> Vector3,
}

type Held = {
	id: string,
	dx: number,
	dy: number,
	since: number,
	chorded: boolean,
}

type Fields = {
	callbacks: Callbacks,
	held: { Held },
	connections: { RBXScriptConnection },
	laneMode: boolean,
	holdRepeat: boolean,
}

local InputController = {}
InputController.__index = InputController

export type InputController = typeof(setmetatable({} :: Fields, InputController))

local STICK_ID = "stick"
local PAD_ID = "pad"

local DIRECTION_DELTAS: { [string]: { number } } = {
	up = { 0, -1 },
	down = { 0, 1 },
	left = { -1, 0 },
	right = { 1, 0 },
}
-- The arrows and the left stick always step, so no binding can lock a player out.
local FIXED_DIRECTION_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.Right] = "right",
}
-- The Settings window's bindings per device, which SettingsController sets.
local boundKeys: { [string]: { [string]: Enum.KeyCode } } = {
	keyboard = {
		up = Enum.KeyCode.W,
		down = Enum.KeyCode.S,
		left = Enum.KeyCode.A,
		right = Enum.KeyCode.D,
		clap = Enum.KeyCode.Space,
	},
	gamepad = {
		up = Enum.KeyCode.DPadUp,
		down = Enum.KeyCode.DPadDown,
		left = Enum.KeyCode.DPadLeft,
		right = Enum.KeyCode.DPadRight,
		clap = Enum.KeyCode.ButtonX,
	},
}
local floorTap = true

local KEY_TO_DELTA: { [Enum.KeyCode]: { number } } = {}

-- On absolute layouts every tile has its own key, so a note is one press. Keys
-- not listed here keep their relative meaning from KEY_TO_DELTA.
local TILE_KEYS: { [string]: { [Enum.KeyCode]: { number } } } = {
	pad3 = {
		[Enum.KeyCode.Q] = { 1, 1 },
		[Enum.KeyCode.W] = { 2, 1 },
		[Enum.KeyCode.E] = { 3, 1 },
		[Enum.KeyCode.A] = { 1, 2 },
		[Enum.KeyCode.S] = { 2, 2 },
		[Enum.KeyCode.D] = { 3, 2 },
		[Enum.KeyCode.Z] = { 1, 3 },
		[Enum.KeyCode.X] = { 2, 3 },
		[Enum.KeyCode.C] = { 3, 3 },
		[Enum.KeyCode.KeypadSeven] = { 1, 1 },
		[Enum.KeyCode.KeypadEight] = { 2, 1 },
		[Enum.KeyCode.KeypadNine] = { 3, 1 },
		[Enum.KeyCode.KeypadFour] = { 1, 2 },
		[Enum.KeyCode.KeypadFive] = { 2, 2 },
		[Enum.KeyCode.KeypadSix] = { 3, 2 },
		[Enum.KeyCode.KeypadOne] = { 1, 3 },
		[Enum.KeyCode.KeypadTwo] = { 2, 3 },
		[Enum.KeyCode.KeypadThree] = { 3, 3 },
		[Enum.KeyCode.ButtonA] = { 2, 2 },
	},
	lanes4 = {
		[Enum.KeyCode.D] = { 1, 1 },
		[Enum.KeyCode.F] = { 2, 1 },
		[Enum.KeyCode.J] = { 3, 1 },
		[Enum.KeyCode.K] = { 4, 1 },
		[Enum.KeyCode.Left] = { 1, 1 },
		[Enum.KeyCode.Down] = { 2, 1 },
		[Enum.KeyCode.Up] = { 3, 1 },
		[Enum.KeyCode.Right] = { 4, 1 },
		[Enum.KeyCode.DPadLeft] = { 1, 1 },
		[Enum.KeyCode.DPadDown] = { 2, 1 },
		[Enum.KeyCode.DPadUp] = { 3, 1 },
		[Enum.KeyCode.DPadRight] = { 4, 1 },
	},
}

-- The highway's four lanes are left, down, up and right arrows, played the way
-- Friday Night Funkin' plays them: W A S D or the arrow keys, each key meaning
-- its own direction.
local LANE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.A] = 1,
	[Enum.KeyCode.Left] = 1,
	[Enum.KeyCode.DPadLeft] = 1,
	[Enum.KeyCode.ButtonX] = 1,
	[Enum.KeyCode.S] = 2,
	[Enum.KeyCode.Down] = 2,
	[Enum.KeyCode.DPadDown] = 2,
	[Enum.KeyCode.ButtonA] = 2,
	[Enum.KeyCode.W] = 3,
	[Enum.KeyCode.Up] = 3,
	[Enum.KeyCode.DPadUp] = 3,
	[Enum.KeyCode.ButtonY] = 3,
	[Enum.KeyCode.D] = 4,
	[Enum.KeyCode.Right] = 4,
	[Enum.KeyCode.DPadRight] = 4,
	[Enum.KeyCode.ButtonB] = 4,
}

local CLAP_KEYS: { [Enum.KeyCode]: boolean } = {}

local function rebuildKeys()
	table.clear(KEY_TO_DELTA)
	table.clear(CLAP_KEYS)

	for key, direction in FIXED_DIRECTION_KEYS do
		KEY_TO_DELTA[key] = DIRECTION_DELTAS[direction]
	end

	for _, keys in boundKeys do
		for direction, delta in DIRECTION_DELTAS do
			KEY_TO_DELTA[keys[direction]] = delta
		end

		CLAP_KEYS[keys.clap] = true
	end
end

rebuildKeys()

local function tileForKey(key: Enum.KeyCode): Coord?
	local keys = TILE_KEYS[Board.getLayoutId()]
	local tile = keys and keys[key]

	return if tile ~= nil then { x = tile[1], y = tile[2] } else nil
end

function InputController.new(callbacks: Callbacks): InputController
	local fields: Fields = {
		callbacks = callbacks,
		held = {},
		connections = {},
		laneMode = false,
		holdRepeat = false,
	}
	local self = setmetatable(fields, InputController)

	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			-- Space can arrive marked processed by the default jump binding, so a clap
			-- key is only refused while typing.
			if CLAP_KEYS[input.KeyCode] and not self.laneMode then
				if UserInputService:GetFocusedTextBox() == nil then
					self.callbacks.onClap()
				end
			elseif not gameProcessed then
				self:_onInputBegan(input)
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input)
			local lane = if self.laneMode then LANE_KEYS[input.KeyCode] else nil

			if lane ~= nil then
				self.callbacks.onReleaseLane(lane)
			end

			if KEY_TO_DELTA[input.KeyCode] ~= nil then
				self:_release(tostring(input.KeyCode))
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				self:_onStick(input.Position)
			end
		end)
	)
	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function()
			self:_repeatHeld(os.clock())
		end)
	)

	return self
end

-- action is "up", "down", "left", "right" or "clap"; device is "keyboard" or "gamepad".
function InputController.setBinding(action: string, key: Enum.KeyCode, device: string?)
	local keys = boundKeys[device or "keyboard"]

	if keys == nil or keys[action] == nil then
		return
	end

	keys[action] = key
	rebuildKeys()
end

-- Tapping or clicking a floor tile walks to it unless the player turned it off.
function InputController.setFloorTap(enabled: boolean)
	floorTap = enabled
end

function InputController.isStepKey(key: Enum.KeyCode): boolean
	return tileForKey(key) ~= nil or KEY_TO_DELTA[key] ~= nil or LANE_KEYS[key] ~= nil or CLAP_KEYS[key] == true
end

-- In lane mode every key and pad button is a lane press and nothing moves the
-- character, which only dances on the spot.
function InputController.setLaneMode(self: InputController, enabled: boolean)
	self.laneMode = enabled
	table.clear(self.held)
end

-- The on-screen grid: a lane in lane mode, otherwise the floor tile it mirrors.
function InputController.pressPadTile(self: InputController, x: number, y: number)
	if self.laneMode then
		self.callbacks.onPressLane(x)
	else
		self.callbacks.onTapTile({ x = x, y = y })
	end
end

function InputController.pressClap(self: InputController)
	if not self.laneMode then
		self.callbacks.onClap()
	end
end

function InputController.setPadDirection(self: InputController, dx: number?, dy: number?)
	if self.laneMode then
		return
	end

	if dx == nil or dy == nil then
		for index = #self.held, 1, -1 do
			if string.sub(self.held[index].id, 1, #PAD_ID) == PAD_ID then
				table.remove(self.held, index)
			end
		end

		return
	end

	-- One entry per key, so two fingers landing together chord into a diagonal.
	self:_press(`{PAD_ID}{dx},{dy}`, dx, dy)
end

function InputController.coordFromScreenPoint(self: InputController, screenX: number, screenY: number): Coord?
	local camera = Workspace.CurrentCamera

	if camera == nil then
		return nil
	end

	local ray = camera:ViewportPointToRay(screenX, screenY)

	if math.abs(ray.Direction.Y) < 0.001 then
		return nil
	end

	local origin = self.callbacks.getOrigin()
	local distance = (origin.Y - ray.Origin.Y) / ray.Direction.Y

	if distance < 0 then
		return nil
	end

	local worldPoint = ray.Origin + ray.Direction * distance

	if not Board.isWorldPointInside(worldPoint, origin) then
		return nil
	end

	local coord = Board.worldToCoord(worldPoint, origin)

	if not Board.isValidCoord(coord.x, coord.y) then
		return nil
	end

	return coord
end

function InputController.destroy(self: InputController)
	for _, connection in self.connections do
		connection:Disconnect()
	end

	table.clear(self.connections)
	table.clear(self.held)
end

function InputController._onInputBegan(self: InputController, input: InputObject)
	if self.laneMode then
		local lane = LANE_KEYS[input.KeyCode]

		if lane ~= nil then
			self.callbacks.onPressLane(lane)
		end

		return
	end

	local tile = tileForKey(input.KeyCode)

	if tile ~= nil then
		self.callbacks.onTapTile(tile)
		return
	end

	local delta = KEY_TO_DELTA[input.KeyCode]

	if delta ~= nil then
		self:_press(tostring(input.KeyCode), delta[1], delta[2])
		return
	end

	local tapped = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch

	if not tapped or not floorTap then
		return
	end

	local coord = self:coordFromScreenPoint(input.Position.X, input.Position.Y)

	if coord ~= nil then
		self.callbacks.onTapTile(coord)
	end
end

function InputController._onStick(self: InputController, position: Vector3)
	if self.laneMode then
		return
	end

	local threshold = InputStrategy.StickThreshold

	if math.abs(position.X) < threshold and math.abs(position.Y) < threshold then
		self:_release(STICK_ID)
		return
	end

	local dx = 0
	local dy = 0

	if Board.isLegalMove(1, 1) then
		dx = if math.abs(position.X) >= threshold then (if position.X > 0 then 1 else -1) else 0
		dy = if math.abs(position.Y) >= threshold then (if position.Y > 0 then -1 else 1) else 0
	elseif math.abs(position.X) > math.abs(position.Y) then
		dx = if position.X > 0 then 1 else -1
	else
		dy = if position.Y > 0 then -1 else 1
	end

	for _, held in self.held do
		if held.id == STICK_ID and held.dx == dx and held.dy == dy then
			return
		end
	end

	self:_press(STICK_ID, dx, dy)
end

function InputController._press(self: InputController, id: string, dx: number, dy: number)
	self:_release(id)
	local now = os.clock()
	local partner = self:_chordPartner(dx, dy, now)
	table.insert(self.held, { id = id, dx = dx, dy = dy, since = now, chorded = partner ~= nil })

	if partner ~= nil then
		partner.chorded = true
		self.callbacks.onBendStep(dx, dy)
	else
		self.callbacks.onStep(dx, dy)
	end
end

-- The key pressed just before this one on the other axis, which makes the two a diagonal.
function InputController._chordPartner(self: InputController, dx: number, dy: number, now: number): Held?
	if not Board.isLegalMove(1, 1) or (dx ~= 0 and dy ~= 0) then
		return nil
	end

	for index = #self.held, 1, -1 do
		local held = self.held[index]
		local across = (dx ~= 0 and held.dx == 0 and held.dy ~= 0) or (dy ~= 0 and held.dy == 0 and held.dx ~= 0)

		if across and not held.chorded and now - held.since <= InputStrategy.ChordSeconds then
			return held
		end
	end

	return nil
end

-- Where diagonals are legal, two keys held down repeat as the diagonal.
function InputController._withHeldKeys(self: InputController, dx: number, dy: number): (number, number)
	if not Board.isLegalMove(1, 1) then
		return dx, dy
	end

	local combinedX, combinedY = dx, dy

	for _, held in self.held do
		if combinedX == 0 then
			combinedX = held.dx
		end

		if combinedY == 0 then
			combinedY = held.dy
		end
	end

	return combinedX, combinedY
end

function InputController._release(self: InputController, id: string)
	for index = #self.held, 1, -1 do
		if self.held[index].id == id then
			table.remove(self.held, index)
		end
	end
end

function InputController._repeatHeld(self: InputController, now: number)
	-- On a floor where every press is a note, a held key repeating would stomp
	-- the tile over and over and play repeated notes by itself.
	if Board.hopsDirectly() or self.laneMode or not self.holdRepeat then
		return
	end

	local newest = self.held[#self.held]

	if newest == nil or now - newest.since < InputStrategy.HoldRepeatDelaySeconds then
		return
	end

	if self.callbacks.needsInput() then
		self.callbacks.onStep(self:_withHeldKeys(newest.dx, newest.dy))
	end
end

return InputController
