extends Node

## Headless check for the day loop rules that are easy to break silently.
## Run: godot --headless --path . res://tests/test_game_loop.tscn
## Exit code 0 means every assertion held.
##
## It runs as a scene rather than with --script because the autoload singletons
## are only registered as globals once a scene main loop starts.

const CHOICE_SCENE := "res://scenes/ui/jamo_choice.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"

var _failures: int = 0


func _ready() -> void:
	_test_starting_stats()
	_test_energy_ends_the_day()
	_test_day_scaling()
	_test_word_completes_and_consumes_jamo()
	_test_bap_needs_two_bieup()
	_test_shared_jamo_is_not_double_spent()
	_test_word_effects_apply()
	_test_prerequisites_gate_words()
	_test_hwayeom_raises_burn_tick()
	_test_bulkkot_spread_data()
	_test_bulkkot_spreads_burn_on_death()
	_test_gangta_adds_crit_chance()
	_test_geum_unlocks_golden()
	_test_chelyeok_adds_energy()
	_test_un_boosts_special_spawn()
	_test_database_holds_ten_words()
	_test_hud_lists_every_craftable_word()
	_test_upgrade_purchase()
	_test_upgrade_blocked_when_poor()
	_test_critical_click()
	_test_candidates_are_useful()
	_test_reroll_upgrade_gates()
	_test_reroll_charges_and_blocks()
	_test_reroll_redraws_candidates()
	_test_reroll_panel_states()
	_test_save_round_trip()
	_test_reroll_save_round_trip()

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


## Doc v0.3 section 10.2 and growth_balance v0.2 sections 8.3 and 13: one shared
## crit system, gated behind Day 25 AND 클릭 피해 Lv.3.
func _test_critical_click() -> void:
	_reset()
	var critical: UpgradeData = GameState.database.find_upgrade(&"critical_click")
	_check(critical != null, "critical_click should be registered in the database")
	if critical == null:
		return

	_close(GameState.get_crit_chance(), 0.0, "crit chance starts at 0")
	_close(GameState.get_crit_multiplier(), 2.0, "base crit multiplier is 2.0")
	_check(not GameState.roll_critical(), "a 0% chance must never roll critical")
	# growth_balance v0.2 section 13 puts 치명 클릭 on Day 25 and section 8.3
	# behind 클릭 피해 Lv.3. Both conditions must hold, so either one alone
	# still leaves the track locked.
	_check(critical.unlock_day == 25, "치명 클릭 unlocks on Day 25")
	_check(
		UpgradeManager.get_availability(critical)
			== UpgradeManager.Availability.LOCKED_BY_DAY,
		"치명 클릭 stays locked before Day 25"
	)
	_check(not UpgradeManager.is_visible(critical), "a day-locked track is not listed")

	var damage: UpgradeData = GameState.database.find_upgrade(&"click_damage")
	GameState.gold = 10000.0
	for _level in 3:
		_check(UpgradeManager.purchase(damage), "클릭 피해 should be affordable")
	_check(
		UpgradeManager.get_availability(critical)
			== UpgradeManager.Availability.LOCKED_BY_DAY,
		"클릭 피해 Lv.3 alone does not unlock 치명 클릭 before Day 25"
	)

	GameState.day = 25
	GameState.upgrade_levels[&"click_damage"] = 0
	_check(
		UpgradeManager.get_availability(critical)
			== UpgradeManager.Availability.LOCKED_BY_UPGRADE,
		"Day 25 alone does not unlock 치명 클릭 below 클릭 피해 Lv.3"
	)
	_check(
		UpgradeManager.is_visible(critical),
		"a requirement-locked track stays listed so the shop can name the reason"
	)

	GameState.upgrade_levels[&"click_damage"] = 3
	_check(UpgradeManager.is_visible(critical), "Day 25 + 클릭 피해 Lv.3 unlocks 치명 클릭")

	GameState.gold = 1500.0
	_check(UpgradeManager.purchase(critical), "1500G should buy 치명 클릭 Lv.1")
	_close(GameState.get_crit_chance(), 0.02, "치명 클릭 Lv.1 is 2%")
	_check(critical.format_value(1, 0.0) == "2%", "the shop should show 2%")

	# FinalClickDamage = normal * CriticalMultiplier, one roll per click.
	var normal: float = GameState.get_click_damage()
	_close(normal, 4.0, "클릭 피해 Lv.3 deals 4")
	_close(GameState.get_click_damage(true), normal * 2.0, "a crit doubles the hit")

	# A guaranteed chance proves the roll actually reads the summed chance.
	GameState.upgrade_levels[&"critical_click"] = critical.max_level()
	_close(GameState.get_crit_chance(), 0.1, "치명 클릭 Lv.5 is 10%")


