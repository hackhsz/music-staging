--!strict
local AbilityCatalog = require(script.Parent.Catalogs.AbilityCatalog)

type Ability = AbilityCatalog.Ability

export type Running = { abilityId: string, endsAtBeat: number, uses: number? }

-- A charged ability waiting on the floor: standing on its tile fires it.
export type Pickup = { slot: number, x: number, y: number, untilBeat: number }

export type State = {
	loadout: { string },
	charge: number,
	readyAt: { [string]: number },
	running: { [string]: Running },
	lostCombo: number,
	activations: number,
	pickup: Pickup?,
	turn: number,
	lookAt: number,
}

export type Slot = {
	id: string,
	readyIn: number,
	beatsLeft: number?,
	usesLeft: number?,
}

export type Snapshot = { charge: number, maxCharge: number, slots: { Slot } }

local MULTIPLIERS = { "doublePoints", "overdrive" }
-- A pickup goes beside a note the chart leaves at least PICKUP_GAP_BEATS to
-- reach, so there is time for the detour, and only a few beats ahead, so it
-- shows up where the player is about to be.
local PICKUP_MIN_LEAD_BEATS = 2
local PICKUP_MAX_LEAD_BEATS = 12
local PICKUP_GAP_BEATS = 2
local PICKUP_CLEAR_STEPS = 3
local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- The run-time rules of abilities, shared so the client can predict what the
-- server will allow. The server owns the state and applies every effect.
local Abilities = {}

function Abilities.new(loadout: { string }): State
	return {
		loadout = AbilityCatalog.sanitizeLoadout(loadout),
		charge = AbilityCatalog.StartCharge,
		readyAt = {},
		running = {},
		lostCombo = 0,
		activations = 0,
		pickup = nil,
		turn = 0,
		lookAt = 0,
	}
end

function Abilities.gain(state: State, grade: string)
	local gain = AbilityCatalog.ChargePerGrade[grade] or 0
	state.charge = math.min(state.charge + gain, AbilityCatalog.MaxCharge)
end

-- The ability in slot, or nil and why it cannot go now.
function Abilities.check(state: State, slot: number, now: number, beat: number): (Ability?, string?)
	local id = state.loadout[slot]
	local ability = if id ~= nil then AbilityCatalog.get(id) else nil

	if ability == nil then
		return nil, "empty"
	elseif now < (state.readyAt[ability.id] or -math.huge) then
		return nil, "cooldown"
	elseif state.charge < ability.cost then
		return nil, "charge"
	elseif Abilities.isRunning(state, ability.effect, beat) then
		return nil, "running"
	end

	return ability, nil
end

function Abilities.activate(state: State, ability: Ability, now: number, beat: number)
	state.charge -= ability.cost
	state.readyAt[ability.id] = now + ability.cooldownSeconds
	state.activations += 1

	if ability.beats ~= nil then
		state.running[ability.effect] = { abilityId = ability.id, endsAtBeat = beat + ability.beats, uses = ability.uses }
	end
end

function Abilities.isRunning(state: State, effect: string, beat: number): boolean
	local running = state.running[effect]

	if running == nil then
		return false
	end

	if beat > running.endsAtBeat or (running.uses ~= nil and running.uses <= 0) then
		state.running[effect] = nil
		return false
	end

	return true
end

local function spend(state: State, effect: string)
	local running = state.running[effect]

	if running ~= nil and running.uses ~= nil then
		running.uses -= 1
	end
end

local function amountOf(state: State, effect: string, fallback: number): number
	local running = state.running[effect]
	local ability = if running ~= nil then AbilityCatalog.get(running.abilityId) else nil

	return if ability ~= nil and ability.amount ~= nil then ability.amount else fallback
end

-- The verdict after abilities have had their say, and whether one changed it.
function Abilities.judge(state: State, grade: string, stepType: string?, beat: number): (string, boolean)
	local original = grade

	if grade == "Miss" then
		if stepType == "danger" and Abilities.isRunning(state, "safeSteps", beat) then
			grade = "Great"
		elseif (stepType == "clap" or stepType == "pose") and Abilities.isRunning(state, "clapEcho", beat) then
			grade = "Great"
		elseif Abilities.isRunning(state, "lifeline", beat) then
			spend(state, "lifeline")
			grade = "Good"
		end
	end

	if grade == "Good" and Abilities.isRunning(state, "steadyFeet", beat) then
		grade = "Great"
	end

	if grade == "Great" and Abilities.isRunning(state, "goldenTouch", beat) then
		grade = "Perfect"
	end

	return grade, grade ~= original
