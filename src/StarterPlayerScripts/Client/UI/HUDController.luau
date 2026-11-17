--!strict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local UiKit = require(script.Parent.UiKit)
local AuthoredRunHud = require(script.Parent.AuthoredRunHud)
local AbilityBar = require(script.Parent.Screens.AbilityBar)
local AbilityPicker = require(script.Parent.Screens.AbilityPicker)
local EventBanner = require(script.Parent.Screens.EventBanner)
local HintBar = require(script.Parent.Screens.HintBar)
local IslandsPanel = require(script.Parent.Screens.IslandsPanel)
local MarketPanel = require(script.Parent.Screens.MarketPanel)
local MenuScreen = require(script.Parent.Screens.MenuScreen)
local MultiplayerPanel = require(script.Parent.Screens.MultiplayerPanel)
local PadHud = require(script.Parent.Screens.PadHud)
local PauseOverlay = require(script.Parent.Screens.PauseOverlay)
local QuestsPanel = require(script.Parent.Screens.QuestsPanel)
local ResultsScreen = require(script.Parent.Screens.ResultsScreen)
local ProgressPopups = require(script.Parent.Screens.ProgressPopups)
local RewardsPanel = require(script.Parent.Screens.RewardsPanel)
local CommunityPanel = require(script.Parent.Screens.CommunityPanel)
local RivalPortrait = require(script.Parent.Screens.RivalPortrait)
local RunHud = require(script.Parent.Screens.RunHud)
local StagePanels = require(script.Parent.Screens.StagePanels)
local StagesScreen = require(script.Parent.Screens.StagesScreen)
local SettingsPanel = require(script.Parent.Screens.SettingsPanel)
local ShopPanel = require(script.Parent.Screens.ShopPanel)
local SideMenu = require(script.Parent.Screens.SideMenu)
local SongBar = require(script.Parent.Screens.SongBar)
local SongSelectScreen = require(script.Parent.Screens.SongSelectScreen)
local StepPad = require(script.Parent.Screens.StepPad)
local TransitionScreen = require(script.Parent.Screens.TransitionScreen)
local TutorialOverlay = require(script.Parent.Screens.TutorialOverlay)
local WardrobePanel = require(script.Parent.Screens.WardrobePanel)

-- Which in-run HUD draws: the art authored in the place, or the code-built one.
-- Both answer the same calls, so this is the only line that has to change to
-- fall back if the authored screen is broken.
local USE_AUTHORED_HUD = true
-- The in-run screens a designer edits: pause, settings, the run's hints and
-- the floor-event banner.
local GAME_GUI_NAME = "GameHud"
local SONGS_GUI_NAME = "Songs"
local RESULTS_GUI_NAME = "Derail"
local LOBBY_GUI_NAME = "Lobby"
local MENU_GUI_NAME = "Menu"
local TRANSITION_GUI_NAME = "Transition"
local PROGRESS_GUI_NAME = "Progress"
local STAGES_GUI_NAME = "Stages"

local PHOTO_HINT = "PHOTO MODE: CENTER AVATAR  /  P EXIT  /  R REPLAY"
local STRIP_HEIGHT = 30
local SMALL_STRIP_HEIGHT = 24
local STRIP_GAP = 6
-- The pad shot puts the floor's far edge at about this fraction of the screen
-- height, so a short screen pulls the call-out strip up over the song bar
-- rather than down onto the tiles.
local PAD_FLOOR_TOP = 0.27
local PAD_AREA_GAP = 8

