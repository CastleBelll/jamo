class_name SpawnManager
extends Node

## Spawns the monsters of the current wave and reports when the wave's field
## is empty. Doc v0.4 sections 5, 25 and 39.
##
## Everything about *what* spawns comes from the WaveData handed to
## configure_wave(): pool, count, interval and the simultaneous cap. The pools
## below are plain Inspector lists of packed scenes, so adding a jamo means
## dragging in its .tscn, not editing code.

## Every enemy the wave promised has been spawned and none is left on the
## field. The WaveController turns this into Wave Clear.
signal field_cleared()

## Weight penalty applied to the jamo that spawned most recently, so the same
## letter does not stack up. Doc v0.3 section 28.
const REPEAT_WEIGHT_PENALTY := 0.25
## How many placements to try before settling for the roomiest one found.
const SPAWN_PLACEMENT_ATTEMPTS := 12

@export_group("Pools")
## Normal Pool, used when the WaveData has an empty enemy_pool. Weights come
## from each JamoMonsterData.spawn_weight. Doc v0.3 section 28.
@export var monster_scenes: Array[PackedScene] = []
## Special Pool - the special variants under scenes/monsters/special/.
## Rolled with WaveData.special_spawn_rate. Doc v0.4 section 16.
@export var special_scenes: Array[PackedScene] = []
## Golden Pool - rolled with GameBalance.golden_spawn_chance, and only once the
## word 금 is equipped this run. Doc v0.4 section 38.
@export var golden_scenes: Array[PackedScene] = []

@export_group("Field")
## Node the spawned monsters are parented to.
@export var spawn_root: Node3D
## Node whose Marker3D children are the outer spawn points. With none, spawns
## are placed anywhere on the sheet as in v0.3. Doc v0.4 section 39.
@export var spawn_point_root: Node3D
## The 문장핵 every spawned monster walks to. Empty makes them wander.
@export var objective: SentenceCore
## Half-extents of the paper sheet, in metres: half width and half depth of
## the 12 x 7.5 sheet in arena.tscn. Each monster insets this by its own body
## footprint, so keep it matching the sheet rather than shrinking it here.
## See JamoMonster.get_walkable_half_extents.
@export var arena_half_extents: Vector2 = Vector2(6.0, 3.75)
## Random offset around the chosen spawn point, in metres, so a wave does not
## spawn in one file.
@export_range(0.0, 3.0, 0.05) var spawn_jitter: float = 0.7
## Y position monsters are placed at.
@export var spawn_height: float = 0.0
## Preferred clearance from the nearest living monster when placing a new one,
## so fresh spawns do not appear inside an existing letter. Set to 0 to place
## purely at random.
@export_range(0.0, 4.0, 0.05) var min_spawn_distance: float = 1.3

@export_group("Diagnostics")
## Seconds a fully spawned wave may sit with survivors that neither die nor
## reach the 문장핵 before they are named in a warning. A wave that cannot clear
## locks the run (doc v0.4 section 31), so it is reported rather than waited on.
## Nothing is forced off the field: that would hit the core or pay a kill the
## player did not earn, and would hide the bug. 0 disables the check.
@export_range(0.0, 120.0, 1.0) var stall_warning_seconds: float = 30.0

var _alive: Array[JamoMonster] = []
## Seconds since the last enemy left the field after the wave finished spawning.
var _stall_seconds: float = 0.0
var _stall_reported: bool = false
var _spawn_timer: float = 0.0
var _last_spawned_id: StringName = &""
## PackedScene -> its JamoMonsterData, so the pools never re-read a packed
## scene state while the field is refilling. Doc v0.3 section 36.
var _data_cache: Dictionary = {}
## The wave being spawned, null while nothing should spawn.
var _wave: WaveData = null
## Monsters spawned so far for _wave.
var _spawned: int = 0


func _ready() -> void:
	if spawn_root == null:
		spawn_root = get_parent() as Node3D
	_validate_pool(monster_scenes, JamoMonsterData.SpecialType.NORMAL, "Normal")
	_validate_pool(special_scenes, JamoMonsterData.SpecialType.SPECIAL, "Special")
	_validate_pool(golden_scenes, JamoMonsterData.SpecialType.GOLDEN, "Golden")


## Catches a scene dropped into the wrong pool in the editor, which would
## otherwise only show up as a golden monster spawning before 금 is completed.
func _validate_pool(
	pool: Array[PackedScene], expected: JamoMonsterData.SpecialType, pool_name: String
) -> void:
	for scene: PackedScene in pool:
		var data := _data_for(scene)
		if data != null and data.special_type != expected:
			push_warning(
				"SpawnManager: %s is in the %s pool but its special_type is %d."
				% [scene.resource_path, pool_name, data.special_type]
			)


