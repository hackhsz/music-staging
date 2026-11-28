--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local Timing = require(Shared:WaitForChild("Timing"))
local AbilityController = require(script.Parent.AbilityController)
local RunController = require(script.Parent.RunController)

-- Studio playtests only: set Workspace.Autoplay to play the chart, and
-- Workspace.AutoplayAbilities to also step onto each ability that lands on the floor.
local AUTOPLAY_ATTRIBUTE = "Autoplay"
local ABILITIES_ATTRIBUTE = "AutoplayAbilities"
-- A step further than one tile starts early enough for each hop before it.
local HOP_SLACK = 0.02
local GIVE_UP_SECONDS = 0.3
-- Spare time a detour onto a pickup must leave before the next note's hops.
local PICKUP_SPARE_SECONDS = 0.25
local SKIPPED = { danger = true, item = true }

type Deps = {
	run: RunController.RunController,
	stepMover: any,
	abilities: AbilityController.AbilityController,
}

type Fields = {
	deps: Deps,
	session: any,
	index: number,
	planned: { x: number, y: number }?,
}

-- Presses what a perfect player would, through the same calls the keys make, so
-- the server judges it like anyone else. Never runs outside Studio.
local AutoplayController = {}
AutoplayController.__index = AutoplayController

export type AutoplayController = typeof(setmetatable({} :: Fields, AutoplayController))

local function sign(value: number): number
	return if value > 0 then 1 elseif value < 0 then -1 else 0
end

function AutoplayController.new(deps: Deps): AutoplayController
	local fields: Fields = {
		deps = deps,
		session = nil,
		index = 1,
		planned = nil,
	}

	return setmetatable(fields, AutoplayController)
end

function AutoplayController.start(self: AutoplayController)
	if not RunService:IsStudio() then
		return
	end

	RunService.Heartbeat:Connect(function()
		if Workspace:GetAttribute(AUTOPLAY_ATTRIBUTE) == true then
			self:_tick(os.clock())
		end
	end)
end

function AutoplayController._tick(self: AutoplayController, now: number)
	local run = self.deps.run
	local session = (run :: any).session

	if session == nil or not run:isRunning() then
		self.session = nil
		return
	end

	if session ~= self.session then
		self.session = session
		self.index = 1
		self.planned = self.deps.stepMover:getCoord()
	end

	local elapsed = session:getElapsed(now)
	local stepSeconds = Timing.getStepSeconds(session.map.difficulty)

	while true do
		local step = session.map.steps[self.index]

		if step == nil then
			break
		end

		local untilBeat = session:getStepTargetTime(step) - elapsed

		if SKIPPED[step.type] then
			self.index += 1
			continue
		end

		if untilBeat < -GIVE_UP_SECONDS then
			self.index += 1
			self.planned = self.deps.stepMover:getCoord()
			continue
		end

		if step.type == "clap" then
			if untilBeat <= 0 then
				run:clap()
				self.index += 1
				continue
			end

			break
		end

		local mover = self.deps.stepMover
		local standing = mover:getCoord()

		-- A refused or dropped hop leaves the plan ahead of the dancer, so plan from where they stand when idle.
		if standing ~= nil and mover:needsInput() and mover:getHop(now) == nil then
			self.planned = standing
		end

		local planned = self.planned or standing

		if planned == nil then
			break
		end

		local distance = Board.distance(planned, step)

		if distance == 0 then
			self.index += 1
			continue
		end

		local pickup = if Workspace:GetAttribute(ABILITIES_ATTRIBUTE) == true then self.deps.abilities:getPickup() else nil

		if pickup ~= nil and Board.distance(planned, pickup) > 0 then
			local hops = Board.distance(planned, pickup) + Board.distance(pickup, step) - 1
			local spare = untilBeat - hops * (stepSeconds + HOP_SLACK)

			if spare > PICKUP_SPARE_SECONDS then
				-- One hop at a time, each once the last has landed, so the step buffer never overflows.
				if standing ~= nil and Board.distance(standing, planned) == 0 then
					self:_hopToward(planned, pickup)
				end

				break
			end
		end

		if untilBeat > (distance - 1) * (stepSeconds + HOP_SLACK) then
			break
		end

		self:_hopToward(planned, step)

		break
	end
end

function AutoplayController._hopToward(self: AutoplayController, from: { x: number, y: number }, to: { x: number, y: number })
	if Board.hopsDirectly() then
		self.deps.stepMover:requestTile({ x = to.x, y = to.y })
		self.planned = { x = to.x, y = to.y }
		return
	end

	local dx, dy = to.x - from.x, to.y - from.y
	local move = if Board.isLegalMove(sign(dx), sign(dy))
		then { sign(dx), sign(dy) }
		elseif math.abs(dx) >= math.abs(dy) then { sign(dx), 0 }
		else { 0, sign(dy) }

	if self.deps.stepMover:requestStep(move[1], move[2]) then
		self.planned = { x = from.x + move[1], y = from.y + move[2] }
	end
end

return AutoplayController
