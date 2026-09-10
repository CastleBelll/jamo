extends Node

## QA re-verification of the P0 HIGH: is the v0.3 migration notice actually
## legible, and is that legibility independent of the photo behind it?
##
## Written independently of tests/qa_p0_flow.gd on purpose. That harness takes
## the darkest and the brightest pixel of the whole notice rect and divides
## them, which cannot tell a glyph read against its own outline from a glyph
## read against a bright patch of the panel somewhere else in the rect. Here
## every ink pixel is measured against what actually surrounds it, and the whole
## measurement is repeated over five forced backgrounds and four panel spots.
##
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa2_notice_contrast.tscn
## The player save is stashed and put back.

const HUB_SCENE := "res://scenes/ui/title_screen.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p0/notice"
const BACKUP_PATH := "user://jamo_save.json.qa2bak"

const LEGACY_SAVE := {
	"save_version": 1,
	"day": 42,
	"gold": 1234.5,
	"upgrade_levels": {"click_damage": 3},
	"unlocked_words": ["fire_001"],
	"jamo_inventory": {"ㅂ": 2},
	"target_word": "fire_002",
}

## A pixel counts as glyph ink when every channel is this close to the theme
## font_color, in 0-255 units. Antialiased edges fall outside and are ignored.
const INK_DELTA := 10
## How far out from an ink pixel to look for the flat colour it is read
## against. A 6px outline plus its antialiasing fits inside this.
const SURROUND_RADIUS := 14
## A pixel is "settled" - a flat area rather than a point on an antialiasing
## ramp - when it differs from all eight of its neighbours by no more than this,
## in 0-255 units. Without this every measurement lands on the ramp between the
## ink and its outline, which is part of the glyph and is the same whatever is
## behind it.
const SETTLED_SPREAD := 6
## Backgrounds forced under the panel. The Scrim is a full-screen ColorRect
## between the photo and the menu, so an opaque colour there replaces whatever
## the photo was drawing. "photo" leaves the scene as authored.
const BACKGROUNDS: Array = [
	["photo", null],
	["white", Color(1.0, 1.0, 1.0, 1.0)],
	["bright_wood", Color(0.80, 0.64, 0.45, 1.0)],
	["outline_cream", Color(0.949, 0.902, 0.808, 1.0)],
	["black", Color(0.0, 0.0, 0.0, 1.0)],
]
## Panel positions swept over the photo, as (anchor_left, anchor_top) pairs.
const PANEL_SPOTS: Array = [
	["topright", Vector2(0.700, 0.045)],
	["topleft", Vector2(0.015, 0.045)],
	# Kept clear of 0.355-0.645 horizontally: the plate column is drawn on top
	# of the panel there and would cover the notice instead of backing it.
	["bottomright", Vector2(0.700, 0.700)],
	["bottomleft", Vector2(0.015, 0.700)],
]

var _failures: int = 0
var _hub: Control
var _note: Label
var _scrim: ColorRect
var _rows: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LEGACY_SAVE, "\t"))
	file.close()
	# The hub loads the save itself; calling load_game() here would migrate the
	# file first and leave the hub with nothing to report.
	_hub = (load(HUB_SCENE) as PackedScene).instantiate()
	add_child(_hub)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	_note = _hub.get_node("%MigrationNoteLabel")
	_scrim = _hub.get_node("Scrim")
	_check(SaveManager.migrated_from_v03, "the v0.3 file migrated")
	_check(_note.visible, "the notice is on screen")
	print("notice text: %s" % _note.text)
	print("theme font_color=%s outline_color=%s outline_size=%d font_size=%d" % [
		str(_note.get_theme_color(&"font_color")),
		str(_note.get_theme_color(&"font_outline_color")),
		_note.get_theme_constant(&"outline_size"),
		_note.get_theme_font_size(&"font_size"),
	])

	var authored_scrim: Color = _scrim.color
	for entry: Array in BACKGROUNDS:
		_scrim.color = authored_scrim if entry[1] == null else (entry[1] as Color)
		await _settle()
		await _measure(String(entry[0]))
	_scrim.color = authored_scrim

	var panel: Control = _hub.get_node("Safe/Content/GrowthPanel")
	var authored_spot := Vector2(panel.anchor_left, panel.anchor_top)
	var span := Vector2(
		panel.anchor_right - panel.anchor_left, panel.anchor_bottom - panel.anchor_top
	)
	for spot: Array in PANEL_SPOTS:
		var at: Vector2 = spot[1]
		panel.anchor_left = at.x
		panel.anchor_top = at.y
		panel.anchor_right = at.x + span.x
		panel.anchor_bottom = at.y + span.y
		await _settle()
		await _measure("photo_%s" % String(spot[0]))
	panel.anchor_left = authored_spot.x
	panel.anchor_top = authored_spot.y
	panel.anchor_right = authored_spot.x + span.x
	panel.anchor_bottom = authored_spot.y + span.y

	_restore_save()
	print("")
	print("| case | ink px | worst surround | median surround | darkest settled pixel in rect |")
	print("|---|---|---|---|---|")
	for row: String in _rows:
		print(row)
	print("")
	if _failures == 0:
		print("OK - the notice clears 4.5:1 against its own surroundings in %d cases."
			% _rows.size())
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


