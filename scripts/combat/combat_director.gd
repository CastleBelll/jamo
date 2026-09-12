class_name CombatDirector
extends Node
## Runs one Wave of combat (G3/G4/G7, B2/B11): spawn schedule, lane placement, manual input,
## the fixed tick order, purify/reach bookkeeping and the single Gold owner. Everything is
## driven from tick(delta) so headless tests can step it deterministically.

signal enemies_changed(remaining: int)
signal enemy_purified(monster: JamoMonster, source: StringName)
signal enemy_reached(monster: JamoMonster)
signal manual_hit(monster: JamoMonster, damage: float, crit: bool)
signal seal_changed

const MONSTER_SCENE := preload("res://scenes/monsters/jamo_monster.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/effects/damage_number.tscn")
const BOSS_SCENE := preload("res://scenes/bosses/boss_base.tscn")
const PATTERN_SCENE := preload("res://scenes/effects/pattern_target.tscn")
const LANE_COUNT := 3
const SUB_LANE_COUNT := 2
const SOURCE_MANUAL := &"manual"
const PRIORITY_WARNING := 100

var run: RunController
var db: ContentDB
var resolver := CombatResolver.new()
var paths: Array[Path2D] = []       # index = lane * 2 + sub
var enemy_root: Node2D
var effect_root: Node2D

var rng_spawn := RandomNumberGenerator.new()
## Variant rolls use their own stream (B2: 생성 가중치와 변형 확률은 별도 추첨).
var rng_variant := RandomNumberGenerator.new()
## Boss decisions (침묵 seal target) roll on their own stream too.
var rng_boss := RandomNumberGenerator.new()
## 위험 words unlocked for this RUN: widens the B5 spawn pool to 20 jamo types.
var risk_unlocked: bool = false
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
## Boss Wave state (G8/B9): the body, its finite minion schedule and live 대응물.
var boss: Boss
var boss_data: BossData
var pending_minions: Array[Dictionary] = []   # [{"t": float, "jamo": String}]
var pattern_targets: Array[PatternTarget] = []
var pending_pattern: PatternTarget

## Manual input state (G3): one global cooldown shared by click, hold and keyboard.
var attack_cooldown: float = 0.0
var pending_target: JamoMonster
var miss_clicks: int = 0
var hold_pressed: bool = false
var focus_index: int = -1
var stats := {"hits": 0, "purified": 0, "reached": 0, "patterns_defused": 0, "patterns_failed": 0}
## Gold earned in this Wave (float, B10 fractions accumulate) for the 돈 clear heal.
var wave_gold: float = 0.0
## Jamo the pinned goal lacks in the deck: B5 spawn weight x1.15, renormalised.
var pin_lacking: Array[String] = []


func setup(controller: RunController, content: ContentDB, page: Node2D) -> void:
	run = controller
	db = content
	paths.clear()
	for name in ["L_A", "L_B", "C_A", "C_B", "R_A", "R_B"]:
		paths.append(page.get_node("Paths/" + name) as Path2D)
	enemy_root = page.get_node("Enemies")
	effect_root = page.get_node("Effects")
	resolver.setup(db, run.build, hash("crit:%d" % run.run_seed))


func start_wave(data: WaveData, seed: int) -> void:
	clear_enemies()
	wave_data = data
	rng_spawn.seed = seed
	rng_variant.seed = hash("variant:%d" % seed)
	rng_boss.seed = hash("boss:%d" % seed)
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
	stats = {"hits": 0, "purified": 0, "reached": 0, "patterns_defused": 0, "patterns_failed": 0}
	wave_gold = 0.0
	boss = null
	boss_data = null
	pending_minions.clear()
	pending_pattern = null
	if data.is_boss:
		boss_data = db.bosses[data.boss_id]
		total = 1
		for entry in boss_data.minion_schedule:
			for i in int(entry["count"]):
				pending_minions.append({"t": float(entry["t"]), "jamo": String(entry.get("jamo", ""))})
				total += 1
		_spawn_boss()
	resolver.build = run.build
	resolver.start_wave()
	run.drops.bonus = resolver.drop_chance_add
	active = true
	enemies_changed.emit(remaining())


func clear_enemies() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for p in pattern_targets:
		p.queue_free()
	pattern_targets.clear()
	active = false


## Enemies still to spawn: the minion schedule on boss Waves, the B2 count otherwise.
func unspawned() -> int:
	return pending_minions.size() if boss_data != null else total - spawned


func minion_count() -> int:
	var n := 0
	for e in enemies:
		if not (e is Boss):
			n += 1
	return n


## Enemies not yet purified/reached: living ones plus the ones still to spawn.
func remaining() -> int:
	return enemies.size() + unspawned()


