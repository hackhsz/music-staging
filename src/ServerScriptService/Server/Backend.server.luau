local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteContract = require(Shared:WaitForChild("RemoteContract"))
local AbilityCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local EmoteCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("EmoteCatalog"))
local CosmeticsCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CosmeticsCatalog"))
local SongCollection = require(Shared:WaitForChild("SongCollection"))
local SongMapCatalog = require(Shared:WaitForChild("SongMapCatalog"))
local RankCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("RankCatalog"))
local DailyChallenges = require(Shared:WaitForChild("Catalogs"):WaitForChild("DailyChallenges"))
local PlayerSettings = require(Shared:WaitForChild("PlayerSettings"))

local Services = script.Parent:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local RewardService = require(Services:WaitForChild("RewardService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local LeaderstatsService = require(Services:WaitForChild("LeaderstatsService"))
local MultiplayerService = require(Services:WaitForChild("MultiplayerService"))
local RateLimiter = require(Services:WaitForChild("RateLimiter"))
local CosmeticVisualsService = require(Services:WaitForChild("CosmeticVisualsService"))
local StationService = require(Services:WaitForChild("StationService"))
local CodeService = require(Services:WaitForChild("CodeService"))
local PodiumService = require(Services:WaitForChild("PodiumService"))
local FunnelService = require(Services:WaitForChild("FunnelService"))
local OnboardingService = require(Services:WaitForChild("OnboardingService"))
local StallService = require(Services:WaitForChild("StallService"))

local remotes = ReplicatedStorage:WaitForChild(RemoteContract.FolderName)
local claimRewardRemote = remotes:WaitForChild(RemoteContract.Events.ClaimReward.name)
local claimPassTierRemote = remotes:WaitForChild(RemoteContract.Events.ClaimPassTier.name)
local equipCosmeticRemote = remotes:WaitForChild(RemoteContract.Events.EquipCosmetic.name)
local unequipCosmeticRemote = remotes:WaitForChild(RemoteContract.Events.UnequipCosmetic.name)
local multiplayerStatusRemote = remotes:WaitForChild(RemoteContract.Events.MultiplayerStatus.name)
local requestModeRemote = remotes:WaitForChild(RemoteContract.Events.RequestMode.name)
local setPlayModeRemote = remotes:WaitForChild(RemoteContract.Events.SetPlayMode.name)
local stageSeenRemote = remotes:WaitForChild(RemoteContract.Events.StageSeen.name)
local requestPartyRemote = remotes:WaitForChild(RemoteContract.Events.RequestParty.name)
local requestRematchRemote = remotes:WaitForChild(RemoteContract.Events.RequestRematch.name)
local playEmoteRemote = remotes:WaitForChild(RemoteContract.Events.PlayEmote.name)
local emoteApprovedRemote = remotes:WaitForChild(RemoteContract.Events.EmoteApproved.name)
local purchaseCosmeticRemote = remotes:WaitForChild(RemoteContract.Events.PurchaseCosmetic.name)
local purchaseSongRemote = remotes:WaitForChild(RemoteContract.Events.PurchaseSong.name)
local purchaseResultRemote = remotes:WaitForChild(RemoteContract.Events.PurchaseResult.name)
local profileSyncRemote = remotes:WaitForChild(RemoteContract.Events.ProfileSync.name)
local songCatalogRemote = remotes:WaitForChild(RemoteContract.Events.SongCatalog.name)
local leaderboardDataRemote = remotes:WaitForChild(RemoteContract.Events.LeaderboardData.name)
local setAbilityLoadoutRemote = remotes:WaitForChild(RemoteContract.Events.SetAbilityLoadout.name)
local openSongPickerRemote = remotes:WaitForChild(RemoteContract.Events.OpenSongPicker.name)
local setPlayerSettingRemote = remotes:WaitForChild(RemoteContract.Events.SetPlayerSetting.name)
local redeemCodeRemote = remotes:WaitForChild(RemoteContract.Events.RedeemCode.name)
local travelToIslandRemote = remotes:WaitForChild(RemoteContract.Events.TravelToIsland.name)
local onboardingStateRemote = remotes:WaitForChild(RemoteContract.Events.OnboardingState.name)
local completeOnboardingStepRemote = remotes:WaitForChild(RemoteContract.Events.CompleteOnboardingStep.name)
local reportFunnelStepRemote = remotes:WaitForChild(RemoteContract.Events.ReportFunnelStep.name)
local claimStallRemote = remotes:WaitForChild(RemoteContract.Events.ClaimStall.name)
local releaseStallRemote = remotes:WaitForChild(RemoteContract.Events.ReleaseStall.name)
local addListingRemote = remotes:WaitForChild(RemoteContract.Events.AddListing.name)
local removeListingRemote = remotes:WaitForChild(RemoteContract.Events.RemoveListing.name)
local buyListingRemote = remotes:WaitForChild(RemoteContract.Events.BuyListing.name)
local listCreationsRemote = remotes:WaitForChild(RemoteContract.Events.ListCreations.name)
local creationsListRemote = remotes:WaitForChild(RemoteContract.Events.CreationsList.name)
local stallStateRemote = remotes:WaitForChild(RemoteContract.Events.StallState.name)
local stallResultRemote = remotes:WaitForChild(RemoteContract.Events.StallResult.name)

local playerDataService = PlayerDataService.new()
local rewardService = RewardService.new(playerDataService)
local purchaseService = PurchaseService.new(playerDataService, rewardService)
local inventoryService = InventoryService.new(playerDataService)
local leaderboardService = LeaderboardService.new()
local leaderstatsService = LeaderstatsService.new(playerDataService)
local multiplayerService = MultiplayerService.new(multiplayerStatusRemote)
local rateLimiter = RateLimiter.new()
local cosmeticVisualsService = CosmeticVisualsService.new(playerDataService)
local stationService = StationService.new(openSongPickerRemote)
local podiumService = PodiumService.new()
local codeService = CodeService.new(playerDataService)
local funnelService = FunnelService.new(playerDataService)
local stallService = StallService.new(playerDataService, stallStateRemote, stallResultRemote)
local AUTOSAVE_INTERVAL_SECONDS = 60
local LEADERBOARD_REFRESH_SECONDS = 60
local leaderboardSnapshot = nil

local STAGE_SEEN_KEYS = { reveal = "stageRevealSeen", notice = "stageNoticeSeen" }

local Backend = {}

local function syncProfileLater(player: Player)
	Backend.syncProfile(player)
end

local onboardingService = OnboardingService.new(playerDataService, funnelService, onboardingStateRemote, syncProfileLater)

Backend.PlayerData = playerDataService
Backend.Rewards = rewardService
Backend.Inventory = inventoryService
Backend.Leaderboards = leaderboardService
Backend.Multiplayer = multiplayerService
Backend.RateLimiter = rateLimiter
Backend.CosmeticVisuals = cosmeticVisualsService
Backend.Stations = stationService
Backend.Codes = codeService
Backend.Funnels = funnelService
Backend.Onboarding = onboardingService
Backend.Stalls = stallService
Backend.Purchases = purchaseService

-- RhythmService replaces this once it starts; it alone knows who is mid-run.
function Backend.isInRun(_player: Player): boolean
	return false
end

-- Balance/inventory snapshot pushed to the owning client on join and after
-- every server-side change (rewards, purchases, equips).
local function buildDailySnapshot(profile: any)
	local dayKey = DailyChallenges.dayKey(os.time())
	local fresh = type(profile.daily) == "table" and profile.daily.key == dayKey
	local progress = fresh and profile.daily.progress or DailyChallenges.emptyProgress()
	local rewarded = fresh and profile.daily.rewarded or {}

	local list = {}
	for _, challenge in DailyChallenges.rollDaily(dayKey) do
		table.insert(list, {
			id = challenge.id,
			name = challenge.name,
			glyph = challenge.glyph,
			icon = challenge.icon,
			value = math.min(progress[challenge.metric] or 0, challenge.target),
			target = challenge.target,
			reward = challenge.reward,
			done = DailyChallenges.isComplete(challenge, progress),
			rewarded = rewarded[challenge.id] == true,
		})
	end

	return list
end

local function buildProfileSnapshot(player: Player)
	local profile = playerDataService:get(player)

	if profile == nil then
		return nil
	end

	return {
		softCurrency = profile.softCurrency or 0,
		cosmetics = profile.cosmetics,
		equipped = profile.equipped,
		unlockedSongs = profile.unlockedSongs,
		achievements = profile.achievements,
		claimedRewards = profile.claimedRewards,
		rewardCooldowns = profile.rewardCooldowns,
		stats = profile.stats,
		abilityLoadout = AbilityCatalog.sanitizeLoadout(profile.abilityLoadout),
		settings = PlayerSettings.resolve(profile.settings),
		xp = profile.xp or 0,
		progression = RankCatalog.progress(profile.xp, profile.rank),
		stages = RankCatalog.stages(profile, DailyChallenges.dayKey(os.time())),
		daily = buildDailySnapshot(profile),
		timeRewards = rewardService:visitSnapshot(player),
		stagePass = rewardService:stagePassSnapshot(player),
		passes = profile.passes,
		boughtOffers = profile.boughtOffers,
		setRoad = rewardService:setRoadSnapshot(player),
	}
end

-- Everyone in a match sees the host's arena; a player outside one sees their own.
local function refreshArena(player: Player)
	local matchPlayers = multiplayerService:getMatchPlayers(player)
	local hostProfile = playerDataService:get(matchPlayers[1])
	local arenaId = if hostProfile ~= nil then hostProfile.equipped.arena else nil

	for _, matchPlayer in matchPlayers do
		matchPlayer:SetAttribute(CosmeticsCatalog.ArenaAttribute, arenaId or CosmeticsCatalog.DefaultArenaId)
	end
end

multiplayerService.onMatchChanged = refreshArena

function Backend.syncProfile(player: Player)
	local snapshot = buildProfileSnapshot(player)

	refreshArena(player)

	if snapshot ~= nil then
		profileSyncRemote:FireClient(player, snapshot)
	end

	leaderstatsService:refresh(player)
end

function Backend.sendSongCatalog(player: Player)
	songCatalogRemote:FireClient(player, SongCollection.buildCatalogPayload(playerDataService:get(player)))
end

local function sendLeaderboards(player: Player)
	if leaderboardSnapshot ~= nil then
		leaderboardDataRemote:FireClient(
			player,
			leaderboardService:buildPlayerPayload(leaderboardSnapshot, player, playerDataService:get(player))
		)
	end
end

-- Lobby Leaderboard Wall feed: refresh the boards every ~60s and push a
-- per-player payload (top-10 plus that player's own best/rank).
local function refreshLeaderboards()
	leaderboardSnapshot = leaderboardService:buildSnapshot()
	podiumService:update(leaderboardSnapshot)

	for _, player in Players:GetPlayers() do
		sendLeaderboards(player)
	end
end

local function isFlagged(summary: any): boolean
	if type(summary.suspicious) ~= "table" then
		return false
	end

	for _, count in summary.suspicious do
		if (tonumber(count) or 0) > 0 then
			return true
		end
	end

	return false
end

function Backend.applySongComplete(player: Player, summary: any)
	-- The lesson pays nothing, ranks nowhere and counts toward no stat.
	if summary.tutorial == true then
		return { tutorial = onboardingService:drillFinished(player, summary.drill, summary) }
	end

	if summary.cleared == true then
		funnelService:onboarding(player, "first_song_cleared")
	end

	summary.flagged = isFlagged(summary)

	local rewards = rewardService:applySongSummary(player, summary)

	-- A failed run, one that used abilities or one anti-cheat flagged still pays,
	-- but does not rank.
	if summary.cleared == true and (summary.abilitiesUsed or 0) == 0 and not summary.flagged then
		leaderboardService:recordSongSummary(player, summary)
	end

	local profile = playerDataService:get(player)

	if profile ~= nil then
		leaderboardService:recordXp(player, profile.xp or 0)
	end

	multiplayerService:complete(player, summary)
	playerDataService:save(player)
	Backend.syncProfile(player)
	-- Rewards can unlock achievement-gated songs; refresh the lock states.
	Backend.sendSongCatalog(player)

	return rewards
end

local function applyCosmeticsToCharacter(player: Player, character: Model)
	-- Wait for the rig before welding cosmetics; bail quietly on despawn.
	task.spawn(function()
		if character:FindFirstChild("HumanoidRootPart") == nil then
			character:WaitForChild("HumanoidRootPart", 5)
		end

		if character.Parent ~= nil and player.Character == character then
			cosmeticVisualsService:applyEquipped(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	playerDataService:load(player)
	rewardService:startVisit(player)
	task.spawn(purchaseService.refreshPasses, purchaseService, player)

	if player.Parent == Players then
		leaderstatsService:add(player)
	end

	multiplayerService:addPlayer(player)
	funnelService:onboarding(player, "joined")

	-- Client scripts may not have connected their remote handlers yet;
	-- mirror RhythmService's one-second join delay for the first push.
	task.delay(1, function()
		if player.Parent == Players then
			Backend.syncProfile(player)
			sendLeaderboards(player)
			onboardingService:push(player)
			stallService:push(player)

			local profile = playerDataService:get(player)

			if profile ~= nil then
				leaderboardService:recordXp(player, profile.xp or 0)
			end
		end
	end)

	player.CharacterAdded:Connect(function(character)
		applyCosmeticsToCharacter(player, character)
	end)

	if player.Character ~= nil then
		applyCosmeticsToCharacter(player, player.Character)
	end
end

-- Backend can finish starting after the first player has joined.
Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	rateLimiter:clear(player)
	multiplayerService:clear(player)
	cosmeticVisualsService:clear(player)
	stationService:clear(player)
	stallService:clear(player)
	funnelService:clear(player)
	leaderboardService:clear(player)
	leaderstatsService:clear(player)
	rewardService:clear(player)
	playerDataService:release(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		playerDataService:saveAll()
	end
end)

task.spawn(function()
	while true do
		refreshLeaderboards()
		task.wait(LEADERBOARD_REFRESH_SECONDS)
	end
end)

game:BindToClose(function()
	playerDataService:saveAll()
end)

claimRewardRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ClaimReward", RemoteContract.Events.ClaimReward.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.rewardId) ~= "string" then
		return
	end

	local ok, reason, reward = rewardService:claimReward(player, payload.rewardId)
	local profile = playerDataService:get(player)

	purchaseResultRemote:FireClient(player, {
		ok = ok,
		kind = "reward",
		itemId = payload.rewardId,
		reason = reason,
		softCurrency = profile ~= nil and profile.softCurrency or 0,
		reward = reward,
	})

	if ok then
		Backend.syncProfile(player)
	end
end)

claimPassTierRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ClaimPassTier", RemoteContract.Events.ClaimPassTier.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.tier) ~= "number" or type(payload.row) ~= "string" then
		return
	end

	-- NaN and infinity are numbers too, and would break the tier lookup and the reply.
	if payload.tier ~= payload.tier or math.abs(payload.tier) == math.huge then
		return
	end

	local ok, reason, reward = rewardService:claimPassTier(player, math.floor(payload.tier), payload.row)
	local profile = playerDataService:get(player)

	purchaseResultRemote:FireClient(player, {
		ok = ok,
		kind = "pass",
		itemId = ("%s:%d"):format(payload.row, math.floor(payload.tier)),
		reason = reason,
		softCurrency = profile ~= nil and profile.softCurrency or 0,
		reward = reward,
	})

	if ok then
		Backend.syncProfile(player)
	end
end)

requestModeRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RequestMode", RemoteContract.Events.RequestMode.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.modeId) ~= "string" then
		return
	end

	multiplayerService:setPreferredMode(player, payload.modeId)
end)

setPlayModeRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SetPlayMode", RemoteContract.Events.SetPlayMode.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.modeId) ~= "string" or not RankCatalog.PlayModes[payload.modeId] then
		return
	end

	local profile = playerDataService:get(player)

	if profile == nil or profile.playMode == payload.modeId then
		return
	end

	profile.playMode = payload.modeId
	playerDataService:markDirty(player)
	Backend.syncProfile(player)
end)

stageSeenRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "StageSeen", RemoteContract.Events.StageSeen.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.what) ~= "string" or type(payload.rank) ~= "number" then
		return
	end

	local profile = playerDataService:get(player)
	local key = STAGE_SEEN_KEYS[payload.what]

	-- Only the stage the player is on can be marked, so a client cannot skip a later reveal.
	if profile == nil or key == nil or payload.rank ~= RankCatalog.clampRank(profile.rank) then
		return
	end

	if (tonumber(profile[key]) or 0) >= payload.rank then
		return
	end

	profile[key] = payload.rank
	playerDataService:markDirty(player)
	Backend.syncProfile(player)
