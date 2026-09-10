extends Node

## The single regression for the F7-F9 plate rules, over EVERY hub plate.
##
## Why this exists: the F7-F9 harnesses were carried into v0.4 unchanged, and
## they only addressed NewGameButton / ContinueButton / SettingsButton /
## QuitButton. The Main Hub of doc v0.4 section 27 added UpgradeButton /
## CodexButton / RecordsButton, so "exactly one bright plate" was, after P0,
## being asserted over a subset of the menu. A second bright plate on one of the
## three new rows would have gone unseen.
##
## Four harnesses that only ever re-asserted a subset of what this one measures
## were removed when it took over: qa_f8_hover_focus, qa_f9_hover_focus,
## qa_f9_verify_real_input and qa_f8_title_shots. What is checked here:
##   - exactly one bright plate over every ordered pointer x keyboard pair,
##     driven with real arrow keys, in both save states, at 1280x720
##   - at every one of the four resolutions, in both save states: every plate
##     lit alone by the pointer, every plate lit alone by the keyboard with the
##     pointer left behind on another plate, the keyboard's plate lit with the
##     pointer parked off the menu, and no plate lit at all once the focus is
##     released (what qa_f8_title_shots used to assert per size and state)
##   - the selection cue holds >= 3.0:1 against the dimmest plain plate, in
##     every one of those frames
##   - layout, column alignment, even gaps and viewport fit at four resolutions
##   - plate height does not depend on whether a save exists
## The full ordered-pair sweep is 74 frames and runs once, at the base
## resolution: which plate is lit is decided by focus and hover state, not by
## the window size. What the window size does change is hit-testing and where
## a plate lands in the frame, so every size gets the per-plate pass instead
## of a second copy of the sweep.
## The plate list is derived from the scene (tests/hub_plates.gd), so the rows
## later phases add are covered without touching this file.
##
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa_p0_plates_all.tscn
## The player save is stashed and put back, so nothing on disk is destroyed.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p0/plates"
const BACKUP_PATH := "user://jamo_save.json.p0platebak"
const OFF_EVERY_PLATE := Vector2(40, 40)
const BRIGHT_LUMA := 0.35
const REQUIRED_CONTRAST := 3.0
const MAX_ARROW_PRESSES := 12

const HubPlates := preload("res://tests/hub_plates.gd")
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(720, 1280),
	Vector2i(2560, 1080),
]

var _title: Control
var _failures: int = 0
## Every plate the hub draws, in column order, derived from the scene.
var _all_plates: Array[String] = []
var _rows: Array[String] = []
## How many (window size, save state) combinations asserted the released-focus rule.
var _released_checks: int = 0
## "1280x720" -> {"nosave": height, "save": height}
var _plate_heights: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	_title.refresh()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()

	var problem: String = HubPlates.problem(_title)
	if not problem.is_empty():
		_fail(problem)
	_all_plates = HubPlates.all(_title)
	print("hub plates: %s" % ", ".join(_all_plates))

	# 1. At the four QA resolutions, both save states: geometry, plate height,
	#    one selected plate per input path, and none once the focus is gone.
	for size: Vector2i in SIZES:
		await _measure_layout(size, "nosave")
		await _sweep_each_plate("nosave", _visible_plates())
		await _measure_nothing_focused("nosave")
	_write_fake_save()
	_title.refresh()
	await _settle()
	for size: Vector2i in SIZES:
		await _measure_layout(size, "save")
		await _sweep_each_plate("save", _visible_plates())
		await _measure_nothing_focused("save")
	_check_plate_height_ignores_the_save()

	# 2. Pointer x keyboard sweep over every ordered pair, at 1280x720.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	await _sweep("save", _visible_plates())
	SaveManager.delete_save()
	_title.refresh()
	await _settle()
	await _sweep("nosave", _visible_plates())

	_restore_save()
	print("")
	print("| window | state | pointer on | keyboard on | bright | selected luma | plain luma | contrast |")
	print("|---|---|---|---|---|---|---|---|")
	for row: String in _rows:
		print(row)
	print("")
	if _failures == 0:
		print("OK - one bright plate across all %d hub plates, %d pointer/keyboard frames at %d sizes x 2 save states, focus released -> 0 lit in %d/%d."
			% [_all_plates.size(), _rows.size(), SIZES.size(),
				_released_checks, SIZES.size() * 2])
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _visible_plates() -> Array[String]:
	return HubPlates.interactive(_title)


## With nothing focused every plate has to fall back to the plain art. The
## sweeps always leave the keyboard somewhere, so this is the one state they
## cannot reach. Asserted once per window size and save state.
func _measure_nothing_focused(state: String) -> void:
	_warp_to(OFF_EVERY_PLATE)
	_title.get_viewport().gui_release_focus()
	await _settle()
	var tag: String = "%s_%s_nothing_focused" % [_window_tag(), state]
	var lit: Array[String] = _bright_plates(_shoot(tag))
	print("--- %s nothing focused: bright=%s" % [tag, str(lit)])
	_released_checks += 1
	if not lit.is_empty():
		_fail("%s: %s stayed lit with nothing focused" % [tag, str(lit)])
	_title.focus_default_button()
	await _settle()


