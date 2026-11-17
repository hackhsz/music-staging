--!strict
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local STAGE_MODE = "StageChallenge"

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	requestChart: (chartId: string) -> (),
	closePicker: () -> (),
}

type Fields = {
	deps: Deps,
	snapshot: any,
	revealSeen: number,
}

-- Stage Challenge between runs: the server's stages snapshot onto the screens, and
-- their buttons back out. The server picks nothing here; it only saves the play mode
-- and which stage's reveal and notice were dismissed.
local StagesController = {}
StagesController.__index = StagesController

export type StagesController = typeof(setmetatable({} :: Fields, StagesController))

function StagesController.new(deps: Deps): StagesController
	return setmetatable({ deps = deps, snapshot = nil, revealSeen = 0 } :: Fields, StagesController)
end

function StagesController.start(self: StagesController)
	local deps = self.deps
	local stages = deps.hud.stages
	local panels = deps.hud.stagePanels

	Remotes.listen(deps.remotes.ProfileSync, function(payload: any)
		if type(payload) == "table" then
			self:_onSnapshot(payload.stages)
		end
	end)

	deps.remotes.SongComplete.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.summary) == "table" then
			self:_onSnapshot(payload.summary.stages)
		end
	end)

	local function markSeen(what: string, rank: number)
		if what == "reveal" then
			self.revealSeen = math.max(self.revealSeen, rank)
		end

		deps.remotes.StageSeen:FireServer({ what = what, rank = rank })
	end

	local function play(chartId: string?)
		self:_play(chartId)
	end

	stages:bindPlay(play)
	stages:bindAllSongs(function()
		panels:openSongs(nil)
	end)
	stages:bindRoadmap(function()
		panels:openRoadmap()
	end)
	stages:bindMode(function(modeId)
		deps.remotes.SetPlayMode:FireServer({ modeId = modeId })
	end)
	stages:bindSeen(markSeen)
	stages:bindLobbyShown(function()
		-- A finished run shows the lobby for an instant before its results cover it, and
		-- that run's reveal belongs to the results; deferring lets the results get there.
		task.defer(function()
			self:_showPendingReveal()
		end)
	end)
	stages:bindSetlistOpened(deps.closePicker)
	panels:bindPlay(play)
	panels:bindSetlist(function()
		stages:openSetlist()
	end)
	panels:bindSeen(markSeen)
	panels:bindOpenChanged(function(open)
		deps.hud:refreshStageCover()

		if open then
			deps.closePicker()
		end
	end)
	deps.hud.menu:bindRank(function()
		stages:openSetlist()
	end)
	deps.hud.songSelect:bindSetlist(function()
		self:toggleSetlist()
	end)
end

function StagesController._onSnapshot(self: StagesController, snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end

	self.snapshot = snapshot
	self.deps.hud.stages:update(snapshot)
	self.deps.hud.stagePanels:update(snapshot)
	self.deps.hud.menu:updateStage(snapshot)
	self:_showPendingReveal()
end

-- The chart the stage plays next, and whether Stage Challenge is the mode that plays it.
function StagesController.nextChart(self: StagesController): (string?, boolean)
	local snapshot = self.snapshot

	if type(snapshot) ~= "table" or type(snapshot.nextChart) ~= "string" then
		return nil, false
	end

	return snapshot.nextChart, snapshot.playMode == STAGE_MODE
end

-- In Stage Challenge the next song is the stage's, as the lobby's PLAY would start it.
-- False when that is not the mode, so the caller picks its own.
function StagesController.playNext(self: StagesController): boolean
	local chartId, staged = self:nextChart()

	if chartId == nil or not staged or self.deps.hud.runActive then
		return false
	end

	self:_play(chartId)

	return true
end

function StagesController.toggleSetlist(self: StagesController)
	local hud = self.deps.hud

	if hud.runActive or hud.lessonFocus or hud.windows:isOpen() then
		return
	end

	if hud.stages:isOpen() then
		hud.stages:closeSetlist()
	else
		hud.stagePanels:closeAll()
		hud.stages:openSetlist()
	end
end

-- Closes whichever stage screen is on top; false when none was open.
function StagesController.closeTop(self: StagesController): boolean
	local hud = self.deps.hud

	return hud.stagePanels:closeTop() or hud.stages:closeTop()
end

-- No chart means Free Play: the browser. A challenger's chart with the bar full is an
-- attempt, so it asks first; the server decides what the run counts as either way.
function StagesController._play(self: StagesController, chartId: string?)
	local deps = self.deps
	local panels = deps.hud.stagePanels
	local snapshot = self.snapshot
	local challenger = if type(snapshot) == "table" then snapshot.challenger else nil

	if chartId == nil then
		panels:openSongs(nil)
		return
	end

	local function start()
		deps.hud.stages:closeSetlist()
		panels:closeAll()
		deps.requestChart(chartId)
	end

	if type(challenger) == "table" and challenger.chartId == chartId and challenger.state ~= "PRACTICE" then
		panels:showPrompt(start)
	else
		start()
	end
end

-- A stage-up whose reveal was never dismissed (the player left first) plays in the
-- lobby. After a run the results own it, and the lobby is hidden until they close.
function StagesController._showPendingReveal(self: StagesController)
	local stages = self.deps.hud.stages
	local snapshot = self.snapshot

	if type(snapshot) ~= "table" or snapshot.revealPending ~= true or snapshot.rank <= self.revealSeen then
		return
	end

	if not stages:isLobbyShown() or stages:isShowingStageUp() or self.deps.hud.runActive then
		return
	end

	stages:showStageUp({
		rank = snapshot.rank,
		name = snapshot.name,
		stages = snapshot,
		challenge = snapshot.beaten,
		opens = if type(snapshot.opens) == "table" then snapshot.opens else {},
	}, function() end)
end

return StagesController
