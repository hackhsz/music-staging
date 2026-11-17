--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputStrategy = require(Shared:WaitForChild("InputStrategy"))
local PlayerSettings = require(Shared:WaitForChild("PlayerSettings"))
local MenuScreen = require(script.Parent.MenuScreen)
local UiKit = require(script.Parent.Parent.UiKit)

local WINDOW = "settings"
local PAGE_SUFFIX = "Page"
-- A styled (Pill) button shows it is picked or on with this tag.
local PICKED_TAG = "Primary"
local ROW_TEMPLATES =
	{ slider = "SliderRow", toggle = "ToggleRow", choice = "ChoiceRow", key = "KeyRow", button = "KeyRow" }
local ABOUT_DEFAULT = "Changes save as you make them."
local CONTROLS_SECTION = "controls"
local DEVICE_TITLES = { keyboard = "KEYBOARD", gamepad = "CONTROLLER", touch = "TOUCH" }
local DEVICE_ABOUT = {
	keyboard = "Click a key, then press the one you want for it. Escape cancels.",
	gamepad = "Pick a row, then press the button you want for it.",
	touch = ABOUT_DEFAULT,
}
local CAPTURE_TEXT = { key = "PRESS A KEY", button = "PRESS A BUTTON" }
-- A key pick that never gets a key gives up, so the hotkeys are not held for ever.
local CAPTURE_TIMEOUT_SECONDS = 6
local CAPTURE_RELEASE_SECONDS = 0.1
local OFFSET_BLURB = "Steps feel early or late? Nudge the offset until a Perfect feels like it lands on the beat. The game also tunes it a little after every run."
local ABOUT_BY_SECTION = { gameplay = OFFSET_BLURB }
local TITLE_BY_SECTION = { gameplay = "TIMING OFFSET" }

type Controls = {
	valueLabel: TextLabel?,
	minusButton: GuiButton?,
	plusButton: GuiButton?,
}

type Row = { setting: PlayerSettings.Setting, frame: GuiObject }
type Tab = { button: GuiButton, section: string }

type Fields = {
	menu: MenuScreen.MenuScreen,
	pausePanel: GuiObject?,
	sets: { Controls },
	marker: GuiObject?,
	about: TextLabel?,
	detailTitle: TextLabel?,
	tabs: { Tab },
	pages: { [string]: GuiObject },
	rows: { [string]: Row },
	values: { [string]: any },
	tabImage: string?,
	pickedTabImage: string?,
	section: string,
	device: string,
	capturing: string?,
	captureConnection: RBXScriptConnection?,
	offsetSeconds: number,
	onSettingChanged: ((id: string, value: any) -> ())?,
	onReset: ((section: string) -> ())?,
	adjustOffset: ((deltaSeconds: number) -> ())?,
}

-- The Settings window in StarterGui.Menu: a tab per PlayerSettings section, each a
-- page of rows authored under the setting's id (SliderRow, ToggleRow, ChoiceRow and
-- KeyRow in Templates are the patterns), with the timing offset on the gameplay page. The pause screen keeps its own small
-- offset panel in StarterGui.GameHud.Settings. Drawing and taps only:
-- SettingsController applies and saves, CalibrationController owns the offset.
local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

export type SettingsPanel = typeof(setmetatable({} :: Fields, SettingsPanel))

local function controls(root: GuiObject?): Controls
	return {
		valueLabel = UiKit.authored(root, "Value", "TextLabel"),
		minusButton = UiKit.authored(root, "MinusButton", "GuiButton"),
		plusButton = UiKit.authored(root, "PlusButton", "GuiButton"),
	}
end

local function pageName(section: string): string
	return string.upper(string.sub(section, 1, 1)) .. string.sub(section, 2) .. PAGE_SUFFIX
end

-- The heading over a tab's rows: its own title, or the tab's name.
local function sectionTitle(section: string): string
	if TITLE_BY_SECTION[section] ~= nil then
		return TITLE_BY_SECTION[section]
	end

	for _, entry in PlayerSettings.Sections do
		if entry.id == section then
			return entry.label
		end
	end

	return ""
end

