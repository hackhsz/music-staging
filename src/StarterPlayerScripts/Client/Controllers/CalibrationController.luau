--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputStrategy = require(Shared:WaitForChild("InputStrategy"))
local Timing = require(Shared:WaitForChild("Timing"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	deviceMode: any,
}

type Fields = {
	deps: Deps,
	offsetSeconds: number,
	calibrated: boolean,
	deviceDefaultSent: boolean,
	presses: { number },
}

export type TuneResult = {
	averageMs: number,
	tunedMs: number,
	onPoint: boolean,
}

-- Owns the player's input-latency offset: what the settings panel shows, what the
-- server judges with, and the per-device default a new player starts from.
local CalibrationController = {}
CalibrationController.__index = CalibrationController

export type CalibrationController = typeof(setmetatable({} :: Fields, CalibrationController))

function CalibrationController.new(deps: Deps): CalibrationController
	local fields: Fields = {
		deps = deps,
		offsetSeconds = 0,
		calibrated = false,
		deviceDefaultSent = false,
		presses = {},
	}

	return setmetatable(fields, CalibrationController)
end

function CalibrationController.start(self: CalibrationController)
	local deps = self.deps

	deps.hud.settings:bindAdjust(function(deltaSeconds)
		self:adjust(deltaSeconds)
	end)
	deps.hud.menu:bindSettings(function()
		self:toggleSettings()
	end)
	deps.remotes.TimingOffsetSync.OnClientEvent:Connect(function(payload)
		self:_onSync(payload)
	end)
end

function CalibrationController.getOffsetSeconds(self: CalibrationController): number
	return self.offsetSeconds
end

function CalibrationController.toggleSettings(self: CalibrationController)
	self.deps.hud.settings:toggle()
	Telemetry.track("settings_toggled")
end

function CalibrationController.adjust(self: CalibrationController, deltaSeconds: number)
	self.offsetSeconds = math.clamp(self.offsetSeconds + deltaSeconds, -InputStrategy.MaxOffsetSeconds, InputStrategy.MaxOffsetSeconds)
	self.calibrated = true
	self.deps.hud.settings:updateOffset(self.offsetSeconds)
	self.deps.remotes.SetTimingOffset:FireServer({
		offsetSeconds = self.offsetSeconds,
	})
end

function CalibrationController.setOffset(self: CalibrationController, seconds: number)
	self:adjust(seconds - self.offsetSeconds)
end

function CalibrationController.beginRun(self: CalibrationController)
	table.clear(self.presses)
end

-- pressOffset is one timed press against its beat on the judged clock, positive when late.
function CalibrationController.notePress(self: CalibrationController, pressOffset: number)
	table.insert(self.presses, pressOffset)
end

-- Ends the run's sampling and moves the offset part of the way toward its
-- median press, so it settles over a few runs without chasing one bad run; nil
-- when the run had too few timed presses to say anything.
function CalibrationController.tuneFromRun(self: CalibrationController): TuneResult?
	local tune = Timing.AutoTune
	local presses = self.presses

	if #presses < tune.minPresses then
		table.clear(presses)
		return nil
	end

	table.sort(presses)

	local half = #presses // 2
	local median = if #presses % 2 == 1 then presses[half + 1] else (presses[half] + presses[half + 1]) / 2
	local before = self.offsetSeconds

	table.clear(presses)

	if math.abs(median) >= tune.deadbandSeconds then
		local step = math.clamp(median * tune.gain, -tune.maxStepSeconds, tune.maxStepSeconds)
		self:adjust(math.floor(step * 1000 + 0.5) / 1000)
		Telemetry.track("timing_tuned", math.floor(median * 1000 + 0.5))
	end

	return {
		averageMs = math.floor(median * 1000 + 0.5),
		tunedMs = math.floor((self.offsetSeconds - before) * 1000 + 0.5),
		onPoint = math.abs(median) < tune.deadbandSeconds,
	}
end

function CalibrationController._onSync(self: CalibrationController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	self.offsetSeconds = math.clamp(tonumber(payload.offsetSeconds) or 0, -InputStrategy.MaxOffsetSeconds, InputStrategy.MaxOffsetSeconds)
	self.calibrated = payload.calibrated == true
	self.deps.hud.settings:updateOffset(self.offsetSeconds)

	-- First sync after join: a player with no saved calibration starts from this
	-- device's input-latency default.
	if self.calibrated or self.deviceDefaultSent then
		return
	end

	self.deviceDefaultSent = true

	local defaultOffset = Timing.getWindows(nil, self.deps.deviceMode.id).deviceDefaultOffsetSeconds

	if defaultOffset ~= 0 then
		self.deps.remotes.SetTimingOffset:FireServer({
			offsetSeconds = defaultOffset,
			deviceDefault = true,
		})
	end
end

return CalibrationController
