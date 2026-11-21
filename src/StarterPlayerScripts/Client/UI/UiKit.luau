--!strict
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiSprites = require(script.Parent.UiSprites)

local UiKit = {}

export type ImageState = { image: string, offset: Vector2, size: Vector2 }

UiKit.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
UiKit.MinTouchTarget = 44

UiKit.Colors = {
	Panel = Color3.fromRGB(24, 25, 42),
	Surface = Color3.fromRGB(15, 18, 42),
	Deep = Color3.fromRGB(6, 7, 20),
	Track = Color3.fromRGB(36, 37, 61),
	Yellow = Color3.fromRGB(255, 226, 76),
	Cyan = Color3.fromRGB(83, 224, 255),
	Green = Color3.fromRGB(106, 255, 128),
	Pink = Color3.fromRGB(255, 132, 229),
	Red = Color3.fromRGB(255, 76, 91),
	Amber = Color3.fromRGB(255, 211, 92),
	Purple = Color3.fromRGB(190, 120, 255),
	Fever = Color3.fromRGB(255, 37, 172),
	White = Color3.fromRGB(255, 255, 255),
	Dim = Color3.fromRGB(148, 150, 170),
}

local FALLBACK_VIEWPORT = Vector2.new(1280, 720)
local SMALL_VIEWPORT_WIDTH = 900
local SMALL_VIEWPORT_HEIGHT = 600
local PHONE_VIEWPORT_HEIGHT = 520
-- StarterGui only copies into PlayerGui once the character spawns, which in a
-- busy Studio session can take well past ten seconds.
local AUTHORED_TIMEOUT = 60
local BUTTON_HOVER_SCALE = 1.08
local BUTTON_HOVER_TILT = -3
local SQUARE_TOLERANCE_PIXELS = 4
local BUTTON_PRESS_SCALE = 0.92
local BUTTON_HOVER_SECONDS = 0.14
local BUTTON_PRESS_SECONDS = 0.06
local DISABLED_TRANSPARENCY = 0.45
local POP_IN_FROM = 0.6
local POP_IN_SECONDS = 0.32
local POP_IN_STAGGER = 0.035
local POP_IN_LIMIT = 24
local LIT_TAG = "Primary"
local LIT_FILL = ColorSequence.new(Color3.fromRGB(255, 95, 225), Color3.fromRGB(185, 70, 255))
local RESTING_FILL = ColorSequence.new(Color3.fromRGB(70, 30, 130), Color3.fromRGB(40, 14, 85))
local LIT_STROKE = Color3.fromRGB(255, 199, 242)
local RESTING_STROKE = Color3.fromRGB(210, 160, 255)
-- Sweeping the pointer along a row of buttons ticks, but never as a buzz.
local HOVER_SOUND_GAP_SECONDS = 0.05

local soundPlayer: ((name: string) -> ())? = nil
local lastHoverSound = 0

function UiKit.create(className: string, properties: { [string]: any }, parent: Instance?): any
	local instance: any = Instance.new(className)

	for key, value in properties do
		instance[key] = value
	end

	instance.Parent = parent

	return instance
end

function UiKit.label(parent: Instance, name: string, text: string, color: Color3, properties: { [string]: any }?): any
	local label = UiKit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextColor3 = color,
		FontFace = UiKit.FontFace,
		TextScaled = true,
		Text = text,
	}, nil)

	if properties ~= nil then
		for key, value in properties do
			label[key] = value
		end
	end

	label.Parent = parent

	return label
end

function UiKit.button(parent: Instance, name: string, text: string, color: Color3, properties: { [string]: any }?): any
	local button = UiKit.create("TextButton", {
		Name = name,
		BackgroundTransparency = 0.18,
		BackgroundColor3 = UiKit.Colors.Surface,
		BorderSizePixel = 0,
		TextColor3 = color,
		FontFace = UiKit.FontFace,
		TextScaled = true,
		Text = text,
	}, nil)

	if properties ~= nil then
		for key, value in properties do
			button[key] = value
		end
	end

	button.Parent = parent

	return button
end

-- TextScaled sizes each label on its own, so a short row renders far bigger
-- than a long one beside it and a list looks broken. Cap the size to keep a
-- group even; the text still shrinks to fit when it is long.
function UiKit.capTextSize(instance: Instance, maxTextSize: number)
	UiKit.create("UITextSizeConstraint", { MaxTextSize = maxTextSize }, instance)
