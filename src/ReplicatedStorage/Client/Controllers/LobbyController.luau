--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MultiplayerModes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MultiplayerModes"))
local SongMapCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SongMapCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local UiKit = require(script.Parent.Parent.UI.UiKit)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)
local HubController = require(script.Parent.HubController)
local RunController = require(script.Parent.RunController)
local ShopController = require(script.Parent.ShopController)
local StagesController = require(script.Parent.StagesController)

local CHOOSE_HINT = "CHOOSE A TRACK TO START"
local GUEST_HINT = "WAITING FOR PLAYER 1 TO PICK THE SONG"
local REOPEN_HINT = "SONGS"
local ISLAND_HINT = "WALK UP TO A DANCE PAD TO PICK A SONG"
-- Browsing quickly past songs does not load each one; the preview starts once
-- the highlight rests this long.
local PREVIEW_DELAY_SECONDS = 0.35

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	run: RunController.RunController,
	shop: ShopController.ShopController,
	audio: any,
	hub: HubController.HubController,
	stages: StagesController.StagesController,
}

type Fields = {
	deps: Deps,
	songs: { any },
	initialized: boolean,
	currentSongIndex: number?,
	currentModeId: string,
	playerCount: number,
	slot: number,
	previewToken: number,
	previewGrid: { bpm: number, offset: number }?,
}

-- Between runs: the song list, picking a track, the play mode, and the lobby
-- rewards. It hands a chosen song to the server and waits for StartSong.
local LobbyController = {}
LobbyController.__index = LobbyController

export type LobbyController = typeof(setmetatable({} :: Fields, LobbyController))

function LobbyController.new(deps: Deps): LobbyController
	local fields: Fields = {
		deps = deps,
		songs = {},
		initialized = false,
		currentSongIndex = nil,
		currentModeId = MultiplayerModes.DefaultModeId,
		playerCount = 1,
		slot = 1,
		previewToken = 0,
		previewGrid = nil,
	}

	return setmetatable(fields, LobbyController)
end

function LobbyController.start(self: LobbyController)
	local deps = self.deps

	deps.hud.songSelect:bindChosen(function(index)
		self:requestSongByIndex(index)
	end)
	deps.hud.songSelect:bindBack(function()
		self:toggleSongSelect()
	end)
	deps.hud.songSelect:bindFocused(function(index)
		self:_previewSong(index)
	end)
	deps.hud.songSelect:bindAudio(function()
		return self:_previewBeat()
	end)
	deps.hud.results:bindNext(function()
		self:requestNextSong()
	end)
	deps.hud.results:bindBack(function()
		self:_leaveResults()
	end)

	if deps.hub:isHub() then
		deps.hud.results:setBackLabel("LEAVE")
		deps.hud.pause:bindLeave(function()
			self:leaveStage()
		end)
	end
	deps.hud.multiplayer:bindModeToggle(function()
		self:requestNextMode()
	end)
	deps.hud.menu:bindSongs(function()
		self:toggleSongSelect()
	end)

	deps.remotes.SongCatalog.OnClientEvent:Connect(function(payload)
		self:_onCatalog(payload)
	end)
	deps.remotes.OpenSongPicker.OnClientEvent:Connect(function()
		if not deps.run:isRunning() then
			deps.hud:hideResults()
			self:_showSongSelect()
		end
	end)
	deps.remotes.MultiplayerStatus.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.modeId) == "string" then
			self.currentModeId = payload.modeId
			self.playerCount = tonumber(payload.playerCount) or 1
			self.slot = tonumber(payload.playerSlot) or 1
		end
	end)
end

-- In a match only player 1 picks the song; it then starts for both players.
function LobbyController.isGuest(self: LobbyController): boolean
	return self.playerCount > 1 and self.slot ~= 1
end

