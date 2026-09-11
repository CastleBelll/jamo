class_name CombatDirector
extends Node
## Runs one Wave of combat (G3/G4/G7, B2/B11): spawn schedule, lane placement, manual input,
## the fixed tick order, purify/reach bookkeeping and the single Gold owner. Everything is
## driven from tick(delta) so headless tests can step it deterministically.

signal enemies_changed(remaining: int)
signal enemy_purified(monster: JamoMonster, source: StringName)
signal enemy_reached(monster: JamoMonster)
signal manual_hit(monster: JamoMonster, damage: float, crit: bool)

const MONSTER_SCENE := preload("res://scenes/monsters/jamo_monster.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/effects/damage_number.tscn")
const LANE_COUNT := 3
const SUB_LANE_COUNT := 2
const SOURCE_MANUAL := &"manual"

var run: RunController
var db: ContentDB
var paths: Array[Path2D] = []       # index = lane * 2 + sub
var enemy_root: Node2D
var effect_root: Node2D

var rng_spawn := RandomNumberGenerator.new()
var enemies: Array[JamoMonster] = []
var wave_data: WaveData
var clock: float = 0.0
var spawned: int = 0
var total: int = 0
var next_spawn_at: float = 0.0
var lane_rotation: int = 0
var sub_rotation: int = 0
var next_entity_id: int = 1
var active: bool = false

## Manual input state (G3): one global cooldown shared by click, hold and keyboard.
var attack_cooldown: float = 0.0
var pending_target: JamoMonster
var miss_clicks: int = 0
var hold_pressed: bool = false
var focus_index: int = -1
var stats := {"hits": 0, "purified": 0, "reached": 0}


func setup(controller: RunController, content: ContentDB, page: Node2D) -> void:
	run = controller
	db = content
	paths.clear()
	for name in ["L_A", "L_B", "C_A", "C_B", "R_A", "R_B"]:
		paths.append(page.get_node("Paths/" + name) as Path2D)
	enemy_root = page.get_node("Enemies")
	effect_root = page.get_node("Effects")


func start_wave(data: WaveData, seed: int) -> void:
	clear_enemies()
	wave_data = data
	rng_spawn.seed = seed
	clock = 0.0
	spawned = 0
	total = data.enemy_count
	next_spawn_at = 0.0
	lane_rotation = 0
	sub_rotation = 0
	attack_cooldown = 0.0
	pending_target = null
	focus_index = -1
	miss_clicks = 0
	stats = {"hits": 0, "purified": 0, "reached": 0}
	active = true
	enemies_changed.emit(remaining())


func clear_enemies() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	active = false


## Enemies not yet purified/reached: living ones plus the ones still to spawn.
func remaining() -> int:
	return enemies.size() + (total - spawned)


func living_count() -> int:
	return enemies.size()


# --- input (G3) ----------------------------------------------------------------------

## Left button pressed at a world position. Empty space costs nothing but a miss statistic.
func request_click(world_pos: Vector2) -> void:
	var target := pick_target(world_pos)
	if target == null:
		miss_clicks += 1
		return
	pending_target = target


func set_hold(pressed: bool) -> void:
	hold_pressed = pressed


## Overlap rule: nearest centre wins, ties go to the lower entity_id (G3).
func pick_target(world_pos: Vector2) -> JamoMonster:
	var radius := db.balance.enemy_click_diameter * 0.5
	var best: JamoMonster = null
	var best_d := INF
	for e in enemies:
		if not e.is_hit_by(world_pos, radius):
			continue
		var d := e.global_position.distance_to(world_pos)
		if d < best_d or (is_equal_approx(d, best_d) and e.entity_id < best.entity_id):
			best = e
			best_d = d
	return best


## Keyboard accessibility: Tab cycles normal enemies by ETA (G3); returns the focused one.
func cycle_focus() -> JamoMonster:
	var order := enemies.duplicate()
	order.sort_custom(func(a, b): return a.eta() < b.eta() or (is_equal_approx(a.eta(), b.eta()) and a.entity_id < b.entity_id))
	if order.is_empty():
		focus_index = -1
		return null
	focus_index = (focus_index + 1) % order.size()
	for e in enemies:
		e.focused = false
	order[focus_index].focused = true
	return order[focus_index]


func focused_enemy() -> JamoMonster:
	for e in enemies:
		if e.focused:
			return e
	return null


func request_keyboard_attack() -> void:
	var target := focused_enemy()
	if target != null:
		pending_target = target


func can_attack() -> bool:
	return attack_cooldown <= 0.0


# --- tick (G7 order) ------------------------------------------------------------------

func tick(delta: float, cursor_world: Vector2 = Vector2.INF) -> void:
	if not active or run.phase != RunController.Phase.COMBAT:
		return
	clock += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	# 1. input judgement: hold repeats through the same cooldown; a press already set pending.
	if pending_target == null and hold_pressed and cursor_world != Vector2.INF:
		pending_target = pick_target(cursor_world)
	# 2. direct damage
	if pending_target != null and can_attack() and pending_target.alive:
		_manual_attack(pending_target)
	pending_target = null
	# 3./4. hit statuses and scheduled auto/status damage arrive with words (P1/P2).
	# 5. purify, in entity_id order
	_resolve_purify()
	# 6. movement, then reach damage (보스 패턴/도달 피해)
	_advance_enemies(delta)
	_spawn_if_due()
	# 7./8. defeat is decided inside damage_stability; clear only if still in COMBAT.
	if run.phase == RunController.Phase.COMBAT and spawned >= total and enemies.is_empty():
		active = false
		run.on_wave_cleared()


func _manual_attack(target: JamoMonster) -> void:
	var crit := false
	var damage := manual_damage(crit)
	var dealt := target.take_damage(damage)
	attack_cooldown = db.balance.manual_interval
	stats["hits"] += 1
	_spawn_damage_number(target.global_position, dealt, crit)
	manual_hit.emit(target, dealt, crit)


