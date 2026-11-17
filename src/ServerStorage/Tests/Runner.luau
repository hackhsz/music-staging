--!strict
-- A minimal test runner for the pure modules. No framework, no dependencies.
--
-- A spec is a ModuleScript returning a table of named functions. A test fails by
-- erroring, so plain `assert` is the whole API.
--
-- Run it from Studio in Edit mode, no Play needed: require this module from
-- ServerStorage.Tests and call run on it.
--
-- Edit mode caches required modules for the session, so after changing a module
-- either restart Studio or call run({ fresh = true }), which requires clones.

local Runner = {}

export type Spec = { [string]: () -> () }

export type Options = {
	fresh: boolean?,
	container: Instance?,
}

local function collectSpecs(container: Instance, fresh: boolean): { { name: string, spec: Spec } }
	local found = {}

	for _, child in container:GetChildren() do
		if not child:IsA("ModuleScript") or child.Name == "Runner" then
			continue
		end

		local target: ModuleScript = child

		if fresh then
			-- A clone has its own identity, so require() does not hand back the
			-- copy it cached earlier in this Studio session.
			local clone = child:Clone()
			clone.Parent = container
			target = clone
		end

		local ok, result = pcall(require, target)

		if fresh then
			target:Destroy()
		end

		if ok and type(result) == "table" then
			table.insert(found, { name = child.Name, spec = result :: Spec })
		else
			table.insert(found, {
				name = child.Name,
				spec = {
					["could not be loaded"] = function()
						error(tostring(result), 0)
					end,
				},
			})
		end
	end

	table.sort(found, function(a, b)
		return a.name < b.name
	end)

	return found
end

function Runner.run(options: Options?): string
	local settings: Options = options or {}
	local container = settings.container or script.Parent
	local fresh = settings.fresh == true

	local lines = {}
	local passed, failed = 0, 0

	for _, entry in collectSpecs(container, fresh) do
		local names = {}

		for name in entry.spec do
			table.insert(names, name)
		end

		table.sort(names)

		table.insert(lines, entry.name)

		for _, name in names do
			local test = entry.spec[name]
			local ok, err = pcall(function()
				test()
			end)

			if ok then
				passed += 1
				table.insert(lines, "  pass  " .. name)
			else
				failed += 1
				table.insert(lines, "  FAIL  " .. name .. "  -- " .. tostring(err))
			end
		end

		table.insert(lines, "")
	end

	table.insert(lines, string.format("%d passed, %d failed", passed, failed))

	return table.concat(lines, "\n")
end

return Runner
