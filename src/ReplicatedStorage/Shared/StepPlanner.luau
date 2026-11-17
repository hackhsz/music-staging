--!strict
local Board = require(script.Parent.Board)

type Coord = Board.TileCoord

local StepPlanner = {}

local function sign(value: number): number
	return if value > 0 then 1 elseif value < 0 then -1 else 0
end

function StepPlanner.offset(from: Coord, dx: number, dy: number): Coord?
	if not Board.isLegalMove(dx, dy) then
		return nil
	end

	local x = from.x + dx
	local y = from.y + dy

	if not Board.isValidCoord(x, y) then
		return nil
	end

	return { x = x, y = y }
end

-- One legal step at a time: diagonals where the layout allows them, and no
-- forward motion at all on lanes.
function StepPlanner.pathTo(from: Coord, to: Coord): { Coord }
	local path = {}
	local x = from.x
	local y = from.y
	local diagonal = Board.isLegalMove(1, 1)
	local targetY = if Board.isLegalMove(0, 1) then to.y else y

	while x ~= to.x or y ~= targetY do
		local dx = sign(to.x - x)
		local dy = sign(targetY - y)

		if dx ~= 0 and not diagonal then
			dy = 0
		end

		x += dx
		y += dy
		table.insert(path, { x = x, y = y })
	end

	return path
end

function StepPlanner.enqueueStep(queue: { Coord }, base: Coord, dx: number, dy: number, limit: number): boolean
	if #queue >= limit then
		return false
	end

	local nextCoord = StepPlanner.offset(queue[#queue] or base, dx, dy)

	if nextCoord == nil then
		return false
	end

	table.insert(queue, nextCoord)

	return true
end

return StepPlanner
