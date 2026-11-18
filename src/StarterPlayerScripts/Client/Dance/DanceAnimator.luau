--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DancePoses = require(Shared:WaitForChild("DancePoses"))
local AnimationPacks = require(Shared:WaitForChild("Catalogs"):WaitForChild("AnimationPacks"))
local EmoteCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("EmoteCatalog"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))
local InputStrategy = require(Shared:WaitForChild("InputStrategy"))
local Timing = require(Shared:WaitForChild("Timing"))
local DanceRig = require(script.Parent.DanceRig)
local PadDanceMoves = require(script.Parent.PadDanceMoves)
local StepMover = require(script.Parent.Parent.Input.StepMover)

type Pose = DancePoses.Pose

type Fields = {
	rig: DanceRig.Rig?,
	animator: Animator?,
	active: boolean,
	fever: boolean,
	beat: number,
	beatSeconds: number,
	base: AnimationTrack?,
	baseEmote: string?,
	baseWeight: number,
	layer: DancePoses.Layer,
	move: Pose?,
	moveName: string?,
	moveUntil: number,
	missAt: number,
	activity: number,
	presence: number,
	lastCombo: number,
	tracks: { [string]: AnimationTrack },
	packIdle: AnimationTrack?,
	pad: boolean,
	padCombo: number,
	beatAt: number,
	variant: number,
	perfectSteps: number,
	dancer: PadDanceMoves.Dancer,
	stepMover: StepMover.StepMover?,
	connections: { RBXScriptConnection },
}

local FADE_RATE = 8
local ACTIVITY_RATE = 12
local MISS_SHAKE_RADIANS = 0.3
local MISS_SHAKE_SPEED = 28
-- A real dance loop plays under the poses so the whole body moves between
-- presses; a pose turns it down so the pose reads cleanly on top of it.
local BASE_EMOTE = "signature-step-001"
local FEVER_EMOTE = "fever-groove-001"
local BASE_FADE_SECONDS = 0.3
local BASE_WEIGHT_UNDER_POSE = 0.15
local BASE_REFERENCE_BPM = 120
local BASE_SPEED_MIN = 0.8
local BASE_SPEED_MAX = 1.3
local GROOVE_OVER_BASE = 0.5
-- On the pad the loop only shows from a long combo on, and never louder than
-- the steps, which StepMover's hop already sells.
local PAD_BASE_WEIGHT = 0.35
local PAD_FEVER_WEIGHT = 0.55
local PAD_BASE_COMBO = PadDanceMoves.ShoulderGrooveCombo
local PAD_SPIN_EVERY = 4
local PAD_RUN_ACCENT = 0.3
local PAD_FINISH_ACCENT = 1.2
local PAD_FINISH_HOLD_SECONDS = 0.45
local PAD_MAX_EXTRAPOLATED_BEATS = 2
local PACK_FADE_SECONDS = 0.1
local PACK_STEP_SLOTS = {
	["0,-1"] = "StepUp",
	["0,1"] = "StepDown",
	["-1,0"] = "StepLeft",
	["1,0"] = "StepRight",
}
local EMOTE_PRIORITIES = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}

-- Poses the local R15 character on top of whatever the Animator plays: each
-- press snaps a lane's pose, an idle groove bops on the beat between presses.
-- Joint transforms are not replicated, so only this player sees the dance.
local DanceAnimator = {}
DanceAnimator.__index = DanceAnimator

export type DanceAnimator = typeof(setmetatable({} :: Fields, DanceAnimator))

function DanceAnimator.new(): DanceAnimator
	local fields: Fields = {
		rig = nil,
		animator = nil,
		active = false,
		fever = false,
		beat = 0,
		beatSeconds = 0.5,
		base = nil,
		baseEmote = nil,
		baseWeight = 1,
		layer = DancePoses.newLayer(),
		move = nil,
		moveName = nil,
		moveUntil = 0,
		missAt = -math.huge,
		activity = 0,
		presence = 0,
		lastCombo = 0,
		tracks = {},
		packIdle = nil,
		pad = false,
		padCombo = 0,
		beatAt = os.clock(),
		variant = 0,
		perfectSteps = 0,
		dancer = PadDanceMoves.newDancer(),
		stepMover = nil,
		connections = {},
	}
	local self = setmetatable(fields, DanceAnimator)
	local player = Players.LocalPlayer

	table.insert(self.connections, player.CharacterAdded:Connect(function(character)
		self:_bind(character)
	end))

	if player.Character ~= nil then
		self:_bind(player.Character)
	end

	-- The Animator writes joint transforms before PreSimulation and physics
	-- places the limbs after it, so this is the one point where an offset
	-- lands on top of the animation instead of being overwritten.
	table.insert(self.connections, RunService.PreSimulation:Connect(function(dt)
		self:_update(os.clock(), dt)
	end))

	return self
