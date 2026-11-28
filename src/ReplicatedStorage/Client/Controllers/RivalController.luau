--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local Ease = require(Shared:WaitForChild("Ease"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local Timing = require(Shared:WaitForChild("Timing"))
local AvatarReactionController = require(script.Parent.Parent.Dance.AvatarReactionController)
local DanceRig = require(script.Parent.Parent.Dance.DanceRig)
local PadDanceMoves = require(script.Parent.Parent.Dance.PadDanceMoves)
local RivalFloor = require(script.Parent.Parent.Floor.RivalFloor)
local RivalPortrait = require(script.Parent.Parent.UI.Screens.RivalPortrait)
local UiKit = require(script.Parent.Parent.UI.UiKit)

-- Far enough out to clear the stage deck around the player's floor, raised so the
-- rival's podium reads as a stage of its own, and set back toward the stage so the
-- floor camera keeps all of it in frame.
local PAD_GAP = 9
local PAD_LIFT = 1.2
local PAD_BACK = 14
local HOP_TILES = 2
local HOP_HEIGHT = 1.8
local DODGE_LEAD_BEATS = 0.5
local MISS_LATE_GRACES = 2
local MILESTONE_COMBO = 25
local FACE_CAMERA = CFrame.Angles(0, math.pi, 0)
local SPIN = math.pi * 2
local SPIN_EVERY_PERFECTS = 4
-- The race stays close: past this share of the combined score the leader's
-- next hit may slip a grade, and the trailer's may lift one.
local CATCH_UP_LEAD = 0.06
local CATCH_UP_CHANCE = 0.35
local SLIP: { [string]: string } = { Perfect = "Great", Great = "Good", Good = "Miss" }
local LIFT: { [string]: string } = { Miss = "Good", Good = "Great", Great = "Perfect" }
local FINALE_EMOTE = "pixel-finale-001"
local DIRECTIONS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }

local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(255, 226, 76),
	Great = Color3.fromRGB(106, 255, 128),
	Good = Color3.fromRGB(83, 224, 255),
	Miss = Color3.fromRGB(255, 70, 90),
}

-- hit: chance a step lands at all; perfect/great: shares of the hits; dodge:
-- chance it steps off a danger tile in time. Close to a good player, so the
-- race is winnable.
local SKILL = {
	easy = { hit = 0.93, perfect = 0.5, great = 0.38, dodge = 0.92 },
	normal = { hit = 0.88, perfect = 0.45, great = 0.4, dodge = 0.85 },
	hard = { hit = 0.84, perfect = 0.4, great = 0.42, dodge = 0.8 },
	expert = { hit = 0.8, perfect = 0.36, great = 0.44, dodge = 0.75 },
}

local LOOKS: { RivalFloor.Look } = {
	{
		name = "Kira Nova",
		color = Color3.fromRGB(240, 60, 80),
		skin = Color3.fromRGB(255, 214, 190),
		outfit = Color3.fromRGB(255, 70, 160),
		legs = Color3.fromRGB(40, 20, 60),
		hair = 7193454569,
		shirt = 398634295,
		pants = 398634487,
	},
	{
		name = "Mira Volt",
		color = Color3.fromRGB(80, 230, 255),
		skin = Color3.fromRGB(198, 140, 105),
		outfit = Color3.fromRGB(60, 200, 255),
		legs = Color3.fromRGB(30, 30, 70),
		hair = 451221329,
		shirt = 398633584,
		pants = 382538503,
	},
	{
		name = "Juno Spark",
		color = Color3.fromRGB(255, 200, 60),
		skin = Color3.fromRGB(240, 190, 150),
		outfit = Color3.fromRGB(255, 180, 40),
		legs = Color3.fromRGB(60, 20, 80),
		hair = 376526888,
		shirt = 4047886060,
		pants = 382537950,
	},
	{
		name = "Lumi Star",
		color = Color3.fromRGB(190, 110, 255),
		skin = Color3.fromRGB(120, 80, 60),
		outfit = Color3.fromRGB(170, 90, 255),
		legs = Color3.fromRGB(25, 25, 45),
		hair = 1103003368,
		shirt = 398635081,
		pants = 398635338,
	},
}

