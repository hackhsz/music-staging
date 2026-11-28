local Lighting = game:GetService("Lighting")

-- Night-club lighting: a dark violet room with haze thick enough for the disco
-- beams to read, and bloom that lets the neon glow without washing out the floor.
-- Everything here is created from code -- no place-file or asset dependencies.
local StageLighting = {}

StageLighting.FocusName = "StageFocus"

StageLighting.Config = {
	ambient = Color3.fromRGB(30, 22, 58),
	outdoorAmbient = Color3.fromRGB(34, 24, 66),
	-- Just after sunset: the sky is a deep navy gradient rather than black, and the sun
	-- is below the horizon so it lights nothing.
	clockTime = 19.8,
	brightness = 1,
	exposureCompensation = 0,
	bloomIntensity = 0.26,
	bloomSize = 24,
	bloomThreshold = 1.2,
	saturation = 0.15,
	contrast = 0.14,
	tintColor = Color3.fromRGB(255, 242, 255),
	atmosphereDensity = 0.34,
	atmosphereColor = Color3.fromRGB(150, 60, 200),
	atmosphereDecay = Color3.fromRGB(40, 24, 120),
	atmosphereHaze = 1.6,
	atmosphereGlare = 0,
	-- Depth of field: CameraController keeps the floor in focus, and everything more than
	-- focusRadius studs beyond it softens so the eye stays on the game.
	focusRadius = 22,
	focusFarIntensity = 0.55,
}

local SKY_NAME = "StageSky"

local focusAllowed = true
local focusWanted = true
local active = false
local look: { [string]: any } = {}
local lookSky: Sky? = nil

-- The player's Background Blur setting; the tier below can still rule it out.
function StageLighting.setFocusWanted(wanted: boolean)
	focusWanted = wanted
end

-- The performance tier turns the background blur off on weak devices.
function StageLighting.setFocusAllowed(allowed: boolean)
	focusAllowed = allowed
end

function StageLighting.isFocusAllowed(): boolean
	return focusAllowed and focusWanted
end

local function getOrCreate(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)

	if existing ~= nil and existing.ClassName == className then
		return existing
	end

	if existing ~= nil then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting

	return instance
end

-- The equipped arena's look: values that override Config by key, and its own sky.
-- Applied now if the stage lighting is up, otherwise the next time it goes up.
function StageLighting.setLook(overrides: { [string]: any }, sky: Sky?)
	look = overrides
	lookSky = sky

	if active then
		StageLighting.apply()
	end
end

local function configWithLook(): { [string]: any }
	local config = table.clone(StageLighting.Config)

	for key, value in look do
		if typeof(value) == typeof(config[key]) then
			config[key] = value
		end
	end

	return config
end

function StageLighting.apply()
	local config = configWithLook()

	active = true

	Lighting.Ambient = config.ambient
	Lighting.OutdoorAmbient = config.outdoorAmbient
	Lighting.ClockTime = config.clockTime
	Lighting.Brightness = config.brightness
	Lighting.ExposureCompensation = config.exposureCompensation
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.FogEnd = 1000

	local bloom = getOrCreate("BloomEffect", "StageBloom") :: BloomEffect
	bloom.Intensity = config.bloomIntensity
	bloom.Size = config.bloomSize
	bloom.Threshold = config.bloomThreshold
	bloom.Enabled = true

	local colorGrade = getOrCreate("ColorCorrectionEffect", "StageColorGrade") :: ColorCorrectionEffect
	colorGrade.Saturation = config.saturation
	colorGrade.Contrast = config.contrast
	colorGrade.TintColor = config.tintColor
	colorGrade.Enabled = true

	local focus = getOrCreate("DepthOfFieldEffect", StageLighting.FocusName) :: DepthOfFieldEffect
	focus.InFocusRadius = config.focusRadius
	focus.FarIntensity = config.focusFarIntensity
	focus.NearIntensity = 0
	focus.Enabled = true

	local atmosphere = getOrCreate("Atmosphere", "StageAtmosphere") :: Atmosphere
	atmosphere.Density = config.atmosphereDensity
	atmosphere.Color = config.atmosphereColor
	atmosphere.Decay = config.atmosphereDecay
	atmosphere.Haze = config.atmosphereHaze
	atmosphere.Glare = config.atmosphereGlare

	local sky = Lighting:FindFirstChild(SKY_NAME)

	if sky ~= nil then
		sky:Destroy()
	end

	if lookSky ~= nil then
		local copy = lookSky:Clone()
		copy.Name = SKY_NAME
		copy.Parent = Lighting
	end
end

local OWN_EFFECTS = {
	StageBloom = true,
	StageColorGrade = true,
	StageAtmosphere = true,
	[StageLighting.FocusName] = true,
	[SKY_NAME] = true,
}
local SAVED_PROPERTIES = {
	"Ambient",
	"OutdoorAmbient",
	"ClockTime",
	"Brightness",
	"ExposureCompensation",
	"GlobalShadows",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"FogEnd",
}

local saved: { properties: { [string]: any }, children: { Instance }, holder: Folder }? = nil

-- In a hub place the club look is only for the stage. Stepping on records the
-- place's own lighting and puts its sky and effects aside (a second Atmosphere or
-- Sky would fight ours); stepping off puts everything back as it was.
function StageLighting.setStage(onStage: boolean)
	if onStage then
		if saved ~= nil then
			return
		end

		local properties = {}

		for _, property in SAVED_PROPERTIES do
			properties[property] = (Lighting :: any)[property]
		end

		local holder = Instance.new("Folder")
		local children = {}

		for _, child in Lighting:GetChildren() do
			if not OWN_EFFECTS[child.Name] then
				table.insert(children, child)
				child.Parent = holder
			end
		end

		saved = { properties = properties, children = children, holder = holder }
		StageLighting.apply()
		return
	end

	local restore = saved

	if restore == nil then
		return
	end

	saved = nil
	active = false

	for _, child in Lighting:GetChildren() do
		if OWN_EFFECTS[child.Name] then
			child:Destroy()
		end
	end

	for property, value in restore.properties do
		(Lighting :: any)[property] = value
	end

	for _, child in restore.children do
		child.Parent = Lighting
	end

	restore.holder:Destroy()
end

return StageLighting
