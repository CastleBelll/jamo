extends Node
## Run screen root: wires RunController to the page, HUD and the per-phase panels (G2/G10).
## Combat itself (spawns, input) is added in the next feature; this file owns screen flow.

const LIBRARY_SCENE := "res://scenes/hub/last_library.tscn"

@onready var run: RunController = $RunController
@onready var hud: CanvasLayer = $HUD
@onready var prep_panel: PanelContainer = %PrepPanel
@onready var prep_label: Label = %PrepLabel
@onready var clear_panel: PanelContainer = %ClearPanel
@onready var forge_panel: PanelContainer = %ForgePanel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var pause_panel: PanelContainer = %PausePanel
@onready var debug_clear_button: Button = %DebugClearButton


func _ready() -> void:
	var db := ContentDB.load_all()
	var errors := db.validate()
	if not errors.is_empty():
		push_error("content invalid: %s" % errors[0])
	run.setup(db)
	hud.bind(run)
	run.phase_changed.connect(_on_phase_changed)
	%StartWaveButton.pressed.connect(func(): run.begin_combat())
	%FinishClearButton.pressed.connect(func(): run.finish_clear())
	%ConfirmBuildButton.pressed.connect(func(): run.confirm_build())
	%ResultLibraryButton.pressed.connect(_on_return_to_library)
	%ResumeButton.pressed.connect(_close_pause)
	%AbandonButton.pressed.connect(_on_abandon)
	# Skeleton only: until combat exists, the COMBAT phase is cleared by this button.
	debug_clear_button.pressed.connect(func(): run.on_wave_cleared())
	pause_panel.visible = false
	run.open_run_setup()
	run.confirm_setup(&"starter_a")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and run.phase != RunController.Phase.RESULT:
		if pause_panel.visible:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _on_phase_changed(_from: RunController.Phase, to: RunController.Phase) -> void:
	prep_panel.visible = to == RunController.Phase.WAVE_PREP
	clear_panel.visible = to == RunController.Phase.CLEAR
	forge_panel.visible = to == RunController.Phase.FORGE
	result_panel.visible = to == RunController.Phase.RESULT
	debug_clear_button.visible = to == RunController.Phase.COMBAT
	# The combat clock only runs during COMBAT (G2); every other phase keeps it paused.
	get_tree().paused = pause_panel.visible or to != RunController.Phase.COMBAT
	match to:
		RunController.Phase.WAVE_PREP:
			prep_label.text = "Wave %d%s" % [run.wave, " 보스" if run.is_boss_wave() else ""]
			%StartWaveButton.grab_focus()
		RunController.Phase.CLEAR:
			%FinishClearButton.grab_focus()
		RunController.Phase.FORGE:
			%ConfirmBuildButton.grab_focus()
		RunController.Phase.RESULT:
			result_label.text = _result_text(run.end_reason)
			%ResultLibraryButton.grab_focus()


func _result_text(reason: RunController.EndReason) -> String:
	match reason:
		RunController.EndReason.COMPLETED:
			return "첫 문서 복원 완료. 도달 Wave %d" % run.wave
		RunController.EndReason.ABANDONED:
			return "귀환. 도달 Wave %d" % run.wave
		_:
			return "이번 페이지의 연결이 끊어졌다. 서고의 기록은 남아 있다.\n도달 Wave %d" % run.wave


func _open_pause() -> void:
	pause_panel.visible = true
	get_tree().paused = true
	%ResumeButton.grab_focus()


func _close_pause() -> void:
	pause_panel.visible = false
	get_tree().paused = run.phase != RunController.Phase.COMBAT


func _on_abandon() -> void:
	pause_panel.visible = false
	run.abandon()


func _on_return_to_library() -> void:
	if run.return_to_library():
		get_tree().paused = false
		get_tree().change_scene_to_file(LIBRARY_SCENE)
