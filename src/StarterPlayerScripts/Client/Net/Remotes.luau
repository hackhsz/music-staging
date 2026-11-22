--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteContract = require(Shared:WaitForChild("RemoteContract"))

-- Every remote the client talks to, resolved once, by the name RemoteContract
-- declares it under. Controllers read them from here and never look one up.
local USED_EVENTS = {
	"SongCatalog",
	"StartSong",
	"SubmitHit",
	"ReportArrival",
	"SubmitPress",
	"SubmitRelease",
	"SubmitClap",
	"HitResult",
	"ItemResult",
	"RivalResult",
	"SongComplete",
	"MultiplayerStatus",
	"RequestMode",
	"SetPlayMode",
	"StageSeen",
	"RequestParty",
	"RequestRematch",
	"RequestRestart",
	"RequestPause",
	"PauseState",
	"RequestSong",
	"SetTimingOffset",
	"SetPlayerSetting",
	"TimingOffsetSync",
	"PlayEmote",
	"EmoteApproved",
	"EquipCosmetic",
	"UnequipCosmetic",
	"PurchaseCosmetic",
	"PurchaseSong",
	"PurchaseResult",
	"ProfileSync",
	"LeaderboardData",
	"LeagueState",
	"ClaimReward",
	"ClaimPassTier",
	"RedeemCode",
	"TravelToIsland",
	"ClaimStall",
	"ReleaseStall",
	"AddListing",
	"RemoveListing",
	"BuyListing",
	"ListCreations",
	"CreationsList",
	"StallState",
	"StallResult",
	"SetAbilityLoadout",
	"AbilityState",
	"OpenSongPicker",
	"ReturnToHub",
	"OnboardingState",
	"StartTutorial",
	"SkipTutorial",
	"CompleteOnboardingStep",
	"ReportFunnelStep",
}

-- A remote event queued before anyone listens goes only to its first connection, so
-- the join-time pushes would reach whichever controller connected first. These are
-- heard through one connection each, and the latest payload is replayed to every
-- listener that arrives after it.
local REPLAYED_EVENTS = { "ProfileSync", "LeaderboardData", "LeagueState", "OnboardingState", "StallState" }

export type Remotes = { [string]: RemoteEvent }

local Remotes = {}

local latest: { [RemoteEvent]: any } = {}
local listeners: { [RemoteEvent]: { (any) -> () } } = {}

local function track(remote: RemoteEvent): { (any) -> () }
	local list = listeners[remote]

	if list ~= nil then
		return list
	end

	local created: { (any) -> () } = {}
	listeners[remote] = created
	remote.OnClientEvent:Connect(function(payload)
		latest[remote] = payload

		for _, callback in created do
			task.spawn(callback, payload)
		end
	end)

	return created
end

function Remotes.resolve(): Remotes
	local folder = ReplicatedStorage:WaitForChild(RemoteContract.FolderName)
	local resolved: Remotes = {}

	for _, eventName in USED_EVENTS do
		resolved[eventName] = folder:WaitForChild(RemoteContract.Events[eventName].name) :: RemoteEvent
	end

	for _, eventName in REPLAYED_EVENTS do
		track(resolved[eventName])
	end

	return resolved
end

function Remotes.listen(remote: RemoteEvent, callback: (any) -> ())
	table.insert(track(remote), callback)

	if latest[remote] ~= nil then
		task.spawn(callback, latest[remote])
	end
end

return Remotes
