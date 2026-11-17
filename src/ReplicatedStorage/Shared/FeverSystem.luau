local Timing = require(script.Parent.Timing)

local FeverSystem = {}

FeverSystem.ComboThreshold = 12
FeverSystem.HypeThreshold = 60
FeverSystem.DurationSeconds = Timing.FeverDurationSeconds
FeverSystem.CooldownSeconds = Timing.FeverCooldownSeconds
FeverSystem.ScoreBonusPerHit = 220
FeverSystem.HypeBonusPerHit = 2
FeverSystem.ItemExtendSeconds = Timing.FeverItemExtendSeconds

function FeverSystem.createState()
	return {
		activeUntil = 0,
		nextAllowedAt = 0,
		activations = 0,
		bonusScore = 0,
	}
end

function FeverSystem.isActive(state: any, now: number): boolean
	return state ~= nil and now < (state.activeUntil or 0)
end

function FeverSystem.tryActivate(state: any, combo: number, hype: number, now: number)
	if FeverSystem.isActive(state, now) then
		return false
	end

	if now < (state.nextAllowedAt or 0) then
		return false
	end

	if combo < FeverSystem.ComboThreshold or hype < FeverSystem.HypeThreshold then
		return false
	end

	state.activeUntil = now + FeverSystem.DurationSeconds
	state.nextAllowedAt = now + FeverSystem.DurationSeconds + FeverSystem.CooldownSeconds
	state.activations = (state.activations or 0) + 1

	return true
end

-- A pickup during Fever keeps it going a little longer, and pushes the
-- cooldown back with it so the gap between Fevers never shrinks.
function FeverSystem.extend(state: any, seconds: number, now: number): boolean
	if not FeverSystem.isActive(state, now) then
		return false
	end

	state.activeUntil += seconds
	state.nextAllowedAt = (state.nextAllowedAt or 0) + seconds

	return true
end

function FeverSystem.applyHitBonus(state: any, accepted: boolean, now: number): number
	if not accepted or not FeverSystem.isActive(state, now) then
		return 0
	end

	state.bonusScore = (state.bonusScore or 0) + FeverSystem.ScoreBonusPerHit
	return FeverSystem.ScoreBonusPerHit
end

function FeverSystem.snapshot(state: any, now: number, started: boolean?, bonusScore: number?)
	local active = FeverSystem.isActive(state, now)

	return {
		active = active,
		started = started == true,
		remainingSeconds = active and math.max(0, math.ceil((state.activeUntil or now) - now)) or 0,
		bonusScore = bonusScore or 0,
		activations = state.activations or 0,
	}
end

return FeverSystem