end

-- Key labels only help players who have a keyboard; touch and gamepad players
-- get buttons instead and never see a letter they cannot press.
function UiKit.keyHint(text: string): string
	return if UserInputService.KeyboardEnabled then text else ""
end

-- Wraps text in a RichText colour tag; the label must have RichText on.
function UiKit.tint(text: string, color: Color3): string
	return ('<font color="#%s">%s</font>'):format(color:ToHex(), text)
end

function UiKit.isTouch(): boolean
	return UserInputService.TouchEnabled
end

function UiKit.viewportSize(): Vector2
	local camera = Workspace.CurrentCamera

	return if camera ~= nil then camera.ViewportSize else FALLBACK_VIEWPORT
end

-- Calls back now and on every resize, following the camera when it is replaced.
function UiKit.onViewportChanged(callback: () -> ())
	local connection: RBXScriptConnection? = nil

	local function hook()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		local camera = Workspace.CurrentCamera

		if camera ~= nil then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
		end

		callback()
	end

	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	hook()
end

function UiKit.isSmallViewport(): boolean
	local viewport = UiKit.viewportSize()

	return viewport.X < SMALL_VIEWPORT_WIDTH or viewport.Y < SMALL_VIEWPORT_HEIGHT
end

-- A phone: upright, or on its side and too short for the desktop layouts.
function UiKit.isPhoneViewport(viewport: Vector2): boolean
	return viewport.X < viewport.Y or viewport.Y < PHONE_VIEWPORT_HEIGHT
end

-- parent's child of that name and class; nil when either is missing.
function UiKit.child(parent: Instance?, name: string, className: string): any
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil

	return if found ~= nil and found:IsA(className) then found else nil
end

-- An item's picture: its uploaded icon when it has one, drawn by an Art image
-- beside the glyph (authored, or made to match the glyph), else its placeholder glyph.
function UiKit.setIcon(glyph: TextLabel?, text: string?, icon: string?)
	local holder = if glyph ~= nil then glyph.Parent else nil

	if glyph == nil or holder == nil then
		return
	end

	local hasIcon = type(icon) == "string" and icon ~= ""
	-- Two glyphs can share a holder (a quest row has its icon and its reward), so each gets its own image.
	local artName = if glyph.Name == "Glyph" then "Art" else glyph.Name .. "Art"
	local art = UiKit.child(holder, artName, "ImageLabel")

	if art == nil and hasIcon then
		art = UiKit.create("ImageLabel", {
			Name = artName,
			BackgroundTransparency = 1,
			AnchorPoint = glyph.AnchorPoint,
			Position = glyph.Position,
			Size = glyph.Size,
			ZIndex = glyph.ZIndex,
			ScaleType = Enum.ScaleType.Fit,
		}, holder)
	end

	if art ~= nil then
		if hasIcon then
			UiKit.setImage(art, icon :: string)
		else
			art.Image = ""
		end

		art.Visible = hasIcon
	end

	glyph.Text = if hasIcon then "" else text or ""
end

function UiKit.imageState(target: ImageLabel | ImageButton): ImageState
	return { image = target.Image, offset = target.ImageRectOffset, size = target.ImageRectSize }
end

-- Draws a UiSprites name (Name_Tint for its grey copy), a saved ImageState, or a
-- plain asset id. Sprites share atlas pages, so the rect has to change with the id.
function UiKit.setImage(target: GuiObject, image: string | ImageState)
	if not (target:IsA("ImageLabel") or target:IsA("ImageButton")) then
		return
	end

	if type(image) == "table" then
		target.Image = image.image
		target.ImageRectOffset = image.offset
		target.ImageRectSize = image.size
		return
	end

	local base, tinted = image:match("^(.-)(_Tint)$")
	local sprite = UiSprites[base or image]

	if sprite == nil then
		target.Image = image
		target.ImageRectOffset = Vector2.zero
		target.ImageRectSize = Vector2.zero
		return
	end

	target.Image = if tinted ~= nil then sprite.Tint else sprite.Image
	target.ImageRectOffset = sprite.Offset
	target.ImageRectSize = sprite.Size
end