end

function DanceAnimator._bind(self: DanceAnimator, character: Model)
	self.rig = nil
	self.animator = nil
	self.base = nil
	self.baseEmote = nil
	self.packIdle = nil
	table.clear(self.tracks)

	-- Rig parts stream in after CharacterAdded fires.
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)

		if humanoid == nil or not humanoid:IsA("Humanoid") or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			return
		end

		character:WaitForChild("UpperTorso", 10)
		character:WaitForChild("Head", 10)

		if Players.LocalPlayer.Character ~= character then
			return
		end

		self.rig = DanceRig.find(character)
		self:_fitLegs()
		self.animator = humanoid:FindFirstChildOfClass("Animator")
		self:_syncBase()
		self:_syncFacing()
	end)
end

function DanceAnimator._fitLegs(self: DanceAnimator)
	local rig = self.rig

	if rig == nil then
		return
	end

	local thigh, shin = DanceRig.measureLegs(rig)

	if thigh ~= nil and shin ~= nil then
		PadDanceMoves.setLegs(self.dancer, thigh, shin)
	end
end

-- Whether the character can be posed; an R6 rig falls back to StepMover's bounce.
function DanceAnimator.isRigged(self: DanceAnimator): boolean
	return self.rig ~= nil
end

function DanceAnimator.setActive(self: DanceAnimator, active: boolean)
	self.active = active
	self.lastCombo = 0

	if not active then
		self.fever = false
		self.move = nil
		self.moveName = nil
	end

	self:_syncBase()
end

function DanceAnimator.setBeat(self: DanceAnimator, beat: number, beatSeconds: number)
	self.beat = beat
	self.beatAt = os.clock()

	if beatSeconds > 0 and beatSeconds ~= self.beatSeconds then
		self.beatSeconds = beatSeconds
		self:_syncBase()
	end
end

function DanceAnimator.setFever(self: DanceAnimator, active: boolean)
	if active ~= self.fever then
		self.fever = active
		self:_syncBase()
	end
end

-- Starts, swaps or stops the dance loop to match the run: none outside a
-- run, the Fever dance during Fever, and played near the song's tempo.
function DanceAnimator._syncBase(self: DanceAnimator)
	local wanted = if not self.active or self.rig == nil
		then nil
		elseif self.fever then FEVER_EMOTE
		elseif self.pad and self.padCombo < PAD_BASE_COMBO then nil
		else BASE_EMOTE

	if wanted ~= self.baseEmote then
		if self.base ~= nil then
			self.base:Stop(BASE_FADE_SECONDS)
			self.base = nil
		end

		self.baseEmote = wanted
		self.baseWeight = self:_baseWeightFor(0)
		self.base = if wanted ~= nil then self:_playLoop(wanted, self.baseWeight) else nil
	end

	local base = self.base

	if base ~= nil then
		local bpm = 60 / self.beatSeconds
		base:AdjustSpeed(math.clamp(bpm / BASE_REFERENCE_BPM, BASE_SPEED_MIN, BASE_SPEED_MAX))
	end
end

function DanceAnimator._baseWeightFor(self: DanceAnimator, activity: number): number
	local full = if not self.pad then 1 elseif self.fever then PAD_FEVER_WEIGHT else PAD_BASE_WEIGHT

	return full * (1 - activity * (1 - BASE_WEIGHT_UNDER_POSE))
end

-- Tracks are kept per animation, so a combo crossing the loop's threshold again
-- and again reuses one track instead of loading a new one each time.
function DanceAnimator._playLoop(self: DanceAnimator, emoteId: string, weight: number): AnimationTrack?
	local emote = EmoteCatalog.getEmote(emoteId)
	local animationId = if emote ~= nil then AnimationPacks.emoteAnimationId(nil, emote) else nil

	if animationId == nil then
		return nil
	end

	local track = self.tracks[animationId] or self:_loadLoop(emoteId, animationId)

	if track == nil then
		return nil
	end

	self.tracks[animationId] = track
	track:Play(BASE_FADE_SECONDS, math.max(weight, 0.001))

	return track
end

function DanceAnimator._loadLoop(self: DanceAnimator, emoteId: string, animationId: string): AnimationTrack?
	local animator = self.animator

	if animator == nil then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not loaded then
		warn("[DanceDanceStep] Could not load the dance loop " .. emoteId)
		return nil
	end

	-- Below Action, so _emotePlaying never mistakes it for a catalog emote.
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true

	return track