## Doc v0.3 section 13.4: candidates come from the pool of jamo a craftable
## word still needs, so a pick is never wasted.
func _test_candidates_are_useful() -> void:
	_reset()
	var needed := _craftable_jamo()
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
	GameState.upgrade_levels[&"critical_click"] = 2
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
	_check(
		GameState.get_upgrade_level(&"critical_click") == 2,
		"치명 클릭 level should persist"
	)
	_close(GameState.get_crit_chance(), 0.04, "a loaded save restores the crit chance")
	_check(GameState.is_word_unlocked(&"fire_001"), "unlocked word should persist")
	_check(GameState.get_jamo_count("ㅏ") == 2, "jamo inventory should persist")
	_check(GameState.get_burn_effect() != null, "loaded words should reapply their effects")

	SaveManager.delete_save()


## growth_balance v0.2 section 10.2: 리롤 unlocks on Day 5 and each further
## level has its own day, so a rich player still waits for Day 25 / Day 60.
func _test_reroll_upgrade_gates() -> void:
	_reset()
	var reroll: UpgradeData = GameState.database.find_upgrade(&"reroll")
	_check(reroll != null, "reroll should be registered in the database")
	if reroll == null:
		return
	_check(reroll.format_value(1, 0.0) == "1 회", "the shop should show 1 회")

	GameState.gold = 100000.0
	_check(
		UpgradeManager.get_availability(reroll)
			== UpgradeManager.Availability.LOCKED_BY_DAY,
		"리롤 stays locked before Day 5"
	)
	_check(not UpgradeManager.is_visible(reroll), "a day-locked track is not listed")
	_check(not UpgradeManager.purchase(reroll), "buying before Day 5 must fail")

	GameState.day = 5
	GameState.gold = 999.0
	_check(
		UpgradeManager.get_availability(reroll)
			== UpgradeManager.Availability.TOO_EXPENSIVE,
		"999G is not enough for the 1,000G Lv.1"
	)
	GameState.gold = 1000.0
	_check(UpgradeManager.purchase(reroll), "Day 5 + 1,000G buys 리롤 Lv.1")
	_check(GameState.get_max_rerolls() == 1, "리롤 Lv.1 grants 1 reroll per day")

	GameState.gold = 100000.0
	_check(
		UpgradeManager.get_availability(reroll)
			== UpgradeManager.Availability.LOCKED_BY_NEXT_DAY,
		"Lv.2 waits for Day 25 no matter how much gold is held"
	)
	_check(UpgradeManager.is_visible(reroll), "an owned track stays listed")
	_check(not UpgradeManager.purchase(reroll), "buying Lv.2 before Day 25 must fail")
	_close(GameState.gold, 100000.0, "a refused purchase must not spend gold")

	GameState.day = 25
	_check(UpgradeManager.purchase(reroll), "Day 25 + 7,500G buys 리롤 Lv.2")
	_check(GameState.get_max_rerolls() == 2, "리롤 Lv.2 grants 2 rerolls per day")
	_check(
		UpgradeManager.get_availability(reroll)
			== UpgradeManager.Availability.LOCKED_BY_NEXT_DAY,
		"Lv.3 waits for Day 60"
	)
	GameState.day = 60
	_check(UpgradeManager.purchase(reroll), "Day 60 + 50,000G buys 리롤 Lv.3")
	_check(GameState.get_max_rerolls() == 3, "리롤 Lv.3 grants 3 rerolls per day")
	_check(
		UpgradeManager.get_availability(reroll) == UpgradeManager.Availability.MAXED,
		"리롤 tops out at Lv.3"
	)

	# The existing tracks must not have gained a per-level day gate.
	var energy: UpgradeData = GameState.database.find_upgrade(&"max_energy")
	_check(
		energy.unlock_day_for_level(3) == energy.unlock_day,
		"a track without a per-level table keeps one shared unlock day"
	)


