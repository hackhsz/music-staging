--!strict
local Players = game:GetService("Players")

local AvatarPuppet = require(script.Parent.Parent.AvatarPuppet)
local PadHud = require(script.Parent.PadHud)
local UiKit = require(script.Parent.Parent.UiKit)

local Colors = UiKit.Colors

export type Look = { name: string, color: Color3? }
type Mood = "idle" | "happy" | "smug" | "worried" | "shocked" | "cheer" | "impressed"
-- box picks the bubble's art: Light is good news for the player, Dark the rival's.
type BubbleStyle = "Light" | "Dark"
type MoodStyle = { word: string?, ring: Color3?, box: BubbleStyle?, face: { [string]: number } }

type Card = {
	layout: GuiObject,
	root: GuiObject,
	scale: UIScale,
	ring: UIStroke,
	art: ImageLabel?,
	avatar: ViewportFrame,
	world: WorldModel,
	camera: Camera,
	headshot: ImageLabel,
	name: TextLabel,
	bubble: GuiObject,
	bubbleScale: UIScale,
	bubbleText: TextLabel,
	bubbleBoxes: { [string]: GuiObject },
	puppet: AvatarPuppet.AvatarPuppet?,
	aim: Vector3,
	fit: number,
}

local CARD_NAME = "RivalCard"
local DEFAULT_COLOR = Color3.fromRGB(240, 60, 80)
local LOSING_TINT = Color3.fromRGB(150, 150, 165)
local FIT_MIN = 0.55
local FIT_GAP = 8

local CAMERA_FOV = 26
local CAMERA_DISTANCE = 7.6
local CAMERA_LIFT = 0.15
local LOOK_DROP = 0.7
-- How quickly the camera follows the head as the dance moves it, per second.
local FOLLOW_RATE = 6

local REACT_SECONDS = 0.7
local CHEER_SECONDS = 1.4
-- The rival's share of the combined score past which they look ahead or behind.
local LEAD_SHARE = 0.55
local BOP = 0.05
local BOP_SECONDS = 0.25
local NOD_DEGREES = 12
local SHAKE_DEGREES = 16
local SHAKE_HZ = 5
local HOP_STUDS = 0.45
local HOP_HZ = 2.5
local TILT_DEGREES = 9
local BUBBLE_POP = 1.3
local BUBBLE_POP_SECONDS = 0.18
local BUBBLE_SHAKE_DEGREES = 8
local BUBBLE_SHAKE_HZ = 7
local BUBBLE_SHAKE_SECONDS = 0.35
local BUBBLE_TEXT: { [string]: Color3 } = { Light = Color3.new(0, 0, 0), Dark = Color3.new(1, 1, 1) }

local MOODS: { [Mood]: MoodStyle } = {
	idle = { face = {} },
	happy = {
		word = "NICE!",
		ring = Colors.Yellow,
		box = "Dark",
		face = { LeftLipCornerPuller = 1, RightLipCornerPuller = 1, LeftCheekRaiser = 0.6, RightCheekRaiser = 0.6 },
	},
	smug = {
		word = "HEHE",
		box = "Dark",
		face = { LeftLipCornerPuller = 0.8, LeftOuterBrowRaiser = 0.8, RightBrowLowerer = 0.5 },
	},
	worried = {
		word = "UH OH",
		ring = Colors.Cyan,
		box = "Light",
		face = { LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, LeftLipCornerDown = 0.7, RightLipCornerDown = 0.7 },
	},
	shocked = {
		word = "OOPS!",
		ring = Colors.Red,
		box = "Light",
		face = { JawDrop = 0.8, LeftInnerBrowRaiser = 0.8, RightInnerBrowRaiser = 0.8, LeftOuterBrowRaiser = 0.8 },
	},
	impressed = {
		word = "WOW!",
		ring = Colors.Cyan,
		box = "Light",
		face = { JawDrop = 0.5, LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, LeftOuterBrowRaiser = 1 },
	},
	cheer = {
		word = "WOO!",
		ring = Colors.Fever,
		box = "Dark",
		face = {
			JawDrop = 0.5,
			LeftLipCornerPuller = 1,
			RightLipCornerPuller = 1,
			LeftEyeClosed = 0.7,
			RightEyeClosed = 0.7,
		},
	},
}

