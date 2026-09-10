extends Node

## QA P0: the F7-F9 plate rules re-measured over EVERY hub plate.
##
## Why this exists: the F7-F9 harnesses were carried into v0.4 unchanged, and
## they only address NewGameButton / ContinueButton / SettingsButton /
## QuitButton. The Main Hub of doc v0.4 section 27 added UpgradeButton /
## CodexButton / RecordsButton, so "exactly one bright plate" was, after P0,
## being asserted over a subset of the menu. A second bright plate on one of the
## three new rows would have gone unseen. This sweep covers all seven.
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

## Every plate the hub draws, in column order.
const ALL_PLATES: Array[String] = [
	"NewGameButton", "ContinueButton", "UpgradeButton", "CodexButton",
	"RecordsButton", "SettingsButton", "QuitButton",
]
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(720, 1280),
	Vector2i(2560, 1080),
]

var _title: Control
var _failures: int = 0
var _rows: Array[String] = []
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

	# 1. Geometry and plate height at the four QA resolutions, both save states.
	for size: Vector2i in SIZES:
		await _measure_layout(size, "nosave")
	_write_fake_save()
	_title.refresh()
	await _settle()
	for size: Vector2i in SIZES:
		await _measure_layout(size, "save")
	_check_plate_height_ignores_the_save()

	# 2. Pointer x keyboard sweep over every visible plate, at 1280x720.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	await _sweep("save", _visible_plates())
	SaveManager.delete_save()
	_title.refresh()
	await _settle()
	await _sweep("nosave", _visible_plates())

	_restore_save()
	print("")
	print("| state | pointer on | keyboard on | bright | selected luma | plain luma | contrast |")
	print("|---|---|---|---|---|---|---|")
	for row: String in _rows:
		print(row)
	print("")
	if _failures == 0:
		print("OK - one bright plate across all %d hub plates, %d pointer/keyboard pairs."
			% [ALL_PLATES.size(), _rows.size()])
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _visible_plates() -> Array[String]:
	var out: Array[String] = []
	for name: String in ALL_PLATES:
		var button: Button = _button(name)
		if button != null and button.visible and button.focus_mode != Control.FOCUS_NONE:
			out.append(name)
	return out


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
func _warp_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(event)


func _measure(state: String, hovered: String, focused: String) -> void:
	var tag: String = "%s_pointer_%s_keyboard_%s" % [
		state, hovered.replace("<none>", "off"), focused
	]
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)

	var bright: Array[String] = []
	var selected_luma := -1.0
	var plain_luma := -1.0
	for name: String in ALL_PLATES:
		var button: Button = _button(name)
		if button == null or not button.visible:
			continue
		var luma: float = _plate_luma(image, button)
		if luma >= BRIGHT_LUMA:
			bright.append(name)
			selected_luma = maxf(selected_luma, luma)
		else:
			plain_luma = luma if plain_luma < 0.0 else minf(plain_luma, luma)

	var contrast: float = _contrast(selected_luma, plain_luma)
	_rows.append("| %s | %s | %s | %d | %.3f | %.3f | %.2f:1 |" % [
		state, hovered, focused, bright.size(), selected_luma, plain_luma, contrast
	])
	if bright.size() != 1:
		_fail("%s lit %d plates %s, want exactly 1" % [tag, bright.size(), str(bright)])
	elif bright[0] != focused:
		_fail("%s lit %s, want the keyboard's plate %s" % [tag, bright[0], focused])
	if contrast < REQUIRED_CONTRAST:
		_fail("%s selection cue is only %.2f:1, want >= %.1f:1"
			% [tag, contrast, REQUIRED_CONTRAST])


## A quarter in from the plate's left edge, clear of the label glyphs.
func _plate_luma(image: Image, button: Button) -> float:
	var rect: Rect2 = button.get_global_rect()
	var point := Vector2i(
		int(rect.position.x + rect.size.x * 0.25), int(rect.get_center().y)
	)
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


func _shoot(tag: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, tag])


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
