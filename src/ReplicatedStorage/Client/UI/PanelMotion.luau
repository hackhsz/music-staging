--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local OPEN_SECONDS = 0.44
local CLOSE_SECONDS = 0.16
local SLIDE = 0.11
local RISE = 0.04
local CLOSE_SLIDE = 0.035
local POP_FROM = 0.86
local CLOSE_SCALE = 0.95
local TILT_DEGREES = 3
local STAGGER_SECONDS = 0.05
local MAX_STAGGER_SECONDS = 0.3
local SCALE_NAME = "Motion"
local COVER_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local COVERS = { Backdrop = true, Dimmer = true, TapCatcher = true }

type Piece = {
	gui: GuiObject,
	home: UDim2,
	rotation: number,
	side: number,
	order: number,
	scale: UIScale?,
	tilts: boolean,
}
type Panel = { pieces: { Piece }, covers: { [GuiObject]: number }, tweens: { Tween }, token: number }

type Fields = {
	panels: { [GuiObject]: Panel },
}

-- How a full-screen panel comes and goes: its cover fades while each block flies in
-- from its own side, tilted and small, and snaps upright with a little overshoot, top
-- block first. It leaves the same way, faster.
local PanelMotion = {}
PanelMotion.__index = PanelMotion

export type PanelMotion = typeof(setmetatable({} :: Fields, PanelMotion))

function PanelMotion.new(): PanelMotion
	local fields: Fields = { panels = setmetatable({}, { __mode = "k" }) :: any }

	return setmetatable(fields, PanelMotion)
end

local function centreX(gui: GuiObject): number
	return gui.Position.X.Scale + gui.Size.X.Scale * (0.5 - gui.AnchorPoint.X)
end

local function scaleFor(gui: GuiObject): UIScale?
	-- A button already carries the hover's UIScale, and an element honours only one.
	if gui:IsA("GuiButton") then
		return nil
	end

	local scale = Instance.new("UIScale")

	scale.Name = SCALE_NAME
	scale.Parent = gui

	return scale
end

-- Homes are read once, at rest, so a panel reopened mid-flight still lands where it was authored.
function PanelMotion._panel(self: PanelMotion, root: GuiObject): Panel
	local known = self.panels[root]

	if known ~= nil then
		return known
	end

	local panel: Panel = { pieces = {}, covers = {}, tweens = {}, token = 0 }

	for _, child in root:GetChildren() do
		if not child:IsA("GuiObject") then
			continue
		end

		if COVERS[child.Name] then
			panel.covers[child] = child.BackgroundTransparency
			continue
		end

		local home = child.Position

		table.insert(panel.pieces, {
			gui = child,
			home = home,
			rotation = child.Rotation,
			side = if centreX(child) < 0.5 then -1 else 1,
			order = home.Y.Scale - child.Size.Y.Scale * child.AnchorPoint.Y,
			scale = scaleFor(child),
			-- A rotated frame stops clipping, so a list would spill while it turned.
			tilts = not child.ClipsDescendants,
		})
	end

	table.sort(panel.pieces, function(a, b)
		return a.order < b.order
	end)

	self.panels[root] = panel

	return panel
end

local function stop(panel: Panel)
	for _, tween in panel.tweens do
		tween:Cancel()
	end

	table.clear(panel.tweens)
	panel.token += 1
end

local function rest(panel: Panel)
	for _, piece in panel.pieces do
		piece.gui.Position = piece.home
		piece.gui.Rotation = piece.rotation

		if piece.scale ~= nil then
			piece.scale.Scale = 1
		end
	end

	for cover, transparency in panel.covers do
		cover.BackgroundTransparency = transparency
	end
end

local function play(panel: Panel, target: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(target, info, goal)

	table.insert(panel.tweens, tween)
	tween:Play()
end

function PanelMotion.open(self: PanelMotion, root: GuiObject)
	local panel = self:_panel(root)

	stop(panel)
	root.Visible = true

	if GuiService.ReducedMotionEnabled then
		rest(panel)
		return
	end

	for cover, transparency in panel.covers do
		cover.BackgroundTransparency = 1
		play(panel, cover, COVER_INFO, { BackgroundTransparency = transparency })
	end

	for index, piece in panel.pieces do
		local delay = math.min((index - 1) * STAGGER_SECONDS, MAX_STAGGER_SECONDS)
		local glide = TweenInfo.new(OPEN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay)
		local snap = TweenInfo.new(OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay)

		piece.gui.Position = piece.home + UDim2.fromScale(piece.side * SLIDE, RISE)
		play(panel, piece.gui, glide, { Position = piece.home })

		if piece.tilts then
			piece.gui.Rotation = piece.rotation + piece.side * TILT_DEGREES
			play(panel, piece.gui, snap, { Rotation = piece.rotation })
		end

		if piece.scale ~= nil then
			piece.scale.Scale = POP_FROM
			play(panel, piece.scale, snap, { Scale = 1 })
		end
	end
end

function PanelMotion.close(self: PanelMotion, root: GuiObject)
	local panel = self:_panel(root)

	stop(panel)

	if not root.Visible then
		rest(panel)
		return
	end

	if GuiService.ReducedMotionEnabled then
		root.Visible = false
		rest(panel)
		return
	end

	local token = panel.token

	for cover in panel.covers do
		play(panel, cover, CLOSE_INFO, { BackgroundTransparency = 1 })
	end

	for _, piece in panel.pieces do
		play(panel, piece.gui, CLOSE_INFO, { Position = piece.home + UDim2.fromScale(piece.side * CLOSE_SLIDE, 0) })

		if piece.scale ~= nil then
			play(panel, piece.scale, CLOSE_INFO, { Scale = CLOSE_SCALE })
		end
	end

	task.delay(CLOSE_SECONDS, function()
		if panel.token == token then
			root.Visible = false
			rest(panel)
		end
	end)
end

return PanelMotion
