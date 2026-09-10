extends Node

## QA P0: the doc v0.4 section 48 Phase 0 completion criterion, walked with real
## input in a real window and photographed at every step.
##
## The DEV harness tests/test_run_flow.gd walks the same path headlessly and
## drives the buttons with pressed.emit(). This one exists to check what that
## cannot: that the plates are actually clickable where they are drawn, that the
## monsters are actually clickable in the arena, and that the save file on disk
## carries the right block at each point of the path (doc v0.4 sections 44, 45).
##
## Path: Main Hub -> RUN 시작 -> Wave 1 -> defeat -> result -> Main Hub,
## then suspend/resume, then a v0.3 save migration.
##
## Run windowed (NOT --headless):
##   godot --path . res://tests/qa_p0_flow.tscn
## The player save is stashed and put back, so nothing on disk is destroyed.

const HUB_SCENE := "res://scenes/ui/title_screen.tscn"
const RUN_SCENE := "res://scenes/main/main.tscn"
const HUB_ROOT_NAME := "TitleScreen"
const RUN_ROOT_NAME := "Main"
const OUT_DIR := "res://tests/qa_artifacts/p0/flow"
const BACKUP_PATH := "user://jamo_save.json.p0flowbak"
const WAIT_FRAME_BUDGET := 900
## Enough clicks to drain 20 energy even when several land on a dying monster.
const MAX_CLICKS := 400

## A v0.3 file exactly as the DEV handoff describes it.
const LEGACY_SAVE := {
	"save_version": 1,
	"day": 42,
	"gold": 1234.5,
	"upgrade_levels": {"click_damage": 3},
	"unlocked_words": ["fire_001"],
	"jamo_inventory": {"ㅂ": 2},
	"target_word": "fire_002",
}

## Run fields that must never appear inside the permanent block, and permanent
## fields that must never appear inside the run block. Doc v0.4 section 3.
const RUN_ONLY_KEYS: Array[String] = [
	"current_wave", "core_hp", "core_max_hp", "current_energy",
	"jamo_draw_bag", "equipped_words", "run_word_ranks", "run_statistics",
]
const META_ONLY_KEYS: Array[String] = [
	"gold", "permanent_upgrade_levels", "codex_words", "highest_wave",
	"defeated_word_bosses", "statistics",
]

