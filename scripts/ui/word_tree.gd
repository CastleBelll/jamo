extends Control

## Word tech tree. Doc v0.3 section 23.5.
##
## The layout lives in word_tree.tscn: one column per word category, a fixed
## number of Button slots per column. This script only fills text in, folds the
## unused slots away and says out loud when a column ran out of room. It never
## creates a node, so the whole tree stays editable in the editor.
##
## Every state it shows comes from GameState.get_word_state(), which is also
## what the HUD reads, so the two panels cannot disagree about a word.

signal closed()

## Guard against a cyclic prerequisite chain in the data, and the deepest
## indent the columns are drawn with.
const MAX_TREE_DEPTH := 6
## One indent step per prerequisite hop, so a branch reads as a branch.
const INDENT := "  "
const BRANCH := "└ "
## Marks the current target in the slot text itself, never by colour alone.
const TARGET_MARK := "  ← 목표"

const SUMMARY_FORMAT := "완성한 단어  %d / %d"
const TARGET_FORMAT := "목표 단어: %s"
const TARGET_NONE := "목표 단어: 없음"
const OVERFLOW_FORMAT := "칸이 모자라 %d개를 감췄습니다"
const DETAIL_PLACEHOLDER := "단어를 선택하면 필요한 자모와 선행 단어가 여기에 보입니다."

## Category id each column shows, in scene order. The last entry is the
## catch-all: a word whose category matches no earlier column lands there, so a
## category added to the database can never vanish from the tree in silence.
@export var column_categories: Array[StringName] = []

@onready var _columns_root: HBoxContainer = %Columns
@onready var _summary_label: Label = %SummaryLabel
@onready var _target_label: Label = %TargetLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _status_label: Label = %StatusLabel
@onready var _clear_target_button: Button = %ClearTargetButton
@onready var _close_button: Button = %CloseButton

## Column index -> its Button slots, read off the scene so adding a slot in the
## editor needs no code change.
var _slots: Array[Array] = []
## Column index -> its overflow notice, or null when a column has none.
var _overflow_labels: Array[Label] = []
## Button -> the word it currently shows.
var _slot_words: Dictionary = {}


