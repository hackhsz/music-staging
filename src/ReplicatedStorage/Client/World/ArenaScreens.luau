--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("LeaderboardConfig"))
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)
local HubBoards = require(script.Parent.HubBoards)

local Accent = ArenaPalette.Accent
local Surface = ArenaPalette.Surface

local SCREEN_X = 46
local SCREEN_BOTTOM = 9
local SCREEN_Z = -27
local SCREEN_SIZE = Vector3.new(30, 12, 1)
local LEG_OFFSET = 12
local ROWS_SHOWN = 5
local BOARD_MARGIN = 0.02
local BOARD_GAP = 0.04

local BOARD_TITLES = {
	weekly_perfect_beats = "WEEKLY PERFECTS",
	all_time_high_score = "ALL-TIME SCORE",
	all_time_level = "TOP LEVEL",
}

local HOW_TO_PLAY = {
	"ONE ARROW = ONE HOP",
	"LAND ON THE LIT TILE",
	"ON THE BEAT IS PERFECT",
	"GOLD TILES GIVE BONUS, RED TILES HURT",
}

type Column = {
	header: TextLabel,
	rows: { TextLabel },
	youRow: TextLabel,
}

local ArenaScreens = {}

export type ArenaScreens = {
	updateLeaderboard: (payload: any) -> (),
}

local function createGui(part: Part): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ScreenGui"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = part

	return gui
end

local function createLabel(parent: Instance, name: string, text: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent

	return label
end

-- A screen raised on two legs, so the crowd in front of the stage stays visible
-- beneath it.
local function addScreen(kit: ArenaKit.ArenaKit, name: string, x: number, trim: Color3): Part
	local centerY = SCREEN_BOTTOM + SCREEN_SIZE.Y / 2
	local screen = kit:box(name, SCREEN_SIZE, Vector3.new(x, centerY, SCREEN_Z), Surface.Void)

	kit:box(name .. "_trim", Vector3.new(SCREEN_SIZE.X + 1, 0.5, 1.4), Vector3.new(x, centerY + SCREEN_SIZE.Y / 2 + 0.25, SCREEN_Z + 0.2), trim, Enum.Material.Neon)

	for side = -1, 1, 2 do
		kit:box(("%s_leg_%s"):format(name, if side < 0 then "left" else "right"), Vector3.new(1, SCREEN_BOTTOM, 1), Vector3.new(x + side * LEG_OFFSET, SCREEN_BOTTOM / 2, SCREEN_Z), Surface.Structure)
	end

	return screen
end

local function addBoardColumns(gui: Instance)
	local count = #LeaderboardConfig.Boards
	local slot = (1 - BOARD_MARGIN * 2) / math.max(count, 1)

	for index, board in LeaderboardConfig.Boards do
		if gui:FindFirstChild("Board_" .. board.id) ~= nil then
			continue
		end

		local column = Instance.new("Frame")
		column.Name = "Board_" .. board.id
		column.BackgroundTransparency = 1
		column.Position = UDim2.fromScale(BOARD_MARGIN + (index - 1) * slot, 0.16)
		column.Size = UDim2.fromScale(slot - BOARD_GAP, 0.82)
		column.Parent = gui

		createLabel(
			column,
			"Header",
			BOARD_TITLES[board.id] or string.upper(board.displayName),
			if index == 1 then Accent.Pink else Accent.Lilac,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 0.12)
		)

		for rowIndex = 1, ROWS_SHOWN do
			local row = createLabel(
				column,
				("Row_%02d"):format(rowIndex),
				("%d  ---"):format(rowIndex),
				Accent.White,
				UDim2.fromScale(0, 0.14 + (rowIndex - 1) * 0.13),
				UDim2.fromScale(1, 0.115)
			)
			row.TextXAlignment = Enum.TextXAlignment.Left
		end

		local youRow = createLabel(column, "You", "YOU  PLAY TO RANK", Accent.Gold, UDim2.fromScale(0, 0.82), UDim2.fromScale(1, 0.13))
		youRow.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function addLeaderboard(screen: Part)
	local gui = createGui(screen)

	createLabel(gui, "Title", "STAR RANKINGS", Accent.Gold, UDim2.fromScale(0.02, 0.02), UDim2.fromScale(0.96, 0.12))
	addBoardColumns(gui)