end

-- An equipped animation pack's run slot. Playing at Action priority makes
-- _emotePlaying fade the procedural dance out, so the pack owns the body.
function DanceAnimator._playPack(self: DanceAnimator, slot: string, looped: boolean): AnimationTrack?
	local animator = self.animator
	local animationId = AnimationPacks.animationFor(nil, slot)

	if animator == nil or animationId == nil then
		return nil
	end

	local track = self.tracks[animationId]

	if track == nil then
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId

		local loaded, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if not loaded then
			warn("[DanceDanceStep] Could not load the animation pack's " .. slot)
			return nil
		end

		track = result
		track.Priority = if looped then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2
		track.Looped = looped
		self.tracks[animationId] = track
	end

	track:Play(PACK_FADE_SECONDS)

	return track
end

function DanceAnimator._packSpin(self: DanceAnimator, slot: string)
	if self:_playPack(slot, false) == nil and slot ~= "Spin" then
		self:_playPack("Spin", false)
	end
end

function DanceAnimator._stopPackIdle(self: DanceAnimator)
	local idle = self.packIdle

	if idle ~= nil then
		idle:Stop(BASE_FADE_SECONDS)
		self.packIdle = nil
	end
end

-- A hold note keeps its pose until the key is let go.
function DanceAnimator.sustain(self: DanceAnimator, lane: number, active: boolean)
	if self.moveName ~= HighwayLanes.get(lane).move then
		return
	end

	self.moveUntil = if active then math.huge else os.clock() + InputStrategy.DancePoseHoldSeconds
end

function DanceAnimator._play(self: DanceAnimator, name: string, holdSeconds: number)
	local pose = DancePoses.Moves[name]

	if pose == nil then
		return
	end

	if self.fever then
		pose = DancePoses.scaled(pose, InputStrategy.DanceFeverScale)
	end

	local now = os.clock()

	if self.moveName == name and now < self.moveUntil then
		DancePoses.kick(self.layer, pose, InputStrategy.DanceRepressKick)
	end

	self.layer.velocity.Root[5] -= InputStrategy.DancePressDip
	self.move = pose
	self.moveName = name
	self.moveUntil = now + holdSeconds
end

-- Returns false when there is no rig to pose, so the caller can fall back.
function DanceAnimator.strike(self: DanceAnimator, lane: number): boolean
	if self.rig == nil or not self.active then
		return false
	end

	local hold = math.max(InputStrategy.DancePoseHoldSeconds, self.beatSeconds * InputStrategy.DancePoseHoldBeats)
	self:_play(HighwayLanes.get(lane).move, hold)

	return true
end

-- The server's verdict: a slump on a Miss, a cheer on each combo milestone.
function DanceAnimator.react(self: DanceAnimator, grade: string, combo: number)
	if self.rig == nil or not self.active then
		return
	end

	if grade == "Miss" then
		self.missAt = os.clock()
		self.lastCombo = 0
		self:_play("miss", InputStrategy.DanceMissHoldSeconds)
		return
	end

	local interval = EmoteCatalog.ComboMilestoneInterval

	if combo > 0 and combo % interval == 0 and combo ~= self.lastCombo then
		self.lastCombo = combo
		self:_play("cheer", InputStrategy.DanceCheerHoldSeconds)
	end
end

function DanceAnimator._emotePlaying(self: DanceAnimator): boolean
	local animator = self.animator

	if animator == nil then
		return false
	end

	for _, track in animator:GetPlayingAnimationTracks() do
		if EMOTE_PRIORITIES[track.Priority] and track.WeightCurrent > 0.1 then
			return true
		end
	end

	return false
end

function DanceAnimator._update(self: DanceAnimator, now: number, dt: number)
	local rig = self.rig

	if rig == nil then
		return
	end

	local wanted = if self.active and not self:_emotePlaying() then 1 else 0
	self.presence += (wanted - self.presence) * (1 - math.exp(-FADE_RATE * dt))

	if wanted == 0 and self.presence < 0.01 then
		self.presence = 0
		DanceRig.restore(rig)
		return
	end

	if self.pad then
		self:_updatePad(rig, now, dt)
		return
	end

	local holding = self.move ~= nil and now < self.moveUntil
	local target = if holding then self.move else nil
	DancePoses.stepLayer(self.layer, target, if holding then DancePoses.Snap else DancePoses.Release, dt)
	self.activity += ((if holding then 1 else 0) - self.activity) * (1 - math.exp(-ACTIVITY_RATE * dt))

	local base = self.base
	local pose = DancePoses.groove(self.beat, self.fever, 1 - self.activity)

	if base ~= nil then
		pose = DancePoses.scaled(pose, GROOVE_OVER_BASE)

		local weight = self:_baseWeightFor(self.activity)

		if math.abs(weight - self.baseWeight) > 0.02 then
			self.baseWeight = weight
			base:AdjustWeight(math.max(weight, 0.001), 0.05)
		end
	end

	DancePoses.addInto(pose, self.layer.value, 1)

	local missAge = now - self.missAt
	local shake = math.max(1 - missAge / InputStrategy.DanceMissHoldSeconds, 0)

	if shake > 0 then
		pose.Neck[2] += math.sin(missAge * MISS_SHAKE_SPEED) * MISS_SHAKE_RADIANS * shake
	end

	DanceRig.writePose(rig, pose, self.presence)
