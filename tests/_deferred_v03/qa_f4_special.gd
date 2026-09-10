extends Node

## QA harness for F4 special monsters. Not a pass/fail test: it runs the real
## main.tscn, forces the spawn chances in memory only, and writes observation
## artifacts (screenshots + JSON) for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f4_special.tscn
##
## Doc v0.3 sections 9, 24, 28, 36, 37 / growth_balance v0.2 section 2.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f4"

const NORMAL_MIEUM := "res://scenes/monsters/monster_mieum.tscn"
const NORMAL_IEUNG := "res://scenes/monsters/monster_ieung.tscn"
const BIG_MIEUM := "res://scenes/monsters/special/monster_big_mieum.tscn"
const FAST_IEUNG := "res://scenes/monsters/special/monster_fast_ieung.tscn"
const GOLDEN_HIEUT := "res://scenes/monsters/special/monster_golden_hieut.tscn"

## Pool draws sampled per gate case. Large enough that a 90% golden chance
## could not stay at zero by luck.
const POOL_SAMPLES := 2000
## Spawn draws recorded for the same-jamo repeat check. Doc v0.3 section 28.
const DIVERSITY_SAMPLES := 200
## Frames the FPS probe averages over. Doc v0.3 section 36.
const FPS_FRAMES := 240

var _main: Node
var _camera: Camera3D
var _monster_root: Node3D
var _spawn: SpawnManager
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = _main.get_node("World/GameWorld")
	_camera = world.get_node("CameraRig/ShakePivot/Camera3D")
	_monster_root = world.get_node("MonsterRoot")
	_spawn = world.get_node("SpawnManager")

	_report["pool_sizes"] = {
		"normal": _spawn.monster_scenes.size(),
		"special": _spawn.special_scenes.size(),
		"golden": _spawn.golden_scenes.size(),
	}

	await _measure_multipliers()
	await _measure_click_counts()
	await _measure_golden_gate()
	_measure_luck()
	await _measure_golden_lifetime()
	await _measure_diversity()
	await _measure_performance()
	await _measure_day_rollover()

	_write_report()
	get_tree().quit()


# --- 3. multipliers --------------------------------------------------------

## Reads the stats the game itself computed on a live instance of each scene,
## rather than re-deriving them from the .tres, so a multiplier that never
## reaches the monster would show up here.
func _measure_multipliers() -> void:
	_apply_state([], 1)
	var pairs := {
		"mieum": [NORMAL_MIEUM, BIG_MIEUM],
		"ieung": [NORMAL_IEUNG, FAST_IEUNG],
	}
	var out: Dictionary = {}
	for key: String in pairs:
		var normal := await _probe(pairs[key][0])
		var special := await _probe(pairs[key][1])
		out[key] = {
			"normal": normal,
			"special": special,
			"hp_ratio": special["max_hp"] / normal["max_hp"],
			"speed_ratio": special["speed"] / normal["speed"],
			"gold_ratio": special["gold"] / normal["gold"],
			"scale_ratio": special["visual_scale"] / normal["visual_scale"],
		}
	var golden := await _probe(GOLDEN_HIEUT)
	var baseline := await _probe(NORMAL_IEUNG)
	out["golden"] = {
		"golden": golden,
		"normal": baseline,
		"gold_ratio": golden["gold"] / baseline["gold"],
		"lifetime_seconds": golden["lifetime"],
		"normal_lifetime_seconds": baseline["lifetime"],
	}
	_report["multipliers"] = out


## Instantiates one monster, lets _ready run, and reads back what it derived.
func _probe(scene_path: String) -> Dictionary:
	var monster: JamoMonster = load(scene_path).instantiate()
	_monster_root.add_child(monster)
	monster.global_position = Vector3(0.0, 0.0, 0.0)
	await get_tree().process_frame
	var out := {
		"id": String(monster.monster_data.id),
		"jamo": monster.monster_data.jamo,
		"max_hp": monster.max_hp,
		"speed": monster._speed,
		"gold": monster._calculate_gold_reward(),
		"visual_scale": monster.monster_data.visual_scale,
		"click_radius": monster.monster_data.click_radius,
		"lifetime": monster.monster_data.lifetime_seconds,
		"special_type": monster.monster_data.special_type,
		"motion_profile": monster.monster_data.motion_profile.resource_path,
	}
	monster.queue_free()
	await get_tree().process_frame
	return out


