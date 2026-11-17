local Board = require(script.Parent.Board)

local StageBlockout = {}

StageBlockout.ArtDirection = "dark_violet_one_accent"

StageBlockout.Zones = {
	DanceFloor = {
		id = "dance_floor",
		displayName = "5x5 Dance Floor",
		center = Board.Origin,
		size = Vector3.new(Board.Columns * Board.TileSize, 1, Board.Rows * Board.TileSize),
	},
	MainStage = {
		id = "main_stage",
		displayName = "Main Stage",
		center = Vector3.new(0, 1.5, -44),
		size = Vector3.new(64, 3, 10),
	},
	LedWall = {
		id = "led_wall",
		displayName = "LED Wall",
		center = Vector3.new(0, 10.5, -50.5),
		size = Vector3.new(84, 15, 1),
	},
	Crowd = {
		id = "crowd",
		displayName = "Audience Silhouettes",
		center = Vector3.new(0, 0, 11),
		size = Vector3.new(96, 8, 24),
	},
	LeaderboardScreen = {
		id = "leaderboard_screen",
		displayName = "Leaderboard Screen",
		center = Vector3.new(-46, 8.5, -24),
		size = Vector3.new(30, 15, 1),
	},
	HowToPlayScreen = {
		id = "how_to_play_screen",
		displayName = "How To Play Screen",
		center = Vector3.new(46, 8.5, -24),
		size = Vector3.new(30, 15, 1),
	},
}

StageBlockout.ReadabilityRules = {
	"The dance floor is the brightest thing in frame during gameplay.",
	"Audience silhouettes stay clear of the floor and never overlap an active tile.",
	"Everything is axis-aligned: no diagonal beams, slopes or tilted props.",
	"Pink is the one accent and gold is for highlights; Neon is for trim, bars and lights only.",
}

return StageBlockout
