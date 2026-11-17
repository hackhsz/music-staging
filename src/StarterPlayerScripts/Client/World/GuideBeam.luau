--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UiKit = require(script.Parent.Parent.UI.UiKit)

local MARKER_LIFT = Vector3.new(0, 7, 0)
local MARKER_SIZE = UDim2.fromOffset(220, 70)
local BEAM_WIDTH = 0.6
local BEAM_TEXTURE_SPEED = 2
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

type Fields = {
	target: Vector3?,
	label: string,
	anchor: Part?,
	from: Attachment?,
	beam: Beam?,
}

-- A glowing beam from the local character to a spot on the island, with a name
-- floating over the spot, for the walkthrough to lead the way. Drawing only.
local GuideBeam = {}
GuideBeam.__index = GuideBeam

export type GuideBeam = typeof(setmetatable({} :: Fields, GuideBeam))

function GuideBeam.new(): GuideBeam
	local self = setmetatable({
		target = nil,
		label = "",
		anchor = nil,
		from = nil,
		beam = nil,
	} :: Fields, GuideBeam)

	Players.LocalPlayer.CharacterAdded:Connect(function()
		if self.target ~= nil then
			self:pointTo(self.target, self.label)
		end
	end)

	return self
end

local function buildAnchor(position: Vector3, label: string): Part
	local anchor = Instance.new("Part")
	anchor.Name = "DanceDanceStepGuide"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position

	local marker = Instance.new("BillboardGui")
	marker.Name = "Marker"
	marker.AlwaysOnTop = true
	marker.Size = MARKER_SIZE
	marker.StudsOffsetWorldSpace = MARKER_LIFT
	marker.Parent = anchor

	local text = UiKit.label(marker, "Label", "▼ " .. label, UiKit.Colors.Yellow, {
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
	})
	UiKit.create("UIStroke", { Color = UiKit.Colors.Fever, Thickness = 2 }, text)

	Instance.new("Attachment", anchor).Name = "To"
	anchor.Parent = Workspace

	return anchor
end

function GuideBeam.pointTo(self: GuideBeam, position: Vector3, label: string)
	self:clear()
	self.target = position
	self.label = label

	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local anchor = buildAnchor(position, label)
	self.anchor = anchor

	if root == nil or not root:IsA("BasePart") then
		return
	end

	local from = Instance.new("Attachment")
	from.Name = "DanceDanceStepGuideFrom"
	from.Parent = root
	self.from = from

	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = anchor:FindFirstChild("To") :: Attachment
	beam.Color = ColorSequence.new(UiKit.Colors.Pink, UiKit.Colors.Yellow)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = BEAM_WIDTH
	beam.Width1 = BEAM_WIDTH
	beam.Segments = 1
	beam.TextureSpeed = BEAM_TEXTURE_SPEED
	beam.Transparency = NumberSequence.new(0.2, 0.5)
	beam.Parent = anchor
	self.beam = beam
end

function GuideBeam.clear(self: GuideBeam)
	self.target = nil

	for _, instance in { self.beam, self.from, self.anchor } do
		if instance ~= nil then
			instance:Destroy()
		end
	end

	self.beam = nil
	self.from = nil
	self.anchor = nil
end

return GuideBeam
