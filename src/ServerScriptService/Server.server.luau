local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Lifecycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utility"):WaitForChild("Lifecycle"))

Lifecycle.Boot(ServerStorage:WaitForChild("Server"):WaitForChild("Inits"), "server")
