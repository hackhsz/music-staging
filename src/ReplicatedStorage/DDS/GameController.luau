--!strict
local POPUP_COLORS = {
	PERFECT = Color3.fromRGB(255, 230, 90),
	GREAT = Color3.fromRGB(120, 230, 140),
	GOOD = Color3.fromRGB(140, 190, 255),
	MISS = Color3.fromRGB(160, 160, 160),
	SHIELD = Color3.fromRGB(120, 200, 255),
	STAR = Color3.fromRGB(255, 200, 40),
	BOMB = Color3.fromRGB(255, 120, 60),
	FEVER = Color3.fromRGB(255, 64, 160),
	PULL = Color3.fromRGB(180, 140, 255),
}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local DDS = script.Parent
local BeatClock = require(DDS.BeatClock)
local GridInput = require(DDS.GridInput)
local JudgeLogic = require(DDS.JudgeLogic)
local ScoreFormula = require(DDS.ScoreFormula)
local PowerUpHandler = require(DDS.PowerUpHandler)
local AudioOffset = require(DDS.AudioOffset)
local Templates = DDS.Templates

local Controller = {}
Controller.__index = Controller

function Controller.new(pad: Model, chart: any, song: any, analyzer: AudioAnalyzer?, loadout: any?, options: { missBudget: number? }?)
	local self = setmetatable({}, Controller)
	self.loadout = loadout or PowerUpHandler.Loadout.new({})
	self.config = self.loadout.config
	self.pad = pad
	self.chart = chart
	self.song = song
	self.analyzer = analyzer
	self.beatSec = 60 / chart.bpm
	local baseRate = math.clamp(tonumber(DDS:GetAttribute("Rate")) or 1, self.config.RATE_MIN, self.config.RATE_MAX)
	DDS:SetAttribute("Rate", baseRate)
	self.rate = baseRate * self.config.RATE_MULT
	self.clock = BeatClock.new()
	self.tiles = {}
	self.cell = self.config.SPAWN_CELL
	self.settledAtSong = -math.huge
	self.score = 0
	self.earned = 0
	self.comboBreaks = 0
	self.noteCount = ScoreFormula.noteCount(chart)
	self.missBudget = options and options.missBudget
	self.combo = 0
	self.maxCombo = 0
	self.life = math.min(self.config.LIFE_START, self.config.LIFE_MAX)
	self.counts = { PERFECT = 0, GREAT = 0, GOOD = 0, MISS = 0 }
	self.eventIndex = 1
	self.pendingGrace = nil
	self.finished = false
	self.exhausted = false
	self.hype = 0
	self.perfectGroove = true
	self.assistedJudgements = 0
	self.clearedEvents = {}
	self.pendingItem = nil
	self.stepLockedUntil = 0
	self.bufferedStep = nil
	local starStepTime = self.config.STEP_TIME_BY_STARS[chart.stars or self.config.DIFFICULTY_STARS[chart.difficulty]]
	self.stepTimeSec = (chart.stepTimeMs or starStepTime or self.config.STEP_TIME_MS) * self.config.STEP_TIME_MULT / 1000
	self.conns = {}
	self.destroyed = false
	self.walkToken = 0 -- bumps cancel an in-flight walkTo chain
	self.resultsShown = Instance.new("BindableEvent")

	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			local r, c = d:GetAttribute("Row"), d:GetAttribute("Col")
			if r ~= nil and c ~= nil then
				self.tiles[r * self.config.GRID_SIZE + c] = d
				if not d:FindFirstChild("CountdownGui") then
					local gui = Templates.CountdownGui:Clone()
					gui.Adornee = d
					gui.Parent = d
				end
			end
		end
	end
	assert(next(self.tiles) ~= nil, "DDS: pad has no tiles with Row/Col attributes (streaming?)")
	return self
end

function Controller.tileAt(self, row: number, col: number): BasePart?
	return self.tiles[row * self.config.GRID_SIZE + col]
end

function Controller.cellToWorld(self, row: number, col: number): Vector3
	local t = self:tileAt(row, col)
	assert(t, `DDS: no tile at {row},{col}`)
	return t.Position
end