-- Which controls the Controls tab shows: those of the device last used.
local function deviceOf(inputType: Enum.UserInputType): string?
	local name = inputType.Name

	if string.sub(name, 1, 7) == "Gamepad" then
		return "gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "touch"
	elseif inputType == Enum.UserInputType.Keyboard or string.sub(name, 1, 5) == "Mouse" then
		return "keyboard"
	end

	return nil
end

local function startingDevice(): string
	local device = deviceOf(UserInputService:GetLastInputType())

	if device ~= nil then
		return device
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end

	return if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then "gamepad" else "keyboard"
end

local function attribute(instance: Instance?, name: string): string?
	local value = if instance ~= nil then instance:GetAttribute(name) else nil

	return if type(value) == "string" then value else nil
end

function SettingsPanel.new(gui: ScreenGui?, menu: MenuScreen.MenuScreen): SettingsPanel
	local pausePanel = UiKit.authored(gui, "Settings", "GuiObject")
	local window = menu:window(WINDOW)
	local pagesFrame = UiKit.authored(window, "Pages", "GuiObject")
	local gameplay = UiKit.authored(pagesFrame, "GameplayPage", "GuiObject")
	local tabsFrame = UiKit.authored(window, "Tabs", "GuiObject")
	local hint = UiKit.authored(pausePanel, "Hint", "TextLabel")

	if hint ~= nil then
		hint.Text ..= UiKit.keyHint("  /  O CLOSE")
	end

	if pausePanel ~= nil then
		pausePanel.Visible = false
	end

	local fields: Fields = {
		menu = menu,
		pausePanel = pausePanel,
		sets = { controls(pausePanel), controls(gameplay) },
		marker = UiKit.authored(gameplay, "Meter.Marker", "GuiObject"),
		about = UiKit.authored(window, "Footer.About", "TextLabel"),
		detailTitle = UiKit.authored(window, "Heading", "TextLabel"),
		tabs = {},
		pages = {},
		rows = {},
		values = PlayerSettings.resolve(nil),
		tabImage = attribute(tabsFrame, "TabImage"),
		pickedTabImage = attribute(tabsFrame, "PickedTabImage"),
		section = PlayerSettings.Sections[1].id,
		device = startingDevice(),
		capturing = nil,
		captureConnection = nil,
		offsetSeconds = 0,
		onSettingChanged = nil,
		onReset = nil,
		adjustOffset = nil,
	}
	local self = setmetatable(fields, SettingsPanel)
	local rangeMs = math.floor(InputStrategy.MaxOffsetSeconds * 1000 + 0.5)

	local function labelEnd(name: string, ms: number)
		local label = UiKit.authored(gameplay, name, "TextLabel")

		if label ~= nil then
			label.Text = ("%+dMS"):format(ms)
		end
	end

	labelEnd("EarlyLabel", -rangeMs)
	labelEnd("LateLabel", rangeMs)

	for index, section in PlayerSettings.Sections do
		local page = UiKit.authored(pagesFrame, pageName(section.id), "GuiObject")
		local button = UiKit.authored(tabsFrame, "Tab" .. index, "GuiButton")

		if page ~= nil then
			fields.pages[section.id] = page
		end

		if button ~= nil then
			table.insert(fields.tabs, { button = button, section = section.id })
			UiKit.bindHover(button)
			button.Activated:Connect(function()
				self:_showSection(section.id)
			end)
		end
	end

	local templates = UiKit.authored(window, "Templates", "Folder")

	-- Each row is authored on its page under the setting's id; one with no row yet
	-- gets a copy of its kind's template, so a new setting shows up before it is laid out.
	for order, setting in PlayerSettings.Settings do
		local page = fields.pages[setting.section]
		local authored = if page ~= nil then page:FindFirstChild(setting.id) else nil
		local frame: GuiObject? = if authored ~= nil and authored:IsA("GuiObject") then authored else nil

		if frame == nil and page ~= nil then
			local template = UiKit.authored(templates, ROW_TEMPLATES[setting.kind], "GuiObject")

			if template ~= nil then
				frame = template:Clone()
				frame.Name = setting.id
				frame.LayoutOrder = order
				frame.Visible = true
				frame.Parent = page
			end
		end

		if frame ~= nil then
			fields.rows[setting.id] = { setting = setting, frame = frame }
			self:_bindRow(setting, frame)
			self:_paintRow(setting.id)
		end
	end

	local resetTab = UiKit.authored(window, "Footer.ResetTabButton", "GuiButton")

	if resetTab ~= nil then
		UiKit.bindHover(resetTab)
		resetTab.Activated:Connect(function()
			self:_resetSection()
		end)
	end

	local closeButton = UiKit.authored(window, "CloseButton", "GuiButton")

	if closeButton ~= nil then
		UiKit.bindHover(closeButton)
		closeButton.Activated:Connect(function()
			menu:close(WINDOW)
		end)
	end

	local windowControls = fields.sets[2]

	for _, button in { windowControls.minusButton, windowControls.plusButton } do
		if button ~= nil then
			UiKit.bindHover(button)
			self:_describeOnHover(button, OFFSET_BLURB)
		end
	end

	if window ~= nil then
		window:GetPropertyChangedSignal("Visible"):Connect(function()
			self:_stopCapture()
		end)
	end

	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local device = deviceOf(inputType)

		if device ~= nil and device ~= self.device and self.capturing == nil then
			self.device = device
			self:_showDevice()
		end
	end)

	self:_showSection(fields.section)

	return self
