local RightsPolicy = {}

RightsPolicy.AudioSourceStatuses = {
	GeneratedOwned = "generated_owned",
	Commissioned = "commissioned",
	Licensed = "licensed",
	CreatorStorePermitted = "creator_store_permitted",
	PlaceholderBlocked = "placeholder_blocked",
	UnknownBlocked = "unknown_blocked",
}

RightsPolicy.RequiredPublicLaunchFields = {
	"rights",
	"rightsProof",
	"sourceAudioFile",
	"audioAssetId",
	"ownerScope",
}

RightsPolicy.Rules = {
	"No real K-pop song without license.",
	"No real celebrity likeness without license.",
	"No real band, label, or brand logo without license.",
	"No copied choreography from protected works.",
	"All generated art must be pixel art and original to this project.",
}

RightsPolicy.AllowedPublicAudioStatuses = {
	repo_generated_owned_synthetic = true,
	generated_owned = true,
	commissioned = true,
	licensed = true,
	creator_store_permitted = true,
}

RightsPolicy.BlockedAudioStatuses = {
	placeholder_blocked = true,
	unknown_blocked = true,
	copyrighted_unlicensed = true,
}

function RightsPolicy.validateAudioSong(song: any): (boolean, string)
	if type(song) ~= "table" then
		return false, "song must be a table"
	end

	if RightsPolicy.BlockedAudioStatuses[song.rights] == true then
		return false, "song rights status is blocked"
	end

	if RightsPolicy.AllowedPublicAudioStatuses[song.rights] ~= true then
		return false, "song rights status is not approved for public launch"
	end

	for _, fieldName in RightsPolicy.RequiredPublicLaunchFields do
		if song[fieldName] == nil or song[fieldName] == "" then
			return false, ("song missing required public launch field: %s"):format(fieldName)
		end
	end

	if song.ownerScope ~= "Derail Games" and song.ownerScope ~= "project_group" then
		return false, "song audio asset must be owned by the project group"
	end

	return true, "ok"
end

return RightsPolicy
