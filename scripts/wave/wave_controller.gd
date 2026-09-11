extends Node

## Drives the waves of one run: hands each wave's data to the SpawnManager,
## declares Wave Clear when every enemy of the wave has been killed or has
## reached the 문장핵, and moves the run on to the next wave.
## Doc v0.4 sections 5, 25 and 31. Placed in main.tscn as WaveController.
##
## The fail rule is not here. RunState.damage_core() ends the run the moment
## the core reaches 0, and Main reacts to SignalBus.run_failed. Doc v0.4 §35.

## The spawner this controller feeds. Assigned in main.tscn.
@export var spawn_manager: SpawnManager
## Seconds the "WAVE CLEAR" beat holds before the next wave begins.
## Doc v0.4 section 31: short, skippable later.
@export_range(0.0, 5.0, 0.1) var wave_clear_delay: float = 1.4

## True while the clear beat is playing, so a second field_cleared cannot
## advance the wave twice.
var _advancing: bool = false


func _ready() -> void:
	if spawn_manager == null:
		push_error("WaveController at %s has no spawn_manager assigned." % get_path())
		return
	spawn_manager.field_cleared.connect(_on_field_cleared)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.run_failed.connect(_on_run_failed)
	# The run was started (or resumed) before this scene existed, so the first
	# wave is launched here without refilling: a resumed run keeps the energy
	# it was suspended with, and only the enemies it had not yet resolved come
	# back. Doc v0.4 section 44.
	if RunState.is_active:
		_launch(RunState.current_wave)


func _on_wave_started(wave: int) -> void:
	_launch(wave)


## Points the spawner at the data for `wave`. Every number comes from the
## WaveData resource; nothing about a wave is decided in code. Doc v0.4 §46.
func _launch(wave: int) -> void:
	var data: WaveData = MetaState.database.find_wave(wave)
	if data == null:
		push_error("WaveController: no WaveData authored for wave %d." % wave)
		return
	_advancing = false
	spawn_manager.configure_wave(data, RunState.wave_resolved_count)


## Every enemy of the wave is resolved. Doc v0.4 section 31:
## Wave Clear -> short settle -> (reward pick, Word Forge) -> next wave.
func _on_field_cleared() -> void:
	if _advancing or not RunState.is_active:
		return
	_advancing = true
	SignalBus.wave_cleared.emit(RunState.current_wave)
	await get_tree().create_timer(wave_clear_delay).timeout
	await _between_waves()
	# The core may have fallen to a straggler tick while the beat played.
	if not RunState.is_active or not is_inside_tree():
		return
	# advance_wave() refills energy and emits wave_started, which is what
	# launches the next wave through _on_wave_started. Doc v0.4 section 7.1.
	RunState.advance_wave()
	# Doc v0.4 section 45 lists Wave Clear as a save point.
	SaveManager.save_run()


## Phase 2 hook. The reward selection and the Word Forge (doc v0.4 sections
## 31 and 32) go here, between the clear beat and the next wave. Phase 1 has
## nothing to offer yet, so the run moves straight on.
func _between_waves() -> void:
	pass


func _on_run_failed(_wave: int, _kills: int, _gold_earned: float, _is_record: bool) -> void:
	spawn_manager.stop()