## The per-resolution pass, 2N + 1 frames for N plates on screen. What the
## window size can break is hit-testing and where the plate sits in the frame,
## so every plate is lit once by each input:
##   1. the pointer walks down the column, plate by plate: hovering has to take
##      the focus, and light that plate alone;
##   2. the pointer stays on the last plate while the arrow keys walk back up:
##      the keyboard's plate is lit alone, the abandoned one is not;
##   3. the pointer leaves the menu: the keyboard's plate stays lit alone.
func _sweep_each_plate(state: String, names: Array[String]) -> void:
	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	for hovered: String in names:
		_warp_to(_centre(hovered))
		await _settle()
		if not _button(hovered).has_focus():
			_fail("%s %s: hovering %s did not take the focus" % [_window_tag(), state, hovered])
		_measure(state, hovered, hovered)

	var left_behind: String = names[names.size() - 1]
	for i: int in range(names.size() - 2, -1, -1):
		await _walk_to(names, names[i])
		await _settle()
		_measure(state, left_behind, names[i])

	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	_measure(state, "<none>", _focused_name())


## Every plate has to sit inside the viewport, share the column's width and keep
## an even gap, at every window size. The hidden rows are skipped because a
## hidden control keeps the rect it last had.
func _measure_layout(size: Vector2i, state: String) -> void:
	DisplayServer.window_set_size(size)
	await _settle()
	var actual: Vector2i = DisplayServer.window_get_size()
	var tag: String = "%s_%dx%d" % [state, actual.x, actual.y]
	_shoot(tag)

	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var box: VBoxContainer = _title.get_node("Safe/Content/Box")
	var separation: float = float(box.get_theme_constant(&"separation"))
	var previous: Control = null
	var drawn: int = 0
	for child: Control in box.get_children():
		if not child.visible:
			continue
		drawn += 1
		if not visible_rect.encloses(child.get_global_rect()):
			_fail("%s: %s leaves the viewport" % [tag, child.name])
		if previous != null:
			var gap: float = child.position.y - previous.position.y - previous.size.y
			if absf(gap - separation) > 1.0:
				_fail("%s: gap %s->%s is %.1f, want %.0f"
					% [tag, previous.name, child.name, gap, separation])
			if absf(child.position.x - previous.position.x) > 1.0 \
					or absf(child.size.x - previous.size.x) > 1.0:
				_fail("%s: %s is not aligned with %s" % [tag, child.name, previous.name])
		previous = child

	var plate: Rect2 = _button("NewGameButton").get_global_rect()
	print("--- %s viewport=%.0fx%.0f rows_drawn=%d plate=%.0fx%.0f (%.1f%% tall)" % [
		tag, visible_rect.size.x, visible_rect.size.y, drawn,
		plate.size.x, plate.size.y, 100.0 * plate.size.y / visible_rect.size.y,
	])
	var key: String = "%dx%d" % [actual.x, actual.y]
	var per_state: Dictionary = _plate_heights.get(key, {})
	per_state[state] = plate.size.y
	_plate_heights[key] = per_state


func _check_plate_height_ignores_the_save() -> void:
	for key: String in _plate_heights:
		var per_state: Dictionary = _plate_heights[key]
		var without_save: float = float(per_state.get("nosave", -1.0))
		var with_save: float = float(per_state.get("save", -1.0))
		print("    %s plate height: nosave=%.1f save=%.1f" % [key, without_save, with_save])
		if absf(without_save - with_save) > 1.0:
			_fail("%s plate is %.1f tall without a save and %.1f with one"
				% [key, without_save, with_save])


## Pointer on one plate, keyboard walked to another: the classic two-bright
## regression. Swept over every ordered pair of the plates that are on screen.
func _sweep(state: String, names: Array[String]) -> void:
	for hovered: String in names:
		for focused: String in names:
			if hovered == focused:
				continue
			_warp_to(OFF_EVERY_PLATE)
			await _settle()
			_warp_to(_centre(hovered))
			await _settle()
			if not _button(hovered).has_focus():
				_fail("%s: hovering %s did not take the focus" % [state, hovered])
			await _walk_to(names, focused)
			await _settle()
			_measure(state, hovered, focused)

	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	_measure(state, "<none>", _focused_name())


func _walk_to(names: Array[String], wanted: String) -> void:
	var downwards: bool = names.find(wanted) > names.find(_focused_name())
	for _i in MAX_ARROW_PRESSES:
		if _button(wanted).has_focus():
			return
		_press(KEY_DOWN if downwards else KEY_UP)
		await _settle()
	if not _button(wanted).has_focus():
		_fail("the arrow keys never reached %s (stuck on %s)" % [wanted, _focused_name()])


