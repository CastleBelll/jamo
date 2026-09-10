extends Node

## Permanent progression. Everything here survives a failed run.
## Doc v0.4 sections 3.1 and 44 (MetaState).
##
## The boundary with RunState is the whole point of this file: if a field would
## be wiped when the run ends, it belongs in RunState and must never be added
## here. See tests/test_state_split.gd, which fails the build when the two
## states start overlapping.
##
## Balance numbers are not written in this file. They come from
## res://resources/balance/game_database.tres, editable in the Inspector.

const DATABASE_PATH := "res://resources/balance/game_database.tres"

## Upgrade ids, matching the .tres files under res://resources/upgrades/.
const UPGRADE_MAX_ENERGY := &"max_energy"
const UPGRADE_CLICK_DAMAGE := &"click_damage"
const UPGRADE_CRITICAL_CLICK := &"critical_click"
const UPGRADE_GOLD_BONUS := &"gold_bonus"
const UPGRADE_MONSTER_CAPACITY := &"monster_capacity"
const UPGRADE_REROLL := &"reroll"

## Names RunState owns. A permanent field may never be called one of these, and
## the split test asserts it. Doc v0.4 section 3.2.
const RUN_OWNED_NAMES: Array[String] = [
	"current_wave", "core_hp", "core_max_hp", "current_energy",
	"jamo_draw_bag", "jamo_discard_bag", "current_slot_jamo", "rerolls",
	"locks", "equipped_words", "run_word_ranks", "active_synergies",
	"active_compounds", "risk_words", "run_modifiers", "run_statistics",
]

var database: GameDatabase
var balance: GameBalance

# --- Permanent state, doc v0.4 section 44 -----------------------------------

## Format version of the save this state was read from. SaveManager owns the
## number; it is mirrored here so the result screen and tests can read it.
var save_version: int = 0
var gold: float = 0.0
## upgrade id -> purchased level.
var permanent_upgrade_levels: Dictionary = {}
## Words the player has ever crafted. Registration is permanent; the *effect*
## is not - that lives in RunState.equipped_words. Doc v0.4 section 38.
var codex_words: Array[StringName] = []
## word id -> accumulated mastery experience.
var codex_mastery_exp: Dictionary = {}
## word id -> mastery level. Filled from Phase 4 on.
var codex_mastery_levels: Dictionary = {}
var discovered_compounds: Array[StringName] = []
var discovered_synergies: Array[StringName] = []
var defeated_word_bosses: Array[StringName] = []
## Best wave ever reached, 1 before the first run ends.
var highest_wave: int = 1
## Free-form lifetime counters, e.g. runs_played / total_kills.
var statistics: Dictionary = {}


func _ready() -> void:
	database = load(DATABASE_PATH) as GameDatabase
	if database == null:
		push_error("MetaState: could not load GameDatabase at %s" % DATABASE_PATH)
		return
	balance = database.balance
	if balance == null:
		push_error("MetaState: GameDatabase has no GameBalance assigned.")


# --- Permanent upgrades -----------------------------------------------------

## Level of an upgrade track, 0 when never purchased.
func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(permanent_upgrade_levels.get(upgrade_id, 0))


## Value an upgrade track currently provides, falling back to base_value at
## level 0.
func get_upgrade_value(upgrade_id: StringName, base_value: float) -> float:
	var upgrade: UpgradeData = database.find_upgrade(upgrade_id)
	if upgrade == null:
		return base_value
	return upgrade.value_at(get_upgrade_level(upgrade_id), base_value)


func set_upgrade_level(upgrade_id: StringName, level: int) -> void:
	permanent_upgrade_levels[upgrade_id] = maxi(0, level)


## The permanent layer of the click damage formula, before any run word.
## Doc v0.4 section 8.
func get_base_click_damage() -> float:
	return get_upgrade_value(UPGRADE_CLICK_DAMAGE, balance.base_click_damage)


## Max energy from upgrades alone. Run words add on top in RunState.
func get_permanent_max_energy() -> int:
	return int(get_upgrade_value(UPGRADE_MAX_ENERGY, float(balance.start_max_energy)))


func get_permanent_crit_chance() -> float:
	return get_upgrade_value(UPGRADE_CRITICAL_CLICK, 0.0)


func get_permanent_gold_bonus() -> float:
	return get_upgrade_value(UPGRADE_GOLD_BONUS, 0.0)


func get_monster_capacity() -> int:
	return int(get_upgrade_value(
		UPGRADE_MONSTER_CAPACITY, float(balance.base_monster_capacity)
	))


## Rerolls a run starts each wave with, 0 while the track is still at level 0.
func get_base_rerolls() -> int:
	return int(get_upgrade_value(UPGRADE_REROLL, 0.0))


func get_core_max_hp() -> float:
	return balance.base_core_hp


# --- Gold -------------------------------------------------------------------

