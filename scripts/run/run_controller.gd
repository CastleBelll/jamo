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
## Stability actually lost during the current Wave (G10 Wave Clear row).
var wave_damage_taken: float = 0.0
## Build roster, goal pin (kept across RUNs, G2), Forge failure pity (B3) and the live Forge.
var build := BuildState.new()
var pinned_word: StringName = &""
var forge_fail_bonus: int = 0
var forge: ForgeService
## Live 자모 정리 model while in CLEAR (persisted so a resume keeps consumed picks, G14).
var reward: RewardService
## Result-screen records (G9): words first restored this RUN, stability loss by cause,
## and the highest Wave actually cleared.
var discovered: Array[StringName] = []
## 위험 words join the pool only when 거대한 ㅁ was purified in an earlier RUN (B5); the pool
## is snapshotted at RUN start and never widens mid-RUN.
var risk_unlocked: bool = false
var run_pool: Array[WordData] = []
## Persistence (G14): stable id for settlement dedupe, and bosses purified this RUN.
var run_id: String = ""
var bosses_purified: Array[String] = []
var damage_causes: Dictionary = {}
var waves_cleared: int = 0


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
	# B5: the 위험 pool opens only for a RUN that starts after 거대한 ㅁ was first purified.
	risk_unlocked = Meta.risk_unlocked_for_new_run()
	first_run = not Meta.first_run_done
	stability_max = Meta.stability_max(db)
	if pinned_word == &"" and Meta.pinned_word != "" and db.words.has(StringName(Meta.pinned_word)):
		pinned_word = StringName(Meta.pinned_word)
	run_id = "%d-%d" % [Time.get_unix_time_from_system(), run_seed]
	bosses_purified.clear()
	build = BuildState.new()
	build.setup(db.balance)
	forge = null
	reward = null
	forge_fail_bonus = 0
	discovered.clear()
	damage_causes.clear()
	waves_cleared = 0
	run_pool.clear()
	run_pool = word_pool()
	# B5: drop and spawn streams are independent; both derive from run_seed through distinct labels.
	drops.setup(db.balance, hash("drop:%d" % run_seed))
	_set_stability(stability_max)
	gold_changed.emit(gold_run)
	wave_changed.emit(wave)
	return _go(Phase.RUN_SETUP, Phase.WAVE_PREP)


func begin_combat() -> bool:
	if phase != Phase.WAVE_PREP:
		return _reject("begin_combat")
	drops.start_wave()
	wave_damage_taken = 0.0
	return _go(Phase.WAVE_PREP, Phase.COMBAT)


## Normal purify with a recoverable jamo. Returns true when it was recovered (B4).
func on_purified(jamo: String) -> bool:
	if phase != Phase.COMBAT:
		return false
	return drops.roll(jamo)


## Reward budget for the Wave just cleared (B4): 1 pick normally, 2 picks + 1 remove after
## a boss Wave. The very first W1 forbids 교체 so the guaranteed tutorial hand survives (G2).
func build_reward() -> RewardService:
	if reward != null and phase == Phase.CLEAR:
		return reward
	reward = RewardService.new()
	var boss := is_boss_wave()
	var picks := db.balance.reward_picks_boss if boss else db.balance.reward_picks_normal
	if not boss:
		picks += CombatResolver.reward_pick_bonus(db, build)  # SY_ECON, normal Waves only (B8)
	var removes := db.balance.reward_removes_boss if boss else CombatResolver.extra_removes(db, build, wave)  # 복 (B7)
	var replace_allowed := not (first_run and wave == FIRST_WAVE)
	reward.start(deck, drops.drops, picks, removes, replace_allowed)
	return reward


## Spawns done and no enemies/patterns left (G2). W20 skips CLEAR/FORGE entirely.
## `heal` is the full clear heal (base + word bonuses); negative means base only.
func on_wave_cleared(heal: float = -1.0) -> bool:
	if phase != Phase.COMBAT:
		return _reject("on_wave_cleared")
	waves_cleared = wave
	if wave >= LAST_WAVE:
		return _end(EndReason.COMPLETED)
	_set_stability(stability + (heal if heal >= 0.0 else db.balance.clear_heal))
	return _go(Phase.COMBAT, Phase.CLEAR)