type Fields = {
	gui: ScreenGui,
	-- Either RunHud or AuthoredRunHud; they present the same surface.
	run: any,
	hints: HintBar.HintBar,
	menu: SideMenu.SideMenu,
	multiplayer: MultiplayerPanel.MultiplayerPanel,
	songSelect: SongSelectScreen.SongSelectScreen,
	results: ResultsScreen.ResultsScreen,
	popups: ProgressPopups.ProgressPopups,
	stages: StagesScreen.StagesScreen,
	stagePanels: StagePanels.StagePanels,
	pause: PauseOverlay.PauseOverlay,
	shop: ShopPanel.ShopPanel,
	settings: SettingsPanel.SettingsPanel,
	pad: StepPad.StepPad,
	songBar: SongBar.SongBar,
	rivalPortrait: RivalPortrait.RivalPortrait,
	banner: EventBanner.EventBanner,
	abilityBar: AbilityBar.AbilityBar,
	abilityPicker: AbilityPicker.AbilityPicker,
	quests: QuestsPanel.QuestsPanel,
	islands: IslandsPanel.IslandsPanel,
	market: MarketPanel.MarketPanel,
	rewards: RewardsPanel.RewardsPanel,
	community: CommunityPanel.CommunityPanel,
	wardrobe: WardrobePanel.WardrobePanel,
	-- The lobby's windows (loadout, shop, wardrobe, settings, quests, islands,
	-- market, rewards, community) that the rail, the gift button and the island prompts open.
	windows: MenuScreen.MenuScreen,
	transition: TransitionScreen.TransitionScreen,
	tutorial: TutorialOverlay.TutorialOverlay,
	resultsShown: boolean,
	runActive: boolean,
	padLayout: boolean,
	photoMode: boolean,
	lessonFocus: boolean,
}

-- The HUD is a set of screens that draw state and report taps. It owns no game
-- rules and never touches a remote; the controllers talk to the screens through
-- the fields below, and only the behaviour that spans several screens lives here.
local HUDController = {}
HUDController.__index = HUDController

export type HUDController = typeof(setmetatable({} :: Fields, HUDController))

function HUDController.hideDefaultRobloxUi()
	for _, coreGuiType in { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu } do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, false)
		end)
	end

	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)
end

function HUDController.new(): HUDController
	local gui = UiKit.create("ScreenGui", {
		Name = "DanceDanceStepHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
	}, nil)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local padGui = PadHud.findGui(playerGui)
	local gameGui = UiKit.authoredGui(playerGui, GAME_GUI_NAME)
	local songsGui = UiKit.authoredGui(playerGui, SONGS_GUI_NAME)
	local resultsGui = UiKit.authoredGui(playerGui, RESULTS_GUI_NAME)
	local lobbyGui = UiKit.authoredGui(playerGui, LOBBY_GUI_NAME)
	local menuGui = UiKit.authoredGui(playerGui, MENU_GUI_NAME)
	local windows = MenuScreen.new(menuGui)
	local transitionGui = UiKit.authoredGui(playerGui, TRANSITION_GUI_NAME)
	local progressGui = UiKit.authoredGui(playerGui, PROGRESS_GUI_NAME)
	local stagesGui = UiKit.authoredGui(playerGui, STAGES_GUI_NAME)
	local authored = if USE_AUTHORED_HUD then AuthoredRunHud.new(playerGui, padGui) else nil

	-- Construction order is draw order for siblings at the same ZIndex.
	local fields: Fields = {
		gui = gui,
		run = authored or RunHud.new(gui),
		pause = PauseOverlay.new(gameGui),
		hints = HintBar.new(gui, UiKit.authored(gameGui, "RunHint", "GuiObject"), lobbyGui),
		menu = SideMenu.new(lobbyGui, windows),
		shop = ShopPanel.new(windows),
		multiplayer = MultiplayerPanel.new(lobbyGui),
		songSelect = SongSelectScreen.new(songsGui),
		results = ResultsScreen.new(resultsGui),
		popups = ProgressPopups.new(progressGui),
		stages = StagesScreen.new(stagesGui),
		stagePanels = StagePanels.new(stagesGui),
		settings = SettingsPanel.new(gameGui, windows),
		pad = StepPad.new(gui, padGui),
		songBar = SongBar.new(gui),
		rivalPortrait = RivalPortrait.new(padGui),
		banner = EventBanner.new(gameGui),
		abilityBar = AbilityBar.new(HUDController._abilityFrames(padGui, authored)),
		abilityPicker = AbilityPicker.new(windows),
		quests = QuestsPanel.new(windows),
		islands = IslandsPanel.new(windows),
		market = MarketPanel.new(windows),
		rewards = RewardsPanel.new(windows),
		community = CommunityPanel.new(windows),
		wardrobe = WardrobePanel.new(windows),
		windows = windows,
		transition = TransitionScreen.new(transitionGui),
		tutorial = TutorialOverlay.new(playerGui),
		resultsShown = false,
		runActive = false,
		padLayout = false,
		photoMode = false,
		lessonFocus = false,
	}
	local self = setmetatable(fields, HUDController)

	gui.Parent = playerGui

	for _, authoredGui in { gameGui, lobbyGui, menuGui, transitionGui, progressGui } do
		if authoredGui ~= nil then
			authoredGui.Enabled = true
		end
	end

	self.menu:bindShown(function(shown)
		self.stages:setLobbyShown(shown)

		if not shown then
			self.stagePanels:closeAll()
		end
	end)
	self.pause:bindSettings(function()
		self.settings:toggle()
	end)
	self.pause:bindClosed(function()
		self.settings:setVisible(false)
	end)
	self.menu:bindHome(function()
		self:closePanels()
	end)
	self.windows:bindChanged(function(open: string?)
		self.menu:setMenuOpen(open ~= nil)
	end)

	if authored ~= nil then
		self.songBar:bindThin(authored:padLines())
		self.songBar.onPlayerRival = function(shown: boolean)
			authored:setPadLifeShown(not shown)
		end
	end

	self:applyDeviceLayout()

	return self
