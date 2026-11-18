--!strict
local SongSchema = {}

SongSchema.Version = 1
SongSchema.StepTypes = {
	tap = true,
	hold = true,
	slide = true,
	bonus = true,
	danger = true,
	item = true,
	freeze = true,
	shape = true,
	pose = true,
	clap = true,
	rush = true,
}
SongSchema.Energies = {
	calm = true,
	build = true,
	chorus = true,
	drop = true,
}

--[[
	Floor events take the whole pad over for a few beats. Each is an entry in
	map.events, { beat, beats, kind }, covering beats [beat, beat + beats), and
	is compiled into ordinary steps that carry `event`, its index:
	lava, spotlight: one step a beat with `zone`, the safe or lit tiles, its own
	  tile among them; the player must be on any of them when the beat lands.
	memory: the pad shows `sequence` from `beat`, one tile every `interval`
	  beats, then from `playBeat` the same tiles come back as steps flagged
	  `hidden`, whose telegraphs show nothing.
	freeze: one `type = "freeze"` step a beat, on the tile the player stands on;
	  any step taken during the beat before it is a Miss.
]]
SongSchema.EventKinds = {
	lava = true,
	memory = true,
	spotlight = true,
	freeze = true,
}
SongSchema.EventBeats = { min = 2, max = 16 }
SongSchema.MaxZoneTiles = 10
SongSchema.MemoryLength = { min = 3, max = 6 }
SongSchema.PoseBeats = { min = 1, max = 4 }
SongSchema.RushLength = { min = 3, max = 5 }

local SAME_BEAT = 0.001

function SongSchema.isItem(step: any): boolean
	return type(step) == "table" and step.type == "item"
end

-- Items are pickups, not notes: they are judged on their own list and never
-- count toward the note total, accuracy or combo.
function SongSchema.splitItems(steps: { any }): ({ any }, { any })
	local notes, items = {}, {}

	for _, step in steps do
		table.insert(if SongSchema.isItem(step) then items else notes, step)
	end

	return notes, items
end

function SongSchema.noteCount(map: any): number
	local count = 0

	for _, step in map.steps do
		if not SongSchema.isItem(step) then
			count += 1
		end
	end

	return count
end

function SongSchema.energyAt(sections: any, beat: number): string?
	if type(sections) ~= "table" then
		return nil
	end

	local energy = nil

	for _, section in sections do
		if type(section) ~= "table" or type(section.beat) ~= "number" or section.beat > beat then
			break
		end

		energy = section.energy
	end

	return energy
end

function SongSchema.isEventStep(step: any): boolean
	return type(step) == "table" and type(step.event) == "number"
end

function SongSchema.isFreeze(step: any): boolean
	return type(step) == "table" and step.type == "freeze"
end

-- A shape is a note outside any event that any tile of its `zone` satisfies.
function SongSchema.isShape(step: any): boolean
	return type(step) == "table" and step.type == "shape"
end

-- A pose is held still on the tile the player already stands on, from its beat
-- for `poseBeats` beats.
function SongSchema.isPose(step: any): boolean
	return type(step) == "table" and step.type == "pose"
end

-- A clap is pressed on the beat; its tile is only where the dancer stands.
function SongSchema.isClap(step: any): boolean
	return type(step) == "table" and step.type == "clap"
end

-- A rush is a plain step that belongs to a path of steps sharing its `rush` id.
function SongSchema.isRush(step: any): boolean
	return type(step) == "table" and step.type == "rush"
end

function SongSchema.poseBeatsOf(step: any): number
	return if SongSchema.isPose(step) and type(step.poseBeats) == "number" then step.poseBeats else 0
end

function SongSchema.rushGroup(steps: { any }, index: number): { any }
	local step = steps[index]

	if not SongSchema.isRush(step) then
		return {}
	end

	local group = {}

	for _, other in steps do
		if SongSchema.isRush(other) and other.rush == step.rush then
			table.insert(group, other)
		end
	end

	return group
end

function SongSchema.zoneOf(step: any): { { x: number, y: number } }?
	return if type(step) == "table" and type(step.zone) == "table" then step.zone else nil
end

function SongSchema.eventEnd(event: any): number
	return event.beat + event.beats
end

function SongSchema.inEvent(event: any, beat: number): boolean
	return beat >= event.beat - SAME_BEAT and beat < SongSchema.eventEnd(event) - SAME_BEAT
end

-- Only the dance pad plays floor events, shapes and moves: elsewhere a freeze,
-- pose or clap is dropped and the rest are plain steps on their own tile.
function SongSchema.withoutEvents(steps: { any }): { any }
	local plain = {}

	for _, step in steps do
		if SongSchema.isFreeze(step) or SongSchema.isPose(step) or SongSchema.isClap(step) then
			continue
		end

		if SongSchema.isEventStep(step) or SongSchema.isShape(step) or SongSchema.isRush(step) then
			step = table.clone(step)
			step.event = nil
			step.zone = nil
			step.hidden = nil
			step.rush = nil
			step.type = if step.type == "shape" or step.type == "rush" then nil else step.type
		end

		table.insert(plain, step)
	end

	return plain
