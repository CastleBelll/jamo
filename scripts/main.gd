extends Node

## Drives the day loop and owns the order of the between-day panels.
## Everything it touches is a node placed in main.tscn, so the flow can be
## followed by reading the scene tree.
##
## Day 1 -> click until energy 0 -> day summary -> jamo pick -> word check
## -> upgrade shop -> Day 2. Nothing resets. Doc v0.3 section 2.1.

## Opacity of the screen dim shown behind the between-day panels.
@export_range(0.0, 1.0, 0.01) var dim_opacity: float = 0.55
@export_range(0.0, 2.0, 0.05) var dim_fade_seconds: float = 0.35

@onready var _world: Node3D = $World/GameWorld
@onready var _hud: Control = $UI/HUD
@onready var _dim: ColorRect = $UI/Dim
@onready var _day_end: Control = $UI/DayEnd
@onready var _jamo_choice: Control = $UI/JamoChoice
@onready var _word_complete: Control = $UI/WordComplete
@onready var _upgrade_shop: Control = $UI/UpgradeShop
@onready var _word_dex: Control = $UI/WordDex
@onready var _pause_menu: Control = $UI/PauseMenu
@onready var _settings: Control = $UI/Settings

var _day_end_running: bool = false


func _ready() -> void:
	SignalBus.energy_depleted.connect(_on_energy_depleted)
	_hud.dictionary_pressed.connect(_word_dex.open)
	_hud.settings_pressed.connect(_settings.open)
	_hud.pause_pressed.connect(_pause_menu.open)
	_pause_menu.settings_requested.connect(_settings.open)

	_dim.color.a = 0.0
	_dim.visible = false

	SaveManager.load_game()
	GameState.begin_day()
	_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _day_end_running or _pause_menu.visible:
		return
	_pause_menu.open()
	get_viewport().set_input_as_handled()


func _on_energy_depleted() -> void:
	if _day_end_running:
		return
	_day_end_running = true
	_run_day_end()


## The between-day sequence. Doc v0.3 section 12: lingering damage-over-time is
## allowed to finish first, and any kill it lands still pays out.
func _run_day_end() -> void:
	await get_tree().create_timer(GameState.balance.day_end_settle_seconds).timeout

	var finished_day := GameState.day
	var kills := GameState.kills_today
	var gold_earned := GameState.gold_earned_today

	_set_dim(true)

	_day_end.open(finished_day, kills, gold_earned)
	await _day_end.closed

	_jamo_choice.open()
	var jamo: String = await _jamo_choice.chosen
	if not jamo.is_empty():
		GameState.add_jamo(jamo)

	var completed := GameState.complete_ready_words()
	if not completed.is_empty():
		_word_complete.open(completed)
		await _word_complete.closed
	SaveManager.save_game()

	_upgrade_shop.open()
	await _upgrade_shop.closed

	GameState.advance_day()
	_world.spawn_manager.clear_field()
	SaveManager.save_game()

	_set_dim(false)
	_day_end_running = false
	SignalBus.day_ended.emit(finished_day, kills, gold_earned)


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
		SaveManager.save_game()
