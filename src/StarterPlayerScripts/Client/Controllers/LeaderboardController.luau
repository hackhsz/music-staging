--!strict
local Remotes = require(script.Parent.Parent.Net.Remotes)

type Deps = {
	remotes: any,
	hud: any,
	boards: any,
}

type Fields = {
	deps: Deps,
}

-- Hands each leaderboard push to the hub's boards and to the lobby's stats card.
local LeaderboardController = {}
LeaderboardController.__index = LeaderboardController

export type LeaderboardController = typeof(setmetatable({} :: Fields, LeaderboardController))

function LeaderboardController.new(deps: Deps): LeaderboardController
	return setmetatable({ deps = deps } :: Fields, LeaderboardController)
end

function LeaderboardController.start(self: LeaderboardController)
	Remotes.listen(self.deps.remotes.LeaderboardData, function(payload: any)
		if type(payload) ~= "table" or type(payload.boards) ~= "table" then
			return
		end

		self.deps.boards:update(payload)
		self.deps.hud.menu:updateRanks(payload.boards)
	end)
end

return LeaderboardController
