--!strict
local UiKit = require(script.Parent.Parent.UiKit)

local DEFAULT_STATUS = "SOLO / WAITING FOR PLAYER 2"
-- With the run HUD up, the free gap on the left between the combo burst and
-- the ability cards.
local STAGE_STATUS_ANCHOR = Vector2.new(0, 0)
local STAGE_STATUS_POSITION = UDim2.fromScale(0.015, 0.6)

type Fields = {
	statusLabel: TextLabel?,
	modeButton: GuiButton?,
	modeLabel: TextLabel?,
	lobbyAnchor: Vector2,
	lobbyPosition: UDim2,
	wanted: boolean,
	stageLayout: boolean,
	inMatch: boolean,
}

-- The play-mode button and the match status, authored in StarterGui.Lobby.
local MultiplayerPanel = {}
MultiplayerPanel.__index = MultiplayerPanel

export type MultiplayerPanel = typeof(setmetatable({} :: Fields, MultiplayerPanel))

function MultiplayerPanel.new(gui: ScreenGui?): MultiplayerPanel
	local statusLabel = UiKit.authored(gui, "Status", "TextLabel")
	local modeButton = UiKit.authored(gui, "Actions.ModeButton", "GuiButton")

	local fields: Fields = {
		statusLabel = statusLabel,
		modeButton = modeButton,
		modeLabel = UiKit.authored(modeButton, "ModeLabel", "TextLabel"),
		lobbyAnchor = if statusLabel ~= nil then statusLabel.AnchorPoint else Vector2.zero,
		lobbyPosition = if statusLabel ~= nil then statusLabel.Position else UDim2.new(),
		wanted = true,
		stageLayout = false,
		inMatch = false,
	}

	if modeButton ~= nil then
		UiKit.bindHover(modeButton)
	end

	return setmetatable(fields, MultiplayerPanel)
end

-- The authored screen scales itself.
function MultiplayerPanel.applyLayout(_self: MultiplayerPanel, _isSmall: boolean) end

function MultiplayerPanel.setStageLayout(self: MultiplayerPanel, active: boolean)
	self.stageLayout = active

	local status = self.statusLabel

	if status ~= nil then
		status.AnchorPoint = if active then STAGE_STATUS_ANCHOR else self.lobbyAnchor
		status.Position = if active then STAGE_STATUS_POSITION else self.lobbyPosition
	end

	self:_refresh()
end

-- The status only earns space in a real match; solo it would just say there is
-- nobody else.
function MultiplayerPanel._refresh(self: MultiplayerPanel)
	if self.statusLabel ~= nil then
		self.statusLabel.Visible = self.wanted and self.inMatch
	end
end

function MultiplayerPanel.setModeVisible(self: MultiplayerPanel, visible: boolean)
	if self.modeButton ~= nil then
		self.modeButton.Visible = visible
	end
end

function MultiplayerPanel.setVisible(self: MultiplayerPanel, visible: boolean)
	self.wanted = visible
	self:_refresh()
end

function MultiplayerPanel.bindModeToggle(self: MultiplayerPanel, callback: () -> ())
	if self.modeButton ~= nil then
		self.modeButton.Activated:Connect(callback)
	end
end

function MultiplayerPanel.update(self: MultiplayerPanel, status: any)
	local statusLabel = self.statusLabel

	if status == nil then
		self.inMatch = false

		if statusLabel ~= nil then
			statusLabel.Text = DEFAULT_STATUS
		end

		self:_refresh()
		return
	end

	local modeLabel = status.modeLabel or DEFAULT_STATUS
	local leader = status.leaderName or "-"
	local leaderScore = status.leaderScore or 0
	local rival = status.rivalName
	local slot = status.playerSlot or 1
	local teamHype = status.teamHype or 0
	local syncBonus = status.syncBonus or 0
	local text

	if self.modeLabel ~= nil then
		self.modeLabel.Text = string.upper((modeLabel:gsub(" / WAITING", "")))
	end

	if rival ~= nil and rival ~= "" then
		text = ("%s  P%d\nRIVAL %s %d/%d\nTEAM HYPE %d  SYNC +%d\nLEADER %s %d"):format(
			modeLabel,
			slot,
			rival,
			status.rivalScore or 0,
			status.rivalCombo or 0,
			teamHype,
			syncBonus,
			leader,
			leaderScore
		)
	else
		text = ("%s  P%d\nTEAM HYPE %d\nLEADER %s %d"):format(modeLabel, slot, teamHype, leader, leaderScore)
	end

	if status.result ~= nil then
		text ..= ("\n%s"):format(status.result)

		if status.rematchRequestedByYou then
			text ..= if status.rematchRequestedByRival then "\nREMATCH STARTING..." else "\nWAITING FOR RIVAL REMATCH"
		else
			text ..= if status.rematchRequestedByRival
				then "\nRIVAL WANTS A REMATCH" .. UiKit.keyHint(" - Y")
				else UiKit.keyHint("\nY REMATCH")
		end
	end

	if status.partyCode ~= nil and status.partyCode ~= "" then
		text ..= ("\nPARTY CODE %s (friend joins with it)"):format(status.partyCode)
	end

	self.inMatch = (tonumber(status.playerCount) or 1) > 1 or (rival ~= nil and rival ~= "")

	if statusLabel ~= nil then
		statusLabel.Text = text
	end

	self:_refresh()
end

return MultiplayerPanel
