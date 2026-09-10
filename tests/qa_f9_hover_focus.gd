extends Node

## Walks the title menu through a pointer-and-keyboard sequence and shoots every
## step, so the F8 carry-over MEDIUM-4 can be judged from pixels instead of from
## the code: exactly one plate may be drawn in its selected (bright) version, in
## every mix of the two inputs, including the pointer being left behind on a
## plate the keyboard has walked away from.
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa_f9_hover_focus.tscn
## Nothing here writes to user://.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f9"
## A plate counts as bright when its centre luminance clears this. The plain
## plate measures ~0.05 and the selected one ~0.75, so the gap is wide.
const BRIGHT_LUMA := 0.35
const OFF_EVERY_PLATE := Vector2(40, 40)

var _title: Control
var _failures: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()

	# 1. Keyboard only, pointer parked off every plate.
	_warp_to(OFF_EVERY_PLATE)
	_press_arrow_to("SettingsButton")
	await _settle()
	_report("1_keyboard_settings", "SettingsButton")

	# 2. The pointer moves onto another plate: it takes the selection with it
	#    rather than lighting a second one.
	_warp_to(_centre("QuitButton"))
	await _settle()
	_report("2_pointer_moves_to_quit", "QuitButton")

	# 3. The MEDIUM-4 case. The keyboard walks back to 설정 while the pointer is
	#    still resting on 종료, so the two inputs point at different plates.
	_press_arrow_to("SettingsButton")
	await _settle()
	_report("3_keyboard_settings_pointer_left_on_quit", "SettingsButton")

	# 4. The pointer leaves without touching anything: nothing changes.
	_warp_to(OFF_EVERY_PLATE)
	await _settle()
	_report("4_pointer_off_every_plate", "SettingsButton")

	# 5. And back the other way - pointer first, then the keyboard - onto 새 게임.
	_warp_to(_centre("NewGameButton"))
	await _settle()
	_report("5_pointer_moves_to_new_game", "NewGameButton")
	_press_arrow_to("QuitButton")
	await _settle()
	_report("6_keyboard_quit_pointer_left_on_new_game", "QuitButton")

	if _failures == 0:
		print("OK - one selected plate in every pointer/keyboard mix.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d step(s) drew the wrong number of selected plates." % _failures)
		get_tree().quit(1)


## Stands in for the arrow keys: what matters to the plate art is which button
## ends up holding the keyboard focus, not how it got there.
func _press_arrow_to(name: String) -> void:
	(_title.get_node("%%%s" % name) as Button).grab_focus()


func _centre(name: String) -> Vector2:
	return (_title.get_node("%%%s" % name) as Control).get_global_rect().get_center()


## Godot only updates a Control's hover state from real mouse motion, so the
## pointer is warped and a matching motion event is pushed by hand.
func _warp_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(event)


func _report(tag: String, expected: String) -> void:
	var path := "%s/hover_%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	# Read the frame back off disk rather than sampling the live viewport
	# texture: the two do not share an orientation on every driver, and the
	# saved PNG is the artifact a human will check the verdict against.
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	var bright: Array[String] = []
	var focused := ""
	for name: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button: Button = _title.get_node("%%%s" % name)
		if not button.visible:
			continue
		if button.has_focus():
			focused = name
		# A quarter in from the plate's left edge, clear of the label glyphs.
		var rect: Rect2 = button.get_global_rect()
		var point := Vector2i(
			int(rect.position.x + rect.size.x * 0.25), int(rect.get_center().y)
		)
		var colour: Color = image.get_pixelv(point)
		if colour.get_luminance() >= BRIGHT_LUMA:
			bright.append("%s(%.2f)" % [name, colour.get_luminance()])
	print("--- %s focus=%s bright_plates=%d %s" % [
		tag, focused, bright.size(), str(bright)
	])
	if bright.size() != 1 or not bright[0].begins_with(expected):
		_failures += 1
		printerr("  FAIL: %s should light %s alone, lit %s" % [tag, expected, str(bright)])
	if focused != expected:
		_failures += 1
		printerr("  FAIL: %s should leave the keyboard on %s, got %s" % [tag, expected, focused])


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
