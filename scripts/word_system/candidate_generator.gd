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
	var weights := _build_weights()
	var result := PackedStringArray()
	for _i in count:
		var picked := _weighted_pick(weights)
		if picked.is_empty():
			break
		result.append(picked)
		weights.erase(picked)
	return result


## jamo -> weight, built from what the craftable words are still missing.
static func _build_weights() -> Dictionary:
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
	return weights


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
