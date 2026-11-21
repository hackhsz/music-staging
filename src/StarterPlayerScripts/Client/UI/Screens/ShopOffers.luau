--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local PAGE_GAP = 10
local DIMMED = 0.45
-- A styled (Pill) buy button that can be pressed takes this tag.
local OWNED_TEXT = "OWNED"
local FREE_TEXT = "FREE"
local VIEW_TEXT = "VIEW"
local ONE_TIME_TEXT = "ONE-TIME OFFER"
-- The cards under a hero banner get their own small header, as the featured section's do.
local CARD_HEADER = "POPULAR"
local SCROLL_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

type Fields = {
	page: ScrollingFrame?,
	header: GuiObject?,
	subheader: GuiObject?,
	hero: GuiObject?,
	passRow: GuiObject?,
	packRow: GuiObject?,
	built: { GuiObject },
	scrollTween: Tween?,
	onBuy: ((entry: any) -> ())?,
}

-- The shop's one scrolling page, authored in the Shop window as Page and the
-- Templates folder, built section by section by ShopPanel: a header per section,
-- then a wide hero banner, pass and bundle cards, coin pack tiles, or item cards.
-- A row template holds Card1, Card2 and so on, which decides how many sit in a row.
-- Drawing and taps only.
local ShopOffers = {}
ShopOffers.__index = ShopOffers

export type ShopOffers = typeof(setmetatable({} :: Fields, ShopOffers))

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	return (formatted:gsub("^,", ""))
end

local function setText(parent: Instance, name: string, text: string?)
	local label = UiKit.child(parent, name, "TextLabel")

	if label ~= nil then
		label.Visible = text ~= nil and text ~= ""
		label.Text = text or ""
	end
end

-- A corner badge frame holding a BadgeLabel; hidden without text.
local function setBadge(parent: Instance, name: string, text: string?)
	local badge = UiKit.child(parent, name, "GuiObject")

	if badge == nil then
		return
	end

	badge.Visible = text ~= nil and text ~= ""

	local label = UiKit.child(badge, "BadgeLabel", "TextLabel")

	if label ~= nil then
		label.Text = text or ""
	end
end

local function discount(entry: any): string?
	local was = tonumber(entry.wasRobux)
	local now = tonumber(entry.robux)

	if was == nil or now == nil or was <= now then
		return nil
	end

	return ("-%d%%"):format(math.floor((1 - now / was) * 100 + 0.5))
end

local function cardsPerRow(template: Instance): number
	local count = 0

	while template:FindFirstChild("Card" .. (count + 1)) ~= nil do
		count += 1
	end

	return math.max(count, 1)
end

function ShopOffers.new(window: Instance?): ShopOffers
	local page = UiKit.authored(window, "Page", "ScrollingFrame")
	local templates = UiKit.authored(window, "Templates", "Folder")

	local self = setmetatable({
		page = page,
		header = UiKit.authored(templates, "HeaderTemplate", "GuiObject"),
		subheader = UiKit.authored(templates, "SubheaderTemplate", "GuiObject"),
		hero = UiKit.authored(templates, "HeroTemplate", "GuiObject"),
		passRow = UiKit.authored(templates, "PassRowTemplate", "GuiObject"),
		packRow = UiKit.authored(templates, "PackRowTemplate", "GuiObject"),
		built = {},
		scrollTween = nil,
		onBuy = nil,
	} :: Fields, ShopOffers)

	if page ~= nil then
		-- The authored samples only show the layout in Studio.
		for _, child in page:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:fit()
		end)

		local layout = page:FindFirstChildOfClass("UIListLayout")

		if layout ~= nil then
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				self:fit()
			end)
		end
	end

	return self
end

function ShopOffers.bindBuy(self: ShopOffers, callback: (entry: any) -> ())
	self.onBuy = callback
end

function ShopOffers.clear(self: ShopOffers)
	for _, gui in self.built do
		gui:Destroy()
	end

	self.built = {}
end

function ShopOffers.addHeader(self: ShopOffers, text: string): GuiObject?
	local header = self:_add(self.header)

	if header ~= nil and header:IsA("TextLabel") then
		header.Text = text
	elseif header ~= nil then
		setText(header, "HeaderLabel", text)
	end

	return header
end

-- Robux offers: hero banners first, then pass and bundle cards, then coin packs.
function ShopOffers.addOffers(self: ShopOffers, entries: { any })
	local heroes, cards, packs = {}, {}, {}

	for _, entry in entries do
		if entry.hero == true then
			table.insert(heroes, entry)
		elseif entry.kind == "coin_pack" then
			table.insert(packs, entry)
		else
			table.insert(cards, entry)
		end
	end

	for _, entry in heroes do
		local banner = self:_add(self.hero)

		if banner ~= nil then
			self:_fillHero(banner, entry)
		end
	end

	if #heroes > 0 and #cards > 0 then
		local subheader = self:_add(self.subheader)

		if subheader ~= nil and subheader:IsA("TextLabel") then
			subheader.Text = CARD_HEADER
		end
	end

	self:addGrid(cards, self.passRow, function(card, entry)
		self:_fillCard(card, entry)
	end)
	self:addGrid(packs, self.packRow, function(card, entry)
		self:_fillPack(card, entry)
	end)
end

function ShopOffers.addGrid(
	self: ShopOffers,
	entries: { any },
	template: GuiObject?,
	fill: (card: GuiObject, entry: any) -> ()
)
	if #entries == 0 or template == nil then
		return
	end

	local perRow = cardsPerRow(template)

	for first = 1, #entries, perRow do
		local row = self:_add(template)

		if row == nil then
			return
		end

		for column = 1, perRow do
			local card = row:FindFirstChild("Card" .. column)
			local entry = entries[first + column - 1]

			if card ~= nil and card:IsA("GuiObject") then
				-- An empty slot keeps its place so the row's cards stay the same width.
				card.Visible = entry ~= nil

				if entry ~= nil then
					fill(card, entry)
				end
			end
		end
	end
