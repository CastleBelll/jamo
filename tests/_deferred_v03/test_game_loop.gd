extends Node

## Headless check for the day loop rules that are easy to break silently.
## Run: godot --headless --path . res://tests/test_game_loop.tscn
## Exit code 0 means every assertion held.
##
## It runs as a scene rather than with --script because the autoload singletons
## are only registered as globals once a scene main loop starts.

const CHOICE_SCENE := "res://scenes/ui/jamo_choice.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const TREE_SCENE := "res://scenes/ui/word_tree.tscn"
const WORD_COMPLETE_SCENE := "res://scenes/ui/word_complete.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const PAUSE_SCENE := "res://scenes/ui/pause_menu.tscn"
const WORLD_SCENE := "res://scenes/world/game_world.tscn"
## A path that is deliberately not in the project, to prove a missing audio
## file is skipped rather than raising a load error. Doc v0.3 section 25.
const MISSING_AUDIO_PATH := "res://art/audio/sfx/step_heavy.ogg"
## Every monster the spawner can put on the field, plain and special.
const MONSTER_SCENES := [
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_i.tscn",
	"res://scenes/monsters/special/monster_big_mieum.tscn",
	"res://scenes/monsters/special/monster_fast_ieung.tscn",
	"res://scenes/monsters/special/monster_golden_hieut.tscn",
]
## Half-extent of the paper in the slab's own frame: arena.tscn draws a
## 5.6 x 5.6 PaperTop, so nothing may pass 2.8 in the slab local x or z.
const SLAB_HALF := 2.8
## Frames a monster is left alone first, so the lean, turn and squash of a walk
## have all reached their widest pose before the footprint is trusted.
const ARENA_WARMUP_FRAMES := 300
## Positions sampled around the rim of the walkable diamond.
const ARENA_RIM_SAMPLES := 96
## A deliberately oversized individual, to prove the clamp follows the scale
## rather than a value hand-tuned for the letters that exist today.
const OVERSIZED_VISUAL_SCALE := 5.0

var _failures: int = 0


func _ready() -> void:
	_test_starting_stats()
	_test_energy_ends_the_day()
	_test_day_scaling()
	_test_day_200_curve_comes_from_the_balance_resource()
	_test_tuned_values_come_from_resources()
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
	_test_golden_pool_waits_for_geum()
	_test_special_multipliers_reach_the_monster()
	_test_un_multiplies_special_spawn_chance()
	_test_golden_leaves_without_paying_gold()
	_test_save_round_trip()
	_test_reroll_save_round_trip()
	_test_word_states_come_from_the_database()
	_test_target_refuses_uncraftable_words()
	_test_target_focus_raises_candidate_weight()
	_test_hud_and_tree_show_the_same_words()
	await _test_no_monster_size_leaves_the_slab()
	await _test_hud_buttons_take_keyboard_focus()
	await _test_burn_vfx_follows_effects_changed()
	await _test_energy_warning_threshold_comes_from_balance()
	_test_volume_settings_survive_a_save()
	_test_missing_audio_files_are_skipped()
	_test_step_sfx_paths_differ_per_motion_profile()
	await _test_word_completion_can_be_skipped()
	await _test_settings_sliders_drive_the_buses()
	await _test_title_hides_continue_without_a_save()
	await _test_new_game_asks_before_overwriting()
	await _test_returning_to_the_title_saves()
	await _test_new_game_keeps_the_volume_settings()
	await _test_hidden_continue_leaves_the_focus_chain()
	await _test_title_plates_keep_one_size_without_a_save()
	await _test_title_lights_one_plate_at_a_time()

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
	GameState.target_word_id = &""
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
	# F8 raised gold growth to match HP growth, so the Day 10 reward moved from
	# the 2.5 of growth_balance v0.2 section 4 to 2.73. docs/BALANCE_NOTES.md.
	_check(
		absf(balance.monster_gold_for_day(10) - 2.73) < 0.05,
		"Day 10 gold should be about 2.73"
	)


## Doc v0.3 section 8.1 pins HP = 3 * 1.035^(Day-1). The far end of the curve is
## where a wrong rounding or a lost float would show, so Day 200 is checked
## against the formula rebuilt from the numbers in game_balance.tres.
func _test_day_200_curve_comes_from_the_balance_resource() -> void:
	var balance: GameBalance = GameState.balance
	_close(balance.base_monster_hp, 3.0, "doc v0.3 8.1 base monster HP")
	_close(balance.hp_growth_per_day, 1.035, "doc v0.3 8.1 HP growth")
	_close(balance.base_monster_gold, 2.0, "doc v0.3 42-4 Day 1 gold")
	# F8 moved gold growth off the 1.025 printed in v0.3 8.1. Pin the tuned
	# constant with a literal so changing it again cannot pass silently -
	# the HP side has had that anchor since F8, the gold side had none.
	# docs/BALANCE_NOTES.md 3-1 carries the reasoning.
	_close(balance.gold_growth_per_day, 1.035, "BALANCE_NOTES 3-1 gold growth")

	for day: int in [1, 10, 50, 100, 200]:
		var expected_hp: float = roundf(
			balance.base_monster_hp * pow(balance.hp_growth_per_day, day - 1)
		)
		var expected_gold: float = (
			balance.base_monster_gold * pow(balance.gold_growth_per_day, day - 1)
		)
		_close(balance.monster_hp_for_day(day), expected_hp, "Day %d HP" % day)
		_close(balance.monster_gold_for_day(day), expected_gold, "Day %d gold" % day)

	var hp_200: float = balance.monster_hp_for_day(200)
	var gold_200: float = balance.monster_gold_for_day(200)
	_check(is_finite(hp_200) and hp_200 > 0.0, "Day 200 HP must stay a finite number")
	_check(is_finite(gold_200) and gold_200 > 0.0, "Day 200 gold must stay a finite number")
	_check(hp_200 > balance.monster_hp_for_day(199), "Day 200 HP must still be rising")
	# 2820 is what 3 * 1.035^199 rounds to. growth_balance v0.2 section 3 prints
	# 2,824; the formula is the authority and the printed table is rounded.
	_close(hp_200, 2820.0, "Day 200 HP from the documented formula")
	# 1880.0076 is 2 * 1.035^199, the tuned gold curve. v0.3 8.1 still prints
	# 2 * 1.025^199 = 272.3; the gap is the deviation BALANCE_NOTES 3-1 records.
	_close(gold_200, 1880.0076, "Day 200 gold from the tuned gold curve")


