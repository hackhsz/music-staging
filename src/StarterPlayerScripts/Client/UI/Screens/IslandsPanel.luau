--!strict
local CardGrid = require(script.Parent.Parent.CardGrid)
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "islands"
local MAX_TABS = 2
local HERE_TEXT = "YOU ARE HERE"
local DIMMED = 0.45

export type Island = {
	id: string,
	name: string,
	blurb: string,
	glyph: string,
	icon: string?,
	area: string,
	here: boolean,
}

export type Area = { id: string, name: string }

type Tab = { button: GuiButton, label: TextLabel? }

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
	travelButton: GuiButton?,
	travelLabel: TextLabel?,
	areas: { Area },
	area: number,
	islands: { Island },
	shown: { Island },
	picked: number,
	onTravel: ((islandId: string) -> ())?,
}

-- The Travel window, authored in StarterGui.Menu's Islands: a tab per area (the
-- main island's spots, the sky islands), a card per place, and the picked one on
-- the pedestal with its TRAVEL button. IslandController sends the trip.
local IslandsPanel = {}
IslandsPanel.__index = IslandsPanel

export type IslandsPanel = typeof(setmetatable({} :: Fields, IslandsPanel))

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

function IslandsPanel.new(menu: MenuScreen.MenuScreen): IslandsPanel
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
		travelButton = UiKit.authored(window, "TravelButton", "GuiButton"),
		travelLabel = UiKit.authored(window, "TravelButton.TravelLabel", "TextLabel"),
		areas = {},
		area = 1,
		islands = {},
		shown = {},
		picked = 1,
		onTravel = nil,
	}
	local self = setmetatable(fields, IslandsPanel)

	for index = 1, MAX_TABS do
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")

		if button ~= nil then
			table.insert(fields.tabs, { button = button, label = UiKit.child(button, "TabLabel", "TextLabel") })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.area = index
				self.picked = 1
				self:_draw()
			end)
		end
	end

	local travel = fields.travelButton

	if travel ~= nil then
		UiKit.bindHover(travel)
		travel.Activated:Connect(function()
			local island = self.shown[self.picked]

			if island == nil or island.here then
				UiKit.playSound("uiDenied")
			elseif self.onTravel ~= nil then
				self.onTravel(island.id)
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

	return self
end

function IslandsPanel.isVisible(self: IslandsPanel): boolean
	return self.menu:isOpen(WINDOW)
end

function IslandsPanel.setVisible(self: IslandsPanel, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
	else
		self.menu:close(WINDOW)
	end
end

function IslandsPanel.bindTravel(self: IslandsPanel, callback: (islandId: string) -> ())
	self.onTravel = callback
end

function IslandsPanel.render(self: IslandsPanel, areas: { Area }, islands: { Island })
	self.areas = areas
	self.islands = islands
	self.area = math.clamp(self.area, 1, math.max(#areas, 1))
	self:_draw()
end

function IslandsPanel._areaName(self: IslandsPanel, areaId: string): string
	for _, area in self.areas do
		if area.id == areaId then
			return string.upper(area.name)
		end
	end

	return ""
end

function IslandsPanel._draw(self: IslandsPanel)
	local area = self.areas[self.area]

	for index, tab in self.tabs do
		local entry = self.areas[index]
		local image = if index == self.area then self.pickedTabImage else self.tabImage

		tab.button.Visible = entry ~= nil

		if tab.label ~= nil and entry ~= nil then
			tab.label.Text = string.upper(entry.name)
		end

		if image ~= nil and tab.button:IsA("ImageButton") then
			UiKit.setImage(tab.button, image)
		end
	end

	local shown: { Island } = {}

	for _, island in self.islands do
		if area == nil or island.area == area.id then
			table.insert(shown, island)
		end
	end

	self.shown = shown
	self.picked = math.clamp(self.picked, 1, math.max(#shown, 1))

	self.grid:build(#shown, function(card: GuiButton, index: number)
		local island = shown[index]
		local name = UiKit.child(card, "NameLabel", "TextLabel")
		local tag = UiKit.child(card, "TagLabel", "TextLabel")
		local check = UiKit.child(card, "Check", "GuiObject")

		UiKit.setIcon(UiKit.child(card:FindFirstChild("Icon"), "Glyph", "TextLabel"), island.glyph, island.icon)

		if name ~= nil then
			name.Text = string.upper(island.name)
		end

		if tag ~= nil then
			tag.Text = if island.here then HERE_TEXT else self:_areaName(island.area)
		end

		if check ~= nil then
			check.Visible = island.here
		end

		card.Activated:Connect(function()
			self.picked = index
			self:_drawDetail()
		end)
	end)

	self:_drawDetail()
end

function IslandsPanel._drawDetail(self: IslandsPanel)
	local island = self.shown[self.picked]

	self.grid:paintPicked(self.picked)
	UiKit.setIcon(self.detailGlyph, if island ~= nil then island.glyph else "", if island ~= nil then island.icon else nil)

	if self.detailName ~= nil then
		self.detailName.Text = if island ~= nil then string.upper(island.name) else ""
	end

	if self.detailTag ~= nil then
		self.detailTag.Text = if island == nil then ""
			elseif island.here then HERE_TEXT
			else self:_areaName(island.area)
	end

	if self.detailState ~= nil then
		self.detailState.Text = if island ~= nil then string.upper(island.blurb) else ""
	end

	local canTravel = island ~= nil and not island.here

	if self.travelLabel ~= nil then
		self.travelLabel.Text = if canTravel then "TRAVEL" else "HERE"
	end

	local travel = self.travelButton

	if travel ~= nil and travel:IsA("ImageButton") then
		travel.ImageTransparency = if canTravel then 0 else DIMMED
	end
end

return IslandsPanel
