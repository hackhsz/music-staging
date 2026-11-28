local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MultiplayerModes = require(Shared:WaitForChild("MultiplayerModes"))

local MultiplayerService = {}
MultiplayerService.__index = MultiplayerService

function MultiplayerService.new(statusRemote: RemoteEvent)
	return setmetatable({
		statusRemote = statusRemote,
		waitingByMode = {},
		preferredModeByPlayer = {},
		matches = {},
		matchByPlayer = {},
		scores = {},
		summaries = {},
		parties = {},
		hostPartyCode = {},
		onRematch = nil,
		onMatchChanged = nil,
	}, MultiplayerService)
end

local PARTY_CODE_CHARS = "ACDEFGHJKLMNPQRSTUVWXYZ23456789"

function MultiplayerService:generatePartyCode(): string
	for _ = 1, 40 do
		local code = ""
		for _ = 1, 4 do
			local i = math.random(1, #PARTY_CODE_CHARS)
			code ..= string.sub(PARTY_CODE_CHARS, i, i)
		end
		if self.parties[code] == nil then
			return code
		end
	end
	return tostring(os.clock()):sub(-4)
end

-- Pick a 2-player mode for party play (fall back to the first selectable duo mode).
function MultiplayerService:twoPlayerModeFor(player: Player): string
	local preferred = self.preferredModeByPlayer[player] or MultiplayerModes.DefaultModeId
	local mode = MultiplayerModes.getMode(preferred)

	if mode ~= nil and (mode.playerCount or 1) > 1 then
		return preferred
	end

	for _, modeId in MultiplayerModes.SelectableModeIds do
		local candidate = MultiplayerModes.getMode(modeId)
		if candidate ~= nil and (candidate.playerCount or 1) > 1 then
			return modeId
		end
	end

	return preferred
end

function MultiplayerService:clearHostedParty(player: Player)
	local code = self.hostPartyCode[player]
	if code ~= nil then
		self.parties[code] = nil
		self.hostPartyCode[player] = nil
	end
end

-- Private invite: no code -> create a party + return its code; with a code ->
-- join that party's host directly, bypassing the open queue.
function MultiplayerService:requestParty(player: Player, code: string?): (boolean, string)
	if type(code) == "string" and code ~= "" then
		local party = self.parties[string.upper(code)]

		if party == nil or party.host == player or party.host.Parent ~= Players then
			return false, "party_not_found"
		end

		self:clearHostedParty(party.host)
		self:leaveQueue(player)
		self:leaveMatch(player, false)
		self:leaveQueue(party.host)
		self:leaveMatch(party.host, false)
		self:createMatch(party.host, player, party.modeId)
		return true, "joined"
	end

	self:clearHostedParty(player)
	self:leaveQueue(player)
	self:leaveMatch(player, false)

	local newCode = self:generatePartyCode()
	self.parties[newCode] = { code = newCode, host = player, modeId = self:twoPlayerModeFor(player) }
	self.hostPartyCode[player] = newCode
	self:broadcastToPlayer(player)
	return true, newCode
end

-- Rematch: valid only at the results screen; a fresh match starts once every
-- player in the match has asked for it.
function MultiplayerService:requestRematch(player: Player): boolean
	local match = self.matchByPlayer[player]

	if match == nil or match.state ~= MultiplayerModes.FlowStates.Results then
		return false
	end

	match.rematchRequests = match.rematchRequests or {}
	match.rematchRequests[player] = true

	local everyone = true
	for _, matchPlayer in match.players do
		if not (match.rematchRequests[matchPlayer] and matchPlayer.Parent == Players) then
			everyone = false
		end
	end

	if not everyone then
		self:broadcastMatch(match)
		return true
	end

	local a, b = match.players[1], match.players[2]
	local modeId = match.modeId

	for _, matchPlayer in match.players do
		self.matchByPlayer[matchPlayer] = nil
		self.summaries[matchPlayer] = nil
		self.scores[matchPlayer] = { score = 0, combo = 0, hype = 0 }
	end
	self.matches[match.id] = nil

	if a ~= nil and b ~= nil and a.Parent == Players and b.Parent == Players then
		self:createMatch(a, b, modeId)

		if self.onRematch ~= nil then
			self.onRematch({ a, b })
		end
	end

	return true
end

function MultiplayerService:addPlayer(player: Player)
	self.scores[player] = {
		score = 0,
		combo = 0,
		hype = 0,
	}
	self.preferredModeByPlayer[player] = MultiplayerModes.DefaultModeId

	self:broadcastToPlayer(player)
end

function MultiplayerService:setPreferredMode(player: Player, modeId: string)
	if not MultiplayerModes.isSelectable(modeId) then
		modeId = MultiplayerModes.DefaultModeId
	end

	self:leaveQueue(player)
	self:leaveMatch(player, false)
	self.preferredModeByPlayer[player] = modeId

	local mode = MultiplayerModes.getMode(modeId)

	if mode.playerCount == 1 then
		self:broadcastToPlayer(player)
		return
	end

	self:enqueueForMode(player, modeId)
end

function MultiplayerService:leaveQueue(player: Player)
	for modeId, waitingPlayer in self.waitingByMode do
		if waitingPlayer == player then
			self.waitingByMode[modeId] = nil
		end
	end
end

function MultiplayerService:enqueueForMode(player: Player, modeId: string)
	local waitingPlayer = self.waitingByMode[modeId]

	if waitingPlayer ~= nil and waitingPlayer ~= player and waitingPlayer.Parent == Players then
		self.waitingByMode[modeId] = nil
		self:createMatch(waitingPlayer, player, modeId)
	else
		self.waitingByMode[modeId] = player
		self:broadcastToPlayer(player)
	end
end

function MultiplayerService:createMatch(firstPlayer: Player, secondPlayer: Player, modeId: string)
	local mode = MultiplayerModes.getMode(modeId)
	local match = {
		id = HttpService:GenerateGUID(false),
		modeId = mode.id,
		state = MultiplayerModes.FlowStates.Playing,
		players = { firstPlayer, secondPlayer },
		createdAt = os.clock(),
		completedAt = nil,
		syncBonus = 0,
		teamHype = 0,
	}

	self.matches[match.id] = match
	self.matchByPlayer[firstPlayer] = match
	self.matchByPlayer[secondPlayer] = match
	self.summaries[firstPlayer] = nil
	self.summaries[secondPlayer] = nil

	self:broadcastMatch(match)
	self:_matchChanged(match.players)
end

function MultiplayerService:_matchChanged(players: { Player })
	if self.onMatchChanged == nil then
		return
	end

	for _, player in players do
		if player.Parent == Players then
			self.onMatchChanged(player)
		end
	end
end

function MultiplayerService:clear(player: Player)
	self.scores[player] = nil
	self.summaries[player] = nil
	self.preferredModeByPlayer[player] = nil
	self:clearHostedParty(player)
	self:leaveQueue(player)
	self:leaveMatch(player, true)
end

function MultiplayerService:leaveMatch(player: Player, requeueRival: boolean)
	local match = self.matchByPlayer[player]
	local rival = self:getRivalFor(player)

	self.matchByPlayer[player] = nil

	if match == nil then
		return
	end

	match.state = MultiplayerModes.FlowStates.Abandoned
	match.completedAt = os.clock()

	for _, matchPlayer in match.players do
		self.matchByPlayer[matchPlayer] = nil
	end

	self.matches[match.id] = nil
	self:_matchChanged(match.players)

	if requeueRival and rival ~= nil and rival.Parent == Players then
		self.summaries[rival] = nil
		self:broadcastToPlayer(rival)
	end
end

function MultiplayerService:updateScore(player: Player, score: number, combo: number?, hype: number?)
	self.scores[player] = {
		score = score or 0,
		combo = combo or 0,
		hype = hype or 0,
	}

	local match = self.matchByPlayer[player]

	if match ~= nil then
		self:updateCoStage(match)
	end

	self:broadcastForPlayer(player)
end

function MultiplayerService:updateCoStage(match: any)
	local totalHype = 0
	local comboSyncReady = true
	local activePlayers = 0

	for _, matchPlayer in match.players do
		local state = self.scores[matchPlayer]

		if state ~= nil then
			activePlayers += 1
			totalHype += state.hype or 0

			if (state.combo or 0) < 8 then
				comboSyncReady = false
			end
		end
	end

	match.teamHype = activePlayers > 0 and math.floor(totalHype / activePlayers + 0.5) or 0

	if comboSyncReady and activePlayers == #match.players then
		match.syncBonus = math.min((match.syncBonus or 0) + 25, 500)
	end
end

function MultiplayerService:complete(player: Player, summary: any)
	self.summaries[player] = summary
	self:updateScore(player, summary.score or 0, summary.maxCombo or 0, 0)

	local match = self.matchByPlayer[player]

	if match ~= nil and self:isMatchComplete(match) then
		match.state = MultiplayerModes.FlowStates.Results
		match.completedAt = os.clock()
		self:broadcastMatch(match)
	end
end

function MultiplayerService:isMatchComplete(match: any)
	for _, player in match.players do
		if self.summaries[player] == nil then
			return false
		end
	end

	return true
end

function MultiplayerService:getRivalFor(player: Player)
	local match = self.matchByPlayer[player]

	if match == nil then
		return nil
	end

	for _, matchPlayer in match.players do
		if matchPlayer ~= player then
			return matchPlayer
		end
	end

	return nil
end

function MultiplayerService:getLeaderFor(match: any)
	local leader = nil
	local leaderScore = -1

	for _, player in match.players do
		local state = self.scores[player]
		local score = state and state.score or 0

		if score > leaderScore then
			leader = player
			leaderScore = score
		end
	end

	return leader, math.max(leaderScore, 0)
end

function MultiplayerService:getSlotFor(player: Player, match: any)
	for index, matchPlayer in match.players do
		if matchPlayer == player then
			return index
		end
	end

	return 1
end

-- Everyone in the player's match, host first; a player outside a match is alone.
function MultiplayerService:getMatchPlayers(player: Player): { Player }
	local match = self.matchByPlayer[player]

	return if match ~= nil then match.players else { player }
end

-- Which floor a player dances on, and how many floors the match needs. A player
-- outside a match has the centre floor to themselves.
function MultiplayerService:getFloorFor(player: Player): (number, number)
	local match = self.matchByPlayer[player]

	if match == nil then
		return 1, 1
	end

	return self:getSlotFor(player, match), #match.players
end

function MultiplayerService:buildStatusFor(player: Player)
	local match = self.matchByPlayer[player]
	local ownState = self.scores[player]

	if match == nil then
		local preferredModeId = self.preferredModeByPlayer[player] or MultiplayerModes.DefaultModeId
		local preferredMode = MultiplayerModes.getMode(preferredModeId)
		local waiting = preferredMode.playerCount > 1

		return {
			modeId = preferredMode.id,
			modeLabel = waiting and (preferredMode.label .. " / WAITING") or preferredMode.label,
			matchId = nil,
			matchState = waiting and MultiplayerModes.FlowStates.Waiting or MultiplayerModes.FlowStates.Playing,
			playerCount = 1,
			ownScore = ownState and ownState.score or 0,
			ownCombo = ownState and ownState.combo or 0,
			playerSlot = 1,
			teamHype = ownState and ownState.hype or 0,
			syncBonus = 0,
			rivalName = nil,
			rivalScore = 0,
			rivalCombo = 0,
			leaderName = player.DisplayName,
			leaderScore = ownState and ownState.score or 0,
			result = nil,
			partyCode = self.hostPartyCode[player],
		}
	end

	local rival = self:getRivalFor(player)
	local rivalState = rival and self.scores[rival] or nil
	local leader, leaderScore = self:getLeaderFor(match)
	local mode = MultiplayerModes.getMode(match.modeId)
	local result = nil
	local rematch = match.rematchRequests or {}
	local rematchByYou = rematch[player] == true
	local rematchByRival = rival ~= nil and rematch[rival] == true

	if match.state == MultiplayerModes.FlowStates.Results then
		local ownScore = ownState and ownState.score or 0
		local rivalScore = rivalState and rivalState.score or 0

		if mode.scoreMode == "team_total" then
			result = "TEAM CLEAR"
		else
			if ownScore == rivalScore then
				result = "DRAW"
			elseif ownScore > rivalScore then
				result = "YOU WIN"
			else
				result = "RIVAL WINS"
			end
		end
	end

	return {
		modeId = match.modeId,
		modeLabel = mode.label,
		matchId = match.id,
		matchState = match.state,
		playerCount = #match.players,
		playerSlot = self:getSlotFor(player, match),
		ownScore = ownState and ownState.score or 0,
		ownCombo = ownState and ownState.combo or 0,
		teamHype = match.teamHype or 0,
		syncBonus = match.syncBonus or 0,
		rivalName = rival and rival.DisplayName or nil,
		rivalUserId = rival and rival.UserId or nil,
		rivalScore = rivalState and rivalState.score or 0,
		rivalCombo = rivalState and rivalState.combo or 0,
		leaderName = leader and leader.DisplayName or nil,
		leaderScore = leaderScore,
		result = result,
		rematchRequestedByYou = rematchByYou,
		rematchRequestedByRival = rematchByRival,
	}
end

function MultiplayerService:broadcastToPlayer(player: Player)
	if player.Parent == Players then
		self.statusRemote:FireClient(player, self:buildStatusFor(player))
	end
end

function MultiplayerService:broadcastForPlayer(player: Player)
	local match = self.matchByPlayer[player]

	if match ~= nil then
		self:broadcastMatch(match)
	else
		self:broadcastToPlayer(player)
	end
end

function MultiplayerService:broadcastMatch(match: any)
	for _, player in match.players do
		self:broadcastToPlayer(player)
	end
end

return MultiplayerService
