extends Node

## Captures the retextured, shrunken title menu at the four window sizes the
## F8-3 fix is measured on, one frame per focus target, and asserts that only
## one plate is ever drawn in its selected version. Run windowed (NOT headless):
##   godot --path . res://tests/qa_f8_title_shots.tscn
## The player save is stashed and put back, so nothing on disk is destroyed.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f8/shots"
const BACKUP_PATH := "user://jamo_save.json.shotbak"

const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(720, 1280),
	Vector2i(2560, 1080),
]
const BUTTONS: Array[String] = [
	"NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"
]

var _title: Control
var _failures: int = 0
## Plate height per window size, one entry per state: {"1280x720": {"save": 67.0}}.
var _plate_heights: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	_title.refresh()
	await _settle()

	for size: Vector2i in SIZES:
		await _capture_size(size, "nosave")

	# 이어하기 only joins the focus chain once a run exists, so the save-present
	# pass is the only one that can show its selected plate.
	_write_fake_save()
	_title.refresh()
	await _settle()
	for size: Vector2i in SIZES:
		await _capture_size(size, "save")

	_restore_save()
	_check_plate_height_ignores_the_save()
	if _failures == 0:
		print("OK - one selected plate at a time across %d sizes." % SIZES.size())
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _capture_size(size: Vector2i, state: String) -> void:
	DisplayServer.window_set_size(size)
	await _settle()
	var actual: Vector2i = DisplayServer.window_get_size()
	var suffix: String = "%s_%dx%d" % [state, actual.x, actual.y]

	# The screen as the player first meets it: entry focus already on a button.
	_shoot("idle_%s" % suffix)
	_report_geometry(state, actual, suffix)

	for name: String in BUTTONS:
		var button: Button = _title.get_node("%%%s" % name)
		if button.focus_mode == Control.FOCUS_NONE:
			continue
		button.grab_focus()
		await _settle()
		_shoot("focus_%s_%s" % [name, suffix])
		_check_single_selection(name, suffix)

	# Nothing focused: every plate must fall back to the unselected art.
	_title.get_viewport().gui_release_focus()
	await _settle()
	_shoot("nofocus_%s" % suffix)
	_check_single_selection("", suffix)
	_title.focus_default_button()
	await _settle()


## The selected plate is a base-style override put on while a button holds
## focus, so exactly one button may carry that override at any time.
func _check_single_selection(expected: String, tag: String) -> void:
	var selected: Array[String] = []
	for name: String in BUTTONS:
		var button: Button = _title.get_node("%%%s" % name)
		if button.has_theme_stylebox_override("normal"):
			selected.append(name)
	var wanted: Array[String] = []
	if not expected.is_empty():
		wanted.append(expected)
	if selected != wanted:
		_failures += 1
		printerr("  FAIL: %s selected=%s expected=%s" % [tag, str(selected), str(wanted)])
	else:
		print("    %s selected plate: %s" % [tag, "<none>" if selected.is_empty() else selected[0]])


func _report_geometry(state: String, window: Vector2i, tag: String) -> void:
	var visible: Rect2 = get_viewport().get_visible_rect()
	var button: Control = _title.get_node("%NewGameButton")
	var logo: Rect2 = _title.get_node("Safe/Content/Logo").get_global_rect()
	var rect: Rect2 = button.get_global_rect()
	print("--- %s viewport=%.0fx%.0f button=%.0fx%.0f (%.1f%% wide, %.1f%% tall) logo_bottom=%.0f box_top=%.0f" % [
		tag, visible.size.x, visible.size.y, rect.size.x, rect.size.y,
		100.0 * rect.size.x / visible.size.x, 100.0 * rect.size.y / visible.size.y,
		logo.end.y, rect.position.y
	])
	var key: String = "%dx%d" % [window.x, window.y]
	var per_state: Dictionary = _plate_heights.get(key, {})
	per_state[state] = rect.size.y
	_plate_heights[key] = per_state
	var box: VBoxContainer = _title.get_node("Safe/Content/Box")
	var separation: float = float(box.get_theme_constant(&"separation"))
	var previous: Control = null
	for child: Control in box.get_children():
		# A hidden row keeps whatever rect it last had; only what is drawn has
		# to fit on screen, and only what is drawn takes part in the spacing.
		if not child.visible:
			continue
		if not visible.encloses(child.get_global_rect()):
			_failures += 1
			printerr("  FAIL: %s leaves the viewport at %s" % [child.name, tag])
		if previous != null:
			var gap: float = child.position.y - previous.position.y - previous.size.y
			if absf(gap - separation) > 1.0:
				_failures += 1
				printerr("  FAIL: %s gap %s->%s is %.1f, want %.0f" % [
					tag, previous.name, child.name, gap, separation
				])
			if absf(child.position.x - previous.position.x) > 1.0 \
					or absf(child.size.x - previous.size.x) > 1.0:
				_failures += 1
				printerr("  FAIL: %s %s is not aligned with %s" % [tag, child.name, previous.name])
		previous = child


## The whole point of the F8-5 fix: the column no longer hands its leftover
## space to whatever rows are still visible, so a plate is the same height with
## 이어하기 on screen and without it, at every window size.
func _check_plate_height_ignores_the_save() -> void:
	for key: String in _plate_heights:
		var per_state: Dictionary = _plate_heights[key]
		var without_save: float = float(per_state.get("nosave", -1.0))
		var with_save: float = float(per_state.get("save", -1.0))
		print("    %s plate height: nosave=%.1f save=%.1f" % [key, without_save, with_save])
		if absf(without_save - with_save) > 1.0:
			_failures += 1
			printerr("  FAIL: %s plate is %.1f tall without a save and %.1f with one" % [
				key, without_save, with_save
			])


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shoot(tag: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, tag])


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
		"save_version": 1, "day": 2, "gold": 137.0, "audio": {},
	}, "\t"))
	file.close()