## 자모 정리 done -> Forge.
func finish_clear() -> bool:
	if phase != Phase.CLEAR:
		return _reject("finish_clear")
	reward = null
	return _go(Phase.CLEAR, Phase.FORGE)


## 빌드 확정 -> next WAVE_PREP.
func confirm_build() -> bool:
	if phase != Phase.FORGE:
		return _reject("confirm_build")
	wave += 1
	wave_changed.emit(wave)
	return _go(Phase.FORGE, Phase.WAVE_PREP)


## Direct Forge candidates this RUN: start-unlocked base words (B5 snapshot; 위험 words and
## compound results are not in the pool until their unlock/recipe systems land).
func word_pool() -> Array[WordData]:
	if not run_pool.is_empty():
		return run_pool
	var out: Array[WordData] = []
	for w in db.base_words():
		if w.unlock == &"start" or (w.unlock == &"after_mieum" and risk_unlocked):
			out.append(w)
	return out


## Opens the Forge for the Wave just cleared (G5). The very first Forge of the first RUN deals
## the fixed tutorial hand from real deck tokens (B3).
func start_forge() -> ForgeService:
	if phase != Phase.FORGE:
		_reject("start_forge")
		return null
	if forge != null:
		return forge  # resumed from a snapshot: same hand, counts and RNG (G14)
	forge = ForgeService.new()
	var tutorial: Array[String] = []
	if first_run and wave == FIRST_WAVE:
		tutorial = db.balance.tutorial_hand
	forge.pinned = pinned_word
	forge.start(deck, db, build, word_pool(), hash("forge:%d:%d" % [run_seed, wave]), forge_fail_bonus, tutorial)
	return forge


func pin_word(word_id: StringName) -> void:
	pinned_word = word_id if db.words.has(word_id) else &""
	Meta.pinned_word = String(pinned_word)
	if forge != null:
		forge.pinned = pinned_word


## Jamo the pinned word still lacks in the deck; B5 spawn weight x1.15 applies to them.
func pin_lacking() -> Array[String]:
	var out: Array[String] = []
	if pinned_word == &"" or deck == null:
		return out
	for j in deck.missing_for(db.words[pinned_word]):
		out.append(j)
	return out


## 빌드 확정: settle Forge failure/success pity (G5/B3), return tokens, advance the Wave.
func finish_forge() -> bool:
	if phase != Phase.FORGE:
		return _reject("finish_forge")
	if forge != null:
		if forge.restored_word != &"":
			forge_fail_bonus = 0
			if forge.restored_word not in discovered:
				discovered.append(forge.restored_word)
			if Meta.codex.is_empty() and "S_WORD" not in Meta.events:
				_record_event("S_WORD")
		elif forge.is_failed():
			heal_stability(db.balance.forge_fail_heal)
			forge_fail_bonus = mini(forge_fail_bonus + db.balance.forge_fail_bonus_reroll, db.balance.forge_fail_bonus_reroll_cap)
		# 합성 is a separate action (G6): it never changes the restore failure/success settlement.
		if forge.compounded != &"":
			var result_id: StringName = db.compounds[forge.compounded].result
			if result_id not in discovered:
				discovered.append(result_id)
		forge.finish()
		forge = null
	return confirm_build()


## Menu abandon, allowed in any in-run phase after confirmation in the UI.
func abandon() -> bool:
	if phase in [Phase.LIBRARY, Phase.RUN_SETUP, Phase.RESULT]:
		return _reject("abandon")
	return _end(EndReason.ABANDONED)


func return_to_library() -> bool:
	return _go(Phase.RESULT, Phase.LIBRARY)


## 재도전 (G2): straight into a new RUN with the same deck; the goal pin is kept and the
## first-run tutorial rules are over.
func retry_run() -> bool:
	if phase != Phase.RESULT:
		return _reject("retry_run")
	phase = Phase.RUN_SETUP
	return confirm_setup(deck_id)


