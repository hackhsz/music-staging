local function course(a: string, b: string, c: string)
	return {
		{ songId = "combo-fever", difficulty = a },
		{ songId = "combo-fever", difficulty = b },
		{ songId = "combo-fever", difficulty = c },
	}
end

return {
	{ name = "Trainee I", songs = course("easy", "easy", "easy"), minAccuracy = 70, maxMiss = 20, itemSlots = 1, reward = "TraineeAura" },
	{ name = "Trainee II", songs = course("easy", "easy", "normal"), minAccuracy = 72, maxMiss = 18, reward = "TraineeAuraPlus" },
	{ name = "Trainee III", songs = course("easy", "normal", "normal"), minAccuracy = 75, maxMiss = 16, itemSlots = 2, reward = "TraineeShoes" },
	{ name = "Rising Star I", songs = course("normal", "normal", "normal"), minAccuracy = 78, maxMiss = 14, reward = "RisingStarShoes" },
	{ name = "Rising Star II", songs = course("normal", "normal", "hard"), minAccuracy = 80, maxMiss = 12, itemSlots = 3, reward = "RisingStarNameplate" },
	{ name = "Rising Star III", songs = course("normal", "hard", "hard"), minAccuracy = 82, maxMiss = 10, reward = "AnimatedNameplate" },
	{ name = "Idol I", songs = course("hard", "hard", "hard"), minAccuracy = 85, maxMiss = 10, reward = "IdolTrail" },
	{ name = "Idol II", songs = course("hard", "hard", "hard"), minAccuracy = 87, maxMiss = 8, reward = "IdolShoes" },
	{ name = "Superstar", songs = course("hard", "hard", "hard"), minAccuracy = 90, maxMiss = 6, reward = "SuperstarEntrance" },
	{ name = "Legend", songs = course("hard", "hard", "hard"), minAccuracy = 93, maxMiss = 4, reward = "LegendCrownAura" },
}
