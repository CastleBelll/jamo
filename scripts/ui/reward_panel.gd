extends PanelContainer
## 자모 정리 screen (G10): candidates, deck size, remaining actions, 추가/교체/건너뛰기/제거.
## Talks only to RewardService; the deck token list is rebuilt from it after every change.

signal finished
signal state_changed

const DECK_COLUMNS := 13

var reward: RewardService
var db: ContentDB
var selected_candidate: int = -1
var mode: StringName = &""   # "", "replace", "remove"
var had_drops: bool = false

@onready var stats_label: Label = %StatsLabel
@onready var info_label: Label = %InfoLabel
@onready var candidates_row: HBoxContainer = %Candidates
@onready var hint_label: Label = %HintLabel
@onready var add_button: Button = %AddButton
@onready var replace_button: Button = %ReplaceButton
@onready var skip_button: Button = %SkipButton
@onready var remove_button: Button = %RemoveButton
@onready var deck_grid: GridContainer = %DeckGrid
@onready var deck_view: DeckView = %DeckView
@onready var finish_button: Button = %FinishButton


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	replace_button.pressed.connect(func(): _set_mode(&"replace"))
	remove_button.pressed.connect(func(): _set_mode(&"remove"))
	skip_button.pressed.connect(func(): if reward != null: reward.skip())
	finish_button.pressed.connect(_on_finish)
	deck_grid.columns = DECK_COLUMNS
	for pair in [[add_button, "act_add"], [replace_button, "act_replace"], [skip_button, "act_skip"], [remove_button, "act_remove"]]:
		AssetLib.apply(pair[0], pair[1])


func open(new_reward: RewardService, content: ContentDB, stats_text: String = "") -> void:
	if reward != null and reward.changed.is_connected(_refresh):
		reward.changed.disconnect(_refresh)
	reward = new_reward
	db = content
	stats_label.text = stats_text
	had_drops = not new_reward.candidates.is_empty()
	selected_candidate = 0 if not reward.candidates.is_empty() else -1
	mode = &""
	reward.changed.connect(_refresh)
	reward.changed.connect(func(): state_changed.emit())
	_refresh()
	finish_button.grab_focus()


func _refresh() -> void:
	if reward == null:
		return
	if selected_candidate >= reward.candidates.size():
		selected_candidate = reward.candidates.size() - 1
	# Leave a mode whose action can no longer happen, so clicks never die silently.
	if (reward.candidates.is_empty() or reward.picks_left <= 0) and mode == &"replace":
		mode = &""
	if (reward.removes_left <= 0 or not reward.deck.can_remove()) and mode == &"remove":
		mode = &""
	info_label.text = "덱 %d/%d · 선택 %d · 제거 %d" % [reward.deck.size(), reward.deck.deck_max, reward.picks_left, reward.removes_left]
	_rebuild_candidates()
	_rebuild_deck()
	deck_view.visible = mode == &""
	deck_view.show_counts(DeckView.counts_of(reward.deck.tokens))
	var has_pick := selected_candidate >= 0 and reward.can_pick()
	add_button.disabled = not (has_pick and reward.deck.can_add())
	add_button.text = "추가" if reward.deck.can_add() else "덱 최대"
	replace_button.disabled = not (has_pick and reward.allow_replace)
	replace_button.text = "교체" if reward.allow_replace else "교체 (W2~)"
	skip_button.disabled = not reward.can_pick()
	remove_button.disabled = reward.removes_left <= 0 or not reward.deck.can_remove()
	remove_button.text = "제거" if reward.deck.can_remove() else "덱 최소"
	hint_label.text = _hint_text()


func _rebuild_candidates() -> void:
	for c in candidates_row.get_children():
		candidates_row.remove_child(c)
		c.queue_free()
	for i in reward.candidates.size():
		var b := Button.new()
		b.text = reward.candidates[i]
		_style_tile(b, 120, 52)
		b.toggle_mode = true
		b.button_pressed = i == selected_candidate
		b.pressed.connect(func(): _select_candidate(i))
		candidates_row.add_child(b)
	if reward.candidates.is_empty():
		var l := Label.new()
		l.text = "선택 완료" if had_drops else "회수한 자모 없음"
		candidates_row.add_child(l)


func _rebuild_deck() -> void:
	for c in deck_grid.get_children():
		deck_grid.remove_child(c)
		c.queue_free()
	deck_grid.visible = mode != &""
	if mode == &"":
		return
	for t in reward.deck.tokens:
		var b := Button.new()
		b.text = t["jamo"]
		_style_tile(b, 72, 34)
		var token_id: int = t["id"]
		b.pressed.connect(func(): _on_token(token_id))
		deck_grid.add_child(b)


## Jamo tiles (G10): square ghost buttons with a big glyph.
func _style_tile(b: Button, size: int, font_size: int) -> void:
	b.custom_minimum_size = Vector2(size, size)
	b.theme_type_variation = &"GhostButton"
	b.add_theme_font_size_override("font_size", font_size)


func _select_candidate(i: int) -> void:
	selected_candidate = i
	_refresh()


func _set_mode(new_mode: StringName) -> void:
	mode = &"" if mode == new_mode else new_mode
	_refresh()


func _on_add() -> void:
	reward.add(selected_candidate)


func _on_token(token_id: int) -> void:
	match mode:
		&"replace":
			if reward.replace(selected_candidate, token_id):
				mode = &""
				_refresh()
		&"remove":
			if reward.remove(token_id):
				_refresh()


func _on_finish() -> void:
	reward.finish()
	finished.emit()


## Which start-unlocked words use the selected jamo, and how many of it the deck still lacks.
func _hint_text() -> String:
	if mode == &"remove":
		return "뺄 활자 선택 (최소 %d장)" % reward.deck.deck_min
	if mode == &"replace":
		return "바꿀 덱 활자 선택"
	if selected_candidate < 0 or selected_candidate >= reward.candidates.size():
		return ""
	var jamo: String = reward.candidates[selected_candidate]
	var names: Array[String] = []
	for w in db.base_words():
		if w.unlock == &"start" and jamo in w.required_jamo:
			var missing := reward.deck.missing_for(w)
			names.append(w.name + ("(%d)" % missing[jamo] if missing.has(jamo) else ""))
	return "%s → %s" % [jamo, " ".join(names)] if not names.is_empty() else "%s → 쓰는 단어 없음" % jamo
