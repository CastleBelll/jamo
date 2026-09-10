extends Node

## QA harness for the 치명 클릭 unlock gate, the save round trip and Inspector
## visibility. Runs the real main.tscn and reads the rendered shop rows, so the
## gate is judged from what the player actually sees.
##
##   godot --path . tests/qa_shop_gate.tscn
##
## growth_balance v0.2 sections 8.3 and 13, doc v0.3 sections 30 and 37.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f1"

var _shop: Control
var _row: UpgradeRow
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var main: Node = load(MAIN_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_shop = main.get_node("UI/UpgradeShop")
	_row = _shop.get_node("Center/Panel/Box/RowCritical")

	await _case_day_24()
	await _case_day_25_locked()
	await _case_day_25_unlocked()
	_case_save_round_trip()
	_case_inspector_visibility()

	_write_report()
	print("QA gate harness finished.")
	get_tree().quit(0)


## Day 24: below unlock_day, so the row is not listed at all.
func _case_day_24() -> void:
	GameState.day = 24
	GameState.upgrade_levels[&"click_damage"] = 3
	GameState.gold = 100000.0
	_report["day24"] = await _snapshot("shop_day24")


## Day 25 but 클릭 피해 Lv.2: listed, disabled, with the reason spelled out.
func _case_day_25_locked() -> void:
	GameState.day = 25
	GameState.upgrade_levels[&"click_damage"] = 2
	_report["day25_locked"] = await _snapshot("shop_day25_locked")


## Day 25 and 클릭 피해 Lv.3: both conditions met, so the row is buyable.
func _case_day_25_unlocked() -> void:
	GameState.day = 25
	GameState.upgrade_levels[&"click_damage"] = 3
	_report["day25_unlocked"] = await _snapshot("shop_day25_unlocked")


## Buys Lv.2, saves, wipes the runtime state and loads it back from the file.
func _case_save_round_trip() -> void:
	var critical: UpgradeData = GameState.database.find_upgrade(&"critical_click")
	GameState.gold = 100000.0
	UpgradeManager.purchase(critical)
	UpgradeManager.purchase(critical)
	SaveManager.save_game()

	var text: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var raw: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	GameState.upgrade_levels.clear()
	GameState.day = 1
	SaveManager.load_game()

	_report["save"] = {
		"path": ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		"raw_upgrade_levels": raw.get("upgrade_levels", {}),
		"restored_level": GameState.get_upgrade_level(&"critical_click"),
		"restored_crit_chance": GameState.get_crit_chance(),
		"restored_day": GameState.day,
	}


## Doc v0.3 section 37: a .tres must show its values in the Inspector, which
## means the properties carry PROPERTY_USAGE_EDITOR.
func _case_inspector_visibility() -> void:
	_report["inspector"] = {
		"game_balance": _editor_properties(GameState.balance),
		"critical_click": _editor_properties(
			GameState.database.find_upgrade(&"critical_click")
		),
	}


func _editor_properties(resource: Resource) -> Array:
	var names: Array = []
	if resource == null:
		return names
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_EDITOR:
			names.append(property["name"])
	return names


## Opens the shop, records what the 치명 클릭 row shows, and saves a screenshot.
func _snapshot(name: String) -> Dictionary:
	_shop.open()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var result: Dictionary = {"row_visible": _row.visible}
	if _row.visible:
		result["name_text"] = _row.get_node("Row/TextBox/NameLabel").text
		result["value_text"] = _row.get_node("Row/TextBox/ValueLabel").text
		result["cost_text"] = _row.get_node("Row/CostLabel").text
		result["button_text"] = _row.get_node("Row/BuyButton").text
		result["button_disabled"] = _row.get_node("Row/BuyButton").disabled

	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [ARTIFACT_DIR, name])

	_shop.hide()
	await get_tree().process_frame
	return result


func _write_report() -> void:
	var file := FileAccess.open("%s/gate_report.json" % ARTIFACT_DIR, FileAccess.WRITE)
	if file == null:
		push_error("QA gate harness: cannot write the report.")
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
