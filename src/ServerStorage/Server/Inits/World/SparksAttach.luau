local Players = game:GetService("Players")

local SparksAttach = {}

function SparksAttach.Start()
	local sparksPart = nil
	-- Search the entire Workspace for the trigger part named "Sparks" (must contain a ParticleEmitter)
	for _, d in game.Workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Sparks" and d:FindFirstChildWhichIsA("ParticleEmitter") then
			sparksPart = d
			break
		end
	end

	if not sparksPart then
	    warn("Sparks part not found!")
	    return
	end

	local particleTemplate = sparksPart:FindFirstChild("Sparks")
	if not particleTemplate or not particleTemplate:IsA("ParticleEmitter") then
	    warn("ParticleEmitter not found inside Sparks part!")
	    return
	end

	local debounce = {}
	local DEBOUNCE_TIME = 5 -- seconds before the same player can trigger again
	local MOVE_CHECK_INTERVAL = 0.1 -- how often to check if the player is moving
	local MOVE_THRESHOLD = 0.5 -- minimum distance (in studs) to count as "moving"

	-- Tracks movement for each player who has sparks attached
	local movementTrackers = {}

	local function startMovementTracking(player, character, emitter)
	    if movementTrackers[player] then return end -- already tracking

	    local hrp = character:FindFirstChild("HumanoidRootPart")
	    if not hrp then return end

	    local lastPosition = hrp.Position
	    local tracker = { emitter = emitter, character = character }
	    movementTrackers[player] = tracker

	    tracker.connection = task.spawn(function()
	        while movementTrackers[player] == tracker do
	            task.wait(MOVE_CHECK_INTERVAL)
	            if not emitter.Parent or not character.Parent then
	                break -- emitter or character was removed, stop tracking
	            end

	            local currentHrp = character:FindFirstChild("HumanoidRootPart")
	            if currentHrp then
	                local currentPos = currentHrp.Position
	                local distance = (currentPos - lastPosition).Magnitude

	                if distance >= MOVE_THRESHOLD then
	                    emitter.Enabled = true
	                else
	                    emitter.Enabled = false
	                end

	                lastPosition = currentPos
	            end
	        end
	    end)
	end

	local function onTouch(otherPart)
	    local character = otherPart.Parent
	    if not character then return end

	    local humanoid = character:FindFirstChildOfClass("Humanoid")
	    if not humanoid or humanoid.Health <= 0 then return end

	    local player = Players:GetPlayerFromCharacter(character)
	    if not player then return end

	    if debounce[player] then return end
	    debounce[player] = true

	    -- Check if the character already has sparks attached
	    local hrp = character:FindFirstChild("HumanoidRootPart")
	    if hrp and not hrp:FindFirstChild("AttachedSparks") then
	        -- Find a foot or leg part to attach sparks to (R15: LeftFoot/RightFoot, R6: Left Leg/Right Leg)
	        local footPart = character:FindFirstChild("RightFoot")
	            or character:FindFirstChild("LeftFoot")
	            or character:FindFirstChild("Right Leg")
	            or character:FindFirstChild("Left Leg")

	        local attachment, clone

	        if footPart then
	            -- Attach to the foot/leg part so sparks follow the actual step
	            attachment = Instance.new("Attachment")
	            attachment.Name = "AttachedSparks"
	            attachment.Position = Vector3.new(0, -0.5, 1) -- slight offset: down to heel level, behind the foot
	            attachment.Parent = footPart
	        else
	            -- Fallback: attach to HumanoidRootPart if no foot/leg part found
	            attachment = Instance.new("Attachment")
	            attachment.Name = "AttachedSparks"
	            attachment.Position = Vector3.new(0, -3, 2)
	            attachment.Parent = hrp
	        end

	        clone = particleTemplate:Clone()
	        clone.Name = "SparksEmitter"
	        clone.Enabled = false -- start off; only emit when moving
	        clone.Parent = attachment

	        -- Start tracking movement to toggle the emitter
	        startMovementTracking(player, character, clone)
	    end

	    task.delay(DEBOUNCE_TIME, function()
	        debounce[player] = nil
	    end)
	end

	sparksPart.Touched:Connect(onTouch)
end

return SparksAttach