# --- Wave lifecycle ---------------------------------------------------------

## Starts spawning `wave`. Monsters already on the field stay: a wave that
## follows a clear starts on an empty field anyway, and a harness may want to
## keep what it has.
## `already_resolved` is how many of the wave's enemies were killed or reached
## the core before this call - the count RunState carries across RUN 이어하기 -
## so a resumed wave spawns only what is left. Doc v0.4 section 44.
func configure_wave(wave: WaveData, already_resolved: int = 0) -> void:
	_wave = wave
	_spawned = 0
	_spawn_timer = 0.0
	_stall_seconds = 0.0
	_stall_reported = false
	if wave == null:
		return
	if _normal_pool().is_empty():
		push_error(
			"SpawnManager: wave %d has no enemy pool and the Normal pool is empty."
			% wave.wave_number
		)
		_wave = null
		return
	_spawned = clampi(already_resolved, 0, wave.enemy_count)
	# A run saved between the last kill and the clear beat resumes with nothing
	# left to spawn or to kill, so the clear has to be declared here.
	if _spawned >= wave.enemy_count and _alive.is_empty():
		field_cleared.emit.call_deferred()


## Stops spawning. The field is left alone; clear_field() empties it.
func stop() -> void:
	_wave = null


func is_spawning() -> bool:
	return _wave != null


## Monsters still on the field, dead ones excluded.
func alive_count() -> int:
	return _alive.size()


## True once the wave has spawned everything it promised.
func is_wave_exhausted() -> bool:
	return _wave != null and _spawned >= _wave.enemy_count


func _process(delta: float) -> void:
	if _wave == null:
		return
	if _spawned >= _wave.enemy_count:
		_watch_for_stall(delta)
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	if _alive.size() >= _wave.max_alive:
		return
	_spawn_timer = _wave.spawn_interval
	_spawn_one()


## Removes every monster on the field without paying out gold.
func clear_field() -> void:
	for monster: JamoMonster in _alive:
		if is_instance_valid(monster):
			monster.queue_free()
	_alive.clear()
	_spawn_timer = 0.0


func _spawn_one() -> void:
	var scene := _pick_scene(_pick_pool())
	if scene == null:
		return
	var monster := scene.instantiate() as JamoMonster
	if monster == null:
		push_error("SpawnManager: %s is not a JamoMonster scene." % scene.resource_path)
		return

	monster.arena_half_extents = arena_half_extents
	monster.objective = objective
	monster.died.connect(_on_monster_died)
	spawn_root.add_child(monster)
	# Placed with the monster's own walkable rectangle, so a big glyph never
	# starts life hanging over the paper edge. Doc v0.3 section 27.
	monster.global_position = _random_spawn_point(monster.get_walkable_half_extents())

	if monster.monster_data != null:
		_last_spawned_id = monster.monster_data.id
	_alive.append(monster)
	_spawned += 1


## Picks a spot with some breathing room. Falls back to the emptiest candidate
## found rather than looping forever, which matters once the field is crowded.
func _random_spawn_point(half_extents: Vector2) -> Vector3:
	var best := _spawn_candidate(half_extents)
	if min_spawn_distance <= 0.0:
		return best
	var best_clearance := _clearance_at(best)
	for _attempt in SPAWN_PLACEMENT_ATTEMPTS:
		if best_clearance >= min_spawn_distance:
			return best
		var candidate := _spawn_candidate(half_extents)
		var clearance := _clearance_at(candidate)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


## One candidate position: a jittered outer spawn point clamped onto the
## monster's walkable rectangle, or anywhere on the sheet when no points exist.
func _spawn_candidate(half_extents: Vector2) -> Vector3:
	var marker: Node3D = _pick_spawn_point()
	if marker == null:
		return JamoMonster.random_point_in_arena(half_extents, spawn_height)
	var point := marker.global_position + Vector3(
		randf_range(-spawn_jitter, spawn_jitter),
		0.0,
		randf_range(-spawn_jitter, spawn_jitter)
	)
	point.y = spawn_height
	return JamoMonster.clamp_point_to_arena(point, half_extents)


func _pick_spawn_point() -> Node3D:
	if spawn_point_root == null or spawn_point_root.get_child_count() == 0:
		return null
	return spawn_point_root.get_children().pick_random() as Node3D


## Distance to the nearest living monster, or INF when the field is empty.
func _clearance_at(point: Vector3) -> float:
	var closest := INF
	for monster: JamoMonster in _alive:
		if is_instance_valid(monster):
			closest = minf(closest, point.distance_to(monster.global_position))
	return closest


