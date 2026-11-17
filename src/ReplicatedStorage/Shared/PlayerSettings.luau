--!strict
-- Every player setting the Settings window shows: the server keeps them in the
-- profile and checks each change against this table, and the client builds the
-- window's rows from it. The timing offset is kept separately (Timing, Calibration).

export type Kind = "slider" | "toggle" | "choice" | "key" | "button"

export type Setting = {
	id: string,
	section: string,
	kind: Kind,
	label: string,
	blurb: string,
	default: any,
	-- A slider's steps, between 0 and 1.
	step: number?,
	-- A key or button setting's action, as the input code names it.
	action: string?,
	-- Controls rows only show for the device the player is using.
	device: string?,
	-- A choice's values in order, and what each shows.
	options: { string }?,
	optionLabels: { [string]: string }?,
}

local PlayerSettings = {}

PlayerSettings.Sections = {
	{ id = "audio", label = "AUDIO" },
	{ id = "graphics", label = "GRAPHICS" },
	{ id = "controls", label = "CONTROLS" },
	{ id = "gameplay", label = "GAMEPLAY" },
}

-- Keys a binding may not take: Roblox's menu, chat and console, and the ones that
-- mean "cancel" while a key is being picked.
local BLOCKED_KEYS = {
	Escape = true,
	Backquote = true,
	Tab = true,
	Slash = true,
	F9 = true,
	Menu = true,
	Unknown = true,
}
local NOT_KEYBOARD_PREFIXES = { "Button", "DPad", "Thumbstick", "Mouse", "World", "Touch", "Gamepad" }
-- Start and Select open Roblox's menus, and the left stick always steps.
local PAD_BUTTONS = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "D-PAD UP",
	DPadDown = "D-PAD DOWN",
	DPadLeft = "D-PAD LEFT",
	DPadRight = "D-PAD RIGHT",
}

PlayerSettings.Settings = {
	{
		id = "musicVolume",
		section = "audio",
		kind = "slider",
		label = "MUSIC",
		blurb = "The song and its preview.",
		default = 1,
		step = 0.05,
	},
	{
		id = "effectsVolume",
		section = "audio",
		kind = "slider",
		label = "SOUND EFFECTS",
		blurb = "Grades, combos, crowd and countdown.",
		default = 1,
		step = 0.05,
	},
	{
		id = "stepsVolume",
		section = "audio",
		kind = "slider",
		label = "DANCE SOUNDS",
		blurb = "The sounds of your own steps.",
		default = 1,
		step = 0.05,
	},
	{
		id = "menuVolume",
		section = "audio",
		kind = "slider",
		label = "MENU SOUNDS",
		blurb = "Clicks and whooshes in menus.",
		default = 1,
		step = 0.05,
	},
	{
		id = "quality",
		section = "graphics",
		kind = "choice",
		label = "EFFECTS QUALITY",
		blurb = "Lower it if the game lags.",
		default = "auto",
		options = { "auto", "high", "medium", "low" },
		optionLabels = { auto = "AUTO", high = "HIGH", medium = "MEDIUM", low = "LOW" },
	},
	{
		id = "backgroundBlur",
		section = "graphics",
		kind = "toggle",
		label = "BACKGROUND BLUR",
		blurb = "Makes the tiles stand out.",
		default = true,
	},
	{
		id = "cameraShake",
		section = "graphics",
		kind = "toggle",
		label = "CAMERA SHAKE",
		blurb = "Turn off if it feels like too much.",
		default = true,
	},
	{
		id = "keyUp",
		section = "controls",
		device = "keyboard",
		kind = "key",
		action = "up",
		label = "STEP UP",
		blurb = "The arrow keys work too.",
		default = "W",
	},
	{
		id = "keyLeft",
		section = "controls",
		device = "keyboard",
		kind = "key",
		action = "left",
		label = "STEP LEFT",
		blurb = "The arrow keys work too.",
		default = "A",
	},
	{
		id = "keyDown",
		section = "controls",
		device = "keyboard",
		kind = "key",
		action = "down",
		label = "STEP DOWN",
		blurb = "The arrow keys work too.",
		default = "S",
	},
	{
		id = "keyRight",
		section = "controls",
		device = "keyboard",
		kind = "key",
		action = "right",
		label = "STEP RIGHT",
		blurb = "The arrow keys work too.",
		default = "D",
	},
	{
		id = "keyClap",
		section = "controls",
		device = "keyboard",
		kind = "key",
		action = "clap",
		label = "CLAP",
		blurb = "Claps on the clap notes.",
		default = "Space",
	},
	{
		id = "padUp",
		section = "controls",
		device = "gamepad",
		kind = "button",
		action = "up",
		label = "STEP UP",
		blurb = "The left stick steps too.",
		default = "DPadUp",
	},
	{
		id = "padLeft",
		section = "controls",
		device = "gamepad",
		kind = "button",
		action = "left",
		label = "STEP LEFT",
		blurb = "The left stick steps too.",
		default = "DPadLeft",
	},
	{
		id = "padDown",
		section = "controls",
		device = "gamepad",
		kind = "button",
		action = "down",
		label = "STEP DOWN",
		blurb = "The left stick steps too.",
		default = "DPadDown",
	},
	{
		id = "padRight",
		section = "controls",
		device = "gamepad",
		kind = "button",
		action = "right",
		label = "STEP RIGHT",
		blurb = "The left stick steps too.",
		default = "DPadRight",
	},
	{
		id = "padClap",
		section = "controls",
		device = "gamepad",
		kind = "button",
		action = "clap",
		label = "CLAP",
		blurb = "Claps on the clap notes.",
		default = "ButtonX",
	},
	{
		id = "touchButtonSize",
		section = "controls",
		device = "touch",
		kind = "choice",
		label = "BUTTON SIZE",
		blurb = "The step and clap buttons.",
		default = "medium",
		options = { "small", "medium", "large" },
		optionLabels = { small = "SMALL", medium = "MEDIUM", large = "LARGE" },
	},
	{
		id = "touchFloorTap",
		section = "controls",
		device = "touch",
		kind = "toggle",
		label = "TAP THE FLOOR",
		blurb = "Tap a tile to walk to it.",
		default = true,
	},
} :: { Setting }

