local ShopCatalog = {}

-- Robux sales stay closed until the server grants what they sell: a ProcessReceipt
-- for products and the pass perks. Until then every Robux offer shows its price
-- but reads coming soon, whatever ids are filled in.
ShopCatalog.RobuxSalesOpen = false

-- Each section lists cosmetics (items) and Robux offers (offers), in shop order.
ShopCatalog.Sections = {
	{
		id = "featured",
		displayName = "Featured",
		offers = { "starter-pack", "vip", "double-coins" },
		items = {},
	},
	{
		id = "passes",
		displayName = "Game Passes",
		offers = { "vip", "double-coins", "double-xp", "season-pass", "song-pack-1" },
		items = {},
	},
	-- Everything worn or shown off: hand items, trails and auras, arenas, then moves.
	{
		id = "style",
		displayName = "Style",
		items = {
			"mint-wand-001",
			"sunset-wand-001",
			"trail-equalizer-001",
			"midnight-wand-001",
			"petal-trail-001",
			"gold-wand-001",
			"starlight-aura-001",
			"arena-neon-main",
			"arena-neon-candy",
			"arena-sakura-concert",
			"arena-school-idol",
			"arena-summer-stage",
			"arena-pixel-galaxy",
			"hype-dance-001",
			"spin-emote-001",
			"star-entrance-001",
			"spotlight-entrance-001",
			"crown-pose-001",
			"heart-pose-001",
		},
	},
}

-- Robux offers. kind "pass" is a game pass (passId); "bundle" is a developer
-- product (productId). oneTime offers can be bought once per player; a hero offer
-- gets the wide banner; wasRobux shows a struck-out old price and its discount;
-- badge is the corner ribbon. The perks are placeholders until each is designed
-- and built on the server.
ShopCatalog.Offers = {
	{
		id = "starter-pack",
		kind = "bundle",
		displayName = "Starter Pack",
		glyph = "🎁",
		rarity = "legendary",
		robux = 99,
		wasRobux = 250,
		oneTime = true,
		hero = true,
		includes = { "1,000 Beat Coins", "Sunset Star Wand", "Petal Trail", "Starter name tag" },
		productId = nil,
	},
	{
		id = "vip",
		kind = "pass",
		displayName = "VIP",
		glyph = "👑",
		rarity = "legendary",
		robux = 399,
		badge = "POPULAR",
		description = "VIP tag and name colour, VIP chat tag and an exclusive VIP emote.",
		includes = { "VIP tag and name colour", "VIP chat tag", "Exclusive VIP emote" },
		passId = nil,
	},
	{
		id = "double-coins",
		kind = "pass",
		displayName = "2x Beat Coins",
		glyph = "💰",
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
		rarity = "epic",
		robux = 199,
		description = "Double XP from every song, so you level up twice as fast.",
		includes = { "Double XP from every song" },
		passId = nil,
	},
	{
		id = "season-pass",
		kind = "pass",
		displayName = "Season Pass",
		glyph = "🎟️",
		rarity = "legendary",
		robux = 499,
		badge = "NEW",
		description = "A premium reward track every season, with a seasonal wand and moves.",
		includes = { "A premium reward track each season", "Seasonal wand and moves" },
		passId = nil,
	},
	{
		id = "song-pack-1",
		kind = "bundle",
		displayName = "Song Pack",
		glyph = "💿",
		rarity = "rare",
		robux = 149,
		oneTime = true,
		description = "Unlock the next pack of tracks right away.",
		includes = { "Unlock the next pack of tracks early" },
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
	{ id = "coins-small", displayName = "Handful of Coins", glyph = "💵", rarity = "common", coins = 500, robux = 49, productId = nil },
	{
		id = "coins-medium",
		displayName = "Bag of Coins",
		glyph = "💰",
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
		rarity = "legendary",
		coins = 10000,
		bonus = "+55% BONUS",
		badge = "BEST VALUE",
		robux = 649,
		productId = nil,
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
