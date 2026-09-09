class_name SpawnManager
extends Node

## Keeps the field topped up to the current monster capacity.
## Doc v0.3 section 28. The spawn pool is a plain Inspector list of packed
## scenes, so adding a jamo means dragging in its .tscn, not editing code.

## Weight penalty applied to the jamo that spawned most recently, so the same
## letter does not stack up. Doc v0.3 section 28.
const REPEAT_WEIGHT_PENALTY := 0.25
## How many placements to try before settling for the roomiest one found.
const SPAWN_PLACEMENT_ATTEMPTS := 12

@export_group("Pool")
## One entry per jamo monster scene. Weights come from each JamoMonsterData.
@export var monster_scenes: Array[PackedScene] = []

@export_group("Field")
## Node the spawned monsters are parented to.
@export var spawn_root: Node3D
## Half-diagonals of the diamond arena footprint, in metres. See
## JamoMonster.random_point_in_arena.
@export var arena_half_extents: Vector2 = Vector2(3.4, 3.4)
## Seconds between spawns while the field is refilling.
@export_range(0.0, 3.0, 0.05) var spawn_interval: float = 0.25
## Y position monsters are placed at.
@export var spawn_height: float = 0.0
## Preferred clearance from the nearest living monster when placing a new one,
## so fresh spawns do not appear inside an existing letter. Set to 0 to place
## purely at random.
@export_range(0.0, 4.0, 0.05) var min_spawn_distance: float = 1.3

var _alive: Array[JamoMonster] = []
var _spawn_timer: float = 0.0
var _last_spawned_id: StringName = &""


func _ready() -> void:
	if spawn_root == null:
		spawn_root = get_parent() as Node3D
	if monster_scenes.is_empty():
		push_error("SpawnManager has an empty monster_scenes pool.")
		set_process(false)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	if _alive.size() >= GameState.get_monster_capacity():
		return
	_spawn_timer = spawn_interval
	_spawn_one()


## Removes every monster on the field without paying out gold. Used when a new
## day starts so the field reflects the new day HP and gold values.
func clear_field() -> void:
	for monster: JamoMonster in _alive:
		if is_instance_valid(monster):
			monster.queue_free()
	_alive.clear()
	_spawn_timer = 0.0


func _spawn_one() -> void:
	var scene := _pick_scene()
	if scene == null:
		return
	var monster := scene.instantiate() as JamoMonster
	if monster == null:
		push_error("SpawnManager: %s is not a JamoMonster scene." % scene.resource_path)
		return

	monster.arena_half_extents = arena_half_extents
	monster.died.connect(_on_monster_died)
	spawn_root.add_child(monster)
	monster.global_position = _random_spawn_point()

	if monster.monster_data != null:
		_last_spawned_id = monster.monster_data.id
	_alive.append(monster)


## Picks a spot with some breathing room. Falls back to the emptiest candidate
## found rather than looping forever, which matters once the field is crowded.
func _random_spawn_point() -> Vector3:
	var best := JamoMonster.random_point_in_arena(arena_half_extents, spawn_height)
	if min_spawn_distance <= 0.0:
		return best
	var best_clearance := _clearance_at(best)
	for _attempt in SPAWN_PLACEMENT_ATTEMPTS:
		if best_clearance >= min_spawn_distance:
			return best
		var candidate := JamoMonster.random_point_in_arena(arena_half_extents, spawn_height)
		var clearance := _clearance_at(candidate)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


## Distance to the nearest living monster, or INF when the field is empty.
func _clearance_at(point: Vector3) -> float:
	var closest := INF
	for monster: JamoMonster in _alive:
		if is_instance_valid(monster):
			closest = minf(closest, point.distance_to(monster.global_position))
	return closest


## Weighted pick using each scene JamoMonsterData.spawn_weight, with a penalty
## on the jamo that spawned last.
func _pick_scene() -> PackedScene:
	var weights: Array[float] = []
	var total := 0.0
	for scene: PackedScene in monster_scenes:
		var weight := _weight_for(scene)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return monster_scenes.pick_random()

	var roll := randf() * total
	for i in monster_scenes.size():
		roll -= weights[i]
		if roll <= 0.0:
			return monster_scenes[i]
	return monster_scenes.back()


func _weight_for(scene: PackedScene) -> float:
	var state := scene.get_state()
	var data: JamoMonsterData = null
	# Read the exported monster_data straight off the packed scene so the pool
	# never has to instantiate a node just to learn its weight.
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"monster_data":
			data = state.get_node_property_value(0, i) as JamoMonsterData
			break
	if data == null:
		return 1.0
	var weight := data.spawn_weight
	if data.id == _last_spawned_id:
		weight *= REPEAT_WEIGHT_PENALTY
	return maxf(0.0, weight)


func _on_monster_died(monster: JamoMonster) -> void:
	_alive.erase(monster)
	_spread_burn_from(monster)


## 불꽃: a monster that dies burning hands its burn to the nearest neighbours.
## Runs only on death and reads the cached _alive list, so no group scan and no
## per-frame neighbour search is added. Doc v0.3 section 36.
func _spread_burn_from(source: JamoMonster) -> void:
	var spread: WordEffectData = GameState.get_burn_spread_effect()
	if spread == null or not source.died_burning:
		return
	# A burn that already hopped its allowed number of times stops here, so a
	# chain of deaths can never run away across the field.
	var next_depth: int = source.burn_chain_depth + 1
	if next_depth > spread.max_chain_depth:
		return
	var burn: WordEffectData = GameState.get_burn_effect()
	if burn == null:
		return
	for target: JamoMonster in _nearest_alive(
		source.global_position, spread.radius, spread.chain_count
	):
		target.apply_status_effect(burn, next_depth)


## The `count` living monsters closest to `origin` and within `radius`, nearest
## first. The field is capped at 20, so a plain sort is cheap enough here.
func _nearest_alive(origin: Vector3, radius: float, count: int) -> Array[JamoMonster]:
	var found: Array[JamoMonster] = []
	if count <= 0 or radius <= 0.0:
		return found
	for monster: JamoMonster in _alive:
		if not is_instance_valid(monster) or not monster.is_alive():
			continue
		if origin.distance_to(monster.global_position) <= radius:
			found.append(monster)
	found.sort_custom(
		func(a: JamoMonster, b: JamoMonster) -> bool:
			var to_a := origin.distance_squared_to(a.global_position)
			var to_b := origin.distance_squared_to(b.global_position)
			return to_a < to_b
	)
	return found.slice(0, count)
