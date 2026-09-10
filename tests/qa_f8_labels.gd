extends Node

## Captures the title screen exactly as it first appears - no focus is grabbed
## or released - so the unselected button plates and their labels can be read
## off a pristine frame. Run windowed:
##   godot --path . res://tests/qa_f8_labels.tscn
## Writes one frame per size to tests/qa_artifacts/f8/labels/.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f8/labels"

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await _settle()

	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		await _settle()
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/pristine_%dx%d.png" % [OUT_DIR, size.x, size.y])
		for name: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
			var button: Button = title.get_node("%%%s" % name)
			print("--- %dx%d %s rect=%s disabled=%s font_color=%s" % [
				size.x, size.y, name, str(button.get_global_rect()),
				str(button.disabled), str(button.get_theme_color("font_color"))
			])
	print("OK - pristine title frames written.")
	get_tree().quit(0)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
