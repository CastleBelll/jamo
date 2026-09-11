extends Node

## QA P1 playthrough: Wave 1 through Wave 5 played with real clicks in a real
## window, then on into the repeated wave until the 문장핵 falls.
## Doc v0.4 section 48 Phase 1 completion bar. WINDOW MODE ONLY - it renders
## and screenshots every wave, and it measures frame rate on a full field.
##
## Run: godot --path . res://tests/qa_p1_play.tscn
##
## What it records per wave: energy spent, kills, monsters that reached the
## core, and the 문장핵 HP at the end of the wave. That is the evidence for
## the DEV wave-curve claim (W1~2 cleared by clicking, W3+ leaks, W5 survived).

const RUN_SCENE := "res://scenes/main/main.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p1/play"
## Waves that have to be reachable for Phase 1 to be done.
const TARGET_WAVE := 5
## Hard stop so a stuck wave fails loudly instead of hanging the harness.
const WAVE_FRAME_BUDGET := 4000
## Field size the frame-rate probe fills to. Doc v0.4 section 36 caps it at 20.
const FPS_FIELD := 20
const FPS_SAMPLE_FRAMES := 300
## Consecutive clicks that land on nothing before the wave is called unclickable.
const MISS_BUDGET := 40
## Waves are walked at this clock so the whole file finishes in minutes. The
## frame-rate probe drops back to 1.0.
const PLAY_TIME_SCALE := 3.0

var _failures: int = 0
var _shot_index: int = 0
var _wave_log: Array[Dictionary] = []
var _cleared: Array[int] = []
var _failed_args: Array = []
## Landed clicks tallied by the monster state they hit, and the non-lethal
## subset - evidence that the play mixed clicks into SPAWN / TURN.
var _clicks_by_state: Dictionary = {}
var _nonlethal_by_state: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	SignalBus.run_failed.connect(
		func(wave: int, kills: int, gold: float, is_record: bool) -> void:
			_failed_args = [wave, kills, gold, is_record]
	)
	await _run()
	Engine.time_scale = 1.0
	_print_table()
	if _failures == 0:
		print("OK - Wave 1~%d play through, the core is the only failure." % TARGET_WAVE)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _run() -> void:
	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	var hud: Control = main.get_node("UI/HUD")
	var result: Control = main.get_node("UI/RunResult")
	_check(core != null and spawner != null, "the run scene carries a SentenceCore and a spawner")
	await _settle()
	await _shoot("00_wave1_start")
	print("    HUD: %s | %s | %s | %s | %s" % [
		hud.get_node("%WaveLabel").text, hud.get_node("%CoreLabel").text,
		hud.get_node("%EnergyLabel").text, hud.get_node("%GoldLabel").text,
		hud.get_node("%KillsLabel").text,
	])

	Engine.time_scale = PLAY_TIME_SCALE
	for _pass in TARGET_WAVE + 4:
		if not RunState.is_active:
			break
		await _play_one_wave(spawner, hud)
	Engine.time_scale = 1.0

	_check(_reached_wave() >= TARGET_WAVE,
		"Wave %d was reached by playing, got %d" % [TARGET_WAVE, _reached_wave()])
	_check(_cleared.has(TARGET_WAVE - 1),
		"Wave %d was cleared on the way, cleared %s" % [TARGET_WAVE - 1, str(_cleared)])

	_check(not RunState.is_active, "the run ended inside the budget")
	_check(_failed_args.size() == 4, "run_failed carried 4 arguments, got %s" % str(_failed_args))
	var banked: float = MetaState.gold
	var waited := 0
	while not result.visible and waited < 2000:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the result screen appeared after the core fell")
	await _settle()
	await _shoot("90_run_result")
	if result.visible:
		var subtitle: Label = result.get_node("Center/Panel/Box/SubtitleLabel")
		print("    subtitle: %s" % subtitle.text)
		print("    result: %s | %s | %s" % [
			result.get_node("%ResultWaveLabel").text,
			result.get_node("%ResultKillsLabel").text,
			result.get_node("%ResultGoldLabel").text,
		])
		_check(subtitle.text.contains("문장핵이 무너졌다"),
			"the subtitle names the fallen 문장핵, got %s" % subtitle.text)
	_check(MetaState.gold == banked and banked > 0.0,
		"the gold earned in the failed run stayed permanent (%.2f)" % MetaState.gold)
	_check(not SaveManager.has_run_save(), "the failed run left the disk")
	print("    banked gold after the defeat: %.2f, highest wave %d"
		% [MetaState.gold, MetaState.highest_wave])

	await _measure_frame_rate(spawner)


