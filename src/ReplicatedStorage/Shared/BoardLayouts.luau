--!strict
-- The shapes the dance floor can take, and how an existing chart is rewritten
-- onto each one.
--
-- The 5x5 floor makes the player solve a routing problem: where am I, where is
-- the target, what is my path. That is a navigation skill, and it is why the
-- music barely matters and why waiting is free. These layouts exist to test
-- whether a different floor turns the beat back into the thing being played.
-- The active one is the Workspace attribute `BoardLayout`, read at song start.
--
-- Pure: no services, no state, so it can be unit-tested without a runtime.

local BoardLayouts = {}

export type Movement = "orthogonal" | "eight" | "horizontal"
-- relative: a press moves one tile from where you are. absolute: every tile has
-- its own key or button, so any note is one press away.
export type Input = "relative" | "absolute"
-- How the approach frame reaches its tile on the beat: closing in around it, or
-- travelling down a lane onto it.
export type Approach = "shrink" | "slide"

export type Layout = {
	id: string,
	columns: number,
	rows: number,
	tileSize: number,
	home: { x: number, y: number }?,
	movement: Movement,
	input: Input,
	approach: Approach,
	description: string,
}

BoardLayouts.Default = "grid5"

BoardLayouts.Layouts = {
	-- Today's floor. Free roaming, so the skill is routing.
	grid5 = {
		id = "grid5",
		columns = 5,
		rows = 5,
		tileSize = 8,
		home = nil,
		movement = "eight",
		input = "relative",
		approach = "shrink",
		description = "The original 5x5 floor. Routing is the challenge.",
	},
	-- A dance pad. Every panel has its own key or button, so a diagonal costs the
	-- same single press as anything else and all that is left is reading the
	-- panel and hitting the beat.
	pad3 = {
		id = "pad3",
		columns = 3,
		rows = 3,
		tileSize = 9,
		home = { x = 2, y = 2 },
		movement = "eight",
		input = "absolute",
		approach = "shrink",
		description = "3x3 pad with a home tile. Direction and timing, no routing.",
	},
	-- Four floor lanes with a note highway behind them, read like any lane game.
	lanes4 = {
		id = "lanes4",
		columns = 4,
		rows = 1,
		tileSize = 9,
		home = nil,
		movement = "horizontal",
		input = "absolute",
		approach = "slide",
		description = "Four lanes across the stage, one key per lane.",
	},
}

function BoardLayouts.get(id: string?): Layout
	local layout = BoardLayouts.Layouts[id or ""]

	return layout or BoardLayouts.Layouts[BoardLayouts.Default]
end

function BoardLayouts.isKnown(id: string?): boolean
	return id ~= nil and BoardLayouts.Layouts[id] ~= nil
end

local function sign(value: number): number
	if value > 0 then
		return 1
	elseif value < 0 then
		return -1
	end

	return 0
end

-- One step of intent, whatever the distance was on the source floor. This is
-- what collapses the authored charts' diagonals into a single legal move.
function BoardLayouts.directionOf(fromX: number, fromY: number, toX: number, toY: number): (number, number)
	return sign(toX - fromX), sign(toY - fromY)
end

function BoardLayouts.laneFor(x: number, sourceColumns: number, columns: number): number
	if sourceColumns <= 1 then
		return 1
	end

	local ratio = (x - 1) / (sourceColumns - 1)

	return math.clamp(math.floor(ratio * (columns - 1) + 0.5) + 1, 1, columns)
end

local function copyStep(step: any, x: number, y: number): any
	local out: any = { beat = step.beat, x = x, y = y }

	if step.type ~= nil and step.type ~= "slide" then
		out.type = step.type
	end

	if step.holdSeconds ~= nil and out.type == "hold" then
		out.holdSeconds = step.holdSeconds
	end

	return out
end

--[[
	Rewrite a chart authored for `sourceColumns` x `sourceRows` onto a layout.

	pad3 keeps the *shape* of the dance rather than the positions: each step
	becomes the direction it moved in, played from the home tile, so a chart full
	of diagonals stays intact instead of becoming L-shaped detours. A step that
	did not move becomes a beat spent on home.

	lanes4 keeps the horizontal motion and drops the rest.

	Slides carry a path of tiles that cannot survive either remap, so they are
	flattened to plain steps rather than shipped broken.
]]
function BoardLayouts.remap(steps: { any }, layoutId: string, sourceColumns: number?, sourceRows: number?): { any }
	local layout = BoardLayouts.get(layoutId)
	local columns = sourceColumns or 5
	local rows = sourceRows or 5

	if layout.id == BoardLayouts.Default then
		return steps
	end

	local out = {}

	if layout.id == "lanes4" then
		for _, step in steps do
			table.insert(out, copyStep(step, BoardLayouts.laneFor(step.x, columns, layout.columns), 1))
		end

		return out
	end

	local home = layout.home or { x = math.ceil(layout.columns / 2), y = math.ceil(layout.rows / 2) }
	local previousX, previousY = math.ceil(columns / 2), math.ceil(rows / 2)

	for _, step in steps do
		local dx, dy = BoardLayouts.directionOf(previousX, previousY, step.x, step.y)
		table.insert(out, copyStep(step, home.x + dx, home.y + dy))
		previousX, previousY = step.x, step.y
	end

	return out
end

return BoardLayouts
