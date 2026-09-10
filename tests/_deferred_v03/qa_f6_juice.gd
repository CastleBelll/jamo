extends Node

## QA harness for F6 juice / polish. Not a pass/fail unit test: it runs the real
## main.tscn, drives real input events and writes observation artifacts
## (screenshots + JSON) for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f6_juice.tscn
##
## Doc v0.3 sections 12, 14.2, 23, 24, 25, 36.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f6"
const GOLDEN_SCENE := "res://scenes/monsters/special/monster_golden_hieut.tscn"
## How many clicks the burst test fires while sampling the frame time.
const BURST_CLICKS := 20
## Frames sampled per FPS measurement window.
const FPS_SAMPLE_FRAMES := 120

var _main: Node
var _world: Node3D
var _camera: Camera3D
var _hud: Control
var _spawner: Node
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	_world = _main.get_node("World/GameWorld")
	_camera = _world.get_node("CameraRig/ShakePivot/Camera3D")
	_hud = _main.get_node("UI/HUD")
	_spawner = _world.get_node("SpawnManager")

	_report["audio_buses"] = _probe_audio_buses()
	_report["missing_audio"] = _probe_missing_audio()
	_report["click_feedback"] = await _probe_click_feedback()
	_report["burst_pooling"] = await _probe_burst_pooling()
	_report["burn_ember"] = await _probe_burn_ember()
	_report["golden_sparkle"] = await _probe_golden_sparkle()
	_report["load_fps"] = await _probe_load_fps()
	_report["word_reveal"] = await _probe_word_reveal()
	_report["word_reveal_skip"] = await _probe_word_reveal_skip()
	_report["energy_feedback"] = await _probe_energy_feedback()
	_report["energy_warning_threshold_ab"] = await _probe_warning_threshold()
	_report["day_end_settle"] = await _probe_day_end_settle()

	_write_report()
	get_tree().quit()


# --- Audio ------------------------------------------------------------------


## The three buses have to come from default_bus_layout.tres, not from code.
func _probe_audio_buses() -> Dictionary:
	var names := PackedStringArray()
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return {
		"bus_count": AudioServer.bus_count,
		"bus_names": names,
		"layout_setting": str(ProjectSettings.get_setting("audio/buses/default_bus_layout", "")),
	}


## Every cue the game can fire, played once. The point is that none of them
## raises a load error while the repository has no audio files.
func _probe_missing_audio() -> Dictionary:
	var library: AudioLibrary = AudioManager.library
	var cues := {}
	for key: StringName in [
		&"click", &"click_critical", &"click_golden", &"kill", &"word_complete"
	]:
		var path: String = "" if library == null else library.path_for(key)
		cues[String(key)] = {"path": path, "exists": ResourceLoader.exists(path)}
		AudioManager.play_sfx(key)

	var steps := {}
	for file_name: String in DirAccess.get_files_at("res://resources/motion_profiles"):
		if not file_name.ends_with(".tres"):
			continue
		var profile: MotionProfile = load("res://resources/motion_profiles/%s" % file_name)
		steps[file_name] = {
			"step_sfx_path": profile.step_sfx_path,
			"exists": ResourceLoader.exists(profile.step_sfx_path),
		}
		AudioManager.play_sfx_path(profile.step_sfx_path)

	return {
		"library_assigned": library != null,
		"bgm_path": "" if library == null else library.bgm,
		"cues": cues,
		"step_paths": steps,
	}


# --- S1 click feedback ------------------------------------------------------


## One real click on one real monster, captured on the frame the feedback is
## still on screen.
func _probe_click_feedback() -> Dictionary:
	var monster := await _wait_for_monster()
	if monster == null:
		return {"error": "no monster spawned"}

	var fx_root: Node3D = _world.get_node("FXRoot")
	var numbers_before := _damage_number_count(fx_root)
	var anim: AnimationPlayer = monster.get_node("AnimationPlayer")

	await _click_monster(monster)
	await get_tree().process_frame
	var anim_after := str(anim.current_animation)
	var emitting := _emitting_count(_world.get_node("FXRoot/HitFXPool"))
	var numbers_after := _damage_number_count(fx_root)
	# Let the burst, the squash and the rising number get a few frames of
	# travel, otherwise the capture shows the instant before any of it moved.
	await get_tree().create_timer(0.15).timeout
	await _shot("s1_single_click")

	return {
		"animation_after_click": anim_after,
		"hitfx_emitting": emitting,
		"damage_numbers_added": numbers_after - numbers_before,
	}


