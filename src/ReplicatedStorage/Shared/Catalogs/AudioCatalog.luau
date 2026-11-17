local RightsPolicy = require(script.Parent.Parent.Policies.RightsPolicy)

local AudioCatalog = {}

AudioCatalog.Policy = {
	Prototype = "Use metronome, owned audio, or permitted Roblox Creator Store audio only.",
	NoCopyrightedKpop = true,
	LoadOnlySelectedSong = true,
	PublicLaunchRequiresAudioAsset = true,
	RightsProofRequired = true,
}

AudioCatalog.LibraryPolicy = {
	CatalogLoadsMetadataOnly = true,
	MaxStartupAudioAssets = 0,
	MaxPreparedAudioAssets = 1,
	PreloadSelectedSongOnly = true,
	UnloadPreviousSongOnPrepare = true,
	LargeLibraryTargetSongs = 100,
	GracefulFailureStatuses = {
		"no_audio_fallback",
		"preload_failed",
		"silent_playback",
	},
}

AudioCatalog.Songs = {
	{
		id = "candy-pop-warmup",
		title = "Candy Pop Warmup",
		artist = "Internal Prototype",
		audioAssetId = 89257026989319,
		sourceAudioFile = "assets/audio/candy-pop-warmup.wav",
		bpm = 108,
		durationSeconds = 152,
		difficulty = "easy",
		previewStartSeconds = 0,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = true,
		noAudioFallback = false,
	},
	{
		id = "neon-heartline",
		title = "Neon Heartline",
		artist = "Internal Prototype",
		audioAssetId = 95968428163065,
		sourceAudioFile = "assets/audio/neon-heartline.wav",
		bpm = 128,
		durationSeconds = 145,
		difficulty = "normal",
		previewStartSeconds = 37,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = true,
		noAudioFallback = false,
	},
	{
		id = "combo-fever",
		title = "Combo Fever",
		artist = "Music Game",
		-- Owned by another account: it plays silent here until its owner gives
		-- this experience permission to use it on the asset's page.
		audioAssetId = 116921418670474,
		sourceAudioFile = "https://create.roblox.com/store/asset/116921418670474",
		bpm = 148,
		durationSeconds = 60,
		difficulty = "normal",
		previewStartSeconds = 10,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.Licensed,
		sourceStatus = RightsPolicy.AudioSourceStatuses.Licensed,
		rightsProof = "Music Game place (placeId 130079880284527)",
		ownerScope = "Roblox user Akpaid",
		loadPolicy = "on_song_start",
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "i-dont-wait",
		title = "I Don't Wait",
		artist = "DistroKid (Creator Store)",
		audioAssetId = 127192200172260,
		sourceAudioFile = "https://create.roblox.com/store/asset/127192200172260",
		bpm = 141,
		durationSeconds = 162,
		difficulty = "normal",
		previewStartSeconds = 30,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		sourceStatus = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		rightsProof = "https://create.roblox.com/store/asset/127192200172260",
		ownerScope = "Roblox Creator Store",
		loadPolicy = "on_song_start",
		-- A listening test: who owns it and whether it may ship is not checked yet.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "kpop-96",
		title = "K-pop 96",
		artist = "DistroKid (Creator Store)",
		audioAssetId = 131190816834402,
		sourceAudioFile = "https://create.roblox.com/store/asset/131190816834402",
		bpm = 130,
		durationSeconds = 206,
		difficulty = "normal",
		previewStartSeconds = 45,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		sourceStatus = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		rightsProof = "https://create.roblox.com/store/asset/131190816834402",
		ownerScope = "Roblox Creator Store",
		loadPolicy = "on_song_start",
		-- A listening test: who owns it and whether it may ship is not checked yet.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "under-the-starlight",
		title = "Under the Starlight",
		artist = "DistroKid (Creator Store)",
		audioAssetId = 101328005557095,
		sourceAudioFile = "https://create.roblox.com/store/asset/101328005557095",
		bpm = 130,
		durationSeconds = 217,
		difficulty = "normal",
		previewStartSeconds = 45,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		sourceStatus = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		rightsProof = "https://create.roblox.com/store/asset/101328005557095",
		ownerScope = "Roblox Creator Store",
		loadPolicy = "on_song_start",
		-- A listening test: who owns it and whether it may ship is not checked yet.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "intro-retro-kpop",
		title = "Intro-Retro KPOP",
		artist = "DistroKid (Creator Store)",
		audioAssetId = 139473515150944,
		sourceAudioFile = "https://create.roblox.com/store/asset/139473515150944",
		bpm = 121,
		durationSeconds = 148,
		difficulty = "normal",
		previewStartSeconds = 30,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		sourceStatus = RightsPolicy.AudioSourceStatuses.CreatorStorePermitted,
		rightsProof = "https://create.roblox.com/store/asset/139473515150944",
		ownerScope = "Roblox Creator Store",
		loadPolicy = "on_song_start",
		-- A listening test: who owns it and whether it may ship is not checked yet.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "first-playable-001",
		title = "First Playable Groove",
		artist = "Internal Prototype",
		audioAssetId = 85672641869803,
		sourceAudioFile = "assets/audio/first-playable-groove.wav",
		bpm = 120,
		durationSeconds = 30,
		difficulty = "normal",
		previewStartSeconds = 0,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = true,
		noAudioFallback = false,
	},
	{
		id = "neon-idol-rush",
		title = "Neon Idol Rush",
		artist = "Internal Prototype",
		audioAssetId = 133003406800219,
		sourceAudioFile = "assets/audio/neon-idol-rush.wav",
		bpm = 132,
		durationSeconds = 30,
		difficulty = "hard",
		previewStartSeconds = 0,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = true,
		noAudioFallback = false,
	},
	-- Original owned K-pop-style tracks for the generated charts (issues 037).
	-- audioAssetId is intentionally omitted: plays silent until the .wav is
	-- uploaded to Roblox via the Open Cloud audio workflow (then fill the id).
	{
		id = "auto-starlight-run",
		title = "Starlight Run (Auto)",
		artist = "Generated",
		audioAssetId = 112972536809713,
		sourceAudioFile = "assets/audio/auto-starlight-run.wav",
		bpm = 128,
		durationSeconds = 100,
		difficulty = "normal",
		previewStartSeconds = 0,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "auto-aurora-drive",
		title = "Aurora Drive (Auto)",
		artist = "Generated",
		audioAssetId = 134909259781382,
		sourceAudioFile = "assets/audio/auto-aurora-drive.wav",
		bpm = 120,
		durationSeconds = 95,
		difficulty = "normal",
		previewStartSeconds = 0,
		previewDurationSeconds = 8,
		rights = "repo_generated_owned_synthetic",
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "docs/audio-rights-and-chart-qa.md",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "nan-an-doraga",
		title = "Nan An Doraga",
		artist = "Suno",
		audioAssetId = 96151832167452,
		sourceAudioFile = "https://suno.com/song/3ec5002a-45a4-40ff-85b4-22b262c79cf6",
		bpm = 120,
		durationSeconds = 135,
		difficulty = "normal",
		previewStartSeconds = 24,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "https://suno.com/song/3ec5002a-45a4-40ff-85b4-22b262c79cf6",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		-- Made with Suno: it may ship only if it was made on a paid plan, which grants ownership.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "our-hearts",
		title = "Our Hearts",
		artist = "Derail Games",
		audioAssetId = 85582961767183,
		-- Re-timed onto one steady tempo; the Suno original drifts a beat late by the end.
		sourceAudioFile = "assets/audio/our-hearts.ogg",
		bpm = 120.98,
		durationSeconds = 183,
		difficulty = "normal",
		previewStartSeconds = 24,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "https://suno.com/song/24882f30-2cd0-48b1-8f90-9eeabfdb4617",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		-- Made with Suno: it may ship only if it was made on a paid plan, which grants ownership.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "just-a-little-static",
		title = "Just a Little Static",
		artist = "Derail Games",
		audioAssetId = 139155830357360,
		-- Re-timed onto one steady tempo where the Suno take wobbled.
		sourceAudioFile = "assets/audio/just-a-little-static.ogg",
		bpm = 98.524,
		durationSeconds = 139,
		difficulty = "normal",
		previewStartSeconds = 28,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "hackhsz/music-game suno/1-just-a-little-static, take 2 (Suno link not recorded)",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		-- Made with Suno: it may ship only if it was made on a paid plan, which grants ownership.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
	{
		id = "do-you-read-me",
		title = "Do You Read Me",
		artist = "Derail Games",
		audioAssetId = 127335160972777,
		-- Re-timed onto one steady tempo where the Suno take wobbled.
		sourceAudioFile = "assets/audio/do-you-read-me.ogg",
		bpm = 106.756,
		durationSeconds = 154,
		difficulty = "normal",
		previewStartSeconds = 40,
		previewDurationSeconds = 8,
		rights = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		sourceStatus = RightsPolicy.AudioSourceStatuses.GeneratedOwned,
		rightsProof = "hackhsz/music-game suno/3-do-you-read-me, take 1 (Suno link not recorded)",
		ownerScope = "Derail Games",
		loadPolicy = "on_song_start",
		-- Made with Suno: it may ship only if it was made on a paid plan, which grants ownership.
		publicReleaseReady = false,
		noAudioFallback = false,
	},
}

local CHART_SUFFIXES = { "-easy", "-normal", "-hard", "-expert" }
-- Lesson drills ("<song id>-tutorial-<n>") play their song's intro.
local LESSON_PATTERN = "^(.+)%-tutorial%-%d+$"

function AudioCatalog.getSong(songId: string)
	for _, song in AudioCatalog.Songs do
		if song.id == songId then
			return song
		end
	end

	local lessonSong = songId:match(LESSON_PATTERN)

	if lessonSong ~= nil then
		return AudioCatalog.getSong(lessonSong)
	end

	-- A song's other difficulties ("<song id>-hard") play the song's own audio.
	for _, suffix in CHART_SUFFIXES do
		if songId:sub(-#suffix) == suffix then
			return AudioCatalog.getSong(songId:sub(1, -#suffix - 1))
		end
	end

	return nil
end

function AudioCatalog.getMetadataCatalog()
	local songs = {}

	for _, song in AudioCatalog.Songs do
		table.insert(songs, {
			id = song.id,
			title = song.title,
			artist = song.artist,
			bpm = song.bpm,
			durationSeconds = song.durationSeconds,
			difficulty = song.difficulty,
			previewStartSeconds = song.previewStartSeconds,
			previewDurationSeconds = song.previewDurationSeconds,
			rights = song.rights,
			sourceStatus = song.sourceStatus,
			ownerScope = song.ownerScope,
			publicReleaseReady = song.publicReleaseReady == true,
			loadPolicy = song.loadPolicy,
			hasAudioAsset = song.audioAssetId ~= nil,
		})
	end

	return songs
end

function AudioCatalog.getRuntimeAudioAssetId(songId: string)
	local song = AudioCatalog.getSong(songId)

	if song == nil or song.noAudioFallback == true then
		return nil
	end

	return song.audioAssetId
end

function AudioCatalog.isPublicReleaseReady(songId: string): boolean
	local song = AudioCatalog.getSong(songId)

	if song == nil or song.publicReleaseReady ~= true then
		return false
	end

	local ok = RightsPolicy.validateAudioSong(song)

	return ok == true
end

return AudioCatalog
