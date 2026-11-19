extends Control
## Presentation layer. All movement outcomes come from RouteSimulator.

const Sim = preload("res://route_simulator.gd")
const BG := Color("07151f")
const PANEL := Color("10232f")
const INK := Color("e6f5f6")
const MUTED := Color("91abb8")
const MINT := Color("b5f8c7")
const ICE := Color("9be5f3")
const ORIGIN := Vector2(445, 224)
const CELL := 86.0
const SPACING := 90.0
const TICK := 0.48

var plan: Dictionary = {}
var selected := Vector2i.UP
var erasing := false
var mode := "planning"
var result: Dictionary = {}
var frame_index := 0
var elapsed := 0.0
var ambience := 0.0
var hovered := Vector2i(-1, -1)
var show_hint := false
var notice := ""
var notice_time := 0.0
var attempts := 0
var best_steps := 0
var ui: Dictionary = {}
var direction_buttons: Dictionary = {}
var font: Font

func _ready() -> void:
	font = load("res://assets/fonts/NotoSansSC.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	_build_ui()
	_sync_ui()
	queue_redraw()

func _process(delta: float) -> void:
	ambience += delta
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			notice = ""
			_sync_ui()
	if mode == "running":
		elapsed += delta
		if elapsed >= TICK:
			elapsed -= TICK
			_advance()
	var remaining := Sim.ice_fraction(frame_index + elapsed / TICK)
	ui.chapter_sub.text = "Ice %d%%   |   %.1f s left" % [ceili(remaining * 100), remaining * Sim.STEP_LIMIT * TICK]
	queue_redraw()

func _style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s

func _label(key: String, text: String, pos: Vector2, size: Vector2, text_size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", text_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	ui[key] = l
	return l

func _button(text: String, pos: Vector2, size: Vector2, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _style(MINT if primary else Color("172f3d"), MINT if primary else Color("2c4857")))
	b.add_theme_stylebox_override("hover", _style(Color("d3ffdf") if primary else Color("254756"), MINT))
	b.add_theme_stylebox_override("pressed", _style(Color("8edaaa") if primary else Color("335c67"), ICE))
	b.add_theme_stylebox_override("disabled", _style(Color("12232d"), Color("233641")))
	b.add_theme_color_override("font_color", Color("163529") if primary else INK)
	b.add_theme_color_override("font_hover_color", Color("163529") if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color("163529") if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("4d6776"))
	b.pressed.connect(action)
	add_child(b)
	return b

func _build_ui() -> void:
	_label("brand", "Be careful! The ice is melting!", Vector2(64, 38), Vector2(950, 60), 44)
	_label("subtitle", "Reach the freezer before you melt.", Vector2(66, 105), Vector2(500, 34), 21, MUTED)
	_label("chapter", "Freezer entrance", Vector2(1080, 52), Vector2(300, 40), 22, MINT)
	_label("chapter_sub", "Ice remaining", Vector2(1080, 94), Vector2(300, 32), 18, MUTED)
	_label("editor_tag", "ROUTE PLANNER", Vector2(66, 198), Vector2(290, 28), 16, MINT)
	_label("editor_title", "Plot your route", Vector2(66, 236), Vector2(300, 42), 28)
	_label("editor_help", "Pick a direction, then click a tile.\nThe cube turns on that tile.", Vector2(66, 294), Vector2(300, 62), 19, MUTED)
	var specs := [
		[Vector2i.UP, "↑  Up   W", Vector2(66, 382)],
		[Vector2i.RIGHT, "→  Right   D", Vector2(216, 382)],
		[Vector2i.DOWN, "↓  Down   S", Vector2(66, 450)],
		[Vector2i.LEFT, "←  Left   A", Vector2(216, 450)],
	]
	for spec in specs:
		var dir: Vector2i = spec[0]
		direction_buttons[dir] = _button(spec[1], spec[2], Vector2(138, 56), func(): _select(dir))
	ui.erase = _button("Erase   E", Vector2(66, 520), Vector2(138, 48), _select_eraser)
	ui.clear = _button("Clear all", Vector2(216, 520), Vector2(138, 48), _clear_plan)
	_label("budget_title", "Arrows placed", Vector2(68, 599), Vector2(180, 28), 18, MUTED)
	_label("budget", "0 / 4", Vector2(265, 586), Vector2(100, 46), 29, MINT)
	ui.play = _button("Start run", Vector2(66, 661), Vector2(288, 60), _play_pressed, true)
	ui.step = _button("Step", Vector2(66, 734), Vector2(138, 48), _step_pressed)
	ui.edit = _button("Edit route", Vector2(216, 734), Vector2(138, 48), _edit)
	_label("board_tag", "01   FIRST STEPS", Vector2(448, 177), Vector2(430, 26), 17, MUTED)
	_label("turn", "Step 00", Vector2(813, 177), Vector2(220, 28), 18, ICE)
	_label("board_hint", "The cube starts facing right.", Vector2(448, 788), Vector2(550, 32), 18, MUTED)
	_label("mission_tag", "OBJECTIVE", Vector2(1078, 209), Vector2(290, 30), 18, MINT)
	_label("mission", "Reach the freezer", Vector2(1078, 255), Vector2(290, 45), 27)
	_label("mission_help", "The cube melts as it moves.\nAt 0% ice, the run ends.", Vector2(1078, 315), Vector2(290, 65), 20, MUTED)
	_label("status_tag", "RUN STATUS", Vector2(1078, 419), Vector2(290, 28), 17, MUTED)
	_label("status", "Ready", Vector2(1078, 456), Vector2(290, 40), 26, INK)
	_label("status_body", "Place arrows to turn.\nPlanning costs no ice.", Vector2(1078, 511), Vector2(292, 100), 19, MUTED)
	ui.hint = _button("Show hint", Vector2(1078, 642), Vector2(280, 50), _hint)
	_label("record", "No runs yet", Vector2(1078, 721), Vector2(290, 70), 18, MUTED)
	_label("footer", "W A S D   Choose direction       E   Erase       Space   Run / Pause       R   Edit route", Vector2(66, 844), Vector2(1070, 28), 16, MUTED)
	_label("footer_right", "Right-click to erase", Vector2(1160, 844), Vector2(240, 28), 17, ICE)

func _sync_ui() -> void:
	ui.budget.text = "%d / %d" % [plan.size(), Sim.MAX_COMMANDS]
	ui.turn.text = "Step %02d / %d" % [frame_index, Sim.STEP_LIMIT]
	ui.record.text = "Runs: %d" % attempts if attempts else "No runs yet"
	if best_steps > 0:
		ui.record.text += "\nBest route: %d steps" % best_steps
	var editable := mode == "planning"
	for dir in direction_buttons:
		var b: Button = direction_buttons[dir]
		b.disabled = not editable
		b.add_theme_stylebox_override("normal", _style(Color("244953") if dir == selected and not erasing else Color("172f3d"), MINT if dir == selected and not erasing else Color("2c4857")))
	ui.erase.disabled = not editable
	ui.clear.disabled = not editable or plan.is_empty()
	ui.erase.add_theme_stylebox_override("normal", _style(Color("244953") if erasing else Color("172f3d"), MINT if erasing else Color("2c4857")))
	ui.edit.disabled = editable
	ui.step.disabled = mode == "running" or mode in ["won", "blocked", "melted"]
	ui.hint.disabled = not editable
	match mode:
		"planning":
			ui.play.text = "Start run"
			ui.status.text = "Ready"
			ui.status_body.text = "Place arrows to turn.\nPlanning costs no ice."
		"running":
			ui.play.text = "Pause"
			ui.status.text = "Melting!"
			ui.status_body.text = "Watch the ice gauge.\nPause to inspect the route."
		"paused":
			ui.play.text = "Resume"
			ui.status.text = "Paused"
			ui.status_body.text = "Melting is paused.\nStep to advance one tile."
		"won":
			ui.play.text = "Replay"
			ui.status.text = "Safe in the freezer!"
			ui.status_body.text = "%d steps with %d arrows.\nTry a different route." % [result.steps, plan.size()]
		"blocked":
			ui.play.text = "Retry"
			ui.status.text = "Route blocked"
			ui.status_body.text = "Turn before the obstacle.\nEdit the route and try again."
		"melted":
			ui.play.text = "Retry"
			ui.status.text = "Melted away"
			ui.status_body.text = "The ice ran out.\nTry a shorter route."
	ui.status.add_theme_color_override("font_color", MINT if mode == "won" else Color("f4c08c") if mode in ["blocked", "melted"] else INK)
	if notice != "":
		ui.status_body.text = notice
	elif show_hint and editable:
		ui.status_body.text = "Turn up just past the start.\nTurn right at the top."

func _select(direction: Vector2i) -> void:
	if mode != "planning": return
	selected = direction
	erasing = false
	_sync_ui()

func _select_eraser() -> void:
	if mode != "planning": return
	erasing = true
	_sync_ui()

func _clear_plan() -> void:
	if mode != "planning": return
	plan.clear()
	_sync_ui()

func _hint() -> void:
	show_hint = not show_hint
	ui.hint.text = "Hide hint" if show_hint else "Show hint"
	_sync_ui()

func _message(text: String) -> void:
	notice = text
	notice_time = 3.5
	_sync_ui()

func _start() -> void:
	result = Sim.simulate(plan)
	frame_index = 0
	elapsed = 0.0
	attempts += 1
	mode = "running"
	show_hint = false
	ui.hint.text = "Show hint"
	notice = ""
	if result.frames.size() == 1:
		_finish()
	_sync_ui()

func _play_pressed() -> void:
	if mode == "running":
		mode = "paused"
	elif mode == "paused":
		mode = "running"
	else:
		_start()
	_sync_ui()

func _step_pressed() -> void:
	if mode == "planning":
		_start()
	if mode in ["running", "paused"]:
		mode = "paused"
		elapsed = 0.0
		_advance()

func _advance() -> void:
	if frame_index < result.frames.size() - 1:
		frame_index += 1
	if frame_index == result.frames.size() - 1:
		_finish()
	_sync_ui()

func _finish() -> void:
	mode = result.status
	elapsed = 0.0
	if mode == "won" and (best_steps == 0 or result.steps < best_steps):
		best_steps = result.steps

func _edit() -> void:
	mode = "planning"
	frame_index = 0
	elapsed = 0.0
	result = {}
	notice = ""
	_sync_ui()

func _cell_at(point: Vector2) -> Vector2i:
	var local := point - ORIGIN
	if local.x < 0 or local.y < 0 or local.x >= 6 * SPACING or local.y >= 6 * SPACING:
		return Vector2i(-1, -1)
	var cell := Vector2i(floori(local.x / SPACING), floori(local.y / SPACING))
	var offset := local - Vector2(cell) * SPACING
	if offset.x > CELL or offset.y > CELL:
		return Vector2i(-1, -1)
	return cell

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = _cell_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if Sim.can_place(hovered) and mode == "planning" else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		if not Sim.can_place(cell): return
		if mode != "planning":
			_message("Select Edit route first.")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and erasing):
			plan.erase(cell)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not plan.has(cell) and plan.size() >= Sim.MAX_COMMANDS:
				_message("All four arrows are in use.\nReplace or erase one.")
				return
			plan[cell] = selected
		_sync_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_W: _select(Vector2i.UP)
		KEY_S: _select(Vector2i.DOWN)
		KEY_A: _select(Vector2i.LEFT)
		KEY_D: _select(Vector2i.RIGHT)
		KEY_E: _select_eraser()
		KEY_SPACE: _play_pressed()
		KEY_R: _edit()
		_: return
	get_viewport().set_input_as_handled()

func _round(rect: Rect2, fill: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> void:
	draw_style_box(_style(fill, border, radius), rect)

func _center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * SPACING + Vector2.ONE * CELL / 2.0

func _arrow(center: Vector2, direction: Vector2i, color: Color, scale_factor: float = 1.0) -> void:
	var d := Vector2(direction)
	var n := Vector2(-d.y, d.x)
	draw_line(center - d * 15 * scale_factor, center + d * 15 * scale_factor, color, 4 * scale_factor, true)
	draw_polyline(PackedVector2Array([center + d * 4 * scale_factor + n * 11 * scale_factor, center + d * 16 * scale_factor, center + d * 4 * scale_factor - n * 11 * scale_factor]), color, 4 * scale_factor, true)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), BG)
	var fraction := Sim.ice_fraction(frame_index + elapsed / TICK)
	draw_rect(Rect2(1080, 132, 272, 8), PANEL)
	draw_rect(Rect2(1080, 132, 272 * fraction, 8), ICE if fraction > 0.3 else Color("f4ab76"))
	# Faint technical grid and restrained polar atmosphere.
	for x in range(0, 1440, 40):
		draw_line(Vector2(x, 0), Vector2(x, 900), Color(0.2, 0.5, 0.6, 0.035), 1)
	for y in range(0, 900, 40):
		draw_line(Vector2(0, y), Vector2(1440, y), Color(0.2, 0.5, 0.6, 0.035), 1)
	draw_line(Vector2(64, 156), Vector2(1376, 156), Color("29404a"), 1)
	draw_line(Vector2(64, 824), Vector2(1376, 824), Color("29404a"), 1)
	_round(Rect2(42, 181, 336, 621), Color("0d202b"), 22, Color("203a48"))
	_round(Rect2(1054, 181, 326, 621), Color("0d202b"), 22, Color("203a48"))
	_round(Rect2(421, 212, 580, 562), Color("05121b"), 26, Color("294955"))
	for y in range(6):
		for x in range(6):
			_draw_tile(Vector2i(x, y))
	# Footprints reveal only steps already executed, never the solution.
	if not result.is_empty() and frame_index > 0:
		var trail := PackedVector2Array()
		for i in range(frame_index + 1):
			trail.append(_center(result.frames[i].cell))
		draw_polyline(trail, Color(0.67, 0.94, 0.94, 0.22), 5, true)
		for p in trail:
			draw_circle(p, 4, Color("7db7c7"))
	for c in plan:
		var p := _center(c)
		_round(Rect2(p - Vector2(25, 25), Vector2(50, 50)), Color("274a57"), 12, Color("91d5d3"))
		_arrow(p, plan[c], MINT)
	if mode == "planning" and Sim.can_place(hovered) and not plan.has(hovered):
		var p := _center(hovered)
		if not erasing:
			_arrow(p, selected, Color(0.75, 1, 0.85, 0.55))
	if show_hint and mode == "planning":
		var p := _center(Vector2i(1, 4))
		draw_arc(p, 37 + sin(ambience * 3) * 2, 0, TAU, 48, MINT, 2, true)
	if mode == "blocked":
		var p := _center(result.blocked)
		draw_line(p - Vector2(9, 9), p + Vector2(9, 9), Color("f2a47e"), 3, true)
		draw_line(p + Vector2(-9, 9), p + Vector2(9, -9), Color("f2a47e"), 3, true)
	var ice_position := _center(Sim.START)
	var ice_direction := Sim.INITIAL_DIRECTION
	if not result.is_empty():
		ice_position = _center(result.frames[frame_index].cell)
		ice_direction = result.frames[frame_index].direction
		if mode in ["running", "paused"] and frame_index + 1 < result.frames.size():
			var t := clampf(elapsed / TICK, 0, 1)
			t = t * t * (3 - 2 * t)
			ice_position = ice_position.lerp(_center(result.frames[frame_index + 1].cell), t)
	_draw_cube(ice_position, ice_direction, fraction)
	if mode == "won":
		for i in range(14):
			var angle := i * TAU / 14.0 + ambience * 0.15
			var p := ice_position + Vector2(cos(angle), sin(angle)) * (52 + sin(ambience * 2 + i) * 7)
			draw_circle(p, 2.5, MINT)

