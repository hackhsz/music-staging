local EmoteCatalog = {}

-- animationId values are the Roblox-owned R15 catalog emote animations from
-- the default Animate script set (dance1/dance2/dance3/cheer). They are
-- published by Roblox, so any experience may load them.
EmoteCatalog.Emotes = {
	{
		id = "signature-step-001",
		displayName = "Signature Step",
		type = "dance_emote",
		animationId = 507771019, -- Roblox R15 dance1
		packSlot = "Dance",
		looped = true,
		maxSeconds = 6,
		playerTriggered = true,
		scoreBonus = false,
	},
	{
		id = "pixel-finale-001",
		displayName = "Pixel Finale",
		type = "ending_move",
		animationId = 507776043, -- Roblox R15 dance2
		packSlot = "Victory",
		looped = false,
		maxSeconds = 5,
		playerTriggered = true,
		scoreBonus = false,
	},
	{
		id = "fever-groove-001",
		displayName = "Fever Groove",
		type = "reaction",
		animationId = 507777268, -- Roblox R15 dance3
		packSlot = "Fever",
		looped = true,
		maxSeconds = 12,
		playerTriggered = false,
		scoreBonus = false,
	},
	{
		id = "combo-cheer-001",
		displayName = "Combo Cheer",
		type = "reaction",
		animationId = 507770677, -- Roblox R15 cheer
		packSlot = "Cheer",
		looped = false,
		maxSeconds = 2.5,
		playerTriggered = false,
		scoreBonus = false,
	},
}

-- packSlot is the AnimationPacks slot that replaces the emote while a pack is equipped.
-- Gameplay moments mapped to catalog emotes.
EmoteCatalog.Reactions = {
	feverStart = "fever-groove-001",
	songCompleteHighRank = "pixel-finale-001",
	comboMilestone = "combo-cheer-001",
}

EmoteCatalog.ComboMilestoneInterval = 10
EmoteCatalog.HighRanks = { S = true, A = true }

EmoteCatalog.Policy = "Emotes are expression only and must not grant score bonuses."

function EmoteCatalog.getEmote(emoteId: string)
	for _, emote in EmoteCatalog.Emotes do
		if emote.id == emoteId then
			return emote
		end
	end

	return nil
end

return EmoteCatalog
