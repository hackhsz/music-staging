--!strict
-- PromptUI — larger custom look for the pad's Start prompt. ProximityPromptStyle.Custom
-- renders nothing on its own, so this draws Templates.StartPromptGui while the prompt is
-- shown and picks the glyph for keyboard / gamepad / touch. The billboard is parented to
-- PlayerGui (adorned to the tile) so its card gets real touch/click input; a tap or click
-- starts the prompt's hold and the fill completes on its own, so nobody has to hold.

local RELEASE_SEC = 0.1
local STACK_STEP = 1.12

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local MatchRules = require(script.Parent:WaitForChild("MatchRules"))
local Templates = script.Parent:WaitForChild("Templates")
local GUI_TEMPLATE = Templates:WaitForChild("StartPromptGui")

local PromptUI = {}

type StackEntry = { rank: number, order: number, gui: BillboardGui }
local stacks: { [Instance]: { StackEntry } } = {}
local nextOrder = 0

local function restack(adornee: Instance)
	local entries = stacks[adornee]
	if not entries then
		return
	end
	if #entries == 0 then
		stacks[adornee] = nil
		return
	end
	table.sort(entries, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.order < b.order
	end)
	for index, entry in entries do
		entry.gui.SizeOffset = Vector2.new(0, (index - 1) * STACK_STEP)
	end
end

local function addToStack(adornee: Instance, entry: StackEntry)
	local entries = stacks[adornee] or {}
	stacks[adornee] = entries
	table.insert(entries, entry)
	restack(adornee)
end

local function removeFromStack(adornee: Instance, gui: BillboardGui)
	local entries = stacks[adornee]
	if not entries then
		return
	end
	for index, entry in entries do
		if entry.gui == gui then
			table.remove(entries, index)
			break
		end
	end
	restack(adornee)
end

local function glyphFor(prompt: ProximityPrompt): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "TAP"
	end
	if last.Name:match("^Gamepad") then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Draws the prompt until the returned cleanup is called.
function PromptUI.attach(prompt: ProximityPrompt): () -> ()
	local conns: { RBXScriptConnection } = {}
	local gui: BillboardGui? = nil
	local holdTween: Tween? = nil
	local latched = false
	local adornee = prompt.Parent :: Instance
	nextOrder += 1
	local order = nextOrder

	local function part(name: string): Instance
		local card = (gui :: BillboardGui):FindFirstChild("Card") :: Instance
		return card:FindFirstChild(name) :: Instance
	end

	local function refreshGlyph()
		if gui then
			(part("Key") :: TextButton).Text = glyphFor(prompt)
		end
	end

	local function setHold(active: boolean)
		if not gui then
			return
		end
		if holdTween then
			holdTween:Cancel()
		end
		local fill = part("Fill") :: Frame
		local info = TweenInfo.new(if active then prompt.HoldDuration else RELEASE_SEC, Enum.EasingStyle.Linear)
		holdTween = TweenService:Create(fill, info, { Size = UDim2.fromScale(if active then 1 else 0, 1) })
		;(holdTween :: Tween):Play()
	end

	local function release()
		if not latched then
			return
		end
		latched = false
		prompt:InputHoldEnd()
	end

	local function press(input: InputObject)
		if latched or not isPress(input) then
			return
		end
		latched = true
		prompt:InputHoldBegin()
	end

	local function hide()
		release()
		if gui then
			removeFromStack(adornee, gui)
			gui:Destroy()
			gui = nil
		end
	end

	local function show()
		if gui then
			return
		end
		local g = GUI_TEMPLATE:Clone()
		g.Adornee = adornee
		gui = g
		;(part("Label") :: TextLabel).Text = prompt.ActionText
		refreshGlyph()
		;(part("Key") :: GuiObject).InputBegan:Connect(press)
		;(g:FindFirstChild("Card") :: GuiObject).InputBegan:Connect(press)
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local rank = prompt:GetAttribute(MatchRules.PROMPT_STACK_ATTRIBUTE)
		addToStack(adornee, { rank = if type(rank) == "number" then rank else 1, order = order, gui = g })
	end

	table.insert(conns, prompt.PromptShown:Connect(show))
	table.insert(conns, prompt.PromptHidden:Connect(hide))
	table.insert(conns, prompt.Triggered:Connect(release))
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		setHold(true)
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		setHold(false)
	end))
	table.insert(conns, UserInputService.LastInputTypeChanged:Connect(refreshGlyph))

	return function()
		for _, c in conns do
			c:Disconnect()
		end
		hide()
	end
end

return PromptUI
