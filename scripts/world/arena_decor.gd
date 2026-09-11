class_name ArenaDecor
extends Node3D

## Environment dressing of the desk around the paper sheet. Doc v0.4
## section 39: a handful of simple props that put the arena in the title
## screen's desk world.
##
## Every child of this node is one slot (a Marker3D named after the prop) and
## holds a primitive stand-in authored in arena.tscn. The finished asset is
## dropped into `replacements` under the slot's name; at load the stand-in is
## freed and the asset scene is instanced at the slot's transform instead, so
## the placement stays in the scene and the model is swapped without editing
## the arena. A slot with no entry keeps its stand-in.

## Slot name -> the asset scene that replaces that slot's stand-in.
@export var replacements: Dictionary[StringName, PackedScene] = {}


func _ready() -> void:
	for slot_name: StringName in replacements:
		var slot := get_node_or_null(NodePath(slot_name)) as Node3D
		var scene: PackedScene = replacements[slot_name]
		if slot == null:
			push_warning("ArenaDecor: no slot named %s under %s." % [slot_name, get_path()])
			continue
		if scene == null:
			continue
		for stand_in: Node in slot.get_children():
			stand_in.queue_free()
		slot.add_child(scene.instantiate())
