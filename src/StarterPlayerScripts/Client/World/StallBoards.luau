--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UGCCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("UGCCatalog"))
local MarketPanel = require(script.Parent.Parent.UI.Screens.MarketPanel)
local UiKit = require(script.Parent.Parent.UI.UiKit)

local BOARD_NAME = "StallBoard"
local BOARD_SIZE = UDim2.fromOffset(320, 120)
local BOARD_OFFSET = Vector3.new(0, 9, 0)
local BOARD_MAX_DISTANCE = 140
local FREE_TEXT = "FREE STALL - CLAIM IT!"

type Stall = MarketPanel.Stall

-- A sign over each market stall on the islands: who holds it (or that it is free)
-- and a row of what it sells. Drawn from the same stall list as the Market window;
-- the islands stream in, so a stall that arrives late is drawn on the next render.
local StallBoards = {}
StallBoards.__index = StallBoards

export type StallBoards = typeof(setmetatable({} :: { stalls: { Stall } }, StallBoards))

function StallBoards.new(): StallBoards
	local self = setmetatable({ stalls = {} }, StallBoards)

	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == UGCCatalog.AnchorName then
			self:render(self.stalls)
		end
	end)

	return self
end

local function anchors(): { [string]: BasePart }
	local found = {}
	local stations = Workspace:FindFirstChild(UGCCatalog.StationsFolder)

	for _, station in if stations ~= nil then stations:GetChildren() else {} do
		local stallId = station:GetAttribute(UGCCatalog.StallAttribute)
		local anchor = station:FindFirstChild(UGCCatalog.AnchorName, true)

		if type(stallId) == "string" and anchor ~= nil and anchor:IsA("BasePart") then
			found[stallId] = anchor
		end
	end

	return found
end

local function build(anchor: BasePart): BillboardGui
	local board = UiKit.create("BillboardGui", {
		Name = BOARD_NAME,
		Size = BOARD_SIZE,
		StudsOffset = BOARD_OFFSET,
		MaxDistance = BOARD_MAX_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
	}, anchor)
	local panel = UiKit.create("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UiKit.Colors.Deep,
		BackgroundTransparency = 0.2,
	}, board)

	UiKit.create("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	UiKit.create("UIStroke", { Color = UiKit.Colors.Fever, Thickness = 2 }, panel)
	UiKit.create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -16, 0.38, 0),
		Position = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		FontFace = UiKit.FontFace,
		TextScaled = true,
		TextColor3 = UiKit.Colors.White,
	}, panel)

	local row = UiKit.create("Frame", {
		Name = "Items",
		Size = UDim2.new(1, -16, 0.5, 0),
		Position = UDim2.new(0, 8, 0.44, 0),
		BackgroundTransparency = 1,
	}, panel)

	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
	}, row)

	for index = 1, UGCCatalog.MaxListings do
		local icon = UiKit.create("ImageLabel", {
			Name = "Icon" .. index,
			Size = UDim2.fromScale(0.115, 1),
			BackgroundColor3 = UiKit.Colors.Track,
			LayoutOrder = index,
			Visible = false,
		}, row)

		UiKit.create("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
		UiKit.create("UICorner", { CornerRadius = UDim.new(0, 6) }, icon)
	end

	return board
end

function StallBoards.render(self: StallBoards, stalls: { Stall })
	self.stalls = stalls

	local found = anchors()

	for _, stall in stalls do
		local anchor = found[stall.id]

		if anchor == nil then
			continue
		end

		local board = anchor:FindFirstChild(BOARD_NAME) or build(anchor)
		local title = board:FindFirstChild("Title", true)

		if title ~= nil and title:IsA("TextLabel") then
			title.Text = if stall.owner ~= nil then string.upper(stall.owner) .. "'S STALL" else FREE_TEXT
			title.TextColor3 = if stall.mine then UiKit.Colors.Yellow else UiKit.Colors.White
		end

		local shown = {}

		for _, item in stall.items do
			if item.forSale then
				table.insert(shown, item)
			end
		end

		for index = 1, UGCCatalog.MaxListings do
			local icon = board:FindFirstChild("Icon" .. index, true)
			local item = shown[index]

			if icon ~= nil and icon:IsA("ImageLabel") then
				icon.Visible = item ~= nil and item.icon ~= nil
				icon.Image = if item ~= nil and item.icon ~= nil then item.icon else ""
			end
		end
	end
end

return StallBoards