end

function SettingsPanel._showDevice(self: SettingsPanel)
	for _, row in self.rows do
		if row.setting.device ~= nil then
			row.frame.Visible = row.setting.device == self.device
		end
	end

	if self.section == CONTROLS_SECTION then
		self:_describe(DEVICE_TITLES[self.device], DEVICE_ABOUT[self.device])
	end
end

function SettingsPanel._showSection(self: SettingsPanel, section: string)
	self:_stopCapture()
	self.section = section

	for id, page in self.pages do
		page.Visible = id == section
	end

	for _, tab in self.tabs do
		self:_paintPicked(tab.button, tab.section == section)
	end

	self:_describe(sectionTitle(section), ABOUT_BY_SECTION[section] or ABOUT_DEFAULT)
	self:_showDevice()
end

-- An image button swaps to its picked art; a styled one takes the picked tag.
function SettingsPanel._paintPicked(self: SettingsPanel, button: GuiObject, picked: boolean)
	local image = if picked then self.pickedTabImage else self.tabImage

	if image ~= nil and button:IsA("ImageButton") then
		UiKit.setImage(button, image)
	elseif picked then
		CollectionService:AddTag(button, PICKED_TAG)
	else
		CollectionService:RemoveTag(button, PICKED_TAG)
	end
end

function SettingsPanel._describe(self: SettingsPanel, title: string, blurb: string)
	if self.detailTitle ~= nil then
		self.detailTitle.Text = title
	end

	if self.about ~= nil then
		self.about.Text = blurb
	end
end

function SettingsPanel._describeOnHover(self: SettingsPanel, gui: GuiObject, blurb: string, title: string?)
	gui.MouseEnter:Connect(function()
		self:_describe(title or sectionTitle(self.section), blurb)
	end)
end

-- The open tab back to its defaults; on the gameplay tab, the timing offset to zero.
function SettingsPanel._resetSection(self: SettingsPanel)
	self:_stopCapture()

	if self.section == "gameplay" then
		if self.adjustOffset ~= nil then
			self.adjustOffset(-self.offsetSeconds)
		end
	elseif self.onReset ~= nil then
		self.onReset(self.section)
	end
end

function SettingsPanel.bindReset(self: SettingsPanel, callback: (section: string) -> ())
	self.onReset = callback
end

function SettingsPanel._changed(self: SettingsPanel, id: string, value: any)
	if self.onSettingChanged ~= nil then
		self.onSettingChanged(id, value)
	end
end

