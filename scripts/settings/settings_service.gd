class_name SettingsService
extends RefCounted
## Applies Meta.settings to the engine (G10/G12): audio buses, window mode, text scale.
## Shake/flash/keyboard flags are read by the scenes that animate.

const BUSES := {"master": "Master", "bgm": "BGM", "sfx": "SFX", "ui": "UI"}
const TEXT_SCALES := [100, 125, 150]
const SHAKE_LEVELS := [0, 50, 100]
const BASE_FONT_SIZE := 28


## Volume 0..100 -> dB (0 = silent). Returns the dB actually set.
static func volume_db(percent: int) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(clampf(percent / 100.0, 0.0, 1.0))


static func apply_all() -> void:
	for key in BUSES:
		apply_volume(key, int(Meta.setting(key)))
	apply_fullscreen(bool(Meta.setting("fullscreen")))


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
static func apply_text_scale(root: Control, percent: int) -> void:
	if root.theme == null:
		return
	root.theme.default_font_size = int(round(BASE_FONT_SIZE * percent / 100.0))


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
