local CharacterCatalog = {}

CharacterCatalog.Policy = {
	RealPeopleRequireLicense = true,
	BrandIntegrationRequiresLicense = true,
	NoPayToWinByDefault = true,
	AbilitiesDisabledInCompetitive = true,
	FictionalPlaceholdersOnlyUntilLicensed = true,
}

CharacterCatalog.AbilityRules = {
	CasualOnly = true,
	CompetitiveAllowed = false,
	RankedLeaderboardAllowed = false,
	ServerAuthoritativeActivationRequired = true,
}

CharacterCatalog.Characters = {
	{
		id = "pixel-dancer-default",
		displayName = "Pixel Dancer",
		rarity = "starter",
		licensedCharacter = false,
		sourceStatus = "fictional_internal",
		hasSpecialAbility = false,
		availability = "always",
		abilityId = nil,
		competitiveEnabled = true,
	},
	{
		id = "neon-rookie",
		displayName = "Neon Rookie",
		rarity = "rare",
		licensedCharacter = false,
		sourceStatus = "fictional_internal",
		hasSpecialAbility = true,
		abilityId = "crowd-hype-mini-boost",
		availability = "prototype",
		competitiveEnabled = false,
	},
	{
		id = "licensed-idol-placeholder",
		displayName = "Licensed Idol Placeholder",
		rarity = "limited",
		licensedCharacter = true,
		sourceStatus = "requires_license",
		hasSpecialAbility = true,
		abilityId = "brand-event-power-move",
		availability = "blocked_until_rights_approved",
		competitiveEnabled = false,
		rightsRequired = {
			"artist_or_band_likeness",
			"brand_name",
			"promotion_window",
			"Roblox_use_permission",
		},
	},
}

CharacterCatalog.Placeholders = CharacterCatalog.Characters

function CharacterCatalog.getCharacter(characterId: string)
	for _, character in CharacterCatalog.Characters do
		if character.id == characterId then
			return character
		end
	end

	return nil
end

function CharacterCatalog.isAllowedInMode(characterId: string, modeId: string): boolean
	local character = CharacterCatalog.getCharacter(characterId)

	if character == nil then
		return false
	end

	if modeId == "competitive" and character.competitiveEnabled ~= true then
		return false
	end

	return character.sourceStatus ~= "requires_license"
end

return CharacterCatalog
