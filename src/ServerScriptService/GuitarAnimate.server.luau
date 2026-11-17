local RunService = game:GetService("RunService")

local folder = workspace:FindFirstChild("Islands_9_3")
local part = folder and folder:FindFirstChild("SKY_Guitar")
if not part then
	warn("SKY_Guitar not found in Workspace.Islands_9_3")
	return
end

-- Rotation speed in degrees per second (slow)
local DEGREES_PER_SECOND = 30

-- Bobbing settings
local BOB_AMPLITUDE = 0.5  -- how far it moves up and down (in studs)
local BOB_SPEED = 1.5       -- how fast it bobs (cycles per second)

local startCFrame = part.CFrame
local startTime = os.clock()

RunService.Heartbeat:Connect(function(dt)
	if not part or not part.Parent then return end

	local elapsed = os.clock() - startTime

	-- Calculate bob offset (sine wave for smooth up/down motion)
	local bobOffset = math.sin(elapsed * BOB_SPEED * math.pi * 2) * BOB_AMPLITUDE

	-- Calculate rotation
	local rotation = CFrame.Angles(0, math.rad(DEGREES_PER_SECOND) * elapsed, 0)

	-- Apply: start from original position, add bob, then rotate
	part.CFrame = (startCFrame + Vector3.new(0, bobOffset, 0)) * rotation
end)