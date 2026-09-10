extends Node

## End-to-end check of the between-day sequence: Day 1 runs out of energy, the
## summary shows, a jamo is picked, the shop opens, and Day 2 starts refilled.
## Run: godot --headless --path . res://tests/test_day_flow.tscn

const MAIN_SCENE := "res://scenes/main/main.tscn"
## Frames to wait for a panel before declaring the flow stuck.
const WAIT_FRAME_BUDGET := 900

var _failures: int = 0


func _ready() -> void:
	# Start from a clean slate so a developer save cannot change the result.
	SaveManager.delete_save()
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await _run(main)

	if _failures == 0:
		print("OK - day flow reached Day 2.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % message)


func _run(main: Node) -> void:
	var ui: Node = main.get_node("UI")
	_check(GameState.day == 1, "a fresh save should start on Day 1")
	_check(GameState.energy == 20, "Day 1 should start with 20 energy")

	if not await _test_clicking_a_monster(main):
		return

	# Spend the rest of the day. In the real game each of these is one click.
	while GameState.energy > 0:
		GameState.spend_click_energy()

	var day_end: Control = ui.get_node("DayEnd")
	if not await _wait_for_visible(day_end, "DayEnd"):
		return
	_press(day_end, "DayEndContinue")

	var choice: Control = ui.get_node("JamoChoice")
	if not await _wait_for_visible(choice, "JamoChoice"):
		return
	var card: Node = choice.get_node("%Card0")
	var chosen_jamo: String = card.jamo
	_check(not chosen_jamo.is_empty(), "the first candidate card should carry a jamo")
	_press(card, "CardButton")

	var shop: Control = ui.get_node("UpgradeShop")
	if not await _wait_for_visible(shop, "UpgradeShop"):
		return
	_check(
		GameState.get_jamo_count(chosen_jamo) == 1,
		"the picked jamo should be in the inventory"
	)
	_press(shop, "NextDayButton")

	if not await _wait_until(func() -> bool: return GameState.day == 2, "Day 2"):
		return
	_check(GameState.energy == GameState.get_max_energy(), "Day 2 should refill energy")
	_check(GameState.kills_today == 0, "Day 2 should reset the kill counter")
	_check(SaveManager.load_game(), "the day end should have written a save")
	_check(GameState.day == 2, "the save should hold Day 2")
	SaveManager.delete_save()


## Verifies the whole click path: the ray finds the monster hitbox, energy is
## spent, damage lands, and a dead monster stops being clickable.
func _test_clicking_a_monster(main: Node) -> bool:
	var monster_root: Node3D = main.get_node("World/GameWorld/MonsterRoot")
	var camera: Camera3D = main.get_node("World/GameWorld/CameraRig/ShakePivot/Camera3D")
	var clicker: ClickController = main.get_node("World/GameWorld/ClickController")

	if not await _wait_until(
		func() -> bool: return monster_root.get_child_count() > 0, "a spawned monster"
	):
		return false
	# Let the physics server register the new click area.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var monster: JamoMonster = monster_root.get_child(0)
	var screen_point: Vector2 = camera.unproject_position(monster.get_hit_position())
	var picked: JamoMonster = clicker.pick_monster_at(screen_point)
	_check(picked == monster, "the click ray should hit the monster under the cursor")
	if picked == null:
		return false

	# Doc v0.3 section 10: a miss must not cost energy.
	var corner: Vector2 = camera.unproject_position(Vector3(0.0, 0.0, 30.0))
	_check(clicker.pick_monster_at(corner) == null, "empty space should pick nothing")
	var energy_at_start: int = GameState.energy

	var energy_before: int = GameState.energy
	var hp_before: float = picked.hp
	GameState.spend_click_energy()
	picked.take_click_damage(GameState.get_click_damage())
	_check(GameState.energy == energy_before - 1, "one click should cost one energy")
	_check(picked.hp == hp_before - 1.0, "one click should deal one damage on Day 1")

	# Day 1 monsters have 3 HP, so two more clicks finish this one.
	var gold_before: float = GameState.gold
	for _extra in 2:
		GameState.spend_click_energy()
		picked.take_click_damage(GameState.get_click_damage())
	_check(not picked.is_alive(), "three clicks should kill a Day 1 monster")
	_check(GameState.kills_today == 1, "the kill should be counted")
	_check(
		GameState.energy == energy_at_start - 3,
		"only the three real clicks should have cost energy"
	)
	_check(GameState.gold > gold_before, "the kill should pay gold")
	await get_tree().physics_frame
	_check(
		clicker.pick_monster_at(screen_point) != picked,
		"a dead monster should no longer be clickable"
	)
	return true


func _press(root: Node, button_name: String) -> void:
	var button: BaseButton = root.find_child(button_name, true, false) as BaseButton
	if button == null:
		_failures += 1
		printerr("  FAIL: could not find button %s" % button_name)
		return
	button.pressed.emit()


func _wait_for_visible(node: Control, label: String) -> bool:
	return await _wait_until(func() -> bool: return node.visible, label)


## Polls a condition frame by frame. Returns false and records a failure if the
## budget runs out, which is what a stuck await in the day flow looks like.
func _wait_until(condition: Callable, label: String) -> bool:
	for _frame in WAIT_FRAME_BUDGET:
		if condition.call():
			return true
		await get_tree().process_frame
	_failures += 1
	printerr("  FAIL: timed out waiting for %s" % label)
	return false
