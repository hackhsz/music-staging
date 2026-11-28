local CollectionService = game:GetService("CollectionService")

-- Star states
local OFF_COLOR = Color3.fromRGB(180, 150, 60) -- soft gold
local OFF_TRANSPARENCY = 0.6
local OFF_MATERIAL = Enum.Material.SmoothPlastic
local ON_TRANSPARENCY = 0.15
local ON_MATERIAL = Enum.Material.Neon

-- Debounce per star so it doesn't toggle rapidly
local debounce = {}
local TOGGLE_COOLDOWN = 0.5

local function setStarState(star, isOn)
    if isOn then
        star.Material = ON_MATERIAL
        star.Transparency = ON_TRANSPARENCY
        star.Color = star:GetAttribute("OriginalColor") or star.Color
    else
        star.Material = OFF_MATERIAL
        star.Transparency = OFF_TRANSPARENCY
        star.Color = OFF_COLOR
    end
    star:SetAttribute("IsOn", isOn)
end

local function onTouch(star, otherPart)
    local character = otherPart.Parent
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Debounce check
    if debounce[star] then return end
    debounce[star] = true

    -- Toggle state
    local isOn = star:GetAttribute("IsOn") or false
    setStarState(star, not isOn)

    task.wait(TOGGLE_COOLDOWN)
    debounce[star] = nil
end

local function setupStar(star)
    if not star:IsA("BasePart") then return end

    -- Save the original color so we can restore it when turned on
    if not star:GetAttribute("OriginalColor") then
        star:SetAttribute("OriginalColor", star.Color)
    end

    -- Start in OFF state
    setStarState(star, false)

    -- Connect touch event
    star.Touched:Connect(function(otherPart)
        onTouch(star, otherPart)
    end)
end

local StarFlash = {}

function StarFlash.Start()
	-- Handle all currently tagged stars
	for _, star in ipairs(CollectionService:GetTagged("StarFlash")) do
	    setupStar(star)
	end

	-- Handle stars tagged later during gameplay
	CollectionService:GetInstanceAddedSignal("StarFlash"):Connect(setupStar)
end

return StarFlash
