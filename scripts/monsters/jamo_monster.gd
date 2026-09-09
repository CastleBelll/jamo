class_name JamoMonster
extends CharacterBody3D

## A living hangul letter. It never attacks the player; it only wanders so that
## picking a click target has texture. Doc v0.3 sections 4 and 8.2.
##
## The script owns state and speed. The bounce, squash and tilt of each walk
## live in the AnimationPlayer, so the feel is tuned in the editor timeline.

signal died(monster: JamoMonster)

enum State { SPAWN, IDLE, WALK, TURN, DEAD }

## Distance at which a walk target counts as reached.
const ARRIVAL_DISTANCE := 0.18
## How often neighbours are re-scanned for separation, in seconds.
const AVOIDANCE_SCAN_INTERVAL := 0.25
## Strength of the separation nudge relative to move speed.
const AVOIDANCE_PUSH := 0.6

@export_group("Data")
## Stats and visuals for this jamo. Edit the .tres to rebalance.
@export var monster_data: JamoMonsterData
## Overrides monster_data.motion_profile when set, for quick experiments.
@export var motion_profile_override: MotionProfile

@export_group("Field")
## Half-diagonals of the walkable area, in metres. The arena is a square slab
## turned 45 degrees, so its footprint in world space is the diamond
## abs(x) / half_extents.x + abs(z) / half_extents.y <= 1.
## SpawnManager overwrites this at spawn time.
@export var arena_half_extents: Vector2 = Vector2(3.4, 3.4)

@onready var _visual_root: Node3D = $VisualRoot
@onready var _click_shape: CollisionShape3D = $ClickArea/CollisionShape3D
@onready var _animation: AnimationPlayer = $AnimationPlayer
@onready var _status: StatusEffectContainer = $StatusEffects
@onready var _hit_anchor: Marker3D = $HitFXAnchor

var max_hp: float = 1.0
var hp: float = 1.0

## How many times the burn on this monster has already been passed on.
## 불꽃 uses it to stop a spread from chaining across the whole field.
var burn_chain_depth: int = 0
## Whether this monster was still burning when it died. Read by SpawnManager
## after death, because _die() clears the status container.
var died_burning: bool = false

var _state: State = State.SPAWN
var _profile: MotionProfile
var _speed: float = 1.0
var _target: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0
var _avoidance_timer: float = 0.0
var _separation: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"jamo_monster")
	if monster_data == null:
		push_error("JamoMonster at %s has no monster_data assigned." % get_path())
		set_physics_process(false)
		return

	_profile = motion_profile_override if motion_profile_override != null \
		else monster_data.motion_profile
	if _profile == null:
		push_error("JamoMonster %s has no MotionProfile." % monster_data.id)
		set_physics_process(false)
		return

	_speed = monster_data.base_speed * _profile.move_speed_multiplier
	_visual_root.scale = Vector3.ONE * monster_data.visual_scale
	_apply_click_radius(monster_data.click_radius)
	_roll_stats()

	_status.tick_damage.connect(_on_status_tick_damage)
	_animation.animation_finished.connect(_on_animation_finished)
	_animation.play(&"spawn")


## HP and gold both scale with the current day. Doc v0.3 section 8.1.
func _roll_stats() -> void:
	max_hp = GameState.balance.monster_hp_for_day(GameState.day) \
		* monster_data.hp_multiplier
	hp = max_hp


func _apply_click_radius(radius: float) -> void:
	var shape := _click_shape.shape
	if shape is SphereShape3D:
		# Duplicate so tuning one monster never resizes every other instance.
		var sphere: SphereShape3D = shape.duplicate()
		sphere.radius = radius
		_click_shape.shape = sphere


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		_:
			velocity = Vector3.ZERO
			move_and_slide()


func _process_idle(delta: float) -> void:
	# Standing still still drifts apart, otherwise a crowd stays interpenetrated
	# until every monster happens to pick a new walk target.
	_update_separation(delta)
	velocity = _separation * _speed * AVOIDANCE_PUSH
	move_and_slide()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_begin_turn()


func _process_walk(delta: float) -> void:
	_update_separation(delta)
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() <= ARRIVAL_DISTANCE:
		_begin_idle()
		return
	var direction := (to_target.normalized() + _separation * AVOIDANCE_PUSH).normalized()
	velocity = direction * _speed
	move_and_slide()


