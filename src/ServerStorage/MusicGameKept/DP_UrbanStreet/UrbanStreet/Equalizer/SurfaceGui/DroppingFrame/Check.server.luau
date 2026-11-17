local parent = script.Parent
local dropper = parent:FindFirstChild("Dropper")
local noMusic = parent:FindFirstChild("NoMusic")

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
	if songPlayNoter then
		if songPlayNoter.Visible == false then
			if dropper then dropper.Disabled = true end
			if noMusic then noMusic.Disabled = false end
		elseif songPlayNoter.Visible == true then
			if dropper then dropper.Disabled = false end
			if noMusic then noMusic.Disabled = true end
		end
	end
end
