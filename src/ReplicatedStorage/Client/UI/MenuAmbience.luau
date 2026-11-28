--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local LAYER_NAME = "Ambience"
-- White sprites, tinted here: six notes, six sparks, six print bits.
local NOTE_ART = {
	"rbxassetid://127783594060006",
	"rbxassetid://103291572883037",
	"rbxassetid://113097196459587",
	"rbxassetid://120941149570643",
	"rbxassetid://119230522768992",
	"rbxassetid://80030856918895",
	"rbxassetid://128977650414965",
	"rbxassetid://119268714993948",
	"rbxassetid://128186328194194",
	"rbxassetid://109395638785571",
	"rbxassetid://120553395167483",
	"rbxassetid://106878694719885",
	"rbxassetid://98689568999351",
	"rbxassetid://89320118268625",
	"rbxassetid://98744677218212",
	"rbxassetid://83962624789343",
	"rbxassetid://126879842904216",
	"rbxassetid://127767293242938",
}
local RECORD_ART = "rbxassetid://131787170534944"
local NOTE_COUNT = 16
local MIN_SECONDS = 10
local MAX_SECONDS = 18
local MIN_SIZE = 0.05
local MAX_SIZE = 0.11
local FAINT = 0.7
local FAINTEST = 0.88
local SWAY = 0.05
local TURN_DEGREES = 30
local START_Y = 1.12
local END_Y = -0.14
local RECORD_SIZE = 0.62
local RECORD_POSITION = UDim2.fromScale(0.97, 0.03)
local RECORD_FAINT = 0.78
local RECORD_TURN_SECONDS = 24
local HIDDEN_WAIT_SECONDS = 0.5
local TWINKLE_SCALE = 1.25
local BAR_COUNT = 18
local BAR_AREA = UDim2.fromScale(1, 0.16)
local BAR_WIDTH = 0.6
local BAR_FAINT = 0.8
local BAR_MIN = 0.12
local BEAT_SECONDS = 0.5
local PAPER = Color3.fromRGB(244, 238, 230)
local PINK = Color3.fromRGB(255, 45, 143)

-- Life behind a menu window: faint notes drifting up its panel and a record turning slowly in
-- the corner. They are children of the panel's background, so they sit over its art and under
-- everything the window shows. Tweens only.
local MenuAmbience = {}

local function square(image: ImageLabel)
	local aspect = Instance.new("UIAspectRatioConstraint")

	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = image
end

local function sprite(layer: Frame, art: string): ImageLabel
	local image = Instance.new("ImageLabel")

	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = art
	image.ZIndex = layer.ZIndex
	square(image)
	image.Parent = layer

	return image
end

-- An equalizer along the panel's bottom edge, jumping to new heights on a 120 bpm beat.
local function equalizer(layer: Frame, isShown: () -> boolean, random: Random)
	local area = Instance.new("Frame")

	area.BackgroundTransparency = 1
	area.AnchorPoint = Vector2.new(0, 1)
	area.Position = UDim2.fromScale(0, 1)
	area.Size = BAR_AREA
	area.ZIndex = layer.ZIndex
	area.Parent = layer

	local bars: { Frame } = {}

	for index = 1, BAR_COUNT do
		local bar = Instance.new("Frame")

		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = PINK
		bar.BackgroundTransparency = BAR_FAINT
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale((index - 0.5) / BAR_COUNT, 1)
		bar.Size = UDim2.fromScale(BAR_WIDTH / BAR_COUNT, BAR_MIN)
		bar.ZIndex = layer.ZIndex
		bar.Parent = area
		table.insert(bars, bar)
	end

	while layer.Parent ~= nil do
		if isShown() then
			for _, bar in bars do
				TweenService:Create(
					bar,
					TweenInfo.new(BEAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(BAR_WIDTH / BAR_COUNT, random:NextNumber(BAR_MIN, 1)) }
				):Play()
			end
		end

		task.wait(BEAT_SECONDS)
	end
end

-- One note, rising again and again. The first rise starts part-way up so a window that has
-- just opened is not empty.
local function drift(layer: Frame, isShown: () -> boolean, random: Random)
	local note = sprite(layer, NOTE_ART[1])
	local from = random:NextNumber(END_Y, START_Y)
	local twinkle = Instance.new("UIScale")

	twinkle.Parent = note
	TweenService:Create(
		twinkle,
		TweenInfo.new(random:NextNumber(0.5, 1.4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = TWINKLE_SCALE }
	):Play()

	while layer.Parent ~= nil do
		if not isShown() then
			task.wait(HIDDEN_WAIT_SECONDS)
			continue
		end

		local x = random:NextNumber(0.04, 0.96)
		local size = random:NextNumber(MIN_SIZE, MAX_SIZE)
		local share = (from - END_Y) / (START_Y - END_Y)

		note.Image = NOTE_ART[random:NextInteger(1, #NOTE_ART)]
		note.ImageColor3 = if random:NextNumber() < 0.35 then PINK else PAPER
		note.ImageTransparency = random:NextNumber(FAINT, FAINTEST)
		note.Size = UDim2.fromScale(size, size)
		note.Position = UDim2.fromScale(x, from)
		note.Rotation = random:NextNumber(-TURN_DEGREES, TURN_DEGREES)

		local rise = TweenService:Create(
			note,
			TweenInfo.new(random:NextNumber(MIN_SECONDS, MAX_SECONDS) * share, Enum.EasingStyle.Linear),
			{
				Position = UDim2.fromScale(x + random:NextNumber(-SWAY, SWAY), END_Y),
				Rotation = note.Rotation + random:NextNumber(-TURN_DEGREES, TURN_DEGREES),
			}
		)

		rise:Play()
		rise.Completed:Wait()
		from = START_Y
	end
end

-- background: the window's panel art. isShown: whether the window is on screen, so nothing
-- is restarted behind a closed menu.
function MenuAmbience.attach(background: GuiObject, isShown: () -> boolean)
	if GuiService.ReducedMotionEnabled or background:FindFirstChild(LAYER_NAME) ~= nil then
		return
	end

	local layer = Instance.new("Frame")

	layer.Name = LAYER_NAME
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = background.ZIndex
	layer.Parent = background

	local record = sprite(layer, RECORD_ART)

	record.Size = UDim2.fromScale(RECORD_SIZE, RECORD_SIZE)
	record.Position = RECORD_POSITION
	record.ImageTransparency = RECORD_FAINT
	TweenService:Create(
		record,
		TweenInfo.new(RECORD_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	):Play()

	local random = Random.new()

	for _ = 1, NOTE_COUNT do
		task.spawn(drift, layer, isShown, random)
	end

	task.spawn(equalizer, layer, isShown, random)
end

return MenuAmbience
