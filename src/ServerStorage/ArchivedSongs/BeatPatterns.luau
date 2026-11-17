--!strict
-- Authored 5x5 pattern vocabulary (DDS_Build_Review §5).
--
-- Two families so charts feel designed, not random:
--   * StepPaths   - one target per beat; consecutive targets are orthogonally
--                   adjacent so a single one-tile move reaches the next beat.
--   * Symmetric   - many tiles lit at once for downbeats / chorus hits; every
--                   shape is mirror-symmetric about the board centre.
--
-- Coordinates are 1-indexed on a 5x5 board (centre is {x = 3, y = 3}).

local BeatPatterns = {}

BeatPatterns.BoardSize = 5

-- One target per beat. Each consecutive pair differs by exactly one tile on a
-- single axis (|dx| + |dy| == 1), matching one-orthogonal-step movement.
BeatPatterns.StepPaths = {
	line = {
		{ x = 1, y = 3 }, { x = 2, y = 3 }, { x = 3, y = 3 }, { x = 4, y = 3 }, { x = 5, y = 3 },
	},
	l_shape = {
		{ x = 1, y = 1 }, { x = 1, y = 2 }, { x = 1, y = 3 }, { x = 2, y = 3 }, { x = 3, y = 3 },
	},
	z_shape = {
		{ x = 1, y = 1 }, { x = 2, y = 1 }, { x = 2, y = 2 }, { x = 3, y = 2 }, { x = 3, y = 3 },
	},
	box_loop = {
		{ x = 2, y = 2 }, { x = 3, y = 2 }, { x = 4, y = 2 }, { x = 4, y = 3 },
		{ x = 4, y = 4 }, { x = 3, y = 4 }, { x = 2, y = 4 }, { x = 2, y = 3 }, { x = 2, y = 2 },
	},
	plus_pulse = {
		{ x = 3, y = 3 }, { x = 2, y = 3 }, { x = 3, y = 3 }, { x = 4, y = 3 },
		{ x = 3, y = 3 }, { x = 3, y = 2 }, { x = 3, y = 3 }, { x = 3, y = 4 },
	},
	diagonal_climb = {
		{ x = 1, y = 1 }, { x = 2, y = 1 }, { x = 2, y = 2 }, { x = 3, y = 2 }, { x = 3, y = 3 },
		{ x = 4, y = 3 }, { x = 4, y = 4 }, { x = 5, y = 4 }, { x = 5, y = 5 },
	},
	snake = {
		{ x = 1, y = 1 }, { x = 2, y = 1 }, { x = 3, y = 1 }, { x = 4, y = 1 }, { x = 5, y = 1 },
		{ x = 5, y = 2 }, { x = 4, y = 2 }, { x = 3, y = 2 }, { x = 2, y = 2 }, { x = 1, y = 2 },
		{ x = 1, y = 3 }, { x = 2, y = 3 }, { x = 3, y = 3 }, { x = 4, y = 3 }, { x = 5, y = 3 },
	},
	spiral = {
		{ x = 1, y = 1 }, { x = 2, y = 1 }, { x = 3, y = 1 }, { x = 4, y = 1 }, { x = 5, y = 1 },
		{ x = 5, y = 2 }, { x = 5, y = 3 }, { x = 5, y = 4 }, { x = 5, y = 5 },
		{ x = 4, y = 5 }, { x = 3, y = 5 }, { x = 2, y = 5 }, { x = 1, y = 5 },
		{ x = 1, y = 4 }, { x = 1, y = 3 }, { x = 1, y = 2 },
		{ x = 2, y = 2 }, { x = 3, y = 2 }, { x = 4, y = 2 }, { x = 4, y = 3 },
		{ x = 4, y = 4 }, { x = 3, y = 4 }, { x = 2, y = 4 }, { x = 2, y = 3 }, { x = 3, y = 3 },
	},
	u_turn = {
		{ x = 2, y = 1 }, { x = 2, y = 2 }, { x = 2, y = 3 }, { x = 3, y = 3 },
		{ x = 4, y = 3 }, { x = 4, y = 2 }, { x = 4, y = 1 },
	},
}

-- Dance figures as moves from wherever the dancer stands, turned and mirrored
-- to fit the pad. A move of two tiles is a jump and needs a whole beat.
BeatPatterns.Moves = {
	pivot = { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 } },
	jacks = { { 1, 0 }, { -1, 0 }, { 1, 0 }, { -1, 0 } },
	box = { { 1, 0 }, { 0, -1 }, { -1, 0 }, { 0, 1 } },
	lturn = { { 0, -1 }, { 0, -1 }, { 1, 0 }, { 1, 0 } },
	stairs = { { 0, -1 }, { 1, 0 }, { 0, -1 }, { 1, 0 } },
	zigzag = { { 1, 0 }, { 0, -1 }, { -1, 0 }, { 0, -1 }, { 1, 0 }, { 0, -1 } },
	wave = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { 1, 0 } },
	run = { { 0, -1 }, { 0, -1 }, { 0, -1 } },
	bigbox = { { 1, 0 }, { 1, 0 }, { 0, -1 }, { 0, -1 }, { -1, 0 }, { -1, 0 }, { 0, 1 }, { 0, 1 } },
	jump = { { 0, -2 } },
	jumpback = { { 0, -2 }, { 0, 2 } },
	diag = { { 1, -1 }, { -1, -1 } },
	widejacks = { { 2, 0 }, { -2, 0 }, { 2, 0 } },
}