end

-- The ability cards authored in each layout that can show during a run.
function HUDController._abilityFrames(padGui: ScreenGui?, authored: any): { [string]: GuiObject }
	local frames: { [string]: GuiObject } = {}

	for _, layout in PadHud.Layouts do
		local layoutFrame = if padGui ~= nil then padGui:FindFirstChild(layout) else nil
		local cards = if layoutFrame ~= nil then layoutFrame:FindFirstChild("Abilities") else nil

		if cards ~= nil and cards:IsA("GuiObject") then
			frames[layout] = cards
		end
	end

	local highway = if authored ~= nil then authored:abilityFrame() else nil

	if highway ~= nil then
		frames.Highway = highway
	end

	return frames
end

function HUDController.applyDeviceLayout(self: HUDController)
	local isSmall = UiKit.isSmallViewport()
	local viewport = UiKit.viewportSize()

	if self.run.setPadLayout ~= nil then
		self.run:setPadLayout(viewport, UiKit.topInset())
	end

	self.run:applyLayout(isSmall, UiKit.topInset())
	self.hints:applyLayout(isSmall, UiKit.isTouch(), UiKit.isPhoneViewport(viewport))
	self.multiplayer:applyLayout(isSmall)
	self.songSelect:applyLayout(isSmall)
	self.results:applyLayout(isSmall)
	self.abilityBar:setView(if self.padLayout and self.run.padLayoutName ~= nil then self.run:padLayoutName() else "Highway")
	self.songBar:setThin(self.padLayout)

	local top, height = self:_calloutStrip(isSmall)
	self.banner:applyLayout(top, height)
end

-- The part of the screen in pixels the pad shot keeps the pad inside: under
-- the top block, so the combo and grade line never cover a target, and between
-- the step keys on the left and the CLAP key and ability cards on the right. On
-- a phone it also keeps clear of the score column, which sits beside the pad.
function HUDController.padArea(self: HUDController): Rect?
	local camera = Workspace.CurrentCamera

	if camera == nil or self.run.padFootprint == nil then
		return nil
	end

	local viewport = camera.ViewportSize
	local screen = self.gui.AbsoluteSize
	local corner = Vector2.new(math.max(viewport.X - screen.X, 0) / 2, UiKit.topInset())
	local origin = self.gui.AbsolutePosition
	local leftBottom, rightWidth, comboBottom = self.run:padFootprint(origin, screen)
	local phone = UiKit.isPhoneViewport(viewport)
	local top = math.max(leftBottom, comboBottom, self.rivalPortrait:bottom(origin.Y)) + PAD_AREA_GAP
	local keys = self.pad:footprint(origin, screen)
	local clap = self.pad:clapReach(origin, screen)
	local abilities = self.abilityBar:reach(origin, screen)
	local left = math.max(keys.X, PAD_AREA_GAP)
	local right = math.max(clap.X, abilities.X + PAD_AREA_GAP, if phone then rightWidth + PAD_AREA_GAP else 0)
	local low = Vector2.new(left, top)
	local high = Vector2.new(screen.X - right, screen.Y - PAD_AREA_GAP)

	return Rect.new(corner + low, corner + high)
end

