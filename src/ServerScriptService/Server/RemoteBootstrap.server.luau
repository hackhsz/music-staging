local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteContract = require(Shared:WaitForChild("RemoteContract"))

local folder = ReplicatedStorage:FindFirstChild(RemoteContract.FolderName)

if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = RemoteContract.FolderName
	folder.Parent = ReplicatedStorage
end

for _, eventConfig in RemoteContract.Events do
	local remote = folder:FindFirstChild(eventConfig.name)

	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = eventConfig.name
		remote.Parent = folder
	end
end

print("[DanceDanceStep] Remote contract bootstrapped")

