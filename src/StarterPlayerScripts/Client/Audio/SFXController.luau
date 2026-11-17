local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundGroups = require(script.Parent:WaitForChild("SoundGroups"))

local SFXController = {}
SFXController.__index = SFXController

-- All gameplay SFX live in this one table so the ids are easy to swap.
-- The defaults are Roblox built-in rbxasset sounds (shipped with every
-- client, no marketplace dependency); replace any soundId with a Roblox
-- library "rbxassetid://..." id to retheme a cue.
local SOUND_DEFS = {
	comboBreak = {
		soundId = "rbxasset://sounds/bass.wav",
		volume = 0.45,
		playbackSpeed = 1.05,
		-- Falling-pitch tail sells the "combo dropped" feeling.
		fallToPlaybackSpeed = 0.45,
		fallSeconds = 0.4,
	},
	feverStart = {
		soundId = "rbxassetid://9120704978",
		volume = 0.45,
		playbackSpeed = 1.2,
	},
	songComplete = {
		soundId = "rbxassetid://770373343",
		volume = 0.6,
		playbackSpeed = 1,
	},
	countdownTick = {
		soundId = "rbxassetid://770375074",
		volume = 0.5,
		playbackSpeed = 1,
	},
	countdownGo = {
		soundId = "rbxassetid://770373595",
		volume = 0.55,
		playbackSpeed = 1,
	},
	-- The crowd, from the Music Game place: a roar as the song starts, during
	-- Fever and at the end.
	cheerStart = {
		soundId = "rbxassetid://786602174",
		volume = 0.4,
		playbackSpeed = 1,
	},
	cheerFever = {
		soundId = "rbxassetid://786602324",
		volume = 0.45,
		playbackSpeed = 1,
	},
	cheerEnd = {
		soundId = "rbxassetid://786602445",
		volume = 0.45,
		playbackSpeed = 1,
	},
	cheerMilestone = {
		soundId = "rbxassetid://786602174",
		volume = 0.5,
		playbackSpeed = 1.05,
	},
	-- The crowd answering a finished hold or run: the roar, short and quick.
	crowdPop = {
		soundId = "rbxassetid://786602174",
		volume = 0.3,
		playbackSpeed = 1.2,
	},
	-- The combo shield catching a miss: a rising ping, heard as a save.
	shieldSave = {
		soundId = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.5,
		playbackSpeed = 0.9,
		fallToPlaybackSpeed = 1.6,
		fallSeconds = 0.3,
	},
	-- A gold pickup: a bright ping pitched well above the grade cues.
	itemCollect = {
		soundId = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.45,
		playbackSpeed = 1.9,
	},
	-- A charged ability landing on the floor: a soft rising chime, heard as "go get it".
	abilityAppear = {
		soundId = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.32,
		playbackSpeed = 1.2,
		fallToPlaybackSpeed = 1.8,
		fallSeconds = 0.25,
	},
	-- A pose held to the end: a bright rising shine over the grade cue.
	poseShine = {
		soundId = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.45,
		playbackSpeed = 1.6,
		fallToPlaybackSpeed = 2.4,
		fallSeconds = 0.35,
	},
	-- A press that catches nothing: a soft tap, so it is heard as a wrong hit.
	emptyPress = {
		soundId = "rbxassetid://770372471",
		volume = 0.3,
		playbackSpeed = 1,
	},
	clapSnap = {
		soundId = "rbxassetid://12222140",
		volume = 0.34,
		playbackSpeed = 1.1,
	},
	clapThud = {
		soundId = "rbxassetid://9126267420",
		volume = 0.3,
		playbackSpeed = 1.25,
	},
	runWhoosh = {
		soundId = "rbxassetid://9125648149",
		volume = 0.32,
		playbackSpeed = 1.1,
	},
	-- Each reached run tile climbs a whole tone, so a long run sounds like a scale.
	runBlip = {
		soundId = "rbxassetid://9125397272",
		volume = 0.26,
		playbackSpeed = 1,
		voices = 3,
		stepSemitones = 2,
		maxPitch = 2,
	},
	runDone = {
		soundId = "rbxassetid://9126073001",
		volume = 0.4,
		playbackSpeed = 1,
	},
	runFail = {
		soundId = "rbxassetid://9126073302",
		volume = 0.3,
		playbackSpeed = 0.8,
		fallToPlaybackSpeed = 0.3,
		fallSeconds = 0.45,
	},
	holdSwell = {
		soundId = "rbxassetid://9119803633",
		volume = 0.16,
		playbackSpeed = 0.9,
		looped = true,
		riseToPlaybackSpeed = 1.35,
	},
	holdTick = {
		soundId = "rbxassetid://9126075967",
		volume = 0.18,
		playbackSpeed = 1.3,
		voices = 2,
	},
	holdChime = {
		soundId = "rbxassetid://9126073318",
		volume = 0.42,
		playbackSpeed = 1.1,
	},
	holdDrop = {
		soundId = "rbxassetid://9126267607",
		volume = 0.32,
		playbackSpeed = 0.9,
	},
	-- The menus, from Roblox's own UI sound set (Roblox_UI_*).
	uiHover = {
		soundId = "rbxassetid://15675032796",
		volume = 0.16,
		playbackSpeed = 1.15,
		voices = 2,
	},
	uiClick = {
		soundId = "rbxassetid://15675059323",
		volume = 0.38,
		playbackSpeed = 1,
		voices = 2,
	},
	uiOpen = {
		soundId = "rbxassetid://15675012262",
		volume = 0.32,
		playbackSpeed = 1.05,
	},
	uiClose = {
		soundId = "rbxassetid://15675081158",
		volume = 0.28,
		playbackSpeed = 1,
	},
	uiSwitch = {
		soundId = "rbxassetid://15675046931",
		volume = 0.26,
		playbackSpeed = 1.2,
	},
	uiBuy = {
		soundId = "rbxassetid://15675043410",
		volume = 0.42,
		playbackSpeed = 1,
	},
	uiDenied = {
		soundId = "rbxassetid://15675075163",
		volume = 0.32,
		playbackSpeed = 1,
	},
}

