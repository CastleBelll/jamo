extends Node

## Headless check for the doc v0.4 Phase 0 completion criterion:
## "Wave 1 을 시작하고 실패 후 Main Hub 로 돌아올 수 있다."
## Run: godot --headless --path . res://tests/test_run_flow.tscn
##
## The whole path is walked through the real scenes and the real buttons -
## hub -> RUN 시작 -> Wave 1 -> defeat -> 결과 화면 -> 메인 허브로 - including the
## engine scene swaps, so a broken wiring fails here rather than in play.
##
## Each loaded scene is installed as the tree's current scene, because that is
## what change_scene_to_file() replaces. The test node itself therefore has to
## stay off that slot, or the first press would free the test mid-run.

const HUB_SCENE := "res://scenes/ui/title_screen.tscn"
const RUN_SCENE := "res://scenes/main/main.tscn"
const HUB_ROOT_NAME := "TitleScreen"
const RUN_ROOT_NAME := "Main"
## Frames to wait for a scene or a panel before declaring the flow stuck.
const WAIT_FRAME_BUDGET := 600

var _failures: int = 0


func _ready() -> void:
	# Start from a clean slate so a developer save cannot change the result.
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()

	await _run()

	SaveManager.delete_save()
	if _failures == 0:
		print("OK - Wave 1 started, the run failed, and the hub came back.")
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
	var hub: Node = await _enter(HUB_SCENE)
	if hub == null:
		return

	print("-- hub, first launch")
	_check(
		not hub.get_node("%ContinueButton").visible,
		"with no run on disk RUN 이어하기 must not be on screen"
	)
	_check(
		hub.get_node("%NewGameButton").has_focus(),
		"RUN 시작 takes the entry focus when there is nothing to continue"
	)
	for plate_name: String in [
		"NewGameButton", "UpgradeButton", "CodexButton", "RecordsButton",
		"SettingsButton", "QuitButton",
	]:
		_check(
			hub.get_node_or_null("%" + plate_name) != null,
			"the hub menu is missing %s (doc v0.4 section 27)" % plate_name
		)
	_check(
		hub.get_node("%StatGoldValue").text == "0 G",
		"the growth readout starts at 0 G, got %s"
			% hub.get_node("%StatGoldValue").text
	)
	_check(
		hub.get_node("%StatWaveValue").text == "1",
		"the best wave starts at 1, got %s" % hub.get_node("%StatWaveValue").text
	)

	print("-- hub panels open")
	for pair: Array in [
		["%UpgradeButton", "%UpgradeShop"],
		["%CodexButton", "%Codex"],
		["%RecordsButton", "%Records"],
		["%SettingsButton", "%Settings"],
	]:
		var panel: Control = hub.get_node(pair[1] as String)
		(hub.get_node(pair[0] as String) as Button).pressed.emit()
		await get_tree().process_frame
		_check(panel.visible, "%s did not open %s" % [pair[0], pair[1]])
		panel.hide()
		await get_tree().process_frame

	print("-- RUN 시작")
	(hub.get_node("%NewGameButton") as Button).pressed.emit()
	_check(RunState.is_active, "pressing RUN 시작 starts a run")
	_check(RunState.current_wave == 1, "a new run starts on Wave 1")
	_check(
		RunState.core_hp == MetaState.get_core_max_hp() and RunState.core_hp > 0.0,
		"the 문장핵 starts at full HP"
	)
	_check(SaveManager.has_run_save(), "the fresh run is written out at once")

	var main: Node = await _await_scene(RUN_ROOT_NAME)
	if main == null:
		_check(false, "RUN 시작 never reached %s" % RUN_SCENE)
		return
	var hud: Control = main.get_node("UI/HUD")
	var result: Control = main.get_node("UI/RunResult")
	_check(
		hud.get_node("%WaveLabel").text == "WAVE 1",
		"the HUD shows the wave, got %s" % hud.get_node("%WaveLabel").text
	)
	_check(
		not result.visible,
		"the result screen is not up while the run is still going"
	)

	print("-- play until the run fails")
	var gold_before: float = MetaState.gold
	RunState.add_gold(75.0)
	RunState.add_run_statistic("kills", 5.0)
	_check(
		MetaState.gold == gold_before + 75.0,
		"gold earned during the run lands in MetaState straight away"
	)

	# Phase 0 stands the defeat in with energy exhaustion; see main.gd.
	while RunState.spend_click_energy():
		pass
	var waited := 0
	while not result.visible and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the result screen never appeared after the run ended")
	if not result.visible:
		return

	print("-- result screen")
	_check(not RunState.is_active, "the run is over")
	_check(
		result.get_node("%ResultWaveLabel").text.contains("1"),
		"the result reports the wave reached, got %s"
			% result.get_node("%ResultWaveLabel").text
	)
	_check(
		result.get_node("%ResultGoldLabel").text.contains("75"),
		"the result reports the gold earned, got %s"
			% result.get_node("%ResultGoldLabel").text
	)
	_check(
		MetaState.gold == gold_before + 75.0,
		"the defeat did not take the earned gold back (doc v0.4 section 14)"
	)
	_check(
		not SaveManager.has_run_save(),
		"a defeated run is gone from disk before the result is even dismissed"
	)
	_check(SaveManager.has_save(), "permanent progress is still on disk")

	print("-- back to the hub")
	(result.get_node("%ResultHubButton") as Button).pressed.emit()
	var hub_again: Node = await _await_scene(HUB_ROOT_NAME)
	if hub_again == null:
		_check(false, "메인 허브로 never reached %s" % HUB_SCENE)
		return
	_check(
		not hub_again.get_node("%ContinueButton").visible,
		"a failed run must not come back as RUN 이어하기"
	)
	_check(
		hub_again.get_node("%StatGoldValue").text.contains("75"),
		"the hub shows the gold the failed run earned, got %s"
			% hub_again.get_node("%StatGoldValue").text
	)


## Loads a scene and hands it the current-scene slot, which is what the game's
## own change_scene_to_file() calls replace.
func _enter(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_check(false, "could not load %s" % path)
		return null
	var scene: Node = packed.instantiate()
	# The root is still setting up its own children on the very first frame, so
	# a direct add_child() there is refused.
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	return scene


## Waits for a change_scene_to_file() to land. The swap is deferred to the end of
## the frame, so the new root only shows up a frame or two later.
func _await_scene(root_name: String) -> Node:
	var waited := 0
	while waited < WAIT_FRAME_BUDGET:
		var current: Node = get_tree().current_scene
		if current != null and current.name == root_name and current.is_inside_tree():
			await get_tree().process_frame
			return current
		await get_tree().process_frame
		waited += 1
	return null