var _failures: int = 0
var _shot_index: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_stash_save()
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()

	await _walk_the_phase_0_path()
	await _walk_the_suspend_and_resume_path()
	await _walk_the_v03_migration()

	SaveManager.delete_save()
	_restore_save()
	if _failures == 0:
		print("OK - the Phase 0 path, the resume rules and the v0.3 migration all held.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


# --- The Phase 0 completion criterion --------------------------------------

func _walk_the_phase_0_path() -> void:
	print("-- 1. Main Hub, first launch")
	var hub: Node = await _enter(HUB_SCENE)
	if hub == null:
		return
	await _shoot("hub_first_launch")
	_check(not hub.get_node("%ContinueButton").visible,
		"RUN 이어하기 is off screen when there is no run to continue")
	_report_growth(hub)

	print("-- 2. RUN 시작, clicked where it is drawn")
	await _click_control(hub.get_node("%NewGameButton"))
	var main: Node = await _await_scene(RUN_ROOT_NAME)
	if main == null:
		_check(false, "clicking RUN 시작 never reached %s" % RUN_SCENE)
		return
	await _settle()
	var hud: Control = main.get_node("UI/HUD")
	var result: Control = main.get_node("UI/RunResult")
	await _shoot("wave1_start")
	_check(hud.get_node("%WaveLabel").text == "WAVE 1",
		"the HUD reads WAVE 1, got %s" % hud.get_node("%WaveLabel").text)
	_check(not hud.get_node("%WaveLabel").text.to_upper().contains("DAY"),
		"no DAY wording is left in the HUD")
	print("    HUD: %s | %s | %s | %s | %s" % [
		hud.get_node("%WaveLabel").text, hud.get_node("%CoreLabel").text,
		hud.get_node("%EnergyLabel").text, hud.get_node("%GoldLabel").text,
		hud.get_node("%KillsLabel").text,
	])
	_check_save_blocks("run in progress", true)

	print("-- 3. play: real clicks on real monsters until the energy runs out")
	var gold_before: float = MetaState.gold
	await _drain_energy_by_clicking()
	_check(RunState.current_energy == 0,
		"the energy actually reached 0, got %d" % RunState.current_energy)
	_check(MetaState.gold > gold_before,
		"killing monsters banked gold into MetaState during the run")
	var earned: float = MetaState.gold - gold_before

	print("-- 4. result screen")
	var waited: int = 0
	while not result.visible and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the RUN 종료 result screen appeared")
	if not result.visible:
		return
	await _settle()
	await _shoot("run_result")
	print("    result: %s | %s | %s" % [
		result.get_node("%ResultWaveLabel").text,
		result.get_node("%ResultKillsLabel").text,
		result.get_node("%ResultGoldLabel").text,
	])
	_check(result.get_node("%ResultWaveLabel").text.contains("WAVE"),
		"the result names the wave reached")
	_check(result.get_node("%ResultGoldLabel").text.contains("GOLD"),
		"the result names the gold earned")
	_check(not RunState.is_active, "the run is over")
	_check(not SaveManager.has_run_save(),
		"the defeated run is already off the disk at the result screen")
	_check_save_blocks("after the defeat", false)

	print("-- 5. back to the Main Hub")
	await _click_control(result.get_node("%ResultHubButton"))
	var hub_again: Node = await _await_scene(HUB_ROOT_NAME)
	if hub_again == null:
		_check(false, "메인 허브로 never reached %s" % HUB_SCENE)
		return
	await _settle()
	await _shoot("hub_after_defeat")
	_check(not hub_again.get_node("%ContinueButton").visible,
		"a defeated run must not come back as RUN 이어하기 (doc v0.4 section 44)")
	_check(MetaState.gold >= earned,
		"the gold the failed run earned is still in MetaState")
	_report_growth(hub_again)
	hub_again.queue_free()
	await get_tree().process_frame


# --- Suspend and resume, and what a defeat does to it -----------------------

func _walk_the_suspend_and_resume_path() -> void:
	print("-- 6. suspend a run from the pause menu")
	var hub: Node = await _enter(HUB_SCENE)
	if hub == null:
		return
	var gold_at_hub: float = MetaState.gold
	await _click_control(hub.get_node("%NewGameButton"))
	var main: Node = await _await_scene(RUN_ROOT_NAME)
	if main == null:
		_check(false, "the second RUN 시작 never reached the run scene")
		return
	await _settle()
	# Spend a little so the resumed run is distinguishable from a fresh one.
	await _click_monsters(6)
	var suspended_energy: int = RunState.current_energy
	var gold_in_run: float = MetaState.gold
	_check(suspended_energy < RunState.get_max_energy(),
		"some energy was actually spent before suspending")

	var pause: Control = main.get_node("UI/PauseMenu")
	pause.open()
	await _settle()
	await _shoot("pause_menu")
	await _click_control(pause.get_node("%HubButton"))
	var hub2: Node = await _await_scene(HUB_ROOT_NAME)
	if hub2 == null:
		_check(false, "저장 후 메인 허브로 never reached the hub")
		return
	await _settle()
	await _shoot("hub_with_continue")
	_check(hub2.get_node("%ContinueButton").visible,
		"an interrupted run comes back as RUN 이어하기")
	print("    continue line: %s" % hub2.get_node("%ContinueInfoLabel").text)
	_check(MetaState.gold == gold_in_run,
		"leaving mid-run kept the gold: %f vs %f" % [MetaState.gold, gold_in_run])
	_check(MetaState.gold >= gold_at_hub, "gold never went backwards")
	_check_save_blocks("suspended run", true)

	print("-- 7. RUN 이어하기 comes back on the same wave and energy")
	await _click_control(hub2.get_node("%ContinueButton"))
	var main2: Node = await _await_scene(RUN_ROOT_NAME)
	if main2 == null:
		_check(false, "RUN 이어하기 never reached the run scene")
		return
	await _settle()
	await _shoot("resumed_run")
	_check(RunState.current_wave == 1,
		"the resumed run is on the wave it was left on, got %d" % RunState.current_wave)
	_check(RunState.current_energy == suspended_energy,
		"the resumed run has the energy it was left with: %d vs %d"
			% [RunState.current_energy, suspended_energy])

	print("-- 8. lose the resumed run: it must not be resumable again")
	await _drain_energy_by_clicking()
	var result: Control = main2.get_node("UI/RunResult")
	var waited: int = 0
	while not result.visible and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the resumed run also reaches the result screen")
	if not result.visible:
		return
	await _click_control(result.get_node("%ResultHubButton"))
	var hub3: Node = await _await_scene(HUB_ROOT_NAME)
	if hub3 == null:
		_check(false, "the hub never came back after the second defeat")
		return
	await _settle()
	await _shoot("hub_after_second_defeat")
	_check(not hub3.get_node("%ContinueButton").visible,
		"the defeated run is gone from the hub for good")
	_check_save_blocks("after the second defeat", false)
	_check(RunState.equipped_words.is_empty() and RunState.run_statistics.is_empty(),
		"RunState is empty at the hub after a defeat")
	_check(MetaState.gold > 0.0, "MetaState still holds the gold both runs earned")
	_report_growth(hub3)
	hub3.queue_free()
	await get_tree().process_frame


# --- v0.3 save migration ----------------------------------------------------

func _walk_the_v03_migration() -> void:
	print("-- 9. a real v0.3 save file is opened, not thrown away")
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(LEGACY_SAVE, "\t"))
	file.close()

	var hub: Node = await _enter(HUB_SCENE)
	if hub == null:
		return
	await _settle()
	await _shoot("hub_v03_migrated")
	_check(SaveManager.migrated_from_v03, "the hub reports the migration")
	_check(hub.get_node("%MigrationNoteLabel").visible,
		"the hub shows the yellow v0.3 notice so the player is told what happened")
	print("    notice: %s" % hub.get_node("%MigrationNoteLabel").text)
	_check_migration_note_is_readable(hub)
	_check(int(floorf(MetaState.gold)) == 1234,
		"gold survived the migration, got %f" % MetaState.gold)
	_check(MetaState.get_upgrade_level(MetaState.UPGRADE_CLICK_DAMAGE) == 3,
		"upgrade levels survived the migration")
	_check(MetaState.has_codex_word(&"fire_001"),
		"an unlocked v0.3 word became a codex entry")
	_check(MetaState.highest_wave == 1,
		"Day 42 was not handed over as a Wave 42 record, got %d" % MetaState.highest_wave)
	_check(not hub.get_node("%ContinueButton").visible,
		"a v0.3 file offers no run to continue")
	_report_growth(hub)

	# Doc v0.4 section 38: the codex entry alone must not switch its effect on.
	_check(not RunState.is_word_equipped(&"fire_001"),
		"the migrated word is known, not equipped")
	_check(RunState.get_burn_effect() == null,
		"a codex word does not grant its effect before a run equips it")

	var rewritten: Dictionary = SaveManager.peek_save()
	_check(int(rewritten.get("save_version", 0)) == SaveManager.SAVE_VERSION,
		"the file was rewritten in the v0.4 shape")
	_check(rewritten.has("legacy_v03"),
		"the original v0.3 payload is kept under legacy_v03")
	var legacy: Dictionary = rewritten.get("legacy_v03", {})
	_check(int(legacy.get("day", 0)) == 42,
		"the kept payload still holds Day 42")
	_check(String(legacy.get("target_word", "")) == "fire_002",
		"even the fields v0.4 has no use for are kept in legacy_v03")
	print("    file keys: %s" % str(rewritten.keys()))

	print("-- 10. the migrated shop shows the carried-over levels, no Day gates")
	var shop: Control = hub.get_node("%UpgradeShop")
	shop.open()
	await _settle()
	await _shoot("shop_after_migration")
	_check_no_day_wording(shop)
	shop.hide()
	hub.queue_free()
	await get_tree().process_frame


