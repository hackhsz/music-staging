--!strict
local UiKit = require(script.Parent.UiKit)

-- A beat lands like a heart: a strong beat and a softer echo just after.
local HEART_DECAY_BEATS = 0.16
local HEART_ECHO_BEATS = 0.22
local HEART_ECHO = 0.55
local EFFECT_SCALE_NAME = "Beat"

export type FadePart = { instance: any, property: string, rest: number }
export type Fade = { root: GuiObject, parts: { FadePart }, alpha: number }
export type Effect = { fade: Fade, scale: UIScale, sheet: ImageLabel? }

local FADE_PROPERTIES: { { class: string, property: string } } = {
	{ class = "GuiObject", property = "BackgroundTransparency" },
	{ class = "ImageLabel", property = "ImageTransparency" },
	{ class = "TextLabel", property = "TextTransparency" },
	{ class = "UIStroke", property = "Transparency" },
	{ class = "UIShadow", property = "Transparency" },
}

-- Small pieces the HUD animates with. Effects are placeholders a designer fills
-- with any art: the code only fades, scales and steps them.
local HudFx = {}

-- 0 to 1 over seconds since at; 1 when at is -math.huge.
function HudFx.since(at: number, seconds: number): number
	return math.clamp((os.clock() - at) / seconds, 0, 1)
end

-- 1 on the beat, falling away, with a smaller echo; phase is 0 to 1 through the beat.
function HudFx.heartbeat(phase: number): number
	local strong = math.max(1 - phase / HEART_DECAY_BEATS, 0) ^ 2
	local sinceEcho = phase - HEART_ECHO_BEATS
	local echo = if sinceEcho >= 0 then math.max(1 - sinceEcho / HEART_DECAY_BEATS, 0) ^ 2 else 0

	return math.max(strong, HEART_ECHO * echo)
end

-- Remembers each part's authored transparency, so alpha 1 is the art as drawn.
function HudFx.fadeOf(root: Instance?): Fade?
	if root == nil or not root:IsA("GuiObject") then
		return nil
	end

	local parts: { FadePart } = {}
	local all = root:GetDescendants()
	table.insert(all, root)

	for _, instance in all do
		for _, entry in FADE_PROPERTIES do
			if instance:IsA(entry.class) then
				table.insert(parts, { instance = instance, property = entry.property, rest = (instance :: any)[entry.property] })
			end
		end
	end

	return { root = root, parts = parts, alpha = -1 }
end

function HudFx.setFade(fade: Fade?, alpha: number)
	if fade == nil or fade.alpha == alpha then
		return
	end

	fade.alpha = alpha
	fade.root.Visible = alpha > 0

	for _, part in fade.parts do
		part.instance[part.property] = 1 - (1 - part.rest) * alpha
	end
end

-- A sprite sheet in an effect is an ImageLabel whose Columns and Frames
-- attributes describe its grid, so the art can be swapped in Studio.
local function sheetOf(root: Instance): ImageLabel?
	for _, instance in root:GetDescendants() do
		if instance:IsA("ImageLabel") and type(instance:GetAttribute("Frames")) == "number" then
			return instance
		end
	end

	return nil
end

function HudFx.effectOf(root: Instance?): Effect?
	local fade = HudFx.fadeOf(root)

	if fade == nil then
		return nil
	end

	return { fade = fade, scale = UiKit.scaleOf(fade.root, EFFECT_SCALE_NAME), sheet = sheetOf(fade.root) }
end

-- Shows the sheet's frame for progress, 0 to 1 through the animation.
function HudFx.showFrame(effect: Effect, progress: number)
	local sheet = effect.sheet

	if sheet == nil then
		return
	end

	local frames = sheet:GetAttribute("Frames") :: number
	local columns = (sheet:GetAttribute("Columns") :: number?) or frames
	local index = math.clamp(math.floor(progress * frames), 0, frames - 1)
	sheet.ImageRectOffset = Vector2.new(index % columns, index // columns) * sheet.ImageRectSize
end

return HudFx
