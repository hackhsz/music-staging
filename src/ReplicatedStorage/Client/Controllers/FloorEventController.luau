--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SongSchema = require(Shared:WaitForChild("SongSchema"))
local Timing = require(Shared:WaitForChild("Timing"))
local UiKit = require(script.Parent.Parent.UI.UiKit)

local ANNOUNCE_BEATS = 4
local COUNT_FROM = 3
local RELEASE_SHOWN_BEATS = 1.5

type Look = { title: string, detail: string, color: Color3 }

local LOOKS: { [string]: Look } = {
	lava = { title = "FLOOR IS LAVA!", detail = "STAND ON THE GREEN TILES", color = UiKit.Colors.Red },
	spotlight = { title = "SPOTLIGHT!", detail = "STAY IN THE LIGHT", color = UiKit.Colors.Amber },
	memory = { title = "MEMORY!", detail = "WATCH THE PATTERN", color = UiKit.Colors.Cyan },
	freeze = { title = "FREEZE!", detail = "DON'T TAKE A STEP", color = UiKit.Colors.White },
}
local PLAY_LOOK: Look = { title = "YOUR TURN!", detail = "STEP IT BACK ON THE BEAT", color = UiKit.Colors.Pink }
local RELEASE_LOOK: Look = { title = "MOVE!", detail = "", color = UiKit.Colors.Green }

type Deps = {
	boardView: any,
	hud: any,
	sfx: any,
}

type Fields = {
	deps: Deps,
	events: { any },
	steps: { any },
	index: number,
	announced: boolean,
	lastCount: number?,
	active: boolean,
	zoneKey: string?,
	flashed: number,
	playing: boolean,
	hideBannerAt: number?,
}

-- Runs the floor events of a pad run on the song clock: the banner and 3-2-1
-- before each, the pad's look while it lasts, and the end. It only presents;
-- the server judges every event step like any other.
local FloorEventController = {}
FloorEventController.__index = FloorEventController

export type FloorEventController = typeof(setmetatable({} :: Fields, FloorEventController))

local function tryCall(target: any, method: string, ...: any)
	if target ~= nil and type(target[method]) == "function" then
		target[method](target, ...)
	end
end

function FloorEventController.new(deps: Deps): FloorEventController
	local fields: Fields = {
		deps = deps,
		events = {},
		steps = {},
		index = 1,
		announced = false,
		lastCount = nil,
		active = false,
		zoneKey = nil,
		flashed = 0,
		playing = false,
		hideBannerAt = nil,
	}

	return setmetatable(fields, FloorEventController)
end

function FloorEventController.begin(self: FloorEventController, events: any, steps: { any })
	self:stop()
	self.events = if type(events) == "table" then events else {}
	self.steps = steps
end

function FloorEventController.stop(self: FloorEventController)
	if self.active then
		tryCall(self.deps.boardView, "setPadEvent", nil, nil)
	end

	if self.announced or self.hideBannerAt ~= nil then
		self.deps.hud.banner:hide()
	end

	self.events = {}
	self.steps = {}
	self:_reset(1)
	self.hideBannerAt = nil
end

function FloorEventController._reset(self: FloorEventController, index: number)
	self.index = index
	self.announced = false
	self.lastCount = nil
	self.active = false
	self.zoneKey = nil
	self.flashed = 0
	self.playing = false
end

function FloorEventController._current(self: FloorEventController): any?
	return self.events[self.index]
end

function FloorEventController._setPad(self: FloorEventController, kind: string?, info: { [string]: any }?)
	tryCall(self.deps.boardView, "setPadEvent", kind, info)
end

function FloorEventController._showBanner(self: FloorEventController, look: Look)
	self.hideBannerAt = nil
	self.deps.hud.banner:show(look.title, if look.detail ~= "" then look.detail else nil, look.color)
	self.deps.hud.banner:setCount(nil)
end

-- The zone the player must be in next: the first zone step whose beat has not
-- closed yet.
function FloorEventController._nextZone(self: FloorEventController, songBeat: number, graceBeats: number): { any }?
	for _, step in self.steps do
		if step.event == self.index and SongSchema.zoneOf(step) ~= nil and step.beat + graceBeats > songBeat then
			return step.zone
		end
	end

	return nil
end

local function zoneKey(zone: { any }): string
	local parts = {}

	for _, tile in zone do
		table.insert(parts, tile.x .. "," .. tile.y)
	end

	return table.concat(parts, ";")
