extends Node3D

## Owns the 2.5D field: arena, camera, spawner and hit feedback.
## Day flow lives in main.gd; this node only reacts to combat signals.

@export_group("Feedback Scenes")
@export var damage_number_scene: PackedScene

@export_group("Wiring")
## Parent for short-lived VFX so they never clutter the monster list.
@export var fx_root: Node3D
## Pre-placed HitFX instances, reused round-robin. Particle systems are never
## instantiated per click: at 20 monsters with burn ticks running, that is the
## allocation the frame budget cannot afford. Doc v0.3 section 36.
@export var hit_fx_pool: Node3D
## Same for the death burst.
@export var death_fx_pool: Node3D

@onready var spawn_manager: SpawnManager = $SpawnManager

var _hit_effects: Array[CPUParticles3D] = []
var _death_effects: Array[CPUParticles3D] = []
var _next_hit_effect: int = 0
var _next_death_effect: int = 0


func _ready() -> void:
	if fx_root == null:
		fx_root = self
	_hit_effects = _collect_particles(hit_fx_pool)
	_death_effects = _collect_particles(death_fx_pool)
	SignalBus.damage_dealt.connect(_on_damage_dealt)
	SignalBus.monster_killed.connect(_on_monster_killed)


static func _collect_particles(pool: Node3D) -> Array[CPUParticles3D]:
	var found: Array[CPUParticles3D] = []
	if pool == null:
		return found
	for child: Node in pool.get_children():
		var particles := child as CPUParticles3D
		if particles != null:
			found.append(particles)
	return found


func _on_damage_dealt(world_position: Vector3, amount: float, is_critical: bool) -> void:
	if damage_number_scene != null:
		var number := damage_number_scene.instantiate()
		number.amount = amount
		number.is_critical = is_critical
		fx_root.add_child(number)
		number.global_position = world_position
	_next_hit_effect = _emit_pooled(_hit_effects, _next_hit_effect, world_position)


func _on_monster_killed(_jamo: String, _gold: float, world_position: Vector3) -> void:
	_next_death_effect = _emit_pooled(
		_death_effects, _next_death_effect, world_position + Vector3.UP * 0.25
	)
	AudioManager.play_sfx(&"kill")


## Moves the next pooled emitter to `world_position` and restarts it. Returns
## the index to use next. When every emitter is busy the oldest one is taken
## over, which is what a burst of clicks should look like anyway.
static func _emit_pooled(
	pool: Array[CPUParticles3D], index: int, world_position: Vector3
) -> int:
	if pool.is_empty():
		return index
	var particles: CPUParticles3D = pool[index]
	particles.global_position = world_position
	particles.restart()
	return (index + 1) % pool.size()