## Shoots the frame, crops the notice, and reports the worst contrast any ink
## pixel has against the pixels around it at each ring distance.
func _measure(tag: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var rect: Rect2 = _note.get_global_rect()
	var scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	# Padded so the surround search can reach outside the label box.
	var pad: int = SURROUND_RADIUS + 2
	var box := Rect2i(
		Vector2i(floori(rect.position.x * scale.x) - pad, floori(rect.position.y * scale.y) - pad),
		Vector2i(ceili(rect.size.x * scale.x) + pad * 2, ceili(rect.size.y * scale.y) + pad * 2)
	).intersection(Rect2i(Vector2i.ZERO, image.get_size()))

	image.get_region(box).save_png("%s/notice_%s.png" % [OUT_DIR, tag])

	var declared: Color = _note.get_theme_color(&"font_color")
	var ink_luma: float = _relative_luminance(declared)
	var ink_points: Array[Vector2i] = []
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			if _channel_delta(image.get_pixel(x, y), declared) <= INK_DELTA:
				ink_points.append(Vector2i(x, y))

	_check(ink_points.size() > 200,
		"%s: only %d ink pixels found - the notice is not drawing its theme colour"
			% [tag, ink_points.size()])
	if ink_points.size() <= 200:
		return

	var settled: Dictionary = _settled_mask(image, box)
	var worst := 999.0
	var worst_colour := Color.WHITE
	var ratios: Array[float] = []
	for point: Vector2i in ink_points:
		var darkest := 2.0
		var darkest_colour := Color.WHITE
		for radius: int in range(2, SURROUND_RADIUS + 1):
			for dy: int in range(-radius, radius + 1):
				for dx: int in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dy)) != radius:
						continue
					var at: Vector2i = point + Vector2i(dx, dy)
					if not settled.has(at):
						continue
					var neighbour: Color = image.get_pixelv(at)
					if _channel_delta(neighbour, declared) <= INK_DELTA:
						continue
					var luma: float = _relative_luminance(neighbour)
					if luma < darkest:
						darkest = luma
						darkest_colour = neighbour
			if darkest < 1.5:
				break
		if darkest > 1.5:
			continue
		var ratio: float = _contrast(ink_luma, darkest)
		ratios.append(ratio)
		if ratio < worst:
			worst = ratio
			worst_colour = darkest_colour
	ratios.sort()
	var median: float = 0.0 if ratios.is_empty() else ratios[ratios.size() / 2]

	# A hard floor: the darkest flat colour anywhere inside the padded rect,
	# glyph ink aside. Nothing the notice is drawn over can be worse than this.
	var floor_luma := 2.0
	var floor_colour := Color.WHITE
	for at: Vector2i in settled:
		var pixel: Color = image.get_pixelv(at)
		if _channel_delta(pixel, declared) <= INK_DELTA * 6:
			continue
		var luma: float = _relative_luminance(pixel)
		if luma < floor_luma:
			floor_luma = luma
			floor_colour = pixel
	var floor_ratio: float = _contrast(ink_luma, floor_luma)

	print("--- %s ink=%d settled=%d worst=%.2f:1 against %s median=%.2f:1 | rect floor %.2f:1 against %s"
		% [tag, ink_points.size(), settled.size(), worst, str(worst_colour), median,
			floor_ratio, str(floor_colour)])
	_check(worst >= 4.5,
		"%s: an ink pixel only reaches %.2f:1 against %s, want >= 4.5:1"
			% [tag, worst, str(worst_colour)])
	_rows.append("| %s | %d | %.2f:1 | %.2f:1 | %.2f:1 |"
		% [tag, ink_points.size(), worst, median, floor_ratio])


## The pixels inside `box` that sit in a flat area rather than on an
## antialiasing ramp, as a set keyed by position.
func _settled_mask(image: Image, box: Rect2i) -> Dictionary:
	var mask: Dictionary = {}
	for y: int in range(box.position.y + 1, box.end.y - 1):
		for x: int in range(box.position.x + 1, box.end.x - 1):
			var here: Color = image.get_pixel(x, y)
			var flat := true
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if _channel_delta(here, image.get_pixel(x + dx, y + dy)) > SETTLED_SPREAD:
						flat = false
			if flat:
				mask[Vector2i(x, y)] = true
	return mask


## WCAG 2.x relative luminance, with the sRGB transfer function applied.
func _relative_luminance(c: Color) -> float:
	var channels: Array[float] = [c.r, c.g, c.b]
	for i: int in channels.size():
		var v: float = channels[i]
		channels[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _contrast(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Largest single-channel difference between two colours, in 0-255 units.
func _channel_delta(a: Color, b: Color) -> int:
	return maxi(
		absi(int(a.r8) - int(b.r8)),
		maxi(absi(int(a.g8) - int(b.g8)), absi(int(a.b8) - int(b.b8)))
	)


func _check(passed: bool, message: String) -> void:
	if passed:
		return
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