func _ready() -> void:
	hide()
	_collect_columns()
	_clear_target_button.pressed.connect(_on_clear_target_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	SignalBus.target_word_changed.connect(_on_target_word_changed)


## Reads the slots and the overflow notice out of each column in the scene.
func _collect_columns() -> void:
	for column: Node in _columns_root.get_children():
		var slots: Array[Button] = []
		var overflow: Label = null
		for child: Node in column.get_children():
			if child is Button and String(child.name).begins_with("Slot"):
				var slot := child as Button
				slot.pressed.connect(_on_slot_pressed.bind(slot))
				slot.focus_entered.connect(_on_slot_highlighted.bind(slot))
				slot.mouse_entered.connect(_on_slot_highlighted.bind(slot))
				slots.append(slot)
			elif child is Label and child.name == &"Overflow":
				overflow = child as Label
		_slots.append(slots)
		_overflow_labels.append(overflow)
	if _slots.size() != column_categories.size():
		push_warning(
			"WordTree has %d columns but %d category ids."
			% [_slots.size(), column_categories.size()]
		)


func open() -> void:
	refresh()
	show()
	_focus_first_slot()


## Repaints every slot from GameState. Public so a caller or a test can check
## the tree without opening it.
func refresh() -> void:
	_refresh_slots()
	_refresh_header()
	_detail_label.text = DETAIL_PLACEHOLDER
	_status_label.text = ""


func _refresh_slots() -> void:
	_slot_words.clear()
	var buckets := _bucket_words()
	for index in _slots.size():
		_fill_column(index, buckets[index])


func _refresh_header() -> void:
	var words: Array[WordData] = GameState.database.words
	var unlocked := 0
	for word: WordData in words:
		if word != null and GameState.is_word_unlocked(word.id):
			unlocked += 1
	_summary_label.text = SUMMARY_FORMAT % [unlocked, words.size()]

	var target: WordData = GameState.get_target_word()
	_target_label.text = TARGET_NONE if target == null else TARGET_FORMAT % target.word
	# Hidden rather than disabled: a disabled button would report "no target"
	# by colour alone, and its greyed label misses the WCAG AA contrast floor.
	_clear_target_button.visible = target != null


## Database words split into one bucket per column, each bucket shallowest
## first so a word always sits below the prerequisite it grew from.
func _bucket_words() -> Array:
	var buckets: Array = []
	for _index in _slots.size():
		buckets.append([])
	if buckets.is_empty():
		return buckets
	for word: WordData in GameState.database.words:
		if word == null:
			continue
		buckets[_column_for(word)].append(word)
	var sorted: Array = []
	for bucket: Array in buckets:
		sorted.append(_sorted_by_depth(bucket))
	return sorted


## Column a word belongs in. Falls back to the last column, which the scene
## keeps as the catch-all for categories no column claims.
func _column_for(word: WordData) -> int:
	for index in mini(column_categories.size(), _slots.size()):
		if column_categories[index] == word.category:
			return index
	return _slots.size() - 1


func _sorted_by_depth(words: Array) -> Array[WordData]:
	var ordered: Array[WordData] = []
	for depth in MAX_TREE_DEPTH + 1:
		for word: WordData in words:
			if _depth_of(word) == depth:
				ordered.append(word)
	# A word deeper than the indent can draw still has to be listed somewhere.
	for word: WordData in words:
		if not ordered.has(word):
			ordered.append(word)
	return ordered


## How many prerequisite hops a word sits below its root, used for the indent.
## Stops at MAX_TREE_DEPTH so a cyclic chain in the data cannot hang the UI.
func _depth_of(word: WordData) -> int:
	var depth := 0
	var current := word
	while current != null and not current.prerequisites.is_empty():
		depth += 1
		if depth >= MAX_TREE_DEPTH:
			return MAX_TREE_DEPTH
		current = GameState.database.find_word(current.prerequisites[0])
	return depth


func _fill_column(index: int, words: Array) -> void:
	var slots: Array = _slots[index]
	for i in slots.size():
		var slot: Button = slots[i]
		if i >= words.size():
			slot.visible = false
			continue
		var word: WordData = words[i]
		slot.visible = true
		slot.text = _slot_text(word)
		slot.tooltip_text = _detail_text(word)
		_slot_words[slot] = word

	var overflow: Label = _overflow_labels[index]
	if overflow == null:
		return
	# More words than slots must never fail silently: say how many are hidden
	# instead of dropping them off the bottom of the column.
	var hidden: int = words.size() - slots.size()
	overflow.visible = hidden > 0
	if hidden > 0:
		overflow.text = OVERFLOW_FORMAT % hidden


func _slot_text(word: WordData) -> String:
	var depth := _depth_of(word)
	var branch := BRANCH if depth > 0 else ""
	var mark := TARGET_MARK if GameState.target_word_id == word.id else ""
	return "%s%s%s %s%s" % [INDENT.repeat(depth), branch, _state_tag(word), word.word, mark]


## The four states are spelled out in words. Colour is never the only cue.
## Doc v0.3 section 23.5.
func _state_tag(word: WordData) -> String:
	match GameState.get_word_state(word):
		GameState.WordState.UNLOCKED:
			return "[완성]"
		GameState.WordState.CRAFTABLE:
			return "[제작 가능]"
		GameState.WordState.PREREQUISITE_LOCKED:
			return "[선행 잠금]"
		_:
			return "[미발견]"


## What the detail line says about one word. An undiscovered word keeps its
## recipe hidden - that is the whole point of the state.
func _detail_text(word: WordData) -> String:
	var lines := PackedStringArray()
	lines.append("%s %s" % [_state_tag(word), word.word])
	if GameState.get_word_state(word) == GameState.WordState.UNDISCOVERED:
		lines.append("선행 단어를 먼저 완성해야 재료가 보입니다.")
		return "\n".join(lines)
	lines.append("필요 자모  %s" % _progress_text(word))
	if not word.prerequisites.is_empty():
		lines.append("선행 단어  %s" % _prerequisite_text(word))
	if not word.description.is_empty():
		lines.append(word.description)
	return "\n".join(lines)


## Held / needed per jamo, the same reading the HUD craft list shows.
func _progress_text(word: WordData) -> String:
	var parts := PackedStringArray()
	var needed: Dictionary = word.required_counts()
	for jamo: String in needed:
		var have: int = mini(GameState.get_jamo_count(jamo), int(needed[jamo]))
		parts.append("%s %d/%d" % [jamo, have, int(needed[jamo])])
	return "  ".join(parts)


func _prerequisite_text(word: WordData) -> String:
	var parts := PackedStringArray()
	for prerequisite: StringName in word.prerequisites:
		var parent: WordData = GameState.database.find_word(prerequisite)
		if parent == null:
			parts.append(String(prerequisite))
			continue
		var done := "" if GameState.is_word_unlocked(parent.id) else " (미완성)"
		parts.append("%s%s" % [parent.word, done])
	return " + ".join(parts)


## Why a word was refused as the target, in words rather than a silent no-op.
func _refusal_text(word: WordData) -> String:
	match GameState.get_word_state(word):
		GameState.WordState.UNLOCKED:
			return "%s 은(는) 이미 완성한 단어입니다." % word.word
		GameState.WordState.PREREQUISITE_LOCKED:
			return "%s 은(는) 선행 단어가 잠겨 있어 목표로 지정할 수 없습니다." % word.word
		_:
			return "%s 은(는) 아직 발견하지 못해 목표로 지정할 수 없습니다." % word.word


func _focus_first_slot() -> void:
	for slots: Array in _slots:
		for slot: Button in slots:
			if slot.visible:
				slot.grab_focus()
				return
	_close_button.grab_focus()


func _on_slot_pressed(slot: Button) -> void:
	var word: WordData = _slot_words.get(slot)
	if word == null:
		return
	if not GameState.set_target_word(word.id):
		_status_label.text = _refusal_text(word)
		return
	# set_target_word already repainted the slots through the signal.
	_status_label.text = "%s 을(를) 목표로 지정했습니다." % word.word
	_detail_label.text = _detail_text(word)


func _on_slot_highlighted(slot: Button) -> void:
	var word: WordData = _slot_words.get(slot)
	if word != null:
		_detail_label.text = _detail_text(word)


func _on_clear_target_pressed() -> void:
	GameState.clear_target_word()
	_status_label.text = "목표 단어를 해제했습니다."
	_focus_first_slot()


func _on_target_word_changed(_word: WordData) -> void:
	if not is_node_ready():
		return
	_refresh_slots()
	_refresh_header()


func _on_close_pressed() -> void:
	hide()
	closed.emit()
