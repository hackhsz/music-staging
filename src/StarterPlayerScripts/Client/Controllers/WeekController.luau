--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local CosmeticsCatalog = require(Catalogs:WaitForChild("CosmeticsCatalog"))
local ShopCatalog = require(Catalogs:WaitForChild("ShopCatalog"))
local WeekCatalog = require(Catalogs:WaitForChild("WeekCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local WeekPanel = require(script.Parent.Parent.UI.Screens.WeekPanel)

local COIN_ICON = "rbxassetid://90381087302472"
local DAY_SECONDS = 86400
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	openShop: () -> (),
	openPass: () -> (),
}

type Fields = {
	deps: Deps,
	eventId: string?,
}

-- The This Week board: builds each card from the profile, the weekly league and the
-- catalogs, and opens it from the rail's HOME. Nothing here decides an outcome.
local WeekController = {}
WeekController.__index = WeekController

export type WeekController = typeof(setmetatable({} :: Fields, WeekController))

local function ordinal(rank: number): string
	local tens = rank % 100
	local suffix = if tens >= 11 and tens <= 13
		then "TH"
		elseif rank % 10 == 1 then "ST"
		elseif rank % 10 == 2 then "ND"
		elseif rank % 10 == 3 then "RD"
		else "TH"

	return tostring(rank) .. suffix
end

local function liveShow(now: number): WeekPanel.LiveShow
	local show = WeekCatalog.LiveShow
	local start = WeekCatalog.nextShow(now)
	local date = os.date("!*t", start) :: any
	local days = math.floor((start - now) / DAY_SECONDS)

	return {
		day = ("%s %d %s"):format(WEEKDAYS[date.wday], date.day, MONTHS[date.month]),
		time = ("%02d:00 UTC · %d MIN"):format(show.hourUtc, show.minutes),
		status = if WeekCatalog.isLive(now)
			then "LIVE NOW"
			elseif days <= 0 then "TODAY"
			elseif days == 1 then "TOMORROW"
			else ("IN %d DAYS"):format(days),
		blurb = show.blurb,
	}
end

local function rewardLook(reward: any): (string, string)
	if reward == nil then
		return "", ""
	end

	if reward.kind == "coins" then
		return ("+%d COINS"):format(reward.amount or 0), COIN_ICON
	end

	local item = CosmeticsCatalog.getItem(reward.cosmeticId)

	return if item ~= nil then string.upper(item.displayName) else "REWARD", if item ~= nil then item.icon or "" else ""
end

local function passCard(snapshot: any): WeekPanel.Pass?
	if type(snapshot) ~= "table" or type(snapshot.tiers) ~= "table" then
		return nil
	end

	local upcoming = snapshot.tiers[math.min(snapshot.tier + 1, #snapshot.tiers)]
	local into = snapshot.points - snapshot.tier * snapshot.pointsPerTier
	local freeName, freeIcon = rewardLook(upcoming and upcoming.free)
	local passName, passIcon = rewardLook(upcoming and upcoming.pass)

	return {
		header = ("STAGE PASS · %s"):format(snapshot.seasonName),
		tier = ("TIER %d / %d"):format(snapshot.tier, #snapshot.tiers),
		week = ("WEEK %d OF %d"):format(snapshot.week, snapshot.weeks),
		fill = if snapshot.tier >= #snapshot.tiers then 1 else into / snapshot.pointsPerTier,
		freeName = freeName,
		freeIcon = freeIcon,
		passName = passName,
		passIcon = passIcon,
	}
end

local function shopPicks(): { WeekPanel.ShopPick }
	local picks: { WeekPanel.ShopPick } = {}

	for _, section in ShopCatalog.Sections do
		for _, offerId in section.offers or {} do
			local offer = ShopCatalog.getOffer(offerId)

			if offer ~= nil and offer.comingSoon ~= true and #picks < WeekCatalog.ShopPicks then
				table.insert(picks, { name = offer.displayName, icon = offer.icon or "", price = ("R$ %d"):format(offer.robux) })
			end
		end

		if #picks > 0 then
			break
		end
	end

	return picks
end

local function league(state: any): WeekPanel.League
	local rows: { WeekPanel.LeagueRow } = {}
	local lineAfter = nil

	for index, row in state.rows do
		table.insert(rows, { rank = row.rank, name = if row.you then "YOU" else row.name, value = row.value, you = row.you })

		if row.rank == state.promoteLine then
			lineAfter = index
		end
	end

	local resets = os.date("!*t", state.resetsAt) :: any

	return {
		tier = state.tierName,
		place = if state.rank ~= nil then ordinal(state.rank) else "—",
		of = if state.rank ~= nil then ("OF %d"):format(state.of) else "",
		rule = ("Top %d move up, the bottom places move down"):format(state.promoteLine),
		rows = rows,
		lineAfter = lineAfter,
		gap = if state.rank == nil
			then "PLAY A SONG TO GET A PLACE"
			elseif state.toPromote ~= nil then ("+%d TO PASS %s"):format(state.toPromote, ordinal(state.promoteLine))
			else "IN THE PROMOTION ZONE",
		resets = ("Resets %s %02d:00 UTC"):format(WEEKDAYS[resets.wday], resets.hour),
	}
end

function WeekController.new(deps: Deps): WeekController
	return setmetatable({ deps = deps, eventId = nil } :: Fields, WeekController)
end

function WeekController.start(self: WeekController)
	local deps = self.deps
	local week = deps.hud.week

	deps.hud.menu:bindHome(function()
		week:toggle()
		week:drawLiveShow(liveShow(os.time()))
	end)
	week:bindFollow(function()
		self:_follow()
	end)
	task.spawn(function()
		self:_findEvent()
	end)
	week:bindShop(deps.openShop)
	week:bindPass(deps.openPass)
	week:drawLiveShow(liveShow(os.time()))
	week:drawShop(shopPicks())

	Remotes.listen(deps.remotes.ProfileSync, function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		local rows: { WeekPanel.DailyRow } = {}

		for _, challenge in if type(payload.daily) == "table" then payload.daily else {} do
			table.insert(rows, { name = challenge.name, value = challenge.value, target = challenge.target, done = challenge.done })
		end

		local streak = tonumber(payload.streakDays) or 0

		week:drawDaily(
			rows,
			if payload.xpBonusReady == true then "2X XP" else "USED",
			if streak == 1 then "1 DAY" else ("%d DAYS"):format(streak)
		)

		local pass = passCard(payload.stagePass)

		if pass ~= nil then
			week:drawPass(pass)
		end
	end)
	Remotes.listen(deps.remotes.LeagueState, function(payload: any)
		if type(payload) == "table" and type(payload.rows) == "table" then
			week:drawLeague(league(payload))
		end
	end)
end

-- The Live Show is a Roblox experience event made in Creator Hub; the next one is looked up
-- at runtime so no event id goes stale.
function WeekController._findEvent(self: WeekController)
	local week = self.deps.hud.week
	local ok, events = pcall(SocialService.GetUpcomingExperienceEventsAsync, SocialService)

	if not ok or type(events) ~= "table" then
		week:setFollow(nil)
		return
	end

	for _, event in events do
		if not event.HasStarted and not event.HasEnded then
			self.eventId = event.Id
			week:setFollow(event.UserRsvpStatus == Enum.RsvpStatus.Going)
			return
		end
	end

	week:setFollow(nil)
end

function WeekController._follow(self: WeekController)
	local eventId = self.eventId

	if eventId == nil then
		return
	end

	local ok, status = pcall(SocialService.PromptRsvpToEventAsync, SocialService, eventId)

	if ok then
		self.deps.hud.week:setFollow(status == Enum.RsvpStatus.Going)
	else
		warn("[DanceDanceStep] Event RSVP prompt failed: " .. tostring(status))
	end
end

return WeekController
