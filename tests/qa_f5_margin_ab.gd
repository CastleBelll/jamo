extends Node

## QA A/B for F5 / S0-2. Fills the field with 큰 ㅁ twice - once with the
## margin forced to 0, which is how the build behaved before F5, and once with
## the shipped arena_margin - and prints the worst body overhang for each, so
## the effect of the new margin can be read as a number rather than guessed at.
##
## The margin is only overwritten on the in-memory JamoMonsterData of the live
## monsters; no .tres on disk is touched.
##
##   godot --path . tests/qa_f5_margin_ab.tscn

const MAIN_SCENE := "res://scenes/main/main.tscn"
const BIG_MIEUM := "res://scenes/monsters/special/monster_big_mieum.tscn"
## Half-extents (x, z) of the paper in the sheet's own frame, read from the
## PaperTop BoxMesh in arena.tscn so a resized sheet is measured as built.
var _slab_half: Vector2 = Vector2.ZERO
const FILL_FRAMES := 900
const OBSERVE_FRAMES := 1500

var _monster_root: Node3D
var _spawn: SpawnManager
## World space -> the rotated slab's own frame.
var _to_slab: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	var main: Node = load(MAIN_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = main.get_node("World/GameWorld")
	_monster_root = world.get_node("MonsterRoot")
	_spawn = world.get_node("SpawnManager")
	var arena: Node3D = world.get_node("Arena")
	_to_slab = arena.global_transform.affine_inverse()
	var paper := arena.get_node("PaperTop") as MeshInstance3D
	var box := paper.mesh as BoxMesh
	_slab_half = Vector2(box.size.x, box.size.z) * 0.5
	_spawn.monster_scenes = [load(BIG_MIEUM)]
	_spawn.special_scenes = []
	_spawn.golden_scenes = []

	for margin: float in [0.0, 0.55]:
		await _measure(margin)
	get_tree().quit()


func _measure(margin: float) -> void:
	_spawn.clear_field()
	MetaState.permanent_upgrade_levels[MetaState.UPGRADE_MONSTER_CAPACITY] = 20
	RunState.start_run()
	_free_roam(_spawn.monster_scenes)
	for _frame in FILL_FRAMES:
		await get_tree().process_frame
		_force_margin(margin)
		if _monster_root.get_child_count() >= MetaState.get_monster_capacity():
			break

	var worst := 0.0
	var worst_centre := 0.0
	var over_samples := 0
	var samples := 0
	for _frame in OBSERVE_FRAMES:
		await get_tree().process_frame
		_force_margin(margin)
		for monster: JamoMonster in _live():
			samples += 1
			var overhang := _overhang(monster)
			if overhang > 0.001:
				over_samples += 1
			worst = maxf(worst, overhang)
			worst_centre = maxf(
				worst_centre,
				maxf(absf(monster.global_position.x), absf(monster.global_position.z))
			)
	print(
		"margin=%.2f worst_overhang=%.3f worst_centre=%.3f over_ratio=%.3f"
		% [margin, worst, worst_centre, float(over_samples) / maxf(1.0, float(samples))]
	)


func _force_margin(margin: float) -> void:
	for monster: JamoMonster in _live():
		if monster.monster_data != null:
			monster.monster_data.arena_margin = margin


## Measured in the sheet's own frame; see _slab_half.
func _overhang(monster: JamoMonster) -> float:
	var box := _world_aabb(monster)
	if box.size == Vector3.ZERO:
		return 0.0
	var worst := 0.0
	for corner_index in 8:
		var corner: Vector3 = _to_slab * box.get_endpoint(corner_index)
		worst = maxf(worst, maxf(
			absf(corner.x) - _slab_half.x, absf(corner.z) - _slab_half.y
		))
	return maxf(0.0, worst)


func _world_aabb(root: Node) -> AABB:
	var result := AABB()
	var seeded := false
	for node: Node in _walk(root):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.visible:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if not seeded:
			result = box
			seeded = true
		else:
			result = result.merge(box)
	return result


func _walk(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_walk(child))
	return found


func _live() -> Array[JamoMonster]:
	var alive: Array[JamoMonster] = []
	for child: Node in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster != null and monster.is_alive():
			alive.append(monster)
	return alive


## Phase 1 moved spawning onto WaveData and pointed every monster at the
## 문장핵. This harness measures the roaming clamp, so the monsters are left
## without an objective and the spawner is handed an endless wave from the
## harness pool after each start_run() (the WaveController reconfigures it on
## every wave_started). The fill target stays MetaState.get_monster_capacity().
func _free_roam(pool: Array) -> void:
	_spawn.objective = null
	var wave := WaveData.new()
	wave.wave_number = 1
	for scene: PackedScene in pool:
		wave.enemy_pool.append(scene)
	wave.enemy_count = 500
	wave.max_alive = MetaState.get_monster_capacity()
	wave.spawn_interval = 0.25
	_spawn.configure_wave(wave)
