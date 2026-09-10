extends Node

## Headless Day 1~200 balance instrumentation. Doc v0.3 section 34.
## Run:  godot --headless --path . res://tests/sim_balance.tscn
## Writes tests/qa_artifacts/f8/sim_metrics.json and sim_report.md.
##
## Everything that decides a number is the shipping system, not a copy of it:
##   GameState            energy, click damage, crit roll, gold multiplier,
##                        jamo inventory, word completion, word bonuses
##   GameBalance (.tres)  monster HP / gold per day
##   UpgradeManager       purchase rules, day gates, prices from the .tres
##   CandidateGenerator   day-end candidate pool and rerolls
##   SpawnManager         which pool a spawn comes from and which jamo inside it
##   StatusEffectInstance burn ticks
##   JamoMonsterData      per-jamo hp / gold multipliers and lifetime
##
## What is modelled instead of played, because a headless run has no renderer
## and no mouse. Listed here so a reader never mistakes it for measured data:
##   - the field is a plain list, not 3D bodies; a dead monster is replaced at
##     once instead of after SpawnManager.spawn_interval
##   - a click always lands, so click difficulty (size, speed, turns) is out
##   - the spread of 불꽃 picks random living neighbours: an abstract field has
##     no positions, so the effect radius cannot be applied. chain_count and
##     max_chain_depth are the real ones
##   - wall-clock day length is derived from SECONDS_PER_CLICK below

const OUT_DIR := "res://tests/qa_artifacts/f8/variants"
const WORLD_SCENE := "res://scenes/world/game_world.tscn"
const BACKUP_PATH := "user://jamo_save.json.simbak"

const LAST_DAY := 200
## Fixed so two runs of the harness produce the same table.
const RANDOM_SEED := 20260910
## Seconds an average player spends picking a target and clicking it. The only
## invented constant in the harness; every "seconds" figure scales with it.
const SECONDS_PER_CLICK := 1.1
## Give up on a day that will not end, so a balance mistake reports instead of
## hanging the run.
const MAX_CLICKS_PER_DAY := 2000
## Days sampled in the printed table.
const SAMPLE_DAYS: Array[int] = [1, 2, 3, 5, 10, 15, 25, 40, 50, 60, 75, 100, 150, 200]


## One monster on the abstract field.
class SimMonster extends RefCounted:
	var data: JamoMonsterData
	var max_hp: float
	var hp: float
	## Seconds it has been on the field, against data.lifetime_seconds.
	var age: float = 0.0
	var burn: StatusEffectInstance = null
	var burn_chain_depth: int = 0

	func _init(monster_data: JamoMonsterData, day_hp: float) -> void:
		data = monster_data
		max_hp = day_hp * monster_data.hp_multiplier
		hp = max_hp

	func is_alive() -> bool:
		return hp > 0.0

	func is_burning() -> bool:
		return burn != null and not burn.is_expired()

	## FinalGold = BaseGold * MonsterGoldMultiplier * PermanentGoldMultiplier,
	## the same product JamoMonster._calculate_gold_reward() forms.
	func gold_reward(day_gold: float) -> float:
		return day_gold * data.gold_multiplier * GameState.get_gold_multiplier()


var _world: Node3D
var _spawner: SpawnManager
var _field: Array[SimMonster] = []
var _days: Array[Dictionary] = []
## word id -> day it was completed on.
var _word_days: Dictionary = {}
## upgrade id -> array of days a level was bought on.
var _purchase_days: Dictionary = {}
var _failures: int = 0
## Filename tag for this variant, e.g. "gold1025".
var _tag: String = "base"


