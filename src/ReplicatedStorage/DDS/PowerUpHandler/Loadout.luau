local KIND_PICKUP = "Pickup"
local TIMING_KEYS = { "PERFECT_LAND_MS", "GREAT_LAND_MS" }

local Config = require(script.Parent.Parent.Config)

local Loadout = {}
Loadout.__index = Loadout

function Loadout.new(definitions)
	local self = setmetatable({}, Loadout)
	self.definitions = definitions
	self.states = {}
	self.assists = {}
	self.baseConfig = Config
	self.coinMultiplier = 1
	self.xpMultiplier = 1

	local helperMultiplier = 1
	local challengeXpMultiplier = 1
	local hasHelper = false
	local overrides = {}
	for _, definition in definitions do
		local state = { id = definition.Id }
		if definition.Init then
			definition.Init(state)
		end
		self.states[definition.Id] = state
		if definition.Kind ~= KIND_PICKUP then
			local multiplier = definition.ScoreMultiplier or 1
			if multiplier < 1 then
				helperMultiplier *= multiplier
				hasHelper = true
			end
			self.coinMultiplier *= definition.CoinMultiplier or 1
			if definition.Kind == "Mod" then
				challengeXpMultiplier *= definition.XpMultiplier or 1
			else
				self.xpMultiplier *= definition.XpMultiplier or 1
			end
		end
		for key, value in definition.ConfigOverrides or {} do
			overrides[key] = value
			if table.find(TIMING_KEYS, key) and not self.timingAssistId then
				self.timingAssistId = definition.Id
			end
		end
	end
	self.assisted = hasHelper
	self.scoreMultiplier = helperMultiplier
	if not hasHelper then
		self.xpMultiplier *= challengeXpMultiplier
	end
	self.config = setmetatable(overrides, { __index = Config })
	return self
end

function Loadout:firstResult(hookName: string, ...)
	for _, definition in self.definitions do
		local hook = definition[hookName]
		if hook then
			local result = hook(self.states[definition.Id], ...)
			if result ~= nil and result ~= false then
				return result
			end
		end
	end
	return nil
end

function Loadout:TransformTier(controller, tier: string, event): string
	for _, definition in self.definitions do
		if definition.TransformTier then
			tier = definition.TransformTier(self.states[definition.Id], controller, tier, event)
		end
	end
	return tier
end

function Loadout:GetScoreBoost(controller): number
	local boost = 1
	for _, definition in self.definitions do
		if definition.ScoreBoost then
			boost *= definition.ScoreBoost(self.states[definition.Id], controller) or 1
		end
	end
	return boost
end

function Loadout:AbsorbMiss(controller, event): string?
	return self:firstResult("AbsorbMiss", controller, event)
end

function Loadout:HandleHypeFull(controller): boolean
	return self:firstResult("OnHypeFull", controller) ~= nil
end

function Loadout:IsAbilityReady(controller): boolean
	return self:firstResult("AbilityReady", controller) ~= nil
end

function Loadout:UseAbility(controller): string?
	return self:firstResult("OnAbility", controller)
end

function Loadout:Collect(controller, event, tier: string): string?
	for _, definition in self.definitions do
		if definition.Kind == KIND_PICKUP and definition.Id == event.item and definition.OnCollect then
			return definition.OnCollect(self.states[definition.Id], controller, event, tier)
		end
	end
	warn("[Loadout] no pickup definition for item '" .. tostring(event.item) .. "'")
	return nil
end

function Loadout:GetIds(): { string }
	local ids = {}
	for _, definition in self.definitions do
		if definition.Kind ~= KIND_PICKUP then
			table.insert(ids, definition.Id)
		end
	end
	return ids
end

function Loadout:RecordAssist(id: string, points: number)
	local record = self.assists[id]
	if not record then
		record = { count = 0, points = 0 }
		self.assists[id] = record
	end
	record.count += 1
	record.points += points
end

function Loadout:GetAssistSummary(): string
	local parts = {}
	for id, record in self.assists do
		table.insert(parts, string.format("%s x%d (+%d)", id, record.count, record.points))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function Loadout:GetStatusText(controller): string
	local parts = {}
	for _, definition in self.definitions do
		if definition.StatusText then
			local text = definition.StatusText(self.states[definition.Id], controller)
			if text then
				table.insert(parts, text)
			end
		end
	end
	return table.concat(parts, "   ")
end

return Loadout