## The count is a per-day allowance: begin_day refills it, spending drains it,
## and zero blocks further rerolls.
func _test_reroll_charges_and_blocks() -> void:
	_reset()
	_check(GameState.get_max_rerolls() == 0, "a locked 리롤 grants no rerolls")
	_check(GameState.rerolls_left == 0, "Day 1 starts with no rerolls")
	_check(not GameState.can_reroll(), "a locked 리롤 cannot be used")
	_check(not GameState.consume_reroll(), "spending a reroll at 0 must fail")

	GameState.day = 25
	GameState.upgrade_levels[&"reroll"] = 2
	_check(GameState.rerolls_left == 0, "buying does not refill the current day")
	GameState.begin_day()
	_check(GameState.rerolls_left == 2, "day start recharges to the maximum")

	_check(GameState.consume_reroll(), "the first reroll should go through")
	_check(GameState.rerolls_left == 1, "one reroll should be spent")
	_check(GameState.consume_reroll(), "the second reroll should go through")
	_check(GameState.rerolls_left == 0, "both rerolls should be spent")
	_check(not GameState.can_reroll(), "no rerolls left today")
	_check(not GameState.consume_reroll(), "a third reroll must be refused")
	_check(GameState.rerolls_left == 0, "a refused reroll must not go negative")

	GameState.advance_day()
	_check(GameState.rerolls_left == 2, "the next day recharges again")


## Doc v0.3 section 13.4: a reroll redraws from the same weighted pools, just
## without the hand it replaces.
func _test_reroll_redraws_candidates() -> void:
	_reset()
	var needed := _craftable_jamo()
	for _attempt in 50:
		var first := CandidateGenerator.generate(2)
		var second := CandidateGenerator.regenerate(2, first)
		_check(second.size() == 2, "a reroll should still offer two candidates")
		_check(second[0] != second[1], "rerolled candidates should be distinct")
		for jamo: String in second:
			_check(needed.has(jamo), "rerolled %s should still be a needed jamo" % jamo)
			_check(not first.has(jamo), "a reroll should avoid the previous hand")

	# Edge case: only 밥 is left to craft, so the pool is exactly ㅂ and ㅏ and
	# the reroll has to hand back the same two rather than return an empty hand.
	# Every other word is unlocked; the tier-2 words behind 밥 stay locked
	# because their prerequisite is the one word still missing.
	for word: WordData in GameState.database.words:
		if word.id != &"energy_001" and word.id != &"energy_002":
			GameState.unlocked_word_ids.append(word.id)
	var small := CandidateGenerator.generate(2)
	_check(small.size() == 2, "the two-jamo pool should still fill a hand")
	var rerolled := CandidateGenerator.regenerate(2, small)
	_check(rerolled.size() == 2, "a pool too small to avoid repeats must still fill")
	_check(rerolled[0] != rerolled[1], "the hand stays distinct even when repeated")


## An old save has no reroll key, so it must start the day fully charged rather
## than stuck at zero.
func _test_reroll_save_round_trip() -> void:
	_reset()
	GameState.day = 25
	GameState.upgrade_levels[&"reroll"] = 2
	GameState.begin_day()
	_check(GameState.consume_reroll(), "spend one reroll before saving")
	_check(SaveManager.save_game(), "save should succeed")

	GameState.rerolls_left = 0
	GameState.upgrade_levels.clear()
	_check(SaveManager.load_game(), "load should succeed")
	_check(GameState.get_max_rerolls() == 2, "리롤 Lv.2 should persist")
	_check(GameState.rerolls_left == 1, "the remaining reroll should survive")

	var legacy: Dictionary = GameState.to_dict()
	legacy.erase("rerolls_left")
	GameState.from_dict(legacy)
	_check(GameState.rerolls_left == 2, "a save without the key starts fully charged")

	SaveManager.delete_save()


