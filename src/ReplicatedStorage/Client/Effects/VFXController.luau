local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local VFXCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("VFXCatalog"))
local TileState = require(Shared:WaitForChild("TileState"))
local StageLighting = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("StageLighting"))

local VFXController = {}
VFXController.__index = VFXController

local CONFETTI_SECONDS = 3
local CONFETTI_RATE_PER_COLOR = 45

-- Authored particle bursts live in ReplicatedStorage.BurstVfx, each a part whose
-- emitters carry EmitCount and EmitDelay. Only a few big moments use one.
local BURST_FOLDER = "BurstVfx"
local BURST_CLEAR = "PartyPop"
local BURST_FEVER = "LovePop"
local BURST_MILESTONE = "YellowBurst"
local BURST_HEIGHT = 3
local BURST_CLEANUP_PAD = 0.5
-- Only these combos get the jackpot; every other milestone keeps the small burst.
local JACKPOT_COMBOS = { [25] = true, [50] = true }
local JACKPOT_EVERY = 100

-- Performance tiers. Visuals are "maxed" on High; on weaker devices (and via a
-- runtime FPS watchdog) they scale down so the effects never tank frame rate.
-- emitMul scales every particle burst; the booleans gate the pricier extras.
-- Dynamic PointLights are the most expensive on mobile, so they're the first to
-- go; the background blur is a full-screen pass, so Low drops it too. Worst-case
-- concurrent particles (8 steps/s): High ~413, Medium ~174, Low ~95.
local QUALITY = {
	High = { emitMul = 1.0, stepLight = true, hitLight = true, rings = true, stepDust = true, focusBlur = true },
	Medium = { emitMul = 0.55, stepLight = false, hitLight = true, rings = true, stepDust = false, focusBlur = true },
	Low = { emitMul = 0.3, stepLight = false, hitLight = false, rings = false, stepDust = false, focusBlur = false },
}
local TIER_ORDER = { "Low", "Medium", "High" }

local STEP_FULL_INTERVAL = 0.05 -- min seconds between full step bursts (coalesces rapid steps)
local FPS_WINDOW = 1.5 -- seconds per FPS sample window
local FPS_DOWNGRADE = 45 -- sustained avg FPS below this -> drop a tier
local FPS_UPGRADE = 58 -- avg FPS above this for several windows -> restore a tier

local function tierIndex(name: string): number
	for i, n in TIER_ORDER do
		if n == name then
			return i
		end
	end
	return #TIER_ORDER
end

