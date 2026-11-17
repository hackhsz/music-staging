--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local CardGrid = require(script.Parent.Parent.CardGrid)
local MenuScreen = require(script.Parent.MenuScreen)
local TryOnPreview = require(script.Parent.Parent.TryOnPreview)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

local WINDOW = "wardrobe"
local DIMMED = 0.45
-- A styled (Pill) tab or button shows it is picked, or is the thing to press, with this tag.
local PICKED_TAG = "Primary"
local EMPTY_NAME = "NOTHING HERE YET"
local EMPTY_STATE = "GET ITEMS IN THE SHOP OR FROM QUESTS"

export type Item = {
	kind: string,
	id: string,
	displayName: string,
	glyph: string?,
	icon: string?,
	rarity: string?,
	category: string,
	equipped: boolean,
}

type Tab = { button: GuiButton, label: TextLabel?, id: string, categories: { string }? }

type Fields = {
	menu: MenuScreen.MenuScreen,
	tabs: { Tab },
	tabImage: string?,
	pickedTabImage: string?,
	grid: CardGrid.CardGrid,
	tryOn: TryOnPreview.TryOnPreview,
	preview: ViewportFrame?,
	detailIcon: GuiObject?,
	detailGlyph: TextLabel?,
	detailName: TextLabel?,
	detailTag: TextLabel?,
	detailState: TextLabel?,
	equipButton: GuiButton?,
	equipLabel: TextLabel?,
	items: { Item },
	shown: { Item },
	tab: number,
	picked: number,
	onEquip: ((item: Item) -> ())?,
	onShop: (() -> ())?,
}

-- The Wardrobe window, authored in StarterGui.Menu's Wardrobe: tabs per kind of
-- item (WardrobeTabs), the owned items as cards, and the picked one tried on the
-- avatar with EQUIP or UNEQUIP. With nothing owned the button sends the player to
-- the shop. WardrobeController sends the change.
local WardrobePanel = {}
WardrobePanel.__index = WardrobePanel

export type WardrobePanel = typeof(setmetatable({} :: Fields, WardrobePanel))

local function paintTag(button: GuiObject, on: boolean)
	if on then
		CollectionService:AddTag(button, PICKED_TAG)
	else
		CollectionService:RemoveTag(button, PICKED_TAG)
	end
end

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

function WardrobePanel.new(menu: MenuScreen.MenuScreen): WardrobePanel
	local window = menu:window(WINDOW)
	local tabsFrame = UiKit.authored(window, "Tabs", "GuiObject")
	local page = UiKit.authored(window, "Page", "GuiObject")
	local list = UiKit.authored(page, "Grid.List", "ScrollingFrame")

	local fields: Fields = {
		menu = menu,
		tabs = {},
		tabImage = attribute(tabsFrame, "TabImage"),
		pickedTabImage = attribute(tabsFrame, "PickedTabImage"),
		grid = CardGrid.new(list, UiKit.authored(list, "RowTemplate", "GuiObject")),
		tryOn = TryOnPreview.new(
			UiKit.authored(page, "Preview", "ViewportFrame"),
			UiKit.authored(page, "Preview.WorldModel", "WorldModel")
		),
		preview = UiKit.authored(page, "Preview", "ViewportFrame"),
		detailIcon = UiKit.authored(page, "DetailIcon", "GuiObject"),
		detailGlyph = UiKit.authored(page, "DetailIcon.Glyph", "TextLabel"),
		detailName = UiKit.authored(page, "DetailName", "TextLabel"),
		detailTag = UiKit.authored(page, "DetailTag", "TextLabel"),
		detailState = UiKit.authored(page, "DetailState", "TextLabel"),
		equipButton = UiKit.authored(page, "EquipButton", "GuiButton"),
		equipLabel = UiKit.authored(page, "EquipButton.EquipLabel", "TextLabel"),
		items = {},
		shown = {},
		tab = 1,
		picked = 1,
		onEquip = nil,
		onShop = nil,
	}
	local self = setmetatable(fields, WardrobePanel)

	for index, info in CosmeticsCatalog.WardrobeTabs do
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")

		if button ~= nil then
			local label = UiKit.child(button, "TabLabel", "TextLabel")

			if label ~= nil then
				label.Text = string.upper(info.name)
			end

			table.insert(fields.tabs, { button = button, label = label, id = info.id, categories = info.categories })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.tab = index
				self.picked = 1
				self:_draw()
			end)
		end
	end

	local equip = fields.equipButton

	if equip ~= nil then
		UiKit.bindHover(equip)
		equip.Activated:Connect(function()
			local item = self.shown[self.picked]

			if item ~= nil and self.onEquip ~= nil then
				self.onEquip(item)
			elseif item == nil and self.onShop ~= nil then
				self.onShop()
			end
		end)
	end

	local close = UiKit.authored(window, "CloseButton", "GuiButton")

	if close ~= nil then
		UiKit.bindHover(close)
		close.Activated:Connect(function()
			menu:close(WINDOW)
		end)
	end

	if window ~= nil then
		window:GetPropertyChangedSignal("Visible"):Connect(function()
			fields.tryOn:setSpinning(window.Visible)
		end)
	end

	return self
