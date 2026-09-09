class_name CandidateGenerator

## Builds the jamo candidates offered at day end.
##
## Doc v0.3 section 13.4: candidates are drawn from weighted pools rather than
## uniformly at random, so a completely dead pick is rare. Pool A/B are the
## jamo still missing from craftable words; pool C is the optional filler list
## on GameDatabase.

## Weight given to a jamo a craftable word still needs.
const NEEDED_WEIGHT := 10.0
## Weight given to a filler jamo that no craftable word needs right now.
const FILLER_WEIGHT := 1.0


## Returns up to `count` distinct jamo. May return fewer when the pool is
## smaller than `count`, for example once every word is complete.
static func generate(count: int) -> PackedStringArray:
	return _pick_distinct(build_weights(), count)


## Redraws the day's hand for the 리롤 upgrade. Same weighted pools as
## generate(): the previous picks are dropped from the pool, so a reroll is
## never the same hand again, but they are put back one at a time when the rest
## of the pool is too small to fill `count`. Doc v0.3 section 13.4.
static func regenerate(count: int, previous: PackedStringArray) -> PackedStringArray:
	var weights := build_weights()
	var excluded: Dictionary = {}
	for jamo: String in previous:
		if weights.has(jamo):
			excluded[jamo] = weights[jamo]
			weights.erase(jamo)
	# Small pool: readmit previous picks, weighted, until a full hand is possible.
	while weights.size() < count and not excluded.is_empty():
		var readmitted := _weighted_pick(excluded)
		if readmitted.is_empty():
			break
		weights[readmitted] = excluded[readmitted]
		excluded.erase(readmitted)
	return _pick_distinct(weights, count)


## Draws `count` distinct jamo from a jamo -> weight map, without replacement.
static func _pick_distinct(weights: Dictionary, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for _i in count:
		var picked := _weighted_pick(weights)
		if picked.is_empty():
			break
		result.append(picked)
		weights.erase(picked)
	return result


## jamo -> weight, built from what the craftable words are still missing.
## Public so a test can read the pool without drawing from it.
static func build_weights() -> Dictionary:
	var weights: Dictionary = {}
	for word: WordData in GameState.get_craftable_words():
		var needed: Dictionary = word.required_counts()
		for jamo: String in needed:
			var missing: int = int(needed[jamo]) - GameState.get_jamo_count(jamo)
			if missing <= 0:
				continue
			# A word missing two of the same jamo weighs that jamo higher.
			weights[jamo] = float(weights.get(jamo, 0.0)) + NEEDED_WEIGHT * missing
	for jamo: String in GameState.database.filler_jamo:
		if not weights.has(jamo):
			weights[jamo] = FILLER_WEIGHT
	_apply_focus_bonus(weights)
	return weights


## Pool A: the jamo the Target word is still missing weigh more than the same
## jamo would on their own. The bonus scales the weight it already has, so the
## pool keeps its shape and the jamo never becomes a certainty.
## Doc v0.3 sections 13.3 and 13.4.
static func _apply_focus_bonus(weights: Dictionary) -> void:
	var target: WordData = GameState.get_target_word()
	if target == null:
		return
	var bonus: float = GameState.get_focus_weight_bonus()
	if bonus <= 0.0:
		return
	for jamo: String in target.required_counts():
		if weights.has(jamo):
			weights[jamo] = float(weights[jamo]) * (1.0 + bonus)


static func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for jamo: String in weights:
		total += float(weights[jamo])
	if total <= 0.0:
		return ""
	var roll := randf() * total
	for jamo: String in weights:
		roll -= float(weights[jamo])
		if roll <= 0.0:
			return jamo
	return ""
