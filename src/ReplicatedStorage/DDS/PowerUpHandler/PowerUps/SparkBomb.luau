local POPUP_TEXT = "BOMB"

return {
	DisplayName = "Spark Bomb",
	Description = "Gold chart tile. Removes the next danger wave from the song.",
	Kind = "Pickup",
	OnCollect = function(_, controller)
		controller:clearNextEvent("DANGER")
		return POPUP_TEXT
	end,
}