end

function WardrobePanel.isVisible(self: WardrobePanel): boolean
	return self.menu:isOpen(WINDOW)
end

function WardrobePanel.setVisible(self: WardrobePanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

-- Tapping the button with an empty tab; the controller opens the shop.
function WardrobePanel.bindShop(self: WardrobePanel, callback: () -> ())
	self.onShop = callback
end

function WardrobePanel.bindEquip(self: WardrobePanel, callback: (item: Item) -> ())
	self.onEquip = callback
end

function WardrobePanel.setPreviewSource(self: WardrobePanel, source: Model?)
	self.tryOn:setSource(source)
end

function WardrobePanel.render(self: WardrobePanel, items: { Item })
	local pickedId = if self.shown[self.picked] ~= nil then self.shown[self.picked].id else nil

	self.items = items
	self:_draw(pickedId)
end

function WardrobePanel._draw(self: WardrobePanel, keepId: string?)
	local tab = self.tabs[self.tab]

	for index, entry in self.tabs do
		local image = if index == self.tab then self.pickedTabImage else self.tabImage

		if image ~= nil and entry.button:IsA("ImageButton") then
			UiKit.setImage(entry.button, image)
		else
			paintTag(entry.button, index == self.tab)
		end
	end

	local shown: { Item } = {}

	for _, item in self.items do
		if tab == nil or tab.categories == nil or table.find(tab.categories, item.category) ~= nil then
			table.insert(shown, item)
		end
	end

	self.shown = shown

	for index, item in shown do
		if item.id == keepId then
			self.picked = index
		end
	end

	self.picked = math.clamp(self.picked, 1, math.max(#shown, 1))

	self.grid:build(#shown, function(card: GuiButton, index: number)
		local item = shown[index]
		local name = UiKit.child(card, "NameLabel", "TextLabel")
		local tag = UiKit.child(card, "TagLabel", "TextLabel")
		local check = UiKit.child(card, "Check", "GuiObject")
		local star = UiKit.child(card, "Star", "ImageLabel")
		local rarity = if item.rarity ~= nil then CosmeticsCatalog.Rarities[item.rarity] else nil

		UiKit.setIcon(UiKit.child(card:FindFirstChild("Icon"), "Glyph", "TextLabel"), item.glyph, item.icon)

		if name ~= nil then
			name.Text = item.displayName
		end

		if tag ~= nil then
			tag.Text = if item.equipped then "EQUIPPED" elseif rarity ~= nil then string.upper(rarity.displayName) else ""
			tag.TextColor3 = if item.equipped then Colors.Green elseif rarity ~= nil then rarity.color else Colors.White

			local tint = tag:FindFirstChildOfClass("UIGradient")

			if tint ~= nil then
				tint.Enabled = false
			end
		end

		if check ~= nil then
			check.Visible = item.equipped
		end

		if star ~= nil then
			star.Visible = item.rarity == "epic" or item.rarity == "legendary"
			star.ImageColor3 = if rarity ~= nil then rarity.color else Colors.White
		end

		card.Activated:Connect(function()
			self.picked = index
			self:_drawDetail()
		end)
	end)

	self:_drawDetail()
end

function WardrobePanel._drawDetail(self: WardrobePanel)
	local item = self.shown[self.picked]
	local rarity = if item ~= nil and item.rarity ~= nil then CosmeticsCatalog.Rarities[item.rarity] else nil
	local previewing = self.tryOn:show(item, item ~= nil and not item.equipped)

	self.grid:paintPicked(self.picked)

	if self.preview ~= nil then
		self.preview.Visible = previewing
	end

	if self.detailIcon ~= nil then
		self.detailIcon.Visible = not previewing
	end

	UiKit.setIcon(self.detailGlyph, if item ~= nil then item.glyph else "🛍️", if item ~= nil then item.icon else nil)

	if self.detailName ~= nil then
		self.detailName.Text = if item ~= nil then item.displayName else EMPTY_NAME
	end

	if self.detailTag ~= nil then
		local kind = if item ~= nil then string.upper(CosmeticsCatalog.categoryName(item.category)) else ""

		self.detailTag.Text = if rarity ~= nil then string.upper(rarity.displayName) .. " " .. kind else kind
		self.detailTag.TextColor3 = if rarity ~= nil then rarity.color else Colors.Pink
	end

	if self.detailState ~= nil then
		self.detailState.Text = if item == nil then EMPTY_STATE elseif item.equipped then "WEARING IT" else "TRY IT ON, THEN EQUIP"
	end

	if self.equipLabel ~= nil then
		self.equipLabel.Text = if item == nil then "SHOP" elseif item.equipped then "UNEQUIP" else "EQUIP"
	end

	local button = self.equipButton

	if button ~= nil and button:IsA("ImageButton") then
		button.ImageTransparency = if item == nil and self.onShop == nil then DIMMED else 0
	elseif button ~= nil then
		paintTag(button, item == nil or not item.equipped)
	end
end

return WardrobePanel
