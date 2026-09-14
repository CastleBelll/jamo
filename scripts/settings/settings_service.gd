class_name SettingsService
extends RefCounted
## Applies Meta.settings to the engine (G10/G12): audio buses, window mode, text scale.
## Shake/flash/keyboard flags are read by the scenes that animate.

const BUSES := {"master": "Master", "bgm": "BGM", "sfx": "SFX", "ui": "UI"}
const TEXT_SCALES := [100, 125, 150]
const SHAKE_LEVELS := [0, 50, 100]
const BASE_SIZES_META := &"base_font_sizes"
const FIXED_TYPES := [&"BannerLabel", &"TitleLabel"]


## Volume 0..100 -> dB (0 = silent). Returns the dB actually set.
static func volume_db(percent: int) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(clampf(percent / 100.0, 0.0, 1.0))


static func apply_all() -> void:
	for key in BUSES:
		apply_volume(key, int(Meta.setting(key)))
	apply_fullscreen(bool(Meta.setting("fullscreen")))
	apply_text_scale(null, int(Meta.setting("text_scale")))  # the project theme is shared: never leave a stale scale on it


static func apply_volume(key: String, percent: int) -> void:
	var idx := AudioServer.get_bus_index(BUSES[key])
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, volume_db(percent))
	AudioServer.set_bus_mute(idx, percent <= 0)


static func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## Text scale applies as a theme font size on a root Control (Anchor/Container UI reflows).
## Scales every font size the theme pins (Label 30, Button 32, ...) plus the default, and every
## per-node `font_size` override under `root`, so the setting reaches real labels. Base sizes are
## cached (theme meta / node meta), so repeated calls scale from the originals, never from each
## other. Decorative types (banner, title) and glyph tiles keep their size by design.
static func apply_text_scale(root: Control, percent: int) -> void:
	var theme: Theme = root.theme if root != null and root.theme != null else ThemeDB.get_project_theme()
	if theme != null:
		_scale_theme(theme, percent)
	if root != null:
		_scale_overrides(root, percent)


## Font size for overrides created in code after the scene applied its scale.
static func px(base: int) -> int:
	return int(round(base * int(Meta.setting("text_scale")) / 100.0))


static func _scale_theme(theme: Theme, percent: int) -> void:
	if not theme.has_meta(BASE_SIZES_META):
		var base := {"": theme.default_font_size}
		for type in theme.get_font_size_type_list():
			if type in FIXED_TYPES:
				continue
			for name in theme.get_font_size_list(type):
				base["%s/%s" % [type, name]] = theme.get_font_size(name, type)
		theme.set_meta(BASE_SIZES_META, base)
	var base_sizes: Dictionary = theme.get_meta(BASE_SIZES_META)
	for key in base_sizes:
		var size := int(round(base_sizes[key] * percent / 100.0))
		if key == "":
			theme.default_font_size = size
		else:
			var parts: PackedStringArray = key.split("/")
			theme.set_font_size(parts[1], parts[0], size)


static func _scale_overrides(node: Node, percent: int) -> void:
	if node is Control and node.has_theme_font_size_override("font_size") and node.theme_type_variation not in FIXED_TYPES:
		if not node.has_meta(BASE_SIZES_META):
			node.set_meta(BASE_SIZES_META, node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", int(round(int(node.get_meta(BASE_SIZES_META)) * percent / 100.0)))
	for child in node.get_children():
		_scale_overrides(child, percent)


static func shake_factor() -> float:
	return clampf(int(Meta.setting("shake")) / 100.0, 0.0, 1.0)


static func flash_enabled() -> bool:
	return bool(Meta.setting("flash"))


## Sets one key, clamps it to the allowed values, applies it and saves (G10 즉시 미리보기·저장).
static func set_and_save(key: String, value) -> void:
	match key:
		"master", "bgm", "sfx", "ui":
			value = clampi(int(value), 0, 100)
			apply_volume(key, value)
		"text_scale":
			value = int(value) if int(value) in TEXT_SCALES else 100
		"shake":
			value = int(value) if int(value) in SHAKE_LEVELS else 50
		"fullscreen":
			value = bool(value)
			apply_fullscreen(value)
		"flash", "keyboard_mode":
			value = bool(value)
		_:
			return
	Meta.settings[key] = value
	Meta.save()
	Meta.settings_changed.emit(key)
