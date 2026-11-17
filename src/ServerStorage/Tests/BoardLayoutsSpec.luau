--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BoardLayouts = require(Shared:WaitForChild("BoardLayouts"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

-- A fragment of the real authored charts, diagonals and all.
local SOURCE = {
	{ beat = 1, x = 3, y = 3 },
	{ beat = 2, x = 3, y = 4 },
	{ beat = 3, x = 4, y = 4 },
	{ beat = 4, x = 3, y = 5 },
	{ beat = 5, x = 1, y = 3 },
	{ beat = 6, x = 1, y = 3 },
	{ beat = 7, x = 2, y = 2, type = "hold", holdSeconds = 0.35 },
	{ beat = 8, x = 5, y = 5, type = "slide", path = { { x = 4, y = 4 }, { x = 5, y = 5 } } },
}

return {
	["an unknown layout falls back to the 5x5"] = function()
		expect(BoardLayouts.get("nonsense").id, "grid5", "unknown id")
		expect(BoardLayouts.get(nil).id, "grid5", "nil id")
		expect(BoardLayouts.isKnown("pad3"), true, "pad3 is known")
		expect(BoardLayouts.isKnown("nope"), false, "nope is not known")
	end,

	["the 5x5 layout returns the chart untouched"] = function()
		local out = BoardLayouts.remap(SOURCE, "grid5", 5, 5)
		expect(out, SOURCE, "grid5 should not copy or alter the chart")
	end,

	["every step keeps its beat and the chart keeps its length"] = function()
		for _, id in { "pad3", "lanes4" } do
			local out = BoardLayouts.remap(SOURCE, id, 5, 5)
			expect(#out, #SOURCE, id .. " step count")

			for index, step in out do
				expect(step.beat, SOURCE[index].beat, id .. " beat at index " .. index)
			end
		end
	end,

	["pad3 puts every target one step from home"] = function()
		local out = BoardLayouts.remap(SOURCE, "pad3", 5, 5)
		local home = BoardLayouts.get("pad3").home

		for index, step in out do
			local dx = math.abs(step.x - home.x)
			local dy = math.abs(step.y - home.y)
			assert(dx <= 1 and dy <= 1, string.format("step %d is more than one step from home", index))
			assert(step.x >= 1 and step.x <= 3 and step.y >= 1 and step.y <= 3, "step " .. index .. " left the pad")
		end
	end,

	["pad3 turns a source diagonal into one diagonal step"] = function()
		-- beat 4 moves from (4,4) to (3,5): left and down at once. On the 5x5
		-- that needed two orthogonal moves; on the pad it is a single step.
		local out = BoardLayouts.remap(SOURCE, "pad3", 5, 5)
		local home = BoardLayouts.get("pad3").home
		local step = out[4]
		expect(step.x, home.x - 1, "diagonal x")
		expect(step.y, home.y + 1, "diagonal y")
	end,

	["pad3 spends a beat on home when the source did not move"] = function()
		-- beats 5 and 6 are both (1,3), so the sixth step has no direction.
		local out = BoardLayouts.remap(SOURCE, "pad3", 5, 5)
		local home = BoardLayouts.get("pad3").home
		expect(out[6].x, home.x, "stay step x")
		expect(out[6].y, home.y, "stay step y")
	end,

	["lanes4 flattens to a single row inside the lane count"] = function()
		local out = BoardLayouts.remap(SOURCE, "lanes4", 5, 5)

		for index, step in out do
			expect(step.y, 1, "lane row at index " .. index)
			assert(step.x >= 1 and step.x <= 4, "lane out of range at index " .. index)
		end
	end,

	["lanes map the ends of the source floor to the ends of the lanes"] = function()
		expect(BoardLayouts.laneFor(1, 5, 4), 1, "left edge")
		expect(BoardLayouts.laneFor(5, 5, 4), 4, "right edge")
		assert(BoardLayouts.laneFor(3, 5, 4) > 1, "middle should not collapse to the left edge")
		assert(BoardLayouts.laneFor(3, 5, 4) < 4, "middle should not collapse to the right edge")
	end,

	["lane mapping never leaves the board for any source column"] = function()
		for x = 1, 5 do
			local lane = BoardLayouts.laneFor(x, 5, 4)
			assert(lane >= 1 and lane <= 4, "lane out of range for x=" .. x)
		end
	end,

	["holds survive the remap and slides are flattened"] = function()
		for _, id in { "pad3", "lanes4" } do
			local out = BoardLayouts.remap(SOURCE, id, 5, 5)
			expect(out[7].type, "hold", id .. " should keep the hold")
			expect(out[7].holdSeconds, 0.35, id .. " should keep the hold length")
			-- A slide's path cannot survive either remap, so it must not ship as
			-- a slide with a stale path.
			expect(out[8].type, nil, id .. " should flatten the slide")
			expect(out[8].path, nil, id .. " should drop the stale path")
		end
	end,

	["the new floors take one press per note, the grid keeps routing"] = function()
		expect(BoardLayouts.get("grid5").input, "relative", "grid5 input")
		expect(BoardLayouts.get("pad3").input, "absolute", "pad3 input")
		expect(BoardLayouts.get("lanes4").input, "absolute", "lanes4 input")
		expect(BoardLayouts.get("lanes4").approach, "slide", "lanes read like a highway")
		expect(BoardLayouts.get("pad3").approach, "shrink", "the pad closes frames in")
	end,

	["directionOf reports one step of intent, not the distance"] = function()
		local dx, dy = BoardLayouts.directionOf(1, 1, 5, 5)
		expect(dx, 1, "far diagonal dx")
		expect(dy, 1, "far diagonal dy")

		local sx, sy = BoardLayouts.directionOf(3, 3, 3, 3)
		expect(sx, 0, "no move dx")
		expect(sy, 0, "no move dy")
	end,
}
