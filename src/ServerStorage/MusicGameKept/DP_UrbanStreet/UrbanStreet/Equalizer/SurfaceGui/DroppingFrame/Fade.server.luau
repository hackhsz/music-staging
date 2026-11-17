local sp = script.Parent
local bars = {}
for i = 1, 7 do
	bars[i] = sp:FindFirstChild("NUM" .. i)
end

while true do
	-- Fade out from 0 to 0.7 in steps of 0.1
	for step = 0, 7 do
		for _, bar in ipairs(bars) do
			if bar then
				bar.BackgroundTransparency = step * 0.1
			end
			task.wait(0.1)
		end
	end
	-- Reset back to 0
	for _, bar in ipairs(bars) do
		if bar then
			bar.BackgroundTransparency = 0
		end
		task.wait(0.1)
	end
end
