--!strict
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local TIPS = {
	"WALK TO THE LIT TILE AND BE ON IT WHEN THE BEAT LANDS",
	"BLUE TILES: ANY OF THEM COUNTS",
	"YELLOW MEANS CLAP",
	"RED TILES: GET OFF BEFORE THE BEAT",
	"A LONGER STAND ON THE TILE MEANS A BETTER GRADE",
	"DAILY CHALLENGES PAY BEAT COINS",
	"SPEND COINS ON WANDS, TRAILS AND AURAS IN THE SHOP",
}
-- Authored in ReplicatedFirst (in the place file) so it reaches the client before anything
-- else and can animate from the first frame.
local GUI_NAME = "Loading"
local PAPER = Color3.fromRGB(244, 238, 230)
local PINK = Color3.fromRGB(255, 45, 143)
-- The authored lobby HUD and windows, whose art is preloaded behind the screen.
local PRELOAD_GUIS = { "Lobby", "Menu", "GameHud", "PadHud", "Songs" }
-- Main.client sets ClientReady once every controller has started; the
-- onboarding waits for LoadingDone before it starts the lesson.
local READY_ATTRIBUTE = "ClientReady"
local DONE_ATTRIBUTE = "LoadingDone"

local GUI_WAIT_SECONDS = 20
local LOADING_GUI_WAIT_SECONDS = 10
local READY_WAIT_SECONDS = 30
local PRELOAD_BATCH = 20
local MIN_SHOW_SECONDS = 4.5
local SKIP_AFTER_SECONDS = 6
local TIP_SECONDS = 3.5
local BEAT_SECONDS = 0.5
local LOGO_BEAT_SCALE = 1.03
local VINYL_TURN_SECONDS = 1.6
local TIP_FADE_SECONDS = 0.25
local BAR_SECONDS = 0.5
local DOT_SECONDS = 0.4
local POP_SECONDS = 0.45
local POP_STAGGER_SECONDS = 0.14
local DRIFT_SECONDS = 7
local DRIFT_FROM = UDim2.fromScale(0.485, 0.5)
local DRIFT_TO = UDim2.fromScale(0.515, 0.5)
local DECK_TURN_SECONDS = 9
local READY_PUNCH_SCALE = 1.12
local READY_HOLD_SECONDS = 0.45
local WIPE_TILT = 12
local WIPE_SIZE = UDim2.fromScale(1.5, 1.9)
local WIPE_TRAIL = 0.14
local WIPE_IN_SECONDS = 0.4
local WIPE_OUT_SECONDS = 0.5
-- Share of the bar each phase fills: the place, then the UI art, then the HUD.
local PLACE_SHARE = 0.3
local ART_SHARE = 0.6

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local authored = ReplicatedFirst:WaitForChild(GUI_NAME, LOADING_GUI_WAIT_SECONDS)

if authored == nil or not authored:IsA("ScreenGui") then
	warn("[DanceDanceStep] ReplicatedFirst.Loading not found; no loading screen")
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	player:SetAttribute(DONE_ATTRIBUTE, true)
	return
end

local gui = authored:Clone()

gui.ResetOnSpawn = false
gui.Parent = playerGui

local root = gui:WaitForChild("Root") :: CanvasGroup
local column = root:WaitForChild("Column")
local backdrop = root:WaitForChild("Backdrop")
local art = backdrop:WaitForChild("Art") :: ImageLabel
local deck = backdrop:FindFirstChild("Deck")
local logo = column:WaitForChild("Logo") :: ImageLabel
local tagline = column:WaitForChild("Tagline") :: ImageLabel
local bar = column:WaitForChild("Bar") :: Frame
local fill = bar:WaitForChild("Fill") :: Frame
local fillArt = fill:WaitForChild("FillArt") :: ImageLabel
local vinyl = bar:WaitForChild("Vinyl") :: ImageLabel
local status = bar:WaitForChild("Status") :: TextLabel
local percent = bar:WaitForChild("Percent") :: TextLabel
local tip = root:WaitForChild("Tip") :: TextLabel
local skip = root:WaitForChild("Skip") :: TextButton

