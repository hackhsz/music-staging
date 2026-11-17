--!strict
-- The dance floor's geometry. The shape comes from BoardLayouts, so the same
-- maths serves the 5x5 grid, the 3x3 pad and the four lanes; `setLayout` is
-- called once at song start and nothing else touches the dimensions.

local BoardLayouts = require(script.Parent.BoardLayouts)

local Board = {}

export type TileCoord = {
	x: number,
	y: number,
}

-- Where the dance floor sits in this place: Workspace's DanceFloorOrigin attribute,
-- so a place can put the stage anywhere in its world. Attributes replicate with
-- Workspace itself, so server and client read the same point.
local placedOrigin = workspace:GetAttribute("DanceFloorOrigin")
Board.Origin = if typeof(placedOrigin) == "Vector3" then placedOrigin else Vector3.zero
Board.SlotGap = 16

-- Set by setLayout. Size stays for callers that assume a square floor.
Board.Layout = BoardLayouts.get(BoardLayouts.Default)
Board.Columns = Board.Layout.columns
Board.Rows = Board.Layout.rows
Board.TileSize = Board.Layout.tileSize
Board.Size = Board.Layout.columns
Board.SlotSpacing = Board.Columns * Board.TileSize + Board.SlotGap

function Board.setLayout(id: string?)
	local layout = BoardLayouts.get(id)

	Board.Layout = layout
	Board.Columns = layout.columns
	Board.Rows = layout.rows
	Board.TileSize = layout.tileSize
	Board.Size = layout.columns
	Board.SlotSpacing = Board.Columns * Board.TileSize + Board.SlotGap
end

function Board.getLayoutId(): string
	return Board.Layout.id
end

function Board.hopsDirectly(): boolean
	return Board.Layout.input == "absolute"
end

-- The farthest one step can carry the player, in studs. A direct hop can cross
-- the whole floor; a relative step is one tile, or one diagonal.
function Board.longestStep(): number
	if Board.hopsDirectly() then
		return Board.TileSize * math.sqrt((Board.Columns - 1) ^ 2 + (Board.Rows - 1) ^ 2)
	end

	return if Board.Layout.movement == "eight" then Board.TileSize * math.sqrt(2) else Board.TileSize
end

function Board.homeCoord(): TileCoord?
	local home = Board.Layout.home

	return if home ~= nil then { x = home.x, y = home.y } else nil
end

-- Where a player starts and where the highway's dancer stands: home on a pad,
-- the middle tile otherwise.
function Board.centerCoord(): TileCoord
	return Board.homeCoord() or { x = math.ceil(Board.Columns / 2), y = math.ceil(Board.Rows / 2) }
end

-- Every player dances on a floor of their own. Floors sit side by side along x
-- and are centred on Board.Origin, so one player gets the centre floor, two
-- players get one a side, and a bigger match just widens the row.
function Board.originFor(slot: number, slotCount: number): Vector3
	return Board.Origin + Vector3.new((slot - (slotCount + 1) / 2) * Board.SlotSpacing, 0, 0)
end

function Board.isValidCoord(x: number, y: number): boolean
	return x >= 1 and x <= Board.Columns and y >= 1 and y <= Board.Rows
end

-- Which single steps the current floor allows. The pad needs diagonals or four
-- of its nine tiles are unreachable; lanes only ever move sideways.
function Board.isLegalMove(dx: number, dy: number): boolean
	if dx == 0 and dy == 0 then
		return false
	end

	if math.abs(dx) > 1 or math.abs(dy) > 1 then
		return false
	end

	local movement = Board.Layout.movement

	if movement == "eight" then
		return true
	end

	if movement == "horizontal" then
		return dy == 0
	end

	return dx == 0 or dy == 0
end

-- Single steps apart: a diagonal counts as one where the floor allows it.
function Board.distance(a: TileCoord, b: TileCoord): number
	local dx, dy = math.abs(a.x - b.x), math.abs(a.y - b.y)

	return if Board.Layout.movement == "eight" then math.max(dx, dy) else dx + dy
end

function Board.nearestTile(tiles: { TileCoord }, from: TileCoord): TileCoord
	local best, bestDistance = tiles[1], math.huge

	for _, tile in tiles do
		local distance = Board.distance(tile, from)

		if distance < bestDistance then
			best, bestDistance = tile, distance
		end
	end

	return best
end

function Board.coordToWorld(x: number, y: number, origin: Vector3?): Vector3
	local halfX = (Board.Columns + 1) / 2
	local halfY = (Board.Rows + 1) / 2
	local worldX = (x - halfX) * Board.TileSize
	local worldZ = (y - halfY) * Board.TileSize

	return (origin or Board.Origin) + Vector3.new(worldX, 0, worldZ)
end

function Board.isWorldPointInside(position: Vector3, origin: Vector3?): boolean
	local center = origin or Board.Origin
	local halfWidth = (Board.Columns * Board.TileSize) / 2
	local halfDepth = (Board.Rows * Board.TileSize) / 2

	return position.X >= center.X - halfWidth
		and position.X <= center.X + halfWidth
		and position.Z >= center.Z - halfDepth
		and position.Z <= center.Z + halfDepth
end

function Board.worldToCoord(position: Vector3, origin: Vector3?): TileCoord
	local center = origin or Board.Origin
	local halfX = (Board.Columns + 1) / 2
	local halfY = (Board.Rows + 1) / 2
	local x = math.floor((position.X - center.X) / Board.TileSize + halfX + 0.5)
	local y = math.floor((position.Z - center.Z) / Board.TileSize + halfY + 0.5)

	return {
		x = math.clamp(x, 1, Board.Columns),
		y = math.clamp(y, 1, Board.Rows),
	}
end

return Board
