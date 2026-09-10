extends Control

## Title screen: the first thing the game shows. It decides whether a run is
## waiting to be continued and only then hands control to the game scene.
## Doc v0.3 section 30 (save points) and section 31 Phase 11.
##
## The settings panel is the same packed scene the game uses, instanced here
## with run_in_progress off so it neither writes progress nor offers to delete
## a save the player has not started yet.

## Scene entered by 새 게임 and 이어하기. Exported so the entry point can be
## repointed in the Inspector instead of in code.
@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main.tscn"

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _continue_info: Label = %ContinueInfoLabel
@onready var _settings: Control = %Settings
@onready var _overwrite_confirm: ConfirmationDialog = %OverwriteConfirm


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_start_game)
	%SettingsButton.pressed.connect(_settings.open)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_settings.closed.connect(_on_settings_closed)
	_overwrite_confirm.confirmed.connect(_on_overwrite_confirmed)
	# Dismissing the dialog leaves the keyboard with nothing selected unless the
	# title takes focus back.
	_overwrite_confirm.canceled.connect(focus_default_button)

	# Nothing has loaded progress yet, but the volume sliders in the settings
	# panel still have to show what the player set on an earlier run.
	SaveManager.load_audio_settings()
	refresh()


## Repaints the continue row from what is on disk. Public so a caller that
## changed the save can ask for a refresh.
func refresh() -> void:
	var save: Dictionary = SaveManager.peek_save()
	var has_progress: bool = save.has("day")
	_continue_button.disabled = not has_progress
	# A disabled button still answers the geometric focus search, so the arrow
	# keys would stop on a button that does nothing. Taking it out of the focus
	# chain is what actually makes it skippable.
	_continue_button.focus_mode = (
		Control.FOCUS_NONE if _continue_button.disabled else Control.FOCUS_ALL
	)
	# The reason is spelled out in words: a greyed out button is not a message,
	# and colour alone must never carry the information.
	if has_progress:
		_continue_info.text = "저장된 진행 — DAY %d · %d G" % [
			maxi(1, int(save.get("day", 1))),
			int(floorf(maxf(0.0, float(save.get("gold", 0.0))))),
		]
	else:
		_continue_info.text = "저장된 게임이 없어 이어하기를 할 수 없습니다."
	focus_default_button()


## Entry focus, so the keyboard always has somewhere to start and the focus
## outline is visible from the first frame.
func focus_default_button() -> void:
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()


## A new game overwrites the run on disk, so it asks first. The save is only
## removed once the dialog is confirmed. Doc v0.3 section 30.
func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_overwrite_confirm.popup_centered()
		# The dialog focuses its OK button on its own, but the destructive
		# choice must never be the one Enter lands on.
		_overwrite_confirm.get_cancel_button().grab_focus()
		return
	_start_game()


## Only the run is dropped. Volumes are the player's setup, not run data, so
## starting over must not silently reset the mixer.
func _on_overwrite_confirmed() -> void:
	SaveManager.clear_progress()
	_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file(game_scene_path)


## The settings panel takes focus while it is open, so hand it back on close
## rather than leaving the keyboard with nothing selected.
func _on_settings_closed() -> void:
	focus_default_button()


func _on_quit_pressed() -> void:
	get_tree().quit()
