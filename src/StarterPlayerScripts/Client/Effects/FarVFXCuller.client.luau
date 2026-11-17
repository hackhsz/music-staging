--!strict
-- FarVFXCuller.client.luau
--
-- Distance-based culling for background / decorative VFX (ParticleEmitters and
-- Beams) so distant scenery (waterfalls, sky props, far islands) doesn't burn
-- perf when the player is nowhere near it.
--
-- Usage: tag any ParticleEmitter/Beam -- or a Model/Part that contains them --
-- with the CollectionService tag "StreamedVFX" (in Studio: Tag Editor, or via
-- CollectionService:AddTag). This script enables those VFX when the local player
-- is close and disables them when far, with a hysteresis band to avoid flicker.
--
-- It is a safe no-op until something is tagged, so it can ship before the stage
-- art lands. It never touches VFX that aren't tagged.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "StreamedVFX"
local NEAR_DISTANCE = 120 -- studs: turn VFX on at/under this range
local FAR_DISTANCE = 160 -- studs: turn VFX off at/over this range (hysteresis)
local UPDATE_INTERVAL = 0.4 -- seconds between distance checks

local player = Players.LocalPlayer

type Entry = {
	emitters: { Instance },
	orig: { [Instance]: boolean },
	anchor: BasePart?,
	on: boolean,
}

local entries: { [Instance]: Entry } = {}

local function collectEmitters(inst: Instance): { Instance }
	local list = {}
	if inst:IsA("ParticleEmitter") or inst:IsA("Beam") then
		table.insert(list, inst)
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Beam") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function anchorPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	local ancestor = inst.Parent
	while ancestor and not ancestor:IsA("BasePart") do
		ancestor = ancestor.Parent
	end
	if ancestor and ancestor:IsA("BasePart") then
		return ancestor
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function getFocusPosition(): Vector3?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.Position or nil
end

local function track(inst: Instance)
	if entries[inst] then
		return
	end
	local emitters = collectEmitters(inst)
	if #emitters == 0 then
		return
	end
	local orig = {}
	for _, e in emitters do
		orig[e] = (e :: any).Enabled == true
	end
	entries[inst] = {
		emitters = emitters,
		orig = orig,
		anchor = anchorPart(inst),
		on = true,
	}
end

local function untrack(inst: Instance)
	entries[inst] = nil
end

local function setState(entry: Entry, on: boolean)
	if entry.on == on then
		return
	end
	entry.on = on
	for _, e in entry.emitters do
		if e and e.Parent then
			(e :: any).Enabled = on and (entry.orig[e] == true)
		end
	end
end

for _, inst in CollectionService:GetTagged(TAG) do
	track(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

local accum = 0
RunService.Heartbeat:Connect(function(dt: number)
	accum += dt
	if accum < UPDATE_INTERVAL then
		return
	end
	accum = 0

	local focus = getFocusPosition()
	if not focus then
		return
	end

	for inst, entry in entries do
		if not inst.Parent then
			entries[inst] = nil
			continue
		end
		local anchor = entry.anchor
		if not anchor or not anchor.Parent then
			anchor = anchorPart(inst)
			entry.anchor = anchor
		end
		if anchor then
			local dist = (anchor.Position - focus).Magnitude
			if entry.on and dist >= FAR_DISTANCE then
				setState(entry, false)
			elseif not entry.on and dist <= NEAR_DISTANCE then
				setState(entry, true)
			end
		end
	end
end)
