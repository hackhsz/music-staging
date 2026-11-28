--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local FADE_SECONDS = 0.15
local POP_SECONDS = 0.25
local POP_FROM_SCALE = 0.88
local CLOSE_SECONDS = 0.18
local CLOSE_TO_SCALE = 0.7
local POP_NAME = "Pop"

type Fields = {
	gui: ScreenGui?,
	overlay: GuiObject?,
	overlayRest: number,
	cardScale: UIScale?,
	pauseButton: GuiButton?,
	resumeButton: GuiButton?,
	restartButton: GuiButton?,
	leaveButton: GuiButton?,
	settingsButton: GuiButton?,
	runActive: boolean,
	buttonReplaced: boolean,
	onClosed: (() -> ())?,
	releaseHovers: { () -> () },
	closing: boolean,
	closeToken: number,
}

-- The pause screen, authored in StarterGui.GameHud.Pause: a dimmed overlay over
-- a card with resume, restart and settings. GameHud.PauseButton only stands in
-- when the run HUD has no pause button of its own.
local PauseOverlay = {}
PauseOverlay.__index = PauseOverlay

export type PauseOverlay = typeof(setmetatable({} :: Fields, PauseOverlay))

local function addKeyHint(button: GuiButton?, hint: string)
	if button ~= nil and button:IsA("TextButton") then
		button.Text ..= UiKit.keyHint(hint)
	end
end

local function connect(button: GuiButton?, callback: () -> ())
	if button ~= nil then
		button.Activated:Connect(callback)
	end
end

function PauseOverlay.new(gui: ScreenGui?): PauseOverlay
	local overlay = UiKit.authored(gui, "Pause", "GuiObject")
	local card = UiKit.authored(overlay, "Card", "GuiObject")
	local keyHint = UiKit.authored(card, "KeyHint", "TextLabel")

	local fields: Fields = {
		gui = gui,
		overlay = overlay,
		overlayRest = if overlay ~= nil then overlay.BackgroundTransparency else 1,
		cardScale = if card ~= nil then UiKit.scaleOf(card, POP_NAME) else nil,
		pauseButton = UiKit.authored(gui, "PauseButton", "GuiButton"),
		resumeButton = UiKit.authored(card, "ResumeButton", "GuiButton"),
		restartButton = UiKit.authored(card, "RestartButton", "GuiButton"),
		leaveButton = if card ~= nil then card:FindFirstChild("LeaveButton") :: GuiButton? else nil,
		settingsButton = UiKit.authored(card, "SettingsButton", "GuiButton"),
		runActive = false,
		buttonReplaced = false,
		onClosed = nil,
		releaseHovers = {},
		closing = false,
		closeToken = 0,
	}

	for _, button in { fields.resumeButton, fields.restartButton, fields.settingsButton, fields.leaveButton } do
		if button ~= nil then
			table.insert(fields.releaseHovers, UiKit.bindHover(button))
		end
	end

	addKeyHint(fields.pauseButton, " (P)")
	addKeyHint(fields.resumeButton, " (P)")
	addKeyHint(fields.restartButton, " (R)")
	addKeyHint(fields.settingsButton, " (O)")

	if keyHint ~= nil then
		keyHint.Text = UiKit.keyHint(keyHint.Text)
	end

	if overlay ~= nil then
		overlay.Visible = false
	end

	if fields.pauseButton ~= nil then
		fields.pauseButton.Visible = false
	end

	if fields.leaveButton ~= nil then
		fields.leaveButton.Visible = false
	end

	return setmetatable(fields, PauseOverlay)
end

function PauseOverlay.setPaused(self: PauseOverlay, paused: boolean)
	local overlay = self.overlay

	if overlay == nil then
		return
	end

	if paused and (not overlay.Visible or self.closing) then
		self.closing = false
		self.closeToken += 1

		if self.gui ~= nil then
			UiKit.coverScreen(overlay, self.gui)
		end

		overlay.BackgroundTransparency = 1
		TweenService:Create(overlay, TweenInfo.new(FADE_SECONDS), {
			BackgroundTransparency = self.overlayRest,
		}):Play()

		local cardScale = self.cardScale

		if cardScale ~= nil then
			cardScale.Scale = POP_FROM_SCALE
			TweenService:Create(cardScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	if paused then
		overlay.Visible = true
	elseif overlay.Visible and not self.closing then
		if self.onClosed ~= nil then
			self.onClosed()
		end

		self:_playClose(overlay)
	end
end

function PauseOverlay._playClose(self: PauseOverlay, overlay: GuiObject)
	self.closing = true
	self.closeToken += 1

	local token = self.closeToken

	for _, release in self.releaseHovers do
		release()
	end

	TweenService:Create(overlay, TweenInfo.new(CLOSE_SECONDS), { BackgroundTransparency = 1 }):Play()

	if self.cardScale ~= nil then
		TweenService:Create(self.cardScale, TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = CLOSE_TO_SCALE,
		}):Play()
	end

	task.delay(CLOSE_SECONDS, function()
		if self.closeToken == token then
			self.closing = false
			overlay.Visible = false
		end
	end)
end

function PauseOverlay.setRunActive(self: PauseOverlay, active: boolean)
	self.runActive = active

	if self.pauseButton ~= nil then
		self.pauseButton.Visible = active and not self.buttonReplaced
	end
end

-- The authored HUD has its own pause button; this one only stands in without it.
function PauseOverlay.setButtonReplaced(self: PauseOverlay, replaced: boolean)
	self.buttonReplaced = replaced
	self:setRunActive(self.runActive)
end

-- The pause button and the resume button both toggle.
function PauseOverlay.bindToggle(self: PauseOverlay, callback: () -> ())
	connect(self.pauseButton, callback)
	connect(self.resumeButton, callback)
end

function PauseOverlay.bindRestart(self: PauseOverlay, callback: () -> ())
	connect(self.restartButton, callback)
end

-- Only a place with somewhere to leave to binds this; the button stays hidden otherwise.
function PauseOverlay.bindLeave(self: PauseOverlay, callback: () -> ())
	local button = self.leaveButton

	if button ~= nil then
		button.Visible = true
		button.Activated:Connect(callback)
	end
end

function PauseOverlay.bindSettings(self: PauseOverlay, callback: () -> ())
	connect(self.settingsButton, callback)
end

-- callback runs when the pause screen closes, so what it opened can close with it.
function PauseOverlay.bindClosed(self: PauseOverlay, callback: () -> ())
	self.onClosed = callback
end

return PauseOverlay
