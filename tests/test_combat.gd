extends Node
## Headless P0 acceptance for W1 combat (G3/G7/G11, B1/B2/B11): coordinates, overlap
## resolution, cooldown, purify-once, reach-once, spacing, blocked spawns, clear/defeat order.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const SUB_LEN := 484.379  # sqrt(65^2 + 480^2)

var failures: Array[String] = []
var game: Node
var run: RunController
var director: CombatDirector
var db: ContentDB
# Lambdas capture locals by value, so signal counters must be members.
var purified_count := 0
var reached_count := 0


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_combat.json"
	Meta.new_profile()
	RunLog.enabled = false  # tests never leave run logs behind unless they test the logger
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_spawn_layout()
		_check_targeting_and_cooldown()
		_check_purify_and_reach_once()
		_check_spacing_and_blocked_spawn()
		_check_clear_and_defeat_order()
		_check_all_missed_still_ends()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_combat: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Boots run_game into COMBAT of W1 with manual ticking (physics process disabled).
func _boot(seed: int = 7) -> void:
	if game != null:
		game.free()
	game = RUN_GAME.instantiate()
	game.run_seed = seed
	game.set_physics_process(false)
	add_child(game)
	run = game.get_node("RunController")
	director = game.get_node("CombatDirector")
	run.begin_combat()


func _wave(count: int, concurrent: int, interval: float, hp: float, travel: float) -> WaveData:
	var w := WaveData.new()
	w.wave = 1
	w.enemy_count = count
	w.concurrent_max = concurrent
	w.spawn_interval = interval
	w.base_hp = hp
	w.travel_time = travel
	return w


func _check_spawn_layout() -> void:
	_boot()
	_expect(director.active and director.total == 8 and director.remaining() == 8, "W1 starts with 8 to spawn")
	director.tick(0.0)
	_expect(director.spawned == 1 and director.enemies.size() == 1, "first spawn at t=0")
	var e1: JamoMonster = director.enemies[0]
	_expect(e1.entity_id == 1 and e1.lane == 0 and e1.sub_lane == 0, "first enemy L_A")
	_expect(e1.global_position.is_equal_approx(Vector2(415, 370)), "first enemy at L_A start %s" % e1.global_position)
	_expect(absf(e1.path_length - SUB_LEN) < 0.5, "sub path length %s" % e1.path_length)
	_expect(absf(e1.speed() - SUB_LEN / 14.0) < 0.01, "B2 W1 travel 14s -> speed %s" % e1.speed())
	_expect(db.spawn_weights(false).has(e1.jamo), "spawned jamo %s is in the B5 pool" % e1.jamo)
	director.tick(1.7)
	_expect(director.spawned == 1, "no spawn before the 1.8s interval")
	director.tick(0.1)
	_expect(director.spawned == 2 and director.enemies[1].lane == 1 and director.enemies[1].sub_lane == 1, "second spawn C_B (fewest lane, rotating tie)")
	director.tick(1.8)
	_expect(director.spawned == 3 and director.enemies[2].lane == 2 and director.enemies[2].sub_lane == 0, "third spawn R_A")
	director.tick(1.8)
	_expect(director.spawned == 4 and director.enemies[3].lane == 0 and director.enemies[3].sub_lane == 1, "fourth spawn L_B (empty sub path first)")
	director.tick(1.8)
	_expect(director.spawned == 4 and director.enemies.size() == 4, "B2 concurrent cap 4 holds the fifth spawn")
	_expect(director.remaining() == 8, "remaining counts living + unspawned")
	var e2: JamoMonster = director.enemies[1]
	_expect(e1.progress > e2.progress and e1.eta() < e2.eta(), "earlier spawn is further along")
	_expect(director.cycle_focus() == e1 and e1.focused, "Tab focuses the enemy with the shortest ETA")
	_expect(director.cycle_focus() == e2, "Tab cycles to the next ETA")


