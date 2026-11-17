--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DancePoses = require(Shared:WaitForChild("DancePoses"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

local function settle(layer: DancePoses.Layer, target: DancePoses.Pose?, spring: DancePoses.Spring, seconds: number)
	for _ = 1, math.floor(seconds * 60) do
		DancePoses.stepLayer(layer, target, spring, 1 / 60)
	end
end

return {
	["every lane names a move, and no two lanes share one"] = function()
		local seen = {}

		for _, lane in HighwayLanes.Lanes do
			assert(DancePoses.Moves[lane.move] ~= nil, lane.name .. " names an unknown move " .. lane.move)
			assert(seen[lane.move] == nil, lane.name .. " reuses the move " .. lane.move)
			seen[lane.move] = true
		end
	end,

	["every move only poses joints the rig knows"] = function()
		for moveName, pose in DancePoses.Moves do
			for jointName, channels in pose do
				assert(table.find(DancePoses.Joints, jointName) ~= nil, moveName .. " poses unknown joint " .. jointName)
				assert(#channels == 6, moveName .. "." .. jointName .. " should have six channels")
			end
		end
	end,

	["the right point mirrors the left point"] = function()
		local left = DancePoses.Moves.pointLeft
		local right = DancePoses.Moves.pointRight

		assert(near(left.RightShoulder[3], -right.LeftShoulder[3]), "the pointing arm swaps sides")
		assert(near(left.Root[4], -right.Root[4]), "the hips shift the other way")
		assert(near(left.Root[5], right.Root[5]), "the hips sink the same")

		local twice = DancePoses.mirror(right)

		for name, channels in left do
			for i = 1, 6 do
				assert(near(twice[name][i], channels[i]), "mirroring twice should give the pose back: " .. name)
			end
		end
	end,

	["the drop sinks the hips and the reach lifts the arms"] = function()
		assert(DancePoses.Moves.drop.Root[5] < -0.4, "the drop should sink the body")
		assert(DancePoses.Moves.reach.RightShoulder[3] > 2, "the reach should raise the right arm")
		assert(DancePoses.Moves.reach.LeftShoulder[3] < -2, "the reach should raise the left arm")
	end,

	["straight legs do not sink, bent legs do"] = function()
		assert(near(DancePoses.legDrop(0, 0), 0), "straight legs keep the hips up")
		assert(DancePoses.legDrop(0.8, -1.6) > 0.5, "a deep bend sinks the hips")
	end,

	["a snapped pose overshoots, then settles on the target"] = function()
		local layer = DancePoses.newLayer()
		local pose = DancePoses.Moves.reach
		local goal = pose.RightShoulder[3]
		local peak = 0

		for _ = 1, 30 do
			DancePoses.stepLayer(layer, pose, DancePoses.Snap, 1 / 60)
			peak = math.max(peak, layer.value.RightShoulder[3])
		end

		assert(peak > goal, "the snap should overshoot a little")
		assert(peak < goal * 1.4, "the overshoot should stay small")

		settle(layer, pose, DancePoses.Snap, 1)
		assert(near(layer.value.RightShoulder[3], goal, 1e-3), "the snap should settle on the pose")
	end,

	["releasing eases back to rest without crossing it far"] = function()
		local layer = DancePoses.newLayer()
		settle(layer, DancePoses.Moves.reach, DancePoses.Snap, 1)

		local lowest = math.huge

		for _ = 1, 90 do
			DancePoses.stepLayer(layer, nil, DancePoses.Release, 1 / 60)
			lowest = math.min(lowest, layer.value.RightShoulder[3])
		end

		assert(lowest > -0.05, "the release should not swing far past rest")
		assert(near(layer.value.RightShoulder[3], 0, 0.02), "the release should come back to rest")
	end,

	["a kick on a held pose shows a repeat press"] = function()
		local layer = DancePoses.newLayer()
		local pose = DancePoses.Moves.pointLeft
		settle(layer, pose, DancePoses.Snap, 1)

		DancePoses.kick(layer, pose, 7)
		local peak = 0

		for _ = 1, 20 do
			DancePoses.stepLayer(layer, pose, DancePoses.Snap, 1 / 60)
			peak = math.max(peak, layer.value.RightShoulder[3])
		end

		assert(peak > pose.RightShoulder[3] * 1.1, "the kick should push the arm visibly past the pose")
	end,

	["a large frame step stays stable"] = function()
		local value, velocity = 0, 0

		for _ = 1, 10 do
			value, velocity = DancePoses.springStep(value, velocity, 1, DancePoses.Snap, 0.5)
		end

		assert(near(value, 1, 1e-3), "the spring should settle even at a low frame rate")
	end,

	["the groove dips on the beat and is still between beats"] = function()
		assert(near(DancePoses.beatDip(4), 0), "no dip exactly on the downbeat frame")
		assert(DancePoses.beatDip(4.12) > 0.7, "the dip lands just after the beat")
		assert(DancePoses.beatDip(4.95) < 0.05, "the body is back up before the next beat")

		local calm = DancePoses.groove(4.12, false, 1)
		local fever = DancePoses.groove(4.12, true, 1)

		assert(calm.Root[5] < 0, "the groove sinks the hips on the beat")
		assert(fever.Root[5] < calm.Root[5], "Fever grooves deeper")
		assert(fever.RightShoulder[3] > calm.RightShoulder[3], "Fever brings the arms in")
	end,

	["a held pose takes the arms out of the groove"] = function()
		local pose = DancePoses.groove(2.5, true, 0)

		for _, name in { "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" } do
			for i = 1, 6 do
				assert(near(pose[name][i], 0), name .. " should be left to the move")
			end
		end
	end,
}
