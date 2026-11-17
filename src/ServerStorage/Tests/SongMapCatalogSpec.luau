--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ScoreSummary = require(Shared:WaitForChild("ScoreSummary"))
local SongMapCatalog = require(Shared:WaitForChild("SongMapCatalog"))

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function chart(difficulty: string, notesPerSecond: number, bpm: number, extra: { any }?): any
	local steps = table.clone(extra or {})

	for index = 1, math.floor(notesPerSecond * 100) do
		table.insert(steps, { beat = index, x = 3, y = 3 })
	end

	return { difficulty = difficulty, bpm = bpm, durationSeconds = 100, steps = steps }
end

return {
	["every chart in the catalog rates one to five stars"] = function()
		for _, map in SongMapCatalog.Maps do
			local stars = SongMapCatalog.starRating(map)
			assert(stars >= 1 and stars <= 5, ("%s rated %d"):format(map.id, stars))
		end
	end,

	["a harder chart of a song never has fewer stars"] = function()
		local order = { easy = 1, normal = 2, hard = 3, expert = 4 }
		local bySong: { [string]: { any } } = {}

		for _, map in SongMapCatalog.Maps do
			bySong[map.title] = bySong[map.title] or {}
			table.insert(bySong[map.title], map)
		end

		for title, maps in bySong do
			table.sort(maps, function(a, b)
				return (order[a.difficulty] or 2) < (order[b.difficulty] or 2)
			end)

			for index = 2, #maps do
				assert(
					SongMapCatalog.starRating(maps[index]) >= SongMapCatalog.starRating(maps[index - 1]),
					("%s %s rates below %s"):format(title, maps[index].difficulty, maps[index - 1].difficulty)
				)
			end
		end
	end,

	["denser and faster charts rate higher"] = function()
		expect(SongMapCatalog.starRating(chart("easy", 0.8, 100)), 1, "sparse easy")
		assert(
			SongMapCatalog.starRating(chart("normal", 2, 150)) > SongMapCatalog.starRating(chart("normal", 1, 100)),
			"denser and faster"
		)
		expect(SongMapCatalog.starRating(chart("expert", 3, 160)), 5, "dense fast expert")
	end,

	["items and danger tiles are not counted as notes"] = function()
		local extras = {}

		for index = 1, 100 do
			table.insert(extras, { beat = index, x = 1, y = 1, type = if index % 2 == 0 then "item" else "danger" })
		end

		local plain = chart("normal", 1, 120)
		local padded = chart("normal", 1, 120, extras)
		expect(SongMapCatalog.starRating(padded), SongMapCatalog.starRating(plain), "items ignored")
	end,

	["a better rank replaces the best, a worse one never does"] = function()
		expect(ScoreSummary.isBetterRank("A", nil), true, "first clear")
		expect(ScoreSummary.isBetterRank("S", "A"), true, "S beats A")
		expect(ScoreSummary.isBetterRank("B", "A"), false, "B does not beat A")
		expect(ScoreSummary.isBetterRank("A", "A"), false, "a tie keeps the best")
		expect(ScoreSummary.isBetterRank(nil, "C"), false, "no rank")
	end,
}
