class_name RunController
extends Node
## Owns the RUN state machine of G2. Pure logic: no scene lookups, so it runs headless.
## Every screen "complete" button maps to exactly one method, and each method only
## fires from its own phase, which is what makes double clicks harmless (G2).

enum Phase { LIBRARY, RUN_SETUP, WAVE_PREP, COMBAT, CLEAR, FORGE, RESULT }
enum EndReason { NONE, FAILED, ABANDONED, COMPLETED }

const FIRST_WAVE := 1
const LAST_WAVE := 20

signal phase_changed(from: Phase, to: Phase)
signal wave_changed(wave: int)
signal stability_changed(current: float, maximum: float)
signal gold_changed(gold: float)
signal run_ended(reason: EndReason)

var db: ContentDB
var phase: Phase = Phase.LIBRARY
var wave: int = FIRST_WAVE
var deck_id: StringName = &"starter_a"
var stability: float = 0.0
var stability_max: float = 0.0
var gold_run: float = 0.0
var end_reason: EndReason = EndReason.NONE
## RUN deck and this Wave's recovered jamo (G4). Rewards are built from these on CLEAR.
var deck: DeckService
var drops := DropService.new()
## Until meta persistence lands (P4) every run counts as the first run for the W1 tutorial rule.
var first_run: bool = true
var run_seed: int = 0


func setup(content: ContentDB, max_stability: float = -1.0) -> void:
	db = content
	stability_max = max_stability if max_stability > 0.0 else db.balance.stability_max


func wave_data() -> WaveData:
	return db.waves.get(wave)


func is_boss_wave() -> bool:
	var w := wave_data()
	return w != null and w.is_boss


# --- transitions (return false when called from the wrong phase) -------------------

## 서고 -> 시작 구성 선택. Deck choice is confirmed later by confirm_setup().
func open_run_setup() -> bool:
	return _go(Phase.LIBRARY, Phase.RUN_SETUP)


## 시작 구성 확정 -> WAVE_PREP of W1 with full stability.
func confirm_setup(chosen_deck: StringName) -> bool:
	if phase != Phase.RUN_SETUP:
		return _reject("confirm_setup")
	if not db.decks.has(chosen_deck):
		return _reject("confirm_setup: unknown deck %s" % chosen_deck)
	deck_id = chosen_deck
	wave = FIRST_WAVE
	gold_run = 0.0
	end_reason = EndReason.NONE
	deck = DeckService.from_deck_data(db.decks[chosen_deck], db.balance)
	drops.setup(db.balance, run_seed + 1)
	_set_stability(stability_max)
	gold_changed.emit(gold_run)
	wave_changed.emit(wave)
	return _go(Phase.RUN_SETUP, Phase.WAVE_PREP)


func begin_combat() -> bool:
	if phase != Phase.WAVE_PREP:
		return _reject("begin_combat")
	drops.start_wave()
	return _go(Phase.WAVE_PREP, Phase.COMBAT)


## Normal purify with a recoverable jamo. Returns true when it was recovered (B4).
func on_purified(jamo: String) -> bool:
	if phase != Phase.COMBAT:
		return false
	return drops.roll(jamo)


## Reward budget for the Wave just cleared (B4): 1 pick normally, 2 picks + 1 remove after
## a boss Wave. The very first W1 forbids 교체 so the guaranteed tutorial hand survives (G2).
func build_reward() -> RewardService:
	var reward := RewardService.new()
	var boss := is_boss_wave()
	var picks := db.balance.reward_picks_boss if boss else db.balance.reward_picks_normal
	var removes := db.balance.reward_removes_boss if boss else 0
	var replace_allowed := not (first_run and wave == FIRST_WAVE)
	reward.start(deck, drops.drops, picks, removes, replace_allowed)
	return reward


## Spawns done and no enemies/patterns left (G2). W20 skips CLEAR/FORGE entirely.
func on_wave_cleared() -> bool:
	if phase != Phase.COMBAT:
		return _reject("on_wave_cleared")
	if wave >= LAST_WAVE:
		return _end(EndReason.COMPLETED)
	_set_stability(stability + db.balance.clear_heal)
	return _go(Phase.COMBAT, Phase.CLEAR)


## 자모 정리 done -> Forge.
func finish_clear() -> bool:
	return _go(Phase.CLEAR, Phase.FORGE)


## 빌드 확정 -> next WAVE_PREP.
func confirm_build() -> bool:
	if phase != Phase.FORGE:
		return _reject("confirm_build")
	wave += 1
	wave_changed.emit(wave)
	return _go(Phase.FORGE, Phase.WAVE_PREP)


## Menu abandon, allowed in any in-run phase after confirmation in the UI.
func abandon() -> bool:
	if phase in [Phase.LIBRARY, Phase.RUN_SETUP, Phase.RESULT]:
		return _reject("abandon")
	return _end(EndReason.ABANDONED)


func return_to_library() -> bool:
	return _go(Phase.RESULT, Phase.LIBRARY)


# --- stability -----------------------------------------------------------------------

## Final stability damage after B1 reductions have been applied by the caller.
## Depletion during COMBAT ends the run immediately (G7: defeat wins over clear).
func damage_stability(amount: float) -> void:
	if amount <= 0.0 or phase != Phase.COMBAT:
		return
	_set_stability(stability - amount)
	if stability <= 0.0:
		_end(EndReason.FAILED)


func heal_stability(amount: float) -> void:
	if amount > 0.0:
		_set_stability(stability + amount)


func add_gold(amount: float) -> void:
	if amount > 0.0:
		gold_run += amount
		gold_changed.emit(gold_run)


# --- internals -----------------------------------------------------------------------

func _set_stability(value: float) -> void:
	stability = clampf(value, 0.0, stability_max)
	stability_changed.emit(stability, stability_max)


func _go(from: Phase, to: Phase) -> bool:
	if phase != from:
		return _reject("%s -> %s" % [Phase.keys()[from], Phase.keys()[to]])
	phase = to
	phase_changed.emit(from, to)
	return true


func _end(reason: EndReason) -> bool:
	var from := phase
	end_reason = reason
	phase = Phase.RESULT
	phase_changed.emit(from, Phase.RESULT)
	run_ended.emit(reason)
	return true


func _reject(what: String) -> bool:
	push_warning("RunController: %s ignored in phase %s" % [what, Phase.keys()[phase]])
	return false
