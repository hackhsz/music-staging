--!strict
local RAINBOW_SPEED = 0.6

export type TextStyle = { top: Color3, bottom: Color3, stroke: Color3 }
-- Highest threshold first; a tier with no style is the rainbow.
export type Tier = { at: number, style: TextStyle? }

local TextStyles = {}

-- The highway's grade palette; results ranks wear the same colours.
TextStyles.Grades = {
	Perfect = { top = Color3.fromRGB(235, 246, 132), bottom = Color3.fromRGB(233, 253, 48), stroke = Color3.fromRGB(110, 30, 120) },
	Great = { top = Color3.fromRGB(190, 255, 170), bottom = Color3.fromRGB(40, 210, 100), stroke = Color3.fromRGB(10, 70, 50) },
	Good = { top = Color3.fromRGB(180, 240, 255), bottom = Color3.fromRGB(50, 150, 255), stroke = Color3.fromRGB(14, 36, 100) },
	Bad = { top = Color3.fromRGB(225, 205, 255), bottom = Color3.fromRGB(140, 110, 200), stroke = Color3.fromRGB(40, 28, 70) },
	Miss = { top = Color3.fromRGB(255, 150, 160), bottom = Color3.fromRGB(225, 40, 60), stroke = Color3.fromRGB(70, 0, 20) },
} :: { [string]: TextStyle }

function TextStyles.tierFor(tiers: { Tier }, combo: number): number
	for index, tier in tiers do
		if combo >= tier.at then
			return index
		end
	end

	return #tiers
end

function TextStyles.rainbow(now: number): TextStyle
	local hue = (now * RAINBOW_SPEED) % 1

	return {
		top = Color3.fromHSV(hue, 0.45, 1),
		bottom = Color3.fromHSV((hue + 0.15) % 1, 0.9, 1),
		stroke = Color3.fromHSV(hue, 0.9, 0.35),
	}
end

return TextStyles
