class_name Boss
extends JamoMonster
## Boss body (G8, B9): fixed position, capsule click area, phase 2 at half HP, and the
## pattern schedule (예고 -> 대응 -> 결과). The director spawns the PatternTarget and
## resolves success/failure; this node only reports when a pattern starts.

const BOSS_ART_HEIGHT := 205.0
const CAPSULE_HALF_LENGTH := 130.0   # 360x100 glyph area: segment +-130, radius 50
const CAPSULE_RADIUS := 50.0

var data: BossData
var is_boss: bool = true
var phase2: bool = false
var next_pattern_at: float = 0.0
var patterns_started: int = 0
## Boss pattern rotation for W15 (index into marker_positions); other bosses use index 0.
var marker_index: int = 0
## 탐욕 (B9): shield gained per designated minion purify, cleared by a broken ring.
var shield: float = 0.0
var shield_lockout_until: float = -1.0

@onready var hp_bar: ProgressBar = $HpBar
@onready var name_label: Label = $NameLabel
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var shield_label: Label = $ShieldLabel


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
	hp_changed.connect(func(current, maximum): hp_bar.max_value = maximum; hp_bar.value = current; _refresh_shield())


func _refresh_visual() -> void:
	if data == null:
		return
	glyph.text = data.name
	name_label.text = data.name
	var sprite := $VisualPivot/Sprite2D as Sprite2D
	sprite.texture = AssetLib.boss_glyph(data.id)
	glyph.visible = sprite.texture == null
	if sprite.texture != null:
		# 512px porcelain art shown at ~205px so it stays in the B11 zone above the lanes;
		# the click capsule (360x100) is unchanged and sits on the body's centre.
		var s := BOSS_ART_HEIGHT / float(sprite.texture.get_height())
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(0, -20)
	hp_bar.max_value = hp_max
	hp_bar.value = hp
	_refresh_shield()


## 보호막 readout (G8): amount and, during the ring lockout, the remaining lock time.
func _refresh_shield(clock: float = -1.0) -> void:
	var has_shield := data != null and data.shield_per_minion > 0.0
	shield_bar.visible = has_shield
	shield_label.visible = has_shield
	if not has_shield:
		return
	shield_bar.max_value = data.shield_cap
	shield_bar.value = shield
	var text := "보호막 %.0f / %.0f" % [shield, data.shield_cap]
	if clock >= 0.0 and clock < shield_lockout_until:
		text += "  (고리 끊김 %.1f초)" % (shield_lockout_until - clock)
	shield_label.text = text


## Called by the director each tick so the lockout countdown stays current.
func update_readout(clock: float) -> void:
	if data != null and data.shield_per_minion > 0.0:
		_refresh_shield(clock)


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


## Shield absorbs before HP (B9); the boss stays attackable while shielded. Absorbed damage
## is still damage dealt (no hidden resistance), so hits keep procing and show real numbers.
func take_damage(amount: float) -> float:
	var absorbed := 0.0
	if shield > 0.0 and amount > 0.0 and alive:
		absorbed = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		hp_changed.emit(hp, hp_max)
		if amount <= 0.0:
			if anim.has_animation("hit"):
				anim.stop()
				anim.play("hit")
			return absorbed
	var dealt := absorbed + super.take_damage(amount)
	# Phase 2 applies from the next scheduled pattern only (B9).
	if not phase2 and hp <= hp_max * data.phase2_hp_ratio:
		phase2 = true
	return dealt


func add_shield(amount: float, clock: float) -> void:
	if data.shield_per_minion <= 0.0 or clock < shield_lockout_until:
		return
	shield = minf(shield + amount, data.shield_cap)
	hp_changed.emit(hp, hp_max)


## Ring broken (pattern defused): shield gone and no gain for the lockout window.
func break_ring(clock: float) -> void:
	shield = 0.0
	shield_lockout_until = clock + data.shield_lockout
	hp_changed.emit(hp, hp_max)


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
		"fail_damage": data.fail_damage, "seal": data.seal_duration > 0.0, "seal_duration": data.seal_duration,
		"ring": data.shield_per_minion > 0.0, "index": patterns_started,
		"lane_x": marker.x if data.marker_positions.size() > 1 else -1.0}
	patterns_started += 1
	if data.marker_positions.size() > 1:
		marker_index = (marker_index + 1) % data.marker_positions.size()
	next_pattern_at += period()
	return spec
