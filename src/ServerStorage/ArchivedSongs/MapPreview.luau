local Timing = require(script.Parent.Parent.Timing)

local MapPreview = {}

function MapPreview.getUpcomingSteps(map: any, elapsedSeconds: number, lookaheadSeconds: number)
	local upcoming = {}

	for index, step in map.steps do
		local targetTime = Timing.beatToSeconds(step.beat, map.bpm)

		if targetTime >= elapsedSeconds and targetTime <= elapsedSeconds + lookaheadSeconds then
			table.insert(upcoming, {
				index = index,
				step = step,
				targetTime = targetTime,
				secondsUntilHit = targetTime - elapsedSeconds,
			})
		end
	end

	return upcoming
end

return MapPreview

