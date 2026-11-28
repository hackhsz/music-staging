local KIND_CONSUMABLE = "Consumable"
local KIND_MOD = "Mod"
local KIND_PICKUP = "Pickup"
local DISABLED_PREFIX = "_"
local HELPER_SCORE_MIN = 0.8
local HELPER_SCORE_MAX = 0.9

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Signal = require(ReplicatedStorage.Shared.Utility.Signal)
local Loadout = require(script.Loadout)

local PowerUpHandler = {}
PowerUpHandler.Loadout = Loadout
PowerUpHandler.HELPER_SCORE_MIN = HELPER_SCORE_MIN
PowerUpHandler.HELPER_SCORE_MAX = HELPER_SCORE_MAX
PowerUpHandler.Changed = Signal.new()
PowerUpHandler.Consumed = Signal.new()

local definitions = {}
local definitionOrder = {}
local selected: { [string]: boolean } = {}
local isSetup = false

local function rejectReason(definition): string?
	local kind = definition.Kind
	local multiplier = definition.ScoreMultiplier or 1
	if kind ~= KIND_CONSUMABLE and kind ~= KIND_MOD and kind ~= KIND_PICKUP then
		return "unknown Kind '" .. tostring(kind) .. "'"
	end
	if multiplier > 1 then
		return "nothing may grant score; accuracy is the score (Timing rule 1)"
	end
	if kind == KIND_CONSUMABLE and definition.Helper ~= false and (multiplier < HELPER_SCORE_MIN or multiplier > HELPER_SCORE_MAX) then
		return string.format("helper consumables must score x%.2f-x%.2f (Scoring & Grades rule 3)", HELPER_SCORE_MIN, HELPER_SCORE_MAX)
	end
	if kind == KIND_MOD and multiplier < 1 then
		return "mods are free, so they cannot help; make it a Consumable"
	end
	return nil
end

local function registerDefinition(module: ModuleScript)
	if string.sub(module.Name, 1, 1) == DISABLED_PREFIX then
		return
	end
	if definitions[module.Name] then
		warn("[PowerUpHandler] duplicate power-up " .. module:GetFullName())
		return
	end
	local ok, definition = pcall(require, module)
	if not ok or type(definition) ~= "table" then
		warn("[PowerUpHandler] failed to load " .. module:GetFullName() .. ": " .. tostring(definition))
		return
	end
	local reason = rejectReason(definition)
	if reason then
		warn("[PowerUpHandler] rejected " .. module:GetFullName() .. ": " .. reason)
		return
	end
	definition.Id = module.Name
	definitions[module.Name] = definition
	table.insert(definitionOrder, definition)
end

function PowerUpHandler:Setup()
	if isSetup then
		return
	end
	isSetup = true
	for _, module in script.PowerUps:GetChildren() do
		if module:IsA("ModuleScript") then
			registerDefinition(module)
		end
	end
	table.sort(definitionOrder, function(a, b)
		return (a.Order or 0) < (b.Order or 0)
	end)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal(Config.ITEM_SLOTS_ATTRIBUTE):Connect(function()
			self.Changed:Fire()
		end)
	end
end

function PowerUpHandler:GetDefinition(id: string)
	return definitions[id]
end

function PowerUpHandler:GetSelectable()
	local selectable = {}
	for _, definition in definitionOrder do
		if definition.Kind ~= KIND_PICKUP then
			table.insert(selectable, definition)
		end
	end
	return selectable
end

function PowerUpHandler:GetSlotCount(): number
	local player = Players.LocalPlayer
	local slots = player and player:GetAttribute(Config.ITEM_SLOTS_ATTRIBUTE)
	if typeof(slots) ~= "number" then
		slots = Config.ITEM_SLOTS_DEFAULT
	end
	return math.clamp(math.floor(slots), 0, Config.ITEM_SLOTS_MAX)
end

function PowerUpHandler:IsSelected(id: string): boolean
	return selected[id] == true
end

function PowerUpHandler:GetSelectedIds(): { string }
	local ids = {}
	for _, definition in definitionOrder do
		if selected[definition.Id] then
			table.insert(ids, definition.Id)
		end
	end
	return ids
end

function PowerUpHandler:GetUsedSlots(): number
	local used = 0
	for id in selected do
		if definitions[id].Kind == KIND_CONSUMABLE then
			used += 1
		end
	end
	return used
end

local function conflicts(a, b): boolean
	return table.find(a.Conflicts or {}, b.Id) ~= nil or table.find(b.Conflicts or {}, a.Id) ~= nil
end

function PowerUpHandler:CanSelect(id: string): (boolean, string?)
	local definition = definitions[id]
	if not definition or definition.Kind == KIND_PICKUP then
		return false, "Not selectable"
	end
	for otherId in selected do
		local other = definitions[otherId]
		if conflicts(definition, other) then
			return false, "Can't combine with " .. other.DisplayName
		end
	end
	if definition.Kind == KIND_CONSUMABLE and self:GetSlotCount() == 0 then
		return false, "Item slots unlock at Lv4"
	end
	if definition.Kind == KIND_CONSUMABLE and self:GetUsedSlots() >= self:GetSlotCount() then
		return false, "All item slots are full"
	end
	return true, nil
end

function PowerUpHandler:SetSelected(id: string, isSelected: boolean): (boolean, string?)
	if not isSelected then
		if selected[id] then
			selected[id] = nil
			self.Changed:Fire()
		end
		return true, nil
	end
	if selected[id] then
		return true, nil
	end
	local ok, reason = self:CanSelect(id)
	if not ok then
		return false, reason
	end
	selected[id] = true
	self.Changed:Fire()
	return true, nil
end

function PowerUpHandler:CreateLoadout(options: { gradeCourse: boolean? }?)
	local gradeCourse = options ~= nil and options.gradeCourse == true
	local chosen = {}
	local consumed = {}
	local slotsLeft = self:GetSlotCount()
	for _, definition in definitionOrder do
		if definition.Kind == KIND_PICKUP then
			table.insert(chosen, definition)
		elseif selected[definition.Id] then
			if definition.Kind == KIND_MOD then
				table.insert(chosen, definition)
			elseif not gradeCourse and slotsLeft > 0 then
				slotsLeft -= 1
				table.insert(chosen, definition)
				table.insert(consumed, definition.Id)
			end
		end
	end
	if #consumed > 0 then
		self.Consumed:Fire(consumed)
	end
	return Loadout.new(chosen)
end

function PowerUpHandler:PreviewLoadout()
	local chosen = {}
	for _, definition in definitionOrder do
		if selected[definition.Id] then
			table.insert(chosen, definition)
		end
	end
	return Loadout.new(chosen)
end

return PowerUpHandler
