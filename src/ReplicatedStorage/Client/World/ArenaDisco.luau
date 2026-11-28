--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Board = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Board"))
local ArenaKit = require(script.Parent.ArenaKit)
local ArenaPalette = require(script.Parent.ArenaPalette)

local Accent = ArenaPalette.Accent

-- Either side of the LED wall's title, where the floor camera shows them clear of the HUD.
local BALL_POSITIONS = { Vector3.new(-15, 20, -8), Vector3.new(15, 20, -8) }
local BALL_DIAMETER = 4.5
local BALL_COLOR = Color3.fromRGB(92, 92, 116)
local CABLE_LENGTH = 30
local HEAD_COUNT = 4
local HEAD_SPACING = 16
local HEAD_Y = 22.4
local HEAD_Z = -18
local TARGET_Y = 0.3
-- Beams land on a ring around the dance floor, so they light the crowd and the
-- deck and only cross the tiles as haze.
local RING_X = 34
local RING_Z = 28
local BEAM_WIDTH = Vector2.new(0.8, 7)
local BEAM_REST = 0.85
local BEAM_PEAK = 0.55
local MILESTONE_SECONDS = 0.6
local DISCO_COLORS = {
	Color3.fromRGB(255, 64, 180),
	Color3.fromRGB(64, 224, 255),
	Accent.Gold,
	Color3.fromRGB(150, 90, 255),
	Color3.fromRGB(80, 255, 150),
}
local MISS_COLOR = Color3.fromRGB(110, 106, 130)

-- How fast the heads sweep and the ball spins for each section; fever also strobes.
local ENERGY: { [string]: { sweep: number, spin: number, sparkle: number } } = {
	none = { sweep = 0.25, spin = 0.3, sparkle = 8 },
	calm = { sweep = 0.2, spin = 0.25, sparkle = 6 },
	build = { sweep = 0.45, spin = 0.5, sparkle = 14 },
	chorus = { sweep = 0.7, spin = 0.8, sparkle = 24 },
	drop = { sweep = 1, spin = 1.1, sparkle = 36 },
	fever = { sweep = 1.2, spin = 1.4, sparkle = 44 },
}

type Head = {
	part: Part,
	beam: Beam,
	target: Part,
	index: number,
}

local ArenaDisco = {}

export type ArenaDisco = {
	onBeat: (phase: number, beatIndex: number) -> (),
	setMood: (mood: string, combo: number) -> (),
	setEnergy: (energy: string) -> (),
	milestone: () -> (),
}

local function headName(index: number): string
	return ("disco_head_%02d"):format(index)
end

local function ballName(index: number): string
	return ("disco_ball_%02d"):format(index)
end

local function targetName(index: number): string
	return ("disco_target_%02d"):format(index)
end

