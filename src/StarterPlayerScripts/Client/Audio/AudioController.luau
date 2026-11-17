local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("AudioCatalog"))
local AudioClock = require(Shared:WaitForChild("AudioClock"))
local SoundGroups = require(script.Parent:WaitForChild("SoundGroups"))

-- A miss muffles the song for a moment, the way Friday Night Funkin' drops the
-- vocals: the music itself tells you that one got away. Only the tone changes,
-- never the speed, so the song stays on the clock the judge uses.
local STUMBLE_HIGH_GAIN = -30
local STUMBLE_MID_GAIN = -12
local STUMBLE_SECONDS = 0.45
local SONG_VOLUME = 1
-- A highlighted song plays its preview window on a loop, a little under the run's
-- volume, faded in and out so browsing never clicks. The window is at least
-- PREVIEW_MIN_SECONDS and a whole number of bars, so each loop ends on a bar line.
local PREVIEW_VOLUME = 0.8
local PREVIEW_FADE_SECONDS = 1
local PREVIEW_MIN_SECONDS = 20
local BEATS_PER_BAR = 4

local AudioController = {}
AudioController.__index = AudioController

local function previewLength(song: any): number
	local seconds = math.max(tonumber(song.previewDurationSeconds) or 0, PREVIEW_MIN_SECONDS)
	local bpm = tonumber(song.bpm)

	if bpm == nil or bpm <= 0 then
		return seconds
	end

	local bar = 60 / bpm * BEATS_PER_BAR

	return math.ceil(seconds / bar) * bar
end

function AudioController.new()
	local sound = Instance.new("Sound")
	sound.Name = "DanceDanceStepSong"
	sound.Looped = false
	sound.Volume = SONG_VOLUME
	sound.SoundGroup = SoundGroups.get("music")
	sound.Parent = SoundService

	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.LowGain = 0
	muffle.MidGain = 0
	muffle.HighGain = 0
	muffle.Parent = sound

	local self = setmetatable({
		sound = sound,
		muffle = muffle,
		muffleTween = nil,
		clock = AudioClock.new(),
		currentSong = nil,
		preparedSongId = nil,
		lastStatus = "not_prepared",
		previewSongId = nil,
		previewToken = 0,
		previewRequest = 0,
		volumeTween = nil,
		stopToken = 0,
		fadingUntil = 0,
	}, AudioController)

	RunService.Heartbeat:Connect(function()
		AudioClock.observe(self.clock, os.clock(), sound.TimePosition, sound.IsPlaying)
	end)

	return self
end

function AudioController:prepare(songId: string)
	self:_endPreview()

	local song = AudioCatalog.getSong(songId)
	self.currentSong = song
	self.preparedSongId = nil

	if AudioCatalog.LibraryPolicy.UnloadPreviousSongOnPrepare then
		self.sound:Stop()
		self.sound.SoundId = ""
	end

	local audioAssetId = AudioCatalog.getRuntimeAudioAssetId(songId)

	if song == nil or audioAssetId == nil then
		self.sound.SoundId = ""
		self.lastStatus = "no_audio_fallback"
		return false
	end

	self.sound.SoundId = ("rbxassetid://%s"):format(tostring(audioAssetId))

	local ok = pcall(function()
		ContentProvider:PreloadAsync({ self.sound })
	end)

	if not ok then
		self.sound.SoundId = ""
		self.lastStatus = "preload_failed"
		return false
	end

	self.preparedSongId = songId
	self.lastStatus = "prepared"
	return true
end

-- fromSeconds starts the song part-way in, so a late start still matches the clock.
function AudioController:play(fromSeconds: number?)
	if self.sound.SoundId == "" then
		self.lastStatus = "silent_playback"
		return false
	end

	self:_endPreview()
	self:_cancelStop()
	AudioClock.reset(self.clock)
	self.sound.Volume = SONG_VOLUME
	self.sound.TimePosition = math.max(fromSeconds or 0, 0)
	self.sound:Play()
	self.lastStatus = "playing"
	return true
end

