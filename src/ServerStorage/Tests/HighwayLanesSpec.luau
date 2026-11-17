--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BoardLayouts = require(Shared:WaitForChild("BoardLayouts"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))

return {
	["there is one lane per column of the lane chart"] = function()
		assert(HighwayLanes.Count == BoardLayouts.get("lanes4").columns, "lane count should match the lane remap")
	end,

	["every lane steps exactly one tile, and no two lanes step the same way"] = function()
		local seen = {}

		for index, lane in HighwayLanes.Lanes do
			local reach = math.abs(lane.step.x) + math.abs(lane.step.y)
			assert(reach == 1, lane.name .. " should step one tile")

			local key = lane.step.x .. "," .. lane.step.y
			assert(seen[key] == nil, lane.name .. " steps the same way as lane " .. tostring(seen[key]))
			seen[key] = index
		end
	end,

	["every lane's arrow points the way its dancer steps"] = function()
		for _, lane in HighwayLanes.Lanes do
			-- The image points up the screen; turned clockwise by its rotation it
			-- must point the way the dancer steps, where down the screen is +y,
			-- toward the audience.
			local radians = math.rad(lane.rotation)
			local x = math.floor(math.sin(radians) + 0.5)
			local y = -math.floor(math.cos(radians) + 0.5)
			assert(x == lane.step.x and y == lane.step.y, lane.name .. "'s arrow and step disagree")
		end
	end,

	["an unknown lane falls back instead of erroring"] = function()
		assert(HighwayLanes.get(99) == HighwayLanes.Lanes[1], "unknown lane should fall back to the first")
		assert(#HighwayLanes.labels() == HighwayLanes.Count, "one label per lane")
	end,
}
