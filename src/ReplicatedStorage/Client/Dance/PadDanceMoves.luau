--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DancePoses = require(Shared:WaitForChild("DancePoses"))
local Ease = require(Shared:WaitForChild("Ease"))

type Pose = DancePoses.Pose
type Layer = DancePoses.Layer
type Spring = DancePoses.Spring

export type Strength = "free" | "hit" | "perfect"

export type Dancer = {
	layer: Layer,
	smooth: Layer,
	target: Pose,
	pose: Pose,
	move: Pose?,
	movedAt: number,
	accent: number,
	activity: number,
	spinAt: number,
	spinDirection: number,
	missAt: number,
	holdUntil: number,
	grooving: boolean,
	bounceAt: number,
	jumpAt: number,
	turned: { number },
	turnFrom: { number },
	turnTo: { number },
	turnAt: number,
	turnHold: number,
	backSide: number,
	strideForward: number,
	strideLeft: number,
	strideLead: number,
	running: boolean,
	thighStuds: number,
	shinStuds: number,
}

local STRENGTH_SCALE = {
	free = 0.8,
	hit = 1,
	perfect = 1.2,
}
local DIAGONAL_SHARE = 0.35
local MILESTONES = { 10, 25, 50, 100 }
local MILESTONE_EVERY_AFTER = 50

local STRIKE_BEATS = 0.5
local STRIKE_MIN_SECONDS = 0.16
local SETTLE_BEATS = 0.75
local SETTLE_SHARE = 0.35
local SETTLE_LEG_SHARE = 0.4
local SETTLE_SPRING: Spring = { frequency = 10, damping = 0.75 }
local ACTIVITY_RATE = 12

local TUCK_HIP = 0.3
local TUCK_KNEE = -0.65
local TUCK_DELAY = 0.2
local SQUASH_HIP = 0.5
local SQUASH_KNEE = -1
local SQUASH_ATTACK_SECONDS = 0.035
local SQUASH_RELEASE_SECONDS = 0.2
-- A landing into a pose that is already low bends the knees less.
local SQUASH_CROUCH_STUDS = 0.6
local SQUASH_CROUCHED_SHARE = 0.3
local RUN_LAND_WEIGHT = 0.4
local RUN_HOP_WEIGHT = 0.45
local MOVE_IN_AIR = 0.3
local LAND_LEAN = 0.3
local FOLLOW_SWING = 0.45
local FOLLOW_FLARE = 0.3
local FOLLOW_SPEED = 12
local FOLLOW_DECAY = 6
local FOLLOW_SECONDS = 1

local BACK_TURN = 0.95
local SIDE_TURN = 0.3
local RUN_SIDE_TURN = 0.8
local FORWARD_DIAGONAL_TURN = 0.2
local LOOK_WAIST = 0.12
local LOOK_NECK = 0.24
local TURNED = 0.25
local TURN_IN_SECONDS = 0.09
local TURN_HOLD_SECONDS = 0.08
local TURN_BACK_SECONDS = 0.3
local RUN_TURN_HOLD_BEATS = 0.6
local STRIDE_REACH = 0.6
local STRIDE_SPREAD = 0.45
local STRIDE_PUSH = 0.35
local STRIDE_KICK = -0.8
local STRIDE_LEAN = 0.15
local STRIDE_ARM_SWING = 0.4
local STRIDE_ARM_OUT = 0.12
-- Every joint follows the assembled pose through this spring, so the layers
-- above can switch on and off within a 0.1 s hop without a joint jumping.
local SMOOTH_SPRING: Spring = { frequency = 36, damping = 1 }
local THIGH_STUDS = 0.92
local SHIN_STUDS = 1.01
local HIP_HALF_WIDTH = 0.5
local FOOT_HALF_LENGTH = 0.5
local FOOT_HALF_WIDTH = 0.5
local ANKLE_ABOVE_SOLE = 0.26
local GROUND_FROM_HOP = 0.5
local LEG_JOINTS = {
	Root = true,
	LeftHip = true,
	RightHip = true,
	LeftKnee = true,
	RightKnee = true,
	LeftAnkle = true,
	RightAnkle = true,
}
local LEGS = {
	[1] = { hip = "RightHip", knee = "RightKnee", ankle = "RightAnkle", shoulder = "RightShoulder" },
	[-1] = { hip = "LeftHip", knee = "LeftKnee", ankle = "LeftAnkle", shoulder = "LeftShoulder" },
}

local SPIN_SECONDS = 0.42
local STUMBLE_SECONDS = 0.6
local STUMBLE_SPEED = 17

local GROOVE_ENERGY = { 1, 1.3, 1.6, 1.85 }
local GROOVE_STANCE = 0.08

local JUMP_SECONDS = 0.36
local JUMP_STUDS = 1.1
local JUMP_TUCK = 0.6
local CLAP_JUMP_COMBO = 25
local RUN_STRIDE_SCALES = { 0.9, 1.1, 1.3 }
local HOLD_GROOVE_PUMP = 0.22

local PadDanceMoves = {}

PadDanceMoves.GrooveArmsCombo = 10
PadDanceMoves.ShoulderGrooveCombo = 25

local function joint(rx: number, ry: number, rz: number, px: number?, py: number?, pz: number?): { number }
	return { rx, ry, rz, px or 0, py or 0, pz or 0 }
end

local function crouch(hip: number, knee: number): number
	return -DancePoses.legDrop(hip, knee)
end

-- Same axes as DancePoses: +x is the dancer's right and they face the
-- audience, so every move here is authored toward screen left (their right)
-- and mirrored for screen right.
local pointSlide: Pose = {
	Root = joint(0, -0.08, -0.08, 0.35, crouch(0.2, -0.4)),
	Waist = joint(0, -0.05, 0),
	Neck = joint(0.1, -0.25, -0.12),
	RightShoulder = joint(0.15, 0, 2.5),
	RightElbow = joint(0.05, 0, 0),
	LeftShoulder = joint(0.1, 0, -0.9),
	LeftElbow = joint(0.15, 0, 0),
	RightHip = joint(0, 0, 0.3),
	RightAnkle = joint(0, 0, -0.3),
	LeftHip = joint(0.35, 0, -0.05),
	LeftKnee = joint(-0.7, 0, 0),
	LeftAnkle = joint(0.35, 0, 0),
}