end

-- The character faces the audience on the pad, and the camera looks from the
-- audience, so a step toward screen left is a move to the dancer's right.
function DanceAnimator.attachStepMover(self: DanceAnimator, stepMover: StepMover.StepMover)
	self.stepMover = stepMover
	self:_syncFacing()
end

function DanceAnimator._syncFacing(self: DanceAnimator)
	local stepMover = self.stepMover

	if stepMover ~= nil then
		stepMover:setFacesAudience(self.pad and self.rig ~= nil)
	end
end

function DanceAnimator.padStart(self: DanceAnimator, bpm: number)
	if bpm > 0 then
		self.beatSeconds = Timing.beatSeconds(bpm)
	end

	self.pad = true
	self.padCombo = 0
	self.beat = 0
	self.beatAt = os.clock()
	self.perfectSteps = 0
	PadDanceMoves.reset(self.dancer)
	self:setActive(true)
	self:_syncFacing()
	self:_stopPackIdle()

	if self.rig ~= nil then
		self.packIdle = self:_playPack("RoundIdle", true)
	end
end

function DanceAnimator.padStop(self: DanceAnimator)
	if not self.pad then
		return
	end

	self.pad = false
	self.padCombo = 0
	self:_stopPackIdle()
	self:setActive(false)
	self:_syncFacing()
end

function DanceAnimator._padReady(self: DanceAnimator): boolean
	return self.rig ~= nil and self.active and self.pad
end

-- grade is the predicted grade when the step lands on a live target, else nil.
-- kind "shape" adds a spin, "rush" swaps the move for a running stride.
function DanceAnimator.padStep(self: DanceAnimator, dx: number, dy: number, grade: string?, kind: string?)
	if not self:_padReady() then
		return
	end

	local perfect = grade == "Perfect"
	local strength: PadDanceMoves.Strength = if perfect or self.fever
		then "perfect"
		elseif grade ~= nil then "hit"
		else "free"
	local now = os.clock()
	self.variant += 1
	PadDanceMoves.strike(
		self.dancer,
		if kind == "rush"
			then PadDanceMoves.pickRun(self.variant)
			else PadDanceMoves.pick(dx, dy, self.variant, strength),
		PadDanceMoves.strengthScale(strength),
		now
	)
	PadDanceMoves.travel(self.dancer, dx, dy, kind == "rush", self.beatSeconds, now)

	local stepSlot = PACK_STEP_SLOTS[`{math.sign(dx)},{math.sign(dy)}`]

	if kind == "shape" then
		PadDanceMoves.spin(self.dancer, if dx ~= 0 then -dx else self.variant % 2 * 2 - 1, now)
		self:_packSpin("Spin")
		return
	end

	if stepSlot ~= nil and self:_playPack(stepSlot, false) == nil and stepSlot == "StepDown" then
		self:_playPack("StepUp", false)
	end

	if not perfect then
		return
	end

	self.perfectSteps += 1

	if self.perfectSteps % PAD_SPIN_EVERY == 0 then
		PadDanceMoves.spin(self.dancer, if dx ~= 0 then -dx else self.variant % 2 * 2 - 1, now)
		self:_packSpin("Spin")
	end
end

function DanceAnimator.padPose(self: DanceAnimator, seconds: number)
	if not self:_padReady() then
		return
	end

	self.variant += 1
	PadDanceMoves.hold(self.dancer, PadDanceMoves.pickPose(self.variant), seconds, os.clock())
end

