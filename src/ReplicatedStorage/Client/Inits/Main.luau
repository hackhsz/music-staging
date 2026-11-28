--!strict
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Input = Client:WaitForChild("Input")
local Controllers = Client:WaitForChild("Controllers")
local Net = Client:WaitForChild("Net")

local BoardView = require(Client:WaitForChild("Floor"):WaitForChild("BoardView"))
local AudioController = require(Client:WaitForChild("Audio"):WaitForChild("AudioController"))
local AvatarReactionController = require(Client:WaitForChild("Dance"):WaitForChild("AvatarReactionController"))
local CameraController = require(Client:WaitForChild("World"):WaitForChild("CameraController"))
local GuideBeam = require(Client:WaitForChild("World"):WaitForChild("GuideBeam"))
local HubBoards = require(Client:WaitForChild("World"):WaitForChild("HubBoards"))
local StallBoards = require(Client:WaitForChild("World"):WaitForChild("StallBoards"))
local DanceAnimator = require(Client:WaitForChild("Dance"):WaitForChild("DanceAnimator"))
local SFXController = require(Client:WaitForChild("Audio"):WaitForChild("SFXController"))
local VFXController = require(Client:WaitForChild("Effects"):WaitForChild("VFXController"))
local HUDController = require(Client:WaitForChild("UI"):WaitForChild("HUDController"))
local NoteHighway = require(Client:WaitForChild("UI"):WaitForChild("Screens"):WaitForChild("NoteHighway"))
local UiKit = require(Client:WaitForChild("UI"):WaitForChild("UiKit"))
local DeviceMode = require(Input:WaitForChild("DeviceMode"))
local HotkeyController = require(Input:WaitForChild("HotkeyController"))
local InputController = require(Input:WaitForChild("InputController"))
local StepMover = require(Input:WaitForChild("StepMover"))
local AbilityController = require(Controllers:WaitForChild("AbilityController"))
local AutoplayController = require(Controllers:WaitForChild("AutoplayController"))
local CalibrationController = require(Controllers:WaitForChild("CalibrationController"))
local FloorController = require(Controllers:WaitForChild("FloorController"))
local HighwayController = require(Controllers:WaitForChild("HighwayController"))
local HubController = require(Controllers:WaitForChild("HubController"))
local IslandController = require(Controllers:WaitForChild("IslandController"))
local LeaderboardController = require(Controllers:WaitForChild("LeaderboardController"))
local LobbyController = require(Controllers:WaitForChild("LobbyController"))
local MarketController = require(Controllers:WaitForChild("MarketController"))
local OnboardingController = require(Controllers:WaitForChild("OnboardingController"))
local QuestController = require(Controllers:WaitForChild("QuestController"))
local StagePassController = require(Controllers:WaitForChild("StagePassController"))
local WeekController = require(Controllers:WaitForChild("WeekController"))
local ProgressController = require(Controllers:WaitForChild("ProgressController"))
local RewardsController = require(Controllers:WaitForChild("RewardsController"))
local CommunityController = require(Controllers:WaitForChild("CommunityController"))
local RivalController = require(Controllers:WaitForChild("RivalController"))
local RunController = require(Controllers:WaitForChild("RunController"))
local SettingsController = require(Controllers:WaitForChild("SettingsController"))
local StagesController = require(Controllers:WaitForChild("StagesController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))
local WardrobeController = require(Controllers:WaitForChild("WardrobeController"))
local Remotes = require(Net:WaitForChild("Remotes"))
local Telemetry = require(Net:WaitForChild("Telemetry"))

local Main = {}

function Main.Start()
	-- Wiring only: build the views and controllers, hand each the pieces it needs, and
	-- start them. Game logic lives in Controllers, drawing in UI, devices in Input.
	Telemetry.track("spawn")

	local deviceMode = DeviceMode.detect()
	local remotes = Remotes.resolve()
	Telemetry.bindFunnels(remotes.ReportFunnelStep)

	local boardView = BoardView.new()
	local audio = AudioController.new()
	local vfx = VFXController.new()
	local sfx = SFXController.new()
	UiKit.setSoundPlayer(function(name: string)
		sfx:play(name)
	end)
	local avatar = AvatarReactionController.new()
	local dancer = DanceAnimator.new()
	local hud = HUDController.new()

	local camera = CameraController.new()
	HUDController.hideDefaultRobloxUi()
	hud:watchViewport()
	camera:setPadArea(function()
		return hud:padArea()
	end)
	hud.hints:setControlsHint(deviceMode.controlHint)

	local stepMover = StepMover.new({
		onStepStarted = function(coord)
			boardView:setPlayerCoord(coord.x, coord.y)
			vfx:playStepSpark(coord)
		end,
	})
	dancer:attachStepMover(stepMover)

	-- Built after the input it listens to; a lane press can only happen in a run,
	-- long after this file has finished.
	local highway: HighwayController.HighwayController? = nil
	local clapRun: RunController.RunController? = nil
	-- The first-join timing check takes the clap key while it runs.
	local timingCheck: OnboardingController.OnboardingController? = nil

	local inputController = InputController.new({
		onStep = function(dx, dy)
			if hud:blocksSteps() then
				return
			end

			stepMover:requestStep(dx, dy)
			hud.pad:flashDirection(dx, dy)
		end,
		onBendStep = function(dx, dy)
			if hud:blocksSteps() then
				return
			end

			if not stepMover:bendStep(dx, dy) then
				stepMover:requestStep(dx, dy)
			end

			hud.pad:flashDirection(dx, dy)
		end,
		onTapTile = function(coord)
			if hud:blocksSteps() then
				return
			end

			stepMover:requestTile(coord)
		end,
		onPressLane = function(lane)
			if highway ~= nil then
				highway:press(lane)
			end
		end,
		onReleaseLane = function(lane)
			if highway ~= nil then
				highway:release(lane)
			end
		end,
		onClap = function()
			if timingCheck ~= nil and timingCheck:isTimingCheck() then
				timingCheck:tap()
			elseif clapRun ~= nil then
				clapRun:clap()
			end
		end,
		needsInput = function()
			return stepMover:needsInput()
		end,
		getOrigin = function()
			return stepMover:getOrigin()
		end,
	})

	hud.pad:bind(function(dx, dy)
		inputController:setPadDirection(dx, dy)
	end)
	hud.pad:bindTiles(function(x, y)
		inputController:pressPadTile(x, y)
	end)
	hud.pad:bindClap(function()
		inputController:pressClap()
	end)

	local floors = FloorController.new({
		remotes = remotes,
		boardView = boardView,
		stepMover = stepMover,
		camera = camera,
		portrait = hud.rivalPortrait,
	})
	local rival = RivalController.new({ hud = hud, floors = floors, portrait = hud.rivalPortrait })
	local calibration = CalibrationController.new({
		remotes = remotes,
		hud = hud,
		deviceMode = deviceMode,
	})
	local highwayController = HighwayController.new({
		remotes = remotes,
		screen = NoteHighway.new(hud.run:getLaneKeys()),
		boardView = boardView,
		input = inputController,
		stepMover = stepMover,
		dancer = dancer,
		avatar = avatar,
		sfx = sfx,
		calibration = calibration,
		camera = camera,
	})
	highway = highwayController
	local hub = HubController.new({
		remotes = remotes,
		stepMover = stepMover,
		camera = camera,
		transition = hud.transition,
	})
	local shop = ShopController.new({
		remotes = remotes,
		hud = hud,
		sfx = sfx,
		openPass = function()
			hud.stagePass:setVisible(true)
		end,
	})
	local run = RunController.new({
		remotes = remotes,
		hud = hud,
		boardView = boardView,
		stepMover = stepMover,
		audio = audio,
		vfx = vfx,
		sfx = sfx,
		avatar = avatar,
		calibration = calibration,
		floors = floors,
		highway = highwayController,
		camera = camera,
		dancer = dancer,
		rival = rival,
		hub = hub,
		deviceMode = deviceMode,
	})
	clapRun = run
	local abilities = AbilityController.new({
		remotes = remotes,
		hud = hud,
		run = run,
		sfx = sfx,
		camera = camera,
		boardView = boardView,
	})
	local lobby: LobbyController.LobbyController
	local stages = StagesController.new({
		remotes = remotes,
		hud = hud,
		requestChart = function(chartId)
			lobby:requestChart(chartId)
		end,
		closePicker = function()
			lobby:closeSongSelect()
		end,
	})
	lobby = LobbyController.new({
		remotes = remotes,
		hud = hud,
		run = run,
		shop = shop,
		audio = audio,
		hub = hub,
		stages = stages,
	})
	local quests = QuestController.new({ remotes = remotes, hud = hud })
	local stagePass = StagePassController.new({ remotes = remotes, hud = hud })
	local week = WeekController.new({
		remotes = remotes,
		hud = hud,
		openShop = function()
			shop:open()
		end,
		openPass = function()
			hud.stagePass:setVisible(true)
		end,
		openQuests = function()
			quests:open()
		end,
	})
	local wardrobe = WardrobeController.new({
		remotes = remotes,
		hud = hud,
		openShop = function()
			shop:open()
		end,
	})
	local market = MarketController.new({ hud = hud, remotes = remotes, boards = StallBoards.new() })
	local rewards = RewardsController.new({ remotes = remotes, hud = hud, sfx = sfx })
	local community = CommunityController.new({ remotes = remotes, hud = hud, sfx = sfx })
	local islands: IslandController.IslandController
	islands = IslandController.new({
		remotes = remotes,
		hud = hud,
		hub = hub,
		openers = {
			shop = function()
				shop:open()
			end,
			quests = function()
				quests:open()
			end,
			rewards = function()
				rewards:open()
			end,
			islands = function()
				islands:open()
			end,
			wardrobe = function()
				wardrobe:open()
			end,
			market = function(prompt)
				market:open(prompt:GetAttribute("Stall") :: any)
			end,
		},
	})
	local onboarding = OnboardingController.new({
		remotes = remotes,
		hud = hud,
		run = run,
		lobby = lobby,
		hub = hub,
		guide = GuideBeam.new(),
		calibration = calibration,
		sfx = sfx,
		vfx = vfx,
	})
	timingCheck = onboarding
	local hotkeys = HotkeyController.new({
		remotes = remotes,
		hud = hud,
		run = run,
		lobby = lobby,
		shop = shop,
		calibration = calibration,
		abilities = abilities,
		stages = stages,
	})

	hub:start()
	floors:start()
	calibration:start()
	SettingsController.new({ remotes = remotes, hud = hud, vfx = vfx, camera = camera }):start()
	ProgressController.new({ remotes = remotes, hud = hud, sfx = sfx }):start()
	shop:start()
	LeaderboardController.new({ remotes = remotes, hud = hud, boards = HubBoards.new() }):start()
	run:start()
	abilities:start()
	AutoplayController.new({ run = run, stepMover = stepMover, abilities = abilities }):start()
	lobby:start()
	stages:start()
	quests:start()
	stagePass:start()
	week:start()
	wardrobe:start()
	market:start()
	rewards:start()
	community:start()
	islands:start()
	hotkeys:start()
	onboarding:start()

	-- The loading screen (ReplicatedFirst) holds until this is set.
	Players.LocalPlayer:SetAttribute("ClientReady", true)
	print("[DanceDanceStep] Client rhythm loop ready")
end

return Main
