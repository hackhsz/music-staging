--!strict
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.Parent.UiKit)

local TOAST_SLIDE_SECONDS = 0.25
local TOAST_HOLD_SECONDS = 2.5
local TOAST_AWAY = UDim2.fromScale(0, -0.2)
local RETIRED = { "Dim", "RankUp" }

type Fields = {
	toast: GuiObject?,
	toastTitle: TextLabel?,
	toastDetail: TextLabel?,
	toastHome: UDim2,
	finish: (() -> ())?,
	token: number,
}

-- The Toast that drops from the top edge when a run earns something, authored in
-- StarterGui.Progress. Drawing only; ProgressController decides what shows and in
-- what order.
local ProgressPopups = {}
ProgressPopups.__index = ProgressPopups

export type ProgressPopups = typeof(setmetatable({} :: Fields, ProgressPopups))

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

function ProgressPopups.new(gui: ScreenGui?): ProgressPopups
	local toast = UiKit.authored(gui, "Toast", "GuiObject")
	local fields: Fields = {
		toast = toast,
		toastTitle = UiKit.authored(toast, "NameLabel", "TextLabel"),
		toastDetail = UiKit.authored(toast, "ProgressLabel", "TextLabel"),
		toastHome = if toast ~= nil then toast.Position else UDim2.new(),
		finish = nil,
		token = 0,
	}
	local self = setmetatable(fields, ProgressPopups)

	-- The stage-up reveal replaced the rank-up card, but the place may still hold
	-- it; it stays hidden until it is deleted there.
	for _, name in RETIRED do
		local retired = UiKit.child(gui, name, "GuiObject")

		if retired ~= nil then
			retired.Visible = false
		end
	end

	if toast ~= nil then
		toast.Visible = false
	end

	return self
end

function ProgressPopups._finish(self: ProgressPopups)
	local finish = self.finish

	self.finish = nil
	self.token += 1

	if self.toast ~= nil then
		self.toast.Visible = false
	end

	if finish ~= nil then
		finish()
	end
end

-- Whatever is up goes at once; its callback still runs so the queue can end.
function ProgressPopups.clear(self: ProgressPopups)
	self:_finish()
end

function ProgressPopups.showToast(self: ProgressPopups, title: string, detail: string, onDone: () -> ())
	local toast = self.toast

	if toast == nil then
		onDone()
		return
	end

	self.finish = onDone
	self.token += 1

	local token = self.token

	if self.toastTitle ~= nil then
		self.toastTitle.Text = title
	end

	if self.toastDetail ~= nil then
		self.toastDetail.Text = detail
	end

	toast.Position = self.toastHome + TOAST_AWAY
	toast.Visible = true
	tween(toast, TOAST_SLIDE_SECONDS, { Position = self.toastHome })

	task.delay(TOAST_SLIDE_SECONDS + TOAST_HOLD_SECONDS, function()
		if self.token ~= token then
			return
		end

		tween(toast, TOAST_SLIDE_SECONDS, { Position = self.toastHome + TOAST_AWAY })
		task.delay(TOAST_SLIDE_SECONDS, function()
			if self.token == token then
				self:_finish()
			end
		end)
	end)
end

return ProgressPopups
