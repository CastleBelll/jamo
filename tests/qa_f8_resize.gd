extends Node

## QA-only probe: sweeps the window through a range of sizes and prints the
## title plate in both canvas units and real screen pixels, so a reviewer can
## see the plate tracks the window instead of sitting on a fixed pixel size.
## Run windowed:  godot --path . res://tests/qa_f8_resize.tscn

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const SIZES: Array[Vector2i] = [
	Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1440, 810),
	Vector2i(1600, 900), Vector2i(1760, 990), Vector2i(1920, 1080),
	Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 576),
]

var _title: Control


func _ready() -> void:
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	await _settle()
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		await _settle()
		var window: Vector2i = DisplayServer.window_get_size()
		var visible: Vector2 = get_viewport().get_visible_rect().size
		var rect: Rect2 = _title.get_node("%NewGameButton").get_global_rect()
		var scale: float = float(window.y) / visible.y
		print("window=%dx%d units=%.0fx%.0f screen_px=%.0fx%.0f" % [
			window.x, window.y, rect.size.x, rect.size.y,
			rect.size.x * scale, rect.size.y * scale
		])
	get_tree().quit(0)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