-- Lights a picked tab or a ready button. The style sheet follows the tag, but the
-- imported NeonFill and NeonStroke are set on the instance, so they are recoloured here.
function UiKit.setLit(button: GuiObject, lit: boolean)
	if lit then
		CollectionService:AddTag(button, LIT_TAG)
	else
		CollectionService:RemoveTag(button, LIT_TAG)
	end

	local fill = button:FindFirstChild("NeonFill")
	local stroke = button:FindFirstChild("NeonStroke")

	if fill ~= nil and fill:IsA("UIGradient") and fill.Enabled then
		fill.Color = if lit then LIT_FILL else RESTING_FILL
	end

	if stroke ~= nil and stroke:IsA("UIStroke") and stroke.Enabled then
		stroke.Color = if lit then LIT_STROKE else RESTING_STROKE
	end

	local skin = button:FindFirstChild("Skin")
	local litImage = button:GetAttribute("LitImage")
	local restingImage = button:GetAttribute("RestingImage")

	if skin ~= nil and skin:IsA("ImageLabel") and typeof(litImage) == "string" and typeof(restingImage) == "string" then
		skin.Image = if lit then litImage else restingImage
	end
end

local function laidOutItems(root: Instance): { GuiObject }
	local items: { GuiObject } = {}

	for _, child in root:GetDescendants() do
		local parent = child.Parent

		if
			child:IsA("GuiObject")
			and child.Visible
			and parent ~= nil
			and (parent:FindFirstChildOfClass("UIGridLayout") ~= nil or parent:FindFirstChildOfClass("UIListLayout") ~= nil)
			and string.sub(child.Name, -8) ~= "Template"
			and child.AbsoluteSize.X > 0
		then
			table.insert(items, child)
		end
	end

	table.sort(items, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition

		return if math.abs(pa.Y - pb.Y) > 4 then pa.Y < pb.Y else pa.X < pb.X
	end)

	return items
end

-- The song picker's entrance for any window: the cards and rows in its lists spring in
-- one after another. Drives the same Pop scale the hover uses, ending at rest.
function UiKit.popIn(root: Instance)
	if GuiService.ReducedMotionEnabled then
		return
	end

	for index, item in laidOutItems(root) do
		if index > POP_IN_LIMIT then
			break
		end

		local scale = UiKit.scaleOf(item, "Pop")

		if item:FindFirstChildOfClass("UIScale") ~= scale then
			continue
		end

		scale.Scale = POP_IN_FROM
		TweenService:Create(
			scale,
			TweenInfo.new(POP_IN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * POP_IN_STAGGER),
			{ Scale = 1 }
		):Play()
	end
end

-- A button authored with a DisabledImage attribute swaps to that art while it is off;
-- without one it is dimmed instead.
function UiKit.setButtonEnabled(button: ImageButton, enabled: boolean)
	local disabled = button:GetAttribute("DisabledImage")

	if typeof(disabled) ~= "string" then
		button.ImageTransparency = if enabled then 0 else DISABLED_TRANSPARENCY
		return
	end

	if button:GetAttribute("IdleImage") == nil then
		button:SetAttribute("IdleImage", button.Image)
	end

	button.Image = if enabled then button:GetAttribute("IdleImage") :: string else disabled
	button.Active = enabled
	button.AutoButtonColor = enabled
end

function UiKit.scaleOf(gui: Instance, name: string?): UIScale
	local existing = if name ~= nil then gui:FindFirstChild(name) else gui:FindFirstChildOfClass("UIScale")

	if existing ~= nil and existing:IsA("UIScale") then
		return existing
	end

	return UiKit.create("UIScale", if name ~= nil then { Name = name } else {}, gui)
end

-- Main hands the UI its sound player, so a screen can sound a cue by name
-- without knowing about the audio code.
function UiKit.setSoundPlayer(player: (name: string) -> ())
	soundPlayer = player
end

function UiKit.playSound(name: string)
	if soundPlayer ~= nil then
		soundPlayer(name)
	end
end

-- A tick under the pointer and a click on press. A tap fires both, so touch
-- only gets the click.
function UiKit.bindSounds(button: GuiButton)
	button.MouseEnter:Connect(function()
		local now = os.clock()

		if UserInputService.MouseEnabled and now - lastHoverSound >= HOVER_SOUND_GAP_SECONDS then
			lastHoverSound = now
			UiKit.playSound("uiHover")
		end
	end)
	button.MouseButton1Down:Connect(function()
		UiKit.playSound("uiClick")
	end)
end

