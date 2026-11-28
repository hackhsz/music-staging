--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local HighwayLanes = require(Shared:WaitForChild("HighwayLanes"))
local TileState = require(Shared:WaitForChild("TileState"))
local Timing = require(Shared:WaitForChild("Timing"))
local DanceAnimator = require(script.Parent.Parent.Dance.DanceAnimator)
local InputController = require(script.Parent.Parent.Input.InputController)
local StepMover = require(script.Parent.Parent.Input.StepMover)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local NoteHighway = require(script.Parent.Parent.UI.Screens.NoteHighway)

local FACE_AUDIENCE_DELAY_SECONDS = 0.2
local BEATS_PER_BAR = 4
-- How long before its beat a note starts filling the bar under its key.
local METER_SECONDS = 0.6
-- How long before its beat a note starts to glow on the floor beside the
-- dancer. Shorter than the scroll, so the floor only shows what is about to land.
local FLOOR_GLOW_SECONDS = 0.6
local PRESS_FLASH_SECONDS = 0.2
local MISS_FLASH_SECONDS = 0.3

type Deps = {
	remotes: Remotes.Remotes,
	screen: NoteHighway.NoteHighway,
	boardView: any,
	input: InputController.InputController,
	stepMover: StepMover.StepMover,
	dancer: DanceAnimator.DanceAnimator,
	avatar: any,
	sfx: any,
	calibration: any,
	camera: any,
}

-- A hold whose head was caught: it stays on its key until it runs out.
type Holding = {
	index: number,
	endsAt: number,
}

type Fields = {
	deps: Deps,
	session: any,
	firstIndex: number,
	caught: { [number]: boolean },
	holding: { [number]: Holding },
	dropped: { [number]: boolean },
	fever: boolean,
}

-- The highway mode on the client: notes scroll up four lanes, a press goes to
-- the server, and the character dances a step for it on a floor that lights up
-- with the music. It decides nothing; the server grades every press.
local HighwayController = {}
HighwayController.__index = HighwayController

export type HighwayController = typeof(setmetatable({} :: Fields, HighwayController))

local FEVER_PALETTE: { Color3 } = {}

for _, lane in HighwayLanes.Lanes do
	table.insert(FEVER_PALETTE, lane.color)
end

local function holdSecondsOf(step: any): number
	return if step.type == "hold" then tonumber(step.holdSeconds) or 0 else 0
end

local function laneTile(lane: number): { x: number, y: number }
	local center = Board.centerCoord()
	local glow = HighwayLanes.get(lane).glow

	return { x = center.x + glow.x, y = center.y + glow.y }
end

function HighwayController.new(deps: Deps): HighwayController
	local fields: Fields = {
		deps = deps,
		session = nil,
		firstIndex = 1,
		caught = {},
		holding = {},
		dropped = {},
		fever = false,
	}

	local self = setmetatable(fields, HighwayController)

	deps.screen:bindPress(function(lane)
		self:press(lane)
	end)
	deps.screen:bindRelease(function(lane)
		self:release(lane)
	end)

	return self
end

-- Whether the notes land on the HUD's authored keys, which are also the touch
-- controls; otherwise the code-built step pad is needed on touch.
function HighwayController.usesAuthoredKeys(self: HighwayController): boolean
	return self.deps.screen:usesAuthoredKeys()
end

function HighwayController.isActive(self: HighwayController): boolean
	return self.session ~= nil
end

function HighwayController.begin(self: HighwayController, session: any)
	local deps = self.deps

	self.session = session
	self.firstIndex = 1
	self.fever = false
	table.clear(self.caught)
	table.clear(self.holding)
	table.clear(self.dropped)

	deps.input:setLaneMode(true)
	deps.stepMover:clearQueue()
	deps.dancer:setActive(true)
	deps.avatar:setLiveDance(true)
	deps.boardView:clearStage()
	deps.camera:setPerformance(true)
	deps.screen:render({}, {})
	deps.screen:setVisible(true)

	-- The server places the character on its floor as the song starts.
	task.delay(FACE_AUDIENCE_DELAY_SECONDS, function()
		if self.session == session then
			deps.stepMover:faceAudience()
		end
	end)
end

