local MultiplayerModes = {}

MultiplayerModes.FlowStates = {
	Waiting = "waiting",
	Countdown = "countdown",
	Playing = "playing",
	Results = "results",
	Abandoned = "abandoned",
}

MultiplayerModes.DefaultModeId = "solo"
MultiplayerModes.SelectableModeIds = { "solo", "coop_separate", "coop_shared", "competitive" }

MultiplayerModes.Modes = {
	Solo = {
		id = "solo",
		label = "SOLO PLAY",
		playerCount = 1,
		board = "single_5x5",
		scoreMode = "individual",
		selectable = true,
	},
	CoopSeparate = {
		id = "coop_separate",
		label = "2P COOP",
		playerCount = 2,
		board = "two_5x5",
		scoreMode = "team_total",
		selectable = true,
	},
	CoopShared = {
		id = "coop_shared",
		label = "2P SHARED COOP",
		playerCount = 2,
		board = "shared_5x10",
		scoreMode = "team_total",
		status = "requires_playtest",
		playtestOnly = true,
		selectable = true,
	},
	Competitive = {
		id = "competitive",
		label = "2P BATTLE",
		playerCount = 2,
		board = "two_5x5",
		scoreMode = "highest_score_wins",
		selectable = true,
	},
}

function MultiplayerModes.getMode(modeId: string?)
	for _, mode in MultiplayerModes.Modes do
		if mode.id == modeId then
			return mode
		end
	end

	return MultiplayerModes.Modes.Solo
end

function MultiplayerModes.isSelectable(modeId: string?): boolean
	local mode = MultiplayerModes.getMode(modeId)

	return mode.selectable == true
end

function MultiplayerModes.nextSelectable(modeId: string?)
	local currentIndex = table.find(MultiplayerModes.SelectableModeIds, modeId) or 1
	local nextIndex = currentIndex + 1

	if nextIndex > #MultiplayerModes.SelectableModeIds then
		nextIndex = 1
	end

	return MultiplayerModes.SelectableModeIds[nextIndex]
end

return MultiplayerModes
