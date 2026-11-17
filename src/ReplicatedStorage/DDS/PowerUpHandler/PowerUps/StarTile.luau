local HYPE_BY_TIER = { PERFECT = 25, GREAT = 15 }
local POPUP_TEXT = "STAR"

return {
	DisplayName = "Star Tile",
	Description = "Gold chart tile. Land on it on the beat for hype.",
	Kind = "Pickup",
	OnCollect = function(_, controller, _, tier)
		local hype = HYPE_BY_TIER[tier]
		if not hype then
			return nil
		end
		controller:addHype(hype)
		return POPUP_TEXT
	end,
}
