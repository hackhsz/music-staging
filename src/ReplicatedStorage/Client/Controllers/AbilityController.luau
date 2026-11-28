--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local HUDController = require(script.Parent.Parent.UI.HUDController)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Telemetry = require(script.Parent.Parent.Net.Telemetry)
local RunController = require(script.Parent.RunController)

type Deps = {
	remotes: Remotes.Remotes,
	hud: HUDController.HUDController,
	run: RunController.RunController,
	sfx: any,
	camera: any,
	boardView: any,
}

-- These change the whole run, so they land with the crowd's biggest roar.
local BIG_EFFECTS = { fever = true, overdrive = true, doublePoints = true, spotlight = true }
local KICK = 0.6
local BIG_KICK = 1

type Snapshot = { charge: number, maxCharge: number, slots: { any }, at: number }
export type Pickup = { slot: number, x: number, y: number }

type Fields = {
	deps: Deps,
	enabled: boolean,
	snapshot: Snapshot?,
	pickup: Pickup?,
}

-- The four abilities of a run. The server puts each charged one on the floor
-- and fires it when the player steps on it; this draws the tile and the cards.
local AbilityController = {}
AbilityController.__index = AbilityController

export type AbilityController = typeof(setmetatable({} :: Fields, AbilityController))

function AbilityController.new(deps: Deps): AbilityController
	local fields: Fields = { deps = deps, enabled = false, snapshot = nil, pickup = nil }

	return setmetatable(fields, AbilityController)
end

function AbilityController.start(self: AbilityController)
	local deps = self.deps
	local hud = deps.hud

	hud.menu:bindAbilities(function()
		self:togglePicker()
	end)
	hud.abilityPicker:bindChanged(function(loadout)
		deps.remotes.SetAbilityLoadout:FireServer({ abilityIds = loadout })
		hud.abilityBar:setLoadout(loadout)
	end)

	deps.remotes.AbilityState.OnClientEvent:Connect(function(payload)
		self:_onState(payload)
	end)
	RunService.Heartbeat:Connect(function()
		self:_draw(os.clock())
	end)
	Remotes.listen(deps.remotes.ProfileSync, function(payload)
		if type(payload) == "table" and type(payload.abilityLoadout) == "table" then
			hud.abilityPicker:setLoadout(payload.abilityLoadout)
			hud.abilityBar:setLoadout(AbilityCatalog.sanitizeLoadout(payload.abilityLoadout))
		end
	end)
end

-- The charged ability waiting on the floor, if any.
function AbilityController.getPickup(self: AbilityController): Pickup?
	return self.pickup
end

function AbilityController._setPickup(self: AbilityController, raw: any)
	local slot = if type(raw) == "table" then tonumber(raw.slot) else nil
	local x = if type(raw) == "table" then tonumber(raw.x) else nil
	local y = if type(raw) == "table" then tonumber(raw.y) else nil
	local snapshot = self.snapshot
	local slotState = if snapshot ~= nil and slot ~= nil then snapshot.slots[slot] else nil
	local ability = if slotState ~= nil then AbilityCatalog.get(tostring(slotState.id)) else nil

	if slot == nil or x == nil or y == nil or ability == nil then
		self.pickup = nil
		self.deps.boardView:setAbilityPickup(nil)
		return
	end

	local fresh = self.pickup == nil or self.pickup.x ~= x or self.pickup.y ~= y
	self.pickup = { slot = slot, x = x, y = y }
	self.deps.boardView:setAbilityPickup({
		x = x,
		y = y,
		color = ability.color,
		glyph = ability.glyph,
		name = string.upper(ability.name),
	})

	if fresh then
		self.deps.sfx:play("abilityAppear")
	end
end

function AbilityController.togglePicker(self: AbilityController)
	if self.deps.run:isRunning() then
		return
	end

	self.deps.hud.abilityPicker:toggle()
end

function AbilityController._onState(self: AbilityController, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local deps = self.deps
	local bar = deps.hud.abilityBar
	self.enabled = payload.enabled == true and deps.run:isRunning()
	bar:setVisible(self.enabled)

	if not self.enabled then
		self:_setPickup(nil)
		return
	end

	if type(payload.loadout) == "table" then
		bar:setLoadout(payload.loadout)
	end

	if type(payload.slots) == "table" then
		self.snapshot = {
			charge = tonumber(payload.charge) or 0,
			maxCharge = tonumber(payload.maxCharge) or AbilityCatalog.MaxCharge,
			slots = payload.slots,
			at = os.clock(),
		}
		self:_setPickup(payload.pickup)
		self:_draw(os.clock())
	end

	local used = payload.used

	if type(used) == "table" and type(used.slot) == "number" then
		bar:flashUsed(used.slot)
		deps.run:applyMeters(payload.meters)
		self:_celebrate(AbilityCatalog.get(tostring(used.id)))
		Telemetry.track("ability_used", tostring(used.id))
	end

	local refused = payload.refused

	if type(refused) == "table" and type(refused.slot) == "number" then
		bar:flashRefused(refused.slot)
		deps.sfx:play("emptyPress")
	end
end

-- The server's last word, counted down to now so timers run between verdicts.
function AbilityController._draw(self: AbilityController, now: number)
	local snapshot = self.snapshot

	if not self.enabled or snapshot == nil then
		return
	end

	if not self.deps.run:isRunning() then
		self.enabled = false
		self.deps.hud.abilityBar:setVisible(false)
		self:_setPickup(nil)
		return
	end

	local beatSeconds = self.deps.run:getBeatSeconds()
	local since = now - snapshot.at
	local slots = {}

	for index, slot in snapshot.slots do
		local beatsLeft = tonumber(slot.beatsLeft)
		slots[index] = {
			id = slot.id,
			readyIn = math.max((tonumber(slot.readyIn) or 0) - since, 0),
			beatsLeft = if beatsLeft ~= nil and beatsLeft - since / beatSeconds > 0 then beatsLeft - since / beatSeconds else nil,
			usesLeft = slot.usesLeft,
			onFloor = self.pickup ~= nil and self.pickup.slot == index,
		}
	end

	self.deps.hud.abilityBar:setState({
		charge = snapshot.charge,
		maxCharge = snapshot.maxCharge,
		beatSeconds = beatSeconds,
		slots = slots,
	})
end

function AbilityController._celebrate(self: AbilityController, ability: AbilityCatalog.Ability?)
	if ability == nil then
		return
	end

	local deps = self.deps
	local big = BIG_EFFECTS[ability.effect] == true
	deps.hud:showAbility(string.upper(ability.name) .. "!", string.upper(ability.blurb), ability.color)
	deps.sfx:play("itemCollect")
	deps.sfx:play(if big then "cheerFever" else "cheerMilestone")
	deps.camera:kick(if big then BIG_KICK else KICK)
	deps.boardView:padMilestone(0)
end

return AbilityController