end)

requestPartyRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RequestParty", RemoteContract.Events.RequestParty.rateLimitPerSecond) then
		return
	end

	local code = type(payload) == "table" and type(payload.code) == "string" and payload.code or nil
	multiplayerService:requestParty(player, code)
end)

requestRematchRemote.OnServerEvent:Connect(function(player)
	if not rateLimiter:allow(player, "RequestRematch", RemoteContract.Events.RequestRematch.rateLimitPerSecond) then
		return
	end

	multiplayerService:requestRematch(player)
end)

setAbilityLoadoutRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SetAbilityLoadout", RemoteContract.Events.SetAbilityLoadout.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.abilityIds) ~= "table" then
		return
	end

	local profile = playerDataService:get(player)

	if profile == nil then
		return
	end

	profile.abilityLoadout = AbilityCatalog.sanitizeLoadout(payload.abilityIds)
	playerDataService:markDirty(player)
	Backend.syncProfile(player)
end)

-- A preference only: nothing here changes a grade, so the client applies it at once
-- and this just keeps it for next time.
setPlayerSettingRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SetPlayerSetting", RemoteContract.Events.SetPlayerSetting.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.settingId) ~= "string" then
		return
	end

	local value = PlayerSettings.sanitize(payload.settingId, payload.value)
	local profile = playerDataService:get(player)

	if value == nil or profile == nil then
		return
	end

	if type(profile.settings) ~= "table" then
		profile.settings = {}
	end

	profile.settings[payload.settingId] = value
	playerDataService:markDirty(player)
