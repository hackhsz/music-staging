--!strict
local ArrivalLedger = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ArrivalLedger"))

local CONFIG: ArrivalLedger.Config = {
	band = 0.08,
	warmupBand = 0.25,
	warmupReports = 5,
	smoothing = 0.2,
	confirmSeconds = 0.5,
	keepSeconds = 3,
	futureTolerance = 0.05,
}

local function expect(actual: any, wanted: any, what: string)
	assert(actual == wanted, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

local function close(actual: number?, wanted: number, what: string)
	assert(actual ~= nil and math.abs(actual - wanted) < 1e-6, string.format("%s: expected %s, got %s", what, tostring(wanted), tostring(actual)))
end

-- Lands on (x, y) at `at`; the report arrives `latency` later and the server
-- sees the position `delay` after the landing.
local function move(ledger: ArrivalLedger.ArrivalLedger, x: number, y: number, at: number, latency: number, delay: number): string?
	local refused = ledger:submit(x, y, at, at + latency, { x = 0, y = 0 }, 0)

	if refused ~= nil then
		return refused
	end

	local reasons = ledger:onPositionSeen(x, y, at + delay)

	return reasons[1]
end

local function settled(): ArrivalLedger.ArrivalLedger
	local ledger = ArrivalLedger.new(CONFIG)

	for index = 1, 6 do
		assert(move(ledger, 1 + index % 2, 1, index, 0.05, 0.2) == nil, "warm-up move refused")
	end

	return ledger
end

return {
	["a report that beats its position waits, then counts"] = function()
		local ledger = ArrivalLedger.new(CONFIG)

		expect(ledger:submit(2, 1, 10, 10.05, { x = 1, y = 1 }, 9), nil, "refused while pending")
		assert(ledger:hasPending(2, 1), "should be pending")
		expect(ledger:nearestUnused(2, 1, 10, 0.1), nil, "a pending report must not be judged")

		expect(#ledger:onPositionSeen(2, 1, 10.2), 0, "position arrived")
		assert(not ledger:hasPending(2, 1), "should be confirmed")
		local claim = ledger:nearestUnused(2, 1, 10, 0.1)
		assert(claim ~= nil, "confirmed report should be usable")
		close(claim.at, 10, "claimed landing")
	end,

	["a report whose position never shows up is thrown out"] = function()
		local ledger = ArrivalLedger.new(CONFIG)
		ledger:submit(3, 1, 10, 10.05, { x = 1, y = 1 }, 9)

		expect(#ledger:expire(10.3), 0, "still inside the confirm window")
		local reasons = ledger:expire(10.6)
		expect(reasons[1], "arrival_without_position", "expiry reason")
		assert(not ledger:hasPending(3, 1), "expired report should be gone")
	end,

	["once settled, a shifted landing time is pulled back to the band"] = function()
		local ledger = settled()

		-- Claims to have landed 0.2 s earlier than the position says; the move is
		-- real, so it stays, but it may only gain the band's 0.08 s.
		expect(move(ledger, 1, 1, 20, 0.05, 0.4), "adjusted_arrival_time", "shifted claim")
		local claim = ledger:nearestUnused(1, 1, 20.2, 0.5)
		assert(claim ~= nil, "the step must still count")
		close(claim.at, 20.4 - 0.2 - 0.08, "time pulled to the band edge")
		expect(move(ledger, 1, 1, 21, 0.05, 0.22), nil, "honest claim inside the band")
	end,

	["a step in place is checked against how long reports take"] = function()
		local ledger = settled()
		local here = { x = 2, y = 1 }

		expect(ledger:submit(2, 1, 30, 30.06, here, 25), nil, "honest stomp")
		assert(ledger:nearestUnused(2, 1, 30, 0.05) ~= nil, "stomp should be usable at once")

		expect(ledger:submit(2, 1, 31, 31.3, here, 25), "implausible_arrival_time", "back-dated stomp")
	end,

	["a quick repeat before the server catches up still counts"] = function()
		local ledger = settled()
		local elsewhere = { x = 1, y = 1 }

		-- Lands on (3, 1), then steps in place 0.12 s later; the server only sees
		-- the arrival after both reports are in.
		expect(ledger:submit(3, 1, 70, 70.05, elsewhere, 60), nil, "arrival report")
		expect(ledger:submit(3, 1, 70.12, 70.17, elsewhere, 60), nil, "repeat report")
		expect(#ledger:onPositionSeen(3, 1, 70.2), 0, "both should fit")

		assert(ledger:nearestUnused(3, 1, 70, 0.05) ~= nil, "the arrival counts")
		assert(ledger:nearestUnused(3, 1, 70.12, 0.05) ~= nil, "the repeat counts")
	end,

	["a lane press counts at once and can be matched to a note"] = function()
		local ledger = ArrivalLedger.new(CONFIG)

		expect(ledger:submitPress(2, 80, 80.06), nil, "press refused")
		local press = ledger:nearestUnused(2, 1, 80.02, 0.1)
		assert(press ~= nil, "the press should match a note on its lane")
		expect(ledger:nearestUnused(3, 1, 80.02, 0.1), nil, "a press only counts on its own lane")
	end,

	["once settled, a back-dated press is refused"] = function()
		local ledger = ArrivalLedger.new(CONFIG)

		for index = 1, 6 do
			expect(ledger:submitPress(1, index, index + 0.05), nil, "warm-up press " .. index)
		end

		expect(ledger:submitPress(1, 10, 10.3), "implausible_press_time", "press claimed 0.25 s early")
		expect(ledger:submitPress(1, 11, 11.06), nil, "honest press")
	end,

	["a hold's release is found in its own lane and window only"] = function()
		local ledger = ArrivalLedger.new(CONFIG)
		expect(ledger:submitPress(2, 90, 90.05), nil, "press")
		expect(ledger:submitRelease(2, 90.8, 90.85), nil, "release")
		expect(ledger:submitRelease(3, 90.5, 90.55), nil, "other lane")

		expect(ledger:releaseBetween(2, 90, 91), 90.8, "the lane's release")
		expect(ledger:releaseBetween(2, 90.9, 91.5), nil, "nothing in a later window")
		expect(ledger:releaseBetween(4, 90, 91), nil, "nothing on a lane never released")
	end,

	["a back-dated release is refused like a press"] = function()
		local ledger = ArrivalLedger.new(CONFIG)

		for index = 1, 6 do
			expect(ledger:submitPress(1, index, index + 0.05), nil, "warm-up press " .. index)
		end

		expect(ledger:submitRelease(1, 10, 10.3), "implausible_release_time", "release claimed 0.25 s early")
	end,

	["reports from the future or the distant past are refused"] = function()
		local ledger = ArrivalLedger.new(CONFIG)
		expect(ledger:submit(1, 1, 11, 10, nil, nil), "future_arrival", "future")
		expect(ledger:submit(1, 1, 9, 10, nil, nil), "stale_arrival", "stale")
	end,

	["each report is spent on one note"] = function()
		local ledger = settled()
		assert(move(ledger, 4, 1, 40, 0.05, 0.2) == nil, "move refused")

		local claim = ledger:nearestUnused(4, 1, 40, 0.1)
		assert(claim ~= nil, "should match")
		claim.used = true
		expect(ledger:nearestUnused(4, 1, 40, 0.1), nil, "a used report must not match twice")
	end,

	["the nearest report to the beat wins"] = function()
		local ledger = settled()
		local here = { x = 3, y = 1 }
		assert(move(ledger, 3, 1, 50, 0.05, 0.2) == nil, "move refused")
		expect(ledger:submit(3, 1, 50.4, 50.45, here, 50.2), nil, "stomp refused")

		local claim = ledger:nearestUnused(3, 1, 50.35, 0.18)
		assert(claim ~= nil, "should match")
		close(claim.at, 50.4, "picked the nearer stomp")
	end,

	["a stay starts at the first landing, not at later stomps"] = function()
		local ledger = settled()
		local here = { x = 2, y = 1 }
		assert(move(ledger, 2, 1, 60, 0.05, 0.2) == nil, "move refused")
		expect(ledger:submit(2, 1, 60.5, 60.55, here, 60.2), nil, "stomp refused")

		close(ledger:arrivalOn(2, 1, 61), 60, "arrival")
		assert(move(ledger, 1, 1, 61.5, 0.05, 0.2) == nil, "move away refused")
		expect(ledger:arrivalOn(2, 1, 62), nil, "the player has left the tile")
	end,

	["a clap is kept apart from the landings and checked for timing"] = function()
		local ledger = ArrivalLedger.new(CONFIG)
		expect(ledger:submitClap(10, 10.1), nil, "a fresh clap")
		expect(#ledger.claps, 1, "kept")
		expect(#ledger.claims, 0, "not a landing")
		expect(ledger:submitClap(11, 10.9), "future_arrival", "from the future")
		expect(ledger:submitClap(10, 11), "stale_arrival", "too old")

		ledger.latency = 0.1
		ledger.samples = CONFIG.warmupReports
		expect(ledger:submitClap(12, 12.4), "implausible_clap_time", "far off the usual latency")
		expect(#ledger.claps, 1, "refused claps are not kept")

		ledger:expire(10 + CONFIG.keepSeconds + 1)
		expect(#ledger.claps, 0, "old claps expire")
	end,
}
