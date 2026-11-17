local Players = game:GetService("Players")

-- Search the entire workspace for TeleportArch instances
local door1, door2, point1, point2

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant.Name == "TeleportArch" then
		local d1 = descendant:FindFirstChild("Door1")
		local d2 = descendant:FindFirstChild("Door2")
		if d1 and not door1 then
			door1 = d1
			point1 = d1:FindFirstChild("Point1")
		end
		if d2 and not door2 then
			door2 = d2
			point2 = d2:FindFirstChild("Point2")
		end
	end
end

if not (door1 and door2 and point1 and point2) then
	warn("Could not find all teleport doors and points! Make sure Door1, Door2, Point1, and Point2 exist.")
	return
end

-- Debounce table to prevent rapid back-and-forth teleporting
local debounce = {}
local COOLDOWN = 2 -- seconds before a player can teleport again

local function teleportPlayer(character, destinationPart)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Teleport to the destination point, offset slightly forward so the player
	-- doesn't immediately re-trigger the other door
	local destCFrame = destinationPart.CFrame * CFrame.new(0, 0, -4)
	character:PivotTo(destCFrame)
end

local function onDoorTouched(otherPart, sourceDoor, destinationPoint)
	local character = otherPart.Parent
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Check debounce
	if debounce[character] then return end
	debounce[character] = true

	teleportPlayer(character, destinationPoint)

	task.delay(COOLDOWN, function()
		debounce[character] = nil
	end)
end

door1.Touched:Connect(function(otherPart)
	onDoorTouched(otherPart, door1, point2)
end)

door2.Touched:Connect(function(otherPart)
	onDoorTouched(otherPart, door2, point1)
end)

print("Teleport doors script loaded successfully!")