## The reroll control in jamo_choice.tscn: hidden while locked, disabled with a
## written reason once the day is spent, and dead after the pick is confirmed.
func _test_reroll_panel_states() -> void:
	_reset()
	var panel: Control = (load(CHOICE_SCENE) as PackedScene).instantiate()
	add_child(panel)

	var row: Control = panel.get_node("%RerollRow")
	var button: Button = panel.get_node("%RerollButton")
	var count_label: Label = panel.get_node("%RerollCountLabel")

	panel.open()
	_check(not row.visible, "the reroll row stays hidden while 리롤 is locked")

	GameState.day = 5
	GameState.upgrade_levels[&"reroll"] = 1
	GameState.begin_day()
	panel.open()
	_check(row.visible, "buying 리롤 shows the reroll row")
	_check(not button.disabled, "one charge means the button is usable")
	_check(button.focus_mode != Control.FOCUS_NONE, "the button must be focusable")
	_check(count_label.text.begins_with("리롤 1/1"), "the count should read 리롤 1/1")

	var before: String = panel.get_node("%Card0").jamo
	button.pressed.emit()
	_check(GameState.rerolls_left == 0, "pressing reroll spends the day's charge")
	_check(panel.get_node("%Card0").jamo != before, "the candidates should change")
	_check(button.disabled, "a spent reroll disables the button")
	_check(
		count_label.text.contains("모두 썼습니다"),
		"the reason must be readable as text, not signalled by colour"
	)

	# Pressing a disabled button is impossible in the UI, but the guard must
	# hold anyway so the count can never go negative.
	button.pressed.emit()
	_check(GameState.rerolls_left == 0, "a refused reroll must not go negative")

	# Confirming the pick closes the panel, which is what makes the pick final.
	GameState.begin_day()
	panel.open()
	panel.get_node("%Card0").get_node("%CardButton").pressed.emit()
	_check(not panel.visible, "choosing a card closes the panel")
	var picked_hand: String = panel.get_node("%Card0").jamo
	button.pressed.emit()
	_check(GameState.rerolls_left == 1, "no reroll may be spent after the pick")
	_check(panel.get_node("%Card0").jamo == picked_hand, "the confirmed hand must not change")

	panel.queue_free()


# --- F3 tier-2 words -------------------------------------------------------

const MONSTER_SCENE := "res://scenes/monsters/monster_mieum.tscn"


## Every jamo some currently craftable word still needs, which is exactly the
## pool CandidateGenerator draws from. Derived rather than written out, so
## adding a word does not silently invalidate the check.
func _craftable_jamo() -> PackedStringArray:
	var pool := PackedStringArray()
	for word: WordData in GameState.get_craftable_words():
		for jamo: String in word.required_jamo:
			if not pool.has(jamo):
				pool.append(jamo)
	return pool


## Unlocks words by id without going through the jamo inventory, then refreshes
## the cached bonuses the way a load would.
func _unlock(word_ids: Array) -> void:
	for word_id: StringName in word_ids:
		if not GameState.unlocked_word_ids.has(word_id):
			GameState.unlocked_word_ids.append(word_id)
	GameState.from_dict(GameState.to_dict())


func _grant(jamo_list: Array) -> void:
	for jamo: String in jamo_list:
		GameState.add_jamo(jamo)


func _is_burning(monster: JamoMonster) -> bool:
	var container: StatusEffectContainer = monster.get_node("StatusEffects")
	return container.has(WordEffectData.EffectType.UNLOCK_BURN)