local function createAnchorPart(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent

	return part
end

local function makeColorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end

	local keypoints = {}

	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end

	return ColorSequence.new(keypoints)
end

function VFXController.new()
	local existing = workspace:FindFirstChild("DanceDanceStepVFX")

	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "DanceDanceStepVFX"
	folder.Parent = workspace

	local self = setmetatable({
		folder = folder,
		feverActive = false,
		feverEmitters = {},
		confettiEmitters = {},
		confettiUntil = 0,
	}, VFXController)

	-- Hit burst anchor: moved to the judged tile, then the matching emitter
	-- fires a one-shot burst.
	self.hitAnchor = createAnchorPart(folder, "hit_burst_anchor", Vector3.new(1, 1, 1), Board.Origin + Vector3.new(0, 1.2, 0))
	local hitAttachment = Instance.new("Attachment")
	hitAttachment.Parent = self.hitAnchor
	self.hitAttachment = hitAttachment

	-- Strong flash light on judged hits (brighter for Perfect/Great).
	local hitLight = Instance.new("PointLight")
	hitLight.Name = "HitFlash"
	hitLight.Color = Color3.fromRGB(255, 240, 200)
	hitLight.Brightness = 0
	hitLight.Range = 15
	hitLight.Shadows = false
	hitLight.Parent = hitAttachment
	self.hitLight = hitLight

	self.syncAnchor = createAnchorPart(folder, "coop_sync_anchor", Vector3.new(1, 1, 1), Board.Origin + Vector3.new(0, 4, -10))
	local syncAttachment = Instance.new("Attachment")
	syncAttachment.Parent = self.syncAnchor
	self.syncAttachment = syncAttachment

	-- Step spark anchor: fires a quick sparkle wherever the player hops.
	self.stepAnchor = createAnchorPart(folder, "step_spark_anchor", Vector3.new(1, 1, 1), Board.Origin + Vector3.new(0, 0.6, 0))
	local stepAttachment = Instance.new("Attachment")
	stepAttachment.Parent = self.stepAnchor

	local stepEmitter = Instance.new("ParticleEmitter")
	stepEmitter.Name = "StepSpark"
	stepEmitter.Enabled = false
	stepEmitter.Rate = 0
	stepEmitter.Color = makeColorSequence({
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 231, 138),
		Color3.fromRGB(255, 143, 191),
		Color3.fromRGB(140, 214, 255),
	})
	stepEmitter.LightEmission = 1
	stepEmitter.LightInfluence = 0
	stepEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	stepEmitter.Transparency = NumberSequence.new(0, 1)
	stepEmitter.Lifetime = NumberRange.new(0.28, 0.55)
	stepEmitter.Speed = NumberRange.new(9, 20)
	stepEmitter.SpreadAngle = Vector2.new(180, 180)
	stepEmitter.Acceleration = Vector3.new(0, -12, 0)
	stepEmitter.Rotation = NumberRange.new(0, 360)
	stepEmitter.RotSpeed = NumberRange.new(-220, 220)
	stepEmitter.Parent = stepAttachment
	self.stepEmitter = stepEmitter

	-- Secondary "glitter dust" layer so every hop throws a dense burst.
	local stepDust = Instance.new("ParticleEmitter")
	stepDust.Name = "StepDust"
	stepDust.Enabled = false
	stepDust.Rate = 0
	stepDust.Color = makeColorSequence({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 236, 255) })
	stepDust.LightEmission = 1
	stepDust.LightInfluence = 0
	stepDust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	stepDust.Transparency = NumberSequence.new(0.05, 1)
	stepDust.Lifetime = NumberRange.new(0.4, 0.8)
	stepDust.Speed = NumberRange.new(2, 6)
	stepDust.SpreadAngle = Vector2.new(180, 180)
	stepDust.Acceleration = Vector3.new(0, -4, 0)
	stepDust.Parent = stepAttachment
	self.stepDust = stepDust

	-- Burst flash light: a short, bright pop of light on every step so the
	-- whole floor lights up under the dancer.
	local stepLight = Instance.new("PointLight")
	stepLight.Name = "StepFlash"
	stepLight.Color = Color3.fromRGB(255, 210, 236)
	stepLight.Brightness = 0
	stepLight.Range = 14
	stepLight.Shadows = false
	stepLight.Parent = stepAttachment
	self.stepLight = stepLight

	-- Dedicated step shockwave ring (separate from the hit ring so rapid steps
	-- never fight the hit-ring tween).
	local stepRing = Instance.new("Part")
	stepRing.Name = "step_shockwave_ring"
	stepRing.Shape = Enum.PartType.Cylinder
	stepRing.Anchored = true
	stepRing.CanCollide = false
	stepRing.CanQuery = false
	stepRing.CanTouch = false
	stepRing.CastShadow = false
	stepRing.Material = Enum.Material.Neon
	stepRing.Color = Color3.fromRGB(255, 200, 230)
	stepRing.Transparency = 1
	stepRing.Size = Vector3.new(0.3, 1.5, 1.5)
	stepRing.CFrame = CFrame.new(Board.Origin + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	stepRing.Parent = folder
	self.stepRing = stepRing

	-- Reusable shockwave ring: a flat neon disc that scales out and fades on
	-- strong hits, adding a punchy ripple to Perfect/Great.
	local ring = Instance.new("Part")
	ring.Name = "shockwave_ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 1
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(Board.Origin + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	self.ring = ring

	local perfectEffect = VFXCatalog.Effects.Perfect
	local perfectEmitter = Instance.new("ParticleEmitter")
	perfectEmitter.Name = "PerfectSparkle"
	perfectEmitter.Enabled = false
	perfectEmitter.Rate = 0
	perfectEmitter.Color = makeColorSequence(perfectEffect.colors)
	perfectEmitter.LightEmission = 1
	perfectEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	perfectEmitter.Transparency = NumberSequence.new(0, 1)
	perfectEmitter.Lifetime = NumberRange.new(0.3, 0.6)
	perfectEmitter.Speed = NumberRange.new(9, 16)
	perfectEmitter.SpreadAngle = Vector2.new(180, 180)
	perfectEmitter.Acceleration = Vector3.new(0, -14, 0)
	perfectEmitter.Parent = hitAttachment
	self.perfectEmitter = perfectEmitter

	local goodEffect = VFXCatalog.Effects.Good
	local goodEmitter = Instance.new("ParticleEmitter")
	goodEmitter.Name = "GoodPuff"
	goodEmitter.Enabled = false
	goodEmitter.Rate = 0
	goodEmitter.Color = makeColorSequence(goodEffect.colors)
	goodEmitter.LightEmission = 0.6
	goodEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	goodEmitter.Transparency = NumberSequence.new(0.25, 1)
	goodEmitter.Lifetime = NumberRange.new(0.25, 0.45)
	goodEmitter.Speed = NumberRange.new(4, 7)
	goodEmitter.SpreadAngle = Vector2.new(180, 180)
	goodEmitter.Parent = hitAttachment
	self.goodEmitter = goodEmitter

	local comboEffect = VFXCatalog.Effects.Combo
	local comboEmitter = Instance.new("ParticleEmitter")
	comboEmitter.Name = "ComboMilestoneSpark"
	comboEmitter.Enabled = false
	comboEmitter.Rate = 0
	comboEmitter.Color = makeColorSequence(comboEffect.colors)
	comboEmitter.LightEmission = 1
	comboEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 0),
	})
	comboEmitter.Transparency = NumberSequence.new(0.15, 1)
	comboEmitter.Lifetime = NumberRange.new(0.45, 0.8)
	comboEmitter.Speed = NumberRange.new(7, 13)
	comboEmitter.SpreadAngle = Vector2.new(90, 90)
	comboEmitter.Parent = syncAttachment
	self.comboEmitter = comboEmitter

	-- Fever aura: soft rising particles at the four corners of the board
	-- while fever is active (edge-only so prompts stay readable).
	local feverEffect = VFXCatalog.Effects.Fever
	local boardWidth = Board.Columns * Board.TileSize
	local boardDepth = Board.Rows * Board.TileSize

	for index = 1, 4 do
		local xSign = index % 2 == 0 and 1 or -1
		local zSign = index <= 2 and 1 or -1
		local corner = createAnchorPart(
			folder,
			("fever_aura_anchor_%02d"):format(index),
			Vector3.new(1, 1, 1),
			Board.Origin + Vector3.new(xSign * (boardWidth / 2 + 2.5), 0.8, zSign * (boardDepth / 2 + 2.5))
		)
		local auraAttachment = Instance.new("Attachment")
		auraAttachment.Parent = corner

		local aura = Instance.new("ParticleEmitter")
		aura.Name = "FeverAura"
		aura.Enabled = false
		aura.Rate = 14
		aura.Color = makeColorSequence(feverEffect.colors)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new(0.3, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(3, 6)
		aura.SpreadAngle = Vector2.new(18, 18)
		aura.Acceleration = Vector3.new(0, 6, 0)
		aura.Parent = auraAttachment

		table.insert(self.feverEmitters, aura)
	end

	-- Confetti rain: wide invisible sheet above the stage, one emitter per
	-- catalog color so the rain reads multi-color.
	local confettiSheet = createAnchorPart(folder, "confetti_sheet", Vector3.new(70, 0.5, 56), Vector3.new(0, 36, -14))
	self.confettiSheet = confettiSheet

	for index, color in VFXCatalog.Effects.SongEnd.colors do
		local confetti = Instance.new("ParticleEmitter")
		confetti.Name = ("Confetti_%02d"):format(index)
		confetti.Enabled = false
		confetti.Rate = CONFETTI_RATE_PER_COLOR
		confetti.Color = ColorSequence.new(color)
		confetti.LightEmission = 0.4
		confetti.Size = NumberSequence.new(0.35)
		confetti.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		confetti.Lifetime = NumberRange.new(2.2, 3.2)
		confetti.Speed = NumberRange.new(4, 9)
		confetti.SpreadAngle = Vector2.new(35, 35)
		confetti.EmissionDirection = Enum.NormalId.Bottom
		confetti.Acceleration = Vector3.new(0, -8, 0)
		confetti.Rotation = NumberRange.new(0, 360)
		confetti.RotSpeed = NumberRange.new(-180, 180)
		confetti.Parent = confettiSheet

		table.insert(self.confettiEmitters, confetti)
	end

	-- Performance / adaptive quality.
	self._lastStepFull = 0
	self._autoTier = true
	self:applyTier(self:_detectInitialTier())
	self:_startPerfWatchdog()

	return self
end

-- Apply a quality tier's multipliers/toggles.
function VFXController:applyTier(tier: string)
	local q = QUALITY[tier] or QUALITY.High
	self.tier = QUALITY[tier] and tier or "High"
	self.emitMul = q.emitMul
	self.useStepLight = q.stepLight
	self.useHitLight = q.hitLight
	self.useRings = q.rings
	self.useStepDust = q.stepDust
	StageLighting.setFocusAllowed(q.focusBlur)
end

local TIER_BY_CHOICE = { high = "High", medium = "Medium", low = "Low" }

-- The Settings window's choice: "auto" lets the watchdog pick the tier, any other
-- pins it there.
function VFXController:setQuality(choice: string)
	local tier = TIER_BY_CHOICE[choice]

	self._autoTier = tier == nil
	self:applyTier(tier or self:_detectInitialTier())
end

-- Touch-only devices (phones/tablets) start at Medium; keyboard/gamepad at High.
function VFXController:_detectInitialTier(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Medium"
	end
	return "High"
end

-- Scale a burst count by the active tier (never below 1).
function VFXController:_scaled(n: number): number
	return math.max(1, math.floor(n * self.emitMul + 0.5))
end

-- Runtime FPS watchdog: samples client frame rate and steps the tier down when
-- the device struggles (and gently back up when it has headroom). This is what
-- actually guarantees the effects don't cause sustained frame drops on-device.
function VFXController:_startPerfWatchdog()
	local frames = 0
	local elapsed = 0
	local goodWindows = 0

	RunService.Heartbeat:Connect(function(dt: number)
		frames += 1
		elapsed += dt
		if elapsed < FPS_WINDOW then
			return
		end
		local fps = frames / elapsed
		frames = 0
		elapsed = 0

		if not self._autoTier then
			return
		end
		local idx = tierIndex(self.tier)
		if fps < FPS_DOWNGRADE and idx > 1 then
			goodWindows = 0
			self:applyTier(TIER_ORDER[idx - 1])
		elseif fps > FPS_UPGRADE and idx < #TIER_ORDER then
			goodWindows += 1
			if goodWindows >= 4 then -- ~6s of headroom before stepping back up
				goodWindows = 0
				self:applyTier(TIER_ORDER[idx + 1])
			end
		else
			goodWindows = 0
		end
	end)
end

function VFXController:playHitBurst(grade: string?, coord: { x: number, y: number }?)
	if coord == nil or coord.x == nil or coord.y == nil then
		return
	end

	self.hitAnchor.Position = Board.coordToWorld(coord.x, coord.y) + Vector3.new(0, 1.2, 0)

	-- Distinct burst size per tier so Perfect reads clearly bigger than Great,
	-- Great bigger than Good, and Bad is only a small near-miss puff. Strong hits
	-- also fire an expanding shockwave ring and a bright light flash for punch.
	local flash = 0

	if grade == "Perfect" then
		self.perfectEmitter:Emit(self:_scaled(34))
		self:playShockwave(coord, grade)
		flash = 5
	elseif grade == "Great" then
		self.perfectEmitter:Emit(self:_scaled(22))
		self:playShockwave(coord, grade)
		flash = 3
	elseif grade == "Good" then
		self.goodEmitter:Emit(self:_scaled(14))
		self:playShockwave(coord, grade)
		flash = 2
	elseif grade == "Bad" then
		self.goodEmitter:Emit(self:_scaled(6))
		flash = 1
	end

	if flash > 0 and self.useHitLight then
		local light = self.hitLight
		light.Color = TileState.getColor(grade or "Perfect")
		light.Brightness = flash
		TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 0,
		}):Play()
	end