## QA-only: rolls the shipping .tres values back to a documented or pre-F8
## state IN MEMORY so the same harness can be re-run against them. Nothing is
## written back to disk; the .tres files are never touched.
func _apply_overrides() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var parts: Array[String] = []
	var balance: GameBalance = GameState.balance
	for arg: String in args:
		match arg:
			"gold-doc":
				balance.gold_growth_per_day = 1.025
				parts.append("gold1025")
			"hp-doc-match":
				balance.hp_growth_per_day = 1.025
				parts.append("hp1025")
			"damage-doc":
				var d: UpgradeData = GameState.database.find_upgrade(&"click_damage")
				d.values = PackedFloat32Array([2, 3, 4, 5, 6, 7, 8, 9, 10])
				d.costs = PackedInt64Array([100, 250, 600, 1400, 3200, 7000, 15000, 32000, 70000])
				parts.append("dmgdoc")
			"prices-doc":
				_set_costs(&"max_energy", [50, 90, 160, 280, 500, 900, 1600, 2800, 5000, 9000])
				_set_costs(&"gold_bonus", [100, 220, 500, 1100, 2500, 5500, 12000, 26000, 55000, 120000])
				_set_costs(&"monster_capacity", [200, 500, 1200, 3000, 7500, 18000])
				_set_costs(&"reroll", [1000, 7500, 50000])
				_set_costs(&"critical_click", [1500, 4000, 10000, 25000, 60000])
				parts.append("pricedoc")
			_:
				push_warning("unknown variant flag: %s" % arg)
	if not parts.is_empty():
		_tag = "_".join(parts)
	print("VARIANT tag=%s hp=%.3f gold=%.3f" % [
		_tag, balance.hp_growth_per_day, balance.gold_growth_per_day
	])


func _set_costs(upgrade_id: StringName, costs: Array) -> void:
	var upgrade: UpgradeData = GameState.database.find_upgrade(upgrade_id)
	upgrade.costs = PackedInt64Array(costs)


func _ready() -> void:
	seed(RANDOM_SEED)
	_apply_overrides()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()

	_world = (load(WORLD_SCENE) as PackedScene).instantiate()
	add_child(_world)
	_spawner = _world.get_node("SpawnManager")
	# The spawner is used as the pool chooser only. Leaving it processing would
	# also start filling the real 3D field, which this harness does not use.
	_spawner.set_process(false)

	_reset_run()
	for day in range(1, LAST_DAY + 1):
		_play_day(day)
	_write_reports()

	_world.queue_free()
	_restore_save()

	if _failures == 0:
		print("OK - simulated Day 1..%d." % LAST_DAY)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d problem(s) during the run." % _failures)
		get_tree().quit(1)


## A brand new run, so the simulation never inherits the player's progress.
func _reset_run() -> void:
	GameState.day = 1
	GameState.gold = 0.0
	GameState.upgrade_levels.clear()
	GameState.unlocked_word_ids.clear()
	GameState.jamo_inventory.clear()
	GameState.target_word_id = &""
	GameState.from_dict(GameState.to_dict())
	GameState.begin_day()


# --- One day ---------------------------------------------------------------

func _play_day(day: int) -> void:
	var record: Dictionary = {
		"day": day,
		"max_energy": GameState.get_max_energy(),
		"monster_capacity": GameState.get_monster_capacity(),
		"base_hp": GameState.balance.monster_hp_for_day(day),
		"base_gold": GameState.balance.monster_gold_for_day(day),
		"click_damage": GameState.get_click_damage(),
		"crit_chance": GameState.get_crit_chance(),
		"gold_multiplier": GameState.get_gold_multiplier(),
		"clicks": 0,
		"kills": 0,
		"special_kills": 0,
		"golden_kills": 0,
		"missed_specials": 0,
		"dot_kills": 0,
		"crit_clicks": 0,
		"hp_sum": 0.0,
		"hp_samples": 0,
		"damage_click": 0.0,
		"damage_crit_extra": 0.0,
		"damage_burn": 0.0,
		"seconds": 0.0,
		"rerolls_used": 0,
		"candidate_misses": 0,
		"field_size": 0,
	}

	_field.clear()
	_refill(day, record)

	while GameState.can_click() and int(record["clicks"]) < MAX_CLICKS_PER_DAY:
		_click_once(day, record)
		_advance_time(day, SECONDS_PER_CLICK, record)
		_refill(day, record)
	if int(record["clicks"]) >= MAX_CLICKS_PER_DAY:
		_failures += 1
		printerr("  Day %d did not end within %d clicks." % [day, MAX_CLICKS_PER_DAY])

	# Doc v0.3 section 12: lingering damage-over-time resolves before the
	# day-end UI, and any kill it lands still pays out.
	_advance_time(day, GameState.balance.day_end_settle_seconds, record)

	_run_day_end(day, record)
	record["gold_earned"] = GameState.gold_earned_today
	record["gold_after"] = GameState.gold
	record["words_unlocked"] = GameState.unlocked_word_ids.size()
	_days.append(record)

	GameState.advance_day()