## F8 tuning lives in the .tres files, never in a script. Reading the numbers
## back through GameState is what proves the shop and the click both see them.
func _test_tuned_values_come_from_resources() -> void:
	_reset()
	var balance: GameBalance = GameState.balance
	# Gold growth is held equal to HP growth so income stays neutral in Day and
	# all growth comes from upgrades. The Day 110 collapse itself came from the
	# click damage Lv9 cap, not from this gap. docs/BALANCE_NOTES.md 3-1.
	_close(
		balance.gold_growth_per_day, balance.hp_growth_per_day,
		"gold growth has to track HP growth"
	)
	_close(balance.special_spawn_chance, 0.02, "growth_balance v0.2 2: special 2%")
	_close(balance.golden_spawn_chance, 0.02, "doc v0.3 9.3: golden 2%")

	var damage: UpgradeData = GameState.database.find_upgrade(&"click_damage")
	_check(damage != null, "click_damage should be registered in the database")
	_check(
		damage.max_level() == 26,
		"the click damage ladder should reach Lv26 (got %d)" % damage.max_level()
	)
	_check(
		damage.costs.size() == damage.values.size(),
		"every click damage level needs both a cost and a value"
	)
	for level in range(1, damage.max_level()):
		_check(
			damage.costs[level] > damage.costs[level - 1],
			"click damage Lv%d must cost more than Lv%d" % [level + 1, level]
		)
		_check(
			damage.values[level] > damage.values[level - 1],
			"click damage Lv%d must hit harder than Lv%d" % [level + 1, level]
		)

	# The top of the ladder has to beat a Day 200 monster in a handful of clicks,
	# which is the whole reason it was extended past the Lv9 of the document.
	GameState.upgrade_levels[&"click_damage"] = damage.max_level()
	var top: float = GameState.get_click_damage()
	_close(top, damage.values[damage.max_level() - 1], "GameState reads the .tres value")
	_check(
		balance.monster_hp_for_day(200) / top < 4.0,
		"Day 200 should fall in under 4 clicks (got %.1f)"
			% (balance.monster_hp_for_day(200) / top)
	)
	_reset()


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


## Prices are read off the .tres rather than written here, so retuning a track
## in the Inspector never turns this into a red test. Doc v0.3 section 38.
func _test_upgrade_purchase() -> void:
	_reset()
	var upgrade: UpgradeData = GameState.database.find_upgrade(&"max_energy")
	var energy_price: int = upgrade.cost_for_next(0)
	GameState.gold = float(energy_price)
	_check(UpgradeManager.purchase(upgrade), "the listed price should buy max energy Lv.1")
	_check(GameState.get_upgrade_level(&"max_energy") == 1, "level should be 1")
	_check(GameState.get_max_energy() == 21, "max energy should now be 21")
	_close(GameState.gold, 0.0, "the price should be deducted")

	var damage: UpgradeData = GameState.database.find_upgrade(&"click_damage")
	GameState.gold = float(damage.cost_for_next(0))
	_check(UpgradeManager.purchase(damage), "the listed price should buy click damage Lv.1")
	_close(GameState.get_click_damage(), 2.0, "click damage Lv.1 is 2")

	var gold_bonus: UpgradeData = GameState.database.find_upgrade(&"gold_bonus")
	GameState.gold = float(gold_bonus.cost_for_next(0))
	_check(UpgradeManager.purchase(gold_bonus), "the listed price should buy gold bonus Lv.1")
	_close(GameState.get_gold_multiplier(), 1.05, "gold bonus Lv.1 is +5%")


func _test_upgrade_blocked_when_poor() -> void:
	_reset()
	var upgrade: UpgradeData = GameState.database.find_upgrade(&"max_energy")
	var short_by_one: float = float(upgrade.cost_for_next(0)) - 1.0
	GameState.gold = short_by_one
	_check(
		UpgradeManager.get_availability(upgrade) == UpgradeManager.Availability.TOO_EXPENSIVE,
		"one gold short of the listed price is not enough"
	)
	_check(not UpgradeManager.purchase(upgrade), "purchase should be refused")
	_close(GameState.gold, short_by_one, "a refused purchase must not spend gold")
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
	var reroll_price: int = reroll.cost_for_next(0)
	GameState.gold = float(reroll_price) - 1.0
	_check(
		UpgradeManager.get_availability(reroll)
			== UpgradeManager.Availability.TOO_EXPENSIVE,
		"one gold short of the listed Lv.1 price is not enough"
	)
	GameState.gold = float(reroll_price)
	_check(UpgradeManager.purchase(reroll), "Day 5 plus the listed price buys 리롤 Lv.1")
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


# --- F4 special monsters ---------------------------------------------------

const IEUNG_SCENE := "res://scenes/monsters/monster_ieung.tscn"
const BIG_MIEUM_SCENE := "res://scenes/monsters/special/monster_big_mieum.tscn"
const FAST_IEUNG_SCENE := "res://scenes/monsters/special/monster_fast_ieung.tscn"
const GOLDEN_HIEUT_SCENE := "res://scenes/monsters/special/monster_golden_hieut.tscn"
## Enough picks that a 2% pool is certain to come up at least once.
const POOL_ROLLS := 2000


## A SpawnManager with the same three pools the game world wires up, and its
## refill loop off so the test decides when a pick happens.
func _make_spawner() -> SpawnManager:
	var spawner := SpawnManager.new()
	var root := Node3D.new()
	spawner.spawn_root = root
	spawner.monster_scenes = [load(MONSTER_SCENE)]
	spawner.special_scenes = [load(BIG_MIEUM_SCENE), load(FAST_IEUNG_SCENE)]
	spawner.golden_scenes = [load(GOLDEN_HIEUT_SCENE)]
	add_child(spawner)
	spawner.add_child(root)
	spawner.set_process(false)
	return spawner


## How many of `rolls` spawn picks landed on each SpecialType. It goes through
## the real pool roll and the real weighted pick, not a shortcut.
func _count_picked_types(spawner: SpawnManager, rolls: int) -> Dictionary:
	var counts: Dictionary = {}
	for _i in rolls:
		var scene: PackedScene = spawner._pick_scene(spawner._pick_pool())
		var data: JamoMonsterData = spawner._data_for(scene)
		if data == null:
			continue
		counts[data.special_type] = int(counts.get(data.special_type, 0)) + 1
	return counts


## Instantiates a monster scene into the tree so its _ready() applies the data.
func _spawn_for_test(root: Node3D, scene_path: String) -> JamoMonster:
	var monster: JamoMonster = (load(scene_path) as PackedScene).instantiate()
	root.add_child(monster)
	return monster


