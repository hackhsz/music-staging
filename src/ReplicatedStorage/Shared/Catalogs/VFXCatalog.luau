local VFXCatalog = {}

VFXCatalog.ArtDirection = "kpop_lowpoly_pastel"

VFXCatalog.Effects = {
	Perfect = {
		id = "gold-sparkle-burst",
		colors = { Color3.fromRGB(255, 211, 92), Color3.fromRGB(255, 252, 255) },
		readability = "short_lived",
	},
	Great = {
		id = "green-petal-pop",
		colors = { Color3.fromRGB(106, 255, 128), Color3.fromRGB(214, 255, 224) },
		readability = "short_lived",
	},
	Good = {
		id = "cyan-soft-puff",
		colors = { Color3.fromRGB(86, 222, 255), Color3.fromRGB(199, 226, 255) },
		readability = "short_lived",
	},
	Bad = {
		id = "dim-nearmiss-shake",
		colors = { Color3.fromRGB(168, 132, 150) },
		readability = "edge_only",
	},
	Combo = {
		id = "combo-spark",
		colors = { Color3.fromRGB(255, 79, 178), Color3.fromRGB(86, 222, 255) },
		readability = "edge_only",
	},
	ComboBreak = {
		id = "combo-break-flash",
		colors = { Color3.fromRGB(255, 76, 91) },
		readability = "short_lived",
	},
	Fever = {
		id = "fever-aura-spotlight",
		colors = { Color3.fromRGB(255, 211, 92), Color3.fromRGB(255, 79, 178), Color3.fromRGB(86, 222, 255) },
		readability = "short_score_bonus_window",
	},
	SongEnd = {
		id = "confetti-finale",
		colors = { Color3.fromRGB(255, 79, 178), Color3.fromRGB(255, 211, 92), Color3.fromRGB(86, 222, 255), Color3.fromRGB(173, 116, 255) },
		readability = "after_gameplay_only",
	},
}

VFXCatalog.EventMatrix = {
	Perfect = {
		effect = "Perfect",
		intensity = 1,
		readabilityRule = "tile burst under 0.6s; never covers next prompt",
	},
	Great = {
		effect = "Great",
		intensity = 1,
		readabilityRule = "smaller burst + tile flash under 0.5s",
	},
	Good = {
		effect = "Good",
		intensity = 1,
		readabilityRule = "soft puff under 0.45s",
	},
	Bad = {
		effect = "Bad",
		intensity = 1,
		readabilityRule = "dim number + tiny near-miss shake; no burst",
	},
	Miss = {
		effect = "ComboBreak",
		intensity = 1,
		readabilityRule = "red flash only; no lingering particles",
	},
	ComboMilestone = {
		effect = "Combo",
		intensity = 2,
		trigger = "every_10_combo",
		readabilityRule = "edge-only sparkle away from active tile",
	},
	ComboBreak = {
		effect = "ComboBreak",
		intensity = 2,
		readabilityRule = "short feedback, no board occlusion",
	},
	FeverStart = {
		effect = "Fever",
		intensity = 3,
		readabilityRule = "corner aura only during scoring window",
	},
	CoopSync = {
		effect = "Combo",
		intensity = 2,
		trigger = "syncBonus increases",
		readabilityRule = "center-stage pulse, not on target tile",
	},
	CrowdHype = {
		effect = "Fever",
		intensity = 2,
		trigger = "teamHype or solo hype crosses threshold",
		readabilityRule = "audience/stage edges only",
	},
	SongClear = {
		effect = "SongEnd",
		intensity = 4,
		readabilityRule = "after gameplay only",
	},
}

VFXCatalog.PerformancePolicy = {
	LowEndMode = "disable_combo_milestone_and_reduce_confetti",
	MaxGameplayBurstParticles = 30,
	MaxPersistentEmitters = 8,
	AllowReducedVfxToggle = true,
}

return VFXCatalog
