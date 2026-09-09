extends Control

## Minimal settings for the vertical slice: window mode and save deletion.

signal closed()

@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _delete_confirm: ConfirmationDialog = %DeleteConfirm


func _ready() -> void:
	hide()
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() \
		== DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	%DeleteSaveButton.pressed.connect(_delete_confirm.popup_centered)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	%SettingsCloseButton.pressed.connect(_on_close_pressed)


func open() -> void:
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


func _on_close_pressed() -> void:
	hide()
	closed.emit()