function HighwayController.stop(self: HighwayController)
	if self.session == nil then
		return
	end

	self.session = nil
	self.fever = false
	self.deps.input:setLaneMode(false)
	self.deps.dancer:setActive(false)
	self.deps.avatar:setLiveDance(false)
	self.deps.screen:setVisible(false)
	self.deps.boardView:clearStage()
	self.deps.camera:setPerformance(false)
end

-- The notes are drawn against the calibrated clock, so a player whose offset
-- says they press late sees each note reach the line when the server expects it.
function HighwayController._elapsed(self: HighwayController, rawElapsed: number): number
	return rawElapsed - self.deps.calibration:getOffsetSeconds()
end

function HighwayController.update(self: HighwayController, rawElapsed: number)
	local session = self.session

	if session == nil then
		return
	end

	local elapsed = self:_elapsed(rawElapsed)
	local difficulty = session.map.difficulty
	local lead = Timing.getHighwayLeadSeconds(difficulty)
	local window = Timing.getWindows(difficulty).goodWindow

	while true do
		local step = session:getStep(self.firstIndex)

		if step == nil or session:getStepTargetTime(step) + holdSecondsOf(step) + window >= elapsed then
			break
		end

		self.firstIndex += 1
	end

	-- A hold kept down to its end is done: it confirms like a hit and leaves.
	for lane, hold in self.holding do
		if elapsed >= hold.endsAt then
			self.caught[hold.index] = true
			self.holding[lane] = nil
			self.deps.screen:setSustain(lane, false)
			self.deps.screen:flashLane(lane, true)
			self.deps.dancer:sustain(lane, false)
		end
	end

	local notes = {}
	local glows = {}
	local meters = table.create(HighwayLanes.Count, 0)
	local index = self.firstIndex

	while true do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		local untilBeat = session:getStepTargetTime(step) - elapsed

		if untilBeat > lead then
			break
		end

		if not self.caught[index] then
			local kind = step.type or "tap"
			local hold = holdSecondsOf(step)
			local held = self.holding[step.x]
			local progress = 1 - untilBeat / lead
			local tail = hold / lead
			local state = nil

			if held ~= nil and held.index == index then
				-- The head stays on the key and the tail drains into it.
				state = "holding"
				progress = 1
				tail = math.max(held.endsAt - elapsed, 0) / lead
			elseif self.dropped[index] then
				state = "dropped"
			end

			table.insert(notes, { lane = step.x, progress = progress, kind = kind, tail = tail, state = state })

			if kind ~= "danger" and meters[step.x] ~= nil then
				meters[step.x] = math.max(meters[step.x], 1 - math.max(untilBeat, 0) / METER_SECONDS)
			end

			if untilBeat <= FLOOR_GLOW_SECONDS then
				local tile = laneTile(step.x)
				local color = if kind == "danger"
					then TileState.getColor(TileState.States.Danger)
					else HighwayLanes.get(step.x).color

				table.insert(glows, {
					x = tile.x,
					y = tile.y,
					color = color,
					strength = 1 - math.max(untilBeat, 0) / FLOOR_GLOW_SECONDS,
				})
			end
		end

		index += 1
	end

	local deps = self.deps
	local bpm = tonumber(session.map.bpm) or 120
	local beatSeconds = Timing.beatSeconds(bpm)
	local beat = elapsed / beatSeconds
	local beatLines = {}

	for line = math.max(math.ceil(beat), 0), math.floor((elapsed + lead) / beatSeconds) do
		table.insert(beatLines, {
			progress = 1 - (line * beatSeconds - elapsed) / lead,
			strong = line % BEATS_PER_BAR == 0,
		})
	end

	deps.screen:render(notes, beatLines)
	deps.screen:setMeters(meters)
	deps.screen:pulse(beat % 1)
	deps.boardView:renderStage(os.clock(), glows, beat, if self.fever then FEVER_PALETTE else nil)
	deps.camera:setBeat(beat)
	deps.dancer:setBeat(beat, beatSeconds)
end

