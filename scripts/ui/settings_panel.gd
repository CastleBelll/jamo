extends Control

## Minimal settings for the vertical slice: window mode, the three audio bus
## volumes and save deletion. Doc v0.3 section 25.

signal closed()

@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _delete_confirm: ConfirmationDialog = %DeleteConfirm
## One row per audio bus: slider, the label showing its percentage, and the bus
## AudioManager applies it to.
@onready var _volume_rows: Array = [
	[%MasterSlider, %MasterValueLabel, AudioManager.BUS_MASTER],
	[%BgmSlider, %BgmValueLabel, AudioManager.BUS_BGM],
	[%SfxSlider, %SfxValueLabel, AudioManager.BUS_SFX],
]


func _ready() -> void:
	hide()
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() \
		== DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	for row: Array in _volume_rows:
		var slider: HSlider = row[0]
		slider.value_changed.connect(_on_volume_changed.bind(row[2] as StringName))
	%DeleteSaveButton.pressed.connect(_delete_confirm.popup_centered)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	%SettingsCloseButton.pressed.connect(_on_close_pressed)
	_refresh_volumes()


## Pulls the sliders back from AudioManager, so opening the panel after a load
## shows the saved positions rather than whatever the scene was built with.
func _refresh_volumes() -> void:
	for row: Array in _volume_rows:
		var slider: HSlider = row[0]
		var value: float = AudioManager.get_volume(row[2] as StringName)
		slider.set_value_no_signal(value)
		_update_volume_label(row[1] as Label, value)


## The percentage is written out as text next to the slider: a slider knob
## position alone is not a readable value.
static func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)


func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioManager.set_volume(bus, value)
	for row: Array in _volume_rows:
		if row[2] == bus:
			_update_volume_label(row[1] as Label, value)


func open() -> void:
	_refresh_volumes()
	show()
	%SettingsCloseButton.grab_focus()


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Wipes the save and restarts, so the player is never left looking at state
## that no longer exists on disk.
func _on_delete_confirmed() -> void:
	SaveManager.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()


## Volumes are part of the save file, so closing the panel writes them out
## instead of waiting for the next day end.
func _on_close_pressed() -> void:
	hide()
	SaveManager.save_game()
	closed.emit()