# --- stability -----------------------------------------------------------------------

## Final stability damage after B1 reductions have been applied by the caller.
## Depletion during COMBAT ends the run immediately (G7: defeat wins over clear).
func damage_stability(amount: float, cause: StringName = &"reach") -> void:
	if amount <= 0.0 or phase != Phase.COMBAT:
		return
	wave_damage_taken += minf(amount, stability)
	damage_causes[cause] = damage_causes.get(cause, 0.0) + minf(amount, stability)
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


## Boss purified this RUN (director hook): records the profile facts behind unlocks (B5).
func on_boss_purified(boss_id: StringName) -> void:
	bosses_purified.append(String(boss_id))
	if boss_id == &"B_MIEUM":
		Meta.mieum_purified = true
		_record_event("S_M")
	elif boss_id == &"B_SILENCE":
		_record_event("S_SILENCE")
	elif boss_id == &"B_GREED":
		_record_event("S_GREED")


func _end(reason: EndReason) -> bool:
	var from := phase
	end_reason = reason
	first_run = false
	Meta.first_run_done = true
	settle()
	phase = Phase.RESULT
	phase_changed.emit(from, Phase.RESULT)
	run_ended.emit(reason)
	return true


func _reject(what: String) -> bool:
	push_warning("RunController: %s ignored in phase %s" % [what, Phase.keys()[phase]])
	return false


# --- persistence (G14) ---------------------------------------------------------------

## Settles the finished RUN into Meta exactly once per result id: Gold integer part, best
## Waves, codex records (base words gain 복원도, compounds/bosses get a first-discovery
## record), S5 events, and the suspended-RUN snapshot is dropped.
func settle() -> void:
	var result_id := "%s:%d" % [run_id, wave]
	if result_id in Meta.settled_results:
		return
	Meta.settled_results.append(result_id)
	Meta.gold += int(gold_run)
	Meta.best_reached = maxi(Meta.best_reached, wave)
	Meta.best_cleared = maxi(Meta.best_cleared, waves_cleared)
	var had_codex := not Meta.codex.is_empty()
	for id in discovered:
		var key := String(id)
		var entry: Dictionary = Meta.codex.get(key, {"mastery": 0, "best_rank": 0, "first_at": Time.get_datetime_string_from_system()})
		if not db.words[id].is_compound:
			entry["mastery"] = int(entry["mastery"]) + 1
		entry["best_rank"] = maxi(int(entry["best_rank"]), build.rank_of(id))
		Meta.codex[key] = entry
	for boss_id in bosses_purified:
		Meta.boss_records[boss_id] = int(Meta.boss_records.get(boss_id, 0)) + 1
	if not had_codex and not discovered.is_empty():
		_record_event("S_WORD")
	if "B_MIEUM" in bosses_purified:
		_record_event("S_M")
	if "B_SILENCE" in bosses_purified:
		_record_event("S_SILENCE")
	if "B_GREED" in bosses_purified:
		_record_event("S_GREED")
	if end_reason == EndReason.COMPLETED:
		_record_event("S_SLICE_END")
	Meta.run = {}
	Meta.save()


## Lines unlocked in this RUN that the next paused screen should show once (G10 한 줄).
var pending_lines: Array[String] = []


func _record_event(id: String) -> void:
	if id not in Meta.events:
		Meta.events.append(id)
		var line := db.narrative.line(id) if db.narrative != null else ""
		if line != "":
			pending_lines.append(line)


func take_pending_line() -> String:
	if pending_lines.is_empty():
		return ""
	return pending_lines.pop_front()


