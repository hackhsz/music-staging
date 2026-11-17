-- RingVisualizer
-- Audio-reactive ring of neon bars driven by PlaybackLoudness.
-- Completely self-contained: pass it the bars folder, the Sound, and the Holder.

local RunService = game:GetService("RunService")

local clamp = math.clamp
local pi = math.pi
local sin = math.sin
local cos = math.cos
local tau = math.pi * 2

local RingVisualizer = {}
RingVisualizer.__index = RingVisualizer

function RingVisualizer.new(barsFolder, sound, holder)
	local self = setmetatable({}, RingVisualizer)

	self.Sound = sound
	self.Holder = holder
	self.Connection = nil
	self.Running = false

	-- Tunable parameters
	self.PeakLoudness = 1
	self.SmoothedLoudness = 0
	self.BaselineLoudness = 0
	self.BeatEnergy = 0
	self.Radius = 1
	self.MaxBarWidth = 15
	self.BaseBarWidth = 0.5
	self.LoudnessDivisor = 400
	self.RadiusGrowth = 0.3
	self.MinRadius = 0.5
	self.MaxRadius = 100
	self.Rainbow = true

	-- Wave parameters
	-- PhaseOffset rotates slowly around the ring so the "hot spot" drifts gently.
	-- RotationSpeed is in radians per second (0.6 rad/s ≈ one full lap every ~10s).
	self.RotationSpeed = 2.0
	self.WaveAmplitude = 0.7
	self.WaveBaseline = 0.2

	-- Size smoothing: fraction of the gap closed per second (higher = snappier)
	self.SizeLerpSpeed = 20

	-- Beat detection: how quickly the baseline follows the average volume
	-- (lower = slower baseline, so beats stand out more)
	self.BaselineDecay = 0.3
	-- How quickly beat energy decays after a hit (lower = longer tail)
	self.EnergyDecay = 5

	-- Collect bars sorted by their numeric name
	local entries = {}
	for _, child in ipairs(barsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			local n = tonumber(child.Name)
			if n then
				table.insert(entries, {idx = n, part = child})
			end
			end
		end
	table.sort(entries, function(a, b) return a.idx < b.idx end)

	self.Bars = {}
	self.BaseSizes = {}
	self.BarAlphas = {}
	for _, entry in ipairs(entries) do
		table.insert(self.Bars, entry.part)
		table.insert(self.BaseSizes, entry.part.Size)
		table.insert(self.BarAlphas, 0)
	end
	self.BarCount = #self.Bars

	-- Collect Motor6Ds and snapshot their original C0 offsets
	self.Motors = {}
	self.OriginalC0 = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("Motor6D") then
			table.insert(self.Motors, child)
			table.insert(self.OriginalC0, child.C0)
		end
	end

	return self
end

function RingVisualizer:Start()
	if self.Running then return end
	self.Running = true

	if self.Sound and not self.Sound.IsPlaying then
		self.Sound:Play()
	end

	local phaseOffset = 0
	local t = 0

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		t += dt

		-- Smooth the loudness so bars don't jitter on every sample
		local loudness = self.Sound.PlaybackLoudness
		self.SmoothedLoudness = self.SmoothedLoudness + (loudness - self.SmoothedLoudness) * math.min(dt * 8, 1)

		-- Slow-moving baseline tracks the average volume level
		self.BaselineLoudness = self.BaselineLoudness + (self.SmoothedLoudness - self.BaselineLoudness) * math.min(dt * self.BaselineDecay, 1)

		-- Beat energy = how much current audio exceeds the baseline
		local rawEnergy = math.max(self.SmoothedLoudness - self.BaselineLoudness, 0)
		if rawEnergy > self.BeatEnergy then
			self.BeatEnergy = rawEnergy
		else
			self.BeatEnergy = self.BeatEnergy - self.BeatEnergy * math.min(dt * self.EnergyDecay, 1)
		end

		-- Track peak with slow decay so amplitude stays responsive
		if loudness > self.PeakLoudness then
			self.PeakLoudness = loudness
		else
			self.PeakLoudness = self.PeakLoudness * 0.997 + loudness * 0.003
		end

		-- Normalised beat energy 0..1
		local energyNorm = clamp(self.BeatEnergy / math.max(self.PeakLoudness * 0.4, 1), 0, 1)

		-- Slowly rotate the wave around the ring
		phaseOffset += self.RotationSpeed * dt

		-- Smoothly approach target radius
		local targetRadius = clamp(
			(self.SmoothedLoudness / self.LoudnessDivisor) + self.RadiusGrowth,
			self.MinRadius, self.MaxRadius
		)
		self.Radius = self.Radius + (targetRadius - self.Radius) * math.min(dt * 3, 1)

		-- Scale every motor offset outward from the original layout
		for i, motor in ipairs(self.Motors) do
			local orig = self.OriginalC0[i]
			local px, py, pz = orig.Position.X, orig.Position.Y, orig.Position.Z
			local rx, ry, rz = orig:ToOrientation()
			motor.C0 = CFrame.new(px * self.Radius, py * self.Radius, pz * self.Radius)
				* CFrame.Angles(rx, ry, rz)
		end

		local lerpFactor = math.min(dt * self.SizeLerpSpeed, 1)

		for i, bar in ipairs(self.Bars) do
			-- Each bar's phase around the ring (0..tau)
			local barPhase = (i / self.BarCount) * tau

			-- Narrow spiked wave: cos^N gives a sharp peak with most bars staying low
			local delta = barPhase - phaseOffset
			local cosVal = cos(delta)
			local spike = 0
			if cosVal > 0 then
				spike = cosVal ^ 10
			end

			-- Small idle baseline so bars aren't totally flat between beats,
			-- but the spike only appears when there's real beat energy
			local targetAlpha = clamp(self.WaveBaseline * 0.3 + spike * energyNorm, 0, 1)

			-- Smoothly lerp the current alpha toward target for graceful rise/fall
			local current = self.BarAlphas[i]
			current = current + (targetAlpha - current) * lerpFactor
			self.BarAlphas[i] = current
			local alpha = current

			-- Taper the first and last few bars for a softer edge
			local edgeRange = 6
			local edgeTaper = 1
			if i < edgeRange then
				edgeTaper = i / edgeRange
			elseif i > self.BarCount - edgeRange then
				edgeTaper = (self.BarCount - i + 1) / edgeRange
			end
			edgeTaper = clamp(edgeTaper, 0, 1)

			-- Bar width grows with intensity and ring radius
			local baseSize = self.BaseSizes[i]
			local width = (self.BaseBarWidth + alpha * (self.MaxBarWidth - self.BaseBarWidth))
				* self.Radius * edgeTaper
			bar.Size = Vector3.new(width, baseSize.Y, baseSize.Z)

			-- Color: slow rolling rainbow tied to bar position + gentle time shift
			if self.Rainbow then
				local hue = ((i / self.BarCount) + t * 0.03) % 1
				bar.Color = Color3.fromHSV(hue, 0.6, 0.35 + alpha * 0.65)
			else
				local baseCol = Color3.fromRGB(195, 142, 255)
				local peakCol = Color3.fromRGB(255, 255, 255)
				bar.Color = baseCol:Lerp(peakCol, alpha)
			end
		end
	end)
end

function RingVisualizer:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.Sound then
		self.Sound:Pause()
	end
	self.Running = false

	-- Restore motors to their original layout
	for i, motor in ipairs(self.Motors) do
		motor.C0 = self.OriginalC0[i]
	end

	-- Restore bar sizes and reset smoothed alphas
	for i, bar in ipairs(self.Bars) do
		bar.Size = self.BaseSizes[i]
		self.BarAlphas[i] = 0
	end
	self.SmoothedLoudness = 0
	self.BaselineLoudness = 0
	self.BeatEnergy = 0
end

return RingVisualizer