function HighwayController.press(self: HighwayController, lane: number)
	local session = self.session

	if session == nil then
		return
	end

	local deps = self.deps
	local style = HighwayLanes.get(lane)
	local tile = laneTile(lane)

	deps.remotes.SubmitPress:FireServer({
		lane = lane,
		t = os.clock() + Workspace:GetServerTimeNow() - os.clock(),
		s = session:toShared(os.clock(), Workspace:GetServerTimeNow() - os.clock())
			- (os.clock() + Workspace:GetServerTimeNow() - os.clock()),
	})
	if not deps.dancer:strike(lane) then
		deps.stepMover:bounce(style.step.x, style.step.y)
	end
	deps.boardView:stageFlash(tile.x, tile.y, style.color, PRESS_FLASH_SECONDS)
	deps.screen:setHeld(lane, true)

	local caught = self:_catchNote(session, lane)
	deps.screen:flashLane(lane, caught)

	if caught then
		deps.sfx:playHit()
	else
		deps.sfx:play("emptyPress")
	end
end

function HighwayController.release(self: HighwayController, lane: number)
	local deps = self.deps
	deps.screen:setHeld(lane, false)

	local session = self.session

	if session == nil then
		return
	end

	deps.remotes.SubmitRelease:FireServer({
		lane = lane,
		t = os.clock() + Workspace:GetServerTimeNow() - os.clock(),
		s = session:toShared(os.clock(), Workspace:GetServerTimeNow() - os.clock())
			- (os.clock() + Workspace:GetServerTimeNow() - os.clock()),
	})

	-- Let go too early and the tail greys out and falls away; the server
	-- decides what that costs.
	local held = self.holding[lane]

	if held ~= nil then
		self.holding[lane] = nil
		deps.screen:setSustain(lane, false)
		deps.dancer:sustain(lane, false)

		if self:_elapsed(session:getElapsed(os.clock())) < held.endsAt - Timing.HoldReleaseGrace then
			self.dropped[held.index] = true
		else
			self.caught[held.index] = true
		end
	end
end

-- Visual only: hide the note this press most likely hit, so the lane clears
-- the instant you press. The server's verdict still sets the grade.
function HighwayController._catchNote(self: HighwayController, session: any, lane: number): boolean
	local elapsed = self:_elapsed(session:getElapsed(os.clock()))
	local window = Timing.getWindows(session.map.difficulty).goodWindow
	local best: number? = nil
	local bestDistance = window
	local index = self.firstIndex

	while true do
		local step = session:getStep(index)

		if step == nil then
			break
		end

		local distance = session:getStepTargetTime(step) - elapsed

		if distance > window then
			break
		end

		if step.x == lane and step.type ~= "danger" and not self.caught[index] and math.abs(distance) <= bestDistance then
			best = index
			bestDistance = math.abs(distance)
		end

		index += 1
	end

	if best == nil then
		return false
	end

	local step = session:getStep(best)
	local hold = holdSecondsOf(step)

	if hold > 0 then
		self.holding[lane] = { index = best, endsAt = session:getStepTargetTime(step) + hold }
		self.deps.screen:setSustain(lane, true)
		self.deps.dancer:sustain(lane, true)
	else
		self.caught[best] = true
	end

	return true
end

-- lane is the judged note's lane; feverActive and combo are the server's.
function HighwayController.onVerdict(
	self: HighwayController,
	grade: string?,
	lane: number?,
	feverActive: boolean,
	combo: number
)
	if self.session == nil then
		return
	end

	local deps = self.deps
	self.fever = feverActive
	deps.camera:setFever(feverActive)
	deps.camera:setCombo(combo)
	deps.dancer:setFever(feverActive)

	if grade ~= nil then
		deps.dancer:react(grade, combo)
	end

	if grade == "Perfect" then
		deps.camera:kick(1)
	elseif grade == "Great" then
		deps.camera:kick(0.5)
	elseif grade == "Miss" then
		deps.camera:kick(-0.8)
	end

	if grade == "Perfect" and lane ~= nil then
		deps.screen:splash(lane)
		deps.boardView:stageRipple(HighwayLanes.get(lane).color)
	elseif (grade == "Great" or grade == "Good") and lane ~= nil then
		deps.screen:splash(lane, grade)
	elseif grade == "Miss" then
		local center = Board.centerCoord()
		deps.boardView:stageFlash(center.x, center.y, TileState.getColor(TileState.States.Miss), MISS_FLASH_SECONDS)
		if not deps.dancer:isRigged() then
			deps.stepMover:stumble()
		end
	end
end

return HighwayController