-- Round and square buttons (the icon rails, close buttons) only grow: a tilt
-- spins their icon and swings the label hung under them.
local function isSquare(button: GuiButton): boolean
	local size = button.AbsoluteSize
	return math.abs(size.X - size.Y) <= SQUARE_TOLERANCE_PIXELS
end

-- Grows and tilts a button under the pointer and dips it on press. It drives the
-- button's Pop scale, which a GuiObject can only have one of, so a screen that
-- also animates Pop gets onHover to step aside while the pointer is on it.
function UiKit.bindHover(button: GuiButton, onHover: ((boolean) -> ())?): () -> ()
	local authoredScale = button:FindFirstChildOfClass("UIScale")

	-- A designer's own UIScale already animates this button, and a GuiObject
	-- honours only one, so a Pop scale here would be ignored or fight it.
	if authoredScale ~= nil and authoredScale.Name ~= "Pop" then
		UiKit.bindSounds(button)

		return function() end
	end

	local scale = UiKit.scaleOf(button, "Pop")
	local restTilt = button.Rotation
	local hovered = false

	UiKit.bindSounds(button)

	local function scaleTo(goal: number, seconds: number)
		TweenService:Create(scale, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = goal,
		}):Play()
	end

	local function setHovered(active: boolean)
		hovered = active
		scaleTo(if active then BUTTON_HOVER_SCALE else 1, BUTTON_HOVER_SECONDS)
		TweenService:Create(button, TweenInfo.new(BUTTON_HOVER_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = if active then restTilt + BUTTON_HOVER_TILT else restTilt,
		}):Play()

		if onHover ~= nil then
			onHover(active)
		end
	end

	button.MouseEnter:Connect(function()
		setHovered(true)
	end)
	button.MouseLeave:Connect(function()
		setHovered(false)
	end)
	button.MouseButton1Down:Connect(function()
		scaleTo(BUTTON_PRESS_SCALE, BUTTON_PRESS_SECONDS)
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(if hovered then BUTTON_HOVER_SCALE else 1, BUTTON_HOVER_SECONDS)
	end)

	-- Touch never sends MouseLeave, so a closing screen calls this to let go.
	return function()
		if hovered then
			setHovered(false)
		end
	end
end

-- A ScreenGui authored in StarterGui, once it has reached the PlayerGui.
function UiKit.authoredGui(playerGui: Instance, name: string): ScreenGui?
	local gui = playerGui:WaitForChild(name, AUTHORED_TIMEOUT)

	if gui == nil or not gui:IsA("ScreenGui") then
		warn(("[DanceDanceStep] StarterGui.%s not found; its screens will not draw"):format(name))
		return nil
	end

	return gui
end

-- A named descendant of the authored root, or nil with a warning naming what is
-- missing. A missing root has already been reported, so it stays quiet.
function UiKit.authored(root: Instance?, path: string, className: string): any
	if root == nil then
		return nil
	end

	local node: Instance? = root

	for _, name in string.split(path, ".") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end

	if node == nil or not node:IsA(className) then
		warn(("[DanceDanceStep] %s has no %s %s"):format(root:GetFullName(), className, path))
		return nil
	end

	return node
end

-- Stretches a frame from a ScreenGui's top-left corner over the whole screen,
-- under Roblox's top bar and any notch, which the gui's safe insets keep out.
function UiKit.coverScreen(frame: GuiObject, gui: ScreenGui)
	local missing = UiKit.viewportSize() - gui.AbsoluteSize
	local top = math.clamp(GuiService:GetGuiInset().Y, 0, math.max(missing.Y, 0))
	frame.Position = UDim2.fromOffset(-missing.X / 2, -top)
	frame.Size = UDim2.new(1, missing.X, 1, missing.Y)
end

-- A slice that spans the art's full height stretches only its middle; its ends
-- keep the art's shape only while SliceScale follows the drawn height.
function UiKit.fitSliceToHeight(gui: GuiObject)
	if not gui:IsA("ImageLabel") then
		return
	end

	local image = gui :: ImageLabel
	local artHeight = image.SliceCenter.Max.Y

	if image.ScaleType ~= Enum.ScaleType.Slice or image.SliceCenter.Min.Y ~= 0 or artHeight <= 0 then
		return
	end

	local function fit()
		image.SliceScale = image.AbsoluteSize.Y / artHeight
	end

	image:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

function UiKit.topInset(): number
	local inset = GuiService:GetGuiInset()

	return inset.Y
end

return UiKit
