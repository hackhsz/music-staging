--!strict
local Loader = require(script.Parent.Parent.Packages.Loader)
local SafeLoader = require(script.Parent.SafeLoader)

local Lifecycle = {}

-- Inits under Priority run first, one at a time in name order, and an Init that
-- answers false stops the boot. Every other init is then loaded and its Start is
-- spawned, so one that yields never holds up the rest.
function Lifecycle.Boot(inits: Instance, side: string): boolean
	local priority = inits:FindFirstChild("Priority")

	if priority ~= nil then
		local modules = SafeLoader.LoadChildren(priority)
		local names = {}

		for name in modules do
			table.insert(names, name)
		end

		table.sort(names)

		for _, name in names do
			local module = modules[name]

			if type(module.Init) == "function" and module.Init() == false then
				warn(("[DanceDanceStep] %s init %s did not complete; the %s will not start"):format(side, name, side))
				return false
			end
		end
	end

	Loader.SpawnAll(
		SafeLoader.LoadDescendants(inits, function(module: ModuleScript): boolean
			return priority == nil or not module:IsDescendantOf(priority)
		end),
		"Start"
	)

	return true
end

return Lifecycle
