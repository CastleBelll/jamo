class_name BuildState
extends RefCounted
## Held words of the RUN (G6): shared slots, unique word ids, one Rank per id, at most one
## 위험 word. Effects are applied elsewhere; this only owns the roster.

var slots: int = 6
var risk_max: int = 1
var words: Array[Dictionary] = []   # {"id": StringName, "rank": int}


func setup(balance: BalanceConfig) -> void:
	slots = balance.build_slots
	risk_max = balance.risk_slot_max


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for w in words:
		out.append(w["id"])
	return out


func has(id: StringName) -> bool:
	return _index_of(id) >= 0


func rank_of(id: StringName) -> int:
	var i := _index_of(id)
	return words[i]["rank"] if i >= 0 else 0


func is_full() -> bool:
	return words.size() >= slots


func risk_count(db: ContentDB) -> int:
	var n := 0
	for w in words:
		if db.words[w["id"]].is_risk():
			n += 1
	return n


func add(id: StringName) -> bool:
	if has(id) or is_full():
		return false
	words.append({"id": id, "rank": 1})
	return true


func remove(id: StringName) -> bool:
	var i := _index_of(id)
	if i < 0:
		return false
	words.remove_at(i)
	return true


func rank_up(id: StringName, max_rank: int) -> bool:
	var i := _index_of(id)
	if i < 0 or words[i]["rank"] >= max_rank:
		return false
	words[i]["rank"] += 1
	return true


## 합성 (G6/B8): recipes whose two materials are held at the required Ranks and whose result
## is not already held.
func compound_options(db: ContentDB) -> Array[CompoundData]:
	var out: Array[CompoundData] = []
	var ids := db.compounds.keys()
	ids.sort()
	for id in ids:
		var c: CompoundData = db.compounds[id]
		if has(c.result):
			continue
		if rank_of(c.material_a) >= c.material_a_min_rank and rank_of(c.material_b) >= c.material_b_min_rank:
			out.append(c)
	return out


## Applies one recipe as a single transaction: both materials leave (their Ranks are lost),
## the result enters at Rank 1. Returns false when the recipe is not available.
func apply_compound(db: ContentDB, compound_id: StringName) -> bool:
	var c: CompoundData = db.compounds.get(compound_id)
	if c == null or not (c in compound_options(db)):
		return false
	remove(c.material_a)
	remove(c.material_b)
	words.append({"id": c.result, "rank": 1})
	return true


func _index_of(id: StringName) -> int:
	for i in words.size():
		if words[i]["id"] == id:
			return i
	return -1
