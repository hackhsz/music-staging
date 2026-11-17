local LeaderboardConfig = {}

LeaderboardConfig.Boards = {
	{
		id = "weekly_perfect_beats",
		displayName = "Weekly Perfect Beats",
		period = "weekly",
		metric = "perfects",
		showAvatar = true,
	},
	{
		id = "all_time_high_score",
		displayName = "All-Time High Score",
		period = "all_time",
		metric = "score",
		showAvatar = true,
	},
	{
		id = "all_time_level",
		displayName = "Top Level",
		period = "all_time",
		metric = "xp",
		showAvatar = true,
	},
}

return LeaderboardConfig

