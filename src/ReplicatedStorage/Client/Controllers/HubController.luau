--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local StageCue = require(Client:WaitForChild("World"):WaitForChild("StageCue"))

local HUB_ATTRIBUTE = "DanceHub"
local TO_STAGE_TEXT = "TO THE STAGE"
local TO_ISLAND_TEXT = "BACK TO THE ISLAND"
-- The server moves the character; a jump this far means it has landed.
local ARRIVAL_STUDS = 20
local ARRIVAL_TIMEOUT_SECONDS = 2
-- A beat for the camera and streaming to settle before the cover lifts.
local SETTLE_SECONDS = 0.15

type Deps = {
	remotes: any,
	stepMover: any,
	camera: any,
	transition: any?,
}

type Fields = {
	deps: Deps,
	hub: boolean,
	onStage: boolean,
	started: boolean,
	switchToken: number,
}

-- Whether the player is on the island or at the stage, in a hub place
-- (Workspace.DanceHub). On the island they walk with Roblox's own controls and
-- camera under the place's own lighting; a run brings the pad, the stage camera and
-- the club lighting, and leaving the stage puts it all back. A place without the
-- attribute is all stage, all the time.
local HubController = {}
HubController.__index = HubController

export type HubController = typeof(setmetatable({} :: Fields, HubController))

function HubController.new(deps: Deps): HubController
	local fields: Fields = {
		deps = deps,
		hub = Workspace:GetAttribute(HUB_ATTRIBUTE) == true,
		onStage = true,
		started = false,
		switchToken = 0,
	}

	return setmetatable(fields, HubController)
end

function HubController.isHub(self: HubController): boolean
	return self.hub
end

function HubController.isOnStage(self: HubController): boolean
	return self.onStage
end

function HubController.start(self: HubController)
	if self.hub then
		self:_setStage(false)
	end

	self.started = true
end

function HubController.enterStage(self: HubController)
	if self.hub and not self.onStage then
		self:_setStage(true)
	end
end

-- Asks the server to put the player back at their station; only between runs.
function HubController.leaveStage(self: HubController)
	if not self.hub or not self.onStage then
		return
	end

	self:_setStage(false)
	self.deps.remotes.ReturnToHub:FireServer({})
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function waitForArrival(from: Vector3?)
	local deadline = os.clock() + ARRIVAL_TIMEOUT_SECONDS

	while os.clock() < deadline do
		local now = rootPosition()

		if from == nil or (now ~= nil and (now - from).Magnitude > ARRIVAL_STUDS) then
			return
		end

		task.wait(0.05)
	end
end

-- Walking switches at once; the lighting and camera switch under the transition
-- cover, which lifts once the server has moved the character. Going down, the
-- stage camera takes over straight away; coming back, it holds the stage until
-- the player lands, so the island never shows under the club lighting.
function HubController._setStage(self: HubController, onStage: boolean)
	local deps = self.deps

	self.onStage = onStage
	self.switchToken += 1
	deps.stepMover:setFreeWalk(not onStage)

	local transition = deps.transition

	if transition == nil or not self.started then
		deps.camera:setActive(onStage)
		StageCue.fire("stage", onStage)
		return
	end

	local token = self.switchToken
	local from = rootPosition()

	transition:cover(if onStage then TO_STAGE_TEXT else TO_ISLAND_TEXT, function()
		if self.switchToken ~= token then
			return
		end

		StageCue.fire("stage", onStage)

		if onStage then
			deps.camera:setActive(true)
		end

		waitForArrival(from)

		if self.switchToken ~= token then
			return
		end

		if not onStage then
			deps.camera:setActive(false)
		end

		task.wait(SETTLE_SECONDS)

		if self.switchToken == token then
			transition:reveal()
		end
	end)
end

return HubController
