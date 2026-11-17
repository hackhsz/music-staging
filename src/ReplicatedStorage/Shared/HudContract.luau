--!strict
-- The contract between the authored HUD in the place and the code that drives it.
--
-- Code never walks a name path. Every element the HUD needs carries the tag
-- below and an attribute naming its role, so an element can be renamed or
-- reparented in Studio without breaking anything. HudBinder resolves these once
-- and reports what is missing, which turns a silent blank into one boot-time line.
--
-- To wire a new element: add a row here, then in Studio tag the instance and set
-- its HudRole attribute to the row's key.

local HudContract = {}

HudContract.Tag = "HudElement"
HudContract.RoleAttribute = "HudRole"

export type Kind = "text" | "bar" | "group" | "button"

export type Element = {
	kind: Kind,
	required: boolean,
	feeds: string,
}

-- feeds names the value that drives the element, so the row says what it is for
-- without anyone reading the controller.
local Elements: { [string]: Element } = {
	ScoreValue = { kind = "text", required = true, feeds = "run score" },
	ScoreGroup = { kind = "group", required = false, feeds = "shown while a run is active" },
	NewRecord = { kind = "group", required = false, feeds = "visible once the run beats the stored best" },

	ComboValue = { kind = "text", required = true, feeds = "current combo" },
	ComboGroup = { kind = "group", required = false, feeds = "hidden at combo 0" },

	LifeFill = { kind = "bar", required = true, feeds = "life 0..1 as a size fraction" },
	LifeGroup = { kind = "group", required = false, feeds = "pulses under 25%" },

	ProgressFill = { kind = "bar", required = true, feeds = "elapsed / duration as a size fraction" },
	ProgressGroup = { kind = "group", required = false, feeds = "shown while a run is active" },

	JudgementText = { kind = "text", required = false, feeds = "Perfect / Great / Good / Miss" },
	TimingDelta = { kind = "text", required = false, feeds = "early or late, in milliseconds" },
	JudgementGroup = { kind = "group", required = false, feeds = "the judgement banner, popped in per grade" },

	SongTitle = { kind = "text", required = false, feeds = "song title" },
	SongArtist = { kind = "text", required = false, feeds = "song artist" },
	SongDifficulty = { kind = "text", required = false, feeds = "difficulty name" },

	PauseButton = { kind = "button", required = false, feeds = "pauses the run" },

	HighwayGroup = { kind = "group", required = false, feeds = "the lane keys' panel, shown in highway runs" },
	LaneKey1 = { kind = "button", required = false, feeds = "highway lane 1: its notes land here, a tap plays it" },
	LaneKey2 = { kind = "button", required = false, feeds = "highway lane 2: its notes land here, a tap plays it" },
	LaneKey3 = { kind = "button", required = false, feeds = "highway lane 3: its notes land here, a tap plays it" },
	LaneKey4 = { kind = "button", required = false, feeds = "highway lane 4: its notes land here, a tap plays it" },
}

HudContract.Elements = Elements

function HudContract.isKnownRole(role: string): boolean
	return HudContract.Elements[role] ~= nil
end

function HudContract.requiredRoles(): { string }
	local roles = {}

	for role, element in HudContract.Elements do
		if element.required then
			table.insert(roles, role)
		end
	end

	table.sort(roles)

	return roles
end

return HudContract