## The migration notice is the only thing that tells a returning player their
## v0.3 progress was kept, so it has to be inside its panel and legible against
## what is drawn behind it. Measured, not eyeballed.
func _check_migration_note_is_readable(hub: Node) -> void:
	var note: Label = hub.get_node("%MigrationNoteLabel")
	var panel: Control = hub.get_node("Safe/Content/GrowthPanel")
	var note_rect: Rect2 = note.get_global_rect()
	var panel_rect: Rect2 = panel.get_global_rect()
	print("    note rect=%s panel rect=%s" % [str(note_rect), str(panel_rect)])
	_check(panel_rect.encloses(note_rect),
		"the v0.3 notice spills outside the 영구 성장 panel: note %s vs panel %s"
			% [str(note_rect), str(panel_rect)])

	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	# Sample the strip the glyphs sit on and take the worst pixel behind them as
	# the background, which is what a WCAG ratio is measured against.
	var text_luma: float = note.get_theme_color(&"font_color").get_luminance()
	var darkest := 1.0
	var brightest := 0.0
	var y: int = int(note_rect.get_center().y)
	for x: int in range(int(note_rect.position.x), int(note_rect.end.x), 4):
		if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
			continue
		var luma: float = image.get_pixel(x, y).get_luminance()
		darkest = minf(darkest, luma)
		brightest = maxf(brightest, luma)
	var worst: float = _contrast_ratio(text_luma, brightest)
	print("    notice contrast: text=%.3f background %.3f..%.3f worst=%.2f:1"
		% [text_luma, darkest, brightest, worst])
	_check(worst >= 4.5,
		"the v0.3 notice only reaches %.2f:1 against what is behind it, want >= 4.5:1"
			% worst)


