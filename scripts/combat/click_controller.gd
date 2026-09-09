class_name ClickController
extends Node

## Turns a mouse click into a raycast against monster click areas.
## Doc v0.3 section 10: energy is only spent when a monster is actually hit,
## so misclicking empty floor costs nothing.

## Physics layer 3 ("ClickArea"), the layer every monster hitbox sits on.
const CLICK_COLLISION_MASK := 4

## Camera used for the pick ray. Assign the arena Camera3D in the Inspector.
@export var camera: Camera3D
## How far the pick ray travels, in metres.
@export_range(1.0, 500.0, 1.0) var ray_length: float = 80.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"click"):
		return
	if camera == null:
		push_error("ClickController has no Camera3D assigned.")
		return
	if not GameState.can_click():
		return

	var monster := pick_monster_at(get_viewport().get_mouse_position())
	if monster == null or not monster.is_alive():
		return
	if not GameState.spend_click_energy():
		return

	# One critical roll per click, shared by the gold upgrade and the 강타 words.
	# Doc v0.3 section 10.2.
	var is_critical := GameState.roll_critical()
	monster.take_click_damage(GameState.get_click_damage(is_critical), is_critical)
	monster.apply_status_effect(GameState.get_burn_effect())
	get_viewport().set_input_as_handled()


## Returns the monster under the given screen point, or null.
func pick_monster_at(screen_position: Vector2) -> JamoMonster:
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(screen_position),
		camera.project_ray_origin(screen_position)
			+ camera.project_ray_normal(screen_position) * ray_length
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = CLICK_COLLISION_MASK

	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	# The click Area3D is a direct child of the monster root.
	var collider: Node = hit.get("collider")
	if collider == null:
		return null
	return collider.get_parent() as JamoMonster
