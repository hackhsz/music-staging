local DANCING_NAV = "Nav_Dancing"
local RESULTS_HOLD_SEC = 4
local RESULTS_WAIT_SEC = 6
local LEAVE_AFTER_MATCH_SEC = 3
local WATCH_CAMERA_OFFSET = Vector3.new(0, 62, 58)
local NOTICE_TITLE = "Dance Dance Step"
local NOTICE_SEC = 6

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local DDS = ReplicatedStorage:WaitForChild("DDS")
local Config = require(DDS:WaitForChild("Config"))
local Controller = require(DDS:WaitForChild("GameController"))
local SongCatalog = require(DDS:WaitForChild("SongCatalog"))
local MenuSignals = require(DDS:WaitForChild("MenuSignals"))
local PromptUI = require(DDS:WaitForChild("PromptUI"))
local PowerUpHandler = require(DDS:WaitForChild("PowerUpHandler"))
local MatchRules = require(DDS:WaitForChild("MatchRules"))
local Maid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utility"):WaitForChild("Maid"))
local ChartMirror = require(script.ChartMirror)
local RemoteDancer = require(script.RemoteDancer)

local HubClient = {}

local player = Players.LocalPlayer
local hubRequest: RemoteEvent
local reportRunResult: RemoteEvent
local stations: Folder
local music
local analyzer
local choosingToken = nil
local inSession = false
local watchMaid = nil
local lastResults = {}
local activeController = nil
local isSetup = false

local function notify(text: string)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = NOTICE_TITLE, Text = text, Duration = NOTICE_SEC })
end

local function chartFor(songId: string?, difficulty: string?)
	local song = SongCatalog.byId(songId)
	if not song then
		return nil, nil
	end
	local charts = require(song.charts)
	return song, charts[difficulty] or charts.normal
end

local function selectedDifficulty(): string
	if DDS:GetAttribute("Difficulty") == nil then
		DDS:SetAttribute("Difficulty", "normal")
	end
	return DDS:GetAttribute("Difficulty")
end

local function dancerName(station: Model, role: string): string
	return station:GetAttribute(if role == "A" then "HostName" else "RivalName") or "?"
end

local function scoreLine(station: Model): string
	if station:FindFirstChild("PadB") then
		return string.format("%s %d  vs  %d %s", dancerName(station, "A"), station:GetAttribute("ScoreA") or 0, station:GetAttribute("ScoreB") or 0, dancerName(station, "B"))
	end
	return string.format("%s  %d", dancerName(station, "A"), station:GetAttribute("ScoreA") or 0)
end

local function suppressPrompts(maid)
	ProximityPromptService.Enabled = false
	maid:GiveTask(function()
		ProximityPromptService.Enabled = true
	end)
end

local function hideBoard(station: Model, maid)
	local board = station:FindFirstChild("Hub") and station.Hub:FindFirstChild("StationBoard")
	if not board then
		return
	end
	board.Enabled = false
	maid:GiveTask(function()
		board.Enabled = true
	end)
end

function HubClient:StopWatching()
	local maid = watchMaid
	watchMaid = nil
	if maid then
		maid:DoCleaning()
	end
end

function HubClient:CancelChoosing()
	if not choosingToken then
		return
	end
	choosingToken = nil
	hubRequest:FireServer({ action = "cancel" })
end

function HubClient:Choose()
	self:StopWatching()
	local token = {}
	choosingToken = token
	MenuSignals.OpenSongSelect:Fire()
	task.spawn(function()
		local song = nil
		repeat
			song = SongCatalog.byId(MenuSignals.SongChosen.Event:Wait())
		until song ~= nil or choosingToken ~= token
		if choosingToken ~= token or not song then
			return
		end
		choosingToken = nil
		hubRequest:FireServer({ action = "song", songId = song.id, difficulty = selectedDifficulty() })
	end)
end

function HubClient:AwaitResults(stationName: string)
	local deadline = os.clock() + RESULTS_WAIT_SEC
	while not lastResults[stationName] and os.clock() < deadline do
		task.wait(0.1)
	end
	local results = lastResults[stationName]
	lastResults[stationName] = nil
	return results
end

