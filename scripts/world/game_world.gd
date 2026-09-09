extends Node3D

## Owns the 2.5D field: arena, camera, spawner and hit feedback.
## Day flow lives in main.gd; this node only reacts to combat signals.

@export_group("Feedback Scenes")
@export var damage_number_scene: PackedScene
@export var hit_fx_scene: PackedScene
@export var death_fx_scene: PackedScene

@export_group("Wiring")
## Parent for short-lived VFX so they never clutter the monster list.
@export var fx_root: Node3D

@onready var spawn_manager: SpawnManager = $SpawnManager


func _ready() -> void:
	if fx_root == null:
		fx_root = self
	SignalBus.damage_dealt.connect(_on_damage_dealt)
	SignalBus.monster_killed.connect(_on_monster_killed)


func _on_damage_dealt(world_position: Vector3, amount: float) -> void:
	if damage_number_scene != null:
		var number := damage_number_scene.instantiate()
		number.amount = amount
		fx_root.add_child(number)
		number.global_position = world_position
	_spawn_fx(hit_fx_scene, world_position)


func _on_monster_killed(_jamo: String, _gold: float, world_position: Vector3) -> void:
	_spawn_fx(death_fx_scene, world_position + Vector3.UP * 0.25)


func _spawn_fx(scene: PackedScene, world_position: Vector3) -> void:
	if scene == null:
		return
	var fx := scene.instantiate() as Node3D
	fx_root.add_child(fx)
	fx.global_position = world_position
