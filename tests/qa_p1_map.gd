extends Node

## QA P1 map: the character jamo and the redesigned field in the real run
## scene. WINDOW MODE ONLY - it screenshots and measures frame rate.
##
## Run: godot --path . res://tests/qa_p1_map.tscn
##
## What it checks:
##   1. every normal jamo scene (15) and the three specials carry the character
##      model (Glyph / Eye_L / Eye_R / Leg_L / Leg_R) under VisualRoot/Body/Lean
##      and no BoxMesh stand-in; the specials differ by scale / material
##   2. one monster per walk profile actually swings its legs while in WALK,
##      left and right in opposite phase (or both tucked, for the bounce)
##   3. the 문장핵 model sits inside the paper sheet with margin on every side;
##      spawn markers surround it from several directions
##   4. the HUD core readout at run start is the real max HP, no test residue
##   5. Wave 1~5 played with real clicks: spawns come from several sectors,
##      no glyph ever hangs over the paper, screenshots per wave
##   6. 20 monsters on the field at 60 FPS

const RUN_SCENE := "res://scenes/main/main.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p1/map"
const TARGET_WAVE := 5
const WAVE_FRAME_BUDGET := 4000
const FPS_FIELD := 20
const FPS_SAMPLE_FRAMES := 300
const MISS_BUDGET := 40
const PLAY_TIME_SCALE := 3.0
## Paper margin the 문장핵 must keep on every side, in metres.
const CORE_PAPER_MARGIN := 0.3
## Body overhang past the paper edge that counts as "off the sheet", in metres.
const OVERHANG_TOLERANCE := 0.02
## Leg swing range a walking monster must show, in radians, over one sample.
const MIN_LEG_RANGE := 0.25
const PARTS := ["Glyph", "Eye_L", "Eye_R", "Leg_L", "Leg_R"]
const NORMAL_SCENES := [
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_nieun.tscn",
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_rieul.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_bieup.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_hieut.tscn",
	"res://scenes/monsters/monster_eo.tscn",
	"res://scenes/monsters/monster_yeo.tscn",
	"res://scenes/monsters/monster_o.tscn",
	"res://scenes/monsters/monster_u.tscn",
	"res://scenes/monsters/monster_eu.tscn",
	"res://scenes/monsters/monster_i.tscn",
]
const SPECIAL_SCENES := [
	"res://scenes/monsters/special/monster_big_mieum.tscn",
	"res://scenes/monsters/special/monster_fast_ieung.tscn",
	"res://scenes/monsters/special/monster_golden_hieut.tscn",
]
## One scene per walk profile, for the leg check.
const GAIT_SCENES := [
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_eu.tscn",
	"res://scenes/monsters/monster_i.tscn",
]

var _failures: int = 0
var _wave_log: Array[Dictionary] = []
var _cleared: Array[int] = []
var _core_hit_pending: bool = false
var _spawner: SpawnManager
var _monster_root: Node3D
var _core: SentenceCore
var _paper_half: Vector2 = Vector2.ZERO
var _worst_overhang: float = 0.0
var _worst_overhang_id: String = ""
var _seen: Dictionary = {}
var _spawn_sectors: Dictionary = {}
var _spawn_count: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	SignalBus.core_hp_changed.connect(func(_c: float, _m: float) -> void: _core_hit_pending = true)
	await _run()
	Engine.time_scale = 1.0
	_print_table()
	if _failures == 0:
		print("OK - character jamo walk in from all sides of the wide sheet and Wave 1~%d play through." % TARGET_WAVE)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _run() -> void:
	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var world: Node3D = main.get_node("World/GameWorld")
	_spawner = world.get_node("SpawnManager")
	_monster_root = world.get_node("MonsterRoot")
	_core = world.get_node("SentenceCore")
	var core: SentenceCore = _core
	var arena: Node3D = world.get_node("Arena")
	# Wave 1 starts with the scene; the lineup and gait checks want an empty
	# field first, so spawning is held until the real play below.
	_spawner.stop()
	_spawner.clear_field()
	var paper := arena.get_node("PaperTop") as MeshInstance3D
	var box := paper.mesh as BoxMesh
	_paper_half = Vector2(box.size.x, box.size.z) * 0.5
	print("-- field: paper half extents %s, spawner %s" % [str(_paper_half), str(_spawner.arena_half_extents)])
	_check(_paper_half.is_equal_approx(_spawner.arena_half_extents),
		"SpawnManager.arena_half_extents matches the PaperTop mesh")
	await _settle()
	await _shoot("00_arena_empty")

	_check_core_seat(core)
	_check_spawn_points(core)
	_check_hud(main.get_node("UI/HUD"))
	await _check_lineup()
	await _check_gaits()

	Engine.time_scale = PLAY_TIME_SCALE
	for _pass in TARGET_WAVE + 3:
		if not RunState.is_active:
			break
		await _play_one_wave()
	Engine.time_scale = 1.0
	_check(_reached_wave() >= TARGET_WAVE,
		"Wave %d was reached by playing, got %d" % [TARGET_WAVE, _reached_wave()])
	for wave in range(1, TARGET_WAVE):
		_check(_cleared.has(wave), "Wave %d cleared on its own, cleared %s" % [wave, str(_cleared)])
	_check(not RunState.is_active, "the run ended inside the budget (the core is the only failure)")
	print("-- spawn sectors used over the run: %s of %d spawns" % [str(_spawn_sectors.keys()), _spawn_count])
	_check(_spawn_sectors.size() >= 4,
		"spawns came from at least 4 sectors around the core, got %d" % _spawn_sectors.size())
	print("-- worst body overhang past the paper edge during play: %.3f m (%s)"
		% [_worst_overhang, _worst_overhang_id])
	_check(_worst_overhang <= OVERHANG_TOLERANCE, "no glyph hung over the paper edge during play")

	var result: Control = main.get_node("UI/RunResult")
	var waited := 0
	while not result.visible and waited < 2000:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the result screen appeared after the core fell")
	result.visible = false
	await _measure_frame_rate()


