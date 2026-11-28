--!strict
-- With no audio a swell runs across the bars every two beats, with a kick in
-- the middle on the beat.
local REST = 0.3
local SWELL = 0.3
local KICK = 0.35
local JITTER = 0.08
local SWELL_BEATS = 2
local MIN = 0.05
-- While the song plays the bars follow how loud it is, against the loudest it
-- has been lately; each bar jumps up fast and falls back slower.
local LOUD_FLOOR = 40
local LOUD_PEAK_SECONDS = 4
local LOUD_SHAPE = 0.45
local LOUD_WOBBLE = 0.5
local LOUD_ONSET = 2.5
local RISE = 30
local FALL = 7

export type Wave = { bars: { GuiObject }, sizes: { UDim2 }, levels: { number } }
-- energy is the song's loudness against its recent peak, nil with no audio;
-- onset is how sharply it just got louder.
export type Hearing = { energy: number?, onset: number }
export type Listener = { peak: number, last: number }

-- The equalizer bars authored in a panel's Wave frame, and the ear that drives
-- them from the song's loudness.
local HudWave = {}

-- The bars in panel's Wave frame, left to right; nil without one.
function HudWave.bind(panel: GuiObject): Wave?
	local frame = panel:FindFirstChild("Wave")

	if frame == nil then
		return nil
	end

	local bars: { GuiObject } = {}

	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(bars, child)
		end
	end

	table.sort(bars, function(a: GuiObject, b: GuiObject): boolean
		return a.Position.X.Scale < b.Position.X.Scale
	end)

	local sizes = {}
	local levels = {}

	for index, bar in bars do
		sizes[index] = bar.Size
		levels[index] = REST
	end

	return if #bars > 0 then { bars = bars, sizes = sizes, levels = levels } else nil
end

local function draw(wave: Wave)
	for index, bar in wave.bars do
		local size = wave.sizes[index]
		local height = wave.levels[index]
		bar.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale * height, size.Y.Offset * height)
	end
end

function HudWave.rest(wave: Wave)
	for index in wave.bars do
		wave.levels[index] = REST
	end

	draw(wave)
end

function HudWave.newListener(): Listener
	return { peak = LOUD_FLOOR, last = 0 }
end

function HudWave.resetListener(listener: Listener)
	listener.peak = LOUD_FLOOR
	listener.last = 0
end

-- loudness is the song's PlaybackLoudness, 0 when there is no audio.
function HudWave.hear(listener: Listener, loudness: number, seconds: number): Hearing
	listener.peak = math.max(loudness, LOUD_FLOOR, listener.peak * math.exp(-seconds / LOUD_PEAK_SECONDS))

	local onset = math.max(loudness - listener.last, 0) / listener.peak
	listener.last = loudness

	return { energy = if loudness > 0 then loudness / listener.peak else nil, onset = onset }
end

-- Moves every bar one frame toward the music (or the beat's swell).
function HudWave.step(waves: { Wave }, beat: number, pulse: number, hearing: Hearing, seconds: number)
	local now = os.clock()
	local energy = hearing.energy

	local function target(index: number, count: number): number
		local across = (index - 0.5) / count
		local middle = 1 - math.abs(across - 0.5) * 2

		if energy == nil then
			local swell = math.sin((beat / SWELL_BEATS - across) * math.pi * 2) * 0.5 + 0.5
			local jitter = math.sin(beat * math.pi * 3 + index * 2.4) * JITTER

			return REST + SWELL * swell + KICK * pulse * middle + jitter
		end

		local wobble = math.sin(now * (5 + index * 1.7) + index * 2.4) * 0.5 + 0.5
		local shape = 1 - LOUD_SHAPE + LOUD_SHAPE * middle

		return energy * shape * (1 - LOUD_WOBBLE + LOUD_WOBBLE * wobble) + (LOUD_ONSET * hearing.onset + KICK * pulse) * middle
	end

	for _, wave in waves do
		local levels = wave.levels

		for index in wave.bars do
			local goal = math.clamp(target(index, #wave.bars), MIN, 1)
			local current = levels[index] or REST
			local rate = if goal > current then RISE else FALL
			levels[index] = current + (goal - current) * (1 - math.exp(-rate * seconds))
		end

		draw(wave)
	end
end

return HudWave
