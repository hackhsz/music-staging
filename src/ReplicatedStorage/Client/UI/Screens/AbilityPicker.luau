--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "loadout"
local CARDS_PER_ROW = 4
local ROW_GAP = 6
-- A styled (Pill) tab shows it is picked with this tag.
local EQUIPPED_COLOR = Color3.fromRGB(106, 255, 128)
local CHARGE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_POP = 1.15
local FILL_POP_SECONDS = 0.35
-- The tabs in order: everything, then one per ability group.
local ALL = "all"
local TAB_GROUPS = { ALL, "defence", "score", "crowd", "assist" }

type Slot = { button: GuiButton, glyph: TextLabel?, name: TextLabel?, blurb: TextLabel? }
type Tab = { button: GuiButton, group: string }

type Fields = {
	menu: MenuScreen.MenuScreen,
	slots: { Slot },
	tabs: { Tab },
	list: ScrollingFrame?,
	rowTemplate: GuiObject?,
	rows: { GuiObject },
	countLabel: TextLabel?,
	headerSub: TextLabel?,
	detailGroup: TextLabel?,
	detailGlyph: TextLabel?,
	detailName: TextLabel?,
	detailBlurb: TextLabel?,
	detailCost: TextLabel?,
	slotImage: string?,
	pickedImage: string?,
	tabImage: string?,
	pickedTabImage: string?,
	group: string,
	loadout: { string },
	selected: number,
	onChanged: ((loadout: { string }) -> ())?,
}

-- The loadout window, authored in StarterGui.Menu's Loadout: pick a slot along the
-- top, then an ability from the grid below; the tabs filter the grid by group and
-- the right side describes the one under the pointer. Drawing and taps only;
-- AbilityController sends the choice.
local AbilityPicker = {}
AbilityPicker.__index = AbilityPicker

export type AbilityPicker = typeof(setmetatable({} :: Fields, AbilityPicker))

-- The card art's gradient carries the ability's group colour.
local function tint(card: Instance, color: Color3)
	local gradient = card:FindFirstChildOfClass("UIGradient")

	if gradient ~= nil then
		gradient.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	end
end

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

function AbilityPicker.new(menu: MenuScreen.MenuScreen): AbilityPicker
	local window = menu:window(WINDOW)
	local slotsFrame = UiKit.authored(window, "Slots", "GuiObject")
	local list = UiKit.authored(window, "Grid.List", "ScrollingFrame")
	local tabsFrame = UiKit.authored(list, "Tabs", "GuiObject")
	local rowTemplate = UiKit.authored(list, "RowTemplate", "GuiObject")
	local detail = UiKit.authored(window, "DetailIcon", "GuiObject")

	local fields: Fields = {
		menu = menu,
		slots = {},
		tabs = {},
		list = list,
		rowTemplate = rowTemplate,
		rows = {},
		countLabel = UiKit.authored(window, "Equipped.CountPanel.CountLabel", "TextLabel"),
		headerSub = UiKit.authored(window, "Header.HeaderSub", "TextLabel"),
		detailGroup = UiKit.authored(window, "DetailGroup", "TextLabel"),
		detailGlyph = UiKit.authored(detail, "Glyph", "TextLabel"),
		detailName = UiKit.authored(window, "DetailName", "TextLabel"),
		detailBlurb = UiKit.authored(window, "DetailBlurb", "TextLabel"),
		detailCost = UiKit.authored(window, "DetailCost", "TextLabel"),
		slotImage = attribute(slotsFrame, "SlotImage"),
		pickedImage = attribute(slotsFrame, "PickedImage"),
		tabImage = attribute(tabsFrame, "TabImage"),
		pickedTabImage = attribute(tabsFrame, "PickedTabImage"),
		group = ALL,
		loadout = table.clone(AbilityCatalog.DefaultLoadout),
		selected = 1,
		onChanged = nil,
	}
	local self = setmetatable(fields, AbilityPicker)

	if rowTemplate ~= nil then
		rowTemplate.Visible = false
	end

	for index = 1, AbilityCatalog.Slots do
		local button = UiKit.authored(slotsFrame, "Slot" .. index, "GuiButton")

		if button ~= nil then
			table.insert(fields.slots, {
				button = button,
				glyph = UiKit.child(button:FindFirstChild("Icon"), "Glyph", "TextLabel"),
				name = UiKit.child(button, "NameLabel", "TextLabel"),
				blurb = UiKit.child(button, "BlurbLabel", "TextLabel"),
			})
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.selected = index
				self:_describe(self.loadout[index])
				self:_paint()
			end)
		end
	end

	for index, group in TAB_GROUPS do
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")
		local tabLabel = if button ~= nil then UiKit.child(button, "TabLabel", "TextLabel") else nil

		for _, groupInfo in AbilityCatalog.Groups do
			if groupInfo.id == group and tabLabel ~= nil then
				tabLabel.TextColor3 = groupInfo.color
			end
		end

		if button ~= nil then
			table.insert(fields.tabs, { button = button, group = group })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self.group = group
				self:_buildGrid()
				self:_paint()
			end)
		end
	end

	for _, path in { "ReadyButton", "CloseButton" } do
		local button = UiKit.authored(window, path, "GuiButton")

		if button ~= nil then
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self:setVisible(false)
			end)
		end
	end

	local reset = UiKit.authored(window, "Equipped.ResetButton", "GuiButton")

	if reset ~= nil then
		UiKit.bindHover(reset)
		reset.Activated:Connect(function()
			self.loadout = table.clone(AbilityCatalog.DefaultLoadout)
			self.selected = 1
			self:_paint()
			self:_changed()
		end)
	end

	if list ~= nil then
		list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fitCanvas()
		end)
	end

	self:_buildGrid()
	self:_paint()
	self:_describe(self.loadout[1])

	return self