## Neighbour separation, rescanned on a timer rather than every frame.
## With a cap of 20 monsters a plain group scan is cheap enough; doc v0.3
## section 36 only forbids doing it per frame.
func _update_separation(delta: float) -> void:
	_avoidance_timer -= delta
	if _avoidance_timer > 0.0:
		return
	_avoidance_timer = AVOIDANCE_SCAN_INTERVAL
	_separation = Vector3.ZERO
	var radius := _profile.avoidance_radius
	if radius <= 0.0:
		return
	for other: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		if other == self or not (other is Node3D):
			continue
		var offset := global_position - (other as Node3D).global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001 and distance < radius:
			_separation += offset / distance * (1.0 - distance / radius)


func _begin_idle() -> void:
	_state = State.IDLE
	_state_timer = randf_range(_profile.idle_min, _profile.idle_max)
	_play_if_not_current(&"idle")


func _begin_turn() -> void:
	_state = State.TURN
	_target = _pick_target()
	_animation.play(&"turn")


func _begin_walk() -> void:
	_state = State.WALK
	_avoidance_timer = 0.0
	_animation.play(_profile.walk_animation)
	_animation.speed_scale = _profile.step_frequency


func _pick_target() -> Vector3:
	return random_point_in_arena(arena_half_extents, global_position.y)


## Uniform random point inside the diamond footprint of the rotated arena slab.
## Mapping the unit square through (u+v, u-v) turns it into the diamond, which
## keeps the corners reachable instead of clipping to an inscribed box.
static func random_point_in_arena(half_extents: Vector2, y: float) -> Vector3:
	var u := randf_range(-1.0, 1.0)
	var v := randf_range(-1.0, 1.0)
	return Vector3((u + v) * 0.5 * half_extents.x, y, (u - v) * 0.5 * half_extents.y)


func _play_if_not_current(anim_name: StringName) -> void:
	if _animation.current_animation != anim_name:
		_animation.speed_scale = 1.0
		_animation.play(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if _state == State.DEAD:
		if anim_name == &"death":
			queue_free()
		return
	match anim_name:
		&"spawn":
			_begin_idle()
		&"turn":
			_begin_walk()
		&"hit":
			# Resume whatever the monster was doing before it was clicked.
			if _state == State.WALK:
				_begin_walk()
			else:
				_play_if_not_current(&"idle")


# --- Damage ----------------------------------------------------------------

func is_alive() -> bool:
	return _state != State.DEAD


## World position where hit feedback should appear.
func get_hit_position() -> Vector3:
	return _hit_anchor.global_position


## Applies click damage and the click reaction. Returns false when the monster
## was already dead, so the caller can ignore a stale hit.
func take_click_damage(amount: float, is_critical: bool = false) -> bool:
	if not is_alive():
		return false
	_animation.speed_scale = 1.0
	_animation.play(&"hit")
	_apply_damage(amount, is_critical)
	return true


## Applies damage without the click reaction, used by status effect ticks.
func take_status_damage(amount: float) -> void:
	if not is_alive():
		return
	_apply_damage(amount)


func _apply_damage(amount: float, is_critical: bool = false) -> void:
	hp -= amount
	SignalBus.damage_dealt.emit(get_hit_position(), amount, is_critical)
	if hp <= 0.0:
		_die()


func _on_status_tick_damage(amount: float) -> void:
	take_status_damage(amount)


## Applies a status effect, ignoring null so callers can pass an effect that is
## still locked behind an unfinished word. `chain_depth` records how many times
## a spread produced this application; a direct click leaves it at 0, which
## makes the monster able to spread its burn again.
func apply_status_effect(effect: WordEffectData, chain_depth: int = 0) -> void:
	if not is_alive():
		return
	if effect != null and effect.effect_type == WordEffectData.EffectType.UNLOCK_BURN:
		burn_chain_depth = chain_depth
	_status.apply(effect)


func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	died_burning = _status.has(WordEffectData.EffectType.UNLOCK_BURN)
	_status.clear()
	set_physics_process(false)
	# Stop responding to clicks and stop blocking other monsters, but stay
	# visible until the death animation finishes.
	$ClickArea.monitorable = false
	$ClickArea.input_ray_pickable = false
	_click_shape.set_deferred(&"disabled", true)
	$MoveCollision.set_deferred(&"disabled", true)

	GameState.register_kill(
		monster_data.jamo, _calculate_gold_reward(), global_position
	)
	died.emit(self)

	_animation.speed_scale = 1.0
	_animation.play(&"death")


## FinalGold = BaseGold * MonsterGoldMultiplier * PermanentGoldMultiplier.
## Doc v0.3 section 8.1 and growth_balance v0.2 section 4.
func _calculate_gold_reward() -> float:
	return GameState.balance.monster_gold_for_day(GameState.day) \
		* monster_data.gold_multiplier \
		* GameState.get_gold_multiplier()
