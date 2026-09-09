extends Node

## Headless check for the day loop rules that are easy to break silently.
## Run: godot --headless --path . res://tests/test_game_loop.tscn
## Exit code 0 means every assertion held.
##
## It runs as a scene rather than with --script because the autoload singletons
## are only registered as globals once a scene main loop starts.

var _failures: int = 0


func _ready() -> void:
	_test_starting_stats()
	_test_energy_ends_the_day()
	_test_day_scaling()
	_test_word_completes_and_consumes_jamo()
	_test_bap_needs_two_bieup()
	_test_shared_jamo_is_not_double_spent()
	_test_word_effects_apply()
	_test_upgrade_purchase()
	_test_upgrade_blocked_when_poor()
	_test_candidates_are_useful()
	_test_save_round_trip()

	if _failures == 0:
		print("OK - all game loop checks passed.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % message)


func _close(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.001, "%s (got %f, want %f)" % [message, actual, expected])


## Fresh permanent state, as if the save file did not exist.
func _reset() -> void:
	GameState.day = 1
	GameState.gold = 0.0
	GameState.upgrade_levels.clear()
	GameState.unlocked_word_ids.clear()
	GameState.jamo_inventory.clear()
	GameState.from_dict(GameState.to_dict())
	GameState.begin_day()


func _test_starting_stats() -> void:
	_reset()
	_check(GameState.get_max_energy() == 20, "Day 1 max energy should be 20")
	_check(GameState.energy == 20, "begin_day should fill energy")
	_close(GameState.get_click_damage(), 1.0, "Day 1 click damage")
	_close(GameState.get_gold_multiplier(), 1.0, "Day 1 gold multiplier")
	_check(GameState.get_monster_capacity() == 8, "Day 1 monster capacity should be 8")
	_check(GameState.get_burn_effect() == null, "Burn stays locked until 불 is made")


func _test_energy_ends_the_day() -> void:
	_reset()
	var depleted := [false]
	var handler := func() -> void: depleted[0] = true
	SignalBus.energy_depleted.connect(handler)

	for i in 20:
		_check(GameState.spend_click_energy(), "click %d should be affordable" % i)
	_check(GameState.energy == 0, "20 clicks should drain 20 energy")
	_check(depleted[0], "energy_depleted should fire at zero")
	_check(not GameState.can_click(), "no clicking at zero energy")
	_check(not GameState.spend_click_energy(), "spending past zero must fail")

	SignalBus.energy_depleted.disconnect(handler)


func _test_day_scaling() -> void:
	var balance: GameBalance = GameState.balance
	_close(balance.monster_hp_for_day(1), 3.0, "Day 1 HP")
	_close(balance.monster_gold_for_day(1), 2.0, "Day 1 gold")
	# Doc growth_balance v0.2 section 3: Day 10 lands on 4 HP after rounding.
	_close(balance.monster_hp_for_day(10), 4.0, "Day 10 HP")
	_check(
		absf(balance.monster_gold_for_day(10) - 2.5) < 0.05,
		"Day 10 gold should be about 2.5"
	)


func _test_word_completes_and_consumes_jamo() -> void:
	_reset()
	for jamo in ["ㅂ", "ㅜ", "ㄹ"]:
		GameState.add_jamo(jamo)
	var completed := GameState.complete_ready_words()
	_check(completed.size() == 1, "collecting ㅂㅜㄹ should complete exactly one word")
	_check(completed[0].word == "불", "the completed word should be 불")
	_check(GameState.is_word_unlocked(&"fire_001"), "불 should be unlocked")
	_check(GameState.get_jamo_count("ㅂ") == 0, "completing 불 should consume ㅂ")
	_check(GameState.get_burn_effect() != null, "불 should unlock burn")
	_check(GameState.complete_ready_words().is_empty(), "a word completes only once")


func _test_bap_needs_two_bieup() -> void:
	_reset()
	GameState.add_jamo("ㅂ")
	GameState.add_jamo("ㅏ")
	_check(GameState.complete_ready_words().is_empty(), "밥 needs a second ㅂ")
	GameState.add_jamo("ㅂ")
	var completed := GameState.complete_ready_words()
	_check(completed.size() == 1 and completed[0].word == "밥", "second ㅂ should finish 밥")
	_check(GameState.get_jamo_count("ㅂ") == 0, "밥 should consume both ㅂ")


## 불 and 밥 both need ㅂ. Completing one must not pay for the other.
func _test_shared_jamo_is_not_double_spent() -> void:
	_reset()
	for jamo in ["ㅂ", "ㅜ", "ㄹ", "ㅏ"]:
		GameState.add_jamo(jamo)
	var completed := GameState.complete_ready_words()
	_check(completed.size() == 1, "only 불 should complete on this inventory")
	_check(GameState.get_jamo_count("ㅏ") == 1, "unused ㅏ should stay in the inventory")
	GameState.add_jamo("ㅂ")
	_check(GameState.complete_ready_words().is_empty(), "밥 still needs a second ㅂ")
	GameState.add_jamo("ㅂ")
	var second := GameState.complete_ready_words()
	_check(second.size() == 1 and second[0].word == "밥", "밥 completes with its own two ㅂ")


func _test_word_effects_apply() -> void:
	_reset()
	for jamo in ["ㅎ", "ㅣ", "ㅁ"]:
		GameState.add_jamo(jamo)
	GameState.complete_ready_words()
	_close(GameState.get_click_damage(), 2.0, "힘 adds +1 flat click damage")

	for jamo in ["ㄷ", "ㅗ", "ㄴ"]:
		GameState.add_jamo(jamo)
	GameState.complete_ready_words()
	_close(GameState.get_gold_multiplier(), 1.1, "돈 adds +10% gold")

	for jamo in ["ㅂ", "ㅏ", "ㅂ"]:
		GameState.add_jamo(jamo)
	GameState.complete_ready_words()
	_check(GameState.get_max_energy() == 22, "밥 adds +2 max energy")


func _test_upgrade_purchase() -> void:
	_reset()
	GameState.gold = 50.0
	var upgrade: UpgradeData = GameState.database.find_upgrade(&"max_energy")
	_check(UpgradeManager.purchase(upgrade), "50G should buy max energy Lv.1")
	_check(GameState.get_upgrade_level(&"max_energy") == 1, "level should be 1")
	_check(GameState.get_max_energy() == 21, "max energy should now be 21")
	_close(GameState.gold, 0.0, "the price should be deducted")

	GameState.gold = 100.0
	var damage: UpgradeData = GameState.database.find_upgrade(&"click_damage")
	_check(UpgradeManager.purchase(damage), "100G should buy click damage Lv.1")
	_close(GameState.get_click_damage(), 2.0, "click damage Lv.1 is 2")

	GameState.gold = 100.0
	var gold_bonus: UpgradeData = GameState.database.find_upgrade(&"gold_bonus")
	_check(UpgradeManager.purchase(gold_bonus), "100G should buy gold bonus Lv.1")
	_close(GameState.get_gold_multiplier(), 1.05, "gold bonus Lv.1 is +5%")


func _test_upgrade_blocked_when_poor() -> void:
	_reset()
	GameState.gold = 49.0
	var upgrade: UpgradeData = GameState.database.find_upgrade(&"max_energy")
	_check(
		UpgradeManager.get_availability(upgrade) == UpgradeManager.Availability.TOO_EXPENSIVE,
		"49G is not enough for a 50G upgrade"
	)
	_check(not UpgradeManager.purchase(upgrade), "purchase should be refused")
	_close(GameState.gold, 49.0, "a refused purchase must not spend gold")
	_check(GameState.get_upgrade_level(&"max_energy") == 0, "level must stay at 0")


## Doc v0.3 section 13.4: candidates come from the pool of jamo a craftable
## word still needs, so a pick is never wasted.
func _test_candidates_are_useful() -> void:
	_reset()
	var needed := PackedStringArray(["ㅂ", "ㅜ", "ㄹ", "ㅎ", "ㅣ", "ㅁ", "ㄷ", "ㅗ", "ㄴ", "ㅏ"])
	for _attempt in 50:
		var candidates := CandidateGenerator.generate(2)
		_check(candidates.size() == 2, "two candidates should be offered")
		for jamo: String in candidates:
			_check(needed.has(jamo), "candidate %s should be needed by some word" % jamo)
		_check(candidates[0] != candidates[1], "candidates should be distinct")


func _test_save_round_trip() -> void:
	_reset()
	GameState.day = 7
	GameState.gold = 1234.5
	GameState.upgrade_levels[&"max_energy"] = 3
	GameState.unlocked_word_ids.append(&"fire_001")
	GameState.jamo_inventory["ㅏ"] = 2

	_check(SaveManager.save_game(), "save should succeed")
	GameState.day = 1
	GameState.gold = 0.0
	GameState.upgrade_levels.clear()
	GameState.unlocked_word_ids.clear()
	GameState.jamo_inventory.clear()

	_check(SaveManager.load_game(), "load should succeed")
	_check(GameState.day == 7, "day should survive the round trip")
	_close(GameState.gold, 1234.5, "gold should survive the round trip")
	_check(GameState.get_upgrade_level(&"max_energy") == 3, "upgrade level should persist")
	_check(GameState.is_word_unlocked(&"fire_001"), "unlocked word should persist")
	_check(GameState.get_jamo_count("ㅏ") == 2, "jamo inventory should persist")
	_check(GameState.get_burn_effect() != null, "loaded words should reapply their effects")

	SaveManager.delete_save()
