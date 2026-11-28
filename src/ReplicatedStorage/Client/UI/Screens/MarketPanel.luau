--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UGCCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("UGCCatalog"))
local CardGrid = require(script.Parent.Parent.CardGrid)
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "market"
local OFF_SALE_TEXT = "OFF SALE"
local SOON_TEXT = "COMING SOON"
local BUY_NOTE = "BOUGHT THROUGH ROBLOX - THE CREATOR GETS PAID"
local DIMMED = 0.45
local MY_ITEMS_TEXT = "MY ITEMS"
local BACK_TEXT = "BACK"
local SHOP_ONLY_TEXT = "SHOP ONLY"
local ON_STALL_TEXT = "ON STALL"

-- sellable is false for one of your own items whose sale location keeps it out of games.
export type Item = {
	name: string,
	glyph: string,
	icon: string?,
	assetId: number?,
	price: number?,
	forSale: boolean,
	sellable: boolean?,
}
-- owner is nil for a free stall; mine is the local player's own stall.
export type Stall = { id: string, name: string, owner: string?, mine: boolean, items: { Item } }
export type Actions = {
	buy: (assetId: number) -> (),
	claim: (stallId: string) -> (),
	remove: (assetId: number) -> (),
	add: (text: string) -> (),
	release: () -> (),
	browse: () -> (),
}

type Tab = { button: GuiButton, label: TextLabel? }
type Action = { label: string, run: (() -> ())? }

type Fields = {
	menu: MenuScreen.MenuScreen,
	tabs: { Tab },
	tabImage: string?,
	pickedTabImage: string?,
	grid: CardGrid.CardGrid,
	detailGlyph: TextLabel?,
	detailName: TextLabel?,
	detailTag: TextLabel?,
	detailState: TextLabel?,
	buyButton: GuiButton?,
	buyLabel: TextLabel?,
	statusLabel: TextLabel?,
	manageBar: GuiObject?,
	idBox: TextBox?,
	myItemsButton: TextButton?,
	browsing: boolean,
	creations: { Item },
	stalls: { Stall },
	open: boolean,
	hasStall: boolean,
	notice: string?,
	stall: number,
	picked: number,
	actions: Actions?,
}

-- The UGC Market window, authored in StarterGui.Menu's Market: a tab per stall, its
-- rack as cards, and one action button for the picked card. Your own stall adds the
-- ManageBar (id box, ADD, MY ITEMS, LEAVE); MY ITEMS swaps the rack for your
-- creations until BACK.
local MarketPanel = {}
MarketPanel.__index = MarketPanel

export type MarketPanel = typeof(setmetatable({} :: Fields, MarketPanel))

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

local function priceText(item: Item): string
	if not item.forSale then
		return OFF_SALE_TEXT
	end

	return if item.price ~= nil then ("R$ %d"):format(item.price) else "BUY"
end

function MarketPanel.new(menu: MenuScreen.MenuScreen): MarketPanel
	local window = menu:window(WINDOW)
	local tabsFrame = UiKit.authored(window, "Tabs", "GuiObject")
	local list = UiKit.authored(window, "Grid.List", "ScrollingFrame")

	local fields: Fields = {
		menu = menu,
		tabs = {},
		tabImage = attribute(tabsFrame, "TabImage"),
		pickedTabImage = attribute(tabsFrame, "PickedTabImage"),
		grid = CardGrid.new(list, UiKit.authored(list, "RowTemplate", "GuiObject")),
		detailGlyph = UiKit.authored(window, "DetailIcon.Glyph", "TextLabel"),
		detailName = UiKit.authored(window, "DetailName", "TextLabel"),
		detailTag = UiKit.authored(window, "DetailTag", "TextLabel"),
		detailState = UiKit.authored(window, "DetailState", "TextLabel"),
		buyButton = UiKit.authored(window, "BuyButton", "GuiButton"),
		buyLabel = UiKit.authored(window, "BuyButton.BuyLabel", "TextLabel"),
		statusLabel = UiKit.authored(window, "StatusLabel", "TextLabel"),
		manageBar = UiKit.authored(window, "ManageBar", "GuiObject"),
		idBox = UiKit.authored(window, "ManageBar.IdBox", "TextBox"),
		myItemsButton = UiKit.authored(window, "ManageBar.MyItemsButton", "TextButton"),
		browsing = false,
		creations = {},
		stalls = {},
		open = false,
		hasStall = false,
		notice = nil,
		stall = 1,
		picked = 1,
		actions = nil,
	}
	local self = setmetatable(fields, MarketPanel)

	for index = 1, #UGCCatalog.Stalls do
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")

		if button ~= nil then
			table.insert(fields.tabs, { button = button, label = UiKit.child(button, "TabLabel", "TextLabel") })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.stall = index
				self.picked = 1
				self.notice = nil
				self.browsing = false
				self:_draw()
			end)
		end
	end

	self:_bindButton(fields.buyButton, function()
		local action = self:_action()

		if action.run == nil then
			UiKit.playSound("uiDenied")
		else
			action.run()
		end
	end)
	self:_bindButton(UiKit.authored(window, "ManageBar.AddButton", "GuiButton"), function()
		local box = self.idBox

		if self.actions ~= nil and box ~= nil then
			self.actions.add(box.Text)
		end
	end)
	self:_bindButton(fields.myItemsButton, function()
		self.browsing = not self.browsing
		self.picked = 1
		self.notice = nil

		if self.browsing then
			self.creations = {}
			self.notice = "LOOKING UP YOUR ITEMS..."

			if self.actions ~= nil then
				self.actions.browse()
			end
		end

		self:_draw()
	end)
	self:_bindButton(UiKit.authored(window, "ManageBar.ReleaseButton", "GuiButton"), function()
		if self.actions ~= nil then
			self.actions.release()
		end
	end)
	self:_bindButton(UiKit.authored(window, "CloseButton", "GuiButton"), function()
		menu:close(WINDOW)
	end)

	return self
