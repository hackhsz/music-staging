--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local POP_SCALE = 1.1
local POP_SECONDS = 0.22
local FADE_SECONDS = 0.25
local COUNT_POP_SCALE = 1.6
local POP_NAME = "Pop"

type Fields = {
	frame: GuiObject?,
	title: TextLabel?,
	detail: TextLabel?,
	count: TextLabel?,
	scale: UIScale?,
	countScale: UIScale?,
	stroke: UIStroke?,
	frameRest: number,
	strokeRest: number,
	shown: boolean,
}

-- The call-out for a floor event: a big title such as FLOOR IS LAVA!, what to
-- do, and the 3-2-1 before it starts. Authored in StarterGui.GameHud.EventBanner;
-- the game sets only its height on screen, so it lands in the grade line's strip.
local EventBanner = {}
EventBanner.__index = EventBanner

export type EventBanner = typeof(setmetatable({} :: Fields, EventBanner))

function EventBanner.new(gui: ScreenGui?): EventBanner
	local frame = UiKit.authored(gui, "EventBanner", "GuiObject")
	local count = UiKit.authored(frame, "Count", "TextLabel")
	local stroke = if frame ~= nil then frame:FindFirstChildOfClass("UIStroke") else nil

	if frame ~= nil then
		frame.Visible = false
	end

	local fields: Fields = {
		frame = frame,
		title = UiKit.authored(frame, "Title", "TextLabel"),
		detail = UiKit.authored(frame, "Detail", "TextLabel"),
		count = count,
		scale = if frame ~= nil then UiKit.scaleOf(frame, POP_NAME) else nil,
		countScale = if count ~= nil then UiKit.scaleOf(count, POP_NAME) else nil,
		stroke = stroke,
		frameRest = if frame ~= nil then frame.BackgroundTransparency else 1,
		strokeRest = if stroke ~= nil then stroke.Transparency else 1,
		shown = false,
	}

	return setmetatable(fields, EventBanner)
end

function EventBanner._labels(self: EventBanner): { TextLabel }
	local labels = {}

	for _, label in { self.title, self.detail, self.count } do
		if label ~= nil then
			table.insert(labels, label)
		end
	end

	return labels
end

-- top and height place the strip, in pixels from the top of the HUD.
function EventBanner.applyLayout(self: EventBanner, top: number?, height: number?)
	local frame = self.frame

	if frame == nil then
		return
	end

	local position = frame.Position
	local size = frame.Size
	frame.Position = UDim2.new(position.X.Scale, position.X.Offset, 0, top or position.Y.Offset)
	frame.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, height or size.Y.Offset)
end

function EventBanner.show(self: EventBanner, title: string, detail: string?, color: Color3)
	local frame = self.frame

	if frame == nil then
		return
	end

	if self.title ~= nil then
		self.title.Text = title
		self.title.TextColor3 = color
	end

	if self.detail ~= nil then
		self.detail.Text = detail or ""
	end

	frame.Visible = true
	self.shown = true
	frame.BackgroundTransparency = 1

	local info = TweenInfo.new(POP_SECONDS)
	TweenService:Create(frame, info, { BackgroundTransparency = self.frameRest }):Play()

	if self.stroke ~= nil then
		self.stroke.Color = color
		self.stroke.Transparency = 1
		TweenService:Create(self.stroke, info, { Transparency = self.strokeRest }):Play()
	end

	if self.scale ~= nil then
		self.scale.Scale = POP_SCALE
		TweenService:Create(self.scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	for _, label in self:_labels() do
		label.TextTransparency = 0
	end
end

function EventBanner.setCount(self: EventBanner, text: string?)
	if self.count == nil then
		return
	end

	self.count.Text = text or ""

	if text == nil or self.countScale == nil then
		return
	end

	self.countScale.Scale = COUNT_POP_SCALE
	TweenService:Create(self.countScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function EventBanner.hide(self: EventBanner)
	local frame = self.frame

	if not self.shown or frame == nil then
		return
	end

	self.shown = false

	local info = TweenInfo.new(FADE_SECONDS)
	local fade = TweenService:Create(frame, info, { BackgroundTransparency = 1 })

	if self.stroke ~= nil then
		TweenService:Create(self.stroke, info, { Transparency = 1 }):Play()
	end

	for _, label in self:_labels() do
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	end

	fade.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not self.shown then
			frame.Visible = false

			if self.count ~= nil then
				self.count.Text = ""
			end
		end
	end)
	fade:Play()
end

return EventBanner
