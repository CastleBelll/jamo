extends Node3D

## Fixed 3/4 camera. The player never rotates it. Doc v0.3 section 26.
## The only motion is a short shake on damage, applied to ShakePivot so the
## Camera3D transform you set in the editor stays untouched.

@export_range(0.0, 0.3, 0.001) var shake_strength: float = 0.03
@export_range(1.0, 30.0, 0.1) var shake_decay: float = 9.0

@onready var _pivot: Node3D = $ShakePivot

var _shake: float = 0.0
var _rest_position: Vector3


func _ready() -> void:
	_rest_position = _pivot.position
	SignalBus.damage_dealt.connect(_on_damage_dealt)


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - shake_decay * delta * _shake)
	if _shake < 0.001:
		_shake = 0.0
		_pivot.position = _rest_position
		return
	_pivot.position = _rest_position + Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
	) * shake_strength * _shake


func _on_damage_dealt(_world_position: Vector3, _amount: float) -> void:
	_shake = 1.0
