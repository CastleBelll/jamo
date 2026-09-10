extends Control

## MAIN HUB. Doc v0.4 section 27.
##
## This is not a start button with a picture behind it: it is the permanent
## growth space. It owns the entry to a run, the permanent upgrade shop, the
## codex, the records screen and the settings, and it shows the four permanent
## numbers - Gold, best wave, words discovered, bosses beaten - at a glance.
##
## The plate behaviour settled in F7-F9 is unchanged: exactly one bright plate
## at a time, no focus outline drawn on top, the pointer takes focus with it,
## and plate height is a fraction of the screen rather than a pixel count.
##
## The scene file still lives at scenes/ui/title_screen.tscn. Doc v0.4 section 43
## sketches scenes/main_hub/main_hub.tscn; moving it would break the F7-F9 art
## and regression tests that address this path, so the move is left to whichever
## phase reorganises the scene tree.

## Scene entered by RUN 시작 and RUN 이어하기. Exported so the entry point can be
## repointed in the Inspector instead of in code.
@export_file("*.tscn") var run_scene_path: String = "res://scenes/main/main.tscn"

## Plate height as a fraction of the safe area's height. The plates are measured
## off the screen rather than off their own text, so they follow the window
## instead of being pinned to a pixel count.
@export_range(0.03, 0.25, 0.001) var plate_height_ratio: float = 0.068

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _continue_info: Label = %ContinueInfoLabel
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _codex_button: Button = %CodexButton
@onready var _records_button: Button = %RecordsButton
@onready var _settings: Control = %Settings
@onready var _upgrade_shop: Control = %UpgradeShop
@onready var _codex: Control = %Codex
@onready var _records: Control = %Records
@onready var _overwrite_confirm: ConfirmationDialog = %OverwriteConfirm
@onready var _safe_area: Control = $Safe/Content

@onready var _gold_value: Label = %StatGoldValue
@onready var _wave_value: Label = %StatWaveValue
@onready var _words_value: Label = %StatWordsValue
@onready var _boss_value: Label = %StatBossValue
@onready var _migration_note: Label = %MigrationNoteLabel

## The plates, in the order the column draws them.
var _plates: Array[Button] = []

## The two plate styleboxes and the label colour that goes with the plain one,
## read from the theme once so a later stylebox override cannot be read back as
## if it were the theme's own value. Authored in theme/jamo_theme.tres, never
## built here. Doc v0.4 section 46.
var _plate_plain: StyleBox
var _plate_selected: StyleBox
var _plate_plain_font_color: Color


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_run_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_upgrade_button.pressed.connect(_open_panel.bind(_upgrade_shop))
	_codex_button.pressed.connect(_open_panel.bind(_codex))
	_records_button.pressed.connect(_on_records_pressed)
	%SettingsButton.pressed.connect(_open_panel.bind(_settings))
	%QuitButton.pressed.connect(_on_quit_pressed)
	for panel: Control in [_settings, _upgrade_shop, _codex, _records]:
		panel.closed.connect(_on_panel_closed)
	_overwrite_confirm.confirmed.connect(_on_overwrite_confirmed)
	# Dismissing the dialog leaves the keyboard with nothing selected unless the
	# hub takes focus back.
	_overwrite_confirm.canceled.connect(focus_default_button)

	# Wired before the first refresh(), which is what grabs the entry focus.
	_plates.assign([
		_new_game_button, _continue_button, _upgrade_button,
		_codex_button, _records_button, %SettingsButton, %QuitButton,
	])
	_plate_plain = _new_game_button.get_theme_stylebox("normal", "TitleButton")
	_plate_selected = _new_game_button.get_theme_stylebox("selected", "TitleButton")
	_plate_plain_font_color = _new_game_button.get_theme_color("font_color", "TitleButton")
	for button: Button in _plates:
		_bind_selection_plate(button)

	# The safe area only changes size when the window does, and that is the one
	# thing the plate height is measured against.
	_safe_area.resized.connect(_apply_plate_height)
	_apply_plate_height()

	# The hub is where permanent progress is loaded; a run scene entered from
	# here inherits an already-loaded MetaState. A defeated run left no run
	# block on disk, so this also puts RunState back to empty.
	SaveManager.load_game()
	RunState.reset()
	refresh()


## Gives every plate the same height, whatever else is on the screen. A height
## taken from the safe area is the same with a run to continue and without one,
## and still scales with the window.
func _apply_plate_height() -> void:
	var height: float = roundf(_safe_area.size.y * plate_height_ratio)
	for button: Button in _plates:
		button.custom_minimum_size.y = height


