extends Node
## Headless checks for DeckService / DropService / RewardService (G4, B3, B4) and the
## 자모 정리 screen wiring in run_game.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_deck.json"
	Meta.new_profile()
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_deck()
		_check_drops()
		_check_drop_rate()
		_check_reward()
		_check_controller_budget()
		_check_scene_flow()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_deck: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_deck() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	_expect(deck.size() == 20, "starter deck has 20 tokens")
	_expect(deck.counts() == db.decks["starter_a"].counts(), "token multiset matches DeckData")
	var ids := {}
	for t in deck.tokens:
		ids[t["id"]] = true
	_expect(ids.size() == 20, "token ids are unique")
	var first_id: int = deck.tokens[0]["id"]
	var second_jamo: String = deck.tokens[1]["jamo"]
	_expect(deck.replace_token(first_id, "ㅋ"), "replace swaps a token")
	_expect(deck.size() == 20 and deck.tokens[0]["jamo"] == "ㅋ" and deck.tokens[0]["id"] != first_id, "replace keeps size, new id")
	_expect(deck.tokens[1]["jamo"] == second_jamo, "other tokens untouched")
	_expect(not deck.replace_token(first_id, "ㄱ"), "old id no longer valid")
	var added := 0
	while deck.add_token("ㄱ") >= 0:
		added += 1
	_expect(deck.size() == 26 and added == 6, "add stops at deck max 26 (size %d)" % deck.size())
	var removed := 0
	while deck.remove_token(deck.tokens[0]["id"]):
		removed += 1
	_expect(deck.size() == 14 and removed == 12, "remove stops at deck min 14 (size %d)" % deck.size())
	var kal: WordData = db.words["W08"]
	var fresh := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	_expect(fresh.missing_for(kal) == {"ㅋ": 1}, "missing_for reports the lacking ㅋ for 칼")


func _check_drops() -> void:
	var d := DropService.new()
	d.setup(db.balance, 1)
	d.start_wave()
	d.chance = 0.0
	var results: Array[bool] = []
	for i in range(10):
		results.append(d.roll("ㄱ"))
	_expect(results == ([false, false, false, false, true, false, false, false, false, true] as Array[bool]), "pity: every 5th purify recovers after 4 misses %s" % [results])
	_expect(d.drops.size() == 2 and d.misses == 0, "pity success resets the counter")
	d.start_wave()
	_expect(d.drops.is_empty() and d.misses == 0, "wave start resets drops and pity")
	d.pity_misses = 0  # forces every roll (B4 pity), since chance is capped at 40%
	for i in range(6):
		d.roll("ㅏ")
	_expect(d.drops.size() == 6 and d.is_capped(), "B4 cap of 6 per wave")
	var misses_before := d.misses
	_expect(not d.roll("ㅏ") and d.drops.size() == 6 and d.misses == misses_before, "no judgement after the cap")
	d.add_guaranteed("ㅁ")
	_expect(d.drops.size() == 7, "boss body drop bypasses the cap")
	d.chance = 0.25
	d.bonus = 0.3
	_expect(is_equal_approx(d.effective_chance(), 0.40), "운 bonus capped at 40%")


func _check_drop_rate() -> void:
	var d := DropService.new()
	d.setup(db.balance, 20260911)
	d.pity_misses = 1000000
	d.cap_per_wave = 1000000
	d.start_wave()
	var hits := 0
	for i in range(20000):
		if d.roll("ㄱ"):
			hits += 1
	var rate := hits / 20000.0
	_expect(rate > 0.235 and rate < 0.265, "base drop rate about 25%% (measured %.3f)" % rate)


