local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The inits are listed from ReplicatedStorage, so the boot waits until the first
-- replication is complete; a module that had not arrived yet would be skipped.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Lifecycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utility"):WaitForChild("Lifecycle"))

Lifecycle.Boot(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Inits"), "client")
