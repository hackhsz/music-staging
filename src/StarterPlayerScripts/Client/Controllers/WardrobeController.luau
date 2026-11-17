--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local WardrobePanel = require(script.Parent.Parent.UI.Screens.WardrobePanel)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	-- Opens the shop when the player has nothing to wear yet.
	openShop: () -> (),
}

type Fields = {
	deps: Deps,
	items: { WardrobePanel.Item },
}

-- The Wardrobe window: what the player owns, from the profile the server pushes,
-- and the equip and unequip requests. The server checks ownership and dresses the
-- avatar; this only asks.
local WardrobeController = {}
WardrobeController.__index = WardrobeController

export type WardrobeController = typeof(setmetatable({} :: Fields, WardrobeController))

function WardrobeController.new(deps: Deps): WardrobeController
	return setmetatable({ deps = deps, items = {} } :: Fields, WardrobeController)
end

function WardrobeController.start(self: WardrobeController)
	local deps = self.deps
	local wardrobe = deps.hud.wardrobe

	deps.hud.menu:bindWardrobe(function()
		if wardrobe:isVisible() then
			wardrobe:setVisible(false)
		else
			self:open()
		end
	end)
	wardrobe:bindEquip(function(item: WardrobePanel.Item)
		if item.equipped then
			deps.remotes.UnequipCosmetic:FireServer({ category = item.category })
		else
			deps.remotes.EquipCosmetic:FireServer({ cosmeticId = item.id })
		end

		Telemetry.track(if item.equipped then "cosmetic_unequip_requested" else "cosmetic_equip_requested", item.id)
	end)
	wardrobe:bindShop(function()
		deps.openShop()
	end)
	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		self:_onProfile(payload)
	end)
end

function WardrobeController.open(self: WardrobeController)
	local wardrobe = self.deps.hud.wardrobe

	wardrobe:setPreviewSource(Players.LocalPlayer.Character)
	wardrobe:render(self.items)
	wardrobe:setVisible(true)
end

function WardrobeController._onProfile(self: WardrobeController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local owned = if type(payload.cosmetics) == "table" then payload.cosmetics else {}
	local equipped = if type(payload.equipped) == "table" then payload.equipped else {}
	local items: { WardrobePanel.Item } = {}

	for _, item in CosmeticsCatalog.Items do
		if owned[item.id] == true then
			table.insert(items, {
				kind = "cosmetic",
				id = item.id,
				displayName = string.upper(item.displayName),
				glyph = item.glyph,
				icon = item.icon,
				rarity = item.rarity,
				category = item.category,
				equipped = equipped[item.category] == item.id,
			})
		end
	end

	self.items = items

	if self.deps.hud.wardrobe:isVisible() then
		self.deps.hud.wardrobe:render(items)
	end
end

return WardrobeController