# --- 3b. clicks to kill ----------------------------------------------------

## Plays the DEV handoff steps 12 and 13 for real: clicks each monster through
## the game's own input path until it dies, counting clicks and gold.
func _measure_click_counts() -> void:
	var out: Dictionary = {}
	for entry: Array in [
		["normal_mieum", NORMAL_MIEUM], ["big_mieum", BIG_MIEUM],
		["normal_ieung", NORMAL_IEUNG], ["fast_ieung", FAST_IEUNG],
	]:
		out[entry[0]] = await _click_to_death(entry[1])
	_report["click_counts"] = out


func _click_to_death(scene_path: String) -> Dictionary:
	_apply_state([], 1)
	# Keep the field from refilling: a monster spawned on top of the probe
	# would take the click ray and pollute the click and gold counts.
	_spawn.set_process(false)
	var monster: JamoMonster = load(scene_path).instantiate()
	_monster_root.add_child(monster)
	monster.global_position = Vector3.ZERO
	await get_tree().process_frame
	# The spawn animation keeps the click shape disabled for a few frames.
	for _frame in 60:
		await get_tree().process_frame

	var gold_before: float = GameState.gold
	var energy_before: int = GameState.energy
	var clicks := 0
	var misses := 0
	for _attempt in 200:
		if not monster.is_alive():
			break
		var energy_at: int = GameState.energy
		await _click(monster)
		if GameState.energy < energy_at:
			clicks += 1
		else:
			misses += 1
		await get_tree().process_frame

	var out := {
		"clicks": clicks,
		"missed_attempts": misses,
		"killed": not monster.is_alive(),
		"gold_gained": GameState.gold - gold_before,
		"energy_spent": energy_before - GameState.energy,
		"max_hp": monster.max_hp,
	}
	if is_instance_valid(monster):
		monster.queue_free()
	_spawn.set_process(true)
	await get_tree().process_frame
	return out


## Real input: warp the cursor onto the monster, feed a motion event so the
## viewport follows, then press and release the left button.
func _click(monster: JamoMonster) -> void:
	var screen: Vector2 = _camera.unproject_position(monster.get_hit_position())
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await get_tree().process_frame

	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)
		await get_tree().process_frame


# --- 2. golden gate --------------------------------------------------------

func _measure_golden_gate() -> void:
	var out: Dictionary = {}

	# 금 locked, golden chance pushed to 90%.
	_apply_state([], 1)
	GameState.balance.golden_spawn_chance = 0.9
	GameState.balance.special_spawn_chance = 0.0
	out["locked_golden_unlocked_flag"] = GameState.is_golden_monster_unlocked()
	out["locked_golden_chance"] = _spawn.get_golden_spawn_chance()
	out["locked_pool_draws"] = _sample_pools()
	out["locked_field"] = await _fill_and_count("gate_locked_field")

	# 금 completed.
	_apply_state([&"gold_001", &"gold_002"], 1)
	GameState.balance.golden_spawn_chance = 0.9
	GameState.balance.special_spawn_chance = 0.0
	out["unlocked_golden_unlocked_flag"] = GameState.is_golden_monster_unlocked()
	out["unlocked_golden_chance"] = _spawn.get_golden_spawn_chance()
	out["unlocked_pool_draws"] = _sample_pools()
	out["unlocked_field"] = await _fill_and_count("gate_unlocked_field")

	# Special pool on its own, so the big/fast pair can be seen on the field.
	_apply_state([], 1)
	GameState.balance.golden_spawn_chance = 0.0
	GameState.balance.special_spawn_chance = 0.9
	out["special_only_field"] = await _fill_and_count("special_field")

	_report["golden_gate"] = out


