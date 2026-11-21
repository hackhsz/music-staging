--!strict
-- Every ability a player can take into a song, four at a time. Charge comes only
-- from playing well, so an ability is earned in the run, never bought.

export type Effect =
	"shield"
	| "ironHeart"
	| "heal"
	| "safeSteps"
	| "encore"
	| "doublePoints"
	| "goldenTouch"
	| "comboSurge"
	| "spotlight"
	| "fever"
	| "crowd"
	| "hypeWave"
	| "steadyFeet"
	| "lifeline"
	| "clapEcho"
	| "overdrive"

export type Ability = {
	id: string,
	name: string,
	blurb: string,
	glyph: string,
	-- An uploaded image that replaces the glyph wherever the ability is drawn.
	icon: string?,
	color: Color3,
	effect: Effect,
	cost: number,
	cooldownSeconds: number,
	-- How long it lasts, in beats of the song; nil for an instant effect.
	beats: number?,
	-- How many verdicts it changes before it is spent; nil for no limit.
	uses: number?,
	amount: number?,
}

local AbilityCatalog = {}

AbilityCatalog.Policy = {
	DisabledForRankedLeaderboards = true,
	NoPaidCompetitiveAdvantage = true,
	ServerAuthoritativeActivation = true,
}

AbilityCatalog.Slots = 4
AbilityCatalog.MaxCharge = 100
-- Enough for a cheap ability straight away, so the bar is a choice from the start.
AbilityCatalog.StartCharge = 25
AbilityCatalog.ChargePerGrade = { Perfect = 6, Great = 4, Good = 1 }

local DEFENCE = Color3.fromRGB(90, 200, 255)
local SCORE = Color3.fromRGB(255, 200, 87)
local CROWD = Color3.fromRGB(255, 120, 200)
local ASSIST = Color3.fromRGB(120, 235, 150)

-- An ability's colour is its group; the loadout picker's tabs filter by it.
AbilityCatalog.Groups = {
	{ id = "defence", name = "Defence", color = DEFENCE },
	{ id = "score", name = "Score", color = SCORE },
	{ id = "crowd", name = "Crowd", color = CROWD },
	{ id = "assist", name = "Assist", color = ASSIST },
}