end

local function addHowToPlay(screen: Part)
	local gui = createGui(screen)

	createLabel(gui, "Title", "HOW TO PLAY", Accent.Gold, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.14))

	for index, line in HOW_TO_PLAY do
		createLabel(
			gui,
			("Line_%d"):format(index),
			("%d  %s"):format(index, line),
			if index == #HOW_TO_PLAY then Accent.Pink else Accent.White,
			UDim2.fromScale(0.05, 0.22 + (index - 1) * 0.18),
			UDim2.fromScale(0.9, 0.13)
		).TextXAlignment = Enum.TextXAlignment.Left
	end
end

-- Two screens either side of the floor: the rankings on the left, a reminder of
-- the one rule of the game on the right. Both face the camera.
function ArenaScreens.build(kit: ArenaKit.ArenaKit)
	kit:section("Screens")
	addLeaderboard(addScreen(kit, "leaderboard_screen", -SCREEN_X, Accent.Pink))
	addHowToPlay(addScreen(kit, "how_to_play_screen", SCREEN_X, Accent.Lilac))
end

local function findColumns(arena: Instance): { [string]: Column }
	local columns: { [string]: Column } = {}
	local screen = ArenaKit.findPart(arena, "leaderboard_screen")
	if screen == nil then
		return columns
	end

	local gui = screen:FindFirstChild("ScreenGui")

	if gui == nil then
		addLeaderboard(screen)
		gui = screen:FindFirstChild("ScreenGui")
	else
		addBoardColumns(gui)
	end

	if gui == nil then
		return columns
	end

	for _, board in LeaderboardConfig.Boards do
		local frame = gui:FindFirstChild("Board_" .. board.id)
		local header = if frame ~= nil then frame:FindFirstChild("Header") else nil
		local youRow = if frame ~= nil then frame:FindFirstChild("You") else nil

		if frame == nil or header == nil or youRow == nil then
			continue
		end

		local rows: { TextLabel } = {}

		for rowIndex = 1, ROWS_SHOWN do
			local row = frame:FindFirstChild(("Row_%02d"):format(rowIndex))

			if row ~= nil and row:IsA("TextLabel") then
				rows[rowIndex] = row
			end
		end

		columns[board.id] = { header = header :: TextLabel, rows = rows, youRow = youRow :: TextLabel }
	end

	return columns
end

function ArenaScreens.bind(arena: Instance): ArenaScreens
	local columns = findColumns(arena)

	local function updateLeaderboard(payload: any)
		if type(payload) ~= "table" or type(payload.boards) ~= "table" then
			return
		end

		for _, board in payload.boards do
			local column = columns[board.id]

			if column == nil then
				continue
			end

			if board.periodKey ~= nil then
				column.header.Text = ("%s  %s"):format(BOARD_TITLES[board.id] or string.upper(board.displayName or board.id), board.periodKey)
			end

			for rowIndex, row in column.rows do
				local entry = if type(board.entries) == "table" then board.entries[rowIndex] else nil

				if entry ~= nil then
					row.Text = ("%d  %s  %s"):format(
						entry.rank or rowIndex,
						string.upper(tostring(entry.name or "?")),
						HubBoards.formatValue(board.metric, entry.value)
					)
				else
					row.Text = ("%d  ---"):format(rowIndex)
				end
			end

			local you = board.you

			if you == nil then
				column.youRow.Text = "YOU  PLAY TO RANK"
			elseif you.rank ~= nil then
				column.youRow.Text = ("YOU  RANK %d  %s"):format(you.rank, HubBoards.formatValue(board.metric, you.value))
			else
				column.youRow.Text = ("YOU  %s  RANK 100+"):format(HubBoards.formatValue(board.metric, you.value))
			end
		end
	end

	return { updateLeaderboard = updateLeaderboard }
end

return ArenaScreens
