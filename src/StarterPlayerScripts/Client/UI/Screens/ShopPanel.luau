--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CosmeticsCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local MenuScreen = require(script.Parent.MenuScreen)
local ShopOffers = require(script.Parent.ShopOffers)
local TryOnPreview = require(script.Parent.Parent.TryOnPreview)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

local WINDOW = "shop"
-- A styled (Pill) tab or buy button shows it is picked, or can be bought, with this tag.
-- Sections drawn as Robux offers; every other section is a grid of item cards.
local OFFER_SECTIONS = { featured = true, passes = true, coin_packs = true }
-- Rarities worth a star on the card.
local STARRED = { epic = true, legendary = true }
local DIMMED = 0.45
local LOCKED_GLYPH = 0.55
local BOUGHT_POP = 1.18
local BOUGHT_SECONDS = 0.45
-- A section's tab lights up once its header is this close to the top of the page.
local SPY_MARGIN = 24

type Tab = { button: GuiButton, section: string }

type Fields = {
	menu: MenuScreen.MenuScreen,
	tabs: { Tab },
	itemRow: GuiObject?,
	offers: ShopOffers.ShopOffers,
	headers: { [string]: GuiObject },
	popup: GuiObject?,
	balanceLabel: TextLabel?,
	detailGlyph: TextLabel?,
	detailName: TextLabel?,
	detailTag: TextLabel?,
	detailTagColor: Color3,
	detailState: TextLabel?,
	buyButton: GuiButton?,
	buyLabel: TextLabel?,
	detailIcon: GuiObject?,
	preview: ViewportFrame?,
	tryOn: TryOnPreview.TryOnPreview,
	sections: { any },
	section: string,
	selectedId: string?,
	onActivated: ((entry: any) -> ())?,
	onPicked: ((entry: any) -> ())?,
}

-- The shop window, authored in StarterGui.Menu's Shop: a tab bar (Sidebar, each
-- tab naming its section in a Section attribute, in LayoutOrder) over one scrolling
-- Page holding every section in tab order (ShopOffers draws it). A tab scrolls to
-- its section and lights up while that section is in view. Tapping an item card
-- opens ItemPopup, the item on the pedestal with its buy or equip button. Drawing
-- and taps only; ShopController builds the entries and sends the purchase.
local ShopPanel = {}
ShopPanel.__index = ShopPanel

export type ShopPanel = typeof(setmetatable({} :: Fields, ShopPanel))

local function glyphFor(entry: any): string
	if type(entry.glyph) == "string" then
		return entry.glyph
	end

	return string.sub(tostring(entry.displayName or entry.id or "?"), 1, 1)
end

local function rarityOf(entry: any): any
	return if type(entry.rarity) == "string" then CosmeticsCatalog.Rarities[entry.rarity] else nil
end

local function tagFor(entry: any): (string, Color3)
	if entry.equipped == true then
		return "EQUIPPED", Colors.Green
	elseif entry.owned == true then
		return "OWNED", Colors.Cyan
	elseif entry.robux ~= nil then
		return ("R$ %d"):format(entry.robux), if entry.comingSoon == true then Colors.Dim else Colors.Green
	elseif entry.comingSoon == true then
		return "COMING SOON", Colors.Dim
	elseif entry.locked == true then
		return "LOCKED", Colors.Dim
	elseif entry.price ~= nil then
		return ("%d COINS"):format(entry.price), if entry.affordable == false then Colors.Red else Colors.Yellow
	end

	return "CLAIM", Colors.Pink
end

local function actionFor(entry: any): (string, boolean)
	if entry.equipped == true then
		return "EQUIPPED", false
	elseif entry.owned == true then
		return "EQUIP", true
	elseif entry.comingSoon == true then
		return "SOON", false
	elseif entry.robux ~= nil then
		return ("R$ %d"):format(entry.robux), true
	elseif entry.locked == true then
		return "LOCKED", false
	elseif entry.price ~= nil then
		return ("BUY %d"):format(entry.price), entry.affordable ~= false
	end

	return "CLAIM", true
end

local function paintTag(button: GuiObject, on: boolean)
	UiKit.setLit(button, on)
end

