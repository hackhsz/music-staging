--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local SLIDE_SECONDS = 0.3
-- Retry and Next close the results a moment before the run starts; the menu waits
-- this long so it does not slide in just to slide out again.
local SHOW_DELAY_SECONDS = 0.6
local RAIL_OFFSCREEN = UDim2.fromScale(-0.2, 0)
-- Far enough to carry the Card's TopButtons, which sit left of the column, off too.
local COLUMN_OFFSCREEN = UDim2.fromScale(0.5, 0)
local DONE_TEXT = "DONE"
local DONE_TRANSPARENCY = 0.45
local DAILY_ROWS = 3
local NO_RANK_TEXT = "-"
local READY_TAG = "Done"
local GAIN_ROLL_SECONDS = 0.7
local GAIN_FLOAT_SECONDS = 1.1
local GAIN_FLOAT_RISE = UDim2.fromScale(0, -0.12)
local STAT_ROWS = {
	bestScore = "BestScore",
	bestCombo = "BestCombo",
	songsCompleted = "SongsPlayed",
	totalPerfects = "Perfects",
}
local RANK_ROWS = {
	all_time_high_score = "ScoreRank",
	weekly_perfect_beats = "WeeklyRank",
}

type DailyRow = { row: GuiObject, name: TextLabel?, progress: TextLabel? }

type Fields = {
	rail: GuiObject?,
	column: GuiObject?,
	railHome: UDim2,
	columnHome: UDim2,
	levelLabel: TextLabel?,
	nameLabel: TextLabel?,
	avatar: ImageLabel?,
	coinLabel: TextLabel?,
	coinGain: TextLabel?,
	coinGainHome: UDim2,
	coinCounter: NumberValue,
	coinTween: Tween?,
	coinTarget: number?,
	coinShown: number?,
	rankStrip: GuiObject?,
	rankNext: TextLabel?,
	rankXp: TextLabel?,
	rankHint: TextLabel?,
	rankFill: GuiObject?,
	rankShare: number?,
	rankShareShown: number?,
	addCoinsButton: GuiButton?,
	homeButton: GuiButton?,
	songButton: GuiButton?,
	loadoutButton: GuiButton?,
	shopButton: GuiButton?,
	wardrobeButton: GuiButton?,
	questsButton: GuiButton?,
	islandsButton: GuiButton?,
	settingsButton: GuiButton?,
	windows: MenuScreen.MenuScreen?,
	giftButton: GuiButton?,
	giftDot: GuiObject?,
	passButton: GuiButton?,
	communityButton: GuiButton?,
	communityDot: GuiObject?,
	daily: GuiObject?,
	dailyRows: { DailyRow },
	dailyHasData: boolean,
	stats: GuiObject?,
	statsOpen: boolean,
	idle: boolean,
	photoMode: boolean,
	menuOpen: boolean,
	covered: boolean,
	shown: boolean,
	onShown: ((shown: boolean) -> ())?,
	slideToken: number,
}

-- The lobby HUD, authored in StarterGui.Lobby: the icon rail on the left, and on
-- the right the player card (avatar, level, name, coins) with the Travel, Rewards
-- and Settings buttons beside it (Card.TopButtons), then the daily challenges.
-- Clicking the card swaps the challenges for the player's stats. Shown between
-- runs; it slides off while one plays.
local SideMenu = {}
SideMenu.__index = SideMenu

export type SideMenu = typeof(setmetatable({} :: Fields, SideMenu))

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	return (formatted:gsub("^,", ""))
end

-- A rail button glows with its HoverImage attribute under the pointer. A sprite
-- name glows only atlas art: on a whole-image button it would stretch an atlas
-- cut of a different shape over it.
local function bindNavHover(button: GuiButton?)
	if button == nil or not button:IsA("ImageButton") then
		return
	end

	local rest = UiKit.imageState(button)
	local glow = button:GetAttribute("HoverImage")

	if type(glow) ~= "string" or (rest.size == Vector2.zero and not glow:match("^rbxassetid://")) then
		UiKit.bindHover(button)
		return
	end

	UiKit.bindHover(button, function(active: boolean)
		UiKit.setImage(button, if active then glow else rest)
	end)
end

local function bindButton(button: GuiButton?, callback: () -> ())
	if button ~= nil then
		button.Activated:Connect(callback)
	end
