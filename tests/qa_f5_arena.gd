extends Node

## QA harness for F5 / S0-2: a crowded field of 큰 ㅁ must not hang over the
## paper slab, and the ordinary jamo must not lose their roaming range doing it.
##
## Not a pass/fail test: it runs the real main.tscn, fills the field from a
## chosen pool, watches it and writes the worst overhang it saw as an
## observation artifact for a human to read.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f5_arena.tscn

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f5"
const BIG_MIEUM := "res://scenes/monsters/special/monster_big_mieum.tscn"
const NORMAL_SCENES := [
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_i.tscn",
]

## Half-extent of the paper in the slab's own frame (PaperTop is a 5.6 x 5.6
## box). arena.tscn turns the slab 45 degrees, so overhang has to be measured
## in that frame, not against a world-axis-aligned square.
const SLAB_HALF := 2.8
## How long to watch a crowded field, in frames at 60 fps.
const OBSERVE_FRAMES := 2100
## Frames given to the spawner to fill the field before observing.
const FILL_FRAMES := 900

var _main: Node
var _monster_root: Node3D
var _spawn: SpawnManager
## World space -> the rotated slab's own frame.
var _to_slab: Transform3D = Transform3D.IDENTITY
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = _main.get_node("World/GameWorld")
	_monster_root = world.get_node("MonsterRoot")
	_spawn = world.get_node("SpawnManager")
	var arena: Node3D = world.get_node("Arena")
	_to_slab = arena.global_transform.affine_inverse()

	_report["slab_half_extent"] = SLAB_HALF
	_report["slab_rotation_y_rad"] = arena.global_rotation.y
	_report["spawn_arena_half_extents"] = [
		_spawn.arena_half_extents.x, _spawn.arena_half_extents.y
	]

	_report["big_mieum"] = await _observe("big_mieum", [BIG_MIEUM])
	_report["normal_jamo"] = await _observe("normal_jamo", NORMAL_SCENES)
	_report["mixed"] = await _observe("mixed", NORMAL_SCENES + [BIG_MIEUM])
	_report["worst_case_corner"] = await _worst_case_corner()

	_write_report()
	get_tree().quit()


## Fills the field from `scene_paths` only, watches it, and returns the worst
## overhang plus how far the crowd actually spread.
func _observe(label: String, scene_paths: Array) -> Dictionary:
	var pool: Array[PackedScene] = []
	for path: String in scene_paths:
		pool.append(load(path))
	_spawn.clear_field()
	_spawn.monster_scenes = pool
	_spawn.special_scenes = []
	_spawn.golden_scenes = []
	GameState.upgrade_levels[GameState.UPGRADE_MONSTER_CAPACITY] = 20
	GameState.jamo_inventory.clear()
	GameState.begin_day()

	for _frame in FILL_FRAMES:
		await get_tree().process_frame
		if _monster_root.get_child_count() >= GameState.get_monster_capacity():
			break

	var worst_body := 0.0
	var worst_centre := 0.0
	var reach := 0.0
	var peak_count := 0
	var offenders: Dictionary = {}
	for frame in OBSERVE_FRAMES:
		await get_tree().process_frame
		peak_count = maxi(peak_count, _live_count())
		for monster: JamoMonster in _live_monsters():
			var body := _body_overhang(monster)
			if body > worst_body:
				worst_body = body
			if body > 0.001:
				var id: String = _monster_id(monster)
				offenders[id] = maxf(float(offenders.get(id, 0.0)), body)
			var centre: float = maxf(
				absf(monster.global_position.x), absf(monster.global_position.z)
			)
			worst_centre = maxf(worst_centre, centre)
			reach = maxf(reach, monster.global_position.length())
		if frame % 700 == 0:
			await _shot("%s_%d" % [label, frame])
	await _shot("%s_final" % label)

	return {
		"peak_monster_count": peak_count,
		"worst_body_overhang_m": worst_body,
		"worst_centre_axis_m": worst_centre,
		"furthest_centre_from_origin_m": reach,
		"offenders": offenders,
	}


## Puts a single 큰 ㅁ on the +X vertex of its own walkable diamond - the
## furthest the clamp allows it to stand - and photographs it against the slab
## edge, so the worst case is a picture rather than an average.
func _worst_case_corner() -> Dictionary:
	_spawn.clear_field()
	_spawn.monster_scenes = [load(BIG_MIEUM)]
	_spawn.special_scenes = []
	_spawn.golden_scenes = []
	GameState.upgrade_levels[GameState.UPGRADE_MONSTER_CAPACITY] = 1
	GameState.begin_day()
	for _frame in FILL_FRAMES:
		await get_tree().process_frame
		if _live_count() >= 1:
			break
	var monsters := _live_monsters()
	if monsters.is_empty():
		return {"error": "no monster spawned"}
	var monster: JamoMonster = monsters[0]
	var extents := monster.get_walkable_half_extents()
	for _frame in 90:
		monster.global_position = Vector3(extents.x, monster.global_position.y, 0.0)
		await get_tree().process_frame
	await _shot("worst_case_corner")
	return {
		"walkable_half_extents": [extents.x, extents.y],
		"position": [monster.global_position.x, monster.global_position.z],
		"body_overhang_m": _body_overhang(monster),
	}


## How far the monster's own mesh sticks out past the slab edge, in metres.
## 0 means the whole body stayed on the paper. The corners are carried into the
## slab's frame one at a time: re-bounding the whole box in a rotated frame
## would inflate it and report an overhang that is not there.
func _body_overhang(monster: JamoMonster) -> float:
	var aabb := _world_aabb(monster)
	if aabb.size == Vector3.ZERO:
		return 0.0
	var worst := 0.0
	for corner_index in 8:
		var corner: Vector3 = _to_slab * aabb.get_endpoint(corner_index)
		worst = maxf(worst, maxf(absf(corner.x), absf(corner.z)) - SLAB_HALF)
	return maxf(0.0, worst)


## Union of every visual mesh under the monster, in world space.
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


func _monster_id(monster: JamoMonster) -> String:
	return String(monster.monster_data.id) if monster.monster_data != null else "?"


func _live_monsters() -> Array[JamoMonster]:
	var alive: Array[JamoMonster] = []
	for child: Node in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster != null and monster.is_alive():
			alive.append(monster)
	return alive


func _live_count() -> int:
	return _live_monsters().size()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/arena_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f5_arena.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f5_arena: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	print(JSON.stringify(_report, "\t"))
	print("OK - F5 arena artifacts written to %s" % ARTIFACT_DIR)
