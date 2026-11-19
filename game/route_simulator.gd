class_name RouteSimulator
extends RefCounted
## Deterministic day-one rules, independent from rendering and animation speed.
## Every accepted step moves one cardinal cell. An arrow on arrival sets the
## heading for the next step. Planning, pausing and replay never advance time.

const START := Vector2i(0, 4)
const GOAL := Vector2i(4, 1)
const INITIAL_DIRECTION := Vector2i.RIGHT
const MAX_COMMANDS := 4
const STEP_LIMIT := 16
const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const FLOOR := [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(1, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(1, 3), Vector2i(3, 3),
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
]

static func ice_fraction(steps_travelled: float) -> float:
	return clampf(1.0 - steps_travelled / STEP_LIMIT, 0.0, 1.0)

static func can_place(cell: Vector2i) -> bool:
	return cell in FLOOR and cell != START and cell != GOAL

static func valid_plan(plan: Dictionary) -> bool:
	if plan.size() > MAX_COMMANDS:
		return false
	for cell in plan:
		if not cell is Vector2i or not can_place(cell) or not plan[cell] in DIRECTIONS:
			return false
	return true

static func simulate(plan: Dictionary) -> Dictionary:
	var frames: Array[Dictionary] = [{"cell": START, "direction": INITIAL_DIRECTION, "step": 0}]
	if not valid_plan(plan):
		return {"status": "invalid", "frames": frames, "steps": 0, "blocked": START}
	var cell := START
	var direction := INITIAL_DIRECTION
	for step in range(1, STEP_LIMIT + 1):
		var next_cell: Vector2i = cell + direction
		if not next_cell in FLOOR:
			return {"status": "blocked", "frames": frames, "steps": step - 1, "blocked": next_cell}
		cell = next_cell
		if plan.has(cell):
			direction = plan[cell]
		frames.append({"cell": cell, "direction": direction, "step": step})
		if cell == GOAL and ice_fraction(step) > 0:
			return {"status": "won", "frames": frames, "steps": step, "blocked": cell}
	return {"status": "melted", "frames": frames, "steps": STEP_LIMIT, "blocked": cell}