## The Golden Pool is gated by the word 금 and nothing else. Doc v0.3 section 9.3.
func _test_golden_pool_waits_for_geum() -> void:
	_reset()
	var spawner := _make_spawner()

	# Every scene must sit in the pool its own special_type names, otherwise the
	# gate below could be passed by a golden dropped into the normal list.
	for scene: PackedScene in spawner.special_scenes:
		_check(
			spawner._data_for(scene).special_type == JamoMonsterData.SpecialType.SPECIAL,
			"%s belongs in the Special Pool" % scene.resource_path
		)
	for scene: PackedScene in spawner.golden_scenes:
		_check(
			spawner._data_for(scene).special_type == JamoMonsterData.SpecialType.GOLDEN,
			"%s belongs in the Golden Pool" % scene.resource_path
		)

	_check(not GameState.is_golden_monster_unlocked(), "금 starts locked")
	_close(spawner.get_golden_spawn_chance(), 0.0, "a locked 금 leaves no golden chance")
	var locked := _count_picked_types(spawner, POOL_ROLLS)
	_check(
		int(locked.get(JamoMonsterData.SpecialType.GOLDEN, 0)) == 0,
		"no golden individual may spawn before 금 is completed"
	)
	_check(
		int(locked.get(JamoMonsterData.SpecialType.SPECIAL, 0)) > 0,
		"the Special Pool does not wait for 금"
	)

	_unlock([&"gold_001", &"gold_002"])
	_check(GameState.is_golden_monster_unlocked(), "금 should unlock the golden individual")
	_close(
		spawner.get_golden_spawn_chance(), GameState.balance.golden_spawn_chance,
		"an unlocked 금 gives the base golden chance from GameBalance"
	)
	var unlocked := _count_picked_types(spawner, POOL_ROLLS)
	_check(
		int(unlocked.get(JamoMonsterData.SpecialType.GOLDEN, 0)) > 0,
		"the golden individual should appear once 금 is completed"
	)
	# The normal jamo still make up the bulk of the field.
	_check(
		int(unlocked.get(JamoMonsterData.SpecialType.NORMAL, 0)) > POOL_ROLLS / 2,
		"special spawns must stay rare next to the normal pool"
	)

	spawner.queue_free()


## The .tres multipliers have to land on the live monster, not only read well in
## the Inspector. Doc v0.3 sections 9.1, 9.2 and 9.3.
func _test_special_multipliers_reach_the_monster() -> void:
	_reset()
	var root := Node3D.new()
	add_child(root)

	var mieum := _spawn_for_test(root, MONSTER_SCENE)
	var ieung := _spawn_for_test(root, IEUNG_SCENE)
	var big := _spawn_for_test(root, BIG_MIEUM_SCENE)
	var fast := _spawn_for_test(root, FAST_IEUNG_SCENE)
	var golden := _spawn_for_test(root, GOLDEN_HIEUT_SCENE)

	# 큰 ㅁ: HP x3, gold x3, speed x0.6.
	_close(big.max_hp / mieum.max_hp, 3.0, "큰 ㅁ should carry 3x the HP")
	_close(
		big._calculate_gold_reward() / mieum._calculate_gold_reward(), 3.0,
		"큰 ㅁ should pay 3x the gold"
	)
	_close(big._speed / mieum._speed, 0.6, "큰 ㅁ should walk at 0.6x the speed")
	_check(
		big.monster_data.visual_scale > mieum.monster_data.visual_scale,
		"큰 ㅁ should be the bigger click target"
	)

	# 빠른 ㅇ: HP x0.75, gold x2, speed x1.8.
	_close(fast.max_hp / ieung.max_hp, 0.75, "빠른 ㅇ should carry 0.75x the HP")
	_close(
		fast._calculate_gold_reward() / ieung._calculate_gold_reward(), 2.0,
		"빠른 ㅇ should pay 2x the gold"
	)
	_close(fast._speed / ieung._speed, 1.8, "빠른 ㅇ should walk at 1.8x the speed")
	_check(
		fast.monster_data.motion_profile.idle_max < ieung.monster_data.motion_profile.idle_max,
		"빠른 ㅇ should change direction more often"
	)

	# 황금 ㅎ: gold x5 and a shorter stay than a normal individual.
	_close(
		golden._calculate_gold_reward() / mieum._calculate_gold_reward(), 5.0,
		"황금 ㅎ should pay 5x the gold"
	)
	_check(golden.monster_data.lifetime_seconds > 0.0, "황금 ㅎ should leave on its own")
	_close(mieum.monster_data.lifetime_seconds, 0.0, "a normal jamo waits to be clicked")

	root.queue_free()


## 운 multiplies both special chances rather than replacing them.
## Doc word_tree v0.1 section 11.
func _test_un_multiplies_special_spawn_chance() -> void:
	_reset()
	var spawner := _make_spawner()
	_unlock([&"gold_001", &"gold_002"])
	_close(GameState.get_special_spawn_multiplier(), 1.0, "운 starts locked")
	var base_special := spawner.get_special_spawn_chance()
	var base_golden := spawner.get_golden_spawn_chance()
	_check(base_special > 0.0 and base_golden > 0.0, "both pools start with a chance")

	_unlock([&"luck_001"])
	var luck := GameState.get_special_spawn_multiplier()
	_check(luck > 1.0, "운 should raise the special spawn multiplier (got %f)" % luck)
	_close(
		spawner.get_special_spawn_chance(), base_special * luck,
		"운 multiplies the Special Pool chance"
	)
	_close(
		spawner.get_golden_spawn_chance(), base_golden * luck,
		"운 multiplies the Golden Pool chance"
	)

	spawner.queue_free()


## A monster that runs out of lifetime leaves quietly: no gold, and the spawner
## stops counting it so the field refills. Doc v0.3 section 9.3.
func _test_golden_leaves_without_paying_gold() -> void:
	_reset()
	var spawner := _make_spawner()
	var golden := _spawn_for_test(spawner.spawn_root, GOLDEN_HIEUT_SCENE)
	golden.died.connect(spawner._on_monster_died)
	spawner._alive.append(golden)

	var gold_before := GameState.gold
	# One oversized step burns the whole lifetime without waiting in real time.
	golden._physics_process(golden.monster_data.lifetime_seconds + 0.1)
	_check(not golden.is_alive(), "the golden individual should leave when its time is up")
	_close(GameState.gold, gold_before, "a monster that left on its own pays no gold")
	_check(spawner._alive.is_empty(), "the spawner should free the slot it left behind")

	spawner.queue_free()


# --- F5 word tree ----------------------------------------------------------

