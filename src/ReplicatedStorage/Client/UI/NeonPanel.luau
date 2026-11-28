--!strict
local UiKit = require(script.Parent.UiKit)
local TweenSlots = require(script.Parent.TweenSlots)

local OUTLINE_IMAGE = "rbxassetid://135170752023997"
local INSIDE_IMAGE = "rbxassetid://102740735299284"
-- Both images are 512x206 with a 28 px border; the inside fills exactly the outline's hole.
local SLICE_CENTER = Rect.new(28, 28, 484, 178)
local SLICE_BORDER = 28
local SLICE_SCALE = 0.25
local SPIN_DEGREES_PER_BEAT = 30
local IDLE_OUTLINE_TRANSPARENCY = 0.35
local BEAT_INSIDE_LIFT = 0.18
local FLASH_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local OUTLINE_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, UiKit.Colors.Fever),
	ColorSequenceKeypoint.new(0.35, UiKit.Colors.Purple),
	ColorSequenceKeypoint.new(0.65, UiKit.Colors.Cyan),
	ColorSequenceKeypoint.new(1, UiKit.Colors.Fever),
})

local NeonPanel = {}
NeonPanel.__index = NeonPanel

type Fields = {
	frame: GuiObject,
	content: GuiObject,
	outline: ImageLabel,
	inside: ImageLabel,
	gradient: UIGradient,
	insideColor: Color3,
	tweens: TweenSlots.TweenSlots,
}

export type NeonPanel = typeof(setmetatable({} :: Fields, NeonPanel))

local function slicedImage(parent: Instance, name: string, image: string, zIndex: number): ImageLabel
	return UiKit.create("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = SLICE_CENTER,
		SliceScale = SLICE_SCALE,
		ZIndex = zIndex,
	}, parent)
end

function NeonPanel.new(parent: Instance, name: string, properties: { [string]: any }?): NeonPanel
	local frame: Frame = UiKit.create("Frame", { Name = name, BackgroundTransparency = 1 }, nil)

	if properties ~= nil then
		for key, value in properties do
			(frame :: any)[key] = value
		end
	end

	local inside = slicedImage(frame, "Inside", INSIDE_IMAGE, frame.ZIndex)
	inside.ImageColor3 = UiKit.Colors.Deep

	local outline = slicedImage(frame, "Outline", OUTLINE_IMAGE, frame.ZIndex + 2)

	local inset = math.round(SLICE_BORDER * SLICE_SCALE)
	local content: Frame = UiKit.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		ZIndex = frame.ZIndex + 1,
	}, frame)

	frame.Parent = parent

	return NeonPanel.bind(frame, content, outline, inside)
end

-- Animates an authored outline and inside, such as a HUD panel built in Studio.
function NeonPanel.bind(frame: GuiObject, content: GuiObject, outline: ImageLabel, inside: ImageLabel): NeonPanel
	outline.ImageTransparency = IDLE_OUTLINE_TRANSPARENCY

	local gradient = outline:FindFirstChildOfClass("UIGradient")

	if gradient == nil then
		gradient = UiKit.create("UIGradient", { Color = OUTLINE_COLORS }, outline)
	end

	local fields: Fields = {
		frame = frame,
		content = content,
		outline = outline,
		inside = inside,
		gradient = gradient :: UIGradient,
		insideColor = inside.ImageColor3,
		tweens = TweenSlots.new(),
	}

	return setmetatable(fields, NeonPanel)
end

function NeonPanel.onBeat(self: NeonPanel, phase: number, beatIndex: number)
	local glow = (1 - phase) ^ 3

	self.gradient.Rotation = ((beatIndex + phase) * SPIN_DEGREES_PER_BEAT) % 360
	self.outline.ImageTransparency = IDLE_OUTLINE_TRANSPARENCY * (1 - glow)
	self.inside.ImageTransparency = BEAT_INSIDE_LIFT * glow
end

function NeonPanel.flash(self: NeonPanel, color: Color3)
	self.inside.ImageColor3 = self.insideColor:Lerp(color, 0.6)
	self.tweens:play(self.inside, FLASH_INFO, { ImageColor3 = self.insideColor })
end

function NeonPanel.destroy(self: NeonPanel)
	self.tweens:cancelAll()
	self.frame:Destroy()
end

return NeonPanel
