--!strict
-- The This Week board's fixed beats: the Saturday Live Show slot and the league board it shows.
local WeekCatalog = {}

local DAY_SECONDS = 86400
local WEEK_SECONDS = 7 * DAY_SECONDS
-- os.date's wday counts from Sunday = 1, so Saturday is 7.
local SATURDAY = 7

WeekCatalog.LiveShow = {
	name = "Saturday Live Show",
	weekday = SATURDAY,
	hourUtc = 15,
	minutes = 45,
	blurb = "Play the week's new song together.",
}

WeekCatalog.ShopPicks = 3

-- When the next Live Show starts, in UTC seconds; one that is on now counts as next.
function WeekCatalog.nextShow(now: number): number
	local show = WeekCatalog.LiveShow
	local date = os.date("!*t", now) :: any
	local midnight = now - (date.hour * 3600 + date.min * 60 + date.sec)
	local start = midnight + ((show.weekday - date.wday) % 7) * DAY_SECONDS + show.hourUtc * 3600

	if start + show.minutes * 60 <= now then
		start += WEEK_SECONDS
	end

	return start
end

function WeekCatalog.isLive(now: number): boolean
	local start = WeekCatalog.nextShow(now)

	return now >= start and now < start + WeekCatalog.LiveShow.minutes * 60
end

return WeekCatalog