end

local function tween(instance: Instance, goal: { [string]: any }): Tween
	local playing = TweenService:Create(instance, TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	playing:Play()

	return playing
end

-- windows is the menu whose own rail repeats this one; its buttons do the same.
function SideMenu.new(gui: ScreenGui?, windows: MenuScreen.MenuScreen?): SideMenu
	local rail = UiKit.authored(gui, "Rail", "GuiObject")
	local buttons = UiKit.authored(rail, "Buttons", "GuiObject")
	local column = UiKit.authored(gui, "RightColumn", "GuiObject")
	local card = UiKit.authored(column, "Card", "GuiObject")
	local daily = UiKit.child(column, "Daily", "GuiObject")
	local stats = UiKit.authored(column, "Stats", "GuiObject")
	local topButtons = UiKit.authored(card, "TopButtons", "GuiObject")
	local rankStrip = UiKit.authored(card, "RankStrip", "GuiObject")
	local coinGain = UiKit.authored(card, "CoinGain", "TextLabel")

	local fields: Fields = {
		rail = rail,
		column = column,
		railHome = if rail ~= nil then rail.Position else UDim2.new(),
		columnHome = if column ~= nil then column.Position else UDim2.new(),
		levelLabel = UiKit.authored(card, "LevelLabel", "TextLabel"),
		nameLabel = UiKit.authored(card, "NameLabel", "TextLabel"),
		avatar = UiKit.authored(card, "AvatarFrame.Avatar", "ImageLabel"),
		coinLabel = UiKit.authored(card, "CoinLabel", "TextLabel"),
		coinGain = coinGain,
		coinGainHome = if coinGain ~= nil then coinGain.Position else UDim2.new(),
		coinCounter = Instance.new("NumberValue"),
		coinTween = nil,
		coinTarget = nil,
		coinShown = nil,
		rankStrip = rankStrip,
		rankNext = UiKit.authored(rankStrip, "NextLabel", "TextLabel"),
		rankXp = UiKit.authored(rankStrip, "XpLabel", "TextLabel"),
		rankHint = UiKit.authored(rankStrip, "HintLabel", "TextLabel"),
		rankFill = UiKit.authored(rankStrip, "Bar.Fill", "GuiObject"),
		rankShare = nil,
		rankShareShown = nil,
		addCoinsButton = UiKit.authored(card, "AddCoinsButton", "GuiButton"),
		homeButton = UiKit.authored(buttons, "HomeButton", "GuiButton"),
		songButton = UiKit.authored(buttons, "SongButton", "GuiButton"),
		loadoutButton = UiKit.authored(buttons, "LoadoutButton", "GuiButton"),
		shopButton = UiKit.authored(buttons, "ShopButton", "GuiButton"),
		wardrobeButton = UiKit.authored(buttons, "WardrobeButton", "GuiButton"),
		questsButton = UiKit.authored(buttons, "QuestsButton", "GuiButton"),
		islandsButton = UiKit.authored(topButtons, "IslandsButton", "GuiButton"),
		settingsButton = UiKit.authored(topButtons, "SettingsButton", "GuiButton"),
		windows = windows,
		giftButton = UiKit.authored(topButtons, "GiftButton", "GuiButton"),
		giftDot = UiKit.authored(topButtons, "GiftButton.Dot", "GuiObject"),
		passButton = UiKit.authored(topButtons, "PassButton", "GuiButton"),
		communityButton = UiKit.authored(topButtons, "CommunityButton", "GuiButton"),
		communityDot = UiKit.authored(topButtons, "CommunityButton.Dot", "GuiObject"),
		daily = daily,
		dailyRows = {},
		dailyHasData = false,
		stats = stats,
		statsOpen = false,
		idle = true,
		photoMode = false,
		menuOpen = false,
		covered = false,
		shown = true,
		onShown = nil,
		slideToken = 0,
	}
	local self = setmetatable(fields, SideMenu)

	for index = 1, DAILY_ROWS do
		local row = UiKit.authored(daily, "Row" .. index, "GuiObject")

		if row ~= nil then
			table.insert(fields.dailyRows, {
				row = row,
				name = UiKit.child(row, "NameLabel", "TextLabel"),
				progress = UiKit.child(row, "ProgressLabel", "TextLabel"),
			})
		end
	end

	for _, button in {
		fields.homeButton,
		fields.songButton,
		fields.loadoutButton,
		fields.shopButton,
		fields.wardrobeButton,
		fields.questsButton,
		fields.islandsButton,
		fields.settingsButton,
	} do
		bindNavHover(button)
	end

	for _, button in { fields.giftButton, fields.communityButton, fields.addCoinsButton, fields.passButton } do
		if button ~= nil then
			UiKit.bindHover(button)
		end
	end

	if daily ~= nil then
		daily.Visible = false
	end

	if stats ~= nil then
		stats.Visible = false
	end

	if coinGain ~= nil then
		coinGain.Visible = false
	end

	fields.coinCounter.Changed:Connect(function(value)
		if self.coinLabel ~= nil then
			self.coinLabel.Text = withCommas(value)
		end
	end)

	bindButton(UiKit.authored(card, "StatsButton", "GuiButton"), function()
		self.statsOpen = not self.statsOpen
		self:_refresh()
	end)

	self:_showPlayer()

	return self
end

function SideMenu._showPlayer(self: SideMenu)
	local player = Players.LocalPlayer

	if self.nameLabel ~= nil then
		self.nameLabel.Text = string.upper(player.DisplayName)
	end

	local avatar = self.avatar

	if avatar == nil then
		return
	end

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		if ok and type(image) == "string" then
			avatar.Image = image
		end
	end)