-- Which figures each part of a song reaches for, most likely first.
BeatPatterns.EnergyMoves = {
	calm = { "pivot", "jacks", "box", "lturn", "wave" },
	build = { "stairs", "zigzag", "lturn", "run", "wave", "jump" },
	chorus = { "zigzag", "jacks", "bigbox", "stairs", "diag", "jump", "widejacks", "box" },
	drop = { "jacks", "jump", "zigzag", "diag", "widejacks", "jumpback", "bigbox", "run" },
}

-- Many tiles at once. Each set is mirror-symmetric under x -> 6 - x and
-- y -> 6 - y, so it reads cleanly as a downbeat accent.
BeatPatterns.Symmetric = {
	cross = {
		{ x = 3, y = 1 }, { x = 3, y = 2 }, { x = 3, y = 3 }, { x = 3, y = 4 }, { x = 3, y = 5 },
		{ x = 1, y = 3 }, { x = 2, y = 3 }, { x = 4, y = 3 }, { x = 5, y = 3 },
	},
	x_shape = {
		{ x = 1, y = 1 }, { x = 2, y = 2 }, { x = 3, y = 3 }, { x = 4, y = 4 }, { x = 5, y = 5 },
		{ x = 1, y = 5 }, { x = 2, y = 4 }, { x = 4, y = 2 }, { x = 5, y = 1 },
	},
	diamond = {
		{ x = 3, y = 1 }, { x = 2, y = 2 }, { x = 4, y = 2 }, { x = 1, y = 3 }, { x = 5, y = 3 },
		{ x = 2, y = 4 }, { x = 4, y = 4 }, { x = 3, y = 5 },
	},
	border_frame = {
		{ x = 1, y = 1 }, { x = 2, y = 1 }, { x = 3, y = 1 }, { x = 4, y = 1 }, { x = 5, y = 1 },
		{ x = 1, y = 5 }, { x = 2, y = 5 }, { x = 3, y = 5 }, { x = 4, y = 5 }, { x = 5, y = 5 },
		{ x = 1, y = 2 }, { x = 1, y = 3 }, { x = 1, y = 4 },
		{ x = 5, y = 2 }, { x = 5, y = 3 }, { x = 5, y = 4 },
	},
	checkerboard = {
		{ x = 1, y = 1 }, { x = 3, y = 1 }, { x = 5, y = 1 },
		{ x = 2, y = 2 }, { x = 4, y = 2 },
		{ x = 1, y = 3 }, { x = 3, y = 3 }, { x = 5, y = 3 },
		{ x = 2, y = 4 }, { x = 4, y = 4 },
		{ x = 1, y = 5 }, { x = 3, y = 5 }, { x = 5, y = 5 },
	},
	bullseye = {
		{ x = 3, y = 3 },
		{ x = 3, y = 1 }, { x = 2, y = 2 }, { x = 4, y = 2 }, { x = 1, y = 3 }, { x = 5, y = 3 },
		{ x = 2, y = 4 }, { x = 4, y = 4 }, { x = 3, y = 5 },
	},
}

local function inBounds(coord: { x: number, y: number }): boolean
	return coord.x >= 1 and coord.x <= BeatPatterns.BoardSize
		and coord.y >= 1 and coord.y <= BeatPatterns.BoardSize
end

-- True when two tiles are exactly one orthogonal step apart.
function BeatPatterns.isOrthogonallyAdjacent(a: { x: number, y: number }, b: { x: number, y: number }): boolean
	return (math.abs(a.x - b.x) + math.abs(a.y - b.y)) == 1
end

-- Validate a step-path: in-bounds and every consecutive pair adjacent.
function BeatPatterns.isValidStepPath(path: { { x: number, y: number } }): boolean
	for index, coord in path do
		if not inBounds(coord) then
			return false
		end

		if index > 1 and not BeatPatterns.isOrthogonallyAdjacent(path[index - 1], coord) then
			return false
		end
	end

	return true
end

-- Validate a symmetric shape: in-bounds and invariant under both mirrors.
function BeatPatterns.isMirrorSymmetric(shape: { { x: number, y: number } }): boolean
	local present = {}

	for _, coord in shape do
		if not inBounds(coord) then
			return false
		end

		present[coord.x .. ":" .. coord.y] = true
	end

	for _, coord in shape do
		local mirrorX = (BeatPatterns.BoardSize + 1) - coord.x
		local mirrorY = (BeatPatterns.BoardSize + 1) - coord.y

		if not present[mirrorX .. ":" .. coord.y] then
			return false
		end

		if not present[coord.x .. ":" .. mirrorY] then
			return false
		end
	end

	return true
end

-- Turn a step-path into BeatStep entries, one target per beat.
function BeatPatterns.toBeatSteps(path: { { x: number, y: number } }, startBeat: number?, beatStride: number?)
	local beat = startBeat or 1
	local stride = beatStride or 1
	local steps = {}

	for _, coord in path do
		table.insert(steps, { beat = beat, x = coord.x, y = coord.y })
		beat += stride
	end

	return steps
end

return BeatPatterns