func _check_targeting_and_cooldown() -> void:
	_boot()
	director.tick(0.0)
	var e1: JamoMonster = director.enemies[0]
	var p := e1.global_position
	var layer := game.get_node_or_null("BattleClip/Battle3D")
	_expect(layer != null and layer.is_in_group("battle3d"), "Battle3D layer instanced under run_game")
	for e in director.enemies:
		var has_model := CharacterProxy.model_for(e.jamo) != null
		_expect((e.proxy != null) == has_model, "3D proxy iff a model exists (%s)" % e.jamo)
		if e.proxy != null:
			_expect(not e.visual_pivot.visible and e.proxy.is_inside_tree(), "2D visual hidden behind the 3D figure (%s)" % e.jamo)
	_expect(director.pick_target(p + Vector2(45, 0)) == e1, "click inside the 92px circle hits")
	_expect(director.pick_target(p + Vector2(47, 0)) == null, "click outside the 92px circle misses")
	director.request_click(Vector2(100, 100))
	_expect(director.miss_clicks == 1 and director.pending_target == null, "empty click is only a miss statistic")
	director.request_click(p)
	director.tick(0.016)
	_expect(e1.hp == 1.0 and director.stats["hits"] == 1, "B1 manual damage 1.0 (hp %s)" % e1.hp)
	director.request_click(p)
	director.tick(0.016)
	_expect(e1.hp == 1.0, "second click inside 0.25s cooldown ignored")
	director.request_click(Vector2(100, 100))
	director.tick(0.3)
	_expect(e1.hp == 1.0 and director.miss_clicks == 2, "miss does not attack")
	director.set_hold(true)
	director.tick(0.016, p)
	_expect(e1.hp == 0.0 and director.stats["hits"] == 2, "hold attacks once cooldown is ready")
	director.tick(0.016, p)
	# purified in that tick: gold once
	_expect(director.stats["purified"] == 1 and run.gold_run == 1.0, "purify pays 1G once (gold %s)" % run.gold_run)
	director.set_hold(false)
	# Overlap: nearest centre, tie -> lower entity_id.
	director.tick(1.8)
	director.tick(1.8)
	var a: JamoMonster = director.enemies[0]
	var b: JamoMonster = director.enemies[1]
	a.global_position = Vector2(500, 500)
	b.global_position = Vector2(520, 500)
	_expect(director.pick_target(Vector2(512, 500)) == b, "nearest centre wins overlap")
	_expect(director.pick_target(Vector2(510, 500)) == a, "tie goes to the lower entity_id")
	director.cycle_focus()
	director.request_keyboard_attack()
	director.tick(0.3)
	_expect(director.stats["hits"] == 3, "Space attacks the focused enemy through the same cooldown")


func _check_purify_and_reach_once() -> void:
	_boot()
	director.tick(0.0)
	var e1: JamoMonster = director.enemies[0]
	purified_count = 0
	director.enemy_purified.connect(func(_m, _s): purified_count += 1)
	_expect(e1.take_damage(5.0) == 2.0 and e1.take_damage(5.0) == 0.0, "damage caps at remaining hp")
	director.tick(0.016)
	director.tick(0.016)
	_expect(purified_count == 1 and run.gold_run == 1.0 and director.stats["purified"] == 1, "purify bookkeeping runs once")
	_expect(not e1.alive and director.enemies.is_empty(), "purified enemy leaves the target list")
	director.tick(1.8)
	var e2: JamoMonster = director.enemies[0]
	reached_count = 0
	director.enemy_reached.connect(func(_m): reached_count += 1)
	e2.progress = e2.path_length - 0.5
	var gold_before := run.gold_run
	director.tick(0.1)
	_expect(reached_count == 1 and director.stats["reached"] == 1, "reach reported once")
	_expect(run.stability == 92.0, "B1 reach damage 8 (stability %s)" % run.stability)
	_expect(run.gold_run == gold_before and not e2.alive and director.enemies.is_empty(), "reached enemy gives no gold and exits")
	_expect(director.remaining() == 6, "reached enemy no longer counts as remaining")
	director.tick(0.1)
	_expect(run.stability == 92.0 and reached_count == 1, "no second reach for the same entity")