## 3a. The 문장핵 model inside the sheet with margin on every side, never on
## an edge or corner. Doc v0.4 section 6.1.
func _check_core_seat(core: SentenceCore) -> void:
	print("-- 문장핵 seat")
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in core.visual_root.find_children("*", "MeshInstance3D", true, false):
		var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
	var margin_x: float = _paper_half.x - maxf(absf(bounds.position.x), absf(bounds.end.x))
	var margin_z: float = _paper_half.y - maxf(absf(bounds.position.z), absf(bounds.end.z))
	print("    model bounds pos=%s size=%s, paper margin x %.2f z %.2f"
		% [str(bounds.position), str(bounds.size), margin_x, margin_z])
	_check(margin_x >= CORE_PAPER_MARGIN and margin_z >= CORE_PAPER_MARGIN,
		"the 문장핵 keeps at least %.1f m of paper on every side" % CORE_PAPER_MARGIN)
	_check(core.global_position.z < 0.0, "the 문장핵 stands in the rear half of the sheet")


## 3b. Spawn markers: several, on the sheet, and spread around the core so a
## wave does not arrive in one file. Doc v0.4 section 39.
func _check_spawn_points(core: SentenceCore) -> void:
	print("-- spawn points")
	var root: Node3D = _spawner.spawn_point_root
	var markers: Array[Node] = root.get_children()
	var sectors: Dictionary = {}
	var min_angle := INF
	var max_angle := -INF
	for marker: Node3D in markers:
		var offset: Vector3 = marker.global_position - core.global_position
		var angle: float = rad_to_deg(atan2(offset.x, offset.z))
		min_angle = minf(min_angle, angle)
		max_angle = maxf(max_angle, angle)
		sectors[_sector_of(marker.global_position, core.global_position)] = true
		print("    %s at %s, %.0f deg from the core, %.2f m away"
			% [marker.name, str(marker.global_position), angle, offset.length()])
		_check(JamoMonster.arena_spill(marker.global_position, _paper_half) <= 1.0,
			"spawn point %s is on the sheet" % marker.name)
	_check(markers.size() >= 6, "at least 6 spawn markers, got %d" % markers.size())
	_check(max_angle - min_angle >= 150.0,
		"spawn markers fan out over at least 150 degrees around the core, got %.0f" % (max_angle - min_angle))
	_check(sectors.size() >= 4, "spawn markers cover at least 4 sectors, got %d" % sectors.size())


## Which side of the core a point is on: left / centre / right x front / rear.
func _sector_of(point: Vector3, core: Vector3) -> String:
	var dx: float = point.x - core.x
	var side := "centre"
	if dx < -1.5:
		side = "left"
	elif dx > 1.5:
		side = "right"
	var depth := "front" if point.z - core.z > 2.0 else "beside"
	return "%s-%s" % [side, depth]


## 4. The HUD core readout is the real run value: no pinned 999999 residue.
func _check_hud(hud: Control) -> void:
	var label: Label = hud.get_node("%CoreLabel")
	var expected := "문장핵 %d / %d" % [int(ceilf(RunState.core_hp)), int(ceilf(RunState.core_max_hp))]
	print("-- HUD core readout: %s" % label.text)
	_check(label.text == expected, "the HUD shows the RunState core HP, expected %s" % expected)
	_check(RunState.core_hp == RunState.core_max_hp
		and RunState.core_max_hp == MetaState.get_core_max_hp(),
		"core HP at run start is the MetaState max (%.0f)" % MetaState.get_core_max_hp())