func _check_reward() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	var r := RewardService.new()
	r.start(deck, ["ㄱ", "ㄴ", "ㄷ"], 1, 0, true)
	_expect(r.picks_left == 1 and r.can_pick(), "normal wave: one pick")
	_expect(not r.can_remove(deck.tokens[0]["id"]), "no remove on a normal wave")
	_expect(r.add(1), "add the second candidate")
	_expect(deck.size() == 21 and deck.counts()["ㄴ"] == 2, "deck grew by the picked ㄴ")
	_expect(r.candidates == (["ㄱ", "ㄷ"] as Array[String]) and not r.can_pick(), "pick spent, candidate consumed")
	_expect(not r.add(0), "no second add")
	r.finish()
	_expect(r.candidates.is_empty() and deck.size() == 21, "unpicked candidates vanish, deck unchanged")
	# First W1: replace forbidden, skip spends the pick.
	var r2 := RewardService.new()
	r2.start(deck, ["ㅁ"], 1, 0, false)
	_expect(not r2.can_replace(0, deck.tokens[0]["id"]) and not r2.replace(0, deck.tokens[0]["id"]), "tutorial W1 forbids 교체")
	_expect(r2.skip() and r2.picks_left == 0 and deck.size() == 21, "skip spends the pick without touching the deck")
	# Boss wave: 2 picks + 1 remove; picks limited by candidates; remove usable with no drops.
	var r3 := RewardService.new()
	r3.start(deck, ["ㅂ"], 2, 1, true)
	_expect(r3.picks_left == 1, "picks limited to candidate count")
	var victim: int = deck.tokens[3]["id"]
	_expect(r3.replace(0, victim) and deck.size() == 21 and not deck.has_token(victim), "replace swaps one token")
	_expect(r3.remove(deck.tokens[0]["id"]) and deck.size() == 20 and r3.removes_left == 0, "remove spends the remove budget")
	_expect(not r3.remove(deck.tokens[0]["id"]), "no second remove")
	var r4 := RewardService.new()
	r4.start(deck, [], 2, 1, true)
	_expect(r4.picks_left == 0 and r4.can_remove(deck.tokens[0]["id"]), "remove allowed even with zero drops")
	var small := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	while small.size() > 14:
		small.remove_token(small.tokens[0]["id"])
	var r5 := RewardService.new()
	r5.start(small, [], 0, 1, true)
	_expect(not r5.can_remove(small.tokens[0]["id"]), "remove blocked at deck min")


func _check_controller_budget() -> void:
	var run := RunController.new()
	run.run_seed = 3
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	_expect(run.deck != null and run.deck.size() == 20, "confirm_setup builds the run deck")
	_expect(not run.on_purified("ㄱ"), "no drop judgement outside COMBAT")
	run.begin_combat()
	run.drops.pity_misses = 0
	_expect(run.on_purified("ㄱ") and run.drops.drops == (["ㄱ"] as Array[String]), "purify in COMBAT rolls a drop")
	run.on_wave_cleared()
	var reward := run.build_reward()
	_expect(reward.picks_left == 1 and reward.removes_left == 0 and not reward.allow_replace, "first W1: 1 pick, no remove, no 교체")
	run.finish_clear()
	run.confirm_build()
	run.begin_combat()
	_expect(run.drops.drops.is_empty(), "drops reset when the next wave starts")
	run.on_purified("ㄴ")
	run.on_wave_cleared()
	_expect(run.build_reward().allow_replace, "W2 allows 교체")
	# Boss wave budget: pretend W5 was just cleared.
	run.finish_clear()
	run.confirm_build()
	run.wave = 5
	run.begin_combat()
	run.on_purified("ㅁ")
	run.on_wave_cleared()
	var boss_reward := run.build_reward()
	_expect(boss_reward.picks_left == 1 and boss_reward.removes_left == 1, "after a boss wave: picks 2 (limited by 1 drop) + 1 remove")
	run.free()


func _check_scene_flow() -> void:
	var game := RUN_GAME.instantiate()
	game.run_seed = 11
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	var hud := game.get_node("HUD")
	var panel := game.get_node("%ClearPanel")
	var w := WaveData.new()
	w.enemy_count = 2
	w.concurrent_max = 2
	w.spawn_interval = 0.1
	w.base_hp = 1.0
	w.travel_time = 14.0
	run.begin_combat()
	director.start_wave(w, 4)
	run.drops.pity_misses = 0
	director.tick(0.0)
	director.tick(0.1)
	var first_jamo: String = director.enemies[0].jamo
	director.request_click(director.enemies[0].global_position)
	director.tick(0.3)
	_expect(run.drops.drops == ([first_jamo] as Array[String]), "purified jamo recovered into the temp store")
	_expect(hud.get_node("%DropsLabel").text == "회수 1", "HUD shows the temp drop count")
	director.request_click(director.enemies[0].global_position)
	director.tick(0.3)
	_expect(run.phase == RunController.Phase.CLEAR and panel.visible, "clear opens the 자모 정리 panel")
	_expect(panel.get_node("%StatsLabel").text.begins_with("정화 2 · 놓침 0 · 안정도 손실 0.0 · 회수 2"), "G10 Wave Clear stats row: %s" % panel.get_node("%StatsLabel").text)
	_expect(run.drops.rng.seed != director.rng_spawn.seed, "B5: drop and spawn RNG streams are seeded independently")
	_expect(panel.reward != null and panel.reward.candidates.size() == 2, "panel shows both recovered jamo")
	_expect(panel.get_node("%ReplaceButton").disabled, "first W1: 교체 button disabled")
	panel.get_node("%AddButton").pressed.emit()
	_expect(run.deck.size() == 21 and panel.reward.picks_left == 0, "add button grows the deck")
	panel.get_node("%FinishButton").pressed.emit()
	_expect(run.phase == RunController.Phase.FORGE, "finish -> FORGE")
	game.queue_free()