function Controller.setupCharacter(self)
	local player = Players.LocalPlayer
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	self.savedWalkSpeed = hum.WalkSpeed
	self.savedJumpPower = hum.JumpPower
	self.savedAutoRotate = hum.AutoRotate
	self.humanoid = hum
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false
	hrp.Anchored = true
	self.char = char
	self.hrp = hrp
	local spawnPos = self:cellToWorld(self.cell.X, self.cell.Y)
	hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3.5, 0), spawnPos + Vector3.new(0, 3.5, -8))

	local popup = Templates.JudgePopup:Clone()
	popup.Adornee = hrp
	popup.Parent = char
	self.popup = popup
end

function Controller.setupCamera(self)
	local cam = workspace.CurrentCamera
	self.savedFieldOfView = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local center = self.pad:GetBoundingBox().Position
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, 52, 34), center)
	cam.FieldOfView = 55
	self.camera = cam
end

function Controller.pulseCombo(self)
	local label = self.hud and self.hud:FindFirstChild("Combo")
	if not label then return end
	local scale = label:FindFirstChild("PulseScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PulseScale"
		scale.Parent = label
	end
	scale.Scale = 1.22
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Controller.punchCamera(self)
	local cam = self.camera
	if not cam then return end
	local t = TweenService:Create(cam, TweenInfo.new(0.05, Enum.EasingStyle.Linear), { FieldOfView = 52.5 })
	t.Completed:Once(function()
		TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 55 }):Play()
	end)
	t:Play()
end

function Controller.setupHud(self)
	local hud = Templates.HUD:Clone()
	hud.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.hud = hud
end

function Controller.tryStep(self, dir: Vector2, fromWalk: boolean?, pressedAt: number?)
	if not fromWalk then
		self.walkToken += 1 -- direct input always overrides a tap-to-walk chain
	end
	local now = os.clock()
	if now < self.stepLockedUntil then
		self.bufferedStep = dir
		return
	end
	local target = self.cell + dir
	if target.X < 0 or target.X >= self.config.GRID_SIZE or target.Y < 0 or target.Y >= self.config.GRID_SIZE then
		self:playSfx("Bump")
		return
	end
	local startedAt = JudgeLogic.stepStart(now, pressedAt, self.stepLockedUntil, self.config.MAX_PRESS_BACKDATE_MS / 1000)
	self.stepLockedUntil = startedAt + self.stepTimeSec
	self.cell = target
	-- Judged landing is press + JUDGE_LAND_MS (song time), independent of how long the step animates.
	self.settledAtSong = self.clock:getSongTime() - (now - startedAt) * self.rate + self.config.JUDGE_LAND_MS * self.rate / 1000
	local g = self.pendingGrace
	local graceHit = g ~= nil and self:isOnTiles(g.ev.tiles)
	self:resolveGraceIfAny()
	self:resolvePendingItem()
	local pos = self:cellToWorld(target.X, target.Y) + Vector3.new(0, 3.5, 0)
	local look = CFrame.lookAt(pos, pos + Vector3.new(dir.Y, 0, dir.X))
	-- Snap, don't glide: linear travel well under a beat, then a landing dip.
	local tween = TweenService:Create(self.hrp, TweenInfo.new(self.stepTimeSec, Enum.EasingStyle.Linear), { CFrame = look })
	tween.Completed:Once(function(state)
		-- A faster next step cancels this tween; its landing must not run (it would
		-- tween the character back to this tile underneath the new step).
		if state ~= Enum.PlaybackState.Completed then return end
		if not self.hrp or not self.hrp.Parent then return end
		self:landingStamp(look)
	end)
	tween:Play()
	-- The landing IS the hit: percussive group sound the instant you commit
	-- onto a live target (grace recovery or the telegraphed next event).
	local ev = self.chart.events[self.eventIndex]
	if graceHit or (ev and ev.kind ~= "DANGER" and self:isOnTiles(ev.tiles)) then
		self:playHitGroup(true)
	end
end

-- Tap-to-walk (mobile): step toward a tapped tile one step time at a time, longest
-- axis first, until we arrive or any direct input takes over. Multi-tile taps are
-- legitimate: chart reachability already allows delta+1 tiles between events.
-- Steps are scheduled back to back from the tap's touch-down, so the walk is judged as if
-- it started when the finger landed rather than when it lifted.
function Controller.walkTo(self, row: number, col: number, pressedAt: number?)
	self.walkToken += 1
	local token = self.walkToken
	local nextStart = pressedAt
	task.spawn(function()
		for _ = 1, self.config.GRID_SIZE * 4 do
			if self.destroyed or self.walkToken ~= token then
				return
			end
			local waitSec = self.stepLockedUntil - os.clock()
			if waitSec > 0 then
				task.wait(waitSec)
				continue
			end
			local dr, dc = row - self.cell.X, col - self.cell.Y
			if dr == 0 and dc == 0 then
				return
			end
			local dir = if math.abs(dr) >= math.abs(dc) then Vector2.new(math.sign(dr), 0) else Vector2.new(0, math.sign(dc))
			self:tryStep(dir, true, nextStart)
			nextStart = self.stepLockedUntil
		end
	end)
