--!strict
local StagePassCatalog = require(script.Parent.StagePassCatalog)

-- What the This Week board announces. Add, change or remove a beat of the week by editing
-- Events: a weekly one gives weekday and hourUtc, a one-off gives startUtc. Only list things
-- the game really does; the board promises whatever is here.
local WeekCatalog = {}

export type Event = {
	id: string,
	title: string,
	blurb: string,
	minutes: number,
	-- The sticker on the hero's art; nil leaves it off.
	sticker: string?,
	-- A featured event can take the hero card; the others only show under UP NEXT.
	featured: boolean?,
	-- Has a Roblox experience event the player can follow.
	followable: boolean?,
	-- os.date's wday: Sunday is 1, Saturday is 7.
	weekday: number?,
	hourUtc: number?,
	startUtc: number?,
}
export type Upcoming = { event: Event, start: number }

local DAY_SECONDS = 86400
local WEEK_SECONDS = 7 * DAY_SECONDS
local MONDAY = 2
local SATURDAY = 7

WeekCatalog.Events = {
	{
		id = "live-show",
		title = "SATURDAY LIVE SHOW",
		blurb = "Play the week's new song together.",
		sticker = "NEW SONG",
		minutes = 45,
		featured = true,
		followable = true,
		weekday = SATURDAY,
		hourUtc = 15,
	},
	{
		id = "league-results",
		title = "LEAGUE RESULTS",
		blurb = "The top places move up a tier and everyone is paid.",
		minutes = 0,
		weekday = MONDAY,
		hourUtc = 0,
	},
	{
		id = "season-end",
		title = StagePassCatalog.Season.name .. " ENDS",
		blurb = "Last day to claim this season's Stage Pass rewards.",
		minutes = 0,
		startUtc = StagePassCatalog.endsUtc(),
	},
} :: { Event }

-- When the event next starts, in UTC seconds; one that is on now counts as next. nil once a
-- one-off is over, or for an entry with no time at all.
function WeekCatalog.nextStart(event: Event, now: number): number?
	local length = event.minutes * 60

	if event.startUtc ~= nil then
		return if event.startUtc + length > now then event.startUtc else nil
	end

	if event.weekday == nil or event.hourUtc == nil then
		return nil
	end

	local date = os.date("!*t", now) :: any
	local midnight = now - (date.hour * 3600 + date.min * 60 + date.sec)
	local start = midnight + ((event.weekday - date.wday) % 7) * DAY_SECONDS + event.hourUtc * 3600

	if start + length <= now then
		start += WEEK_SECONDS
	end

	return start
end

-- Every event still to come, soonest first.
function WeekCatalog.upcoming(now: number): { Upcoming }
	local list: { Upcoming } = {}

	for _, event in WeekCatalog.Events do
		local start = WeekCatalog.nextStart(event, now)

		if start ~= nil then
			table.insert(list, { event = event, start = start })
		end
	end

	table.sort(list, function(a, b)
		return a.start < b.start
	end)

	return list
end

-- The event the hero card shows: the soonest featured one.
function WeekCatalog.featured(now: number): Upcoming?
	for _, entry in WeekCatalog.upcoming(now) do
		if entry.event.featured == true then
			return entry
		end
	end

	return nil
end

function WeekCatalog.isLive(now: number): boolean
	local entry = WeekCatalog.featured(now)

	return entry ~= nil and now >= entry.start and now < entry.start + entry.event.minutes * 60
end

return WeekCatalog