end

-- Big sparkle burst wherever the player steps (called on every hop). Fires a
-- dense spark + glitter-dust burst, an expanding neon ring, and a quick light
-- flash so every step visibly pops the floor.
function VFXController:playStepSpark(coord: { x: number, y: number }?)
	if coord == nil or coord.x == nil or coord.y == nil then
		return
	end

	local pos = Board.coordToWorld(coord.x, coord.y)
	self.stepAnchor.Position = pos + Vector3.new(0, 0.6, 0)

	-- Coalesce rapid consecutive steps: only fire the heavy burst + light + ring
	-- if enough time passed since the last full one, so particles/sec stays
	-- bounded on fast charts. Every step still sparks (lighter one in between).
	local now = os.clock()
	local full = (now - self._lastStepFull) >= STEP_FULL_INTERVAL
	if full then
		self._lastStepFull = now
	end

	self.stepEmitter:Emit(full and self:_scaled(14) or self:_scaled(5))

	if not full then
		return
	end

	if self.useStepDust then
		self.stepDust:Emit(self:_scaled(10))
	end

	-- Quick bright flash under the dancer (High tier only; lights are costly).
	if self.useStepLight then
		local light = self.stepLight
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 0,
		}):Play()
	end

	-- Expanding step ring (softer: fainter start, smaller spread).
	if self.useRings then
		local ring = self.stepRing
		ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Size = Vector3.new(0.3, 1.5, 1.5)
		ring.Transparency = 0.6
		TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.3, 7, 7),
			Transparency = 1,
		}):Play()
	end
