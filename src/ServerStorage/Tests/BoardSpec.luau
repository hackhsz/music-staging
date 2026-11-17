--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local BoardLayouts = require(Shared:WaitForChild("BoardLayouts"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

-- setLayout mutates shared module state, so a test that leaves the wrong layout
-- set would poison every test after it and the running game with it.
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

return {
	["the default layout is the original 5x5"] = function()
		expect(Board.getLayoutId(), "grid5", "default layout")
		expect(Board.Columns, 5, "default columns")
		expect(Board.Rows, 5, "default rows")
	end,

	["each layout reports its own dimensions"] = function()
		withLayout("pad3", function()
			expect(Board.Columns, 3, "pad columns")
			expect(Board.Rows, 3, "pad rows")
		end)

		withLayout("lanes4", function()
			expect(Board.Columns, 4, "lane columns")
			expect(Board.Rows, 1, "lane rows")
		end)

		expect(Board.getLayoutId(), "grid5", "layout restored after the test")
	end,

	["coordinates outside the layout are rejected"] = function()
		withLayout("pad3", function()
			assert(Board.isValidCoord(3, 3), "3,3 is on the pad")
			assert(not Board.isValidCoord(4, 1), "4,1 is off the pad")
		end)

		withLayout("lanes4", function()
			assert(Board.isValidCoord(4, 1), "lane 4 exists")
			assert(not Board.isValidCoord(4, 2), "lanes have one row only")
			assert(not Board.isValidCoord(5, 1), "there is no fifth lane")
		end)
	end,

	["the 5x5 allows single steps in eight directions"] = function()
		assert(Board.isLegalMove(1, 0), "right")
		assert(Board.isLegalMove(0, -1), "up")
		assert(Board.isLegalMove(1, 1), "diagonals are legal on the grid")
		assert(not Board.isLegalMove(0, 0), "standing still is not a move")
		assert(not Board.isLegalMove(2, 0), "two tiles at once is not a step")
	end,

	["the pad allows diagonals, which is what makes it a pad"] = function()
		withLayout("pad3", function()
			assert(Board.isLegalMove(1, 1), "diagonal should be legal")
			assert(Board.isLegalMove(-1, 1), "other diagonal should be legal")
			assert(Board.isLegalMove(1, 0), "orthogonal still legal")
			assert(not Board.isLegalMove(0, 0), "standing still is not a move")
		end)
	end,

	["lanes move sideways only"] = function()
		withLayout("lanes4", function()
			assert(Board.isLegalMove(1, 0), "right")
			assert(Board.isLegalMove(-1, 0), "left")
			assert(not Board.isLegalMove(0, 1), "lanes have nowhere to go forward")
			assert(not Board.isLegalMove(1, 1), "no diagonals in lanes")
		end)
	end,

	["the centre tile is home on the pad and the middle elsewhere"] = function()
		expect(Board.centerCoord().x, 3, "grid5 centre x")
		expect(Board.centerCoord().y, 3, "grid5 centre y")

		withLayout("pad3", function()
			expect(Board.centerCoord().x, 2, "pad centre x")
			expect(Board.centerCoord().y, 2, "pad centre y")
		end)

		withLayout("lanes4", function()
			local center = Board.centerCoord()
			assert(Board.isValidCoord(center.x, center.y), "the lanes' centre must be on the floor")
		end)
	end,

	["only the pad has a home tile"] = function()
		expect(Board.homeCoord(), nil, "the grid has no home")

		withLayout("pad3", function()
			local home = Board.homeCoord()
			assert(home ~= nil, "the pad should have a home")
			expect(home.x, 2, "home x")
			expect(home.y, 2, "home y")
		end)

		withLayout("lanes4", function()
			expect(Board.homeCoord(), nil, "lanes have no home")
		end)
	end,

	["a coordinate survives a trip through world space on every layout"] = function()
		for id in BoardLayouts.Layouts do
			withLayout(id, function()
				for x = 1, Board.Columns do
					for y = 1, Board.Rows do
						local world = Board.coordToWorld(x, y)
						local back = Board.worldToCoord(world)
						expect(back.x, x, id .. " x round trip")
						expect(back.y, y, id .. " y round trip")
					end
				end
			end)
		end
	end,

	["the board's own tiles are inside its bounds"] = function()
		for id in BoardLayouts.Layouts do
			withLayout(id, function()
				for x = 1, Board.Columns do
					for y = 1, Board.Rows do
						assert(Board.isWorldPointInside(Board.coordToWorld(x, y)), id .. " tile should be inside")
					end
				end
			end)
		end
	end,

	["only the new floors hop straight to a tile"] = function()
		assert(not Board.hopsDirectly(), "the grid routes tile by tile")

		withLayout("pad3", function()
			assert(Board.hopsDirectly(), "the pad hops")
		end)

		withLayout("lanes4", function()
			assert(Board.hopsDirectly(), "lanes hop")
		end)
	end,

	["the longest step covers the farthest hop on each floor"] = function()
		expect(Board.longestStep(), Board.TileSize * math.sqrt(2), "grid5 moves one diagonal")

		for _, id in { "pad3", "lanes4" } do
			withLayout(id, function()
				local corner = (Board.coordToWorld(1, 1) - Board.coordToWorld(Board.Columns, Board.Rows)).Magnitude
				assert(math.abs(Board.longestStep() - corner) < 1e-6, id .. " longest step should reach the far corner")
			end)
		end
	end,

	["floors for two players do not overlap on any layout"] = function()
		for id in BoardLayouts.Layouts do
			withLayout(id, function()
				local first = Board.originFor(1, 2)
				local second = Board.originFor(2, 2)
				local gap = math.abs(second.X - first.X)
				assert(gap > Board.Columns * Board.TileSize, id .. " floors overlap")
			end)
		end
	end,
}
