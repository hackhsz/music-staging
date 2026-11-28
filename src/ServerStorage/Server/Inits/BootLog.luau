local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SongMapCatalog = require(Shared:WaitForChild("SongMapCatalog"))
local Board = require(Shared:WaitForChild("Board"))

local BootLog = {}

function BootLog.Start()
	local defaultMap = SongMapCatalog.getDefaultMap()

	print(("[DanceDanceStep] Loaded rhythm map: %s (%d bpm)"):format(defaultMap.title, defaultMap.bpm))
	print(("[DanceDanceStep] Board ready: %s %dx%d, tile size %d"):format(Board.getLayoutId(), Board.Columns, Board.Rows, Board.TileSize))
end

return BootLog