## Doc v0.3 section 23.5: the four tree states are derived from the database,
## never stored, so a save can never disagree with the word list.
func _test_word_states_come_from_the_database() -> void:
	_reset()
	var bul: WordData = GameState.database.find_word(&"fire_001")
	var hwayeom: WordData = GameState.database.find_word(&"fire_002")
	_check(
		GameState.get_word_state(bul) == GameState.WordState.CRAFTABLE,
		"불 has no prerequisite, so Day 1 offers it"
	)
	_check(
		GameState.get_word_state(hwayeom) == GameState.WordState.PREREQUISITE_LOCKED,
		"화염 sits one step behind 불"
	)

	_unlock([&"fire_001"])
	_check(
		GameState.get_word_state(bul) == GameState.WordState.UNLOCKED,
		"a completed word reads as 완성"
	)
	_check(
		GameState.get_word_state(hwayeom) == GameState.WordState.CRAFTABLE,
		"unlocking 불 opens 화염"
	)

	# 미발견 needs a word two prerequisite hops deep. The shipped database only
	# goes one deep, so the rule is proven against a probe database instead of
	# by editing balance data.
	var original: GameDatabase = GameState.database
	var probe := GameDatabase.new()
	probe.balance = original.balance
	probe.filler_jamo = original.filler_jamo
	probe.upgrades = original.upgrades
	var deep := WordData.new()
	deep.id = &"fire_probe"
	deep.word = "고열"
	deep.category = &"fire"
	deep.required_jamo = PackedStringArray(["ㄱ", "ㅗ"])
	deep.prerequisites = [&"fire_002"]
	var words: Array[WordData] = original.words.duplicate()
	words.append(deep)
	probe.words = words

	GameState.database = probe
	_reset()
	_check(
		GameState.get_word_state(deep) == GameState.WordState.UNDISCOVERED,
		"a word two steps behind an unmet prerequisite reads as 미발견"
	)
	_unlock([&"fire_001"])
	_check(
		GameState.get_word_state(deep) == GameState.WordState.PREREQUISITE_LOCKED,
		"once 화염 is craftable, the word behind it is only 선행 잠금"
	)
	GameState.database = original
	_reset()


## Doc v0.3 section 13.3: only a craftable word can be the Target.
func _test_target_refuses_uncraftable_words() -> void:
	_reset()
	_check(
		not GameState.set_target_word(&"fire_002"),
		"a prerequisite-locked word must be refused as the target"
	)
	_check(GameState.target_word_id == &"", "a refused target leaves the target unset")
	_check(not GameState.set_target_word(&"not_a_word"), "an unknown id is refused")

	_check(GameState.set_target_word(&"fire_001"), "a craftable word is accepted")
	_check(GameState.target_word_id == &"fire_001", "the accepted target is stored")
	_check(GameState.get_target_word() != null, "the stored target resolves to its word")

	# Completing the target retires it rather than leaving a stale pointer.
	_grant(["ㅂ", "ㅜ", "ㄹ"])
	GameState.complete_ready_words()
	_check(GameState.is_word_unlocked(&"fire_001"), "the target word completed")
	_check(GameState.target_word_id == &"", "completing the target clears it")
	_check(
		not GameState.set_target_word(&"fire_001"),
		"an already completed word cannot be re-targeted"
	)

	# A save carrying a target that is no longer craftable drops it on load.
	GameState.target_word_id = &"fire_001"
	GameState.from_dict(GameState.to_dict())
	_check(GameState.target_word_id == &"", "a stale saved target is dropped on load")


## Doc v0.3 section 13.3: the target's jamo weigh more in the candidate pool,
## by +5~20 %, and never enough to be a certainty.
func _test_target_focus_raises_candidate_weight() -> void:
	_reset()
	var balance: GameBalance = GameState.balance
	_close(balance.focus_weight_bonus_at(0), 0.0, "focus level 0 gives no bonus")
	_close(balance.focus_weight_bonus_at(1), 0.05, "focus level 1 is +5%")
	_close(
		balance.focus_weight_bonus_at(99),
		balance.focus_weight_steps[balance.focus_weight_steps.size() - 1],
		"a level past the last step stays on the last step"
	)

	var before: Dictionary = CandidateGenerator.build_weights()
	_check(GameState.set_target_word(&"gold_001"), "돈 is craftable on Day 1")
	var bonus: float = GameState.get_focus_weight_bonus()
	_check(bonus > 0.0, "a target must actually raise its jamo")
	_check(bonus < 1.0, "the focus bonus must never make a jamo certain")

	var after: Dictionary = CandidateGenerator.build_weights()
	for jamo: String in ["ㄷ", "ㅗ", "ㄴ"]:
		_close(
			float(after[jamo]),
			float(before[jamo]) * (1.0 + bonus),
			"%s is a target jamo, so it weighs more" % jamo
		)
	_close(
		float(after["ㅂ"]),
		float(before["ㅂ"]),
		"a jamo no target needs keeps its weight"
	)

	# Pool A/B/C still hold: every candidate is a jamo some craftable word needs.
	var needed := _craftable_jamo()
	var misses := 0
	for _attempt in 200:
		var candidates := CandidateGenerator.generate(2)
		for jamo: String in candidates:
			_check(needed.has(jamo), "candidate %s should still come from the pools" % jamo)
		if not candidates.has("ㄷ"):
			misses += 1
	_check(misses > 0, "focus must not guarantee the target jamo shows up")
	GameState.clear_target_word()


## The F3 failure was two panels disagreeing about the same word list. Both now
## read GameState, so they are checked against each other.
func _test_hud_and_tree_show_the_same_words() -> void:
	_reset()
	var hud: Control = (load(HUD_SCENE) as PackedScene).instantiate()
	add_child(hud)
	var tree: Control = (load(TREE_SCENE) as PackedScene).instantiate()
	add_child(tree)
	hud.refresh()
	tree.refresh()

	var craftable := GameState.get_craftable_words()
	var slot_texts := _tree_slot_texts(tree)
	_check(
		slot_texts.size() == GameState.database.words.size(),
		"the tree shows every word once (%d slots for %d words)"
			% [slot_texts.size(), GameState.database.words.size()]
	)
	for word: WordData in GameState.database.words:
		var listed := false
		for text: String in slot_texts:
			if text.ends_with(word.word):
				listed = true
		_check(listed, "the tree should list %s" % word.word)

	var hud_names := PackedStringArray()
	for text: String in _visible_word_texts(_hud_word_rows(hud)):
		hud_names.append(text.split(" ")[0])
	for word: WordData in craftable:
		_check(hud_names.has(word.word), "the HUD craft list should show %s" % word.word)
		var tagged := false
		for text: String in slot_texts:
			if text.ends_with("[제작 가능] %s" % word.word):
				tagged = true
		_check(tagged, "the tree should tag %s as 제작 가능 too" % word.word)
	_check(
		hud_names.size() == craftable.size(),
		"the HUD lists exactly the craftable words"
	)

	# The HUD target readout follows the tree choice.
	_check(GameState.set_target_word(&"fire_001"), "불 can be targeted")
	var target_label: Label = hud.get_node("%TargetWordLabel")
	_check(
		target_label.text.contains("불"),
		"the HUD TARGET line should name the target (got %s)" % target_label.text
	)
	GameState.clear_target_word()

	hud.queue_free()
	tree.queue_free()


## Text of every visible tree slot, read off the scene so the slot count is
## never guessed.
func _tree_slot_texts(tree: Control) -> PackedStringArray:
	var texts := PackedStringArray()
	for column: Node in tree.get_node("%Columns").get_children():
		for child: Node in column.get_children():
			if child is Button and String(child.name).begins_with("Slot") and child.visible:
				texts.append((child as Button).text)
	return texts