## 1. Every scene carries the character model, and nothing else. Standing in
## two rows for one lineup shot.
func _check_lineup() -> void:
	print("-- lineup: 15 normal + 3 special scenes")
	_spawner.stop()
	var placed: Array[JamoMonster] = []
	var paths: Array = NORMAL_SCENES + SPECIAL_SCENES
	for index in paths.size():
		var monster: JamoMonster = _place(paths[index], Vector3(
			-5.0 + 1.25 * (index % 9), 0.0, 2.6 if index < 9 else 0.4
		))
		if monster == null:
			continue
		placed.append(monster)
		var id: String = String(monster.monster_data.id)
		var model: Node = monster.get_node_or_null("VisualRoot/Body/Lean/Model")
		_check(model != null, "%s: the model is instanced at VisualRoot/Body/Lean/Model" % id)
		for part: String in PARTS:
			_check(monster.get_node("VisualRoot").find_child(part, true, false) is MeshInstance3D,
				"%s: part %s is a MeshInstance3D" % [id, part])
		var boxes := 0
		var triangles := 0
		for mesh: MeshInstance3D in monster.get_node("VisualRoot").find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh is BoxMesh:
				boxes += 1
			elif mesh.mesh != null:
				triangles += _triangle_count(mesh.mesh)
		_check(boxes == 0, "%s: no BoxMesh stand-in strokes remain, found %d" % [id, boxes])
		print("    %s: %d triangles, visual_scale %.2f" % [id, triangles, monster.monster_data.visual_scale])
	await _settle()
	for _i in 30:
		await get_tree().process_frame
	await _shoot("01_lineup_15_plus_specials")

	var by_id: Dictionary = {}
	for monster: JamoMonster in placed:
		by_id[String(monster.monster_data.id)] = monster
	var big: JamoMonster = by_id.get("big_mieum")
	var plain: JamoMonster = by_id.get("mieum")
	if big != null and plain != null:
		_check(big.get_node("VisualRoot").scale.x > plain.get_node("VisualRoot").scale.x * 1.3,
			"큰 ㅁ is drawn at least 1.3x the plain ㅁ (%.2f vs %.2f)"
			% [big.get_node("VisualRoot").scale.x, plain.get_node("VisualRoot").scale.x])
	_check_glyph_override(by_id.get("fast_ieung"), "jamo_special_fast")
	_check_glyph_override(by_id.get("golden_hieut"), "jamo_gold")
	_check_glyph_override(by_id.get("ieung"), "")
	for monster: JamoMonster in placed:
		monster.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## Surface 0 of the Glyph wears the named material, or none; surface 1 (the
## paper edge) and the eyes are never overridden. Doc v0.4 section 16.
func _check_glyph_override(monster: JamoMonster, material_name: String) -> void:
	if monster == null:
		_check(false, "special %s was placed" % material_name)
		return
	var id: String = String(monster.monster_data.id)
	var glyph := monster.get_node("VisualRoot").find_child("Glyph", true, false) as MeshInstance3D
	var override: Material = glyph.get_surface_override_material(0)
	if material_name.is_empty():
		_check(override == null, "%s: the plain glyph wears no override" % id)
		return
	_check(override != null and override.resource_path.ends_with("%s.tres" % material_name),
		"%s: Glyph surface 0 wears %s, got %s" % [id, material_name, str(override)])
	_check(glyph.get_surface_override_material(1) == null, "%s: the paper edge (surface 1) is untouched" % id)
	var eye := monster.get_node("VisualRoot").find_child("Eye_L", true, false) as MeshInstance3D
	_check(eye.get_surface_override_material(0) == null and eye.material_override == null,
		"%s: the eyes keep their own ink" % id)