end

function SideMenu.updateBalance(self: SideMenu, amount: number?)
	self.coinTarget = math.max(tonumber(amount) or 0, 0)
	self:_showGains()
end

local function rankHint(stages: any, challenger: any): string
	if challenger == nil then
		local opens = if type(stages.nextOpens) == "table" then stages.nextOpens[1] else nil

		return if opens ~= nil then ("OPENS %s"):format(tostring(opens)) else "MORE STAGES COMING"
	end

	return if challenger.state ~= "PRACTICE"
		then ("CHALLENGE %s READY"):format(tostring(challenger.name))
		else ("%s XP TO %s"):format(withCommas(tonumber(stages.toChallenge) or 0), tostring(challenger.name))
end

-- The rank strip reads the stages snapshot, so it says what the setlist board says.
function SideMenu.updateStage(self: SideMenu, stages: any)
	if type(stages) ~= "table" then
		return
	end

	local xp = tonumber(stages.xp) or 0
	local threshold = tonumber(stages.threshold)
	local challenger = if type(stages.challenger) == "table" then stages.challenger else nil
	local following = if type(stages.ranks) == "table" then stages.ranks[(tonumber(stages.rank) or 0) + 1] else nil

	if self.levelLabel ~= nil then
		self.levelLabel.Text = tostring(stages.name)
	end

	if self.rankNext ~= nil then
		self.rankNext.Text = if type(following) == "table" then ("NEXT: %s"):format(tostring(following.name)) else "TOP STAGE"
	end

	if self.rankXp ~= nil then
		self.rankXp.Text = if threshold ~= nil
			then ("%s / %s XP"):format(withCommas(xp), withCommas(threshold))
			else ("%s XP"):format(withCommas(xp))
	end

	if self.rankHint ~= nil then
		self.rankHint.Text = rankHint(stages, challenger)
	end

	if self.rankStrip ~= nil then
		if challenger ~= nil and challenger.state ~= "PRACTICE" then
			CollectionService:AddTag(self.rankStrip, READY_TAG)
		else
			CollectionService:RemoveTag(self.rankStrip, READY_TAG)
		end
	end

	self.rankShare = if threshold ~= nil then math.clamp(xp / math.max(threshold, 1), 0, 1) else 1
	self:_showGains()
end

