local AnimationPacks = require(script.Parent.AnimationPacks)

local CosmeticsCatalog = {}

-- Unlock fields drive the server purchase flow:
-- unlock = "soft_currency" items are buyable for `price` Beat Coins;
-- achievement-gated items carry `unlockAchievementId` and are granted by
-- RewardService (the shop can only claim them once the achievement is done);
-- `requirementText` is the player-facing unlock hint for shop and song UI.
-- `glyph` is the placeholder icon; an uploaded `icon` image replaces it.
-- unlock = "coming_soon" items are listed in the shop but cannot be had yet;
-- unlock = "group" items come with the group reward (SocialRewards).
-- category = "arena" items are whole environments around the dance floor: the
-- model named after the id in ReplicatedStorage.Arenas, or Workspace.Arena for
-- the default. `robux` on a coming-soon arena is the premium price it will sell at.
CosmeticsCatalog.Rarities = {
	common = { displayName = "Common", color = Color3.fromRGB(200, 205, 220) },
	rare = { displayName = "Rare", color = Color3.fromRGB(90, 200, 255) },
	epic = { displayName = "Epic", color = Color3.fromRGB(200, 120, 255) },
	legendary = { displayName = "Legendary", color = Color3.fromRGB(255, 200, 87) },
}

CosmeticsCatalog.Items = {
	{
		id = "pixel-sneakers-001",
		rarity = "rare",
		glyph = "👟",
		icon = "rbxassetid://99333117585812",
		category = "shoes",
		displayName = "Neon Pixel Sneakers",
		unlock = "song_achievement",
		unlockAchievementId = "full-combo-metronome",
		requirementText = "FULL COMBO 8 IN A ROW",
		pixelArtRequired = true,
	},
	{
		id = "idol-jacket-001",
		rarity = "common",
		glyph = "🧥",
		icon = "rbxassetid://96026359892176",
		category = "jacket",
		displayName = "Debut Pixel Jacket",
		unlock = "first_song_complete",
		unlockAchievementId = "first-show-complete",
		requirementText = "COMPLETE YOUR FIRST SHOW",
		pixelArtRequired = true,
	},
	{
		id = "star-mic-001",
		rarity = "rare",
		glyph = "🎤",
		icon = "rbxassetid://114496832190266",
		category = "microphone",
		displayName = "Star Practice Mic",
		unlock = "rank_b_or_better",
		unlockAchievementId = "rank-b-practice",
		requirementText = "EARN RANK B ON ANY TRACK",
		pixelArtRequired = true,
	},
	{
		id = "lemon-lightstick-001",
		rarity = "common",
		glyph = "🎇",
		icon = "rbxassetid://103306179631517",
		category = "glow_stick",
		displayName = "Lemon Lightstick",
		unlock = "starter",
		requirementText = "STARTER GIFT",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "candy-hairpin-001",
		rarity = "rare",
		glyph = "🎀",
		icon = "rbxassetid://118256522459835",
		category = "hair_accessory",
		displayName = "Candy Pixel Hairpin",
		unlock = "perfect_starter",
		unlockAchievementId = "first-ten-perfects",
		requirementText = "HIT 10 PERFECTS",
		pixelArtRequired = true,
	},
	{
		id = "trail-equalizer-001",
		rarity = "epic",
		glyph = "🎶",
		icon = "rbxassetid://74188477340816",
		category = "particle_trail",
		displayName = "Equalizer Trail",
		unlock = "soft_currency",
		price = 250,
		requirementText = "250 BEAT COINS",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "stage-aura-001",
		rarity = "legendary",
		glyph = "🌟",
		icon = "rbxassetid://72671950596816",
		category = "aura",
		displayName = "Tiny Stage Aura",
		unlock = "rank_a_or_better",
		unlockAchievementId = "rank-a-spotlight",
		requirementText = "EARN RANK A ON ANY TRACK",
		pixelArtRequired = true,
		readabilityRule = "edge_only",
	},
	{
		id = "mint-wand-001",
		rarity = "common",
		glyph = "✨",
		icon = "rbxassetid://88346308866310",
		category = "glow_stick",
		displayName = "Mint Bubble Wand",
		unlock = "soft_currency",
		price = 150,
		requirementText = "150 BEAT COINS",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "sunset-wand-001",
		rarity = "rare",
		glyph = "✨",
		icon = "rbxassetid://113521260792395",
		category = "glow_stick",
		displayName = "Sunset Star Wand",
		unlock = "soft_currency",
		price = 400,
		requirementText = "400 BEAT COINS",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "midnight-wand-001",
		rarity = "epic",
		glyph = "✨",
		icon = "rbxassetid://112873657749069",
		category = "glow_stick",
		displayName = "Midnight Moon Wand",
		unlock = "soft_currency",
		price = 900,
		requirementText = "900 BEAT COINS",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "petal-trail-001",
		rarity = "epic",
		glyph = "🌸",
		icon = "rbxassetid://135413103981760",
		category = "particle_trail",
		displayName = "Petal Trail",
		unlock = "soft_currency",
		price = 1200,
		requirementText = "1200 BEAT COINS",
		colors = { Color3.fromRGB(255, 190, 220), Color3.fromRGB(255, 120, 190) },
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "gold-wand-001",
		rarity = "legendary",
		glyph = "✨",
		icon = "rbxassetid://130184695356670",
		category = "glow_stick",
		displayName = "Golden Star Wand",
		unlock = "soft_currency",
		price = 2500,
		requirementText = "2500 BEAT COINS",
		pixelArtRequired = true,
		readabilityRule = "must_not_cover_active_tiles",
	},
	{
		id = "starlight-aura-001",
		rarity = "legendary",
		glyph = "💫",
		icon = "rbxassetid://90682838810570",
		category = "aura",
		displayName = "Starlight Aura",
		unlock = "soft_currency",
		price = 3000,
		requirementText = "3000 BEAT COINS",
		colors = { Color3.fromRGB(150, 200, 255) },
		pixelArtRequired = true,
		readabilityRule = "edge_only",
	},
	{
		id = "group-star-aura-001",
		rarity = "epic",
		glyph = "💜",
		icon = "rbxassetid://97736630334345",
		category = "aura",
		displayName = "Group Star Aura",
		unlock = "group",
		requirementText = "JOIN THE GROUP",
		colors = { Color3.fromRGB(200, 120, 255) },
		pixelArtRequired = true,
		readabilityRule = "edge_only",
	},
	{
		id = "hype-dance-001",
		rarity = "common",
		glyph = "💃",
		icon = "rbxassetid://131184109522317",
		category = "emote",
		displayName = "Hype Dance",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "spin-emote-001",
		rarity = "rare",
		glyph = "🌀",
		icon = "rbxassetid://113268470442691",
		category = "emote",
		displayName = "Spotlight Spin",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "star-entrance-001",
		rarity = "epic",
		glyph = "🌠",
		icon = "rbxassetid://109573704343699",
		category = "entrance",
		displayName = "Shooting Star Entrance",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "spotlight-entrance-001",
		rarity = "legendary",
		glyph = "🔦",
		icon = "rbxassetid://73214271275618",
		category = "entrance",
		displayName = "Spotlight Entrance",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "crown-pose-001",
		rarity = "epic",
		glyph = "👑",
		icon = "rbxassetid://104481267524654",
		category = "victory_pose",
		displayName = "Crown Pose",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "heart-pose-001",
		rarity = "rare",
		glyph = "💖",
		icon = "rbxassetid://138442823974395",
		category = "victory_pose",
		displayName = "Heart Pose",
		unlock = "coming_soon",
		requirementText = "COMING SOON",
	},
	{
		id = "arena-neon-main",
		rarity = "common",
		glyph = "🏟️",
		icon = "rbxassetid://82700587963454",
		category = "arena",
		displayName = "Neon Main Stage",
		unlock = "starter",
		requirementText = "FREE",
	},
	{
		id = "arena-sakura-concert",
		rarity = "epic",
		glyph = "🌸",
		icon = "rbxassetid://128789519738268",
		category = "arena",
		displayName = "Sakura Concert",
		unlock = "soft_currency",
		price = 1500,
		requirementText = "1500 BEAT COINS",
	},
	{
		id = "arena-pixel-galaxy",
		rarity = "legendary",
		glyph = "🌌",
		icon = "rbxassetid://83406356094131",
		category = "arena",
		displayName = "Pixel Galaxy",
		unlock = "coming_soon",
		robux = 199,
		requirementText = "PREMIUM - 199 ROBUX - SOON",
	},
	{
		id = "arena-neon-candy",
		rarity = "rare",
		glyph = "🍭",
		icon = "rbxassetid://77907284015051",
		category = "arena",
		displayName = "Neon Candy Practice",
		unlock = "soft_currency",
		price = 800,
		requirementText = "800 BEAT COINS",
	},
	{
		id = "arena-school-idol",
		rarity = "epic",
		glyph = "🏫",
		icon = "rbxassetid://135962705358174",
		category = "arena",
		displayName = "School Idol Studio",
		unlock = "soft_currency",
		price = 2500,
		requirementText = "2500 BEAT COINS",
	},
	{
		id = "arena-summer-stage",
		rarity = "legendary",
		glyph = "🏖️",
		icon = "rbxassetid://94646640295873",
		category = "arena",
		displayName = "Summer Pop Stage",
		unlock = "coming_soon",
		robux = 149,
		requirementText = "PREMIUM - 149 ROBUX - SOON",
	},
}