## 2. Legs swing while walking, one monster per profile, opposite phase.
func _check_gaits() -> void:
	print("-- legs while walking")
	var subjects: Array[JamoMonster] = []
	for index in GAIT_SCENES.size():
		var monster: JamoMonster = _place(GAIT_SCENES[index], Vector3(-4.5 + 1.5 * index, 0.0, 3.2))
		if monster != null:
			monster.objective = _core
			subjects.append(monster)
	var frames := 0
	while frames < 600:
		await get_tree().process_frame
		frames += 1
		var walking := 0
		for monster: JamoMonster in subjects:
			if monster.get_state() == JamoMonster.State.WALK:
				walking += 1
		if walking == subjects.size():
			break
	await _shoot("02_gaits_walking")
	# All subjects are sampled in the same frames: the light-footed ones reach
	# the 문장핵 in a few seconds, so one after another would miss them.
	var stats: Dictionary = {}
	for monster: JamoMonster in subjects:
		stats[monster] = {"lo": INF, "hi": -INF, "matches": 0, "frames": 0}
	for _i in 60:
		await get_tree().process_frame
		for monster: JamoMonster in subjects:
			if not is_instance_valid(monster) or monster.get_state() != JamoMonster.State.WALK:
				continue
			var left := monster.get_node("VisualRoot").find_child("Leg_L", true, false) as Node3D
			var right := monster.get_node("VisualRoot").find_child("Leg_R", true, false) as Node3D
			var entry: Dictionary = stats[monster]
			entry["frames"] += 1
			entry["lo"] = minf(entry["lo"], left.rotation.x)
			entry["hi"] = maxf(entry["hi"], left.rotation.x)
			var swing: float = monster.leg_swing
			var tuck: float = monster.leg_tuck
			if is_equal_approx(left.rotation.x, tuck + swing) \
					and is_equal_approx(right.rotation.x, tuck - swing):
				entry["matches"] += 1
	for monster: JamoMonster in subjects:
		var entry: Dictionary = stats[monster]
		var id: String = String(monster.monster_data.id)
		var profile: String = String(monster.monster_data.motion_profile.profile_name)
		var range_seen: float = entry["hi"] - entry["lo"]
		print("    %s (%s): Leg_L range %.2f rad over %d walk frames, pose matches %d"
			% [id, profile, range_seen, entry["frames"], entry["matches"]])
		_check(entry["frames"] > 0, "%s walked during the leg sample" % id)
		_check(range_seen >= MIN_LEG_RANGE, "%s (%s): legs swing at least %.2f rad, got %.2f"
			% [id, profile, MIN_LEG_RANGE, range_seen])
		_check(entry["matches"] == entry["frames"],
			"%s: Leg_L / Leg_R follow leg_swing and leg_tuck every frame" % id)
	for monster: JamoMonster in subjects:
		if is_instance_valid(monster):
			monster.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Everything placed by hand is gone; the real Wave 1 starts on a fresh run.
	RunState.start_run()
	await _settle()


## 5. Plays the current wave: every point of energy on real clicks, then
## watches the rest resolve with no input. Screenshots at the start, once the
## field is busy, and on the first core hit.
func _play_one_wave() -> void:
	var wave: int = RunState.current_wave
	var core_before: float = RunState.core_hp
	var kills_before: float = RunState.get_run_statistic("kills")
	var clicks := 0
	var frames := 0
	var misses := 0
	var hit_shot_taken := false
	var mid_shot_taken := false
	var full_field: int = MetaState.database.find_wave(wave).max_alive
	_core_hit_pending = false
	await _settle()
	await _shoot("%02d_wave%d_start" % [wave * 10, wave])
	while RunState.is_active and RunState.current_wave == wave \
			and RunState.current_energy > 0 and frames < WAVE_FRAME_BUDGET \
			and misses < MISS_BUDGET:
		_watch_field()
		if not mid_shot_taken and _spawner.alive_count() >= full_field:
			mid_shot_taken = true
			await _shoot("%02d_wave%d_incoming" % [wave * 10 + 2, wave])
		var monster: JamoMonster = _closest_alive_to_core(_core)
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
	while RunState.is_active and RunState.current_wave == wave and frames < WAVE_FRAME_BUDGET:
		_watch_field()
		if not mid_shot_taken and _spawner.alive_count() >= full_field:
			mid_shot_taken = true
			await _shoot("%02d_wave%d_incoming" % [wave * 10 + 2, wave])
		if _core_hit_pending and not hit_shot_taken:
			hit_shot_taken = true
			await _shoot("%02d_wave%d_core_hit" % [wave * 10 + 5, wave])
		await get_tree().process_frame
		frames += 1
	_wave_log.append({
		"wave": wave,
		"clicks": clicks,
		"kills": int(RunState.get_run_statistic("kills") - kills_before),
		"core_lost": core_before - RunState.core_hp,
		"core_left": RunState.core_hp,
		"cleared": _cleared.has(wave),
	})


