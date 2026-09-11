class_name ForgeService
extends RefCounted
## Word Forge (G4/G5, B3): full reshuffle per Forge, non-replacement draws inside it, Lock
## and Reroll budgets, candidate classification, one restore transaction, failure detection.
## Token count is the invariant: hand + draw + discard always equals the deck.

const KIND_NEW := &"new"
const KIND_RANK_UP := &"rank_up"

var rng := RandomNumberGenerator.new()
var deck: DeckService
var db: ContentDB
var build: BuildState
var pool: Array[WordData] = []       # craftable words this RUN (unlocked snapshot)
var hand: Array[Dictionary] = []     # tokens {"id", "jamo"}
var draw: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var locked: Array[int] = []
var hand_size: int = 7
var lock_max: int = 3
var rerolls_left: int = 2
var restores_left: int = 1
var restored_word: StringName = &""
var pinned: StringName = &""
## One 합성 per 빌드 확정 (G6); it never counts as the Forge restore.
var compounded: StringName = &""


func start(run_deck: DeckService, content: ContentDB, run_build: BuildState, word_pool: Array[WordData],
		seed: int, bonus_rerolls: int, tutorial_hand: Array[String] = []) -> void:
	deck = run_deck
	db = content
	build = run_build
	pool = word_pool
	rng.seed = seed
	hand_size = db.balance.hand_size
	lock_max = db.balance.lock_max
	rerolls_left = db.balance.reroll_base + bonus_rerolls
	restores_left = db.balance.restores_per_forge
	restored_word = &""
	compounded = &""
	locked.clear()
	hand.clear()
	discard.clear()
	draw = deck.tokens.duplicate(true)
	# Tutorial (G2/B3): pull the real tokens of the fixed hand out first, shuffle the rest.
	for jamo in tutorial_hand:
		for i in draw.size():
			if draw[i]["jamo"] == jamo:
				hand.append(draw[i])
				draw.remove_at(i)
				break
	_shuffle(draw)
	while hand.size() < hand_size and not draw.is_empty():
		hand.append(draw.pop_back())


func token_total() -> int:
	return hand.size() + draw.size() + discard.size()


func is_locked(token_id: int) -> bool:
	return token_id in locked


## Lock toggle; refuses (without unlocking anything) past the cap (G5).
func toggle_lock(token_id: int) -> bool:
	if token_id in locked:
		locked.erase(token_id)
		return true
	if locked.size() >= lock_max or not _in_hand(token_id):
		return false
	locked.append(token_id)
	return true


func reroll_slots() -> int:
	return hand.size() - locked.size()


func can_reroll() -> bool:
	return rerolls_left > 0 and reroll_slots() > 0 and restored_word == &""


## Unlocked tokens go to discard, then the same number is drawn; draw refills from a
## reshuffled discard only when it runs dry (G4).
func reroll() -> bool:
	if not can_reroll():
		return false
	var kept: Array[Dictionary] = []
	var outgoing: Array[Dictionary] = []
	for t in hand:
		if t["id"] in locked:
			kept.append(t)
		else:
			outgoing.append(t)
	hand = kept
	# The outgoing tokens join the discard only after drawing, so neither they nor the locked
	# ones can be in the reshuffle pool of this reroll (G4).
	for i in outgoing.size():
		if draw.is_empty():
			draw = discard
			discard = []
			_shuffle(draw)
		if draw.is_empty():
			break
		hand.append(draw.pop_back())
	discard.append_array(outgoing)
	rerolls_left -= 1
	return true


func hand_counts() -> Dictionary:
	var out := {}
	for t in hand:
		out[t["jamo"]] = out.get(t["jamo"], 0) + 1
	return out


static func required_counts(word: WordData) -> Dictionary:
	var need := {}
	for j in word.required_jamo:
		need[j] = need.get(j, 0) + 1
	return need


static func covers(counts: Dictionary, word: WordData) -> bool:
	var need := required_counts(word)
	for j in need:
		if counts.get(j, 0) < need[j]:
			return false
	return true


## Candidates from the current hand (G5): {word, kind, needs_replace, replace_risk}. Words
## already held at max Rank are excluded; slot-full new words stay valid but need a swap.
func candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := hand_counts()
	for w in pool:
		if not covers(counts, w):
			continue
		if not w.requires_any_word.is_empty():
			var ok := false
			for req in w.requires_any_word:
				if build.has(req):
					ok = true
			if not ok:
				continue
		var entry := {"word": w, "kind": KIND_NEW, "needs_replace": false, "replace_risk": false}
		if build.has(w.id):
			if build.rank_of(w.id) >= w.max_rank():
				continue
			entry["kind"] = KIND_RANK_UP
		else:
			entry["needs_replace"] = build.is_full()
			entry["replace_risk"] = w.is_risk() and build.risk_count(db) >= build.risk_max
		out.append(entry)
	return out


