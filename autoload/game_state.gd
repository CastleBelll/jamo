extends Node

## Authoritative runtime state and the single place stats are derived.
##
## Everything here except the "today" block is permanent: the game never resets
## to Day 1. Doc v0.3 section 2.1.
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

var database: GameDatabase
var balance: GameBalance

# --- Permanent state -------------------------------------------------------
var day: int = 1
var gold: float = 0.0
## upgrade id -> purchased level.
var upgrade_levels: Dictionary = {}
var unlocked_word_ids: Array[StringName] = []
## jamo character -> how many are held.
var jamo_inventory: Dictionary = {}

# --- Per-day state ---------------------------------------------------------
var energy: int = 0
var kills_today: int = 0
var gold_earned_today: float = 0.0

# --- Cached word bonuses, refreshed by _recalculate_word_bonuses() ---------
var _word_flat_click_damage: float = 0.0
var _word_click_multiplier: float = 1.0
var _word_crit_chance: float = 0.0
var _word_crit_multiplier: float = 0.0
var _word_gold_bonus: float = 0.0
var _word_bonus_max_energy: int = 0
var _burn_effect: WordEffectData = null


func _ready() -> void:
	database = load(DATABASE_PATH) as GameDatabase
	if database == null:
		push_error("GameState: could not load GameDatabase at %s" % DATABASE_PATH)
		return
	balance = database.balance
	if balance == null:
		push_error("GameState: GameDatabase has no GameBalance assigned.")
		return
	_recalculate_word_bonuses()


# --- Derived stats ---------------------------------------------------------

## Level of an upgrade track, 0 when never purchased.
func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


## Value an upgrade track currently provides, falling back to base_value at
## level 0.
func get_upgrade_value(upgrade_id: StringName, base_value: float) -> float:
	var upgrade: UpgradeData = database.find_upgrade(upgrade_id)
	if upgrade == null:
		return base_value
	return upgrade.value_at(get_upgrade_level(upgrade_id), base_value)


func get_max_energy() -> int:
	var from_upgrade: float = get_upgrade_value(
		UPGRADE_MAX_ENERGY, float(balance.start_max_energy)
	)
	return int(from_upgrade) + _word_bonus_max_energy


## FinalClickDamage = (BaseClickDamage + FlatWordBonus) * WordDamageMultiplier
## * CriticalMultiplier. TargetTakenDamageMultiplier is still out of scope for
## the vertical slice. Doc v0.3 section 10.1.
func get_click_damage(is_critical: bool = false) -> float:
	var base: float = get_upgrade_value(
		UPGRADE_CLICK_DAMAGE, balance.base_click_damage
	)
	var damage: float = (base + _word_flat_click_damage) * _word_click_multiplier
	if is_critical:
		damage *= get_crit_multiplier()
	return damage


## CritChance = GoldCritChance + StrongHitWordBonus. Doc v0.3 section 10.2:
## the gold upgrade and the 강타 word family share one roll, never two.
func get_crit_chance() -> float:
	return clampf(
		get_upgrade_value(UPGRADE_CRITICAL_CLICK, 0.0) + _word_crit_chance, 0.0, 1.0
	)


## CritMultiplier = base_crit_multiplier + WordCritMultiplierBonus.
func get_crit_multiplier() -> float:
	return balance.base_crit_multiplier + _word_crit_multiplier


## The single critical roll of one click. Call it exactly once per click and
## pass the result to get_click_damage(). Doc v0.3 section 10.2.
func roll_critical() -> bool:
	var chance: float = get_crit_chance()
	return chance > 0.0 and randf() < chance


## PermanentGoldMultiplier. Upgrade and word bonuses add together, matching the
## worked example in growth_balance v0.2 section 9.1.
func get_gold_multiplier() -> float:
	return 1.0 + get_upgrade_value(UPGRADE_GOLD_BONUS, 0.0) + _word_gold_bonus


func get_monster_capacity() -> int:
	return int(get_upgrade_value(
		UPGRADE_MONSTER_CAPACITY, float(balance.base_monster_capacity)
	))


func get_jamo_candidate_count() -> int:
	return balance.base_jamo_candidates


## The burn effect granted by the word 불, or null while it is still locked.
func get_burn_effect() -> WordEffectData:
	return _burn_effect


# --- Energy ----------------------------------------------------------------

func can_click() -> bool:
	return energy >= balance.click_energy_cost


## Spends one click worth of energy. Returns false when the day is already out
## of energy so callers can skip the whole click.
func spend_click_energy() -> bool:
	if not can_click():
		return false
	energy -= balance.click_energy_cost
	SignalBus.energy_changed.emit(energy, get_max_energy())
	if energy <= 0:
		SignalBus.energy_depleted.emit()
	return true


# --- Gold and kills --------------------------------------------------------

func add_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	gold += amount
	gold_earned_today += amount
	SignalBus.gold_changed.emit(gold)


## Called by a monster on death. gold_reward already includes the monster and
## permanent multipliers.
func register_kill(jamo: String, gold_reward: float, world_position: Vector3) -> void:
	kills_today += 1
	add_gold(gold_reward)
	SignalBus.monster_killed.emit(jamo, gold_reward, world_position)