-- Loops a song's preview window until another song is previewed, the preview
-- stops, or a run prepares its own audio. Yields while the asset loads.
function AudioController:preview(songId: string)
	local song = AudioCatalog.getSong(songId)

	if song == nil or AudioCatalog.getRuntimeAudioAssetId(song.id) == nil then
		self:stopPreview()
		return
	end

	if self.previewSongId == song.id then
		return
	end

	self.previewRequest += 1

	local request = self.previewRequest

	-- Loading yields; a newer request or a run that took the sound wins.
	if self.preparedSongId ~= song.id and not self:prepare(song.id) or self.previewRequest ~= request then
		return
	end

	self.previewToken += 1
	self.previewSongId = song.id

	self:_cancelStop()

	local token = self.previewToken
	local from = tonumber(song.previewStartSeconds) or 0
	local seconds = previewLength(song)

	task.spawn(function()
		while self.previewToken == token do
			self.sound.TimePosition = from
			self.sound.Volume = 0
			self.sound:Play()
			self:_fadeTo(PREVIEW_VOLUME)
			task.wait(math.max(seconds - PREVIEW_FADE_SECONDS, PREVIEW_FADE_SECONDS))

			if self.previewToken ~= token then
				return
			end

			self:_fadeTo(0)
			task.wait(PREVIEW_FADE_SECONDS)
		end
	end)
end

-- Where the playing preview is and how loud it is right now, for the song
-- picker to move with; no time while nothing previews.
function AudioController:getPreviewState(): (number?, number)
	if self.previewSongId == nil or not self.sound.IsPlaying then
		return nil, 0
	end

	return self.sound.TimePosition, self.sound.PlaybackLoudness
end

-- How loud the song is right now, 0 to about 1000; 0 while nothing plays.
function AudioController:getLoudness(): number
	return if self.sound.IsPlaying then self.sound.PlaybackLoudness else 0
end

function AudioController:stopPreview()
	self.previewRequest += 1

	if self.previewSongId == nil then
		return
	end

	local token = self.previewToken + 1
	self.previewToken = token
	self.previewSongId = nil
	self:_fadeTo(0)

	task.delay(PREVIEW_FADE_SECONDS, function()
		if self.previewToken == token and self.previewSongId == nil then
			self.sound:Stop()
		end
	end)
end

-- Cancels the preview loop and any fade or stop it left pending.
function AudioController:_endPreview()
	local previewing = self.previewSongId ~= nil

	self.previewToken += 1
	self.previewSongId = nil

	if self.volumeTween ~= nil then
		self.volumeTween:Cancel()
		self.volumeTween = nil
	end

	if previewing then
		self.sound:Stop()
	end

	self.sound.Volume = SONG_VOLUME
end

function AudioController:_fadeTo(volume: number, seconds: number?)
	if self.volumeTween ~= nil then
		self.volumeTween:Cancel()
	end

	self.volumeTween = TweenService:Create(self.sound, TweenInfo.new(seconds or PREVIEW_FADE_SECONDS, Enum.EasingStyle.Sine), {
		Volume = volume,
	})
	self.volumeTween:Play()
end

function AudioController:seek(seconds: number)
	if not self.sound.IsPlaying then
		return
	end

	AudioClock.reset(self.clock)
	self.sound.TimePosition = math.max(seconds, 0)
end

-- Where the music is, extrapolated to now; nil until playback is confirmed.
function AudioController:getPlayhead(now: number): number?
	return AudioClock.read(self.clock, now)
end

function AudioController:stumble()
	if self.muffleTween ~= nil then
		self.muffleTween:Cancel()
	end

	self.muffle.HighGain = STUMBLE_HIGH_GAIN
	self.muffle.MidGain = STUMBLE_MID_GAIN
	self.muffleTween = TweenService:Create(
		self.muffle,
		TweenInfo.new(STUMBLE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ HighGain = 0, MidGain = 0 }
	)
	self.muffleTween:Play()
end

function AudioController:stop()
	self:_cancelStop()
	self.sound:Stop()
end

-- Lets the song ring out instead of cutting it off. A fade already under way is
-- left to finish, so a quick quit right after a song ends does not clip its tail.
function AudioController:fadeOut(seconds: number)
	-- A run left from the pause menu has its song paused, not playing; it just stops.
	if not self.sound.IsPlaying then
		self.sound:Stop()
		return
	end

	if os.clock() < self.fadingUntil then
		return
	end

	self.stopToken += 1

	local token = self.stopToken
	self.fadingUntil = os.clock() + seconds
	self:_fadeTo(0, seconds)

	task.delay(seconds, function()
		if self.stopToken == token then
			self.sound:Stop()
			self.sound.Volume = SONG_VOLUME
		end
	end)
end

-- A new song or preview takes the sound back from a fade that has not finished.
function AudioController:_cancelStop()
	self.stopToken += 1
	self.fadingUntil = 0
end

function AudioController:pause()
	if self.sound.IsPlaying then
		self.sound:Pause()
		self.lastStatus = "paused"
	end
end

function AudioController:resume()
	if self.sound.SoundId ~= "" and self.sound.IsPaused then
		self.sound:Resume()
		self.lastStatus = "playing"
	end
end

return AudioController