-- Two mirror balls over the stage, and a row of moving heads on the truss throwing
-- coloured beams through the haze. Beams cost no light budget; the haze from
-- StageLighting is what makes them read.
function ArenaDisco.build(kit: ArenaKit.ArenaKit)
	kit:section("Disco")

	for index, position in BALL_POSITIONS do
		-- A reflective ball has nothing to reflect in a dark club, so it glows a dim silver instead.
		local ball = kit:ball(ballName(index), BALL_DIAMETER, position, BALL_COLOR, Enum.Material.Neon)

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Shape = Enum.ParticleEmitterShape.Sphere
		sparkle.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		sparkle.Rate = ENERGY.none.sparkle
		sparkle.Lifetime = NumberRange.new(0.25, 0.5)
		sparkle.Speed = NumberRange.new(0)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(Accent.White)
		sparkle.Parent = ball

		kit:box(
			ballName(index) .. "_cable",
			Vector3.new(0.15, CABLE_LENGTH, 0.15),
			position + Vector3.new(0, BALL_DIAMETER / 2 + CABLE_LENGTH / 2, 0),
			Color3.fromRGB(40, 40, 48)
		)
	end

	for index = 1, HEAD_COUNT do
		local x = (index - (HEAD_COUNT + 1) / 2) * HEAD_SPACING
		local head = kit:box(headName(index), Vector3.new(1.3, 1.5, 1.3), Vector3.new(x, HEAD_Y, HEAD_Z), Color3.fromRGB(30, 28, 40), Enum.Material.Metal)
		local target = kit:anchor(targetName(index), Vector3.new(x, TARGET_Y, 0))
		local from = Instance.new("Attachment")
		from.Name = "BeamFrom"
		from.Position = Vector3.new(0, -0.8, 0)
		from.Parent = head

		local to = Instance.new("Attachment")
		to.Name = "BeamTo"
		to.Parent = target

		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Width0 = BEAM_WIDTH.X
		beam.Width1 = BEAM_WIDTH.Y
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(DISCO_COLORS[(index - 1) % #DISCO_COLORS + 1])
		beam.Transparency = NumberSequence.new(BEAM_REST, 1)
		beam.Parent = head
	end
end

function ArenaDisco.bind(arena: Instance): ArenaDisco
	local balls: { { part: Part, home: CFrame, sparkle: ParticleEmitter? } } = {}

	for index in BALL_POSITIONS do
		local part = ArenaKit.findPart(arena, ballName(index))

		if part ~= nil then
			table.insert(balls, { part = part, home = part.CFrame, sparkle = part:FindFirstChildOfClass("ParticleEmitter") })
		end
	end
	local heads: { Head } = {}

	for index = 1, HEAD_COUNT do
		local part = ArenaKit.findPart(arena, headName(index))
		local target = ArenaKit.findPart(arena, targetName(index))
		local beam = if part ~= nil then part:FindFirstChildOfClass("Beam") else nil

		if part ~= nil and target ~= nil and beam ~= nil then
			table.insert(heads, { part = part, beam = beam, target = target, index = index })
		end
	end

	local profile = ENERGY.none
	local missed = false
	local idle = true
	local milestoneAt = -math.huge
	local lastBeat = -1
	local sweepClock = 0
	local spin = 0
	local lastAt = os.clock()

	local function paint(beatIndex: number)
		for _, head in heads do
			local color = if missed
				then MISS_COLOR
				elseif idle then Accent.Lilac
				else DISCO_COLORS[(beatIndex + head.index) % #DISCO_COLORS + 1]

			head.beam.Color = ColorSequence.new(color)
		end
	end

	return {
		onBeat = function(phase, beatIndex)
			local now = os.clock()
			local dt = math.min(now - lastAt, 0.1)
			lastAt = now
			sweepClock += dt * profile.sweep
			spin += dt * profile.spin

			for index, ball in balls do
				ball.part.CFrame = ball.home * CFrame.Angles(0, if index % 2 == 0 then -spin else spin, 0)
			end

			local kick = (1 - phase) ^ 2
			local flash = math.max(1 - (now - milestoneAt) / MILESTONE_SECONDS, 0)
			local strobeOff = profile == ENERGY.fever and phase > 0.5
			local alpha = if strobeOff then 0.85 else BEAM_REST - (BEAM_REST - BEAM_PEAK) * math.max(kick, flash)

			for _, head in heads do
				local angle = sweepClock * (if head.index % 2 == 0 then 1 else -1) + head.index * (2 * math.pi / HEAD_COUNT)
				local aim = Board.Origin + Vector3.new(RING_X * math.cos(angle), TARGET_Y, RING_Z * math.sin(angle))

				head.target.Position = aim
				head.part.CFrame = CFrame.lookAt(head.part.Position, aim) * CFrame.Angles(math.pi / 2, 0, 0)
				head.beam.Transparency = NumberSequence.new(alpha, 1)
			end

			if beatIndex ~= lastBeat then
				lastBeat = beatIndex
				paint(beatIndex)
			end
		end,
		setMood = function(mood, _combo)
			missed = mood == "miss"
			idle = mood == "idle"
			paint(lastBeat)
		end,
		setEnergy = function(energy)
			profile = ENERGY[energy] or ENERGY.none

			for _, ball in balls do
				if ball.sparkle ~= nil then
					ball.sparkle.Rate = profile.sparkle
				end
			end
		end,
		milestone = function()
			milestoneAt = os.clock()

			for _, ball in balls do
				if ball.sparkle ~= nil then
					ball.sparkle:Emit(40)
				end
			end
		end,
	}
end

return ArenaDisco