type Deps = {
	hud: any,
	floors: any,
	portrait: RivalPortrait.RivalPortrait,
}

type Fields = {
	deps: Deps,
	active: boolean,
	runToken: number,
	look: RivalFloor.Look,
	floor: RivalFloor.RivalFloor?,
	templates: { [string]: Model },
	steps: { any },
	stepTimes: { number },
	plans: { string },
	landOffsets: { number },
	judgeIndex: number,
	moveIndex: number,
	hopSeconds: number,
	score: Scoring.ScoreState,
	ownScore: number,
	tileX: number,
	tileY: number,
	hopFrom: Vector3,
	hopTo: Vector3,
	hopStart: number,
	hopEnd: number,
	hopping: boolean,
	spinNext: boolean,
	hopSpins: boolean,
	dancer: PadDanceMoves.Dancer,
	danceRig: DanceRig.Rig?,
	variant: number,
	perfects: number,
	landedAt: number,
	lastFrame: number,
	beatSeconds: number,
	catchUp: Random,
}

-- A bot that dances the player's chart on a small floor beside theirs and races
-- them on the song bar. Cosmetic and client-only: it never talks to the server.
local RivalController = {}
RivalController.__index = RivalController

export type RivalController = typeof(setmetatable({} :: Fields, RivalController))

local function seedFor(text: string): number
	local hash = 7

	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index)) % 2147483647
	end

	return hash
end

-- A phone has no room beside the player's pad, so there the race is only the versus line.
local function roomBeside(): boolean
	local camera = Workspace.CurrentCamera

	return camera == nil or not UiKit.isPhoneViewport(camera.ViewportSize)
end

local function hasCoord(step: any): boolean
	return type(step) == "table" and type(step.x) == "number" and type(step.y) == "number"
end

function RivalController.new(deps: Deps): RivalController
	local fields: Fields = {
		deps = deps,
		active = false,
		runToken = 0,
		look = LOOKS[1],
		floor = nil,
		templates = {},
		steps = {},
		stepTimes = {},
		plans = {},
		landOffsets = {},
		judgeIndex = 1,
		moveIndex = 1,
		hopSeconds = 0,
		score = Scoring.createState(),
		ownScore = 0,
		tileX = 1,
		tileY = 1,
		hopFrom = Vector3.zero,
		hopTo = Vector3.zero,
		hopStart = 0,
		hopEnd = 0,
		hopping = false,
		spinNext = false,
		hopSpins = false,
		dancer = PadDanceMoves.newDancer(),
		danceRig = nil,
		variant = 0,
		perfects = 0,
		landedAt = -math.huge,
		lastFrame = os.clock(),
		beatSeconds = 0.5,
		catchUp = Random.new(),
	}

	return setmetatable(fields, RivalController)
end

function RivalController.isActive(self: RivalController): boolean
	return self.active
end

