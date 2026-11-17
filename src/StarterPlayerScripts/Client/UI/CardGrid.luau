--!strict
local UiKit = require(script.Parent.UiKit)

local CARDS_PER_ROW = 4
local ROW_GAP = 6
local PICKED_TINT = Color3.fromRGB(255, 170, 255)
local RESTING_TINT = Color3.new(1, 1, 1)

type Fields = {
	list: ScrollingFrame?,
	template: GuiObject?,
	rows: { GuiObject },
}

-- Rows of cards cloned from an authored RowTemplate (Card1 to Card4) inside a
-- scrolling list, as the shop draws them. A card's index is kept on it, so the
-- picked one can be tinted.
local CardGrid = {}
CardGrid.__index = CardGrid

export type CardGrid = typeof(setmetatable({} :: Fields, CardGrid))

function CardGrid.new(list: ScrollingFrame?, template: GuiObject?): CardGrid
	local self = setmetatable({ list = list, template = template, rows = {} } :: Fields, CardGrid)

	if template ~= nil then
		template.Visible = false
	end

	if list ~= nil then
		list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:fitCanvas()
		end)
	end

	return self
end

function CardGrid.build(self: CardGrid, count: number, fill: (card: GuiButton, index: number) -> ())
	local list, template = self.list, self.template

	for _, row in self.rows do
		row:Destroy()
	end

	self.rows = {}

	if list == nil or template == nil then
		return
	end

	for rowIndex = 1, math.ceil(count / CARDS_PER_ROW) do
		local row = template:Clone()
		row.Name = "Row" .. rowIndex
		row.LayoutOrder = rowIndex
		row.Visible = true

		for column = 1, CARDS_PER_ROW do
			local card = row:FindFirstChild("Card" .. column)
			local index = (rowIndex - 1) * CARDS_PER_ROW + column

			if card ~= nil and card:IsA("GuiButton") then
				card.Visible = index <= count

				if index <= count then
					card:SetAttribute("Index", index)
					UiKit.bindHover(card)
					fill(card, index)
				end
			end
		end

		row.Parent = list
		table.insert(self.rows, row)
	end

	-- New rows have no size until the next layout pass.
	task.defer(function()
		self:fitCanvas()
	end)
end

function CardGrid.paintPicked(self: CardGrid, picked: number?)
	for _, row in self.rows do
		for _, card in row:GetChildren() do
			if card:IsA("ImageButton") then
				card.ImageColor3 = if card:GetAttribute("Index") == picked then PICKED_TINT else RESTING_TINT
			end
		end
	end
end

function CardGrid.fitCanvas(self: CardGrid)
	local list = self.list

	if list == nil then
		return
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")
	local padding = list:FindFirstChildOfClass("UIPadding")
	local height = 0

	-- The layout knows the real height, gaps included.
	if layout ~= nil then
		height = layout.AbsoluteContentSize.Y
	else
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				height += child.AbsoluteSize.Y + ROW_GAP
			end
		end
	end

	if padding ~= nil then
		height += padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	end

	list.CanvasSize = UDim2.fromOffset(0, height)
end

return CardGrid