## 20 clicks as fast as the input queue takes them. Nothing may be added to the
## pools and the frame time may not collapse.
func _probe_burst_pooling() -> Dictionary:
	var hit_pool: Node3D = _world.get_node("FXRoot/HitFXPool")
	var death_pool: Node3D = _world.get_node("FXRoot/DeathFXPool")
	var before := {
		"hit_pool": hit_pool.get_child_count(),
		"death_pool": death_pool.get_child_count(),
	}

	GameState.energy = 999
	var energy_before := GameState.energy
	var worst_frame_ms := 0.0
	var clicks_landed := 0
	for i in BURST_CLICKS:
		var monster := await _wait_for_monster()
		if monster == null:
			break
		var started := Time.get_ticks_usec()
		await _click_monster(monster)
		clicks_landed += 1
		worst_frame_ms = maxf(worst_frame_ms, float(Time.get_ticks_usec() - started) / 1000.0)

	await _shot("s1_burst_20")
	return {
		"clicks_attempted": clicks_landed,
		# Energy is only spent on a click that actually hit a monster, so this
		# is the honest count of landed hits.
		"clicks_that_hit": energy_before - GameState.energy,
		"pool_before": before,
		"pool_after": {
			"hit_pool": hit_pool.get_child_count(),
			"death_pool": death_pool.get_child_count(),
		},
		"worst_click_frame_ms": worst_frame_ms,
		"fps_during_burst": await _sample_fps(),
	}


# --- S2 status VFX ----------------------------------------------------------


## Burn has to switch the ember on through effects_changed and off again when
## the effect expires, with nothing left emitting afterwards.
func _probe_burn_ember() -> Dictionary:
	_unlock_word_by_jamo(["ㅂ", "ㅜ", "ㄹ"])
	var burn: WordEffectData = GameState.get_burn_effect()
	if burn == null:
		return {"error": "burn effect still locked after completing the word"}

	# One monster on the field, so the capture cannot be misread as somebody
	# else's particles.
	_spawner.clear_field()
	await get_tree().process_frame
	var monster := await _wait_for_monster()
	if monster == null:
		return {"error": "no monster spawned"}
	monster.max_hp = 9999.0
	monster.hp = 9999.0
	var ember: CPUParticles3D = monster.get_node("StatusEffectAnchor/BurnEmber")
	var before := ember.emitting

	monster.apply_status_effect(burn)
	await get_tree().process_frame
	var during := ember.emitting
	# The emitter needs time on screen before it has any particles to show.
	await get_tree().create_timer(0.8).timeout
	_report["burn_ember_monster"] = {
		"jamo": monster.name,
		"screen": str(_camera.unproject_position(monster.global_position)),
	}
	await _shot("s2_burn_ember_on")

	# Wait out the burn rather than forcing it off, so the off switch is the
	# real effects_changed path.
	var waited := 0.0
	while ember.emitting and waited < burn.duration + 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var after := ember.emitting
	await _shot("s2_burn_ember_off")
	# Particles already in flight keep their remaining lifetime; after that the
	# monster has to be clean, which is what step 9 of the handoff asks for.
	await get_tree().create_timer(ember.lifetime + 0.5).timeout
	var still_emitting := ember.emitting
	await _shot("s2_burn_ember_cleared")

	return {
		"emitting_after_particle_lifetime": still_emitting,
		"ember_lifetime": ember.lifetime,
		"burn_duration": burn.duration,
		"emitting_before": before,
		"emitting_during": during,
		"emitting_after_expiry": after,
		"seconds_until_off": waited,
		"env_glow_enabled": _glow_enabled(),
	}


