--!strict
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent

local BAR_COUNT = 7
-- The authored bars hang from the foot of a 600 px frame and grow upward with a negative height.
local BAR_SPAN = 600
local BAR_REST = 0.08
local BAR_REACH: { [string]: number } = {
	none = 0.45,
	calm = 0.4,
	build = 0.65,
	chorus = 0.85,
	drop = 1,
	fever = 1,
}
local LIGHT_REST = 0.35
local SPEAKER_REST = 0.3
local MILESTONE_FLASH_SECONDS = 0.45
-- How far a speaker swells on its kick, scaled from its base so it never sinks into the street.
local PUMP = 0.06
local MILESTONE_PUMP = 0.12
local BIG_SPEAKER_HEIGHT = 25
local EIGHTH_ENERGIES = { build = true, chorus = true, drop = true, fever = true }

type Equalizer = {
	bars: { GuiObject },
	lights: { { light: Light, brightness: number } },
}

type SpeakerPart = {
	part: BasePart,
	size: Vector3,
	offset: CFrame,
}

type Speaker = {
	glow: BasePart,
	color: Color3,
	base: CFrame,
	parts: { SpeakerPart },
	big: boolean,
}

local ArenaStreet = {}

ArenaStreet.FolderName = "Street"

export type ArenaStreet = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setMood: (mood: string, combo: number) -> (),
	setEnergy: (energy: string) -> (),
	milestone: () -> (),
}

local function findEqualizer(part: Instance): Equalizer?
	local frame = part:FindFirstChild("DroppingFrame", true)

	if frame == nil then
		return nil
	end

	local equalizer: Equalizer = { bars = {}, lights = {} }

	for index = 1, BAR_COUNT do
		local bar = frame:FindFirstChild("NUM" .. index)

		if bar ~= nil and bar:IsA("GuiObject") then
			bar.BackgroundTransparency = 0
			table.insert(equalizer.bars, bar)
		end
	end

	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			table.insert(equalizer.lights, { light = child, brightness = child.Brightness })
		end
	end

	return equalizer
end

local function findSpeaker(body: BasePart): Speaker?
	local glow = body:FindFirstChild("light")

	if glow == nil or not glow:IsA("BasePart") then
		return nil
	end

	local base = body.CFrame * CFrame.new(0, -body.Size.Y / 2, 0)
	local parts: { SpeakerPart } = { { part = body, size = body.Size, offset = base:ToObjectSpace(body.CFrame) } }

	for _, child in body:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, { part = child, size = child.Size, offset = base:ToObjectSpace(child.CFrame) })
		end
	end

	return { glow = glow, color = glow.Color, base = base, parts = parts, big = body.Size.Y > BIG_SPEAKER_HEIGHT }
end

local function pump(speaker: Speaker, scale: number)
	for _, entry in speaker.parts do
		local offset = entry.offset

		entry.part.Size = entry.size * scale
		entry.part.CFrame = speaker.base * (offset - offset.Position + offset.Position * scale)
	end
end

-- The street stage (Workspace.Arena.Street): its equalizer screens jump on each
-- beat and fall through it, and the speakers pump and glow on the kick in their own colours.
function ArenaStreet.bind(street: Instance?): ArenaStreet
	local equalizers: { Equalizer } = {}
	local speakers: { Speaker } = {}

	if street ~= nil then
		for _, descendant in street:GetDescendants() do
			if descendant:IsA("BasePart") and string.match(descendant.Name, "^Equalizer") ~= nil then
				local equalizer = findEqualizer(descendant)

				if equalizer ~= nil then
					table.insert(equalizers, equalizer)
				end
			elseif descendant:IsA("BasePart") and string.match(descendant.Name, "^Speaker%a+$") ~= nil then
				local speaker = findSpeaker(descendant)

				if speaker ~= nil then
					table.insert(speakers, speaker)
				end
			end
		end
	end

	local reach = BAR_REACH.none
	local eighths = false
	local flashUntil = 0

	local function setMood(mood: string, combo: number)
		local accent = ArenaPalette.moodAccent(mood, combo)

		for _, equalizer in equalizers do
			for _, bar in equalizer.bars do
				bar.BackgroundColor3 = accent
			end

			for _, entry in equalizer.lights do
				entry.light.Color = accent
			end
		end
	end

	setMood("idle", 0)

	return {
		onBeat = function(phase, beatIndex)
			local kick = (1 - phase) ^ 2
			local flashing = os.clock() < flashUntil

			for which, equalizer in equalizers do
				for index, bar in equalizer.bars do
					local peak = reach * (0.35 + 0.65 * math.abs(math.sin(beatIndex * 1.7 + index * 0.9 + which * 2.3)))
					local height = math.max(BAR_REST, peak * (0.25 + 0.75 * kick))

					bar.Size = UDim2.new(bar.Size.X, UDim.new(0, -BAR_SPAN * height))
				end

				for _, entry in equalizer.lights do
					entry.light.Brightness = entry.brightness * (LIGHT_REST + (1 - LIGHT_REST) * kick)
				end
			end

			-- The big pair keeps the beat; the small ones double it on eighths once the song gets going.
			local eighthKick = if eighths then (1 - (phase * 2) % 1) ^ 2 else kick

			for _, speaker in speakers do
				local hit = if speaker.big then kick else eighthKick

				speaker.glow.Color = if flashing
					then Accent.White
					else speaker.color:Lerp(Color3.new(), (1 - SPEAKER_REST) * (1 - hit))
				pump(speaker, 1 + hit * (if flashing then MILESTONE_PUMP else PUMP * reach))
			end
		end,
		setMood = setMood,
		setEnergy = function(energy)
			reach = BAR_REACH[energy] or BAR_REACH.none
			eighths = EIGHTH_ENERGIES[energy] == true
		end,
		milestone = function()
			flashUntil = os.clock() + MILESTONE_FLASH_SECONDS
		end,
	}
end

return ArenaStreet
