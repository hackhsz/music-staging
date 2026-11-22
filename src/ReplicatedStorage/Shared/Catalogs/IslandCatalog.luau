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
	-- The short line on the place's row, and the picture of it.
	tag: string,
	scene: string?,
	-- Where the place sits on its area's map, each axis from 0 to 1; nil leaves it off the map.
	pin: Vector2?,
	-- Up to three things to do there, for the detail panel.
	what: { string },
	area: Area,
	station: string,
}

local IslandCatalog = {}

IslandCatalog.TravelCooldownSeconds = 3

-- In tab order. map is the picture the area's pins sit on.
IslandCatalog.Areas = {
	{ id = "main", name = "Main Island", map = "rbxassetid://113597406111495" },
	{ id = "sky", name = "Sky Islands", map = "rbxassetid://114969360256907" },
}

local function stall(index: number, station: string, pin: Vector2): Island
	return {
		id = "stall-" .. index,
		name = "UGC Stall " .. index,
		blurb = "A creator stall in the Runway Market.",
		glyph = "🧵",
		tag = "Creator stall",
		scene = "rbxassetid://132263959412252",
		pin = pin,
		what = { "Creator items", "Claim a stall" },
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
		tag = "Welcome boards",
		scene = "rbxassetid://99174638106496",
		pin = Vector2.new(0.35, 0.12),
		what = { "What's new", "Welcome boards" },
		area = "main",
		station = "Spawn",
	},
	{
		id = "stage",
		name = "Dance Pad",
		blurb = "Step onto the pad and pick a song.",
		glyph = "🎵",
		tag = "Pick a song",
		scene = "rbxassetid://123565944624549",
		pin = Vector2.new(0.76, 0.14),
		what = { "Songs", "Stage Challenge", "Live Show" },
		area = "main",
		station = "Solo",
	},
	{
		id = "shop",
		name = "Shop",
		blurb = "Wands, trails, auras and passes.",
		glyph = "🛍️",
		tag = "Wands, trails, auras",
		scene = "rbxassetid://95251885361738",
		pin = Vector2.new(0.27, 0.33),
		what = { "Outfits", "Emotes", "Passes" },
		area = "main",
		station = "Shop",
	},
	{
		id = "quests",
		name = "Quest Board",
		blurb = "Daily challenges and achievements.",
		glyph = "📜",
		tag = "Daily challenges",
		scene = "rbxassetid://77086362965538",
		pin = Vector2.new(0.67, 0.43),
		what = { "Daily", "Achievements" },
		area = "main",
		station = "Quests",
	},
	{
		id = "stats",
		name = "Top Players",
		blurb = "The leaderboards and the top three on their podiums.",
		glyph = "🏆",
		tag = "Leaderboards",
		scene = "rbxassetid://75293070512265",
		pin = Vector2.new(0.28, 0.58),
		what = { "Top players", "Weekly league" },
		area = "main",
		station = "Stats",
	},
	{
		id = "dj",
		name = "DJ Booth",
		blurb = "Codes, the daily gift and thank-you coins.",
		glyph = "🎧",
		tag = "Codes and gifts",
		scene = "rbxassetid://77469402407496",
		pin = Vector2.new(0.77, 0.61),
		what = { "Codes", "Daily gift", "Thank-you coins" },
		area = "main",
		station = "Rewards",
	},
	{
		id = "teleport",
		name = "Teleport Garden",
		blurb = "The travel hub, and crates coming soon.",
		glyph = "🌀",
		tag = "Travel hub",
		scene = "rbxassetid://132214942886906",
		pin = Vector2.new(0.5, 0.8),
		what = { "Sky Islands" },
		area = "main",
		station = "Travel",
	},
	stall(1, "Market", Vector2.new(0.14, 0.15)),
	stall(2, "Stall2", Vector2.new(0.51, 0.15)),
	stall(3, "Stall3", Vector2.new(0.87, 0.15)),
	stall(4, "Stall4", Vector2.new(0.16, 0.59)),
	stall(5, "Stall5", Vector2.new(0.51, 0.59)),
	stall(6, "Stall6", Vector2.new(0.87, 0.59)),
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
