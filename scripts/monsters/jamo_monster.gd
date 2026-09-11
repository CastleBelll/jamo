class_name JamoMonster
extends CharacterBody3D

## A living hangul letter. It walks toward the 문장핵 with its own gait and
## hurts the core when it gets there; the player clicks it before that.
## Doc v0.4 sections 6.1 and 15. The v0.3 walk personalities are untouched -
## only the destination changed from a random point to the core.
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
## Floor for the walkable half-extents, so an oversized arena_margin still
## leaves the monster somewhere to stand instead of pinning it to the centre.
const MIN_WALKABLE_HALF_EXTENT := 0.5

@export_group("Data")
## Stats and visuals for this jamo. Edit the .tres to rebalance.
@export var monster_data: JamoMonsterData
## Overrides monster_data.motion_profile when set, for quick experiments.
@export var motion_profile_override: MotionProfile

@export_group("Field")
## Half-extents of the paper sheet itself, in metres: x is half its width, y
## half its depth (world z). arena.tscn lays a 12 x 7.5 sheet flat on the desk
## with no rotation, so its world footprint is the rectangle
## abs(x) <= half_extents.x and abs(z) <= half_extents.y. This is the sheet, not
## the walkable area: each monster insets it by its own body footprint in
## get_walkable_half_extents(). SpawnManager overwrites this at spawn time.
@export var arena_half_extents: Vector2 = Vector2(6.0, 3.75)
## The 문장핵 this monster walks to. Left empty the monster wanders the arena
## as it did in v0.3, which the arena harnesses rely on. SpawnManager sets it
## at spawn time. Doc v0.4 section 6.1.
@export var objective: SentenceCore

@export_group("Legs")
## Forward/back swing of the character legs, in radians: Leg_L gets this and
## Leg_R the opposite, so a positive key is a left-foot-forward stride. Keyed
## by the walk animations in walk_library.tres; the legs themselves are found
## by name inside the GLB (art/monsters/characters/README.md), so the timeline
## never has to know the model's node path.
@export var leg_swing: float = 0.0:
	set(value):
		leg_swing = value
		_pose_legs()
## Both legs bent the same way, in radians, for the crouch of a landing.
@export var leg_tuck: float = 0.0:
	set(value):
		leg_tuck = value
		_pose_legs()

@onready var _visual_root: Node3D = $VisualRoot
@onready var _click_shape: CollisionShape3D = $ClickArea/CollisionShape3D
@onready var _animation: AnimationPlayer = $AnimationPlayer
@onready var _status: StatusEffectContainer = $StatusEffects
@onready var _hit_anchor: Marker3D = $HitFXAnchor
## Burn ember, placed in jamo_monster_base.tscn. Switched by _on_effects_changed.
@onready var _burn_ember: CPUParticles3D = $StatusEffectAnchor/BurnEmber

var max_hp: float = 1.0
var hp: float = 1.0

## How many times the burn on this monster has already been passed on.
## 불꽃 uses it to stop a spread from chaining across the whole field.
var burn_chain_depth: int = 0
## Whether this monster was still burning when it died. Read by SpawnManager
## after death, because _die() clears the status container.
var died_burning: bool = false

## Visual meshes of the glyph, cached so measuring the footprint never has to
## walk the node tree again.
var _body_meshes: Array[MeshInstance3D] = []
## Widest horizontal half-extents the glyph has reached, in metres, measured
## around the monster origin. Kept as a running maximum because the walk
## animations lean, turn and squash the letter, so the rest pose alone would
## under-measure the footprint the arena clamp has to respect.
var _body_extent: Vector2 = Vector2.ZERO

## Leg parts of the character model, null on a model without legs.
var _leg_left: Node3D
var _leg_right: Node3D

