extends Node

## QA P1 re-verification: did the state machine rewrite flatten the walks?
##
## The six walk personalities of doc v0.4 section 15 are authored in
## resources/motion_profiles/*.tres and the AnimationPlayer timelines. The P1
## fix changed only what ends SPAWN and TURN, so every gait number and the
## idle/turn rhythm have to come out unchanged. This spawns one monster per
## motion profile in the real game world, lets them walk to the 문장핵, and
## measures each one instead of taking the claim on trust:
##
##   - which walk animation is playing and at what speed_scale
##   - the horizontal speed it actually covers ground at
##   - the vertical bob of its VisualRoot, which is what "heavy" or "bouncy"
##     looks like on screen
##   - how often it stops to pick a direction - the IDLE/TURN rhythm that a
##     timer-driven state machine could have flattened
##
## Windowed, because it also writes comparison frames for the report.
## Run: godot --path . res://tests/qa_p1_gait.tscn

const RUN_SCENE := "res://scenes/main/main.tscn"
const SHOT_DIR := "res://tests/qa_artifacts/p1/gait"
const MEASURE_FRAMES := 900
const SHOT_EVERY := 220

## One monster scene per motion profile, so the six personalities line up.
const SUBJECTS: Array[String] = [
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_i.tscn",
]

var _failures: int = 0
var _tracks: Array[Dictionary] = []


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _run()
	if _failures == 0:
		print("OK - the six gaits are still six different gaits.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _run() -> void:
	var packed: PackedScene = load(RUN_SCENE) as PackedScene
	var main: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = main.get_node("World/GameWorld")
	var spawner: SpawnManager = world.get_node("SpawnManager")
	var core: SentenceCore = world.get_node("SentenceCore")
	RunState.core_max_hp = 999999.0
	RunState.core_hp = 999999.0
	# Only the six subjects may be on the field, so nothing else is measured.
	spawner.stop()
	spawner.clear_field()
	await get_tree().process_frame

	for index in SUBJECTS.size():
		var scene: PackedScene = load(SUBJECTS[index]) as PackedScene
		var monster := scene.instantiate() as JamoMonster
		monster.objective = core
		monster.arena_half_extents = spawner.arena_half_extents
		spawner.spawn_root.add_child(monster)
		# Spread them along the far edge so they walk a long way in and never
		# crowd each other into a separation dance.
		var angle: float = TAU * float(index) / float(SUBJECTS.size())
		monster.global_position = Vector3(cos(angle) * 2.6, 0.0, 2.2 + sin(angle) * 0.6)
		_tracks.append({
			"monster": monster,
			"id": "",
			"profile": "",
			"anim": "",
			"speed_scale": 0.0,
			"distance": 0.0,
			"walk_frames": 0,
			"idle_entries": 0,
			"turn_entries": 0,
			"bob_min": INF,
			"bob_max": -INF,
			"last_state": -1,
			"last_pos": Vector3.ZERO,
			"started": false,
		})
	await get_tree().process_frame
	await get_tree().process_frame

	var shot := 0
	for frame in MEASURE_FRAMES:
		for track: Dictionary in _tracks:
			_sample(track)
		if frame % SHOT_EVERY == 0:
			await _shoot("%02d_walk.png" % shot)
			shot += 1
		await get_tree().process_frame

	print("-- gait signatures, one monster per motion profile")
	print("    %-12s %-12s %-16s %6s %8s %8s %6s %6s" % [
		"jamo", "profile", "walk animation", "scale", "m/s", "bob m", "idles", "turns",
	])
	var animations: Dictionary = {}
	var speeds: Array[float] = []
	var bobs: Array[float] = []
	for track: Dictionary in _tracks:
		var seconds: float = float(track.walk_frames) / 60.0
		var speed: float = track.distance / seconds if seconds > 0.0 else 0.0
		var bob: float = (track.bob_max - track.bob_min) if track.bob_max > track.bob_min else 0.0
		print("    %-12s %-12s %-16s %6.2f %8.2f %8.3f %6d %6d" % [
			track.id, track.profile, track.anim, track.speed_scale, speed, bob,
			track.idle_entries, track.turn_entries,
		])
		animations[track.anim] = true
		speeds.append(speed)
		bobs.append(bob)
		_check(track.walk_frames > 0, "%s spent time walking" % track.id)
		_check(track.distance > 0.5,
			"%s covered ground (%.2f m)" % [track.id, track.distance])
		_check(bob > 0.0,
			"%s still bobs while it walks (%.3f m)" % [track.id, bob])
		_check(track.idle_entries + track.turn_entries > 0,
			"%s still stops to pick a direction (%d idle, %d turn)"
				% [track.id, track.idle_entries, track.turn_entries])
	_check(animations.size() >= 5,
		"the subjects play %d different walk animations, expected at least 5"
			% animations.size())
	_check(_spread(speeds) > 0.15,
		"the walk speeds are still spread apart (%.3f m/s between fastest and slowest)"
			% _spread(speeds))
	_check(_spread(bobs) > 0.01,
		"the bob amplitudes are still spread apart (%.3f m)" % _spread(bobs))
	print("    %d distinct walk animations, speed spread %.2f m/s, bob spread %.3f m"
		% [animations.size(), _spread(speeds), _spread(bobs)])
	print("    frames: %s" % SHOT_DIR)


## Reads one monster for this frame. Everything measured here is what the
## player sees, not what the resource says, so an unchanged .tres that stopped
## reaching the monster would still show up.
func _sample(track: Dictionary) -> void:
	# A subject that reached the 문장핵 is freed mid-run, and reading a freed
	# instance into a typed variable is itself an error, so the check comes
	# before the assignment.
	if not is_instance_valid(track.monster):
		return
	var monster: JamoMonster = track.monster
	if not monster.is_alive():
		return
	if track.id == "":
		track.id = str(monster.monster_data.id)
		var profile: MotionProfile = monster.monster_data.motion_profile
		track.profile = profile.resource_path.get_file().get_basename() if profile != null else "?"
	var state: int = monster.get_state()
	if state != track.last_state:
		if state == JamoMonster.State.IDLE:
			track.idle_entries += 1
		elif state == JamoMonster.State.TURN:
			track.turn_entries += 1
		track.last_state = state
	var visual: Node3D = monster.get_node("VisualRoot")
	if state == JamoMonster.State.WALK:
		var player: AnimationPlayer = monster.get_node("AnimationPlayer")
		track.anim = str(player.current_animation)
		track.speed_scale = player.speed_scale
		track.bob_min = minf(track.bob_min, visual.position.y)
		track.bob_max = maxf(track.bob_max, visual.position.y)
		if track.started:
			track.distance += Vector2(
				monster.global_position.x - track.last_pos.x,
				monster.global_position.z - track.last_pos.z
			).length()
		track.walk_frames += 1
		track.started = true
	else:
		track.started = false
	track.last_pos = monster.global_position


func _spread(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var low: float = values[0]
	var high: float = values[0]
	for value: float in values:
		low = minf(low, value)
		high = maxf(high, value)
	return high - low


func _shoot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s" % [SHOT_DIR, file_name]
	image.save_png(path)
	print("    shot: %s" % path)