## B1: 1.0 x (1 + bonus sum) x crit. Word bonuses plug in here in P1.
func manual_damage(crit: bool) -> float:
	var bonus := 0.0
	var value := db.balance.manual_base_damage * (1.0 + minf(bonus, db.balance.manual_damage_bonus_cap))
	return value * (db.balance.crit_multiplier if crit else 1.0)


func _resolve_purify() -> void:
	var dead: Array[JamoMonster] = []
	for e in enemies:
		if e.alive and e.hp <= 0.0:
			dead.append(e)
	dead.sort_custom(func(a, b): return a.entity_id < b.entity_id)
	for e in dead:
		e.alive = false
		enemies.erase(e)
		stats["purified"] += 1
		run.add_gold(gold_per_kill())
		enemy_purified.emit(e, SOURCE_MANUAL)
		e.play_purify()
		_retire(e, 0.2)
	if not dead.is_empty():
		enemies_changed.emit(remaining())


func gold_per_kill() -> int:
	return db.balance.gold_per_kill_late if run.wave >= db.balance.gold_late_from_wave else db.balance.gold_per_kill_early


func _advance_enemies(delta: float) -> void:
	var reached: Array[JamoMonster] = []
	# Followers are limited by the enemy ahead on the same sub path (G11 min spacing).
	var ordered := enemies.duplicate()
	ordered.sort_custom(func(a, b): return a.progress > b.progress)
	var lead_progress := {}
	for e in ordered:
		var key: int = e.lane * SUB_LANE_COUNT + e.sub_lane
		var limit: float = INF
		if lead_progress.has(key):
			limit = lead_progress[key] - db.balance.enemy_min_spacing
		if e.advance(delta, limit):
			reached.append(e)
		lead_progress[key] = e.progress
	reached.sort_custom(func(a, b): return a.entity_id < b.entity_id)
	for e in reached:
		e.alive = false
		enemies.erase(e)
		stats["reached"] += 1
		enemy_reached.emit(e)
		_retire(e, 0.0)
		run.damage_stability(db.balance.reach_damage)
		if run.phase != RunController.Phase.COMBAT:
			break
	if not reached.is_empty():
		enemies_changed.emit(remaining())


func _spawn_if_due() -> void:
	if spawned >= total or clock < next_spawn_at:
		return
	if enemies.size() >= wave_data.concurrent_max:
		return
	var slot := _pick_slot()
	if slot < 0:
		return  # spawn spot blocked: hold this spawn, never batch (G11)
	_spawn(slot)
	# B2: next spawn counts from the actual spawn time, delays included.
	next_spawn_at = clock + wave_data.spawn_interval


## Lane with the fewest living enemies, ties rotating L->C->R; same rule for sub paths.
## Returns -1 when the chosen sub path start is still occupied.
func _pick_slot() -> int:
	var lane_counts := [0, 0, 0]
	var sub_counts := [0, 0, 0, 0, 0, 0]
	for e in enemies:
		lane_counts[e.lane] += 1
		sub_counts[e.lane * SUB_LANE_COUNT + e.sub_lane] += 1
	var lane := _fewest(lane_counts, lane_rotation)
	var sub_base := lane * SUB_LANE_COUNT
	var sub := _fewest([sub_counts[sub_base], sub_counts[sub_base + 1]], sub_rotation)
	for e in enemies:
		if e.lane == lane and e.sub_lane == sub and e.progress < db.balance.enemy_min_spacing:
			return -1
	lane_rotation = (lane + 1) % LANE_COUNT
	sub_rotation = (sub + 1) % SUB_LANE_COUNT
	return sub_base + sub


func _fewest(counts: Array, start: int) -> int:
	var best := -1
	for offset in counts.size():
		var i := (start + offset) % counts.size()
		if best < 0 or counts[i] < counts[best]:
			best = i
	return best


func _spawn(slot: int) -> void:
	var m: JamoMonster = MONSTER_SCENE.instantiate()
	var lane := slot / SUB_LANE_COUNT
	var sub := slot % SUB_LANE_COUNT
	m.setup(next_entity_id, _draw_jamo(), wave_data.base_hp, paths[slot], wave_data.travel_time, lane, sub)
	next_entity_id += 1
	enemy_root.add_child(m)
	enemies.append(m)
	spawned += 1
	enemies_changed.emit(remaining())


## B5 weighted draw on the spawn RNG stream (no pin bonus yet: P1).
func _draw_jamo() -> String:
	var weights := db.spawn_weights(false)
	var keys := weights.keys()
	keys.sort()
	var total_w := 0
	for k in keys:
		total_w += weights[k]
	var roll := rng_spawn.randi_range(1, total_w)
	for k in keys:
		roll -= weights[k]
		if roll <= 0:
			return k
	return keys[-1]


func _spawn_damage_number(at: Vector2, value: float, crit: bool) -> void:
	if effect_root == null:
		return
	var n := DAMAGE_NUMBER_SCENE.instantiate()
	effect_root.add_child(n)
	n.global_position = at + Vector2(-20, -50)
	n.show_value(value, crit)


func spawn_text(at: Vector2, text: String, color: Color) -> void:
	if effect_root == null:
		return
	var n := DAMAGE_NUMBER_SCENE.instantiate()
	effect_root.add_child(n)
	n.global_position = at + Vector2(-20, -80)
	n.show_text(text, color)


func _retire(m: JamoMonster, delay: float) -> void:
	m.focused = false
	if delay <= 0.0 or not is_inside_tree():
		m.queue_free()
		return
	var t := get_tree().create_timer(delay)
	t.timeout.connect(m.queue_free)
