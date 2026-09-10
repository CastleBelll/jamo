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

## Plate height as a fraction of the safe area's height. The plates are measured
## off the screen rather than off their own text, so they follow the window
## instead of being pinned to a pixel count. Doc v0.3 section 31 Phase 11.
@export_range(0.03, 0.25, 0.001) var plate_height_ratio: float = 0.093

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _continue_info: Label = %ContinueInfoLabel
@onready var _settings: Control = %Settings
@onready var _overwrite_confirm: ConfirmationDialog = %OverwriteConfirm
@onready var _safe_area: Control = $Safe/Content

## The four plates, in the order the column draws them.
var _plates: Array[Button] = []

## The two plate styleboxes and the label colour that goes with the plain one,
## read from the theme once so a later stylebox override cannot be read back as
## if it were the theme's own value. Doc v0.3 section 38: authored in
## theme/jamo_theme.tres, never built here.
var _plate_plain: StyleBox
var _plate_selected: StyleBox
var _plate_plain_font_color: Color


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

	# Wired before the first refresh(), which is what grabs the entry focus.
	_plates.assign([_new_game_button, _continue_button, %SettingsButton, %QuitButton])
	_plate_plain = _new_game_button.get_theme_stylebox("normal", "TitleButton")
	_plate_selected = _new_game_button.get_theme_stylebox("selected", "TitleButton")
	_plate_plain_font_color = _new_game_button.get_theme_color("font_color", "TitleButton")
	for button: Button in _plates:
		_bind_selection_plate(button)

	# The safe area only changes size when the window does, and that is the one
	# thing the plate height is measured against.
	_safe_area.resized.connect(_apply_plate_height)
	_apply_plate_height()

	# Nothing has loaded progress yet, but the volume sliders in the settings
	# panel still have to show what the player set on an earlier run.
	SaveManager.load_audio_settings()
	refresh()


## Gives every plate the same height, whatever else is on the screen. The
## column used to hand its leftover space to whichever rows were still visible,
## so hiding 이어하기 grew the other three; a height taken from the safe area
## instead is the same with a save and without one, and still scales with the
## window. Doc v0.3 section 31 Phase 11.
func _apply_plate_height() -> void:
	var height: float = roundf(_safe_area.size.y * plate_height_ratio)
	for button: Button in _plates:
		button.custom_minimum_size.y = height


## Repaints the continue row from what is on disk. Public so a caller that
## changed the save can ask for a refresh.
func refresh() -> void:
	var save: Dictionary = SaveManager.peek_save()
	var has_progress: bool = save.has("day")
	# An option that can never be taken is not shown at all: with no run on disk
	# both 이어하기 and the line underneath it leave the screen rather than sit
	# there greyed out. A hidden row is also the one state the keyboard cannot
	# stop on, whatever the focus search does.
	_continue_button.visible = has_progress
	_continue_info.visible = has_progress
	_continue_button.disabled = not has_progress
	# A disabled button still answers the geometric focus search, so the arrow
	# keys would stop on a button that does nothing. Taking it out of the focus
	# chain is what actually makes it skippable.
	_continue_button.focus_mode = (
		Control.FOCUS_NONE if _continue_button.disabled else Control.FOCUS_ALL
	)
	if has_progress:
		_continue_info.text = "저장된 진행 — DAY %d · %d G" % [
			maxi(1, int(save.get("day", 1))),
			int(floorf(maxf(0.0, float(save.get("gold", 0.0))))),
		]
	focus_default_button()


## The plate art comes in two versions, unselected and selected, and the menu
## must only ever show one selected plate. Godot has no focused draw mode: the
## focus stylebox is painted over whatever the base state already drew. So the
## base style is swapped while the button holds focus, which is now the whole of
## the selection cue - the title draws no focus outline on top of it.
##
## The pointer used to light a second plate of its own, because the hover style
## is bright too and hover state is independent of focus: keyboard on 설정 with
## the pointer on 종료 showed two selected plates and no way to tell where Enter
## would go. Two rules keep it to one. Hovering hands the button the keyboard
## focus, so the pointer moves the one selection rather than adding a second;
## and while a button is unfocused its hover style is muted to the plain plate,
## so a pointer left behind when the keyboard walks away stops looking selected.
## The bright plate therefore always follows whichever input was used last.
func _bind_selection_plate(button: Button) -> void:
	button.focus_entered.connect(_on_button_focus_entered.bind(button))
	button.focus_exited.connect(_on_button_focus_exited.bind(button))
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	_mute_hover(button)


func _on_button_focus_entered(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _plate_selected)
	# The theme's own hover art matches the selected plate, so the focused
	# button keeps looking selected with the pointer resting on it.
	button.remove_theme_stylebox_override("hover")
	button.remove_theme_color_override("font_hover_color")


func _on_button_focus_exited(button: Button) -> void:
	button.remove_theme_stylebox_override("normal")
	_mute_hover(button)


## The pointer takes the keyboard focus with it, so hovering lights the plate up
## and Enter always goes where the player is pointing. The settings panel and the
## overwrite dialog run their own focus, so the title does not pull it back while
## either is open.
func _on_button_mouse_entered(button: Button) -> void:
	if button.focus_mode == Control.FOCUS_NONE or button.has_focus():
		return
	if _settings.visible or _overwrite_confirm.visible:
		return
	button.grab_focus()


## Paints an unfocused plate the same way whether the pointer rests on it or not.
func _mute_hover(button: Button) -> void:
	button.add_theme_stylebox_override("hover", _plate_plain)
	button.add_theme_color_override("font_hover_color", _plate_plain_font_color)


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
