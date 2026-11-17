local CHARGES = 3
local POPUP_TEXT = "SHIELD"

return {
	DisplayName = "Groove Shield",
	Description = "Absorbs 3 Misses. Combo and life kept.",
	Kind = "Consumable",
	Order = 3,
	ScoreMultiplier = 0.9,
	Conflicts = { "GlassHeels" },
	Init = function(state)
		state.charges = CHARGES
	end,
	AbsorbMiss = function(state, controller)
		if state.charges <= 0 then
			return nil
		end
		state.charges -= 1
		controller:recordAssist(state.id, 0)
		return POPUP_TEXT
	end,
	StatusText = function(state)
		if state.charges <= 0 then
			return nil
		end
		return "SHIELD x" .. state.charges
	end,
}