end

-- Where a built element sits on the page, measured from the top of the canvas.
function ShopOffers.offsetOf(self: ShopOffers, gui: GuiObject): number
	local page = self.page

	if page == nil then
		return 0
	end

	return gui.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
end

function ShopOffers.scrollTo(self: ShopOffers, gui: GuiObject, onDone: (() -> ())?)
	local page = self.page

	if page == nil then
		return
	end

	local padding = page:FindFirstChildOfClass("UIPadding")
	local top = if padding ~= nil then padding.PaddingTop.Offset else 0
	local maxY = math.max(page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y, 0)
	local target = math.clamp(self:offsetOf(gui) - top, 0, maxY)

	if self.scrollTween ~= nil then
		self.scrollTween:Cancel()
	end

	local tween = TweenService:Create(page, SCROLL_INFO, { CanvasPosition = Vector2.new(0, target) })

	self.scrollTween = tween
	tween.Completed:Connect(function()
		if self.scrollTween == tween then
			self.scrollTween = nil

			if onDone ~= nil then
				onDone()
			end
		end
	end)
	tween:Play()
end

function ShopOffers.isScrolling(self: ShopOffers): boolean
	return self.scrollTween ~= nil
end

function ShopOffers._add(self: ShopOffers, template: GuiObject?): GuiObject?
	if template == nil or self.page == nil then
		return nil
	end

	local gui = template:Clone()
	gui.Name = template.Name:gsub("Template$", "") .. (#self.built + 1)
	gui.LayoutOrder = #self.built + 1
	gui.Visible = true
	gui.Parent = self.page
	table.insert(self.built, gui)

	return gui
end

function ShopOffers._bindBuy(self: ShopOffers, card: Instance, entry: any)
	local button = UiKit.child(card, "BuyButton", "GuiButton")

	if button == nil then
		return
	end

	local price = UiKit.child(button, "PriceLabel", "TextLabel")
	local owned = entry.owned == true

	if price ~= nil then
		price.Text = if owned
			then entry.ownedText or OWNED_TEXT
			elseif entry.opensPass == true and entry.robux == nil then VIEW_TEXT
			elseif entry.robux == 0 then FREE_TEXT
			else ("R$ %d"):format(entry.robux or 0)
	end

	local buyable = not owned and (entry.comingSoon ~= true or entry.opensPass == true)

	if button:IsA("ImageButton") then
		button.ImageTransparency = if buyable then 0 else DIMMED
	else
		UiKit.setLit(button, buyable)
	end

	UiKit.bindHover(button)
	button.Activated:Connect(function()
		if owned and entry.opensPass ~= true then
			UiKit.playSound("uiDenied")
		elseif self.onBuy ~= nil then
			self.onBuy(entry)
		end
	end)
end

function ShopOffers._fillHero(self: ShopOffers, banner: GuiObject, entry: any)
	local lines = {}

	for _, line in if type(entry.includes) == "table" then entry.includes else {} do
		-- Set Road lines carry their own step marks.
		local bullet = if entry.kind == "set_road" then "" else "+ "

		table.insert(lines, bullet .. string.upper(tostring(line)))
	end

	UiKit.setIcon(UiKit.child(banner, "Glyph", "TextLabel"), entry.glyph, entry.icon)
	setText(banner, "NameLabel", entry.displayName)
	setText(banner, "Includes", table.concat(lines, "\n"))
	setText(banner, "WasLabel", if entry.wasRobux ~= nil then ("<s>R$ %d</s>"):format(entry.wasRobux) else nil)
	setBadge(banner, "Ribbon", if entry.oneTime == true then ONE_TIME_TEXT else entry.badge)
	setBadge(banner, "Badge", discount(entry))
	self:_bindBuy(banner, entry)
end

function ShopOffers._fillCard(self: ShopOffers, card: GuiObject, entry: any)
	local description = entry.description

	if description == nil and type(entry.includes) == "table" then
		description = table.concat(entry.includes, ", ")
	end

	UiKit.setIcon(UiKit.child(card, "Glyph", "TextLabel"), entry.glyph, entry.icon)
	setText(card, "NameLabel", entry.displayName)
	setText(card, "DescLabel", if description ~= nil then string.upper(description) else nil)
	setBadge(card, "Badge", discount(entry) or entry.badge or (if entry.oneTime == true then ONE_TIME_TEXT else nil))
	self:_bindBuy(card, entry)
end

function ShopOffers._fillPack(self: ShopOffers, card: GuiObject, entry: any)
	UiKit.setIcon(UiKit.child(card, "Glyph", "TextLabel"), entry.glyph, entry.icon)
	setText(card, "NameLabel", entry.displayName)
	setText(card, "AmountLabel", withCommas(tonumber(entry.coins) or 0))
	setText(card, "BonusLabel", entry.bonus)
	setBadge(card, "Badge", entry.badge)
	self:_bindBuy(card, entry)
end

function ShopOffers.fit(self: ShopOffers)
	local page = self.page

	if page == nil then
		return
	end

	local layout = page:FindFirstChildOfClass("UIListLayout")
	local height = 0

	-- The layout knows the real height, gaps and wrapped rows included.
	if layout ~= nil then
		height = layout.AbsoluteContentSize.Y
	else
		for _, gui in self.built do
			height += gui.AbsoluteSize.Y + PAGE_GAP
		end
	end

	local padding = page:FindFirstChildOfClass("UIPadding")

	if padding ~= nil then
		height += padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	end

	page.CanvasSize = UDim2.fromOffset(0, height)
end

return ShopOffers
