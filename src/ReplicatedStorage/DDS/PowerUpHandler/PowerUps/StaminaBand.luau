local Config = require(script.Parent.Parent.Parent.Config)

return {
	DisplayName = "Stamina Band",
	Description = "Misses cost half the life.",
	Kind = "Consumable",
	Order = 6,
	ScoreMultiplier = 0.9,
	Conflicts = { "GlassHeels" },
	ConfigOverrides = { LIFE_MISS = Config.LIFE_MISS / 2 },
}
