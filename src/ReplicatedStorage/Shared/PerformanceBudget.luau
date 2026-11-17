local PerformanceBudget = {}

PerformanceBudget.Targets = {
	minimumFps = 30,
	targetFps = 60,
	maxRuntimeStageParts = 340,
	maxDanceFloorParts = 170,
	maxClientMemoryMb = 700,
	maxServerReceiveKbpsPerPlayer = 8,
	maxStageLightInstances = 16,
}

PerformanceBudget.QualityProfiles = {
	High = {
		equalizerBars = 44,
		audiencePods = 11,
		standFans = 8,
		crowdWallFill = 1,
		maxSpotlights = 7,
		maxStagePointLights = 6,
	},
	Low = {
		equalizerBars = 24,
		audiencePods = 5,
		standFans = 4,
		crowdWallFill = 0.5,
		maxSpotlights = 3,
		maxStagePointLights = 2,
	},
}

function PerformanceBudget.getDefaultQualityProfile()
	return PerformanceBudget.QualityProfiles.High
end

return PerformanceBudget
