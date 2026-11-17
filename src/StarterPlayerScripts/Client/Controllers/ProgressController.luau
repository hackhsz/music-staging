--!strict
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local MAX_ACHIEVEMENT_TOASTS = 2
local RANK_UP_SOUND = "cheerEnd"
local TOAST_SOUND = "uiBuy"

type Popup = (done: () -> ()) -> ()

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	sfx: any,
}

type Fields = {
	deps: Deps,
	queue: { Popup },
	playing: boolean,
}

-- What a finished run gained, shown one at a time once the results have revealed:
-- the stage-up reveal, then achievements, then finished daily challenges.
local ProgressController = {}
ProgressController.__index = ProgressController

export type ProgressController = typeof(setmetatable({} :: Fields, ProgressController))

function ProgressController.new(deps: Deps): ProgressController
	return setmetatable({ deps = deps, queue = {}, playing = false } :: Fields, ProgressController)
end

function ProgressController.start(self: ProgressController)
	self.deps.remotes.SongComplete.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.summary) == "table" and payload.summary.tutorial ~= true then
			self.queue = self:_popupsFor(payload.summary)
		end
	end)

	self.deps.hud.results:bindRevealDone(function()
		self:_playNext()
	end)
end

function ProgressController._toast(self: ProgressController, title: string, detail: string): Popup
	return function(done: () -> ())
		self.deps.sfx:play(TOAST_SOUND)
		self.deps.hud.popups:showToast(title, detail, done)
	end
end

function ProgressController._popupsFor(self: ProgressController, summary: any): { Popup }
	local popups: { Popup } = {}
	local after = summary.rankAfter

	if summary.rankedUp == true and type(after) == "table" then
		table.insert(popups, function(done: () -> ())
			self.deps.sfx:play(RANK_UP_SOUND)
			self.deps.hud.stages:showStageUp({
				rank = after.rank,
				name = after.name,
				stages = summary.stages,
				challenge = if type(summary.challenge) == "table" then summary.challenge else nil,
				opens = if type(summary.rankOpens) == "table" then summary.rankOpens else {},
			}, done)
		end)
	end

	local achievements = if type(summary.achievements) == "table" then summary.achievements else {}

	for index = 1, math.min(#achievements, MAX_ACHIEVEMENT_TOASTS) do
		local achievement = achievements[index]

		table.insert(popups, self:_toast(string.upper(tostring(achievement.name)), tostring(achievement.detail or "")))
	end

	if #achievements > MAX_ACHIEVEMENT_TOASTS then
		table.insert(popups, self:_toast(("+%d MORE ACHIEVEMENTS"):format(#achievements - MAX_ACHIEVEMENT_TOASTS), ""))
	end

	for _, daily in if type(summary.dailyCompleted) == "table" then summary.dailyCompleted else {} do
		table.insert(popups, self:_toast(string.upper(tostring(daily.name)), ("+%d"):format(tonumber(daily.reward) or 0)))
	end

	return popups
end

-- A run that starts mid-queue drops the rest; nothing pops up during a song.
function ProgressController._playNext(self: ProgressController)
	if self.playing then
		return
	end

	local popup = table.remove(self.queue, 1)

	if popup == nil then
		return
	end

	if self.deps.hud.runActive then
		table.clear(self.queue)
		return
	end

	self.playing = true
	popup(function()
		self.playing = false
		self:_playNext()
	end)
end

return ProgressController
