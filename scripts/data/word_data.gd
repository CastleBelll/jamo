class_name WordData
extends Resource
## A base word (B7) or compound result (B8). `required_jamo` is the authoritative
## multiset for Forge checks; the Unicode decomposition of `name` is only a typo guard.

const CATEGORIES: Array[StringName] = [&"E", &"R", &"S", &"X"]
const TAGS: Array[StringName] = [&"무기", &"화염", &"지속", &"방어", &"자동", &"냉기", &"경제", &"행운", &"위험"]
const UNLOCKS: Array[StringName] = [&"start", &"after_mieum"]
const MAX_RANK_BASE := 3
const MAX_RANK_COMPOUND := 1

@export var id: StringName = &""
@export var name: String = ""
@export var required_jamo: Array[String] = []
@export var category: StringName = &"E"
@export var tags: Array[StringName] = []
@export var role: String = ""
@export var rank1: Array[Resource] = []
@export var rank2: Array[Resource] = []
@export var rank3: Array[Resource] = []
@export var unlock: StringName = &"start"
@export var related_boss: StringName = &""
## Compound this word is a material of (informational; recipe lives in CompoundData).
@export var compound_id: StringName = &""
@export var is_compound: bool = false
## Forge candidate precondition: at least one of these words must be held (폭주).
@export var requires_any_word: Array[StringName] = []


func is_risk() -> bool:
	return category == &"X"


func max_rank() -> int:
	return MAX_RANK_COMPOUND if is_compound else MAX_RANK_BASE


func effects_at(rank: int) -> Array[Resource]:
	match rank:
		1: return rank1
		2: return rank2
		3: return rank3
	return []


func validate() -> Array[String]:
	var errors: Array[String] = []
	var p := "word %s" % id
	if id == &"" or name == "":
		errors.append("%s: id and name are required" % p)
	if required_jamo.is_empty():
		errors.append("%s: required_jamo empty" % p)
	if category not in CATEGORIES:
		errors.append("%s: bad category '%s'" % [p, category])
	if (category == &"X") != (&"위험" in tags):
		errors.append("%s: category X must match the 위험 tag" % p)
	for t in tags:
		if t not in TAGS:
			errors.append("%s: unknown tag '%s'" % [p, t])
	if unlock not in UNLOCKS:
		errors.append("%s: bad unlock '%s'" % [p, unlock])
	var decomposed := HangulJamo.decompose(name)
	var expected := required_jamo.duplicate()
	expected.sort()
	decomposed.sort()
	if decomposed != expected:
		errors.append("%s: required_jamo %s != decomposition of '%s' %s" % [p, required_jamo, name, decomposed])
	if rank1.is_empty():
		errors.append("%s: rank1 has no effects" % p)
	if is_compound and (not rank2.is_empty() or not rank3.is_empty()):
		errors.append("%s: compound results are Rank 1 only" % p)
	if not is_compound and (rank2.is_empty() or rank3.is_empty()):
		errors.append("%s: base words need rank2 and rank3" % p)
	for rank in range(1, 4):
		var effects := effects_at(rank)
		for i in effects.size():
			var e := effects[i] as EffectData
			if e == null:
				errors.append("%s: rank%d[%d] is not EffectData" % [p, rank, i])
				continue
			errors.append_array(e.validate("%s rank%d[%d]" % [p, rank, i]))
	return errors
