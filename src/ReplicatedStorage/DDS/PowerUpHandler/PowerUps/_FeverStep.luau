local FEVER_BEATS = 8
local FEVER_SCORE_BOOST = 2
local POPUP_TEXT = "FEVER"

local function isActive(state, controller): boolean
	return controller.clock:getBeat() < state.activeUntilBeat
end

return {
	DisplayName = "Fever Step",
	Description = "Free mod: a full hype meter banks Fever instead of the flat bonus. Press E (Y on gamepad) for double judgement score over 8 beats.",
	Kind = "Mod",
	Order = 22,
	ScoreMultiplier = 1,
	Init = function(state)
		state.ready = false
		state.activeUntilBeat = -math.huge
	end,
	OnHypeFull = function(state)
		state.ready = true
		return true
	end,
	AbilityReady = function(state)
		return state.ready
	end,
	OnAbility = function(state, controller)
		if not state.ready then
			return nil
		end
		state.ready = false
		state.activeUntilBeat = controller.clock:getBeat() + FEVER_BEATS
		controller.hype = 0
		controller:playSfx("CheerFever")
		controller:perfectFlash()
		return POPUP_TEXT
	end,
	ScoreBoost = function(state, controller)
		if isActive(state, controller) then
			return FEVER_SCORE_BOOST
		end
		return 1
	end,
	StatusText = function(state, controller)
		if state.ready then
			return "FEVER READY [E]"
		end
		if isActive(state, controller) then
			return "FEVER x2"
		end
		return nil
	end,
}