## Draws from _pick_pool without spawning anything, which is the branch the
## gate lives in. Counted by pool identity, not by monster.
func _sample_pools() -> Dictionary:
	var counts := {"normal": 0, "special": 0, "golden": 0}
	for _i in POOL_SAMPLES:
		var pool: Array[PackedScene] = _spawn._pick_pool()
		if pool == _spawn.golden_scenes:
			counts["golden"] += 1
		elif pool == _spawn.special_scenes:
			counts["special"] += 1
		else:
			counts["normal"] += 1
	return counts


func _fill_and_count(label: String) -> Dictionary:
	_spawn.clear_field()
	await _fill_field()
	var counts := {"normal": 0, "special": 0, "golden": 0}
	var ids: Array[String] = []
	for child in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster == null or monster.monster_data == null:
			continue
		ids.append(String(monster.monster_data.id))
		match monster.monster_data.special_type:
			JamoMonsterData.SpecialType.GOLDEN:
				counts["golden"] += 1
			JamoMonsterData.SpecialType.SPECIAL:
				counts["special"] += 1
			_:
				counts["normal"] += 1
	await _shot(label)
	return {"counts": counts, "ids": ids}


# --- 5. luck ---------------------------------------------------------------

func _measure_luck() -> void:
	GameState.balance.golden_spawn_chance = 0.02
	GameState.balance.special_spawn_chance = 0.02

	_apply_state([&"gold_001", &"gold_002"], 1)
	var before := {
		"multiplier": GameState.get_special_spawn_multiplier(),
		"golden_chance": _spawn.get_golden_spawn_chance(),
		"special_chance": _spawn.get_special_spawn_chance(),
	}
	_apply_state([&"gold_001", &"gold_002", &"luck_001"], 1)
	var after := {
		"multiplier": GameState.get_special_spawn_multiplier(),
		"golden_chance": _spawn.get_golden_spawn_chance(),
		"special_chance": _spawn.get_special_spawn_chance(),
	}
	_report["luck"] = {"without_un": before, "with_un": after}


# --- 4. golden dwell time --------------------------------------------------

## Watches one golden individual leave on its own and checks the payout, then
## kills a second one to compare. Doc v0.3 section 9.3.
func _measure_golden_lifetime() -> void:
	_apply_state([&"gold_001", &"gold_002"], 1)
	_spawn.clear_field()
	await get_tree().process_frame

	var golden: JamoMonster = load(GOLDEN_HIEUT).instantiate()
	_monster_root.add_child(golden)
	golden.global_position = Vector3.ZERO
	await get_tree().process_frame

	var gold_before: float = GameState.gold
	var kills_before: int = GameState.kills_today
	var started := Time.get_ticks_msec()
	var expired := false
	for _frame in 900:
		await get_tree().process_frame
		if not golden.is_alive():
			expired = true
			break
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0

	_report["golden_lifetime"] = {
		"declared_lifetime": golden.monster_data.lifetime_seconds,
		"expired_on_its_own": expired,
		"observed_seconds": elapsed,
		"gold_before": gold_before,
		"gold_after": GameState.gold,
		"kills_before": kills_before,
		"kills_after": GameState.kills_today,
	}
	if is_instance_valid(golden):
		golden.queue_free()
	await get_tree().process_frame

	# Same monster, killed instead of left alone.
	var killed: JamoMonster = load(GOLDEN_HIEUT).instantiate()
	_monster_root.add_child(killed)
	killed.global_position = Vector3.ZERO
	await get_tree().process_frame
	var before_kill: float = GameState.gold
	killed.take_click_damage(9999.0)
	await get_tree().process_frame
	_report["golden_kill_payout"] = {
		"gold_gained": GameState.gold - before_kill,
		"normal_gold_for_day": GameState.balance.monster_gold_for_day(GameState.day),
	}
	if is_instance_valid(killed):
		killed.queue_free()
	await get_tree().process_frame


# --- 10. spawn diversity ---------------------------------------------------

