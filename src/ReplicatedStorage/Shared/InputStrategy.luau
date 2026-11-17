local Timing = require(script.Parent.Timing)

local InputStrategy = {}

InputStrategy.DeviceModes = {
	Keyboard = {
		id = "keyboard",
		description = "Arrow keys or WASD move one tile at a time.",
		controlHint = "MOVE: WASD / ARROWS / TAP TILES",
		qaPriority = "primary_desktop",
	},
	Touch = {
		id = "touch",
		description = "Arrow lanes under each thumb step one tile on touch-down; tapping a tile paths to it.",
		controlHint = "STEP: ARROW LANES OR TAP A TILE",
		qaPriority = "primary_mobile",
	},
	Gamepad = {
		id = "gamepad",
		description = "D-pad or left stick moves one tile at a time.",
		controlHint = "MOVE: D-PAD OR LEFT STICK",
		qaPriority = "deferred_console",
	},
}

InputStrategy.DefaultMode = InputStrategy.DeviceModes.Keyboard

InputStrategy.OffsetStepSeconds = 0.01
InputStrategy.MaxOffsetSeconds = Timing.MaxTimingOffsetSeconds
-- Presses queued behind the step in flight. Two, so a quick pair pressed
-- during one hop is played rather than half dropped, and a mashed key still
-- cannot run the character far past the beat.
InputStrategy.StepBufferSize = 2
InputStrategy.HoldRepeatDelaySeconds = 0.18
-- Two keys this close together are one diagonal press; further apart they are
-- two steps, so a key still held from the last step never bends the next one.
InputStrategy.ChordSeconds = 0.08
InputStrategy.StickThreshold = 0.5
InputStrategy.StepHopHeight = 0.4
-- A hop covers most of its distance in its first frames, so the character
-- answers the key at once; the timing never depends on it.
InputStrategy.StepEaseOutPower = 2.5
InputStrategy.LandDipStuds = 0.3
InputStrategy.LandDipDownSeconds = 0.04
InputStrategy.LandDipUpSeconds = 0.06
-- The highway dance on rigs that cannot be posed (R6): a small lunge toward the
-- arrow and back. A Miss is a wobble instead.
InputStrategy.DanceStepStuds = 0.8
InputStrategy.DanceStepHop = 0.35
InputStrategy.DanceStepSeconds = 0.22
InputStrategy.StumbleSeconds = 0.32
InputStrategy.StumbleTiltRadians = 0.25
-- The posed dance (DanceAnimator): how long each pose holds before easing back
-- to the groove (most of a beat, like FNF's sing poses, never under the
-- seconds floor), the kick a repeated press gives it, and Fever's extra size.
InputStrategy.DancePoseHoldSeconds = 0.2
InputStrategy.DancePoseHoldBeats = 0.75
InputStrategy.DanceMissHoldSeconds = 0.45
InputStrategy.DanceCheerHoldSeconds = 0.4
InputStrategy.DanceRepressKick = 7
InputStrategy.DancePressDip = 2.5
InputStrategy.DanceFeverScale = 1.2

InputStrategy.LaunchPlatformMatrix = {
	Desktop = {
		id = "desktop",
		launchStatus = "required",
		mode = InputStrategy.DeviceModes.Keyboard,
		requiredChecks = {
			"WASD and arrow-key movement",
			"fixed camera framing",
			"score/progress/result UI avoids Roblox topbar",
			"30-second full-song run",
		},
	},
	Phone = {
		id = "phone",
		launchStatus = "required",
		mode = InputStrategy.DeviceModes.Touch,
		requiredChecks = {
			"tap-to-tile movement",
			"safe-area screenshot",
			"default Roblox menu does not cover core HUD",
			"timing offset seeded at +30ms until calibrated",
		},
	},
	Tablet = {
		id = "tablet",
		launchStatus = "required",
		mode = InputStrategy.DeviceModes.Touch,
		requiredChecks = {
			"landscape tile readability",
			"tap target accuracy",
			"text scaling and shop panel fit",
		},
	},
	Console = {
		id = "console",
		launchStatus = "deferred",
		mode = InputStrategy.DeviceModes.Gamepad,
		requiredChecks = {
			"D-pad movement implementation",
			"console-specific prompts",
			"results and shop navigable without mouse/touch",
		},
	},
	VR = {
		id = "vr",
		launchStatus = "unsupported",
		mode = nil,
		requiredChecks = {
			"disable in Roblox dashboard until a VR-specific camera/control pass exists",
		},
	},
}

function InputStrategy.getModeForCapabilities(touchEnabled: boolean, keyboardEnabled: boolean, gamepadEnabled: boolean)
	if touchEnabled and not keyboardEnabled then
		return InputStrategy.DeviceModes.Touch
	end

	if gamepadEnabled and not keyboardEnabled then
		return InputStrategy.DeviceModes.Gamepad
	end

	return InputStrategy.DefaultMode
end

function InputStrategy.isLaunchSupported(platformId: string): boolean
	for _, platform in InputStrategy.LaunchPlatformMatrix do
		if platform.id == platformId then
			return platform.launchStatus == "required"
		end
	end

	return false
end

return InputStrategy