## Plays the current wave: spends every point of energy on real clicks, then
## watches the rest of the wave resolve without any input at all.
func _play_one_wave(spawner: SpawnManager, hud: Control) -> void:
	var wave: int = RunState.current_wave
	var data: WaveData = MetaState.database.find_wave(wave)
	var core_before: float = RunState.core_hp
	var kills_before: float = RunState.get_run_statistic("kills")
	var energy_start: int = RunState.current_energy
	var clicks: int = 0

	var frames := 0
	var misses := 0
	while RunState.is_active and RunState.current_wave == wave \
			and RunState.current_energy > 0 and frames < WAVE_FRAME_BUDGET \
			and misses < MISS_BUDGET:
		var monster: JamoMonster = _closest_alive_to_core(spawner.objective)
		if monster == null:
			await get_tree().process_frame
			frames += 1
			continue
		if await _click_monster(monster):
			clicks += 1
			misses = 0
		else:
			misses += 1
		frames += 2
	_check(misses < MISS_BUDGET,
		"Wave %d: %d clicks in a row missed a monster that was on screen" % [wave, misses])

	var zero_shot_taken := false
	while RunState.is_active and RunState.current_wave == wave and frames < WAVE_FRAME_BUDGET:
		if not zero_shot_taken and RunState.current_energy == 0:
			zero_shot_taken = true
			_check(not RunState.can_click(),
				"Wave %d: manual clicks are refused at energy 0" % wave)
			_check(spawner.is_spawning() or spawner.alive_count() > 0,
				"Wave %d: the wave is still running at energy 0" % wave)
			_check(hud.get_node("%EnergyWarnLabel").text.contains("WAVE 는 계속된다"),
				"Wave %d: the HUD says the wave goes on, got %s"
					% [wave, hud.get_node("%EnergyWarnLabel").text])
			if wave == 3:
				await _shoot("30_wave3_energy_zero_wave_continues")
		await get_tree().process_frame
		frames += 1

	var kills: int = int(RunState.get_run_statistic("kills") - kills_before)
	var leaked: float = core_before - RunState.core_hp
	_wave_log.append({
		"wave": wave,
		"count": data.enemy_count if data != null else 0,
		"hp": int(MetaState.balance.monster_hp_for_wave(data, 1.0)),
		"energy": energy_start,
		"clicks": clicks,
		"kills": kills,
		"core_lost": leaked,
		"core_left": RunState.core_hp,
		"cleared": _cleared.has(wave),
	})
	if RunState.is_active and wave <= TARGET_WAVE:
		_check(RunState.current_wave == wave + 1,
			"Wave %d handed over to Wave %d, got %d" % [wave, wave + 1, RunState.current_wave])
		_check(RunState.current_energy == RunState.get_max_energy(),
			"Wave %d Clear refilled the energy, got %d / %d"
				% [wave, RunState.current_energy, RunState.get_max_energy()])
		await _settle()
		await _shoot("%02d_wave%d_start" % [wave * 10, wave + 1])


## One real click, delivered where the monster is drawn on screen.
func _click_monster(monster: JamoMonster) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_check(false, "the arena has no current Camera3D to click through")
		return false
	var before: int = RunState.current_energy
	# The body centre, not the hit anchor: the anchor sits above the glyph and a
	# click aimed there can sail over the ClickArea sphere.
	var point: Vector2 = camera.unproject_position(monster.global_position)
	_warp_to(point)
	await get_tree().process_frame
	# Read right before the press: which state the click lands in, and whether
	# it can kill. A non-lethal click in SPAWN/TURN is the P1 freeze trigger.
	var state: String = JamoMonster.State.keys()[monster.get_state()]
	var lethal: bool = monster.hp <= RunState.get_click_damage()
	_click_at(point)
	await get_tree().process_frame
	await get_tree().process_frame
	var landed: bool = RunState.current_energy < before
	if landed:
		_clicks_by_state[state] = int(_clicks_by_state.get(state, 0)) + 1
		if not lethal:
			_nonlethal_by_state[state] = int(_nonlethal_by_state.get(state, 0)) + 1
	return landed