## Doc word_tree v0.1 section 15: a tier-2 word is uncraftable, and its jamo are
## not even offered, until its prerequisite word is unlocked.
func _test_prerequisites_gate_words() -> void:
	_reset()
	var hwayeom: WordData = GameState.database.find_word(&"fire_002")
	_check(hwayeom != null, "화염 should be registered in the database")
	if hwayeom == null:
		return
	_check(
		hwayeom.prerequisites.has(&"fire_001"),
		"화염 should list 불 as its prerequisite"
	)
	_check(not GameState.are_prerequisites_met(hwayeom), "불 is not unlocked yet")

	_grant(["ㅎ", "ㅗ", "ㅏ", "ㅇ", "ㅕ", "ㅁ"])
	_check(
		GameState.complete_ready_words().is_empty(),
		"a full 화염 inventory must not complete it while 불 is locked"
	)
	_check(not GameState.is_word_unlocked(&"fire_002"), "화염 should still be locked")
	for word: WordData in GameState.get_craftable_words():
		_check(
			word.id != &"fire_002",
			"a word with an unmet prerequisite must not be craftable"
		)

	# ㅕ, ㅊ, ㅌ and ㅡ are only needed by words that are still gated, so the
	# candidate pool must never offer them.
	var gated := PackedStringArray(["ㅕ", "ㅊ", "ㅌ", "ㅡ"])
	for _attempt in 50:
		for jamo: String in CandidateGenerator.generate(2):
			_check(
				not gated.has(jamo),
				"%s belongs to a gated word and must not be offered" % jamo
			)

	# Unlocking 불 opens 화염, and the jamo already held finish it at once.
	_grant(["ㅂ", "ㅜ", "ㄹ"])
	var completed_words := PackedStringArray()
	for word: WordData in GameState.complete_ready_words():
		completed_words.append(word.word)
	_check(completed_words.has("불"), "불 should complete")
	_check(
		completed_words.has("화염"),
		"화염 should complete in the same batch once 불 unlocks it"
	)


## 화염: burn tick damage 1 -> 2, added on top of the 불 effect rather than
## replacing it. Doc v0.3 section 15.1.
func _test_hwayeom_raises_burn_tick() -> void:
	_reset()
	_unlock([&"fire_001"])
	_close(GameState.get_burn_effect().base_value, 1.0, "불 alone ticks for 1")

	_unlock([&"fire_002"])
	_close(GameState.get_burn_effect().base_value, 2.0, "화염 raises the tick to 2")
	_close(
		GameState.get_burn_effect().duration, 3.0,
		"화염 must leave the burn duration alone"
	)
	# The bonus is applied to a copy: mutating the shared .tres would make the
	# tick grow again on every recalculation.
	var source: WordData = GameState.database.find_word(&"fire_001")
	_close(source.effects[0].base_value, 1.0, "the 불 resource must not be mutated")
	GameState.from_dict(GameState.to_dict())
	_close(
		GameState.get_burn_effect().base_value, 2.0,
		"recalculating must not stack the bonus a second time"
	)


## 불꽃 carries its radius and target count as data, not as constants in code.
func _test_bulkkot_spread_data() -> void:
	_reset()
	_check(GameState.get_burn_spread_effect() == null, "불꽃 starts locked")
	_unlock([&"fire_001", &"fire_003"])
	var spread: WordEffectData = GameState.get_burn_spread_effect()
	_check(spread != null, "불꽃 should expose a spread effect")
	if spread == null:
		return
	_check(spread.radius > 0.0, "the spread radius must come from the .tres")
	_check(spread.chain_count == 1, "불꽃 spreads to one neighbour")
	_check(spread.max_chain_depth == 1, "a spread burn must not spread again")