func _press(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


## Godot only recomputes hover from real mouse motion, so the pointer is warped
## and a matching motion event is pushed by hand.
##
## `point` is in viewport coordinates, which is what Control.get_global_rect()
## speaks. The project stretches its canvas (canvas_items / expand), so away
## from 1280x720 the window and the viewport are different sizes and
## Input.warp_mouse() wants the window one; warping the raw viewport point
## lands the pointer off the plate at 1920x1080 and 2560x1080. The pushed
## event goes through the window's own input handling, which applies the
## stretch on its way in, so it carries the window point too.
func _warp_to(point: Vector2) -> void:
	var in_window: Vector2 = point * _window_per_viewport()
	var event := InputEventMouseMotion.new()
	event.position = in_window
	event.global_position = in_window
	Input.warp_mouse(in_window)
	Input.parse_input_event(event)


## Window pixels per viewport unit, per axis.
func _window_per_viewport() -> Vector2:
	return Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size


func _window_tag() -> String:
	var size: Vector2i = DisplayServer.window_get_size()
	return "%dx%d" % [size.x, size.y]


func _measure(state: String, hovered: String, focused: String) -> void:
	var tag: String = "%s_%s_pointer_%s_keyboard_%s" % [
		_window_tag(), state, hovered.replace("<none>", "off"), focused
	]
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)

	var bright: Array[String] = _bright_plates(image)
	var selected_luma := -1.0
	var plain_luma := -1.0
	for name: String in _all_plates:
		var button: Button = _button(name)
		if button == null or not button.visible:
			continue
		var luma: float = _plate_luma(image, button)
		if bright.has(name):
			selected_luma = maxf(selected_luma, luma)
		else:
			plain_luma = luma if plain_luma < 0.0 else minf(plain_luma, luma)

	var contrast: float = _contrast(selected_luma, plain_luma)
	_rows.append("| %s | %s | %s | %s | %d | %.3f | %.3f | %.2f:1 |" % [
		_window_tag(), state, hovered, focused,
		bright.size(), selected_luma, plain_luma, contrast
	])
	if bright.size() != 1:
		_fail("%s lit %d plates %s, want exactly 1" % [tag, bright.size(), str(bright)])
	elif bright[0] != focused:
		_fail("%s lit %s, want the keyboard's plate %s" % [tag, bright[0], focused])
	if contrast < REQUIRED_CONTRAST:
		_fail("%s selection cue is only %.2f:1, want >= %.1f:1"
			% [tag, contrast, REQUIRED_CONTRAST])


## The plates drawn in their selected (bright) art in this frame.
func _bright_plates(image: Image) -> Array[String]:
	var bright: Array[String] = []
	for name: String in _all_plates:
		var button: Button = _button(name)
		if button == null or not button.visible:
			continue
		if _plate_luma(image, button) >= BRIGHT_LUMA:
			bright.append(name)
	return bright


## A quarter in from the plate's left edge, clear of the label glyphs.
##
## The rect is in viewport coordinates and the captured frame is the size of
## the window; the two only agree at 1280x720. Sampling without the scale
## reads a pixel outside the plate at the other sizes (background at
## 720x1280, which reads as "not lit", so a stuck plate would have passed).
func _plate_luma(image: Image, button: Button) -> float:
	var rect: Rect2 = button.get_global_rect()
	var scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var point := Vector2i(
		int((rect.position.x + rect.size.x * 0.25) * scale.x),
		int(rect.get_center().y * scale.y)
	)
	point = point.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(point).get_luminance()


func _contrast(lighter: float, darker: float) -> float:
	if lighter < 0.0 or darker < 0.0:
		return 0.0
	return (lighter + 0.05) / (darker + 0.05)


func _button(name: String) -> Button:
	return _title.get_node_or_null("%%%s" % name) as Button


func _centre(name: String) -> Vector2:
	return _button(name).get_global_rect().get_center()


func _focused_name() -> String:
	var focused: Control = _title.get_viewport().gui_get_focus_owner()
	return "<none>" if focused == null else focused.name


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FAIL: %s" % message)


## Writes the frame and hands it back, read off disk: the saved PNG is the
## artifact a human checks the verdict against.
func _shoot(tag: String) -> Image:
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		ProjectSettings.globalize_path(BACKUP_PATH)
	)


func _restore_save() -> void:
	SaveManager.delete_save()
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	)


func _write_fake_save() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": SaveManager.SAVE_VERSION,
		"meta": {"gold": 137.0, "highest_wave": 2},
		"run": {"current_wave": 2, "core_hp": 14.0, "core_max_hp": 20.0},
		"audio": {},
	}, "\t"))
	file.close()