func _probe_golden_sparkle() -> Dictionary:
	# 금 sits behind 돈 in the tree, so the prerequisite has to be completed
	# first or the unlock silently does not happen.
	_unlock_word_by_jamo(["ㄷ", "ㅗ", "ㄴ"])
	_unlock_word_by_jamo(["ㄱ", "ㅡ", "ㅁ"])
	_spawner.clear_field()
	await get_tree().process_frame
	var golden: JamoMonster = load(GOLDEN_SCENE).instantiate()
	_world.get_node("MonsterRoot").add_child(golden)
	golden.global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	var sparkle: CPUParticles3D = golden.get_node_or_null("StatusEffectAnchor/GoldSparkle")
	var result := {
		"golden_unlocked": GameState.is_golden_monster_unlocked(),
		"sparkle_node_present": sparkle != null,
		"sparkle_emitting": sparkle != null and sparkle.emitting,
		"sparkle_amount": 0 if sparkle == null else sparkle.amount,
		"env_glow_enabled": _glow_enabled(),
		"screen": str(_camera.unproject_position(golden.global_position)),
	}
	await get_tree().create_timer(0.8).timeout
	await _shot("s2_golden_sparkle")
	golden.queue_free()
	await get_tree().process_frame
	return result


# --- Performance ------------------------------------------------------------


## The doc's 60 FPS budget, measured with the field full and burns running.
func _probe_load_fps() -> Dictionary:
	GameState.energy = 9999
	# Day 1 capacity is well under 20, so buy the capacity track up to the top
	# rather than fake the field: the spawner still does its own placement.
	GameState.upgrade_levels[GameState.UPGRADE_MONSTER_CAPACITY] = 99
	var burn: WordEffectData = GameState.get_burn_effect()
	var deadline := Time.get_ticks_msec() + 30000
	while _alive_monsters().size() < 20 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var monsters := _alive_monsters()
	var burning := 0
	for monster: JamoMonster in monsters:
		monster.max_hp = 99999.0
		monster.hp = 99999.0
		if burn != null:
			monster.apply_status_effect(burn)
			burning += 1
	# Keep the hit particles busy on top of the burns.
	for i in 10:
		if i < monsters.size():
			SignalBus.damage_dealt.emit(monsters[i].get_hit_position(), 1.0, false)
	await get_tree().process_frame
	var fps := await _sample_fps()
	await _shot("perf_20_monsters_burning")
	return {
		"monsters_alive": monsters.size(),
		"monsters_burning": burning,
		"fps": fps,
	}


# --- S4 word completion sequence --------------------------------------------


## The four beats of doc v0.3 section 14.2, captured one at a time: the jamo on
## the ring, the jamo travelling in, the panel punching out, the camera zoom.
func _probe_word_reveal() -> Dictionary:
	var panel: Control = _main.get_node("UI/WordComplete")
	var word: WordData = GameState.database.find_word(&"fire_001")
	var fly_layer: Control = panel.get_node("%FlyLayer")
	var reveal_anim: AnimationPlayer = panel.get_node("%RevealAnim")
	var size_before := _camera.size
	var queue: Array[WordData] = [word]

	panel.open(queue)
	await get_tree().process_frame
	var ring_positions := _fly_positions(panel)
	await _shot("s4_1_gather_ring")
	var stage_ring := {
		"fly_layer_visible": fly_layer.visible,
		"panel_visible": panel.get_node("Center/Panel").visible,
		"jamo_on_ring": ring_positions.size(),
		"ring_spread_px": _spread(ring_positions),
	}

	await get_tree().create_timer(0.25).timeout
	var mid_positions := _fly_positions(panel)
	await _shot("s4_2_gather_midway")
	var stage_mid := {"spread_px": _spread(mid_positions)}

	# Wait out the whole gather so the reveal happens on its own.
	var deadline := Time.get_ticks_msec() + 4000
	while not panel.get_node("Center/Panel").visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var stage_reveal := {
		"panel_visible": panel.get_node("Center/Panel").visible,
		"fly_layer_visible": fly_layer.visible,
		"reveal_anim_playing": reveal_anim.is_playing(),
		"reveal_anim_name": str(reveal_anim.current_animation),
		"word_text": (panel.get_node("%CompletedWord") as Label).text,
		"jamo_text": (panel.get_node("%CompletedJamo") as Label).text,
		"effect_text": (panel.get_node("%CompletedEffect") as Label).text,
		"camera_size_at_reveal": _camera.size,
		"camera_size_before": size_before,
	}
	# The reveal animation starts the panel scaled down and the camera zoom
	# peaks a fraction of a second in, so capture the punch, then the settled
	# panel, tracking the smallest camera size seen along the way.
	var smallest := _camera.size
	smallest = minf(smallest, await _track_camera_size(0.1))
	await _shot("s4_3a_reveal_overshoot")
	smallest = minf(smallest, await _track_camera_size(0.1))
	stage_reveal["camera_size_at_zoom_peak"] = smallest
	await _shot("s4_4_camera_zoom")
	smallest = minf(smallest, await _track_camera_size(0.3))
	stage_reveal["camera_size_at_zoom_peak"] = minf(
		float(stage_reveal["camera_size_at_zoom_peak"]), smallest
	)
	await _shot("s4_3b_reveal_settled")
	await get_tree().create_timer(0.7).timeout
	stage_reveal["camera_size_after_zoom_out"] = _camera.size

	# Second word in the same queue has to replay the gather from the top.
	var replay := {}
	var second: WordData = GameState.database.find_word(&"gold_001")
	var pair: Array[WordData] = [word, second]
	panel.open(pair)
	await get_tree().process_frame
	replay["first_gather_jamo"] = _fly_positions(panel).size()
	while not panel.get_node("Center/Panel").visible:
		await get_tree().process_frame
	panel.get_node("%WordCompleteContinue").pressed.emit()
	await get_tree().process_frame
	replay["second_word_gathers_again"] = fly_layer.visible
	replay["second_gather_jamo"] = _fly_positions(panel).size()
	replay["second_panel_hidden_during_gather"] = \
		not panel.get_node("Center/Panel").visible
	await _shot("s4_5_second_word_gather")
	while not panel.get_node("Center/Panel").visible:
		await get_tree().process_frame
	replay["second_word_text"] = (panel.get_node("%CompletedWord") as Label).text
	panel.get_node("%WordCompleteContinue").pressed.emit()
	await get_tree().process_frame

	return {
		"stage_1_ring": stage_ring,
		"stage_2_midway": stage_mid,
		"stage_3_reveal": stage_reveal,
		"queue_replay": replay,
		"panel_hidden_after_queue": not panel.visible,
	}


