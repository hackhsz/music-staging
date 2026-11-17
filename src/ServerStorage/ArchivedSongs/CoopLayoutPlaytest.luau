local CoopLayoutPlaytest = {}

CoopLayoutPlaytest.DefaultRecommendedModeId = "coop_separate"

CoopLayoutPlaytest.Variants = {
	{
		id = "coop_separate",
		label = "Dual 5x5 Floors",
		modeId = "coop_separate",
		board = "two_5x5",
		hypothesis = "Best readability and lowest collision risk for first launch.",
		successCriteria = {
			"Both players understand their own lane within 10 seconds.",
			"Team score feels collaborative despite separated boards.",
			"Camera remains readable on desktop and phone.",
			"Miss recovery does not depend on the other player's position.",
		},
		risks = {
			"Can feel less social if players never cross paths.",
			"Requires stronger shared VFX/audio feedback to feel like a duet.",
		},
	},
	{
		id = "coop_shared",
		label = "Shared 5x10 Floor",
		modeId = "coop_shared",
		board = "shared_5x10",
		hypothesis = "More social and choreographed, but higher readability and collision risk.",
		successCriteria = {
			"Both players can identify which lit square belongs to whom.",
			"Crossing routes feel intentional, not blocked.",
			"Shared camera shows the entire board without shrinking avatar readability.",
			"Team scoring remains understandable after one player misses.",
		},
		risks = {
			"Avatar overlap can hide active tiles.",
			"Mobile camera may need a wider view than solo.",
			"Collision and pathing can make misses feel unfair.",
		},
	},
}

CoopLayoutPlaytest.Metrics = {
	"completionRate",
	"averageAccuracy",
	"wrongTileRate",
	"collisionOrOverlapNotes",
	"cameraReadabilityRating",
	"teamworkFeelingRating",
	"confusionMomentCount",
}

function CoopLayoutPlaytest.getVariant(modeId: string)
	for _, variant in CoopLayoutPlaytest.Variants do
		if variant.modeId == modeId or variant.id == modeId then
			return variant
		end
	end

	return nil
end

return CoopLayoutPlaytest
