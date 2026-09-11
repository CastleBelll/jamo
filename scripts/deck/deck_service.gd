class_name DeckService
extends RefCounted
## The RUN deck (G4): a multiset of jamo tokens with unique token ids. Token count is the
## invariant every operation preserves or changes by exactly one, inside B3 min/max.

var tokens: Array[Dictionary] = []   # {"id": int, "jamo": String}
var deck_min: int = 14
var deck_max: int = 26
var _next_id: int = 1


static func from_deck_data(data: DeckData, balance: BalanceConfig) -> DeckService:
	var d := DeckService.new()
	d.deck_min = balance.deck_min
	d.deck_max = balance.deck_max
	for j in data.tokens:
		d._push(j)
	return d


func snapshot() -> Dictionary:
	return {"tokens": tokens.duplicate(true), "next_id": _next_id, "deck_min": deck_min, "deck_max": deck_max}


static func from_snapshot(d: Dictionary, balance: BalanceConfig) -> DeckService:
	var s := DeckService.new()
	s.deck_min = balance.deck_min
	s.deck_max = balance.deck_max
	for t in d.get("tokens", []):
		s.tokens.append({"id": int(t["id"]), "jamo": String(t["jamo"])})
	s._next_id = int(d.get("next_id", s.tokens.size() + 1))
	return s


func size() -> int:
	return tokens.size()


func jamo_list() -> Array[String]:
	var out: Array[String] = []
	for t in tokens:
		out.append(t["jamo"])
	return out


func counts() -> Dictionary:
	var out := {}
	for t in tokens:
		out[t["jamo"]] = out.get(t["jamo"], 0) + 1
	return out


func has_token(token_id: int) -> bool:
	return _index_of(token_id) >= 0


func can_add() -> bool:
	return tokens.size() < deck_max


func can_remove() -> bool:
	return tokens.size() > deck_min


## 추가: one new token. Returns the new token id, or -1 when the deck is full.
func add_token(jamo: String) -> int:
	if not can_add():
		return -1
	return _push(jamo)


## 교체: swap one deck token for one drop; size is unchanged.
func replace_token(token_id: int, jamo: String) -> bool:
	var i := _index_of(token_id)
	if i < 0:
		return false
	tokens[i] = {"id": _next_id, "jamo": jamo}
	_next_id += 1
	return true


## 제거: only above the minimum size.
func remove_token(token_id: int) -> bool:
	var i := _index_of(token_id)
	if i < 0 or not can_remove():
		return false
	tokens.remove_at(i)
	return true


## Words whose required jamo the deck can currently cover (used by the 정리 UI hints).
func missing_for(word: WordData) -> Dictionary:
	var have := counts()
	var need := {}
	for j in word.required_jamo:
		need[j] = need.get(j, 0) + 1
	var missing := {}
	for j in need:
		if have.get(j, 0) < need[j]:
			missing[j] = need[j] - have.get(j, 0)
	return missing


func _push(jamo: String) -> int:
	var id := _next_id
	_next_id += 1
	tokens.append({"id": id, "jamo": jamo})
	return id


func _index_of(token_id: int) -> int:
	for i in tokens.size():
		if tokens[i]["id"] == token_id:
			return i
	return -1
