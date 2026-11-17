--!strict
-- DDS Config — all tunables from GDD §16. Ship defaults; retune from playtest feel.

local Config = {
	-- Grid
	GRID_SIZE = 5,
	TILE_STUDS = 8,
	SPAWN_CELL = Vector2.new(2, 2), -- (row, col)

	-- Tempo
	BPM_DEFAULT = 96,
	TRAVEL_WINDOW = 2, -- W beats between targets (easy 4 / normal 2 / hard 1)
	TELEGRAPH_LEAD = 2, -- beats of telegraph warning (== W for v1)

	-- Movement
	-- Avatar step time is a difficulty dial (Progression §1: 140 relaxed -> 90 snappy). A step
	-- blocks the next one until it lands; one input is buffered. Charts override via stepTimeMs.
	STEP_TIME_MS = 120,
	STEP_TIME_BY_STARS = { 140, 120, 120, 100, 90 },
	DIFFICULTY_STARS = { easy = 1, normal = 2, hard = 3 },
	STEP_TIME_MULT = 1, -- item hook (Dash Sneakers)
	JUDGE_LAND_MS = 80, -- judged landing = press + this. Fixed on purpose: step-animation speed never moves the timing target
	MAX_PRESS_BACKDATE_MS = 250, -- touch taps/swipes register after touch-down; judge them from touch-down, up to this far back

	-- Judging: the landing is the hit. |beatTime - landedAt| within the window.
	-- Early arrivals beyond GREAT_LAND_MS cap at GOOD; late landings past LATE_GRACE_MS are a MISS.
	PERFECT_LAND_MS = 60,
	GREAT_LAND_MS = 140,
	LATE_GRACE_MS = 200,
	DODGE_TIER = "GREAT", -- tier awarded for being off every DANGER tile at the beat
	JUDGE_WEIGHT = { PERFECT = 1, GREAT = 0.8, GOOD = 0.4, MISS = 0 },
	SCORE_ACCURACY_MAX = 900000,
	SCORE_COMBO_MAX = 100000,
	SCORE_COMBO_BREAK = 10000,
	RANKS = { { rank = "S", minRaw = 950000 }, { rank = "A", minRaw = 900000 }, { rank = "B", minRaw = 800000 }, { rank = "C", minRaw = 0 } },

	-- Combo / life. The combo is a display and crown condition only; it does not multiply
	-- score (Combo Meter rule 5, which overrides the GDD §8 combo multiplier).
	COMBO_MILESTONES = { 10, 25, 50 },
	LIFE_MAX = 100,
	LIFE_START = 60, -- room to recover before the first miss streak, not a free full bar
	LIFE_MISS = -8, -- drain per MISS (DANGER hits included); 0 life = EXHAUSTED
	LIFE_HIT = 2, -- recovery on PERFECT / GREAT / dodges
	LIFE_GOOD = 1, -- GOOD keeps you alive but recovers half
	HYPE_MAX = 100,
	HYPE_PERFECT = 6,
	HYPE_GREAT = 3,
	HYPE_MISS_DECAY = -30,
	HYPE_MIN_COMBO = 8,

	-- Presentation (GDD §3, §17)
	POPUP_MS = 500,
	SPENT_FADE_BEATS = 0.9,
	IDLE_COLOR = Color3.fromRGB(14, 12, 16),
	IDLE_COLOR_ALT = Color3.fromRGB(24, 21, 28), -- checker partner; both under 15% of active luminance, boundaries stay aimable
	TARGET_COLOR = Color3.fromRGB(255, 64, 160), -- pink family: singles
	SHAPE_COLOR = Color3.fromRGB(64, 224, 255), -- cyan family: shapes
	DANGER_COLOR = Color3.fromRGB(255, 72, 32), -- red-orange: tiles you must be OFF at the beat
	HIT_COLOR = Color3.fromRGB(255, 255, 255),
	TELEGRAPH_MIN_ALPHA = 0.15, -- brightness at window start
	TELEGRAPH_FADE_OUT_BEATS = 0, -- >0 fades the telegraph out before the beat (Ghost Tiles)
	PREVIEW_LEAD_MULT = 2, -- on-deck preview reaches lead * this beats ahead
	PREVIEW_ALPHA = 0.15,
	ITEM_COLOR = Color3.fromRGB(255, 200, 40), -- gold: optional pickups

	-- Pre-roll (RoBeats-style countdown before music starts)
	PRE_ROLL_MS = 3000,

	-- Rate mods
	RATE_MIN = 0.5,
	RATE_MAX = 2.0,
	RATE_MULT = 1, -- item hook (Slow-Time Charm); applied on top of the player's chosen rate

	-- Items (Power-ups & Special Items card). Slot capacity comes from levels/grades, never money.
	ITEM_SLOTS_ATTRIBUTE = "ItemSlots", -- on the Player, set by progression
	ITEM_SLOTS_DEFAULT = 0,
	ITEM_SLOTS_MAX = 3,

	-- Audio
	AUDIO_LOOKAHEAD_MS = 150,
	AUDIO_OFFSET_MS_DEFAULT = 100, -- used until the player calibrates
	AUDIO_OFFSET_MIN_MS = -300,
	AUDIO_OFFSET_MAX_MS = 500,
	AUDIO_OFFSET_ATTRIBUTE = "AudioOffsetMs", -- on the Player; set by SettingsService from the DataStore
	CALIBRATION_SONG_ID = "combo-fever", -- tap-along track; swap for a click track when one is uploaded

	-- Lobby look (out-of-session pads)
	LOBBY_COLOR_A = Color3.fromRGB(244, 178, 202),
	LOBBY_COLOR_B = Color3.fromRGB(250, 242, 235),
}

Config.BEAT_SEC = 60 / Config.BPM_DEFAULT

return Config
