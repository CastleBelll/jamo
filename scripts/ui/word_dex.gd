extends Control

## Word dex. One static row per word in the database; the script only fills in
## text and state, it never creates nodes.

signal closed()

@onready var _rows: Array[Label] = [
	%DexRow0, %DexRow1, %DexRow2, %DexRow3, %DexRow4,
	%DexRow5, %DexRow6, %DexRow7, %DexRow8, %DexRow9,
]
@onready var _count_label: Label = %DexCount


func _ready() -> void:
	hide()
	%DexCloseButton.pressed.connect(_on_close_pressed)


func open() -> void:
	var words: Array[WordData] = GameState.database.words
	var unlocked := 0
	for word: WordData in words:
		if GameState.is_word_unlocked(word.id):
			unlocked += 1
	for i in _rows.size():
		var row := _rows[i]
		if i >= words.size():
			row.visible = false
			continue
		row.visible = true
		row.text = _describe(words[i])
	_count_label.text = "완성한 단어  %d / %d" % [unlocked, words.size()]
	show()
	%DexCloseButton.grab_focus()


## State is spelled out in words, never signalled by colour alone.
func _describe(word: WordData) -> String:
	if GameState.is_word_unlocked(word.id):
		return "[완성] %s   %s" % [word.word, word.description]
	if not GameState.are_prerequisites_met(word):
		return "[선행 잠금] %s" % word.word
	return "[제작 가능] %s   필요 %s" % [word.word, " + ".join(word.required_jamo)]


func _on_close_pressed() -> void:
	hide()
	closed.emit()