end

local function validateSections(sections: any): (boolean, string)
	if type(sections) ~= "table" then
		return false, "map.sections must be a list"
	end

	local previousBeat = -math.huge

	for index, section in sections do
		if type(section) ~= "table" or type(section.beat) ~= "number" or section.beat < 1 then
			return false, ("section %d needs a beat of 1 or more"):format(index)
		end

		if SongSchema.Energies[section.energy] ~= true then
			return false, ("section %d has unknown energy %s"):format(index, tostring(section.energy))
		end

		if section.beat <= previousBeat then
			return false, ("section %d must come after the section before it"):format(index)
		end

		previousBeat = section.beat
	end

	return true, "ok"
end

-- A player stands on one tile, so an item cannot share its beat with a note
-- they must be elsewhere for; only a danger tile somewhere else can.
local function itemClash(item: any, steps: { any }): boolean
	for _, other in steps do
		if other == item or math.abs(other.beat - item.beat) >= SAME_BEAT then
			continue
		end

		local sameTile = other.x == item.x and other.y == item.y

		if other.type ~= "danger" or sameTile then
			return true
		end
	end

	return false
end

local function isTile(tile: any): boolean
	return type(tile) == "table" and type(tile.x) == "number" and type(tile.y) == "number"
end

local function tileList(tiles: any, min: number, max: number): boolean
	if type(tiles) ~= "table" or #tiles < min or #tiles > max then
		return false
	end

	for _, tile in tiles do
		if not isTile(tile) then
			return false
		end
	end

	return true
end

local function validateMemory(event: any, index: number): (boolean, string)
	local length = SongSchema.MemoryLength

	if not tileList(event.sequence, length.min, length.max) then
		return false, ("event %d memory needs a sequence of %d to %d tiles"):format(index, length.min, length.max)
	end

	if type(event.interval) ~= "number" or event.interval <= 0 or type(event.playBeat) ~= "number" then
		return false, ("event %d memory needs an interval and a playBeat"):format(index)
	end

	local count = #event.sequence

	if event.playBeat < event.beat + count * event.interval - SAME_BEAT then
		return false, ("event %d memory plays before its sequence has been shown"):format(index)
	end

	if not SongSchema.inEvent(event, event.playBeat + (count - 1) * event.interval) then
		return false, ("event %d memory runs past its beats"):format(index)
	end

	return true, "ok"
end

local function validateEvents(events: any): (boolean, string)
	if type(events) ~= "table" then
		return false, "map.events must be a list"
	end

	local previousEnd = -math.huge

	for index, event in events do
		if type(event) ~= "table" or type(event.beat) ~= "number" or event.beat < 1 then
			return false, ("event %d needs a beat of 1 or more"):format(index)
		end

		if SongSchema.EventKinds[event.kind] ~= true then
			return false, ("event %d has unknown kind %s"):format(index, tostring(event.kind))
		end

		local bounds = SongSchema.EventBeats

		if type(event.beats) ~= "number" or event.beats < bounds.min or event.beats > bounds.max then
			return false, ("event %d must last %d to %d beats"):format(index, bounds.min, bounds.max)
		end

		if event.beat < previousEnd - SAME_BEAT then
			return false, ("event %d overlaps the event before it"):format(index)
		end

		if event.kind == "memory" then
			local ok, reason = validateMemory(event, index)

			if not ok then
				return false, reason
			end
		end

		previousEnd = SongSchema.eventEnd(event)
	end

	return true, "ok"
end

local function inZone(step: any, zone: { any }): boolean
	for _, tile in zone do
		if tile.x == step.x and tile.y == step.y then
			return true
		end
	end

	return false
end

local function validateEventStep(step: any, index: number, events: { any }): (boolean, string)
	local event = events[step.event]

	if event == nil or not SongSchema.inEvent(event, step.beat) then
		return false, ("step %d names an event it does not fall inside"):format(index)
	end

	if (event.kind == "freeze") ~= SongSchema.isFreeze(step) then
		return false, ("step %d: freeze events hold only freeze steps"):format(index)
	end

	if SongSchema.isShape(step) then
		return false, ("step %d: a shape plays outside events"):format(index)
	end

	if event.kind == "lava" or event.kind == "spotlight" then
		local zone = SongSchema.zoneOf(step)

		if zone == nil or not tileList(zone, 1, SongSchema.MaxZoneTiles) or not inZone(step, zone) then
			return false, ("step %d needs a zone of 1 to %d tiles holding its own tile"):format(index, SongSchema.MaxZoneTiles)
		end
	elseif step.zone ~= nil then
		return false, ("step %d: only lava and spotlight steps take a zone"):format(index)
	end

	if (event.kind == "memory") ~= (step.hidden == true) then
		return false, ("step %d: memory steps, and only they, are hidden"):format(index)
	end

	return true, "ok"