end

function MarketPanel._bindButton(_self: MarketPanel, button: GuiButton?, onActivated: () -> ())
	if button == nil then
		return
	end

	UiKit.bindHover(button)
	button.Activated:Connect(onActivated)
end

function MarketPanel.isVisible(self: MarketPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function MarketPanel.setVisible(self: MarketPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function MarketPanel.bindActions(self: MarketPanel, actions: Actions)
	self.actions = actions
end

-- open is whether the market sells yet; closed, everything reads coming soon.
-- hasStall is whether the local player already holds a stall.
function MarketPanel.render(self: MarketPanel, stalls: { Stall }, open: boolean, hasStall: boolean)
	self.stalls = stalls
	self.open = open
	self.hasStall = hasStall
	self.stall = math.clamp(self.stall, 1, math.max(#stalls, 1))
	self:_draw()
end

function MarketPanel.showStall(self: MarketPanel, stallId: string)
	for index, stall in self.stalls do
		if stall.id == stallId then
			self.stall = index
			self.picked = 1
			self.notice = nil
			self.browsing = false
			self:_draw()
			return
		end
	end
end

function MarketPanel.showCreations(self: MarketPanel, items: { Item })
	self.creations = items
	self.picked = 1
	self.notice = if #items == 0 then UGCCatalog.reasonText("no_creations") else nil
	self:_draw()
end

function MarketPanel._isBrowsing(self: MarketPanel): boolean
	local stall = self.stalls[self.stall]

	return self.browsing and stall ~= nil and stall.mine
end

function MarketPanel._rack(self: MarketPanel): { Item }
	local stall = self.stalls[self.stall]

	if self:_isBrowsing() then
		return self.creations
	end

	return if stall ~= nil then stall.items else {}
end

function MarketPanel._onMyStall(self: MarketPanel, assetId: number?): boolean
	local stall = self.stalls[self.stall]

	for _, item in if stall ~= nil and stall.mine then stall.items else {} do
		if item.assetId == assetId then
			return true
		end
	end

	return false
end

function MarketPanel._tagText(self: MarketPanel, item: Item): string
	if not self.open then
		return SOON_TEXT
	end

	if self:_isBrowsing() then
		return if self:_onMyStall(item.assetId)
			then ON_STALL_TEXT
			elseif item.sellable == false then SHOP_ONLY_TEXT
			else priceText(item)
	end

	return priceText(item)
end

function MarketPanel.showNotice(self: MarketPanel, text: string)
	self.notice = text
	self:_drawDetail()
end

function MarketPanel.clearIdBox(self: MarketPanel)
	if self.idBox ~= nil then
		self.idBox.Text = ""
	end
end

function MarketPanel._action(self: MarketPanel): Action
	local stall = self.stalls[self.stall]
	local item = self:_rack()[self.picked]
	local actions = self.actions

	if not self.open or stall == nil or actions == nil then
		return { label = "SOON" }
	end

	if stall.owner == nil then
		if self.hasStall then
			return { label = "YOU HAVE A STALL" }
		end

		return {
			label = "CLAIM STALL",
			run = function()
				actions.claim(stall.id)
			end,
		}
	end

	local assetId = if item ~= nil then item.assetId else nil

	if self:_isBrowsing() then
		if item == nil or assetId == nil then
			return { label = "NOTHING TO ADD" }
		elseif self:_onMyStall(assetId) then
			return { label = "ON YOUR STALL" }
		elseif item.sellable == false then
			return { label = SHOP_ONLY_TEXT }
		end

		return {
			label = "ADD TO STALL",
			run = function()
				actions.add(tostring(assetId))
			end,
		}
	end

	if assetId == nil then
		return { label = if stall.mine then "ADD ITEMS BELOW" else "EMPTY RACK" }
	end

	if stall.mine then
		return {
			label = "REMOVE",
			run = function()
				actions.remove(assetId)
			end,
		}
	end

	if not (item :: Item).forSale then
		return { label = OFF_SALE_TEXT }
	end

	return {
		label = priceText(item :: Item),
		run = function()
			actions.buy(assetId)
		end,
	}
end

function MarketPanel._draw(self: MarketPanel)
	for index, tab in self.tabs do
		local stall = self.stalls[index]
		local image = if index == self.stall then self.pickedTabImage else self.tabImage

		tab.button.Visible = stall ~= nil

		if tab.label ~= nil and stall ~= nil then
			tab.label.Text = string.upper(if stall.owner ~= nil then stall.owner else stall.name)
		end

		if image ~= nil and tab.button:IsA("ImageButton") then
			UiKit.setImage(tab.button, image)
		end
	end

	if self.statusLabel ~= nil then
		self.statusLabel.Visible = not self.open
	end

	local stall = self.stalls[self.stall]
	local items = self:_rack()

	if self.manageBar ~= nil then
		self.manageBar.Visible = self.open and stall ~= nil and stall.mine
	end

	if self.myItemsButton ~= nil then
		self.myItemsButton.Text = if self:_isBrowsing() then BACK_TEXT else MY_ITEMS_TEXT
	end

	self.grid:build(#items, function(card: GuiButton, index: number)
		local item = items[index]
		local name = UiKit.child(card, "NameLabel", "TextLabel")
		local tag = UiKit.child(card, "TagLabel", "TextLabel")
		local check = UiKit.child(card, "Check", "GuiObject")

		UiKit.setIcon(UiKit.child(card:FindFirstChild("Icon"), "Glyph", "TextLabel"), item.glyph, item.icon)

		if name ~= nil then
			name.Text = string.upper(item.name)
		end

		if tag ~= nil then
			tag.Text = self:_tagText(item)
		end

		if check ~= nil then
			check.Visible = false
		end

		card.Activated:Connect(function()
			self.picked = index
			self.notice = nil
			self:_drawDetail()
		end)
	end)

	self:_drawDetail()
end

function MarketPanel._drawDetail(self: MarketPanel)
	local stall = self.stalls[self.stall]
	local item = self:_rack()[self.picked]
	local browsing = self:_isBrowsing()
	local action = self:_action()

	self.grid:paintPicked(self.picked)
	UiKit.setIcon(
		self.detailGlyph,
		if item ~= nil then item.glyph elseif stall ~= nil then "🏪" else "",
		if item ~= nil then item.icon else nil
	)

	if self.detailName ~= nil then
		self.detailName.Text = if item ~= nil
			then string.upper(item.name)
			elseif stall ~= nil and stall.owner == nil then "FREE STALL"
			else "EMPTY RACK"
	end

	if self.detailTag ~= nil then
		self.detailTag.Text = if stall == nil
			then ""
			elseif browsing then "YOUR ITEMS"
			elseif stall.mine then "YOUR STALL"
			elseif stall.owner ~= nil then "BY " .. string.upper(stall.owner)
			else ("LIST UP TO %d ITEMS YOU MADE"):format(UGCCatalog.MaxListings)
	end

	if self.detailState ~= nil then
		self.detailState.Text = if self.notice ~= nil
			then self.notice
			elseif browsing and item ~= nil and item.sellable == false then UGCCatalog.reasonText("wrong_sale_location")
			elseif browsing then "PICK AN ITEM TO PUT ON YOUR STALL"
			elseif item ~= nil and not item.forSale then UGCCatalog.reasonText("off_sale")
			elseif not self.open then "CREATOR STALLS OPEN SOON"
			elseif stall ~= nil and stall.owner == nil then "CLAIM IT TO SELL YOUR UGC HERE"
			else BUY_NOTE
	end

	if self.buyLabel ~= nil then
		self.buyLabel.Text = action.label
	end

	local buy = self.buyButton

	if buy ~= nil and buy:IsA("ImageButton") then
		buy.ImageTransparency = if action.run ~= nil then 0 else DIMMED
	end
end

return MarketPanel
