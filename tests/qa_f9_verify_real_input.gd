extends Node

## QA re-verification of the F8 carry-over MEDIUM-4, independent of the DEV
## harness. Two things are done differently on purpose:
##
##   1. The keyboard is driven with real InputEventKey arrow presses instead of
##      Button.grab_focus(), so the focus chain itself is exercised the way a
##      player exercises it. qa_f9_hover_focus.gd calls grab_focus() directly and
##      therefore cannot see a broken focus_neighbour wiring.
##   2. Every focus x hover pair is swept in both save states and the plate
##      luminances are turned into WCAG contrast ratios, so "exactly one bright
##      plate" is backed by a measured number rather than a threshold flag.
##
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa_f9_verify_real_input.tscn
## The player save is stashed and put back, so nothing on disk is destroyed.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f9/verify"
const BACKUP_PATH := "user://jamo_save.json.f9bak"
const OFF_EVERY_PLATE := Vector2(40, 40)
## Measured plate luminances are ~0.05 plain and ~0.92 selected, so anything in
## between separates them with a wide margin either side.
const BRIGHT_LUMA := 0.35
## The selection cue has to stay at or above this against the plain plate.
const REQUIRED_CONTRAST := 3.0
const MAX_ARROW_PRESSES := 8

var _title: Control
var _failures: int = 0
var _rows: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	_title.refresh()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()

	await _sweep("nosave", ["NewGameButton", "SettingsButton", "QuitButton"])

	_write_fake_save()
	_title.refresh()
	await _settle()
	await _sweep("save",
		["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"])

	_restore_save()
	print("")
	print("| state | pointer on | keyboard on | bright | selected luma | plain luma | contrast |")
	print("|---|---|---|---|---|---|---|")
	for row: String in _rows:
		print(row)
	print("")
	if _failures == 0:
		print("OK - real arrow keys keep exactly one selected plate in %d pointer/keyboard pairs." % _rows.size())
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


## Every ordered pair of distinct plates: the pointer lands on one (which hands
## it the focus), then the arrow keys walk the focus away to the other while the
## pointer stays behind. That abandoned plate is where the two-bright-plate
## regression showed up.
func _sweep(state: String, names: Array) -> void:
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
			await _walk_to(focused, names.find(focused) > names.find(hovered))
			await _settle()
			_measure(state, hovered, focused)

	# The pointer parked outside every plate must leave the keyboard's plate lit.
	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	_measure(state, "<none>", _focused_name())


## Presses the real arrow key until the focus lands on the wanted button, so a
## broken focus_neighbour would strand the walk instead of being papered over.
## The menu does not wrap at either end (Godot's default spatial focus, no
## focus_neighbour overrides anywhere in the title), so the caller says which
## way to walk.
func _walk_to(wanted: String, downwards: bool) -> void:
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
	for name: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button: Button = _button(name)
		if button == null or not button.visible:
			continue
		var luma: float = _plate_luma(image, button)
		if luma >= BRIGHT_LUMA:
			bright.append(name)
			selected_luma = maxf(selected_luma, luma)
		else:
			# The dimmest plain plate is the worst case for the cue's contrast.
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
		_fail("%s selection cue is only %.2f:1, want >= %.1f:1" % [
			tag, contrast, REQUIRED_CONTRAST
		])


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
## The hub keys off the run block now, not off permanent progress, so a meta
## block alone would leave the plate hidden. Doc v0.4 section 44.
func _write_fake_save() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": SaveManager.SAVE_VERSION,
		"meta": {"gold": 137.0, "highest_wave": 2},
		"run": {"current_wave": 2, "core_hp": 14.0, "core_max_hp": 20.0},
		"audio": {},
	}, "\t"))
	file.close()
