extends Control

## Pause overlay. Pausing only stops the world; the UI keeps processing because
## this node runs in PROCESS_MODE_ALWAYS (set in the scene).

signal settings_requested()

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(close)
	%PauseSettingsButton.pressed.connect(settings_requested.emit)
	%QuitButton.pressed.connect(_on_quit_pressed)


func open() -> void:
	get_tree().paused = true
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()
