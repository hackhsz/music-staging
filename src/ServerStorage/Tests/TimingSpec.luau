--!strict
local Timing = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Timing"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

return {
	["beat 1 is time zero"] = function()
		expect(Timing.beatToSeconds(1, 120), 0, "beat 1")
		expect(Timing.beatToSeconds(2, 120), 0.5, "beat 2 at 120bpm")
		expect(Timing.beatToSeconds(3, 60), 2, "beat 3 at 60bpm")
	end,

	["grade boundaries are inclusive"] = function()
		local windows = Timing.getWindows("normal")
		expect(Timing.gradeWithWindows(windows.perfectWindow, 0, windows), "Perfect", "perfect edge")
		expect(Timing.gradeWithWindows(windows.greatWindow, 0, windows), "Great", "great edge")
		expect(Timing.gradeWithWindows(windows.goodWindow, 0, windows), "Good", "good edge")
		expect(Timing.gradeWithWindows(windows.badWindow, 0, windows), "Bad", "bad edge")
		expect(Timing.gradeWithWindows(windows.badWindow + 0.001, 0, windows), "Miss", "past bad")
	end,

	["grading is symmetric around the target"] = function()
		local windows = Timing.getWindows("hard")

		for _, offset in { 0.02, 0.07, 0.12, 0.3 } do
			expect(
				Timing.gradeWithWindows(offset, 0, windows),
				Timing.gradeWithWindows(-offset, 0, windows),
				"offset " .. tostring(offset)
			)
		end
	end,

	["every difficulty profile is complete and ordered"] = function()
		for name, profile in Timing.DifficultyProfiles do
			assert(profile.perfectWindow < profile.greatWindow, name .. ": perfect must be tighter than great")
			assert(profile.greatWindow < profile.goodWindow, name .. ": great must be tighter than good")
			assert(profile.goodWindow < profile.badWindow, name .. ": good must be tighter than bad")
			assert(profile.travelWindowBeats > 0, name .. ": travel window must be positive")
			assert(profile.stepSeconds > 0, name .. ": step seconds must be positive")
			assert(profile.highwayLeadSeconds > 0, name .. ": highway lead must be positive")
		end

		local order = { "easy", "normal", "hard", "expert" }

		for index = 2, #order do
			assert(
				Timing.getHighwayLeadSeconds(order[index]) < Timing.getHighwayLeadSeconds(order[index - 1]),
				order[index] .. ": notes should scroll faster than on " .. order[index - 1]
			)
		end
	end,

	["an unknown difficulty falls back to normal"] = function()
		local fallback = Timing.getWindows("does-not-exist")
		local normal = Timing.getWindows("normal")
		expect(fallback.perfectWindow, normal.perfectWindow, "unknown difficulty")
		expect(Timing.getStepSeconds("does-not-exist"), Timing.getStepSeconds("normal"), "unknown step seconds")
	end,

	["standing longer never lowers the grade"] = function()
		local order = { Miss = 0, Bad = 1, Good = 2, Great = 3, Perfect = 4 }
		local previous = -1

		for _, settle in { 0, 0.05, 0.15, 0.2, 0.25, 0.5 } do
			local rank = order[Timing.gradeStandAndWait(true, settle, 0.5)]
			assert(rank >= previous, "grade went down as settle time rose")
			previous = rank
		end
	end,

	["a player who is not on the tile always misses"] = function()
		expect(Timing.gradeStandAndWait(false, 10, 0.5), "Miss", "off tile")
	end,

	["analyzeMap flags a chart that outruns its travel budget"] = function()
		local report = Timing.analyzeMap({
			steps = {
				{ beat = 1, x = 1, y = 1 },
				{ beat = 2, x = 5, y = 5 },
			},
		}, "normal")

		expect(report.ok, false, "should flag the jump")
		assert(#report.warnings > 0, "expected a warning")
	end,

	["onBeat windows match the Music Game on normal and tighten with difficulty"] = function()
		local normal = Timing.getOnBeatWindows("normal")
		expect(normal.perfectWindow, 0.06, "normal perfect")
		expect(normal.greatWindow, 0.14, "normal great")
		expect(Timing.OnBeatLateGrace, 0.2, "late grace")

		local previous = Timing.getOnBeatWindows("easy")

		for _, difficulty in { "normal", "hard", "expert" } do
			local windows = Timing.getOnBeatWindows(difficulty)
			assert(windows.perfectWindow < previous.perfectWindow, difficulty .. " perfect should be tighter")
			assert(windows.greatWindow < previous.greatWindow, difficulty .. " great should be tighter")
			previous = windows
		end
	end,

	["a press on the heard beat is a Perfect on every difficulty"] = function()
		for difficulty in Timing.DifficultyProfiles do
			assert(
				math.abs(Timing.OnBeatLandDelay) <= Timing.getOnBeatWindows(difficulty).perfectWindow / 2,
				difficulty .. ": the land delay alone eats most of the Perfect window"
			)
		end
	end,

	["device default offsets stay small and inside the calibration clamp"] = function()
		for device, profile in Timing.DeviceProfiles do
			assert(profile.defaultOffsetSeconds >= 0, device .. ": negative default")
			assert(profile.defaultOffsetSeconds <= 0.1, device .. ": default too large to be device latency")
		end
	end,

	["eighth notes at 180 bpm fit one hop each on every difficulty"] = function()
		local eighth = 60 / 180 / 2

		for difficulty in Timing.DifficultyProfiles do
			assert(Timing.getStepSeconds(difficulty) < eighth, difficulty .. ": a hop outlasts an eighth note")
		end

		local order = { "easy", "normal", "hard", "expert" }

		for index = 2, #order do
			assert(
				Timing.getStepSeconds(order[index]) <= Timing.getStepSeconds(order[index - 1]),
				order[index] .. ": hops should not be slower than on " .. order[index - 1]
			)
		end
	end,
}