local airplane: Pose = {
	Root = joint(0, 0, -0.3, 0.3, crouch(0.3, -0.6)),
	Waist = joint(0, 0, -0.1),
	Neck = joint(0, -0.2, 0.25),
	RightShoulder = joint(0, 0, 1.45),
	RightElbow = joint(0.1, 0, 0),
	LeftShoulder = joint(0, 0, -1.45),
	LeftElbow = joint(0.1, 0, 0),
	RightHip = joint(0.3, 0, 0.3),
	RightKnee = joint(-0.6, 0, 0),
	RightAnkle = joint(0.3, 0, -0.3),
	LeftHip = joint(0.1, 0, -0.45),
	LeftKnee = joint(-0.3, 0, 0),
	LeftAnkle = joint(0.2, 0, 0),
}

local starReach: Pose = {
	Root = joint(0, 0, 0, 0, 0.2),
	Waist = joint(0.2, 0, 0),
	Neck = joint(0.25, 0, 0),
	RightShoulder = joint(0.2, 0, 2.6),
	LeftShoulder = joint(0.2, 0, -2.6),
	RightElbow = joint(0.15, 0, 0),
	LeftElbow = joint(0.15, 0, 0),
	RightHip = joint(1, 0, 0),
	RightKnee = joint(-1.4, 0, 0),
	RightAnkle = joint(0.3, 0, 0),
	LeftAnkle = joint(-0.35, 0, 0),
}

local raiseRoof: Pose = {
	Root = joint(0, 0, 0, 0, crouch(0.3, -0.6)),
	Waist = joint(0.15, 0, 0),
	Neck = joint(0.3, 0, 0),
	RightShoulder = joint(0, 0, 2.2),
	LeftShoulder = joint(0, 0, -2.2),
	RightElbow = joint(1.4, 0, 0),
	LeftElbow = joint(1.4, 0, 0),
	RightHip = joint(0.3, 0, 0.12),
	LeftHip = joint(0.3, 0, -0.12),
	RightKnee = joint(-0.6, 0, 0),
	LeftKnee = joint(-0.6, 0, 0),
	RightAnkle = joint(0.3, 0, -0.12),
	LeftAnkle = joint(0.3, 0, 0.12),
}

local slapHip, slapKnee = 0.6, -1.1
local kneeSlap: Pose = {
	Root = joint(0, 0, 0, 0, crouch(slapHip, slapKnee)),
	Waist = joint(-0.3, 0, 0),
	Neck = joint(0.35, 0, 0),
	RightShoulder = joint(0.6, 0, 0.35),
	LeftShoulder = joint(0.6, 0, -0.35),
	RightElbow = joint(0.2, 0, 0),
	LeftElbow = joint(0.2, 0, 0),
	RightHip = joint(slapHip, 0, 0.3),
	LeftHip = joint(slapHip, 0, -0.3),
	RightKnee = joint(slapKnee, 0, 0),
	LeftKnee = joint(slapKnee, 0, 0),
	RightAnkle = joint(-slapHip - slapKnee, 0, -0.3),
	LeftAnkle = joint(-slapHip - slapKnee, 0, 0.3),
}

local powerStomp: Pose = {
	Root = joint(0, 0, 0.08, -0.1, crouch(0.3, -0.6)),
	Waist = joint(-0.1, 0, 0.08),
	Neck = joint(-0.1, 0, 0),
	RightShoulder = joint(0.5, 0, 0.6),
	LeftShoulder = joint(0.5, 0, -0.6),
	RightElbow = joint(1.7, 0, 0),
	LeftElbow = joint(1.7, 0, 0),
	RightHip = joint(1.1, 0, 0.3),
	RightKnee = joint(-1.5, 0, 0),
	RightAnkle = joint(0.3, 0, 0),
	LeftHip = joint(0.3, 0, 0),
	LeftKnee = joint(-0.6, 0, 0),
	LeftAnkle = joint(0.3, 0, 0),
}

local clapHip, clapKnee = 0.2, -0.4
local clapFront: Pose = {
	Root = joint(0, 0, 0, 0, crouch(clapHip, clapKnee)),
	Waist = joint(-0.12, 0, 0),
	Neck = joint(0.2, 0, 0),
	RightShoulder = joint(1.35, 0, -0.5),
	LeftShoulder = joint(1.35, 0, 0.5),
	RightElbow = joint(0.55, 0, 0),
	LeftElbow = joint(0.55, 0, 0),
	RightHip = joint(clapHip, 0, 0),
	LeftHip = joint(clapHip, 0, 0),
	RightKnee = joint(clapKnee, 0, 0),
	LeftKnee = joint(clapKnee, 0, 0),
	RightAnkle = joint(-clapHip - clapKnee, 0, 0),
	LeftAnkle = joint(-clapHip - clapKnee, 0, 0),
}

local dropHip, dropKnee = 0.85, -1.5
local drop: Pose = {
	Root = joint(0, 0, 0, 0, crouch(dropHip, dropKnee)),
	Waist = joint(-0.15, 0, 0),
	Neck = joint(0.1, 0, 0),
	RightShoulder = joint(0.3, 0, 1.3),
	LeftShoulder = joint(0.3, 0, -1.3),
	RightElbow = joint(0.4, 0, 0),
	LeftElbow = joint(0.4, 0, 0),
	RightHip = joint(dropHip, 0, 0.45),
	LeftHip = joint(dropHip, 0, -0.45),
	RightKnee = joint(dropKnee, 0, 0),
	LeftKnee = joint(dropKnee, 0, 0),
	RightAnkle = joint(-dropHip - dropKnee, 0, -0.45),
	LeftAnkle = joint(-dropHip - dropKnee, 0, 0.45),
}

local victory: Pose = {
	Root = joint(0, 0, 0, 0, 0.15),
	Waist = joint(0.25, 0, 0),
	Neck = joint(0.35, 0, 0),
	RightShoulder = joint(0.25, 0, 2.5),
	LeftShoulder = joint(0.25, 0, -2.5),
	RightElbow = joint(0.3, 0, 0),
	LeftElbow = joint(0.3, 0, 0),
	LeftHip = joint(1.1, 0, -0.1),
	LeftKnee = joint(-1.6, 0, 0),
	LeftAnkle = joint(0.4, 0, 0),
	RightAnkle = joint(-0.3, 0, 0),
}

