extends Node3D

## Fixed 3/4 camera. The player never rotates it. Doc v0.3 section 26.
## It moves in exactly two ways: a short shake on damage and a word-complete
## zoom, both applied to ShakePivot or to the orthogonal size, so the Camera3D
## transform you set in the editor stays untouched.

@export_group("Hit Shake")
@export_range(0.0, 0.3, 0.001) var shake_strength: float = 0.03
@export_range(0.02, 1.0, 0.01) var shake_duration: float = 0.12

@export_group("Critical Shake")
## Doc v0.3 section 23.2: a critical hit adds a small extra camera kick.
@export_range(0.0, 0.5, 0.001) var critical_shake_strength: float = 0.09
@export_range(0.02, 1.0, 0.01) var critical_shake_duration: float = 0.22

@export_group("Word Complete Zoom")
## Fraction of the resting orthogonal size the camera pushes in to when a word
## is revealed. 0.85 is a 15% push. Doc v0.3 section 26.
@export_range(0.3, 1.0, 0.01) var zoom_scale: float = 0.85
## Seconds to push in, and to come back out again.
@export_range(0.05, 2.0, 0.05) var zoom_in_seconds: float = 0.18
@export_range(0.05, 3.0, 0.05) var zoom_out_seconds: float = 0.5

@onready var _pivot: Node3D = $ShakePivot
@onready var _camera: Camera3D = $ShakePivot/Camera3D

var _strength: float = 0.0
var _remaining: float = 0.0
var _duration: float = 0.0
var _rest_position: Vector3
## Orthogonal size the camera rests at, captured so a zoom always returns to
## whatever was set in the editor.
var _rest_camera_size: float = 0.0
var _zoom_tween: Tween


func _ready() -> void:
	_rest_position = _pivot.position
	_rest_camera_size = _camera.size
	SignalBus.damage_dealt.connect(_on_damage_dealt)
	SignalBus.word_revealed.connect(zoom_punch)


## Starts a shake that fades out over `duration` seconds. A shake already in
## flight is only ever strengthened, never cut short by a weaker hit.
func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	_strength = maxf(_strength, strength)
	_duration = maxf(_duration, duration)
	_remaining = maxf(_remaining, duration)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_strength = 0.0
		_duration = 0.0
		_pivot.position = _rest_position
		return
	var falloff: float = _remaining / _duration
	_pivot.position = _rest_position + Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
	) * _strength * falloff


func _on_damage_dealt(_world_position: Vector3, _amount: float, is_critical: bool) -> void:
	if is_critical:
		shake(critical_shake_strength, critical_shake_duration)
	else:
		shake(shake_strength, shake_duration)


## Pushes in and eases back out. Doc v0.3 section 26: Word Complete Zoom.
func zoom_punch() -> void:
	if _zoom_tween != null:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(
		_camera, ^"size", _rest_camera_size * zoom_scale, zoom_in_seconds
	).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(
		_camera, ^"size", _rest_camera_size, zoom_out_seconds
	).set_ease(Tween.EASE_IN_OUT)