-- The rival's card sits where PadHud places it, shrunk if it would reach the
-- CLAP key or the ability cards under it.
function HUDController.updateRivalPortrait(self: HUDController, beat: number)
	local portrait = self.rivalPortrait

	if not portrait:isShown() then
		return
	end

	local origin = self.gui.AbsolutePosition
	local screen = self.gui.AbsoluteSize
	local below = math.max(self.pad:clapReach(origin, screen).Y, self.abilityBar:reach(origin, screen).Y)
	portrait:fit(origin.Y + screen.Y - below)
	portrait:update(beat)
end

-- Where floor events show: on the pad, in the grade line under the combo;
-- otherwise just under the song bar.
function HUDController._calloutStrip(self: HUDController, isSmall: boolean): (number, number)
	if self.padLayout and self.run.padLineSpot ~= nil then
		return self.run:padLineSpot(self.gui.AbsolutePosition)
	end

	local height = if isSmall then SMALL_STRIP_HEIGHT else STRIP_HEIGHT
	local viewportY = UiKit.viewportSize().Y
	local belowBar = self.songBar:bottom() + STRIP_GAP
	local aboveFloor = viewportY * PAD_FLOOR_TOP - UiKit.topInset() - height - STRIP_GAP

	return math.max(math.min(belowBar, aboveFloor), self.songBar:clockBottom() + STRIP_GAP), height
end

-- Re-lays the HUD out whenever the window or the device orientation changes.
function HUDController.watchViewport(self: HUDController)
	UiKit.onViewportChanged(function()
		self:applyDeviceLayout()
	end)
end

-- A run hides everything that is not part of it, so the screen is the floor, the
-- score column, and the pause and pad controls.
function HUDController.setRunActive(self: HUDController, active: boolean)
	self.runActive = active
	self.windows:setBlocked(active)

	if active then
		self.popups:clear()
		self.stages:clear()
		self.stagePanels:closeAll()
		self.stagePanels:hideResults()
		self.shop:setVisible(false)
		self.settings:setVisible(false)
		self.abilityPicker:setVisible(false)
		self.multiplayer:setStageLayout(true)
	end

	self.run:setRunActive(active)
	self.hints:setRunLayout(active)

	if not active then
		self.songBar:setVisible(false)
		self.abilityBar:setVisible(false)
		self.rivalPortrait:setRival(nil)
		self.banner:hide()
	end

	self.menu:setIdle(not active)
	self.multiplayer:setModeVisible(not active and not self.lessonFocus)
	self.pause:setRunActive(active)
	self.pad:setVisible(active and UiKit.isTouch())
end

-- The highway and the pad both show the song bar in place of the run column's
-- progress, and move the grade and combo off the middle of the screen.
function HUDController.setRunLayout(self: HUDController, highway: boolean, pad: boolean)
	self.padLayout = pad and not highway

	if self.run.setPadActive ~= nil then
		self.run:setPadActive(self.padLayout)
	end

	self.run:setHighwayActive(highway)
	self.songBar:setVisible(highway or pad)

	-- On the pad the keys show on every device: they double as the guide to the next tile.
	if self.padLayout then
		self.pad:setVisible(true)
	end

	self:applyDeviceLayout()
end

function HUDController.showAbility(self: HUDController, title: string, detail: string?, color: Color3)
	if self.run.showAbility ~= nil then
		self.run:showAbility(title, detail, color)
	end
end

-- Only the authored HUD draws the milestone call-out; the code-built one has none.
function HUDController.showMilestone(self: HUDController, text: string, combo: number?)
	if self.run.showMilestone ~= nil then
		self.run:showMilestone(text, combo)
	end

	self.rivalPortrait:impressed()
end

-- The combo multiplier and shield badges, and the shield's save call-out, are
-- likewise only on the authored HUD.
function HUDController.setComboExtras(self: HUDController, multiplier: number, shieldReady: boolean)
	if self.run.setComboExtras ~= nil then
		self.run:setComboExtras(multiplier, shieldReady)
	end
end

function HUDController.showShieldSave(self: HUDController, combo: number)
	if self.run.showShieldSave ~= nil then
		self.run:showShieldSave(combo)
	end
end

-- callback toggles pause. The authored HUD's own button replaces the code-built
-- one when the place has tagged it.
function HUDController.bindPauseToggle(self: HUDController, callback: () -> ())
	self.pause:bindToggle(callback)
	self.pause:setButtonReplaced(self.run:bindPause(callback))
