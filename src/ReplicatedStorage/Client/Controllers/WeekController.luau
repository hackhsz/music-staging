--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Catalogs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs")
local CosmeticsCatalog = require(Catalogs:WaitForChild("CosmeticsCatalog"))
local LeagueCatalog = require(Catalogs:WaitForChild("LeagueCatalog"))
local ShopCatalog = require(Catalogs:WaitForChild("ShopCatalog"))
local WeekCatalog = require(Catalogs:WaitForChild("WeekCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local WeekPanel = require(script.Parent.Parent.UI.Screens.WeekPanel)

local COIN_ICON = "rbxassetid://90381087302472"
local DAY_SECONDS = 86400
local LIVE_CHECK_SECONDS = 30
local UPCOMING_SHOWN = 2
local LADDER_SHOWN = 3
local STREAK_DOTS = 7
local SHOP_CARDS = 4
local FEATURED_SECTION = "featured"
local PASS_OFFER = "stage-pass"
local HOUR_SECONDS = 3600
local AVATAR_SIZE = Enum.ThumbnailSize.Size150x150
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	openShop: () -> (),
	openPass: () -> (),
	openQuests: () -> (),
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

local function dayText(time: number): string
	local date = os.date("!*t", time) :: any

	return ("%s %d %s"):format(WEEKDAYS[date.wday], date.day, MONTHS[date.month])
end

local function hero(now: number): WeekPanel.Hero?
	local entry = WeekCatalog.featured(now)

	if entry == nil then
		return nil
	end

	local event = entry.event
	local hour = (os.date("!*t", entry.start) :: any).hour
	local days = math.floor((entry.start - now) / DAY_SECONDS)

	return {
		title = event.title,
		sticker = event.sticker,
		day = dayText(entry.start),
		time = if event.minutes > 0 then ("%02d:00 UTC · %d MIN"):format(hour, event.minutes) else ("%02d:00 UTC"):format(hour),
		status = if now >= entry.start
			then "LIVE NOW"
			elseif days <= 0 then "TODAY"
			elseif days == 1 then "TOMORROW"
			else ("IN %d DAYS"):format(days),
		blurb = event.blurb,
	}
end

-- What comes after the hero's event, soonest first.
local function upcoming(now: number): { WeekPanel.UpcomingRow }
	local featured = WeekCatalog.featured(now)
	local rows: { WeekPanel.UpcomingRow } = {}

	for _, entry in WeekCatalog.upcoming(now) do
		if (featured == nil or entry.event ~= featured.event) and #rows < UPCOMING_SHOWN then
			table.insert(rows, { day = dayText(entry.start), title = entry.event.title })
		end
	end

	return rows
end

local function weekLabel(now: number): string
	local sunday = LeagueCatalog.resetsAt(LeagueCatalog.weekOf(now)) - 1
	local monday = sunday - 7 * DAY_SECONDS + 1
	local first = os.date("!*t", monday) :: any
	local last = os.date("!*t", sunday) :: any

	return ("WEEK %d · MON %d – SUN %d %s"):format((first.yday - 1) // 7 + 1, first.day, last.day, MONTHS[last.month])
end

local function grouped(amount: number): string
	local text = tostring(math.floor(amount))
	local count = 0

	repeat
		text, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return text
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

local function passCell(reward: any, state: any): WeekPanel.PassCell
	local name, icon = rewardLook(reward)

	return { name = name, icon = icon, state = tostring(state) }
end

local function passCard(snapshot: any): WeekPanel.Pass?
	if type(snapshot) ~= "table" or type(snapshot.tiers) ~= "table" then
		return nil
	end

	local top = #snapshot.tiers
	local maxed = snapshot.tier >= top
	local into = snapshot.points - snapshot.tier * snapshot.pointsPerTier
	local tiers: { WeekPanel.PassTier } = {}

	for _, tier in snapshot.tiers do
		table.insert(tiers, { free = passCell(tier.free, tier.freeState), pass = passCell(tier.pass, tier.passState) })
	end

	local offer = ShopCatalog.getOffer(PASS_OFFER)

	return {
		header = ("%s · WEEK %d OF %d · ENDS %s"):format(snapshot.seasonName, snapshot.week, snapshot.weeks, dayText(snapshot.endsUtc)),
		tier = ("TIER %d"):format(snapshot.tier),
		points = if maxed
			then "EVERY TIER REACHED"
			else ("%s / %s POINTS TO TIER %d"):format(grouped(into), grouped(snapshot.pointsPerTier), snapshot.tier + 1),
		note = ("+%d points for every finished song"):format(snapshot.pointsPerSong),
		fill = if maxed then 1 else into / snapshot.pointsPerTier,
		current = snapshot.tier,
		tiers = tiers,
		button = if snapshot.passOwned == true or offer == nil then "OPEN PASS" else ("UNLOCK PASS · R$ %d"):format(offer.robux),
	}
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
	local left = math.max(state.resetsAt - os.time(), 0)
	local ladder: { string } = {}
	local pay = LeagueCatalog.CoinsFor

	for tier = tonumber(state.tier) or 1, #LeagueCatalog.Tiers do
		if #ladder < LADDER_SHOWN then
			table.insert(ladder, LeagueCatalog.Tiers[tier].name)
		end
	end

	return {
		tier = state.tierName,
		place = if state.rank ~= nil then ordinal(state.rank) else "—",
		of = if state.rank ~= nil then ("OF %d"):format(state.of) else "",
		rule = ("Top %d move up a tier, the bottom places move down. Sum of your %d best songs this week."):format(
			state.promoteLine,
			LeagueCatalog.BestSongs
		),
		rows = rows,
		lineAfter = lineAfter,
		gap = if state.rank == nil
			then "PLAY A SONG TO GET A PLACE"
			elseif state.toPromote ~= nil then ("+%d TO PASS %s"):format(state.toPromote, ordinal(state.promoteLine))
			else "IN THE PROMOTION ZONE",
		resets = ("Resets %s %02d:00 UTC"):format(WEEKDAYS[resets.wday], resets.hour),
		ends = ("ENDS IN %dD %dH"):format(left // DAY_SECONDS, (left % DAY_SECONDS) // HOUR_SECONDS),
		best = ("YOUR BEST %d SONGS: %s PTS"):format(LeagueCatalog.BestSongs, grouped(tonumber(state.points) or 0)),
		ladder = ladder,
		payUp = ("PROMOTE: +%d"):format(pay.up),
		payStay = ("STAY: +%d"):format(pay.stay),
		payDown = ("DROP: +%d"):format(pay.down),
	}
end

local function daily(payload: any): WeekPanel.Daily
	local rows: { WeekPanel.DailyRow } = {}
	local done = 0

	for _, challenge in if type(payload.daily) == "table" then payload.daily else {} do
		local target = math.max(tonumber(challenge.target) or 1, 1)
		local value = math.min(tonumber(challenge.value) or 0, target)
		local finished = challenge.done == true

		if finished then
			done += 1
		end

		table.insert(rows, {
			name = tostring(challenge.name or ""),
			progress = if finished then "DONE" else ("%d/%d"):format(value, target),
			fill = if finished then 1 else value / target,
			reward = ("+%d"):format(tonumber(challenge.reward) or 0),
			done = finished,
		})
	end

	local streak = tonumber(payload.streakDays) or 0

	return {
		rows = rows,
		done = ("%d OF %d DONE"):format(done, #rows),
		streak = if streak == 1 then "1 DAY" else ("%d DAYS"):format(streak),
		lit = math.min(streak, STREAK_DOTS),
		bonus = if payload.xpBonusReady == true then "2X XP · READY" else "2X XP · USED",
	}
end

local function shop(payload: any): WeekPanel.Shop
	local road = ShopCatalog.SetRoad
	local saved = if type(payload.setRoad) == "table" then payload.setRoad else {}
	local taken = tonumber(saved.step) or 0
	local steps: { WeekPanel.ShopStep } = {}
	local collected = 0
	local nextFound = false

	for index, step in road.steps do
		local item = CosmeticsCatalog.getItem(step.cosmeticId)
		local claimed = if step.robux == 0 then saved.freeClaimed == true else index <= taken
		local state = "later"

		if claimed then
			collected += 1
			state = "claimed"
		elseif not nextFound then
			nextFound = true
			state = "next"
		end

		table.insert(steps, {
			icon = if item ~= nil then item.icon or "" else "",
			price = if step.robux == 0 then "FREE" else ("R$ %d"):format(step.robux),
			state = state,
		})
	end

	local cards: { WeekPanel.ShopCard } = {}

	for _, section in ShopCatalog.Sections do
		if section.id ~= FEATURED_SECTION then
			continue
		end

		for _, offerId in section.offers or {} do
			local offer = ShopCatalog.getOffer(offerId)

			if offer ~= nil and offer.comingSoon ~= true and #cards < SHOP_CARDS then
				table.insert(cards, {
					name = string.upper(offer.displayName),
					blurb = offer.description or "",
					price = ("R$ %d"):format(offer.robux),
					icon = offer.boardIcon or offer.icon or "",
					sticker = if offer.oneTime == true then "ONE TIME" else nil,
				})
			end
		end
	end

	return {
		title = string.upper(road.subtitle),
		steps = steps,
		collected = ("%d OF %d COLLECTED"):format(collected, #road.steps),
		fill = collected / math.max(#road.steps, 1),
		cards = cards,
	}
end

local function resetText(): string
	local left = DAY_SECONDS - math.floor(Workspace:GetServerTimeNow()) % DAY_SECONDS

	return ("NEW IN %dH %02dM"):format(left // HOUR_SECONDS, (left % HOUR_SECONDS) // 60)
end

function WeekController.new(deps: Deps): WeekController
	return setmetatable({ deps = deps, eventId = nil } :: Fields, WeekController)
end

function WeekController.start(self: WeekController)
	local deps = self.deps
	local week = deps.hud.week

	deps.hud.menu:bindHome(function()
		week:toggle()
		self:_drawWeek()
	end)
	week:bindFollow(function()
		self:_follow()
	end)
	task.spawn(function()
		self:_findEvent()
	end)
	task.spawn(function()
		self:_loadAvatar()
	end)
	week:bindShop(deps.openShop)
	week:bindPass(deps.openPass)
	week:bindQuests(deps.openQuests)
	task.spawn(function()
		while true do
			self:_drawWeek()
			deps.hud.menu:setEventLive(WeekCatalog.isLive(os.time()))
			task.wait(LIVE_CHECK_SECONDS)
		end
	end)

	Remotes.listen(deps.remotes.ProfileSync, function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		week:drawDaily(daily(payload))
		week:drawShop(shop(payload))

		local progression = payload.progression

		if type(progression) == "table" then
			local into = tonumber(progression.into) or 0
			local need = math.max(tonumber(progression.need) or 1, 1)

			week:drawPlayer({
				name = string.upper(Players.LocalPlayer.DisplayName),
				rank = ("RANK %d · %s"):format(tonumber(progression.rank) or 1, string.upper(tostring(progression.name))),
				coins = grouped(tonumber(payload.softCurrency) or 0),
				xp = if progression.maxed == true then "MAX RANK" else ("%s / %s XP"):format(grouped(into), grouped(need)),
				fill = if progression.maxed == true then 1 else into / need,
			})
		end

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

-- The hero, what is up next and the week's dates all come from the clock, so they are
-- redrawn on a timer and an event rolls over without a rejoin.
function WeekController._drawWeek(self: WeekController)
	local week = self.deps.hud.week
	local now = os.time()
	local card = hero(now)

	if card ~= nil then
		week:drawHero(card)
	end

	week:drawUpcoming(upcoming(now))
	week:drawWeek(weekLabel(now))
	week:drawReset(resetText())
end

function WeekController._loadAvatar(self: WeekController)
	local ok, image = pcall(
		Players.GetUserThumbnailAsync,
		Players,
		Players.LocalPlayer.UserId,
		Enum.ThumbnailType.HeadShot,
		AVATAR_SIZE
	)

	if ok and type(image) == "string" then
		self.deps.hud.week:setAvatar(image)
	end
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
