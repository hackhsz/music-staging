--!strict
type Joint = Motor6D | AnimationConstraint
-- One bone of the copy, from the part nearer the root to the one it carries:
-- child = parent * near * transform * far:Inverse(), or its inverse when the
-- joint was authored the other way round.
type Link = {
	parent: BasePart,
	child: BasePart,
	near: CFrame,
	far: CFrame,
	nearInverse: CFrame,
	farInverse: CFrame,
	inverted: boolean,
	source: Joint?,
	root: boolean,
}
type Edge = { other: BasePart, joint: Instance, near: CFrame, far: CFrame, forward: boolean }

type Fields = {
	model: Model,
	head: BasePart?,
	face: FaceControls?,
	-- Where the head rests before any pose, in the puppet's own space.
	focus: Vector3,
	root: BasePart?,
	rootRest: CFrame,
	links: { Link },
	parts: { BasePart },
	frames: { CFrame },
	placed: { [BasePart]: CFrame },
	world: WorldModel,
}

local STRIPPED = { "BaseScript", "Sound", "BillboardGui", "ParticleEmitter", "Trail", "Beam", "ForceField", "Light" }

-- Parts in a ViewportFrame are never simulated, so constraint joints would not
-- move them: this copy of an avatar is posed bone by bone from the live dancer.
local AvatarPuppet = {}
AvatarPuppet.__index = AvatarPuppet

export type AvatarPuppet = typeof(setmetatable({} :: Fields, AvatarPuppet))

local function copyOf(source: Model): Model?
	local archivable = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	source.Archivable = archivable

	if not ok or copy == nil then
		return nil
	end

	for _, descendant in copy:GetDescendants() do
		local stripped = false

		for _, className in STRIPPED do
			stripped = stripped or descendant:IsA(className)
		end

		if stripped then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local humanoid = copy:FindFirstChildOfClass("Humanoid")

	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return copy
end

local function isJoint(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function jointEnds(joint: Instance): (BasePart?, BasePart?, CFrame, CFrame)
	if joint:IsA("JointInstance") then
		return joint.Part0, joint.Part1, joint.C0, joint.C1
	elseif joint:IsA("AnimationConstraint") or joint:IsA("RigidConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1

		if a0 ~= nil and a1 ~= nil then
			local p0, p1 = a0.Parent, a1.Parent

			if p0 ~= nil and p0:IsA("BasePart") and p1 ~= nil and p1:IsA("BasePart") then
				return p0, p1, a0.CFrame, a1.CFrame
			end
		end
	elseif joint:IsA("WeldConstraint") then
		local p0, p1 = joint.Part0, joint.Part1

		if p0 ~= nil and p1 ~= nil then
			return p0, p1, p0.CFrame:ToObjectSpace(p1.CFrame), CFrame.identity
		end
	end

	return nil, nil, CFrame.identity, CFrame.identity
end

-- nil when the source cannot be copied or has no root to pose from.
function AvatarPuppet.new(source: Model, world: WorldModel): AvatarPuppet?
	local model = copyOf(source)

	if model == nil then
		return nil
	end

	model:PivotTo(CFrame.identity)
	model.Parent = world

	local head = model:FindFirstChild("Head")
	local headPart = if head ~= nil and head:IsA("BasePart") then head else nil
	local focus = if headPart ~= nil
		then headPart.Position
		else model:GetBoundingBox().Position + Vector3.new(0, model:GetExtentsSize().Y / 2 - 0.6, 0)

	local fields: Fields = {
		model = model,
		head = headPart,
		face = if head ~= nil then head:FindFirstChildOfClass("FaceControls") else nil,
		focus = focus,
		root = nil,
		rootRest = CFrame.identity,
		links = {},
		parts = {},
		frames = {},
		placed = {},
		world = world,
	}
	local self = setmetatable(fields, AvatarPuppet)

	if not self:_rig(source) then
		model:Destroy()
		return nil
	end

	return self
end

function AvatarPuppet._rig(self: AvatarPuppet, source: Model): boolean
	local model = self.model
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return false
	end

	local sources: { [string]: Joint } = {}

	for _, joint in source:GetDescendants() do
		if isJoint(joint) and sources[joint.Name] == nil then
			sources[joint.Name] = joint :: Joint
		end
	end

	local edges: { [BasePart]: { Edge } } = {}
	local joints = {}

	for _, joint in model:GetDescendants() do
		local p0, p1, near, far = jointEnds(joint)

		if p0 ~= nil and p1 ~= nil then
			edges[p0] = edges[p0] or {}
			edges[p1] = edges[p1] or {}
			table.insert(edges[p0], { other = p1, joint = joint, near = near, far = far, forward = true })
			table.insert(edges[p1], { other = p0, joint = joint, near = near, far = far, forward = false })
			table.insert(joints, joint)
		end
	end

	local seen = { [root] = true }
	local queue = { root }
	local head = 1

	while head <= #queue do
		local parent = queue[head]
		head += 1

		for _, edge in edges[parent] or {} do
			if not seen[edge.other] then
				seen[edge.other] = true
				table.insert(queue, edge.other)
				table.insert(self.links, {
					parent = parent,
					child = edge.other,
					near = edge.near,
					far = edge.far,
					nearInverse = edge.near:Inverse(),
					farInverse = edge.far:Inverse(),
					inverted = not edge.forward,
					source = if isJoint(edge.joint) then sources[edge.joint.Name] else nil,
					root = edge.joint.Name == "Root",
				})
			end
		end
	end

	-- Every part is placed directly now; a joint left in would pull them back.
	for _, joint in joints do
		joint:Destroy()
	end

	self.root = root
	self.rootRest = root.CFrame
	table.insert(self.parts, root)

	for _, link in self.links do
		table.insert(self.parts, link.child)
	end

	return true
end

-- The root carries the dancer's travel, turns and spins; the puppet stays
-- square to the viewer and shows only the dance above it.
local function linkTransform(link: Link): CFrame
	local source = link.source

	return if source == nil or link.root then CFrame.identity else source.Transform
end

-- Copies the dancer's pose with base on top, and returns where the head now is,
-- in the puppet's space before base: the dance's drift alone.
function AvatarPuppet.pose(self: AvatarPuppet, base: CFrame): Vector3?
	local root = self.root

	if root == nil then
		return nil
	end

	local placed = self.placed
	local frames = self.frames
	placed[root] = base * self.rootRest
	frames[1] = placed[root]

	for index, link in self.links do
		local parentFrame = placed[link.parent]
		local transform = linkTransform(link)
		local frame = if link.inverted
			then parentFrame * link.far * transform:Inverse() * link.nearInverse
			else parentFrame * link.near * transform * link.farInverse
		placed[link.child] = frame
		frames[index + 1] = frame
	end

	self.world:BulkMoveTo(self.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)

	local head = if self.head ~= nil then placed[self.head] else nil

	return if head ~= nil then base:PointToObjectSpace(head.Position) else nil
end

-- Only a dynamic head has face controls.
function AvatarPuppet.setFace(self: AvatarPuppet, keys: { string }, values: { [string]: number })
	local face = self.face

	if face == nil then
		return
	end

	for _, key in keys do
		pcall(function()
			(face :: any)[key] = values[key] or 0
		end)
	end
end

function AvatarPuppet.destroy(self: AvatarPuppet)
	self.model:Destroy()
end

return AvatarPuppet
