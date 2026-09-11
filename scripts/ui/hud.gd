extends Control

## In-game HUD. Doc v0.4 section 30: Wave, 문장핵 HP, Energy, Gold, kills and the
## top-bar buttons. The equipped-word and synergy readouts also belong here, but
## there is nothing to equip until the slot board arrives in Phase 2, so the
## rows are authored in hud.tscn and simply report an empty build for now.

## Fraction of max 문장핵 HP below which the readout is tinted as a warning.
const CORE_LOW_FRACTION := 0.25
## Warning line while manual clicks are nearly out, and the line shown at 0.
const ENERGY_LOW_TEXT := "⚠ 에너지 부족"
const ENERGY_EMPTY_TEXT := "수동 클릭 불가 — WAVE 는 계속된다"

signal codex_pressed()
signal settings_pressed()
signal pause_pressed()

@onready var _wave_label: Label = %WaveLabel
@onready var _core_label: Label = %CoreLabel
@onready var _core_bar: ProgressBar = %CoreBar
@onready var _energy_label: Label = %EnergyLabel
@onready var _energy_bar: ProgressBar = %EnergyBar
## The low-energy warning: a label that appears and blinks, so the cue is text
## plus motion and not colour alone.
@onready var _energy_warn_label: Label = %EnergyWarnLabel
## Punch on every energy change; the warning loop lives in its own player
## because one AnimationPlayer cannot run both at once.
@onready var _energy_pulse_anim: AnimationPlayer = %EnergyPulseAnim
@onready var _energy_warn_anim: AnimationPlayer = %EnergyWarnAnim
@onready var _gold_label: Label = %GoldLabel
@onready var _kills_label: Label = %KillsLabel
## The Wave Clear beat: a label the animation fades in and out. Doc v0.4 §31.
@onready var _wave_clear_label: Label = %WaveClearLabel
@onready var _wave_clear_anim: AnimationPlayer = %WaveClearAnim
## One static row per equipped word slot; the script only shows, hides and fills
## them, it never creates nodes. Doc v0.4 section 46.
@onready var _word_rows: Array[Label] = [
	%WordRow0, %WordRow1, %WordRow2, %WordRow3, %WordRow4,
	%WordRow5, %WordRow6, %WordRow7, %WordRow8, %WordRow9,
]
@onready var _word_empty_label: Label = %WordEmptyLabel


func _ready() -> void:
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	SignalBus.core_hp_changed.connect(_on_core_hp_changed)
	SignalBus.energy_changed.connect(_on_energy_changed)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.monster_killed.connect(_on_monster_killed)
	SignalBus.word_completed.connect(_on_word_completed)

	%CodexButton.pressed.connect(codex_pressed.emit)
	%SettingsButton.pressed.connect(settings_pressed.emit)
	%PauseButton.pressed.connect(pause_pressed.emit)

	refresh()


## Tab does nothing while no control holds focus, which is how the game starts
## and how it comes back from a panel that hid its own focused button. Seeding
## the top bar here is what lets the player reach the buttons without a mouse.
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
	%CodexButton.grab_focus()


## Repaints every field from the two state singletons. Called on load and
## whenever a wave boundary is crossed.
func refresh() -> void:
	_on_wave_started(RunState.current_wave)
	_on_core_hp_changed(RunState.core_hp, RunState.core_max_hp)
	_on_energy_changed(RunState.current_energy, RunState.get_max_energy())
	_on_gold_changed(MetaState.gold)
	_update_kills()
	_refresh_equipped_words()


func _on_wave_started(wave: int) -> void:
	_wave_label.text = "WAVE %d" % wave
	_update_kills()
	_refresh_equipped_words()


func _on_wave_cleared(wave: int) -> void:
	_wave_clear_label.text = "WAVE %d CLEAR" % wave
	_wave_clear_anim.stop()
	_wave_clear_anim.play(&"wave_clear")


## The 문장핵 readout. The number is always spelled out, so the bar is a
## reinforcement rather than the only cue. Doc v0.4 section 6.1.
func _on_core_hp_changed(current: float, maximum: float) -> void:
	_core_label.text = "문장핵 %d / %d" % [int(ceilf(current)), int(ceilf(maximum))]
	_core_bar.max_value = maxf(1.0, maximum)
	_core_bar.value = current
	# Tint is a reinforcement of the number, never the only cue.
	var low := maximum > 0.0 and current / maximum <= CORE_LOW_FRACTION
	_core_label.modulate = Color(0.72, 0.27, 0.18) if low else Color.WHITE


func _on_energy_changed(current: int, maximum: int) -> void:
	_energy_label.text = "ENERGY %d / %d" % [current, maximum]
	_energy_bar.max_value = maxi(1, maximum)
	_energy_bar.value = current
	# Colour is a reinforcement, never the only cue: the number is always there.
	var low := current <= MetaState.balance.low_energy_warning and current > 0
	_energy_label.modulate = Color(0.72, 0.27, 0.18) if low or current <= 0 else Color.WHITE
	_set_low_energy_warning(low)
	# At 0 the text says what the rule is, so nobody reads the wave going on
	# as a bug. Doc v0.4 section 7.1.
	if current <= 0:
		_energy_warn_label.text = ENERGY_EMPTY_TEXT
		_energy_warn_label.modulate = Color.WHITE
		_energy_warn_label.visible = true
	else:
		_energy_warn_label.text = ENERGY_LOW_TEXT
	# Stopped first so a fast click streak restarts the punch every time
	# instead of resuming the one already in flight.
	_energy_pulse_anim.stop()
	_energy_pulse_anim.play(&"pulse")


## Runs the blinking warning while manual clicks are nearly out, and puts the
## bar back to its normal tint when they are not.
func _set_low_energy_warning(low: bool) -> void:
	_energy_warn_label.visible = low
	if low:
		if not _energy_warn_anim.is_playing():
			_energy_warn_anim.play(&"warn")
		return
	if _energy_warn_anim.is_playing():
		_energy_warn_anim.stop()
	_energy_bar.self_modulate = Color.WHITE


func _on_gold_changed(total: float) -> void:
	_gold_label.text = "%s G" % _format_gold(total)


func _on_monster_killed(_jamo: String, _gold: float, _position: Vector3) -> void:
	_update_kills()


func _on_word_completed(_word: WordData) -> void:
	_refresh_equipped_words()


func _update_kills() -> void:
	_kills_label.text = "처치 %d" % int(RunState.get_run_statistic("kills"))


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


## The words carried by the current run, with their run rank. A word in the
## codex but not equipped is deliberately absent: only equipped words do
## anything. Doc v0.4 section 38.
func _refresh_equipped_words() -> void:
	var equipped := RunState.equipped_words
	for i in _word_rows.size():
		var row := _word_rows[i]
		if i >= equipped.size():
			row.visible = false
			continue
		row.visible = true
		row.text = _describe_equipped(equipped[i])

	# An empty list still has to say so; a blank box reads as a bug.
	_word_empty_label.visible = equipped.is_empty()


func _describe_equipped(word_id: StringName) -> String:
	var word: WordData = MetaState.database.find_word(word_id)
	if word == null:
		return String(word_id)
	var rank := RunState.get_word_rank(word_id)
	return "%s  R%d" % [word.get_display_name(), maxi(1, rank)]
