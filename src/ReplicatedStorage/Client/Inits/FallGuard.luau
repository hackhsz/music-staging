local KILL_Y = 223
local CHECK_INTERVAL_SEC = 0.15
local FADE_SEC = 0.25
local SPAWN_LIFT = Vector3.new(0, 4, 0)
-- The dance stage sits far below the island; a player there has not fallen.
local STAGE_REACH = 160

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FallGuard = {}

function FallGuard.Start()
	local fadeTemplate = ReplicatedStorage:WaitForChild("DDS"):WaitForChild("Templates"):WaitForChild("FadeGui")
	local spawnLocation = workspace:WaitForChild("SpawnLocation")
	local player = Players.LocalPlayer
	local fadeInfo = TweenInfo.new(FADE_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function bounceBack(rootPart: BasePart)
		local fade = fadeTemplate:Clone()
		fade.Parent = player:WaitForChild("PlayerGui")
		local cover = fade.Cover
		TweenService:Create(cover, fadeInfo, { BackgroundTransparency = 0 }):Play()
		task.wait(FADE_SEC)

		local character = rootPart.Parent
		if character and character.Parent then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(spawnLocation.CFrame + SPAWN_LIFT)
		end

		local reveal = TweenService:Create(cover, fadeInfo, { BackgroundTransparency = 1 })
		reveal:Play()
		reveal.Completed:Wait()
		fade:Destroy()
	end

	local function onStage(position: Vector3): boolean
		local origin = workspace:GetAttribute("DanceFloorOrigin")

		return typeof(origin) == "Vector3" and (position - origin).Magnitude < STAGE_REACH
	end

	while true do
		task.wait(CHECK_INTERVAL_SEC)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart and not rootPart.Anchored and rootPart.Position.Y < KILL_Y and not onStage(rootPart.Position) then
			bounceBack(rootPart)
		end
	end
end

return FallGuard
