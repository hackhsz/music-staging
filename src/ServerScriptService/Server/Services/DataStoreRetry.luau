--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local BUDGET_POLL_SECONDS = 0.25

export type Options = {
	attempts: number,
	baseDelaySeconds: number,
	waitAfterFinalFailure: boolean?,
}

local DataStoreRetry = {}

function DataStoreRetry.waitForBudget(requestType: Enum.DataStoreRequestType)
	if RunService:IsStudio() then
		return
	end

	while DataStoreService:GetRequestBudgetForRequestType(requestType) <= 0 do
		task.wait(BUDGET_POLL_SECONDS)
	end
end

-- Waits baseDelaySeconds * attempt after a failed attempt. Returns ok and the
-- callback's result, or the last error.
function DataStoreRetry.run(requestType: Enum.DataStoreRequestType, options: Options, callback: () -> any): (boolean, any)
	local lastError = nil

	for attempt = 1, options.attempts do
		DataStoreRetry.waitForBudget(requestType)

		local ok, result = pcall(callback)

		if ok then
			return true, result
		end

		lastError = result

		if attempt < options.attempts or options.waitAfterFinalFailure == true then
			task.wait(options.baseDelaySeconds * attempt)
		end
	end

	return false, lastError
end

return DataStoreRetry