end

-- Whether a Miss on this beat keeps the combo; spends the shield if so.
function Abilities.keepsCombo(state: State, beat: number): boolean
	if not Abilities.isRunning(state, "shield", beat) then
		return false
	end

	spend(state, "shield")

	return true
end

-- What a hit's points are multiplied by. Multipliers do not stack: the biggest wins.
function Abilities.pointsScale(state: State, beat: number): number
	local scale = 1

	for _, effect in MULTIPLIERS do
		if Abilities.isRunning(state, effect, beat) then
			scale = math.max(scale, amountOf(state, effect, 1))
		end
	end

	if Abilities.isRunning(state, "spotlight", beat) then
		scale = math.max(scale, amountOf(state, "spotlight", 1))
		spend(state, "spotlight")
	end

	return scale
end

function Abilities.lifeLossScale(state: State, beat: number): number
	return if Abilities.isRunning(state, "ironHeart", beat) then amountOf(state, "ironHeart", 1) else 1
end

function Abilities.hypeScale(state: State, beat: number): number
	return if Abilities.isRunning(state, "hypeWave", beat) then amountOf(state, "hypeWave", 1) else 1
end

function Abilities.noteComboBreak(state: State, lost: number)
	if lost > 0 then
		state.lostCombo = lost
	end
end

-- The combo Encore gives back, and forgets it so it cannot be claimed twice.
function Abilities.takeEncore(state: State, ability: Ability): number
	local back = math.floor(state.lostCombo * (ability.amount or 0.5))
	state.lostCombo = 0

	return back
end

-- The next slot, after the last one put on the floor, that could fire now.
function Abilities.nextReady(state: State, now: number, beat: number): number?
	local count = #state.loadout

	for offset = 0, count - 1 do
		local slot = (state.turn + offset) % count + 1

		if Abilities.check(state, slot, now, beat) ~= nil then
			return slot
		end
	end

	return nil
end

local function plain(step: any): boolean
	return step.type == nil or step.type == "bonus"
end

local function distance(from: { x: number, y: number }, to: { x: number, y: number }): number
	return math.abs(from.x - to.x) + math.abs(from.y - to.y)
end

-- The free tile beside an upcoming plain note nearest the note before it, and
-- the beat the pickup lasts until: that note's.
function Abilities.pickupSpot(
	steps: { any },
	fromIndex: number,
	beat: number,
	columns: number,
	rows: number,
	standing: { x: number, y: number }?
): ({ x: number, y: number }?, number?)
	for index = math.max(fromIndex, 2), #steps do
		local step, previous = steps[index], steps[index - 1]

		if step.beat > beat + PICKUP_MAX_LEAD_BEATS then
			return nil, nil
		end

		if
			step.beat < beat + PICKUP_MIN_LEAD_BEATS
			or step.beat - previous.beat < PICKUP_GAP_BEATS
			or not plain(step)
			or not plain(previous)
		then
			continue
		end

		local taken = {}

		for near = index - 1, math.min(index + PICKUP_CLEAR_STEPS, #steps) do
			taken[steps[near].x * rows + steps[near].y] = true
		end

		local best: { x: number, y: number }? = nil

		for _, offset in NEIGHBOURS do
			local spot = { x = step.x + offset[1], y = step.y + offset[2] }
			local inside = spot.x >= 1 and spot.x <= columns and spot.y >= 1 and spot.y <= rows
			local here = standing ~= nil and distance(standing, spot) == 0

			if inside and not here and not taken[spot.x * rows + spot.y] then
				if best == nil or distance(previous, spot) < distance(previous, best) then
					best = spot
				end
			end
		end

		if best ~= nil then
			return best, step.beat
		end
	end

	return nil, nil
end

function Abilities.snapshot(state: State, now: number, beat: number): Snapshot
	local slots = {}

	for _, id in state.loadout do
		local ability = AbilityCatalog.get(id)
		local effect: string? = if ability ~= nil then ability.effect else nil
		local running = if effect ~= nil and Abilities.isRunning(state, effect, beat) then state.running[effect] else nil
		local own = running ~= nil and running.abilityId == id

		table.insert(slots, {
			id = id,
			readyIn = math.max((state.readyAt[id] or 0) - now, 0),
			beatsLeft = if own and running then running.endsAtBeat - beat else nil,
			usesLeft = if own and running then running.uses else nil,
		})
	end

	return { charge = state.charge, maxCharge = AbilityCatalog.MaxCharge, slots = slots }
end

return Abilities