## A click during the gather has to jump straight to the reveal and leave the
## panel in the same state it would have reached on its own.
func _probe_word_reveal_skip() -> Dictionary:
	var panel: Control = _main.get_node("UI/WordComplete")
	var word: WordData = GameState.database.find_word(&"fire_001")
	var inner: Control = panel.get_node("Center/Panel")

	var by_click := await _skip_once(panel, inner, word, false)
	var by_accept := await _skip_once(panel, inner, word, true)
	return {"skip_by_click": by_click, "skip_by_ui_accept": by_accept}


func _skip_once(
	panel: Control, inner: Control, word: WordData, use_accept: bool
) -> Dictionary:
	var queue: Array[WordData] = [word]
	panel.open(queue)
	await get_tree().process_frame
	await get_tree().process_frame
	var visible_before := inner.visible
	if use_accept:
		# A real key event: Input.action_press only flips the polled state and
		# never reaches the panel's _input handler.
		for pressed: bool in [true, false]:
			var key_event := InputEventKey.new()
			key_event.keycode = KEY_ENTER
			key_event.physical_keycode = KEY_ENTER
			key_event.pressed = pressed
			Input.parse_input_event(key_event)
			await get_tree().process_frame
	else:
		var centre := Vector2(get_viewport().get_visible_rect().size) * 0.5
		Input.warp_mouse(centre)
		await get_tree().process_frame
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = centre
			event.global_position = centre
			Input.parse_input_event(event)
			await get_tree().process_frame
	await get_tree().process_frame
	var result := {
		"panel_visible_before_skip": visible_before,
		"panel_visible_after_skip": inner.visible,
		"word_text": (panel.get_node("%CompletedWord") as Label).text,
		"jamo_text": (panel.get_node("%CompletedJamo") as Label).text,
		"effect_text": (panel.get_node("%CompletedEffect") as Label).text,
		"fly_layer_visible": (panel.get_node("%FlyLayer") as Control).visible,
	}
	await _shot("s4_6_skip_%s" % ("accept" if use_accept else "click"))
	panel.get_node("%WordCompleteContinue").pressed.emit()
	await get_tree().process_frame
	result["closed_after_continue"] = not panel.visible
	return result