local FACE_KEYS = {
	"JawDrop",
	"LeftLipCornerPuller",
	"RightLipCornerPuller",
	"LeftCheekRaiser",
	"RightCheekRaiser",
	"LeftOuterBrowRaiser",
	"RightBrowLowerer",
	"LeftInnerBrowRaiser",
	"RightInnerBrowRaiser",
	"LeftLipCornerDown",
	"RightLipCornerDown",
	"LeftEyeClosed",
	"RightEyeClosed",
}

type Fields = {
	cards: { Card },
	shown: boolean,
	rivalName: string?,
	color: Color3,
	share: number,
	mood: Mood?,
	moodAt: number,
	reaction: Mood?,
	reactionEnds: number,
	userId: number?,
	lastBeat: number,
	beatAt: number,
	lastFrame: number,
}

-- The rival's avatar in the card authored in StarterGui.PadHud, at the top
-- right of the pad run, dancing along with the rival. It reacts to the rival's
-- own grades and, between them, shows who is ahead: a word bubble, the ring's
-- colour, a nod, shake or hop, and the face itself on a dynamic head.
local RivalPortrait = {}
RivalPortrait.__index = RivalPortrait

export type RivalPortrait = typeof(setmetatable({} :: Fields, RivalPortrait))

local child = UiKit.child

-- Optional art inside the bubble, one image per style; without it the bubble
-- keeps its plain coloured fill.
local function bubbleBoxesOf(bubble: GuiObject?): { [string]: GuiObject }
	local boxes: { [string]: GuiObject } = {}

	for _, style in { "Light", "Dark" } do
		local box = child(bubble, style, "GuiObject")

		if box ~= nil then
			boxes[style] = box
		end
	end

	return boxes
end

local function bindCard(layout: GuiObject): Card?
	local root = child(layout, CARD_NAME, "GuiObject")
	local back = child(root, "Back", "GuiObject")
	local avatar = child(root, "Avatar", "ViewportFrame")
	local bubble = child(root, "Bubble", "GuiObject")
	local headshot = child(root, "Headshot", "ImageLabel")
	local name = child(root, "RivalName", "TextLabel")
	local bubbleText = child(bubble, "Text", "TextLabel")
	local ring = if back ~= nil then back:FindFirstChildOfClass("UIStroke") else nil

	if avatar == nil or ring == nil or headshot == nil or name == nil or bubbleText == nil then
		warn(("[DanceDanceStep] PadHud.%s has no complete %s; the rival will not show"):format(layout.Name, CARD_NAME))
		return nil
	end

	local camera = UiKit.create("Camera", { FieldOfView = CAMERA_FOV }, avatar)
	avatar.CurrentCamera = camera
	root.Visible = false

	return {
		layout = layout,
		root = root,
		scale = UiKit.scaleOf(root),
		ring = ring,
		art = child(root, "Art", "ImageLabel"),
		avatar = avatar,
		world = avatar:FindFirstChildOfClass("WorldModel") or UiKit.create("WorldModel", {}, avatar),
		camera = camera,
		headshot = headshot,
		name = name,
		bubble = bubble,
		bubbleScale = UiKit.scaleOf(bubble),
		bubbleText = bubbleText,
		bubbleBoxes = bubbleBoxesOf(bubble),
		puppet = nil,
		aim = Vector3.zero,
		fit = 1,
	}
end

-- A posed rig faces -Z, so the camera stands in front of it on that side.
local function aimCamera(card: Card)
	local aim = card.aim
	card.camera.CFrame =
		CFrame.lookAt(aim + Vector3.new(0, CAMERA_LIFT, -CAMERA_DISTANCE), aim - Vector3.new(0, LOOK_DROP, 0))
end

local function clearAvatar(card: Card)
	if card.puppet ~= nil then
		card.puppet:destroy()
	end

	card.puppet = nil
	card.headshot.Visible = false
	card.headshot.Image = ""
end

-- gui is the authored PadHud; without it the portrait draws nothing.
function RivalPortrait.new(gui: ScreenGui?): RivalPortrait
	local cards: { Card } = {}

	for _, layoutName in PadHud.Layouts do
		local layout = if gui ~= nil then gui:FindFirstChild(layoutName) else nil
		local card = if layout ~= nil and layout:IsA("GuiObject") then bindCard(layout) else nil

		if card ~= nil then
			table.insert(cards, card)
		end
	end

	local fields: Fields = {
		cards = cards,
		shown = false,
		rivalName = nil,
		color = DEFAULT_COLOR,
		share = 0.5,
		mood = nil,
		moodAt = 0,
		reaction = nil,
		reactionEnds = 0,
		userId = nil,
		lastBeat = -1,
		beatAt = -math.huge,
		lastFrame = os.clock(),
	}

	return setmetatable(fields, RivalPortrait)