-- Front and overhead claps alternate; from a long combo the overhead one jumps.
function DanceAnimator.padClap(self: DanceAnimator)
	if not self:_padReady() then
		return
	end

	local now = os.clock()
	self.variant += 1
	PadDanceMoves.strike(self.dancer, PadDanceMoves.pickClap(self.variant), 1, now)

	if PadDanceMoves.isOverheadClap(self.variant) and PadDanceMoves.clapJumps(self.padCombo) then
		PadDanceMoves.jump(self.dancer, now)
	else
		PadDanceMoves.bounce(self.dancer, now)
	end
end

-- One stride per purple tile reached, longer and harder toward the end of the run.
function DanceAnimator.padRunStep(self: DanceAnimator, index: number, count: number)
	if not self:_padReady() then
		return
	end

	local progress = if count > 1 then math.clamp((index - 1) / (count - 1), 0, 1) else 1
	self.variant += 1
	PadDanceMoves.strike(
		self.dancer,
		PadDanceMoves.pickRun(self.variant, progress),
		1 + PAD_RUN_ACCENT * progress,
		os.clock()
	)
end

function DanceAnimator.padRunDone(self: DanceAnimator, perfect: boolean)
	if not self:_padReady() then
		return
	end

	local now = os.clock()

	if not perfect then
		PadDanceMoves.stumble(self.dancer, now)
		return
	end

	self.variant += 1
	PadDanceMoves.spin(self.dancer, self.variant % 2 * 2 - 1, now)
	PadDanceMoves.hold(self.dancer, PadDanceMoves.pickRunFinish(self.variant), PAD_FINISH_HOLD_SECONDS, now)
	self:_packSpin("Spin")
end

function DanceAnimator.padHoldStart(self: DanceAnimator, seconds: number)
	if not self:_padReady() then
		return
	end

	self.variant += 1
	PadDanceMoves.holdGroove(self.dancer, PadDanceMoves.pickHold(self.variant), seconds, os.clock())
end

-- held is false when the dancer stepped off before the end.
function DanceAnimator.padHoldEnd(self: DanceAnimator, held: boolean)
	if not self:_padReady() then
		return
	end

	local now = os.clock()

	if held then
		PadDanceMoves.strike(self.dancer, PadDanceMoves.HoldPop, PAD_FINISH_ACCENT, now)
		PadDanceMoves.jump(self.dancer, now)
	else
		PadDanceMoves.strike(self.dancer, PadDanceMoves.HoldSlump, 1, now)
	end
end

function DanceAnimator.padVerdict(self: DanceAnimator, grade: string, combo: number)

	if not self.pad then
		return
	end

	local previous = self.padCombo
	self.padCombo = if grade == "Miss" then 0 else combo

	if (previous >= PAD_BASE_COMBO) ~= (self.padCombo >= PAD_BASE_COMBO) then
		self:_syncBase()
	end

	if self.rig == nil or not self.active then
		return
	end

	local now = os.clock()

	if grade == "Miss" then
		self.perfectSteps = 0
		self.lastCombo = 0
		PadDanceMoves.stumble(self.dancer, now)
		return
	end

	if combo ~= self.lastCombo and PadDanceMoves.isMilestone(combo) then
		self.lastCombo = combo
		PadDanceMoves.spin(self.dancer, self.variant % 2 * 2 - 1, now)
		PadDanceMoves.strike(self.dancer, PadDanceMoves.Flourish, 1, now)
		self:_packSpin("SpinKick")
	end
end

function DanceAnimator._updatePad(self: DanceAnimator, rig: DanceRig.Rig, now: number, dt: number)
	-- The run may only report whole beats, so the groove runs on between them.
	local since = math.min(now - self.beatAt, PAD_MAX_EXTRAPOLATED_BEATS * self.beatSeconds)
	local beat = self.beat + since / self.beatSeconds
	local hop, landedAt = nil, -math.huge
	local stepMover = self.stepMover

	if stepMover ~= nil then
		hop, landedAt = stepMover:getHop(now)
	end

	local dancer = self.dancer
	local pose =
		PadDanceMoves.update(dancer, now, dt, beat, self.beatSeconds, self.padCombo, self.fever, hop, landedAt)
	local base = self.base

	if base ~= nil then
		local weight = self:_baseWeightFor(dancer.activity)

		if math.abs(weight - self.baseWeight) > 0.02 then
			self.baseWeight = weight
			base:AdjustWeight(math.max(weight, 0.001), 0.05)
		end
	end

	DanceRig.writePose(rig, pose, self.presence)
end

function DanceAnimator.destroy(self: DanceAnimator)
	for _, connection in self.connections do
		connection:Disconnect()
	end

	table.clear(self.connections)
	self.active = false
	self:_syncBase()

	local rig = self.rig

	if rig ~= nil then
		DanceRig.restore(rig)
	end
end

return DanceAnimator