AbilityCatalog.Abilities = {
	{
		id = "beat-shield",
		name = "Beat Shield",
		blurb = "Your next Miss keeps your combo.",
		glyph = "🛡️",
		icon = "rbxassetid://132769437050434",
		color = DEFENCE,
		effect = "shield",
		cost = 30,
		cooldownSeconds = 20,
		beats = 32,
		uses = 1,
	},
	{
		id = "iron-heart",
		name = "Iron Heart",
		blurb = "Misses drain half the life for 16 beats.",
		glyph = "💖",
		icon = "rbxassetid://94850528926798",
		color = DEFENCE,
		effect = "ironHeart",
		cost = 30,
		cooldownSeconds = 25,
		beats = 16,
		amount = 0.5,
	},
	{
		id = "second-wind",
		name = "Second Wind",
		blurb = "Win back 30 life right now.",
		glyph = "💨",
		icon = "rbxassetid://123236781744271",
		color = DEFENCE,
		effect = "heal",
		cost = 40,
		cooldownSeconds = 30,
		amount = 30,
	},
	{
		id = "safe-steps",
		name = "Safe Steps",
		blurb = "Red tiles cannot hurt you for 16 beats.",
		glyph = "🚧",
		icon = "rbxassetid://116262574152553",
		color = DEFENCE,
		effect = "safeSteps",
		cost = 35,
		cooldownSeconds = 25,
		beats = 16,
	},
	{
		id = "encore",
		name = "Encore",
		blurb = "Bring back half the combo you just lost.",
		glyph = "🔁",
		icon = "rbxassetid://103503380066926",
		color = DEFENCE,
		effect = "encore",
		cost = 45,
		cooldownSeconds = 40,
		amount = 0.5,
	},
	{
		id = "double-time",
		name = "Double Time",
		blurb = "Double points for 8 beats.",
		glyph = "💰",
		icon = "rbxassetid://82697298370204",
		color = SCORE,
		effect = "doublePoints",
		cost = 50,
		cooldownSeconds = 30,
		beats = 8,
		amount = 2,
	},
	{
		id = "golden-touch",
		name = "Golden Touch",
		blurb = "Greats count as Perfects for 8 beats.",
		glyph = "✨",
		icon = "rbxassetid://96723031702656",
		color = SCORE,
		effect = "goldenTouch",
		cost = 45,
		cooldownSeconds = 30,
		beats = 8,
	},
	{
		id = "combo-surge",
		name = "Combo Surge",
		blurb = "Add 10 to your combo.",
		glyph = "⚡",
		icon = "rbxassetid://92830720078925",
		color = SCORE,
		effect = "comboSurge",
		cost = 35,
		cooldownSeconds = 30,
		amount = 10,
	},
	{
		id = "spotlight",
		name = "Spotlight",
		blurb = "Your next 4 hits score triple.",
		glyph = "🔦",
		icon = "rbxassetid://81212139824753",
		color = SCORE,
		effect = "spotlight",
		cost = 40,
		cooldownSeconds = 30,
		beats = 16,
		uses = 4,
		amount = 3,
	},
	{
		id = "fever-rush",
		name = "Fever Rush",
		blurb = "Start Fever right now.",
		glyph = "🔥",
		icon = "rbxassetid://109954870643247",
		color = SCORE,
		effect = "fever",
		cost = 70,
		cooldownSeconds = 45,
	},
	{
		id = "crowd-call",
		name = "Crowd Call",
		blurb = "The crowd roars: 25 hype at once.",
		glyph = "📣",
		icon = "rbxassetid://112288861580085",
		color = CROWD,
		effect = "crowd",
		cost = 25,
		cooldownSeconds = 20,
		amount = 25,
	},
	{
		id = "hype-wave",
		name = "Hype Wave",
		blurb = "Double hype from every hit for 16 beats.",
		glyph = "🌊",
		icon = "rbxassetid://88928539646063",
		color = CROWD,
		effect = "hypeWave",
		cost = 30,
		cooldownSeconds = 25,
		beats = 16,
		amount = 2,
	},
	{
		id = "steady-feet",
		name = "Steady Feet",
		blurb = "Goods count as Greats for 16 beats.",
		glyph = "👟",
		icon = "rbxassetid://91641722839946",
		color = ASSIST,
		effect = "steadyFeet",
		cost = 35,
		cooldownSeconds = 25,
		beats = 16,
	},
	{
		id = "lifeline",
		name = "Lifeline",
		blurb = "Your next Miss becomes a Good.",
		glyph = "🩹",
		icon = "rbxassetid://119502522387799",
		color = ASSIST,
		effect = "lifeline",
		cost = 45,
		cooldownSeconds = 35,
		beats = 32,
		uses = 1,
	},
	{
		id = "clap-echo",
		name = "Clap Echo",
		blurb = "Claps and poses cannot be missed for 16 beats.",
		glyph = "👏",
		icon = "rbxassetid://98989814695785",
		color = ASSIST,
		effect = "clapEcho",
		cost = 30,
		cooldownSeconds = 25,
		beats = 16,
	},
	{
		id = "overdrive",
		name = "Overdrive",
		blurb = "Triple points for 8 beats. Takes a full bar.",
		glyph = "🚀",
		icon = "rbxassetid://123471295758258",
		color = SCORE,
		effect = "overdrive",
		cost = 100,
		cooldownSeconds = 60,
		beats = 8,
		amount = 3,
	},
} :: { Ability }

AbilityCatalog.DefaultLoadout = { "beat-shield", "double-time", "second-wind", "crowd-call" }

function AbilityCatalog.groupOf(ability: Ability): string?
	for _, group in AbilityCatalog.Groups do
		if group.color == ability.color then
			return group.id
		end
	end

	return nil
end

function AbilityCatalog.get(abilityId: string): Ability?
	for _, ability in AbilityCatalog.Abilities do
		if ability.id == abilityId then
			return ability
		end
	end

	return nil
end

-- A loadout as the server keeps it: known, distinct ids, at most four, padded
-- from the default so every slot holds something.
function AbilityCatalog.sanitizeLoadout(ids: any): { string }
	local loadout: { string } = {}

	if type(ids) == "table" then
		for _, id in ids do
			if #loadout < AbilityCatalog.Slots and type(id) == "string" and AbilityCatalog.get(id) ~= nil then
				if not table.find(loadout, id) then
					table.insert(loadout, id)
				end
			end
		end
	end

	for _, id in AbilityCatalog.DefaultLoadout do
		if #loadout < AbilityCatalog.Slots and not table.find(loadout, id) then
			table.insert(loadout, id)
		end
	end

	return loadout
end

return AbilityCatalog