## Full logical state of the RUN for the atomic save points (G14).
func snapshot() -> Dictionary:
	var d := {"run_id": run_id, "phase": phase, "wave": wave, "deck_id": String(deck_id),
		"stability": stability, "stability_max": stability_max, "gold_run": gold_run,
		"deck": deck.snapshot() if deck != null else {}, "build": build.words.duplicate(true),
		"pinned": String(pinned_word), "forge_fail_bonus": forge_fail_bonus, "drops": drops.snapshot(),
		"discovered": [], "damage_causes": damage_causes.duplicate(), "waves_cleared": waves_cleared,
		"risk_unlocked": risk_unlocked, "first_run": first_run, "run_seed": run_seed,
		"bosses_purified": bosses_purified.duplicate(), "wave_damage_taken": wave_damage_taken}
	for id in discovered:
		d["discovered"].append(String(id))
	d["forge"] = forge.snapshot() if forge != null else {}
	d["reward"] = reward.snapshot() if reward != null and phase == Phase.CLEAR else {}
	return d


## Rebuilds the RUN from a snapshot; a FORGE snapshot returns to the same hand and RNG.
func load_snapshot(d: Dictionary) -> void:
	run_id = String(d.get("run_id", ""))
	run_seed = int(d.get("run_seed", 0))
	deck_id = StringName(String(d.get("deck_id", "starter_a")))
	wave = int(d.get("wave", FIRST_WAVE))
	stability_max = float(d.get("stability_max", db.balance.stability_max))
	stability = float(d.get("stability", stability_max))
	gold_run = float(d.get("gold_run", 0.0))
	deck = DeckService.from_snapshot(d.get("deck", {}), db.balance)
	if deck.size() < db.balance.deck_min or deck.size() > db.balance.deck_max:
		# A snapshot from another build or a corrupt file: never resume with a broken deck.
		push_warning("RunController: snapshot deck had %d tokens, rebuilding the starter deck" % deck.size())
		deck = DeckService.from_deck_data(db.decks.get(deck_id, db.decks["starter_a"]), db.balance)
	build = BuildState.new()
	build.setup(db.balance)
	for w in d.get("build", []):
		build.words.append({"id": StringName(String(w["id"])), "rank": int(w["rank"])})
	pinned_word = StringName(String(d.get("pinned", "")))
	forge_fail_bonus = int(d.get("forge_fail_bonus", 0))
	drops.setup(db.balance, hash("drop:%d" % run_seed))
	drops.restore(d.get("drops", {}))
	discovered.clear()
	for id in d.get("discovered", []):
		discovered.append(StringName(String(id)))
	damage_causes = Dictionary(d.get("damage_causes", {}))
	waves_cleared = int(d.get("waves_cleared", 0))
	risk_unlocked = bool(d.get("risk_unlocked", false))
	first_run = bool(d.get("first_run", false))
	wave_damage_taken = float(d.get("wave_damage_taken", 0.0))
	bosses_purified.clear()
	for b in d.get("bosses_purified", []):
		bosses_purified.append(String(b))
	run_pool.clear()
	run_pool = word_pool()
	end_reason = EndReason.NONE
	var target := int(d.get("phase", Phase.WAVE_PREP))
	# A combat-time save never exists: resume lands on the WAVE_PREP checkpoint (G14).
	if target == Phase.COMBAT or target == Phase.LIBRARY or target == Phase.RUN_SETUP or target == Phase.RESULT:
		target = Phase.WAVE_PREP
	var from := phase
	phase = target
	forge = null
	reward = null
	if target == Phase.FORGE and not d.get("forge", {}).is_empty():
		forge = ForgeService.new()
		forge.load_snapshot(d["forge"], deck, db, build, word_pool())
		forge.pinned = pinned_word
		var deck_ids := []
		for t in deck.tokens:
			deck_ids.append(int(t["id"]))
		deck_ids.sort()
		if forge.token_ids() != deck_ids:
			push_warning("RunController: Forge snapshot does not match the deck, dealing a fresh Forge")
			forge = null
	if target == Phase.CLEAR and not d.get("reward", {}).is_empty():
		reward = RewardService.new()
		reward.load_snapshot(d["reward"], deck)
	gold_changed.emit(gold_run)
	wave_changed.emit(wave)
	stability_changed.emit(stability, stability_max)
	phase_changed.emit(from, phase)