function LobbyController.requestSongByIndex(self: LobbyController, index: number)
	local deps = self.deps
	local song = self.songs[index]

	if self:isGuest() then
		deps.hud.hints:setHint(GUEST_HINT)
		return
	end

	if song == nil or song.id == nil then
		deps.hud.hints:setHint("TRACK NOT READY")
		return
	end

	-- Client-side gate; the server rejects locked RequestSong payloads too.
	if song.locked == true then
		local requirement = string.upper(song.requirementText or "LOCKED")
		local openShop = if song.unlockType == "soft_currency" then "  OPEN SHOP" .. UiKit.keyHint(" (B)") else ""

		deps.hud.hints:setHint(("LOCKED  %s%s"):format(requirement, openShop))
		Telemetry.track("locked_song_selected", song.id)
		return
	end

	self.currentSongIndex = index
	-- On the stage before the server moves the player there, so the island camera
	-- never follows the trip down.
	deps.hub:enterStage()
	deps.hud.hints:setHint(("LOADING %s..."):format(string.upper(song.title or song.id)))
	self:_stopPreview()
	deps.hud:launchSongSelect()
	deps.hud:hideResults()
	Telemetry.track("song_selected", song.id)
	deps.remotes.RequestSong:FireServer({ songId = song.id })
end

-- Starts a chart straight from the lobby, as picking it in the song picker would.
function LobbyController.requestChart(self: LobbyController, chartId: string)
	if self.deps.run:isRunning() then
		return
	end

	for index, song in self.songs do
		if song.id == chartId then
			self.deps.run:resetToLobby()
			self:requestSongByIndex(index)
			return
		end
	end

	self.deps.hud.hints:setHint("TRACK NOT READY")
end

function LobbyController.requestNextSong(self: LobbyController)
	local deps = self.deps

	if #self.songs == 0 then
		deps.hud.hints:setHint("SONG LIST STILL LOADING")
		return
	end

	if deps.stages:playNext() then
		return
	end

	-- Cycle forward to the next unlocked track.
	for offset = 1, #self.songs do
		local nextIndex = ((self.currentSongIndex or 0) + offset - 1) % #self.songs + 1
		local song = self.songs[nextIndex]

		if song ~= nil and song.locked ~= true then
			self:requestSongByIndex(nextIndex)
			return
		end
	end

	deps.hud.hints:setHint("NO UNLOCKED TRACKS YET")
end

function LobbyController.requestNextMode(self: LobbyController)
	self.currentModeId = MultiplayerModes.nextSelectable(self.currentModeId)

	local mode = MultiplayerModes.getMode(self.currentModeId)

	self.deps.hud.hints:setHint(("MODE: %s"):format(mode.label))
	self.deps.remotes.RequestMode:FireServer({ modeId = self.currentModeId })
end

-- The picker closes to the lobby and opens again from it; never during a run.
function LobbyController.toggleSongSelect(self: LobbyController)
	local deps = self.deps

	if deps.run:isRunning() then
		return
	end

	if deps.hud.songSelect:isVisible() then
		self:closeSongSelect()
	else
		self:_leaveResults()
	end
end

function LobbyController.closeSongSelect(self: LobbyController)
	local deps = self.deps

	if not deps.hud.songSelect:isVisible() then
		return
	end

	self:_stopPreview()
	deps.hud:hideSongSelect()
	deps.hud.hints:setHint(if self:_onIsland() then ISLAND_HINT else REOPEN_HINT .. UiKit.keyHint(" (L)"))
end

-- In a hub place, off the stage from anywhere on it: mid-song from the pause menu,
-- or after the results. The server drops an unfinished solo run.
function LobbyController.leaveStage(self: LobbyController)
	local deps = self.deps

	self:_stopPreview()
	deps.run:resetToLobby()
	deps.hud:hideResults()
	deps.hud:hideSongSelect()
	deps.hub:leaveStage()
	deps.hud.hints:setHint(ISLAND_HINT)
end

function LobbyController._onIsland(self: LobbyController): boolean
	return self.deps.hub:isHub() and not self.deps.hub:isOnStage()
end

