extends Node
## Headless checks for P5-1: settings (G10 설정 row), SFX voice rules (B11), local run log
## (B12), idle motion under VisualPivot with 움직임 줄이기 (G11), status labels and G12
## feedback wiring, focus-loss pause and Esc order (G10).

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const MONSTER := preload("res://scenes/monsters/jamo_monster.tscn")
const LIBRARY := preload("res://scenes/hub/last_library.tscn")

var failures: Array[String] = []
var db: ContentDB


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_settings.json"
	Meta.new_profile()
	RunLog.enabled = true  # tests never leave run logs behind unless they test the logger
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid: %s" % db.validate()[0])
	else:
		_check_settings()
		_check_sfx()
		_check_log()
		_check_motion_and_status()
		_check_run_game()
		_check_qa_fixes()
		_check_input_shield()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_settings: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_settings() -> void:
	Meta.new_profile()
	_expect(int(Meta.setting("shake")) == 50 and bool(Meta.setting("flash")) and int(Meta.setting("text_scale")) == 100, "B11 defaults: shake 50, flash on, text 100")
	_expect(SettingsService.volume_db(0) == -80.0 and is_equal_approx(SettingsService.volume_db(100), 0.0), "volume 0 mutes, 100 is 0 dB")
	SettingsService.set_and_save("sfx", 250)
	_expect(int(Meta.setting("sfx")) == 100, "volume clamped to 100")
	SettingsService.set_and_save("master", 0)
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "0 volume mutes the bus")
	SettingsService.set_and_save("master", 80)
	_expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "unmuted again")
	_expect(AudioServer.get_bus_index("BGM") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("UI") >= 0, "Master/BGM/SFX/UI buses exist")
	SettingsService.set_and_save("text_scale", 125)
	SettingsService.set_and_save("shake", 0)
	SettingsService.set_and_save("flash", false)
	SettingsService.set_and_save("text_scale", 137)
	_expect(int(Meta.setting("text_scale")) == 100, "invalid text scale falls back to 100")
	SettingsService.set_and_save("text_scale", 150)
	Meta.load_profile()
	_expect(int(Meta.setting("text_scale")) == 150 and int(Meta.setting("shake")) == 0 and not bool(Meta.setting("flash")), "settings persist to disk")
	_expect(is_equal_approx(SettingsService.shake_factor(), 0.0) and not SettingsService.flash_enabled(), "accessibility flags read back")
	var root := Control.new()
	root.theme = Theme.new()
	root.theme.default_font_size = 28
	SettingsService.apply_text_scale(root, 150)
	_expect(root.theme.default_font_size == 42, "150%% text scale = 42px on the theme")
	root.free()
	Meta.new_profile()


func _check_sfx() -> void:
	Sfx.reset()
	Sfx.set_boss_layer(true)
	_expect(Sfx.boss_layer_on, "boss layer flag turns on")
	Sfx.set_boss_layer(false)
	_expect(not Sfx.boss_layer_on, "boss layer flag turns off")
	_expect(Sfx.play_ui("ui_click") and not Sfx.play_ui("ui_click"), "UI click respects the same-sound gap")
	_expect(Sfx.process_mode == Node.PROCESS_MODE_ALWAYS, "Sfx keeps ticking while menus pause the tree")
	_expect(Sfx.active_voices() == 0, "UI sounds never take an SFX voice")
	var probe := Button.new()
	probe.name = "SetupBackButton"
	add_child(probe)
	_expect(Sfx._ui_sound_for(probe) == "ui_cancel", "Back buttons cancel")
	probe.theme_type_variation = &"PrimaryButton"
	_expect(Sfx._ui_sound_for(probe) == "ui_confirm", "primary buttons confirm")
	_expect(probe.pressed.get_connections().size() == 1, "every button gets the UI click hook on enter")
	probe.free()
	for id in ["ui_click", "ui_confirm", "ui_cancel", "ui_hover", "boss_purified"]:
		_expect(Sfx.streams.has(id), "audio asset registered: %s" % id)
	_expect(Sfx.layer_player.stream != null and Sfx.layer_player.stream.loop, "boss layer stream loaded and looping")
	if Sfx.layer_player.stream != null:
		var combat: AudioStream = load("res://art/audio/bgm_combat.ogg")
		_expect(is_equal_approx(snappedf(combat.get_length(), 0.01), snappedf(Sfx.layer_player.stream.get_length(), 0.01)), "boss layer matches the combat loop length")
	_expect(Sfx.play("hit_ink", 0, 1.0), "first sound plays")
	_expect(not Sfx.play("hit_ink", 0, 1.0), "same sound within 0.05s is dropped")
	Sfx.clock += 0.06
	_expect(Sfx.play("hit_ink", 0, 1.0), "same sound after the gap plays")
	for i in 6:
		Sfx.clock += 0.06
		Sfx.play("s%d" % i, 0, 1.0)
	_expect(Sfx.active_voices() == 8, "eight voices active (cap)")
	Sfx.clock += 0.06
	_expect(not Sfx.play("extra", 0, 1.0), "ninth ordinary voice refused")
	_expect(Sfx.play("boss_warning", Sfx.PRIORITY_WARNING, 1.0) and Sfx.active_voices() == 8, "boss warning evicts a lower voice and keeps the cap")
	Sfx.clock += 2.0
	_expect(Sfx.active_voices() == 0, "voices expire")