var _state: State = State.SPAWN
var _profile: MotionProfile
var _speed: float = 1.0
var _target: Vector3 = Vector3.ZERO
## Seconds left in the current SPAWN / IDLE / TURN. This timer, ticked from
## _physics_process, is the only thing that moves the monster out of those
## states. animation_finished is not trusted for it: AnimationPlayer never
## reports an animation that play() replaced, so a hit reaction landing during
## "turn" used to eat the signal and park the monster in TURN for good.
var _state_timer: float = 0.0
var _avoidance_timer: float = 0.0
var _separation: Vector3 = Vector3.ZERO
## Seconds left before the monster leaves on its own. 0 disables the timer.
var _lifetime_left: float = 0.0


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

	# Wave speed scaling multiplies the gait, it never replaces it: the six
	# walk personalities stay exactly as tuned. Doc v0.4 sections 5.2 and 15.
	var wave: WaveData = RunState.get_current_wave_data()
	var wave_speed: float = wave.speed_multiplier if wave != null else 1.0
	_speed = monster_data.base_speed * _profile.move_speed_multiplier \
		* monster_data.speed_multiplier * wave_speed
	_lifetime_left = monster_data.lifetime_seconds
	_visual_root.scale = Vector3.ONE * monster_data.visual_scale
	_bind_character_parts()
	_collect_body_meshes()
	_measure_body()
	_apply_click_radius(monster_data.click_radius)
	_roll_stats()

	_status.tick_damage.connect(_on_status_tick_damage)
	_status.effects_changed.connect(_on_effects_changed)
	_animation.animation_finished.connect(_on_animation_finished)
	_begin_spawn()


## HP and gold both scale with the current WaveData. Doc v0.4 sections 5.2, 25.
func _roll_stats() -> void:
	max_hp = MetaState.balance.monster_hp_for_wave(
		RunState.get_current_wave_data(), monster_data.hp_multiplier
	)
	hp = max_hp


## Finds the legs and the glyph body by name, the contract of
## art/monsters/characters/README.md, and gives the glyph its data material.
## Only surface 0 (the ink face) is overridden, so the paper edge, eyes and
## legs keep their own look. Doc v0.4 section 16: specials differ by material.
func _bind_character_parts() -> void:
	_leg_left = _visual_root.find_child("Leg_L", true, false) as Node3D
	_leg_right = _visual_root.find_child("Leg_R", true, false) as Node3D
	_pose_legs()
	if monster_data.glyph_material == null:
		return
	var glyph := _visual_root.find_child("Glyph", true, false) as MeshInstance3D
	if glyph == null:
		push_warning("JamoMonster %s has a glyph_material but no Glyph mesh." % monster_data.id)
		return
	glyph.set_surface_override_material(0, monster_data.glyph_material)


## Applies leg_swing / leg_tuck to the leg pivots. Each leg turns about its
## own hip (local X), so the feet lift instead of sinking into the paper.
func _pose_legs() -> void:
	if _leg_left != null:
		_leg_left.rotation.x = leg_tuck + leg_swing
	if _leg_right != null:
		_leg_right.rotation.x = leg_tuck - leg_swing


func _apply_click_radius(radius: float) -> void:
	var shape := _click_shape.shape
	if shape is SphereShape3D:
		# Duplicate so tuning one monster never resizes every other instance.
		var sphere: SphereShape3D = shape.duplicate()
		sphere.radius = radius
		_click_shape.shape = sphere


## The AnimationPlayer poses the glyph in the idle frame, after the physics
## clamp has already run, so a pose that just got wider would be drawn hanging
## over the paper for a frame. Re-clamping here closes that gap; the scene sets
## process_priority so this runs after the AnimationPlayer has posed the body.
func _process(_delta: float) -> void:
	if _state == State.DEAD or _body_meshes.is_empty():
		return
	_clamp_to_arena()


func _physics_process(delta: float) -> void:
	if _lifetime_left > 0.0:
		_lifetime_left -= delta
		if _lifetime_left <= 0.0:
			_expire()
			return
	match _state:
		State.SPAWN:
			_process_hold(delta, _begin_idle)
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.TURN:
			_process_hold(delta, _begin_walk)
		_:
			velocity = Vector3.ZERO
			move_and_slide()


## SPAWN and TURN stand still for the length of their animation and then move
## on, whatever the AnimationPlayer is showing by then. Every state the monster
## can be in therefore has a physics branch that leads somewhere.
func _process_hold(delta: float, next_state: Callable) -> void:
	velocity = Vector3.ZERO
	move_and_slide()
	_state_timer -= delta
	if _state_timer <= 0.0:
		next_state.call()


func _process_idle(delta: float) -> void:
	# Standing still still drifts apart, otherwise a crowd stays interpenetrated
	# until every monster happens to pick a new walk target.
	_update_separation(delta)
	velocity = _separation * _speed * AVOIDANCE_PUSH
	move_and_slide()
	_clamp_to_arena()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_begin_turn()