## Repaints the continue row and the growth readout. Public so a caller that
## changed the save can ask for a refresh.
func refresh() -> void:
	var run: Dictionary = SaveManager.peek_run()
	var has_run: bool = not run.is_empty()
	# An option that can never be taken is not shown at all: with no run on disk
	# both RUN 이어하기 and the line underneath it leave the screen rather than
	# sit there greyed out. A hidden row is also the one state the keyboard
	# cannot stop on, whatever the focus search does.
	_continue_button.visible = has_run
	_continue_info.visible = has_run
	_continue_button.disabled = not has_run
	# A disabled button still answers the geometric focus search, so the arrow
	# keys would stop on a button that does nothing. Taking it out of the focus
	# chain is what actually makes it skippable.
	_continue_button.focus_mode = (
		Control.FOCUS_NONE if _continue_button.disabled else Control.FOCUS_ALL
	)
	if has_run:
		_continue_info.text = "진행 중인 RUN — WAVE %d · 문장핵 %d" % [
			maxi(1, int(run.get("current_wave", 1))),
			int(ceilf(maxf(0.0, float(run.get("core_hp", 0.0))))),
		]

	_refresh_growth()
	# A migrated v0.3 save loses its Day count, and saying nothing about that
	# would look like the save was thrown away.
	_migration_note.visible = SaveManager.migrated_from_v03
	focus_default_button()


## The four permanent numbers of doc v0.4 section 27. Every one of them comes
## from MetaState, which is exactly the point: none of this lives on RunState.
func _refresh_growth() -> void:
	_gold_value.text = "%d G" % int(floorf(MetaState.gold))
	_wave_value.text = "%d" % MetaState.highest_wave
	_words_value.text = "%d / %d" % [MetaState.codex_words.size(), _total_word_count()]
	_boss_value.text = "%d" % MetaState.defeated_word_bosses.size()


func _total_word_count() -> int:
	return MetaState.database.words.size() if MetaState.database != null else 0


## The plate art comes in two versions, unselected and selected, and the menu
## must only ever show one selected plate. Godot has no focused draw mode: the
## focus stylebox is painted over whatever the base state already drew. So the
## base style is swapped while the button holds focus, which is the whole of the
## selection cue - the hub draws no focus outline on top of it.
##
## The pointer used to light a second plate of its own, because the hover style
## is bright too and hover state is independent of focus. Two rules keep it to
## one. Hovering hands the button the keyboard focus, so the pointer moves the
## one selection rather than adding a second; and while a button is unfocused
## its hover style is muted to the plain plate, so a pointer left behind when
## the keyboard walks away stops looking selected. The bright plate therefore
## always follows whichever input was used last.
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
## and Enter always goes where the player is pointing. An open panel runs its own
## focus, so the hub does not pull it back while one is up.
func _on_button_mouse_entered(button: Button) -> void:
	if button.focus_mode == Control.FOCUS_NONE or button.has_focus():
		return
	if _is_any_panel_open():
		return
	button.grab_focus()


func _is_any_panel_open() -> bool:
	return _settings.visible or _upgrade_shop.visible or _codex.visible \
		or _records.visible or _overwrite_confirm.visible


## Paints an unfocused plate the same way whether the pointer rests on it or not.
func _mute_hover(button: Button) -> void:
	button.add_theme_stylebox_override("hover", _plate_plain)
	button.add_theme_color_override("font_hover_color", _plate_plain_font_color)


## Entry focus, so the keyboard always has somewhere to start.
func focus_default_button() -> void:
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()


## A new run overwrites the run waiting on disk, so it asks first. Permanent
## progress is never at stake here - only the suspended run. Doc v0.4 section 35.
func _on_new_run_pressed() -> void:
	if SaveManager.has_run_save():
		_overwrite_confirm.popup_centered()
		# The dialog focuses its OK button on its own, but the destructive
		# choice must never be the one Enter lands on.
		_overwrite_confirm.get_cancel_button().grab_focus()
		return
	_start_new_run()


func _on_overwrite_confirmed() -> void:
	_start_new_run()


func _start_new_run() -> void:
	RunState.start_run()
	SaveManager.save_run()
	get_tree().change_scene_to_file(run_scene_path)


## Picks the suspended run back up. If the file turned out to be unusable the
## hub stays put and repaints rather than dropping the player into a blank run.
func _on_continue_pressed() -> void:
	if not SaveManager.load_run():
		refresh()
		return
	get_tree().change_scene_to_file(run_scene_path)


func _open_panel(panel: Control) -> void:
	panel.open()


## The records screen quotes the permanent numbers it will one day break down,
## so the placeholder says something true rather than nothing.
func _on_records_pressed() -> void:
	_records.body_text = (
		"최고 WAVE %d · 발견 단어 %d / %d · 처치 보스 %d\n\n"
		+ "RUN 이력과 상세 통계 화면은 이후 Phase 에서 추가된다."
	) % [
		MetaState.highest_wave,
		MetaState.codex_words.size(),
		_total_word_count(),
		MetaState.defeated_word_bosses.size(),
	]
	_records.open()


## Any panel can have changed gold or the run on disk, so the hub repaints when
## one closes rather than trusting what it drew before.
func _on_panel_closed() -> void:
	refresh()


func _on_quit_pressed() -> void:
	get_tree().quit()
