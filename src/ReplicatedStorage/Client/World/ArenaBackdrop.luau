--!strict
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent
local Surface = ArenaPalette.Surface

local WALL_Z = -52
local FRAME_Z = -50.5
local FRAME_WIDTH = 130
local STAGE_GAP = 9
local FRAME_BOTTOM = 3
local FRAME_HEIGHT = 15
local BAR_BASE_Y = 3.6
local BAR_DEPTH = 0.5
local PILLAR_X = 67
local BAR_SWING: { [string]: number } = {
	none = 0.45,
	calm = 0.15,
	build = 0.3,
	chorus = 0.45,
	drop = 0.5,
	fever = 0.5,
}
local FEVER_BAR_COLORS = {
	Accent.Gold,
	Accent.Pink,
	Color3.fromRGB(64, 224, 255),
	Accent.Lilac,
}

type Bar = {
	part: Part,
	baseHeight: number,
	baseBottom: number,
	baseColor: Color3,
	index: number,
}

local ArenaBackdrop = {}

export type ArenaBackdrop = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setEnergy: (energy: string) -> (),
}

-- The wall behind the stage: a dark LED frame with an equalizer along its foot,
-- a neon line above and below, and a pillar at each end. All of it sits inside
-- what the camera sees, and none of it is tilted.
function ArenaBackdrop.build(kit: ArenaKit.ArenaKit)
	kit:section("Backdrop")
	kit:box("back_wall", Vector3.new(220, 44, 2), Vector3.new(0, 22, WALL_Z), Surface.Wall)

	local frame = kit:box("led_frame", Vector3.new(FRAME_WIDTH, FRAME_HEIGHT, 1), Vector3.new(0, FRAME_BOTTOM + FRAME_HEIGHT / 2, FRAME_Z), Surface.Void)
	ArenaKit.signText(frame, "DANCE DANCE STEP", nil, Accent.Gold, 0.22)

	kit:box("led_top_strip", Vector3.new(FRAME_WIDTH, 0.5, 0.7), Vector3.new(0, FRAME_BOTTOM + FRAME_HEIGHT + 0.25, FRAME_Z + 0.2), Accent.Pink, Enum.Material.Neon)
	kit:box("led_bottom_strip", Vector3.new(FRAME_WIDTH, 0.4, 0.7), Vector3.new(0, FRAME_BOTTOM - 0.2, FRAME_Z + 0.2), Accent.Lilac, Enum.Material.Neon)

	for side = -1, 1, 2 do
		kit:box(("pillar_%s"):format(if side < 0 then "left" else "right"), Vector3.new(1.4, 17, 1.4), Vector3.new(side * PILLAR_X, FRAME_BOTTOM + 8.5, FRAME_Z + 0.2), Accent.Lilac, Enum.Material.Neon)
	end

	local count = kit.quality.equalizerBars
	local pitch = (FRAME_WIDTH - 4) / count

	for index = 1, count do
		local x = (index - (count + 1) / 2) * pitch
		local height = 2 + ((index * 7) % 9)
		local centreness = 1 - math.abs(x) / (FRAME_WIDTH / 2)

		-- Leave the middle clear so the performer stands against a dark wall.
		if math.abs(x) >= STAGE_GAP then
			kit:box(
				("equalizer_bar_%02d"):format(index),
				Vector3.new(pitch - 0.5, height, BAR_DEPTH),
				Vector3.new(x, BAR_BASE_Y + height / 2, FRAME_Z + 0.5),
				Accent.Lilac:Lerp(Accent.Pink, centreness),
				Enum.Material.Neon
			)
		end
	end
end

function ArenaBackdrop.bind(arena: Instance): ArenaBackdrop
	local bars: { Bar } = {}
	local topStrip = ArenaKit.findPart(arena, "led_top_strip")

	for _, descendant in arena:GetDescendants() do
		local number = if descendant:IsA("Part") then string.match(descendant.Name, "^equalizer_bar_(%d+)$") else nil

		if number ~= nil then
			local part = descendant :: Part

			table.insert(bars, {
				part = part,
				baseHeight = part.Size.Y,
				baseBottom = part.Position.Y - part.Size.Y / 2,
				baseColor = part.Color,
				index = tonumber(number) :: number,
			})
		end
	end

	local lastBeat = -1
	local swing = BAR_SWING.none
	local fever = false
	local lastFeverBeat = -1

	return {
		onBeat = function(phase, beatIndex)
			for _, bar in bars do
				local lift = 1 - swing + swing * math.abs(math.sin((beatIndex + phase) * math.pi + bar.index * 0.7))
				local height = bar.baseHeight * lift
				local position = bar.part.Position

				bar.part.Size = Vector3.new(bar.part.Size.X, height, bar.part.Size.Z)
				bar.part.Position = Vector3.new(position.X, bar.baseBottom + height / 2, position.Z)
			end

			if topStrip ~= nil and beatIndex ~= lastBeat then
				lastBeat = beatIndex
				topStrip.Color = if beatIndex % 2 == 0 then Accent.Pink else Accent.Lilac
			end

			if fever and beatIndex ~= lastFeverBeat then
				lastFeverBeat = beatIndex

				for _, bar in bars do
					bar.part.Color = FEVER_BAR_COLORS[(bar.index + beatIndex) % #FEVER_BAR_COLORS + 1]
				end
			end
		end,
		setEnergy = function(energy)
			swing = BAR_SWING[energy] or BAR_SWING.none
			fever = energy == "fever"
			lastFeverBeat = -1

			if not fever then
				for _, bar in bars do
					bar.part.Color = bar.baseColor
				end
			end
		end,
	}
end

return ArenaBackdrop