end

-- Song select is the lobby. The run column and the multiplayer status both sit
-- under the panel, so they come off the screen while it is open rather than
-- showing through the gaps.
function HUDController.showSongSelect(self: HUDController, songs: any)
	self:closePanels()

	if not self.songSelect:isVisible() then
		self.stages:closeAll()
		self.stagePanels:closeAll()
	end

	self.songSelect:show(songs)
	self:refreshStageCover()
	self.run:setIdle(true)
	self.multiplayer:setStageLayout(false)
	self.multiplayer:setVisible(false)
end

-- A picked song plays the picker's launch instead of closing it outright.
function HUDController.launchSongSelect(self: HUDController)
	self.songSelect:launch()
	self:refreshStageCover()
	self.run:setIdle(false)
	self.multiplayer:setVisible(true)
end

function HUDController.hideSongSelect(self: HUDController)
	self.songSelect:hide()
	self:refreshStageCover()
	self.run:setIdle(not self.runActive)
	self.multiplayer:setVisible(true)
end

-- The stage's lobby pieces step aside while the picker or a stage panel fills the screen.
function HUDController.refreshStageCover(self: HUDController)
	self.stages:setCovered(self.songSelect:isVisible() or self.stagePanels:isOpen())
end

function HUDController.showSummary(self: HUDController, summary: any)
	self:_setPhotoMode(false)
	self.run:showFinal(summary)
	self.results:show(summary)
	self.stagePanels:showResults(summary)
	self.resultsShown = true
	-- The authored results fill the screen; the lobby menu and hints would sit on it.
	self.multiplayer:setModeVisible(false)
	self.menu:setPhotoMode(true)
	self.hints:setResultsLayout(true)
	self.hints:setHint(nil)
end

-- The lesson keeps the lobby's rail, cards and play button out of the way, even
-- in the moments between its drills when no run is on.
function HUDController.setLessonFocus(self: HUDController, active: boolean)
	self.lessonFocus = active
	self.menu:setPhotoMode(active or self.photoMode or self.resultsShown)
	self.multiplayer:setVisible(not active and not self.photoMode)
	self.multiplayer:setModeVisible(not active and not self.runActive)
end

function HUDController.isShowingResults(self: HUDController): boolean
	return self.resultsShown
end

function HUDController.hideResults(self: HUDController)
	self:_setPhotoMode(false)

	-- The reveal and anything opened from it sat over the results, and leave with them.
	if self.resultsShown then
		self.stages:clear()
		self.stages:closeAll()
		self.stagePanels:closeAll()
	end

	self.results:hide()
	self.stagePanels:hideResults()
	self.resultsShown = false
	self.menu:setPhotoMode(self.lessonFocus)
	self.hints:setResultsLayout(false)
	self.multiplayer:setModeVisible(not self.runActive and not self.lessonFocus)

	-- The song card and score stay up beside the results; without a run they go too.
	if not self.runActive then
		self.run:setIdle(true)
	end
end

-- Home on the lobby rail: back to the bare lobby, whatever was open over it.
function HUDController.closePanels(self: HUDController)
	self.shop:setVisible(false)
	self.settings:setVisible(false)
	self.abilityPicker:setVisible(false)
	self.windows:close()
end

-- The dancer stays put while the picker or a run's results are up.
function HUDController.blocksSteps(self: HUDController): boolean
	return self.songSelect:isVisible() or self.results:hasPhoto()
end

function HUDController.togglePhotoMode(self: HUDController)
	if not self.results:hasPhoto() then
		return
	end

	self:_setPhotoMode(not self.photoMode)
end

function HUDController._setPhotoMode(self: HUDController, active: boolean)
	if self.photoMode == active then
		return
	end

	self.photoMode = active
	self.run:setPhotoMode(active)
	self.menu:setPhotoMode(active or self.results:hasPhoto() or self.lessonFocus)
	self.multiplayer:setVisible(not active and not self.lessonFocus)
	self.results:setPhotoMode(active)

	if active then
		self.shop:setVisible(false)
		self.hints:setHint(PHOTO_HINT)
	else
		self.hints:setHint(nil)
	end
end

return HUDController