func _draw_tile(cell: Vector2i) -> void:
	var p := ORIGIN + Vector2(cell) * SPACING
	var center := _center(cell)
	if not cell in Sim.FLOOR:
		_round(Rect2(p + Vector2(4, 4), Vector2(CELL - 8, CELL - 8)), Color("0d202c"), 14, Color("18323d"))
		# Soft rock islands occupy non-walkable ground.
		var offset := float((cell.x * 7 + cell.y * 3) % 9)
		var poly := PackedVector2Array([center + Vector2(-24, 7), center + Vector2(-17, -17 - offset), center + Vector2(10, -23), center + Vector2(25, -4), center + Vector2(20, 20), center + Vector2(-8, 25)])
		draw_colored_polygon(poly, Color("183440"))
		draw_line(poly[1], poly[2], Color("2e505c"), 2, true)
		return
	_round(Rect2(p + Vector2(0, 6), Vector2(CELL, CELL)), Color("173f50"), 14)
	var fill := Color("286176") if cell == hovered and mode == "planning" else Color("204b5e")
	_round(Rect2(p, Vector2(CELL, CELL)), fill, 14, Color("457787"))
	draw_line(p + Vector2(15, 8), p + Vector2(CELL - 15, 8), Color("5f92a0"), 1.5, true)
	if cell == Sim.START:
		draw_arc(center, 30, 0, TAU, 48, Color("9edfe9"), 1.5, true)
		return
	if cell == Sim.GOAL:
		_round(Rect2(p + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), Color("244b43"), 12, MINT)
		_round(Rect2(center - Vector2(23, 30), Vector2(46, 60)), Color("c7e4d9"), 8, Color("e9fff0"))
		draw_line(center + Vector2(-19, -5), center + Vector2(19, -5), Color("5f9b8e"), 2)
		draw_line(center + Vector2(11, 4), center + Vector2(11, 16), Color("39695c"), 3, true)
		draw_circle(center + Vector2(0, -20), 3, MINT)
		return
	if not plan.has(cell):
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_circle(center + d * 13, 1.5, Color("7298a7"))