function HubClient:RunMatch(event)
	self:StopWatching()
	choosingToken = nil
	lastResults[event.station] = nil

	local station = stations:FindFirstChild(event.station)
	local song, chart = chartFor(event.songId, event.difficulty)
	local myPad = station and station:FindFirstChild("Pad" .. tostring(event.role))
	if not song or not chart or not myPad then
		warn("[HubClient] bad match start for station " .. tostring(event.station))
		return
	end

	local isDuel = event.kind == MatchRules.KIND_DUEL
	local otherRole = if event.role == "A" then "B" else "A"
	local otherPad = station:FindFirstChild("Pad" .. otherRole)
	local songStartAt = MatchRules.songStartAt(event.startAt, Config.PRE_ROLL_MS)
	local maid = Maid.new()
	inSession = true
	suppressPrompts(maid)
	hideBoard(station, maid)
	MenuSignals.SessionState:Fire(true)

	if isDuel then
		local savedRate = DDS:GetAttribute("Rate")
		DDS:SetAttribute("Rate", MatchRules.MATCH_RATE)
		maid:GiveTask(function()
			DDS:SetAttribute("Rate", savedRate)
		end)
	end
	if otherPad then
		maid:GiveTask(ChartMirror.new(otherPad, chart, songStartAt))
		maid:GiveTask(RemoteDancer.new(station, otherRole, otherPad))
	end

	music.AssetId = song.sound.SoundId
	MatchRules.waitUntil(event.startAt)

	local course = event.course
	if course then
		notify(string.format("%s - song %d/%d: %d misses left, need %d%% overall", course.grade, course.step, course.steps, course.missesLeft, course.minAccuracy))
	end
	local loadout = PowerUpHandler:CreateLoadout({ gradeCourse = course ~= nil })
	local controller = Controller.new(myPad, chart, music, analyzer, loadout, { missBudget = course and course.missesLeft })
	activeController = controller
	maid:GiveTask(function()
		if activeController == controller then
			activeController = nil
		end
		controller:destroy()
	end)
	controller:start()
	if course then
		controller.hud.LifeBack.Visible = false
	end
	print(string.format("[DDS] %s started: %s station=%s role=%s targets=%d", song.title, chart.difficulty, event.station, event.role, #chart.events))

	local rivalLabel = controller.hud:FindFirstChild("Rival")
	local finished = false
	task.spawn(function()
		while not finished and not controller.destroyed do
			hubRequest:FireServer({ action = "score", score = controller.score, combo = controller.combo, cell = controller.cell })
			if isDuel and rivalLabel then
				rivalLabel.Text = string.format("%s  %d", dancerName(station, otherRole), station:GetAttribute("Score" .. otherRole) or 0)
			end
			task.wait(MatchRules.SCORE_REPORT_INTERVAL_SEC)
		end
	end)

	controller.resultsShown.Event:Wait()
	finished = true
	reportRunResult:FireServer(controller.result)
	hubRequest:FireServer({ action = "done", score = controller.score, combo = controller.combo, cell = controller.cell })

	if isDuel and rivalLabel then
		local results = self:AwaitResults(event.station)
		if results then
			local verdict = if results.winner == event.role then "YOU WIN!" elseif results.winner == MatchRules.TIE then "TIE!" else dancerName(station, otherRole) .. " wins"
			rivalLabel.Text = string.format("%s  +%d coins", verdict, results.coins or 0)
		end
	end

	task.wait(RESULTS_HOLD_SEC)
	maid:DoCleaning()
	inSession = false
	MenuSignals.SessionState:Fire(false)
end

function HubClient:Watch(station: Model)
	if inSession or watchMaid or choosingToken or station:GetAttribute("State") ~= MatchRules.STATE_PLAYING then
		return
	end
	local song, chart = chartFor(station:GetAttribute("SongId"), station:GetAttribute("Difficulty"))
	local startAt = station:GetAttribute("StartAt")
	if not song or not chart or not startAt then
		return
	end

	local songStartAt = MatchRules.songStartAt(startAt, Config.PRE_ROLL_MS)
	local maid = Maid.new()
	watchMaid = maid
	suppressPrompts(maid)
	hideBoard(station, maid)
	MenuSignals.SessionState:Fire(true)
	maid:GiveTask(function()
		MenuSignals.SessionState:Fire(false)
	end)

	for _, role in { "A", "B" } do
		local pad = station:FindFirstChild("Pad" .. role)
		if pad then
			maid:GiveTask(ChartMirror.new(pad, chart, songStartAt))
			maid:GiveTask(RemoteDancer.new(station, role, pad))
		end
	end

	local camera = workspace.CurrentCamera
	local center = station:GetBoundingBox().Position
	local watchView = CFrame.lookAt(center + WATCH_CAMERA_OFFSET, center)
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = watchView
	end))
	maid:GiveTask(function()
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end)

	local hud = maid:GiveTask(DDS.Templates.HUD:Clone())
	hud.AbilityButton.Visible = false
	hud.LifeBack.Visible = false
	hud.Combo.Text = ""
	hud.Status.Text = "Watching " .. (station:GetAttribute("DisplayName") or station.Name) .. "  -  jump to leave"
	hud.Parent = player:WaitForChild("PlayerGui")
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		hud.Score.Text = scoreLine(station)
	end))

	music.AssetId = song.sound.SoundId
	task.spawn(function()
		MatchRules.waitUntil(songStartAt)
		if watchMaid ~= maid then
			return
		end
		music.TimePosition = math.max(0, workspace:GetServerTimeNow() - songStartAt)
		music:Play()
	end)
	maid:GiveTask(function()
		music:Stop()
	end)

	maid:GiveTask(station:GetAttributeChangedSignal("State"):Connect(function()
		if station:GetAttribute("State") == MatchRules.STATE_PLAYING then
			return
		end
		task.delay(LEAVE_AFTER_MATCH_SEC, function()
			if watchMaid == maid then
				self:StopWatching()
			end
		end)
	end))

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		maid:GiveTask(humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if humanoid.Jump then
				self:StopWatching()
			end
		end))
	end