end)

equipCosmeticRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "EquipCosmetic", RemoteContract.Events.EquipCosmetic.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.cosmeticId) ~= "string" then
		return
	end

	local equipped = inventoryService:equip(player, payload.cosmeticId)

	if equipped then
		cosmeticVisualsService:applyEquipped(player)
		Backend.syncProfile(player)
	end
end)

unequipCosmeticRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "UnequipCosmetic", RemoteContract.Events.UnequipCosmetic.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.category) ~= "string" then
		return
	end

	if inventoryService:unequip(player, payload.category) then
		cosmeticVisualsService:applyEquipped(player)
		Backend.syncProfile(player)
	end
end)

purchaseCosmeticRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "PurchaseCosmetic", RemoteContract.Events.PurchaseCosmetic.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.cosmeticId) ~= "string" then
		return
	end

	funnelService:shop(player, "purchase_requested")

	local ok, reason = inventoryService:purchase(player, payload.cosmeticId)
	local profile = playerDataService:get(player)

	purchaseResultRemote:FireClient(player, {
		ok = ok,
		kind = "cosmetic",
		itemId = payload.cosmeticId,
		reason = reason,
		softCurrency = profile ~= nil and profile.softCurrency or 0,
	})

	if ok then
		funnelService:shop(player, "purchased")
		playerDataService:save(player)
		Backend.syncProfile(player)
	end
