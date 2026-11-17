--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DancePoses = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DancePoses"))

export type Bound = {
	joint: Motor6D | AnimationConstraint,
	base: CFrame,
	written: CFrame?,
}
export type Rig = { [string]: Bound }

local REQUIRED_JOINTS = { "Root", "Waist", "LeftShoulder", "RightShoulder" }

-- The R15 joints a dance pose writes, found on a character and written on top
-- of whatever the Animator plays. Shared by the player's dancer and the rival's.
local DanceRig = {}

function DanceRig.channelsToCFrame(c: { number }, weight: number): CFrame
	return CFrame.new(c[4] * weight, c[5] * weight, c[6] * weight)
		* CFrame.Angles(c[1] * weight, c[2] * weight, c[3] * weight)
end

function DanceRig.find(character: Model): Rig?
	local rig: Rig = {}

	for _, descendant in character:GetDescendants() do
		if (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint")) and rig[descendant.Name] == nil then
			if table.find(DancePoses.Joints, descendant.Name) ~= nil then
				local joint = descendant :: Motor6D | AnimationConstraint
				rig[descendant.Name] = { joint = joint, base = joint.Transform, written = nil }
			end
		end
	end

	for _, name in REQUIRED_JOINTS do
		if rig[name] == nil then
			return nil
		end
	end

	return rig
end

-- Where a joint sits on its outer or inner part, for either joint class.
local function pivotOn(joint: Motor6D | AnimationConstraint, inner: boolean): Vector3?
	if joint:IsA("Motor6D") then
		return if inner then joint.C0.Position else joint.C1.Position
	end

	local constraint = joint :: AnimationConstraint
	local attachment = if inner then constraint.Attachment0 else constraint.Attachment1

	return if attachment ~= nil then attachment.Position else nil
end

-- Thigh and shin length in studs, when the rig has a right leg to measure.
function DanceRig.measureLegs(rig: Rig): (number?, number?)
	local hip, knee, ankle = rig.RightHip, rig.RightKnee, rig.RightAnkle

	if hip == nil or knee == nil or ankle == nil then
		return nil, nil
	end

	local hipEnd, kneeTop = pivotOn(hip.joint, false), pivotOn(knee.joint, true)
	local kneeEnd, ankleTop = pivotOn(knee.joint, false), pivotOn(ankle.joint, true)

	if hipEnd == nil or kneeTop == nil or kneeEnd == nil or ankleTop == nil then
		return nil, nil
	end

	return (kneeTop - hipEnd).Magnitude, (ankleTop - kneeEnd).Magnitude
end

-- If the joint still holds what was written last frame, no animation touched
-- it, so the last animated value is reused rather than stacking offsets.
function DanceRig.write(bound: Bound, offset: CFrame)
	local current = bound.joint.Transform

	if bound.written == nil or current ~= bound.written then
		bound.base = current
	end

	-- Both joint classes have Transform, but the checker cannot write through the union.
	local joint: any = bound.joint
	local result = bound.base * offset
	joint.Transform = result
	bound.written = result
end

function DanceRig.writePose(rig: Rig, pose: { [string]: { number } }, weight: number)
	for name, bound in rig do
		local channels = pose[name]

		if channels ~= nil then
			DanceRig.write(bound, DanceRig.channelsToCFrame(channels, weight))
		end
	end
end

-- For a rig nothing else animates: the pose is set over its rest, never
-- stacked on what the joint reads back, which is not exact.
function DanceRig.setPose(rig: Rig, pose: { [string]: { number } }, weight: number)
	for name, bound in rig do
		local channels = pose[name]

		if channels ~= nil then
			local joint: any = bound.joint
			joint.Transform = bound.base * DanceRig.channelsToCFrame(channels, weight)
		end
	end
end

function DanceRig.restore(rig: Rig)
	for _, bound in rig do
		if bound.written ~= nil then
			local joint: any = bound.joint

			if joint.Transform == bound.written then
				joint.Transform = bound.base
			end

			bound.written = nil
		end
	end
end

return DanceRig
