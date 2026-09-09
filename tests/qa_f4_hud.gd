extends Node

## QA harness for the F3 FAIL fix (HUD craftable list). Not a pass/fail test:
## it renders the real HUD scene and writes screenshots for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f4_hud.tscn
##
## The overflow row is unreachable through play (10 rows > 6 simultaneously
## craftable words), so it is exercised by shrinking the HUD's row list from
## this harness instead of editing production code. Doc v0.3 section 19.1.

const HUD_SCENE := "res://scenes/ui/hud.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f3"

const ALL_WORDS := [
	&"fire_001", &"fire_002", &"fire_003", &"power_001", &"power_002",
	&"gold_001", &"gold_002", &"energy_001", &"energy_002", &"luck_001",
]

var _layer: CanvasLayer
var _hud: Control
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_layer = CanvasLayer.new()
	add_child(_layer)
	_hud = load(HUD_SCENE).instantiate()
	_layer.add_child(_hud)
	await get_tree().process_frame

	_report["rows_in_scene"] = _hud._word_rows.size()
	_report["words_in_database"] = GameState.database.words.size()

	_apply_state([])
	_report["day1_craftable"] = _craftable_names()
	_report["day1_visible_rows"] = _visible_rows()
	_report["day1_empty_label_visible"] = _hud._word_empty_label.visible
	_report["day1_overflow_label_visible"] = _hud._word_overflow_label.visible
	await _shot("hud_day1_rows")

	_apply_state(ALL_WORDS)
	_report["all_done_visible_rows"] = _visible_rows()
	_report["all_done_empty_label_visible"] = _hud._word_empty_label.visible
	_report["all_done_empty_label_text"] = _hud._word_empty_label.text
	await _shot("hud_all_done_empty")

	await _capture_overflow()

	_write_report()
	get_tree().quit()


## Temporarily hands the HUD a two-row list so the overflow label has to fire.
## The scene file is untouched; the original array is restored right after.
func _capture_overflow() -> void:
	var original: Array[Label] = _hud._word_rows
	var shrunk: Array[Label] = [original[0], original[1]]
	for i in range(2, original.size()):
		original[i].visible = false
	_hud._word_rows = shrunk
	_apply_state([])
	_report["overflow_visible_rows"] = _visible_rows()
	_report["overflow_label_visible"] = _hud._word_overflow_label.visible
	_report["overflow_label_text"] = _hud._word_overflow_label.text
	await _shot("hud_overflow")

	_hud._word_rows = original
	_apply_state([])
	_report["after_restore_visible_rows"] = _visible_rows()
	_report["after_restore_overflow_visible"] = _hud._word_overflow_label.visible


func _apply_state(word_ids: Array) -> void:
	GameState.unlocked_word_ids.clear()
	for id: StringName in word_ids:
		GameState.unlocked_word_ids.append(id)
	GameState.jamo_inventory.clear()
	GameState.day = 1 if word_ids.is_empty() else 12
	GameState._recalculate_word_bonuses()
	GameState.begin_day()
	_hud.refresh()


func _craftable_names() -> Array[String]:
	var names: Array[String] = []
	for word: WordData in GameState.get_craftable_words():
		names.append(word.word)
	return names


func _visible_rows() -> Array[String]:
	var texts: Array[String] = []
	var box: Node = _hud.get_node("WordProgressPanel/WordBox")
	for child in box.get_children():
		var label := child as Label
		if label != null and label.visible and label.name != "TitleLabel":
			texts.append(label.text)
	return texts


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/play_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f4_hud_observations.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f4_hud: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
