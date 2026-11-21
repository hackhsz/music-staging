local AnimationPacks = require(script.Parent.AnimationPacks)

local ShopCatalog = {}

-- PurchaseService grants every product and pass perk below, so an offer sells as soon
-- as its passId or productId is filled in. An offer marked comingSoon has no grant yet.
ShopCatalog.RobuxSalesOpen = true

-- Each section lists cosmetics (items) and Robux offers (offers), in shop order.
ShopCatalog.Sections = {
	{
		id = "featured",
		displayName = "Featured",
		setRoad = true,
		offers = { "stage-pass", "starter-pack", "double-coins", "double-xp" },
		items = {},
	},
	{
		id = "outfits",
		displayName = "Outfits",
		items = {
			"mint-wand-001",
			"sunset-wand-001",
			"midnight-wand-001",
			"gold-wand-001",
			"trail-equalizer-001",
			"petal-trail-001",
			"starlight-aura-001",
		},
	},
	{
		id = "emotes",
		displayName = "Emotes",
		items = {
			"hype-dance-001",
			"spin-emote-001",
			"star-entrance-001",
			"spotlight-entrance-001",
			"crown-pose-001",
			"heart-pose-001",
			table.unpack(AnimationPacks.ids()),
		},
	},
	{
		id = "stages",
		displayName = "Stages",
		items = {
			"arena-neon-main",
			"arena-neon-candy",
			"arena-sakura-concert",
			"arena-school-idol",
			"arena-summer-stage",
			"arena-pixel-galaxy",
		},
	},
	{
		id = "passes",
		displayName = "Passes",
		offers = { "stage-pass", "double-coins", "double-xp", "vip", "song-pack-1" },
		items = {},
	},
}

-- Robux offers. kind "pass" is a game pass (passId); "bundle" is a developer
-- product (productId). oneTime offers can be bought once per player; a hero offer
-- gets the wide banner; wasRobux shows a struck-out old price and its discount;
-- badge is the corner ribbon. grants is what PurchaseService hands over for a product;
-- a pass's perk is applied where it pays out (RewardService for 2x coins and XP).
ShopCatalog.Offers = {
	{
		id = "starter-pack",
		kind = "bundle",
		displayName = "Starter Pack",
		glyph = "🎁",
		icon = "rbxassetid://70793384037603",
		rarity = "legendary",
		robux = 99,
		wasRobux = 250,
		oneTime = true,
		includes = { "1,000 Beat Coins", "Sunset Star Wand", "Petal Trail" },
		grants = { coins = 1000, cosmetics = { "sunset-wand-001", "petal-trail-001" } },
		productId = nil,
	},
	{
		id = "vip",
		kind = "pass",
		displayName = "VIP",
		glyph = "👑",
		icon = "rbxassetid://127779038184866",
		rarity = "legendary",
		robux = 399,
		badge = "POPULAR",
		description = "VIP tag and name colour, VIP chat tag and an exclusive VIP emote.",
		includes = { "VIP tag and name colour", "VIP chat tag", "Exclusive VIP emote" },
		comingSoon = true,
		passId = nil,
	},
	{
		id = "double-coins",
		kind = "pass",
		displayName = "2x Beat Coins",
		glyph = "💰",
		icon = "rbxassetid://115289050254455",
		rarity = "epic",
		robux = 249,
		badge = "BEST SELLER",
		description = "Double Beat Coins from every song you play.",
		includes = { "Double Beat Coins from every song" },
		passId = nil,
	},
	{
		id = "double-xp",
		kind = "pass",
		displayName = "2x XP",
		glyph = "⚡",
		icon = "rbxassetid://106782623695831",
		rarity = "epic",
		robux = 199,
		description = "Double XP from every song, so you level up twice as fast.",
		includes = { "Double XP from every song" },
		passId = nil,
	},
	{
		id = "stage-pass",
		kind = "bundle",
		displayName = "Stage Pass",
		glyph = "🎟️",
		icon = "rbxassetid://116786250829050",
		rarity = "legendary",
		robux = 99,
		badge = "NEW",
		description = "Blooming Sky, four weeks. Opens the pass row of the Stage Pass.",
		includes = { "Every pass reward this season" },
		opensPass = true,
		grants = { stagePass = true },
		productId = nil,
	},
	{
		id = "song-pack-1",
		kind = "bundle",
		displayName = "Song Pack",
		glyph = "💿",
		icon = "rbxassetid://78973228204637",
		rarity = "rare",
		robux = 149,
		oneTime = true,
		description = "Unlock the next pack of tracks right away.",
		includes = { "Unlock the next pack of tracks early" },
		comingSoon = true,
		productId = nil,
	},
}

-- Locked tracks render as an extra shop section; entries come from the
-- per-player SongCatalog payload (SongCollection owns the unlock rules).
ShopCatalog.TrackSection = {
	id = "track_unlocks",
	displayName = "Track Unlocks",
}

-- Beat Coin packs for Robux, developer products like the bundles above.
ShopCatalog.CoinPackSection = {
	id = "coin_packs",
	displayName = "Beat Coin Packs",
}

ShopCatalog.CoinPacks = {
	{ id = "coins-small", displayName = "Handful of Coins", glyph = "💵", icon = "rbxassetid://90381087302472", rarity = "common", coins = 500, robux = 49, productId = nil },
	{
		id = "coins-medium",
		displayName = "Bag of Coins",
		glyph = "💰",
		icon = "rbxassetid://121968853135819",
		rarity = "rare",
		coins = 1500,
		bonus = "+15% BONUS",
		robux = 129,
		productId = nil,
	},
	{
		id = "coins-large",
		displayName = "Chest of Coins",
		glyph = "🧰",
		icon = "rbxassetid://73967585210718",
		rarity = "epic",
		coins = 4000,
		bonus = "+35% BONUS",
		badge = "MOST POPULAR",
		robux = 299,
		productId = nil,
	},
	{
		id = "coins-huge",
		displayName = "Vault of Coins",
		glyph = "🏦",
		icon = "rbxassetid://111904717942330",
		rarity = "legendary",
		coins = 10000,
		bonus = "+55% BONUS",
		badge = "BEST VALUE",
		robux = 649,
		productId = nil,
	},
}

-- The Stage Set Road: a fixed set of looks bought in order, one step at a time, the first
-- free. No random items (MonetizationPolicy keeps paid random rewards off).
ShopCatalog.SetRoad = {
	id = "set-road",
	season = "blooming-sky",
	displayName = "Stage Set Road",
	subtitle = "Blooming Sky",
	icon = "rbxassetid://118256522459835",
	freeRewardId = "set-road-free",
	-- A step whose look is already owned pays these coins instead.
	ownedRefund = 100,
	steps = {
		{ cosmeticId = "candy-hairpin-001", robux = 0 },
		{ cosmeticId = "petal-trail-001", robux = 49, productId = nil },
		{ cosmeticId = "sunset-wand-001", robux = 79, productId = nil },
		{ cosmeticId = "star-entrance-001", robux = 99, productId = nil },
		{ cosmeticId = "starlight-aura-001", robux = 149, productId = nil },
		{ cosmeticId = "gold-wand-001", robux = 249, productId = nil },
	},
}

function ShopCatalog.getOffer(offerId: string)
	for _, offer in ShopCatalog.Offers do
		if offer.id == offerId then
			return offer
		end
	end

	return nil
end

return ShopCatalog