end)

purchaseSongRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "PurchaseSong", RemoteContract.Events.PurchaseSong.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.songId) ~= "string" then
		return
	end

	funnelService:shop(player, "purchase_requested")

	local profile = playerDataService:get(player)
	local ok = false
	local reason

	if profile == nil then
		reason = "profile_not_loaded"
	elseif SongMapCatalog.getMap(payload.songId) == nil then
		reason = "unknown_song"
	elseif SongCollection.isUnlocked(payload.songId, profile) then
		reason = "already_unlocked"
	else
		local rule = SongCollection.getRule(payload.songId)

		if rule == nil or rule.type ~= "soft_currency" or not SongCollection.UnlockRules.SoftCurrencyUnlock then
			-- Achievement-gated tracks are never coin-purchasable.
			reason = "locked_requirement"
		elseif (profile.softCurrency or 0) < (tonumber(rule.price) or 0) then
			reason = "insufficient_funds"
		else
			profile.softCurrency -= tonumber(rule.price) or 0
			table.insert(profile.unlockedSongs, payload.songId)
			playerDataService:markDirty(player)
			ok = true
			reason = "purchased"
		end
	end

	purchaseResultRemote:FireClient(player, {
		ok = ok,
		kind = "song",
		itemId = payload.songId,
		reason = reason,
		softCurrency = profile ~= nil and profile.softCurrency or 0,
	})

	if ok then
		funnelService:shop(player, "purchased")
		playerDataService:save(player)
		Backend.syncProfile(player)
		Backend.sendSongCatalog(player)
	end