function ShopPanel.new(menu: MenuScreen.MenuScreen): ShopPanel
	local window = menu:window(WINDOW)
	local sidebar = UiKit.authored(window, "Sidebar", "GuiObject")
	local popup = UiKit.authored(window, "ItemPopup", "GuiObject")

	local fields: Fields = {
		menu = menu,
		tabs = {},
		itemRow = UiKit.authored(window, "Templates.ItemRowTemplate", "GuiObject"),
		offers = ShopOffers.new(window),
		headers = {},
		popup = popup,
		balanceLabel = UiKit.authored(window, "Balance.CoinLabel", "TextLabel"),
		detailGlyph = UiKit.authored(popup, "DetailIcon.Glyph", "TextLabel"),
		detailName = UiKit.authored(popup, "DetailName", "TextLabel"),
		detailTag = UiKit.authored(popup, "DetailTag", "TextLabel"),
		detailTagColor = Colors.Pink,
		detailState = UiKit.authored(popup, "DetailState", "TextLabel"),
		buyButton = UiKit.authored(popup, "BuyButton", "GuiButton"),
		buyLabel = UiKit.authored(popup, "BuyButton.BuyLabel", "TextLabel"),
		detailIcon = UiKit.authored(popup, "DetailIcon", "GuiObject"),
		preview = UiKit.authored(popup, "Preview", "ViewportFrame"),
		tryOn = TryOnPreview.new(
			UiKit.authored(popup, "Preview", "ViewportFrame"),
			UiKit.authored(popup, "Preview.WorldModel", "WorldModel")
		),
		sections = {},
		section = "",
		selectedId = nil,
		onActivated = nil,
		onPicked = nil,
	}
	local self = setmetatable(fields, ShopPanel)

	if fields.detailTag ~= nil then
		fields.detailTagColor = fields.detailTag.TextColor3
	end

	if popup ~= nil then
		popup.Visible = false
	end

	local buttons = if sidebar ~= nil then sidebar:GetChildren() else {}

	table.sort(buttons, function(a: Instance, b: Instance)
		return (if a:IsA("GuiObject") then a.LayoutOrder else 0) < (if b:IsA("GuiObject") then b.LayoutOrder else 0)
	end)

	for _, button in buttons do
		local section = button:GetAttribute("Section")

		if button:IsA("GuiButton") and type(section) == "string" then
			table.insert(fields.tabs, { button = button, section = section })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self:_jumpTo(section)
			end)
		end
	end

	fields.section = if fields.tabs[1] ~= nil then fields.tabs[1].section else ""
	fields.offers:bindBuy(function(entry: any)
		if self.onActivated ~= nil then
			self.onActivated(entry)
		end
	end)

	local page = fields.offers.page

	if page ~= nil then
		page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if not self.offers:isScrolling() then
				self:_followScroll()
			end
		end)
	end

	local buy = fields.buyButton

	if buy ~= nil then
		UiKit.bindHover(buy)
		buy.Activated:Connect(function()
			local entry = self:_selected()

			if entry == nil or not select(2, actionFor(entry)) then
				UiKit.playSound("uiDenied")
			elseif self.onActivated ~= nil then
				self.onActivated(entry)
			end
		end)
	end

	local back = UiKit.authored(popup, "BackButton", "GuiButton")

	if back ~= nil then
		UiKit.bindHover(back)
		back.Activated:Connect(function()
			self:_closeItem()
		end)
	end

	local close = UiKit.authored(window, "CloseButton", "GuiButton")

	if close ~= nil then
		UiKit.bindHover(close)
		close.Activated:Connect(function()
			self:setVisible(false)
		end)
	end

	if window ~= nil then
		window:GetPropertyChangedSignal("Visible"):Connect(function()
			fields.tryOn:setSpinning(window.Visible)

			if not window.Visible then
				self:_closeItem()
			end
		end)
	end

	return self
end

-- The avatar the pedestal shows; ShopController hands over the player's character.
function ShopPanel.setPreviewSource(self: ShopPanel, source: Model?)
	self.tryOn:setSource(source)

	if self.selectedId ~= nil then
		self:_drawDetail(self:_selected())
	end
end