## Records where each new monster first appeared and the worst body overhang
## past the paper edge seen so far.
func _watch_field() -> void:
	var core: Vector3 = _core.global_position
	for node: Node in _monster_root.get_children():
		var monster := node as JamoMonster
		if monster == null or not monster.is_alive():
			continue
		var key: int = monster.get_instance_id()
		if not _seen.has(key):
			_seen[key] = true
			_spawn_count += 1
			_spawn_sectors[_sector_of(monster.global_position, core)] = true
		var overhang: float = _body_overhang(monster)
		if overhang > _worst_overhang:
			_worst_overhang = overhang
			_worst_overhang_id = String(monster.monster_data.id)


## How far the monster's meshes stick out past the paper rectangle, in metres.
func _body_overhang(monster: JamoMonster) -> float:
	var worst := 0.0
	for mesh: MeshInstance3D in monster.get_node("VisualRoot").find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		for corner_index in 8:
			var corner: Vector3 = box.get_endpoint(corner_index)
			worst = maxf(worst, maxf(absf(corner.x) - _paper_half.x, absf(corner.z) - _paper_half.y))
	return worst


## One real click, delivered where the monster is drawn on screen.
func _click_monster(monster: JamoMonster) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_check(false, "the arena has no current Camera3D to click through")
		return false
	var before: int = RunState.current_energy
	var point: Vector2 = camera.unproject_position(monster.global_position)
	_warp_to(point)
	await get_tree().process_frame
	_click_at(point)
	await get_tree().process_frame
	await get_tree().process_frame
	return RunState.current_energy < before


## 6. Frame rate with a full field of character models. Doc v0.4 section 36
## asks for 20 monsters at 60 FPS.
func _measure_frame_rate() -> void:
	print("-- frame rate on a full field of character jamo")
	Engine.time_scale = 1.0
	RunState.start_run()
	await get_tree().process_frame
	_spawner.objective = null
	var wave := WaveData.new()
	wave.wave_number = 1
	for path: String in NORMAL_SCENES:
		wave.enemy_pool.append(load(path))
	wave.enemy_count = 500
	wave.max_alive = FPS_FIELD
	wave.spawn_interval = 0.05
	wave.hp_multiplier = 60.0
	_spawner.configure_wave(wave)
	var frames := 0
	while _spawner.alive_count() < FPS_FIELD and frames < WAVE_FRAME_BUDGET:
		await get_tree().process_frame
		frames += 1
	_check(_spawner.alive_count() >= FPS_FIELD,
		"the field filled to %d monsters, got %d" % [FPS_FIELD, _spawner.alive_count()])
	for _i in 60:
		await get_tree().process_frame
	var samples: Array[float] = []
	var outside := 0
	for _i in FPS_SAMPLE_FRAMES:
		await get_tree().process_frame
		samples.append(Engine.get_frames_per_second())
		_watch_field()
	samples.sort()
	var total := 0.0
	for value: float in samples:
		total += value
	var average: float = total / samples.size()
	var low_index: int = maxi(0, int(samples.size() * 0.01))
	await _shoot("95_full_field_%d" % _spawner.alive_count())
	print("    %d alive: avg %.1f FPS, min %.1f, low 1 pct %.1f"
		% [_spawner.alive_count(), average, samples[0], samples[low_index]])
	_check(average >= 60.0,
		"20 character jamo hold 60 FPS (doc v0.4 section 36), average was %.1f" % average)
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster == null or not monster.is_inside_tree():
			continue
		if JamoMonster.arena_spill(monster.global_position, monster.get_walkable_half_extents()) > 1.02:
			outside += 1
	_check(outside == 0, "no monster escaped its walkable rectangle on a full field, %d did" % outside)
	print("    worst body overhang on the full field: %.3f m" % _worst_overhang)
	_check(_worst_overhang <= OVERHANG_TOLERANCE, "no glyph hung over the paper on the full field")
	_spawner.stop()
	_spawner.clear_field()


# --- plumbing ---------------------------------------------------------------

## Instances one monster scene by hand at `position`, wired like the spawner
## does but without an objective, so it stands where it is put.
func _place(path: String, position: Vector3) -> JamoMonster:
	var packed: PackedScene = load(path) as PackedScene
	var monster := packed.instantiate() as JamoMonster
	if monster == null:
		_check(false, "%s is a JamoMonster scene" % path)
		return null
	monster.arena_half_extents = _spawner.arena_half_extents
	_monster_root.add_child(monster)
	monster.global_position = position
	return monster


static func _triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		else:
			total += indices.size() / 3
	return total


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
	print("    wave | clicks | kills | core lost | core left | cleared")
	for entry: Dictionary in _wave_log:
		print("    %4d | %6d | %5d | %9.0f | %9.0f | %s" % [
			entry["wave"], entry["clicks"], entry["kills"],
			entry["core_lost"], entry["core_left"], str(entry["cleared"]),
		])


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
