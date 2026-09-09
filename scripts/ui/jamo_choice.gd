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


func _ready() -> void:
	hide()
	for card: JamoCard in _cards:
		card.chosen.connect(_on_card_chosen)
	_skip_button.pressed.connect(_on_skip_pressed)


func open() -> void:
	var candidates := CandidateGenerator.generate(GameState.get_jamo_candidate_count())
	var is_empty := candidates.is_empty()
	_empty_label.visible = is_empty
	_skip_button.visible = is_empty
	for i in _cards.size():
		if i < candidates.size():
			_cards[i].setup(candidates[i])
		else:
			_cards[i].visible = false
	show()
	if is_empty:
		_skip_button.grab_focus()
	elif not _cards.is_empty():
		_cards[0].grab_card_focus()


func _on_card_chosen(jamo: String) -> void:
	hide()
	chosen.emit(jamo)


func _on_skip_pressed() -> void:
	hide()
	chosen.emit("")
