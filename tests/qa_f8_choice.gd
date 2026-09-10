extends Node

## QA-only viewer: opens the real jamo_choice.tscn with live candidates so the
## keyboard focus border on the cards can be read off the running UI.
## Run through the editor Game tab, or:
##   godot --path . res://tests/qa_f8_choice.tscn

const CHOICE_SCENE := "res://scenes/ui/jamo_choice.tscn"


func _ready() -> void:
	GameState.day = 1
	GameState.gold = 0.0
	GameState.upgrade_levels.clear()
	GameState.jamo_inventory.clear()
	var choice: Control = (load(CHOICE_SCENE) as PackedScene).instantiate()
	add_child(choice)
	await get_tree().process_frame
	choice.open()
