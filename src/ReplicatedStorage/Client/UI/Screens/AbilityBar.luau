--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("AbilityCatalog"))
local TweenSlots = require(script.Parent.Parent.TweenSlots)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

local LOCKED_TRANSPARENCY = 0.5
local POP_SCALE = 1.22
local POP_SECONDS = 0.25
local SHAKE_PIXELS = 4
local FLOOR_BOB_SCALE = 1.08
local FLOOR_BOB_SECONDS = 0.45
local SPIN_SECONDS = 1.2

export type SlotState = { id: string, readyIn: number, beatsLeft: number?, usesLeft: number?, onFloor: boolean? }
export type State = { charge: number, maxCharge: number, beatSeconds: number, slots: { SlotState } }

type Slot = {
	frame: GuiObject,
	glyph: TextLabel,
	glyphHome: UDim2,
	name: TextLabel?,
	timer: TextLabel?,
	charge: GuiObject?,
	chargeFill: GuiObject?,
	scale: UIScale,
	gradient: UIGradient?,
	onFloor: boolean,
	running: boolean,
	abilityId: string?,
}

type View = { frame: GuiObject, slots: { Slot } }

type Fields = {
	views: { [string]: View },
	active: string?,
	shown: boolean,
	tweens: TweenSlots.TweenSlots,
	loadout: { string },
}

-- The four abilities of a run, drawn on the slot cards authored in the place:
-- PadHud's Desktop and PhoneLandscape layouts and the Derail HUD each carry an
-- Abilities frame of Slot1-4 (Icon, Badge, Title, Timer). The card art is
-- kept as authored; the Icon is a placeholder, so the ability's glyph is drawn
-- over it. Abilities fire from the floor, so the cards only show what each is doing.
-- An optional Charge bar (with a Fill) shows the charge while it builds; the
-- Timer then only speaks up for a countdown or the floor.
local AbilityBar = {}
AbilityBar.__index = AbilityBar

export type AbilityBar = typeof(setmetatable({} :: Fields, AbilityBar))

local child = UiKit.child

local function makeGlyph(frame: GuiObject, icon: ImageLabel?): TextLabel
	local glyph = UiKit.label(icon or frame, "Glyph", "", Colors.White, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(if icon ~= nil then 1.3 else 0.5, if icon ~= nil then 1 else 0.4),
		ZIndex = frame.ZIndex + 3,
	})
	UiKit.create("UIStroke", { Thickness = 2, Color = Colors.Deep }, glyph)

	return glyph
end

local function bindSlot(frame: GuiObject): Slot
	local icon = child(frame, "Icon", "ImageLabel")

	if icon ~= nil then
		icon.ImageTransparency = 1
	end

	-- An authored Glyph keeps its own font and outline; otherwise one is made.
	local glyph: TextLabel = child(icon or frame, "Glyph", "TextLabel") or makeGlyph(frame, icon)

	local charge = child(frame, "Charge", "GuiObject")

	return {
		frame = frame,
		glyph = glyph,
		glyphHome = glyph.Position,
		name = child(frame, "Title", "TextLabel"),
		timer = child(frame, "Timer", "TextLabel"),
		charge = charge,
		chargeFill = if charge ~= nil then child(charge, "Fill", "GuiObject") else nil,
		scale = UiKit.scaleOf(frame),
		gradient = child(frame, "UIGradient", "UIGradient"),
		onFloor = false,
		running = false,
		abilityId = nil,
	}
end

local function bindView(frame: GuiObject): View?
	local slots = {}

	for index = 1, AbilityCatalog.Slots do
		local slot = frame:FindFirstChild("Slot" .. index)

		if slot == nil or not slot:IsA("GuiObject") then
			warn("[DanceDanceStep] " .. frame:GetFullName() .. " has no Slot" .. index .. "; its ability bar will not draw")
			return nil
		end

		table.insert(slots, bindSlot(slot))
	end

	frame.Visible = false

	return { frame = frame, slots = slots }
end

-- frames maps a layout name to its authored Abilities frame.
function AbilityBar.new(frames: { [string]: GuiObject }): AbilityBar
	local views = {}

	for name, frame in frames do
		local view = bindView(frame)

		if view ~= nil then
			views[name] = view
		end
	end

	local fields: Fields = {
		views = views,
		active = nil,
		shown = false,
		tweens = TweenSlots.new(),
		loadout = {},
	}

	return setmetatable(fields, AbilityBar)
end

function AbilityBar._refreshVisibility(self: AbilityBar)
	for name, view in self.views do
		view.frame.Visible = self.shown and name == self.active
	end
end

-- Which layout's cards draw: "Desktop" or "PhoneLandscape" on the pad, "Highway" otherwise.
function AbilityBar.setView(self: AbilityBar, name: string)
	if self.views[name] == nil then
		return
	end

	self.active = name
	self:_refreshVisibility()
end

function AbilityBar.setVisible(self: AbilityBar, visible: boolean)
	self.shown = visible
	self:_refreshVisibility()
end

function AbilityBar.isVisible(self: AbilityBar): boolean
	return self.shown