end)

playEmoteRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "PlayEmote", RemoteContract.Events.PlayEmote.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.emoteId) ~= "string" then
		return
	end

	local emote = EmoteCatalog.getEmote(payload.emoteId)

	-- Catalog emotes are expression-only and available to everyone, so
	-- validation is existence + player-triggerable + rate limit.
	if emote == nil or emote.animationId == nil or emote.playerTriggered ~= true then
		return
	end

	-- Player characters are client network-owned, so the reliable playback
	-- path is local: the approved client plays the track on its own
	-- Animator and Roblox replicates it to the server and all other
	-- clients automatically.
	emoteApprovedRemote:FireClient(player, {
		emoteId = emote.id,
	})
end)

redeemCodeRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RedeemCode", RemoteContract.Events.RedeemCode.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.code) ~= "string" then
		return
	end

	local ok, reason, coins = codeService:redeem(player, payload.code)
	local profile = playerDataService:get(player)

	purchaseResultRemote:FireClient(player, {
		ok = ok,
		kind = "code",
		itemId = CodeService.normalize(payload.code),
		reason = reason,
		softCurrency = profile ~= nil and profile.softCurrency or 0,
		reward = if ok then { type = "soft_currency", amount = coins } else nil,
	})

	if ok then
		Backend.syncProfile(player)
	end