func _check_log() -> void:
	RunLog.begin_run("test:1", 42, Meta.CONTENT_VERSION, ["R_SAFE_1"], "starter_a")
	RunLog.event("purify", {"wave": 1, "entity": 3})
	var rows := RunLog.read_all()
	_expect(rows.size() == 2 and rows[0]["kind"] == "run_start" and int(rows[0]["seed"]) == 42 and rows[0]["deck"] == "starter_a", "run_start line with seed/deck/research")
	_expect(rows[0]["content_version"] == Meta.CONTENT_VERSION and rows[1]["kind"] == "purify" and rows[1]["run_id"] == "test:1", "events carry run id and content version")
	RunLog.event("spawn", {"t": 3.5})
	var last := RunLog.read_all()[-1]
	_expect(last.has("ms") and is_equal_approx(float(last["t"]), 3.5), "wall clock in ms, wave clock t preserved")
	_expect(RunLog.path.begins_with("user://logs/"), "log stays local under user://logs")
	var path := RunLog.path
	RunLog.end_run()
	_expect(RunLog.path == "" and FileAccess.file_exists(path), "end_run closes the log and keeps the file")
	DirAccess.remove_absolute(path)


func _check_motion_and_status() -> void:
	var m: JamoMonster = MONSTER.instantiate()
	m.jamo = "ㄱ"
	add_child(m)
	var profile: MotionProfile = db.motion_profiles["BOUNCE"]
	m.alive = true
	m.set_motion(profile, 1.0)
	m._process(0.2)
	_expect(m.visual_pivot.position.y < 0.0 or absf(m.visual_pivot.rotation) > 0.0, "motion profile moves the VisualPivot")
	_expect(m.position == Vector2.ZERO, "the root (click circle) never moves with the idle motion")
	m.set_motion(profile, 0.0)
	m._process(0.2)
	_expect(m.visual_pivot.position == Vector2.ZERO and m.visual_pivot.rotation == 0.0, "움직임 줄이기: zero displacement")
	m.apply_burn(0.8, 3.0, 0.0)
	m.apply_poison(4.0, 3, 0.35, 0.0)
	m.apply_poison(4.0, 3, 0.35, 0.0)
	m.apply_slow(0.2, 2.0, 0.0)
	m.refresh_status_label(0.5)
	var text: String = m.get_node("StatusAnchor/StatusLabel").text
	_expect(text == "3 x2 2", "status label shows time, stacks and time next to the icons (%s)" % text)
	_expect(m.get_node("StatusAnchor/Icon_burn").visible and m.get_node("StatusAnchor/Icon_poison").visible and m.get_node("StatusAnchor/Icon_slow").visible, "status icons visible for burn, poison and slow")
	_expect(m.get_node("VisualPivot/Sprite2D").texture != null and not m.get_node("VisualPivot/Glyph").visible, "glyph sprite replaces the label when the art exists")
	m.free()