-- A caught note plays a drum sample on top of the song, so every hit sounds
-- like part of the track. Each group alternates its samples so fast runs do
-- not machine-gun one sound.
local HIT_GROUPS = {
	Clap = { "rbxassetid://866504380", "rbxassetid://866504511" },
	Drum = { "rbxassetid://574838657", "rbxassetid://574838433" },
	Tamb = { "rbxassetid://864172134", "rbxassetid://864172106" },
	Hihat = { "rbxassetid://870818834", "rbxassetid://870818951", "rbxassetid://870819035" },
}
local HIT_VOLUME = 0.5
-- The hi-hat ticks under the song on every step, so it sits well below the clap.
-- It lands on the beat, so it stays above the landing thumps, which never do.
local HIT_VOLUMES = { Hihat = 0.4 }
local DEFAULT_HIT_GROUP = "Clap"
-- The cues that are the dancing itself, in the Dance Sounds volume with the hits.
local STEP_CUES = { clapSnap = true, clapThud = true }

local function groupFor(name: string): string
	if STEP_CUES[name] then
		return "steps"
	end

	if string.sub(name, 1, 2) == "ui" then
		return "menus"
	end

	return if string.sub(name, 1, 5) == "cheer" or string.sub(name, 1, 5) == "crowd" then "crowd" else "effects"
end
local STOP_FADE_SECONDS = 0.12

