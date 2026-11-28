--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiKit = require(script.Parent.Parent.UI.UiKit)

local BOARD_TAG = "LeaderboardBoard"
local ROWS_SHOWN = 10
local EMPTY_NAME = "---"
local ALL_TIME_TEXT = "ALL TIME"
local HEADSHOT_URL = "rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"
local HIGHLIGHTED_LABELS = { "Rank", "Name", "Value" }

-- The leaderboards on the hub island: SurfaceGuis authored in Studio, tagged
-- LeaderboardBoard with the LeaderboardId they show. The island streams in, so a
-- board that arrives late is drawn from the last payload.
local HubBoards = {}
HubBoards.__index = HubBoards

type Fields = {
	payload: any,
}

export type HubBoards = typeof(setmetatable({} :: Fields, HubBoards))

local authoredColors: { [TextLabel]: Color3 } = setmetatable({}, { __mode = "k" }) :: any

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	return (formatted:gsub("^,", ""))
end

function HubBoards.formatValue(metric: string?, value: number?): string
	local amount = tonumber(value) or 0

	if metric == "xp" then
		return ("%d XP"):format(amount)
	end

	return withCommas(amount)
end

local function setText(parent: Instance?, name: string, text: string)
	local label = if parent ~= nil then parent:FindFirstChild(name, true) else nil

	if label ~= nil and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setHighlighted(row: Instance, highlighted: boolean)
	for _, name in HIGHLIGHTED_LABELS do
		local label = row:FindFirstChild(name, true)

		if label == nil or not label:IsA("TextLabel") then
			continue
		end

		local authored = authoredColors[label]

		if authored == nil then
			authored = label.TextColor3
			authoredColors[label] = authored
		end

		label.TextColor3 = if highlighted then UiKit.Colors.Yellow else authored
	end
end

local function setAvatar(row: Instance, userId: number?)
	local avatar = row:FindFirstChild("Avatar", true)

	if avatar == nil or not avatar:IsA("ImageLabel") then
		return
	end

	avatar.Image = if userId ~= nil and userId > 0 then HEADSHOT_URL:format(userId) else ""
end

local function draw(gui: Instance, board: any)
	setText(gui, "Period", if board.periodKey ~= nil then "WEEK " .. string.gsub(board.periodKey, "^%d+%-W", "") else ALL_TIME_TEXT)

	local localUserId = if Players.LocalPlayer ~= nil then Players.LocalPlayer.UserId else nil

	for index = 1, ROWS_SHOWN do
		local row = gui:FindFirstChild(("Row%02d"):format(index), true)
		local entry = if type(board.entries) == "table" then board.entries[index] else nil

		if row == nil then
			continue
		end

		local userId = if entry ~= nil then tonumber(entry.userId) else nil

		setText(row, "Rank", tostring(if entry ~= nil then entry.rank or index else index))
		setText(row, "Name", if entry ~= nil then string.upper(tostring(entry.name or "?")) else EMPTY_NAME)
		setText(row, "Value", if entry ~= nil then HubBoards.formatValue(board.metric, entry.value) else "")
		setHighlighted(row, userId ~= nil and userId == localUserId)
		setAvatar(row, userId)
	end

	local you = board.you
	local youRow = gui:FindFirstChild("You", true)

	if you == nil then
		setText(youRow, "Rank", "-")
		setText(youRow, "Value", "PLAY TO RANK")
	else
		setText(youRow, "Rank", if you.rank ~= nil then "#" .. you.rank else "100+")
		setText(youRow, "Value", HubBoards.formatValue(board.metric, you.value))
	end
end

function HubBoards.new(): HubBoards
	local self = setmetatable({ payload = nil } :: Fields, HubBoards)

	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(gui)
		self:_drawOne(gui)
	end)

	return self
end

function HubBoards._drawOne(self: HubBoards, gui: Instance)
	if type(self.payload) ~= "table" or type(self.payload.boards) ~= "table" then
		return
	end

	for _, board in self.payload.boards do
		if board.id == gui:GetAttribute("LeaderboardId") then
			draw(gui, board)
		end
	end
end

function HubBoards.update(self: HubBoards, payload: any)
	self.payload = payload

	for _, gui in CollectionService:GetTagged(BOARD_TAG) do
		self:_drawOne(gui)
	end
end

return HubBoards
