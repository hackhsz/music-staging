--!strict
-- One run's landing reports from the client, each checked against what the
-- server saw before the judge may use it.
--
-- A report usually reaches the server before the character position it
-- describes, so a report for a tile the server has not seen yet waits as pending
-- until the position catches up. A report for the tile the player already
-- stands on is a step in place; there is no new position to check it against,
-- so its timing is checked against how long reports normally take to arrive.
-- Either way a cheater can shift a claimed time by at most `band`.
--
-- Pure: times are passed in, so it can be unit-tested without a runtime.

local ArrivalLedger = {}
ArrivalLedger.__index = ArrivalLedger

export type Config = {
	band: number,
	warmupBand: number,
	warmupReports: number,
	smoothing: number,
	confirmSeconds: number,
	keepSeconds: number,
	futureTolerance: number,
}

export type Claim = {
	x: number,
	y: number,
	at: number,
	pressAt: number?,
	receivedAt: number,
	confirmed: boolean,
	used: boolean,
}

type Release = {
	lane: number,
	at: number,
}

export type Clap = {
	at: number,
	used: boolean,
}

type Fields = {
	config: Config,
	claims: { Claim },
	releases: { Release },
	claps: { Clap },
	delay: number?,
	latency: number?,
	samples: number,
}

export type ArrivalLedger = typeof(setmetatable({} :: Fields, ArrivalLedger))

type Coord = { x: number, y: number }

function ArrivalLedger.new(config: Config): ArrivalLedger
	local fields: Fields = {
		config = config,
		claims = {},
		releases = {},
		claps = {},
		delay = nil,
		latency = nil,
		samples = 0,
	}

	return setmetatable(fields, ArrivalLedger)
end

local function smooth(estimate: number?, sample: number, factor: number): number
	return if estimate == nil then sample else estimate + (sample - estimate) * factor
end

function ArrivalLedger._band(self: ArrivalLedger): number
	return if self.samples < self.config.warmupReports then self.config.warmupBand else self.config.band
end

function ArrivalLedger._fits(self: ArrivalLedger, sample: number, estimate: number?): boolean
	if sample < -self.config.futureTolerance or sample > self.config.confirmSeconds then
		return false
	end

	return estimate == nil or math.abs(sample - estimate) <= self:_band()
end

-- The position proves the move happened, so a report whose time sits outside the
-- band is kept with its time pulled to the band's edge rather than thrown out: a
-- real step is never lost, and a shifted claim still gains at most `band`.
-- Returns whether the move counts and whether its time had to be moved.
function ArrivalLedger._confirmMove(self: ArrivalLedger, claim: Claim, seenAt: number): (boolean, boolean)
	local delay = seenAt - claim.at

	if delay < -self.config.futureTolerance or delay > self.config.confirmSeconds then
		return false, false
	end

	local estimate = self.delay

	if estimate ~= nil and math.abs(delay - estimate) > self:_band() then
		local kept = estimate + math.clamp(delay - estimate, -self:_band(), self:_band())
		local shift = (seenAt - kept) - claim.at
		claim.at += shift

		if claim.pressAt ~= nil then
			claim.pressAt = (claim.pressAt :: number) + shift
		end

		claim.confirmed = true
		self.delay = smooth(self.delay, delay, self.config.smoothing)
		self.samples += 1

		return true, true
	end

	claim.confirmed = true
	self.delay = smooth(self.delay, delay, self.config.smoothing)
	self.latency = smooth(self.latency, claim.receivedAt - claim.at, self.config.smoothing)
	self.samples += 1

	return true, false
end

-- Returns a suspicious-activity reason when the report is refused.
function ArrivalLedger.submit(
	self: ArrivalLedger,
	x: number,
	y: number,
	claimedAt: number,
	receivedAt: number,
	seen: Coord?,
	seenSince: number?
): string?
	if claimedAt > receivedAt + self.config.futureTolerance then
		return "future_arrival"
	end

	if receivedAt - claimedAt > self.config.confirmSeconds then
		return "stale_arrival"
	end

	local claim: Claim = {
		x = x,
		y = y,
		at = claimedAt,
		receivedAt = receivedAt,
		confirmed = false,
		used = false,
	}
	local alreadyThere = seen ~= nil and seenSince ~= nil and seen.x == x and seen.y == y

	if alreadyThere and (seenSince :: number) >= claimedAt - self.config.futureTolerance then
		if not (self:_confirmMove(claim, seenSince :: number)) then
			return "implausible_arrival_time"
		end
	elseif alreadyThere then
		if not self:_fits(receivedAt - claimedAt, self.latency) then
			return "implausible_arrival_time"
		end

		claim.confirmed = true
	end

	table.insert(self.claims, claim)

	return nil
end

-- A lane press in the highway mode has no position at all to check against,
-- so its time is only checked against how long this player's reports take to
-- arrive. Presses are kept as confirmed claims on (lane, 1).
function ArrivalLedger.submitPress(self: ArrivalLedger, lane: number, claimedAt: number, receivedAt: number): string?
	if claimedAt > receivedAt + self.config.futureTolerance then
		return "future_arrival"
	end

	local latency = receivedAt - claimedAt

	if latency > self.config.confirmSeconds then
		return "stale_arrival"
	end

	if not self:_fits(latency, self.latency) then
		return "implausible_press_time"
	end

	self.latency = smooth(self.latency, latency, self.config.smoothing)
	self.samples += 1
	table.insert(self.claims, {
		x = lane,
		y = 1,
		at = claimedAt,
		receivedAt = receivedAt,
		confirmed = true,
		used = false,
	})

	return nil
