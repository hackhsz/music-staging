--!strict
-- The season reward track (Stage Pass): finished songs earn points, points climb tiers, and
-- each tier has a free reward and a pass reward. Looks only; nothing here changes a score.
local StagePassCatalog = {}

export type Reward = { kind: string, amount: number?, cosmeticId: string? }
export type Tier = { free: Reward, pass: Reward }
export type State = { season: string, points: number, claimedFree: { [string]: boolean }, claimedPass: { [string]: boolean }, passOwned: boolean }

StagePassCatalog.Season = {
	id = "blooming-sky",
	name = "BLOOMING SKY",
	startUtc = 1794787200,
	weeks = 4,
}
StagePassCatalog.PointsPerSong = 20
StagePassCatalog.PointsPerTier = 200
StagePassCatalog.Rows = { free = true, pass = true } :: { [string]: boolean }

local function coins(amount: number): Reward
	return { kind = "coins", amount = amount }
end

local function cosmetic(id: string): Reward
	return { kind = "cosmetic", cosmeticId = id }
end

StagePassCatalog.Tiers = {
	{ free = coins(50), pass = cosmetic("mint-wand-001") },
	{ free = coins(50), pass = coins(150) },
	{ free = cosmetic("hype-dance-001"), pass = cosmetic("candy-hairpin-001") },
	{ free = coins(75), pass = cosmetic("petal-trail-001") },
	{ free = coins(75), pass = coins(200) },
	{ free = cosmetic("heart-pose-001"), pass = cosmetic("sunset-wand-001") },
	{ free = coins(100), pass = cosmetic("spin-emote-001") },
	{ free = coins(100), pass = coins(250) },
	{ free = cosmetic("star-entrance-001"), pass = cosmetic("midnight-wand-001") },
	{ free = coins(125), pass = cosmetic("crown-pose-001") },
	{ free = coins(125), pass = coins(300) },
	{ free = coins(150), pass = cosmetic("starlight-aura-001") },
	{ free = coins(150), pass = cosmetic("spotlight-entrance-001") },
	{ free = coins(175), pass = coins(400) },
	{ free = coins(200), pass = cosmetic("gold-wand-001") },
} :: { Tier }

function StagePassCatalog.weekOf(now: number): number
	local week = math.floor((now - StagePassCatalog.Season.startUtc) / (7 * 86400)) + 1

	return math.clamp(week, 1, StagePassCatalog.Season.weeks)
end

function StagePassCatalog.endsUtc(): number
	return StagePassCatalog.Season.startUtc + StagePassCatalog.Season.weeks * 7 * 86400
end

function StagePassCatalog.tierFor(points: number): number
	return math.clamp(math.floor(points / StagePassCatalog.PointsPerTier), 0, #StagePassCatalog.Tiers)
end

-- A profile's pass state for the current season; a state from an earlier season starts over.
function StagePassCatalog.fresh(): State
	return { season = StagePassCatalog.Season.id, points = 0, claimedFree = {}, claimedPass = {}, passOwned = false }
end

function StagePassCatalog.normalize(state: any): State
	if type(state) ~= "table" or state.season ~= StagePassCatalog.Season.id then
		return StagePassCatalog.fresh()
	end

	state.points = math.max(tonumber(state.points) or 0, 0)
	state.claimedFree = if type(state.claimedFree) == "table" then state.claimedFree else {}
	state.claimedPass = if type(state.claimedPass) == "table" then state.claimedPass else {}
	state.passOwned = state.passOwned == true

	return state
end

-- Why a claim is refused, or nil when it may go ahead.
function StagePassCatalog.claimProblem(state: State, tier: number, row: string): string?
	if StagePassCatalog.Rows[row] ~= true or StagePassCatalog.Tiers[tier] == nil then
		return "unknown_tier"
	end

	if tier > StagePassCatalog.tierFor(state.points) then
		return "not_reached"
	end

	if row == "pass" and not state.passOwned then
		return "pass_locked"
	end

	local claimed = if row == "free" then state.claimedFree else state.claimedPass

	if claimed[tostring(tier)] then
		return "already_claimed"
	end

	return nil
end

-- What the client draws: the season line, progress and every tier with its two states.
function StagePassCatalog.snapshot(state: State, now: number): { [string]: any }
	local reached = StagePassCatalog.tierFor(state.points)
	local tiers = {}

	for index, tier in StagePassCatalog.Tiers do
		local key = tostring(index)

		table.insert(tiers, {
			tier = index,
			free = tier.free,
			pass = tier.pass,
			freeState = if state.claimedFree[key] then "claimed" elseif index <= reached then "ready" else "locked",
			passState = if state.claimedPass[key] then "claimed"
				elseif not state.passOwned then "pass"
				elseif index <= reached then "ready"
				else "locked",
		})
	end

	return {
		seasonName = StagePassCatalog.Season.name,
		week = StagePassCatalog.weekOf(now),
		weeks = StagePassCatalog.Season.weeks,
		endsUtc = StagePassCatalog.endsUtc(),
		points = state.points,
		tier = reached,
		pointsPerTier = StagePassCatalog.PointsPerTier,
		pointsPerSong = StagePassCatalog.PointsPerSong,
		passOwned = state.passOwned,
		tiers = tiers,
	}
end

return StagePassCatalog