end

-- Expanding neon ripple on strong hits.
function VFXController:playShockwave(coord: { x: number, y: number }?, grade: string?)
	if coord == nil or coord.x == nil or coord.y == nil then
		return
	end

	if not self.useRings then
		return
	end

	local ring = self.ring
	ring.Color = TileState.getColor(grade or "Perfect")
	ring.CFrame = CFrame.new(Board.coordToWorld(coord.x, coord.y) + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.Transparency = 0.45

	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, 11, 11),
		Transparency = 1,
	}):Play()
end

-- Plays an authored burst above the local dancer, or at position, scaled down
-- on the lower quality tiers like every other burst.
function VFXController:playBurst(name: string, position: Vector3?)
	local library = ReplicatedStorage:FindFirstChild(BURST_FOLDER)
	local preset = if library ~= nil then library:FindFirstChild(name) else nil

	if preset == nil or not preset:IsA("BasePart") then
		return
	end

	local at = position

	if at == nil then
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		at = if root ~= nil and root:IsA("BasePart") then root.Position + Vector3.new(0, BURST_HEIGHT, 0) else nil
	end

	if at == nil then
		return
	end

	local burst = preset:Clone()
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Transparency = 1
	burst.CFrame = CFrame.new(at)
	burst.Parent = workspace

	local longest = 0

	for _, emitter in burst:GetDescendants() do
		if not emitter:IsA("ParticleEmitter") then
			continue
		end

		local count = tonumber(emitter:GetAttribute("EmitCount")) or 1
		local delay = tonumber(emitter:GetAttribute("EmitDelay")) or 0
		-- A fractional count is a chance of one more particle.
		local whole = math.floor(count) + (if math.random() < count % 1 then 1 else 0)

		longest = math.max(longest, delay + emitter.Lifetime.Max)

		if whole > 0 then
			task.delay(delay, function()
				if emitter.Parent ~= nil then
					emitter:Emit(self:_scaled(whole))
				end
			end)
		end
	end

	Debris:AddItem(burst, longest + BURST_CLEANUP_PAD)
