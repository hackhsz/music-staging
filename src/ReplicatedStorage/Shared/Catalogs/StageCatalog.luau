local StageCatalog = {}

StageCatalog.Stages = {
	{
		id = "neon-pixel-main",
		displayName = "Neon Pixel Main Stage",
		unlockedByDefault = true,
		unlockType = "starter",
		pixelArtRequired = true,
		defaultThemeId = "sakura-concert",
		performanceBudgetId = "default_concert_stage",
		supportedModes = { "solo", "coop_separate", "coop_shared", "competitive" },
		themeIds = {
			"sakura-concert",
			"neon-candy",
			"school-idol",
			"summer-stage",
			"pixel-galaxy",
		},
	},
}

StageCatalog.SelectionRules = {
	solo = "player_selected",
	coop_separate = "party_leader_selected",
	coop_shared = "party_leader_selected",
	competitive = "default_or_mutual_owned_only",
}

function StageCatalog.getStage(stageId: string)
	for _, stage in StageCatalog.Stages do
		if stage.id == stageId then
			return stage
		end
	end

	return nil
end

function StageCatalog.isStageAllowedInMode(stageId: string, modeId: string): boolean
	local stage = StageCatalog.getStage(stageId)

	if stage == nil then
		return false
	end

	return table.find(stage.supportedModes or {}, modeId) ~= nil
end

return StageCatalog