for _, item in AnimationPacks.Items do
	table.insert(CosmeticsCatalog.Items, item)
end

-- What the shop and wardrobe call a category, where its id does not read well.
CosmeticsCatalog.CategoryNames = {
	glow_stick = "Hand Item",
}

CosmeticsCatalog.DefaultArenaId = "arena-neon-main"
-- The arena a player's client draws, set by the server on the Player.
CosmeticsCatalog.ArenaAttribute = "StageArena"

-- The Wardrobe window's tabs, each a set of categories.
-- Shoes, jackets, mics and hair clips show under All only.
CosmeticsCatalog.WardrobeTabs = {
	{ id = "all", name = "All" },
	{ id = "outfit", name = "Outfit", categories = { "glow_stick", "particle_trail", "aura" } },
	{ id = "moves", name = "Moves", categories = { "emote", "entrance", "victory_pose", AnimationPacks.Category } },
	{ id = "arenas", name = "Arenas", categories = { "arena" } },
}

function CosmeticsCatalog.categoryName(category: string): string
	return CosmeticsCatalog.CategoryNames[category] or (category:gsub("_", " "))
end

function CosmeticsCatalog.getItem(cosmeticId: string)
	for _, item in CosmeticsCatalog.Items do
		if item.id == cosmeticId then
			return item
		end
	end

	return nil
end

return CosmeticsCatalog