local vogue: Pose = {
	Root = joint(0, 0.2, 0.08, 0.3, crouch(0.15, -0.3)),
	Waist = joint(0.1, 0.12, -0.12),
	Neck = joint(0.2, -0.35, 0.1),
	RightShoulder = joint(0.35, 0, 2.6),
	RightElbow = joint(0.05, 0, 0),
	LeftShoulder = joint(0.2, 0, -0.75),
	LeftElbow = joint(1.8, 0, 0),
	RightHip = joint(0, 0, 0.12),
	RightAnkle = joint(0, 0, -0.12),
	LeftHip = joint(0.35, 0, -0.2),
	LeftKnee = joint(-0.7, 0, 0),
	LeftAnkle = joint(0.35, 0, 0.2),
}

local clapHigh: Pose = {
	Root = joint(0, 0, 0, 0, 0.12),
	Waist = joint(0.2, 0, 0),
	Neck = joint(0.4, 0, 0),
	RightShoulder = joint(2.85, 0, -0.5),
	LeftShoulder = joint(2.85, 0, 0.5),
	RightElbow = joint(0.15, 0, 0),
	LeftElbow = joint(0.15, 0, 0),
	RightAnkle = joint(-0.25, 0, 0),
	LeftAnkle = joint(-0.25, 0, 0),
}

local runHip, runKnee = 0.9, -1.3
local runStride: Pose = {
	Root = joint(-0.12, 0, 0, 0, crouch(0.25, -0.5)),
	Waist = joint(-0.1, 0.1, 0),
	Neck = joint(0.15, -0.1, 0),
	RightShoulder = joint(-0.8, 0, 0.2),
	RightElbow = joint(1.2, 0, 0),
	LeftShoulder = joint(1, 0, -0.2),
	LeftElbow = joint(1.4, 0, 0),
	RightHip = joint(runHip, 0, 0),
	RightKnee = joint(runKnee, 0, 0),
	RightAnkle = joint(0.3, 0, 0),
	LeftHip = joint(-0.35, 0, 0),
	LeftKnee = joint(-0.5, 0, 0),
	LeftAnkle = joint(0.2, 0, 0),
}

local runFinish: Pose = {
	Root = joint(0, 0, 0, 0, 0.2),
	Waist = joint(0.3, 0, 0),
	Neck = joint(0.4, 0, 0),
	RightShoulder = joint(0.4, 0, 2.65),
	LeftShoulder = joint(0.4, 0, -2.65),
	RightElbow = joint(0.1, 0, 0),
	LeftElbow = joint(0.1, 0, 0),
	RightHip = joint(1.2, 0, 0.15),
	RightKnee = joint(-1.7, 0, 0),
	RightAnkle = joint(0.4, 0, 0),
	LeftAnkle = joint(-0.35, 0, 0),
}

local powerHip, powerKnee = 0.45, -0.9
local holdPower: Pose = {
	Root = joint(0, -0.15, 0, 0, crouch(powerHip, powerKnee)),
	Waist = joint(0.05, -0.15, -0.08),
	Neck = joint(0.35, -0.3, 0),
	RightShoulder = joint(0.5, 0, 2.3),
	RightElbow = joint(0.05, 0, 0),
	LeftShoulder = joint(0.2, 0, -0.45),
	LeftElbow = joint(1.9, 0, 0),
	RightHip = joint(powerHip, 0, 0.35),
	LeftHip = joint(powerHip, 0, -0.35),
	RightKnee = joint(powerKnee, 0, 0),
	LeftKnee = joint(powerKnee, 0, 0),
	RightAnkle = joint(-powerHip - powerKnee, 0, -0.35),
	LeftAnkle = joint(-powerHip - powerKnee, 0, 0.35),
}

local holdPop: Pose = {
	Waist = joint(0.25, 0, 0),
	Neck = joint(0.35, 0, 0),
	RightShoulder = joint(0.3, 0, 2.4),
	LeftShoulder = joint(0.3, 0, -2.4),
	RightElbow = joint(0.2, 0, 0),
	LeftElbow = joint(0.2, 0, 0),
	RightAnkle = joint(-0.4, 0, 0),
	LeftAnkle = joint(-0.4, 0, 0),
}

local slumpHip, slumpKnee = 0.4, -0.8
local holdSlump: Pose = {
	Root = joint(0, 0, 0, 0, crouch(slumpHip, slumpKnee)),
	Waist = joint(-0.45, 0, 0.08),
	Neck = joint(-0.45, 0, 0),
	RightShoulder = joint(0.15, 0, -0.1),
	LeftShoulder = joint(0.15, 0, 0.1),
	RightElbow = joint(0.15, 0, 0),
	LeftElbow = joint(0.15, 0, 0),
	RightHip = joint(slumpHip, 0, 0),
	LeftHip = joint(slumpHip, 0, 0),
	RightKnee = joint(slumpKnee, 0, 0),
	LeftKnee = joint(slumpKnee, 0, 0),
	RightAnkle = joint(-slumpHip - slumpKnee, 0, 0),
	LeftAnkle = joint(-slumpHip - slumpKnee, 0, 0),
}

local discoPoint: Pose = {
	Root = joint(0, -0.12, -0.1, 0.3, crouch(0.25, -0.5)),
	Waist = joint(0, -0.1, -0.08),
	Neck = joint(0.3, -0.3, -0.1),
	RightShoulder = joint(0.4, 0, 2.3),
	LeftShoulder = joint(-0.2, 0, -0.35),
	LeftElbow = joint(1.2, 0, 0),
	RightHip = joint(0, 0, 0.3),
	RightAnkle = joint(0, 0, -0.3),
	LeftHip = joint(0.25, 0, -0.05),
	LeftKnee = joint(-0.5, 0, 0),
	LeftAnkle = joint(0.25, 0, 0),
}

local fistPump: Pose = {
	Root = joint(0, 0, 0, 0, 0.15),
	Waist = joint(0.15, 0, 0.1),
	Neck = joint(0.3, 0, 0),
	RightShoulder = joint(2.9, 0, -0.2),
	RightElbow = joint(0.6, 0, 0),
	LeftShoulder = joint(0.3, 0, -0.5),
	LeftElbow = joint(1.6, 0, 0),
	LeftHip = joint(1.2, 0, -0.05),
	LeftKnee = joint(-1.5, 0, 0),
	LeftAnkle = joint(0.3, 0, 0),
	RightAnkle = joint(-0.2, 0, 0),
}