## Chance the next spawn is drawn from the Golden Pool. 0 unless the word 금 is
## equipped in the current run, and the word 운 multiplies it. Doc v0.4 §16, §38.
func get_golden_spawn_chance() -> float:
	if golden_scenes.is_empty() or not RunState.is_golden_monster_unlocked():
		return 0.0
	var luck := RunState.get_special_spawn_multiplier()
	return MetaState.balance.golden_spawn_chance * luck


## Chance the next spawn is drawn from the Special Pool: the wave's own rate,
## scaled by 운. Doc v0.4 sections 5.2 and 16.
func get_special_spawn_chance() -> float:
	if special_scenes.is_empty() or _wave == null:
		return 0.0
	var luck := RunState.get_special_spawn_multiplier()
	return _wave.special_spawn_rate * luck


## The wave's own pool, or the Inspector Normal Pool when the wave has none.
func _normal_pool() -> Array[PackedScene]:
	if _wave != null and not _wave.enemy_pool.is_empty():
		return _wave.enemy_pool
	return monster_scenes


## One roll decides the pool: golden first, then special, then the plain jamo.
## Doc v0.3 section 28.
func _pick_pool() -> Array[PackedScene]:
	var roll := randf()
	var golden_chance := get_golden_spawn_chance()
	if roll < golden_chance:
		return golden_scenes
	if roll < golden_chance + get_special_spawn_chance():
		return special_scenes
	return _normal_pool()


## Weighted pick inside one pool using each scene JamoMonsterData.spawn_weight,
## with a penalty on the jamo that spawned last.
func _pick_scene(pool: Array[PackedScene]) -> PackedScene:
	if pool.is_empty():
		return null
	var weights: Array[float] = []
	var total := 0.0
	for scene: PackedScene in pool:
		var weight := _weight_for(scene)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return pool.pick_random()

	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool.back()


func _weight_for(scene: PackedScene) -> float:
	var data := _data_for(scene)
	if data == null:
		return 1.0
	var weight := data.spawn_weight
	if data.id == _last_spawned_id:
		weight *= REPEAT_WEIGHT_PENALTY
	return maxf(0.0, weight)


## The JamoMonsterData of a pool entry, read once off the packed scene and kept,
## so refilling the field never instantiates a node just to learn a weight.
func _data_for(scene: PackedScene) -> JamoMonsterData:
	if scene == null:
		return null
	if _data_cache.has(scene):
		return _data_cache[scene]
	var data: JamoMonsterData = null
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"monster_data":
			data = state.get_node_property_value(0, i) as JamoMonsterData
			break
	_data_cache[scene] = data
	return data


## A monster left the field, killed or otherwise. Once the wave has nothing
## more to spawn and nothing left standing, the field is cleared.
func _on_monster_died(monster: JamoMonster) -> void:
	_alive.erase(monster)
	_stall_seconds = 0.0
	# Counted on RunState so a suspended run knows how much of the wave is done.
	RunState.wave_resolved_count += 1
	_spread_burn_from(monster)
	if is_wave_exhausted() and _alive.is_empty():
		field_cleared.emit()


## Names the survivors of a wave that has spawned everything and still will
## not clear. Warning only; see stall_warning_seconds.
func _watch_for_stall(delta: float) -> void:
	if stall_warning_seconds <= 0.0 or _stall_reported or _alive.is_empty():
		return
	_stall_seconds += delta
	if _stall_seconds < stall_warning_seconds:
		return
	_stall_reported = true
	var survivors := PackedStringArray()
	for monster: JamoMonster in _alive:
		if not is_instance_valid(monster):
			survivors.append("<freed>")
			continue
		survivors.append("%s state=%s hp=%.0f pos=(%.2f, %.2f)" % [
			String(monster.monster_data.id) if monster.monster_data != null else "?",
			JamoMonster.State.keys()[monster.get_state()], monster.hp,
			monster.global_position.x, monster.global_position.z,
		])
	push_warning(
		"SpawnManager: wave %d finished spawning %.0fs ago and %d enemy(ies) never resolved: %s"
		% [_wave.wave_number, _stall_seconds, _alive.size(), ", ".join(survivors)]
	)


## 불꽃: a monster that dies burning hands its burn to the nearest neighbours.
## Runs only on death and reads the cached _alive list, so no group scan and no
## per-frame neighbour search is added. Doc v0.3 section 36.
func _spread_burn_from(source: JamoMonster) -> void:
	var spread: WordEffectData = RunState.get_burn_spread_effect()
	if spread == null or not source.died_burning:
		return
	# A burn that already hopped its allowed number of times stops here, so a
	# chain of deaths can never run away across the field.
	var next_depth: int = source.burn_chain_depth + 1
	if next_depth > spread.max_chain_depth:
		return
	var burn: WordEffectData = RunState.get_burn_effect()
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