func _contrast_ratio(a: float, b: float) -> float:
	var lighter: float = maxf(a, b)
	var darker: float = minf(a, b)
	return (lighter + 0.05) / (darker + 0.05)


## Doc v0.4 section 5: the Day axis is gone, so no shop row may still quote it.
func _check_no_day_wording(root: Node) -> void:
	var found: Array[String] = []
	for node: Node in _every_descendant(root):
		var label := node as Label
		if label == null or not label.visible:
			continue
		if label.text.to_upper().contains("DAY"):
			found.append(label.text)
	if found.is_empty():
		print("    no DAY wording anywhere in the shop")
		return
	_check(false, "the shop still quotes DAY: %s" % str(found))


func _every_descendant(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in root.get_children():
		out.append(child)
		out.append_array(_every_descendant(child))
	return out


# --- Save file shape --------------------------------------------------------

## Doc v0.4 sections 44 and 45: meta and run are separate blocks and neither
## carries the other's fields.
func _check_save_blocks(tag: String, expect_run: bool) -> void:
	var data: Dictionary = SaveManager.peek_save()
	var meta: Dictionary = data.get("meta", {})
	var run: Dictionary = data.get("run", {})
	print("    save[%s]: top=%s meta_keys=%d run_present=%s"
		% [tag, str(data.keys()), meta.size(), str(data.has("run"))])

	_check(data.has("meta"), "%s: the file has a meta block" % tag)
	_check(data.has("run") == expect_run,
		"%s: run block present=%s, expected %s" % [tag, str(data.has("run")), str(expect_run)])

	for key: String in RUN_ONLY_KEYS:
		_check(not meta.has(key), "%s: the meta block must not carry %s" % [tag, key])
	for key: String in META_ONLY_KEYS:
		_check(meta.has(key), "%s: the meta block is missing %s" % [tag, key])
	if not expect_run:
		return
	for key: String in META_ONLY_KEYS:
		_check(not run.has(key), "%s: the run block must not carry %s" % [tag, key])
	for key: String in ["current_wave", "core_hp", "current_energy", "equipped_words"]:
		_check(run.has(key), "%s: the run block is missing %s" % [tag, key])

	# Nothing in either block may be a serialised Resource. Doc v0.4 section 45.
	for block: Dictionary in [meta, run]:
		for key: Variant in block:
			var value: Variant = block[key]
			if value is String and String(value).begins_with("res://"):
				_check(false, "%s: %s stores a resource path (%s)" % [tag, key, value])


func _report_growth(hub: Node) -> void:
	print("    growth: GOLD %s | 최고 WAVE %s | 발견 단어 %s | 처치 보스 %s" % [
		hub.get_node("%StatGoldValue").text, hub.get_node("%StatWaveValue").text,
		hub.get_node("%StatWordsValue").text, hub.get_node("%StatBossValue").text,
	])


# --- Real input -------------------------------------------------------------

## Clicks a Control where it is actually drawn, so a plate that is covered or
## mispositioned fails here instead of passing on a pressed.emit().
func _click_control(control: Control) -> void:
	await _settle()
	var point: Vector2 = control.get_global_rect().get_center()
	_warp_to(point)
	await _settle()
	_click_at(point)
	await _settle()


func _click_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)