end

function Controller.landingStamp(self, look: CFrame)
	local dip = TweenService:Create(self.hrp, TweenInfo.new(0.04, Enum.EasingStyle.Linear), { CFrame = look * CFrame.new(0, -0.3, 0) })
	dip.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed then return end -- superseded by the next step
		TweenService:Create(self.hrp, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = look }):Play()
	end)
	dip:Play()
	local tile = self:tileAt(self.cell.X, self.cell.Y)
	if tile then
		local baseY = tile:GetAttribute("BaseY")
		if baseY == nil then baseY = tile.Position.Y; tile:SetAttribute("BaseY", baseY) end
		tile.Position = Vector3.new(tile.Position.X, baseY - 0.22, tile.Position.Z)
		task.delay(0.05, function()
			tile.Position = Vector3.new(tile.Position.X, baseY, tile.Position.Z)
		end)
	end
end

function Controller.isOnTiles(self, tiles): boolean
	for _, rc in tiles do
		if self.cell.X == rc[1] and self.cell.Y == rc[2] then return true end
	end
	return false
end

function Controller.windowsFor(self, config)
	return {
		PERFECT_LAND_MS = config.PERFECT_LAND_MS * self.rate,
		GREAT_LAND_MS = config.GREAT_LAND_MS * self.rate,
	}
end

function Controller.tierForLanding(self, beatTime: number): string
	local landDelta = beatTime - self.settledAtSong
	local tier = JudgeLogic.tier(landDelta, self:windowsFor(self.config))
	local baseTier = JudgeLogic.tier(landDelta, self:windowsFor(self.loadout.baseConfig))
	if tier ~= baseTier then
		local weightGain = self.config.JUDGE_WEIGHT[tier] - self.config.JUDGE_WEIGHT[baseTier]
		self:recordAssist(self.loadout.timingAssistId or "Timing", math.floor(weightGain * self.config.SCORE_ACCURACY_MAX / math.max(1, self.noteCount)))
	end
	return tier
end

function Controller.colorForKind(self, kind: string): Color3
	if kind == "SHAPE" then return self.config.SHAPE_COLOR end
	if kind == "DANGER" then return self.config.DANGER_COLOR end
	if kind == "ITEM" then return self.config.ITEM_COLOR end
	return self.config.TARGET_COLOR
end

function Controller.applyJudgement(self, tier: string, ev)
	if self.exhausted then
		self:flashTiles(ev, tier)
		return
	end
	tier = self.loadout:TransformTier(self, tier, ev)
	local absorbedBy = if tier == "MISS" then self.loadout:AbsorbMiss(self, ev) else nil
	if absorbedBy then
		self.counts.MISS += 1
		self.perfectGroove = false
		self:playSfx("Miss")
		self:flashTiles(ev, tier)
		self:showPopup(absorbedBy)
		self:updateHud()
		return
	end
	self.counts[tier] += 1
	local isDodge = ev.kind == "DANGER" and tier ~= "MISS"
	if tier ~= "PERFECT" and not isDodge then
		self.perfectGroove = false
	end
	if tier == "MISS" then
		self:playSfx("Miss")
		if self.combo >= 4 then
			self:playSfx("ComboBreak")
		end
		self.hype = math.max(0, self.hype + self.config.HYPE_MISS_DECAY)
		self.combo = 0
		self.comboBreaks += 1
		if not self.missBudget then
			self.life = math.max(0, self.life + ScoreFormula.lifeDelta(tier, self.config))
		end
		if self.life <= 0 or (self.missBudget and self.counts.MISS > self.missBudget) then
			self.exhausted = true
			self.popup.Label.Text = "EXHAUSTED"
			self.popup.Label.TextColor3 = Color3.fromRGB(200, 120, 120)
			self.popup.Label.TextTransparency = 0
		end
	else
		if tier == "PERFECT" then
			self:perfectFlash()
			if self.combo >= 7 then
				self:punchCamera()
			end
		end
		if self.combo >= self.config.HYPE_MIN_COMBO then
			self:addHype(if tier == "PERFECT" then self.config.HYPE_PERFECT elseif tier == "GREAT" then self.config.HYPE_GREAT else 0)
		end
		self.earned += self.config.JUDGE_WEIGHT[tier]
		self.score = ScoreFormula.liveScore(self.earned, self.noteCount, self.loadout.scoreMultiplier, self.config)
		self.combo += 1
		self:pulseCombo()
		self.maxCombo = math.max(self.maxCombo, self.combo)
		self.life = math.min(self.config.LIFE_MAX, self.life + ScoreFormula.lifeDelta(if isDodge then "GREAT" else tier, self.config))
		if table.find(self.config.COMBO_MILESTONES, self.combo) then
			self:comboMilestone()
		end
	end
	self:flashTiles(ev, tier)
	self:showPopup(tier)
	self:updateHud()
