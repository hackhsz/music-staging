--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Animation packs are authored in Studio, not here: each Folder under
-- ReplicatedStorage.AnimationPacks is one pack, its Animations named by slot.
-- See docs/SELLING_ANIMATIONS.md for how to add one.
local FOLDER_NAME = "AnimationPacks"
local ID_PREFIX = "animpack-"
local DEFAULT_GLYPH = "🕺"
local DEFAULT_RARITY = "common"

export type Pack = {
	id: string,
	displayName: string,
	animations: { [string]: string },
	order: number,
}

local AnimationPacks = {}

AnimationPacks.Category = "animation_pack"
AnimationPacks.PlayerAttribute = "AnimationPack"

-- Slot name -> the child of the character's Animate script it replaces.
AnimationPacks.MovementSlots = {
	Idle = "idle",
	Walk = "walk",
	Run = "run",
	Jump = "jump",
	Fall = "fall",
	Climb = "climb",
	Swim = "swim",
	SwimIdle = "swimidle",
}

-- Run slots: Dance, Fever, Cheer and Victory replace an EmoteCatalog emote (its
-- packSlot); the rest play on the pad's steps, spins and combo milestones.
AnimationPacks.DanceSlots = {
	Dance = true,
	Fever = true,
	Cheer = true,
	Victory = true,
	RoundIdle = true,
	StepUp = true,
	StepDown = true,
	StepLeft = true,
	StepRight = true,
	Spin = true,
	SpinKick = true,
}

local packs: { Pack } = {}
local byId: { [string]: Pack } = {}

local function readPack(folder: Instance): Pack?
	if not folder:IsA("Folder") then
		return nil
	end

	local animations = {}

	for _, child in folder:GetChildren() do
		local known = AnimationPacks.MovementSlots[child.Name] ~= nil or AnimationPacks.DanceSlots[child.Name] ~= nil

		if not child:IsA("Animation") or not known then
			warn(("[DanceDanceStep] AnimationPacks.%s.%s is not a slot Animation; skipped"):format(folder.Name, child.Name))
			continue
		end

		if child.AnimationId ~= "" then
			animations[child.Name] = child.AnimationId
		end
	end

	if next(animations) == nil then
		warn(("[DanceDanceStep] AnimationPacks.%s has no animations; skipped"):format(folder.Name))
		return nil
	end

	local displayName = folder:GetAttribute("DisplayName")
	local order = folder:GetAttribute("Order")

	return {
		id = ID_PREFIX .. folder.Name,
		displayName = if type(displayName) == "string" then displayName else folder.Name,
		animations = animations,
		order = if type(order) == "number" then order else math.huge,
	}
end

local function toItem(folder: Instance, pack: Pack): { [string]: any }
	local price = folder:GetAttribute("Price")
	local rarity = folder:GetAttribute("Rarity")
	local glyph = folder:GetAttribute("Glyph")
	local icon = folder:GetAttribute("Icon")
	local forSale = type(price) == "number" and price >= 0

	return {
		id = pack.id,
		rarity = if type(rarity) == "string" then string.lower(rarity) else DEFAULT_RARITY,
		glyph = if type(glyph) == "string" then glyph else DEFAULT_GLYPH,
		icon = if type(icon) == "string" and icon ~= "" then icon else nil,
		category = AnimationPacks.Category,
		displayName = pack.displayName,
		unlock = if forSale then "soft_currency" else "coming_soon",
		price = if forSale then price else nil,
		requirementText = if not forSale
			then "COMING SOON"
			elseif price == 0 then "FREE"
			else ("%d BEAT COINS"):format(price :: number),
	}
end

local items: { { [string]: any } } = {}

-- The client must not read the folder before the place's initial replication.
if RunService:IsClient() and not game:IsLoaded() then
	game.Loaded:Wait()
end

local root = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
local entries = {}

for _, folder in if root ~= nil then root:GetChildren() else {} do
	local pack = readPack(folder)

	if pack ~= nil then
		table.insert(entries, { folder = folder, pack = pack })
	end
end

table.sort(entries, function(a, b)
	if a.pack.order ~= b.pack.order then
		return a.pack.order < b.pack.order
	end

	return a.pack.id < b.pack.id
end)

for _, entry in entries do
	table.insert(packs, entry.pack)
	byId[entry.pack.id] = entry.pack
	table.insert(items, toItem(entry.folder, entry.pack))
end

AnimationPacks.Packs = packs
-- Cosmetic catalog rows, one per pack, in shop order.
AnimationPacks.Items = items

function AnimationPacks.get(packId: string?): Pack?
	return if packId ~= nil then byId[packId] else nil
end

function AnimationPacks.ids(): { string }
	local ids = {}

	for _, pack in packs do
		table.insert(ids, pack.id)
	end

	return ids
end

-- The pack's animation for a slot on this player, or nil to keep the default.
function AnimationPacks.animationFor(player: Player?, slot: string?): string?
	if slot == nil then
		return nil
	end

	local target = player or Players.LocalPlayer

	if target == nil then
		return nil
	end

	local packId = target:GetAttribute(AnimationPacks.PlayerAttribute)
	local pack = AnimationPacks.get(if type(packId) == "string" then packId else nil)

	return if pack ~= nil then pack.animations[slot] else nil
end

-- An EmoteCatalog emote's animation id, swapped for the equipped pack's when it has that slot.
function AnimationPacks.emoteAnimationId(player: Player?, emote: { [string]: any }): string?
	local override = AnimationPacks.animationFor(player, emote.packSlot)

	if override ~= nil then
		return override
	end

	return if emote.animationId ~= nil then ("rbxassetid://%d"):format(emote.animationId) else nil
end

return AnimationPacks
