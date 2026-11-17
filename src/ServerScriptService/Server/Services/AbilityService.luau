--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local Board = require(Shared:WaitForChild("Board"))
local AbilityCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local CrowdHype = require(Shared:WaitForChild("CrowdHype"))
local FeverSystem = require(Shared:WaitForChild("FeverSystem"))
local LifeGauge = require(Shared:WaitForChild("LifeGauge"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local Timing = require(Shared:WaitForChild("Timing"))

-- How often a run with nothing on the floor looks for a charged ability to put there.
local PICKUP_LOOK_SECONDS = 0.25
-- A pickup that fired nothing, such as a heal at full life, waits this long to come back.
local PICKUP_REFUSED_SECONDS = 4
-- A pickup stays a moment past its note's beat, for a player stepping off that note onto it.
local PICKUP_LINGER_BEATS = 0.5

-- The meters a verdict or an instant ability changed, taken before the change.
export type Before = { combo: number, score: number, hype: number, life: number }

type Fields = {
	stateRemote: RemoteEvent,
}

-- Runs a player's abilities inside RhythmService's session state: the server
-- alone decides when one may fire and what it does to a verdict.
local AbilityService = {}
AbilityService.__index = AbilityService

export type AbilityService = typeof(setmetatable({} :: Fields, AbilityService))

function AbilityService.new(stateRemote: RemoteEvent): AbilityService
	local fields: Fields = { stateRemote = stateRemote }

	return setmetatable(fields, AbilityService)
end

local function beatOf(state: any, now: number): number
	return state.session:getElapsed(now) / Timing.beatSeconds(state.session.map.bpm) + 1
end

function AbilityService.before(_self: AbilityService, state: any): Before
	return {
		combo = state.scoreState.combo,
		score = state.scoreState.score,
		hype = state.hype,
		life = state.life,
	}
end

function AbilityService.begin(self: AbilityService, player: Player, state: any, loadout: { string }?, enabled: boolean)
	state.abilities = if enabled then Abilities.new(loadout or AbilityCatalog.DefaultLoadout) else nil
	self:push(player, state, os.clock())
end

function AbilityService.push(self: AbilityService, player: Player, state: any, now: number, extra: { [string]: any }?)
	local abilities = state.abilities
	local payload: { [string]: any } = { enabled = abilities ~= nil }

	if abilities ~= nil then
		local snapshot = Abilities.snapshot(abilities, now, beatOf(state, now))
		payload.loadout = abilities.loadout
		payload.charge = snapshot.charge
		payload.maxCharge = snapshot.maxCharge
		payload.slots = snapshot.slots
		payload.pickup = abilities.pickup
	end

	if extra ~= nil then
		for key, value in extra do
			payload[key] = value
		end
	end

	self.stateRemote:FireClient(player, payload)
end

-- The verdict an ability turns it into, before anything is scored.
function AbilityService.judge(_self: AbilityService, state: any, result: any, step: any, now: number)
	local abilities = state.abilities

	if abilities == nil then
		return
	end

	local grade, changed = Abilities.judge(abilities, result.grade, step.type, beatOf(state, now))

	if changed then
		result.grade = grade
		result.accepted = grade ~= "Miss"
		result.reason = nil
		result.abilityChanged = true
	end
end

-- After the verdict is scored: a shield keeps the combo, multipliers scale the
-- points, hype and life the verdict just moved, and good play charges the bar.
-- Returns whether the combo was kept.
function AbilityService.settle(self: AbilityService, player: Player, state: any, grade: string, before: Before, now: number): boolean
	local abilities = state.abilities

	if abilities == nil then
		return false
	end

	local beat = beatOf(state, now)
	local scoreState = state.scoreState
	local kept = false

	if grade == "Miss" and before.combo > 0 and scoreState.combo == 0 then
		if Abilities.keepsCombo(abilities, beat) then
			scoreState.combo = before.combo
			kept = true
		else
			Abilities.noteComboBreak(abilities, before.combo)
		end
	end

	local gained = scoreState.score - before.score

	if gained > 0 then
		local bonus = math.floor(gained * (Abilities.pointsScale(abilities, beat) - 1))
		scoreState.score += bonus
	end

	local hype = state.hype - before.hype

	if hype > 0 then
		state.hype = math.clamp(before.hype + hype * Abilities.hypeScale(abilities, beat), 0, CrowdHype.Max)
	end

	local lost = before.life - state.life

	if lost > 0 then
		state.life = math.clamp(before.life - lost * Abilities.lifeLossScale(abilities, beat), 0, LifeGauge.Max)
	end

	Abilities.gain(abilities, grade)
	self:push(player, state, now)

	return kept
end

local function meters(state: any, now: number): { [string]: any }
	return {
		score = state.scoreState.score,
		combo = state.scoreState.combo,
		hype = state.hype,
		life = state.life,
		maxLife = LifeGauge.Max,
		fever = FeverSystem.snapshot(state.feverState, now, false, 0),
	}
end

-- An instant ability's whole effect; false when it would do nothing now.
local function applyInstant(state: any, ability: AbilityCatalog.Ability, now: number): boolean
	local scoreState = state.scoreState
	local effect = ability.effect

	if effect == "heal" then
		if state.life >= LifeGauge.Max then
			return false
		end

		state.life = math.min(state.life + (ability.amount or 0), LifeGauge.Max)
	elseif effect == "crowd" then
		state.hype = CrowdHype.boost(state.hype, ability.amount or 0)
	elseif effect == "comboSurge" then
		scoreState.combo += ability.amount or 0
		scoreState.maxCombo = math.max(scoreState.maxCombo, scoreState.combo)
	elseif effect == "encore" then
		local back = Abilities.takeEncore(state.abilities, ability)

		if back <= 0 then
			return false
		end

		scoreState.combo += back
		scoreState.maxCombo = math.max(scoreState.maxCombo, scoreState.combo)
	elseif effect == "fever" then
		-- Fever's own cooldown still holds, so this can bring one forward but never chain them.
		return FeverSystem.tryActivate(state.feverState, math.huge, CrowdHype.Max, now)
	end

	return true
end

-- Puts the next charged ability on the floor, and fires it once the server
-- sees the player standing on its tile.
function AbilityService.tick(self: AbilityService, player: Player, state: any, now: number)
	local abilities = state.abilities

	if abilities == nil or state.completed or now < state.session.startTime or now < abilities.lookAt then
		return
	end

	local beat = beatOf(state, now)
	local pickup = abilities.pickup

	if pickup ~= nil then
		local coord = state.currentCoord

		if coord ~= nil and coord.x == pickup.x and coord.y == pickup.y then
			abilities.pickup = nil

			if not self:activate(player, state, pickup.slot, now) then
				abilities.lookAt = now + PICKUP_REFUSED_SECONDS
			end
		elseif beat > pickup.untilBeat + PICKUP_LINGER_BEATS then
			abilities.pickup = nil
			self:push(player, state, now)
		end

		return
	end

	abilities.lookAt = now + PICKUP_LOOK_SECONDS

	local slot = Abilities.nextReady(abilities, now, beat)

	if slot == nil then
		return
	end

	local session = state.session
	local spot, untilBeat =
		Abilities.pickupSpot(session.map.steps, session.nextStepIndex, beat, Board.Columns, Board.Rows, state.currentCoord)

	if spot == nil or untilBeat == nil then
		return
	end

	abilities.pickup = { slot = slot, x = spot.x, y = spot.y, untilBeat = untilBeat }
	abilities.turn = slot
	self:push(player, state, now)
end

-- Returns whether it fired, and why not if it did not.
function AbilityService.activate(self: AbilityService, player: Player, state: any, slot: number, now: number): (boolean, string?)
	local abilities = state.abilities

	if abilities == nil then
		return false, "disabled"
	end

	if state.paused or state.completed or now < state.session.startTime then
		self:push(player, state, now, { refused = { slot = slot, reason = "not_now" } })
		return false, "not_now"
	end

	local beat = beatOf(state, now)
	local ability, reason = Abilities.check(abilities, slot, now, beat)

	if ability == nil then
		self:push(player, state, now, { refused = { slot = slot, reason = reason } })
		return false, reason
	end

	if ability.beats == nil and not applyInstant(state, ability, now) then
		self:push(player, state, now, { refused = { slot = slot, reason = "nothing" } })
		return false, "nothing"
	end

	Abilities.activate(abilities, ability, now, beat)
	self:push(player, state, now, {
		used = { slot = slot, id = ability.id },
		meters = meters(state, now),
		multiplier = Scoring.multiplierFor(state.scoreState.combo),
	})

	return true, nil
end

return AbilityService