end

function VFXController:setFeverActive(active: boolean)
	if self.feverActive == active then
		return
	end

	self.feverActive = active

	if active then
		self:playBurst(BURST_FEVER)
	end

	for _, aura in self.feverEmitters do
		aura.Enabled = active
	end

	if active then
		for _, aura in self.feverEmitters do
			aura:Emit(10)
		end
	end
end

function VFXController:playComboMilestone(combo: number?)
	if combo == nil or combo <= 0 or combo % 10 ~= 0 then
		return
	end

	self.comboEmitter:Emit(18)

	if JACKPOT_COMBOS[combo] or combo % JACKPOT_EVERY == 0 then
		self:playBurst(BURST_MILESTONE)
	end
end

function VFXController:playCoopSync(syncBonus: number?)
	if syncBonus == nil or syncBonus <= 0 then
		return
	end

	self.comboEmitter:Emit(22)
end

function VFXController:playConfetti()
	self.confettiUntil = os.clock() + CONFETTI_SECONDS
	self:playBurst(BURST_CLEAR)

	for _, confetti in self.confettiEmitters do
		confetti.Enabled = true
	end

	task.delay(CONFETTI_SECONDS, function()
		if os.clock() >= self.confettiUntil then
			for _, confetti in self.confettiEmitters do
				confetti.Enabled = false
			end
		end
	end)
end

return VFXController
