--!strict
local SongSchema = require(script.Parent.SongSchema)

local StraightSteps = {}

local SAME_BEAT = 0.001
local MAX_CORNER_LEAD_BEATS = 1
local PLAIN_TYPES: { [string]: boolean } = { tap = true, hold = true, bonus = true }

type Tile = { x: number, y: number }

-- Notes on one beat keep their order.
local function sortedByBeat(steps: { any }): { any }
	local order: { [any]: number } = {}
	local sorted = table.clone(steps)

	for index, step in steps do
		order[step] = index
	end

	table.sort(sorted, function(a, b)
		if a.beat ~= b.beat then
			return a.beat < b.beat
		end

		return order[a] < order[b]
	end)

	return sorted
end

local function isPlain(step: any): boolean
	return (step.type == nil or PLAIN_TYPES[step.type] == true) and not SongSchema.isEventStep(step) and step.zone == nil
end

local function ignoresPosition(step: any): boolean
	return step.type == "danger" or SongSchema.isItem(step) or SongSchema.isClap(step)
end

-- Where the dancer stands once a note is played; nil when a zone lets them pick.
local function standingAfter(step: any): Tile?
	if step.zone ~= nil then
		return nil
	end

	if step.type == "slide" and type(step.path) == "table" and #step.path > 0 then
		local last = step.path[#step.path]
		return { x = last.x, y = last.y }
	end

	return { x = step.x, y = step.y }
end

local function freeFrom(step: any, bpm: number): number
	if step.type == "hold" then
		return step.beat + (tonumber(step.holdSeconds) or 0) * bpm / 60
	end

	return step.beat + SongSchema.poseBeatsOf(step)
end

-- The tile in line with both ends, longer leg first.
local function corners(from: Tile, to: Tile): { Tile }
	local alongX, alongY = { x = to.x, y = from.y }, { x = from.x, y = to.y }

	if math.abs(to.x - from.x) >= math.abs(to.y - from.y) then
		return { alongX, alongY }
	end

	return { alongY, alongX }
end

local function dangerOn(steps: { any }, tile: Tile, fromBeat: number, toBeat: number): boolean
	for _, other in steps do
		local inside = other.beat > fromBeat - SAME_BEAT and other.beat < toBeat + SAME_BEAT

		if inside and other.type == "danger" and other.x == tile.x and other.y == tile.y then
			return true
		end
	end

	return false
end

local function beatTaken(map: any, beat: number): boolean
	for _, other in map.steps do
		if math.abs(other.beat - beat) < SAME_BEAT and other.type ~= "danger" then
			return true
		end
	end

	for _, event in map.events or {} do
		if SongSchema.inEvent(event, beat) then
			return true
		end
	end

	return false
end

-- A note right after a moved target must not care where that target was.
local function followerAllowsMove(ordered: { any }, position: number): boolean
	for index = position + 1, #ordered do
		local other = ordered[index]

		if not ignoresPosition(other) then
			return isPlain(other) or SongSchema.isShape(other) or other.type == "slide"
		end
	end

	return true
end

local function straighten(
	map: any,
	ordered: { any },
	position: number,
	from: Tile,
	freeBeat: number,
	cornerBeats: number,
	out: { any }
): any
	local step = ordered[position]
	local options = corners(from, step)
	local gap = step.beat - freeBeat

	if gap >= 2 * cornerBeats - SAME_BEAT then
		local cornerLead = math.floor(gap / 2 / cornerBeats + SAME_BEAT) * cornerBeats
		local beat = step.beat - math.clamp(cornerLead, cornerBeats, MAX_CORNER_LEAD_BEATS)

		if not beatTaken(map, beat) then
			for _, corner in options do
				if not dangerOn(ordered, corner, beat, step.beat) then
					table.insert(out, { beat = beat, x = corner.x, y = corner.y })
					return step
				end
			end
		end
	end

	if not followerAllowsMove(ordered, position) then
		return step
	end

	for _, tile in options do
		if not dangerOn(ordered, tile, step.beat, step.beat) then
			local moved = table.clone(step)
			moved.x, moved.y = tile.x, tile.y
			return moved
		end
	end

	return step
end

-- Puts every plain note on the row or column the dancer already stands on. A
-- diagonal target gets a corner note on its own beat when there is room, and
-- otherwise moves onto the line. cornerBeats is the shortest gap a corner may
-- leave either side of it.
function StraightSteps.apply(map: any, cornerBeats: number): { any }
	local ordered = sortedByBeat(map.steps)
	local out = {}
	local at: Tile? = nil
	local freeBeat = -math.huge

	for position, step in ordered do
		if ignoresPosition(step) then
			table.insert(out, step)
			continue
		end

		if SongSchema.isPose(step) or SongSchema.isFreeze(step) then
			freeBeat = math.max(freeBeat, freeFrom(step, map.bpm))
			table.insert(out, step)
			continue
		end

		if at ~= nil and isPlain(step) and step.x ~= at.x and step.y ~= at.y then
			step = straighten(map, ordered, position, at, freeBeat, cornerBeats, out)
		end

		table.insert(out, step)
		at = standingAfter(step)
		freeBeat = freeFrom(step, map.bpm)
	end

	return sortedByBeat(out)
end

return StraightSteps
