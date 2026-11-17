local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local CosmeticBuilds = require(Shared:WaitForChild("CosmeticBuilds"))

-- Attaches procedural lowpoly visuals for equipped cosmetics to the player
-- character: lightstick or wand welded to the right hand, equalizer particle trail
-- while moving, subtle stage aura, plus simple BodyColors tints for the
-- jacket/shoes slots. Applied on equip and on character respawn.
local CosmeticVisualsService = {}
CosmeticVisualsService.__index = CosmeticVisualsService

local VISUALS_FOLDER_NAME = "DanceDanceStepCosmetics"

local TRAIL_COLORS = {
	Color3.fromRGB(86, 222, 255),
	Color3.fromRGB(255, 79, 178),
}
local AURA_COLOR = Color3.fromRGB(255, 211, 92)

function CosmeticVisualsService.new(playerDataService)
	return setmetatable({
		playerDataService = playerDataService,
		trailConnections = {},
	}, CosmeticVisualsService)
end

local function buildTrail(self, folder: Folder, character: Model, player: Player, colors: { Color3 }?)
	local torso = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if torso == nil or not torso:IsA("BasePart") or humanoid == nil then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "EqualizerTrail"
	attachment.Position = Vector3.new(0, -0.4, 0.6)
	attachment.Parent = torso

	local trail = Instance.new("ParticleEmitter")
	trail.Name = "EqualizerTrailEmitter"
	trail.Enabled = false
	trail.Rate = 22
	local palette = colors or TRAIL_COLORS
	trail.Color = ColorSequence.new(palette[1], palette[#palette])
	trail.LightEmission = 0.8
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = NumberRange.new(0.4, 0.7)
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.SpreadAngle = Vector2.new(12, 12)
	trail.Parent = attachment

	-- Trail only while the avatar is actually moving.
	self.trailConnections[player] = humanoid.Running:Connect(function(speed)
		trail.Enabled = speed > 0.5
	end)
end

local function buildAura(folder: Folder, character: Model, color: Color3?)
	local root = character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "StageAura"
	attachment.Position = Vector3.new(0, -2.2, 0)
	attachment.Parent = root

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "StageAuraEmitter"
	aura.Enabled = true
	aura.Rate = 6
	aura.Color = ColorSequence.new(color or AURA_COLOR)
	aura.LightEmission = 0.9
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new(0.45, 1)
	aura.Lifetime = NumberRange.new(0.9, 1.4)
	aura.Speed = NumberRange.new(1, 2)
	aura.SpreadAngle = Vector2.new(35, 35)
	aura.Acceleration = Vector3.new(0, 3, 0)
	aura.Parent = attachment
end

-- The avatar's own colours, kept on its BodyColors the first time a tint lands so
-- taking the item off can put them back.
local BASE_ATTRIBUTES = {
	TorsoColor3 = "BaseTorsoColor",
	LeftLegColor3 = "BaseLeftLegColor",
	RightLegColor3 = "BaseRightLegColor",
}

local function restoreBodyColors(character: Model)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")

	if bodyColors == nil then
		return
	end

	for property, attribute in BASE_ATTRIBUTES do
		local base = bodyColors:GetAttribute(attribute)

		if typeof(base) == "Color3" then
			(bodyColors :: any)[property] = base
		end
	end
end

local function applyBodyTint(character: Model, tint: { torso: Color3?, legs: Color3? })
	local bodyColors = character:FindFirstChildOfClass("BodyColors")

	if bodyColors == nil then
		return
	end

	for property, attribute in BASE_ATTRIBUTES do
		if bodyColors:GetAttribute(attribute) == nil then
			bodyColors:SetAttribute(attribute, (bodyColors :: any)[property])
		end
	end

	if tint.torso ~= nil then
		bodyColors.TorsoColor3 = tint.torso
	end

	if tint.legs ~= nil then
		bodyColors.LeftLegColor3 = tint.legs
		bodyColors.RightLegColor3 = tint.legs
	end
end

function CosmeticVisualsService:clear(player: Player)
	local connection = self.trailConnections[player]

	if connection ~= nil then
		connection:Disconnect()
		self.trailConnections[player] = nil
	end

	local character = player.Character

	if character ~= nil then
		local folder = character:FindFirstChild(VISUALS_FOLDER_NAME)

		if folder ~= nil then
			folder:Destroy()
		end

		for _, descendantName in { "EqualizerTrail", "StageAura" } do
			for _, child in character:GetDescendants() do
				if child.Name == descendantName and child:IsA("Attachment") then
					child:Destroy()
				end
			end
		end
	end
end

function CosmeticVisualsService:applyEquipped(player: Player)
	local character = player.Character
	local profile = self.playerDataService:get(player)

	if character == nil or profile == nil or type(profile.equipped) ~= "table" then
		return
	end

	if character:FindFirstChild("HumanoidRootPart") == nil then
		return
	end

	self:clear(player)
	restoreBodyColors(character)

	local folder = Instance.new("Folder")
	folder.Name = VISUALS_FOLDER_NAME
	folder.Parent = character

	for _, cosmeticId in profile.equipped do
		local item = CosmeticsCatalog.getItem(cosmeticId)

		if item == nil then
			continue
		end

		if CosmeticBuilds.HandProps[cosmeticId] ~= nil then
			CosmeticBuilds.buildHandProp(folder, character, cosmeticId)
		elseif item.category == "particle_trail" then
			buildTrail(self, folder, character, player, item.colors)
		elseif item.category == "aura" then
			buildAura(folder, character, if item.colors ~= nil then item.colors[1] else nil)
		elseif CosmeticBuilds.BodyTints[cosmeticId] ~= nil then
			applyBodyTint(character, CosmeticBuilds.BodyTints[cosmeticId])
		end
	end
end

return CosmeticVisualsService
