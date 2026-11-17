local Config = require(script.Parent.Parent.Parent.Config)

return {
	DisplayName = "Glass Heels",
	Description = "One Miss and you're out. +15% XP on clean runs.",
	Kind = "Mod",
	Order = 21,
	ScoreMultiplier = 1,
	XpMultiplier = 1.15,
	Conflicts = { "GrooveShield", "StaminaBand" },
	ConfigOverrides = { LIFE_MISS = -Config.LIFE_MAX },
}
