--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Board = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Board"))
local BoardView = require(script.Parent.Parent.Floor.BoardView)
local StepMover = require(script.Parent.Parent.Input.StepMover)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local RivalPortrait = require(script.Parent.Parent.UI.Screens.RivalPortrait)

local RIVAL_FOLDER_NAME = "DanceDanceStepRivalBoard"

type Deps = {
	remotes: Remotes.Remotes,
	boardView: any,
	stepMover: StepMover.StepMover,
	camera: any,
	portrait: RivalPortrait.RivalPortrait,
}

type Fields = {
	deps: Deps,
	ownOrigin: Vector3,
	rivalView: any,
}

-- Which floors this client shows. The player's own floor, the camera and the
-- stepping all follow one origin; in a match a second, ghost floor shows the
-- rival's grades landing as the server reports them.
local FloorController = {}
FloorController.__index = FloorController

export type FloorController = typeof(setmetatable({} :: Fields, FloorController))

function FloorController.new(deps: Deps): FloorController
	local fields: Fields = {
		deps = deps,
		ownOrigin = Board.Origin,
		rivalView = nil,
	}

	return setmetatable(fields, FloorController)
end

function FloorController.start(self: FloorController)
	self.deps.remotes.RivalResult.OnClientEvent:Connect(function(payload)
		self:_onRivalResult(payload)
	end)
end

-- layoutId is the floor shape the server picked for this song; nil keeps the
-- current one.
function FloorController.setFloors(self: FloorController, own: Vector3, rival: Vector3?, layoutId: string?)
	local deps = self.deps
	local layoutChanged = layoutId ~= nil and layoutId ~= Board.getLayoutId()

	if layoutChanged then
		Board.setLayout(layoutId)
		deps.stepMover:clearQueue()
	end

	self.ownOrigin = own
	deps.boardView:setOrigin(own, layoutChanged)
	deps.stepMover:setOrigin(own)
	deps.camera:setFocus(own)

	if rival == nil then
		self:_removeRival()
	elseif self.rivalView == nil then
		self.rivalView = BoardView.new(rival, RIVAL_FOLDER_NAME)
	else
		self.rivalView:setOrigin(rival, layoutChanged)
	end
end

function FloorController.getOwnOrigin(self: FloorController): Vector3
	return self.ownOrigin
end

-- Back to the centre floor on its own, as in the lobby.
function FloorController.reset(self: FloorController)
	self:setFloors(Board.Origin, nil)
end

function FloorController._removeRival(self: FloorController)
	if self.rivalView ~= nil then
		self.rivalView:destroy()
		self.rivalView = nil
	end
end

function FloorController._onRivalResult(self: FloorController, payload: any)
	if type(payload) == "table" and type(payload.grade) == "string" then
		self.deps.portrait:react(payload.grade, false)
	end

	if self.rivalView == nil or type(payload) ~= "table" then
		return
	end

	self.rivalView:flashResult({ x = payload.x, y = payload.y }, payload.grade, payload.fever == true)
end

return FloorController
