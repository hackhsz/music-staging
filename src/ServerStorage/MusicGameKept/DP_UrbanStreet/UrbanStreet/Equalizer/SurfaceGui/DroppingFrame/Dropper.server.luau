local sp = script.Parent
local bars = {}
for i = 1, 7 do
	bars[i] = sp:FindFirstChild("NUM" .. i)
end

while true do
	for _, bar in ipairs(bars) do
		if bar then
			bar:TweenSize(UDim2.new(0, 100, 0, math.random(-600, 0)), "Out", "Linear", 0.1, false)
		end
	end
	task.wait(0.05)
end
