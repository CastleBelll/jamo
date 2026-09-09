extends Node

## F3 QA probe: backward compatibility of old saves, the shared critical roll,
## and the distance gate on the 불꽃 burn spread.

const CRIT_SAMPLES := 200000


func _ready() -> void:
	_check_legacy_save()
	_check_unknown_word_id()
	_check_crit_rates()
	_check_spread_radius_gate()
	print("OK - compat probe finished.")
	get_tree().quit()


## An old save has no key for anything F3 added; it must still load.
func _check_legacy_save() -> void:
	GameState.from_dict({
		"day": 12,
		"gold": 400.0,
		"upgrade_levels": {"click_damage": 2},
		"unlocked_words": ["fire_001", "power_001"],
		"jamo_inventory": {"ㅂ": 1},
	})
	print("legacy save -> day=%d gold=%.0f words=%s burn=%s energy=%d" % [
		GameState.day, GameState.gold, str(GameState.unlocked_word_ids),
		str(GameState.get_burn_effect() != null), GameState.get_max_energy(),
	])


## A save written by a newer build, opened by a build that lacks the word.
func _check_unknown_word_id() -> void:
	GameState.from_dict({
		"day": 3,
		"gold": 0.0,
		"upgrade_levels": {},
		"unlocked_words": ["fire_001", "does_not_exist_999"],
		"jamo_inventory": {},
	})
	print("unknown word id -> loaded, burn=%s crit=%.2f (no crash)" % [
		str(GameState.get_burn_effect() != null), GameState.get_crit_chance(),
	])


func _check_crit_rates() -> void:
	GameState.upgrade_levels.clear()
	_report_crit("강타 only", [&"power_001", &"power_002"] as Array[StringName])

	GameState.upgrade_levels[GameState.UPGRADE_CRITICAL_CLICK] = 5
	_report_crit("강타 + 치명 클릭 Lv.5", [&"power_001", &"power_002"] as Array[StringName])

	_report_crit("치명 클릭 Lv.5 only", [] as Array[StringName])
	GameState.upgrade_levels.clear()


func _report_crit(label: String, word_ids: Array[StringName]) -> void:
	GameState.unlocked_word_ids = word_ids.duplicate()
	GameState._recalculate_word_bonuses()
	var hits := 0
	for _i in CRIT_SAMPLES:
		if GameState.roll_critical():
			hits += 1
	print("%s -> declared %.3f, measured %.4f over %d rolls" % [
		label, GameState.get_crit_chance(),
		float(hits) / float(CRIT_SAMPLES), CRIT_SAMPLES,
	])


## 불꽃 must only reach a neighbour inside its radius. The DEV suite covers the
## in-range hop; this covers the monster standing too far away.
func _check_spread_radius_gate() -> void:
	GameState.upgrade_levels.clear()
	GameState.unlocked_word_ids = [&"fire_001", &"fire_003"] as Array[StringName]
	GameState._recalculate_word_bonuses()
	var spread: WordEffectData = GameState.get_burn_spread_effect()

	var scene: PackedScene = load("res://scenes/monsters/monster_mieum.tscn")
	var spawner := SpawnManager.new()
	var field := Node3D.new()
	spawner.spawn_root = field
	spawner.monster_scenes = [scene]
	add_child(spawner)
	spawner.add_child(field)
	spawner.set_process(false)

	var monsters: Array[JamoMonster] = []
	for i in 2:
		var monster: JamoMonster = scene.instantiate()
		field.add_child(monster)
		# Just outside the radius, so the nearest neighbour is still too far.
		monster.global_position = Vector3(float(i) * (spread.radius + 0.5), 0.0, 0.0)
		monster.died.connect(spawner._on_monster_died)
		spawner._alive.append(monster)
		monsters.append(monster)

	monsters[0].apply_status_effect(GameState.get_burn_effect())
	monsters[0].take_status_damage(9999.0)
	var spread_out_of_range: bool = monsters[1].get_node("StatusEffects").has(
		WordEffectData.EffectType.UNLOCK_BURN
	)
	print("spread radius gate -> radius %.2fm, neighbour at %.2fm, burning = %s" % [
		spread.radius, spread.radius + 0.5, str(spread_out_of_range),
	])
	spawner.queue_free()
