local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local BounceSpringInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, true)

local LocalPlayer = Players.LocalPlayer

local velocity = Vector3.zero

local function map(x, in_min, in_max, out_min, out_max)
	return out_min + (x - in_min) * (out_max - out_min) / (in_max - in_min)
end

local Bouncy = {}

function Bouncy.Start()
	RunService.PreSimulation:Connect(function()
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			velocity = LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity
		end
	end)

	local function SetupBouncy(instance: BasePart)

		local VelocityBounce = instance:GetAttribute("MinVelocity") or -15
		local Bounciness = (instance:GetAttribute("Bounciness") or 150)
		local Spring = (instance:GetAttribute("Spring") or 0)
		local lastBounce = tick()
		local OGSize = instance.Size

		local newAudio = Instance.new("Sound")
		newAudio.Parent = instance
		newAudio.SoundId = "rbxassetid://12222124"
		newAudio.Volume = 0.2

		local pitchMod = Instance.new("PitchShiftSoundEffect")
		pitchMod.Parent = newAudio

		local touchedConn
		touchedConn = instance.Touched:Connect(function(other)

			local hitPlayer = Players:GetPlayerFromCharacter(other.Parent)
			if LocalPlayer ~= hitPlayer then
				return
			end

			if tick() - lastBounce <= 0.2 then
				return
			end

			local HumanoidRootPart: BasePart = LocalPlayer.Character.HumanoidRootPart

			if velocity.Y > VelocityBounce then
				return
			end

			local humanoid = other.Parent:FindFirstChild("Humanoid")
			if not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Dead then
				return
			end

			local newRaycastParams = RaycastParams.new()
			newRaycastParams.FilterType = Enum.RaycastFilterType.Include
			newRaycastParams.FilterDescendantsInstances = { instance }

			local position = HumanoidRootPart.CFrame.Position
			local raycast = workspace:Raycast(position, position - Vector3.yAxis * 200, newRaycastParams)
			local up = raycast and raycast.Normal or Vector3.yAxis

			lastBounce = tick()

			local bounceForce = up * math.min(map(math.max(-velocity.Y, Spring), 0, 100, 0, Bounciness), Bounciness)

			HumanoidRootPart.AssemblyLinearVelocity = bounceForce
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

			local newTween =
				TweenService:Create(instance, BounceSpringInfo, { Size = OGSize * Vector3.new(1.2, 1.2, 1.2) })
			pitchMod.Octave = math.random(90, 110) / 100
			newAudio:Play()
			newTween:Play()
		end)

		-- Clean up the connection if the instance is destroyed / unparented
		local function cleanup()
			if touchedConn then
				touchedConn:Disconnect()
				touchedConn = nil
			end
		end

		instance.AncestryChanged:Connect(function(_, parent)
			if not parent then
				cleanup()
			end
		end)

		CollectionService:GetInstanceRemovedSignal("bouncy"):Connect(function(removedInstance)
			if removedInstance == instance then
				cleanup()
			end
		end)
	end

	-- Set up on all currently-tagged instances
	for _, instance in ipairs(CollectionService:GetTagged("bouncy")) do
		task.defer(SetupBouncy, instance)
	end

	-- Set up on any future-tagged instances
	CollectionService:GetInstanceAddedSignal("bouncy"):Connect(SetupBouncy)
end

return Bouncy
