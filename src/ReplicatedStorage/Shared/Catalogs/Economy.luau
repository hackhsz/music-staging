local Economy = {}

Economy.Currencies = {
	Soft = {
		id = "soft",
		displayName = "Beat Coins",
		serverAuthoritative = true,
	},
	Hard = {
		id = "hard",
		displayName = "Stage Gems",
		serverAuthoritative = true,
		enabled = false,
	},
}

Economy.Rewards = {
	SongComplete = 25,
	RankUp = 100,
	-- Paid once when the first-join lesson ends: enough for the cheapest wand.
	LessonGift = 150,
	PerfectStreak = 10,
	EasterEggPickup = 5,
	WeeklyChallenge = 100,
}

return Economy