## The behaviour itself: a monster that dies burning hands its burn to the
## nearest neighbour inside the radius, and that second burn does not chain on.
func _test_bulkkot_spreads_burn_on_death() -> void:
	_reset()
	_unlock([&"fire_001", &"fire_003"])
	var spread: WordEffectData = GameState.get_burn_spread_effect()
	if spread == null:
		return

	var scene: PackedScene = load(MONSTER_SCENE)
	var spawner := SpawnManager.new()
	var root := Node3D.new()
	spawner.spawn_root = root
	# A non-empty pool keeps _ready quiet; the refill loop itself is off so the
	# test controls exactly which monsters are on the field.
	spawner.monster_scenes = [scene]
	add_child(spawner)
	spawner.add_child(root)
	spawner.set_process(false)

	var monsters: Array[JamoMonster] = []
	for i in 3:
		var monster: JamoMonster = scene.instantiate()
		root.add_child(monster)
		# In a line, each one a third of the radius from the last, so every
		# monster has a neighbour in range but the far one is never nearest.
		monster.global_position = Vector3(float(i) * spread.radius * 0.3, 0.0, 0.0)
		monster.died.connect(spawner._on_monster_died)
		spawner._alive.append(monster)
		monsters.append(monster)

	var burn: WordEffectData = GameState.get_burn_effect()
	monsters[0].apply_status_effect(burn)
	_check(_is_burning(monsters[0]), "the clicked monster should be burning")
	_check(not _is_burning(monsters[1]), "the neighbour should not be burning yet")

	monsters[0].take_status_damage(9999.0)
	_check(not monsters[0].is_alive(), "enough damage should kill the monster")
	_check(_is_burning(monsters[1]), "the burn should spread to the nearest neighbour")
	_check(
		monsters[1].burn_chain_depth == 1,
		"a spread burn should be marked as one hop deep"
	)

	# The safety net: the second death must not start a third fire.
	monsters[1].take_status_damage(9999.0)
	_check(
		not _is_burning(monsters[2]),
		"a burn that already spread once must not spread again"
	)

	# A fresh click resets the depth, so the player can restart the chain.
	monsters[2].apply_status_effect(burn)
	_check(monsters[2].burn_chain_depth == 0, "a clicked burn starts at depth 0")

	spawner.queue_free()


## 강타: +10%p on the one shared critical roll, never a second roll.
## Doc v0.3 section 10.2.
func _test_gangta_adds_crit_chance() -> void:
	_reset()
	_unlock([&"power_001"])
	_close(GameState.get_crit_chance(), 0.0, "힘 alone grants no crit chance")

	_unlock([&"power_002"])
	_close(GameState.get_crit_chance(), 0.1, "강타 grants +10%p crit chance")
	_check(
		GameState.get_click_damage(true) > GameState.get_click_damage(),
		"a critical hit still multiplies the same click damage"
	)

	# The gold track and the word add into one chance rather than rolling twice.
	GameState.day = 25
	GameState.upgrade_levels[&"click_damage"] = 3
	GameState.upgrade_levels[&"critical_click"] = 5
	_close(
		GameState.get_crit_chance(), 0.2,
		"치명 클릭 Lv.5 and 강타 sum into a single 20% chance"
	)


## 금 only reports that golden monsters are unlocked; the spawn itself is F4.
func _test_geum_unlocks_golden() -> void:
	_reset()
	_check(not GameState.is_golden_monster_unlocked(), "golden starts locked")
	_unlock([&"gold_001"])
	_check(not GameState.is_golden_monster_unlocked(), "돈 alone does not unlock it")
	_unlock([&"gold_002"])
	_check(GameState.is_golden_monster_unlocked(), "금 unlocks golden monsters")

	_check(SaveManager.save_game(), "save should succeed")
	GameState.unlocked_word_ids.clear()
	GameState.from_dict(GameState.to_dict())
	_check(not GameState.is_golden_monster_unlocked(), "clearing words relocks it")
	_check(SaveManager.load_game(), "load should succeed")
	_check(
		GameState.is_golden_monster_unlocked(),
		"the golden unlock should survive a save round trip"
	)
	SaveManager.delete_save()


## 체력: +3 max energy on top of the +2 from 밥. Doc word_tree v0.1 section 10.
func _test_chelyeok_adds_energy() -> void:
	_reset()
	_unlock([&"energy_001"])
	_check(GameState.get_max_energy() == 22, "밥 alone gives 22 max energy")
	_unlock([&"energy_002"])
	_check(GameState.get_max_energy() == 25, "체력 adds a further +3")
	GameState.begin_day()
	_check(GameState.energy == 25, "the new maximum is what the day refills to")