end

function RivalPortrait.isShown(self: RivalPortrait): boolean
	return self.shown
end

-- look nil means no rival, and the card hides. Returns whether the rival changed.
function RivalPortrait.setRival(self: RivalPortrait, look: Look?): boolean
	local name = if look ~= nil then look.name else nil

	if self.shown == (look ~= nil) and self.rivalName == name then
		return false
	end

	self.shown = look ~= nil
	self.rivalName = name
	self.color = if look ~= nil and look.color ~= nil then look.color else DEFAULT_COLOR
	self.share = 0.5
	self.reaction = nil
	self.mood = nil
	self.userId = nil

	for _, card in self.cards do
		card.root.Visible = self.shown

		card.name.Text = string.upper(name or "")
		card.name.TextColor3 = self.color
		clearAvatar(card)
	end

	return true
end

-- source is copied, never moved. With no model, a userId shows the headshot.
function RivalPortrait.setAvatar(self: RivalPortrait, source: Model?, userId: number?)
	self.userId = userId

	for _, card in self.cards do
		clearAvatar(card)

		local puppet = if source ~= nil then AvatarPuppet.new(source, card.world) else nil

		if puppet ~= nil then
			card.puppet = puppet
			card.aim = puppet.focus
			aimCamera(card)
		end
	end

	-- The face is only set on a mood change, so a new avatar forces one.
	self.mood = nil

	if source == nil and userId ~= nil then
		self:_loadHeadshot(userId)
	end
end

-- Thumbnails are a web request, so the face fills in when it arrives.
function RivalPortrait._loadHeadshot(self: RivalPortrait, userId: number)
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		if not ok or self.userId ~= userId then
			return
		end

		for _, card in self.cards do
			if card.puppet == nil then
				card.headshot.Image = content
				card.headshot.Visible = true
			end
		end
	end)
end

function RivalPortrait.setLead(self: RivalPortrait, ownScore: number, rivalScore: number)
	local total = ownScore + rivalScore
	self.share = if total > 0 then rivalScore / total else 0.5
end

function RivalPortrait._startReaction(self: RivalPortrait, mood: Mood, seconds: number)
	self.reaction = mood
	self.reactionEnds = os.clock() + seconds
	self.mood = nil
end

-- grade is the rival's own; milestone marks a combo worth cheering.
function RivalPortrait.react(self: RivalPortrait, grade: string, milestone: boolean?)
	if milestone then
		self:_startReaction("cheer", CHEER_SECONDS)
		return
	end

	local mood: Mood? = if grade == "Miss"
		then "shocked"
		elseif grade == "Perfect" or grade == "Great" then "happy"
		else nil

	if mood ~= nil and (self.reaction ~= "cheer" or mood == "shocked") then
		self:_startReaction(mood, REACT_SECONDS)
	end
end

-- The player's own milestone: the rival is impressed, unless busy cheering.
function RivalPortrait.impressed(self: RivalPortrait)
	if self.reaction ~= "cheer" then
		self:_startReaction("impressed", CHEER_SECONDS)
	end
end

-- Pixels from originY to the bottom of the card showing, or 0 when hidden.
function RivalPortrait.bottom(self: RivalPortrait, originY: number): number
	if not self.shown then
		return 0
	end

	for _, card in self.cards do
		if card.layout.Visible then
			return card.root.AbsolutePosition.Y + card.root.AbsoluteSize.Y - originY
		end
	end

	return 0
end

-- limitY is the lowest absolute pixel row the card may reach: the top of the CLAP key or ability cards.
function RivalPortrait.fit(self: RivalPortrait, limitY: number)
	for _, card in self.cards do
		local height = card.root.AbsoluteSize.Y / math.max(card.scale.Scale, 0.01)

		if card.layout.Visible and height > 0 then
			card.fit = math.clamp((limitY - FIT_GAP - card.root.AbsolutePosition.Y) / height, FIT_MIN, 1)
		end
	end
end

function RivalPortrait._resting(self: RivalPortrait): Mood
	if self.share >= LEAD_SHARE then
		return "smug"
	elseif self.share <= 1 - LEAD_SHARE then
		return "worried"
	end

	return "idle"