func _check_run_game() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	Meta.settings["shake"] = 100
	var game := RUN_GAME.instantiate()
	game.run_seed = 3
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	_expect(game.get_node("%Banner").visible and game.get_node("%Banner").text == "Wave 1", "prep banner")
	_expect(RunLog.path != "" and RunLog.read_all()[0]["kind"] == "run_start", "run log opened with the run")
	run.begin_combat()
	director.tick(0.0)
	_expect(director.enemies[0].motion != null, "spawned enemies get their motion profile")
	var sentence: Node2D = game.get_node("CorruptedPage/LastSentence")
	run.damage_stability(8.0)
	_expect(sentence.position.x <= 3.0 and sentence.position.x >= -3.0, "sentence shake stays within 3px")
	var kinds := []
	for r in RunLog.read_all():
		kinds.append(r["kind"])
	_expect("wave_start" in kinds and "spawn" in kinds, "wave start and spawns logged")
	# Focus loss pauses combat; Esc closes settings before the pause menu.
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(get_tree().paused and game.get_node("%PausePanel").visible, "focus loss auto-pauses combat")
	game.get_node("%PauseSettingsButton").pressed.emit()
	_expect(game.get_node("%SettingsPanel").visible, "settings open from the pause menu")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	game._unhandled_input(esc)
	_expect(not game.get_node("%SettingsPanel").visible and game.get_node("%PausePanel").visible and get_tree().paused, "Esc closes settings first, pause stays")
	game._unhandled_input(esc)
	_expect(not game.get_node("%PausePanel").visible and not get_tree().paused, "second Esc resumes")
	var log_path := RunLog.path
	run.damage_stability(200.0)
	_expect(RunLog.path == "", "log closed at the result")
	RunLog.path = log_path
	kinds.clear()
	for r in RunLog.read_all():
		kinds.append(r["kind"])
	RunLog.path = ""
	_expect("result" in kinds and "wave_clear" not in kinds, "result logged (no clear on a failed wave)")
	DirAccess.remove_absolute(log_path)
	game.free()


## QA fixes: embedded settings never hide, 흔들림 previews on live monsters, B12 log fields.
func _check_qa_fixes() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	var lib := LIBRARY.instantiate()
	add_child(lib)
	var panel := lib.get_node("%SettingsPanel")
	_expect(panel.visible and panel.embedded and panel.get_node("%CloseButton").text == "서고로", "library settings tab: embedded, close reads 서고로")
	lib.get_node("%Tabs").current_tab = 4
	panel.get_node("%CloseButton").pressed.emit()
	_expect(panel.visible and lib.get_node("%Tabs").current_tab == 0, "embedded close returns to the 서고 tab and keeps the panel")
	lib.free()
	Meta.settings["shake"] = 100
	RunLog.enabled = true
	var game := RUN_GAME.instantiate()
	game.run_seed = 5
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	run.begin_combat()
	director.tick(0.0)
	var e: JamoMonster = director.enemies[0]
	_expect(is_equal_approx(e.motion_scale, 1.0), "spawned with shake 100%%")
	SettingsService.set_and_save("shake", 0)
	_expect(is_equal_approx(e.motion_scale, 0.0) and e.visual_pivot.position == Vector2.ZERO, "changing 흔들림 previews on monsters already on the field")
	SettingsService.set_and_save("shake", 50)
	_expect(is_equal_approx(e.motion_scale, 0.5), "and back to 50%%")
	director.set_hold(true)
	director.tick(0.3, e.global_position)
	director.set_hold(false)
	run.drops.pity_misses = 0
	e.hp = 0.5
	director.request_click(e.global_position)
	director.tick(0.3)
	director.clear_enemies()
	run.on_wave_cleared()
	var reward := run.build_reward()
	reward.add(0)
	run.finish_clear()
	var forge := run.start_forge()
	forge.reroll()
	var kinds := []
	var clear_row := {}
	for r in RunLog.read_all():
		kinds.append(r["kind"])
		if r["kind"] == "wave_clear":
			clear_row = r
	_expect("forge_hand" in kinds and "forge_reroll" in kinds and "reward_action" in kinds, "Forge hand/reroll and reward actions logged (%s)" % [kinds])
	_expect(clear_row.has("hold_time") and float(clear_row["hold_time"]) > 0.25 and clear_row.has("damage_by_source") and clear_row["damage_by_source"].has("manual"), "wave_clear logs hold time and damage by source")
	var log_path := RunLog.path
	game.free()
	RunLog.end_run()
	if log_path != "":
		DirAccess.remove_absolute(log_path)


## Clicks aimed at the last enemy must not land on the 자모 정리 / Forge / result buttons.
func _check_input_shield() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	var game := RUN_GAME.instantiate()
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	var shield: Control = game.get_node("%InputShield")
	_expect(not shield.visible, "no shield during prep")
	run.begin_combat()
	director.set_hold(true)
	director.clear_enemies()
	run.on_wave_cleared()
	_expect(shield.visible and shield.mouse_filter == Control.MOUSE_FILTER_STOP and not director.hold_pressed, "wave clear raises the input shield and drops the held click")
	_expect(shield.get_index() > game.get_node("UI/Panels/Center").get_index(), "shield is drawn above the panels")
	await game.shield_timer.timeout
	_expect(not shield.visible, "shield drops after %.2fs" % game.INPUT_SHIELD_SECONDS)
	game.get_node("%ClearPanel").get_node("%FinishButton").pressed.emit()
	_expect(shield.visible, "Forge also opens shielded")
	game.free()
