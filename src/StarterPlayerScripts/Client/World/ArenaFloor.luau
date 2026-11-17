--!strict
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Surface = ArenaPalette.Surface

local ArenaFloor = {}

-- The ground the street, the crowd and the skyline stand on, just under the street's
-- surface. Each dance floor stands on its own stage deck (ArenaStage) or podium.
function ArenaFloor.build(kit: ArenaKit.ArenaKit)
	kit:section("Floor")
	kit:box("arena_floor", Vector3.new(400, 1, 400), Vector3.new(0, -2.1, -25), Surface.Floor)
end

return ArenaFloor