## Records the order the normal pool actually produces and reports the longest
## run of one jamo. Doc v0.3 section 28 asks for a repeat penalty, not a ban.
func _measure_diversity() -> void:
	_apply_state([], 1)
	GameState.balance.golden_spawn_chance = 0.0
	GameState.balance.special_spawn_chance = 0.0
	var sequence: Array[String] = []
	for _i in DIVERSITY_SAMPLES:
		_spawn._spawn_one()
		sequence.append(String(_spawn._last_spawned_id))
		_spawn.clear_field()
	await get_tree().process_frame

	var longest := 1
	var current := 1
	var immediate_repeats := 0
	for i in range(1, sequence.size()):
		if sequence[i] == sequence[i - 1]:
			current += 1
			immediate_repeats += 1
			longest = maxi(longest, current)
		else:
			current = 1
	var histogram: Dictionary = {}
	for id: String in sequence:
		histogram[id] = int(histogram.get(id, 0)) + 1
	_report["diversity"] = {
		"samples": sequence.size(),
		"longest_same_jamo_run": longest,
		"immediate_repeat_rate": float(immediate_repeats) / float(sequence.size() - 1),
		"histogram": histogram,
	}


# --- 9. performance --------------------------------------------------------

func _measure_performance() -> void:
	_apply_state([&"gold_001", &"gold_002"], 1)
	GameState.upgrade_levels[GameState.UPGRADE_MONSTER_CAPACITY] = 12
	GameState.balance.special_spawn_chance = 0.35
	GameState.balance.golden_spawn_chance = 0.2
	_spawn.clear_field()
	await _fill_field()

	var frames := 0
	var worst := 9999.0
	var total := 0.0
	for _frame in FPS_FRAMES:
		await get_tree().process_frame
		var fps: float = Engine.get_frames_per_second()
		if fps <= 0.0:
			continue
		frames += 1
		total += fps
		worst = minf(worst, fps)
	await _shot("perf_20_monsters")

	var counts := {"normal": 0, "special": 0, "golden": 0}
	for child in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster == null or monster.monster_data == null:
			continue
		match monster.monster_data.special_type:
			JamoMonsterData.SpecialType.GOLDEN:
				counts["golden"] += 1
			JamoMonsterData.SpecialType.SPECIAL:
				counts["special"] += 1
			_:
				counts["normal"] += 1

	_report["performance"] = {
		"capacity": GameState.get_monster_capacity(),
		"monsters_on_field": _monster_root.get_child_count(),
		"mix": counts,
		"average_fps": total / maxf(1.0, float(frames)),
		"worst_fps": worst,
		"sampled_frames": frames,
	}
	GameState.upgrade_levels.erase(GameState.UPGRADE_MONSTER_CAPACITY)


# --- 11. day rollover ------------------------------------------------------

## A golden left on the field when the day turns must not pay out.
func _measure_day_rollover() -> void:
	_apply_state([&"gold_001", &"gold_002"], 1)
	_spawn.clear_field()
	var golden: JamoMonster = load(GOLDEN_HIEUT).instantiate()
	_monster_root.add_child(golden)
	golden.global_position = Vector3.ZERO
	await get_tree().process_frame

	var gold_before: float = GameState.gold
	GameState.advance_day()
	GameState.begin_day()
	_spawn.clear_field()
	await _fill_field()
	await _shot("day2_field")

	_report["day_rollover"] = {
		"day": GameState.day,
		"gold_before": gold_before,
		"gold_after": GameState.gold,
		"energy": GameState.energy,
		"max_energy": GameState.get_max_energy(),
		"monsters_after_rollover": _monster_root.get_child_count(),
	}


# --- shared ----------------------------------------------------------------

func _apply_state(word_ids: Array, day: int) -> void:
	GameState.unlocked_word_ids.clear()
	for id: StringName in word_ids:
		GameState.unlocked_word_ids.append(id)
	GameState.jamo_inventory.clear()
	GameState.day = day
	GameState._recalculate_word_bonuses()
	GameState.begin_day()
	_spawn.clear_field()


func _fill_field() -> void:
	for _frame in 900:
		await get_tree().process_frame
		if _monster_root.get_child_count() >= GameState.get_monster_capacity():
			return


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/play_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f4_observations.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f4_special: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	print(JSON.stringify(_report, "\t"))
	print("OK - F4 artifacts written to %s" % ARTIFACT_DIR)
