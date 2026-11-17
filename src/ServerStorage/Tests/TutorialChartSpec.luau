--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FunnelCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("FunnelCatalog"))
local OnboardingCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("OnboardingCatalog"))
local SongSchema = require(Shared:WaitForChild("SongSchema"))
local TutorialChart = require(Shared:WaitForChild("TutorialChart"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

return {
	["every drill is a valid chart"] = function()
		for drill = 1, TutorialChart.DrillCount do
			local ok, reason = SongSchema.validate(TutorialChart.build(drill))
			assert(ok, ("drill %d: %s"):format(drill, tostring(reason)))
		end
	end,

	["the drills teach every kind of pad step"] = function()
		local seen: { [string]: boolean } = {}

		for drill = 1, TutorialChart.DrillCount do
			for _, step in TutorialChart.build(drill).steps do
				seen[step.type or "tap"] = true
			end
		end

		for _, kind in { "tap", "shape", "hold", "clap", "danger" } do
			assert(seen[kind], "no " .. kind .. " step")
		end
	end,

	["a drill id names its drill and nothing else does"] = function()
		for drill = 1, TutorialChart.DrillCount do
			expect(TutorialChart.drillOf(TutorialChart.drillId(drill)), drill, "drill " .. drill)
		end

		expect(TutorialChart.drillOf(TutorialChart.drillId(TutorialChart.DrillCount + 1)), nil, "past the last drill")
		expect(TutorialChart.drillOf("our-hearts"), nil, "a real song")
		expect(TutorialChart.drillOf(TutorialChart.Id), nil, "the bare lesson id")
	end,

	["each step is at most two tiles from the one before it"] = function()
		for drill = 1, TutorialChart.DrillCount do
			local last = { x = 3, y = 3 }

			for _, step in TutorialChart.build(drill).steps do
				if step.type == "danger" or step.type == "clap" then
					continue
				end

				local moves = math.abs(step.x - last.x) + math.abs(step.y - last.y)
				assert(moves <= 2, ("drill %d beat %.2f is %d tiles away"):format(drill, step.beat, moves))
				last = step
			end
		end
	end,

	["standing still on the start tile passes no drill"] = function()
		for drill = 1, TutorialChart.DrillCount do
			local steps = TutorialChart.build(drill).steps
			local misses = 0

			for _, step in steps do
				local tiles = step.zone or { { x = step.x, y = step.y } }
				local onStart = false

				for _, tile in tiles do
					onStart = onStart or (tile.x == 3 and tile.y == 3)
				end

				local landed = if step.type == "danger" then not onStart elseif step.type == "clap" then false else onStart

				if not landed then
					misses += 1
				end
			end

			expect(TutorialChart.passed({ totalSteps = #steps, misses = misses }), false, "idle on drill " .. drill)
		end
	end,

	["a drill passes at three of four landed"] = function()
		expect(TutorialChart.passed({ totalSteps = 4, misses = 1 }), true, "3 of 4")
		expect(TutorialChart.passed({ totalSteps = 4, misses = 2 }), false, "2 of 4")
		expect(TutorialChart.passed({ totalSteps = 8, misses = 2 }), true, "6 of 8")
		expect(TutorialChart.passed({ totalSteps = 0, misses = 0 }), false, "nothing played")
	end,

	["every drill and onboarding step has a funnel step"] = function()
		for _, drill in TutorialChart.Drills do
			assert(FunnelCatalog.stepIndex("onboarding", drill.funnelStep) ~= nil, drill.funnelStep)
		end

		for _, tip in OnboardingCatalog.Tips do
			assert(FunnelCatalog.stepIndex("onboarding", "tip_" .. tip.id) ~= nil, "tip_" .. tip.id)
			assert(OnboardingCatalog.isStep(tip.id), tip.id)
		end

		assert(OnboardingCatalog.isStep(OnboardingCatalog.TimingCheck.id), "timing")
		expect(OnboardingCatalog.isStep("anything"), false, "unknown step")
	end,

	["server-only funnel steps cannot be reported by the client"] = function()
		expect(FunnelCatalog.isClientStep("onboarding", "tutorial_done"), false, "tutorial_done")
		expect(FunnelCatalog.isClientStep("onboarding", "drill_step"), false, "drill_step")
		expect(FunnelCatalog.isClientStep("shop", "purchased"), false, "purchased")
		expect(FunnelCatalog.isClientStep("run", "started"), false, "run started")
		expect(FunnelCatalog.isClientStep("nope", "opened"), false, "unknown funnel")
		expect(FunnelCatalog.isClientStep("onboarding", "loaded"), true, "loaded")
	end,
}
