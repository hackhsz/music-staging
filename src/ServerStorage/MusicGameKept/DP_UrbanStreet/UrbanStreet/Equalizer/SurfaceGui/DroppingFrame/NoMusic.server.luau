local sp = script.Parent
local bars = {}
for i = 1, 7 do
	bars[i] = sp:FindFirstChild("NUM" .. i)
end

local function getSongPlayNoter()
	local djTable = workspace:FindFirstChild("DJTABLE")
	if not djTable then return nil end
	local surfaceGui = djTable:FindFirstChild("SurfaceGui")
	if not surfaceGui then return nil end
	return surfaceGui:FindFirstChild("SongPlayNoter")
end

while true do
	task.wait()
	local songPlayNoter = getSongPlayNoter()
	if songPlayNoter and songPlayNoter.Visible == false then
		for _, bar in ipairs(bars) do
			if bar then
				bar:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Linear", 0.1, false)
			end
		end
	end
end
