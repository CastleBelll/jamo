class_name SentenceCore
extends Node3D

## The 문장핵: the object the player defends. Doc v0.4 sections 6.1 and 35.
##
## The HP itself is run state and lives in RunState.core_hp; this node is the
## thing in the world that monsters walk to, and the place hit feedback plays.
## Everything under VisualRoot is the model from art/objective; the hit look
## (squash, jolt, paper flash) is authored in sentence_core.tscn's AnimationPlayer.

## Root of the look. Swap the children of this node for another asset; the
## script never reaches past it. Doc v0.4 section 46.
@export var visual_root: Node3D
## Horizontal distance at which an approaching monster counts as having reached
## the core, in metres. Doc v0.4 section 6.1.
@export_range(0.1, 3.0, 0.05) var reach_radius: float = 0.9

@export_group("Hit Feedback")
## CameraRig whose shake() plays on every hit. Optional.
@export var camera_rig: Node3D
@export_range(0.0, 0.5, 0.001) var hit_shake_strength: float = 0.06
@export_range(0.02, 1.0, 0.01) var hit_shake_duration: float = 0.2
## Animation played on every hit. Authored in sentence_core.tscn.
@export var hit_animation: StringName = &"hit"

@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group(&"sentence_core")
	if visual_root == null:
		push_warning("SentenceCore at %s has no visual_root assigned." % get_path())


## A monster reached the core. The damage rule lives in RunState so the fail
## path stays in one place; this only plays the feedback. Doc v0.4 section 35.
func take_hit(amount: float) -> void:
	if amount <= 0.0 or not RunState.is_active:
		return
	RunState.damage_core(amount)
	if _animation.has_animation(hit_animation):
		_animation.stop()
		_animation.play(hit_animation)
	if camera_rig != null and camera_rig.has_method("shake"):
		camera_rig.shake(hit_shake_strength, hit_shake_duration)
