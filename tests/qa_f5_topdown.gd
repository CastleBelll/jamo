extends Node

## QA-side visual cross-check for F5 / S0-2. The shipped harness measures the
## overhang numerically; this one photographs the same field straight down an
## orthogonal camera so a human can see the glyph footprints against the paper
## edge without the isometric camera's height parallax getting in the way.
##
## Test-only: it adds its own camera and never touches the production scene.
##   godot --path . tests/qa_f5_topdown.tscn

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f5"
const BIG_MIEUM := "res://scenes/monsters/special/monster_big_mieum.tscn"
const NORMAL_SCENES := [
	"res://scenes/monsters/monster_giyeok.tscn",
	"res://scenes/monsters/monster_mieum.tscn",
	"res://scenes/monsters/monster_ieung.tscn",
	"res://scenes/monsters/monster_digeut.tscn",
	"res://scenes/monsters/monster_siot.tscn",
	"res://scenes/monsters/monster_i.tscn",
]
## An oversized glyph nothing in the data ships with, to prove the inset is
## computed from the real body rather than tuned per resource.
const EXAGGERATED_SCALE := 4.0
const FILL_FRAMES := 900
const OBSERVE_FRAMES := 1500

var _main: Node
var _monster_root: Node3D
var _spawn: SpawnManager
var _camera: Camera3D


func _ready() -> void:
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = _main.get_node("World/GameWorld")
	_monster_root = world.get_node("MonsterRoot")
	_spawn = world.get_node("SpawnManager")

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 9.0
	_camera.position = Vector3(0.0, 24.0, 0.0)
	_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	world.add_child(_camera)
	_camera.make_current()

	var hud: CanvasItem = _main.get_node("UI/HUD")
	hud.visible = false

	await _observe("topdown_big_mieum", [BIG_MIEUM], 0.0)
	await _observe("topdown_normal", NORMAL_SCENES, 0.0)
	await _observe("topdown_scale4", [BIG_MIEUM], EXAGGERATED_SCALE)
	get_tree().quit()


## Fills the field from one pool, optionally blowing every glyph up to
## `forced_scale`, and photographs it from above at three moments.
func _observe(label: String, scene_paths: Array, forced_scale: float) -> void:
	var pool: Array[PackedScene] = []
	for path: String in scene_paths:
		pool.append(load(path))
	_spawn.clear_field()
	_spawn.monster_scenes = pool
	_spawn.special_scenes = []
	_spawn.golden_scenes = []
	MetaState.permanent_upgrade_levels[MetaState.UPGRADE_MONSTER_CAPACITY] = 20
	RunState.start_run()

	for _frame in FILL_FRAMES:
		await get_tree().process_frame
		if _monster_root.get_child_count() >= MetaState.get_monster_capacity():
			break

	if forced_scale > 0.0:
		for monster: JamoMonster in _live_monsters():
			var visual: Node3D = monster.get_node("VisualRoot")
			visual.scale = Vector3.ONE * forced_scale

	for frame in OBSERVE_FRAMES:
		await get_tree().process_frame
		if frame % 700 == 0:
			await _shot("%s_%d" % [label, frame])
	await _shot("%s_final" % label)


func _live_monsters() -> Array[JamoMonster]:
	var found: Array[JamoMonster] = []
	for child: Node in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster != null and is_instance_valid(monster):
			found.append(monster)
	return found


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [ARTIFACT_DIR, label])
