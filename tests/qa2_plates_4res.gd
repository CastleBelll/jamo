extends Node

## QA re-measurement of the hub plate rules at ALL FOUR QA resolutions.
##
## tests/qa_p0_plates_all.gd measures layout at four sizes but pins the window
## back to 1280x720 before the pointer x keyboard sweep, so "exactly one bright
## plate" and the >= 3.0:1 selection cue are asserted at one resolution only.
## The harness it replaced (qa_f8_title_shots) did check one-selected-plate at
## all four. This walks the full sweep at every size, in both save states, and
## adds the released-focus case per size and state.
##
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa2_plates_4res.tscn
## The player save is stashed and put back.

const HubPlates := preload("res://tests/hub_plates.gd")
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p0/plates4res"
const BACKUP_PATH := "user://jamo_save.json.qa2resbak"
const OFF_EVERY_PLATE := Vector2(40, 40)
const BRIGHT_LUMA := 0.35
const REQUIRED_CONTRAST := 3.0
const MAX_ARROW_PRESSES := 12
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(720, 1280),
	Vector2i(2560, 1080),
]

var _title: Control
var _failures: int = 0
var _all_plates: Array[String] = []
var _pairs: int = 0
## "1280x720 | save | 7" -> [worst contrast, worst tag]
var _worst: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	_title.refresh()
	await _settle()
	var problem: String = HubPlates.problem(_title)
	if not problem.is_empty():
		_fail(problem)
	_all_plates = HubPlates.all(_title)
	print("hub plates: %s" % ", ".join(_all_plates))

	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		await _settle()
		await _sweep(size, "nosave")
	_write_fake_save()
	_title.refresh()
	await _settle()
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		await _settle()
		await _sweep(size, "save")
	_restore_save()

	print("")
	print("| window | state | plates | worst selection contrast | at |")
	print("|---|---|---|---|---|")
	for key: String in _worst:
		var entry: Array = _worst[key]
		print("| %s | %.2f:1 | %s |" % [key, entry[0], entry[1]])
	print("")
	if _failures == 0:
		print("OK - one bright plate and >= %.1f:1 across %d pointer/keyboard pairs at %d sizes."
			% [REQUIRED_CONTRAST, _pairs, SIZES.size()])
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _sweep(size: Vector2i, state: String) -> void:
	var actual: Vector2i = DisplayServer.window_get_size()
	var label: String = "%dx%d | %s" % [actual.x, actual.y, state]
	var names: Array[String] = HubPlates.interactive(_title)
	print("    window=%s viewport=%s frame=%s" % [
		str(actual), str(get_viewport().get_visible_rect().size),
		str(get_viewport().get_texture().get_image().get_size()),
	])
	var worst := 999.0
	var worst_tag := "-"
	var measured: int = 0
	for hovered: String in names:
		for focused: String in names:
			if hovered == focused:
				continue
			_warp_to(OFF_EVERY_PLATE)
			await _settle()
			_warp_to(_centre(hovered))
			await _settle()
			if not _button(hovered).has_focus():
				_fail("%s: hovering %s did not take the focus" % [label, hovered])
			await _walk_to(names, focused)
			await _settle()
			var ratio: float = _measure(actual, state, hovered, focused)
			measured += 1
			_pairs += 1
			if ratio < worst:
				worst = ratio
				worst_tag = "%s hover / %s key" % [hovered, focused]

	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	var ratio_off: float = _measure(actual, state, "<none>", _focused_name())
	measured += 1
	_pairs += 1
	if ratio_off < worst:
		worst = ratio_off
		worst_tag = "pointer off"

	# Nothing focused at all: every plate falls back to the plain art.
	_title.get_viewport().gui_release_focus()
	await _settle()
	var lit: Array[String] = _bright_plates(_shoot("%dx%d_%s_nothing_focused"
		% [actual.x, actual.y, state]))
	print("--- %s: %d plates, %d pairs, nothing focused bright=%s"
		% [label, names.size(), measured, str(lit)])
	if not lit.is_empty():
		_fail("%s: %s stayed lit with nothing focused" % [label, str(lit)])
	_title.focus_default_button()
	await _settle()
	_worst["%dx%d | %s | %d" % [actual.x, actual.y, state, names.size()]] = [worst, worst_tag]


## Returns the selection cue's contrast for this frame, and fails on the two
## rules the F7-F9 pass settled: exactly one bright plate, and it is the one the
## keyboard is on.
func _measure(window: Vector2i, state: String, hovered: String, focused: String) -> float:
	var tag: String = "%dx%d_%s_pointer_%s_keyboard_%s" % [
		window.x, window.y, state, hovered.replace("<none>", "off"), focused
	]
	var image: Image = _shoot("_frame")
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
	var bad := false
	if bright.size() != 1:
		_fail("%s lit %d plates %s, want exactly 1" % [tag, bright.size(), str(bright)])
		bad = true
	elif bright[0] != focused:
		_fail("%s lit %s, want the keyboard's plate %s" % [tag, bright[0], focused])
		bad = true
	if contrast < REQUIRED_CONTRAST:
		_fail("%s selection cue is only %.2f:1, want >= %.1f:1"
			% [tag, contrast, REQUIRED_CONTRAST])
		bad = true
	# One frame per size and state is kept as evidence; a failing frame is
	# always kept, so a verdict can be checked against a picture.
	if bad or hovered == "<none>":
		image.save_png("%s/%s.png" % [OUT_DIR, tag])
	return contrast


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
## the window, which are only the same thing at the project's base resolution.
## Sampling without this correction reads the wrong part of the picture and
## reports plates as lit that are not.
func _plate_luma(image: Image, button: Button) -> float:
	var rect: Rect2 = button.get_global_rect()
	var scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var point := Vector2i(
		int((rect.position.x + rect.size.x * 0.25) * scale.x),
		int(rect.get_center().y * scale.y)
	)
	point = point.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(point).get_luminance()


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
## speaks. The project stretches its canvas, so above 1280x720 the window and
## the viewport are different sizes and Input.warp_mouse() wants the window
## one - warping the raw viewport point lands the pointer off the plate and the
## hover never happens. This is why the sweep has to be resolution-aware at all.
func _warp_to(point: Vector2) -> void:
	var scale: Vector2 = (
		Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	)
	var in_window: Vector2 = point * scale
	var event := InputEventMouseMotion.new()
	# The pushed event goes through the window's own input handling, which
	# applies the stretch transform on its way in, so it carries the window
	# point too - a viewport point here would be scaled down a second time.
	event.position = in_window
	event.global_position = in_window
	Input.warp_mouse(in_window)
	Input.parse_input_event(event)


## Writes the frame and reads it back off disk: the two do not share an
## orientation on every driver, and the saved PNG is what a human checks.
func _shoot(tag: String) -> Image:
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


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


## A v0.4 save with a run waiting, which is what makes RUN 이어하기 appear.
func _write_fake_save() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": SaveManager.SAVE_VERSION,
		"meta": {"gold": 137.0, "highest_wave": 2},
		"run": {"current_wave": 2, "core_hp": 14.0, "core_max_hp": 20.0},
		"audio": {},
	}, "\t"))
	file.close()
