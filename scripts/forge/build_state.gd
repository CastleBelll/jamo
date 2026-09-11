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


func _index_of(id: StringName) -> int:
	for i in words.size():
		if words[i]["id"] == id:
			return i
	return -1