func living_count() -> int:
	return enemies.size()


# --- input (G3) ----------------------------------------------------------------------

## Left button pressed at a world position. Empty space costs nothing but a miss statistic.
func request_click(world_pos: Vector2) -> void:
	# 대응물 first: it never overlaps the boss capsule (B9) and is not an enemy target (G8).
	for p in pattern_targets:
		if p.is_hit_by(world_pos):
			pending_pattern = p
			return
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


## Keyboard accessibility (G3): Tab cycles live 대응물 (least time left), then normal enemies
## by ETA, then the boss. Returns the focused node (PatternTarget or JamoMonster).
func cycle_focus() -> Node2D:
	var order: Array = []
	var live_patterns := pattern_targets.filter(func(p): return not p.done)
	live_patterns.sort_custom(func(a, b): return a.remaining < b.remaining)
	order.append_array(live_patterns)
	var normals := enemies.filter(func(e): return not (e is Boss))
	normals.sort_custom(func(a, b): return a.eta() < b.eta() or (is_equal_approx(a.eta(), b.eta()) and a.entity_id < b.entity_id))
	order.append_array(normals)
	if boss != null and boss.alive:
		order.append(boss)
	for e in enemies:
		e.focused = false
	for p in pattern_targets:
		p.focused = false
	if order.is_empty():
		focus_index = -1
		return null
	focus_index = (focus_index + 1) % order.size()
	order[focus_index].focused = true
	return order[focus_index]


func focused_enemy() -> JamoMonster:
	for e in enemies:
		if e.focused:
			return e
	return null


func request_keyboard_attack() -> void:
	for p in pattern_targets:
		if p.focused and not p.done:
			pending_pattern = p
			return
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
	for e in enemies:
		e.refresh_status_label(resolver.clock)
	# 2. direct damage, or one manual input into a 대응물 (same cooldown, G8)
	if pending_pattern != null and can_attack() and not pending_pattern.done:
		attack_cooldown = resolver.input_interval()
		stats["hits"] += 1
		if pending_pattern.register_input():
			stats["patterns_defused"] += 1
	elif pending_target != null and can_attack() and pending_target.alive:
		_manual_attack(pending_target)
	pending_target = null
	pending_pattern = null
	# 3. hit statuses were applied inside _manual_attack (only for a surviving target).
	# 4. scheduled auto / status damage (no procs from these sources, G7)
	var sealed_before := resolver.sealed_ids().size()
	for hit in resolver.scheduled_damage(delta, enemies):
		_apply_hit(hit["target"], hit["damage"], hit["source"])
	if resolver.sealed_ids().size() != sealed_before:
		seal_changed.emit()
	# 5. purify, in entity_id order
	_resolve_purify()
	# 6. movement and reach damage, then boss patterns (보스 패턴/도달 피해)
	_advance_enemies(delta)
	_tick_boss(delta)
	_spawn_if_due()
	# 7./8. defeat is decided inside damage_stability; clear only if still in COMBAT.
	if run.phase == RunController.Phase.COMBAT and remaining() == 0:
		active = false
		resolver.end_wave()
		run.on_wave_cleared(resolver.clear_heal(wave_gold))


func _manual_attack(target: JamoMonster) -> void:
	var roll := resolver.manual_damage(target)
	var crit: bool = roll["crit"]
	var dealt := _apply_hit(target, roll["damage"], CombatResolver.SOURCE_MANUAL)
	attack_cooldown = resolver.input_interval()
	stats["hits"] += 1
	Sfx.play("hit_ink", 0, 0.12)
	_spawn_damage_number(target.global_position, dealt, crit)
	manual_hit.emit(target, dealt, crit)
	# 3. counters on every real hit; statuses only if the target survived (resolver decides).
	if dealt > 0.0:
		for hit in resolver.on_manual_hit(target, enemies):
			_apply_hit(hit["target"], hit["damage"], hit["source"])


