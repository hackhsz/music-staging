local PULL_RANGE = 1
local POPUP_TEXT = "PULL"
local PULLABLE_KINDS = { STEP = true, SHAPE = true }

local function nearestTile(controller, tiles)
	local best, bestDistance = nil, math.huge
	for _, tile in tiles do
		local distance = math.abs(controller.cell.X - tile[1]) + math.abs(controller.cell.Y - tile[2])
		if distance < bestDistance then
			best, bestDistance = tile, distance
		end
	end
	return best, bestDistance
end

return {
	DisplayName = "Step Magnet",
	Description = "Miss by one tile: pulled on, combo kept. Scores nothing.",
	Kind = "Consumable",
	Order = 2,
	ScoreMultiplier = 0.85,
	AbsorbMiss = function(state, controller, event)
		if not PULLABLE_KINDS[event.kind] then
			return nil
		end
		local tile, distance = nearestTile(controller, event.tiles)
		if not tile or distance > PULL_RANGE then
			return nil
		end
		controller:pullTo(tile[1], tile[2])
		controller:recordAssist(state.id, 0)
		return POPUP_TEXT
	end,
}
