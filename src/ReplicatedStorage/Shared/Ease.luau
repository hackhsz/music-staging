--!strict
local Ease = {}

function Ease.outQuad(t: number): number
	return 1 - (1 - t) ^ 2
end

-- A punch that starts at 1 and dies away over its length, for beat bops and pops.
function Ease.decay(elapsed: number, length: number): number
	return (1 - math.clamp(elapsed / length, 0, 1)) ^ 2
end

function Ease.smoothstep(t: number): number
	local clamped = math.clamp(t, 0, 1)

	return clamped * clamped * (3 - 2 * clamped)
end

return Ease