function SettingsPanel._bindRow(self: SettingsPanel, setting: PlayerSettings.Setting, frame: GuiObject)
	local label = UiKit.child(frame, "Label", "TextLabel")

	if label ~= nil then
		label.Text = setting.label
	end

	local blurb = UiKit.child(frame, "Blurb", "TextLabel")

	if blurb ~= nil then
		blurb.Text = setting.blurb
	end

	if setting.kind == "slider" then
		self:_bindSlider(setting, frame)
	elseif setting.kind == "toggle" then
		local switch = UiKit.child(frame, "Switch", "GuiButton")

		if switch ~= nil then
			UiKit.bindHover(switch)
			switch.Activated:Connect(function()
				self:_changed(setting.id, not self.values[setting.id])
			end)
		end
	elseif setting.kind == "key" or setting.kind == "button" then
		local keyButton = UiKit.child(frame, "KeyButton", "GuiButton")

		if keyButton ~= nil then
			UiKit.bindHover(keyButton)
			keyButton.Activated:Connect(function()
				self:_startCapture(setting.id)
			end)
		end
	else
		self:_bindChoiceStep(setting, UiKit.child(frame, "PrevButton", "GuiButton"), -1)
		self:_bindChoiceStep(setting, UiKit.child(frame, "NextButton", "GuiButton"), 1)
	end
end

-- Waits for the next keyboard key, or controller button for a button row, and
-- offers it as the new binding. Picking the same row again, or Escape, cancels.
function SettingsPanel._startCapture(self: SettingsPanel, id: string)
	if self.capturing == id then
		self:_stopCapture()
		return
	end

	self:_stopCapture()
	self.capturing = id
	self:_paintRow(id)

	local row = self.rows[id]
	local wantsButton = row ~= nil and row.setting.kind == "button"

	self.captureConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		local cancel = input.KeyCode == Enum.KeyCode.Escape
		local offered = if wantsButton
			then PlayerSettings.buttonCode(input.KeyCode.Name) ~= nil
			else input.UserInputType == Enum.UserInputType.Keyboard

		if not (offered or cancel) or self.captureConnection == nil then
			return
		end

		self.captureConnection:Disconnect()
		self.captureConnection = nil

		if not cancel then
			self:_changed(id, input.KeyCode.Name)
		end

		-- The hotkeys see this same key; capturing stays on until they have, so
		-- binding B does not also open the shop.
		task.delay(CAPTURE_RELEASE_SECONDS, function()
			if self.capturing == id then
				self:_stopCapture()
			end
		end)
	end)

	task.delay(CAPTURE_TIMEOUT_SECONDS, function()
		if self.capturing == id then
			self:_stopCapture()
		end
	end)
end

function SettingsPanel._stopCapture(self: SettingsPanel)
	local id = self.capturing

	if self.captureConnection ~= nil then
		self.captureConnection:Disconnect()
		self.captureConnection = nil
	end

	self.capturing = nil

	if id ~= nil then
		self:_paintRow(id)
	end
end

function SettingsPanel.isCapturingKey(self: SettingsPanel): boolean
	return self.capturing ~= nil
end

