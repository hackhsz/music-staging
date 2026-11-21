local RemoteContract = {}

RemoteContract.FolderName = "Remotes"

RemoteContract.Events = {
	SongCatalog = {
		name = "SongCatalog",
		direction = "server_to_client",
		payload = {
			"songs",
		},
	},
	StartSong = {
		name = "StartSong",
		direction = "server_to_client",
		payload = {
			"songId",
			"artist",
			"difficulty",
			"serverStartTime",
			"startSharedTime",
			"performanceGoal",
			"slot",
			"slotCount",
			"boardOrigin",
			"rivalOrigin",
			"coreMode",
			"boardLayout",
			"items",
			"sections",
			"events",
			"lesson",
			"tutorial",
		},
	},
	-- The server sees a replicated position 140-300 ms late, which is far too
	-- coarse to grade a landing against a beat. The client reports when its own
	-- step landed on a server-synced clock and the server checks the claim is
	-- plausible before trusting it.
	ReportArrival = {
		name = "ReportArrival",
		direction = "client_to_server",
		payload = {
			"x",
			"y",
			"t",
			"p",
			"s",
		},
		rateLimitPerSecond = 20,
	},
	-- The highway mode's input: which lane was pressed, on the clock the server
	-- shares. There is no position behind it, so the press time is the claim.
	SubmitPress = {
		name = "SubmitPress",
		direction = "client_to_server",
		payload = {
			"lane",
			"t",
			"s",
		},
		rateLimitPerSecond = 30,
	},
	-- When a highway lane is let go, so a hold can be judged by how long it was held.
	SubmitRelease = {
		name = "SubmitRelease",
		direction = "client_to_server",
		payload = {
			"lane",
			"t",
			"s",
		},
		rateLimitPerSecond = 30,
	},
	-- A clap on the pad, timed on the shared clock like a landing report.
	SubmitClap = {
		name = "SubmitClap",
		direction = "client_to_server",
		payload = {
			"t",
			"s",
		},
		rateLimitPerSecond = 12,
	},
	SubmitHit = {
		name = "SubmitHit",
		direction = "client_to_server",
		payload = {
			"stepIndex",
			"clientHitTime",
		},
		rateLimitPerSecond = 12,
	},
	HitResult = {
		name = "HitResult",
		direction = "server_to_client",
		payload = {
			"stepIndex",
			"grade",
			"score",
			"combo",
			"hype",
			"fever",
			"deltaMs",
			"milestone",
			"multiplier",
			"shielded",
			"shieldReady",
			"reason",
		},
	},
	ItemResult = {
		name = "ItemResult",
		direction = "server_to_client",
		payload = {
			"itemIndex",
			"x",
			"y",
			"collected",
			"bonus",
			"score",
			"hype",
			"fever",
		},
	},
	RivalResult = {
		name = "RivalResult",
		direction = "server_to_client",
		payload = {
			"x",
			"y",
			"grade",
			"fever",
		},
	},
	SetAbilityLoadout = {
		name = "SetAbilityLoadout",
		direction = "client_to_server",
		payload = {
			"abilityIds",
		},
		rateLimitPerSecond = 2,
	},
	-- The charge bar, each slot's cooldown and what is running; pickup is the
	-- charged ability waiting on the floor, used names the ability just fired,
	-- or refused why it would not.
	AbilityState = {
		name = "AbilityState",
		direction = "server_to_client",
		payload = {
			"loadout",
			"charge",
			"maxCharge",
			"slots",
			"pickup",
			"used",
			"refused",
			"enabled",
		},
	},
	SetTimingOffset = {
		name = "SetTimingOffset",
		direction = "client_to_server",
		payload = {
			"offsetSeconds",
			"deviceDefault",
		},
		rateLimitPerSecond = 8,
	},
	-- One Settings window change (PlayerSettings), saved to the profile.
	SetPlayerSetting = {
		name = "SetPlayerSetting",
		direction = "client_to_server",
		payload = {
			"settingId",
			"value",
		},
		rateLimitPerSecond = 10,
	},
	TimingOffsetSync = {
		name = "TimingOffsetSync",
		direction = "server_to_client",
		payload = {
			"offsetSeconds",
			"calibrated",
		},
	},
	SongComplete = {
		name = "SongComplete",
		direction = "server_to_client",
		payload = {
			"summary",
		},
	},
	MultiplayerStatus = {
		name = "MultiplayerStatus",
		direction = "server_to_client",
		payload = {
			"modeId",
			"modeLabel",
			"matchState",
			"playerCount",
			"ownScore",
			"rivalName",
			"rivalUserId",
			"rivalScore",
			"leaderName",
			"leaderScore",
		},
	},
	RequestMode = {
		name = "RequestMode",
		direction = "client_to_server",
		payload = {
			"modeId",
		},
		rateLimitPerSecond = 2,
	},
	SetPlayMode = {
		name = "SetPlayMode",
		direction = "client_to_server",
		payload = {
			"modeId",
		},
		rateLimitPerSecond = 2,
	},
	StageSeen = {
		name = "StageSeen",
		direction = "client_to_server",
		payload = {
			"what",
			"rank",
		},
		rateLimitPerSecond = 2,
	},
	RequestParty = {
		name = "RequestParty",
		direction = "client_to_server",
		payload = {
			"code",
		},
		rateLimitPerSecond = 2,
	},
	RequestRematch = {
		name = "RequestRematch",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 2,
	},
	-- A hub place (Workspace.DanceHub): a station's prompt opens the song picker, and
	-- leaving the stage takes the player back to that station.
	OpenSongPicker = {
		name = "OpenSongPicker",
		direction = "server_to_client",
		payload = {},
	},
	ReturnToHub = {
		name = "ReturnToHub",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 1,
	},
	RequestRestart = {
		name = "RequestRestart",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 1,
	},
	RequestPause = {
		name = "RequestPause",
		direction = "client_to_server",
		payload = {
			"paused",
		},
		rateLimitPerSecond = 4,
	},
	PauseState = {
		name = "PauseState",
		direction = "server_to_client",
		payload = {
			"paused",
		},
	},
	RequestSong = {
		name = "RequestSong",
		direction = "client_to_server",
		payload = {
			"songId",
		},
		rateLimitPerSecond = 2,
	},
	EquipCosmetic = {
		name = "EquipCosmetic",
		direction = "client_to_server",
		payload = {
			"cosmeticId",
		},
		rateLimitPerSecond = 2,
	},
	UnequipCosmetic = {
		name = "UnequipCosmetic",
		direction = "client_to_server",
		payload = {
			"category",
		},
		rateLimitPerSecond = 2,
	},
	PurchaseCosmetic = {
		name = "PurchaseCosmetic",
		direction = "client_to_server",
		payload = {
			"cosmeticId",
		},
		rateLimitPerSecond = 2,
	},
	PurchaseSong = {
		name = "PurchaseSong",
		direction = "client_to_server",
		payload = {
			"songId",
		},
		rateLimitPerSecond = 2,
	},
	PurchaseResult = {
		name = "PurchaseResult",
		direction = "server_to_client",
		payload = {
			"ok",
			"kind",
			"itemId",
			"reason",
			"softCurrency",
		},
	},
	ProfileSync = {
		name = "ProfileSync",
		direction = "server_to_client",
		payload = {
			"softCurrency",
			"cosmetics",
			"equipped",
			"unlockedSongs",
			"achievements",
			"stats",
			"abilityLoadout",
			"claimedRewards",
			"rewardCooldowns",
			"timeRewards",
			"stagePass",
			"passes",
			"boughtOffers",
			"setRoad",
		},
	},
	ClaimPassTier = {
		name = "ClaimPassTier",
		direction = "client_to_server",
		payload = {
			"tier",
			"row",
		},
		rateLimitPerSecond = 3,
	},
	ClaimReward = {
		name = "ClaimReward",
		direction = "client_to_server",
		payload = {
			"rewardId",
		},
		rateLimitPerSecond = 2,
	},
	RedeemCode = {
		name = "RedeemCode",
		direction = "client_to_server",
		payload = {
			"code",
		},
		rateLimitPerSecond = 1,
	},
	ClaimStall = {
		name = "ClaimStall",
		direction = "client_to_server",
		payload = {
			"stallId",
		},
		rateLimitPerSecond = 1,
	},
	ReleaseStall = {
		name = "ReleaseStall",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 1,
	},
	AddListing = {
		name = "AddListing",
		direction = "client_to_server",
		payload = {
			"assetId",
		},
		rateLimitPerSecond = 1,
	},
	RemoveListing = {
		name = "RemoveListing",
		direction = "client_to_server",
		payload = {
			"assetId",
		},
		rateLimitPerSecond = 2,
	},
	BuyListing = {
		name = "BuyListing",
		direction = "client_to_server",
		payload = {
			"assetId",
		},
		rateLimitPerSecond = 1,
	},
	-- The player's own on-sale avatar items, for picking what to list.
	ListCreations = {
		name = "ListCreations",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 1,
	},
	CreationsList = {
		name = "CreationsList",
		direction = "server_to_client",
		payload = {
			"items",
		},
	},
	StallState = {
		name = "StallState",
		direction = "server_to_client",
		payload = {
			"open",
			"stalls",
		},
	},
	StallResult = {
		name = "StallResult",
		direction = "server_to_client",
		payload = {
			"ok",
			"reason",
			"assetId",
		},
	},
	TravelToIsland = {
		name = "TravelToIsland",
		direction = "client_to_server",
		payload = {
			"islandId",
		},
		rateLimitPerSecond = 1,
	},
	PlayEmote = {
		name = "PlayEmote",
		direction = "client_to_server",
		payload = {
			"emoteId",
		},
		rateLimitPerSecond = 2,
	},
	EmoteApproved = {
		name = "EmoteApproved",
		direction = "server_to_client",
		payload = {
			"emoteId",
		},
	},
	LeaderboardData = {
		name = "LeaderboardData",
		direction = "server_to_client",
		payload = {
			"boards",
		},
	},
	-- Where the player is in the first-join lesson and the steps after it, and where
	-- each tip's station stands (the client may not have streamed it in yet).
	OnboardingState = {
		name = "OnboardingState",
		direction = "server_to_client",
		payload = {
			"tutorialDone",
			"drillsPassed",
			"done",
			"stops",
		},
	},
	-- One lesson drill, which may only be the next one not yet passed or a retry.
	StartTutorial = {
		name = "StartTutorial",
		direction = "client_to_server",
		payload = {
			"drill",
		},
		rateLimitPerSecond = 1,
	},
	SkipTutorial = {
		name = "SkipTutorial",
		direction = "client_to_server",
		payload = {},
		rateLimitPerSecond = 1,
	},
	-- The timing check or a tip seen (OnboardingCatalog.isStep).
	CompleteOnboardingStep = {
		name = "CompleteOnboardingStep",
		direction = "client_to_server",
		payload = {
			"step",
		},
		rateLimitPerSecond = 2,
	},
	-- A funnel step only the client sees (FunnelCatalog marks which).
	ReportFunnelStep = {
		name = "ReportFunnelStep",
		direction = "client_to_server",
		payload = {
			"funnel",
			"step",
		},
		rateLimitPerSecond = 4,
	},
}

return RemoteContract
