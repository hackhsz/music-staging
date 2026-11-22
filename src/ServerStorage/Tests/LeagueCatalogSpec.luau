--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LeagueCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("LeagueCatalog"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local MONDAY_2026_11_23 = 1795392000

return {
	["weeks turn over at Monday 00:00 UTC"] = function()
		local week = LeagueCatalog.weekOf(MONDAY_2026_11_23)

		expect(LeagueCatalog.weekOf(MONDAY_2026_11_23 - 1), week - 1, "a second before Monday")
		expect(LeagueCatalog.weekOf(MONDAY_2026_11_23 + 6 * 86400), week, "Sunday")
		expect(LeagueCatalog.resetsAt(week), MONDAY_2026_11_23 + 7 * 86400, "reset time")
	end,

	["points are the sum of the best five different songs"] = function()
		local best, points = {}, 0

		for index, score in { 100, 500, 300, 200, 400, 50, 600 } do
			best, points = LeagueCatalog.addScore(best, "song" .. index, score)
		end

		expect(points, 600 + 500 + 400 + 300 + 200, "points")
	end,

	["replaying one song only keeps its best score"] = function()
		local best, points = {}, 0

		for _, score in { 900, 950, 920, 990, 980 } do
			best, points = LeagueCatalog.addScore(best, "same", score)
		end

		expect(points, 990, "one song counts once")
	end,

	["top five move up and the bottom five move down in a full group"] = function()
		expect(LeagueCatalog.movement(1, 30), "up", "first")
		expect(LeagueCatalog.movement(5, 30), "up", "fifth")
		expect(LeagueCatalog.movement(6, 30), "stay", "sixth")
		expect(LeagueCatalog.movement(25, 30), "stay", "25th")
		expect(LeagueCatalog.movement(26, 30), "down", "26th")
	end,

	["small groups never demote the stay zone and tiny groups never move"] = function()
		expect(LeagueCatalog.movement(10, 10), "stay", "last of ten")
		expect(LeagueCatalog.movement(1, 9), "stay", "first of nine")
		expect(LeagueCatalog.movement(nil, 30), "stay", "unranked")
		expect(LeagueCatalog.movement(14, 14), "down", "last of fourteen")
	end,

	["tiers clamp to the table"] = function()
		expect(LeagueCatalog.clampTier(0), 1, "below")
		expect(LeagueCatalog.clampTier(99), #LeagueCatalog.Tiers, "above")
		expect(LeagueCatalog.clampTier("x"), 1, "junk")
	end,
}