end)

claimStallRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ClaimStall", RemoteContract.Events.ClaimStall.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.stallId) ~= "string" then
		return
	end

	stallService:reply(player, stallService:claim(player, payload.stallId))
end)

releaseStallRemote.OnServerEvent:Connect(function(player)
	if not rateLimiter:allow(player, "ReleaseStall", RemoteContract.Events.ReleaseStall.rateLimitPerSecond) then
		return
	end

	stallService:reply(player, stallService:release(player))
end)

addListingRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "AddListing", RemoteContract.Events.AddListing.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.assetId) ~= "number" then
		return
	end

	local ok, reason = stallService:addListing(player, payload.assetId)

	stallService:reply(player, ok, reason, payload.assetId)
end)

removeListingRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "RemoveListing", RemoteContract.Events.RemoveListing.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.assetId) ~= "number" then
		return
	end

	local ok, reason = stallService:removeListing(player, payload.assetId)

	stallService:reply(player, ok, reason, payload.assetId)
end)

listCreationsRemote.OnServerEvent:Connect(function(player)
	if not rateLimiter:allow(player, "ListCreations", RemoteContract.Events.ListCreations.rateLimitPerSecond) then
		return
	end

	local creations = stallService:creationsOf(player)

	if creations == nil then
		stallService:reply(player, false, "lookup_failed")
		return
	end

	creationsListRemote:FireClient(player, { items = creations })
end)

buyListingRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "BuyListing", RemoteContract.Events.BuyListing.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.assetId) ~= "number" then
		return
	end

	local ok, reason = stallService:buy(player, payload.assetId)

	if not ok then
		stallService:reply(player, ok, reason, payload.assetId)
	end
end)

purchaseService.onGranted = function(player: Player, itemId: string)
	local profile = playerDataService:get(player)

	purchaseResultRemote:FireClient(player, {
		ok = true,
		kind = "robux",
		itemId = itemId,
		reason = "purchased",
		softCurrency = if profile ~= nil then profile.softCurrency else 0,
	})
	Backend.syncProfile(player)
end
purchaseService:start()

MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, purchased)
	stallService:onPurchaseFinished(player, assetId, purchased)
end)

travelToIslandRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "TravelToIsland", RemoteContract.Events.TravelToIsland.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.islandId) ~= "string" then
		return
	end

	if Backend.isInRun(player) then
		return
	end

	stationService:travel(player, payload.islandId)
end)

stationService:start()

completeOnboardingStepRemote.OnServerEvent:Connect(function(player, payload)
	if
		not rateLimiter:allow(player, "CompleteOnboardingStep", RemoteContract.Events.CompleteOnboardingStep.rateLimitPerSecond)
	then
		return
	end

	if type(payload) ~= "table" or type(payload.step) ~= "string" then
		return
	end

	onboardingService:completeStep(player, payload.step)
end)

reportFunnelStepRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "ReportFunnelStep", RemoteContract.Events.ReportFunnelStep.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.funnel) ~= "string" or type(payload.step) ~= "string" then
		return
	end

	funnelService:report(player, payload.funnel, payload.step)
end)

_G.DanceDanceStepBackend = Backend

print("[DanceDanceStep] Backend services started")