end

function FloorEventController._updateZone(self: FloorEventController, event: any, songBeat: number, graceBeats: number)
	local zone = self:_nextZone(songBeat, graceBeats)

	if zone == nil then
		return
	end

	local key = zoneKey(zone)

	if key == self.zoneKey then
		return
	end

	self.zoneKey = key
	self.active = true
	self:_setPad(event.kind, if event.kind == "lava" then { safe = zone } else { lit = zone })
end

function FloorEventController._updateMemory(self: FloorEventController, event: any, songBeat: number, beatSeconds: number)
	local interval = event.interval
	local sequence = event.sequence

	if not self.active and songBeat >= event.beat then
		self.active = true
		self:_setPad("memory", {
			phase = "watch",
			sequence = sequence,
			beatSeconds = interval * beatSeconds,
			interval = interval,
		})
	end

	while self.flashed < #sequence and songBeat >= event.beat + self.flashed * interval do
		self.flashed += 1

		local sfx = self.deps.sfx

		if sfx ~= nil and type(sfx.playMemoryTone) == "function" then
			sfx:playMemoryTone(self.flashed)
		else
			sfx:play("countdownTick")
		end
	end

	if not self.playing and songBeat >= event.playBeat - interval then
		self.playing = true
		self:_setPad("memory", { phase = "play", count = #sequence })
		self:_showBanner(PLAY_LOOK)
		self.deps.sfx:play("countdownGo")
	end
end

function FloorEventController._updateFreeze(self: FloorEventController, event: any, songBeat: number, graceBeats: number)
	if not self.active and songBeat >= event.beat - 1 + graceBeats then
		self.active = true
		self:_setPad("freeze", {})
	end

	if songBeat >= event.beat then
		local left = math.ceil(SongSchema.eventEnd(event) - songBeat)

		if left ~= self.lastCount and left > 0 then
			self.lastCount = left
			self.deps.hud.banner:setCount(tostring(left))
		end
	end
end

function FloorEventController._announce(self: FloorEventController, event: any, songBeat: number)
	if not self.announced and songBeat >= event.beat - ANNOUNCE_BEATS then
		self.announced = true
		self:_showBanner(LOOKS[event.kind] or LOOKS.lava)
		self.deps.sfx:play("feverStart")
		self.deps.sfx:play("cheerMilestone")
	end

	if songBeat >= event.beat or songBeat < event.beat - COUNT_FROM then
		return
	end

	local count = math.ceil(event.beat - songBeat)

	if count ~= self.lastCount then
		self.lastCount = count
		self.deps.hud.banner:setCount(tostring(count))
		self.deps.sfx:play("countdownTick")
	end
end

function FloorEventController._finish(self: FloorEventController, event: any, songBeat: number)
	self:_setPad(nil, nil)

	if event.kind == "freeze" then
		self:_showBanner(RELEASE_LOOK)
		self.deps.sfx:play("cheerMilestone")
	end

	self.hideBannerAt = songBeat + RELEASE_SHOWN_BEATS
	self:_reset(self.index + 1)
end

-- songBeat counts from 1 at the song's start, as chart beats do.
function FloorEventController.update(self: FloorEventController, songBeat: number, beatSeconds: number)
	if self.hideBannerAt ~= nil and songBeat >= self.hideBannerAt then
		self.hideBannerAt = nil
		self.deps.hud.banner:hide()
	end

	local event = self:_current()

	if event == nil then
		return
	end

	local graceBeats = Timing.OnBeatLateGrace / beatSeconds
	local lastBeat = SongSchema.eventEnd(event) - 1

	if songBeat >= lastBeat + graceBeats then
		self:_finish(event, songBeat)
		return
	end

	local wasCounting = songBeat < event.beat
	self:_announce(event, songBeat)

	if not wasCounting and self.lastCount ~= nil and event.kind ~= "freeze" then
		self.lastCount = nil
		self.deps.hud.banner:setCount(nil)

		if event.kind ~= "memory" then
			self.hideBannerAt = event.beat + RELEASE_SHOWN_BEATS
		end
	end

	if event.kind == "memory" then
		self:_updateMemory(event, songBeat, beatSeconds)
	elseif event.kind == "freeze" then
		self:_updateFreeze(event, songBeat, graceBeats)
	elseif songBeat >= event.beat - 1 then
		self:_updateZone(event, songBeat, graceBeats)
	end
end

return FloorEventController
