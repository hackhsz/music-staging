local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ jobs = {} }, Maid)
end

function Maid:GiveTask(job)
	table.insert(self.jobs, job)
	return job
end

local function cleanJob(job)
	local jobType = typeof(job)
	if jobType == "RBXScriptConnection" then
		job:Disconnect()
	elseif jobType == "Instance" then
		job:Destroy()
	elseif jobType == "function" then
		job()
	elseif jobType == "table" then
		if type(job.Destroy) == "function" then
			job:Destroy()
		elseif type(job.Disconnect) == "function" then
			job:Disconnect()
		end
	end
end

function Maid:DoCleaning()
	local jobs = self.jobs
	self.jobs = {}
	for index = #jobs, 1, -1 do
		cleanJob(jobs[index])
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
