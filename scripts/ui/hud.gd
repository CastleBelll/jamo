extends Control

## In-game HUD. Deliberately limited to Day, Energy, Gold, today kills, the
## current word progress and three buttons - no timer, no player HP, no skill
## bar. Doc v0.3 section 23.1.

## Below this much energy the bar warns the player the day is nearly over.
## Doc v0.3 section 23.3.
const LOW_ENERGY_WARNING := 3

signal dictionary_pressed()
signal settings_pressed()
signal pause_pressed()

@onready var _day_label: Label = %DayLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _gold_label: Label = %GoldLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _word_rows: Array[Label] = [
	%WordRow0, %WordRow1, %WordRow2, %WordRow3,
]


func _ready() -> void:
	SignalBus.day_started.connect(_on_day_started)
	SignalBus.energy_changed.connect(_on_energy_changed)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.monster_killed.connect(_on_monster_killed)
	SignalBus.jamo_collected.connect(_on_inventory_changed)
	SignalBus.word_completed.connect(_on_word_completed)

	%DictionaryButton.pressed.connect(dictionary_pressed.emit)
	%SettingsButton.pressed.connect(settings_pressed.emit)
	%PauseButton.pressed.connect(pause_pressed.emit)

	refresh()


## Repaints every field from GameState. Called on load and after the day ends.
func refresh() -> void:
	_on_day_started(GameState.day)
	_on_energy_changed(GameState.energy, GameState.get_max_energy())
	_on_gold_changed(GameState.gold)
	_update_kills()
	_refresh_word_progress()


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


func _on_word_completed(_word: WordData) -> void:
	_refresh_word_progress()


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


func _describe_progress(word: WordData) -> String:
	var parts: PackedStringArray = []
	var needed: Dictionary = word.required_counts()
	for jamo: String in needed:
		var have: int = mini(GameState.get_jamo_count(jamo), int(needed[jamo]))
		parts.append("%s %d/%d" % [jamo, have, int(needed[jamo])])
	return "%s   %s" % [word.word, "  ".join(parts)]
