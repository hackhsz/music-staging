--!strict
local DancePoses = {}

-- A joint's offset from its animated pose: rotation x, y, z in radians, then
-- position x, y, z in studs. Only the Root joint uses position.
export type Channels = { number }
export type Pose = { [string]: Channels }
export type Layer = { value: Pose, velocity: Pose }
export type Spring = { frequency: number, damping: number }

local CHANNELS = 6
local MAX_SUBSTEP = 1 / 240
local THIGH_STUDS = 1.2
local SHIN_STUDS = 1.3

DancePoses.Joints = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"LeftAnkle",
	"RightAnkle",
}

-- Under-damped going in, so a pose lands with a little overshoot; near
-- critical coming back, so the return to the groove never wobbles.
DancePoses.Snap = { frequency = 26, damping = 0.45 } :: Spring
DancePoses.Release = { frequency = 9, damping = 0.9 } :: Spring

local function joint(rx: number, ry: number, rz: number, px: number?, py: number?, pz: number?): Channels
	return { rx, ry, rz, px or 0, py or 0, pz or 0 }
end

-- How far the hips sink when the legs bend, so a crouch keeps the feet on the floor.
function DancePoses.legDrop(hip: number, knee: number): number
	return THIGH_STUDS * (1 - math.cos(hip)) + SHIN_STUDS * (1 - math.cos(hip + knee))
end

local function mirrorName(name: string): string
	if string.sub(name, 1, 4) == "Left" then
		return "Right" .. string.sub(name, 5)
	elseif string.sub(name, 1, 5) == "Right" then
		return "Left" .. string.sub(name, 6)
	end

	return name
end

-- The same pose on the other side of the body.
function DancePoses.mirror(pose: Pose): Pose
	local mirrored: Pose = {}

	for name, c in pose do
		mirrored[mirrorName(name)] = { c[1], -c[2], -c[3], -c[4], c[5], c[6] }
	end

	return mirrored
end

function DancePoses.scaled(pose: Pose, factor: number): Pose
	local result: Pose = {}

	for name, c in pose do
		local copy = table.clone(c)

		for i = 1, CHANNELS do
			copy[i] *= factor
		end

		result[name] = copy
	end

	return result
end

function DancePoses.addInto(into: Pose, pose: Pose, weight: number)
	for name, c in pose do
		local target = into[name]

		if target == nil then
			target = table.create(CHANNELS, 0)
			into[name] = target
		end

		for i = 1, CHANNELS do
			target[i] += c[i] * weight
		end
	end
end

-- Joint axes are the character's own: +x is their right, they face -z. They
-- face the audience, so a move toward screen left is toward their right.
local pointLeft: Pose = {
	Root = joint(0, -0.1, -0.12, 0.45, -0.22),
	Waist = joint(0, -0.18, -0.3),
	Neck = joint(0.05, -0.5, -0.12),
	RightShoulder = joint(0.2, 0, 2),
	RightElbow = joint(0.1, 0, 0),
	LeftShoulder = joint(0.5, 0, 0.2),
	LeftElbow = joint(1.2, 0, 0),
	RightHip = joint(0, 0, 0.38),
	LeftHip = joint(0.25, 0, 0),
	LeftKnee = joint(-0.45, 0, 0),
	LeftAnkle = joint(0.2, 0, 0),
}

local cheerHip, cheerKnee = 0.45, -0.9

DancePoses.Moves = {
	pointLeft = pointLeft,
	pointRight = DancePoses.mirror(pointLeft),
	drop = {
		Root = joint(0, 0, 0, 0, -DancePoses.legDrop(0.85, -1.5) - 0.15),
		Waist = joint(-0.2, 0, 0),
		Neck = joint(-0.12, 0, 0),
		RightShoulder = joint(0.2, 0, 0.55),
		LeftShoulder = joint(0.2, 0, -0.55),
		RightHip = joint(0.85, 0, 0.45),
		LeftHip = joint(0.85, 0, -0.45),
		RightKnee = joint(-1.5, 0, 0),
		LeftKnee = joint(-1.5, 0, 0),
		RightAnkle = joint(0.65, 0, 0),
		LeftAnkle = joint(0.65, 0, 0),
	},
	reach = {
		Root = joint(0, 0, 0, 0, 0.15),
		Waist = joint(0.15, 0, 0),
		Neck = joint(0.15, 0, 0),
		RightShoulder = joint(0.15, 0, 2.4),
		LeftShoulder = joint(0.15, 0, -2.4),
		RightElbow = joint(0.2, 0, 0),
		LeftElbow = joint(0.2, 0, 0),
		RightAnkle = joint(-0.3, 0, 0),
		LeftAnkle = joint(-0.3, 0, 0),
	},
	miss = {
		Root = joint(0, 0, 0.06, 0, -DancePoses.legDrop(0.3, -0.5)),
		Waist = joint(-0.42, 0, 0.12),
		Neck = joint(-0.5, 0, 0),
		RightShoulder = joint(0.25, 0, 0.08),
		LeftShoulder = joint(0.25, 0, -0.08),
		RightHip = joint(0.3, 0, 0),
		LeftHip = joint(0.3, 0, 0),
		RightKnee = joint(-0.5, 0, 0),
		LeftKnee = joint(-0.5, 0, 0),
		RightAnkle = joint(0.2, 0, 0),
		LeftAnkle = joint(0.2, 0, 0),
	},
	cheer = {
		Root = joint(0, 0, 0, 0, 0.5),
		Waist = joint(0.15, 0, 0),
		Neck = joint(0.2, 0, 0),
		RightShoulder = joint(0.3, 0, 2.5),
		LeftShoulder = joint(0.3, 0, -2.5),
		RightElbow = joint(0.9, 0, 0),
		LeftElbow = joint(0.9, 0, 0),
		RightHip = joint(cheerHip, 0, 0),
		LeftHip = joint(cheerHip, 0, 0),
		RightKnee = joint(cheerKnee, 0, 0),
		LeftKnee = joint(cheerKnee, 0, 0),
		RightAnkle = joint(-cheerHip - cheerKnee, 0, 0),
		LeftAnkle = joint(-cheerHip - cheerKnee, 0, 0),
	},
} :: { [string]: Pose }

