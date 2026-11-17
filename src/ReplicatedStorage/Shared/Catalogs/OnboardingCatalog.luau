--!strict
-- What a new player learns after the lesson (TutorialChart), one card at a time
-- and each only once. Steps run in order straight after the lesson; tips wait
-- until they are useful (`trigger`) and the player is free on the island. A tip
-- with a `station` leads there with a beam (Workspace.Stations.<station>, at `part`
-- or its Anchor); a tip with a `button` rings that lobby rail button. Opening the
-- tip's `window` finishes it. The server checks every id against this catalog.
local OnboardingCatalog = {}

-- Off: no lesson, timing check or tips for anyone. Nothing is saved while it is off,
-- so switching it back on gives them to every player who has not done them.
OnboardingCatalog.Enabled = false

export type Trigger = "firstClear" | "canAfford" | "firstPurchase"

export type Tip = {
	id: string,
	title: string,
	text: string,
	trigger: Trigger,
	station: string?,
	part: string?,
	button: string?,
	window: string,
}

-- After the lesson: the timing check, then the first real song.
OnboardingCatalog.TimingCheck = {
	id = "timing",
	title = "TIMING CHECK",
	text = "TAP ON EVERY BEAT YOU HEAR",
	beats = 12,
	countIn = 4,
	bpm = 100,
	-- Taps further than this from any beat are stray and ignored.
	maxErrorSeconds = 0.25,
	minTaps = 6,
}

OnboardingCatalog.FirstSong = {
	title = "YOU'RE READY!",
	text = "PLAY YOUR FIRST SONG",
	button = "PLAY",
}

OnboardingCatalog.Tips = {
	{
		id = "quests",
		title = "QUESTS",
		text = "DAILY CHALLENGES PAY COINS. FOLLOW THE BEAM",
		trigger = "firstClear",
		station = "Quests",
		window = "quests",
	},
	{
		id = "shop",
		title = "YOU CAN AFFORD A WAND!",
		text = "FOLLOW THE BEAM TO THE SHOP",
		trigger = "canAfford",
		station = "Shop",
		window = "shop",
	},
	{
		id = "wardrobe",
		title = "WEAR IT",
		text = "PRESS WARDROBE TO EQUIP WHAT YOU BOUGHT",
		trigger = "firstPurchase",
		button = "wardrobe",
		window = "wardrobe",
	},
} :: { Tip }

-- The steps a client may report done (CompleteOnboardingStep).
function OnboardingCatalog.isStep(stepId: string): boolean
	if stepId == OnboardingCatalog.TimingCheck.id then
		return true
	end

	for _, tip in OnboardingCatalog.Tips do
		if tip.id == stepId then
			return true
		end
	end

	return false
end

return OnboardingCatalog
