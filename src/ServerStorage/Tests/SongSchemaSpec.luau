--!strict
local SongSchema = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SongSchema"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function map(steps: { any }, sections: any?): any
	return { id = "spec", title = "Spec", bpm = 120, steps = steps, sections = sections }
end

local function withEvents(steps: { any }, events: { any }): any
	local chart = map(steps)
	chart.events = events
	return chart
end

local function lavaChart(): any
	return withEvents({
		{ beat = 1, x = 3, y = 3 },
		{ beat = 5, x = 3, y = 4, event = 1, zone = { { x = 3, y = 4 }, { x = 1, y = 1 } } },
		{ beat = 6, x = 4, y = 4, event = 1, zone = { { x = 4, y = 4 } } },
		{ beat = 8, x = 4, y = 3 },
	}, { { beat = 5, beats = 2, kind = "lava" } })
end

local function memoryChart(): any
	return withEvents({
		{ beat = 1, x = 3, y = 3 },
		{ beat = 9, x = 3, y = 2, event = 1, hidden = true },
		{ beat = 10, x = 4, y = 2, event = 1, hidden = true },
		{ beat = 11, x = 4, y = 3, event = 1, hidden = true },
		{ beat = 13, x = 3, y = 3 },
	}, {
		{
			beat = 5,
			beats = 7,
			kind = "memory",
			interval = 1,
			playBeat = 9,
			sequence = { { x = 3, y = 2 }, { x = 4, y = 2 }, { x = 4, y = 3 } },
		},
	})
end