func _check_spacing_and_blocked_spawn() -> void:
	_boot()
	var w := _wave(8, 8, 0.1, 2.0, 14.0)
	director.start_wave(w, 3)
	for i in range(6):
		director.tick(0.1)
	_expect(director.spawned == 6, "six spawns fill every sub path once (got %d)" % director.spawned)
	var slots := []
	for e in director.enemies:
		slots.append(e.lane * 2 + e.sub_lane)
	slots.sort()
	_expect(slots == [0, 1, 2, 3, 4, 5], "each sub path used once %s" % [slots])
	director.tick(0.1)
	_expect(director.spawned == 6, "seventh spawn held while L_A start is occupied (< 92px)")
	var total_time := 0.7
	while total_time < 2.55:
		director.tick(0.1)
		total_time += 0.1
	_expect(director.spawned == 6, "still held while the first enemy is under 92px (spawned %d)" % director.spawned)
	director.tick(0.1)
	director.tick(0.1)
	_expect(director.spawned >= 7, "held spawn resumes once the spot clears (spawned %d)" % director.spawned)
	# Follower never overtakes or moves backwards.
	var leader: JamoMonster = director.enemies[0]
	var follower: JamoMonster = director.enemies[6]
	_expect(leader.lane == follower.lane and leader.sub_lane == follower.sub_lane, "seventh shares L_A with the first")
	leader.progress = 100.0
	follower.progress = 50.0
	director.tick(1.0)
	_expect(is_equal_approx(follower.progress, 50.0), "follower waits instead of moving back (%s)" % follower.progress)
	_expect(leader.progress > 100.0, "leader keeps moving")
	leader.progress = 300.0
	follower.progress = 50.0
	director.tick(1.0)
	_expect(follower.progress > 50.0 and leader.progress - follower.progress >= 92.0, "spacing >= 92px kept")


func _check_clear_and_defeat_order() -> void:
	_boot()
	var w := _wave(2, 2, 0.1, 1.0, 14.0)
	director.start_wave(w, 5)
	director.tick(0.0)
	director.tick(0.1)
	_expect(director.enemies.size() == 2, "two enemies up")
	director.request_click(director.enemies[0].global_position)
	director.tick(0.3)
	director.request_click(director.enemies[0].global_position)
	director.tick(0.3)
	_expect(run.phase == RunController.Phase.CLEAR and get_tree().paused, "last purify -> CLEAR and clock stops")
	_expect(run.gold_run == 2.0 and run.stability == 100.0, "2G, clear heal capped")
	# Defeat wins over clear when the final reach empties stability (G7).
	_boot()
	director.start_wave(w, 5)
	director.tick(0.0)
	director.tick(0.1)
	run.damage_stability(92.0)
	for e in director.enemies:
		e.progress = e.path_length - 0.5
	director.tick(0.1)
	_expect(run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.FAILED, "depletion beats clear")
	_expect(director.enemies.size() <= 1, "processing stops after defeat")


func _check_all_missed_still_ends() -> void:
	_boot()
	var w := _wave(3, 3, 0.1, 1.0, 14.0)
	director.start_wave(w, 9)
	for i in range(3):
		director.tick(0.1)
	for e in director.enemies:
		e.progress = e.path_length - 0.5
	director.tick(0.1)
	_expect(run.phase == RunController.Phase.CLEAR, "wave ends when every enemy reached")
	_expect(run.gold_run == 0.0 and run.stability == 80.0, "no gold, 3 x 8 damage then +4 heal (stability %s)" % run.stability)
	game.free()
	game = null
