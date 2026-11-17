--!strict
-- The funnels logged to the Creator Dashboard (AnalyticsService), each an ordered
-- list of steps. Only the server logs; a step marked `client` is one only the
-- client can see, and the client reports it through ReportFunnelStep. Append new
-- steps at the end: a step's number is its place in the list, and moving one
-- breaks the dashboard's history.
local FunnelCatalog = {}

export type Step = { id: string, client: boolean? }

-- Logged at most once per player, ever.
FunnelCatalog.Onboarding = "onboarding"

FunnelCatalog.Funnels = {
	onboarding = {
		{ id = "joined" },
		{ id = "loaded", client = true },
		{ id = "tutorial_started" },
		{ id = "drill_step" },
		{ id = "drill_any" },
		{ id = "drill_hold" },
		{ id = "drill_clap" },
		{ id = "drill_avoid" },
		{ id = "tutorial_done" },
		{ id = "timing_checked" },
		{ id = "first_song_started" },
		{ id = "first_song_cleared" },
		{ id = "tip_quests" },
		{ id = "tip_shop" },
		{ id = "tip_wardrobe" },
	},
	-- One session per shop visit, from opening it to a purchase.
	shop = {
		{ id = "opened", client = true },
		{ id = "item_viewed", client = true },
		{ id = "purchase_requested" },
		{ id = "purchased" },
	},
	-- One session per run.
	run = {
		{ id = "started" },
		{ id = "first_hit" },
		{ id = "halfway" },
		{ id = "finished" },
		{ id = "cleared" },
	},
} :: { [string]: { Step } }

function FunnelCatalog.stepIndex(funnelName: string, stepId: string): number?
	local steps = FunnelCatalog.Funnels[funnelName]

	if steps == nil then
		return nil
	end

	for index, step in steps do
		if step.id == stepId then
			return index
		end
	end

	return nil
end

function FunnelCatalog.isClientStep(funnelName: string, stepId: string): boolean
	local index = FunnelCatalog.stepIndex(funnelName, stepId)

	return index ~= nil and FunnelCatalog.Funnels[funnelName][index].client == true
end

return FunnelCatalog
