class_name JamoCard
extends VBoxContainer

## One day-end jamo candidate. Four cards sit in jamo_choice.tscn already;
## the panel just fills in the ones it needs and hides the rest, so nothing is
## created from script. Doc v0.3 section 19.1.

signal chosen(jamo: String)

var jamo: String = ""

@onready var _button: Button = %CardButton
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	_button.pressed.connect(_on_pressed)


func setup(new_jamo: String) -> void:
	jamo = new_jamo
	_button.text = new_jamo
	_button.tooltip_text = "자모 %s 선택" % new_jamo
	var held := GameState.get_jamo_count(new_jamo)
	_hint.text = "보유 %d" % held
	visible = true


func _on_pressed() -> void:
	chosen.emit(jamo)


## Moves keyboard focus onto this card, so the pick is reachable without a mouse.
func grab_card_focus() -> void:
	_button.grab_focus()
