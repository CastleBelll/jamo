class_name PatternTarget
extends Node2D
## 대응물 (G8): a 90px target that counts manual inputs only. Attacks, crits and auto hits
## never change the count. Expires after `duration`; the director resolves the outcome.

signal completed(target: PatternTarget)
signal expired(target: PatternTarget)

const CLICK_RADIUS := 45.0

var required: int = 3
var hits: int = 0
var remaining: float = 0.0
var duration: float = 0.0
var fail_damage: float = 0.0
var seal: bool = false
var seal_duration: float = 0.0
var ring: bool = false
## 침묵: the word this 봉인선 threatens (chosen by the director at pattern start).
var seal_word: StringName = &""
var seal_word_name: String = ""
var lane_x: float = -1.0
var done: bool = false
var focused: bool = false:
	set(value):
		focused = value
		if is_node_ready():
			$FocusRing.visible = value

@onready var count_label: Label = $CountLabel
@onready var time_label: Label = $TimeLabel


func setup(spec: Dictionary) -> void:
	required = spec["required"]
	duration = spec["duration"]
	remaining = duration
	fail_damage = spec["fail_damage"]
	seal = spec.get("seal", false)
	seal_duration = spec.get("seal_duration", 0.0)
	ring = spec.get("ring", false)
	seal_word = spec.get("seal_word", &"")
	position = spec["marker"]
	lane_x = spec.get("lane_x", -1.0)
	if is_node_ready():
		_refresh()
		_draw_lane_preview()
	if is_node_ready():
		_refresh()


func _ready() -> void:
	$FocusRing.visible = focused
	_refresh()
	_draw_lane_preview()


## 질주 ㅇ (G8/B9): a non-colliding preview line from the marker down its lane.
func _draw_lane_preview() -> void:
	var line := get_node_or_null("LanePreview") as Line2D
	if line == null:
		return
	line.visible = lane_x >= 0.0
	if lane_x >= 0.0:
		line.points = PackedVector2Array([Vector2(0, 60), Vector2(0, 850 - position.y)])


func is_hit_by(world_pos: Vector2) -> bool:
	return not done and global_position.distance_to(world_pos) <= CLICK_RADIUS


## One manual input. Returns true when the pattern is now defused.
func register_input() -> bool:
	if done:
		return false
	hits += 1
	_refresh()
	if hits >= required:
		done = true
		completed.emit(self)
		return true
	return false


func tick(delta: float) -> void:
	if done:
		return
	remaining -= delta
	_refresh()
	if remaining <= 0.0:
		done = true
		expired.emit(self)


func _refresh() -> void:
	count_label.text = "%d / %d" % [hits, required]
	if seal_word != &"":
		count_label.text += "  봉인선 → %s" % seal_word_name
	time_label.text = "%.1f" % maxf(remaining, 0.0)