end

-- A lane let go, for holds. Checked against the same arrival time as presses,
-- but it does not teach the estimate: only presses do.
function ArrivalLedger.submitRelease(self: ArrivalLedger, lane: number, claimedAt: number, receivedAt: number): string?
	if claimedAt > receivedAt + self.config.futureTolerance then
		return "future_arrival"
	end

	local latency = receivedAt - claimedAt

	if latency > self.config.confirmSeconds then
		return "stale_arrival"
	end

	if not self:_fits(latency, self.latency) then
		return "implausible_release_time"
	end

	table.insert(self.releases, { lane = lane, at = claimedAt })

	return nil
end

-- A clap has no position either. Like a release it is checked against the
-- press arrival time but does not teach it, and it is never a landing.
function ArrivalLedger.submitClap(self: ArrivalLedger, claimedAt: number, receivedAt: number): string?
	if claimedAt > receivedAt + self.config.futureTolerance then
		return "future_arrival"
	end

	local latency = receivedAt - claimedAt

	if latency > self.config.confirmSeconds then
		return "stale_arrival"
	end

	if not self:_fits(latency, self.latency) then
		return "implausible_clap_time"
	end

	table.insert(self.claps, { at = claimedAt, used = false })

	return nil
end

-- The first time a lane was let go after `from` and no later than `to`.
function ArrivalLedger.releaseBetween(self: ArrivalLedger, lane: number, from: number, to: number): number?
	local first: number? = nil

	for _, release in self.releases do
		if release.lane == lane and release.at > from and release.at <= to then
			if first == nil or release.at < first then
				first = release.at
			end
		end
	end

	return first
end

-- The server has just seen the player arrive on a tile. The earliest pending
-- report on it is that arrival; any later one is a step in place made before
-- the server caught up. Returns a reason for every report that does not fit.
function ArrivalLedger.onPositionSeen(self: ArrivalLedger, x: number, y: number, seenAt: number): { string }
	local reasons = {}
	local arrived = false
	local index = 1

	while index <= #self.claims do
		local claim = self.claims[index]
		local fits = true

		if not claim.confirmed and claim.x == x and claim.y == y then
			if arrived then
				fits = self:_fits(claim.receivedAt - claim.at, self.latency)
				claim.confirmed = fits
			else
				local adjusted
				fits, adjusted = self:_confirmMove(claim, seenAt)
				arrived = fits

				if adjusted then
					table.insert(reasons, "adjusted_arrival_time")
				end
			end
		end

		if fits then
			index += 1
		else
			table.remove(self.claims, index)
			table.insert(reasons, "implausible_arrival_time")
		end
	end

	return reasons
end

-- Drops what is too old to matter. Returns a reason for every report whose
-- position never showed up.
function ArrivalLedger.expire(self: ArrivalLedger, now: number): { string }
	local reasons = {}

	for index = #self.claims, 1, -1 do
		local claim = self.claims[index]

		if not claim.confirmed and now - claim.receivedAt > self.config.confirmSeconds then
			table.remove(self.claims, index)
			table.insert(reasons, "arrival_without_position")
		elseif now - claim.at > self.config.keepSeconds then
			table.remove(self.claims, index)
		end
	end

	for index = #self.releases, 1, -1 do
		if now - self.releases[index].at > self.config.keepSeconds then
			table.remove(self.releases, index)
		end
	end

	for index = #self.claps, 1, -1 do
		if now - self.claps[index].at > self.config.keepSeconds then
			table.remove(self.claps, index)
		end
	end

	return reasons
end

function ArrivalLedger.hasPending(self: ArrivalLedger, x: number, y: number): boolean
	for _, claim in self.claims do
		if not claim.confirmed and claim.x == x and claim.y == y then
			return true
		end
	end

	return false
end

-- The confirmed, unused landing on a tile closest to `expectedAt`, within `window`.
function ArrivalLedger.nearestUnused(self: ArrivalLedger, x: number, y: number, expectedAt: number, window: number): Claim?
	local best: Claim? = nil
	local bestDistance = window

	for _, claim in self.claims do
		if claim.confirmed and not claim.used and claim.x == x and claim.y == y then
			local distance = math.abs(claim.at - expectedAt)

			if distance <= bestDistance then
				best = claim
				bestDistance = distance
			end
		end
	end

	return best
end

-- When the player's current stay on a tile began, as of `before`, by confirmed
-- reports. Steps in place on the same tile do not restart the stay.
function ArrivalLedger.arrivalOn(self: ArrivalLedger, x: number, y: number, before: number): number?
	local arrival: number? = nil

	for index = #self.claims, 1, -1 do
		local claim = self.claims[index]

		if claim.confirmed and claim.at <= before then
			if claim.x ~= x or claim.y ~= y then
				break
			end

			arrival = claim.at
		end
	end

	return arrival
end

function ArrivalLedger.getDelay(self: ArrivalLedger): number?
	return self.delay
end

return ArrivalLedger