## Auto player: golden first, then special, then whichever normal monster is
## closest to dying. Finishing the weakest normal wastes the fewest clicks on
## overkill, which is what an attentive player converges on.
func _pick_target() -> SimMonster:
	var best: SimMonster = null
	var best_rank: int = -1
	for monster: SimMonster in _field:
		if not monster.is_alive():
			continue
		var rank: int = _priority(monster)
		if best == null or rank > best_rank \
				or (rank == best_rank and monster.hp < best.hp):
			best = monster
			best_rank = rank
	return best


static func _priority(monster: SimMonster) -> int:
	match monster.data.special_type:
		JamoMonsterData.SpecialType.GOLDEN:
			return 2
		JamoMonsterData.SpecialType.SPECIAL:
			return 1
		_:
			return 0


func _click_once(day: int, record: Dictionary) -> void:
	var target: SimMonster = _pick_target()
	if target == null:
		return
	if not GameState.spend_click_energy():
		return
	record["clicks"] = int(record["clicks"]) + 1
	record["hp_sum"] = float(record["hp_sum"]) + target.max_hp
	record["hp_samples"] = int(record["hp_samples"]) + 1

	# One critical roll per click, shared by the gold upgrade and 강타.
	var is_critical: bool = GameState.roll_critical()
	var damage: float = GameState.get_click_damage(is_critical)
	if is_critical:
		record["crit_clicks"] = int(record["crit_clicks"]) + 1
		var plain: float = GameState.get_click_damage(false)
		record["damage_click"] = float(record["damage_click"]) + plain
		record["damage_crit_extra"] = float(record["damage_crit_extra"]) + damage - plain
	else:
		record["damage_click"] = float(record["damage_click"]) + damage

	target.hp -= damage
	var burn: WordEffectData = GameState.get_burn_effect()
	if burn != null:
		_apply_burn(target, burn, 0)
	if not target.is_alive():
		_kill(target, day, record, false)


func _apply_burn(monster: SimMonster, burn: WordEffectData, chain_depth: int) -> void:
	monster.burn_chain_depth = chain_depth
	if monster.burn == null or monster.burn.is_expired():
		monster.burn = StatusEffectInstance.new(burn)
	else:
		monster.burn.refresh(burn)


## Runs `seconds` of world time: burn ticks, lifetimes, and the deaths both can
## cause. Kills landed here cost no energy, which is what makes the "energy
## saved by status effects" figure meaningful.
func _advance_time(day: int, seconds: float, record: Dictionary) -> void:
	record["seconds"] = float(record["seconds"]) + seconds
	for monster: SimMonster in _field.duplicate():
		if not monster.is_alive():
			continue
		monster.age += seconds
		if monster.burn != null and not monster.burn.is_expired():
			var damage: float = monster.burn.advance(seconds)
			if damage > 0.0:
				record["damage_burn"] = float(record["damage_burn"]) + damage
				monster.hp -= damage
				if not monster.is_alive():
					_kill(monster, day, record, true)
					continue
		var lifetime: float = monster.data.lifetime_seconds
		if lifetime > 0.0 and monster.age >= lifetime:
			_expire(monster, record)


func _kill(monster: SimMonster, day: int, record: Dictionary, by_status: bool) -> void:
	monster.hp = 0.0
	var reward: float = monster.gold_reward(GameState.balance.monster_gold_for_day(day))
	GameState.register_kill(monster.data.jamo, reward, Vector3.ZERO)
	record["kills"] = int(record["kills"]) + 1
	if by_status:
		record["dot_kills"] = int(record["dot_kills"]) + 1
	match monster.data.special_type:
		JamoMonsterData.SpecialType.GOLDEN:
			record["golden_kills"] = int(record["golden_kills"]) + 1
		JamoMonsterData.SpecialType.SPECIAL:
			record["special_kills"] = int(record["special_kills"]) + 1
	_spread_burn_from(monster)
	_field.erase(monster)


