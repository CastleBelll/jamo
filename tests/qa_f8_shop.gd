extends Node

## QA-only viewer: puts the real upgrade_shop.tscn on screen at a chosen game
## state so the F8 prices and the extended click damage ladder can be read off
## the running UI. Run:  godot --path . res://tests/qa_f8_shop.tscn -- <state>
##   day1   fresh Day 1, nothing bought   (DEV_HANDOFF step 16)
##   late   Day 60, click damage Lv25     (click damage Lv26 display)

const SHOP_SCENE := "res://scenes/ui/upgrade_shop.tscn"
## State used when no user arg is given (the editor Game tab passes none).
const DEFAULT_STATE := "late"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var state: String = args[0] if args.size() > 0 else DEFAULT_STATE

	GameState.day = 1
	GameState.gold = 0.0
	GameState.upgrade_levels.clear()
	GameState.unlocked_word_ids.clear()
	GameState.jamo_inventory.clear()
	GameState.from_dict(GameState.to_dict())

	match state:
		"late":
			GameState.day = 60
			GameState.gold = 5000000.0
			GameState.upgrade_levels[&"click_damage"] = 25
			GameState.upgrade_levels[&"critical_click"] = 4
			GameState.upgrade_levels[&"max_energy"] = 9
			GameState.upgrade_levels[&"gold_bonus"] = 9
			GameState.upgrade_levels[&"monster_capacity"] = 5
			GameState.upgrade_levels[&"reroll"] = 2
		_:
			GameState.gold = 12.0

	var shop: Control = (load(SHOP_SCENE) as PackedScene).instantiate()
	add_child(shop)
	await get_tree().process_frame
	shop.call("open")
	await get_tree().process_frame
	print("SHOP STATE=%s day=%d gold=%d" % [state, GameState.day, int(GameState.gold)])
