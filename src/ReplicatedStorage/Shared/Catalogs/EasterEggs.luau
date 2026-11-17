local EasterEggs = {}

EasterEggs.Items = {
	{
		id = "backstage-sticker-001",
		displayName = "Backstage Pixel Sticker",
		rewardSoftCurrency = 5,
		location = "lobby_backstage_corner",
		repeatable = false,
		rewardId = "easter:backstage-sticker-001",
		hint = "Find the sticker tucked behind the idol stage speakers.",
	},
	{
		id = "daily-lightstick-glow",
		displayName = "Daily Lightstick Glow",
		rewardSoftCurrency = 50,
		location = "shop_counter_pickup",
		repeatable = true,
		cooldownSeconds = 86400,
		rewardId = "daily:lightstick-glow",
		hint = "Collect one daily glow from the shop counter.",
	},
	{
		id = "photo-spot-first-pose",
		displayName = "First Photo Spot Pose",
		rewardSoftCurrency = 5,
		location = "photo_spot",
		repeatable = false,
		rewardId = "easter:photo-spot-first-pose",
		hint = "Stand at the result photo spot after a run.",
	},
}

function EasterEggs.getItem(id: string)
	for _, item in EasterEggs.Items do
		if item.id == id or item.rewardId == id then
			return item
		end
	end

	return nil
end

return EasterEggs
