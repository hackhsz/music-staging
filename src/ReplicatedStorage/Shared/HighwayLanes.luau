--!strict
-- The highway's four lanes, left to right, the way Friday Night Funkin' lays
-- them out: left, down, up and right arrows in FNF's colours. The notes, the
-- keys, the floor and the dance step all read this, so a lane is the same
-- colour and the same direction everywhere.

local HighwayLanes = {}

export type Lane = {
	name: string,
	label: string,
	color: Color3,
	rotation: number,
	step: { x: number, y: number },
	-- The floor tile that lights for the lane, from the dancer's own tile. Down
	-- lights the tile under the dancer: the one toward the audience sits under
	-- the stage camera, where it can never be seen.
	glow: { x: number, y: number },
	move: string,
}

-- A white arrow pointing up with a dark rim, so one image tints to every lane
-- colour and rotates to every direction.
HighwayLanes.ArrowImage = "rbxassetid://93429911144629"

-- rotation turns the up-pointing arrow to the lane's direction, clockwise.
-- step is the floor direction the dancer steps for the lane: +y is toward the
-- audience, because the camera looks down -Z. move names the dancer's pose in
-- DancePoses.Moves. label is the text fallback where no image can be drawn.
HighwayLanes.Lanes = {
	{
		name = "Left",
		label = "<",
		color = Color3.fromRGB(194, 75, 153),
		rotation = -90,
		step = { x = -1, y = 0 },
		glow = { x = -1, y = 0 },
		move = "pointLeft",
	},
	{
		name = "Down",
		label = "v",
		color = Color3.fromRGB(0, 255, 255),
		rotation = 180,
		step = { x = 0, y = 1 },
		glow = { x = 0, y = 0 },
		move = "drop",
	},
	{
		name = "Up",
		label = "^",
		color = Color3.fromRGB(18, 250, 5),
		rotation = 0,
		step = { x = 0, y = -1 },
		glow = { x = 0, y = -1 },
		move = "reach",
	},
	{
		name = "Right",
		label = ">",
		color = Color3.fromRGB(249, 57, 63),
		rotation = 90,
		step = { x = 1, y = 0 },
		glow = { x = 1, y = 0 },
		move = "pointRight",
	},
} :: { Lane }

HighwayLanes.Count = #HighwayLanes.Lanes

function HighwayLanes.get(lane: number): Lane
	return HighwayLanes.Lanes[lane] or HighwayLanes.Lanes[1]
end

function HighwayLanes.labels(): { string }
	local labels = {}

	for _, lane in HighwayLanes.Lanes do
		table.insert(labels, lane.label)
	end

	return labels
end

return HighwayLanes
