--  Loader's two Load calls, keyed the same way, with one difference: each module is
--  required on its own. One that fails to load is named in the output and left out,
--  and every other module still loads and starts. A sweep of plain requires stops at
--  the first failure and leaves joining players on the loading screen with nothing
--  started.

local SafeLoader = {}

SafeLoader.Failed = {} :: {[ModuleScript]: string}

local function Load(Module: ModuleScript, Into: {[string]: any})
	local Ok, Result = pcall(require, Module)

	if Ok then
		Into[Module.Name] = Result
	else
		SafeLoader.Failed[Module] = tostring(Result)
		warn(`[DanceDanceStep] {Module:GetFullName()} failed to load and was skipped -- {Result}`)
	end
end

function SafeLoader.LoadChildren(Parent: Instance, Predicate: ((ModuleScript) -> boolean)?): {[string]: any}
	local Modules = {}

	for _, Child in Parent:GetChildren() do
		if Child:IsA("ModuleScript") and (Predicate == nil or Predicate(Child)) then
			Load(Child, Modules)
		end
	end

	return Modules
end

function SafeLoader.LoadDescendants(Parent: Instance, Predicate: ((ModuleScript) -> boolean)?): {[string]: any}
	local Modules = {}

	for _, Descendant in Parent:GetDescendants() do
		if Descendant:IsA("ModuleScript") and (Predicate == nil or Predicate(Descendant)) then
			Load(Descendant, Modules)
		end
	end

	return Modules
end

return SafeLoader
