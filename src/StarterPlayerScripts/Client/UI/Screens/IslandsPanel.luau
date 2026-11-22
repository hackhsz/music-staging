--!strict
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "islands"
local MAX_TABS = 2
local MAX_PLACES = 8
local MAX_CHIPS = 3
local HERE_TEXT = "YOU ARE HERE"
-- The list sits beside the map, or takes the map's room in an area that has no map. The
-- authored List names both placements in these attributes.
local BESIDE_MAP = { position = "MapPosition", size = "MapSize" }
local NO_MAP = { position = "WidePosition", size = "WideSize" }
-- A lit row or pin can need different text; the authored instance says which in these.
local LIT_TEXT = "LitText"
local REST_TEXT = "RestText"

export type Island = {
	id: string,
	name: string,
	blurb: string,
	tag: string,
	scene: string?,
	-- Where the place sits on its area's map, each axis from 0 to 1; nil leaves it off the map.
	pin: Vector2?,
	what: { string },
	area: string,
	here: boolean,
}

export type Area = { id: string, name: string, map: string? }

type Tab = { button: GuiButton, label: TextLabel? }

type Fields = {
	menu: MenuScreen.MenuScreen,
	window: GuiObject?,
	tabs: { Tab },
	areas: { Area },
	area: number,
	islands: { Island },
	shown: { Island },
	picked: number,
	onTravel: ((islandId: string) -> ())?,
}

-- The Travel window, authored in StarterGui.Menu's Islands: a tab per area, the area's map
-- with a numbered pin per place, the places as a numbered list, and the picked one in the
-- detail panel with its TRAVEL button. IslandController sends the trip.
local IslandsPanel = {}
IslandsPanel.__index = IslandsPanel

export type IslandsPanel = typeof(setmetatable({} :: Fields, IslandsPanel))

local function setText(root: Instance?, path: string, text: string)
	local label = UiKit.authored(root, path, "TextLabel")

	if label ~= nil then
		label.Text = text
	end
end

local function setImage(root: Instance?, path: string, image: string)
	local art = UiKit.authored(root, path, "ImageLabel")

	if art ~= nil then
		art.Image = image
	end
end

local function setLit(part: GuiObject?, lit: boolean)
	if part == nil then
		return
	end

	UiKit.setLit(part, lit)

	local color = part:GetAttribute(if lit then LIT_TEXT else REST_TEXT)

	if typeof(color) ~= "Color3" then
		return
	end

	for _, child in part:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextColor3 = color
		end
	end
end

function IslandsPanel.new(menu: MenuScreen.MenuScreen): IslandsPanel
	local window = menu:window(WINDOW)
	local tabsFrame = UiKit.authored(window, "Tabs", "GuiObject")

	local fields: Fields = {
		menu = menu,
		window = window,
		tabs = {},
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

	for index = 1, MAX_PLACES do
		for _, path in { "List.Place" .. index, "Map.Pin" .. index } do
			local button = UiKit.authored(window, path, "GuiButton")

			if button ~= nil then
				UiKit.bindHover(button)
				button.Activated:Connect(function()
					self.picked = index
					self:_drawPicked()
				end)
			end
		end
	end

	local travel = UiKit.authored(window, "TravelButton", "GuiButton")

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

function IslandsPanel._placeList(self: IslandsPanel, hasMap: boolean)
	local list = UiKit.authored(self.window, "List", "GuiObject")
	local names = if hasMap then BESIDE_MAP else NO_MAP

	if list == nil then
		return
	end

	local position, size = list:GetAttribute(names.position), list:GetAttribute(names.size)

	if typeof(position) == "UDim2" and typeof(size) == "UDim2" then
		list.Position = position
		list.Size = size
	end
end

function IslandsPanel._draw(self: IslandsPanel)
	local area = self.areas[self.area]

	for index, tab in self.tabs do
		local entry = self.areas[index]

		tab.button.Visible = entry ~= nil
		setLit(tab.button, index == self.area)

		if tab.label ~= nil and entry ~= nil then
			tab.label.Text = string.upper(entry.name)
		end
	end

	local shown: { Island } = {}
	local hasMap = false

	for _, island in self.islands do
		if (area == nil or island.area == area.id) and #shown < MAX_PLACES then
			table.insert(shown, island)
			hasMap = hasMap or island.pin ~= nil
		end
	end

	self.shown = shown
	self.picked = math.clamp(self.picked, 1, math.max(#shown, 1))

	local map = UiKit.authored(self.window, "Map", "GuiObject")

	hasMap = hasMap and area ~= nil and area.map ~= nil

	if map ~= nil then
		map.Visible = hasMap
		setImage(map, "Art", if area ~= nil then area.map or "" else "")
	end

	self:_placeList(hasMap)

	for index = 1, MAX_PLACES do
		local island = shown[index]
		local row = UiKit.authored(self.window, "List.Place" .. index, "GuiObject")
		local pin = UiKit.authored(map, "Pin" .. index, "GuiObject")

		if row ~= nil then
			row.Visible = island ~= nil

			if island ~= nil then
				setImage(row, "Thumb", island.scene or "")
				setText(row, "NameLabel", ("%d. %s"):format(index, string.upper(island.name)))
				setText(row, "TagLabel", island.tag)

				local here = UiKit.authored(row, "HereChip", "GuiObject")

				if here ~= nil then
					here.Visible = island.here
				end
			end
		end

		if pin ~= nil then
			pin.Visible = island ~= nil and island.pin ~= nil

			if island ~= nil and island.pin ~= nil then
				pin.Position = UDim2.fromScale(island.pin.X, island.pin.Y)
				setText(pin, "NumberLabel", tostring(index))
			end
		end
	end

	local hereTag = UiKit.authored(map, "HereTag", "GuiObject")

	if hereTag ~= nil then
		hereTag.Visible = false

		for _, island in shown do
			if island.here and island.pin ~= nil then
				hereTag.Visible = true
				hereTag.Position = UDim2.fromScale(island.pin.X, island.pin.Y)
			end
		end
	end

	self:_drawPicked()
end

function IslandsPanel._drawPicked(self: IslandsPanel)
	local island = self.shown[self.picked]
	local window = self.window

	for index = 1, MAX_PLACES do
		setLit(UiKit.authored(window, "List.Place" .. index, "GuiObject"), index == self.picked)
		setLit(UiKit.authored(window, "Map.Pin" .. index, "GuiObject"), index == self.picked)
	end

	setImage(window, "DetailScene", if island ~= nil then island.scene or "" else "")
	setText(window, "DetailName", if island ~= nil then string.upper(island.name) else "")
	setText(window, "DetailState", if island ~= nil then island.blurb else "")

	for index = 1, MAX_CHIPS do
		local chip = UiKit.authored(window, "What.Chip" .. index, "GuiObject")
		local text = if island ~= nil then island.what[index] else nil

		if chip ~= nil then
			chip.Visible = text ~= nil
			setText(chip, "Label", string.upper(text or ""))
		end
	end

	local canTravel = island ~= nil and not island.here

	setText(window, "TravelButton.TravelLabel", if canTravel then "TRAVEL" else HERE_TEXT)
	setLit(UiKit.authored(window, "TravelButton", "GuiObject"), canTravel)
end

return IslandsPanel