end

function Controller.addHype(self, amount: number)
	self.hype = math.min(self.config.HYPE_MAX, self.hype + amount)
	if self.hype < self.config.HYPE_MAX then
		return
	end
	if self.loadout:HandleHypeFull(self) then
		return
	end
	self.hype = 0
	self:playSfx("CheerFever")
	self:perfectFlash()
	DDS:SetAttribute("HypeMoment", (DDS:GetAttribute("HypeMoment") or 0) + 1)
end

function Controller.comboMilestone(self)
	self:perfectFlash()
	self:punchCamera()
	DDS:SetAttribute("ComboMilestone", self.combo)
end

function Controller.recordAssist(self, id: string, points: number)
	self.assistedJudgements += 1
	self.loadout:RecordAssist(id, points)
end

function Controller.useAbility(self)
	if self.exhausted or self.finished then
		return
	end
	local popupText = self.loadout:UseAbility(self)
	if not popupText then
		return
	end
	self:showPopup(popupText)
	self:updateHud()
end

function Controller.collectItem(self, ev, tier: string)
	if self.exhausted then
		return
	end
	local popupText = self.loadout:Collect(self, ev, tier)
	if not popupText then
		self:fadeTilesToIdle(ev)
		return
	end
	self:playSfx("Perfect")
	self:flashTiles(ev, "PERFECT")
	self:showPopup(popupText)
	self:updateHud()
end

function Controller.resolvePendingItem(self)
	local item = self.pendingItem
	if not item or not self:isOnTiles(item.ev.tiles) then
		return
	end
	if self.clock:getSongTime() - item.missedAtSong > self.config.LATE_GRACE_MS * self.rate / 1000 then
		return
	end
	self.pendingItem = nil
	self:collectItem(item.ev, self:tierForLanding(self.clock:beatToTime(item.ev.beat)))
end

function Controller.fadeTilesToIdle(self, ev)
	local fadeSec = self.config.SPENT_FADE_BEATS * self.beatSec * 0.5
	for _, rc in ev.tiles do
		local t = self:tileAt(rc[1], rc[2])
		if t then
			t.Material = Enum.Material.SmoothPlastic
			TweenService:Create(t, TweenInfo.new(fadeSec), { Color = self:idleColorFor(t) }):Play()
		end
	end
end

function Controller.clearNextEvent(self, kind: string): boolean
	for index = self.eventIndex, #self.chart.events do
		local ev = self.chart.events[index]
		if ev.kind == kind and not self.clearedEvents[index] then
			self.clearedEvents[index] = true
			self:clearCountdown(ev)
			self:fadeTilesToIdle(ev)
			return true
		end
	end
	return false
end

function Controller.pullTo(self, row: number, col: number)
	self.walkToken += 1
	self.cell = Vector2.new(row, col)
	local pos = self:cellToWorld(row, col) + Vector3.new(0, 3.5, 0)
	local facing = self.hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	local look = CFrame.lookAt(pos, pos + (if facing.Magnitude > 0 then facing.Unit else Vector3.new(0, 0, -1)))
	TweenService:Create(self.hrp, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = look }):Play()
end

function Controller.ghostVisibility(self, beatsAway: number, lead: number): number
	local fadeBeats = math.min(self.config.TELEGRAPH_FADE_OUT_BEATS, lead * 0.5)
	if fadeBeats <= 0 then
		return 1
	end
	return math.clamp(beatsAway / fadeBeats, 0, 1)
end

