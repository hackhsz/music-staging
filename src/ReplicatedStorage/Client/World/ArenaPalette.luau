--!strict
-- The arena is a dark violet room with one accent. Pink is the accent, gold is
-- kept for highlights, and nothing else competes with the lit floor.
local ArenaPalette = {}

ArenaPalette.Surface = {
	Void = Color3.fromRGB(10, 9, 20),
	Floor = Color3.fromRGB(20, 17, 36),
	Wall = Color3.fromRGB(26, 22, 46),
	Structure = Color3.fromRGB(44, 38, 76),
	Trim = Color3.fromRGB(96, 88, 142),
}

ArenaPalette.Silhouettes = {
	Color3.fromRGB(38, 32, 64),
	Color3.fromRGB(46, 40, 78),
	Color3.fromRGB(32, 28, 56),
}

ArenaPalette.Accent = {
	Pink = Color3.fromRGB(255, 127, 191),
	Gold = Color3.fromRGB(255, 200, 87),
	Lilac = Color3.fromRGB(201, 188, 230),
	White = Color3.fromRGB(250, 247, 244),
}

local MISS_COLOR = Color3.fromRGB(120, 116, 146)
local FEVER_COMBO = 12

-- One colour for the whole room to lean toward, picked from how the run is going.
function ArenaPalette.moodAccent(mood: string, combo: number): Color3
	if mood == "miss" then
		return MISS_COLOR
	end

	if mood == "fever" or combo >= FEVER_COMBO then
		return ArenaPalette.Accent.Gold
	end

	if mood == "idle" then
		return ArenaPalette.Accent.Lilac
	end

	return ArenaPalette.Accent.Pink
end

return ArenaPalette