local function scaleOf(object: Instance): UIScale
	local scale = Instance.new("UIScale")

	scale.Parent = object

	return scale
end

local logoScale = scaleOf(logo)
local statusLabel = "LOADING"

-- The fill is a window onto bar-wide art, so the stripes never squash as it grows.
local function fitFillArt()
	fillArt.Size = UDim2.new(0, bar.AbsoluteSize.X, fillArt.Size.Y.Scale, 0)
end

bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitFillArt)
fitFillArt()
fill.Size = UDim2.fromScale(0, 1)
vinyl.Position = UDim2.fromScale(0, 0.5)
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
	statusLabel = label
	percent.Text = ("%d%%"):format(math.floor(progress * 100))
	local glide = TweenInfo.new(BAR_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(fill, glide, { Size = UDim2.fromScale(progress, 1) }):Play()
	TweenService:Create(vinyl, glide, { Position = UDim2.fromScale(progress, 0.5) }):Play()
end

TweenService:Create(vinyl, TweenInfo.new(VINYL_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()

art.Position = DRIFT_FROM
TweenService:Create(
	art,
	TweenInfo.new(DRIFT_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = DRIFT_TO }
):Play()

if deck ~= nil then
	TweenService:Create(deck, TweenInfo.new(DECK_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
end

for index, scale in { logoScale, scaleOf(tagline), scaleOf(bar), scaleOf(tip) } do
	scale.Scale = 0
	TweenService:Create(
		scale,
		TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * POP_STAGGER_SECONDS),
		{ Scale = 1 }
	):Play()
end

task.spawn(function()
	local dots = 0

	while not finished do
		status.Text = statusLabel .. string.rep(".", dots)
		dots = (dots + 1) % 4
		task.wait(DOT_SECONDS)
	end
end)

task.spawn(function()
	task.wait(POP_SECONDS)

	while not finished do
		logoScale.Scale = LOGO_BEAT_SCALE
		TweenService:Create(logoScale, TweenInfo.new(BEAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.wait(BEAT_SECONDS)
	end
end)

task.spawn(function()
	local index = 1

	while not finished do
		task.wait(TIP_SECONDS)
		index = index % #TIPS + 1

		local fadeOut = TweenService:Create(tip, TweenInfo.new(TIP_FADE_SECONDS), { TextTransparency = 1 })

		fadeOut:Play()
		fadeOut.Completed:Wait()
		tip.Text = TIPS[index]
		TweenService:Create(tip, TweenInfo.new(TIP_FADE_SECONDS), { TextTransparency = 0 }):Play()
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
status.Text = "READY"
TweenService:Create(
	logoScale,
	TweenInfo.new(READY_HOLD_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	{ Scale = READY_PUNCH_SCALE }
):Play()
task.wait(READY_HOLD_SECONDS)

local function wipePanel(color: Color3, zIndex: number, lag: number): (Frame, number)
	local panel = Instance.new("Frame")

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = WIPE_SIZE
	panel.Rotation = WIPE_TILT
	panel.Position = UDim2.fromScale(-1 - lag, 0.5)
	panel.BackgroundColor3 = color
	panel.BorderSizePixel = 0
	panel.ZIndex = zIndex
	panel.Parent = gui

	return panel, lag
end

-- A slanted pink sheet sweeps across, the screen is dropped behind it, and it carries on
-- off the far side with a paper edge trailing.
local sheets = { { wipePanel(PINK, 21, 0) }, { wipePanel(PAPER, 20, WIPE_TRAIL) } }
local cover

for _, sheet in sheets do
	cover = TweenService:Create(
		sheet[1],
		TweenInfo.new(WIPE_IN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromScale(0.5 - sheet[2], 0.5) }
	)
	cover:Play()
end

cover.Completed:Wait()
root.Visible = false

local reveal

for _, sheet in sheets do
	reveal = TweenService:Create(
		sheet[1],
		TweenInfo.new(WIPE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(2.1 - sheet[2], 0.5) }
	)
	reveal:Play()
end

reveal.Completed:Wait()
gui:Destroy()
player:SetAttribute(DONE_ATTRIBUTE, true)
