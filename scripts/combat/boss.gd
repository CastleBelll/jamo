class_name Boss
extends JamoMonster
## Boss body (G8, B9): fixed position, capsule click area, phase 2 at half HP, and the
## pattern schedule (예고 -> 대응 -> 결과). The director spawns the PatternTarget and
## resolves success/failure; this node only reports when a pattern starts.

const CAPSULE_HALF_LENGTH := 130.0   # 360x100 glyph area: segment +-130, radius 50
const CAPSULE_RADIUS := 50.0

var data: BossData
var is_boss: bool = true
var phase2: bool = false
var next_pattern_at: float = 0.0
var patterns_started: int = 0
## Boss pattern rotation for W15 (index into marker_positions); other bosses use index 0.
var marker_index: int = 0

@onready var hp_bar: ProgressBar = $HpBar
@onready var name_label: Label = $NameLabel


func setup_boss(id: int, boss_data: BossData) -> void:
	data = boss_data
	entity_id = id
	jamo = ""
	hp_max = boss_data.hp
	hp = boss_data.hp
	lane = 1   # 논리 통로는 중앙 (G7)
	sub_lane = 0
	path_length = INF
	position = boss_data.boss_position
	next_pattern_at = boss_data.pattern_first_at
	if is_node_ready():
		_refresh_visual()


func _ready() -> void:
	$FocusRing.visible = focused
	_refresh_visual()
	hp_changed.connect(func(current, maximum): hp_bar.max_value = maximum; hp_bar.value = current)


func _refresh_visual() -> void:
	if data == null:
		return
	glyph.text = data.name
	name_label.text = data.name
	hp_bar.max_value = hp_max
	hp_bar.value = hp


## Bosses never walk (G3/G8).
func advance(_delta: float, _max_progress: float) -> bool:
	return false


func remaining_path() -> float:
	return INF


func eta() -> float:
	return INF


func is_hit_by(world_pos: Vector2, _radius: float) -> bool:
	if not alive:
		return false
	var local := world_pos - global_position
	var x := clampf(local.x, -CAPSULE_HALF_LENGTH, CAPSULE_HALF_LENGTH)
	return Vector2(x, 0).distance_to(local) <= CAPSULE_RADIUS


func take_damage(amount: float) -> float:
	var dealt := super.take_damage(amount)
	# Phase 2 applies from the next scheduled pattern only (B9).
	if not phase2 and hp <= hp_max * data.phase2_hp_ratio:
		phase2 = true
	return dealt


func warn_time() -> float:
	return data.warn_time_p2 if phase2 else data.warn_time


func respond_count() -> int:
	return data.respond_count_p2 if phase2 else data.respond_count


func period() -> float:
	return data.pattern_period_p2 if phase2 else data.pattern_period


## Returns a pattern spec when one starts at `clock`, else an empty Dictionary. The next
## start is scheduled from this start using the phase the boss is in right now.
func poll_pattern(clock: float) -> Dictionary:
	if not alive or clock < next_pattern_at:
		return {}
	var marker: Vector2 = data.marker_positions[marker_index % data.marker_positions.size()]
	var spec := {"marker": marker, "required": respond_count(), "duration": warn_time(),
		"fail_damage": data.fail_damage, "seal": data.seal_duration > 0.0, "index": patterns_started}
	patterns_started += 1
	if data.marker_positions.size() > 1:
		marker_index = (marker_index + 1) % data.marker_positions.size()
	next_pattern_at += period()
	return spec
