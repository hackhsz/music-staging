--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local AbilityCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function charged(loadout: { string }): Abilities.State
	local state = Abilities.new(loadout)
	state.charge = AbilityCatalog.MaxCharge

	return state
end

local function fire(state: Abilities.State, slot: number, now: number, beat: number): AbilityCatalog.Ability
	local ability, reason = Abilities.check(state, slot, now, beat)
	assert(ability ~= nil, "could not fire: " .. tostring(reason))
	Abilities.activate(state, ability, now, beat)

	return ability
end

return {
	["there are 10 to 20 abilities with unique ids and sane numbers"] = function()
		local count = #AbilityCatalog.Abilities
		assert(count >= 10 and count <= 20, "ability count " .. count)
		local seen = {}

		for _, ability in AbilityCatalog.Abilities do
			assert(not seen[ability.id], "duplicate id " .. ability.id)
			seen[ability.id] = true
			assert(ability.cost > 0 and ability.cost <= AbilityCatalog.MaxCharge, ability.id .. " cost")
			assert(ability.cooldownSeconds > 0, ability.id .. " cooldown")
		end
	end,

	["a loadout keeps four known, distinct ids and fills gaps from the default"] = function()
		local loadout = AbilityCatalog.sanitizeLoadout({ "overdrive", "overdrive", "nope", 7 :: any })
		expect(#loadout, AbilityCatalog.Slots, "slots")
		expect(loadout[1], "overdrive", "kept the first")
		expect(table.find(loadout, "nope"), nil, "unknown dropped")
		expect(#AbilityCatalog.sanitizeLoadout(nil), AbilityCatalog.Slots, "nil loadout")
	end,

	["charge comes from good grades only and caps at the bar"] = function()
		local state = Abilities.new({})
		expect(state.charge, AbilityCatalog.StartCharge, "starting charge")
		Abilities.gain(state, "Miss")
		expect(state.charge, AbilityCatalog.StartCharge, "miss")
		Abilities.gain(state, "Perfect")
		expect(state.charge, AbilityCatalog.StartCharge + AbilityCatalog.ChargePerGrade.Perfect, "perfect")

		for _ = 1, 100 do
			Abilities.gain(state, "Perfect")
		end

		expect(state.charge, AbilityCatalog.MaxCharge, "capped")
	end,

	["an ability needs charge, then waits out its cooldown"] = function()
		local state = Abilities.new({ "crowd-call" })
		state.charge = 0
		local _, reason = Abilities.check(state, 1, 0, 1)
		expect(reason, "charge", "no charge")
		state.charge = AbilityCatalog.MaxCharge
		local ability = fire(state, 1, 0, 1)
		expect(state.charge, AbilityCatalog.MaxCharge - ability.cost, "paid")
		_, reason = Abilities.check(state, 1, ability.cooldownSeconds - 1, 1)
		expect(reason, "cooldown", "cooling")
		assert(Abilities.check(state, 1, ability.cooldownSeconds, 1) ~= nil, "ready again")
	end,

	["a timed ability ends after its beats"] = function()
		local state = charged({ "double-time" })
		local ability = fire(state, 1, 0, 10)
		expect(Abilities.pointsScale(state, 10 + (ability.beats :: number)), 2, "last beat")
		expect(Abilities.pointsScale(state, 11 + (ability.beats :: number)), 1, "after")
	end,

	["the shield saves one combo, then is spent"] = function()
		local state = charged({ "beat-shield" })
		fire(state, 1, 0, 1)
		expect(Abilities.keepsCombo(state, 2), true, "first miss")
		expect(Abilities.keepsCombo(state, 3), false, "second miss")
	end,

	["lifeline turns one Miss into a Good"] = function()
		local state = charged({ "lifeline" })
		fire(state, 1, 0, 1)
		expect((Abilities.judge(state, "Miss", nil, 2)), "Good", "saved")
		expect((Abilities.judge(state, "Miss", nil, 3)), "Miss", "spent")
	end,

	["safe steps only forgive danger tiles"] = function()
		local state = charged({ "safe-steps" })
		fire(state, 1, 0, 1)
		expect((Abilities.judge(state, "Miss", "danger", 2)), "Great", "danger")
		expect((Abilities.judge(state, "Miss", "tap", 2)), "Miss", "tap")
	end,

	["steady feet and golden touch lift grades a tier each"] = function()
		local state = charged({ "steady-feet", "golden-touch" })
		fire(state, 1, 0, 1)
		expect((Abilities.judge(state, "Good", nil, 2)), "Great", "steady")
		state.charge = AbilityCatalog.MaxCharge
		fire(state, 2, 0, 1)
		expect((Abilities.judge(state, "Good", nil, 2)), "Perfect", "both")
		expect((Abilities.judge(state, "Miss", nil, 2)), "Miss", "a miss stays a miss")
	end,

	["point multipliers do not stack and spotlight runs out"] = function()
		local state = charged({ "double-time", "spotlight" })
		fire(state, 1, 0, 1)
		state.charge = AbilityCatalog.MaxCharge
		fire(state, 2, 0, 1)
		expect(Abilities.pointsScale(state, 2), 3, "biggest wins")

		for _ = 1, 3 do
			Abilities.pointsScale(state, 2)
		end

		expect(Abilities.pointsScale(state, 2), 2, "spotlight spent")
	end,

	["the same effect cannot run twice at once"] = function()
		local state = charged({ "double-time" })
		local ability = fire(state, 1, 0, 1)
		state.readyAt[ability.id] = 0
		local _, reason = Abilities.check(state, 1, 1, 2)
		expect(reason, "running", "already running")
	end,

	["encore gives back half the lost combo once"] = function()
		local state = charged({ "encore" })
		Abilities.noteComboBreak(state, 41)
		local ability = fire(state, 1, 0, 1)
		expect(Abilities.takeEncore(state, ability), 20, "half")
		expect(Abilities.takeEncore(state, ability), 0, "once")
	end,

	["the snapshot shows cooldowns and what is running"] = function()
		local state = charged({ "double-time", "crowd-call" })
		local ability = fire(state, 1, 0, 1)
		local snapshot = Abilities.snapshot(state, 1, 3)
		expect(snapshot.slots[1].readyIn, ability.cooldownSeconds - 1, "cooldown")
		expect(snapshot.slots[1].beatsLeft, (ability.beats :: number) - 2, "beats left")
		expect(snapshot.slots[2].beatsLeft, nil, "idle slot")
	end,

	["the next pickup takes the charged slots in turn"] = function()
		local state = charged({ "crowd-call", "beat-shield", "second-wind", "encore" })
		expect(Abilities.nextReady(state, 0, 1), 1, "first slot first")
		state.turn = 1
		expect(Abilities.nextReady(state, 0, 1), 2, "then the next")
		state.charge = 0
		expect(Abilities.nextReady(state, 0, 1), nil, "nothing charged")
	end,

	["a pickup lands beside a note there is time to detour to"] = function()
		local steps = {
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 3, y = 2 },
			{ beat = 4, x = 4, y = 2 },
			{ beat = 5, x = 5, y = 2 },
		}
		local spot, untilBeat = Abilities.pickupSpot(steps, 1, 1, 5, 5, nil)
		assert(spot ~= nil, "no spot")
		expect(untilBeat, 4, "lasts until the note after the gap")
		expect(math.abs(spot.x - 4) + math.abs(spot.y - 2), 1, "beside that note")
		assert(not (spot.x == 3 and spot.y == 2), "not on the note before")
		assert(not (spot.x == 5 and spot.y == 2), "not on a note after")
		assert(math.abs(spot.x - 3) + math.abs(spot.y - 2) <= 2, "one hop off the way")
	end,

	["no pickup without a gap or too close to the beat"] = function()
		local tight = {
			{ beat = 1, x = 3, y = 3 },
			{ beat = 2, x = 3, y = 2 },
			{ beat = 3, x = 4, y = 2 },
		}
		expect(Abilities.pickupSpot(tight, 1, 1, 5, 5, nil), nil, "one beat apart")

		local soon = {
			{ beat = 1, x = 3, y = 3 },
			{ beat = 3, x = 3, y = 2 },
		}
		expect(Abilities.pickupSpot(soon, 1, 2, 5, 5, nil), nil, "a beat away")
	end,
}