end

local function memoryMatches(event: any, eventIndex: number, steps: { any }): boolean
	local played = 0

	for _, step in steps do
		if step.event ~= eventIndex then
			continue
		end

		played += 1
		local tile = event.sequence[played]
		local beat = event.playBeat + (played - 1) * event.interval

		if tile == nil or tile.x ~= step.x or tile.y ~= step.y or math.abs(step.beat - beat) >= SAME_BEAT then
			return false
		end
	end

	return played == #event.sequence
end

-- Every step inside an event's beats belongs to it, items and dangers too, so
-- nothing else asks the player to be somewhere during it.
local function validateEventSteps(map: any): (boolean, string)
	local events = if type(map.events) == "table" then map.events else {}

	for index, step in map.steps do
		if SongSchema.isEventStep(step) then
			local ok, reason = validateEventStep(step, index, events)

			if not ok then
				return false, reason
			end
		elseif SongSchema.isShape(step) then
			local zone = SongSchema.zoneOf(step)

			if zone == nil or not tileList(zone, 2, SongSchema.MaxZoneTiles) or not inZone(step, zone) then
				return false, ("step %d: a shape needs 2 to %d tiles holding its own tile"):format(index, SongSchema.MaxZoneTiles)
			end
		elseif SongSchema.isFreeze(step) or step.zone ~= nil or step.hidden ~= nil then
			return false, ("step %d is a freeze, zone or hidden step outside any event"):format(index)
		end

		for eventIndex, event in events do
			if step.event ~= eventIndex and SongSchema.inEvent(event, step.beat) then
				return false, ("step %d falls inside event %d without belonging to it"):format(index, eventIndex)
			end
		end
	end

	for eventIndex, event in events do
		if event.kind == "memory" and not memoryMatches(event, eventIndex, map.steps) then
			return false, ("event %d memory steps must replay its sequence on its beats"):format(eventIndex)
		end
	end

	return true, "ok"
end

local function isMove(step: any): boolean
	return SongSchema.isPose(step) or SongSchema.isClap(step) or SongSchema.isRush(step)
end

-- Items and dangers never say where the player stands; every other note does.
local function placesPlayer(step: any): boolean
	return not SongSchema.isItem(step) and step.type ~= "danger"
end

local function dangerElsewhere(other: any, step: any): boolean
	return other.type == "danger" and (other.x ~= step.x or other.y ~= step.y)
end

local function noteBefore(steps: { any }, beat: number, skip: (any) -> boolean): any?
	local latest = nil

	for _, other in steps do
		if placesPlayer(other) and not skip(other) and other.beat < beat - SAME_BEAT then
			if latest == nil or other.beat >= latest.beat then
				latest = other
			end
		end
	end

	return latest
end

local function adjacent(a: any, b: any): boolean
	return math.abs(a.x - b.x) + math.abs(a.y - b.y) == 1
end

local function validatePose(step: any, index: number, steps: { any }): (boolean, string)
	local bounds = SongSchema.PoseBeats
	local poseBeats = step.poseBeats

	if type(poseBeats) ~= "number" or poseBeats < bounds.min or poseBeats > bounds.max then
		return false, ("step %d pose needs poseBeats of %d to %d"):format(index, bounds.min, bounds.max)
	end

	local previous = noteBefore(steps, step.beat, function()
		return false
	end)

	if previous == nil or SongSchema.isShape(previous) or previous.x ~= step.x or previous.y ~= step.y then
		return false, ("step %d pose must sit on the single tile of the note before it"):format(index)
	end

	local clearUntil = step.beat + poseBeats + 1 - SAME_BEAT

	for _, other in steps do
		if other ~= step and other.beat > step.beat - SAME_BEAT and other.beat < clearUntil and not dangerElsewhere(other, step) then
			return false, ("step %d pose needs nothing else until %d beats after it"):format(index, poseBeats + 1)
		end
	end

	return true, "ok"
end

local function validateClap(step: any, index: number, steps: { any }): (boolean, string)
	for _, other in steps do
		if other ~= step and math.abs(other.beat - step.beat) < SAME_BEAT and not dangerElsewhere(other, step) then
			return false, ("step %d clap shares its beat with a note"):format(index)
		end
	end

	return true, "ok"
end

