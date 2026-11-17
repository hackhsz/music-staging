--!strict
local RunService = game:GetService("RunService")

local UGCPolicy = require(script.Parent.Parent.Policies.UGCPolicy)

-- The Runway Market's stalls. A player claims a free stall for as long as they are
-- in the server and lists Roblox marketplace items they created; buyers pay through
-- Roblox's own prompt, so the game never takes payment itself.

export type Stall = {
	id: string,
	name: string,
	glyph: string,
}

local UGCCatalog = {}

UGCCatalog.MaxListings = 8
UGCCatalog.StationsFolder = "Stations"
UGCCatalog.AnchorName = "Anchor"
UGCCatalog.StallAttribute = "Stall"
-- The catalog's sale location that lets an item be bought inside this game.
UGCCatalog.SellableLocation = "ShopAndAllExperiences"
-- How many of a player's own items the MY ITEMS picker lists.
UGCCatalog.CreationsShown = 30
-- How close a player must stand to a stall's Anchor to claim it.
UGCCatalog.ClaimDistance = 24

UGCCatalog.Stalls = {
	{ id = "stall-1", name = "Stall 1", glyph = "👕" },
	{ id = "stall-2", name = "Stall 2", glyph = "👗" },
	{ id = "stall-3", name = "Stall 3", glyph = "🧢" },
	{ id = "stall-4", name = "Stall 4", glyph = "🎀" },
	{ id = "stall-5", name = "Stall 5", glyph = "🕶️" },
	{ id = "stall-6", name = "Stall 6", glyph = "✨" },
} :: { Stall }

-- Avatar items a stall may list, by Roblox AssetTypeId: classic clothing and the
-- accessory types. Gear, places, audio and the like are refused.
UGCCatalog.ListableAssetTypes = {
	[2] = "T-Shirt",
	[8] = "Hat",
	[11] = "Shirt",
	[12] = "Pants",
	[41] = "Hair",
	[42] = "Face Accessory",
	[43] = "Neck Accessory",
	[44] = "Shoulder Accessory",
	[45] = "Front Accessory",
	[46] = "Back Accessory",
	[47] = "Waist Accessory",
	[64] = "T-Shirt",
	[65] = "Shirt",
	[66] = "Pants",
	[67] = "Jacket",
	[68] = "Sweater",
	[69] = "Shorts",
	[70] = "Left Shoe",
	[71] = "Right Shoe",
	[72] = "Dress or Skirt",
}

-- What a refused request tells the player, by the reason the server gives.
UGCCatalog.ReasonText = {
	market_closed = "THE MARKET OPENS SOON",
	unknown_stall = "THAT STALL DOESN'T EXIST",
	stall_taken = "SOMEONE ALREADY HAS THIS STALL",
	already_have_stall = "YOU ALREADY HAVE A STALL",
	too_far = "WALK UP TO THE STALL TO CLAIM IT",
	no_stall = "CLAIM A STALL FIRST",
	stall_full = "YOUR STALL IS FULL",
	already_listed = "ALREADY ON YOUR STALL",
	not_listed = "THAT ITEM ISN'T ON YOUR STALL",
	off_sale = "OFF SALE - REMOVE IT OR PUT IT BACK ON SALE",
	not_on_stall = "THAT ITEM ISN'T ON A STALL ANY MORE",
	own_item = "THAT'S YOUR OWN ITEM",
	prompt_failed = "COULDN'T OPEN THE PURCHASE, TRY AGAIN",
	bad_asset_id = "PASTE AN ITEM ID FROM THE CATALOG",
	lookup_failed = "COULDN'T REACH ROBLOX, TRY AGAIN",
	not_avatar_item = "ONLY CLOTHING AND ACCESSORIES",
	not_for_sale = "THAT ITEM ISN'T ON SALE",
	not_creator = "YOU CAN ONLY LIST ITEMS YOU MADE",
	wrong_sale_location = "SET ITS SALE LOCATION TO MARKETPLACE AND ALL EXPERIENCES",
	no_creations = "NO ON-SALE CLOTHING OR ACCESSORIES BY YOU YET",
	claimed = "STALL CLAIMED - ADD YOUR ITEMS",
	released = "YOU LEFT YOUR STALL",
	listed = "ADDED - KEEP ITS SALE LOCATION ON ALL EXPERIENCES",
	unlisted = "REMOVED FROM YOUR STALL",
	sold = "SOLD!",
}

-- Studio playtests always open the market so it can be tried before the policy
-- review; live servers wait for UGCPolicy.
function UGCCatalog.isOpen(): boolean
	return UGCPolicy.Day0Status == "open" or RunService:IsStudio()
end

function UGCCatalog.getStall(stallId: string): Stall?
	for _, stall in UGCCatalog.Stalls do
		if stall.id == stallId then
			return stall
		end
	end

	return nil
end

function UGCCatalog.reasonText(reason: string): string
	return UGCCatalog.ReasonText[reason] or string.upper((reason:gsub("_", " ")))
end

return UGCCatalog
