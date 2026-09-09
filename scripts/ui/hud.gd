extends Control

## In-game HUD. Deliberately limited to Day, Energy, Gold, today kills, the
## current word progress and three buttons - no timer, no player HP, no skill
## bar. Doc v0.3 section 23.1.

## Below this much energy the bar warns the player the day is nearly over.
## Doc v0.3 section 23.3.
const LOW_ENERGY_WARNING := 3
## Shown while no target word is set. Doc v0.3 section 23.1.
const TARGET_NONE_TEXT := "TARGET: 없음  (트리에서 지정)"

signal dictionary_pressed()
signal settings_pressed()
signal pause_pressed()

@onready var _day_label: Label = %DayLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _gold_label: Label = %GoldLabel
@onready var _kills_label: Label = %KillsLabel
## One static row per word in the database; the script only shows, hides and
## fills them, it never creates nodes. Doc v0.3 section 19.1.
@onready var _word_rows: Array[Label] = [
	%WordRow0, %WordRow1, %WordRow2, %WordRow3, %WordRow4,
	%WordRow5, %WordRow6, %WordRow7, %WordRow8, %WordRow9,
]
@onready var _word_overflow_label: Label = %WordOverflowLabel
@onready var _word_empty_label: Label = %WordEmptyLabel
@onready var _target_word_label: Label = %TargetWordLabel
@onready var _target_slots_label: Label = %TargetSlotsLabel


func _ready() -> void:
	SignalBus.day_started.connect(_on_day_started)
	SignalBus.energy_changed.connect(_on_energy_changed)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.monster_killed.connect(_on_monster_killed)
	SignalBus.jamo_collected.connect(_on_inventory_changed)
	SignalBus.word_completed.connect(_on_word_completed)
	SignalBus.target_word_changed.connect(_on_target_word_changed)

	%DictionaryButton.pressed.connect(dictionary_pressed.emit)
	%SettingsButton.pressed.connect(settings_pressed.emit)
	%PauseButton.pressed.connect(pause_pressed.emit)

	refresh()


## Tab does nothing while no control holds focus, which is how the game starts
## and how it comes back from a panel that hid its own focused button. Seeding
## the top bar here is what lets the player reach the tree without a mouse.
## Doc v0.3 section 27.
func _unhandled_input(event: InputEvent) -> void:
	var next_pressed := event.is_action_pressed(&"ui_focus_next")
	if not next_pressed and not event.is_action_pressed(&"ui_focus_prev"):
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	focus_first_button()
	get_viewport().set_input_as_handled()


## Puts keyboard focus on the first top bar button. Public so a panel can hand
## focus back to the HUD when it closes instead of dropping it on the floor.
func focus_first_button() -> void:
	%DictionaryButton.grab_focus()


## Repaints every field from GameState. Called on load and after the day ends.
func refresh() -> void:
	_on_day_started(GameState.day)
	_on_energy_changed(GameState.energy, GameState.get_max_energy())
	_on_gold_changed(GameState.gold)
	_update_kills()
	_refresh_word_progress()
	_refresh_target()


func _on_day_started(day: int) -> void:
	_day_label.text = "DAY %d" % day
	_update_kills()
	_refresh_word_progress()


func _on_energy_changed(current: int, maximum: int) -> void:
	_energy_label.text = "ENERGY %d / %d" % [current, maximum]
	_energy_bar.max_value = maxi(1, maximum)
	_energy_bar.value = current
	# Colour is a reinforcement, never the only cue: the number is always there.
	var low := current <= LOW_ENERGY_WARNING and current > 0
	_energy_label.modulate = Color(0.72, 0.27, 0.18) if low else Color.WHITE


func _on_gold_changed(total: float) -> void:
	_gold_label.text = "%s G" % _format_gold(total)


func _on_monster_killed(_jamo: String, _gold: float, _position: Vector3) -> void:
	_update_kills()


func _on_inventory_changed(_jamo: String) -> void:
	_refresh_word_progress()
	_refresh_target()


func _on_word_completed(_word: WordData) -> void:
	_refresh_word_progress()
	_refresh_target()


func _on_target_word_changed(_word: WordData) -> void:
	_refresh_target()


func _update_kills() -> void:
	_kills_label.text = "처치 %d" % GameState.kills_today


static func _format_gold(amount: float) -> String:
	var whole := int(floorf(amount))
	var text := str(whole)
	var grouped := ""
	var digits := 0
	for i in range(text.length() - 1, -1, -1):
		grouped = text[i] + grouped
		digits += 1
		if digits % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped


## Shows how far each craftable word has come. Jamo are collected into an
## unordered inventory, so progress reads as "held / needed" per jamo.
func _refresh_word_progress() -> void:
	var craftable := GameState.get_craftable_words()
	for i in _word_rows.size():
		var row := _word_rows[i]
		if i >= craftable.size():
			row.visible = false
			continue
		row.visible = true
		row.text = _describe_progress(craftable[i])

	# Nothing left to craft still has to say so; an empty box reads as a bug.
	_word_empty_label.visible = craftable.is_empty()
	# More words than rows must not fail silently: say how many are hidden.
	var overflow := craftable.size() - _word_rows.size()
	_word_overflow_label.visible = overflow > 0
	if overflow > 0:
		_word_overflow_label.text = "외 %d개 더" % overflow


## The small bottom readout: the word being aimed at and how much of it is
## already in the inventory, as "TARGET: 불" over "[ㅂ][ㅜ][ ]".
## Doc v0.3 section 23.1.
func _refresh_target() -> void:
	var target := GameState.get_target_word()
	if target == null:
		_target_word_label.text = TARGET_NONE_TEXT
		_target_slots_label.visible = false
		return
	_target_word_label.text = "TARGET: %s" % target.word
	_target_slots_label.visible = true
	_target_slots_label.text = _target_slot_text(target)


## One bracket per required jamo, in the word's own order so a doubled jamo
## fills one slot at a time. A slot the inventory cannot pay for stays blank.
func _target_slot_text(word: WordData) -> String:
	var remaining: Dictionary = {}
	var slots := PackedStringArray()
	for jamo: String in word.required_jamo:
		var held: int = GameState.get_jamo_count(jamo) - int(remaining.get(jamo, 0))
		if held > 0:
			remaining[jamo] = int(remaining.get(jamo, 0)) + 1
			slots.append("[%s]" % jamo)
		else:
			slots.append("[ ]")
	return "".join(slots)


func _describe_progress(word: WordData) -> String:
	var parts: PackedStringArray = []
	var needed: Dictionary = word.required_counts()
	for jamo: String in needed:
		var have: int = mini(GameState.get_jamo_count(jamo), int(needed[jamo]))
		parts.append("%s %d/%d" % [jamo, have, int(needed[jamo])])
	return "%s   %s" % [word.word, "  ".join(parts)]
