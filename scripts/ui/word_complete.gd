extends Control

## Word completion moment. Doc v0.3 section 14.2 calls this out as one of the
## game's main reward beats, so it gets its own full-screen panel.

signal closed()

@onready var _word_label: Label = %CompletedWord
@onready var _jamo_label: Label = %CompletedJamo
@onready var _effect_label: Label = %CompletedEffect

var _queue: Array[WordData] = []


## Shows each completed word in turn, then emits closed().
func open(words: Array[WordData]) -> void:
	_queue = words.duplicate()
	_show_next()


func _ready() -> void:
	hide()
	%WordCompleteContinue.pressed.connect(_show_next)


func _show_next() -> void:
	if _queue.is_empty():
		hide()
		closed.emit()
		return
	var word: WordData = _queue.pop_front()
	_word_label.text = word.word
	_jamo_label.text = " + ".join(word.required_jamo)
	_effect_label.text = word.description
	show()
	%WordCompleteContinue.grab_focus()