function Controller.crownFor(self): string?
	if self.exhausted then
		return nil
	end
	if self.counts.MISS > 0 or self.assistedJudgements > 0 then
		return "CLEAR"
	end
	if self.perfectGroove then
		return "PERFECT GROOVE"
	end
	return "FULL GROOVE"
end

function Controller.perfectFlash(self)
	local frame = self.screenFlash.Flash
	frame.BackgroundTransparency = 0.88
	TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
end

function Controller.playHitGroup(self, alternating: boolean)
	local g = self.hitGroup
	if not g or g.n == 0 then return end
	if not alternating then g.idx = 1 end
	local pool = g[g.idx]
	pool[pool.idx]:Play()
	pool.idx = pool.idx % 3 + 1
	g.idx = g.idx % g.n + 1
end

function Controller.playSfx(self, name: string)
	local pool = self.sfx and self.sfx[name]
	if not pool then return end
	pool[pool.idx]:Play()
	pool.idx = pool.idx % 3 + 1
end

function Controller.showPopup(self, tier: string)
	if self.exhausted then return end
	local label = self.popup.Label
	label.Text = tier
	label.TextColor3 = POPUP_COLORS[tier] or POPUP_COLORS.PERFECT
	label.TextTransparency = 0
	task.delay(self.config.POPUP_MS / 1000, function()
		if label.Text == tier then label.TextTransparency = 1; label.Text = "" end
	end)
end

function Controller.updateHud(self)
	self.hud.Score.Text = tostring(self.score)
	self.hud.Combo.Text = self.combo >= 2 and (tostring(self.combo) .. " COMBO") or ""
	self.hud.LifeBack.LifeFill.Size = UDim2.fromScale(self.life / self.config.LIFE_MAX, 1)
	self.hud.Status.Text = self.loadout:GetStatusText(self)
	self.hud.AbilityButton.Visible = self.loadout:IsAbilityReady(self)
end

function Controller.flashTiles(self, ev, tier: string)
	local fadeSec = self.config.SPENT_FADE_BEATS * self.beatSec
	if ev.kind == "DANGER" and tier ~= "MISS" then
		for _, rc in ev.tiles do
			local t = self:tileAt(rc[1], rc[2])
			if t then
				t.Material = Enum.Material.SmoothPlastic
				TweenService:Create(t, TweenInfo.new(fadeSec * 0.5), { Color = self:idleColorFor(t) }):Play()
			end
		end
		return
	end
	local flashColor = tier == "MISS" and Color3.fromRGB(90, 40, 40) or self.config.HIT_COLOR
	for _, rc in ev.tiles do
		local t = self:tileAt(rc[1], rc[2])
		if t then
			t.Color = flashColor
			t.Material = Enum.Material.Neon
		end
	end
	task.delay(0.1, function()
		for _, rc in ev.tiles do
			local t = self:tileAt(rc[1], rc[2])
			if t then
				TweenService:Create(t, TweenInfo.new(fadeSec), { Color = self:idleColorFor(t) }):Play()
				task.delay(fadeSec, function() t.Material = Enum.Material.SmoothPlastic end)
			end
		end
	end)
end

function Controller.resolveGraceIfAny(self)
	local g = self.pendingGrace
	if not g then return end
	if self.clock:getSongTime() - g.missedAtSong <= self.config.LATE_GRACE_MS * self.rate / 1000 and self:isOnTiles(g.ev.tiles) then
		self.pendingGrace = nil
		self:applyJudgement(self:tierForLanding(self.clock:beatToTime(g.ev.beat)), g.ev)
	end
end

