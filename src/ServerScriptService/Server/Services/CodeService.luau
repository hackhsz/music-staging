--!strict
-- Promo codes from the Rewards window. The list lives on the server so a client
-- cannot read the codes out of ReplicatedStorage; each pays once per player.

type Code = {
	coins: number,
	-- Unix seconds after which the code stops working; nil never expires.
	expiresAt: number?,
}

local MAX_CODE_LENGTH = 32

local CODES: { [string]: Code } = {
	WELCOME = { coins = 100 },
	ENCORE = { coins = 250 },
}

local CodeService = {}
CodeService.__index = CodeService

export type CodeService = typeof(setmetatable({} :: { playerDataService: any }, CodeService))

function CodeService.new(playerDataService: any): CodeService
	return setmetatable({ playerDataService = playerDataService }, CodeService)
end

function CodeService.normalize(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

-- Returns (ok, reason, coins paid).
function CodeService.redeem(self: CodeService, player: Player, text: string, now: number?): (boolean, string, number)
	local profile = self.playerDataService:get(player)

	if profile == nil then
		return false, "profile_not_loaded", 0
	end

	local key = CodeService.normalize(text)
	local code = if #key <= MAX_CODE_LENGTH then CODES[key] else nil

	if code == nil then
		return false, "unknown_code", 0
	end

	if code.expiresAt ~= nil and (now or os.time()) > code.expiresAt then
		return false, "code_expired", 0
	end

	if type(profile.redeemedCodes) ~= "table" then
		profile.redeemedCodes = {}
	end

	if profile.redeemedCodes[key] == true then
		return false, "already_redeemed", 0
	end

	profile.redeemedCodes[key] = true
	profile.softCurrency = (profile.softCurrency or 0) + code.coins
	self.playerDataService:markDirty(player)

	return true, "code_redeemed", code.coins
end

return CodeService
