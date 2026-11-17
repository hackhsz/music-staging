--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticBuilds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticBuilds"))

local SPIN_RADIANS_PER_SECOND = 0.7
local PREVIEW_FOV = 30
local PREVIEW_MARGIN = 1.25
-- Copies of the avatar keep only what draws; a script in a ViewportFrame does nothing.
local PREVIEW_STRIPPED = { "BaseScript", "Sound", "ParticleEmitter", "Trail", "Beam", "BillboardGui" }
local ARENAS_FOLDER = "Arenas"
local ARENA_CATEGORY = "arena"
-- An arena shows as a diorama: the ground and sky pieces past this size are left
-- out, and the camera looks down at it from the audience side.
local ARENA_MAX_PART_SIZE = 200
local ARENA_CAMERA_OFFSET = Vector3.new(0, 82, 178)
local ARENA_LOOK_AT = Vector3.new(0, 4, -18)

type Fields = {
	viewport: ViewportFrame?,
	world: WorldModel?,
	camera: Camera?,
	source: Model?,
	model: Model?,
	centre: Vector3,
	spin: RBXScriptConnection?,
}

-- A spinning copy of the player's avatar in a ViewportFrame (with a WorldModel
-- inside), wearing what is equipped with one item tried on. The shop and the
-- wardrobe both show one.
local TryOnPreview = {}
TryOnPreview.__index = TryOnPreview

export type TryOnPreview = typeof(setmetatable({} :: Fields, TryOnPreview))

function TryOnPreview.new(viewport: ViewportFrame?, world: WorldModel?): TryOnPreview
	local self = setmetatable({
		viewport = viewport,
		world = world,
		camera = nil,
		source = nil,
		model = nil,
		centre = Vector3.zero,
		spin = nil,
	} :: Fields, TryOnPreview)

	if viewport ~= nil then
		local camera = Instance.new("Camera")
		camera.FieldOfView = PREVIEW_FOV
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		self.camera = camera
	end

	return self
end

function TryOnPreview.setSource(self: TryOnPreview, source: Model?)
	self.source = source
end

function TryOnPreview.setSpinning(self: TryOnPreview, on: boolean)
	if self.spin ~= nil then
		self.spin:Disconnect()
		self.spin = nil
	end

	if not on then
		return
	end

	local started = os.clock()

	self.spin = RunService.RenderStepped:Connect(function()
		local model = self.model

		if model ~= nil and model.Parent ~= nil then
			local turn = CFrame.Angles(0, (os.clock() - started) * SPIN_RADIANS_PER_SECOND, 0)
			model:PivotTo(CFrame.new(self.centre) * turn * CFrame.new(-self.centre))
		end
	end)
end

local function stripForPreview(model: Instance)
	for _, descendant in model:GetDescendants() do
		for _, className in PREVIEW_STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

-- An arena has no avatar to dress; its model in ReplicatedStorage.Arenas is shown
-- instead. The default arena has none there and falls back to its glyph.
function TryOnPreview._showArena(self: TryOnPreview, entry: any): boolean
	local world, camera = self.world, self.camera
	local folder = ReplicatedStorage:FindFirstChild(ARENAS_FOLDER)
	local template = if folder ~= nil then folder:FindFirstChild(entry.id) else nil

	if world == nil or camera == nil or template == nil or not template:IsA("Model") then
		return false
	end

	local model = template:Clone()
	stripForPreview(model)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Size.Magnitude > ARENA_MAX_PART_SIZE then
			descendant:Destroy()
		end
	end

	model:PivotTo(CFrame.identity)
	model.Parent = world
	self.centre = Vector3.zero
	camera.CFrame = CFrame.lookAt(ARENA_CAMERA_OFFSET, ARENA_LOOK_AT)
	self.model = model

	return true
end

-- entry is a shop or wardrobe row; only a cosmetic is shown. tryOn false shows the
-- avatar as it is. Returns whether a model is showing.
function TryOnPreview.show(self: TryOnPreview, entry: any, tryOn: boolean): boolean
	local source, world, camera = self.source, self.world, self.camera

	if self.model ~= nil then
		self.model:Destroy()
		self.model = nil
	end

	if entry ~= nil and entry.kind == "cosmetic" and entry.category == ARENA_CATEGORY then
		return self:_showArena(entry)
	end

	if source == nil or world == nil or camera == nil or entry == nil or entry.kind ~= "cosmetic" then
		return false
	end

	local archivable = source.Archivable
	source.Archivable = true

	local ok, copy = pcall(function()
		return source:Clone()
	end)

	source.Archivable = archivable

	if not ok or copy == nil then
		return false
	end

	local model = copy :: Model

	stripForPreview(model)

	model:PivotTo(CFrame.identity)

	if tryOn then
		if CosmeticBuilds.HandProps[entry.id] ~= nil then
			CosmeticBuilds.buildHandProp(model, model, entry.id)
		else
			CosmeticBuilds.paintTint(model, entry.id)
		end
	end

	model.Parent = world

	-- A posed rig faces -Z, so the camera stands on that side and frames the whole body.
	local frame, size = model:GetBoundingBox()
	local distance = (size.Y * PREVIEW_MARGIN / 2) / math.tan(math.rad(PREVIEW_FOV / 2))
	self.centre = frame.Position
	camera.CFrame = CFrame.lookAt(frame.Position + Vector3.new(0, 0, -distance), frame.Position)
	self.model = model

	return true
end

return TryOnPreview