## The monster left on its own before it was killed, so it pays no gold.
func _expire(monster: SimMonster, record: Dictionary) -> void:
	if monster.data.special_type != JamoMonsterData.SpecialType.NORMAL:
		record["missed_specials"] = int(record["missed_specials"]) + 1
	_field.erase(monster)


## 불꽃. chain_count and max_chain_depth come from the word; the neighbours are
## picked at random because the abstract field carries no positions.
func _spread_burn_from(source: SimMonster) -> void:
	var spread: WordEffectData = GameState.get_burn_spread_effect()
	if spread == null or not source.is_burning():
		return
	if source.burn_chain_depth + 1 > spread.max_chain_depth:
		return
	var burn: WordEffectData = GameState.get_burn_effect()
	if burn == null:
		return
	var candidates: Array[SimMonster] = []
	for monster: SimMonster in _field:
		if monster != source and monster.is_alive():
			candidates.append(monster)
	candidates.shuffle()
	for i in mini(spread.chain_count, candidates.size()):
		_apply_burn(candidates[i], burn, source.burn_chain_depth + 1)


## Tops the field back up to the current capacity, asking the real SpawnManager
## which pool and which jamo each new monster comes from. The underscore-named
## helpers are called on purpose: copying that pick into the harness would make
## the special and golden rates a second model instead of the shipping one.
func _refill(day: int, record: Dictionary) -> void:
	var day_hp: float = GameState.balance.monster_hp_for_day(day)
	while _field.size() < GameState.get_monster_capacity():
		var scene: PackedScene = _spawner._pick_scene(_spawner._pick_pool())
		if scene == null:
			_failures += 1
			printerr("  Day %d: the spawn pool returned nothing." % day)
			return
		var data: JamoMonsterData = _spawner._data_for(scene)
		if data == null:
			_failures += 1
			printerr("  Day %d: %s carries no JamoMonsterData." % [day, scene.resource_path])
			return
		# The repeat penalty lives on the spawner, so the harness has to move it
		# along the same way _spawn_one() would.
		_spawner._last_spawned_id = data.id
		_field.append(SimMonster.new(data, day_hp))
	record["field_size"] = _field.size()


# --- Day end ---------------------------------------------------------------

func _run_day_end(day: int, record: Dictionary) -> void:
	var count: int = GameState.get_jamo_candidate_count()
	var candidates: PackedStringArray = CandidateGenerator.generate(count)

	# Reroll policy: spend one only when nothing on offer moves a craftable word
	# forward, which is the case the 리롤 upgrade exists for.
	while not candidates.is_empty() and not _has_useful_jamo(candidates) 			and GameState.can_reroll():
		GameState.consume_reroll()
		record["rerolls_used"] = int(record["rerolls_used"]) + 1
		candidates = CandidateGenerator.regenerate(count, candidates)
	if not candidates.is_empty() and not _has_useful_jamo(candidates):
		record["candidate_misses"] = 1

	var picked: String = _pick_jamo(candidates)
	if not picked.is_empty():
		GameState.add_jamo(picked)
	for word: WordData in GameState.complete_ready_words():
		_word_days[String(word.id)] = day

	_shop(day)


## True when at least one candidate is still needed by a craftable word.
func _has_useful_jamo(candidates: PackedStringArray) -> bool:
	var wanted: Dictionary = CandidateGenerator.build_weights()
	for jamo: String in candidates:
		if float(wanted.get(jamo, 0.0)) > CandidateGenerator.FILLER_WEIGHT:
			return true
	return false


## Takes whichever candidate the craftable words want most, falling back to the
## first offer. growth_balance v0.2 section 15: one jamo a day is what sets the
## pace, so the pick has to be the useful one.
func _pick_jamo(candidates: PackedStringArray) -> String:
	if candidates.is_empty():
		return ""
	var weights: Dictionary = CandidateGenerator.build_weights()
	var best: String = candidates[0]
	var best_weight: float = -1.0
	for jamo: String in candidates:
		var weight: float = float(weights.get(jamo, 0.0))
		if weight > best_weight:
			best = jamo
			best_weight = weight
	return best


