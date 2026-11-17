local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("EmoteCatalog"))

-- Plays Roblox-owned catalog dance emotes on the player avatar at key
-- gameplay moments. Tracks are played on the local client: player
-- characters are client network-owned, so locally played AnimationTracks
-- replicate to the server and every other client automatically.
local AvatarReactionController = {}
AvatarReactionController.__index = AvatarReactionController

local function getAnimator(character: Model?): Animator?
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

function AvatarReactionController.playEmoteOnCharacter(character: Model?, emoteId: string): AnimationTrack?
	local emote = EmoteCatalog.getEmote(emoteId)

	if emote == nil or emote.animationId == nil then
		return nil
	end

	local animator = getAnimator(character)

	if animator == nil then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = ("rbxassetid://%d"):format(emote.animationId)

	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not loaded or track == nil then
		return nil
	end

	track.Looped = emote.looped == true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.15)

	-- Safety stop so non-looped reactions never get stuck.
	task.delay(emote.maxSeconds or 6, function()
		if track.IsPlaying and emote.looped ~= true then
			track:Stop(0.3)
		end
	end)

	return track
end

function AvatarReactionController.new()
	local self = setmetatable({
		player = Players.LocalPlayer,
		feverTrack = nil,
		feverActive = false,
		liveDance = false,
		lastMilestoneCombo = 0,
	}, AvatarReactionController)

	self.player.CharacterAdded:Connect(function()
		self.feverTrack = nil
		self.feverActive = false
	end)

	return self
end

function AvatarReactionController:playLocalEmote(emoteId: string): AnimationTrack?
	return AvatarReactionController.playEmoteOnCharacter(self.player.Character, emoteId)
end

function AvatarReactionController:reset()
	self:setFeverActive(false)
	self.lastMilestoneCombo = 0
end

-- While DanceAnimator is dancing to the presses, the Fever loop and the combo
-- cheer would freeze the dance under a canned emote, so they are skipped.
function AvatarReactionController:setLiveDance(active: boolean)
	self.liveDance = active

	if active and self.feverTrack ~= nil then
		self.feverTrack:Stop(0.3)
		self.feverTrack = nil
	end
end

function AvatarReactionController:setFeverActive(active: boolean)
	if active == self.feverActive then
		return
	end

	self.feverActive = active

	if active and not self.liveDance then
		self.feverTrack = self:playLocalEmote(EmoteCatalog.Reactions.feverStart)
	elseif self.feverTrack ~= nil then
		self.feverTrack:Stop(0.3)
		self.feverTrack = nil
	end
end

function AvatarReactionController:onComboMilestone(combo: number)
	local interval = EmoteCatalog.ComboMilestoneInterval

	if combo <= 0 or combo % interval ~= 0 or combo == self.lastMilestoneCombo then
		return
	end

	self.lastMilestoneCombo = combo

	-- Keep the fever dance loop running instead of interrupting it.
	if self.feverActive or self.liveDance then
		return
	end

	self:playLocalEmote(EmoteCatalog.Reactions.comboMilestone)
end

function AvatarReactionController:onSongComplete(rank: string?)
	self:setFeverActive(false)
	self.lastMilestoneCombo = 0

	if rank ~= nil and EmoteCatalog.HighRanks[rank] == true then
		self:playLocalEmote(EmoteCatalog.Reactions.songCompleteHighRank)
	end
end

return AvatarReactionController
