extends SceneTree

## One-shot generator that seeded res://resources/animations/walk_library.tres.
##
## WARNING: running it again OVERWRITES that file and discards any curve you
## tuned in the editor. The .tres is the source of truth now; this script is
## kept only as a record of the starting values from doc v0.3 sections 5 and 7.
##
## Run (only if you really want to reset the animations):
##   godot --headless --path . --script res://tools/gen_walk_library.gd

const OUTPUT_PATH := "res://resources/animations/walk_library.tres"

const VISUAL_POS := "VisualRoot:position"
const BODY_ROT := "VisualRoot/Body:rotation"
const BODY_SCALE := "VisualRoot/Body:scale"

const DEG := PI / 180.0


func _initialize() -> void:
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", _make_idle())
	library.add_animation(&"turn", _make_turn())
	library.add_animation(&"hit", _make_hit())
	library.add_animation(&"spawn", _make_spawn())
	library.add_animation(&"death", _make_death())
	library.add_animation(&"walk_heavy_step", _make_heavy_step())
	library.add_animation(&"walk_light_step", _make_light_step())
	library.add_animation(&"walk_bounce", _make_bounce())
	library.add_animation(&"walk_roll", _make_roll())
	library.add_animation(&"walk_sway", _make_sway())
	library.add_animation(&"walk_glide", _make_glide())
	library.add_animation(&"walk_upright", _make_upright())

	var error := ResourceSaver.save(library, OUTPUT_PATH)
	if error != OK:
		printerr("Failed to save %s (error %d)" % [OUTPUT_PATH, error])
	else:
		print("Wrote %s with %d animations." % [OUTPUT_PATH, library.get_animation_list().size()])
	quit()


## Adds a value track and returns its index.
func _track(anim: Animation, path: String) -> int:
	var index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, path)
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	return index


func _keys(anim: Animation, track: int, times: Array, values: Array) -> void:
	for i in times.size():
		anim.track_insert_key(track, times[i], values[i])


# --- Shared states ---------------------------------------------------------

func _make_idle() -> Animation:
	# Barely-there breathing so a stopped jamo still reads as alive.
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 1.0, 2.0], [
		Vector3.ZERO, Vector3(0.0, 0.008, 0.0), Vector3.ZERO,
	])
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 1.0, 2.0], [
		Vector3.ONE, Vector3(0.99, 1.01, 0.99), Vector3.ONE,
	])
	return anim


func _make_turn() -> Animation:
	# A short lean into the new heading. Doc v0.3 section 4.1.
	var anim := Animation.new()
	anim.length = 0.35
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.15, 0.35], [
		Vector3.ZERO, Vector3(0.0, 0.0, -10.0 * DEG), Vector3.ZERO,
	])
	return anim


func _make_hit() -> Animation:
	# Squash punch. Doc v0.3 section 23.2, feedback item 1.
	var anim := Animation.new()
	anim.length = 0.18
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.05, 0.18], [
		Vector3.ONE, Vector3(1.25, 0.72, 1.25), Vector3.ONE,
	])
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.05, 0.18], [
		Vector3.ZERO, Vector3(0.0, -0.05, 0.0), Vector3.ZERO,
	])
	return anim


func _make_spawn() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.22, 0.4], [
		Vector3(0.1, 0.1, 0.1), Vector3(1.15, 1.15, 1.15), Vector3.ONE,
	])
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.4], [Vector3(0.0, 0.5, 0.0), Vector3.ZERO])
	return anim


func _make_death() -> Animation:
	# Flatten into the floor like a stamped ink mark.
	var anim := Animation.new()
	anim.length = 0.45
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.12, 0.45], [
		Vector3.ONE, Vector3(1.35, 0.55, 1.35), Vector3(0.05, 0.02, 0.05),
	])
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.45], [Vector3.ZERO, Vector3(0.0, 0.0, 35.0 * DEG)])
	return anim


# --- Walk profiles ---------------------------------------------------------
# One clip per personality from doc v0.3 section 7.2. Amplitudes follow the
# per-jamo numbers in section 5; a body is treated as roughly 0.6 m tall, so
# "bounce 6%" becomes 0.036 m.

func _make_heavy_step() -> Animation:
	# HEAVY_STEP - ㄷ. Bounce 6%, landing squash Y 0.92 / XZ 1.04.
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_LINEAR
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.2, 0.4, 0.6, 0.8], [
		Vector3.ZERO, Vector3(0.0, 0.036, 0.0), Vector3.ZERO,
		Vector3(0.0, 0.036, 0.0), Vector3.ZERO,
	])
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.08, 0.2, 0.4, 0.48, 0.6, 0.8], [
		Vector3(1.04, 0.92, 1.04), Vector3.ONE, Vector3.ONE,
		Vector3(1.04, 0.92, 1.04), Vector3.ONE, Vector3.ONE,
		Vector3(1.04, 0.92, 1.04),
	])
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.4, 0.8], [
		Vector3(0.0, 0.0, 3.0 * DEG), Vector3(0.0, 0.0, -3.0 * DEG),
		Vector3(0.0, 0.0, 3.0 * DEG),
	])
	return anim


