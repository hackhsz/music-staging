--!strict
local LeagueCatalog = {}

local WEEK_SECONDS = 7 * 86400
-- 1970-01-05 00:00 UTC was a Monday; league weeks run Monday to Monday.
local FIRST_MONDAY = 4 * 86400

export type Movement = "up" | "stay" | "down"

LeagueCatalog.Tiers = {
	{ id = "bronze", name = "Bronze" },
	{ id = "silver", name = "Silver" },
	{ id = "gold", name = "Gold" },
	{ id = "platinum", name = "Platinum" },
	{ id = "diamond", name = "Diamond" },
	{ id = "superstar", name = "Superstar" },
}

LeagueCatalog.GroupSize = 30
LeagueCatalog.MoveCount = 5
LeagueCatalog.BestSongs = 5
-- One group per tier while the player count is small; raise it as the game grows so
-- groups stay near GroupSize.
LeagueCatalog.GroupsPerTier = 1
-- Below this many players in a group nobody moves, so a near-empty week changes nothing.
LeagueCatalog.MinPlayersToMove = 10
LeagueCatalog.RowsShown = 6
LeagueCatalog.CoinsFor = { up = 150, stay = 75, down = 25 }

function LeagueCatalog.weekOf(now: number): number
	return math.floor((now - FIRST_MONDAY) / WEEK_SECONDS)
end

function LeagueCatalog.resetsAt(week: number): number
	return FIRST_MONDAY + (week + 1) * WEEK_SECONDS
end

function LeagueCatalog.clampTier(tier: any): number
	return math.clamp(math.floor(tonumber(tier) or 1), 1, #LeagueCatalog.Tiers)
end

function LeagueCatalog.groupOf(userId: number): number
	return userId % LeagueCatalog.GroupsPerTier
end

-- Keeps each song's best score this week; points are the BestSongs highest, so replaying
-- one song cannot fill every slot.
function LeagueCatalog.addScore(
	best: { [string]: number },
	songId: string,
	score: number
): ({ [string]: number }, number)
	local kept = table.clone(best)
	kept[songId] = math.max(kept[songId] or 0, math.max(math.floor(score), 0))

	local values = {}

	for _, value in kept do
		table.insert(values, value)
	end

	table.sort(values, function(a, b)
		return a > b
	end)

	local points = 0

	for index = 1, math.min(#values, LeagueCatalog.BestSongs) do
		points += values[index]
	end

	return kept, points
end

function LeagueCatalog.movement(rank: number?, count: number): Movement
	if rank == nil or count < LeagueCatalog.MinPlayersToMove then
		return "stay"
	elseif rank <= LeagueCatalog.MoveCount then
		return "up"
	-- A small group keeps a stay zone: only places past twice MoveCount can drop.
	elseif rank > count - LeagueCatalog.MoveCount and rank > 2 * LeagueCatalog.MoveCount then
		return "down"
	end

	return "stay"
end

return LeagueCatalog