## Gold is permanent even when the run that earned it fails.
## Doc v0.4 section 14.
func add_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	gold += amount
	SignalBus.gold_changed.emit(gold)


func spend_gold(amount: float) -> bool:
	if amount <= 0.0 or gold < amount:
		return false
	gold -= amount
	SignalBus.gold_changed.emit(gold)
	return true


# --- Codex ------------------------------------------------------------------

func has_codex_word(word_id: StringName) -> bool:
	return codex_words.has(word_id)


## Registers a first discovery. Returns true only the first time, so the caller
## can play the "new word" beat exactly once. Doc v0.4 section 2.7.
func register_codex_word(word_id: StringName) -> bool:
	if word_id == &"" or has_codex_word(word_id):
		return false
	codex_words.append(word_id)
	SignalBus.codex_word_registered.emit(word_id)
	return true


## Mastery experience gained so far for one word. The curve that turns this into
## a level is Phase 4 work; the storage exists now so nothing is lost meanwhile.
func get_mastery_exp(word_id: StringName) -> float:
	return float(codex_mastery_exp.get(word_id, 0.0))


func get_mastery_level(word_id: StringName) -> int:
	return int(codex_mastery_levels.get(word_id, 0))


func add_mastery_exp(word_id: StringName, amount: float) -> void:
	if word_id == &"" or amount <= 0.0:
		return
	codex_mastery_exp[word_id] = get_mastery_exp(word_id) + amount


func register_compound(compound_id: StringName) -> bool:
	return _append_once(discovered_compounds, compound_id)


func register_synergy(synergy_id: StringName) -> bool:
	return _append_once(discovered_synergies, synergy_id)


func register_defeated_boss(boss_id: StringName) -> bool:
	return _append_once(defeated_word_bosses, boss_id)


func has_defeated_boss(boss_id: StringName) -> bool:
	return defeated_word_bosses.has(boss_id)


func _append_once(list: Array[StringName], id: StringName) -> bool:
	if id == &"" or list.has(id):
		return false
	list.append(id)
	return true


# --- Records ----------------------------------------------------------------

## Records the wave a finished run reached. Returns true on a new record.
func record_reached_wave(wave: int) -> bool:
	if wave <= highest_wave:
		return false
	highest_wave = wave
	return true


func get_statistic(key: String) -> float:
	return float(statistics.get(key, 0.0))


func add_statistic(key: String, amount: float) -> void:
	statistics[key] = get_statistic(key) + amount


# --- Save / load ------------------------------------------------------------
# Only ids, levels and values are stored, never the Resources themselves.
# Doc v0.4 section 45.

func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"permanent_upgrade_levels": _string_keyed(permanent_upgrade_levels),
		"codex_words": _string_list(codex_words),
		"codex_mastery_exp": _string_keyed(codex_mastery_exp),
		"codex_mastery_levels": _string_keyed(codex_mastery_levels),
		"discovered_compounds": _string_list(discovered_compounds),
		"discovered_synergies": _string_list(discovered_synergies),
		"defeated_word_bosses": _string_list(defeated_word_bosses),
		"highest_wave": highest_wave,
		"statistics": statistics.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	gold = maxf(0.0, float(data.get("gold", 0.0)))

	permanent_upgrade_levels.clear()
	var stored_upgrades: Dictionary = data.get("permanent_upgrade_levels", {})
	for key: String in stored_upgrades:
		permanent_upgrade_levels[StringName(key)] = int(stored_upgrades[key])

	_fill_id_list(codex_words, data.get("codex_words", []))
	_fill_id_list(discovered_compounds, data.get("discovered_compounds", []))
	_fill_id_list(discovered_synergies, data.get("discovered_synergies", []))
	_fill_id_list(defeated_word_bosses, data.get("defeated_word_bosses", []))

	codex_mastery_exp.clear()
	var stored_exp: Dictionary = data.get("codex_mastery_exp", {})
	for key: String in stored_exp:
		codex_mastery_exp[StringName(key)] = float(stored_exp[key])

	codex_mastery_levels.clear()
	var stored_levels: Dictionary = data.get("codex_mastery_levels", {})
	for key: String in stored_levels:
		codex_mastery_levels[StringName(key)] = int(stored_levels[key])

	highest_wave = maxi(1, int(data.get("highest_wave", 1)))

	statistics.clear()
	var stored_statistics: Dictionary = data.get("statistics", {})
	for key: String in stored_statistics:
		statistics[key] = stored_statistics[key]


## Wipes permanent progress. Only the explicit "start over" path calls this;
## a failed run must never reach it. Doc v0.4 section 3.1.
func reset() -> void:
	from_dict({})
	save_version = 0


func _string_keyed(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[String(key)] = source[key]
	return out


func _string_list(source: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in source:
		out.append(String(id))
	return out


func _fill_id_list(target: Array[StringName], source: Variant) -> void:
	target.clear()
	if not (source is Array):
		return
	for id: Variant in source:
		target.append(StringName(id))
