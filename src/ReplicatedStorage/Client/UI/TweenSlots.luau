--!strict
local TweenService = game:GetService("TweenService")

-- One running tween per key; the key is the target unless two tweens on one
-- instance must not cancel each other.
local TweenSlots = {}
TweenSlots.__index = TweenSlots

type Fields = {
	tweens: { [any]: Tween },
}

export type TweenSlots = typeof(setmetatable({} :: Fields, TweenSlots))

function TweenSlots.new(): TweenSlots
	local fields: Fields = { tweens = {} }

	return setmetatable(fields, TweenSlots)
end

function TweenSlots.play(self: TweenSlots, target: Instance, info: TweenInfo, goal: { [string]: any }, key: any?): Tween
	local slot = if key ~= nil then key else target
	self:stop(slot)

	local tween = TweenService:Create(target, info, goal)
	self.tweens[slot] = tween
	tween:Play()

	return tween
end

function TweenSlots.stop(self: TweenSlots, key: any)
	local running: Tween? = self.tweens[key]

	if running ~= nil then
		running:Cancel()
		self.tweens[key] = nil
	end
end

function TweenSlots.cancelAll(self: TweenSlots)
	for _, tween in self.tweens do
		tween:Cancel()
	end

	table.clear(self.tweens)
end

return TweenSlots
