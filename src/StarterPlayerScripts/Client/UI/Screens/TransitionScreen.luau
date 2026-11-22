--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local COVER_SECONDS = 0.22
local REVEAL_SECONDS = 0.4
local CAPTION_POP_FROM = 0.85
local FLOOR_STEP_SECONDS = 0.3
local TILE_COUNT = 9
local TILE_IDLE = Color3.fromRGB(96, 48, 140)
local TILE_LIT = Color3.fromRGB(255, 132, 229)

type Fields = {
	frame: CanvasGroup?,
	caption: TextLabel?,
	captionScale: UIScale?,
	tiles: { Frame },
	token: number,
}

-- The cover for the trip between the island and the stage, authored in
-- StarterGui.Transition: it fades in, the world is swapped underneath it, and it
-- fades out once the player has arrived, so the lighting and camera never cut in
-- front of them.
local TransitionScreen = {}
TransitionScreen.__index = TransitionScreen

export type TransitionScreen = typeof(setmetatable({} :: Fields, TransitionScreen))

function TransitionScreen.new(gui: ScreenGui?): TransitionScreen
	local cover = UiKit.authored(gui, "Cover", "CanvasGroup")
	local caption = UiKit.authored(cover, "Caption", "GuiObject")
	local floor = UiKit.authored(cover, "Floor", "GuiObject")
	local tiles = {}

	for index = 1, TILE_COUNT do
		local tile = if floor ~= nil then floor:FindFirstChild("Tile" .. index) else nil

		if tile ~= nil and tile:IsA("Frame") then
			table.insert(tiles, tile)
		end
	end

	local fields: Fields = {
		frame = cover,
		caption = UiKit.authored(caption, "CaptionLabel", "TextLabel"),
		captionScale = if caption ~= nil then UiKit.scaleOf(caption, "Pop") else nil,
		tiles = tiles,
		token = 0,
	}

	if cover ~= nil then
		cover.Visible = false
	end

	return setmetatable(fields, TransitionScreen)
end

-- Fades the cover in and calls onCovered once nothing behind it shows. With no
-- authored cover, onCovered runs straight away.
function TransitionScreen.cover(self: TransitionScreen, text: string, onCovered: () -> ())
	local cover = self.frame

	self.token += 1

	local token = self.token

	if cover == nil then
		task.spawn(onCovered)
		return
	end

	if self.caption ~= nil then
		self.caption.Text = text
	end

	if not cover.Visible then
		cover.GroupTransparency = 1
		cover.Visible = true
		self:_lightFloor(cover)
	end

	if self.captionScale ~= nil then
		self.captionScale.Scale = CAPTION_POP_FROM
		TweenService:Create(self.captionScale, TweenInfo.new(COVER_SECONDS * 2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	local fade = TweenService:Create(cover, TweenInfo.new(COVER_SECONDS, Enum.EasingStyle.Quad), { GroupTransparency = 0 })

	fade.Completed:Connect(function()
		if self.token == token then
			onCovered()
		end
	end)
	fade:Play()
end

function TransitionScreen.reveal(self: TransitionScreen)
	local cover = self.frame

	if cover == nil or not cover.Visible then
		return
	end

	self.token += 1

	local token = self.token
	local fade = TweenService:Create(cover, TweenInfo.new(REVEAL_SECONDS, Enum.EasingStyle.Quad), { GroupTransparency = 1 })

	fade.Completed:Connect(function()
		if self.token == token then
			cover.Visible = false
		end
	end)
	fade:Play()
end

function TransitionScreen._lightFloor(self: TransitionScreen, cover: CanvasGroup)
	local tiles = self.tiles

	if #tiles == 0 then
		return
	end

	task.spawn(function()
		local lit = tiles[1]

		while cover.Visible do
			lit.BackgroundColor3 = TILE_IDLE
			lit = tiles[math.random(#tiles)]
			lit.BackgroundColor3 = TILE_LIT
			task.wait(FLOOR_STEP_SECONDS)
		end

		lit.BackgroundColor3 = TILE_IDLE
	end)
end

return TransitionScreen