func _draw_cube(center: Vector2, direction: Vector2i, fraction: float) -> void:
	var bob := sin(ambience * 2.6) * 2.5 if mode != "running" else sin(ambience * 9) * 1.3
	draw_set_transform(center + Vector2(0, 15), 0, Vector2(1, 0.34))
	draw_circle(Vector2.ZERO, 34, Color(0.02, 0.12, 0.17, 0.55))
	if fraction <= 0:
		draw_circle(Vector2.ZERO, 23, ICE)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(center, 0, Vector2.ONE * sqrt(fraction))
	var c := Vector2(0, -9 + bob)
	draw_circle(c, 40, Color(0.5, 0.9, 1, 0.055))
	var top := PackedVector2Array([c + Vector2(-27, -16), c + Vector2(0, -30), c + Vector2(27, -16), c + Vector2(0, -1)])
	var left := PackedVector2Array([c + Vector2(-27, -16), c + Vector2(0, -1), c + Vector2(0, 32), c + Vector2(-27, 16)])
	var right := PackedVector2Array([c + Vector2(0, -1), c + Vector2(27, -16), c + Vector2(27, 16), c + Vector2(0, 32)])
	draw_colored_polygon(left, Color("91d9ec"))
	draw_colored_polygon(right, Color("55b5d2"))
	draw_colored_polygon(top, Color("c9f5fb"))
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], right[2], right[3], left[3], top[0]]), Color("c7f5ff"), 1.5, true)
	draw_line(c + Vector2(-20, -11), c + Vector2(-20, 11), Color("dcfcff"), 2, true)
	var eye_y := 9.0
	if mode == "won":
		draw_arc(c + Vector2(-18, eye_y - 3), 3, PI, TAU, 10, Color("174353"), 2, true)
		draw_arc(c + Vector2(-7, eye_y + 3), 3, PI, TAU, 10, Color("174353"), 2, true)
	else:
		draw_circle(c + Vector2(-18, eye_y - 3), 2.6, Color("174353"))
		draw_circle(c + Vector2(-7, eye_y + 3), 2.6, Color("174353"))
	# A small heading indicator remains legible while the cube covers its tile.
	draw_set_transform(Vector2.ZERO)
	_arrow(center + Vector2(direction) * 36, direction, Color("e2fcff"), 0.38)

