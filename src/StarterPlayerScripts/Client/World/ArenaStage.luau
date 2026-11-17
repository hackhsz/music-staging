--!strict
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent
local Surface = ArenaPalette.Surface

-- The dance floor's own 5x5 sits on the street's frame; the deck reaches a little
-- past it and stops just under the frame's top, so the frame stays the floor's edge.
local DECK_SIZE = 52
local DECK_TOP = -0.1
local DECK_DEPTH = 1.6
local TRIM_WIDTH = 0.5
local STEP_SIZE = Vector3.new(18, 0.75, 2.6)
local TRUSS_Y = 24
local TRUSS_BACK_Z = -18
local TRUSS_FRONT_Z = 6
local TRUSS_HALF_WIDTH = 30
local RAIL = 1.1
local RAIL_GAP = 1.6
local TRUSS_COLOR = Color3.fromRGB(58, 56, 72)
local CHASE_COLORS = {
	Accent.Pink,
	Color3.fromRGB(64, 224, 255),
	Accent.Gold,
	Color3.fromRGB(150, 90, 255),
}
local MISS_COLOR = Color3.fromRGB(90, 86, 112)

local ArenaStage = {}

export type ArenaStage = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setMood: (mood: string, combo: number) -> (),
}

local TRIM_SIDES = { "north", "east", "south", "west" }

local function addRails(kit: ArenaKit.ArenaKit, name: string, size: Vector3, center: Vector3)
	kit:box(name .. "_top", size, center, TRUSS_COLOR, Enum.Material.DiamondPlate)
	kit:box(name .. "_low", size, center - Vector3.new(0, RAIL_GAP, 0), TRUSS_COLOR, Enum.Material.DiamondPlate)
end

-- A disco stage around the dance floor: a raised deck with a neon edge that chases
-- the beat, a step at the front, and a flown truss over the back and sides for the
-- moving heads. The truss hangs from above, so nothing stands in the crowd's way.
function ArenaStage.build(kit: ArenaKit.ArenaKit)
	kit:section("Stage")

	local half = DECK_SIZE / 2

	kit:box("stage_deck", Vector3.new(DECK_SIZE, DECK_DEPTH, DECK_SIZE), Vector3.new(0, DECK_TOP - DECK_DEPTH / 2, 0), Surface.Structure)
	kit:box(
		"stage_step_front",
		STEP_SIZE,
		Vector3.new(0, DECK_TOP - DECK_DEPTH + STEP_SIZE.Y / 2, half + STEP_SIZE.Z / 2),
		Surface.Wall
	)

	for index, side in TRIM_SIDES do
		local along = if index % 2 == 1 then Vector3.new(DECK_SIZE, 0.3, TRIM_WIDTH) else Vector3.new(TRIM_WIDTH, 0.3, DECK_SIZE)
		local offset = ({
			Vector3.new(0, 0, -half),
			Vector3.new(half, 0, 0),
			Vector3.new(0, 0, half),
			Vector3.new(-half, 0, 0),
		})[index]

		kit:box("stage_trim_" .. side, along, Vector3.new(0, DECK_TOP, 0) + offset, Accent.Pink, Enum.Material.Neon)
	end

	local sideLength = TRUSS_FRONT_Z - TRUSS_BACK_Z
	local sideZ = (TRUSS_FRONT_Z + TRUSS_BACK_Z) / 2

	addRails(kit, "truss_back", Vector3.new(TRUSS_HALF_WIDTH * 2, RAIL, RAIL), Vector3.new(0, TRUSS_Y, TRUSS_BACK_Z))
	addRails(kit, "truss_left", Vector3.new(RAIL, RAIL, sideLength), Vector3.new(-TRUSS_HALF_WIDTH, TRUSS_Y, sideZ))
	addRails(kit, "truss_right", Vector3.new(RAIL, RAIL, sideLength), Vector3.new(TRUSS_HALF_WIDTH, TRUSS_Y, sideZ))
end

function ArenaStage.bind(arena: Instance): ArenaStage
	local trims: { Part } = {}

	for _, side in TRIM_SIDES do
		local part = ArenaKit.findPart(arena, "stage_trim_" .. side)

		if part ~= nil then
			table.insert(trims, part)
		end
	end

	local missed = false
	local lastBeat = -1

	return {
		onBeat = function(phase, beatIndex)
			if beatIndex ~= lastBeat then
				lastBeat = beatIndex

				for index, trim in trims do
					trim.Color = if missed then MISS_COLOR else CHASE_COLORS[(beatIndex + index) % #CHASE_COLORS + 1]
				end
			end

			for _, trim in trims do
				trim.Transparency = 0.3 + 0.4 * phase
			end
		end,
		setMood = function(mood, _combo)
			missed = mood == "miss"
		end,
	}
end

return ArenaStage
