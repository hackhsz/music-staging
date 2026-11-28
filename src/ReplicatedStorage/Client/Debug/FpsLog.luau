--!strict
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

-- Frame-rate log for performance work, after AB's NetStats: the FPS is the frames
-- counted over each second, not one frame's delta, so it holds still. Each second
-- also takes what rendering cost the CPU and GPU, which still moves while vsync holds
-- the FPS at its cap. start() prints a line every PRINT_SECONDS, and early when the
-- state label changes; measure() samples a window for an A/B check from the command
-- bar, and format() turns its summary into the same line start() prints.
-- Runs in Studio unless Workspace's FpsLog attribute is false; set it true on a live
-- server to log on clients (Developer Console).
local SAMPLE_SECONDS = 1
local PRINT_SECONDS = 10

export type Summary = {
	label: string,
	seconds: number,
	fps: number,
	fpsLow: number,
	frameMs: number,
	cpuMs: number?,
	gpuMs: number?,
}

type Window = { started: number, fps: { number }, deltas: { number }, cpu: { number }, gpu: { number } }

local FpsLog = {}

local canReadRender = pcall(function()
	return Stats.RenderCPUFrameTime + Stats.RenderGPUFrameTime
end)
local started = false

local function median(values: { number }): number?
	local count = #values

	if count == 0 then
		return nil
	end

	local sorted = table.clone(values)
	table.sort(sorted)

	local middle = (count + 1) // 2

	return if count % 2 == 1 then sorted[middle] else (sorted[middle] + sorted[middle + 1]) / 2
end

local function newWindow(): Window
	return { started = os.clock(), fps = {}, deltas = {}, cpu = {}, gpu = {} }
end

local function summarize(label: string, window: Window): Summary
	return {
		label = label,
		seconds = os.clock() - window.started,
		fps = median(window.fps) or 0,
		fpsLow = if #window.fps > 0 then math.min(table.unpack(window.fps)) else 0,
		frameMs = (median(window.deltas) or 0) * 1000,
		cpuMs = median(window.cpu),
		gpuMs = median(window.gpu),
	}
end

-- Every frame adds its delta to the window; every second, the frames counted over it
-- and the render times, then calls onSecond.
local function track(window: () -> Window, onSecond: (() -> ())?): RBXScriptConnection
	local frames, elapsed = 0, 0

	return RunService.Heartbeat:Connect(function(delta: number)
		local current = window()
		frames += 1
		elapsed += delta
		table.insert(current.deltas, delta)

		if elapsed < SAMPLE_SECONDS then
			return
		end

		table.insert(current.fps, frames / elapsed)

		-- Studio often reads 0 for a frame the GPU timer missed; a 0 is no reading.
		if canReadRender and Stats.RenderCPUFrameTime > 0 then
			table.insert(current.cpu, Stats.RenderCPUFrameTime * 1000)
		end

		if canReadRender and Stats.RenderGPUFrameTime > 0 then
			table.insert(current.gpu, Stats.RenderGPUFrameTime * 1000)
		end

		frames, elapsed = 0, 0

		if onSecond ~= nil then
			onSecond()
		end
	end)
end

function FpsLog.format(summary: Summary): string
	local render = if summary.cpuMs ~= nil then (" | render cpu %.1f ms"):format(summary.cpuMs) else ""

	if summary.gpuMs ~= nil then
		render ..= (" gpu %.1f ms"):format(summary.gpuMs)
	end

	return ("[DanceDanceStep][FpsLog] %s %ds | FPS median %d (low %d) | frame %.1f ms%s"):format(
		summary.label,
		math.round(summary.seconds),
		math.round(summary.fps),
		math.round(summary.fpsLow),
		summary.frameMs,
		render
	)
end

-- Samples the next `seconds` and returns the summary. Yields.
function FpsLog.measure(seconds: number, label: string?): Summary
	local window = newWindow()
	local connection = track(function()
		return window
	end)

	task.wait(seconds)
	connection:Disconnect()

	return summarize(label or "measure", window)
end

local function shouldRun(): boolean
	local flag = Workspace:GetAttribute("FpsLog")

	return flag == true or (flag == nil and RunService:IsStudio())
end

-- labelOf names the state each line belongs to (lobby, run); when its answer changes
-- the current line is closed early, so states never share a median.
function FpsLog.start(labelOf: () -> string)
	if started then
		return
	end

	if not shouldRun() then
		local waiting: RBXScriptConnection? = nil
		waiting = Workspace:GetAttributeChangedSignal("FpsLog"):Connect(function()
			if shouldRun() and waiting ~= nil then
				waiting:Disconnect()
				FpsLog.start(labelOf)
			end
		end)

		return
	end

	started = true

	local label = labelOf()
	local window = newWindow()

	track(function()
		return window
	end, function()
		local now = labelOf()

		if now == label and os.clock() - window.started < PRINT_SECONDS then
			return
		end

		print(FpsLog.format(summarize(label, window)))
		label, window = now, newWindow()
	end)
end

return FpsLog
