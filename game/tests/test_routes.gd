extends SceneTree

const Sim = preload("res://route_simulator.gd")
var checks := 0
var failures := 0

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var empty := Sim.simulate({})
	verify(empty.status == "blocked" and empty.steps == 4, "No instructions must stop at the end of the corridor.")
	var plan := {Vector2i(1, 4): Vector2i.UP, Vector2i(1, 1): Vector2i.RIGHT}
	var result := Sim.simulate(plan)
	verify(result.status == "won" and result.steps == 7, "Two arrows must deliver the cube in seven steps.")
	verify(result.frames[1].direction == Vector2i.UP, "A landing instruction changes the next movement.")
	verify(result.frames.back().cell == Sim.GOAL, "Success ends at the refrigerator.")
	verify(plan.size() == 2, "Simulation may not consume or modify the edited plan.")
	verify(result == Sim.simulate(plan), "Replay must be deterministic.")
	var alternative := {Vector2i(3, 4): Vector2i.UP, Vector2i(3, 2): Vector2i.RIGHT, Vector2i(4, 2): Vector2i.UP}
	verify(Sim.simulate(alternative).status == "won", "The alternate route must also be playable.")
	var loop := {Vector2i(1, 4): Vector2i.RIGHT, Vector2i(3, 4): Vector2i.LEFT}
	verify(Sim.simulate(loop).status == "melted", "A loop must stop at the step limit, never hang.")
	verify(not Sim.valid_plan({Sim.START: Vector2i.UP}), "Start cannot be overwritten.")
	verify(not Sim.valid_plan({Sim.GOAL: Vector2i.UP}), "Goal cannot be overwritten.")
	verify(not Sim.valid_plan({Vector2i(0, 0): Vector2i.UP}), "No instructions on blocked cells.")
	verify(not Sim.valid_plan({Vector2i(1, 1): Vector2i(1, 1)}), "Diagonal directions are invalid.")
	var over_budget := {}
	for c in Sim.FLOOR:
		if Sim.can_place(c):
			over_budget[c] = Vector2i.UP
		if over_budget.size() == 5:
			break
	verify(not Sim.valid_plan(over_budget), "Over-budget routes must be rejected.")
	verify(is_equal_approx(Sim.ice_fraction(8), 0.5), "Half the movement time uses half the ice.")
	verify(Sim.ice_fraction(16) == 0 and Sim.ice_fraction(0) == 1, "Ice resets at the start and runs out at the deadline.")
	print("Route rules: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