function Controller.updateTelegraphs(self)
	local songBeat = self.clock:getBeat()
	local activeTiles = {}
	for i = self.eventIndex, #self.chart.events do
		local ev = self.chart.events[i]
		local beatsAway = ev.beat - songBeat
		local lead = self.chart.W or self.config.TELEGRAPH_LEAD
		if beatsAway > lead * self.config.PREVIEW_LEAD_MULT then break end
		if self.clearedEvents[i] then continue end
		if beatsAway > lead then
			-- On-deck preview (feedback: show the next 1-2 beats). Never paints
			-- over the active telegraph when events share tiles (holds).
			local base = self:colorForKind(ev.kind)
			for _, rc in ev.tiles do
				if not activeTiles[rc[1] * 5 + rc[2]] then
					local t = self:tileAt(rc[1], rc[2])
					if t then
						t.Color = self:idleColorFor(t):Lerp(base, self.config.PREVIEW_ALPHA)
						t.Material = Enum.Material.SmoothPlastic
					end
				end
			end
		elseif beatsAway > 0 then
			local progress = 1 - (beatsAway / lead)
			local eased = progress * progress
			local alpha = self.config.TELEGRAPH_MIN_ALPHA + (1 - self.config.TELEGRAPH_MIN_ALPHA) * eased
			local visibility = self:ghostVisibility(beatsAway, lead)
			alpha *= visibility
			local base = self:colorForKind(ev.kind)
			for _, rc in ev.tiles do
				activeTiles[rc[1] * 5 + rc[2]] = true
				local t = self:tileAt(rc[1], rc[2])
				if t then
					t.Color = self:idleColorFor(t):Lerp(base, alpha)
					t.Material = alpha > 0.6 and Enum.Material.Neon or Enum.Material.SmoothPlastic
					local count = t.CountdownGui.Count
					count.Text = tostring(math.ceil(beatsAway))
					count.TextTransparency = if visibility < 1 then 1 else 0.2
				end
			end
		end
	end
end

function Controller.clearCountdown(self, ev)
	for _, rc in ev.tiles do
		local t = self:tileAt(rc[1], rc[2])
		if t then
			t.CountdownGui.Count.Text = ""
			t.CountdownGui.Count.TextTransparency = 1
		end
	end
end

function Controller.setLobbyLook(self)
	for _, t in self.tiles do
		local r, c = t:GetAttribute("Row"), t:GetAttribute("Col")
		t.Color = (r + c) % 2 == 0 and self.config.LOBBY_COLOR_A or self.config.LOBBY_COLOR_B
		t.Material = Enum.Material.SmoothPlastic
		t.CountdownGui.Count.Text = ""
	end
end

function Controller.idleColorFor(self, t): Color3
	local r, c = t:GetAttribute("Row"), t:GetAttribute("Col")
	return (r + c) % 2 == 0 and self.config.IDLE_COLOR or self.config.IDLE_COLOR_ALT
end

function Controller.setGameLook(self)
	for _, t in self.tiles do
		t.Color = self:idleColorFor(t)
		t.Material = Enum.Material.SmoothPlastic
	end
end

function Controller.dodgeDirection(self, tiles): Vector2?
	for _, dir in { Vector2.new(-1, 0), Vector2.new(1, 0), Vector2.new(0, -1), Vector2.new(0, 1) } do
		local target = self.cell + dir
		if target.X < 0 or target.X >= self.config.GRID_SIZE or target.Y < 0 or target.Y >= self.config.GRID_SIZE then
			continue
		end
		local blocked = false
		for _, rc in tiles do
			if target.X == rc[1] and target.Y == rc[2] then blocked = true; break end
		end
		if not blocked then return dir end
	end
	return nil
end

function Controller.autopilotStep(self)
	local ev = self.chart.events[self.eventIndex]
	if not ev or os.clock() - self.lastAutoStep <= 0.15 then return end
	local beatsAway = ev.beat - self.clock:getBeat()
	if beatsAway > (self.chart.W or self.config.TELEGRAPH_LEAD) then return end
	local onTiles = self:isOnTiles(ev.tiles)
	if ev.kind == "DANGER" then
		if not onTiles then return end
		local dir = self:dodgeDirection(ev.tiles)
		if dir then
			self:tryStep(dir)
			self.lastAutoStep = os.clock()
		end
		return
	end
	if onTiles then return end
	local best, bd = nil, math.huge
	for _, rc in ev.tiles do
		local d = math.abs(rc[1] - self.cell.X) + math.abs(rc[2] - self.cell.Y)
		if d < bd then bd = d; best = rc end
	end
	if not best then return end
	local dr, dc = best[1] - self.cell.X, best[2] - self.cell.Y
	local dir = math.abs(dr) >= math.abs(dc) and Vector2.new(math.sign(dr), 0) or Vector2.new(0, math.sign(dc))
	self:tryStep(dir)
	self.lastAutoStep = os.clock()
end

