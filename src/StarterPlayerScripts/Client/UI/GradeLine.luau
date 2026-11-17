--!strict
local HudFx = require(script.Parent.HudFx)
local TextStyles = require(script.Parent.TextStyles)

local DETAIL_SIZE = 0.62
-- Roblox caps TextSize here.
local MAX_TEXT_SIZE = 100
local CHROME_SILVER = Color3.fromRGB(230, 230, 230)
local CHROME_SHADE = 0.15

type TextStyle = TextStyles.TextStyle

export type GradeLine = {
	root: GuiObject,
	scale: UIScale,
	grade: TextLabel,
	detail: TextLabel,
	fade: HudFx.Fade,
	copies: { TextLabel },
	shine: { UIGradient },
	glows: { Instance },
	strokePerText: { [UIStroke]: number },
}

-- The grade call-out authored as GradeLine: a Grade in chrome, which can carry
-- styled copies of itself (a highlight outline drawn over it), gradients,
-- strokes and shadows that all follow it, and a smaller Detail beside it.
local GradeLine = {}

function GradeLine.bind(root: GuiObject, scale: UIScale, grade: TextLabel, detail: TextLabel): GradeLine
	local line: GradeLine = {
		root = root,
		scale = scale,
		grade = grade,
		detail = detail,
		fade = HudFx.fadeOf(root) :: HudFx.Fade,
		copies = {},
		shine = {},
		glows = {},
		strokePerText = {},
	}

	for _, instance in grade:GetDescendants() do
		if instance:IsA("TextLabel") then
			table.insert(line.copies, instance)
		elseif instance:IsA("UIGradient") then
			table.insert(line.shine, instance)
		elseif instance:IsA("UIShadow") then
			table.insert(line.glows, instance)
		end
	end

	-- Strokes keep the thickness they were authored with, relative to the text.
	for _, instance in root:GetDescendants() do
		local owner = instance.Parent

		if instance:IsA("UIStroke") and owner ~= nil and owner:IsA("TextLabel") and owner.TextSize > 0 then
			line.strokePerText[instance] = instance.Thickness / owner.TextSize
		end
	end

	return line
end

-- Sizes the text to the line's authored height, outlines included.
function GradeLine.fit(line: GradeLine)
	if line.scale.Scale < 0.05 then
		return
	end

	local height = line.root.AbsoluteSize.Y / line.scale.Scale

	if height <= 0 then
		return
	end

	local function fit(label: TextLabel, ratio: number)
		label.TextSize = math.min(math.floor(height * ratio + 0.5), MAX_TEXT_SIZE)

		for _, child in label:GetChildren() do
			local perText = if child:IsA("UIStroke") then line.strokePerText[child] else nil

			if perText ~= nil then
				(child :: UIStroke).Thickness = perText * label.TextSize
			end
		end
	end

	fit(line.grade, 1)
	fit(line.detail, DETAIL_SIZE)

	for _, copy in line.copies do
		fit(copy, 1)
	end
end

-- The authored height in pixels, whatever the pop scale is doing.
function GradeLine.height(line: GradeLine): number
	return line.root.AbsoluteSize.Y / math.max(line.scale.Scale, 0.05)
end

local function chrome(style: TextStyle): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, style.top),
		ColorSequenceKeypoint.new(0.19, style.top:Lerp(style.bottom, 0.5)),
		ColorSequenceKeypoint.new(0.37, style.bottom),
		ColorSequenceKeypoint.new(0.49, style.bottom:Lerp(Color3.new(), CHROME_SHADE)),
		ColorSequenceKeypoint.new(0.53, CHROME_SILVER),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
end

function GradeLine.set(line: GradeLine, text: string, detail: string?, style: TextStyle?)
	line.grade.Text = text

	for _, copy in line.copies do
		copy.Text = text
	end

	line.detail.Text = detail or ""
	line.detail.Visible = detail ~= nil and detail ~= ""

	if style == nil then
		return
	end

	local colors = chrome(style)

	for _, gradient in line.shine do
		gradient.Color = colors
	end

	for _, glow in line.glows do
		(glow :: any).Color = style.bottom
	end
end

-- Puts every part back to its authored transparency after a fade-out.
function GradeLine.restore(line: GradeLine, stop: (part: HudFx.FadePart) -> ())
	for _, part in line.fade.parts do
		stop(part)
		part.instance[part.property] = part.rest
	end
end

return GradeLine
