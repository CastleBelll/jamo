extends Node

## Headless guard for the v0.4 permanent / run boundary.
## Run: godot --headless --path . res://tests/test_state_split.tscn
## Exit code 0 means every assertion held.
##
## It runs as a scene rather than with --script because the autoload singletons
## are only registered as globals once a scene main loop starts.
##
## Three things are checked, in the order doc v0.4 sections 3, 38, 44 and 45
## put them:
##   1. Neither state carries a field that belongs to the other.
##   2. A failed run empties RunState and leaves MetaState untouched.
##   3. A v0.3 save opens without crashing and keeps what can be kept.

const LEGACY_SAVE := {
	"save_version": 1,
	"day": 42,
	"gold": 1234.5,
	"upgrade_levels": {"click_damage": 3, "max_energy": 2},
	"unlocked_words": ["fire_001", "gold_001"],
	"jamo_inventory": {"ㅂ": 2, "ㅜ": 1},
	"rerolls_left": 1,
	"target_word": "fire_002",
}

var _failures: int = 0


func _ready() -> void:
	SaveManager.delete_save()

	_test_no_field_overlap()
	_test_failed_run_clears_only_run_state()
	_test_run_word_effects_are_not_permanent()
	_test_legacy_v03_save_opens()
	_test_failed_run_is_not_resumable()

	SaveManager.delete_save()
	if _failures == 0:
		print("OK - meta/run split holds.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


## Every scripted property of one singleton, ignoring the engine's own Node
## properties and the private caches.
func _own_property_names(node: Node) -> PackedStringArray:
	var names := PackedStringArray()
	for entry: Dictionary in node.get_property_list():
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = entry.get("name", "")
		if name.begins_with("_"):
			continue
		names.append(name)
	return names


## The boundary is structural: a run field simply does not exist on MetaState,
## and a permanent field does not exist on RunState. Doc v0.4 sections 3.1, 3.2.
func _test_no_field_overlap() -> void:
	print("-- field overlap")
	var meta_names := _own_property_names(MetaState)
	var run_names := _own_property_names(RunState)

	for name: String in MetaState.RUN_OWNED_NAMES:
		_check(
			not meta_names.has(name),
			"MetaState must not carry the run field %s" % name
		)
		_check(
			run_names.has(name),
			"RunState is missing the run field %s from doc v0.4 section 44" % name
		)
	for name: String in RunState.META_OWNED_NAMES:
		_check(
			not run_names.has(name),
			"RunState must not carry the permanent field %s" % name
		)
		_check(
			meta_names.has(name),
			"MetaState is missing the permanent field %s from doc v0.4 section 44" % name
		)


## Doc v0.4 section 3.2: a defeat wipes the run and nothing else.
func _test_failed_run_clears_only_run_state() -> void:
	print("-- failed run")
	MetaState.reset()
	MetaState.gold = 500.0
	MetaState.set_upgrade_level(MetaState.UPGRADE_CLICK_DAMAGE, 4)
	MetaState.register_codex_word(&"fire_001")
	MetaState.register_defeated_boss(&"boss_silence")
	MetaState.highest_wave = 3

	RunState.start_run()
	RunState.begin_wave(7)
	RunState.equip_word(MetaState.database.find_word(&"power_001"))
	RunState.jamo_draw_bag = PackedStringArray(["ㅂ", "ㅜ"])
	RunState.add_run_statistic("kills", 12.0)
	RunState.add_gold(60.0)
	_check(RunState.is_active, "the run is running before it fails")
	_check(
		MetaState.gold == 560.0,
		"run gold banks into MetaState as it drops, not at the end"
	)

	RunState.end_run()
	RunState.reset()

	_check(not RunState.is_active, "a failed run is no longer active")
	_check(RunState.current_wave == 1, "the next run starts at Wave 1")
	_check(RunState.equipped_words.is_empty(), "run words are gone")
	_check(RunState.run_word_ranks.is_empty(), "run ranks are gone")
	_check(RunState.jamo_draw_bag.is_empty(), "the run jamo bag is gone")
	_check(RunState.run_statistics.is_empty(), "run statistics are gone")
	_check(RunState.get_click_damage() == MetaState.get_base_click_damage(),
		"the cleared run adds nothing to click damage any more")

	_check(MetaState.gold == 560.0, "gold survives the defeat")
	_check(MetaState.get_upgrade_level(MetaState.UPGRADE_CLICK_DAMAGE) == 4,
		"permanent upgrades survive the defeat")
	_check(MetaState.has_codex_word(&"fire_001"), "the codex survives the defeat")
	_check(MetaState.has_codex_word(&"power_001"),
		"a word crafted during the run stays in the codex after the defeat")
	_check(MetaState.has_defeated_boss(&"boss_silence"),
		"boss records survive the defeat")
	_check(MetaState.highest_wave == 7, "the reached wave became the new record")


## Doc v0.4 section 38: being in the codex is not the same as being active.
func _test_run_word_effects_are_not_permanent() -> void:
	print("-- codex is not an effect")
	MetaState.reset()
	RunState.reset()
	var him: WordData = MetaState.database.find_word(&"power_001")
	_check(him != null, "the word 힘 is in the database")
	var base := RunState.get_click_damage()

	MetaState.register_codex_word(him.id)
	_check(
		RunState.get_click_damage() == base,
		"a codex entry alone must not change click damage"
	)

	RunState.start_run()
	RunState.equip_word(him)
	_check(
		RunState.get_click_damage() > base,
		"the same word equipped in a run does change click damage"
	)

	RunState.reset()
	_check(
		RunState.get_click_damage() == base,
		"the effect is gone once the run is cleared, even though the codex is not"
	)
	_check(MetaState.has_codex_word(him.id), "the codex entry itself is still there")


## Doc v0.4 section 45 plus the task rule that a user save is never silently
## dropped: an old file loads, keeps what maps, and says so on disk.
func _test_legacy_v03_save_opens() -> void:
	print("-- v0.3 save")
	MetaState.reset()
	RunState.reset()
	_write_raw(LEGACY_SAVE)

	var loaded := SaveManager.load_game()
	_check(loaded, "a v0.3 save still counts as progress worth loading")
	_check(SaveManager.migrated_from_v03, "the load reports that it migrated")
	_check(MetaState.gold == 1234.5, "gold carried over")
	_check(MetaState.get_upgrade_level(MetaState.UPGRADE_CLICK_DAMAGE) == 3,
		"upgrade levels carried over")
	_check(MetaState.has_codex_word(&"fire_001") and MetaState.has_codex_word(&"gold_001"),
		"unlocked words became codex entries")
	_check(MetaState.highest_wave == 1,
		"Day 42 must not be handed over as a Wave 42 record")
	_check(not SaveManager.has_run_save(),
		"a v0.3 file offers no run to continue")

	var rewritten: Dictionary = SaveManager.peek_save()
	_check(int(rewritten.get("save_version", 0)) == SaveManager.SAVE_VERSION,
		"the file was rewritten in the v0.4 shape")
	_check(rewritten.has("legacy_v03"),
		"the original v0.3 payload is kept rather than discarded")
	var legacy: Dictionary = rewritten.get("legacy_v03", {})
	_check(int(legacy.get("day", 0)) == 42,
		"the kept payload still holds the Day the player reached")

	# Loading the migrated file a second time must be a no-op, not a re-migration.
	SaveManager.load_game()
	_check(not SaveManager.migrated_from_v03,
		"a file that is already v0.4 does not migrate again")
	_check(MetaState.gold == 1234.5, "the second load did not lose gold")


## Doc v0.4 section 44: an interrupted run can be resumed, a defeated one cannot.
func _test_failed_run_is_not_resumable() -> void:
	print("-- resume rules")
	SaveManager.delete_save()
	MetaState.reset()
	RunState.start_run()
	RunState.begin_wave(4)
	SaveManager.save_run()
	_check(SaveManager.has_run_save(), "a live run is written out for resuming")
	_check(int(SaveManager.peek_run().get("current_wave", 0)) == 4,
		"the stored run remembers its wave")

	RunState.reset()
	_check(SaveManager.load_run(), "the stored run loads back")
	_check(RunState.current_wave == 4 and RunState.is_active,
		"the resumed run is the one that was saved")

	# Now fail it the way main.gd does.
	RunState.end_run()
	SaveManager.clear_run()
	_check(not SaveManager.has_run_save(), "a defeated run leaves nothing to resume")
	_check(SaveManager.has_save(), "permanent progress is still on disk")
	_check(not SaveManager.load_run(), "loading a run that is gone reports failure")
	_check(not RunState.is_active, "and leaves RunState empty rather than half-filled")

	# A file whose core already fell must not be offered either, even if some
	# earlier build wrote one out.
	var payload: Dictionary = SaveManager.peek_save()
	payload["run"] = {"current_wave": 9, "core_hp": 0.0, "core_max_hp": 20.0}
	_write_raw(payload)
	_check(not SaveManager.has_run_save(),
		"a stored run with no core HP left is not resumable")


func _write_raw(payload: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
