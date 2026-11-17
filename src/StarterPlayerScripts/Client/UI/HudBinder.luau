--!strict
-- Resolves the authored HUD against Shared/HudContract and reports what is missing.
--
-- Tags resolve across the whole DataModel and StarterGui is cloned into every
-- PlayerGui, so every lookup is scoped to one root. Nothing here walks a name
-- path, which is what lets the place be renamed and reparented freely.
--
-- A role binds to a list, not one instance: authored art layers copies of a
-- label for weight and shadow, and both have to show the same number.

local CollectionService = game:GetService("CollectionService")

local HudContract = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HudContract"))

export type Report = {
	roles: number,
	instances: number,
	missingRequired: { string },
	missingOptional: { string },
	unknownRoles: { string },
	untagged: number,
}

type Fields = {
	root: Instance,
	elements: { [string]: { Instance } },
	report: Report,
}

local HudBinder = {}
HudBinder.__index = HudBinder

export type HudBinder = typeof(setmetatable({} :: Fields, HudBinder))

local function emptyReport(): Report
	return {
		roles = 0,
		instances = 0,
		missingRequired = {},
		missingOptional = {},
		unknownRoles = {},
		untagged = 0,
	}
end

local function describe(report: Report): string
	local parts = { string.format("%d roles bound across %d instances", report.roles, report.instances) }

	if #report.missingRequired > 0 then
		table.insert(parts, string.format("MISSING REQUIRED: %s", table.concat(report.missingRequired, ", ")))
	end

	if #report.unknownRoles > 0 then
		table.insert(parts, string.format("unknown roles: %s", table.concat(report.unknownRoles, ", ")))
	end

	if report.untagged > 0 then
		table.insert(parts, string.format("%d tagged with no %s attribute", report.untagged, HudContract.RoleAttribute))
	end

	if #report.missingOptional > 0 then
		table.insert(parts, string.format("not authored yet: %s", table.concat(report.missingOptional, ", ")))
	end

	return table.concat(parts, "  |  ")
end

function HudBinder.new(root: Instance): HudBinder
	local fields: Fields = {
		root = root,
		elements = {},
		report = emptyReport(),
	}
	local self = setmetatable(fields, HudBinder)
	self:refresh()

	return self
end

function HudBinder.refresh(self: HudBinder): Report
	local elements: { [string]: { Instance } } = {}
	local report = emptyReport()

	for _, inst in CollectionService:GetTagged(HudContract.Tag) do
		if not inst:IsDescendantOf(self.root) then
			continue
		end

		local role = inst:GetAttribute(HudContract.RoleAttribute)

		if type(role) ~= "string" or role == "" then
			report.untagged += 1
			continue
		end

		if not HudContract.isKnownRole(role) then
			table.insert(report.unknownRoles, role)
			continue
		end

		local bucket = elements[role]

		if bucket == nil then
			bucket = {}
			elements[role] = bucket
			report.roles += 1
		end

		table.insert(bucket, inst)
		report.instances += 1
	end

	for role, element in HudContract.Elements do
		if elements[role] == nil then
			if element.required then
				table.insert(report.missingRequired, role)
			else
				table.insert(report.missingOptional, role)
			end
		end
	end

	table.sort(report.missingRequired)
	table.sort(report.missingOptional)
	table.sort(report.unknownRoles)

	self.elements = elements
	self.report = report

	return report
end

-- One line at startup instead of a blank HUD nobody can explain.
function HudBinder.logReport(self: HudBinder)
	local line = "[HudBinder] " .. describe(self.report)

	if #self.report.missingRequired > 0 then
		warn(line)
	else
		print(line)
	end
end

function HudBinder.get(self: HudBinder, role: string): Instance?
	local bucket = self.elements[role]

	return if bucket ~= nil then bucket[1] else nil
end

function HudBinder.setText(self: HudBinder, role: string, text: string)
	local bucket: { Instance } = self.elements[role] or {}

	for _, inst in bucket do
		if inst:IsA("TextLabel") then
			inst.Text = text
		elseif inst:IsA("TextButton") then
			inst.Text = text
		end
	end
end

-- Bars are driven by width so the authored art keeps its own anchoring.
function HudBinder.setFill(self: HudBinder, role: string, fraction: number)
	local clamped = math.clamp(fraction, 0, 1)
	local bucket: { Instance } = self.elements[role] or {}

	for _, inst in bucket do
		if inst:IsA("GuiObject") then
			inst.Size = UDim2.new(clamped, 0, inst.Size.Y.Scale, inst.Size.Y.Offset)
		end
	end
end

function HudBinder.setVisible(self: HudBinder, role: string, visible: boolean)
	local bucket: { Instance } = self.elements[role] or {}

	for _, inst in bucket do
		if inst:IsA("GuiObject") then
			inst.Visible = visible
		end
	end
end

function HudBinder.onActivated(self: HudBinder, role: string, callback: () -> ()): { RBXScriptConnection }
	local connections = {}
	local bucket: { Instance } = self.elements[role] or {}

	for _, inst in bucket do
		if inst:IsA("TextButton") or inst:IsA("ImageButton") then
			table.insert(connections, inst.Activated:Connect(callback))
		end
	end

	return connections
end

return HudBinder