-- A keyboard key's KeyCode name a binding may take, or nil.
function PlayerSettings.keyCode(name: any): Enum.KeyCode?
	if type(name) ~= "string" or BLOCKED_KEYS[name] then
		return nil
	end

	for _, prefix in NOT_KEYBOARD_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return nil
		end
	end

	local ok, key = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)

	return if ok and typeof(key) == "EnumItem" then key else nil
end

-- A controller button's KeyCode name a binding may take, or nil.
function PlayerSettings.buttonCode(name: any): Enum.KeyCode?
	if type(name) ~= "string" or PAD_BUTTONS[name] == nil then
		return nil
	end

	return (Enum.KeyCode :: any)[name]
end

-- What a controller button is called on screen.
function PlayerSettings.buttonLabel(name: string): string
	return PAD_BUTTONS[name] or string.upper(name)
end

function PlayerSettings.get(id: string): Setting?
	for _, setting in PlayerSettings.Settings do
		if setting.id == id then
			return setting
		end
	end

	return nil
end

-- A value as the profile may keep it, or nil when it cannot be one.
function PlayerSettings.sanitize(id: string, value: any): any
	local setting = PlayerSettings.get(id)

	if setting == nil then
		return nil
	end

	if setting.kind == "slider" then
		local number = tonumber(value)

		if number == nil or number ~= number then
			return nil
		end

		local step = setting.step or 0.05

		return math.clamp(math.floor(number / step + 0.5) * step, 0, 1)
	elseif setting.kind == "toggle" then
		return if type(value) == "boolean" then value else nil
	elseif setting.kind == "key" then
		return if PlayerSettings.keyCode(value) ~= nil then value else nil
	elseif setting.kind == "button" then
		return if PlayerSettings.buttonCode(value) ~= nil then value else nil
	end

	return if type(value) == "string" and table.find(setting.options or {}, value) ~= nil then value else nil
end

-- Every setting's value from a saved table, the default where it is missing or bad.
function PlayerSettings.resolve(saved: any): { [string]: any }
	local values = {}

	for _, setting in PlayerSettings.Settings do
		local value = if type(saved) == "table" then PlayerSettings.sanitize(setting.id, saved[setting.id]) else nil
		values[setting.id] = if value ~= nil then value else setting.default
	end

	return values
end

return PlayerSettings