## Runs for `seconds` and returns the smallest orthogonal camera size seen,
## which is the peak of the word-complete zoom punch.
func _track_camera_size(seconds: float) -> float:
	var smallest := _camera.size
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
		smallest = minf(smallest, _camera.size)
	return smallest


func _fly_positions(panel: Control) -> Array:
	var found := []
	for i in 8:
		var label: Label = panel.get_node("%%FlyJamo%d" % i)
		if label.visible:
			found.append(label.position)
	return found


## How far apart the travelling jamo currently are; it shrinks as they converge.
func _spread(positions: Array) -> float:
	if positions.size() < 2:
		return 0.0
	var centre := Vector2.ZERO
	for position: Vector2 in positions:
		centre += position
	centre /= float(positions.size())
	var worst := 0.0
	for position: Vector2 in positions:
		worst = maxf(worst, centre.distance_to(position))
	return worst


# --- S3 energy feedback -----------------------------------------------------


func _probe_energy_feedback() -> Dictionary:
	var warn_label: Label = _hud.get_node("%EnergyWarnLabel")
	var bar: ProgressBar = _hud.get_node("%EnergyBar")
	var pulse: AnimationPlayer = _hud.get_node("%EnergyPulseAnim")
	var warn_anim: AnimationPlayer = _hud.get_node("%EnergyWarnAnim")

	# Above the threshold: no warning.
	GameState.energy = 10
	SignalBus.energy_changed.emit(GameState.energy, GameState.get_max_energy())
	await get_tree().process_frame
	var high := {"warn_visible": warn_label.visible, "warn_anim": warn_anim.is_playing()}

	# One real click drops it to the warning band, which also exercises pulse.
	GameState.energy = GameState.balance.low_energy_warning + 1
	var monster := await _wait_for_monster()
	if monster != null:
		await _click_monster(monster)
	await get_tree().process_frame
	var low := {
		"energy": GameState.energy,
		"warn_visible": warn_label.visible,
		"warn_text": warn_label.text,
		"warn_anim_playing": warn_anim.is_playing(),
		"warn_anim_name": str(warn_anim.current_animation),
		"pulse_anim_name": str(pulse.current_animation),
		"bar_self_modulate": str(bar.self_modulate),
	}
	await _shot("s3_low_energy_warning")

	return {
		"above_threshold": high,
		"at_threshold": low,
		"low_energy_warning": GameState.balance.low_energy_warning,
	}


## Step 14 of the handoff: the threshold has to come from GameBalance, not from
## a constant in the HUD. Changed in memory only, then put back, so the .tres on
## disk is never touched.
func _probe_warning_threshold() -> Dictionary:
	var warn_label: Label = _hud.get_node("%EnergyWarnLabel")
	var original: int = GameState.balance.low_energy_warning
	GameState.balance.low_energy_warning = 6

	GameState.energy = 6
	SignalBus.energy_changed.emit(GameState.energy, GameState.get_max_energy())
	await get_tree().process_frame
	var at_six := warn_label.visible
	await _shot("s3_threshold_6")

	GameState.energy = 7
	SignalBus.energy_changed.emit(GameState.energy, GameState.get_max_energy())
	await get_tree().process_frame
	var at_seven := warn_label.visible

	GameState.balance.low_energy_warning = original
	GameState.energy = 6
	SignalBus.energy_changed.emit(GameState.energy, GameState.get_max_energy())
	await get_tree().process_frame
	var restored_at_six := warn_label.visible

	return {
		"threshold_6_warns_at_energy_6": at_six,
		"threshold_6_quiet_at_energy_7": not at_seven,
		"restored_threshold": GameState.balance.low_energy_warning,
		"restored_quiet_at_energy_6": not restored_at_six,
	}