-- A choice's arrows step through its options and wrap round at either end.
function SettingsPanel._bindChoiceStep(self: SettingsPanel, setting: PlayerSettings.Setting, button: GuiButton?, step: number)
	if button == nil then
		return
	end

	local options = setting.options or {}

	UiKit.bindHover(button)
	button.Activated:Connect(function()
		local index = table.find(options, self.values[setting.id]) or 1

		self:_changed(setting.id, options[(index - 1 + step) % #options + 1])
	end)
end

-- Press anywhere on the track and drag; the value follows the pointer.
function SettingsPanel._bindSlider(self: SettingsPanel, setting: PlayerSettings.Setting, frame: GuiObject)
	local track = UiKit.child(frame, "Track", "GuiObject")

	if track == nil then
		return
	end

	local dragging = false

	local function follow(x: number)
		local share = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)

		self:_changed(setting.id, math.clamp(share, 0, 1))
	end

	track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			follow(input.Position.X)
			UiKit.playSound("uiClick")
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local moved = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch

		if dragging and moved then
			follow(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

function SettingsPanel._paintRow(self: SettingsPanel, id: string)
	local row = self.rows[id]

	if row == nil then
		return
	end

	local setting, frame, value = row.setting, row.frame, self.values[id]

	if setting.kind == "slider" then
		local track = UiKit.child(frame, "Track", "GuiObject")
		local fill = UiKit.child(track, "Fill", "GuiObject")
		local knob = UiKit.child(track, "Knob", "GuiObject")
		local valueLabel = UiKit.child(frame, "ValueLabel", "TextLabel")

		if fill ~= nil then
			fill.Size = UDim2.new(value, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
		end

		if knob ~= nil then
			knob.Position = UDim2.new(value, 0, knob.Position.Y.Scale, knob.Position.Y.Offset)
		end

		if valueLabel ~= nil then
			valueLabel.Text = ("%d%%"):format(math.floor(value * 100 + 0.5))
		end
	elseif setting.kind == "toggle" then
		local switch = UiKit.child(frame, "Switch", "GuiButton")
		local switchLabel = UiKit.child(switch, "PillLabel", "TextLabel")
		if switch ~= nil then
			self:_paintPicked(switch, value == true)
		end

		if switchLabel ~= nil then
			switchLabel.Text = if value then "ON" else "OFF"
		end
	elseif setting.kind == "key" or setting.kind == "button" then
		local keyLabel = UiKit.child(UiKit.child(frame, "KeyButton", "GuiButton"), "PillLabel", "TextLabel")
		local name = if setting.kind == "button"
			then PlayerSettings.buttonLabel(tostring(value))
			else string.upper(tostring(value))

		if keyLabel ~= nil then
			keyLabel.Text = if self.capturing == id then CAPTURE_TEXT[setting.kind] else name
		end
	else
		local valueLabel = UiKit.child(frame, "ValueLabel", "TextLabel")

		if valueLabel ~= nil then
			valueLabel.Text = (setting.optionLabels or {})[value] or string.upper(tostring(value))
		end
	end
end

-- One setting changed by the player; SettingsController applies and saves it.
function SettingsPanel.bindSettingChanged(self: SettingsPanel, callback: (id: string, value: any) -> ())
	self.onSettingChanged = callback
end

function SettingsPanel.setSettingValue(self: SettingsPanel, id: string, value: any)
	self.values[id] = value
	self:_paintRow(id)
end

function SettingsPanel.isVisible(self: SettingsPanel): boolean
	return self.menu:isOpen(WINDOW) or (self.pausePanel ~= nil and self.pausePanel.Visible)
end

function SettingsPanel.setVisible(self: SettingsPanel, visible: boolean)
	if visible then
		self:toggle()
		return
	end

	self.menu:close(WINDOW)

	if self.pausePanel ~= nil then
		self.pausePanel.Visible = false
	end
end

-- During a run the menu is blocked, so the pause screen's panel stands in.
function SettingsPanel.toggle(self: SettingsPanel)
	if not self.menu:isBlocked() then
		self.menu:toggle(WINDOW)
		return
	end

	if self.pausePanel ~= nil then
		self.pausePanel.Visible = not self.pausePanel.Visible
	end
end

function SettingsPanel.updateOffset(self: SettingsPanel, offsetSeconds: number)
	local offsetMs = math.floor(offsetSeconds * 1000 + 0.5)
	local text = ("%s%dMS"):format(if offsetMs >= 0 then "+" else "", offsetMs)

	self.offsetSeconds = offsetSeconds

	for _, set in self.sets do
		if set.valueLabel ~= nil then
			set.valueLabel.Text = text
		end
	end

	if self.marker ~= nil then
		local share = math.clamp(offsetSeconds / InputStrategy.MaxOffsetSeconds, -1, 1)
		self.marker.Position = UDim2.fromScale(0.5 + share / 2, 0.5)
	end
end

function SettingsPanel.bindAdjust(self: SettingsPanel, adjust: (deltaSeconds: number) -> ())
	self.adjustOffset = adjust

	for _, set in self.sets do
		if set.minusButton ~= nil then
			set.minusButton.Activated:Connect(function()
				adjust(-InputStrategy.OffsetStepSeconds)
			end)
		end

		if set.plusButton ~= nil then
			set.plusButton.Activated:Connect(function()
				adjust(InputStrategy.OffsetStepSeconds)
			end)
		end
	end
end

return SettingsPanel