## No glyph may hang over the paper, whatever its visual_scale is. The walkable
## diamond is the slab inset by each monster's own measured body footprint, so
## this pins every monster to the rim of that diamond - the furthest the clamp
## lets it stand - and checks the meshes against the slab in the slab's own
## frame, because arena.tscn turns the slab 45 degrees.
func _test_no_monster_size_leaves_the_slab() -> void:
	_reset()
	var world: Node3D = (load(WORLD_SCENE) as PackedScene).instantiate()
	add_child(world)
	var spawn: SpawnManager = world.get_node("SpawnManager")
	# This test places its own monsters; a refilling field would fight it.
	spawn.set_process(false)
	var arena: Node3D = world.get_node("Arena")
	var to_slab := arena.global_transform.affine_inverse()
	var monster_root: Node3D = world.get_node("MonsterRoot")

	for path: String in MONSTER_SCENES:
		await _check_stays_on_slab(path, 0.0, spawn, monster_root, to_slab)
	await _check_stays_on_slab(
		BIG_MIEUM_SCENE, OVERSIZED_VISUAL_SCALE, spawn, monster_root, to_slab
	)
	world.queue_free()


## Walks one monster around the rim of its walkable diamond and reports the
## worst overhang it produced. `visual_scale_override` of 0 keeps the authored
## scale.
func _check_stays_on_slab(
	path: String,
	visual_scale_override: float,
	spawn: SpawnManager,
	monster_root: Node3D,
	to_slab: Transform3D
) -> void:
	var monster: JamoMonster = (load(path) as PackedScene).instantiate()
	var label := path.get_file()
	if visual_scale_override > 0.0:
		# Duplicated so resizing this probe never resizes the shared .tres.
		monster.monster_data = monster.monster_data.duplicate()
		monster.monster_data.visual_scale = visual_scale_override
		label = "%s at scale %.1f" % [label, visual_scale_override]
	monster.arena_half_extents = spawn.arena_half_extents
	monster_root.add_child(monster)

	for _frame in ARENA_WARMUP_FRAMES:
		await get_tree().process_frame

	var worst := 0.0
	var worst_at := Vector2.ZERO
	for sample in ARENA_RIM_SAMPLES:
		await get_tree().process_frame
		var extents := monster.get_walkable_half_extents()
		var angle := TAU * float(sample) / float(ARENA_RIM_SAMPLES)
		var direction := Vector2(cos(angle), sin(angle))
		var rim := absf(direction.x) / extents.x + absf(direction.y) / extents.y
		if rim <= 0.0:
			continue
		monster.global_position = Vector3(direction.x / rim, 0.0, direction.y / rim)
		var overhang := _slab_overhang(monster, to_slab)
		if overhang > worst:
			worst = overhang
			worst_at = Vector2(monster.global_position.x, monster.global_position.z)
	_check(
		worst <= 0.0,
		"%s hangs %.3f m over the slab at (%.2f, %.2f)"
			% [label, worst, worst_at.x, worst_at.y]
	)
	monster.queue_free()


## How far the glyph pokes past the paper, in metres. The corners of each mesh
## box are carried into the slab's frame one by one, because re-bounding the
## whole box in a rotated frame would inflate it and cry wolf.
func _slab_overhang(monster: JamoMonster, to_slab: Transform3D) -> float:
	var worst := 0.0
	for node: Node in monster.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		for corner_index in 8:
			var corner: Vector3 = to_slab * box.get_endpoint(corner_index)
			worst = maxf(worst, maxf(absf(corner.x), absf(corner.z)) - SLAB_HALF)
	return worst


## The word tree can only be reached without a mouse if the top bar can hold
## focus, shows that it has it, and if Tab has somewhere to start from. F5 QA
## found all three missing: twelve Tab presses focused nothing at all.
func _test_hud_buttons_take_keyboard_focus() -> void:
	_reset()
	var hud: Control = (load(HUD_SCENE) as PackedScene).instantiate()
	add_child(hud)

	var project_theme := ThemeDB.get_project_theme()
	for button_name: String in ["DictionaryButton", "SettingsButton", "PauseButton"]:
		var button: Button = hud.get_node("%" + button_name)
		_check(
			button.focus_mode == Control.FOCUS_ALL,
			"%s must accept keyboard focus" % button_name
		)
		_check(
			project_theme != null
				and project_theme.has_stylebox(&"focus", button.theme_type_variation),
			"%s needs a focus style from the theme, not from code" % button_name
		)

	hud.focus_first_button()
	_check(
		get_viewport().gui_get_focus_owner() == hud.get_node("%DictionaryButton"),
		"the HUD should be able to put focus on its first button"
	)

	# The regression itself: with focus dropped, Tab has to find the HUD again.
	get_viewport().gui_release_focus()
	await get_tree().process_frame
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		get_viewport().gui_get_focus_owner() != null,
		"Tab must reach the top bar while nothing else holds focus"
	)

	hud.queue_free()


## F3 left StatusEffectContainer.effects_changed with no listener at all. The
## burn ember is that listener: applying a burn must switch the particles on
## and clearing it must switch them off, without anything polling per frame.
## Doc v0.3 section 24.
func _test_burn_vfx_follows_effects_changed() -> void:
	_reset()
	for jamo in ["ㅂ", "ㅜ", "ㄹ"]:
		GameState.add_jamo(jamo)
	GameState.complete_ready_words()
	var burn: WordEffectData = GameState.get_burn_effect()
	_check(burn != null, "불 should be unlocked before the burn VFX check")

	var monster: JamoMonster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	add_child(monster)
	await get_tree().process_frame
	var ember: CPUParticles3D = monster.get_node("StatusEffectAnchor/BurnEmber")
	_check(not ember.emitting, "the ember stays off while nothing burns")

	monster.apply_status_effect(burn)
	_check(ember.emitting, "applying burn must switch the ember on")

	var status: StatusEffectContainer = monster.get_node("StatusEffects")
	status.clear()
	_check(not ember.emitting, "clearing the effects must switch the ember off")

	monster.queue_free()
	await get_tree().process_frame


## The warning threshold is balance data, not a constant in hud.gd: moving it in
## game_balance.tres has to move the warning. Doc v0.3 section 23.3.
func _test_energy_warning_threshold_comes_from_balance() -> void:
	_reset()
	var hud: Control = (load(HUD_SCENE) as PackedScene).instantiate()
	add_child(hud)
	await get_tree().process_frame
	var warn_label: Label = hud.get_node("%EnergyWarnLabel")
	var original: int = GameState.balance.low_energy_warning

	GameState.balance.low_energy_warning = 3
	SignalBus.energy_changed.emit(5, 20)
	_check(not warn_label.visible, "5 energy is above a threshold of 3")
	SignalBus.energy_changed.emit(3, 20)
	_check(warn_label.visible, "3 energy is at a threshold of 3")

	# Raising the threshold in the data alone has to widen the warning band.
	GameState.balance.low_energy_warning = 6
	SignalBus.energy_changed.emit(5, 20)
	_check(warn_label.visible, "5 energy warns once the balance threshold is 6")
	SignalBus.energy_changed.emit(0, 20)
	_check(not warn_label.visible, "an empty day is the day end, not a warning")

	GameState.balance.low_energy_warning = original
	hud.queue_free()
	await get_tree().process_frame


