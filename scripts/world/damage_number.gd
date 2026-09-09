extends Node3D

## Floating damage number. Lives in 3D and billboards toward the camera, so no
## world-to-screen projection is needed. Doc v0.3 section 23.2, feedback item 3.

## Set this before add_child(); _ready() reads it.
var amount: float = 1.0

@export_range(0.1, 3.0, 0.05) var rise_height: float = 0.8
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.7

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_label.text = str(maxi(1, roundi(amount)))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"position:y", position.y + rise_height, lifetime) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_label, ^"modulate:a", 0.0, lifetime) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
