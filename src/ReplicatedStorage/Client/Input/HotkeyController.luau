--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputStrategy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InputStrategy"))
local AbilityController = require(script.Parent.Parent.Controllers.AbilityController)
local CalibrationController = require(script.Parent.Parent.Controllers.CalibrationController)
local LobbyController = require(script.Parent.Parent.Controllers.LobbyController)
local RunController = require(script.Parent.Parent.Controllers.RunController)
local ShopController = require(script.Parent.Parent.Controllers.ShopController)
local StagesController = require(script.Parent.Parent.Controllers.StagesController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)
local HUDController = require(script.Parent.Parent.UI.HUDController)
local InputController = require(script.Parent.InputController)

local STARTER_EMOTE_ID = "signature-step-001"

local SONG_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

-- While the song picker is open the arrows browse it instead of stepping.
local PICKER_SONG_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Up] = -1,
	[Enum.KeyCode.Down] = 1,
	[Enum.KeyCode.DPadUp] = -1,
	[Enum.KeyCode.DPadDown] = 1,
}
local PICKER_DIFFICULTY_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Left] = -1,
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.DPadLeft] = -1,
	[Enum.KeyCode.DPadRight] = 1,
}
local PICKER_CONFIRM_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
}
-- Escape belongs to the Roblox menu, so the stage screens close on these instead.
local CLOSE_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Backspace] = true,
	[Enum.KeyCode.ButtonB] = true,
}

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	run: RunController.RunController,
	lobby: LobbyController.LobbyController,
	shop: ShopController.ShopController,
	calibration: CalibrationController.CalibrationController,
	abilities: AbilityController.AbilityController,
	stages: StagesController.StagesController,
}

type Fields = {
	deps: Deps,
}

-- Keyboard shortcuts for everything that also has an on-screen button. Each key
-- only forwards to the controller that owns the action; none of them decide
-- anything.
local HotkeyController = {}
HotkeyController.__index = HotkeyController

export type HotkeyController = typeof(setmetatable({} :: Fields, HotkeyController))

function HotkeyController.new(deps: Deps): HotkeyController
	local fields: Fields = { deps = deps }

	return setmetatable(fields, HotkeyController)
end

function HotkeyController.start(self: HotkeyController)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed then
			self:_onKey(input.KeyCode)
		end
	end)
end

function HotkeyController._onKey(self: HotkeyController, key: Enum.KeyCode)
	local deps = self.deps

	-- The Settings window is waiting for a key to bind; this one is not a hotkey.
	if deps.hud.settings:isCapturingKey() then
		return
	end

	-- Mid-run a step key is a step: on the pad, E is a panel and not an emote.
	if deps.run:isRunning() and InputController.isStepKey(key) then
		return
	end

	-- The number keys pick songs between runs and never interrupt one.
	if deps.run:isRunning() and SONG_KEYS[key] ~= nil then
		return
	end

	if CLOSE_KEYS[key] and deps.stages:closeTop() then
		return
	end

	local picker = deps.hud.songSelect

	if not deps.run:isRunning() and picker:isVisible() then
		if PICKER_SONG_KEYS[key] ~= nil then
			picker:moveSong(PICKER_SONG_KEYS[key])
			return
		elseif PICKER_DIFFICULTY_KEYS[key] ~= nil then
			picker:moveDifficulty(PICKER_DIFFICULTY_KEYS[key])
			return
		elseif PICKER_CONFIRM_KEYS[key] then
			picker:confirm()
			return
		end
	end

	local songIndex = SONG_KEYS[key]

	if songIndex ~= nil then
		deps.lobby:requestSongByIndex(songIndex)
	elseif key == Enum.KeyCode.R then
		deps.run:requestReplay()
	elseif key == Enum.KeyCode.N then
		deps.lobby:requestNextSong()
	elseif key == Enum.KeyCode.I then
		deps.hud.hints:setHint("INVITE A FRIEND FROM THE ROBLOX MENU")
		Telemetry.track("invite_prompt_viewed")
	elseif key == Enum.KeyCode.E then
		-- The server validates the emote before approving playback.
		deps.remotes.PlayEmote:FireServer({ emoteId = STARTER_EMOTE_ID })
		Telemetry.track("emote_requested")
	elseif key == Enum.KeyCode.P then
		-- During a run P pauses; on the results screen it toggles photo mode.
		if deps.run:isRunning() then
			deps.run:togglePause()
		else
			deps.hud:togglePhotoMode()
			Telemetry.track("photo_mode_toggled")
		end
	elseif key == Enum.KeyCode.L then
		deps.lobby:toggleSongSelect()
	elseif key == Enum.KeyCode.T then
		deps.stages:toggleSetlist()
	elseif key == Enum.KeyCode.B then
		deps.shop:toggle()
	elseif key == Enum.KeyCode.O then
		deps.calibration:toggleSettings()
	elseif key == Enum.KeyCode.K then
		deps.abilities:togglePicker()
	elseif key == Enum.KeyCode.Minus and deps.hud.settings:isVisible() then
		deps.calibration:adjust(-InputStrategy.OffsetStepSeconds)
	elseif key == Enum.KeyCode.Equals and deps.hud.settings:isVisible() then
		deps.calibration:adjust(InputStrategy.OffsetStepSeconds)
	elseif key == Enum.KeyCode.Y then
		deps.lobby:requestRematch()
	elseif key == Enum.KeyCode.G then
		deps.lobby:requestParty()
	end
end

return HotkeyController