## Volumes travel in the same save file as the rest of the progress.
func _test_volume_settings_survive_a_save() -> void:
	_reset()
	var original: Dictionary = AudioManager.to_dict()

	AudioManager.set_volume(AudioManager.BUS_MASTER, 0.4)
	AudioManager.set_volume(AudioManager.BUS_BGM, 0.0)
	AudioManager.set_volume(AudioManager.BUS_SFX, 0.75)
	_check(SaveManager.save_game(), "saving the volumes should succeed")

	AudioManager.set_volume(AudioManager.BUS_MASTER, 1.0)
	AudioManager.set_volume(AudioManager.BUS_BGM, 1.0)
	AudioManager.set_volume(AudioManager.BUS_SFX, 1.0)
	_check(SaveManager.load_game(), "loading the volumes should succeed")
	_close(AudioManager.get_volume(AudioManager.BUS_MASTER), 0.4, "master volume")
	_close(AudioManager.get_volume(AudioManager.BUS_BGM), 0.0, "bgm volume")
	_close(AudioManager.get_volume(AudioManager.BUS_SFX), 0.75, "sfx volume")

	# A muted bus really is muted, not merely quiet.
	var bgm_bus := AudioServer.get_bus_index(String(AudioManager.BUS_BGM))
	_check(bgm_bus >= 0, "the BGM bus must exist in the project bus layout")
	_check(AudioServer.is_bus_mute(bgm_bus), "a volume of 0 should mute the bus")

	AudioManager.from_dict(original)


## No audio asset ships with the repository yet, so every cue resolves to a
## missing file. That has to be silent, never a load error mid-fight.
func _test_missing_audio_files_are_skipped() -> void:
	_check(
		not ResourceLoader.exists(MISSING_AUDIO_PATH),
		"this check needs %s to still be absent" % MISSING_AUDIO_PATH
	)
	# None of these may raise; a cue with no file simply plays nothing.
	AudioManager.play_sfx_path(MISSING_AUDIO_PATH)
	AudioManager.play_sfx_path("")
	AudioManager.play_sfx(&"click")
	AudioManager.play_sfx(&"word_complete")
	AudioManager.play_sfx(&"not_a_cue_at_all")

	var pool: Node = AudioManager.get_node("SfxPool")
	var playing := 0
	for child: Node in pool.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
	_check(playing == 0, "a missing audio file must leave every player idle")
	_check(
		AudioManager.library != null and AudioManager.library.path_for(&"click").is_empty(),
		"the click cue is still waiting for its audio asset"
	)


## Doc v0.3 section 25 asks for a different step sound per motion profile
## family. The paths live on the .tres files, so the split survives a rebalance.
func _test_step_sfx_paths_differ_per_motion_profile() -> void:
	var profiles := {
		"heavy_step": "step_heavy",
		"light_step": "step_light",
		"bounce": "step_bounce",
		"roll": "step_roll",
		"glide": "step_glide",
	}
	var seen: Dictionary = {}
	for name: String in profiles:
		var profile: MotionProfile = load("res://resources/motion_profiles/%s.tres" % name)
		_check(profile != null, "%s.tres should load" % name)
		if profile == null:
			continue
		_check(
			profile.step_sfx_path.contains(profiles[name]),
			"%s should point at %s (got %s)"
				% [name, profiles[name], profile.step_sfx_path]
		)
		seen[profile.step_sfx_path] = true
	_check(seen.size() == 5, "the five step families need five distinct sounds")

	# The step is fired from the walk animation's method track, not from code.
	var library: AnimationLibrary = load("res://resources/animations/walk_library.tres")
	for animation_name: StringName in library.get_animation_list():
		if not String(animation_name).begins_with("walk_"):
			continue
		var animation: Animation = library.get_animation(animation_name)
		var step_keys := 0
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_METHOD:
				step_keys += animation.track_get_key_count(track)
		_check(step_keys > 0, "%s needs at least one step method key" % animation_name)