func _warp_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(event)


## Doc v0.3 section 10, still true in v0.4: energy is only spent on a click that
## actually hits a monster, so the drain is proof the arena is clickable.
func _drain_energy_by_clicking() -> void:
	var maximum: int = RunState.get_max_energy()
	var landed: int = await _click_monsters(MAX_CLICKS)
	print("    landed %d monster clicks, energy %d -> %d"
		% [landed, maximum, RunState.current_energy])


func _click_monsters(budget: int) -> int:
	var landed: int = 0
	for _i in budget:
		if RunState.current_energy <= 0:
			break
		var before: int = RunState.current_energy
		var monster: Node3D = _first_alive_monster()
		if monster == null:
			# The spawner refills on its own timer; wait rather than give up.
			await _settle()
			continue
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			_check(false, "the arena has no current Camera3D to click through")
			return landed
		var point: Vector2 = camera.unproject_position(monster.global_position)
		_warp_to(point)
		await get_tree().process_frame
		_click_at(point)
		await get_tree().process_frame
		await get_tree().process_frame
		if RunState.current_energy < before:
			landed += 1
	return landed


func _first_alive_monster() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as Node3D
		if monster == null or not monster.is_inside_tree():
			continue
		if monster.has_method("is_alive") and not monster.call("is_alive"):
			continue
		return monster
	return null


# --- Scene plumbing ---------------------------------------------------------

## Loads a scene into the current-scene slot, which is what the game's own
## change_scene_to_file() calls replace. The harness node stays off that slot.
func _enter(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_check(false, "could not load %s" % path)
		return null
	var scene: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await _settle()
	return scene


func _await_scene(root_name: String) -> Node:
	var waited: int = 0
	while waited < WAIT_FRAME_BUDGET:
		var current: Node = get_tree().current_scene
		if current != null and current.name == root_name and current.is_inside_tree():
			await get_tree().process_frame
			return current
		await get_tree().process_frame
		waited += 1
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _shoot(tag: String) -> void:
	_shot_index += 1
	await RenderingServer.frame_post_draw
	var path: String = "%s/%02d_%s.png" % [OUT_DIR, _shot_index, tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("    shot: %s" % path)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		ProjectSettings.globalize_path(BACKUP_PATH)
	)


func _restore_save() -> void:
	SaveManager.delete_save()
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	)
