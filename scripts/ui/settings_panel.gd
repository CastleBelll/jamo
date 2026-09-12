extends PanelContainer
## 설정 (G10): volumes, screen, text scale, 흔들림/섬광, keyboard mode, 계속하기. Every change
## previews immediately and saves; opening it never resumes the combat clock.

signal closed

## Embedded in a library tab: the panel stays visible and shows no 계속하기 button.
var embedded: bool = false
var text_root: Control


func _ready() -> void:
	for key in ["master", "bgm", "sfx", "ui"]:
		var slider: HSlider = get_node("%%%sSlider" % key.capitalize())
		slider.value_changed.connect(func(v): SettingsService.set_and_save(key, int(v)); _refresh_labels())
	%FullscreenCheck.toggled.connect(func(on): SettingsService.set_and_save("fullscreen", on))
	%FlashCheck.toggled.connect(func(on): SettingsService.set_and_save("flash", on))
	%KeyboardCheck.toggled.connect(func(on): SettingsService.set_and_save("keyboard_mode", on))
	%TextScaleOption.item_selected.connect(func(i): SettingsService.set_and_save("text_scale", SettingsService.TEXT_SCALES[i]); _apply_text_scale())
	%ShakeOption.item_selected.connect(func(i): SettingsService.set_and_save("shake", SettingsService.SHAKE_LEVELS[i]))
	%CloseButton.pressed.connect(func(): if not embedded: visible = false; closed.emit())
	for v in SettingsService.TEXT_SCALES:
		%TextScaleOption.add_item("%d%%" % v)
	for v in SettingsService.SHAKE_LEVELS:
		%ShakeOption.add_item("%d%%" % v)


func open(root_for_text: Control = null, embed: bool = false) -> void:
	text_root = root_for_text
	embedded = embed
	%CloseButton.visible = not embed
	for key in ["master", "bgm", "sfx", "ui"]:
		get_node("%%%sSlider" % key.capitalize()).set_value_no_signal(int(Meta.setting(key)))
	%FullscreenCheck.set_pressed_no_signal(bool(Meta.setting("fullscreen")))
	%FlashCheck.set_pressed_no_signal(bool(Meta.setting("flash")))
	%KeyboardCheck.set_pressed_no_signal(bool(Meta.setting("keyboard_mode")))
	%TextScaleOption.select(SettingsService.TEXT_SCALES.find(int(Meta.setting("text_scale"))))
	%ShakeOption.select(SettingsService.SHAKE_LEVELS.find(int(Meta.setting("shake"))))
	_refresh_labels()
	visible = true
	%CloseButton.grab_focus()


func _refresh_labels() -> void:
	%VolumeLabel.text = "마스터 %d · BGM %d · SFX %d · UI %d" % [int(Meta.setting("master")), int(Meta.setting("bgm")), int(Meta.setting("sfx")), int(Meta.setting("ui"))]


func _apply_text_scale() -> void:
	if text_root != null:
		SettingsService.apply_text_scale(text_root, int(Meta.setting("text_scale")))