end

function HubClient:Setup()
	if isSetup then
		return
	end
	isSetup = true

	local remotes = DDS:WaitForChild("Remotes")
	hubRequest = remotes:WaitForChild("HubRequest")
	reportRunResult = remotes:WaitForChild("ReportRunResult")
	stations = workspace:WaitForChild(MatchRules.STATIONS_FOLDER)

	reportRunResult.OnClientEvent:Connect(function(reply)
		if type(reply) ~= "table" then
			return
		end
		if reply.type == "notice" then
			notify(reply.text)
			return
		end
		if reply.type ~= "run" then
			return
		end
		if activeController then
			activeController:showReward(reply)
		end
		for _, label in reply.levelUps or {} do
			notify(label)
		end
		if reply.course then
			notify(reply.course)
		end
	end)

	local rig = DDS.Templates.MusicRig:Clone()
	rig.Parent = player:WaitForChild("PlayerScripts")
	music = rig.Music
	analyzer = rig.Analyzer

	local function attachPrompt(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		local detach = PromptUI.attach(prompt)
		prompt.Destroying:Once(detach)
	end
	for _, prompt in CollectionService:GetTagged(MatchRules.PROMPT_TAG) do
		attachPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal(MatchRules.PROMPT_TAG):Connect(attachPrompt)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Action") ~= MatchRules.WATCH_ACTION then
			return
		end
		local station = stations:FindFirstChild(prompt:GetAttribute("Station") or "")
		if station then
			self:Watch(station)
		end
	end)

	remotes:WaitForChild("HubEvent").OnClientEvent:Connect(function(event)
		if type(event) ~= "table" then
			return
		end
		if event.type == "choose" then
			self:Choose()
		elseif event.type == "start" then
			task.spawn(self.RunMatch, self, event)
		elseif event.type == "results" then
			lastResults[event.station] = event
		elseif event.type == "cancel" and choosingToken then
			choosingToken = nil
			MenuSignals.CloseNav:Fire()
		end
	end)

	MenuSignals.NavSelected.Event:Connect(function(navName: string?)
		if not choosingToken or navName == DANCING_NAV then
			return
		end
		task.defer(function()
			if choosingToken and MenuSignals.activeNav ~= DANCING_NAV then
				self:CancelChoosing()
			end
		end)
	end)
end

return HubClient
