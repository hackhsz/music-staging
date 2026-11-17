--!strict
-- The places a player can travel to from the Travel window: spots on the main
-- island, and the sky islands floating around it. Each one lands on the Anchor
-- part of its station model under Workspace.Stations, which the place authors; a
-- place whose station is missing is listed but cannot be visited.

export type Area = "main" | "sky"

export type Island = {
	id: string,
	name: string,
	blurb: string,
	glyph: string,
	icon: string?,
	area: Area,
	station: string,
}

local IslandCatalog = {}

IslandCatalog.TravelCooldownSeconds = 3

-- In tab order.
IslandCatalog.Areas = {
	{ id = "main", name = "Main Island" },
	{ id = "sky", name = "Sky Islands" },
}

local function stall(index: number, station: string): Island
	return {
		id = "stall-" .. index,
		name = "UGC Stall " .. index,
		blurb = "A creator stall in the Runway Market.",
		glyph = "🧵",
		area = "sky",
		station = station,
	}
end

IslandCatalog.Islands = {
	{
		id = "spawn",
		name = "Spawn",
		blurb = "Where everyone lands. Welcome boards and what's new.",
		glyph = "🏝️",
		area = "main",
		station = "Spawn",
	},
	{
		id = "stage",
		name = "Dance Pad",
		blurb = "Step onto the pad and pick a song.",
		glyph = "🎵",
		area = "main",
		station = "Solo",
	},
	{
		id = "shop",
		name = "Shop",
		blurb = "Wands, trails, auras and passes.",
		glyph = "🛍️",
		area = "main",
		station = "Shop",
	},
	{
		id = "quests",
		name = "Quest Board",
		blurb = "Daily challenges and achievements.",
		glyph = "📜",
		area = "main",
		station = "Quests",
	},
	{
		id = "stats",
		name = "Top Players",
		blurb = "The leaderboards and the top three on their podiums.",
		glyph = "🏆",
		area = "main",
		station = "Stats",
	},
	{
		id = "dj",
		name = "DJ Booth",
		blurb = "Codes, the daily gift and thank-you coins.",
		glyph = "🎧",
		area = "main",
		station = "Rewards",
	},
	{
		id = "teleport",
		name = "Teleport Garden",
		blurb = "The travel hub, and crates coming soon.",
		glyph = "🌀",
		area = "main",
		station = "Travel",
	},
	stall(1, "Market"),
	stall(2, "Stall2"),
	stall(3, "Stall3"),
	stall(4, "Stall4"),
	stall(5, "Stall5"),
	stall(6, "Stall6"),
} :: { Island }

function IslandCatalog.get(islandId: string): Island?
	for _, island in IslandCatalog.Islands do
		if island.id == islandId then
			return island
		end
	end

	return nil
end

function IslandCatalog.areaName(area: string): string
	for _, entry in IslandCatalog.Areas do
		if entry.id == area then
			return entry.name
		end
	end

	return ""
end

return IslandCatalog
