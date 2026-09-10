extends Control

## Pause overlay. Pausing only stops the world; the UI keeps processing because
## this node runs in PROCESS_MODE_ALWAYS (set in the scene).

signal settings_requested()
## Raised after the run has been saved and the tree unpaused. The scene swap
## itself belongs to main.gd, which owns scene level flow.
signal hub_requested()

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(close)
	%PauseSettingsButton.pressed.connect(settings_requested.emit)
	%HubButton.pressed.connect(_on_hub_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func open() -> void:
	get_tree().paused = true
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


## Leaving for the hub suspends the run rather than failing it: the run is
## written out first so the hub can offer RUN 이어하기. Doc v0.4 section 44.
func _on_hub_pressed() -> void:
	SaveManager.save_run()
	hide()
	get_tree().paused = false
	hub_requested.emit()


func _on_quit_pressed() -> void:
	SaveManager.save_run()
	get_tree().quit()
