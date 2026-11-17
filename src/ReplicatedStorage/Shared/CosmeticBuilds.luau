--!strict
-- How an equipped cosmetic looks on a character. The server puts these on the
-- real avatar (CosmeticVisualsService); the shop puts the same ones on its preview
-- copy, so trying an item on shows exactly what wearing it will.
local CosmeticBuilds = {}

-- Along the stick from the fist: the handle sits a little back inside the hand.
local LIGHTSTICK = { handleSize = Vector3.new(0.3, 1.2, 0.3), handleReach = 0.35, tipReach = 1.25, tipScale = 1 }
local WAND = { handleSize = Vector3.new(0.15, 1.6, 0.15), handleReach = 0.45, tipReach = 1.4, tipScale = 0.7 }
-- A star tip is a flat disc standing on edge, so it reads from the side.
local STAR_TIP_SIZE = Vector3.new(0.25, 1, 1)
local ORB_TIP_SIZE = Vector3.new(0.7, 0.7, 0.7)
local HAND_PROP_FOLDER = "HandProp"

type HandShape = { handleSize: Vector3, handleReach: number, tipReach: number, tipScale: number }
type HandProp = { shape: HandShape, tip: "star" | "orb", handle: Color3, glow: Color3 }

-- Everything held in the hand, one at a time: the glow_stick slot.
CosmeticBuilds.HandProps = {
	["lemon-lightstick-001"] = {
		shape = LIGHTSTICK,
		tip = "star",
		handle = Color3.fromRGB(255, 248, 235),
		glow = Color3.fromRGB(255, 230, 110),
	},
	["mint-wand-001"] = {
		shape = WAND,
		tip = "orb",
		handle = Color3.fromRGB(255, 248, 235),
		glow = Color3.fromRGB(150, 235, 200),
	},
	["sunset-wand-001"] = {
		shape = WAND,
		tip = "star",
		handle = Color3.fromRGB(255, 214, 180),
		glow = Color3.fromRGB(255, 140, 90),
	},
	["midnight-wand-001"] = {
		shape = WAND,
		tip = "orb",
		handle = Color3.fromRGB(60, 50, 110),
		glow = Color3.fromRGB(170, 140, 255),
	},
	["gold-wand-001"] = {
		shape = WAND,
		tip = "star",
		handle = Color3.fromRGB(255, 225, 150),
		glow = Color3.fromRGB(255, 205, 90),
	},
} :: { [string]: HandProp }

-- Jacket and shoes have no prop yet; they tint body groups instead.
CosmeticBuilds.BodyTints = {
	["idol-jacket-001"] = { torso = Color3.fromRGB(255, 248, 235) },
	["pixel-sneakers-001"] = { legs = Color3.fromRGB(255, 179, 217) },
} :: { [string]: { torso: Color3?, legs: Color3? } }

local TORSO_PARTS = { "UpperTorso", "LowerTorso", "Torso" }
local LEG_PARTS = {
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Leg",
	"Right Leg",
}

local function makePart(folder: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = folder

	return part
end

local function weldTo(part: Part, target: BasePart, offset: CFrame)
	part.CFrame = target.CFrame * offset

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

-- Held like a tool: out of the fist (the rig's grip point, which on R6 is the
-- bottom of the whole arm part) and pointing forward along the hand. Replaces
-- whatever the character already holds.
function CosmeticBuilds.buildHandProp(folder: Instance, character: Model, cosmeticId: string)
	local prop = CosmeticBuilds.HandProps[cosmeticId]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")

	if prop == nil or hand == nil or not hand:IsA("BasePart") then
		return
	end

	for _, descendant in character:GetDescendants() do
		if descendant.Name == HAND_PROP_FOLDER and descendant:IsA("Folder") then
			descendant:Destroy()
		end
	end

	local holder = Instance.new("Folder")
	holder.Name = HAND_PROP_FOLDER
	holder.Parent = folder

	local grip = hand:FindFirstChild("RightGripAttachment")
	local fist = if grip ~= nil and grip:IsA("Attachment") then CFrame.new(grip.Position) else CFrame.new()
	local along = fist * CFrame.Angles(math.rad(-90), 0, 0)
	local shape = prop.shape

	local handle = makePart(holder, "handle", shape.handleSize, prop.handle)
	weldTo(handle, hand, along * CFrame.new(0, shape.handleReach, 0))

	local tipAt = along * CFrame.new(0, shape.tipReach, 0)
	local tip: Part

	if prop.tip == "orb" then
		tip = makePart(holder, "tip", ORB_TIP_SIZE * shape.tipScale, prop.glow, Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
		weldTo(tip, hand, tipAt)
	else
		tip = makePart(holder, "tip_a", STAR_TIP_SIZE * shape.tipScale, prop.glow, Enum.Material.Neon)
		weldTo(tip, hand, tipAt)

		local tipB = makePart(holder, "tip_b", STAR_TIP_SIZE * shape.tipScale, prop.glow, Enum.Material.Neon)
		weldTo(tipB, hand, tipAt * CFrame.Angles(math.rad(45), 0, 0))
	end

	local glow = Instance.new("PointLight")
	glow.Brightness = 0.8
	glow.Range = 9
	glow.Color = prop.glow
	glow.Shadows = false
	glow.Parent = tip
end

-- Paints a tint straight onto the parts, for a copy that BodyColors does not reach.
function CosmeticBuilds.paintTint(character: Model, cosmeticId: string)
	local tint = CosmeticBuilds.BodyTints[cosmeticId]

	if tint == nil then
		return
	end

	for _, group in { { names = TORSO_PARTS, color = tint.torso }, { names = LEG_PARTS, color = tint.legs } } do
		local color: Color3? = group.color

		if color ~= nil then
			for _, name in group.names do
				local part = character:FindFirstChild(name)

				if part ~= nil and part:IsA("BasePart") then
					part.Color = color
				end
			end
		end
	end
end

return CosmeticBuilds
