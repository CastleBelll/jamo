extends Node3D

## Floating damage number. Lives in 3D and billboards toward the camera, so no
## world-to-screen projection is needed. Doc v0.3 section 23.2, feedback item 3.
##
## A critical hit is marked by BOTH a bigger number and a different colour, so
## the difference still reads without colour vision.

## Set these before add_child(); _ready() reads them.
var amount: float = 1.0
var is_critical: bool = false

@export_range(0.1, 3.0, 0.05) var rise_height: float = 0.8
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.7

@export_group("Critical")
## Multiplies Label3D.pixel_size on a critical hit. Doc v0.3 section 23.2.
@export_range(1.0, 3.0, 0.05) var critical_scale: float = 1.6
## Fill colour of a critical number. Kept alongside the size change on purpose:
## colour alone must never be the only cue.
@export var critical_modulate: Color = Color(0.86, 0.24, 0.16, 1.0)
## Outline colour of a critical number, for contrast against the paper arena.
@export var critical_outline_modulate: Color = Color(1.0, 0.94, 0.78, 1.0)
## Extra rise on a critical hit, so the bigger number clears the crowd.
@export_range(1.0, 3.0, 0.05) var critical_rise_scale: float = 1.35

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_label.text = str(maxi(1, roundi(amount)))
	var rise := rise_height
	if is_critical:
		_label.pixel_size *= critical_scale
		_label.modulate = critical_modulate
		_label.outline_modulate = critical_outline_modulate
		rise *= critical_rise_scale

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"position:y", position.y + rise, lifetime) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_label, ^"modulate:a", 0.0, lifetime) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
