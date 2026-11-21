local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local OnboardingCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("OnboardingCatalog"))
local DataStoreRetry = require(script.Parent.DataStoreRetry)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local CURRENT_SCHEMA_VERSION = 3
-- Version 3 added onboarding; anyone who had played before it skips the lesson.
local ONBOARDING_SCHEMA_VERSION = 3
-- Music Game's old rhythm game kept its own stores, keyed player_<UserId>. A
-- player's progress there folds into this profile once, the first time they load.
local LEGACY_PROGRESSION_STORE = "DDSProgression"
local LEGACY_SHOP_STORE = "DDSShop"
local MAX_RETRIES = 4
local RETRY_OPTIONS: DataStoreRetry.Options = {
	attempts = MAX_RETRIES,
	baseDelaySeconds = 0.5,
	waitAfterFinalFailure = true,
}

local DEFAULT_PROFILE = {
	schemaVersion = CURRENT_SCHEMA_VERSION,
	softCurrency = 0,
	hardCurrency = 0,
	xp = 0,
	rank = 1,
	lastXpBonusDay = -1,
	-- Tries at each stage's challenger and the best score, keyed by the rank being left.
	challenge = { attempts = {}, best = {} },
	playMode = "StageChallenge",
	-- The highest stage whose reveal and whose half-XP notice the player has dismissed.
	stageRevealSeen = 1,
	stageNoticeSeen = 1,
	unlockedSongs = { "candy-pop-warmup" },
	cosmetics = {
		["lemon-lightstick-001"] = true,
		["arena-neon-main"] = true,
	},
	equipped = {
		["glow_stick"] = "lemon-lightstick-001",
		["arena"] = "arena-neon-main",
	},
	achievements = {},
	-- Marketplace asset ids this player lists on the stall they claim, and how many
	-- sold through it.
	ugcListings = {},
	ugcSales = 0,
	onboarding = {
		tutorialDone = false,
		drillsPassed = 0,
		giftPaid = false,
		-- OnboardingCatalog step ids already done: the timing check and each tip.
		done = {},
		-- The onboarding funnel steps already logged, so none is logged twice.
		funnelLogged = {},
	},
	abilityLoadout = table.clone(AbilityCatalog.DefaultLoadout),
	claimedRewards = {},
	stagePass = { season = "", points = 0, claimedFree = {}, claimedPass = {}, passOwned = false },
	-- ShopCatalog game pass offers the player owns, by offer id.
	passes = {},
	-- One-time Robux offers already bought, by offer id.
	boughtOffers = {},
	-- Developer product receipts already granted: PurchaseId to the time granted.
	receipts = {},
	setRoad = { season = "", step = 0, freeClaimed = false },
	rewardCooldowns = {},
	redeemedCodes = {},
	daily = {
		key = -1,
		progress = {},
		rewarded = {},
	},
	-- Set once the old game's XP and coins have been added; legacy keeps what has no
	-- home here yet (its grade, crowns and shop items).
	legacyImported = false,
	legacy = {},
	settings = {
		timingOffsetSeconds = 0,
		timingOffsetCalibrated = false,
		musicVolume = 1,
		effectsVolume = 1,
		stepsVolume = 1,
		menuVolume = 1,
		quality = "auto",
		backgroundBlur = true,
		cameraShake = true,
		keyUp = "W",
		keyLeft = "A",
		keyDown = "S",
		keyRight = "D",
		keyClap = "Space",
	},
	stats = {
		bestScore = 0,
		bestCombo = 0,
		songsCompleted = 0,
		totalPerfects = 0,
		totalGoods = 0,
		totalMisses = 0,
		completedSongs = {},
		-- Per chart id: the best { rank, score, combo }, shown on the song picker.
		songBests = {},
	},
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, child in value do
		copy[key] = deepCopy(child)
	end

	return copy
end

local function mergeDefaults(profile, defaults)
	for key, value in defaults do
		if profile[key] == nil then
			profile[key] = deepCopy(value)
		elseif type(value) == "table" and type(profile[key]) == "table" then
			mergeDefaults(profile[key], value)
		end
	end

	return profile
end

function PlayerDataService.new()
	return setmetatable({
		store = DataStoreService:GetDataStore("DanceDanceStepProfilesV1"),
		profiles = {},
		dirty = {},
		saveFailures = {},
	}, PlayerDataService)
end

function PlayerDataService:getDefaultProfile()
	return deepCopy(DEFAULT_PROFILE)
end

function PlayerDataService:migrate(profile)
	if type(profile) ~= "table" then
		return self:getDefaultProfile()
	end

	profile.schemaVersion = tonumber(profile.schemaVersion) or 0

	local played = type(profile.stats) == "table" and (tonumber(profile.stats.songsCompleted) or 0) > 0

	local onboarding = profile.onboarding
	-- An early cut of the onboarding saved walkthroughDone in place of the done list.
	local walkedThrough = type(onboarding) == "table" and onboarding.walkthroughDone == true

	if (profile.schemaVersion < ONBOARDING_SCHEMA_VERSION and onboarding == nil and played) or walkedThrough then
		local done = { [OnboardingCatalog.TimingCheck.id] = true }

		for _, tip in OnboardingCatalog.Tips do
			done[tip.id] = true
		end

		local logged = if type(onboarding) == "table" and type(onboarding.funnelLogged) == "table"
			then onboarding.funnelLogged
			else {}

		profile.onboarding = { tutorialDone = true, drillsPassed = 0, giftPaid = true, done = done, funnelLogged = logged }
	elseif type(onboarding) == "table" then
		onboarding.walkthroughDone = nil
	end

	-- A profile from before stages has nothing to reveal for the ranks it already holds, but
	-- its older charts now pay half, so the notice for its rank still shows once.
	if profile.stageRevealSeen == nil then
		profile.stageRevealSeen = math.max(tonumber(profile.rank) or 1, 1)
		profile.stageNoticeSeen = profile.stageRevealSeen - 1
	end

	mergeDefaults(profile, DEFAULT_PROFILE)
	profile.schemaVersion = CURRENT_SCHEMA_VERSION

	return profile
end

function PlayerDataService:retryDataStore(requestType: Enum.DataStoreRequestType, callback)
	local ok, result = DataStoreRetry.run(requestType, RETRY_OPTIONS, callback)

	if not ok then
		warn(("[DanceDanceStep] DataStore operation failed after %d attempts: %s"):format(MAX_RETRIES, tostring(result)))
	end

	return ok, result
end

function PlayerDataService:load(player: Player)
	local key = tostring(player.UserId)
	local profile = nil

	if not RunService:IsStudio() then
		local ok, result = self:retryDataStore(Enum.DataStoreRequestType.GetAsync, function()
			return self.store:GetAsync(key)
		end)

		if ok and type(result) == "table" then
			profile = result
		end
	end

	if profile == nil then
		profile = self:getDefaultProfile()
	end

	self.profiles[player] = self:migrate(profile)
	self.dirty[player] = false
	self.saveFailures[player] = 0

	if not RunService:IsStudio() then
		self:_importLegacy(player, self.profiles[player])
	end

	return self.profiles[player]
end

-- Reads one of the old game's stores. A failed read returns ok = false, so the
-- import waits for the next join instead of being marked done with nothing in it.
function PlayerDataService:_readLegacy(storeName: string, key: string): (boolean, any)
	local ok, result = self:retryDataStore(Enum.DataStoreRequestType.GetAsync, function()
		return DataStoreService:GetDataStore(storeName):GetAsync(key)
	end)

	return ok, if ok and type(result) == "table" then result else nil
end

function PlayerDataService:_importLegacy(player: Player, profile)
	if profile.legacyImported == true then
		return
	end

	local key = "player_" .. player.UserId
	local progressionOk, progression = self:_readLegacy(LEGACY_PROGRESSION_STORE, key)
	local shopOk, shop = self:_readLegacy(LEGACY_SHOP_STORE, key)

	if not progressionOk or not shopOk then
		return
	end

	if progression ~= nil then
		profile.xp += math.max(0, math.floor(tonumber(progression.Xp) or 0))
		profile.legacy.grade = progression.Grade
		profile.legacy.crowns = progression.Crowns
		profile.legacy.rewards = progression.Rewards
	end

	if shop ~= nil then
		profile.softCurrency += math.max(0, math.floor(tonumber(shop.Coins) or 0))
		profile.legacy.shop = shop
	end

	profile.legacyImported = true
	self:markDirty(player)
end

function PlayerDataService:get(player: Player)
	return self.profiles[player]
end

function PlayerDataService:markDirty(player: Player)
	if self.profiles[player] ~= nil then
		self.dirty[player] = true
	end
end

-- force writes even when the profile looks clean: an autosave already in flight clears the dirty
-- flag when it lands, though its write may have been taken before the newest change.
function PlayerDataService:save(player: Player, force: boolean?)
	local profile = self.profiles[player]

	if profile == nil or (not self.dirty[player] and not force) then
		return true
	end

	if RunService:IsStudio() then
		self.dirty[player] = false
		return true
	end

	local ok = self:retryDataStore(Enum.DataStoreRequestType.SetIncrementAsync, function()
		self.store:UpdateAsync(tostring(player.UserId), function(previous)
			local nextProfile = self:migrate(type(previous) == "table" and previous or {})
			mergeDefaults(profile, nextProfile)
			profile.schemaVersion = CURRENT_SCHEMA_VERSION

			return profile
		end)
	end)

	if ok then
		self.dirty[player] = false
		self.saveFailures[player] = 0
	else
		self.saveFailures[player] = (self.saveFailures[player] or 0) + 1
	end

	return ok
end

function PlayerDataService:saveAll()
	local ok = true

	for player in self.profiles do
		ok = self:save(player) and ok
	end

	return ok
end

function PlayerDataService:release(player: Player)
	self:save(player)
	self.profiles[player] = nil
	self.dirty[player] = nil
	self.saveFailures[player] = nil
end

return PlayerDataService