local popHip, popKnee = 0.35, -0.7
local chestPop: Pose = {
	Root = joint(0, 0, 0, 0, crouch(popHip, popKnee)),
	Waist = joint(0.3, 0, 0),
	Neck = joint(-0.15, 0, 0),
	RightShoulder = joint(0.2, 0, 0.9),
	LeftShoulder = joint(0.2, 0, -0.9),
	RightElbow = joint(1.7, 0, 0),
	LeftElbow = joint(1.7, 0, 0),
	RightHip = joint(popHip, 0, 0.2),
	LeftHip = joint(popHip, 0, -0.2),
	RightKnee = joint(popKnee, 0, 0),
	LeftKnee = joint(popKnee, 0, 0),
	RightAnkle = joint(-popHip - popKnee, 0, -0.2),
	LeftAnkle = joint(-popHip - popKnee, 0, 0.2),
}

local shimmyHip, shimmyKnee = 0.3, -0.6
local shoulderShimmy: Pose = {
	Root = joint(0, 0, 0, 0, crouch(shimmyHip, shimmyKnee)),
	Waist = joint(-0.15, 0.25, 0),
	Neck = joint(0.1, -0.3, 0),
	RightShoulder = joint(0.9, 0, 0.4),
	LeftShoulder = joint(0.9, 0, -0.4),
	RightElbow = joint(1.3, 0, 0),
	LeftElbow = joint(1.3, 0, 0),
	RightHip = joint(shimmyHip, 0, 0.1),
	LeftHip = joint(shimmyHip, 0, -0.1),
	RightKnee = joint(shimmyKnee, 0, 0),
	LeftKnee = joint(shimmyKnee, 0, 0),
	RightAnkle = joint(-shimmyHip - shimmyKnee, 0, -0.1),
	LeftAnkle = joint(-shimmyHip - shimmyKnee, 0, 0.1),
}

local stumbleHip, stumbleKnee = 0.3, -0.6
local stumble: Pose = {
	Root = joint(0, 0, 0.1, -0.15, crouch(stumbleHip, stumbleKnee)),
	Waist = joint(0.25, 0, 0.2),
	Neck = joint(-0.35, 0, 0.25),
	RightShoulder = joint(0.4, 0, 1.1),
	LeftShoulder = joint(-0.2, 0, -0.8),
	RightElbow = joint(0.9, 0, 0),
	LeftElbow = joint(0.7, 0, 0),
	RightHip = joint(stumbleHip, 0, 0),
	RightKnee = joint(stumbleKnee, 0, 0),
	RightAnkle = joint(-stumbleHip - stumbleKnee, 0, 0),
	LeftHip = joint(0.6, 0, -0.25),
	LeftKnee = joint(-0.8, 0, 0),
	LeftAnkle = joint(0.2, 0, 0),
}

-- Three variants per direction, cycled so repeated steps don't look canned.
-- dx is screen right, dy is toward the camera.
local BASE_MOVES: { [string]: { Pose } } = {
	["-1,0"] = { pointSlide, airplane, discoPoint },
	["1,0"] = { DancePoses.mirror(pointSlide), DancePoses.mirror(airplane), DancePoses.mirror(discoPoint) },
	["0,-1"] = { starReach, raiseRoof, fistPump },
	["0,1"] = { drop, kneeSlap, chestPop },
	["0,0"] = { powerStomp, clapFront, shoulderShimmy },
}

-- A diagonal is the sideways move with the forward or back move layered in
-- lightly where they share a joint, so two raised arms never add past overhead.
local function blend(across: Pose, along: Pose): Pose
	local result: Pose = {}
	DancePoses.addInto(result, across, 1)

	for name, channels in along do
		DancePoses.addInto(result, { [name] = channels }, if across[name] ~= nil then DIAGONAL_SHARE else 1)
	end

	return result
end

