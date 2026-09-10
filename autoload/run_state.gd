extends Node

## The current RUN. Everything here is wiped when the run ends.
## Doc v0.4 sections 3.2 and 44 (RunState).
##
## A word registered in MetaState.codex_words is *known*; only a word listed in
## equipped_words is *active*. That split is what stops v0.3's permanent word
## effects from coming back. Doc v0.4 section 38.
##
## Combat numbers are assembled here because combat only happens inside a run:
## Base -> Permanent Meta -> Current RUN Word, in that order. Doc v0.4 section 8.

## Names MetaState owns. A run field may never be called one of these, and the
## split test asserts it. Doc v0.4 section 3.1.
const META_OWNED_NAMES: Array[String] = [
	"gold", "permanent_upgrade_levels", "codex_words", "codex_mastery_exp",
	"codex_mastery_levels", "discovered_compounds", "discovered_synergies",
	"defeated_word_bosses", "highest_wave", "statistics",
]

## The public properties here that are NOT run payload: the run's own liveness
## flag. Everything else this script declares has to appear in
## MetaState.RUN_OWNED_NAMES, and test_state_split asserts exactly that.
## Doc v0.4 sections 3.2 and 44.
const NON_STATE_NAMES: Array[String] = ["is_active"]

## True between start_run() and end_run(). The hub reads it to decide whether a
## run can be continued.
var is_active: bool = false

# --- Run state, doc v0.4 section 44 -----------------------------------------

var current_wave: int = 1
var core_hp: float = 0.0
var core_max_hp: float = 0.0
var current_energy: int = 0
## Jamo still to be drawn this run, and the ones already spent. Filled in
## Phase 2 (doc v0.4 section 2.4); the storage exists now so the boundary is
## already in the right place.
var jamo_draw_bag: PackedStringArray = PackedStringArray()
var jamo_discard_bag: PackedStringArray = PackedStringArray()
## Jamo currently sitting on the slot board.
var current_slot_jamo: PackedStringArray = PackedStringArray()
var rerolls: int = 0
## Indices of slot_jamo the player has locked before a reroll.
var locks: PackedInt32Array = PackedInt32Array()
## Word ids crafted and worn this run. These, and only these, grant effects.
var equipped_words: Array[StringName] = []
## word id -> rank reached this run by re-crafting it. Doc v0.4 section 11.
var run_word_ranks: Dictionary = {}
var active_synergies: Array[StringName] = []
var active_compounds: Array[StringName] = []
var risk_words: Array[StringName] = []
## Free-form run-scoped rule changes, e.g. from a boss or a risk word.
var run_modifiers: Dictionary = {}
## Counters for the result screen: kills / gold_earned.
var run_statistics: Dictionary = {}

# --- Cached run word bonuses, refreshed by _recalculate_word_bonuses() ------
var _word_flat_click_damage: float = 0.0
var _word_click_multiplier: float = 1.0
var _word_crit_chance: float = 0.0
var _word_crit_multiplier: float = 0.0
var _word_gold_bonus: float = 0.0
var _word_bonus_max_energy: int = 0
var _burn_effect: WordEffectData = null
var _burn_spread_effect: WordEffectData = null
var _golden_monster_unlocked: bool = false
var _word_special_luck: float = 0.0


# --- Run lifecycle ----------------------------------------------------------

## Clears every run-scoped field. MetaState is deliberately not touched.
func reset() -> void:
	is_active = false
	current_wave = 1
	core_max_hp = 0.0
	core_hp = 0.0
	current_energy = 0
	jamo_draw_bag = PackedStringArray()
	jamo_discard_bag = PackedStringArray()
	current_slot_jamo = PackedStringArray()
	rerolls = 0
	locks = PackedInt32Array()
	equipped_words.clear()
	run_word_ranks.clear()
	active_synergies.clear()
	active_compounds.clear()
	risk_words.clear()
	run_modifiers.clear()
	run_statistics.clear()
	_recalculate_word_bonuses()


## Starts a fresh run at Wave 1. Doc v0.4 section 35: there is no checkpoint.
func start_run() -> void:
	reset()
	is_active = true
	core_max_hp = MetaState.get_core_max_hp()
	core_hp = core_max_hp
	MetaState.add_statistic("runs_started", 1.0)
	begin_wave(1)


## Refills the wave-scoped resources and announces the wave.
## Doc v0.4 section 7.1: energy returns to full at the start of every wave.
func begin_wave(wave: int) -> void:
	current_wave = maxi(1, wave)
	current_energy = get_max_energy()
	rerolls = MetaState.get_base_rerolls()
	SignalBus.energy_changed.emit(current_energy, get_max_energy())
	SignalBus.wave_started.emit(current_wave)


func advance_wave() -> void:
	begin_wave(current_wave + 1)


## Ends the run and folds its record into MetaState. The gold earned during the
## run was already banked as it dropped, so failing never takes it back.
## Doc v0.4 sections 14 and 35.
func end_run() -> void:
	if not is_active:
		return
	is_active = false
	MetaState.record_reached_wave(current_wave)
	MetaState.add_statistic("runs_finished", 1.0)
	MetaState.add_statistic("total_kills", get_run_statistic("kills"))
	SignalBus.run_failed.emit(
		current_wave, int(get_run_statistic("kills")), get_run_statistic("gold_earned")
	)


