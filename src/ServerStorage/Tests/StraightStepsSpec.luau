--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SongMapCatalog = require(Shared:WaitForChild("SongMapCatalog"))
local StraightSteps = require(Shared:WaitForChild("StraightSteps"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function chart(steps: { any }): any
	return { bpm = 120, steps = steps }
end

local function assertInLine(steps: { any }, what: string)
	local at = nil
	local standStill = { danger = true, item = true, clap = true, pose = true, freeze = true }

	for _, step in steps do
		if standStill[step.type] then
			continue
		elseif step.zone ~= nil or step.event ~= nil or step.type == "slide" then
			at = nil
			continue
		end

		if at ~= nil and (step.type == nil or step.type == "hold") then
			assert(step.x == at.x or step.y == at.y, ("%s: diagonal at beat %s"):format(what, tostring(step.beat)))
		end

		at = step
	end
end

return {
	["a diagonal with room gets a corner on its own beat"] = function()
		local steps = StraightSteps.apply(chart({ { beat = 0, x = 3, y = 3 }, { beat = 4, x = 5, y = 4 } }), 0.5)

		expect(#steps, 3, "notes")
		expect(steps[2].beat, 3, "corner beat")
		expect(steps[2].x, 5, "corner x")
		expect(steps[2].y, 3, "corner y")
		expect(steps[3].x, 5, "target x")
		expect(steps[3].y, 4, "target y")
	end,

	["a short gap puts the corner half a beat out"] = function()
		local steps = StraightSteps.apply(chart({ { beat = 0, x = 3, y = 3 }, { beat = 1, x = 4, y = 4 } }), 0.5)

		expect(#steps, 3, "notes")
		expect(steps[2].beat, 0.5, "corner beat")
	end,

	["a diagonal with no room moves onto the line"] = function()
		local steps = StraightSteps.apply(chart({ { beat = 0, x = 3, y = 3 }, { beat = 1, x = 5, y = 4 } }), 1)

		expect(#steps, 2, "notes")
		expect(steps[2].x, 5, "moved x")
		expect(steps[2].y, 3, "moved y")
	end,

	["a corner avoids a danger tile"] = function()
		local steps = StraightSteps.apply(
			chart({
				{ beat = 0, x = 3, y = 3 },
				{ beat = 3.5, x = 5, y = 3, type = "danger" },
				{ beat = 4, x = 5, y = 4 },
			}),
			0.5
		)

		expect(steps[2].x, 3, "corner x")
		expect(steps[2].y, 4, "corner y")
	end,

	["a note before a pose is never moved"] = function()
		local steps = StraightSteps.apply(
			chart({
				{ beat = 0, x = 3, y = 3 },
				{ beat = 0.5, x = 4, y = 4 },
				{ beat = 1, x = 4, y = 4, type = "pose", poseBeats = 1 },
			}),
			1
		)

		expect(steps[2].x, 4, "x")
		expect(steps[2].y, 4, "y")
	end,

	["easy and normal charts have no diagonal targets"] = function()
		for _, map in SongMapCatalog.Maps do
			if map.difficulty == "easy" or map.difficulty == "normal" then
				assertInLine(map.steps, map.id)
			end
		end
	end,
}
