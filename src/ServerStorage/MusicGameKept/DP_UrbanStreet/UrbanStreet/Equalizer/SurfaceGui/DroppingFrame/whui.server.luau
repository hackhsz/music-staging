local parent = script.Parent
local frames = {}
for i = 1, 7 do
	frames[i] = parent:FindFirstChild("NUM" .. i)
end

-- Robustly find the Equalizer part (parent of the SurfaceGui)
local equalizerPart = script.Parent.Parent.Parent
local pointLight = equalizerPart:FindFirstChild("PointLight")
local spotLight1 = equalizerPart:FindFirstChild("SpotLight1")
local spotLight2 = equalizerPart:FindFirstChild("SpotLight2")
local spotLight3 = equalizerPart:FindFirstChild("SpotLight3")

local function setColor(color)
	for _, frame in ipairs(frames) do
		if frame then
			frame.BackgroundColor3 = color
		end
	end
	if pointLight then pointLight.Color = color end
	if spotLight1 then spotLight1.Color = color end
	if spotLight2 then spotLight2.Color = color end
	if spotLight3 then spotLight3.Color = color end
end

while true do
	task.wait()
	setColor(Color3.new(1, 0, 0))
	for q = 1, 255 do
		task.wait()
		setColor(Color3.new((255 - q) / 255, q / 255, 0))
	end
	for w = 1, 255 do
		task.wait()
		setColor(Color3.new(0, (255 - w) / 255, w / 255))
	end
	for e = 1, 255 do
		task.wait()
		setColor(Color3.new(e / 255, 0, (255 - e) / 255))
	end
end
