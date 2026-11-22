--!strict
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local COLORS = {
	track = Color3.fromRGB(96, 48, 140),
	pink = Color3.fromRGB(255, 132, 229),
	yellow = Color3.fromRGB(255, 226, 76),
}

local TIPS = {
	"WALK TO THE LIT TILE AND BE ON IT WHEN THE BEAT LANDS",
	"BLUE TILES: ANY OF THEM COUNTS",
	"YELLOW MEANS CLAP",
	"RED TILES: GET OFF BEFORE THE BEAT",
	"A LONGER STAND ON THE TILE MEANS A BETTER GRADE",
	"DAILY CHALLENGES PAY BEAT COINS",
	"SPEND COINS ON WANDS, TRAILS AND AURAS IN THE SHOP",
}
-- Authored in StarterGui so it can be edited in Studio; it only reaches the
-- client with the rest of StarterGui, so the default screen covers until then.
local GUI_NAME = "Loading"
-- The authored lobby HUD and windows, whose art is preloaded behind the screen.
local PRELOAD_GUIS = { "Lobby", "Menu", "GameHud", "PadHud", "Songs" }
-- Main.client sets ClientReady once every controller has started; the
-- onboarding waits for LoadingDone before it starts the lesson.
local READY_ATTRIBUTE = "ClientReady"
local DONE_ATTRIBUTE = "LoadingDone"

local GUI_WAIT_SECONDS = 20
local LOADING_GUI_WAIT_SECONDS = 30
local READY_WAIT_SECONDS = 30
local PRELOAD_BATCH = 20
local MIN_SHOW_SECONDS = 2
local SKIP_AFTER_SECONDS = 6
local TIP_SECONDS = 3.5
local FLOOR_STEP_SECONDS = 0.45
local FADE_SECONDS = 0.5
local BAR_SECONDS = 0.25
-- Share of the bar each phase fills: the place, then the UI art, then the HUD.
local PLACE_SHARE = 0.3
local ART_SHARE = 0.6

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = playerGui:WaitForChild(GUI_NAME, LOADING_GUI_WAIT_SECONDS) :: ScreenGui?

if gui == nil then
	warn("[DanceDanceStep] StarterGui.Loading not found; no loading screen")
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	player:SetAttribute(DONE_ATTRIBUTE, true)
	return
end

local root = gui:WaitForChild("Root") :: CanvasGroup
local column = root:WaitForChild("Column")
local floor = column:WaitForChild("Floor")
local fill = column:WaitForChild("Bar"):WaitForChild("Fill") :: Frame
local status = column:WaitForChild("Status") :: TextLabel
local tip = root:WaitForChild("Tip") :: TextLabel
local skip = root:WaitForChild("Skip") :: TextButton
local tiles: { Frame } = {}

for index = 1, 9 do
	local tile = floor:WaitForChild("Tile" .. index) :: Frame
	tile.BackgroundColor3 = COLORS.track
	table.insert(tiles, tile)
end

fill.Size = UDim2.fromScale(0, 1)
tip.Text = TIPS[math.random(#TIPS)]
skip.Visible = false
root.GroupTransparency = 0
gui.Enabled = true
ReplicatedFirst:RemoveDefaultLoadingScreen()

local shownAt = os.clock()
local finished = false
local skipped = false
local progress = 0

local function setProgress(value: number, label: string)
	progress = math.max(progress, math.clamp(value, 0, 1))
	status.Text = ("%s  %d%%"):format(label, math.floor(progress * 100))
	TweenService:Create(fill, TweenInfo.new(BAR_SECONDS), { Size = UDim2.fromScale(progress, 1) }):Play()
end

task.spawn(function()
	local lit = 1

	while not finished do
		tiles[lit].BackgroundColor3 = COLORS.track
		lit = math.random(#tiles)
		tiles[lit].BackgroundColor3 = if math.random() < 0.2 then COLORS.yellow else COLORS.pink
		task.wait(FLOOR_STEP_SECONDS)
	end
end)

task.spawn(function()
	local index = 1

	while not finished do
		task.wait(TIP_SECONDS)
		index = index % #TIPS + 1
		tip.Text = TIPS[index]
	end
end)

task.delay(SKIP_AFTER_SECONDS, function()
	if not finished then
		skip.Visible = true
	end
end)

skip.Activated:Connect(function()
	skipped = true
end)

-- Waits until done() or the timeout, unless the player skips first.
local function waitFor(done: () -> boolean, timeout: number)
	local deadline = os.clock() + timeout

	while not skipped and not done() and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function collectArt(): { string }
	local seen: { [string]: boolean } = {}
	local art = {}

	for _, name in PRELOAD_GUIS do
		local authored = playerGui:FindFirstChild(name)

		if authored == nil then
			continue
		end

		for _, descendant in authored:GetDescendants() do
			local image = if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")
				then (descendant :: any).Image :: string
				else nil

			if image ~= nil and image ~= "" and not seen[image] then
				seen[image] = true
				table.insert(art, image)
			end
		end
	end

	return art
end

local function preloadArt()
	waitFor(function()
		return playerGui:FindFirstChild("Lobby") ~= nil and playerGui:FindFirstChild("Menu") ~= nil
	end, GUI_WAIT_SECONDS)

	local art = collectArt()

	for first = 1, #art, PRELOAD_BATCH do
		if skipped then
			return
		end

		local batch = table.move(art, first, math.min(first + PRELOAD_BATCH - 1, #art), 1, {})
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		if not ok then
			warn("[DanceDanceStep] Loading screen preload failed: " .. tostring(err))
		end

		setProgress(PLACE_SHARE + ART_SHARE * math.min(first + PRELOAD_BATCH - 1, #art) / #art, "LOADING ART")
	end
end

setProgress(0, "LOADING")

if not game:IsLoaded() then
	waitFor(function()
		return game:IsLoaded()
	end, math.huge)
end

setProgress(PLACE_SHARE, "LOADING ART")
preloadArt()
setProgress(PLACE_SHARE + ART_SHARE, "GETTING THE STAGE READY")
waitFor(function()
	return player:GetAttribute(READY_ATTRIBUTE) == true
end, READY_WAIT_SECONDS)
setProgress(1, "READY")

waitFor(function()
	return os.clock() - shownAt >= MIN_SHOW_SECONDS
end, MIN_SHOW_SECONDS)

finished = true
skip.Visible = false

local fade = TweenService:Create(root, TweenInfo.new(FADE_SECONDS), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
player:SetAttribute(DONE_ATTRIBUTE, true)