## Buys the cheapest available thing over and over, which is the "small growth
## almost every day" player doc v0.3 section 34 describes. When nothing is
## affordable the gold simply carries over, and that carry-over is what the Gold
## warning in section 35 is measured from.
func _shop(day: int) -> void:
	while true:
		var cheapest: UpgradeData = null
		var cheapest_cost: int = -1
		for upgrade: UpgradeData in GameState.database.upgrades:
			if UpgradeManager.get_availability(upgrade) != UpgradeManager.Availability.AVAILABLE:
				continue
			var cost: int = upgrade.cost_for_next(GameState.get_upgrade_level(upgrade.id))
			if cheapest == null or cost < cheapest_cost:
				cheapest = upgrade
				cheapest_cost = cost
		if cheapest == null:
			return
		if not UpgradeManager.purchase(cheapest):
			return
		var key: String = String(cheapest.id)
		if not _purchase_days.has(key):
			_purchase_days[key] = []
		(_purchase_days[key] as Array).append(day)


# --- Reporting -------------------------------------------------------------

func _write_reports() -> void:
	var payload: Dictionary = {
		"seed": RANDOM_SEED,
		"seconds_per_click": SECONDS_PER_CLICK,
		"last_day": LAST_DAY,
		"days": _days,
		"word_days": _word_days,
		"purchase_days": _purchase_days,
	}
	_save_text("%s/%s_metrics.json" % [OUT_DIR, _tag], JSON.stringify(payload, "\t"))
	var markdown: String = _build_markdown()
	_save_text("%s/%s_report.md" % [OUT_DIR, _tag], markdown)
	print(markdown)


func _save_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures += 1
		printerr("  could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.close()


func _build_markdown() -> String:
	var lines: Array[String] = []
	lines.append("# JAMO 밸런스 계측 (Day 1~%d)" % LAST_DAY)
	lines.append("")
	lines.append("- seed `%d`, seconds per click `%.2f`" % [RANDOM_SEED, SECONDS_PER_CLICK])
	lines.append("- 자동 플레이어: 황금 > 특수 > 남은 HP 가 가장 적은 일반")
	lines.append("- 상점 정책: 매일 살 수 있는 것 중 가장 싼 것을 못 살 때까지")
	lines.append("- 리롤 정책: 후보 전부가 쓸모없을 때만 사용")
	lines.append("")
	lines.append("| Day | Energy | Clicks | Kills | Gold/Day | Gold/Click"
		+ " | Avg HP | Day len (s) | Special % | DoT kills | Words |")
	lines.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for record: Dictionary in _days:
		if not SAMPLE_DAYS.has(int(record["day"])):
			continue
		lines.append(_row(record))
	lines.append("")
	lines.append(_word_section())
	lines.append("")
	lines.append(_purchase_section())
	lines.append("")
	lines.append(_damage_section())
	return "\n".join(lines) + "\n"


func _row(record: Dictionary) -> String:
	var clicks: int = int(record["clicks"])
	var kills: int = int(record["kills"])
	var earned: float = float(record["gold_earned"])
	var samples: int = maxi(1, int(record["hp_samples"]))
	var specials: int = int(record["special_kills"]) + int(record["golden_kills"])
	return "| %d | %d | %d | %d | %.0f | %.2f | %.0f | %.0f | %.2f%% | %d | %d |" % [
		int(record["day"]), int(record["max_energy"]), clicks, kills, earned,
		earned / maxi(1, clicks), float(record["hp_sum"]) / samples,
		float(record["seconds"]), 100.0 * specials / maxi(1, kills),
		int(record["dot_kills"]), int(record["words_unlocked"]),
	]


func _word_section() -> String:
	var lines: Array[String] = [
		"## Days per Word", "",
		"| 단어 | 완성 Day | 직전 단어와의 간격 |", "|---|---:|---:|",
	]
	var ordered: Array = _word_days.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return int(_word_days[a]) < int(_word_days[b]))
	var previous: int = 0
	for word_id: String in ordered:
		var day: int = int(_word_days[word_id])
		var word: WordData = GameState.database.find_word(StringName(word_id))
		lines.append("| %s | %d | %d |" % [
			word.word if word != null else word_id, day, day - previous
		])
		previous = day
	if ordered.is_empty():
		lines.append("| (없음) | - | - |")
	return "\n".join(lines)