for _, sx in { -1, 1 } do
	for _, sy in { -1, 1 } do
		local across = BASE_MOVES[`{sx},0`]
		local along = BASE_MOVES[`0,{sy}`]
		local diagonals = {}

		for index = 1, math.min(#across, #along) do
			diagonals[index] = blend(across[index], along[index])
		end

		BASE_MOVES[`{sx},{sy}`] = diagonals
	end
end

local function scaledMoves(scale: number): { [string]: { Pose } }
	local byDirection: { [string]: { Pose } } = {}

	for key, variants in BASE_MOVES do
		local scaled = {}

		for index, variant in variants do
			scaled[index] = DancePoses.scaled(variant, scale)
		end

		byDirection[key] = scaled
	end

	return byDirection
end

local MOVES: { [Strength]: { [string]: { Pose } } } = {
	free = scaledMoves(STRENGTH_SCALE.free),
	hit = scaledMoves(STRENGTH_SCALE.hit),
	perfect = scaledMoves(STRENGTH_SCALE.perfect),
}

PadDanceMoves.Flourish = victory
PadDanceMoves.Stumble = stumble
PadDanceMoves.HoldPop = holdPop
PadDanceMoves.HoldSlump = holdSlump

local POSES = { vogue, DancePoses.mirror(vogue) }
local CLAPS = { clapFront, clapHigh }
local RUN_FINISHES = { runFinish, DancePoses.mirror(runFinish) }
local HOLDS = { holdPower, DancePoses.mirror(holdPower) }
local RUN_STRIDES: { { Pose } } = {}

for tier, scale in RUN_STRIDE_SCALES do
	local stride = DancePoses.scaled(runStride, scale)
	RUN_STRIDES[tier] = { stride, DancePoses.mirror(stride) }
end

local function alternate(variants: { Pose }, variant: number): Pose
	return variants[(variant - 1) % #variants + 1]
end

function PadDanceMoves.pickPose(variant: number): Pose
	return alternate(POSES, variant)
end

function PadDanceMoves.pickClap(variant: number): Pose
	return alternate(CLAPS, variant)
end

-- progress runs 0 to 1 along a run; the stride grows toward the end.
function PadDanceMoves.pickRun(variant: number, progress: number?): Pose
	local tier = math.clamp(math.floor((progress or 0.5) * #RUN_STRIDES) + 1, 1, #RUN_STRIDES)

	return alternate(RUN_STRIDES[tier], variant)
end

function PadDanceMoves.pickRunFinish(variant: number): Pose
	return alternate(RUN_FINISHES, variant)
end

function PadDanceMoves.pickHold(variant: number): Pose
	return alternate(HOLDS, variant)
end

function PadDanceMoves.isOverheadClap(variant: number): boolean
	return alternate(CLAPS, variant) == clapHigh
end

function PadDanceMoves.clapJumps(combo: number): boolean
	return combo >= CLAP_JUMP_COMBO
end

function PadDanceMoves.pick(dx: number, dy: number, variant: number, strength: Strength): Pose
	local key = `{math.sign(dx)},{math.sign(dy)}`
	local variants = MOVES[strength][key] or MOVES[strength]["0,0"]

	return alternate(variants, variant)
end

function PadDanceMoves.strengthScale(strength: Strength): number
	return STRENGTH_SCALE[strength]
end

function PadDanceMoves.isMilestone(combo: number): boolean
	if table.find(MILESTONES, combo) ~= nil then
		return true
	end

	return combo > MILESTONES[#MILESTONES] and combo % MILESTONE_EVERY_AFTER == 0
end

function PadDanceMoves.newPose(): Pose
	return DancePoses.newLayer().value
end

function PadDanceMoves.clear(pose: Pose)
	for _, channels in pose do
		for i = 1, #channels do
			channels[i] = 0
		end
	end
end

local function add(pose: Pose, name: string, rx: number, ry: number, rz: number, px: number, py: number)
	local c = pose[name]
	c[1] += rx
	c[2] += ry
	c[3] += rz
	c[4] += px
	c[5] += py
end

local function bendLegs(pose: Pose, hip: number, knee: number)
	local ankle = -hip - knee
	add(pose, "RightHip", hip, 0, 0, 0, 0)
	add(pose, "LeftHip", hip, 0, 0, 0, 0)
	add(pose, "RightKnee", knee, 0, 0, 0, 0)
	add(pose, "LeftKnee", knee, 0, 0, 0, 0)
	add(pose, "RightAnkle", ankle, 0, 0, 0, 0)
	add(pose, "LeftAnkle", ankle, 0, 0, 0, 0)
end

local function addArms(pose: Pose, right: number, left: number, out: number, rightElbow: number, leftElbow: number)
	add(pose, "RightShoulder", right, 0, out, 0, 0)
	add(pose, "LeftShoulder", left, 0, -out, 0, 0)
	add(pose, "RightElbow", rightElbow, 0, 0, 0, 0)
	add(pose, "LeftElbow", leftElbow, 0, 0, 0, 0)
end

local function grooveLevel(combo: number, fever: boolean): number
	if fever then
		return 4
	elseif combo >= PadDanceMoves.ShoulderGrooveCombo then
		return 3
	elseif combo >= PadDanceMoves.GrooveArmsCombo then
		return 2
	end

	return 1
end

-- The groove between steps, written into a reused pose so a frame allocates
-- nothing. The body never stops: a bounce on every beat and a weight shift
-- across every two, growing with the combo from loose arm swings to
-- alternating pumps, a hype stance, and the Fever wave overhead.
function PadDanceMoves.fillGroove(pose: Pose, beat: number, combo: number, fever: boolean, armWeight: number)
	local level = grooveLevel(combo, fever)
	local energy = GROOVE_ENERGY[level]
	local dip = DancePoses.beatDip(if fever then beat * 2 else beat)
	local side = math.sin(beat * math.pi)
	local hip = GROOVE_STANCE + 0.28 * energy * dip
	local knee = -2 * hip
	local relax = 0.12 * energy
	local rightRelax = relax * math.max(-side, 0)
	local leftRelax = relax * math.max(side, 0)

	add(pose, "Root", 0, 0.05 * energy * side, -0.04 * energy * side, 0.14 * energy * side, crouch(hip, knee))
	add(pose, "Waist", -0.05 * energy * dip, -0.07 * energy * side, 0.05 * energy * side, 0, 0)
	add(pose, "Neck", 0.04 - 0.15 * energy * dip, 0, -0.05 * side, 0, 0)
	bendLegs(pose, hip, knee)
	add(pose, "RightHip", rightRelax, 0, 0, 0, 0)
	add(pose, "RightKnee", -2 * rightRelax, 0, 0, 0, 0)
	add(pose, "RightAnkle", rightRelax, 0, 0, 0, 0)
	add(pose, "LeftHip", leftRelax, 0, 0, 0, 0)
	add(pose, "LeftKnee", -2 * leftRelax, 0, 0, 0, 0)
	add(pose, "LeftAnkle", leftRelax, 0, 0, 0, 0)

	local rightTurn = math.floor(beat) % 2 == 0
	local rightPump = if rightTurn then dip else 0
	local leftPump = dip - rightPump
	local w = armWeight

	if level == 1 then
		addArms(pose, 0.25 * side * w, -0.25 * side * w, 0.12 * w, (0.35 + 0.3 * dip) * w, (0.35 + 0.3 * dip) * w)
	elseif level == 2 then
		addArms(
			pose,
			(0.3 + 0.5 * rightPump) * w,
			(0.3 + 0.5 * leftPump) * w,
			0.15 * w,
			(1 + 0.5 * rightPump) * w,
			(1 + 0.5 * leftPump) * w
		)
	elseif level == 3 then
		add(pose, "Waist", 0, 0, 0.1 * (rightPump - leftPump), 0, 0)
		add(pose, "RightShoulder", (0.55 + 0.5 * rightPump) * w, 0, (0.3 + 0.25 * rightPump) * w, 0, 0)
		add(pose, "LeftShoulder", (0.55 + 0.5 * leftPump) * w, 0, -(0.3 + 0.25 * leftPump) * w, 0, 0)
		add(pose, "RightElbow", (1.5 - 0.4 * rightPump) * w, 0, 0, 0, 0)
		add(pose, "LeftElbow", (1.5 - 0.4 * leftPump) * w, 0, 0, 0, 0)
	else
		add(pose, "Waist", 0, 0, 0.08 * (rightPump - leftPump), 0, 0)
		add(pose, "RightShoulder", 0.3 * w, 0, (1.5 + 0.9 * rightPump) * w, 0, 0)
		add(pose, "LeftShoulder", 0.3 * w, 0, -(1.5 + 0.9 * leftPump) * w, 0, 0)
		add(pose, "RightElbow", (0.5 + 0.6 * leftPump) * w, 0, 0, 0, 0)
		add(pose, "LeftElbow", (0.5 + 0.6 * rightPump) * w, 0, 0, 0, 0)
	end
end

function PadDanceMoves.newDancer(): Dancer
	return {
		layer = DancePoses.newLayer(),
		smooth = DancePoses.newLayer(),
		target = PadDanceMoves.newPose(),
		pose = PadDanceMoves.newPose(),
		move = nil,
		movedAt = -math.huge,
		accent = 1,
		activity = 0,
		spinAt = -math.huge,
		spinDirection = 1,
		missAt = -math.huge,
		holdUntil = -math.huge,
		grooving = false,
		bounceAt = -math.huge,
		jumpAt = -math.huge,
		turned = { 0, 0, 0 },
		turnFrom = { 0, 0, 0 },
		turnTo = { 0, 0, 0 },
		turnAt = -math.huge,
		turnHold = 0,
		backSide = 1,
		strideForward = 0,
		strideLeft = 0,
		strideLead = 1,
		running = false,
		thighStuds = THIGH_STUDS,
		shinStuds = SHIN_STUDS,
	}
end

-- The character's own leg lengths, so its feet stay on the floor whatever its body.
function PadDanceMoves.setLegs(dancer: Dancer, thighStuds: number, shinStuds: number)
	dancer.thighStuds = thighStuds
	dancer.shinStuds = shinStuds
end

function PadDanceMoves.reset(dancer: Dancer)
	PadDanceMoves.clear(dancer.layer.value)
	PadDanceMoves.clear(dancer.layer.velocity)
	PadDanceMoves.clear(dancer.smooth.value)
	PadDanceMoves.clear(dancer.smooth.velocity)
	dancer.move = nil
	dancer.movedAt = -math.huge
	dancer.activity = 0
	dancer.spinAt = -math.huge
	dancer.missAt = -math.huge
	dancer.holdUntil = -math.huge
	dancer.grooving = false
	dancer.bounceAt = -math.huge
	dancer.jumpAt = -math.huge

	for i = 1, 3 do
		dancer.turned[i] = 0
		dancer.turnFrom[i] = 0
		dancer.turnTo[i] = 0
	end

	dancer.turnAt = -math.huge
	dancer.strideForward = 0
	dancer.strideLeft = 0
	dancer.running = false
end

-- A new move springs from wherever the last one is, so fast steps flow from
-- pose to pose instead of passing back through standing still.
function PadDanceMoves.strike(dancer: Dancer, move: Pose, accent: number, now: number)
	dancer.move = move
	dancer.movedAt = now
	dancer.accent = accent
	dancer.holdUntil = -math.huge
	dancer.grooving = false
end

-- Strikes the move and keeps it at full weight until released, then settles
-- out like any other move.
function PadDanceMoves.hold(dancer: Dancer, move: Pose, seconds: number, now: number)
	PadDanceMoves.strike(dancer, move, 1, now)
	dancer.holdUntil = now + math.max(seconds, 0)
end

-- A hold that bops on every beat while it lasts.
function PadDanceMoves.holdGroove(dancer: Dancer, move: Pose, seconds: number, now: number)
	PadDanceMoves.hold(dancer, move, seconds, now)
	dancer.grooving = true
end

function PadDanceMoves.bounce(dancer: Dancer, now: number)
	dancer.bounceAt = now
end

function PadDanceMoves.jump(dancer: Dancer, now: number)
	dancer.jumpAt = now
	dancer.bounceAt = now + JUMP_SECONDS
end

function PadDanceMoves.stumble(dancer: Dancer, now: number)
	PadDanceMoves.strike(dancer, stumble, 1, now)
	dancer.missAt = now
end

function PadDanceMoves.spin(dancer: Dancer, direction: number, now: number)
	dancer.spinAt = now
	dancer.spinDirection = if direction < 0 then -1 else 1
end

local function backTurnSide(dancer: Dancer, sx: number): number
	if sx ~= 0 then
		return sx
	elseif math.abs(dancer.turned[1]) > TURNED then
		return math.sign(dancer.turned[1])
	end

	local side = dancer.backSide
	dancer.backSide = -side

	return side
end

-- One hop toward (dx, dy), screen right and toward the camera as in pick. The
-- body turns into the hop and looks where it is going, so a step back is a
-- side-on step over the shoulder instead of a glide backwards. A turn already
-- under way keeps its side, so a run of back steps never spins.
function PadDanceMoves.travel(dancer: Dancer, dx: number, dy: number, run: boolean, beatSeconds: number, now: number)
	local sx, sy = math.sign(dx), math.sign(dy)
	local yaw = 0

	if sy < 0 then
		local side = backTurnSide(dancer, sx)
		yaw = side * BACK_TURN
	elseif sx ~= 0 then
		yaw = sx * (if sy > 0 then FORWARD_DIAGONAL_TURN elseif run then RUN_SIDE_TURN else SIDE_TURN)
		dancer.backSide = sx
	end

	local moving = sx ~= 0 or sy ~= 0
	local heading = if sx == 0 and sy < 0 then math.pi * math.sign(yaw) else math.atan2(sx, sy)
	local look = if moving then heading - yaw else 0

	for i = 1, 3 do
		dancer.turnFrom[i] = dancer.turned[i]
	end

	dancer.turnTo[1] = yaw
	dancer.turnTo[2] = look * LOOK_WAIST
	dancer.turnTo[3] = look * LOOK_NECK
	dancer.turnAt = now
	dancer.turnHold = if run then RUN_TURN_HOLD_BEATS * beatSeconds else TURN_HOLD_SECONDS
	dancer.strideForward = if moving then math.cos(look) else 0
	dancer.strideLeft = if moving then math.sin(look) else 0

	if math.abs(dancer.strideLeft) > 0.3 then
		dancer.strideLead = -math.sign(dancer.strideLeft)
	else
		dancer.strideLead = -dancer.strideLead
	end

	dancer.running = run
end

local function strikeSeconds(beatSeconds: number): number
	return math.max(STRIKE_BEATS * beatSeconds, STRIKE_MIN_SECONDS)
end

local function moveAge(dancer: Dancer, now: number, beatSeconds: number): number
	if dancer.holdUntil <= dancer.movedAt then
		return now - dancer.movedAt
	elseif now < dancer.holdUntil then
		return 0
	end

	return strikeSeconds(beatSeconds) + now - dancer.holdUntil
end

local function moveWeight(age: number, beatSeconds: number): (number, Spring)
	local strike = strikeSeconds(beatSeconds)
	local settle = SETTLE_BEATS * beatSeconds

	if age < strike then
		return 1, DancePoses.Snap
	elseif age < strike + settle then
		local u = (age - strike) / settle
		return SETTLE_SHARE * (1 - u * u), SETTLE_SPRING
	end

	return 0, DancePoses.Release
end

local function squashAmount(sinceLanding: number): number
	if sinceLanding < 0 then
		return 0
	elseif sinceLanding < SQUASH_ATTACK_SECONDS then
		return math.sin(sinceLanding / SQUASH_ATTACK_SECONDS * math.pi / 2)
	end

	local u = (sinceLanding - SQUASH_ATTACK_SECONDS) / SQUASH_RELEASE_SECONDS

	return if u < 1 then (1 - u) ^ 2 else 0
end

local function addSquash(pose: Pose, squash: number)
	if squash <= 0 then
		return
	end

	local hip = SQUASH_HIP * squash
	local knee = SQUASH_KNEE * squash
	bendLegs(pose, hip, knee)
	add(pose, "Root", 0, 0, 0, 0, crouch(hip, knee))
	add(pose, "Waist", -0.12 * squash, 0, 0, 0, 0)
	add(pose, "Neck", 0.08 * squash, 0, 0, 0, 0)
end

local function hopWeight(dancer: Dancer): number
	return if dancer.running then RUN_HOP_WEIGHT else 1
end

local function followThrough(sinceLanding: number): number
	if sinceLanding < 0 or sinceLanding > FOLLOW_SECONDS then
		return 0
	end

	return math.sin(sinceLanding * FOLLOW_SPEED) * math.exp(-sinceLanding * FOLLOW_DECAY)
end

-- Every value springs from where the last turn left it, so quick steps never snap.
local function addTurn(dancer: Dancer, pose: Pose, now: number, hop: number?, landedAt: number)
	local into = Ease.smoothstep((now - dancer.turnAt) / TURN_IN_SECONDS)
	local back = 0

	if hop == nil then
		local settled = math.max(landedAt, dancer.turnAt + TURN_IN_SECONDS) + dancer.turnHold
		back = Ease.smoothstep((now - settled) / TURN_BACK_SECONDS)
	end

	local turned = dancer.turned

	for i = 1, 3 do
		turned[i] = (dancer.turnFrom[i] + (dancer.turnTo[i] - dancer.turnFrom[i]) * into) * (1 - back)
	end

	add(pose, "Root", 0, turned[1], 0, 0, 0)
	add(pose, "Waist", 0, turned[2], 0, 0, 0)
	add(pose, "Neck", 0, turned[3], 0, 0, 0)
end

-- The leg on the side of travel reaches for the new tile while the other
-- pushes off and trails, and the arms swing against the legs.
local function addStride(dancer: Dancer, pose: Pose, hop: number)
	local reach = math.sin(hop * math.pi) * hopWeight(dancer)
	local forward = dancer.strideForward * reach
	local left = dancer.strideLeft * reach
	local lead = LEGS[dancer.strideLead]
	local trail = LEGS[-dancer.strideLead]

	add(pose, lead.hip, STRIDE_REACH * forward, 0, -STRIDE_SPREAD * left, 0, 0)
	add(pose, lead.knee, -0.3 * reach, 0, 0, 0, 0)
	add(pose, trail.hip, -STRIDE_PUSH * forward, 0, 0.15 * left, 0, 0)
	add(pose, trail.knee, STRIDE_KICK * reach, 0, 0, 0, 0)
	add(pose, trail.ankle, 0.3 * reach, 0, 0, 0, 0)
	add(pose, "Waist", -STRIDE_LEAN * forward, 0, STRIDE_LEAN * left, 0, 0)
	add(pose, lead.shoulder, -STRIDE_ARM_SWING * reach, 0, 0, 0, 0)
	add(pose, trail.shoulder, STRIDE_ARM_SWING * reach, 0, 0, 0, 0)
	add(pose, "RightShoulder", 0, 0, STRIDE_ARM_OUT * reach, 0, 0)
	add(pose, "LeftShoulder", 0, 0, -STRIDE_ARM_OUT * reach, 0, 0)
end

-- Weight on every hop: a tuck in the air, and a landing the knees absorb
-- while the torso leans on into it and the arms swing through and settle.
local function addHop(dancer: Dancer, pose: Pose, hop: number?, sinceLanding: number)
	local weight = (if dancer.running then RUN_LAND_WEIGHT else 1) * dancer.accent
	local push = hopWeight(dancer)
	local crouched = math.clamp(-pose.Root[5] / SQUASH_CROUCH_STUDS, 0, 1)
	local land = squashAmount(sinceLanding) * weight * (1 - crouched * (1 - SQUASH_CROUCHED_SHARE))

	if hop ~= nil then
		addSquash(pose, land)

		local tuck = math.sin(math.clamp((hop - TUCK_DELAY) / (1 - TUCK_DELAY), 0, 1) * math.pi) * push
		bendLegs(pose, TUCK_HIP * tuck, TUCK_KNEE * tuck)
		addStride(dancer, pose, hop)
	else
		addSquash(pose, land)
	end

	add(pose, "Waist", -LAND_LEAN * dancer.strideForward * land, 0, LAND_LEAN * dancer.strideLeft * land, 0, 0)

	local follow = followThrough(sinceLanding) * weight
	local swing = FOLLOW_SWING * dancer.strideForward * follow
	local flare = FOLLOW_FLARE * math.abs(follow)
	add(pose, "RightShoulder", swing, 0, flare - FOLLOW_SWING * dancer.strideLeft * follow, 0, 0)
	add(pose, "LeftShoulder", swing, 0, -flare - FOLLOW_SWING * dancer.strideLeft * follow, 0, 0)
end

local function addJump(dancer: Dancer, pose: Pose, now: number)
	local jump = (now - dancer.jumpAt) / JUMP_SECONDS

	if jump >= 0 and jump < 1 then
		local arc = math.sin(jump * math.pi)
		local tuck = JUMP_TUCK * arc
		add(pose, "Root", 0, 0, 0, 0, JUMP_STUDS * arc)
		bendLegs(pose, TUCK_HIP * tuck, TUCK_KNEE * tuck)
		return
	end

	addSquash(pose, squashAmount(now - dancer.bounceAt))
end

local function addHoldGroove(dancer: Dancer, pose: Pose, now: number, beat: number)
	if not dancer.grooving or now >= dancer.holdUntil then
		return
	end

	local pump = HOLD_GROOVE_PUMP * DancePoses.beatDip(beat)
	add(pose, "Waist", -0.5 * pump, 0, 0, 0, 0)
	add(pose, "Neck", -0.9 * pump, 0, 0, 0, 0)
	add(pose, "RightShoulder", pump, 0, 0, 0, 0)
	add(pose, "LeftShoulder", pump, 0, 0, 0, 0)
	add(pose, "RightElbow", 1.5 * pump, 0, 0, 0, 0)
	add(pose, "LeftElbow", 1.5 * pump, 0, 0, 0, 0)
end

local function addSpin(dancer: Dancer, pose: Pose, now: number)
	local spin = (now - dancer.spinAt) / SPIN_SECONDS

	if spin >= 0 and spin < 1 then
		local open = math.sin(spin * math.pi)
		pose.Root[2] += dancer.spinDirection * 2 * math.pi * (1 - (1 - spin) ^ 3)
		add(pose, "RightShoulder", 0, 0, 0.9 * open, 0, 0)
		add(pose, "LeftShoulder", 0, 0, -0.9 * open, 0, 0)
	end
end

local function addStumble(dancer: Dancer, pose: Pose, now: number)
	local missAge = now - dancer.missAt

	if missAge >= 0 and missAge < STUMBLE_SECONDS then
		local fade = 1 - missAge / STUMBLE_SECONDS
		local wobble = math.sin(missAge * STUMBLE_SPEED) * fade
		add(pose, "Waist", 0, 0, 0.18 * wobble, 0, 0)
		add(pose, "Neck", 0, 0.3 * wobble, 0, 0, 0)
		add(pose, "RightShoulder", 0, 0, 0.5 * wobble, 0, 0)
		add(pose, "LeftShoulder", 0, 0, 0.5 * wobble, 0, 0)
	end
end

-- How far above the floor a foot would sit with the hips at rest height: the
-- leg shortens as it bends or swings out, a tilted pelvis raises one hip, and
-- a tipped foot reaches lower than a flat one.
local function footClearance(dancer: Dancer, pose: Pose, side: number): number
	local leg = LEGS[side]
	local hip = pose[leg.hip]
	local knee = pose[leg.knee][1]
	local ankle = pose[leg.ankle]
	local folded = (dancer.thighStuds + dancer.shinStuds * math.cos(knee)) * math.cos(hip[3])
	local reach = folded * math.cos(hip[1]) - dancer.shinStuds * math.sin(knee) * math.sin(hip[1])
	local drop = dancer.thighStuds + dancer.shinStuds - reach
	local pitch = hip[1] + knee + ankle[1]
	local roll = hip[3] + ankle[3] + pose.Root[3]
	local tip = FOOT_HALF_LENGTH * math.abs(math.sin(pitch))
		+ FOOT_HALF_WIDTH * math.abs(math.sin(roll))
		- ANKLE_ABOVE_SOLE * (1 - math.cos(pitch) * math.cos(roll))

	return side * HIP_HALF_WIDTH * math.sin(pose.Root[3]) + drop - tip
end

-- Sets the hip height so the lower foot rests on the floor, whatever the
-- layers did to the legs. In the air it eases in over the descent, so the
-- feet meet the floor as the hop touches down.
local function ground(dancer: Dancer, pose: Pose, hop: number?)
	local planted = -math.min(footClearance(dancer, pose, 1), footClearance(dancer, pose, -1))
	local share = if hop == nil then 1 else Ease.smoothstep((hop - GROUND_FROM_HOP) / (1 - GROUND_FROM_HOP))
	pose.Root[5] += (planted - pose.Root[5]) * share
end

local function copyInto(into: Pose, from: Pose)
	for name, channels in from do
		local target = into[name]

		for i = 1, #channels do
			target[i] = channels[i]
		end
	end
end

-- One frame of the dance. hop is how far through a hop the character is (nil
-- on the ground) and landedAt when it last touched down, both from StepMover.
function PadDanceMoves.update(
	dancer: Dancer,
	now: number,
	dt: number,
	beat: number,
	beatSeconds: number,
	combo: number,
	fever: boolean,
	hop: number?,
	landedAt: number
): Pose
	local move = dancer.move
	local weight, spring = 0, DancePoses.Release

	if move ~= nil then
		weight, spring = moveWeight(moveAge(dancer, now, beatSeconds), beatSeconds)

	end

	local target = dancer.target
	PadDanceMoves.clear(target)

	-- A traveling step strikes its pose as it lands, not while it flies; a
	-- run's stride is the travel itself, so it shows at once. As it settles the
	-- legs let go first, so the dancer stands on both feet while the arms still
	-- show the move.
	if move ~= nil and weight > 0 then
		local gate = if hop ~= nil and not dancer.running then MOVE_IN_AIR + (1 - MOVE_IN_AIR) * hop * hop else 1
		local legs = if weight < 1 then SETTLE_LEG_SHARE else 1

		for name, channels in move do
			local share = weight * gate * (if LEG_JOINTS[name] then legs else 1)
			local into = target[name]

			for i = 1, #channels do
				into[i] += channels[i] * share
			end
		end
	end

	DancePoses.stepLayer(dancer.layer, target, spring, dt)
	dancer.activity += (math.min(weight * 1.6, 1) - dancer.activity) * (1 - math.exp(-ACTIVITY_RATE * dt))

	PadDanceMoves.clear(target)
	PadDanceMoves.fillGroove(target, beat, combo, fever, 1 - dancer.activity)
	DancePoses.addInto(target, dancer.layer.value, 1)
	addTurn(dancer, target, now, hop, landedAt)
	addHop(dancer, target, hop, now - landedAt)
	addHoldGroove(dancer, target, now, beat)
	addStumble(dancer, target, now)
	DancePoses.stepLayer(dancer.smooth, target, SMOOTH_SPRING, dt)

	local pose = dancer.pose
	copyInto(pose, dancer.smooth.value)
	ground(dancer, pose, hop)
	addJump(dancer, pose, now)
	addSpin(dancer, pose, now)

	return pose
end

return PadDanceMoves