## Energy 0 must not stop the day on the same frame: burn ticks and the kills
## they land are settled first. Doc v0.3 section 12.
func _probe_day_end_settle() -> Dictionary:
	var dim: ColorRect = _main.get_node("UI/Dim")
	var day_end: Control = _main.get_node("UI/DayEnd")
	var warn_label: Label = _hud.get_node("%EnergyWarnLabel")
	var burn: WordEffectData = GameState.get_burn_effect()

	# One monster left, burning, one tick from death: its gold must still land
	# during the settle window.
	_spawner.clear_field()
	await get_tree().process_frame
	var monster := await _wait_for_monster()
	if monster == null:
		return {"error": "no monster spawned"}
	monster.max_hp = 100.0
	monster.hp = 0.9
	if burn != null:
		monster.apply_status_effect(burn)
	# The burn ticks once a second; wait most of that out so its lethal tick
	# falls inside the settle window rather than after it.
	await get_tree().create_timer(0.5).timeout
	var gold_before := GameState.gold_earned_today
	var kills_before := GameState.kills_today

	GameState.energy = 1
	var spent := GameState.spend_click_energy()
	await get_tree().process_frame
	var at_zero := {
		"energy": GameState.energy,
		"spent": spent,
		"warn_visible_at_zero": warn_label.visible,
		"dim_visible": dim.visible,
		"day_end_visible": day_end.visible,
	}
	await _shot("s3_energy_zero_settling")

	var started := Time.get_ticks_msec()
	while not day_end.visible and Time.get_ticks_msec() - started < 5000:
		await get_tree().process_frame
	var elapsed_ms := Time.get_ticks_msec() - started
	await _shot("s3_day_end")

	return {
		"settle_seconds_setting": GameState.balance.day_end_settle_seconds,
		"at_zero": at_zero,
		"day_end_after_ms": elapsed_ms,
		"dim_visible_at_day_end": dim.visible,
		"gold_earned_delta": GameState.gold_earned_today - gold_before,
		"kills_delta": GameState.kills_today - kills_before,
	}


# --- Helpers ----------------------------------------------------------------


func _alive_monsters() -> Array[JamoMonster]:
	var found: Array[JamoMonster] = []
	for child: Node in _world.get_node("MonsterRoot").get_children():
		var monster := child as JamoMonster
		if monster != null and monster.is_alive():
			found.append(monster)
	return found


## Waits for a monster that has finished its spawn animation, so a click lands
## on a settled hitbox rather than on one that is still scaling in.
func _wait_for_monster() -> JamoMonster:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		for monster: JamoMonster in _alive_monsters():
			var anim: AnimationPlayer = monster.get_node("AnimationPlayer")
			if str(anim.current_animation) != "spawn":
				return monster
		await get_tree().process_frame
	return null


## A real mouse click at the monster's projected screen point, so it goes
## through ClickController exactly like a player's click. The pointer is warped
## first because ClickController raycasts from the viewport mouse position, not
## from the event's own coordinates.
func _click_monster(monster: JamoMonster) -> void:
	var screen := _camera.unproject_position(monster.get_hit_position())
	Input.warp_mouse(screen)
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)
		await get_tree().process_frame


func _emitting_count(pool: Node3D) -> int:
	var count := 0
	for child: Node in pool.get_children():
		var particles := child as CPUParticles3D
		if particles != null and particles.emitting:
			count += 1
	return count


func _damage_number_count(fx_root: Node3D) -> int:
	var count := 0
	for child: Node in fx_root.get_children():
		if child.name == "HitFXPool" or child.name == "DeathFXPool":
			continue
		count += 1
	return count


## Completes a word by handing GameState the jamo it asks for, which is the
## same path the jamo choice screen uses.
func _unlock_word_by_jamo(jamo: Array) -> void:
	for piece: String in jamo:
		GameState.add_jamo(piece)
	GameState.complete_ready_words()


func _sample_fps() -> Dictionary:
	var worst_delta := 0.0
	var total := 0.0
	for i in FPS_SAMPLE_FRAMES:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		worst_delta = maxf(worst_delta, delta)
		total += delta
	var average := total / float(FPS_SAMPLE_FRAMES)
	return {
		"frames": FPS_SAMPLE_FRAMES,
		"average_fps": 0.0 if average <= 0.0 else 1.0 / average,
		"worst_frame_ms": worst_delta * 1000.0,
		"engine_fps": Engine.get_frames_per_second(),
	}


## Bloom check: doc v0.3 section 24 rules out a blown-out glow, so record what
## the environment actually has switched on.
func _glow_enabled() -> bool:
	var world_env: WorldEnvironment = _main.get_node_or_null("WorldEnvironment")
	if world_env == null or world_env.environment == null:
		return false
	return world_env.environment.glow_enabled


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/juice_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f6_juice.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f6_juice: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	print(JSON.stringify(_report, "\t"))
	print("OK - F6 juice artifacts written to %s" % ARTIFACT_DIR)