local function legs(pose: Pose, hip: number, knee: number)
	pose.RightHip = joint(hip, 0, 0)
	pose.LeftHip = joint(hip, 0, 0)
	pose.RightKnee = joint(knee, 0, 0)
	pose.LeftKnee = joint(knee, 0, 0)
	pose.RightAnkle = joint(-hip - knee, 0, 0)
	pose.LeftAnkle = joint(-hip - knee, 0, 0)
end

-- 0 off the beat, rising fast to a dip just after it and easing back up, so
-- the body bops on the beat without snapping.
function DancePoses.beatDip(beat: number): number
	local phase = beat % 1
	local attack = math.sin(math.min(phase / 0.12, 1) * math.pi / 2)

	return attack * (1 - phase) ^ 1.5
end

-- The idle groove between presses. armWeight fades the arms out while a move
-- holds them, so the groove never bends a pose out of shape.
function DancePoses.groove(beat: number, fever: boolean, armWeight: number): Pose
	local dip = DancePoses.beatDip(beat)
	local side = math.sin(beat * math.pi)
	local size = if fever then 1.7 else 1
	local hip = 0.35 * size * dip
	local knee = -2 * hip
	local pose: Pose = {
		Root = joint(0, if fever then 0.18 * side else 0, -0.05 * side * size, 0.12 * side * size, -DancePoses.legDrop(hip, knee)),
		Waist = joint(-0.06 * dip * size, if fever then -0.1 * side else 0, 0.07 * side * size),
		Neck = joint(-0.2 * dip * size, 0, -0.06 * side),
	}

	legs(pose, hip, knee)

	if fever then
		local right = if math.floor(beat) % 2 == 0 then dip else 0
		local left = dip - right

		pose.RightShoulder = joint((0.55 + 0.4 * right) * armWeight, 0, (0.5 + 1.5 * right) * armWeight)
		pose.LeftShoulder = joint((0.55 + 0.4 * left) * armWeight, 0, -(0.5 + 1.5 * left) * armWeight)
		pose.RightElbow = joint(1.3 * armWeight, 0, 0)
		pose.LeftElbow = joint(1.3 * armWeight, 0, 0)
	else
		pose.RightShoulder = joint(0.15 * side * armWeight, 0, 0.12 * armWeight)
		pose.LeftShoulder = joint(-0.15 * side * armWeight, 0, -0.12 * armWeight)
		pose.RightElbow = joint((0.35 + 0.25 * dip) * armWeight, 0, 0)
		pose.LeftElbow = joint((0.35 + 0.25 * dip) * armWeight, 0, 0)
	end

	return pose
end

function DancePoses.newLayer(): Layer
	local layer: Layer = { value = {}, velocity = {} }

	for _, name in DancePoses.Joints do
		layer.value[name] = table.create(CHANNELS, 0)
		layer.velocity[name] = table.create(CHANNELS, 0)
	end

	return layer
end

function DancePoses.springStep(
	value: number,
	velocity: number,
	target: number,
	spring: Spring,
	dt: number
): (number, number)
	local steps = math.max(math.ceil(dt / MAX_SUBSTEP), 1)
	local h = dt / steps
	local w = spring.frequency

	for _ = 1, steps do
		velocity += (w * w * (target - value) - 2 * spring.damping * w * velocity) * h
		value += velocity * h
	end

	return value, velocity
end

-- Moves every channel toward the target pose; a joint the pose leaves out
-- goes back to zero.
function DancePoses.stepLayer(layer: Layer, target: Pose?, spring: Spring, dt: number)
	for _, name in DancePoses.Joints do
		local value = layer.value[name]
		local velocity = layer.velocity[name]
		local goal = target and target[name]

		for i = 1, CHANNELS do
			value[i], velocity[i] = DancePoses.springStep(value[i], velocity[i], if goal then goal[i] else 0, spring, dt)
		end
	end
end

-- A push along a pose. Pressing the same lane again leaves the target where it
-- is, so this is what makes the repeat visible.
function DancePoses.kick(layer: Layer, pose: Pose, amount: number)
	DancePoses.addInto(layer.velocity, pose, amount)
end

return DancePoses