func _process_walk(delta: float) -> void:
	_update_separation(delta)
	# One distance check against a single cached node, never a search.
	if objective != null and _is_at_objective():
		_reach_objective()
		return
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() <= ARRIVAL_DISTANCE:
		_begin_idle()
		return
	var direction := (to_target.normalized() + _separation * AVOIDANCE_PUSH).normalized()
	velocity = direction * _speed
	move_and_slide()
	_clamp_to_arena()


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


func _begin_spawn() -> void:
	_state = State.SPAWN
	_state_timer = _animation_length(&"spawn")
	_animation.speed_scale = 1.0
	_animation.play(&"spawn")


func _begin_idle() -> void:
	_state = State.IDLE
	_state_timer = randf_range(_profile.idle_min, _profile.idle_max)
	_play_if_not_current(&"idle")


func _begin_turn() -> void:
	_state = State.TURN
	_state_timer = _animation_length(&"turn")
	_target = _pick_target()
	_animation.speed_scale = 1.0
	_animation.play(&"turn")


## How long a one-shot animation holds its state. A missing animation holds
## for nothing, so the state falls through on the next physics frame instead
## of waiting for a signal that will never come.
func _animation_length(anim_name: StringName) -> float:
	if not _animation.has_animation(anim_name):
		return 0.0
	return _animation.get_animation(anim_name).length


func _begin_walk() -> void:
	_state = State.WALK
	_avoidance_timer = 0.0
	_animation.play(_profile.walk_animation)
	_animation.speed_scale = _profile.step_frequency


## Where the next walk goes: the 문장핵, pulled onto this monster's own
## walkable rectangle so the clamp and the destination never disagree. With no
## objective the v0.3 wander is kept as is. Doc v0.4 section 15.
func _pick_target() -> Vector3:
	var extents := get_walkable_half_extents()
	if objective == null:
		return random_point_in_arena(extents, global_position.y)
	var goal := objective.global_position
	goal.y = global_position.y
	return clamp_point_to_arena(goal, extents)


func _is_at_objective() -> bool:
	var offset := objective.global_position - global_position
	offset.y = 0.0
	return offset.length() <= objective.reach_radius


## The monster got through: it hurts the core and leaves without paying gold.
## Doc v0.4 section 6.1.
func _reach_objective() -> void:
	if _state == State.DEAD:
		return
	objective.take_hit(monster_data.core_damage)
	_expire()


## Widest horizontal half-extents of the glyph seen so far, in metres.
func get_body_half_extents() -> Vector2:
	return _body_extent


## The arena rectangle this monster's centre may walk in: the sheet with its
## own body footprint and arena_margin taken off, so no part of the glyph hangs
## over the paper whatever its visual_scale is. The sheet and the body are both
## axis aligned, so each axis is inset by the body's own half-extent on that
## axis. Read by SpawnManager as well, so spawning and walking agree.
## Doc v0.3 section 27.
func get_walkable_half_extents() -> Vector2:
	var margin: float = monster_data.arena_margin if monster_data != null else 0.0
	return Vector2(
		maxf(MIN_WALKABLE_HALF_EXTENT, arena_half_extents.x - _body_extent.x - margin),
		maxf(MIN_WALKABLE_HALF_EXTENT, arena_half_extents.y - _body_extent.y - margin)
	)


func _collect_body_meshes() -> void:
	for node: Node in _visual_root.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(node as MeshInstance3D)


## Grows the cached footprint to whatever the glyph occupies right now. Cheap
## enough per frame: a letter is a handful of boxes and the list is cached.
func _measure_body() -> void:
	var origin := global_position
	for mesh: MeshInstance3D in _body_meshes:
		if not mesh.visible:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		_body_extent.x = maxf(_body_extent.x, maxf(
			absf(box.position.x - origin.x),
			absf(box.position.x + box.size.x - origin.x)
		))
		_body_extent.y = maxf(_body_extent.y, maxf(
			absf(box.position.z - origin.z),
			absf(box.position.z + box.size.z - origin.z)
		))


## Pulls the body back onto its walkable rectangle. Neighbour separation
## pushes outward and a crowd of 20 can otherwise shove a big glyph past the
## paper edge faster than it picks a new target. Doc v0.3 section 27.
func _clamp_to_arena() -> void:
	_measure_body()
	global_position = clamp_point_to_arena(global_position, get_walkable_half_extents())


