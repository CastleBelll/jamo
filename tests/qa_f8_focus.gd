extends Node

## Measures the WCAG 2.2 SC 2.4.11 focus-change contrast of the title buttons.
## Renders the same window twice - once with the button focused, once without -
## and compares the two frames pixel by pixel. Run windowed (NOT --headless):
##   godot --path . res://tests/qa_f8_focus.tscn
## Writes the two frames plus a report to tests/qa_artifacts/f8/.
## It never touches the player save: nothing here writes to user://.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f8"
## SC 2.4.11 asks the focus indicator to change by at least this contrast.
const REQUIRED_CONTRAST := 3.0
## Ignore pixels that barely moved: font anti-aliasing shifts a channel or two
## even where nothing was drawn, and those are not part of the indicator.
const CHANGE_THRESHOLD := 12

const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
]

var _title: Control
var _failures: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	await _settle()

	for size: Vector2i in SIZES:
		await _measure(size)
	await _shoot_overwrite_dialog()

	if _failures == 0:
		print("OK - focus indicator meets %.1f:1 and the dialog fits its contents." % REQUIRED_CONTRAST)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


## Focus 새 게임, shoot, drop focus, shoot again, then diff inside its rect.
func _measure(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await _settle()

	var button: Button = _title.get_node("%NewGameButton")
	button.grab_focus()
	await _settle()
	var focused: Image = _shoot("focus_on_%dx%d" % [size.x, size.y])

	button.release_focus()
	await _settle()
	var unfocused: Image = _shoot("focus_off_%dx%d" % [size.x, size.y])

	_report(size, button, focused, unfocused)


## The overwrite dialog carries no pixel size any more, so this captures it and
## reports the size it settles on next to the size its contents ask for.
func _shoot_overwrite_dialog() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	var confirm: ConfirmationDialog = _title.get_node("%OverwriteConfirm")
	confirm.popup_centered()
	await _settle()
	var minimum: Vector2 = confirm.get_contents_minimum_size()
	print("--- overwrite dialog size=%s contents_minimum=%s" % [
		str(confirm.size), str(minimum)
	])
	if confirm.size.x < int(minimum.x) or confirm.size.y < int(minimum.y):
		_failures += 1
		printerr("  FAIL: the overwrite dialog is smaller than its contents.")
	_shoot("overwrite_dialog_1280x720")
	confirm.hide()
	await _settle()


func _shoot(tag: String) -> Image:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, tag])
	return image


## The button rect in frame pixels, grown so the ring drawn outside it is
## included. The theme pushes the ring out by expand_margin, so a diff limited
## to the rect itself would miss the indicator entirely.
func _search_rect(button: Button, image: Image) -> Rect2i:
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var scale: Vector2 = Vector2(image.get_width(), image.get_height()) / visible
	var rect: Rect2 = button.get_global_rect().grow(12.0)
	var pixels := Rect2i(
		Vector2i(floori(rect.position.x * scale.x), floori(rect.position.y * scale.y)),
		Vector2i(ceili(rect.size.x * scale.x), ceili(rect.size.y * scale.y))
	)
	return pixels.intersection(Rect2i(Vector2i.ZERO, image.get_size()))


func _report(size: Vector2i, button: Button, focused: Image, unfocused: Image) -> void:
	var rect: Rect2i = _search_rect(button, focused)
	var contrasts: Array[float] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var a: Color = unfocused.get_pixel(x, y)
			var b: Color = focused.get_pixel(x, y)
			if _channel_delta(a, b) < CHANGE_THRESHOLD:
				continue
			contrasts.append(_contrast(a, b))
	contrasts.sort()

	if contrasts.is_empty():
		_failures += 1
		printerr("  FAIL: %dx%d - no focus indicator was drawn at all." % [size.x, size.y])
		return

	var median: float = contrasts[contrasts.size() / 2]
	var passing: int = 0
	for value: float in contrasts:
		if value >= REQUIRED_CONTRAST:
			passing += 1
	print("--- %dx%d changed=%d median=%.2f:1 above_%.1f=%d (%.1f%%)" % [
		size.x, size.y, contrasts.size(), median, REQUIRED_CONTRAST,
		passing, 100.0 * passing / contrasts.size()
	])
	if median < REQUIRED_CONTRAST:
		_failures += 1
		printerr("  FAIL: %dx%d focus change median %.2f:1 is below %.1f:1" % [
			size.x, size.y, median, REQUIRED_CONTRAST
		])


## Largest single-channel difference between two colours, in 0-255 units.
func _channel_delta(a: Color, b: Color) -> int:
	return maxi(
		absi(int(a.r8) - int(b.r8)),
		maxi(absi(int(a.g8) - int(b.g8)), absi(int(a.b8) - int(b.b8)))
	)


func _luminance(c: Color) -> float:
	var channels: Array[float] = [c.r, c.g, c.b]
	for i in channels.size():
		var v: float = channels[i]
		channels[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