-- Off the results: back to the picker, or in a hub place off the stage and back to
-- the station the player came from.
function LobbyController._leaveResults(self: LobbyController)
	local deps = self.deps

	deps.run:resetToLobby()
	deps.hud:hideResults()

	if deps.hub:isHub() and deps.hub:isOnStage() then
		deps.hub:leaveStage()
		deps.hud.hints:setHint(ISLAND_HINT)
	else
		self:_showSongSelect()
	end
end

function LobbyController.requestRematch(self: LobbyController)
	-- Only acts server-side at a multiplayer results screen.
	self.deps.remotes.RequestRematch:FireServer()
end

function LobbyController.requestParty(self: LobbyController)
	-- Hosts a private party; the code shows in the multiplayer panel.
	self.deps.remotes.RequestParty:FireServer({})
end

function LobbyController._previewSong(self: LobbyController, index: number)
	local song = self.songs[index]

	self.previewToken += 1

	local token = self.previewToken

	task.delay(PREVIEW_DELAY_SECONDS, function()
		local deps = self.deps

		if self.previewToken ~= token or song == nil or deps.run:isRunning() or not deps.hud.songSelect:isVisible() then
			return
		end

		local map = SongMapCatalog.getMap(song.id)
		local steps = if map ~= nil then map.steps else nil
		local first = if type(steps) == "table" and steps[1] ~= nil then tonumber(steps[1].beat) else nil

		-- Charts count beat 1 at the audio's start; the first step's fraction is
		-- where the song's own beat grid sits.
		self.previewGrid = {
			bpm = tonumber(song.bpm) or 120,
			offset = if first ~= nil then (first - 1) % 1 else 0,
		}
		deps.audio:preview(song.id)
	end)
end

-- The preview's position in beats on the song's grid, and its loudness.
function LobbyController._previewBeat(self: LobbyController): (number?, number)
	local grid = self.previewGrid
	local time, loudness = self.deps.audio:getPreviewState()

	if grid == nil or time == nil then
		return nil, 0
	end

	return time * grid.bpm / 60 - grid.offset, loudness
end

function LobbyController._stopPreview(self: LobbyController)
	self.previewToken += 1
	self.deps.audio:stopPreview()
end

-- Where the picker opens: on the stage's next chart in Stage Challenge, otherwise on
-- the last chart played, and on the stage's when nothing has been played yet.
function LobbyController._openingIndex(self: LobbyController): number?
	local chartId, staged = self.deps.stages:nextChart()
	local stageIndex: number? = nil

	for index, song in self.songs do
		if song.id == chartId then
			stageIndex = index
			break
		end
	end

	return if staged and stageIndex ~= nil then stageIndex else self.currentSongIndex or stageIndex
end

function LobbyController._showSongSelect(self: LobbyController)
	local hud = self.deps.hud
	local opening = not hud.songSelect:isVisible()

	hud:showSongSelect(self.songs)

	if opening then
		hud.songSelect:setSelected(self:_openingIndex())
	end
	hud.hints:showOnboarding(nil)
	hud.hints:setHint(if self:isGuest() then GUEST_HINT else CHOOSE_HINT)
end

function LobbyController._onCatalog(self: LobbyController, payload: any)
	if type(payload) ~= "table" or type(payload.songs) ~= "table" then
		return
	end

	local deps = self.deps

	self.songs = payload.songs

	if not self.initialized then
		-- First catalog after join: reset everything and open song select.
		self.initialized = true
		self.currentSongIndex = nil
		deps.run:resetToLobby()
		deps.hud:hideResults()

		-- A hub place opens the picker from a station, not on join.
		if deps.hub:isHub() then
			deps.hud.hints:setHint(ISLAND_HINT)
		else
			self:_showSongSelect()
		end
	elseif deps.hud.songSelect:isVisible() then
		-- Later pushes only refresh lock states; never stomp gameplay or the
		-- results screen.
		self:_showSongSelect()
	end

	deps.shop:setSongCatalog(self.songs)
	Telemetry.track("song_catalog_received", #self.songs)
end

return LobbyController
