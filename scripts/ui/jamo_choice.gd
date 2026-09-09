extends Control

## Day-end jamo pick. Doc v0.3 section 13: the player takes exactly one jamo
## per day. Candidates come from CandidateGenerator, never from the monsters
## that happened to be on the field.

## Emitted with the chosen jamo, or an empty string when the day is skipped
## because no craftable word needs anything.
signal chosen(jamo: String)

@onready var _cards: Array[JamoCard] = [%Card0, %Card1, %Card2, %Card3]
@onready var _empty_label: Label = %EmptyLabel
@onready var _skip_button: Button = %SkipButton
@onready var _reroll_row: HBoxContainer = %RerollRow
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_count_label: Label = %RerollCountLabel

## Today's candidates, kept so a reroll knows what to avoid.
var _candidates: PackedStringArray = PackedStringArray()


func _ready() -> void:
	hide()
	for card: JamoCard in _cards:
		card.chosen.connect(_on_card_chosen)
	_skip_button.pressed.connect(_on_skip_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)


func open() -> void:
	_candidates = CandidateGenerator.generate(GameState.get_jamo_candidate_count())
	_show_candidates()
	show()
	if _candidates.is_empty():
		_skip_button.grab_focus()
	elif not _cards.is_empty():
		_cards[0].grab_card_focus()


func _show_candidates() -> void:
	var is_empty := _candidates.is_empty()
	_empty_label.visible = is_empty
	_skip_button.visible = is_empty
	for i in _cards.size():
		if i < _candidates.size():
			_cards[i].setup(_candidates[i])
		else:
			_cards[i].visible = false
	_refresh_reroll()


## The 리롤 row is hidden entirely while the track is locked; once owned it
## stays visible and says in words why it is unusable, never by colour alone.
func _refresh_reroll() -> void:
	var maximum := GameState.get_max_rerolls()
	_reroll_row.visible = maximum > 0
	if maximum <= 0:
		return
	var left := GameState.rerolls_left
	var reason := ""
	if left <= 0:
		reason = "  ·  오늘 리롤을 모두 썼습니다"
	elif _candidates.is_empty():
		reason = "  ·  다시 뽑을 후보가 없습니다"
	_reroll_button.disabled = not reason.is_empty()
	_reroll_count_label.text = "리롤 %d/%d%s" % [left, maximum, reason]


func _on_reroll_pressed() -> void:
	# The panel is hidden the moment a card is picked, so a pick is final.
	if not visible or not GameState.consume_reroll():
		_refresh_reroll()
		return
	_candidates = CandidateGenerator.regenerate(
		GameState.get_jamo_candidate_count(), _candidates
	)
	_show_candidates()
	# Keep focus reachable once the button turns itself off.
	if _reroll_button.disabled and not _candidates.is_empty():
		_cards[0].grab_card_focus()


func _on_card_chosen(jamo: String) -> void:
	hide()
	chosen.emit(jamo)


func _on_skip_pressed() -> void:
	hide()
	chosen.emit("")