-- A purchase went through: the pedestal and the button pop.
function ShopPanel.playBought(self: ShopPanel)
	for _, gui in { self.preview, self.buyButton } do
		if gui ~= nil then
			local scale = UiKit.scaleOf(gui, "Pop")
			scale.Scale = BOUGHT_POP
			TweenService:Create(scale, TweenInfo.new(BOUGHT_SECONDS, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
end

function ShopPanel.isVisible(self: ShopPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function ShopPanel.setVisible(self: ShopPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
		task.defer(function()
			self.offers:fit()
		end)
	else
		self.menu:close(WINDOW)
	end
end

function ShopPanel.updateBalance(self: ShopPanel, amount: number?)
	if self.balanceLabel ~= nil then
		self.balanceLabel.Text = tostring(math.max(tonumber(amount) or 0, 0))
	end
end

function ShopPanel.bindItemActivated(self: ShopPanel, callback: (entry: any) -> ())
	self.onActivated = callback
end

-- sections: { { id, displayName, entries = { { kind, id, displayName, glyph, icon,
-- rarity, stateText, category, price, robux, wasRobux, includes, description,
-- badge, hero, coins, bonus, owned, equipped, locked, comingSoon, affordable } } } }
function ShopPanel.bindItemPicked(self: ShopPanel, callback: (entry: any) -> ())
	self.onPicked = callback
end

-- Rebuilds the page in tab order, keeping where the player had scrolled to.
function ShopPanel.render(self: ShopPanel, sections: any)
	self.sections = if type(sections) == "table" then sections else {}

	local offers = self.offers
	local page = offers.page
	local scrolled = if page ~= nil then page.CanvasPosition else Vector2.zero

	offers:clear()
	self.headers = {}

	for _, tab in self.tabs do
		local group = self:_group(tab.section)
		local entries = if group ~= nil then group.entries or {} else {}

		tab.button.Visible = #entries > 0

		if #entries == 0 then
			continue
		end

		local header = offers:addHeader(tostring(group.displayName or tab.section))

		if header ~= nil then
			self.headers[tab.section] = header
		end

		if OFFER_SECTIONS[tab.section] then
			offers:addOffers(entries)
		else
			offers:addGrid(entries, self.itemRow, function(card, entry)
				self:_fillCard(card, entry)
			end)
		end
	end

	-- New rows have no size until the next layout pass.
	task.defer(function()
		offers:fit()

		if page ~= nil then
			page.CanvasPosition = scrolled
		end

		self:_followScroll()
	end)

	if self.selectedId ~= nil then
		self:_drawDetail(self:_selected())
	end
end

function ShopPanel._group(self: ShopPanel, section: string): any
	for _, group in self.sections do
		if group.id == section then
			return group
		end
	end

	return nil
end

function ShopPanel._selected(self: ShopPanel): any
	for _, group in self.sections do
		for _, entry in group.entries or {} do
			if entry.id == self.selectedId and not OFFER_SECTIONS[group.id] then
				return entry
			end
		end
	end

	return nil
end

function ShopPanel._paintTabs(self: ShopPanel)
	for _, tab in self.tabs do
		local picked = tab.section == self.section
		local skin = UiKit.child(tab.button, "TabSkin", "ImageLabel")
		local image = tab.button:GetAttribute(if picked then "TabSelectedImage" else "TabImage")

		paintTag(tab.button, picked)

		if skin ~= nil and type(image) == "string" then
			skin.Image = image
		end
	end
end

function ShopPanel._jumpTo(self: ShopPanel, section: string)
	local header = self.headers[section]

	self:_closeItem()
	self.section = section
	self:_paintTabs()

	if header ~= nil then
		self.offers:scrollTo(header, function()
			self:_followScroll()
		end)
	end
end

-- The tab of the last section whose header has reached the top of the page.
function ShopPanel._followScroll(self: ShopPanel)
	local page = self.offers.page

	if page == nil then
		return
	end

	local current = self.section
	local best = -math.huge

	for _, tab in self.tabs do
		local header = self.headers[tab.section]

		if header ~= nil then
			local top = self.offers:offsetOf(header)

			if top <= page.CanvasPosition.Y + SPY_MARGIN and top > best then
				best = top
				current = tab.section
			end
		end
	end

	-- At the very bottom the last section counts, even if its header never reaches the top.
	local maxY = page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y

	if maxY > 0 and page.CanvasPosition.Y >= maxY - 1 then
		for index = #self.tabs, 1, -1 do
			if self.headers[self.tabs[index].section] ~= nil then
				current = self.tabs[index].section
				break
			end
		end
	end

	self.section = current
	self:_paintTabs()
end

function ShopPanel._openItem(self: ShopPanel, entry: any)
	self.selectedId = entry.id

	if self.popup ~= nil then
		self.popup.Visible = true
	end

	self:_drawDetail(entry)

	if self.onPicked ~= nil then
		self.onPicked(entry)
	end
end

function ShopPanel._closeItem(self: ShopPanel)
	self.selectedId = nil

	if self.popup ~= nil then
		self.popup.Visible = false
	end

	self.tryOn:show(nil, false)
end

function ShopPanel._fillCard(self: ShopPanel, card: GuiObject, entry: any)
	local glyph = UiKit.child(card:FindFirstChild("Icon"), "Glyph", "TextLabel")
	local name = UiKit.child(card, "NameLabel", "TextLabel")
	local tag = UiKit.child(card, "TagLabel", "TextLabel")
	local check = UiKit.child(card, "Check", "GuiObject")
	local star = UiKit.child(card, "Star", "ImageLabel")
	local rarity = rarityOf(entry)
	local tagText, tagColor = tagFor(entry)

	UiKit.setIcon(glyph, glyphFor(entry), entry.icon)

	if glyph ~= nil then
		glyph.TextTransparency = if entry.locked == true then LOCKED_GLYPH else 0
	end

	if star ~= nil then
		star.Visible = rarity ~= nil and STARRED[entry.rarity] == true
		star.ImageColor3 = if rarity ~= nil then rarity.color else Colors.White
	end

	if name ~= nil then
		name.Text = tostring(entry.displayName or entry.id)
	end

	if tag ~= nil then
		tag.Text = tagText
		tag.TextColor3 = tagColor

		-- The authored gradient would tint every state the same.
		local tint = tag:FindFirstChildOfClass("UIGradient")

		if tint ~= nil then
			tint.Enabled = false
		end
	end

	if check ~= nil then
		check.Visible = entry.owned == true
	end

	if card:IsA("GuiButton") then
		UiKit.bindHover(card)
		card.Activated:Connect(function()
			self:_openItem(entry)
		end)
	end
end

function ShopPanel._drawDetail(self: ShopPanel, entry: any)
	local previewing = self.tryOn:show(entry, entry ~= nil and entry.equipped ~= true)

	if self.preview ~= nil then
		self.preview.Visible = previewing
	end

	if self.detailIcon ~= nil then
		self.detailIcon.Visible = not previewing
	end

	UiKit.setIcon(self.detailGlyph, if entry ~= nil then glyphFor(entry) else "", if entry ~= nil then entry.icon else nil)

	if self.detailName ~= nil then
		self.detailName.Text = if entry ~= nil then tostring(entry.displayName or entry.id) else ""
	end

	if self.detailTag ~= nil then
		local category = if entry ~= nil then entry.category or (if entry.kind == "song" then "track" else nil) else nil
		local rarity = if entry ~= nil then rarityOf(entry) else nil
		local words = if category ~= nil then string.upper(CosmeticsCatalog.categoryName(tostring(category))) else ""

		if rarity ~= nil then
			words = string.upper(rarity.displayName) .. " " .. words
		end

		self.detailTag.Text = words
		self.detailTag.TextColor3 = if rarity ~= nil then rarity.color else self.detailTagColor
	end

	if self.detailState ~= nil then
		self.detailState.Text = if entry ~= nil then tostring(entry.stateText or "") else ""
	end

	local label, enabled = "BUY", false

	if entry ~= nil then
		label, enabled = actionFor(entry)
	end

	if self.buyLabel ~= nil then
		self.buyLabel.Text = label
	end

	local buy = self.buyButton

	if buy ~= nil and buy:IsA("ImageButton") then
		buy.ImageTransparency = if enabled then 0 else DIMMED
	elseif buy ~= nil then
		paintTag(buy, enabled)
	end
end

return ShopPanel
