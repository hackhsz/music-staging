-- // Fixed-Hz scheduler. One Heartbeat drives every registered task, and the work is
-- // split across frames so a large registry costs a slice per frame instead of a spike.

local RunService = game:GetService("RunService")

local DefaultFrequency = 10

local Stepper = {}
Stepper.__index = Stepper

function Stepper.new(Frequency: number?)
	local self = setmetatable({}, Stepper)

	self.Frequency = Frequency or DefaultFrequency

	self.Tasks = {}
	self.Indices = {} -- [Task] = index into Tasks, for O(1) removal
	self.Clocks = {} -- [Task] = os.clock() of its last step

	self.Cursor = 1
	self.Credit = 0

	self.Connection = nil
	self.Destroyed = false

	return self
end

function Stepper:_Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

function Stepper:_Step(DeltaTime: number)
	local Count = #self.Tasks

	if Count == 0 then
		self:_Stop()
		return
	end

	--  Credit is how many individual steps this frame owes: Count tasks at Frequency
	--  each. Capping at Count keeps a task from running twice in one frame and stops a
	--  hitch from banking work into a catch-up spike.
	self.Credit = math.min(self.Credit + Count * self.Frequency * DeltaTime, Count)

	local Budget = math.floor(self.Credit)
	self.Credit -= Budget

	local Now = os.clock()

	for _ = 1, Budget do
		--  A task is allowed to remove itself mid-step, so the bounds are re-read.
		local Total = #self.Tasks

		if Total == 0 then
			break
		end

		if self.Cursor > Total then
			self.Cursor = 1
		end

		local Task = self.Tasks[self.Cursor]
		self.Cursor += 1

		local Last = self.Clocks[Task] or Now
		self.Clocks[Task] = Now

		if type(Task) == "function" then
			Task(Now - Last)
		else
			Task:Step(Now - Last)
		end
	end
end

function Stepper:Add(Task: any): any
	assert(not self.Destroyed, "[Stepper] Attempt to use destroyed Stepper.")
	assert(type(Task) == "function" or type(Task) == "table", "[Stepper] Add expects a function or an object with :Step.")

	if self.Indices[Task] then
		return Task
	end

	table.insert(self.Tasks, Task)

	self.Indices[Task] = #self.Tasks
	self.Clocks[Task] = os.clock()

	if not self.Connection then
		self.Connection = RunService.Heartbeat:Connect(function(DeltaTime)
			self:_Step(DeltaTime)
		end)
	end

	return Task
end

function Stepper:Remove(Task: any)
	local Index = self.Indices[Task]

	if not Index then
		return
	end

	local Last = #self.Tasks
	local Moved = self.Tasks[Last]

	self.Tasks[Index] = Moved
	self.Indices[Moved] = Index

	self.Tasks[Last] = nil
	self.Indices[Task] = nil
	self.Clocks[Task] = nil

	if #self.Tasks == 0 then
		self:_Stop()
	end
end

function Stepper:Count(): number
	return #self.Tasks
end

function Stepper:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	self:_Stop()

	table.clear(self.Tasks)
	table.clear(self.Indices)
	table.clear(self.Clocks)
end

return Stepper
