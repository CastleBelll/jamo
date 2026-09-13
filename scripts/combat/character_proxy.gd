class_name CharacterProxy
extends Node3D
## One porcelain figure in the Battle3D layer, driven by its 2D JamoMonster. Rigged models
## (art/models, codex P6) play idle/walk/hit/purify tracks; the older static figures
## (art/monsters/characters, Leg_L/Leg_R parts) get a procedural gait per G11 motion group.

const MODEL_DIRS := ["res://art/models/char_%s.glb", "res://art/monsters/characters/%s.glb"]
const TARGET_HEIGHT := 1.9        # units; reads as ~92px at the 60-degree camera tilt (B11 visual size)
const TURN_SPEED := 10.0
const HIT_SECONDS := 0.16
const PURIFY_SECONDS := 0.45
## Gait per G11 group: leg swing (deg), step rate (Hz), body bob (units), yaw sway (deg), roll.
const GAITS := {
	&"ROLL": {"swing": 0.0, "rate": 0.0, "bob": 0.0, "sway": 0.0, "roll": true},
	&"BOUNCE": {"swing": 20.0, "rate": 1.8, "bob": 0.08, "sway": 0.0, "roll": false},
	&"LIGHT_STEP": {"swing": 30.0, "rate": 4.0, "bob": 0.02, "sway": 0.0, "roll": false},
	&"HEAVY_STEP": {"swing": 25.0, "rate": 1.4, "bob": 0.05, "sway": 0.0, "roll": false},
	&"SWAY": {"swing": 22.0, "rate": 2.2, "bob": 0.01, "sway": 6.0, "roll": false},
	&"GLIDE": {"swing": 6.0, "rate": 1.0, "bob": 0.015, "sway": 0.0, "roll": false},
}

var model: Node3D
var anim: AnimationPlayer
var leg_l: Node3D
var leg_r: Node3D
var body: Node3D
var gait: Dictionary = GAITS[&"GLIDE"]
var phase: float = 0.0
var heading: float = 0.0
var dying: bool = false
var base_scale: float = 1.0


static func model_for(jamo: String) -> PackedScene:
	var name: String = AssetLib.GLYPH_NAMES.get(jamo, "")
	if name == "":
		return null
	for pattern in MODEL_DIRS:
		var path: String = pattern % name
		if ResourceLoader.exists(path):
			return load(path)
	return null


func setup(scene: PackedScene, motion_id: StringName) -> void:
	model = scene.instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	leg_l = model.find_child("Leg_L", true, false)
	leg_r = model.find_child("Leg_R", true, false)
	body = model.find_child("Glyph", true, false)
	gait = GAITS.get(motion_id, GAITS[&"GLIDE"])
	var aabb := _bounds()
	base_scale = TARGET_HEIGHT / maxf(aabb.size.y, 0.01)
	model.scale = Vector3.ONE * base_scale
	if anim != null and anim.has_animation("idle"):
		anim.play("idle")


func _bounds() -> AABB:
	var out := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = m.get_aabb()
		box.position += m.position
		out = box if first else out.merge(box)
		first = false
	return out


## Called by the 2D entity every frame with its battlefield position and where it is heading.
func update_from(layer: Node, pos2d: Vector2, velocity2d: Vector2, delta: float) -> void:
	var target: Vector3 = layer.ground_point(pos2d)
	var moving := velocity2d.length() > 1.0
	if moving:
		var ahead: Vector3 = layer.ground_point(pos2d + velocity2d.normalized() * 10.0)
		var dir := ahead - target
		if dir.length() > 0.001:
			heading = lerp_angle(heading, atan2(dir.x, dir.z), minf(1.0, TURN_SPEED * delta))
	position = target
	rotation.y = heading
	if dying:
		return
	if anim != null and anim.has_animation("walk"):
		var want := "walk" if moving else "idle"
		if anim.current_animation != want and anim.has_animation(want):
			anim.play(want)
		return
	_procedural_gait(moving, velocity2d.length(), delta)


## Static figures: legs swing about their pivots, body bobs/sways/rolls per group (G11).
func _procedural_gait(moving: bool, speed_px: float, delta: float) -> void:
	if not moving:
		phase = 0.0
		_set_legs(0.0)
		if body != null:
			body.position.y = 0.0
			body.rotation = Vector3.ZERO
		return
	phase += delta * TAU * float(gait["rate"]) * clampf(speed_px / 60.0, 0.6, 1.6)
	var s := sin(phase)
	_set_legs(deg_to_rad(float(gait["swing"])) * s)
	if body == null:
		return
	if gait["roll"]:
		body.rotation.x += delta * speed_px * 0.01 / maxf(TARGET_HEIGHT * 0.5, 0.1)
		return
	body.position.y = absf(s) * float(gait["bob"])
	body.rotation.z = deg_to_rad(float(gait["sway"])) * s


func _set_legs(angle: float) -> void:
	if leg_l != null:
		leg_l.rotation.x = angle
	if leg_r != null:
		leg_r.rotation.x = -angle


## Squash on a hit (G12): 0.16s, on the model so it never disturbs the 2D click circle.
func hit() -> void:
	if dying:
		return
	if anim != null and anim.has_animation("hit"):
		anim.play("hit")
		return
	var t := create_tween()
	model.scale = Vector3(1.08, 0.9, 1.08) * base_scale
	t.tween_property(model, "scale", Vector3.ONE * base_scale, HIT_SECONDS)


## Purify: play the track or crumble (scale down + sink), then free.
func purify() -> void:
	dying = true
	if anim != null and anim.has_animation("purify"):
		anim.play("purify")
		get_tree().create_timer(PURIFY_SECONDS).timeout.connect(queue_free)
		return
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(model, "scale", Vector3(base_scale * 1.2, base_scale * 0.05, base_scale * 1.2), PURIFY_SECONDS)
	t.tween_property(model, "position:y", -0.2, PURIFY_SECONDS)
	t.chain().tween_callback(queue_free)
