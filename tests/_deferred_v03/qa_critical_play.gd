extends Node

## QA harness for F1 Critical. Not a pass/fail test: it runs the real
## main.tscn, drives real mouse clicks through the input pipeline, and writes
## observation artifacts (screenshots + JSON) for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_critical_play.tscn
##
## Doc v0.3 sections 10.2 and 23.2, growth_balance v0.2 section 8.3.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f1"
## Enough attempts that a 2% chance is observed with near certainty.
const MAX_CLICKS := 800
## Day 25 is when 치명 클릭 unlocks. growth_balance v0.2 section 13.
const PLAY_DAY := 25

var _camera: Camera3D
var _pivot: Node3D
var _monster_root: Node3D
var _fx_root: Node3D
var _spawn: SpawnManager

var _clicks: int = 0
var _hits: int = 0
var _crits: int = 0
var _last_was_critical: bool = false
var _last_amount: float = 0.0
var _got_hit: bool = false

var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var main: Node = load(MAIN_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = main.get_node("World/GameWorld")
	_camera = world.get_node("CameraRig/ShakePivot/Camera3D")
	_pivot = world.get_node("CameraRig/ShakePivot")
	_monster_root = world.get_node("MonsterRoot")
	_fx_root = world.get_node("FXRoot")
	_spawn = world.get_node("SpawnManager")
	# Keep the field busy so the click loop is never starved of targets.
	_spawn.spawn_interval = 0.05

	SignalBus.damage_dealt.connect(_on_damage_dealt)

	_setup_state()
	await _wait_for_monster()

	_report["day"] = GameState.day
	_report["click_damage_level"] = GameState.get_upgrade_level(&"click_damage")
	_report["crit_level"] = GameState.get_upgrade_level(&"critical_click")
	_report["crit_chance"] = GameState.get_crit_chance()
	_report["crit_multiplier"] = GameState.get_crit_multiplier()
	_report["normal_click_damage"] = GameState.get_click_damage()
	_report["critical_click_damage"] = GameState.get_click_damage(true)

	await _run_clicks()

	_report["clicks"] = _clicks
	_report["hits"] = _hits
	_report["crits"] = _crits
	_report["observed_crit_rate"] = (float(_crits) / float(_hits)) if _hits > 0 else 0.0

	_write_report()
	print("QA harness finished. hits=%d crits=%d" % [_hits, _crits])
	get_tree().quit(0)


## Puts the run past both unlock gates and buys 치명 클릭 Lv.1, so the 2%
## chance comes from critical_click.tres and not from a harness constant.
func _setup_state() -> void:
	GameState.day = PLAY_DAY
	GameState.upgrade_levels[&"click_damage"] = 3
	GameState.upgrade_levels[&"monster_capacity"] = 3
	GameState.upgrade_levels[&"critical_click"] = 1
	GameState.energy = GameState.get_max_energy()


func _on_damage_dealt(_world_position: Vector3, amount: float, is_critical: bool) -> void:
	_hits += 1
	_last_amount = amount
	_last_was_critical = is_critical
	_got_hit = true
	if is_critical:
		_crits += 1


func _run_clicks() -> void:
	var normal_done := false
	var crit_done := false
	while _clicks < MAX_CLICKS and not (normal_done and crit_done):
		var monster := _pick_alive_monster()
		if monster == null:
			await get_tree().process_frame
			continue

		# The click path spends energy; a day end would swallow the harness.
		GameState.energy = GameState.get_max_energy()
		_got_hit = false
		await _click(monster)
		if not _got_hit:
			continue

		var want_normal := not _last_was_critical and not normal_done
		var want_crit := _last_was_critical and not crit_done
		if not (want_normal or want_crit):
			continue

		var label := "critical" if _last_was_critical else "normal"
		var sample := await _observe(label)
		_report[label] = sample
		if _last_was_critical:
			crit_done = true
		else:
			normal_done = true

	_report["normal_captured"] = normal_done
	_report["critical_captured"] = crit_done


## Real input: warp the OS cursor, feed a motion event so the viewport mouse
## position follows, then press and release the "click" action.
func _click(monster: JamoMonster) -> void:
	var screen: Vector2 = _camera.unproject_position(monster.get_hit_position())
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await get_tree().process_frame

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	Input.parse_input_event(press)
	await get_tree().process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen
	release.global_position = screen
	Input.parse_input_event(release)
	_clicks += 1
	await get_tree().process_frame


## Records the damage number's look, the camera shake envelope, and a colour
## plus a greyscale screenshot, so the critical cue can be judged without
## relying on hue.
func _observe(label: String) -> Dictionary:
	var sample: Dictionary = {"amount": _last_amount}

	var number := _find_damage_number()
	if number != null:
		var text_label: Label3D = number.get_node("Label3D")
		sample["label_text"] = text_label.text
		sample["label_pixel_size"] = text_label.pixel_size
		sample["label_modulate"] = str(text_label.modulate)
		sample["label_outline_modulate"] = str(text_label.outline_modulate)

	# Capture while the number is still opaque; the shake outlives it.
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/play_%s.png" % [ARTIFACT_DIR, label])
	_save_greyscale(image, "%s/play_%s_greyscale.png" % [ARTIFACT_DIR, label])

	sample["max_shake_offset"] = await _sample_shake()
	return sample


## Peak displacement of ShakePivot from rest over the next half second.
func _sample_shake() -> float:
	var peak := 0.0
	for _frame in 40:
		peak = maxf(peak, _pivot.position.length())
		await get_tree().process_frame
	return peak


## The newest damage number. Several are alive at once at this click rate, and
## only the last one belongs to the hit just observed.
func _find_damage_number() -> Node3D:
	var children := _fx_root.get_children()
	for i in range(children.size() - 1, -1, -1):
		if children[i].get("is_critical") != null:
			return children[i] as Node3D
	return null


func _save_greyscale(source: Image, path: String) -> void:
	var grey := Image.create_empty(
		source.get_width(), source.get_height(), false, Image.FORMAT_RGB8
	)
	for y in source.get_height():
		for x in source.get_width():
			var c: Color = source.get_pixel(x, y)
			var v: float = c.get_luminance()
			grey.set_pixel(x, y, Color(v, v, v, 1.0))
	grey.save_png(path)


func _pick_alive_monster() -> JamoMonster:
	for child in _monster_root.get_children():
		var monster := child as JamoMonster
		if monster != null and monster.is_alive():
			return monster
	return null


func _wait_for_monster() -> void:
	for _frame in 600:
		if _pick_alive_monster() != null:
			return
		await get_tree().process_frame


func _write_report() -> void:
	var file := FileAccess.open("%s/play_report.json" % ARTIFACT_DIR, FileAccess.WRITE)
	if file == null:
		push_error("QA harness: cannot write the play report.")
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
