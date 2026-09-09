extends Control

## Word completion moment. Doc v0.3 section 14.2 calls this out as one of the
## game's main reward beats, so it runs a sequence rather than just popping a
## panel: the jamo gather in the centre, the syllable assembles, the word is
## revealed with a punch, the camera zooms and the sting plays.
##
## Every timing below is exported and the reveal itself lives in RevealAnim, so
## the feel is tuned in the Inspector and the AnimationPlayer timeline rather
## than in this file. Doc v0.3 sections 7.1 and 37.

signal closed()

@export_group("Gather")
## Seconds one jamo takes to travel from the ring to the centre.
@export_range(0.05, 3.0, 0.05) var gather_seconds: float = 0.5
## Delay added per jamo, so they arrive one after another instead of together.
@export_range(0.0, 0.5, 0.01) var gather_stagger: float = 0.07
## Radius of the ring the jamo start on, in pixels.
@export_range(40.0, 600.0, 5.0) var gather_radius: float = 240.0
## Where the ring starts, in degrees. Rotating it changes which jamo comes from
## where without touching the scene.
@export_range(-180.0, 180.0, 1.0) var gather_start_angle: float = -90.0

@onready var _word_label: Label = %CompletedWord
@onready var _jamo_label: Label = %CompletedJamo
@onready var _effect_label: Label = %CompletedEffect
@onready var _fly_layer: Control = %FlyLayer
@onready var _panel: Control = $Center/Panel
@onready var _reveal_anim: AnimationPlayer = %RevealAnim
## Fixed set of travelling jamo labels, placed in the scene. No node is created
## at runtime; a word longer than this list simply shows the first few.
## Doc v0.3 section 19.1.
@onready var _fly_labels: Array[Label] = [
	%FlyJamo0, %FlyJamo1, %FlyJamo2, %FlyJamo3,
	%FlyJamo4, %FlyJamo5, %FlyJamo6, %FlyJamo7,
]

var _queue: Array[WordData] = []
var _gather_tween: Tween


func _ready() -> void:
	hide()
	_fly_layer.visible = false
	%WordCompleteContinue.pressed.connect(_on_continue_pressed)


## Shows each completed word in turn, then emits closed().
func open(words: Array[WordData]) -> void:
	_queue = words.duplicate()
	_show_next()


## The gather is a reward, not a cutscene: on repeat play any click or accept
## jumps straight to the reveal. Doc v0.3 section 14.2.
## _input rather than _unhandled_input on purpose: this panel covers the screen
## and its own Control would otherwise swallow the click before it got here.
func _input(event: InputEvent) -> void:
	if not visible or _gather_tween == null or not _gather_tween.is_running():
		return
	if not event.is_action_pressed(&"click") and not event.is_action_pressed(&"ui_accept"):
		return
	# Running the tween to its end finishes it exactly as if it had played out,
	# so the reveal still happens through the same path.
	_gather_tween.custom_step(gather_seconds + gather_stagger * _fly_labels.size())
	get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_stop_gather()
		hide()
		closed.emit()
		return
	_play_sequence(_queue.pop_front())


## Step 1 and 2 of doc v0.3 section 14.2: the jamo move to the centre and merge.
func _play_sequence(word: WordData) -> void:
	_stop_gather()
	show()
	_panel.visible = false
	var used := _place_jamo(word)
	if used == 0:
		_reveal(word)
		return
	_fly_layer.visible = true

	var centre := _fly_layer.size * 0.5
	_gather_tween = create_tween().set_parallel(true)
	for i in used:
		var label: Label = _fly_labels[i]
		var target := centre - label.size * 0.5
		_gather_tween.tween_property(label, ^"position", target, gather_seconds) \
			.set_delay(gather_stagger * i).set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_BACK)
		_gather_tween.tween_property(label, ^"modulate:a", 0.0, gather_seconds * 0.4) \
			.set_delay(gather_stagger * i + gather_seconds * 0.6)
	_gather_tween.chain().tween_callback(_reveal.bind(word))


## Puts one label per required jamo on a ring around the centre and returns how
## many were used. Extra labels are hidden.
func _place_jamo(word: WordData) -> int:
	var centre := _fly_layer.size * 0.5
	var count: int = mini(word.required_jamo.size(), _fly_labels.size())
	for i in _fly_labels.size():
		var label: Label = _fly_labels[i]
		label.visible = i < count
		if i >= count:
			continue
		label.text = word.required_jamo[i]
		label.modulate.a = 1.0
		var angle: float = deg_to_rad(gather_start_angle) + TAU * float(i) / float(count)
		label.position = centre + Vector2.RIGHT.rotated(angle) * gather_radius \
			- label.size * 0.5
	return count


## Steps 3 to 5: the word appears with a punch, the camera zooms and the sting
## plays. The zoom is requested through SignalBus so this panel never needs a
## path into the 3D scene.
func _reveal(word: WordData) -> void:
	_fly_layer.visible = false
	_word_label.text = word.word
	_jamo_label.text = " + ".join(word.required_jamo)
	_effect_label.text = word.description
	_panel.visible = true
	_reveal_anim.play(&"reveal")
	AudioManager.play_sfx(&"word_complete")
	SignalBus.word_revealed.emit()
	%WordCompleteContinue.grab_focus()


func _stop_gather() -> void:
	if _gather_tween != null:
		_gather_tween.kill()
		_gather_tween = null
	_fly_layer.visible = false
