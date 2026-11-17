local AchievementCatalog = require(script.Parent.AchievementCatalog)

local Progression = {}

function Progression.evaluate(summary: any): { string }
	local unlocked = {}

	for _, achievement in AchievementCatalog.Achievements do
		local value = summary[achievement.metric] or 0

		if achievement.songId ~= nil then
			local songProgress = type(summary.songProgress) == "table" and summary.songProgress or {}
			value = tonumber(songProgress[achievement.songId]) or 0
		end

		if value >= achievement.target then
			table.insert(unlocked, achievement.id)
		end
	end

	return unlocked
end

return Progression