func _make_light_step() -> Animation:
	# LIGHT_STEP - ㅅ. Small bounce, roll +-8 degrees, quick tapping rhythm.
	var anim := Animation.new()
	anim.length = 0.34
	anim.loop_mode = Animation.LOOP_LINEAR
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.085, 0.17, 0.255, 0.34], [
		Vector3.ZERO, Vector3(0.0, 0.014, 0.0), Vector3.ZERO,
		Vector3(0.0, 0.014, 0.0), Vector3.ZERO,
	])
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.17, 0.34], [
		Vector3(0.0, 0.0, 8.0 * DEG), Vector3(0.0, 0.0, -8.0 * DEG),
		Vector3(0.0, 0.0, 8.0 * DEG),
	])
	return anim


func _make_bounce() -> Animation:
	# BOUNCE - ㅁ. Hops with both feet, jump height 10%, strong landing squash.
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_LINEAR
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.1, 0.3, 0.45, 0.6], [
		Vector3.ZERO, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.06, 0.0),
		Vector3(0.0, 0.01, 0.0), Vector3.ZERO,
	])
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.08, 0.3, 0.46, 0.55, 0.6], [
		Vector3(1.12, 0.85, 1.12), Vector3(0.94, 1.1, 0.94), Vector3.ONE,
		Vector3(1.14, 0.83, 1.14), Vector3.ONE, Vector3(1.12, 0.85, 1.12),
	])
	return anim


func _make_roll() -> Animation:
	# ROLL - ㅇ. Rocks as if rolling, but swings back so the glyph never ends up
	# upside down. Doc v0.3 section 5.8 requires the front orientation to hold.
	var anim := Animation.new()
	anim.length = 0.7
	anim.loop_mode = Animation.LOOP_LINEAR
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.175, 0.35, 0.525, 0.7], [
		Vector3.ZERO, Vector3(0.0, 0.0, -14.0 * DEG), Vector3.ZERO,
		Vector3(0.0, 0.0, 14.0 * DEG), Vector3.ZERO,
	])
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.175, 0.35, 0.525, 0.7], [
		Vector3.ONE, Vector3(1.07, 0.94, 1.0), Vector3.ONE,
		Vector3(1.07, 0.94, 1.0), Vector3.ONE,
	])
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.35, 0.7], [
		Vector3.ZERO, Vector3(0.0, 0.018, 0.0), Vector3.ZERO,
	])
	return anim


func _make_sway() -> Animation:
	# SWAY - ㄱ. Leans onto the bent corner, springs forward, recovers.
	# Doc v0.3 section 5.1: bounce 4%, tilt +-7 degrees.
	var anim := Animation.new()
	anim.length = 0.7
	anim.loop_mode = Animation.LOOP_LINEAR
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.2, 0.35, 0.55, 0.7], [
		Vector3.ZERO, Vector3(0.0, 0.0, -7.0 * DEG), Vector3.ZERO,
		Vector3(0.0, 0.0, 4.0 * DEG), Vector3.ZERO,
	])
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.2, 0.35, 0.7], [
		Vector3.ZERO, Vector3(0.0, 0.024, 0.0), Vector3.ZERO, Vector3.ZERO,
	])
	return anim


func _make_glide() -> Animation:
	# GLIDE - ㅡ and other low shapes. Slides along the floor, almost no lift.
	var anim := Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_LINEAR
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.6, 1.2], [
		Vector3.ZERO, Vector3(0.0, 0.008, 0.0), Vector3.ZERO,
	])
	var scale := _track(anim, BODY_SCALE)
	_keys(anim, scale, [0.0, 0.6, 1.2], [
		Vector3.ONE, Vector3(1.04, 0.98, 1.0), Vector3.ONE,
	])
	return anim


func _make_upright() -> Animation:
	# UPRIGHT - ㅣ. Doc v0.3 section 6.6: lightest and fastest, tilt +-10
	# degrees, narrow strides repeated quickly.
	var anim := Animation.new()
	anim.length = 0.3
	anim.loop_mode = Animation.LOOP_LINEAR
	var rot := _track(anim, BODY_ROT)
	_keys(anim, rot, [0.0, 0.15, 0.3], [
		Vector3(0.0, 0.0, 10.0 * DEG), Vector3(0.0, 0.0, -10.0 * DEG),
		Vector3(0.0, 0.0, 10.0 * DEG),
	])
	var pos := _track(anim, VISUAL_POS)
	_keys(anim, pos, [0.0, 0.075, 0.15, 0.225, 0.3], [
		Vector3.ZERO, Vector3(0.0, 0.016, 0.0), Vector3.ZERO,
		Vector3(0.0, 0.016, 0.0), Vector3.ZERO,
	])
	return anim
