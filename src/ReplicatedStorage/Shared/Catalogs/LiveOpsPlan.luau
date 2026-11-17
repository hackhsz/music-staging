local LiveOpsPlan = {}

local StageThemeCatalog = require(script.Parent.StageThemeCatalog)

LiveOpsPlan.Cadence = {
	SongsPerWeek = 1,
	ChallengeReset = "weekly",
	CosmeticDrop = "biweekly",
}

LiveOpsPlan.WeeklySongDrops = {
	{
		weekKey = "launch-week",
		featuredSongIds = { "candy-pop-warmup", "first-playable-001" },
		challenge = "Complete Candy Pop Warmup and unlock First Playable Groove.",
		rewardSoftCurrency = 50,
		status = "ready",
	},
	{
		weekKey = "week-2-hard-unlock",
		featuredSongIds = { "neon-idol-rush" },
		challenge = "Earn Rank B to unlock Neon Idol Rush.",
		rewardSoftCurrency = 75,
		status = "scheduled_after_playtest",
	},
}

LiveOpsPlan.SongDropWorkflow = {
	"Source or generate rights-cleared audio.",
	"Run scripts/generate-rhythm-map.py for a draft chart.",
	"Playtest timing with docs/timing-skill-gap-qa.md.",
	"Upload audio under Derail Games and fill AudioCatalog.audioAssetId.",
	"Add song metadata, unlock rule, and weekly drop entry.",
	"Run static checks, Rojo build, Studio smoke test, then deploy.",
}

LiveOpsPlan.Requirements = {
	"Song maps must be cheap to author.",
	"Audio rights must be cleared before release.",
	"Memory loading must be profiled before large song libraries.",
	"Stage skins must map to StageCatalog and keep active tiles readable on phone.",
}

LiveOpsPlan.StageSkinThemes = StageThemeCatalog.Themes

LiveOpsPlan.StageSkinPipeline = {
	"Select a StageThemeCatalog id and attach it to StageCatalog.themeIds.",
	"Generate or import pixel-art prop sheets, decals, and low-part-count meshes for that theme.",
	"Add tile VFX presets that preserve 5x5 grid contrast and respect PerformanceBudget.",
	"QA each theme on phone, tablet, and desktop before scheduling it as a liveops drop.",
}

return LiveOpsPlan
