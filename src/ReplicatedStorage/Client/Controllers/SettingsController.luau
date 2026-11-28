--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerSettings"))
local SoundGroups = require(script.Parent.Parent.Audio.SoundGroups)
local InputController = require(script.Parent.Parent.Input.InputController)
local StageLighting = require(script.Parent.Parent.World.StageLighting)
local Remotes = require(script.Parent.Parent.Net.Remotes)

-- A slider sends once the player stops dragging, not on every step of it.
local SAVE_DELAY_SECONDS = 0.4
local BUTTON_SCALES = { small = 0.8, medium = 1, large = 1.25 }
local VOLUME_GROUPS = {
	musicVolume = { "music" },
	effectsVolume = { "effects", "crowd" },
	stepsVolume = { "steps" },
	menuVolume = { "menus" },
}

type Deps = {
	remotes: any,
	hud: any,
	vfx: any,
	camera: any,
}

type Fields = {
	deps: Deps,
	values: { [string]: any },
	loaded: boolean,
	saveTokens: { [string]: number },
}

-- The Settings window's audio, graphics and gameplay preferences: applied the
-- moment they change, saved to the profile through SetPlayerSetting, and loaded
-- back from the first profile sync after joining.
local SettingsController = {}
SettingsController.__index = SettingsController

export type SettingsController = typeof(setmetatable({} :: Fields, SettingsController))

function SettingsController.new(deps: Deps): SettingsController
	local fields: Fields = {
		deps = deps,
		values = PlayerSettings.resolve(nil),
		loaded = false,
		saveTokens = {},
	}

	return setmetatable(fields, SettingsController)
end

function SettingsController.start(self: SettingsController)
	local deps = self.deps

	deps.hud.settings:bindSettingChanged(function(id: string, value: any)
		self:set(id, value)
	end)
	deps.hud.settings:bindReset(function(section: string)
		self:resetSection(section)
	end)
	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		-- Only the first sync: later ones would undo a change still on its way.
		if not self.loaded and type(payload) == "table" and type(payload.settings) == "table" then
			self.loaded = true
			self.values = PlayerSettings.resolve(payload.settings)
			self:_applyAll()
		end
	end)

	self:_applyAll()
end

function SettingsController.get(self: SettingsController, id: string): any
	return self.values[id]
end

function SettingsController.set(self: SettingsController, id: string, value: any)
	local clean = PlayerSettings.sanitize(id, value)

	if clean == nil or clean == self.values[id] then
		return
	end

	local setting = PlayerSettings.get(id)

	-- One key, one action: whatever held it takes this one's old key.
	if setting ~= nil and (setting.kind == "key" or setting.kind == "button") then
		for _, other in PlayerSettings.Settings do
			if other.kind == setting.kind and other.id ~= id and self.values[other.id] == clean then
				self.values[other.id] = self.values[id]
				self:_apply(other.id)
				self:_save(other.id)
			end
		end
	end

	self.values[id] = clean
	self:_apply(id)
	self:_save(id)
end

function SettingsController.resetSection(self: SettingsController, section: string)
	for _, setting in PlayerSettings.Settings do
		if setting.section == section then
			self:set(setting.id, setting.default)
		end
	end
end

function SettingsController._applyAll(self: SettingsController)
	for _, setting in PlayerSettings.Settings do
		self:_apply(setting.id)
	end
end

function SettingsController._apply(self: SettingsController, id: string)
	local deps = self.deps
	local value = self.values[id]
	local groups = VOLUME_GROUPS[id]

	if groups ~= nil then
		for _, group in groups do
			SoundGroups.setLevel(group, value)
		end
	elseif id == "quality" then
		deps.vfx:setQuality(value)
	elseif id == "backgroundBlur" then
		StageLighting.setFocusWanted(value)
	elseif id == "cameraShake" then
		deps.camera:setMotion(value)
	elseif id == "touchButtonSize" then
		deps.hud.pad:setKeyScale(BUTTON_SCALES[value] or 1)
	elseif id == "touchFloorTap" then
		InputController.setFloorTap(value)
	else
		local setting = PlayerSettings.get(id)
		local action = if setting ~= nil then setting.action else nil
		local kind = if setting ~= nil then setting.kind else nil
		local key = PlayerSettings.keyCode(value)
		local button = PlayerSettings.buttonCode(value)

		if action ~= nil and kind == "key" and key ~= nil then
			InputController.setBinding(action, key, "keyboard")
			deps.hud.pad:setKeyLetter(action, string.upper(value))
		elseif action ~= nil and kind == "button" and button ~= nil then
			InputController.setBinding(action, button, "gamepad")
		end
	end

	deps.hud.settings:setSettingValue(id, value)
end

function SettingsController._save(self: SettingsController, id: string)
	local token = (self.saveTokens[id] or 0) + 1

	self.saveTokens[id] = token
	task.delay(SAVE_DELAY_SECONDS, function()
		if self.saveTokens[id] == token then
			self.deps.remotes.SetPlayerSetting:FireServer({ settingId = id, value = self.values[id] })
		end
	end)
end

return SettingsController
