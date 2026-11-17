local StageThemeCatalog = {}

StageThemeCatalog.Themes = {
	{
		id = "sakura-concert",
		displayName = "Sakura Concert Stage",
		palette = { "sakura pink", "blossom blush", "warm cream", "plum night", "soft gold" },
		props = { "cherry-blossom trees", "petal drift emitters", "paper lantern rows", "torii photo gate" },
		tileVfx = { "petal perfect burst", "blossom combo trail", "soft pink miss puff" },
		rewards = { "sakura hairpin", "petal lightstick", "blossom tile trail" },
		riskNotes = {
			"Keep the floor base dark so pink blossom decor never hides the active tile.",
			"Original stylized blossoms only; no real brand, idol, or licensed motifs.",
		},
		stageCatalogId = "neon-pixel-main",
		assetPipeline = "Recolor floor frame + stage dressing to the blossom palette first, then add capped petal-drift particle emitters within the performance budget.",
	},
	{
		id = "neon-candy",
		displayName = "Neon Candy Practice",
		palette = { "hot pink", "candy blue", "lemon yellow", "mint green", "cream white" },
		props = { "toy speakers", "cloud mirrors", "heart vanity seats", "wrapped-candy LED pixels" },
		tileVfx = { "sugar-sparkle glow", "pink miss puff", "mint perfect burst" },
		rewards = { "candy hairpin", "lemon lightstick", "bubble tile trail" },
		riskNotes = {
			"Keep floor contrast high so pink decorations do not hide active tiles.",
			"Avoid candy brands, real idol likenesses, or licensed character silhouettes.",
		},
		stageCatalogId = "neon-pixel-main",
		assetPipeline = "Generate pixel props as modular decals/meshes, then test neon material budgets before enabling particles.",
	},
	{
		id = "school-idol",
		displayName = "School Idol Studio",
		palette = { "chalk white", "clubroom teal", "uniform navy", "sunset coral", "gold star" },
		props = { "club bulletin board", "practice mirrors", "shoe lockers", "star curtains" },
		tileVfx = { "chalk beat rings", "star-note confetti", "desk-sticker combo trail" },
		rewards = { "club badge title", "uniform jacket", "star notebook aura" },
		riskNotes = {
			"Make the setting fictional and age-neutral.",
			"Do not use real school logos, uniforms, or group branding.",
		},
		stageCatalogId = "neon-pixel-main",
		assetPipeline = "Start with prop recolors, then add a single wall decal sheet and one low-poly locker mesh.",
	},
	{
		id = "summer-stage",
		displayName = "Summer Pop Stage",
		palette = { "pool cyan", "sun yellow", "watermelon pink", "white sand", "night teal" },
		props = { "floatie speakers", "boardwalk runway", "festival lights", "juice stand shop" },
		tileVfx = { "splash perfect ring", "sun flare fever", "water ripple slide path" },
		rewards = { "sun visor", "floatie backpack", "wave trail" },
		riskNotes = {
			"Keep water/floor materials visually distinct for mobile readability.",
			"Limit animated water planes; prefer static pixel patterns for performance.",
		},
		stageCatalogId = "neon-pixel-main",
		assetPipeline = "Reuse lobby kiosk sockets, swap palette/decals, and cap animated splash particles to the performance budget.",
	},
	{
		id = "pixel-galaxy",
		displayName = "Pixel Galaxy Arena",
		palette = { "deep violet", "star white", "laser cyan", "comet magenta", "moon silver" },
		props = { "star gate", "planet speakers", "constellation LED wall", "moon photo spot" },
		tileVfx = { "comet tile glow", "starfield fever pulse", "meteor miss crackle" },
		rewards = { "galaxy shoes", "moon mic", "constellation aura" },
		riskNotes = {
			"Avoid making the stage too dark; active tiles must stay readable.",
			"Use looping pixel cards instead of heavy full-screen particle fields.",
		},
		stageCatalogId = "neon-pixel-main",
		assetPipeline = "Generate star decals first, then ship a low-part-count prop pack for gates and planet speakers.",
	},
}

function StageThemeCatalog.getTheme(id: string)
	for _, theme in StageThemeCatalog.Themes do
		if theme.id == id then
			return theme
		end
	end

	return nil
end

return StageThemeCatalog