# --- Day flow --------------------------------------------------------------

## Refills energy and clears the per-day counters. Doc v0.3 section 12.
func begin_day() -> void:
	energy = get_max_energy()
	kills_today = 0
	gold_earned_today = 0.0
	SignalBus.energy_changed.emit(energy, get_max_energy())
	SignalBus.day_started.emit(day)


func advance_day() -> void:
	day += 1
	begin_day()


# --- Jamo inventory and word crafting --------------------------------------

func get_jamo_count(jamo: String) -> int:
	return int(jamo_inventory.get(jamo, 0))


func add_jamo(jamo: String) -> void:
	jamo_inventory[jamo] = get_jamo_count(jamo) + 1
	SignalBus.jamo_collected.emit(jamo)


func is_word_unlocked(word_id: StringName) -> bool:
	return unlocked_word_ids.has(word_id)


func are_prerequisites_met(word: WordData) -> bool:
	for prerequisite: StringName in word.prerequisites:
		if not is_word_unlocked(prerequisite):
			return false
	return true


## True when the inventory already holds everything the word needs.
func can_complete_word(word: WordData) -> bool:
	if word == null or is_word_unlocked(word.id):
		return false
	if not are_prerequisites_met(word):
		return false
	var needed: Dictionary = word.required_counts()
	for jamo: String in needed:
		if get_jamo_count(jamo) < int(needed[jamo]):
			return false
	return true


## Words whose prerequisites are met and that are not unlocked yet.
func get_craftable_words() -> Array[WordData]:
	var result: Array[WordData] = []
	for word: WordData in database.words:
		if word == null or is_word_unlocked(word.id):
			continue
		if are_prerequisites_met(word):
			result.append(word)
	return result


## Completes every word the inventory can now afford, consuming their jamo.
## Returns the words that were completed, in database order.
func complete_ready_words() -> Array[WordData]:
	var completed: Array[WordData] = []
	# Loop until nothing more completes: unlocking a word can satisfy the
	# prerequisites of another word in the same batch.
	var progressed := true
	while progressed:
		progressed = false
		for word: WordData in database.words:
			if not can_complete_word(word):
				continue
			_consume_jamo(word)
			unlocked_word_ids.append(word.id)
			completed.append(word)
			progressed = true
	if not completed.is_empty():
		_recalculate_word_bonuses()
		for word: WordData in completed:
			SignalBus.word_completed.emit(word)
	return completed


func _consume_jamo(word: WordData) -> void:
	var needed: Dictionary = word.required_counts()
	for jamo: String in needed:
		var remaining: int = get_jamo_count(jamo) - int(needed[jamo])
		if remaining > 0:
			jamo_inventory[jamo] = remaining
		else:
			jamo_inventory.erase(jamo)


func _recalculate_word_bonuses() -> void:
	_word_flat_click_damage = 0.0
	_word_click_multiplier = 1.0
	# Summation points for the 강타 / 괴력 words. No word feeds them yet.
	_word_crit_chance = 0.0
	_word_crit_multiplier = 0.0
	_word_gold_bonus = 0.0
	_word_bonus_max_energy = 0
	_burn_effect = null
	for word_id: StringName in unlocked_word_ids:
		var word: WordData = database.find_word(word_id)
		if word == null:
			continue
		for effect: WordEffectData in word.effects:
			if effect == null:
				continue
			match effect.effect_type:
				WordEffectData.EffectType.FLAT_CLICK_DAMAGE:
					_word_flat_click_damage += effect.base_value
				WordEffectData.EffectType.GOLD_MULTIPLIER:
					_word_gold_bonus += effect.base_value
				WordEffectData.EffectType.MAX_ENERGY:
					_word_bonus_max_energy += int(effect.base_value)
				WordEffectData.EffectType.UNLOCK_BURN:
					_burn_effect = effect


# --- Save / load -----------------------------------------------------------
# Only ids and levels are stored, never the Resources themselves.
# Doc v0.3 section 30.

func to_dict() -> Dictionary:
	var upgrades: Dictionary = {}
	for key: StringName in upgrade_levels:
		upgrades[String(key)] = int(upgrade_levels[key])
	var words: Array[String] = []
	for word_id: StringName in unlocked_word_ids:
		words.append(String(word_id))
	return {
		"day": day,
		"gold": gold,
		"upgrade_levels": upgrades,
		"unlocked_words": words,
		"jamo_inventory": jamo_inventory.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	gold = maxf(0.0, float(data.get("gold", 0.0)))

	upgrade_levels.clear()
	var stored_upgrades: Dictionary = data.get("upgrade_levels", {})
	for key: String in stored_upgrades:
		upgrade_levels[StringName(key)] = int(stored_upgrades[key])

	unlocked_word_ids.clear()
	for word_id: String in data.get("unlocked_words", []):
		unlocked_word_ids.append(StringName(word_id))

	jamo_inventory.clear()
	var stored_jamo: Dictionary = data.get("jamo_inventory", {})
	for key: String in stored_jamo:
		jamo_inventory[key] = int(stored_jamo[key])

	_recalculate_word_bonuses()
