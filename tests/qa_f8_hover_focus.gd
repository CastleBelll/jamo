extends Node

## Reproduces the mixed input case the F8-QA-2 pass has to judge: the keyboard
## focus sits on one button while the pointer hovers another. Godot paints the
## hover style and the focus style from independent state, so this harness puts
## the two on different buttons on purpose, shoots the frame, and reports how
## many plates are drawn in their selected (bright) version.
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa_f8_hover_focus.tscn
## Nothing here writes to user://.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f8/verify3"
## A plate counts as bright when its centre luminance clears this. The plain
## plate measures ~0.05 and the selected one ~0.75, so the gap is wide.
const BRIGHT_LUMA := 0.35

var _title: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()

	# Baseline: keyboard only, pointer parked off every plate.
	_warp_to(Vector2(40, 40))
	_focus("SettingsButton")
	await _settle()
	_report("keyboard_only_settings")

	# Mixed: keyboard still on 설정, pointer moved onto 종료.
	_warp_to(_centre("QuitButton"))
	await _settle()
	_report("keyboard_settings_hover_quit")

	# Pointer leaves: the hover highlight has to drop immediately.
	_warp_to(Vector2(40, 40))
	await _settle()
	_report("hover_released")

	# Pointer and keyboard agreeing on one button.
	_focus("QuitButton")
	_warp_to(_centre("QuitButton"))
	await _settle()
	_report("keyboard_and_hover_quit")

	get_tree().quit(0)


func _focus(name: String) -> void:
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


func _report(tag: String) -> void:
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


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
