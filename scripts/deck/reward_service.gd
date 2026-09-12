class_name RewardService
extends RefCounted
## 자모 정리 model (G4/B4): a budget of picks (추가/교체/건너뛰기) and optional removes over
## this Wave's recovered jamo. Unpicked drops vanish; nothing converts to Gold.

signal changed

var deck: DeckService
var candidates: Array[String] = []
var picks_left: int = 0
var removes_left: int = 0
var allow_replace: bool = true
var finished: bool = false


func start(run_deck: DeckService, drops: Array[String], picks: int, removes: int, replace_allowed: bool) -> void:
	deck = run_deck
	candidates = drops.duplicate()
	# Only as many picks as there are drops; removes stay usable even with none (G4).
	picks_left = mini(picks, candidates.size())
	removes_left = removes
	allow_replace = replace_allowed
	finished = false
	changed.emit()


func can_pick() -> bool:
	return not finished and picks_left > 0 and not candidates.is_empty()


func can_add(index: int) -> bool:
	return can_pick() and index >= 0 and index < candidates.size() and deck.can_add()


func can_replace(index: int, token_id: int) -> bool:
	return can_pick() and allow_replace and index >= 0 and index < candidates.size() and deck.has_token(token_id)


func can_remove(token_id: int) -> bool:
	return not finished and removes_left > 0 and deck.can_remove() and deck.has_token(token_id)


func add(index: int) -> bool:
	if not can_add(index):
		return false
	RunLog.event("reward_action", {"action": "add", "jamo": candidates[index]})
	deck.add_token(candidates[index])
	_consume(index)
	return true


func replace(index: int, token_id: int) -> bool:
	if not can_replace(index, token_id):
		return false
	RunLog.event("reward_action", {"action": "replace", "jamo": candidates[index], "token": token_id})
	deck.replace_token(token_id, candidates[index])
	_consume(index)
	return true


## 건너뛰기 spends one pick without touching the deck.
func skip() -> bool:
	if not can_pick():
		return false
	RunLog.event("reward_action", {"action": "skip"})
	picks_left -= 1
	changed.emit()
	return true


func remove(token_id: int) -> bool:
	if not can_remove(token_id):
		return false
	RunLog.event("reward_action", {"action": "remove", "token": token_id})
	deck.remove_token(token_id)
	removes_left -= 1
	changed.emit()
	return true


## Ends the screen; leftover candidates are discarded (미선택 회수는 사라진다).
func finish() -> void:
	finished = true
	candidates.clear()
	picks_left = 0
	changed.emit()


func _consume(index: int) -> void:
	candidates.remove_at(index)
	picks_left -= 1
	changed.emit()


func snapshot() -> Dictionary:
	return {"candidates": candidates.duplicate(), "picks_left": picks_left, "removes_left": removes_left,
		"allow_replace": allow_replace, "finished": finished}


func load_snapshot(d: Dictionary, run_deck: DeckService) -> void:
	deck = run_deck
	candidates.clear()
	for j in d.get("candidates", []):
		candidates.append(String(j))
	picks_left = int(d.get("picks_left", 0))
	removes_left = int(d.get("removes_left", 0))
	allow_replace = bool(d.get("allow_replace", true))
	finished = bool(d.get("finished", false))
	changed.emit()