end

function AbilityPicker._visibleAbilities(self: AbilityPicker): { AbilityCatalog.Ability }
	local shown = {}

	for _, ability in AbilityCatalog.Abilities do
		if self.group == ALL or AbilityCatalog.groupOf(ability) == self.group then
			table.insert(shown, ability)
		end
	end

	return shown
end

-- One row per four abilities, cloned from the authored RowTemplate.
function AbilityPicker._buildGrid(self: AbilityPicker)
	local list, template = self.list, self.rowTemplate

	for _, row in self.rows do
		row:Destroy()
	end

	self.rows = {}

	if list == nil or template == nil then
		return
	end

	local abilities = self:_visibleAbilities()

	for rowIndex = 1, math.ceil(#abilities / CARDS_PER_ROW) do
		local row = template:Clone()
		row.Name = "Row" .. rowIndex
		row.LayoutOrder = rowIndex
		row.Visible = true

		for column = 1, CARDS_PER_ROW do
			local card = row:FindFirstChild("Card" .. column)
			local ability = abilities[(rowIndex - 1) * CARDS_PER_ROW + column]

			if card ~= nil and card:IsA("GuiButton") then
				self:_fillCard(card, ability)
			end
		end

		row.Parent = list
		table.insert(self.rows, row)
	end

	list.CanvasPosition = Vector2.zero
	-- New rows have no size until the next layout pass.
	task.defer(function()
		self:_fitCanvas()
	end)
end

function AbilityPicker._fillCard(self: AbilityPicker, card: GuiButton, ability: AbilityCatalog.Ability?)
	card.Visible = ability ~= nil

	if ability == nil then
		return
	end

	card:SetAttribute("AbilityId", ability.id)

	local glyph = UiKit.child(card:FindFirstChild("Icon"), "Glyph", "TextLabel")
	local name = UiKit.child(card, "NameLabel", "TextLabel")

	UiKit.setIcon(glyph, ability.glyph, ability.icon)

	if glyph ~= nil then
		glyph.TextColor3 = ability.color
	end

	if name ~= nil then
		name.Text = string.upper(ability.name)
	end

	tint(card, ability.color)

	UiKit.bindHover(card, function(active: boolean)
		if active then
			self:_describe(ability.id)
		end
	end)
	card.Activated:Connect(function()
		self:_choose(ability.id)
	end)
end

-- The rows keep their authored aspect, so the canvas is sized to hold them.
function AbilityPicker._fitCanvas(self: AbilityPicker)
	local list = self.list

	if list == nil then
		return
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")
	local height = 0

	if layout ~= nil then
		height = layout.AbsoluteContentSize.Y
	else
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				height += child.AbsoluteSize.Y + ROW_GAP
			end
		end
	end

	list.CanvasSize = UDim2.fromOffset(0, height)
end

function AbilityPicker._describe(self: AbilityPicker, id: string?)
	local ability = if id ~= nil then AbilityCatalog.get(id) else nil

	if ability == nil then
		return
	end

	UiKit.setIcon(self.detailGlyph, ability.glyph, ability.icon)

	if self.detailGlyph ~= nil then
		self.detailGlyph.TextColor3 = ability.color
	end

	if self.detailName ~= nil then
		self.detailName.Text = string.upper(ability.name)
	end

	if self.detailBlurb ~= nil then
		self.detailBlurb.Text = ability.blurb
	end

	if self.detailCost ~= nil then
		self.detailCost.Text = ("%d CHARGE  /  %dS COOLDOWN"):format(ability.cost, ability.cooldownSeconds)
	end

	if self.detailGroup ~= nil then
		local slot = table.find(self.loadout, ability.id)
		local groupId = AbilityCatalog.groupOf(ability)
		local groupName = ""

		for _, group in AbilityCatalog.Groups do
			if group.id == groupId then
				groupName = string.upper(group.name)
			end
		end

		self.detailGroup.Text = if slot ~= nil then ("%s  /  IN SLOT %d"):format(groupName, slot) else groupName
		self.detailGroup.TextColor3 = ability.color
	end
end

-- Puts id in the selected slot and moves on to the next. An ability already in a
-- slot picks that slot instead, so it can be swapped out from there.
function AbilityPicker._choose(self: AbilityPicker, id: string)
	local loadout = self.loadout
	local from = table.find(loadout, id)

	self:_describe(id)

	if from ~= nil then
		self.selected = from
		self:_paint()
		return
	end

	local filled = self.selected

	loadout[filled] = id
	self.selected = filled % AbilityCatalog.Slots + 1
	self:_paint()
	self:_popSlot(filled)
	self:_changed()
end

function AbilityPicker._popSlot(self: AbilityPicker, index: number)
	local slot = self.slots[index]

	if slot == nil then
		return
	end

	local scale = UiKit.scaleOf(slot.button, "Pop")
	scale.Scale = FILL_POP
	TweenService:Create(scale, TweenInfo.new(FILL_POP_SECONDS, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function AbilityPicker._changed(self: AbilityPicker)
	if self.onChanged ~= nil then
		self.onChanged(table.clone(self.loadout))
	end
end

function AbilityPicker._paint(self: AbilityPicker)
	for index, slot in self.slots do
		local ability = if self.loadout[index] ~= nil then AbilityCatalog.get(self.loadout[index]) else nil
		local image = if index == self.selected then self.pickedImage else self.slotImage

		if image ~= nil and slot.button:IsA("ImageButton") then
			UiKit.setImage(slot.button, image)
		end

		-- The slot art's tint, in the ability's group colour, is the resting look; the
		-- picked slot drops it.
		local gradient = slot.button:FindFirstChildOfClass("UIGradient")

		if gradient ~= nil then
			gradient.Enabled = index ~= self.selected

			if ability ~= nil then
				tint(slot.button, ability.color)
			end
		end

		UiKit.setIcon(slot.glyph, if ability ~= nil then ability.glyph else "", if ability ~= nil then ability.icon else nil)

		if slot.glyph ~= nil then
			slot.glyph.TextColor3 = if ability ~= nil then ability.color else CHARGE_COLOR
		end

		if slot.name ~= nil then
			slot.name.Text = if ability ~= nil then string.upper(ability.name) else "EMPTY"
		end

		if slot.blurb ~= nil then
			slot.blurb.Text = if ability ~= nil then ("%d CHARGE"):format(ability.cost) else ""
		end
	end

	for _, tab in self.tabs do
		local image = if tab.group == self.group then self.pickedTabImage else self.tabImage

		if image ~= nil and tab.button:IsA("ImageButton") then
			UiKit.setImage(tab.button, image)
		else
			UiKit.setLit(tab.button, tab.group == self.group)
		end
	end

	for _, row in self.rows do
		for _, card in row:GetChildren() do
			local id = card:GetAttribute("AbilityId")
			local ability = if type(id) == "string" then AbilityCatalog.get(id) else nil

			if ability ~= nil then
				local slotIndex = table.find(self.loadout, ability.id)
				local state = UiKit.child(card, "StateLabel", "TextLabel")
				local check = UiKit.child(card, "Check", "GuiObject")

				if state ~= nil then
					state.Text = if slotIndex ~= nil
						then ("SLOT %d"):format(slotIndex)
						else ("%d CHARGE"):format(ability.cost)
					state.TextColor3 = if slotIndex ~= nil then EQUIPPED_COLOR else CHARGE_COLOR
				end

				if check ~= nil then
					check.Visible = slotIndex ~= nil
				end
			end
		end
	end

	if self.countLabel ~= nil then
		self.countLabel.Text = ("%d/%d"):format(#self.loadout, AbilityCatalog.Slots)
	end

	if self.headerSub ~= nil then
		self.headerSub.Text = ("PICK AN ABILITY FOR SLOT %d"):format(self.selected)
	end
end

function AbilityPicker.setLoadout(self: AbilityPicker, loadout: { string })
	self.loadout = AbilityCatalog.sanitizeLoadout(loadout)
	self:_paint()
end

function AbilityPicker.bindChanged(self: AbilityPicker, callback: (loadout: { string }) -> ())
	self.onChanged = callback
end

function AbilityPicker.isVisible(self: AbilityPicker): boolean
	return self.menu:isOpen(WINDOW)
end

function AbilityPicker.setVisible(self: AbilityPicker, visible: boolean)
	if visible then
		self.menu:open(WINDOW)
		self:_describe(self.loadout[self.selected])
		task.defer(function()
			self:_fitCanvas()
		end)
	else
		self.menu:close(WINDOW)
	end
end

function AbilityPicker.toggle(self: AbilityPicker)
	self:setVisible(not self:isVisible())
end

return AbilityPicker
