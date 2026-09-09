extends Node

## QA harness for F3 tier-2 words. Not a pass/fail test: it runs the real
## main.tscn, drives real mouse clicks through the input pipeline, and writes
## observation artifacts (screenshots + JSON) for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f3_play.tscn
##
## Doc v0.3 sections 14, 15, 22.4, 33, 36 / word_tree v0.1.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f3"
## Long enough for a 3 second burn to run out and kill, plus settle time.
const BURN_OBSERVE_FRAMES := 420

const TIER1 := [&"fire_001", &"power_001", &"gold_001", &"energy_001", &"luck_001"]
const ALL_WORDS := [
	&"fire_001", &"fire_002", &"fire_003", &"power_001", &"power_002",
	&"gold_001", &"gold_002", &"energy_001", &"energy_002", &"luck_001",
]

var _main: Node
var _camera: Camera3D
var _monster_root: Node3D
var _fx_root: Node3D
var _spawn: SpawnManager
var _dex: Control

var _burn_ticks: Array[float] = []
## Set just before a synthetic click so the click's own damage event is not
## mistaken for a burn tick; burn and click damage can be the same number.
var _expect_click_damage: bool = false
var _kills: int = 0
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = _main.get_node("World/GameWorld")
	_camera = world.get_node("CameraRig/ShakePivot/Camera3D")
	_monster_root = world.get_node("MonsterRoot")
	_fx_root = world.get_node("FXRoot")
	_spawn = world.get_node("SpawnManager")
	_dex = _main.get_node("UI/WordTree")

	SignalBus.damage_dealt.connect(_on_damage_dealt)
	SignalBus.monster_killed.connect(_on_monster_killed)

	await _capture_fresh_start()
	await _capture_dex("dex_fresh", [])
	_report["burn_tick_bul"] = await _measure_burn([&"fire_001"], "burn_bul")
	_report["burn_tick_hwayeom"] = await _measure_burn(
		[&"fire_001", &"fire_002"], "burn_hwayeom"
	)
	_report["burn_tick_hwayeom_reloaded"] = await _measure_burn(
		[&"fire_001", &"fire_002"], "burn_hwayeom_again"
	)
	_report["kills_without_bulkkot"] = await _measure_spread(
		[&"fire_001", &"fire_002"], "spread_off"
	)
	_report["kills_with_bulkkot"] = await _measure_spread(
		[&"fire_001", &"fire_002", &"fire_003"], "spread_on"
	)
	await _capture_dex("dex_all", ALL_WORDS)
	_report["max_energy_all_words"] = GameState.get_max_energy()

	_write_report()
	get_tree().quit()


## The bug the player reported: an overlay sitting on top of a fresh Day 1.
func _capture_fresh_start() -> void:
	_apply_state([], 1)
	await _wait_for_monster()
	var overlays: Dictionary = {}
	for overlay_name: String in [
		"Dim", "DayEnd", "JamoChoice", "WordComplete", "UpgradeShop",
		"WordTree", "PauseMenu", "Settings",
	]:
		overlays[overlay_name] = (_main.get_node("UI/%s" % overlay_name) as CanvasItem).visible
	_report["overlays_visible_on_day1"] = overlays

	# A click must still reach a monster with no overlay in the way.
	var before: int = GameState.energy
	await _click_until_hit()
	_report["energy_before_click"] = before
	_report["energy_after_click"] = GameState.energy
	await _shot("day1_fresh")


func _capture_dex(label: String, word_ids: Array) -> void:
	_apply_state(word_ids, 1 if word_ids.is_empty() else 30)
	_dex.open()
	await get_tree().process_frame
	await _shot(label)
	_report[label] = _read_dex_rows()
	_dex.hide()
	await get_tree().process_frame


## Word rows of the tree panel, one entry per visible slot button.
func _read_dex_rows() -> Array[String]:
	var rows: Array[String] = []
	for column: Node in _dex.get_node("%Columns").get_children():
		for child: Node in column.get_children():
			var slot := child as Button
			if slot != null and slot.visible:
				rows.append(slot.text)
	return rows


## Clicks one monster and records every burn tick it takes.
func _measure_burn(word_ids: Array, label: String) -> Array:
	_apply_state(word_ids, 1)
	await _wait_for_monster()
	_burn_ticks.clear()
	await _click_until_hit()
	for _frame in BURN_OBSERVE_FRAMES:
		await get_tree().process_frame
	await _shot(label)
	return _burn_ticks.duplicate()


## Clicks exactly one monster on a full field and counts the resulting deaths.
## Without 불꽃 that is one; with it, the source plus a single spread.
func _measure_spread(word_ids: Array, label: String) -> int:
	_apply_state(word_ids, 1)
	GameState.upgrade_levels[GameState.UPGRADE_MONSTER_CAPACITY] = 6
	await _fill_field()
	_kills = 0
	await _click_until_hit()
	for _frame in BURN_OBSERVE_FRAMES:
		await get_tree().process_frame
	await _shot(label)
	GameState.upgrade_levels.erase(GameState.UPGRADE_MONSTER_CAPACITY)
	return _kills


func _apply_state(word_ids: Array, day: int) -> void:
	GameState.unlocked_word_ids.clear()
	for id: StringName in word_ids:
		GameState.unlocked_word_ids.append(id)
	GameState.jamo_inventory.clear()
	GameState.day = day
	GameState._recalculate_word_bonuses()
	GameState.begin_day()
	_spawn.clear_field()


func _fill_field() -> void:
	for _frame in 600:
		await get_tree().process_frame
		if _monster_root.get_child_count() >= GameState.get_monster_capacity():
			return


func _wait_for_monster() -> void:
	for _frame in 600:
		if _pick_alive_monster() != null:
			return
		await get_tree().process_frame


func _pick_alive_monster() -> JamoMonster:
	for child in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster != null and monster.is_alive():
			return monster
	return null


## A monster that is still falling into the arena has its click shape disabled,
## so a single synthetic click can legitimately miss. Retry until energy is
## actually spent, which is the game's own definition of a hit.
func _click_until_hit() -> bool:
	for _attempt in 40:
		var before: int = GameState.energy
		_expect_click_damage = true
		await _click(_pick_alive_monster())
		await get_tree().process_frame
		if GameState.energy < before:
			return true
		_expect_click_damage = false
		for _frame in 6:
			await get_tree().process_frame
	push_error("qa_f3_play: could not land a click on any monster")
	return false


## Real input: warp the OS cursor, feed a motion event so the viewport mouse
## position follows, then press and release the "click" action.
func _click(monster: JamoMonster) -> void:
	if monster == null:
		return
	var screen: Vector2 = _camera.unproject_position(monster.get_hit_position())
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await get_tree().process_frame

	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)
		await get_tree().process_frame


func _on_damage_dealt(_position: Vector3, amount: float, _is_critical: bool) -> void:
	if _expect_click_damage:
		_expect_click_damage = false
		return
	_burn_ticks.append(amount)


func _on_monster_killed(_jamo: String, _gold: float, _position: Vector3) -> void:
	_kills += 1


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/play_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f3_observations.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f3_play: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	print(JSON.stringify(_report, "\t"))
	print("OK - F3 artifacts written to %s" % ARTIFACT_DIR)
