--!strict
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent
local Surface = ArenaPalette.Surface

local SPOT_COUNT = 7
local SPOT_SPACING = 16
local SPOT_HEIGHT = 24
local POST_COUNT = 4
local POST_OFFSET_X = 59
local POST_OFFSET_Z = 27
local SPOT_BASE_BRIGHTNESS = 0.6
local POST_BASE_BRIGHTNESS = 0.6

local MILESTONE_SECONDS = 0.7
local MILESTONE_BOOST = 3

-- How hard the room pulses for each section of the song. "none" is the lobby and
-- every mode that does not send sections, and matches the old fixed pulse.
local ENERGY: { [string]: { base: number, pulse: number, wild: boolean } } = {
	none = { base = SPOT_BASE_BRIGHTNESS, pulse = 1, wild = false },
	calm = { base = 0.25, pulse = 0.4, wild = false },
	build = { base = 0.45, pulse = 1, wild = false },
	chorus = { base = 0.9, pulse = 1.5, wild = false },
	drop = { base = 1.1, pulse = 2.2, wild = false },
	fever = { base = 0.9, pulse = 2, wild = true },
}
local WILD_COLORS = {
	Accent.Gold,
	Accent.Pink,
	Color3.fromRGB(64, 224, 255),
	Accent.Lilac,
}

type GlowPost = {
	cap: Part,
	light: PointLight?,
	color: Color3,
}

local ArenaLights = {}

export type ArenaLights = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setMood: (mood: string, combo: number) -> (),
	setEnergy: (energy: string) -> (),
	milestone: () -> (),
}

-- Overhead spots that pool light on the floor, and a post at each corner of the
-- floor that pulses with the beat. The spots are never in frame; only their
-- light is, so each is a plain invisible anchor.
function ArenaLights.build(kit: ArenaKit.ArenaKit)
	kit:section("Lights")

	for index = 1, SPOT_COUNT do
		local anchor = kit:anchor(("spot_anchor_%02d"):format(index), Vector3.new((index - (SPOT_COUNT + 1) / 2) * SPOT_SPACING, SPOT_HEIGHT, 0))

		kit:spotlight(anchor, ArenaPalette.moodAccent("idle", 0), 1)
	end

	for index, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x = corner[1] * POST_OFFSET_X
		local z = corner[2] * POST_OFFSET_Z

		kit:box(("corner_post_%02d"):format(index), Vector3.new(1.4, 3, 1.4), Vector3.new(x, 1.5, z), Surface.Structure)

		local cap = kit:box(("corner_cap_%02d"):format(index), Vector3.new(1.4, 0.4, 1.4), Vector3.new(x, 3.2, z), Accent.Pink, Enum.Material.Neon)

		kit:pointLight(cap, Accent.Pink, 1, 18)
	end
end

function ArenaLights.bind(arena: Instance): ArenaLights
	local spotlights: { SpotLight } = {}
	local posts: { GlowPost } = {}

	for index = 1, SPOT_COUNT do
		local anchor = ArenaKit.findPart(arena, ("spot_anchor_%02d"):format(index))
		local spotlight = if anchor ~= nil then anchor:FindFirstChildOfClass("SpotLight") else nil

		if spotlight ~= nil then
			table.insert(spotlights, spotlight)
		end
	end

	for index = 1, POST_COUNT do
		local cap = ArenaKit.findPart(arena, ("corner_cap_%02d"):format(index))

		if cap ~= nil then
			table.insert(posts, { cap = cap, light = cap:FindFirstChildOfClass("PointLight"), color = cap.Color })
		end
	end

	local profile = ENERGY.none
	local moodColor = ArenaPalette.moodAccent("idle", 0)
	local milestoneAt = -math.huge
	local lastBeat = -1

	local function paintSpots(beatIndex: number)
		for index, spotlight in spotlights do
			spotlight.Color = if profile.wild then WILD_COLORS[(beatIndex + index) % #WILD_COLORS + 1] else moodColor
		end
	end

	return {
		onBeat = function(phase, beatIndex)
			local pulse = (1 - math.clamp(phase, 0, 1)) ^ 2
			local burst = math.max(1 - (os.clock() - milestoneAt) / MILESTONE_SECONDS, 0)
			local spotBrightness = profile.base + profile.pulse * pulse + MILESTONE_BOOST * burst

			for _, spotlight in spotlights do
				spotlight.Brightness = spotBrightness
			end

			for _, post in posts do
				if post.light ~= nil then
					post.light.Brightness = POST_BASE_BRIGHTNESS + 1.4 * pulse * profile.pulse + MILESTONE_BOOST * burst
				end

				post.cap.Transparency = 0.1 * (1 - pulse)
			end

			if beatIndex ~= lastBeat then
				lastBeat = beatIndex

				if profile.wild then
					paintSpots(beatIndex)
				end
			end
		end,
		setMood = function(mood, combo)
			moodColor = ArenaPalette.moodAccent(mood, combo)

			if not profile.wild then
				paintSpots(lastBeat)
			end
		end,
		setEnergy = function(energy)
			profile = ENERGY[energy] or ENERGY.none
			paintSpots(lastBeat)
		end,
		milestone = function()
			milestoneAt = os.clock()

			for _, post in posts do
				post.cap.Color = Accent.Gold
			end

			task.delay(MILESTONE_SECONDS, function()
				for _, post in posts do
					post.cap.Color = post.color
				end
			end)
		end,
	}
end

return ArenaLights