## The word-complete gather is the game's biggest reward beat, but it is also
## seen over and over: a click has to jump straight to the reveal.
## Doc v0.3 section 14.2.
func _test_word_completion_can_be_skipped() -> void:
	_reset()
	var panel: Control = (load(WORD_COMPLETE_SCENE) as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame

	var revealed := [false]
	var handler := func() -> void: revealed[0] = true
	SignalBus.word_revealed.connect(handler)

	var word: WordData = GameState.database.find_word(&"fire_001")
	panel.open([word] as Array[WordData])
	await get_tree().process_frame
	_check(not revealed[0], "the gather has to run before the reveal")

	var skip := InputEventAction.new()
	skip.action = &"click"
	skip.pressed = true
	Input.parse_input_event(skip)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(revealed[0], "a click during the gather must jump to the reveal")
	_check(
		panel.get_node("%CompletedWord").text == word.word,
		"the skipped reveal still has to show the finished word"
	)

	SignalBus.word_revealed.disconnect(handler)
	panel.queue_free()
	await get_tree().process_frame


## The settings screen is what the player actually reaches, so the sliders have
## to move the buses and read back the stored positions. Doc v0.3 section 25.
func _test_settings_sliders_drive_the_buses() -> void:
	var original: Dictionary = AudioManager.to_dict()
	var panel: Control = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame

	var slider: HSlider = panel.get_node("%SfxSlider")
	var value_label: Label = panel.get_node("%SfxValueLabel")
	slider.value = 0.5
	_close(
		AudioManager.get_volume(AudioManager.BUS_SFX), 0.5,
		"moving the SFX slider should move the SFX bus"
	)
	_check(value_label.text == "50%", "the slider needs a readable value, got %s" % value_label.text)

	# Reopening has to show the stored position, not the value baked into
	# the scene.
	AudioManager.set_volume(AudioManager.BUS_SFX, 0.2)
	panel.open()
	_close(slider.value, 0.2, "reopening settings should show the stored volume")
	_check(value_label.text == "20%", "the percentage should follow the stored volume")

	AudioManager.from_dict(original)
	panel.queue_free()
	await get_tree().process_frame


## Doc v0.3 section 30: with nothing on disk there is nothing to continue, so
## the row is taken off the screen rather than greyed out. A row that is not
## drawn cannot mislead and cannot be stopped on.
func _test_title_hides_continue_without_a_save() -> void:
	SaveManager.delete_save()
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame

	var continue_button: Button = title.get_node("%ContinueButton")
	var info: Label = title.get_node("%ContinueInfoLabel")
	_check(not continue_button.visible, "no save should hide 이어하기 entirely")
	_check(
		not info.visible,
		"with 이어하기 gone its reason line has nothing left to explain"
	)
	_check(continue_button.disabled, "the hidden 이어하기 must also stay disabled")
	_check(
		title.get_node("%NewGameButton").has_focus(),
		"the title should hold keyboard focus on entry"
	)
	# The three rows that are left still have to sit in one evenly spaced stack.
	_check_remaining_stack_is_intact(title)

	# A save appears: the same screen has to offer it, with the run's day in it.
	_reset()
	GameState.day = 7
	GameState.gold = 123.0
	_check(SaveManager.save_game(), "the test needs a save file on disk")
	title.refresh()
	await get_tree().process_frame
	_check(continue_button.visible, "an existing save should bring 이어하기 back")
	_check(info.visible, "the saved progress line comes back with the button")
	_check(not continue_button.disabled, "an existing save should enable 이어하기")
	_check(
		info.text.contains("7"),
		"the continue line should name the saved day, got %s" % info.text
	)
	_check(
		continue_button.has_focus(),
		"with a save present, focus should start on 이어하기"
	)

	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## 새 게임 over an existing run is not reversible, so it must only ask, never
## delete on the press itself. Doc v0.3 section 30.
func _test_new_game_asks_before_overwriting() -> void:
	_reset()
	GameState.day = 4
	_check(SaveManager.save_game(), "the test needs a save file on disk")

	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame

	var confirm: ConfirmationDialog = title.get_node("%OverwriteConfirm")
	title.get_node("%NewGameButton").pressed.emit()
	_check(confirm.visible, "새 게임 over a save should raise the overwrite dialog")
	_check(
		SaveManager.has_save(),
		"pressing 새 게임 must not delete the save before the player confirms"
	)
	_check(
		int(SaveManager.peek_save().get("day", 0)) == 4,
		"the untouched save should still hold the day it was written with"
	)
	# The dialog carries no hardcoded pixel size, so it has to end up at least
	# as big as its own contents whatever the font or the content scale does.
	await get_tree().process_frame
	var minimum: Vector2 = confirm.get_contents_minimum_size()
	_check(
		confirm.size.x >= int(minimum.x) and confirm.size.y >= int(minimum.y),
		"the overwrite dialog must fit its contents (size %s, contents %s)"
			% [str(confirm.size), str(minimum)]
	)

	confirm.hide()
	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## Doc v0.3 section 30 counts leaving the game as a save point, so the run has
## to be on disk before the title takes over. The pause menu only asks for the
## swap; main.gd performs it, which is what keeps this checkable headlessly.
func _test_returning_to_the_title_saves() -> void:
	SaveManager.delete_save()
	_reset()
	GameState.day = 9
	GameState.gold = 42.0

	var pause: Control = (load(PAUSE_SCENE) as PackedScene).instantiate()
	add_child(pause)
	await get_tree().process_frame

	var requested: Array[bool] = [false]
	pause.title_requested.connect(func() -> void: requested[0] = true)
	pause.open()
	pause.get_node("%TitleButton").pressed.emit()

	_check(requested[0], "타이틀로 should ask for the scene swap")
	_check(not get_tree().paused, "leaving for the title should unpause the tree")
	_check(SaveManager.has_save(), "타이틀로 should write the run to disk first")
	var save: Dictionary = SaveManager.peek_save()
	_check(
		int(save.get("day", 0)) == 9,
		"the save written on the way out should hold the day being played"
	)

	# And that save is exactly what the title then offers to continue.
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	_check(
		not title.get_node("%ContinueButton").disabled,
		"the run saved on the way out should be continuable from the title"
	)

	title.queue_free()
	pause.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## Doc v0.3 section 30: 새 게임 throws the run away, not the player's setup.
## The volume sliders are environment rather than run data, so starting over
## must leave the mixer where the player put it.
func _test_new_game_keeps_the_volume_settings() -> void:
	SaveManager.delete_save()
	var original: Dictionary = AudioManager.to_dict()
	_reset()
	GameState.day = 5
	AudioManager.set_volume(AudioManager.BUS_BGM, 0.6)
	AudioManager.set_volume(AudioManager.BUS_SFX, 0.3)
	_check(SaveManager.save_game(), "the test needs a save file on disk")

	# The overwrite dialog must not open on the button that cannot be undone.
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var confirm: ConfirmationDialog = title.get_node("%OverwriteConfirm")
	title.get_node("%NewGameButton").pressed.emit()
	_check(
		confirm.get_cancel_button().has_focus(),
		"the overwrite dialog should open with 취소 focused, not the destructive button"
	)
	confirm.hide()
	title.queue_free()
	await get_tree().process_frame

	# What confirming the dialog does: the run goes, the settings stay.
	_check(SaveManager.clear_progress(), "clearing the run should rewrite the save file")
	_check(
		not SaveManager.has_save(),
		"a cleared file must not read as a run waiting to be continued"
	)

	# A fresh process starts at the defaults and reads the file back.
	AudioManager.from_dict({"master": 1.0, "bgm": 1.0, "sfx": 1.0})
	SaveManager.load_audio_settings()
	_check(
		absf(AudioManager.get_volume(AudioManager.BUS_BGM) - 0.6) < 0.001,
		"새 게임 must keep the music volume, got %f"
		% AudioManager.get_volume(AudioManager.BUS_BGM)
	)
	_check(
		absf(AudioManager.get_volume(AudioManager.BUS_SFX) - 0.3) < 0.001,
		"새 게임 must keep the effects volume, got %f"
		% AudioManager.get_volume(AudioManager.BUS_SFX)
	)

	AudioManager.from_dict(original)
	SaveManager.delete_save()


## A greyed out button still answers Godot's geometric focus search, so the
## arrow keys would stop on 이어하기 with nothing to continue. Doc v0.3
## section 37: every keyboard step has to land somewhere that does something.
## The row is hidden now, which is the stronger version of the same rule, so
## this walks the whole chain and asserts it never arrives there.
func _test_hidden_continue_leaves_the_focus_chain() -> void:
	SaveManager.delete_save()
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame

	var new_game: Button = title.get_node("%NewGameButton")
	var continue_button: Button = title.get_node("%ContinueButton")
	_check(not continue_button.visible, "the test needs 이어하기 hidden to start with")
	_check(continue_button.disabled, "the test needs 이어하기 disabled to start with")
	_check(
		continue_button.focus_mode == Control.FOCUS_NONE,
		"a hidden 이어하기 has to be out of the focus chain"
	)
	var below: Control = new_game.find_valid_focus_neighbor(SIDE_BOTTOM)
	_check(
		below != continue_button,
		"the arrow keys must step over the hidden 이어하기"
	)
	var walked: Array[String] = _walk_focus_chain(new_game)
	_check(
		not walked.has("ContinueButton"),
		"walking the whole chain must never land on the hidden 이어하기, got %s"
			% ", ".join(walked)
	)
	for required: String in ["NewGameButton", "SettingsButton", "QuitButton"]:
		_check(
			walked.has(required),
			"%s must stay reachable once 이어하기 is gone, got %s" % [required, ", ".join(walked)]
		)

	# With a run on disk the same button has to come back into the chain.
	_reset()
	GameState.day = 3
	_check(SaveManager.save_game(), "the test needs a save file on disk")
	title.refresh()
	await get_tree().process_frame
	_check(continue_button.visible, "an enabled 이어하기 has to be on screen again")
	_check(
		continue_button.focus_mode == Control.FOCUS_ALL,
		"an enabled 이어하기 has to be focusable again"
	)
	_check(
		new_game.find_valid_focus_neighbor(SIDE_BOTTOM) == continue_button,
		"with a save present the arrow keys should reach 이어하기"
	)
	_check(
		_walk_focus_chain(new_game).has("ContinueButton"),
		"with a save present the chain should pass through 이어하기"
	)

	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## Hiding 이어하기 used to make the other plates grow: the column shared its
## leftover space out between whatever rows were still visible, so three rows
## each took more than four did. The menu has to be the same size either way.
## Doc v0.3 section 31 Phase 11.
func _test_title_plates_keep_one_size_without_a_save() -> void:
	SaveManager.delete_save()
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await _settle_layout()

	var safe: Control = title.get_node("Safe/Content")
	var ratio: float = float(title.get(&"plate_height_ratio"))
	var wanted: float = roundf(safe.size.y * ratio)
	var without_save: float = title.get_node("%NewGameButton").size.y
	_check(
		absf(without_save - wanted) <= 1.0,
		"the plate should be %.0f px tall (%.1f%% of the safe area), got %.1f"
			% [wanted, 100.0 * ratio, without_save]
	)
	for plate: String in ["SettingsButton", "QuitButton"]:
		var height: float = title.get_node("%%%s" % plate).size.y
		_check(
			absf(height - without_save) <= 1.0,
			"%s should match 새 게임: %.1f vs %.1f" % [plate, height, without_save]
		)

	# The same screen with a run on disk: one more plate and the progress line
	# join the column, and none of that may resize what was already there.
	_reset()
	GameState.day = 3
	_check(SaveManager.save_game(), "the test needs a save file on disk")
	title.refresh()
	await _settle_layout()
	_check(
		title.get_node("%ContinueButton").visible,
		"the test needs 이어하기 back on screen to compare against"
	)
	for plate: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var height: float = title.get_node("%%%s" % plate).size.y
		_check(
			absf(height - without_save) <= 1.0,
			"a save must not resize %s: %.1f without a save, %.1f with one"
				% [plate, without_save, height]
		)

	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## Exactly one plate may look selected. Dropping the focus outline left the
## plate art as the whole of the selection cue, and the pointer's hover art is
## bright too, so keyboard focus on one plate with the pointer on another used
## to light both and hide where Enter would go. Doc v0.3 section 31 Phase 11.
func _test_title_lights_one_plate_at_a_time() -> void:
	SaveManager.delete_save()
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await _settle_layout()
	_check_one_plate_looks_selected(title, "without a save")

	# With a run on disk 이어하기 joins the column and has to obey the same rule.
	_reset()
	GameState.day = 3
	_check(SaveManager.save_game(), "the test needs a save file on disk")
	title.refresh()
	await _settle_layout()
	_check(title.get_node("%ContinueButton").visible, "the save case needs 이어하기 on screen")
	_check_one_plate_looks_selected(title, "with a save")

	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()


## Walks every (focused plate, hovered plate) pair, including the mixed ones a
## headless run cannot make with a real pointer, and counts the plates that
## would be painted with the selected art. A button draws its hover stylebox
## while the pointer is on it and its normal one otherwise, so reading those two
## back per button is the same thing the windowed harness measures in pixels.
func _check_one_plate_looks_selected(title: Control, state: String) -> void:
	var plates: Array[Button] = []
	for plate: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button: Button = title.get_node("%%%s" % plate)
		if button.visible and button.focus_mode != Control.FOCUS_NONE:
			plates.append(button)
	_check(plates.size() >= 3, "%s: the title should offer at least three plates" % state)
	var selected: StyleBox = plates[0].get_theme_stylebox("selected", "TitleButton")
	for focused: Button in plates:
		focused.grab_focus()
		# The pointer parked off every plate (index -1), then on each in turn.
		for index: int in range(-1, plates.size()):
			var hovered: Button = null if index < 0 else plates[index]
			var lit: Array[String] = []
			for button: Button in plates:
				var drawn: StyleBox = button.get_theme_stylebox(
					"hover" if button == hovered else "normal", "TitleButton"
				)
				if _plate_art_of(drawn) == _plate_art_of(selected):
					lit.append(String(button.name))
			var pointer: String = "nothing" if hovered == null else String(hovered.name)
			_check(
				lit.size() == 1 and lit[0] == String(focused.name),
				"%s: focus on %s with the pointer on %s should light %s alone, lit %s"
					% [state, focused.name, pointer, focused.name, str(lit)]
			)


## Which of the two plate textures a stylebox paints. Comparing the texture
## rather than the stylebox itself is what makes the hover and pressed variants,
## which only differ by a modulate, count as the same plate art.
func _plate_art_of(style: StyleBox) -> Texture2D:
	var textured := style as StyleBoxTexture
	return null if textured == null else textured.texture


## Containers only re-sort on the frame after a minimum size changes, and the
## plate height is applied from a resize signal, so measuring takes a few frames.
func _settle_layout() -> void:
	for _frame in 4:
		await get_tree().process_frame


## Names of every control the down arrow reaches, starting from `first`. Bounded
## so a chain that loops back on itself cannot hang the suite.
func _walk_focus_chain(first: Control) -> Array[String]:
	var seen: Array[String] = []
	var cursor: Control = first
	for _step in 8:
		if cursor == null or seen.has(String(cursor.name)):
			break
		seen.append(String(cursor.name))
		cursor = cursor.find_valid_focus_neighbor(SIDE_BOTTOM)
	return seen


## Hiding a row must not leave a hole behind it: whatever is still on screen
## stays in one column, with the theme's separation between every neighbouring
## pair and a single shared width.
func _check_remaining_stack_is_intact(title: Control) -> void:
	var box: VBoxContainer = title.get_node("Safe/Content/Box")
	var separation: float = float(box.get_theme_constant(&"separation"))
	var previous: Control = null
	for child: Control in box.get_children():
		if not child.visible:
			continue
		if previous != null:
			var gap: float = child.position.y - previous.position.y - previous.size.y
			_check(
				absf(gap - separation) <= 1.0,
				"the stack should keep a %.0f px gap, got %.1f between %s and %s"
					% [separation, gap, previous.name, child.name]
			)
			_check(
				absf(child.position.x - previous.position.x) <= 1.0
					and absf(child.size.x - previous.size.x) <= 1.0,
				"%s should stay aligned with %s" % [child.name, previous.name]
			)
		previous = child
	_check(previous != null, "the title stack must not be empty")
