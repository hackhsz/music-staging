local RunService = game:GetService("RunService")

-- Animation parameters
local rotationSpeed = 0.5  -- radians per second (slow rotation)
local bobAmplitude = 1     -- studs to bob up and down
local bobSpeed = 1.5       -- how fast the bobbing oscillates

-- Collect all meshes we want to animate
local island = workspace:FindFirstChild("Islands_9_3")
-- Only the headband lives here; the Guitar has its own dedicated script (GuitarAnimate)
local meshNames = { "SKY_HeadPhones" }

local meshes = {}
if island then
    for _, name in ipairs(meshNames) do
        local mesh = island:FindFirstChild(name)
        if mesh and mesh:IsA("BasePart") then
            table.insert(meshes, {
                part = mesh,
                baseCFrame = mesh.CFrame,
            })
        else
            warn(name .. " not found!")
        end
    end
else
    warn("Islands_9_3 not found!")
end

local runTime = 0

RunService.Heartbeat:Connect(function(dt)
    runTime += dt

    -- Calculate rotation and bob offset
    local rotation = CFrame.Angles(0, rotationSpeed * runTime, 0)
    local bobOffset = CFrame.new(0, math.sin(bobSpeed * runTime) * bobAmplitude, 0)

    -- Apply the combined transform relative to each mesh's original position
    for _, entry in ipairs(meshes) do
        entry.part.CFrame = entry.baseCFrame * bobOffset * rotation
    end
end)