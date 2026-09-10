extends Control

## Pause overlay. Pausing only stops the world; the UI keeps processing because
## this node runs in PROCESS_MODE_ALWAYS (set in the scene).

signal settings_requested()
## Raised after the run has been saved and the tree unpaused. The scene swap
## itself belongs to main.gd, which owns scene level flow.
signal title_requested()

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(close)
	%PauseSettingsButton.pressed.connect(settings_requested.emit)
	%TitleButton.pressed.connect(_on_title_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func open() -> void:
	get_tree().paused = true
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


## Leaving for the title is a quit as far as the save file is concerned, so the
## run is written out first. Doc v0.3 section 30.
func _on_title_pressed() -> void:
	SaveManager.save_game()
	hide()
	get_tree().paused = false
	title_requested.emit()


func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()