local function validateRush(group: { any }, id: any, steps: { any }): (boolean, string)
	local bounds = SongSchema.RushLength

	if #group < bounds.min or #group > bounds.max then
		return false, ("rush %s needs %d to %d tiles"):format(tostring(id), bounds.min, bounds.max)
	end

	for position = 2, #group do
		local before, after = group[position - 1], group[position]

		if after.beat <= before.beat + SAME_BEAT or not adjacent(before, after) then
			return false, ("rush %s must run one tile at a time on rising beats"):format(tostring(id))
		end
	end

	local first, last = group[1], group[#group]
	local previous = noteBefore(steps, first.beat, function(other)
		return SongSchema.isRush(other) and other.rush == id
	end)

	if previous ~= nil and not SongSchema.isShape(previous) and not adjacent(previous, first) then
		return false, ("rush %s must start one tile from the note before it"):format(tostring(id))
	end

	for _, other in steps do
		local inside = other.beat > first.beat - SAME_BEAT and other.beat < last.beat + SAME_BEAT
		local member = SongSchema.isRush(other) and other.rush == id

		if inside and not member and placesPlayer(other) then
			return false, ("rush %s has another note inside its path"):format(tostring(id))
		end
	end

	return true, "ok"
end

local function validateMoves(map: any): (boolean, string)
	local rushes: { [any]: { any } } = {}
	local order = {}

	for index, step in map.steps do
		if not isMove(step) then
			continue
		end

		if SongSchema.isEventStep(step) or step.path ~= nil or step.holdSeconds ~= nil then
			return false, ("step %d: a %s plays outside events and takes no path or holdSeconds"):format(index, step.type)
		end

		local ok, reason = true, "ok"

		if SongSchema.isPose(step) then
			ok, reason = validatePose(step, index, map.steps)
		elseif SongSchema.isClap(step) then
			ok, reason = validateClap(step, index, map.steps)
		elseif type(step.rush) ~= "string" and type(step.rush) ~= "number" then
			ok, reason = false, ("step %d rush needs a rush id"):format(index)
		else
			if rushes[step.rush] == nil then
				rushes[step.rush] = {}
				table.insert(order, step.rush)
			end

			table.insert(rushes[step.rush], step)
		end

		if not ok then
			return false, reason
		end
	end

	for _, id in order do
		local ok, reason = validateRush(rushes[id], id, map.steps)

		if not ok then
			return false, reason
		end
	end

	return true, "ok"
end

function SongSchema.validate(map: any): (boolean, string)
	if type(map.id) ~= "string" or map.id == "" then
		return false, "map.id is required"
	end

	if type(map.title) ~= "string" or map.title == "" then
		return false, "map.title is required"
	end

	if type(map.bpm) ~= "number" or map.bpm <= 0 then
		return false, "map.bpm must be positive"
	end

	if type(map.steps) ~= "table" or #map.steps == 0 then
		return false, "map.steps must contain at least one step"
	end

	if map.performanceGoal ~= nil then
		if type(map.performanceGoal) ~= "table" then
			return false, "map.performanceGoal must be a table"
		end

		if type(map.performanceGoal.targetScore) ~= "number" or map.performanceGoal.targetScore <= 0 then
			return false, "map.performanceGoal.targetScore must be positive"
		end
	end

	if map.sections ~= nil then
		local ok, reason = validateSections(map.sections)

		if not ok then
			return false, reason
		end
	end

	for index, step in map.steps do
		if type(step.beat) ~= "number" or type(step.x) ~= "number" or type(step.y) ~= "number" then
			return false, ("step %d must include beat, x, and y"):format(index)
		end

		if step.type ~= nil and SongSchema.StepTypes[step.type] ~= true then
			return false, ("step %d has unsupported type %s"):format(index, tostring(step.type))
		end

		if step.type == "slide" and type(step.path) ~= "table" then
			return false, ("step %d slide must include a path"):format(index)
		end

		if step.type == "hold" and step.holdSeconds ~= nil and (type(step.holdSeconds) ~= "number" or step.holdSeconds <= 0) then
			return false, ("step %d holdSeconds must be positive"):format(index)
		end

		if step.type == "item" and (step.path ~= nil or step.holdSeconds ~= nil) then
			return false, ("step %d item takes no path or holdSeconds"):format(index)
		end
	end

	if map.events ~= nil then
		local ok, reason = validateEvents(map.events)

		if not ok then
			return false, reason
		end
	end

	local eventsOk, eventsReason = validateEventSteps(map)

	if not eventsOk then
		return false, eventsReason
	end

	local movesOk, movesReason = validateMoves(map)

	if not movesOk then
		return false, movesReason
	end

	if SongSchema.noteCount(map) == 0 then
		return false, "map.steps must contain at least one note besides items"
	end

	for index, step in map.steps do
		if SongSchema.isItem(step) and itemClash(step, map.steps) then
			return false, ("step %d item clashes with a note on its beat"):format(index)
		end
	end

	return true, "ok"
end

return SongSchema
