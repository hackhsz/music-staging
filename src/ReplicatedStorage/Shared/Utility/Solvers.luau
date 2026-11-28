local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

export type PathInput = {string} | string

local function normalizePath(path: PathInput): {string}
	if type(path) == "string" then
		local out = {}

		for segment in string.gmatch(path, "[^/]+") do
			table.insert(out, segment)
		end

		return out
	end

	if type(path) == "table" then
		local out = table.create(#path)

		for i, segment in ipairs(path) do
			assert(type(segment) == "string", `Invalid path segment at index {i}`)
			out[i] = segment
		end

		return out
	end

	error("Path must be a string or an array of strings")
end

local Solvers = {}

function Solvers.ResolveCFrame(CframeReference: Model | BasePart | Attachment | Vector3 | CFrame?): CFrame?
	if CframeReference == nil then
		return nil
	end

	local valueType = typeof(CframeReference)

	if valueType == "CFrame" then
		return CframeReference
	end

	if valueType == "Vector3" then
		return CFrame.new(CframeReference)
	end

	if valueType ~= "Instance" then
		return nil
	end

	if CframeReference:IsA("Attachment") then
		return CframeReference.WorldCFrame
	end

	if CframeReference:IsA("BasePart") then
		return CframeReference.CFrame
	end

	if CframeReference:IsA("Model") then
		local primaryPart = CframeReference.PrimaryPart
		if primaryPart then
			return primaryPart.CFrame
		end

		local pivot = CframeReference:GetPivot()
		return pivot
	end

	return nil
end;

function Solvers.GetDictionaryLength(dict: {[any]: any})
	local count = 0
	for _ in dict do
		count += 1
	end

	return count
end;

function Solvers.MakeMotor6D(BasePart0, BasePart1, C0, C1): Motor6D
	local Motor6D = Instance.new("Motor6D")

	Motor6D.Part0 = BasePart0;
	Motor6D.Part1 = BasePart1;
	Motor6D.C0 = C0;
	Motor6D.C1 = C1;
	Motor6D.Parent = BasePart0;

	return Motor6D;
end;

function Solvers.YawOnlyLookVector(Position1, Position2)
	local Origin: Vector3
	local Target: Vector3

	if typeof(Position1) == "Instance" and Position1:IsA("BasePart") then
		Origin = Position1.Position
	elseif typeof(Position1) == "Vector3" then
		Origin = Position1
	else
		error("YawOnlyLookAt Position1 must be BasePart or Vector3")
	end

	if typeof(Position2) == "Instance" and Position2:IsA("BasePart") then
		Target = Position2.Position
	elseif typeof(Position2) == "Vector3" then
		Target = Position2
	else
		error("YawOnlyLookAt Position2 must be BasePart or Vector3")
	end

	local FlatTarget = Vector3.new(Target.X, Origin.Y, Target.Z)
	local FlatDirection = FlatTarget - Origin

	if FlatDirection.Magnitude <= 0.001 then
		return CFrame.new(Origin)
	end

	return CFrame.lookAt(Origin, FlatTarget)
end

function Solvers.YawOnlyCFrame(Pivot: CFrame): CFrame
	local Position = Pivot.Position
	local _, Yaw, _ = Pivot:ToOrientation()

	return CFrame.new(Position) * CFrame.Angles(0, Yaw, 0)
end

function Solvers.DeepCopy(tab: any): any
	local copy = {}
	for k, v in pairs(tab) do
		if type(v) == "table" then
			copy[k] = Solvers.DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

--  Accepts a Player, a Character, or any descendant of one (a BasePart,
--  Humanoid, Accessory) and walks up until it finds the owning Player.
--  Returns nil instead of erroring so late calls on a departed player are
--  merely a no-op.
function Solvers.ResolvePlayer(Reference: any): Player?
	if Reference == nil then
		return nil
	end

	if typeof(Reference) == "number" then
		return Players:GetPlayerByUserId(Reference)
	end

	if typeof(Reference) ~= "Instance" then
		return nil
	end

	if Reference:IsA("Player") then
		return Reference
	end

	local Owner = Players:GetPlayerFromCharacter(Reference)
	if Owner then
		return Owner
	end

	local Ancestor = Reference:FindFirstAncestorOfClass("Model")
	while Ancestor do
		Owner = Players:GetPlayerFromCharacter(Ancestor)
		if Owner then
			return Owner
		end

		Ancestor = Ancestor:FindFirstAncestorOfClass("Model")
	end

	return nil
end

--  Single value or array. Unresolvable entries are dropped and duplicates
--  collapse, so callers can pass raw hit results straight through.
function Solvers.ResolvePlayers(Reference: any): ({Player}, number)
	local Result = {}
	local Seen = {}
	local Dropped = 0

	local function Add(Value: any)
		local Player = Solvers.ResolvePlayer(Value)

		if Player == nil then
			if Value ~= nil then
				Dropped += 1
			end
			return
		end

		if Seen[Player] then
			return
		end

		Seen[Player] = true
		table.insert(Result, Player)
	end

	if type(Reference) == "table" then
		for _, Value in Reference do
			Add(Value)
		end
	else
		Add(Reference)
	end

	return Result, Dropped
end

--  What is holding the health behind a reference: a rig's Humanoid, or an object
--  carrying its own replicated Health field. Never both, so a caller branches on
--  which one came back rather than on what it passed in.
--
--  A table exposing GetCharacter is pointing at a rig, and one exposing
--  GetHumanoid is pointing at the object that actually holds the health -- both
--  resolve once more rather than becoming extra kinds of target. Instances go
--  through ResolvePlayer first, which is what makes a Player, a character and a
--  stray limb equivalent.
function Solvers.ResolveTarget(Reference: any): (Humanoid?, any?)
	if type(Reference) == "table" then
		if type(Reference.GetCharacter) == "function" then
			return Solvers.ResolveTarget(Reference:GetCharacter())
		end

		if type(Reference.GetHumanoid) == "function" then
			local Owned = Reference:GetHumanoid()

			return nil, if Owned ~= nil and type(Owned.GetHealth) == "function" then Owned else nil
		end

		if type(Reference.Get) == "function" and Reference:Get("Health") ~= nil then
			return nil, Reference
		end

		return nil, nil
	end

	if typeof(Reference) ~= "Instance" then
		return nil, nil
	end

	local Player = Solvers.ResolvePlayer(Reference)
	local Model = if Player ~= nil then Player.Character else nil

	if Model == nil then
		Model = if Reference:IsA("Model") then Reference else Reference:FindFirstAncestorOfClass("Model")
	end

	if Model == nil then
		return nil, nil
	end

	return Model:FindFirstChildOfClass("Humanoid"), nil
end

--  How wide a part is on the ground whichever way it is turned -- the smaller
--  of its world X and Z extents. Size alone reads a cylinder stood on its side
--  as a sliver.
function Solvers.Footprint(Part: BasePart): number
	local Size = Part.Size
	local Right, Up, Look = Part.CFrame.RightVector, Part.CFrame.UpVector, Part.CFrame.LookVector

	local X = math.abs(Right.X) * Size.X + math.abs(Up.X) * Size.Y + math.abs(Look.X) * Size.Z
	local Z = math.abs(Right.Z) * Size.X + math.abs(Up.Z) * Size.Y + math.abs(Look.Z) * Size.Z

	return math.min(X, Z)
end

--  The floor inside a region volume, by looking down its middle. Ignore is
--  excluded from the ray -- the regions folder, characters. With MinSpan, a
--  hit narrower than it is a lamp hung over the middle rather than a floor and
--  the walk carries on down past it; left out, the first hit is the floor. It
--  gives up at the volume's underside.
--
--  MaxFloorHits is only a guard against a runaway walk -- the underside is the
--  real stop. Generous on purpose: the boss arena's chandelier puts twelve
--  narrow parts above its floor, and a cap of 8 read that as no floor at all.
--
--  Column (a world point) looks down there instead of the middle, for a volume
--  whose middle is filled -- the crafting pad's forge.
local MaxFloorHits = 64

function Solvers.GroundInside(Part: BasePart, Ignore: {Instance}?, MinSpan: number?, Column: Vector3?): Vector3?
	local Params = RaycastParams.new()

	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Ignore or {}
	Params.IgnoreWater = true

	local Span = MinSpan or 0
	local At = Column or Part.Position
	local Origin = Vector3.new(At.X, Part.Position.Y + Part.Size.Y * 0.5, At.Z)
	local Floor = Part.Position.Y - Part.Size.Y * 0.5

	for _ = 1, MaxFloorHits do
		local Reach = Origin.Y - Floor

		if Reach <= 0 then
			return nil
		end

		local Hit = workspace:Raycast(Origin, Vector3.new(0, -Reach, 0), Params)

		if Hit == nil then
			return nil
		end

		if Hit.Instance:IsA("BasePart") and Solvers.Footprint(Hit.Instance) >= Span then
			return Hit.Position
		end

		Origin = Hit.Position - Vector3.new(0, 0.05, 0)
	end

	return nil
end

function Solvers.SolvePath(root: any, path: PathInput): any?
	local current = root
	local parts = normalizePath(path)

	for _, key in ipairs(parts) do
		if current == nil then
			return nil
		end

		if typeof(current) == "Instance" then
			current = current:FindFirstChild(key)
		elseif type(current) == "table" then
			current = current[key]
		else
			return nil
		end
	end

	return current
end

return Solvers