func _purchase_section() -> String:
	var lines: Array[String] = [
		"## Upgrade purchase interval", "",
		"| 트랙 | 구매 횟수 | 첫 구매 Day | 마지막 구매 Day | 평균 간격 |",
		"|---|---:|---:|---:|---:|",
	]
	for upgrade: UpgradeData in GameState.database.upgrades:
		var key: String = String(upgrade.id)
		var days: Array = _purchase_days.get(key, [])
		if days.is_empty():
			lines.append("| %s | 0 | - | - | - |" % upgrade.display_name)
			continue
		var first: int = int(days[0])
		var last: int = int(days[days.size() - 1])
		var gap: float = float(last - first) / maxi(1, days.size() - 1)
		lines.append("| %s | %d | %d | %d | %.1f |" % [
			upgrade.display_name, days.size(), first, last, gap
		])
	lines.append("")
	lines.append(_idle_gold_section())
	return "\n".join(lines)


## The Gold warning of doc v0.3 section 35: the longest run of days in a row
## where nothing was bought and the purse only grew.
func _idle_gold_section() -> String:
	var streak: int = 0
	var first_idle_day: int = 0
	var longest: int = 0
	var longest_start: int = 0
	for record: Dictionary in _days:
		var day: int = int(record["day"])
		var bought: bool = false
		for key: String in _purchase_days:
			if (_purchase_days[key] as Array).has(day):
				bought = true
				break
		if bought:
			streak = 0
			continue
		if streak == 0:
			first_idle_day = day
		streak += 1
		if streak > longest:
			longest = streak
			longest_start = first_idle_day
	return "가장 긴 무구매 구간: Day %d 부터 %d 일" % [longest_start, longest]


func _damage_section() -> String:
	var click: float = 0.0
	var crit: float = 0.0
	var burn: float = 0.0
	var dot_kills: int = 0
	var kills: int = 0
	var missed: int = 0
	var rerolls: int = 0
	var misses: int = 0
	for record: Dictionary in _days:
		click += float(record["damage_click"])
		crit += float(record["damage_crit_extra"])
		burn += float(record["damage_burn"])
		dot_kills += int(record["dot_kills"])
		kills += int(record["kills"])
		missed += int(record["missed_specials"])
		rerolls += int(record["rerolls_used"])
		misses += int(record["candidate_misses"])
	var total: float = maxf(1.0, click + crit + burn)
	return "\n".join([
		"## Damage source breakdown (Day 1~%d 누적)" % LAST_DAY,
		"",
		"| 출처 | 피해 | 비율 |",
		"|---|---:|---:|",
		"| 클릭 기본 | %.0f | %.1f%% |" % [click, 100.0 * click / total],
		"| 치명 추가분 | %.0f | %.1f%% |" % [crit, 100.0 * crit / total],
		"| 화상 (DoT) | %.0f | %.1f%% |" % [burn, 100.0 * burn / total],
		"",
		"상태이상이 아낀 에너지: %d 킬 (전체 %d 킬의 %.1f%%)" % [
			dot_kills, kills, 100.0 * dot_kills / maxi(1, kills)
		],
		"놓친 특수/황금 개체: %d 마리" % missed,
		"리롤 사용: %d 회 / 쓸모없는 후보로 끝난 Day: %d 일" % [rerolls, misses],
	])


# --- Save file protection --------------------------------------------------
# UpgradeManager.purchase() writes the real save, so the player's run is moved
# aside for the length of the simulation and put back afterwards.

func _stash_save() -> void:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		ProjectSettings.globalize_path(BACKUP_PATH)
	)


func _restore_save() -> void:
	SaveManager.delete_save()
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	)