func candidate_for(word_id: StringName) -> Dictionary:
	for c in candidates():
		if c["word"].id == word_id:
			return c
	return {}


func can_restore() -> bool:
	return restores_left > 0 and restored_word == &""


## The one restore transaction (G5): validate everything, then mutate the build in one go.
## `replace_id` is required only when the candidate needs a slot or the risk slot.
func restore(word_id: StringName, replace_id: StringName = &"") -> bool:
	if not can_restore():
		return false
	var c := candidate_for(word_id)
	if c.is_empty():
		return false
	var word: WordData = c["word"]
	if c["kind"] == KIND_RANK_UP:
		if not build.rank_up(word.id, word.max_rank()):
			return false
	else:
		var must_swap: bool = c["needs_replace"] or c["replace_risk"]
		if must_swap:
			if replace_id == &"" or not build.has(replace_id) or replace_id == word.id:
				return false
			if c["replace_risk"] and not db.words[replace_id].is_risk():
				return false
			build.remove(replace_id)
		if not build.add(word.id):
			return false
	restores_left -= 1
	restored_word = word.id
	return true


## 복원 건너뛰기: closes the restore step voluntarily (no pity, G5) so 합성 can follow.
func skip_restore() -> void:
	if restored_word == &"":
		restores_left = 0


## The restore step is over: a word was restored, or the player closed it, or it failed.
func restore_closed() -> bool:
	return restored_word != &"" or restores_left <= 0 or is_failed()


## 합성 happens after the restore step (G6: Forge 복원 후 빌드 확정 화면에서 선택).
func can_compound() -> bool:
	return compounded == &"" and restore_closed() and not build.compound_options(db).is_empty()


## 합성 preview (G6): what leaves, what enters, and which synergies switch off/on.
func compound_preview(compound_id: StringName) -> Dictionary:
	var c: CompoundData = db.compounds.get(compound_id)
	if c == null:
		return {}
	var before: Array[StringName] = []
	for syn in CombatResolver.active_synergies(db, build):
		before.append(syn.id)
	var trial := BuildState.new()
	trial.slots = build.slots
	trial.risk_max = build.risk_max
	trial.words = build.words.duplicate(true)
	trial.apply_compound(db, compound_id)
	var after: Array[StringName] = []
	for syn in CombatResolver.active_synergies(db, trial):
		after.append(syn.id)
	var lost: Array[StringName] = []
	for id in before:
		if id not in after:
			lost.append(id)
	return {"compound": c, "material_a_rank": build.rank_of(c.material_a), "material_b_rank": build.rank_of(c.material_b),
		"result": db.words[c.result], "synergies_lost": lost}


## Applies the recipe once per 빌드 확정; cancelling before this call costs nothing.
func compound(compound_id: StringName) -> bool:
	if not can_compound():
		return false
	if not build.apply_compound(db, compound_id):
		return false
	compounded = compound_id
	restores_left = 0  # no restore into the freed slot afterwards (G6)
	return true


## 복원 실패 (G5): no reroll left, nothing restorable, nothing restored.
func is_failed() -> bool:
	return restored_word == &"" and rerolls_left <= 0 and candidates().is_empty()


## Skipping while a candidate exists is voluntary and earns no pity.
func is_voluntary_skip() -> bool:
	return restored_word == &"" and not candidates().is_empty()


## Pin status (G5): lacking jamo vs the whole deck, so the UI can say whether it is reachable.
func pin_status(word_id: StringName) -> Dictionary:
	if not db.words.has(word_id):
		return {}
	var word: WordData = db.words[word_id]
	var deck_counts := deck.counts()
	var missing := {}
	var need := required_counts(word)
	for j in need:
		if deck_counts.get(j, 0) < need[j]:
			missing[j] = need[j] - deck_counts.get(j, 0)
	return {"word": word, "missing": missing, "possible": missing.is_empty(), "deck_counts": deck_counts}


## Jamo the pinned word lacks in the deck (B5 spawn weight x1.15 applies to these).
func pinned_lacking() -> Array[String]:
	var out: Array[String] = []
	if pinned == &"":
		return out
	for j in pin_status(pinned).get("missing", {}):
		out.append(j)
	return out


func finish() -> void:
	# Every token returns to the deck untouched; the deck list itself never changed.
	assert(token_total() == deck.size(), "forge token count drifted")
	hand.clear()
	draw.clear()
	discard.clear()
	locked.clear()


func _in_hand(token_id: int) -> bool:
	for t in hand:
		if t["id"] == token_id:
			return true
	return false


func _shuffle(arr: Array[Dictionary]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