func _apply_hit(target: JamoMonster, damage: float, source: StringName) -> float:
	var dealt := target.take_damage(damage * guard_multiplier(target))
	if dealt > 0.0:
		target.last_source = source
	return dealt


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
		var base_gold := boss_data.gold if e is Boss else (boss_data.minion_gold if boss_data != null else gold_per_kill())
		var gold := resolver.gold_for_kill(base_gold)
		wave_gold += gold
		run.add_gold(gold)
		if e is Boss:
			_on_boss_purified(e as Boss)
			run.on_boss_purified(boss_data.id)
		elif boss != null and boss.alive and boss_data != null and boss_data.shield_per_minion > 0.0:
			boss.add_shield(boss_data.shield_per_minion, clock)  # 탐욕: 지정 부하 정화마다 +3 (B9)
		var kill := resolver.on_kill(e, e.last_source, enemies)
		if kill["heal"] > 0.0:
			run.heal_stability(kill["heal"])
		for hit in kill["derived"]:
			_apply_hit(hit["target"], hit["damage"], hit["source"])
		Sfx.play("purify", 1, 0.2)
		RunLog.event("purify", {"wave": run.wave, "entity": e.entity_id, "source": String(e.last_source), "gold": gold, "t": clock})
		enemy_purified.emit(e, e.last_source)
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
		if e is Boss:
			continue
		var key: int = e.lane * SUB_LANE_COUNT + e.sub_lane
		var limit: float = INF
		if lead_progress.has(key):
			limit = lead_progress[key] - db.balance.enemy_min_spacing
		e.speed_mult = resolver.speed_mult_for(e)
		if e.advance(delta, limit):
			reached.append(e)
		lead_progress[key] = e.progress
	reached.sort_custom(func(a, b): return a.entity_id < b.entity_id)
	for e in reached:
		e.alive = false
		enemies.erase(e)
		stats["reached"] += 1
		Sfx.play("sentence_hit", 2, 0.3)
		RunLog.event("reach", {"wave": run.wave, "entity": e.entity_id, "t": clock})
		enemy_reached.emit(e)
		_retire(e, 0.0)
		run.damage_stability(resolver.stability_damage(db.balance.reach_damage), &"reach")
		if run.phase != RunController.Phase.COMBAT:
			break
	if not reached.is_empty():
		enemies_changed.emit(remaining())


func _spawn_if_due() -> void:
	if boss_data != null:
		_spawn_minion_if_due()
		return
	if spawned >= total or clock < next_spawn_at:
		return
	if enemies.size() >= wave_data.concurrent_max:
		return
	var slot := _pick_slot()
	if slot < 0:
		return  # spawn spot blocked: hold this spawn, never batch (G11)
	_spawn(slot, _draw_jamo(), wave_data.base_hp, wave_data.travel_time, _roll_variant())
	# B2: next spawn counts from the actual spawn time, delays included.
	next_spawn_at = clock + wave_data.spawn_interval


## B9 minion schedule: one per tick when due, under the minion cap, same blocking rule.
func _spawn_minion_if_due() -> void:
	if pending_minions.is_empty() or clock < pending_minions[0]["t"]:
		return
	if minion_count() >= boss_data.minion_concurrent_max:
		return
	var slot := _pick_slot()
	if slot < 0:
		return
	var entry: Dictionary = pending_minions.pop_front()
	var jamo: String = entry["jamo"] if entry["jamo"] != "" else _draw_jamo()
	_spawn(slot, jamo, boss_data.minion_hp, boss_data.minion_travel_time)


func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.setup_boss(next_entity_id, boss_data)
	next_entity_id += 1
	enemy_root.add_child(boss)
	enemies.append(boss)
	spawned += 1
	enemies_changed.emit(remaining())


## Boss patterns (G8): start on schedule, count down, then resolve defused/failed.
func _tick_boss(delta: float) -> void:
	if boss == null or not boss.alive:
		return
	boss.update_readout(clock)
	var spec := boss.poll_pattern(clock)
	if not spec.is_empty():
		if spec["seal"]:
			# 침묵: pick the threatened word now so the 봉인선 is visible during the warning.
			var options := resolver.sealable_words()
			if not options.is_empty():
				var chosen: StringName = options[rng_boss.randi_range(0, options.size() - 1)]
				spec["seal_word"] = chosen
		Sfx.play("boss_warning", PRIORITY_WARNING, 0.6)
		var p: PatternTarget = PATTERN_SCENE.instantiate()
		if spec.has("seal_word"):
			p.seal_word_name = db.words[spec["seal_word"]].name
		p.setup(spec)
		effect_root.add_child(p)
		pattern_targets.append(p)
		p.completed.connect(_on_pattern_defused)
	for p in pattern_targets.duplicate():
		if p.done:
			continue
		p.tick(delta)
		if p.done and p.hits < p.required:
			_on_pattern_failed(p)
	_prune_patterns()


## 대응 성공 (G8): the pattern effect is cancelled; 탐욕 also loses its shield for 4s.
func _on_pattern_defused(p: PatternTarget) -> void:
	if p.ring and boss != null:
		boss.break_ring(clock)


## 대응 실패 (G8/B9): damage, or for 침묵 a 4s seal of the threatened word (damage when
## nothing could be sealed). Sealed words never include 위험 words.
func _on_pattern_failed(p: PatternTarget) -> void:
	stats["patterns_failed"] += 1
	if p.seal and p.seal_word != &"" and not resolver.is_sealed(p.seal_word):
		resolver.seal(p.seal_word, p.seal_duration)
		seal_changed.emit()
		return
	run.damage_stability(resolver.stability_damage(p.fail_damage), &"pattern")