## Damage dealt to the 문장핵. Returns true when the run just ended.
## The damage source itself is Phase 1 work; the rule lives here already so the
## fail path is not scattered across scenes. Doc v0.4 section 6.1.
func damage_core(amount: float) -> bool:
	if not is_active or amount <= 0.0:
		return false
	core_hp = maxf(0.0, core_hp - amount)
	SignalBus.core_hp_changed.emit(core_hp, core_max_hp)
	if core_hp > 0.0:
		return false
	end_run()
	return true


# --- Derived combat stats ---------------------------------------------------

## Permanent max energy plus whatever the equipped words add this run.
func get_max_energy() -> int:
	return MetaState.get_permanent_max_energy() + _word_bonus_max_energy


## FinalClickDamage = (Base + PermanentFlat + RunFlat) * WordMultiplier
## * CriticalMultiplier. Target modifiers are still Phase 1+ scope.
## Doc v0.4 section 8.
func get_click_damage(is_critical: bool = false) -> float:
	var base: float = MetaState.get_base_click_damage()
	var damage: float = (base + _word_flat_click_damage) * _word_click_multiplier
	if is_critical:
		damage *= get_crit_multiplier()
	return damage


## The permanent crit track and the run's crit words share one roll, never two.
func get_crit_chance() -> float:
	return clampf(MetaState.get_permanent_crit_chance() + _word_crit_chance, 0.0, 1.0)


func get_crit_multiplier() -> float:
	return MetaState.balance.base_crit_multiplier + _word_crit_multiplier


## The single critical roll of one click. Call it exactly once per click and
## pass the result to get_click_damage().
func roll_critical() -> bool:
	var chance: float = get_crit_chance()
	return chance > 0.0 and randf() < chance


func get_gold_multiplier() -> float:
	return 1.0 + MetaState.get_permanent_gold_bonus() + _word_gold_bonus


## The burn granted by the word 불 while it is equipped this run, or null.
func get_burn_effect() -> WordEffectData:
	return _burn_effect


## The 불꽃 spread rule while it is equipped this run, or null.
func get_burn_spread_effect() -> WordEffectData:
	return _burn_spread_effect


## True while a run word unlocks golden spawns. Knowing 금 from the codex is not
## enough - it has to be equipped. Doc v0.4 section 38.
func is_golden_monster_unlocked() -> bool:
	return _golden_monster_unlocked


func get_special_spawn_multiplier() -> float:
	return 1.0 + _word_special_luck


# --- Energy -----------------------------------------------------------------

func can_click() -> bool:
	return current_energy >= MetaState.balance.click_energy_cost


## Spends one click worth of energy. Returns false when the wave is already out
## of energy so callers can skip the whole click. Damage-over-time and automatic
## effects keep running at 0. Doc v0.4 section 7.1.
func spend_click_energy() -> bool:
	if not can_click():
		return false
	current_energy -= MetaState.balance.click_energy_cost
	SignalBus.energy_changed.emit(current_energy, get_max_energy())
	if current_energy <= 0:
		SignalBus.energy_depleted.emit()
	return true


func can_reroll() -> bool:
	return rerolls > 0


func consume_reroll() -> bool:
	if not can_reroll():
		return false
	rerolls -= 1
	return true


# --- Gold and kills ---------------------------------------------------------

## Gold banks straight into MetaState; the run only records how much it earned
## so the result screen can show it. Doc v0.4 section 14.
func add_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	MetaState.add_gold(amount)
	add_run_statistic("gold_earned", amount)


## Called by a monster on death. gold_reward already includes the monster and
## permanent multipliers.
func register_kill(jamo: String, gold_reward: float, world_position: Vector3) -> void:
	add_run_statistic("kills", 1.0)
	add_gold(gold_reward)
	SignalBus.monster_killed.emit(jamo, gold_reward, world_position)


func get_run_statistic(key: String) -> float:
	return float(run_statistics.get(key, 0.0))


func add_run_statistic(key: String, amount: float) -> void:
	run_statistics[key] = get_run_statistic(key) + amount


# --- Run words --------------------------------------------------------------

func is_word_equipped(word_id: StringName) -> bool:
	return equipped_words.has(word_id)


func get_word_rank(word_id: StringName) -> int:
	return int(run_word_ranks.get(word_id, 0))


## Equips a word for this run and registers the first discovery in the codex.
## Re-crafting an equipped word raises its run rank instead of duplicating it.
## Doc v0.4 sections 11 and 2.7.
func equip_word(word: WordData) -> void:
	if word == null:
		return
	MetaState.register_codex_word(word.id)
	if is_word_equipped(word.id):
		run_word_ranks[word.id] = mini(get_word_rank(word.id) + 1, word.run_max_rank)
	else:
		equipped_words.append(word.id)
		run_word_ranks[word.id] = 1
		if word.is_risk_word and not risk_words.has(word.id):
			risk_words.append(word.id)
	_recalculate_word_bonuses()
	SignalBus.word_completed.emit(word)


