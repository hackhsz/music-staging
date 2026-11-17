local TileState = {}

TileState.States = {
	Inactive = "Inactive",
	Preview = "Preview",
	Upcoming = "Upcoming",
	Active = "Active",
	Bonus = "Bonus",
	Hold = "Hold",
	SlidePath = "SlidePath",
	SlideEnd = "SlideEnd",
	Danger = "Danger",
	Perfect = "Perfect",
	Great = "Great",
	Good = "Good",
	Bad = "Bad",
	Miss = "Miss",
	Fever = "Fever",
}

TileState.PixelPalette = {
	-- A resting tile is a Neon part covering most of the pad, so this colour is
	-- what the floor looks like when nothing is lit. Near-black made the board
	-- vanish into the room; it glows faintly now so the squares stay countable.
	Inactive = Color3.fromRGB(46, 41, 78),
	Preview = Color3.fromRGB(83, 224, 255),
	-- The step after next. Dim enough to read as "not yet", bright enough to
	-- route by; the old olive sat below the floor's own brightness.
	Upcoming = Color3.fromRGB(168, 148, 72),
	Active = Color3.fromRGB(255, 226, 76),
	Bonus = Color3.fromRGB(255, 241, 110),
	Hold = Color3.fromRGB(156, 104, 255),
	SlidePath = Color3.fromRGB(83, 224, 255),
	SlideEnd = Color3.fromRGB(255, 132, 229),
	Danger = Color3.fromRGB(255, 76, 91),
	Perfect = Color3.fromRGB(106, 255, 128),
	Great = Color3.fromRGB(72, 230, 180),
	Good = Color3.fromRGB(255, 132, 229),
	Bad = Color3.fromRGB(168, 132, 150),
	Miss = Color3.fromRGB(255, 76, 91),
	Fever = Color3.fromRGB(255, 230, 72),
}

function TileState.getColor(state: string): Color3
	return TileState.PixelPalette[state] or TileState.PixelPalette.Inactive
end

return TileState