func _prune_patterns() -> void:
	for p in pattern_targets.duplicate():
		if p.done:
			pattern_targets.erase(p)
			p.queue_free()


## Boss purified: remaining minions, 대응물 and future spawns vanish without reward, and the
## body drops its guaranteed tokens outside the normal cap (B9/B4).
func _on_boss_purified(b: Boss) -> void:
	for e in enemies.duplicate():
		if e != b:
			e.alive = false
			enemies.erase(e)
			e.queue_free()
	pending_minions.clear()
	for p in pattern_targets:
		p.done = true
	_prune_patterns()
	for jamo in boss_data.body_drop:
		run.drops.add_guaranteed(jamo)


## Lane with the fewest living enemies, ties rotating L->C->R; same rule for sub paths.
## Returns -1 when the chosen sub path start is still occupied.
func _pick_slot() -> int:
	var lane_counts := [0, 0, 0]
	var sub_counts := [0, 0, 0, 0, 0, 0]
	for e in enemies:
		if e is Boss:
			continue
		lane_counts[e.lane] += 1
		sub_counts[e.lane * SUB_LANE_COUNT + e.sub_lane] += 1
	var lane := _fewest(lane_counts, lane_rotation)
	var sub_base := lane * SUB_LANE_COUNT
	var sub := _fewest([sub_counts[sub_base], sub_counts[sub_base + 1]], sub_rotation)
	for e in enemies:
		if e is Boss:
			continue  # the boss sits above the paths and never occupies a spawn spot
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


## B2: variant chance per Wave, then LIGHT/HEAVY/GUARD by the 40/40/20 weights. Minions
## never roll (B9).
func _roll_variant() -> JamoMonster.Variant:
	if wave_data == null or wave_data.variant_chance <= 0.0:
		return JamoMonster.Variant.NORMAL
	if rng_variant.randf() >= wave_data.variant_chance:
		return JamoMonster.Variant.NORMAL
	var w: Dictionary = db.balance.variant_weights
	var total_w := 0
	for k in w:
		total_w += int(w[k])
	var roll := rng_variant.randi_range(1, total_w)
	for name in ["LIGHT", "HEAVY", "GUARD"]:
		roll -= int(w.get(name, 0))
		if roll <= 0:
			return JamoMonster.Variant[name]
	return JamoMonster.Variant.NORMAL


## GUARD (B2): the foremost OTHER enemy in the guard lane takes 25% less damage; several
## guards never stack. Returns the multiplier for `target`.
func guard_multiplier(target: JamoMonster) -> float:
	if target is Boss:
		return 1.0
	for g in enemies:
		if g == target or g is Boss or not g.alive or g.variant != JamoMonster.Variant.GUARD or g.lane != target.lane:
			continue
		if resolver._lane_front_other(g, enemies) == target:
			return 1.0 - db.balance.guard_damage_reduction
	return 1.0


func _spawn(slot: int, jamo: String, hp: float, travel_time: float, variant: JamoMonster.Variant = JamoMonster.Variant.NORMAL) -> void:
	var m: JamoMonster = MONSTER_SCENE.instantiate()
	var lane := slot / SUB_LANE_COUNT
	var sub := slot % SUB_LANE_COUNT
	m.setup(next_entity_id, jamo, hp, paths[slot], travel_time, lane, sub)
	m.apply_variant(variant, db.balance)
	m.set_motion(_motion_for(jamo), SettingsService.shake_factor())
	RunLog.event("spawn", {"wave": run.wave, "entity": m.entity_id, "jamo": jamo, "variant": m.variant_name(), "lane": lane, "sub": sub, "t": clock})
	next_entity_id += 1
	enemy_root.add_child(m)
	enemies.append(m)
	spawned += 1
	enemies_changed.emit(remaining())


func _motion_for(jamo: String) -> MotionProfile:
	for id in db.motion_profiles:
		if jamo in db.motion_profiles[id].jamo:
			return db.motion_profiles[id]
	return null


## B5 weighted draw on the spawn RNG stream; pinned-and-lacking jamo get x1.15 once.
func _draw_jamo() -> String:
	var weights := db.spawn_weights(risk_unlocked)
	var keys := weights.keys()
	keys.sort()
	var total_w := 0.0
	var scaled := {}
	for k in keys:
		scaled[k] = float(weights[k]) * (db.balance.pin_weight_mult if k in pin_lacking else 1.0)
		total_w += scaled[k]
	var roll := rng_spawn.randf() * total_w
	for k in keys:
		roll -= scaled[k]
		if roll < 0.0:
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
