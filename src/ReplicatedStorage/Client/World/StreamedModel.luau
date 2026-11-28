--!strict
local Workspace = game:GetService("Workspace")

local WAIT_SECONDS = 15
local POLL_SECONDS = 0.2

-- With Workspace streaming on, parts far from the player arrive after the client
-- starts, even in a Persistent model. A model stamped with a Parts attribute (its
-- BasePart count) is waited on until all of them are here.
local StreamedModel = {}

-- The named child of Workspace, waited for when streaming may not have sent it yet.
function StreamedModel.find(name: string): Instance?
	local found = Workspace:FindFirstChild(name)

	if found == nil and Workspace.StreamingEnabled then
		found = Workspace:WaitForChild(name, WAIT_SECONDS)
	end

	if found ~= nil then
		StreamedModel.waitForParts(found)
	end

	return found
end

function StreamedModel.waitForParts(model: Instance)
	local expected = model:GetAttribute("Parts")

	if not Workspace.StreamingEnabled or type(expected) ~= "number" then
		return
	end

	local deadline = os.clock() + WAIT_SECONDS

	while os.clock() < deadline do
		local count = 0

		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				count += 1
			end
		end

		if count >= expected then
			return
		end

		task.wait(POLL_SECONDS)
	end

	warn(("[DanceDanceStep] %s streamed in only partly; is it a Persistent model?"):format(model:GetFullName()))
end

return StreamedModel
