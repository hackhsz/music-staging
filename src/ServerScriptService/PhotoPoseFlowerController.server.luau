local CollectionService = game:GetService("CollectionService")

local poseIds = {
	"rbxassetid://130366748695089",
	"rbxassetid://109932401284008",
	"rbxassetid://125782971309211",
	"rbxassetid://104897775828231",
	"rbxassetid://109179352897794",
	"rbxassetid://110088159077911"
}
local TOTAL_STATES = #poseIds + 1 -- +1 for the "release back to idle" state

-- Keyed by player, then by flower, so each flower tracks its own progress per player
local playerSessions = {}

local function findClickDetector(flower)
	for _, child in ipairs(flower:GetDescendants()) do
		if child:IsA("ClickDetector") then
			return child
		end
	end
	return nil
end

local function setupFlower(flower)
	local detector = findClickDetector(flower)
	if not detector then
		warn("No ClickDetector found for", flower:GetFullName())
		return
	end

	detector.MouseClick:Connect(function(player)
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not animator then return end

		playerSessions[player] = playerSessions[player] or {}
		local session = playerSessions[player][flower]
		if not session then
			session = {index = 1, track = nil}
			playerSessions[player][flower] = session
		end

		-- Always stop whatever pose is currently playing
		if session.track then
			session.track:Stop()
			session.track = nil
		end

		if session.index <= #poseIds then
			-- Play the current pose
			local anim = Instance.new("Animation")
			anim.AnimationId = poseIds[session.index]
			local track = animator:LoadAnimation(anim)
			track:Play()
			session.track = track
		end
		-- else: index is the "release" state, track stays nil, player returns to normal idle/walk anims

		session.index = session.index + 1
		if session.index > TOTAL_STATES then
			session.index = 1
		end
	end)
end

-- Wire up all flowers currently tagged, plus any tagged later at runtime
for _, flower in ipairs(CollectionService:GetTagged("PhotoPoseFlower")) do
	setupFlower(flower)
end
CollectionService:GetInstanceAddedSignal("PhotoPoseFlower"):Connect(setupFlower)

game.Players.PlayerRemoving:Connect(function(player)
	playerSessions[player] = nil
end)