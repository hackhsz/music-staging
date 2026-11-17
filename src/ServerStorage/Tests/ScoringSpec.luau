--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CrowdHype = require(Shared:WaitForChild("CrowdHype"))
local FeverSystem = require(Shared:WaitForChild("FeverSystem"))
local LifeGauge = require(Shared:WaitForChild("LifeGauge"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

return {
	["an item adds score but leaves the combo and grades alone"] = function()
		local state = Scoring.createState()
		Scoring.applyGrade(state, "Perfect")
		local before = state.score

		expect(Scoring.applyItem(state), Scoring.ItemBonus, "bonus")
		expect(state.score, before + Scoring.ItemBonus, "score")
		expect(state.combo, 1, "combo")
		expect(state.perfects, 1, "perfects")
		expect(state.itemsCollected, 1, "items")
	end,

	["combo milestones are 10, 25, 50, 100 and every hundred after"] = function()
		for _, combo in { 10, 25, 50, 100, 200, 700 } do
			expect(Scoring.isComboMilestone(combo), true, tostring(combo))
		end

		for _, combo in { 0, 1, 9, 11, 75, 150, 250 } do
			expect(Scoring.isComboMilestone(combo), false, tostring(combo))
		end
	end,

	["only a Miss breaks the combo"] = function()
		local state = Scoring.createState()

		for _, grade in { "Perfect", "Good", "Great", "Good" } do
			Scoring.applyGrade(state, grade)
		end

		expect(state.combo, 4, "Goods keep it")
		local _, shielded = Scoring.applyGrade(state, "Miss")
		expect(shielded, false, "no shield yet")
		expect(state.combo, 0, "broken")
	end,

	["the combo multiplies a hit's points in tiers"] = function()
		expect(Scoring.multiplierFor(0), 1, "none")
		expect(Scoring.multiplierFor(24), 1, "under 25")
		expect(Scoring.multiplierFor(25), 1.1, "25")
		expect(Scoring.multiplierFor(50), 1.25, "50")
		expect(Scoring.multiplierFor(99), 1.25, "99")
		expect(Scoring.multiplierFor(100), 1.5, "100")

		local state = Scoring.createState()
		state.combo = 99
		Scoring.applyGrade(state, "Perfect")
		local points = Scoring.Points.Perfect + 100 * Scoring.ComboBonusPerHit
		expect(state.score, math.floor(points * 1.5), "100th hit")
	end,

	["a shield charged at 50 absorbs one Miss and recharges at the next milestone"] = function()
		local state = Scoring.createState()

		for _ = 1, Scoring.ShieldCombo - 1 do
			Scoring.applyGrade(state, "Great")
		end

		expect(state.shieldReady, false, "not yet")
		Scoring.applyGrade(state, "Great")
		expect(state.shieldReady, true, "charged at 50")

		local _, shielded = Scoring.applyGrade(state, "Miss")
		expect(shielded, true, "absorbed")
		expect(state.combo, Scoring.ShieldCombo, "combo kept")
		expect(state.misses, 1, "still a Miss")
		expect(state.shieldReady, false, "spent")

		local _, second = Scoring.applyGrade(state, "Miss")
		expect(second, false, "once only")
		expect(state.combo, 0, "broken")

		state.combo = 99
		Scoring.applyGrade(state, "Perfect")
		expect(state.shieldReady, true, "recharged at 100")
	end,

	["a shape note earns its type bonus"] = function()
		local state = Scoring.createState()
		Scoring.applyGrade(state, "Great", { type = "shape" })
		expect(state.score, Scoring.Points.Great + Scoring.ComboBonusPerHit + Scoring.StepTypeBonus.shape, "score")
	end,

	["life is forgiving: easy never fails and normal survives a short streak"] = function()
		local life = LifeGauge.Start

		for _ = 1, 8 do
			life = LifeGauge.applyGrade(life, "Miss", "normal")
		end

		expect(LifeGauge.isFailed(life, "normal"), false, "eight misses on normal")
		expect(LifeGauge.isFailed(0, "easy"), false, "easy never fails")
		expect(LifeGauge.isFailed(0, "normal"), true, "normal empties")
		expect(LifeGauge.isFailed(0, "expert"), true, "expert empties")
		expect(LifeGauge.isFailed(0), true, "default is normal")
		assert(LifeGauge.getProfile("easy").missDrain < LifeGauge.getProfile("expert").missDrain, "easy drains less")
	end,

	["hype boosts stay inside the meter"] = function()
		expect(CrowdHype.boost(95, CrowdHype.MilestoneGain), CrowdHype.Max, "capped")
		expect(CrowdHype.boost(10, CrowdHype.ItemGain), 10 + CrowdHype.ItemGain, "added")
	end,

	["an item stretches a running Fever, never a cold one"] = function()
		local state = FeverSystem.createState()
		expect(FeverSystem.extend(state, FeverSystem.ItemExtendSeconds, 0), false, "no Fever yet")

		expect(FeverSystem.tryActivate(state, FeverSystem.ComboThreshold, FeverSystem.HypeThreshold, 0), true, "starts")
		local endsAt, nextAt = state.activeUntil, state.nextAllowedAt
		expect(FeverSystem.extend(state, FeverSystem.ItemExtendSeconds, 1), true, "extends")
		expect(state.activeUntil, endsAt + FeverSystem.ItemExtendSeconds, "longer")
		expect(state.nextAllowedAt, nextAt + FeverSystem.ItemExtendSeconds, "cooldown moves with it")
	end,

	["poses, claps and rushes pay a type bonus on a hit"] = function()
		for _, kind in { "pose", "clap", "rush" } do
			local plain, typed = Scoring.createState(), Scoring.createState()
			Scoring.applyGrade(plain, "Perfect", {})
			Scoring.applyGrade(typed, "Perfect", { type = kind })
			expect(typed.score - plain.score, Scoring.StepTypeBonus[kind], kind)
		end
	end,
}