## 운: a multiplier the special monster spawn will read in F4.
func _test_un_boosts_special_spawn() -> void:
	_reset()
	_close(
		GameState.get_special_spawn_multiplier(), 1.0,
		"the special spawn multiplier starts neutral"
	)
	var un: WordData = GameState.database.find_word(&"luck_001")
	_check(un != null, "운 should be registered in the database")
	if un == null:
		return
	_check(un.prerequisites.is_empty(), "운 opens a new root with no prerequisite")
	_unlock([&"luck_001"])
	_close(
		GameState.get_special_spawn_multiplier(), 1.05,
		"운 raises the special spawn multiplier by 5%"
	)


## Doc v0.3 section 33: the prototype set is exactly ten words.
func _test_database_holds_ten_words() -> void:
	var expected := PackedStringArray(
		["불", "화염", "불꽃", "힘", "강타", "돈", "금", "밥", "체력", "운"]
	)
	_check(
		GameState.database.words.size() == 10,
		"the database should hold 10 words (got %d)" % GameState.database.words.size()
	)
	for word_text: String in expected:
		var found := false
		for word: WordData in GameState.database.words:
			if word != null and word.word == word_text:
				found = true
				break
		_check(found, "%s should be registered in the database" % word_text)


## Doc v0.3 section 19.1 / F3 regression: the HUD craft list is scene nodes, so
## it must hold at least one row per database word. It used to stop at four,
## which silently hid 운 on Day 1 while the dex still listed it.
func _test_hud_lists_every_craftable_word() -> void:
	_reset()
	var hud: Control = (load(HUD_SCENE) as PackedScene).instantiate()
	add_child(hud)

	var rows := _hud_word_rows(hud)
	var empty_label: Label = hud.get_node("%WordEmptyLabel")
	var overflow_label: Label = hud.get_node("%WordOverflowLabel")

	_check(
		rows.size() >= GameState.database.words.size(),
		"the HUD needs a row per word (%d rows for %d words)"
			% [rows.size(), GameState.database.words.size()]
	)

	hud.refresh()
	var craftable := GameState.get_craftable_words()
	_check(craftable.size() >= 5, "Day 1 should offer at least the five tier-1 words")
	_check(
		_visible_word_texts(rows).size() == craftable.size(),
		"the HUD should show %d rows on Day 1 (got %d)"
			% [craftable.size(), _visible_word_texts(rows).size()]
	)
	for word: WordData in craftable:
		var listed := false
		for text: String in _visible_word_texts(rows):
			if text.begins_with(word.word):
				listed = true
				break
		_check(listed, "the HUD craft list should show %s" % word.word)
	_check(not empty_label.visible, "the empty notice must stay hidden while words remain")
	_check(not overflow_label.visible, "nothing is truncated while rows outnumber words")

	# Everything completed: the panel must say so instead of going blank.
	var every_id: Array = []
	for word: WordData in GameState.database.words:
		every_id.append(word.id)
	_unlock(every_id)
	hud.refresh()
	_check(GameState.get_craftable_words().is_empty(), "unlocking every word empties the list")
	_check(_visible_word_texts(rows).is_empty(), "no rows should remain visible")
	_check(empty_label.visible, "an empty craft list needs a readable notice")

	hud.queue_free()


## The HUD's WordRow labels, read from the scene so the count is never guessed.
func _hud_word_rows(hud: Control) -> Array[Label]:
	var rows: Array[Label] = []
	for child in hud.get_node("WordProgressPanel/WordBox").get_children():
		if child is Label and child.name.begins_with("WordRow"):
			rows.append(child)
	return rows


func _visible_word_texts(rows: Array[Label]) -> PackedStringArray:
	var texts := PackedStringArray()
	for row: Label in rows:
		if row.visible:
			texts.append(row.text)
	return texts