return {
	["an item is a valid step type"] = function()
		local ok, reason = SongSchema.validate(map({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 4, y = 3, type = "item" },
			{ beat = 3, x = 4, y = 4 },
		}))
		expect(ok, true, reason)
	end,

	["items are not notes"] = function()
		local chart = map({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 4, y = 3, type = "item" },
			{ beat = 3, x = 4, y = 4, type = "danger" },
		})
		expect(SongSchema.noteCount(chart), 2, "note count")

		local notes, items = SongSchema.splitItems(chart.steps)
		expect(#notes, 2, "notes")
		expect(#items, 1, "items")
		expect(notes[2].beat, 3, "notes keep their order")
		expect(items[1].x, 4, "the item")
	end,

	["a chart of only items is rejected"] = function()
		expect(SongSchema.validate(map({ { beat = 1, x = 3, y = 3, type = "item" } })), false, "items only")
	end,

	["an item cannot share its beat with a note elsewhere"] = function()
		expect(SongSchema.validate(map({
			{ beat = 2, x = 1, y = 1 },
			{ beat = 2, x = 5, y = 5, type = "item" },
		})), false, "note on another tile")
		expect(SongSchema.validate(map({
			{ beat = 2, x = 5, y = 5 },
			{ beat = 2, x = 5, y = 5, type = "item" },
		})), false, "note on the same tile")
		expect(SongSchema.validate(map({
			{ beat = 2, x = 5, y = 5, type = "danger" },
			{ beat = 2, x = 5, y = 5, type = "item" },
		})), false, "danger on the same tile")
		expect(SongSchema.validate(map({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 1, y = 1, type = "danger" },
			{ beat = 2, x = 5, y = 5, type = "item" },
		})), true, "danger elsewhere is fine")
	end,

	["an item takes no path or hold"] = function()
		expect(SongSchema.validate(map({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 4, y = 3, type = "item", holdSeconds = 1 },
		})), false, "item hold")
	end,

	["sections are optional, ordered and use known energies"] = function()
		local steps = { { beat = 1, x = 3, y = 3 } }
		expect(SongSchema.validate(map(steps)), true, "no sections")
		expect(SongSchema.validate(map(steps, {
			{ beat = 1, energy = "calm" },
			{ beat = 17, energy = "build" },
			{ beat = 33, energy = "drop" },
		})), true, "good sections")
		expect(SongSchema.validate(map(steps, { { beat = 1, energy = "loud" } })), false, "unknown energy")
		expect(SongSchema.validate(map(steps, { { beat = 9, energy = "calm" }, { beat = 9, energy = "drop" } })), false, "unordered")
		expect(SongSchema.validate(map(steps, { { beat = 0, energy = "calm" } })), false, "before the song")
		expect(SongSchema.validate(map(steps, "calm")), false, "not a list")
	end,

	["lava and memory events validate"] = function()
		local ok, reason = SongSchema.validate(lavaChart())
		expect(ok, true, reason)
		ok, reason = SongSchema.validate(memoryChart())
		expect(ok, true, reason)
	end,

	["a freeze is a freeze step a beat inside a freeze event"] = function()
		local chart = withEvents({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 3, x = 3, y = 3, type = "freeze", event = 1 },
			{ beat = 4, x = 3, y = 3, type = "freeze", event = 1 },
			{ beat = 6, x = 2, y = 3 },
		}, { { beat = 3, beats = 2, kind = "freeze" } })
		local ok, reason = SongSchema.validate(chart)
		expect(ok, true, reason)

		chart.events = nil
		expect(SongSchema.validate(chart), false, "freeze without an event")
	end,

	["nothing else may happen inside an event"] = function()
		local chart = lavaChart()
		table.insert(chart.steps, 3, { beat = 5.5, x = 2, y = 2, type = "item" })
		expect(SongSchema.validate(chart), false, "an item inside the lava")
	end,

	["zone and memory steps must match their event"] = function()
		local chart = lavaChart()
		chart.steps[2].zone = { { x = 1, y = 1 } }
		expect(SongSchema.validate(chart), false, "zone without its own tile")

		local memory = memoryChart()
		memory.steps[3].x = 5
		expect(SongSchema.validate(memory), false, "memory replays another tile")

		memory = memoryChart()
		memory.steps[2].hidden = nil
		expect(SongSchema.validate(memory), false, "memory step not hidden")

		memory = memoryChart()
		memory.events[1].playBeat = 6
		expect(SongSchema.validate(memory), false, "plays before the sequence is shown")
	end,

	["events are ordered, known and short"] = function()
		local chart = lavaChart()
		chart.events[1].kind = "earthquake"
		expect(SongSchema.validate(chart), false, "unknown kind")

		chart = lavaChart()
		chart.events[1].beats = 40
		expect(SongSchema.validate(chart), false, "too long")
	end,

	["a shape is a zone note outside events"] = function()
		local square = { { x = 3, y = 3 }, { x = 4, y = 3 }, { x = 3, y = 4 }, { x = 4, y = 4 } }
		local ok, reason = SongSchema.validate(map({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 4, y = 4, type = "shape", zone = square },
		}))
		expect(ok, true, reason)
		expect(SongSchema.isShape({ type = "shape" }), true, "isShape")
		expect(SongSchema.isShape({ type = "tap" }), false, "a tap is not")

		local lone = SongSchema.validate(map({ { beat = 1, x = 3, y = 3, type = "shape", zone = { { x = 3, y = 3 } } } }))
		expect(lone, false, "one tile is not a shape")
		local five = table.clone(square)
		table.insert(five, { x = 5, y = 5 })
		expect(SongSchema.validate(map({ { beat = 1, x = 3, y = 3, type = "shape", zone = five } })), false, "too many tiles")
		local away = SongSchema.validate(map({ { beat = 1, x = 1, y = 1, type = "shape", zone = square } }))
		expect(away, false, "its own tile must be in the zone")
		expect(SongSchema.validate(map({ { beat = 1, x = 3, y = 3, type = "shape" } })), false, "needs a zone")
	end,

	["other zone steps still need an event, and shapes stay out of them"] = function()
		local zone = { { x = 3, y = 3 }, { x = 4, y = 3 } }
		expect(SongSchema.validate(map({ { beat = 1, x = 3, y = 3, zone = zone } })), false, "a tap with a zone")

		local chart = lavaChart()
		chart.steps[2].type = "shape"
		expect(SongSchema.validate(chart), false, "a shape inside a lava event")
	end,

	["off the pad, a shape is a plain step on its own tile"] = function()
		local shape = { beat = 2, x = 4, y = 3, type = "shape", zone = { { x = 4, y = 3 }, { x = 5, y = 3 } } }
		local plain = SongSchema.withoutEvents({ shape })[1]
		expect(plain.type, nil, "type")
		expect(plain.zone, nil, "zone")
		expect(plain.x, 4, "x")
		expect(shape.type, "shape", "the chart is untouched")
	end,

	["off the pad, events become plain steps"] = function()
		local steps = SongSchema.withoutEvents({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 3, y = 3, type = "freeze", event = 1 },
			{ beat = 3, x = 2, y = 3, event = 2, hidden = true },
			{ beat = 4, x = 2, y = 4, event = 3, zone = { { x = 2, y = 4 } } },
		})
		expect(#steps, 3, "the freeze is dropped")
		expect(steps[2].hidden, nil, "not hidden")
		expect(steps[3].zone, nil, "no zone")
		expect(steps[3].event, nil, "no event")
	end,

	["the energy at a beat is the last section started"] = function()
		local sections = { { beat = 1, energy = "calm" }, { beat = 17, energy = "chorus" } }
		expect(SongSchema.energyAt(sections, 1), "calm", "first beat")
		expect(SongSchema.energyAt(sections, 16.9), "calm", "just before")
		expect(SongSchema.energyAt(sections, 17), "chorus", "on the change")
		expect(SongSchema.energyAt({ { beat = 5, energy = "drop" } }, 2), nil, "before any section")
		expect(SongSchema.energyAt(nil, 3), nil, "no sections")
	end,

	["a pose holds the tile it follows, with room after it"] = function()
		local function pose(poseBeats: any): any
			return map({
				{ beat = 1, x = 3, y = 3 },
				{ beat = 2, x = 3, y = 3, type = "pose", poseBeats = poseBeats },
				{ beat = 5, x = 3, y = 2 },
			})
		end

		expect(SongSchema.validate(pose(2)), true, "a two beat pose")
		expect(SongSchema.validate(pose(0)), false, "no beats")
		expect(SongSchema.validate(pose(5)), false, "too long")
		expect(SongSchema.validate(pose(3)), false, "the next note comes too soon")
		expect(SongSchema.isPose(pose(2).steps[2]), true, "isPose")
		expect(SongSchema.poseBeatsOf(pose(2).steps[2]), 2, "poseBeatsOf")
		expect(SongSchema.poseBeatsOf(pose(2).steps[1]), 0, "a step has none")

		local moved = pose(2)
		moved.steps[2].x = 4
		expect(SongSchema.validate(moved), false, "not on the tile before it")

		local danger = pose(2)
		table.insert(danger.steps, 3, { beat = 3, x = 1, y = 1, type = "danger" })
		expect(SongSchema.validate(danger), true, "a danger elsewhere during it")
		danger.steps[3].x, danger.steps[3].y = 3, 3
		expect(SongSchema.validate(danger), false, "a danger on its tile")
	end,

	["a clap stands alone on its beat"] = function()
		local chart = map({ { beat = 1, x = 3, y = 3 }, { beat = 2, x = 3, y = 3, type = "clap" }, { beat = 3, x = 3, y = 2 } })
		expect(SongSchema.validate(chart), true, "a clap")
		expect(SongSchema.isClap(chart.steps[2]), true, "isClap")
		table.insert(chart.steps, 3, { beat = 2, x = 2, y = 3 })
		expect(SongSchema.validate(chart), false, "a step on its beat")
		chart.steps[3].type = "danger"
		expect(SongSchema.validate(chart), true, "a danger elsewhere on its beat")
	end,

	["a rush runs tile to tile from the note before it"] = function()
		local function rush(): any
			return map({
				{ beat = 1, x = 3, y = 3 },
				{ beat = 2, x = 3, y = 2, type = "rush", rush = 1 },
				{ beat = 2.5, x = 3, y = 1, type = "rush", rush = 1 },
				{ beat = 3, x = 4, y = 1, type = "rush", rush = 1 },
				{ beat = 4, x = 4, y = 2 },
			})
		end

		expect(SongSchema.validate(rush()), true, "a turning rush")
		expect(#SongSchema.rushGroup(rush().steps, 3), 3, "the group")
		expect(#SongSchema.rushGroup(rush().steps, 1), 0, "a plain step has no group")

		local gap = rush()
		gap.steps[3].x = 2
		expect(SongSchema.validate(gap), false, "a tile skipped")

		local short = rush()
		table.remove(short.steps, 4)
		expect(SongSchema.validate(short), false, "too short")

		local far = rush()
		far.steps[1].x = 1
		expect(SongSchema.validate(far), false, "starts away from the note before")

		local noId = rush()
		noId.steps[2].rush = nil
		expect(SongSchema.validate(noId), false, "no rush id")

		local crowded = rush()
		table.insert(crowded.steps, 3, { beat = 2.25, x = 5, y = 5 })
		expect(SongSchema.validate(crowded), false, "a note inside the path")
	end,

	["off the pad, poses and claps go and rushes are plain steps"] = function()
		local steps = SongSchema.withoutEvents({
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 3, y = 3, type = "pose", poseBeats = 1 },
			{ beat = 4, x = 3, y = 3, type = "clap" },
			{ beat = 5, x = 3, y = 2, type = "rush", rush = "a" },
		})
		expect(#steps, 2, "pose and clap dropped")
		expect(steps[2].type, nil, "rush type")
		expect(steps[2].rush, nil, "rush id")
	end,
}
