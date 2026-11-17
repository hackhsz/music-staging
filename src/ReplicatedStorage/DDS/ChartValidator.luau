--!strict
-- Chart rule validation. Reachability is one tile per beat plus one, measured
-- from the last positioned event (STEP/SHAPE); a DANGER between two positioned
-- events costs one extra tile for the dodge. A DANGER itself must leave a safe
-- tile within reach of the last position. An ITEM is optional: it must be reachable and
-- must not strand the next target, but it never becomes the anchor.

local ChartValidator = {}

local GRID_SIZE = 5

local function worstDist(tilesA, tilesB): number
	local worst = 0
	for _, a in tilesA do
		local best = math.huge
		for _, b in tilesB do
			local d = math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
			if d < best then best = d end
		end
		if best > worst then worst = best end
	end
	return worst
end

local function safeTiles(dangerTiles)
	local blocked = {}
	for _, rc in dangerTiles do
		blocked[rc[1] * GRID_SIZE + rc[2]] = true
	end
	local safe = {}
	for r = 0, GRID_SIZE - 1 do
		for c = 0, GRID_SIZE - 1 do
			if not blocked[r * GRID_SIZE + c] then
				table.insert(safe, { r, c })
			end
		end
	end
	return safe
end

function ChartValidator.allowedDist(deltaBeats: number): number
	return math.max(1, deltaBeats + 1)
end

local function checkItem(events, k: number, anchor, dodgesSinceAnchor: number, issues: { string })
	local item = events[k]
	if item.item == nil then
		table.insert(issues, `event {k}: ITEM has no item id`)
	end
	local reach = worstDist(anchor.tiles, item.tiles) + dodgesSinceAnchor
	if reach > ChartValidator.allowedDist(item.beat - anchor.beat) then
		table.insert(issues, `event {k}: item unreachable {reach} (beats {anchor.beat}->{item.beat})`)
	end
	for n = k + 1, #events do
		local nextEvent = events[n]
		if nextEvent.kind == "STEP" or nextEvent.kind == "SHAPE" then
			local onward = worstDist(item.tiles, nextEvent.tiles)
			if onward > ChartValidator.allowedDist(nextEvent.beat - item.beat) then
				table.insert(issues, `event {k}: item strands the next target {onward} (beats {item.beat}->{nextEvent.beat})`)
			end
			return
		end
	end
end

function ChartValidator.validate(chart): { string }
	local issues = {}
	local events = chart.events
	if #events == 0 then
		table.insert(issues, "chart has no events")
		return issues
	end
	local anchor = events[1]
	local dodgesSinceAnchor = 0
	for k = 2, #events do
		local prev, cur = events[k - 1], events[k]
		local delta = cur.beat - prev.beat
		if delta <= 0 then
			table.insert(issues, `event {k}: non-increasing beat {cur.beat}`)
		end
		local allowed = ChartValidator.allowedDist(cur.beat - anchor.beat)
		if cur.kind == "ITEM" then
			checkItem(events, k, anchor, dodgesSinceAnchor, issues)
			continue
		end
		if cur.kind == "DANGER" then
			local safe = safeTiles(cur.tiles)
			if #safe == 0 then
				table.insert(issues, `event {k}: danger covers the whole board`)
			else
				local d = worstDist(anchor.tiles, safe) + dodgesSinceAnchor
				if d > allowed then
					table.insert(issues, `event {k}: no safe tile within reach {d} > {allowed} (beats {anchor.beat}->{cur.beat})`)
				end
			end
			dodgesSinceAnchor += 1
		else
			local d = worstDist(anchor.tiles, cur.tiles) + dodgesSinceAnchor
			if d > allowed then
				table.insert(issues, `event {k}: reachability {d} > {allowed} (beats {anchor.beat}->{cur.beat})`)
			end
			anchor = cur
			dodgesSinceAnchor = 0
		end
	end
	for k, ev in events do
		for _, t in ev.tiles do
			if t[1] < 0 or t[1] > 4 or t[2] < 0 or t[2] > 4 then
				table.insert(issues, `event {k}: tile off board ({t[1]},{t[2]})`)
			end
		end
		if ev.kind == "SHAPE" and ev.beat % 4 ~= 0 then
			table.insert(issues, `event {k}: shape off downbeat (beat {ev.beat})`)
		end
	end
	local last = events[#events]
	if last.kind ~= "STEP" then
		table.insert(issues, "final event is not a STEP")
	else
		local r, c = last.tiles[1][1], last.tiles[1][2]
		if r < 1 or r > 3 or c < 1 or c > 3 then
			table.insert(issues, `final target not interior ({r},{c})`)
		end
	end
	return issues
end

return ChartValidator
