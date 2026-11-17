local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local modules = {
	"Catalogs/AudioCatalog",
	"RemoteContract",
	"SongMapCatalog",
	"InputStrategy",
	"StageBlockout",
	"CrowdHype",
	"MultiplayerModes",
	"Catalogs/Economy",
	"Catalogs/EasterEggs",
	"Catalogs/LeaderboardConfig",
	"Catalogs/SocialRewards",
	"Catalogs/LiveOpsPlan",
	"SongCollection",
	"Catalogs/CosmeticsCatalog",
	"Catalogs/EmoteCatalog",
	"Catalogs/StageCatalog",
	"Catalogs/CharacterCatalog",
	"Catalogs/AbilityCatalog",
	"Catalogs/AchievementCatalog",
	"ScoreSummary",
	"Catalogs/VFXCatalog",
	"Catalogs/ShopCatalog",
	"Catalogs/IslandCatalog",
	"Catalogs/UGCCatalog",
	"Catalogs/FunnelCatalog",
	"Catalogs/OnboardingCatalog",
	"Policies/RightsPolicy",
	"Policies/UGCPolicy",
	"Policies/MonetizationPolicy",
	"Catalogs/EarlySupporterProgram",
	"PerformanceBudget",
}

for _, path in modules do
	local module = Shared

	for name in string.gmatch(path, "[^/]+") do
		module = module:WaitForChild(name)
	end

	require(module)
end

local chartsOk, chartsReason = require(Shared:WaitForChild("SongMapCatalog")).validateAll()

if not chartsOk then
	warn("[DanceDanceStep] A chart failed validation: " .. chartsReason)
end

print(("[DanceDanceStep] Day 0 feature registry loaded %d modules"):format(#modules))
