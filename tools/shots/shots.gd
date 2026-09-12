extends Node
## Screenshot harness (not a test): boots each screen with a scratch profile and writes PNGs
## to user://shots/. Run with a window: `godot --path . tools/shots/shots.tscn`.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const LIBRARY := preload("res://scenes/hub/last_library.tscn")
const OUT := "user://shots/"


func _ready() -> void:
	Meta.saver.path = "user://shots_profile.json"
	RunLog.enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _shoot_library()
	await _shoot_run()
	get_tree().quit()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("shot ", name)


func _shoot_library() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	Meta.title_seen = false
	Meta.gold = 120
	Meta.best_reached = 6
	var lib := LIBRARY.instantiate()
	add_child(lib)
	await _snap("01_title")
	lib._dismiss_title()
	await _snap("02_hub")
	for i in range(1, lib.get_node("%Tabs").get_tab_count()):
		lib.get_node("%Tabs").current_tab = i
		await _snap("03_tab_%d" % i)
	lib.get_node("%Tabs").current_tab = 0
	lib._open_setup()
	await _snap("04_setup")
	lib.get_node("%RunSetup").visible = false
	Meta.run = {"wave": 3}
	lib._refresh()
	await _snap("05_hub_suspended")
	Meta.run = {}
	lib.queue_free()
	await get_tree().process_frame


func _shoot_run() -> void:
	var game := RUN_GAME.instantiate()
	add_child(game)
	var run: RunController = game.get_node("RunController")
	await _snap("10_prep")
	game.get_node("%StartWaveButton").pressed.emit()
	await get_tree().create_timer(4.0).timeout
	await _snap("11_combat")
	await get_tree().create_timer(3.0).timeout
	await _snap("12_combat_late")
	run.on_wave_cleared()
	await _snap("13_clear")
	game.get_node("%ClearPanel").get_node("%FinishButton").pressed.emit()
	await _snap("14_forge")
	game.get_node("%ForgePanel").get_node("%FinishButton").pressed.emit()
	game.get_node("%StartWaveButton").pressed.emit()
	await get_tree().create_timer(1.0).timeout
	game._open_pause()
	await _snap("15_pause")
	game._close_pause()
	run.damage_stability(200.0)
	await _snap("16_result")
	game.queue_free()
	await get_tree().process_frame
	await _shoot_boss()


## W5 boss fight: walk the RUN through four Waves the way tests do, then start W5.
func _shoot_boss() -> void:
	var game := RUN_GAME.instantiate()
	game.run_seed = 5
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	for i in 4:
		run.begin_combat()
		director.clear_enemies()
		run.on_wave_cleared()
		run.finish_clear()
		run.finish_forge()
	game.get_node("%StartWaveButton").pressed.emit()
	await get_tree().create_timer(3.0).timeout
	await _snap("17_boss")
	game.queue_free()
	await get_tree().process_frame
	await _shoot_forge_loaded()


## Forge with a full RUN behind it (W12, six held words, candidates/replace/compound rows):
## the layout risk the empty W1 Forge never shows.
func _shoot_forge_loaded() -> void:
	var bot := B12Bot.new()
	bot.direction = &"무기"
	bot.boot(RUN_GAME, ContentDB.load_all(), 11, self)
	bot.play_run(11)
	if bot.play_wave():
		B12Sim.reward_policy(bot.db, bot.run, bot.run.build_reward(), bot.direction)
		bot.run.finish_clear()  # the scene opens the Forge panel on this phase change
		await get_tree().process_frame
		var panel := bot.game.get_node("%ForgePanel")
		var list: Array = bot.run.forge.candidates()
		if not list.is_empty():
			panel._select(list[0]["word"].id)
		await _snap("18_forge_loaded")
	bot.free_game()
