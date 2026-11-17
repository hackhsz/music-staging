--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local StepPlanner = require(Shared:WaitForChild("StepPlanner"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function withLayout(id: string, body: () -> ())
	local previous = Board.getLayoutId()
	Board.setLayout(id)
	local ok, err = pcall(function()
		body()
	end)
	Board.setLayout(previous)

	if not ok then
		error(err, 0)
	end
end

local function assertLegalPath(path: { Board.TileCoord }, from: Board.TileCoord, what: string)
	local previous = from

	for index, coord in path do
		assert(Board.isLegalMove(coord.x - previous.x, coord.y - previous.y), what .. ": illegal move at " .. index)
		assert(Board.isValidCoord(coord.x, coord.y), what .. ": left the floor at " .. index)
		previous = coord
	end
end

return {
	["the grid takes a diagonal step"] = function()
		assert(StepPlanner.offset({ x = 3, y = 3 }, 1, 1) ~= nil, "diagonal")
		assert(StepPlanner.offset({ x = 3, y = 3 }, 1, 0) ~= nil, "orthogonal")
		expect(StepPlanner.offset({ x = 3, y = 3 }, 2, 0), nil, "two tiles")
	end,

	["the grid routes a tap diagonally first"] = function()
		local from = { x = 1, y = 1 }
		local path = StepPlanner.pathTo(from, { x = 3, y = 4 })
		expect(#path, 3, "path length")
		assertLegalPath(path, from, "grid5")
	end,

	["the pad routes a tap diagonally"] = function()
		withLayout("pad3", function()
			local from = { x = 1, y = 1 }
			local path = StepPlanner.pathTo(from, { x = 3, y = 3 })
			expect(#path, 2, "two diagonal steps")
			assertLegalPath(path, from, "pad3")
		end)
	end,

	["lanes never step forward or back"] = function()
		withLayout("lanes4", function()
			expect(StepPlanner.offset({ x = 2, y = 1 }, 0, 1), nil, "forward")
			local from = { x = 1, y = 1 }
			local path = StepPlanner.pathTo(from, { x = 4, y = 1 })
			expect(#path, 3, "three lanes across")
			assertLegalPath(path, from, "lanes4")
		end)
	end,

	["the step buffer stops at its limit"] = function()
		local queue = {}
		assert(StepPlanner.enqueueStep(queue, { x = 3, y = 3 }, 1, 0, 2), "first")
		assert(StepPlanner.enqueueStep(queue, { x = 3, y = 3 }, 1, 0, 2), "second")
		assert(not StepPlanner.enqueueStep(queue, { x = 3, y = 3 }, 1, 0, 2), "third should be refused")
		expect(queue[2].x, 5, "steps chain from the last queued tile")
	end,
}