function RivalController.start(self: RivalController, map: any, difficulty: string)
	self:stop()

	if type(map) ~= "table" or type(map.steps) ~= "table" or type(map.bpm) ~= "number" or map.bpm <= 0 then
		return
	end

	local seedText = tostring(map.songId or map.title or "") .. ":" .. difficulty
	local random = Random.new(seedFor(seedText))
	self.catchUp = Random.new(seedFor(seedText) + 1)
	local look = LOOKS[random:NextInteger(1, #LOOKS)]

	self.active = true
	self.runToken += 1
	self.look = look
	self.steps = map.steps
	self.judgeIndex = 1
	self.moveIndex = 1
	self.hopSeconds = Timing.getStepSeconds(difficulty) * HOP_TILES
	self.score = Scoring.createState()
	self.ownScore = 0
	self.hopping = false
	self.spinNext = false
	self.danceRig = nil
	self.variant = 0
	self.perfects = 0
	self.landedAt = -math.huge
	self.beatSeconds = Timing.beatSeconds(map.bpm)
	PadDanceMoves.reset(self.dancer)
	self:_plan(random, map.bpm, difficulty)

	local start = Board.centerCoord()
	self.tileX = start.x
	self.tileY = start.y

	local floor = RivalFloor.new(self:_padOrigin(), Board.Columns, Board.Rows, look)
	self.floor = floor
	self:_showFloor(floor, roomBeside())
	self.deps.portrait:setRival(look)

	self:_pushVersus()

	local token = self.runToken

	task.spawn(function()
		local template = self:_template(look)

		if not self.active or self.runToken ~= token then
			return
		end

		local rig = template:Clone()
		floor:setRig(rig)
		floor:placeRig(CFrame.new(floor:standPoint(self.tileX, self.tileY)) * FACE_CAMERA)
		self:_bindDancer(rig)
		self.deps.portrait:setAvatar(rig)
	end)
end

-- The bot dances with the player's own move set, so the two read as one game.
function RivalController._bindDancer(self: RivalController, rig: Model)
	local danceRig = DanceRig.find(rig)
	self.danceRig = danceRig

	if danceRig == nil then
		return
	end

	local thigh, shin = DanceRig.measureLegs(danceRig)

	if thigh ~= nil and shin ~= nil then
		PadDanceMoves.setLegs(self.dancer, thigh, shin)
	end
end

function RivalController._template(self: RivalController, look: RivalFloor.Look): Model
	local cached: Model? = self.templates[look.name]

	if cached ~= nil then
		return cached
	end

	local template = RivalFloor.buildRig(look)
	self.templates[look.name] = template

	return template
end

-- Beside the player's floor, on the left and set back, where the song bar shows the rival.
function RivalController._padOrigin(self: RivalController): Vector3
	local floors = self.deps.floors
	local own = if floors ~= nil and floors.getOwnOrigin ~= nil then floors:getOwnOrigin() else Board.Origin
	local footprint = RivalFloor.footprint(Board.Columns, Board.Rows)
	local ownHalf = Board.Columns * Board.TileSize / 2

	return own - Vector3.new(ownHalf + PAD_GAP + footprint.X / 2, -PAD_LIFT, PAD_BACK)
end

-- Every roll is made up front from the song's seed, so a song plays the same
-- rival every time.
function RivalController._plan(self: RivalController, random: Random, bpm: number, difficulty: string)
	local skill = SKILL[difficulty] or SKILL.normal
	local windows = Timing.getOnBeatWindows(difficulty)
	local beatSeconds = Timing.beatSeconds(bpm)
	local stepTimes = self.stepTimes
	local plans = self.plans
	local landOffsets = self.landOffsets

	table.clear(stepTimes)
	table.clear(plans)
	table.clear(landOffsets)

	for index, step in self.steps do
		local beat = if type(step) == "table" and type(step.beat) == "number" then step.beat else 1
		local sign = if random:NextNumber() < 0.5 then -1 else 1
		local plan = "Miss"
		local offset = Timing.OnBeatLateGrace * MISS_LATE_GRACES

		if not hasCoord(step) or step.type == "item" then
			plan = "skip"
			offset = 0
		elseif step.type == "danger" then
			plan = if random:NextNumber() < skill.dodge then "dodge" else "stay"
			offset = -beatSeconds * DODGE_LEAD_BEATS
		elseif random:NextNumber() < skill.hit then
			local roll = random:NextNumber()

			if roll < skill.perfect then
				plan = "Perfect"
				offset = sign * random:NextNumber(0, windows.perfectWindow / 2)
			elseif roll < skill.perfect + skill.great then
				plan = "Great"
				offset = sign * random:NextNumber(windows.perfectWindow, windows.greatWindow)
			else
				plan = "Good"
				offset = random:NextNumber(windows.greatWindow, Timing.OnBeatLateGrace)
			end
		end

		stepTimes[index] = Timing.beatToSeconds(beat, bpm)
		plans[index] = plan
		landOffsets[index] = offset
	end
end

function RivalController.setOwnScore(self: RivalController, score: number)
	if score == self.ownScore then
		return
	end

	self.ownScore = score

	if self.active then
		self:_pushVersus()
	end
end

function RivalController._pushVersus(self: RivalController)
	local hud = self.deps.hud

	if hud == nil or hud.songBar == nil then
		return
	end

	hud.songBar:setVersus(self.ownScore, self.score.score, self.look.name, nil)
	self.deps.portrait:setLead(self.ownScore, self.score.score)
end

function RivalController._showFloor(self: RivalController, floor: RivalFloor.RivalFloor, shown: boolean)
	floor:setShown(shown)
end

-- songBeat counts from 0 at the first beat, the same fractional beat the song
-- bar is driven with.
function RivalController.update(self: RivalController, songBeat: number, beatSeconds: number)
	local floor = self.floor

	if not self.active or floor == nil then
		return
	end

	local elapsed = songBeat * beatSeconds
	local stepCount = #self.steps

	while self.judgeIndex <= stepCount and elapsed >= self.stepTimes[self.judgeIndex] do
		self:_judge(self.judgeIndex)
		self.judgeIndex += 1
	end

	while self.moveIndex <= stepCount and elapsed >= self:_hopStartTime(self.moveIndex) do
		self:_startHop(self.moveIndex, elapsed)
		self.moveIndex += 1
	end

	if self.hopping then
		self:_animateHop(floor, elapsed)
	end

	self:_dance(songBeat, elapsed)

	local shown = roomBeside()

	if shown ~= floor:isShown() then
		self:_showFloor(floor, shown)
	end

	floor:tick(os.clock())
end

function RivalController._dance(self: RivalController, songBeat: number, elapsed: number)
	local now = os.clock()
	local dt = math.clamp(now - self.lastFrame, 0, 0.1)
	self.lastFrame = now

	local danceRig = self.danceRig

	if danceRig == nil then
		return
	end

	local span = math.max(self.hopEnd - self.hopStart, 1e-3)
	local hop = if self.hopping then math.clamp((elapsed - self.hopStart) / span, 0, 1) else nil
	local pose = PadDanceMoves.update(
		self.dancer,
		now,
		dt,
		songBeat,
		self.beatSeconds,
		self.score.combo,
		false,
		hop,
		self.landedAt
	)
	DanceRig.setPose(danceRig, pose, 1)
end

function RivalController._hopStartTime(self: RivalController, index: number): number
	return self.stepTimes[index] + self.landOffsets[index] - self.hopSeconds
end

function RivalController._dodgeTile(self: RivalController, step: any): (number, number)
	local floor = self.floor

	for _, direction in DIRECTIONS do
		local x = self.tileX + direction.X
		local y = self.tileY + direction.Y

		if floor ~= nil and floor:isValid(x, y) and not (x == step.x and y == step.y) then
			return x, y
		end
	end

	return self.tileX, self.tileY
end

function RivalController._startHop(self: RivalController, index: number, elapsed: number)
	local floor = self.floor
	local step = self.steps[index]
	local plan = self.plans[index]

	if floor == nil or plan == "skip" or plan == "stay" then
		return
	end

	local x, y = step.x, step.y

	if plan == "dodge" then
		if self.tileX ~= step.x or self.tileY ~= step.y then
			return
		end

		x, y = self:_dodgeTile(step)
	end

	if not floor:isValid(x, y) or (x == self.tileX and y == self.tileY and not self.hopping) then
		return
	end

	local from = if self.hopping then self.hopTo else floor:standPoint(self.tileX, self.tileY)
	local dx, dy = x - self.tileX, y - self.tileY

	self.tileX = x
	self.tileY = y
	self.hopFrom = from
	self.hopTo = floor:standPoint(x, y)
	self.hopStart = elapsed
	self.hopEnd = math.max(self.stepTimes[index] + self.landOffsets[index], elapsed + self.hopSeconds / HOP_TILES)
	self.hopping = true
	self.hopSpins = self.spinNext
	self.spinNext = false

	if plan ~= "dodge" then
		floor:markTarget(x, y, self.look.color)
	end

	self:_strike(dx, dy, plan)
end

function RivalController._strike(self: RivalController, dx: number, dy: number, plan: string)
	local strength: PadDanceMoves.Strength = if plan == "Perfect"
		then "perfect"
		elseif plan == "dodge" then "free"
		else "hit"
	local now = os.clock()
	self.variant += 1
	PadDanceMoves.strike(
		self.dancer,
		PadDanceMoves.pick(dx, dy, self.variant, strength),
		PadDanceMoves.strengthScale(strength),
		now
	)
	PadDanceMoves.travel(self.dancer, dx, dy, false, self.beatSeconds, now)
end

function RivalController._animateHop(self: RivalController, floor: RivalFloor.RivalFloor, elapsed: number)
	local span = math.max(self.hopEnd - self.hopStart, 1e-3)
	local t = math.clamp((elapsed - self.hopStart) / span, 0, 1)
	local eased = Ease.outQuad(t)
	local position = self.hopFrom:Lerp(self.hopTo, eased) + Vector3.new(0, 4 * t * (1 - t) * HOP_HEIGHT, 0)
	local spin = if self.hopSpins then CFrame.Angles(0, SPIN * eased, 0) else CFrame.identity

	floor:placeRig(CFrame.new(position) * FACE_CAMERA * spin)

	if t >= 1 then
		self.hopping = false
		self.landedAt = os.clock()
	end
end

function RivalController._judge(self: RivalController, index: number)
	local step = self.steps[index]
	local plan = self.plans[index]
	local floor = self.floor

	if plan == "skip" or floor == nil then
		return
	end

	local grade = plan
	local flashX, flashY = step.x, step.y

	if step.type == "danger" then
		local onDanger = self.tileX == step.x and self.tileY == step.y
		grade = if onDanger then "Miss" else "Perfect"
		flashX, flashY = self.tileX, self.tileY
	else
		grade = self:_keepClose(grade)
	end

	Scoring.applyGrade(self.score, grade, step)
	floor:flash(flashX, flashY, GRADE_COLORS[grade] or GRADE_COLORS.Good)
	self:_pushVersus()

	local milestone = grade ~= "Miss" and self.score.combo % MILESTONE_COMBO == 0
	self.deps.portrait:react(grade, milestone)
	self:_react(grade, milestone)

	if index == #self.steps then
		self.danceRig = nil
		AvatarReactionController.playEmoteOnCharacter(floor:getRig(), FINALE_EMOTE)
	end
end

-- Nudges a planned grade one step toward a close race; danger is never nudged.
function RivalController._keepClose(self: RivalController, grade: string): string
	local total = self.ownScore + self.score.score

	if total <= 0 or self.catchUp:NextNumber() >= CATCH_UP_CHANCE then
		return grade
	end

	local lead = (self.score.score - self.ownScore) / total

	if lead > CATCH_UP_LEAD then
		return SLIP[grade] or grade
	elseif lead < -CATCH_UP_LEAD then
		return LIFT[grade] or grade
	end

	return grade
end

function RivalController._react(self: RivalController, grade: string, milestone: boolean)
	local now = os.clock()
	local direction = self.variant % 2 * 2 - 1

	if grade == "Miss" then
		self.perfects = 0
		PadDanceMoves.stumble(self.dancer, now)
		return
	end

	if milestone then
		self.spinNext = true
		PadDanceMoves.strike(self.dancer, PadDanceMoves.Flourish, 1, now)
		PadDanceMoves.jump(self.dancer, now)
		return
	end

	if grade ~= "Perfect" then
		return
	end

	self.perfects += 1

	if self.perfects % SPIN_EVERY_PERFECTS == 0 then
		PadDanceMoves.spin(self.dancer, direction, now)
	end
end

function RivalController.getScore(self: RivalController): number
	return self.score.score
end

function RivalController.getName(self: RivalController): string
	return self.look.name
end

function RivalController.stop(self: RivalController)
	if not self.active then
		return
	end

	self.active = false
	self.runToken += 1
	self.hopping = false

	if self.floor ~= nil then
		self.floor:destroy()
		self.floor = nil
	end

	self.steps = {}
	table.clear(self.stepTimes)
	table.clear(self.plans)
	table.clear(self.landOffsets)

	local hud = self.deps.hud

	if hud ~= nil and hud.songBar ~= nil then
		hud.songBar:setVersus(0, 0, nil, nil)
	end

	self.deps.portrait:setRival(nil)
end

return RivalController