func unequip_word(word_id: StringName) -> void:
	if not is_word_equipped(word_id):
		return
	equipped_words.erase(word_id)
	run_word_ranks.erase(word_id)
	risk_words.erase(word_id)
	_recalculate_word_bonuses()


## Folds every equipped word's effects into the cached bonuses. Only
## equipped_words is read - the codex never contributes. Doc v0.4 section 38.
func _recalculate_word_bonuses() -> void:
	_word_flat_click_damage = 0.0
	_word_click_multiplier = 1.0
	_word_crit_chance = 0.0
	_word_crit_multiplier = 0.0
	_word_gold_bonus = 0.0
	_word_bonus_max_energy = 0
	_burn_effect = null
	_burn_spread_effect = null
	_golden_monster_unlocked = false
	_word_special_luck = 0.0
	if MetaState.database == null:
		return
	var burn_tick_bonus := 0.0
	for word_id: StringName in equipped_words:
		var word: WordData = MetaState.database.find_word(word_id)
		if word == null:
			continue
		for effect: WordEffectData in word.base_effects:
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
				WordEffectData.EffectType.BURN_TICK_BONUS:
					burn_tick_bonus += effect.base_value
				WordEffectData.EffectType.BURN_SPREAD:
					_burn_spread_effect = effect
				WordEffectData.EffectType.CRIT_CHANCE:
					_word_crit_chance += effect.base_value
				WordEffectData.EffectType.UNLOCK_GOLDEN:
					_golden_monster_unlocked = true
				WordEffectData.EffectType.SPECIAL_LUCK:
					_word_special_luck += effect.base_value
	# 화염 raises the tick damage of the burn 불 unlocked. Applied to a copy so
	# the shared .tres resource is never mutated, and after the loop so the
	# order the two words were equipped in does not matter.
	if _burn_effect != null and burn_tick_bonus > 0.0:
		_burn_effect = _burn_effect.duplicate() as WordEffectData
		_burn_effect.base_value += burn_tick_bonus


# --- Save / load ------------------------------------------------------------
# A run is only saved so an interrupted session can be resumed. A run that has
# already failed is never written back. Doc v0.4 sections 44 and 45.

func to_dict() -> Dictionary:
	var ranks: Dictionary = {}
	for key: StringName in run_word_ranks:
		ranks[String(key)] = int(run_word_ranks[key])
	return {
		"current_wave": current_wave,
		"core_hp": core_hp,
		"core_max_hp": core_max_hp,
		"current_energy": current_energy,
		"jamo_draw_bag": Array(jamo_draw_bag),
		"jamo_discard_bag": Array(jamo_discard_bag),
		"current_slot_jamo": Array(current_slot_jamo),
		"rerolls": rerolls,
		"locks": Array(locks),
		"equipped_words": _string_list(equipped_words),
		"run_word_ranks": ranks,
		"active_synergies": _string_list(active_synergies),
		"active_compounds": _string_list(active_compounds),
		"risk_words": _string_list(risk_words),
		"run_modifiers": run_modifiers.duplicate(),
		"run_statistics": run_statistics.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	current_wave = maxi(1, int(data.get("current_wave", 1)))
	core_max_hp = maxf(0.0, float(data.get("core_max_hp", MetaState.get_core_max_hp())))
	core_hp = clampf(float(data.get("core_hp", core_max_hp)), 0.0, core_max_hp)
	current_energy = maxi(0, int(data.get("current_energy", 0)))
	jamo_draw_bag = _string_array(data.get("jamo_draw_bag", []))
	jamo_discard_bag = _string_array(data.get("jamo_discard_bag", []))
	current_slot_jamo = _string_array(data.get("current_slot_jamo", []))
	rerolls = maxi(0, int(data.get("rerolls", 0)))
	locks = _int_array(data.get("locks", []))
	_fill_id_list(equipped_words, data.get("equipped_words", []))
	_fill_id_list(active_synergies, data.get("active_synergies", []))
	_fill_id_list(active_compounds, data.get("active_compounds", []))
	_fill_id_list(risk_words, data.get("risk_words", []))

	run_word_ranks.clear()
	var stored_ranks: Dictionary = data.get("run_word_ranks", {})
	for key: String in stored_ranks:
		run_word_ranks[StringName(key)] = int(stored_ranks[key])

	run_modifiers.clear()
	var stored_modifiers: Dictionary = data.get("run_modifiers", {})
	for key: String in stored_modifiers:
		run_modifiers[key] = stored_modifiers[key]

	run_statistics.clear()
	var stored_statistics: Dictionary = data.get("run_statistics", {})
	for key: String in stored_statistics:
		run_statistics[key] = stored_statistics[key]

	# A core with no HP left is a run that already failed, so it is not resumed.
	is_active = core_hp > 0.0
	_recalculate_word_bonuses()


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


func _string_array(source: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (source is Array):
		return out
	for value: Variant in source:
		out.append(String(value))
	return out


func _int_array(source: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (source is Array):
		return out
	for value: Variant in source:
		out.append(int(value))
	return out