function Controller.start(self)
	self:setupCharacter()
	self:setupCamera()
	self:setupHud()
	self.input = GridInput.new(self.hud, function(dir)
		self:tryStep(dir)
	end, function()
		self:useAbility()
	end)
	self.input:enable()
	table.insert(self.conns, self.hud.AbilityButton.Activated:Connect(function()
		self:useAbility()
	end))
	self:setGameLook()
	self.sfx = {}
	for _, template in Templates.SFX:GetChildren() do
		local pool = { idx = 1 }
		for i = 1, 3 do
			local s = template:Clone()
			s.Parent = workspace
			pool[i] = s
		end
		self.sfx[template.Name] = pool
	end
	local groupFolder = Templates.SFX.HitGroups:FindFirstChild(self.chart.hitSfxGroup or "Clap") or Templates.SFX.HitGroups.Clap
	self.hitGroup = { idx = 1, n = #groupFolder:GetChildren() }
	for i, template in groupFolder:GetChildren() do
		local pool = { idx = 1 }
		for k = 1, 3 do
			local s = template:Clone()
			s.Parent = workspace
			pool[k] = s
		end
		self.hitGroup[i] = pool
	end
	self.screenFlash = Templates.ScreenFlash:Clone()
	self.screenFlash.Parent = Players.LocalPlayer.PlayerGui
	self:updateHud()

	local tick = Instance.new("Sound")
	tick.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	tick.Volume = 0.18
	tick.Parent = workspace
	self.tick = tick
	if DDS:GetAttribute("Metronome") == nil then
		DDS:SetAttribute("Metronome", true)
	end

	if self.song then
		self.song.PlaybackSpeed = self.rate
	end
	self:playSfx("CountdownReady")
	local quarterSec = self.config.PRE_ROLL_MS / 4000
	for count = 3, 1, -1 do
		self.popup.Label.Text = tostring(count)
		self.popup.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
		self.popup.Label.TextTransparency = 0
		task.wait(quarterSec)
	end
	self.popup.Label.Text = "GO!"
	self.popup.Label.TextColor3 = Color3.fromRGB(120, 230, 140)
	self:playSfx("CountdownGo")
	task.delay(quarterSec, function()
		if self.popup.Label.Text == "GO!" then self.popup.Label.TextTransparency = 1; self.popup.Label.Text = "" end
	end)
	self.clock:start({ bpm = self.chart.bpm, firstBeatSec = self.chart.firstBeatSec or 0, sound = self.song })
	self.settledAtSong = self.clock:getSongTime()

	table.insert(self.conns, self.clock:onBeat(function(beatIndex)
		if beatIndex >= 0 and DDS:GetAttribute("Metronome") then
			tick.PlaybackSpeed = beatIndex % 4 == 0 and 1.25 or 0.9
			tick:Play()
		end
	end))

	self.lastAutoStep = 0
	table.insert(self.conns, RunService.Heartbeat:Connect(function()
		self.clock.audioOffsetSec = (AudioOffset.get() + (self.chart.audioOffsetMs or 0)) / 1000
		if self.bufferedStep and os.clock() >= self.stepLockedUntil then
			local dir = self.bufferedStep
			self.bufferedStep = nil
			self:tryStep(dir, true, self.stepLockedUntil)
		end
		local songTime = self.clock:getSongTime()
		self:updateTelegraphs()

		if DDS:GetAttribute("Autopilot") then
			self:autopilotStep()
		end

		local g = self.pendingGrace
		if g and songTime - g.missedAtSong > self.config.LATE_GRACE_MS * self.rate / 1000 then
			self.pendingGrace = nil
			self:applyJudgement("MISS", g.ev)
		end

		local item = self.pendingItem
		if item and songTime - item.missedAtSong > self.config.LATE_GRACE_MS * self.rate / 1000 then
			self.pendingItem = nil
			self:fadeTilesToIdle(item.ev)
		end

		local ev = self.chart.events[self.eventIndex]
		if ev then
			local beatTime = self.clock:beatToTime(ev.beat)
			if songTime >= beatTime then
				local cleared = self.clearedEvents[self.eventIndex] == true
				self.eventIndex += 1
				self:clearCountdown(ev)
				if ev.kind == "ITEM" then
					if self:isOnTiles(ev.tiles) then
						self:collectItem(ev, self:tierForLanding(beatTime))
					else
						self.pendingItem = { ev = ev, missedAtSong = songTime }
					end
				elseif ev.kind == "DANGER" then
					if not cleared then
						self:applyJudgement(if self:isOnTiles(ev.tiles) then "MISS" else self.config.DODGE_TIER, ev)
					end
				elseif self:isOnTiles(ev.tiles) then
					self:applyJudgement(self:tierForLanding(beatTime), ev)
				else
					self.pendingGrace = { ev = ev, missedAtSong = songTime }
				end
			end
		elseif not self.finished then
			self.finished = true
			task.delay(2, function() self:showResults() end)
		end
	end))
end

function Controller.showResults(self)
	local summary = ScoreFormula.summarize(self.counts, self.comboBreaks, self.loadout.scoreMultiplier, not self.exhausted, self.config)
	local acc, rank = summary.accuracy, summary.rank or "-"
	self.score = summary.final
	self.hud.Score.Text = string.format("%d  |  %.2f%%  RANK %s", self.score, acc, rank)
	self.hud.Combo.Text = string.format("P%d G%d O%d M%d  maxCombo %d", self.counts.PERFECT, self.counts.GREAT, self.counts.GOOD, self.counts.MISS, self.maxCombo)
	self:setLobbyLook()
	print(string.format("[DDS] Results: score=%d acc=%.1f%% rank=%s P=%d G=%d O=%d M=%d maxCombo=%d",
		self.score, acc, rank, self.counts.PERFECT, self.counts.GREAT, self.counts.GOOD, self.counts.MISS, self.maxCombo))
	local crown = self:crownFor()
	self.result = {
		counts = table.clone(self.counts),
		comboBreaks = self.comboBreaks,
		score = self.score,
		crown = crown,
		exhausted = self.exhausted,
		items = self.loadout:GetIds(),
	}
	self.hud.Status.Text = string.format("%s   score x%.2f", crown or "FAILED", self.loadout.scoreMultiplier)
	DDS:SetAttribute("LastCrown", crown or "")
	print(string.format("[DDS] Crown=%s scoreMult=%.2f assisted=%s assists=[%s] coins x%.1f xp x%.1f",
		crown or "none", self.loadout.scoreMultiplier, tostring(self.loadout.assisted), self.loadout:GetAssistSummary(),
		self.loadout.coinMultiplier, self.loadout.xpMultiplier))
	self.resultsShown:Fire()
end

function Controller.showReward(self, reward)
	if self.destroyed or not self.hud then
		return
	end
	local parts = { reward.crown or "FAILED" }
	if reward.rank then
		table.insert(parts, "RANK " .. reward.rank)
	end
	if reward.newBest then
		table.insert(parts, "NEW BEST")
	end
	table.insert(parts, string.format("+%d XP", reward.xp or 0))
	if (reward.crownPoints or 0) > 0 then
		table.insert(parts, string.format("+%d CP", reward.crownPoints))
	end
	table.insert(parts, string.format("+%d coins", reward.coins or 0))
	if reward.crate then
		table.insert(parts, string.format("%s CRATE: %s", string.upper(reward.crate.tier), reward.crate.itemName or string.format("+%d coins", reward.crate.coins or 0)))
	end
	self.hud.Status.Text = table.concat(parts, "   ")
end

local function destroyPool(pool)
	if not pool then return end
	for i = 1, 3 do
		if pool[i] then pool[i]:Destroy() end
	end
end

function Controller.destroy(self)
	if self.destroyed then return end
	self.destroyed = true

	for _, conn in self.conns do
		conn:Disconnect()
	end
	table.clear(self.conns)
	self.clock:stop()

	if self.input then
		self.input:destroy()
		self.input = nil
	end

	for _, pool in self.sfx or {} do
		destroyPool(pool)
	end
	self.sfx = nil
	if self.hitGroup then
		for i = 1, self.hitGroup.n do
			destroyPool(self.hitGroup[i])
		end
		self.hitGroup = nil
	end
	if self.tick then self.tick:Destroy() end
	if self.screenFlash then self.screenFlash:Destroy() end
	if self.hud then self.hud:Destroy() end
	if self.popup then self.popup:Destroy() end

	self:setLobbyLook()
	for _, t in self.tiles do
		local gui = t:FindFirstChild("CountdownGui")
		if gui then gui:Destroy() end
	end

	local hum = self.humanoid
	if hum and hum.Parent and self.hrp then
		self.hrp.Anchored = false
		hum.WalkSpeed = self.savedWalkSpeed
		hum.JumpPower = self.savedJumpPower
		hum.AutoRotate = self.savedAutoRotate
	end

	local cam = self.camera
	if cam then
		cam.FieldOfView = self.savedFieldOfView
		cam.CameraType = Enum.CameraType.Custom
		if hum and hum.Parent then cam.CameraSubject = hum end
		self.camera = nil
	end

	self.resultsShown:Destroy()
end

return Controller
