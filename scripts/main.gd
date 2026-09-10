extends Node

## Drives one RUN. Everything it touches is a node placed in main.tscn, so the
## flow can be followed by reading the scene tree. Doc v0.4 sections 4 and 35.
##
## Main Hub -> RUN 시작 -> Wave 1 -> ... -> 문장핵 HP 0 -> 결과 화면 -> Main Hub.
## A failed run clears RunState; MetaState is never touched by a defeat.

## Scene the pause menu and the result screen go back to. Exported so the entry
## point can be repointed in the Inspector instead of in code.
@export_file("*.tscn") var hub_scene_path: String = "res://scenes/ui/title_screen.tscn"

## Opacity of the screen dim shown behind the result panel.
@export_range(0.0, 1.0, 0.01) var dim_opacity: float = 0.55
@export_range(0.0, 2.0, 0.05) var dim_fade_seconds: float = 0.35

## TEMPORARY, Phase 0 only. The 문장핵 is Phase 1 work, so nothing damages the
## core yet and a run could never end. Until the wave controller exists, running
## out of manual energy stands in for the core falling, which is what makes the
## Phase 0 completion criterion - start Wave 1, fail, return to the hub -
## reachable. Doc v0.4 section 7.1 is explicit that energy 0 must NOT end a wave
## once real waves exist, so this has to be turned off in Phase 1.
@export var end_run_when_energy_depleted: bool = true

@onready var _world: Node3D = $World/GameWorld
@onready var _hud: Control = $UI/HUD
@onready var _dim: ColorRect = $UI/Dim
@onready var _run_result: Control = $UI/RunResult
@onready var _pause_menu: Control = $UI/PauseMenu
@onready var _settings: Control = $UI/Settings

var _run_ending: bool = false


func _ready() -> void:
	SignalBus.energy_depleted.connect(_on_energy_depleted)
	_hud.settings_pressed.connect(_settings.open)
	_hud.pause_pressed.connect(_pause_menu.open)
	_hud.codex_pressed.connect(_on_codex_pressed)
	_pause_menu.settings_requested.connect(_settings.open)
	_pause_menu.hub_requested.connect(_on_hub_requested)
	_run_result.hub_requested.connect(_on_hub_requested)

	_dim.color.a = 0.0
	_dim.visible = false

	# The hub decides which run this scene is playing: it either resumed one
	# from disk or started a fresh one. Reaching this scene with no active run
	# at all means the scene was opened directly, so start Wave 1.
	if not RunState.is_active:
		SaveManager.load_game()
		RunState.start_run()
	_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _run_ending or _pause_menu.visible:
		return
	_pause_menu.open()
	get_viewport().set_input_as_handled()


func _on_energy_depleted() -> void:
	if not end_run_when_energy_depleted:
		return
	_fail_run()


## Doc v0.4 section 35: the run ends, the RunState on disk is dropped, the
## result is shown, and the player goes back to the hub.
func _fail_run() -> void:
	if _run_ending or not RunState.is_active:
		return
	_run_ending = true
	# Let lingering damage-over-time resolve first; a kill it lands still pays.
	await get_tree().create_timer(MetaState.balance.run_end_settle_seconds).timeout

	var reached_wave := RunState.current_wave
	var kills := int(RunState.get_run_statistic("kills"))
	var gold_earned := RunState.get_run_statistic("gold_earned")
	var is_record := reached_wave > MetaState.highest_wave

	RunState.end_run()
	_world.spawn_manager.clear_field()
	# The run leaves the disk before the result screen appears, so quitting out
	# of the result cannot resurrect a run that already failed.
	SaveManager.clear_run()

	_set_dim(true)
	_run_result.open(reached_wave, kills, gold_earned, is_record)


func _on_codex_pressed() -> void:
	# The in-run codex view is Phase 4. Nothing to open yet.
	pass


## Leaving mid-run suspends it rather than failing it: the pause menu has
## already written the run out, so the hub offers RUN 이어하기.
## Doc v0.4 section 44.
func _on_hub_requested() -> void:
	get_tree().change_scene_to_file(hub_scene_path)


func _set_dim(enabled: bool) -> void:
	if enabled:
		_dim.visible = true
	var target := dim_opacity if enabled else 0.0
	var tween := create_tween()
	tween.tween_property(_dim, ^"color:a", target, dim_fade_seconds)
	if not enabled:
		tween.tween_callback(func() -> void: _dim.visible = false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_run()