## How far outside the rectangle a point is, as a fraction of the half-extents:
## <= 1 is inside. Shared with the harnesses so they judge the same edge.
static func arena_spill(point: Vector3, half_extents: Vector2) -> float:
	return maxf(absf(point.x) / half_extents.x, absf(point.z) / half_extents.y)


## Pulls a point back onto the rectangle abs(x) <= hx, abs(z) <= hz, leaving y
## alone. Shared by the walk clamp, the target pick and the spawner so all
## three agree on the edge.
static func clamp_point_to_arena(point: Vector3, half_extents: Vector2) -> Vector3:
	return Vector3(
		clampf(point.x, -half_extents.x, half_extents.x),
		point.y,
		clampf(point.z, -half_extents.y, half_extents.y)
	)


## Uniform random point inside the rectangle footprint of the paper sheet.
static func random_point_in_arena(half_extents: Vector2, y: float) -> Vector3:
	return Vector3(
		randf_range(-half_extents.x, half_extents.x),
		y,
		randf_range(-half_extents.y, half_extents.y)
	)


func _play_if_not_current(anim_name: StringName) -> void:
	if _animation.current_animation != anim_name:
		_animation.speed_scale = 1.0
		_animation.play(anim_name)


## Only the visuals hang off this signal. No state transition does: SPAWN and
## TURN run on _state_timer, so a "hit" that replaces their animation changes
## what is drawn, never where the state machine goes next.
func _on_animation_finished(anim_name: StringName) -> void:
	if _state == State.DEAD:
		if anim_name == &"death":
			queue_free()
		return
	if anim_name != &"hit":
		return
	# Put the current state's own look back after the click reaction.
	if _state == State.WALK:
		_begin_walk()
	else:
		_play_if_not_current(&"idle")


# --- Damage ----------------------------------------------------------------

func is_alive() -> bool:
	return _state != State.DEAD


## Where the state machine is, for the spawner's stall report and the tests.
func get_state() -> State:
	return _state


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


## The only consumer of StatusEffectContainer.effects_changed: it turns the
## status VFX on and off, so a burn is visible without polling every frame.
## Doc v0.3 section 24.
func _on_effects_changed() -> void:
	_burn_ember.emitting = _status.has(WordEffectData.EffectType.UNLOCK_BURN)


## Called from the method track of every walk animation, so a footstep sound
## lands on the beat the animator keyed rather than on a timer in code.
## Silent while the motion profile has no step_sfx_path or the file is missing.
## Doc v0.3 sections 7.1 and 25.
func play_step_sfx() -> void:
	if _profile == null or _state != State.WALK:
		return
	AudioManager.play_sfx_path(_profile.step_sfx_path)


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
	died_burning = _status.has(WordEffectData.EffectType.UNLOCK_BURN)
	_leave_field()
	RunState.register_kill(
		monster_data.jamo, _calculate_gold_reward(), global_position
	)
	died.emit(self)


## The monster leaves without being killed - its lifetime_seconds ran out or it
## reached the 문장핵 - so it pays no gold and its burn does not spread.
## Doc v0.3 section 9.3, doc v0.4 section 6.1.
func _expire() -> void:
	if _state == State.DEAD:
		return
	died_burning = false
	_leave_field()
	died.emit(self)


## Shared teardown: stop moving, stop taking clicks, stop blocking the others,
## but stay visible until the death animation finishes.
func _leave_field() -> void:
	_state = State.DEAD
	_status.clear()
	set_physics_process(false)
	$ClickArea.monitorable = false
	$ClickArea.input_ray_pickable = false
	_click_shape.set_deferred(&"disabled", true)
	$MoveCollision.set_deferred(&"disabled", true)
	_animation.speed_scale = 1.0
	_animation.play(&"death")


## FinalGold = BaseGold * MonsterGoldMultiplier * GoldMultiplier, where the
## multiplier already folds the permanent track and the run words together.
## Doc v0.4 section 8.
func _calculate_gold_reward() -> float:
	return MetaState.balance.monster_gold_for_wave(
		RunState.get_current_wave_data(), monster_data.gold_multiplier
	) * RunState.get_gold_multiplier()
