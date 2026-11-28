local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: {
	calls: { [Player]: { [string]: { windowStart: number, count: number } } },
}, RateLimiter))

function RateLimiter.new(): RateLimiter
	return setmetatable({
		calls = {},
	}, RateLimiter)
end

function RateLimiter:allow(player: Player, key: string, maxPerSecond: number, now: number?): boolean
	local currentTime = now or os.clock()
	local playerCalls = self.calls[player]

	if playerCalls == nil then
		playerCalls = {}
		self.calls[player] = playerCalls
	end

	local bucket = playerCalls[key]

	if bucket == nil or currentTime - bucket.windowStart >= 1 then
		playerCalls[key] = {
			windowStart = currentTime,
			count = 1,
		}
		return true
	end

	if bucket.count >= maxPerSecond then
		return false
	end

	bucket.count += 1
	return true
end

function RateLimiter:clear(player: Player)
	self.calls[player] = nil
end

return RateLimiter

