--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("EmoteCatalog"))

local PODIUM_TAG = "LeaderboardPodium"
local STATUE_NAME = "PodiumStatue"
local LABEL_NAME = "PodiumLabel"
local LABEL_SIZE = UDim2.fromScale(8, 2.4)
local LABEL_OFFSET = Vector3.new(0, 3, 0)
local LABEL_MAX_DISTANCE = 120
local PLACE_NAMES = { "1ST", "2ND", "3RD" }
-- The looped catalog dance each place does on its podium.
local RANK_DANCES = { "signature-step-001", "fever-groove-001", "signature-step-001" }
-- Who an empty podium shows; no real player has user id 0.
local PLACEHOLDER_USER_ID = 0
local PLACEHOLDER_TEXT = "PLAY TO RANK"
local SILHOUETTE_COLOR = Color3.fromRGB(70, 50, 120)
local SILHOUETTE_TRANSPARENCY = 0.35

type Entry = { userId: number, name: string, value: number }

type Fields = {
	shownUserIds: { [Instance]: number },
}

-- The top three of a board stand on the hub's podiums as copies of their avatars,
-- dancing. A podium is any part tagged LeaderboardPodium, with a PodiumRank (1 to
-- 3), the LeaderboardId it shows, and a Facing direction for the statue. A place
-- nobody holds yet shows a silhouette asking players to rank.
local PodiumService = {}
PodiumService.__index = PodiumService

export type PodiumService = typeof(setmetatable({} :: Fields, PodiumService))

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	return (formatted:gsub("^,", ""))
end

local function addLabel(statue: Model, rank: number, entry: Entry)
	local head = statue:FindFirstChild("Head")

	if head == nil then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = LABEL_SIZE
	gui.StudsOffset = LABEL_OFFSET
	gui.MaxDistance = LABEL_MAX_DISTANCE
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = if entry.userId == PLACEHOLDER_USER_ID
		then ("%s\n%s"):format(PLACE_NAMES[rank] or "", PLACEHOLDER_TEXT)
		else ("%s  %s\n%s"):format(PLACE_NAMES[rank] or "", string.upper(entry.name), withCommas(entry.value))
	label.Parent = gui

	gui.Parent = head
end

-- A faceless, see-through rig for a place nobody holds yet.
local function makeSilhouette(statue: Model)
	for _, item in statue:GetDescendants() do
		if item:IsA("Decal") or item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Color = SILHOUETTE_COLOR
			item.Material = Enum.Material.SmoothPlastic
			item.Transparency = if item.Name == "HumanoidRootPart" then 1 else SILHOUETTE_TRANSPARENCY
		end
	end
end

-- The root is anchored and the limbs hang off it on their joints, so the statue
-- stays put while its dance moves the limbs.
local function dance(humanoid: Humanoid, rank: number)
	local emote = EmoteCatalog.getEmote(RANK_DANCES[rank] or "")

	if emote == nil or emote.animationId == nil then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. emote.animationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok and track ~= nil then
		track.Looped = true
		track:Play()
	else
		warn(("[DanceDanceStep] Podium dance did not load: %s"):format(tostring(track)))
	end
end

local function buildStatue(podium: BasePart, rank: number, entry: Entry): Model?
	local placeholder = entry.userId == PLACEHOLDER_USER_ID
	local ok, statue = pcall(function()
		if placeholder then
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end

		return Players:CreateHumanoidModelFromUserIdAsync(entry.userId)
	end)

	if not ok or statue == nil then
		warn(("[DanceDanceStep] Could not build a podium statue for %d: %s"):format(entry.userId, tostring(statue)))
		return nil
	end

	statue.Name = STATUE_NAME

	for _, part in statue:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide = false
		end
	end

	if placeholder then
		makeSilhouette(statue)
	end

	local humanoid = statue:FindFirstChildOfClass("Humanoid")

	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local facing = podium:GetAttribute("Facing")
	local direction = if typeof(facing) == "Vector3" and facing.Magnitude > 0 then facing.Unit else podium.CFrame.LookVector
	local topY = podium.Position.Y + podium.Size.Y / 2

	statue:PivotTo(CFrame.lookAt(podium.Position, podium.Position + Vector3.new(direction.X, 0, direction.Z)))

	local box, size = statue:GetBoundingBox()
	statue:PivotTo(statue:GetPivot() + Vector3.new(0, topY - (box.Position.Y - size.Y / 2), 0))

	addLabel(statue, rank, entry)
	statue.Parent = podium

	if humanoid ~= nil and not placeholder then
		dance(humanoid, rank)
	end

	return statue
end

function PodiumService.new(): PodiumService
	return setmetatable({ shownUserIds = {} } :: Fields, PodiumService)
end

-- snapshot is LeaderboardService:buildSnapshot(). A podium only rebuilds when
-- its player changes; a new value just relabels the statue.
function PodiumService.update(self: PodiumService, snapshot: any)
	local boards = {}

	for _, board in snapshot.boards do
		boards[board.id] = board
	end

	for _, podium in CollectionService:GetTagged(PODIUM_TAG) do
		local rank = podium:GetAttribute("PodiumRank")

		if not podium:IsA("BasePart") or type(rank) ~= "number" then
			continue
		end

		local board = boards[podium:GetAttribute("LeaderboardId")]
		local entry: Entry = if board ~= nil and board.entries[rank] ~= nil
			then board.entries[rank]
			else { userId = PLACEHOLDER_USER_ID, name = "", value = 0 }
		local current = podium:FindFirstChild(STATUE_NAME)

		if current ~= nil and self.shownUserIds[podium] == entry.userId then
			local label = current:FindFirstChild(LABEL_NAME, true)

			if label ~= nil then
				label:Destroy()
			end

			addLabel(current :: Model, rank, entry)
			continue
		end

		if current ~= nil then
			current:Destroy()
		end

		self.shownUserIds[podium] = entry.userId
		task.spawn(buildStatue, podium, rank, entry)
	end
end

return PodiumService