function SFXController.new()
	local folder = Instance.new("Folder")
	folder.Name = "DanceDanceStepSFX"
	folder.Parent = SoundService

	local sounds = {}

	for name, def in SOUND_DEFS do
		sounds[name] = {}

		for voice = 1, def.voices or 1 do
			local sound = Instance.new("Sound")
			sound.Name = name .. voice
			sound.SoundId = def.soundId
			sound.Volume = def.volume
			sound.PlaybackSpeed = def.playbackSpeed or 1
			sound.Looped = def.looped == true
			sound.SoundGroup = SoundGroups.get(groupFor(name))
			sound.Parent = folder
			table.insert(sounds[name], sound)
		end
	end

	local hits = {}

	for group, ids in HIT_GROUPS do
		hits[group] = {}

		for index, soundId in ids do
			local sound = Instance.new("Sound")
			sound.Name = group .. index
			sound.SoundId = soundId
			sound.Volume = HIT_VOLUMES[group] or HIT_VOLUME
			sound.SoundGroup = SoundGroups.get("steps")
			sound.Parent = folder
			table.insert(hits[group], sound)
		end
	end

	-- A cue loaded on its first play sounds late, and the clap must land on the
	-- press, so every cue is fetched before the first run.
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(folder:GetChildren())
		end)

		if not ok then
			warn("[DanceDanceStep] Could not preload SFX: " .. tostring(err))
		end
	end)

	return setmetatable({
		folder = folder,
		sounds = sounds,
		hits = hits,
		hitGroup = DEFAULT_HIT_GROUP,
		hitTurn = 0,
		voiceTurn = {},
		tweens = {},
		stopTurn = {},
	}, SFXController)
end

function SFXController:_voice(name: string): Sound?
	local voices = self.sounds[name]

	if voices == nil or #voices == 0 or voices[1].SoundId == "" then
		return nil
	end

	local turn = (self.voiceTurn[name] or 0) % #voices + 1
	self.voiceTurn[name] = turn

	return voices[turn]
end

function SFXController:_cancelTween(sound: Sound)
	local running = self.tweens[sound]

	if running ~= nil then
		running:Cancel()
		self.tweens[sound] = nil
	end
end

function SFXController:_tween(sound: Sound, info: TweenInfo, goal: { [string]: any })
	self:_cancelTween(sound)

	local tween = TweenService:Create(sound, info, goal)
	self.tweens[sound] = tween
	tween:Play()
end

-- `pitch` scales the cue's own playback speed, falling tail included.
function SFXController:play(name: string, pitch: number?)
	local def = SOUND_DEFS[name]
	local sound = self:_voice(name)

	if sound == nil or def == nil then
		return
	end

	local scale = pitch or 1
	self.stopTurn[sound] = nil
	self:_cancelTween(sound)
	sound.Volume = def.volume
	sound.PlaybackSpeed = (def.playbackSpeed or 1) * scale
	sound.TimePosition = 0
	sound:Play()

	if def.fallToPlaybackSpeed ~= nil then
		local info = TweenInfo.new(def.fallSeconds or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		self:_tween(sound, info, { PlaybackSpeed = def.fallToPlaybackSpeed * scale })
	end
end

-- A short fade instead of a hard stop, which clicks on a sustained tone.
function SFXController:stop(name: string)
	local voices = self.sounds[name]

	if voices == nil then
		return
	end

	for _, sound in voices do
		if sound.IsPlaying and self.stopTurn[sound] == nil then
			local token = {}
			self.stopTurn[sound] = token
			self:_tween(sound, TweenInfo.new(STOP_FADE_SECONDS), { Volume = 0 })

			task.delay(STOP_FADE_SECONDS, function()
				if self.stopTurn[sound] == token then
					self.stopTurn[sound] = nil
					sound:Stop()
				end
			end)
		end
	end
end

-- scale is 0..1 on top of the sample's own volume, for quieter sections.
function SFXController:playHit(groupName: string?, scale: number?)
	local name = if groupName ~= nil and self.hits[groupName] ~= nil then groupName else self.hitGroup
	local group = self.hits[name]
	self.hitTurn += 1

	local sound = group[(self.hitTurn - 1) % #group + 1]
	sound.Volume = (HIT_VOLUMES[name] or HIT_VOLUME) * (scale or 1)
	sound.TimePosition = 0
	sound:Play()
end

return SFXController
