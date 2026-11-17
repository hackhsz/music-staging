--!strict
local ArenaKit = require(script.Parent.ArenaKit)

local GROUND_Y = -1.6
local TOWER_COLOR = Color3.fromRGB(16, 13, 30)
-- Dim on purpose: past the focus band they blur into soft city lights, never
-- brighter than the stage.
local WINDOW_COLORS = {
	Color3.fromRGB(96, 80, 58),
	Color3.fromRGB(52, 88, 110),
	Color3.fromRGB(104, 52, 92),
}
local BEACON_COLOR = Color3.fromRGB(255, 48, 64)
local BEACON_OFF = Color3.fromRGB(60, 12, 20)
local BEACON_SECONDS = 1.6
local SEED = 7
-- Each row of towers: where it runs (from, to), how many, and how tall they get.
local ROWS = {
	{ from = Vector3.new(-150, 0, -110), to = Vector3.new(150, 0, -110), count = 9, height = NumberRange.new(45, 85) },
	{ from = Vector3.new(-140, 0, -60), to = Vector3.new(-140, 0, 30), count = 4, height = NumberRange.new(35, 65) },
	{ from = Vector3.new(140, 0, -60), to = Vector3.new(140, 0, 30), count = 4, height = NumberRange.new(35, 65) },
}
local WINDOW_BANDS = 3
local BEACON_EVERY = 3

local ArenaSkyline = {}

export type ArenaSkyline = {
	onBeat: (phase: number, beatIndex: number) -> (),
}

-- A night skyline around the street, standing where the old back wall did. Every
-- tower faces the stage, so its lit windows show behind the speakers and truss.
function ArenaSkyline.build(kit: ArenaKit.ArenaKit)
	kit:section("Skyline")

	local random = Random.new(SEED)
	local tower = 0

	for _, row in ROWS do
		local facesZ = row.from.X ~= row.to.X

		for index = 1, row.count do
			tower += 1

			local along = (index - 0.5) / row.count
			local base = row.from:Lerp(row.to, along)
			local width = random:NextNumber(16, 24)
			local depth = random:NextNumber(14, 20)
			local height = random:NextNumber(row.height.Min, row.height.Max)
			local size = if facesZ then Vector3.new(width, height, depth) else Vector3.new(depth, height, width)
			local center = Vector3.new(base.X, GROUND_Y + height / 2, base.Z)
			local name = ("skyline_tower_%02d"):format(tower)

			kit:box(name, size, center, TOWER_COLOR)

			-- The face toward the stage: +Z for the back row, toward x = 0 for the sides.
			local face = if facesZ then Vector3.new(0, 0, depth / 2 + 0.1) else Vector3.new(-math.sign(base.X) * (depth / 2 + 0.1), 0, 0)
			local bandSize = if facesZ then Vector3.new(width * 0.7, 0.8, 0.2) else Vector3.new(0.2, 0.8, width * 0.7)

			for band = 1, WINDOW_BANDS do
				local y = GROUND_Y + height * (band / (WINDOW_BANDS + 1))

				kit:box(
					("%s_windows_%d"):format(name, band),
					bandSize,
					Vector3.new(center.X, y, center.Z) + face,
					WINDOW_COLORS[random:NextInteger(1, #WINDOW_COLORS)],
					Enum.Material.Neon
				)
			end

			if tower % BEACON_EVERY == 0 then
				kit:box(("%s_beacon"):format(name), Vector3.new(1, 1, 1), center + Vector3.new(0, height / 2 + 0.5, 0), BEACON_COLOR, Enum.Material.Neon)
			end
		end
	end
end

function ArenaSkyline.bind(arena: Instance): ArenaSkyline
	local beacons: { Part } = {}
	local section = arena:FindFirstChild("Skyline")

	if section ~= nil then
		for _, part in section:GetChildren() do
			if part:IsA("Part") and string.match(part.Name, "_beacon$") ~= nil then
				table.insert(beacons, part)
			end
		end
	end

	local lit = true

	return {
		onBeat = function(_phase, _beatIndex)
			local on = os.clock() % BEACON_SECONDS < BEACON_SECONDS / 2

			if on == lit then
				return
			end

			lit = on

			for _, beacon in beacons do
				beacon.Color = if on then BEACON_COLOR else BEACON_OFF
			end
		end,
	}
end

return ArenaSkyline
