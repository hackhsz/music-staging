--!strict
local ArenaPalette = require(script.Parent.ArenaPalette)

export type Quality = {
	maxSpotlights: number,
	maxStagePointLights: number,
	equalizerBars: number,
	audiencePods: number,
	standFans: number,
	-- The share of the painted crowd's seats that are filled, 0 to 1.
	crowdWallFill: number,
}

type Fields = {
	root: Instance,
	folder: Instance,
	quality: Quality,
	partCount: number,
	spotlightCount: number,
	pointLightCount: number,
}

-- Builds the arena's parts and lights into folders and keeps count, so a scene
-- can be checked against PerformanceBudget. Parts are anchored, non-colliding
-- and axis-aligned; nothing here tilts or slopes. Every part has a unique name,
-- because the runtime finds them again by name.
local ArenaKit = {}
ArenaKit.__index = ArenaKit

export type ArenaKit = typeof(setmetatable({} :: Fields, ArenaKit))

function ArenaKit.new(root: Instance, quality: Quality): ArenaKit
	local fields: Fields = {
		root = root,
		folder = root,
		quality = quality,
		partCount = 0,
		spotlightCount = 0,
		pointLightCount = 0,
	}

	return setmetatable(fields, ArenaKit)
end

-- Everything built after this goes into a folder of this name under the root.
function ArenaKit.section(self: ArenaKit, name: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = self.root
	self.folder = folder
end

-- The part with this name anywhere under the arena, if it is still there.
function ArenaKit.findPart(arena: Instance, name: string): Part?
	local found = arena:FindFirstChild(name, true)

	if found ~= nil and found:IsA("Part") then
		return found
	end

	return nil
end

function ArenaKit.box(self: ArenaKit, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	self.partCount += 1

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = self.folder

	return part
end

function ArenaKit.ball(self: ArenaKit, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = self:box(name, Vector3.new(diameter, diameter, diameter), position, color, material)
	part.Shape = Enum.PartType.Ball

	return part
end

-- A flat disc lying on the floor or stage.
function ArenaKit.disc(self: ArenaKit, name: string, diameter: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = self:box(name, Vector3.new(thickness, diameter, diameter), position, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)

	return part
end

-- A part that only carries a light and is never seen.
function ArenaKit.anchor(self: ArenaKit, name: string, position: Vector3): Part
	local part = self:box(name, Vector3.new(1, 1, 1), position, ArenaPalette.Surface.Void)
	part.Transparency = 1

	return part
end

function ArenaKit.spotlight(self: ArenaKit, parent: BasePart, color: Color3, brightness: number): SpotLight?
	if self.spotlightCount >= self.quality.maxSpotlights then
		return nil
	end

	self.spotlightCount += 1

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 52
	light.Brightness = brightness
	light.Range = 42
	light.Color = color
	light.Shadows = false
	light.Parent = parent

	return light
end

function ArenaKit.pointLight(self: ArenaKit, parent: Instance, color: Color3, brightness: number, range: number): PointLight?
	if self.pointLightCount >= self.quality.maxStagePointLights then
		return nil
	end

	self.pointLightCount += 1

	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Shadows = false
	light.Parent = parent

	return light
end

-- A title and an optional subtitle printed on the face of a part that looks toward
-- the camera (+Z, which Roblox calls Back). A band
-- height keeps the title to the top of a tall part instead of filling it.
function ArenaKit.signText(part: Part, title: string, subtitle: string?, titleColor: Color3, bandHeight: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.Size = UDim2.fromScale(1, bandHeight or (if subtitle ~= nil then 0.6 else 1))
	titleLabel.Position = UDim2.fromScale(0, if bandHeight ~= nil then 0.03 elseif subtitle ~= nil then 0.08 else 0)
	titleLabel.Text = title
	titleLabel.TextColor3 = titleColor
	titleLabel.TextScaled = true
	titleLabel.Parent = gui

	if subtitle ~= nil then
		local subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Font = Enum.Font.Arcade
		subtitleLabel.Size = UDim2.fromScale(1, 0.22)
		subtitleLabel.Position = UDim2.fromScale(0, 0.72)
		subtitleLabel.Text = subtitle
		subtitleLabel.TextColor3 = ArenaPalette.Accent.Lilac
		subtitleLabel.TextScaled = true
		subtitleLabel.Parent = gui
	end
end

return ArenaKit