## Frame rate with a full field. Doc v0.4 section 36 asks for 20 monsters at
## 60 FPS. Measured at time_scale 1 on the real run scene, with the monsters
## still walking at the 문장핵.
func _measure_frame_rate(spawner: SpawnManager) -> void:
	print("-- frame rate on a full field")
	Engine.time_scale = 1.0
	RunState.start_run()
	await get_tree().process_frame
	# The probe measures frame time on a full field, not the fail rule: with the
	# 문장핵 still targeted, 20 monsters flatten it before the field even fills
	# and the WaveController stops the spawner on run_failed.
	spawner.objective = null
	var wave := WaveData.new()
	wave.wave_number = 1
	for scene: PackedScene in MetaState.database.find_wave(TARGET_WAVE).enemy_pool:
		wave.enemy_pool.append(scene)
	wave.enemy_count = 500
	wave.max_alive = FPS_FIELD
	wave.spawn_interval = 0.05
	# The probe is about frame time, not balance: fat HP keeps the field full.
	wave.hp_multiplier = 60.0
	spawner.configure_wave(wave)
	var frames := 0
	while spawner.alive_count() < FPS_FIELD and frames < WAVE_FRAME_BUDGET:
		await get_tree().process_frame
		frames += 1
	_check(spawner.alive_count() >= FPS_FIELD,
		"the field filled to %d monsters, got %d" % [FPS_FIELD, spawner.alive_count()])
	for _i in 60:
		await get_tree().process_frame
	var samples: Array[float] = []
	for _i in FPS_SAMPLE_FRAMES:
		await get_tree().process_frame
		samples.append(Engine.get_frames_per_second())
	samples.sort()
	var total := 0.0
	for value: float in samples:
		total += value
	var average: float = total / samples.size()
	var low_index: int = maxi(0, int(samples.size() * 0.01))
	await _shoot("95_full_field_%d" % spawner.alive_count())
	print("    %d alive: avg %.1f FPS, min %.1f, low 1 pct %.1f"
		% [spawner.alive_count(), average, samples[0], samples[low_index]])
	_check(average >= 60.0,
		"20 monsters hold 60 FPS (doc v0.4 section 36), average was %.1f" % average)
	var outside := 0
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster == null or not monster.is_inside_tree():
			continue
		var extents: Vector2 = monster.get_walkable_half_extents()
		if JamoMonster.arena_spill(monster.global_position, extents) > 1.02:
			outside += 1
	_check(outside == 0, "no monster escaped the arena on a full field, %d did" % outside)
	print("    monsters outside their walkable rectangle: %d" % outside)
	spawner.stop()
	spawner.clear_field()


# --- plumbing ---------------------------------------------------------------

func _reached_wave() -> int:
	var highest := 1
	for entry: Dictionary in _wave_log:
		highest = maxi(highest, int(entry["wave"]))
	return highest


func _closest_alive_to_core(core: Node3D) -> JamoMonster:
	var best: JamoMonster = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster == null or not monster.is_inside_tree() or not monster.is_alive():
			continue
		var distance: float = monster.global_position.distance_to(core.global_position)
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


func _print_table() -> void:
	print("-- wave log")
	print("    wave | count | hp | energy | clicks | kills | core lost | core left | cleared")
	for entry: Dictionary in _wave_log:
		print("    %4d | %5d | %2d | %6d | %6d | %5d | %9.0f | %9.0f | %s" % [
			entry["wave"], entry["count"], entry["hp"], entry["energy"], entry["clicks"],
			entry["kills"], entry["core_lost"], entry["core_left"], str(entry["cleared"]),
		])
	print("    clicks landed by state: %s" % str(_clicks_by_state))
	print("    non-lethal clicks by state: %s" % str(_nonlethal_by_state))


func _click_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)


func _warp_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _shoot(tag: String) -> void:
	_shot_index += 1
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("    shot: %s" % path)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _enter(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_check(false, "could not load %s" % path)
		return null
	var scene: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	return scene
