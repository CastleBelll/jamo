extends Node

## Renders the real title screen at several window sizes and writes PNGs plus a
## measured layout/contrast report. Run windowed (NOT --headless):
##   godot --path . res://tests/qa_f7_art.tscn
## QA-only harness for F7 re-verification; it never destroys the player save.

const HubPlates := preload("res://tests/hub_plates.gd")
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/f7/r2"
const BACKUP_PATH := "user://jamo_save.json.artbak"

const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(720, 1280),
	Vector2i(2560, 1080),
	Vector2i(1920, 720),
]

var _title: Control


func _ready() -> void:
	_stash_save()
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	await _settle()

	for size: Vector2i in SIZES:
		await _capture_size(size, "nosave")

	# Save present: 이어하기 becomes active and takes the entry focus.
	_write_fake_save()
	_title.refresh()
	await _settle()
	for size: Vector2i in SIZES:
		await _capture_size(size, "save")

	# Overwrite dialog drawn over the art.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	_title._on_new_run_pressed()
	await _settle()
	_shoot("dialog_1280x720")
	_title._overwrite_confirm.hide()
	await _settle()

	# Settings panel drawn over the art.
	_title.get_node("%Settings").open()
	await _settle()
	_shoot("settings_1280x720")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _settle()
	_shoot("settings_1920x1080")

	_restore_save()
	print("DONE")
	get_tree().quit(0)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shoot(tag: String) -> Image:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, tag])
	return image


func _capture_size(size: Vector2i, state: String) -> void:
	DisplayServer.window_set_size(size)
	await _settle()
	var actual: Vector2i = DisplayServer.window_get_size()
	var tag: String = "%s_%dx%d" % [state, actual.x, actual.y]
	var image: Image = _shoot(tag)
	_report(tag, size, actual, image)


## Maps a Control rect (canvas units) into pixels of the captured frame.
func _to_pixels(rect: Rect2, image: Image) -> Rect2i:
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var scale: Vector2 = Vector2(image.get_width(), image.get_height()) / visible
	return Rect2i(
		Vector2i(roundi(rect.position.x * scale.x), roundi(rect.position.y * scale.y)),
		Vector2i(roundi(rect.size.x * scale.x), roundi(rect.size.y * scale.y))
	)


func _report(tag: String, asked: Vector2i, actual: Vector2i, image: Image) -> void:
	var visible: Rect2 = get_viewport().get_visible_rect()
	print("--- %s (asked %dx%d, window %dx%d, viewport %.0fx%.0f, image %dx%d)" % [
		tag, asked.x, asked.y, actual.x, actual.y,
		visible.size.x, visible.size.y, image.get_width(), image.get_height()
	])
	var names: Array[String] = HubPlates.all(_title)
	names.append("ContinueInfoLabel")
	var rects: Array[Rect2] = []
	var shown: Array[bool] = []
	for node_name: String in names:
		var control: Control = _title.get_node("%" + node_name)
		var rect: Rect2 = control.get_global_rect()
		rects.append(rect)
		shown.append(control.is_visible_in_tree())
		var pixels: Rect2i = _to_pixels(rect, image)
		var inside: bool = visible.encloses(rect)
		print("    %-18s canvas=%s px=%s inside_viewport=%s shown=%s" % [
			node_name, str(rect), str(pixels), str(inside),
			str(control.is_visible_in_tree())
		])
		if control.is_visible_in_tree() and not inside:
			printerr("  FAIL: %s leaves the viewport at %s" % [node_name, tag])
	var logo: Rect2 = _title.get_node("Safe/Content/Logo").get_global_rect()
	print("    Logo               canvas=%s inside_viewport=%s" % [
		str(logo), str(visible.encloses(logo))
	])
	if shown[0] and logo.intersects(rects[0]):
		printerr("  FAIL: the logo overlaps the first button at %s" % tag)
	# A hidden control keeps the rect it had when it was last laid out, so the
	# overlap check has to skip it: the hub hides two rows when there is no run
	# to continue, and their stale rects would read as a collision even though
	# nothing is drawn there.
	for i in range(rects.size()):
		if not shown[i]:
			continue
		for j in range(i + 1, rects.size()):
			if not shown[j]:
				continue
			if rects[i].intersects(rects[j]):
				printerr("  FAIL: %s overlaps %s at %s" % [names[i], names[j], tag])
	_check_edges(image, tag)
	var focus_owner: Control = _title.get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		print("    focus owner: %s" % focus_owner.name)
		_measure_rect(image, focus_owner.get_global_rect(),
			"focused:%s" % focus_owner.name, 0.02, 0.85)
	_measure_rect(image, _title.get_node("%ContinueButton").get_global_rect(),
		"ContinueButton", 0.02, 0.85)
	_measure_rect(image, _title.get_node("%ContinueInfoLabel").get_global_rect(),
		"ContinueInfoLabel", 0.10, 0.97)


## A letterbox shows up as near-black pixels along an edge of the frame.
func _check_edges(image: Image, tag: String) -> void:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var samples: Array[Color] = [
		image.get_pixel(2, height / 2), image.get_pixel(width - 3, height / 2),
		image.get_pixel(width / 2, 2), image.get_pixel(width / 2, height - 3),
	]
	var flat: int = 0
	var text: String = ""
	for c: Color in samples:
		text += c.to_html(false) + " "
		if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
			flat += 1
	print("    edge samples: %s" % text)
	if flat > 0:
		printerr("  WARN: %d edge sample(s) look like letterbox at %s" % [flat, tag])


func _luminance(c: Color) -> float:
	var parts: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		parts.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Splits the pixels of a rect by luminance and reports the contrast between the
## dark percentile (glyph ink) and the light percentile (the plate behind it).
func _measure_rect(
	image: Image, source: Rect2, label: String, low: float, high: float
) -> void:
	var rect: Rect2i = _to_pixels(source, image).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	if rect.size.x < 8 or rect.size.y < 4:
		return
	var pixels: Array[Color] = []
	var lums: Array[float] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c: Color = image.get_pixel(x, y)
			pixels.append(c)
			lums.append(_luminance(c))
	var order: Array[int] = []
	for i in range(lums.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return lums[a] < lums[b])
	var dark: Color = pixels[order[int(order.size() * low)]]
	var light: Color = pixels[order[int(order.size() * high)]]
	print("    %-26s rect=%s dark=%s light=%s contrast=%.2f:1" % [
		label, str(rect), dark.to_html(false), light.to_html(false),
		_contrast(dark, light)
	])


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
