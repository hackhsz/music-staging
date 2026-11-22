--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WeekCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("WeekCatalog"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local MONDAY_2026_11_23 = 1795392000
local HOUR = 3600
local DAY = 86400
local SATURDAY_SHOW = MONDAY_2026_11_23 + 5 * DAY + 15 * HOUR

local function weekly(weekday: number, hourUtc: number, minutes: number): WeekCatalog.Event
	return { id = "test", title = "TEST", blurb = "", minutes = minutes, weekday = weekday, hourUtc = hourUtc }
end

return {
	["a weekly event is next on its weekday and hour"] = function()
		local show = weekly(7, 15, 45)

		expect(WeekCatalog.nextStart(show, MONDAY_2026_11_23), SATURDAY_SHOW, "from Monday")
		expect(WeekCatalog.nextStart(show, SATURDAY_SHOW + 44 * 60), SATURDAY_SHOW, "while it is on")
		expect(WeekCatalog.nextStart(show, SATURDAY_SHOW + 45 * 60), SATURDAY_SHOW + 7 * DAY, "once it is over")
	end,

	["an instant weekly event rolls to next week as it passes"] = function()
		local reset = weekly(2, 0, 0)

		expect(WeekCatalog.nextStart(reset, MONDAY_2026_11_23 - 1), MONDAY_2026_11_23, "a second before")
		expect(WeekCatalog.nextStart(reset, MONDAY_2026_11_23), MONDAY_2026_11_23 + 7 * DAY, "at the reset")
	end,

	["a one-off event is gone once it is over"] = function()
		local once: WeekCatalog.Event = { id = "test", title = "TEST", blurb = "", minutes = 30, startUtc = SATURDAY_SHOW }

		expect(WeekCatalog.nextStart(once, MONDAY_2026_11_23), SATURDAY_SHOW, "before it")
		expect(WeekCatalog.nextStart(once, SATURDAY_SHOW + 31 * 60), nil, "after it")
	end,

	["upcoming events come soonest first and the hero is a featured one"] = function()
		local list = WeekCatalog.upcoming(MONDAY_2026_11_23)

		for index = 2, #list do
			assert(list[index - 1].start <= list[index].start, "upcoming is out of order")
		end

		local hero = WeekCatalog.featured(MONDAY_2026_11_23)

		assert(hero ~= nil and hero.event.featured == true, "no featured event for the hero")
		expect(WeekCatalog.isLive(SATURDAY_SHOW + 60), true, "live during the show")
		expect(WeekCatalog.isLive(SATURDAY_SHOW - 60), false, "not live before it")
	end,
}
