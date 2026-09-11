class_name JamoMonster
extends Node2D
## One corrupted jamo walking a Path2D sub lane (G3/G11). Drawing, clicking and moving are
## separate nodes: VisualPivot animates, ClickArea is the fixed 76px circle, the root follows
## the path. The director owns purify/reach bookkeeping; this node only reports.

enum Variant { NORMAL, LIGHT, HEAVY, GUARD }

signal hp_changed(current: float, maximum: float)

var entity_id: int = 0
var jamo: String = ""
var variant: Variant = Variant.NORMAL
var hp: float = 1.0
var hp_max: float = 1.0
var path: Path2D
var lane: int = 0
var sub_lane: int = 0
## Distance travelled along the path in px.
var progress: float = 0.0
var path_length: float = 1.0
## Base px/s before slow/speed multipliers (B2 travel time).
var base_speed: float = 0.0
var speed_mult: float = 1.0
## Alive == still a valid target. Purified or reached enemies flip this once, so bookkeeping
## can never run twice for the same entity (G7).
var alive: bool = true
var focused: bool = false:
	set(value):
		focused = value
		if is_node_ready():
			$FocusRing.visible = value

@onready var visual_pivot: Node2D = $VisualPivot
@onready var glyph: Label = $VisualPivot/Glyph
@onready var anim: AnimationPlayer = $AnimationPlayer


func setup(id: int, jamo_char: String, max_hp: float, on_path: Path2D, travel_time: float, lane_index: int, sub_index: int) -> void:
	entity_id = id
	jamo = jamo_char
	hp_max = max_hp
	hp = max_hp
	path = on_path
	lane = lane_index
	sub_lane = sub_index
	path_length = maxf(on_path.curve.get_baked_length(), 1.0)
	base_speed = path_length / maxf(travel_time, 0.01)
	progress = 0.0
	position = on_path.to_global(on_path.curve.sample_baked(0.0))
	if is_node_ready():
		glyph.text = jamo


func _ready() -> void:
	glyph.text = jamo
	$FocusRing.visible = focused


func speed() -> float:
	return base_speed * speed_mult


func remaining_path() -> float:
	return maxf(path_length - progress, 0.0)


## Seconds until the enemy reaches the sentence at its current speed (도달 예상시간).
func eta() -> float:
	return remaining_path() / maxf(speed(), 0.001)


## Advance along the path, never past max_progress (the follower spacing limit) or the end.
## Returns true when the end was reached this call.
func advance(delta: float, max_progress: float) -> bool:
	if not alive:
		return false
	# Never move backwards when the leader is closer than the spacing limit.
	progress = maxf(progress, minf(progress + speed() * delta, minf(max_progress, path_length)))
	position = path.to_global(path.curve.sample_baked(progress))
	return progress >= path_length


## Applies raw damage. Returns the amount actually removed from HP. Does not decide death;
## the director resolves purify in its own tick step so rewards happen exactly once.
func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, hp)
	hp -= dealt
	hp_changed.emit(hp, hp_max)
	if anim.has_animation("hit"):
		anim.stop()
		anim.play("hit")
	return dealt


func is_hit_by(world_pos: Vector2, radius: float) -> bool:
	return alive and global_position.distance_to(world_pos) <= radius


func play_purify() -> void:
	if anim.has_animation("purify"):
		anim.play("purify")
