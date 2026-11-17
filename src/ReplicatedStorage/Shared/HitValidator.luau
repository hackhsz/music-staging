local Board = require(script.Parent.Board)
local Timing = require(script.Parent.Timing)

local HitValidator = {}

export type HitResult = {
	accepted: boolean,
	grade: string,
	reason: string,
}

function HitValidator.validate(step: any, hitCoord: Board.TileCoord, hitTime: number, targetTime: number): HitResult
	if step == nil then
		return {
			accepted = false,
			grade = "Miss",
			reason = "missing_step",
		}
	end

	if hitCoord == nil or not Board.isValidCoord(hitCoord.x, hitCoord.y) then
		return {
			accepted = false,
			grade = "Miss",
			reason = "invalid_coord",
		}
	end

	local grade = Timing.grade(hitTime, targetTime)

	if step.type == "danger" then
		if hitCoord.x == step.x and hitCoord.y == step.y then
			return {
				accepted = false,
				grade = "Miss",
				reason = "danger_tile",
			}
		end

		return {
			accepted = grade ~= "Miss",
			grade = grade,
			reason = "danger_avoided",
		}
	end

	if hitCoord.x ~= step.x or hitCoord.y ~= step.y then
		return {
			accepted = false,
			grade = "Miss",
			reason = "wrong_tile",
		}
	end

	return {
		accepted = grade ~= "Miss",
		grade = grade,
		reason = step.type == "slide" and "slide_end_hit" or "timed_hit",
	}
end

return HitValidator