end

-- The corner the cards take at the bottom right of a screen at origin, size
-- big, for the pad shot to keep the floor clear of them; zero while hidden.
function AbilityBar.reach(self: AbilityBar, origin: Vector2, size: Vector2): Vector2
	local view = if self.shown and self.active ~= nil then self.views[self.active] else nil

	return if view ~= nil then origin + size - view.frame.AbsolutePosition else Vector2.zero
end

function AbilityBar.setLoadout(self: AbilityBar, loadout: { string })
	self.loadout = loadout

	for _, view in self.views do
		for index, slot in view.slots do
			local ability = if loadout[index] ~= nil then AbilityCatalog.get(loadout[index]) else nil
			slot.abilityId = if ability ~= nil then ability.id else nil

			UiKit.setIcon(slot.glyph, if ability ~= nil then ability.glyph else "", if ability ~= nil then ability.icon else nil)
			slot.glyph.TextColor3 = if ability ~= nil then ability.color else Colors.Dim

			if slot.name ~= nil then
				slot.name.Text = if ability ~= nil then string.upper(ability.name) else ""
			end

			if slot.chargeFill ~= nil and ability ~= nil then
				slot.chargeFill.BackgroundColor3 = ability.color
			end
		end
	end
end

-- On the floor the card bobs until the player steps on it.
function AbilityBar._setOnFloor(self: AbilityBar, slot: Slot, onFloor: boolean)
	if slot.onFloor == onFloor then
		return
	end

	slot.onFloor = onFloor

	if onFloor then
		self.tweens:play(
			slot.scale,
			TweenInfo.new(FLOOR_BOB_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = FLOOR_BOB_SCALE }
		)
	else
		self.tweens:stop(slot.scale)
		slot.scale.Scale = 1
	end
end

function AbilityBar._setRunning(self: AbilityBar, slot: Slot, running: boolean)
	if slot.running == running or slot.gradient == nil then
		slot.running = running
		return
	end

	slot.running = running
	local gradient = slot.gradient :: UIGradient

	if running then
		gradient.Rotation = 0
		self.tweens:play(gradient, TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	else
		self.tweens:stop(gradient)
		gradient.Rotation = 90
	end
end

function AbilityBar.setState(self: AbilityBar, state: State)
	local charge = state.charge

	for _, view in self.views do
		for index, slot in view.slots do
			local slotState = state.slots[index]
			local ability = if slot.abilityId ~= nil then AbilityCatalog.get(slot.abilityId) else nil

			if ability == nil or slotState == nil then
				continue
			end

			local cooling = slotState.readyIn > 0
			local running = slotState.beatsLeft ~= nil
			local onFloor = slotState.onFloor == true
			self:_setOnFloor(slot, onFloor)
			self:_setRunning(slot, running)

			slot.glyph.TextTransparency = if onFloor or running then 0 else LOCKED_TRANSPARENCY

			local charging = not running and not onFloor and not cooling

			if slot.charge ~= nil then
				slot.charge.Visible = charging

				if slot.chargeFill ~= nil then
					slot.chargeFill.Size = UDim2.fromScale(math.clamp(charge / ability.cost, 0, 1), 1)
				end
			end

			local timer = slot.timer

			if timer == nil then
				continue
			end

			timer.Visible = not charging or slot.charge == nil

			if running then
				local seconds = math.max((slotState.beatsLeft :: number) * state.beatSeconds, 0)
				timer.Text = ("%ds"):format(math.ceil(seconds))
				timer.TextColor3 = ability.color
			elseif onFloor then
				timer.Text = "ON FLOOR!"
				timer.TextColor3 = Colors.Pink
			elseif cooling then
				timer.Text = ("%ds"):format(math.ceil(slotState.readyIn))
				timer.TextColor3 = Colors.Dim
			else
				timer.Text = ("%d%%"):format(math.floor(math.clamp(charge / ability.cost, 0, 1) * 100))
				timer.TextColor3 = Colors.White
			end
		end
	end
end

-- The server took it: the card swells and settles.
function AbilityBar.flashUsed(self: AbilityBar, slotIndex: number)
	for name, view in self.views do
		local slot = view.slots[slotIndex]

		if slot ~= nil then
			slot.scale.Scale = POP_SCALE
			self.tweens:play(slot.scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back), { Scale = 1 }, "pop" .. name .. slotIndex)
		end
	end
end

-- The server said no: a short shake of the glyph.
function AbilityBar.flashRefused(self: AbilityBar, slotIndex: number)
	for name, view in self.views do
		local slot = view.slots[slotIndex]

		if slot == nil then
			continue
		end

		local glyph, home = slot.glyph, slot.glyphHome
		glyph.Position = home + UDim2.fromOffset(SHAKE_PIXELS, 0)
		self.tweens
			:play(
				glyph,
				TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
				{ Position = home - UDim2.fromOffset(SHAKE_PIXELS, 0) },
				"shake" .. name .. slotIndex
			).Completed
			:Once(function()
				glyph.Position = home
			end)
	end
end

return AbilityBar