end

function RivalPortrait._setMood(self: RivalPortrait, mood: Mood, now: number)
	if mood == self.mood then
		return
	end

	self.mood = mood
	self.moodAt = now

	local style = MOODS[mood]

	for _, card in self.cards do
		card.ring.Color = style.ring or self.color

		if card.art ~= nil then
			card.art.ImageColor3 = card.ring.Color
		end

		card.bubble.Visible = style.word ~= nil
		card.bubble.BackgroundColor3 = style.ring or self.color
		card.bubbleText.Text = style.word or ""

		local boxStyle = style.box

		if boxStyle and card.bubbleBoxes[boxStyle] then
			for name, box in card.bubbleBoxes do
				box.Visible = name == boxStyle
			end

			card.bubbleText.TextColor3 = BUBBLE_TEXT[boxStyle]
		end
		card.avatar.ImageColor3 = if mood == "worried" then LOSING_TINT else Colors.White

		if card.puppet ~= nil then
			card.puppet:setFace(FACE_KEYS, style.face)
		end
	end
end

-- The reaction's nod, shake or hop, turned about the head so it stays in frame.
local function pose(mood: Mood, since: number, focus: Vector3): CFrame
	local pitch, yaw, roll, lift = 0, 0, 0, 0
	local fade = math.max(1 - since / REACT_SECONDS, 0)

	if mood == "happy" then
		pitch = math.rad(NOD_DEGREES) * math.sin((1 - fade) * math.pi)
	elseif mood == "shocked" then
		yaw = math.rad(SHAKE_DEGREES) * math.sin(since * SHAKE_HZ * 2 * math.pi) * fade
		pitch = -math.rad(NOD_DEGREES / 2)
	elseif mood == "cheer" then
		lift = HOP_STUDS * math.abs(math.sin(since * HOP_HZ * math.pi))
		roll = math.rad(TILT_DEGREES) * math.sin(since * HOP_HZ * math.pi)
	elseif mood == "smug" then
		roll = math.rad(TILT_DEGREES)
		pitch = -math.rad(NOD_DEGREES / 3)
	elseif mood == "worried" then
		pitch = math.rad(NOD_DEGREES / 2)
	elseif mood == "impressed" then
		pitch = -math.rad(NOD_DEGREES) * math.min(since / BUBBLE_POP_SECONDS, 1)
	end

	return CFrame.new(focus + Vector3.new(0, lift, 0)) * CFrame.Angles(pitch, yaw, roll) * CFrame.new(-focus)
end

-- Called every frame of a run with the fractional song beat.
function RivalPortrait.update(self: RivalPortrait, beat: number)
	if not self.shown then
		return
	end

	local now = os.clock()
	local dt = math.clamp(now - self.lastFrame, 0, 0.1)
	self.lastFrame = now

	if self.reaction ~= nil and now >= self.reactionEnds then
		self.reaction = nil
	end

	local mood = self.reaction or self:_resting()
	self:_setMood(mood, now)

	local whole = math.floor(beat)

	if whole ~= self.lastBeat and beat >= 0 then
		self.lastBeat = whole
		self.beatAt = now
	end

	local bop = 1 + BOP * (1 - math.clamp((now - self.beatAt) / BOP_SECONDS, 0, 1)) ^ 2
	local since = now - self.moodAt
	local pop = 1 + (BUBBLE_POP - 1) * (1 - math.clamp(since / BUBBLE_POP_SECONDS, 0, 1))
	local shake = math.sin(since * BUBBLE_SHAKE_HZ * 2 * math.pi)
		* BUBBLE_SHAKE_DEGREES
		* math.max(1 - since / BUBBLE_SHAKE_SECONDS, 0)

	for _, card in self.cards do
		card.scale.Scale = card.fit * bop
		card.bubbleScale.Scale = pop
		card.bubble.Rotation = shake

		local puppet = card.puppet

		if puppet == nil or not card.layout.Visible then
			continue
		end

		-- Only the dance's drift is followed; the reaction's nod and shake stay in view.
		local head = puppet:pose(pose(mood, since, puppet.focus))

		if head ~= nil then
			card.aim = card.aim:Lerp(head, 1 - math.exp(-FOLLOW_RATE * dt))
			aimCamera(card)
		end
	end
end

return RivalPortrait