-- A run's gains land while the results hide this menu, so they play when it is back.
function SideMenu._showGains(self: SideMenu)
	local target, share, fill = self.coinTarget, self.rankShare, self.rankFill

	if target ~= nil and self.coinShown == nil then
		self.coinShown = target
		self.coinCounter.Value = target
	end

	if share ~= nil and fill ~= nil and self.rankShareShown == nil then
		self.rankShareShown = share
		fill.Size = UDim2.fromScale(share, 1)
	end

	if not self.shown then
		return
	end

	if share ~= nil and fill ~= nil and share ~= self.rankShareShown then
		self.rankShareShown = share
		TweenService:Create(fill, TweenInfo.new(GAIN_ROLL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(share, 1),
		}):Play()
	end

	if target == nil or target == self.coinShown then
		return
	end

	local gained = target - (self.coinShown or target)

	self.coinShown = target

	if self.coinTween ~= nil then
		self.coinTween:Cancel()
		self.coinTween = nil
	end

	if gained < 0 then
		self.coinCounter.Value = target
		return
	end

	local roll = TweenService:Create(self.coinCounter, TweenInfo.new(GAIN_ROLL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = target,
	})

	self.coinTween = roll
	roll:Play()
	self:_floatCoinGain(gained)
end

function SideMenu._floatCoinGain(self: SideMenu, gained: number)
	local label = self.coinGain

	if label == nil then
		return
	end

	local info = TweenInfo.new(GAIN_FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local stroke = label:FindFirstChildOfClass("UIStroke")

	label.Text = ("+%s"):format(withCommas(gained))
	label.Position = self.coinGainHome
	label.TextTransparency = 0
	label.Visible = true
	TweenService:Create(label, info, { Position = self.coinGainHome + GAIN_FLOAT_RISE, TextTransparency = 1 }):Play()

	if stroke ~= nil then
		stroke.Transparency = 0
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
end

function SideMenu.updateDaily(self: SideMenu, list: any)
	local count = if type(list) == "table" then #list else 0

	for index, slot in self.dailyRows do
		local daily = if index <= count then list[index] else nil

		slot.row.Visible = daily ~= nil

		if daily ~= nil then
			local done = daily.done == true

			if slot.name ~= nil then
				slot.name.Text = string.upper(tostring(daily.name or ""))
				slot.name.TextTransparency = if done then DONE_TRANSPARENCY else 0
			end

			if slot.progress ~= nil then
				slot.progress.Text = if done then DONE_TEXT else ("%d/%d"):format(daily.value or 0, daily.target or 0)
			end
		end
	end

	self.dailyHasData = count > 0
	self:_refresh()
end

function SideMenu._setStat(self: SideMenu, rowName: string, text: string)
	local label = UiKit.child(UiKit.child(self.stats, rowName, "GuiObject"), "ProgressLabel", "TextLabel")

	if label ~= nil then
		label.Text = text
	end
end

function SideMenu.updateStats(self: SideMenu, stats: any)
	if type(stats) ~= "table" then
		return
	end

	for key, rowName in STAT_ROWS do
		self:_setStat(rowName, withCommas(math.max(tonumber(stats[key]) or 0, 0)))
	end
end

-- boards is the leaderboard push; a rank past the first page reads 100+.
function SideMenu.updateRanks(self: SideMenu, boards: { any })
	for _, board in boards do
		local rowName = RANK_ROWS[board.id]

		if rowName == nil then
			continue
		end

		local you = board.you
		self:_setStat(rowName, if you == nil then NO_RANK_TEXT elseif you.rank ~= nil then "#" .. you.rank else "100+")
	end
end

-- Idle means no run is going on; the menu is only for the lobby and results.
function SideMenu.setIdle(self: SideMenu, idle: boolean)
	self.idle = idle
	self:_refresh()
end

function SideMenu.setPhotoMode(self: SideMenu, active: boolean)
	self.photoMode = active
	self:_refresh()
end

function SideMenu._bindNav(self: SideMenu, button: GuiButton?, key: string, callback: () -> ())
	bindButton(button, callback)

	if self.windows ~= nil then
		bindButton(self.windows:navButton(key), callback)
	end
end

-- A rail button by the window it opens, for the walkthrough to point at.
function SideMenu.navButton(self: SideMenu, key: string): GuiButton?
	local buttons: { [string]: GuiButton? } = {
		shop = self.shopButton,
		wardrobe = self.wardrobeButton,
		quests = self.questsButton,
		islands = self.islandsButton,
		loadout = self.loadoutButton,
		settings = self.settingsButton,
	}

	return buttons[key]
end

function SideMenu.bindShop(self: SideMenu, callback: () -> ())
	self:_bindNav(self.shopButton, "shop", callback)
	bindButton(self.addCoinsButton, callback)
end

function SideMenu.bindWardrobe(self: SideMenu, callback: () -> ())
	self:_bindNav(self.wardrobeButton, "wardrobe", callback)
end

function SideMenu.bindQuests(self: SideMenu, callback: () -> ())
	self:_bindNav(self.questsButton, "quests", callback)
end

function SideMenu.bindIslands(self: SideMenu, callback: () -> ())
	self:_bindNav(self.islandsButton, "islands", callback)
end

-- The red dot on the Rewards button while a play-time gift is waiting.
function SideMenu.setGiftReady(self: SideMenu, ready: boolean)
	if self.giftDot ~= nil then
		self.giftDot.Visible = ready
	end
end

function SideMenu.bindDaily(self: SideMenu, callback: () -> ())
	bindButton(self.giftButton, callback)
end

function SideMenu.bindPass(self: SideMenu, callback: () -> ())
	bindButton(self.passButton, callback)
end

-- The red dot on the Group button while the daily gift is waiting.
function SideMenu.setCommunityReady(self: SideMenu, ready: boolean)
	if self.communityDot ~= nil then
		self.communityDot.Visible = ready
	end
end

function SideMenu.bindCommunity(self: SideMenu, callback: () -> ())
	bindButton(self.communityButton, callback)
end

function SideMenu.bindSettings(self: SideMenu, callback: () -> ())
	self:_bindNav(self.settingsButton, "settings", callback)
end

function SideMenu.bindAbilities(self: SideMenu, callback: () -> ())
	self:_bindNav(self.loadoutButton, "loadout", callback)
end

function SideMenu.bindRank(self: SideMenu, callback: () -> ())
	bindButton(UiKit.authored(self.rankStrip, "RankButton", "GuiButton"), callback)
end

-- Told whenever the lobby HUD slides on or off, and once with where it stands now.
function SideMenu.bindShown(self: SideMenu, callback: (shown: boolean) -> ())
	self.onShown = callback
	callback(self.shown)
end

function SideMenu.bindSongs(self: SideMenu, callback: () -> ())
	self:_bindNav(self.songButton, "song", callback)
end

function SideMenu.bindHome(self: SideMenu, callback: () -> ())
	self:_bindNav(self.homeButton, "home", callback)
end

-- An open window brings its own rail, so this one steps aside.
function SideMenu.setMenuOpen(self: SideMenu, open: boolean)
	self.menuOpen = open
	self:_refresh(0)
end

-- A full-screen stage panel is over the lobby. The rail and card slide off without the
-- lobby counting as hidden, since hiding it would close the panel that hangs off it.
function SideMenu.setCovered(self: SideMenu, covered: boolean)
	if self.covered == covered then
		return
	end

	self.covered = covered
	self.slideToken += 1
	self:_slide(self.rail, self.railHome, RAIL_OFFSCREEN)
	self:_slide(self.column, self.columnHome, COLUMN_OFFSCREEN)
end

-- showDelay holds the slide-in back (Retry's flicker guard); a closing window
-- passes 0 so the lobby comes straight back.
function SideMenu._refresh(self: SideMenu, showDelay: number?)
	if self.daily ~= nil then
		self.daily.Visible = self.dailyHasData and not self.statsOpen
	end

	if self.stats ~= nil then
		self.stats.Visible = self.statsOpen
	end

	local shown = self.idle and not self.photoMode and not self.menuOpen

	if shown == self.shown then
		return
	end

	self.shown = shown
	self.slideToken += 1

	if self.onShown ~= nil then
		self.onShown(shown)
	end

	local token = self.slideToken

	task.delay(if shown then showDelay or SHOW_DELAY_SECONDS else 0, function()
		if self.slideToken == token then
			self:_slide(self.rail, self.railHome, RAIL_OFFSCREEN)
			self:_slide(self.column, self.columnHome, COLUMN_OFFSCREEN)
		end
	end)
end

function SideMenu._slide(self: SideMenu, gui: GuiObject?, home: UDim2, away: UDim2)
	if gui == nil then
		return
	end

	if self.shown and not self.covered then
		gui.Visible = true
		gui.Position = home + away
		tween(gui, { Position = home }).Completed:Connect(function()
			self:_showGains()
		end)
		return
	end

	local token = self.slideToken

	tween(gui, { Position = home + away }).Completed:Connect(function()
		if self.slideToken == token then
			gui.Visible = false
		end
	end)
end

return SideMenu
