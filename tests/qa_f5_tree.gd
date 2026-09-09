extends Node

## QA harness for F5 word tree UI. Not a pass/fail test: it runs the real
## main.tscn, drives real keyboard events through the input pipeline and writes
## observation artifacts (screenshots + JSON) for a human to inspect.
##
## Run windowed, it needs rendering:
##   godot --path . tests/qa_f5_tree.tscn
##
## Doc v0.3 sections 13.3, 15, 19.1, 23.1, 23.5, 27, 37.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f5"
## How many Tab presses to try when hunting for a control.
const TAB_PROBE_STEPS := 12
## A window short enough that the tree panel has to give something up.
const SHORT_WINDOW := Vector2i(1280, 460)

var _main: Node
var _hud: Control
var _tree: Control
var _report: Dictionary = {}
var _original_window_size: Vector2i


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_original_window_size = DisplayServer.window_get_size()
	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	_hud = _main.get_node("UI/HUD")
	_tree = _main.get_node("UI/WordTree")

	_report["keyboard_open"] = await _probe_keyboard_open()
	_report["keyboard_inside_tree"] = await _probe_keyboard_inside_tree()
	_report["target_rules"] = await _probe_target_rules()
	_report["hud_vs_tree"] = _compare_hud_and_tree()
	_report["target_save_round_trip"] = _probe_save_round_trip()
	_report["undiscovered_probe"] = await _probe_undiscovered()
	_report["overflow_probe"] = await _probe_overflow()
	_report["short_window"] = await _probe_short_window()

	_write_report()
	get_tree().quit()


# --- S5 keyboard -----------------------------------------------------------


## Can the tree be reached at all without a mouse? Records what each Tab press
## actually focused, then tries Enter on whatever ended up focused.
func _probe_keyboard_open() -> Dictionary:
	_tree.hide()
	await get_tree().process_frame
	var chain := PackedStringArray()
	var opened_after := -1
	for step in TAB_PROBE_STEPS:
		await _key(KEY_TAB)
		chain.append(_focus_path())
		await _key(KEY_ENTER)
		if _tree.visible:
			opened_after = step + 1
			break
	await _shot("keyboard_open_attempt")
	var result := {
		"tab_focus_chain": chain,
		"tree_opened_after_tabs": opened_after,
		"tree_visible": _tree.visible,
	}
	_tree.hide()
	await get_tree().process_frame
	return result


## Once the tree is open (opened here in code, since the previous probe records
## whether the keyboard alone can get here), walk the slots with the arrow keys.
func _probe_keyboard_inside_tree() -> Dictionary:
	_tree.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var on_open := _focus_path()
	await _shot("keyboard_01_open")

	var walk := PackedStringArray()
	for key: Key in [KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP]:
		await _key(key)
		walk.append("%s -> %s" % [OS.get_keycode_string(key), _focus_path()])
	await _shot("keyboard_02_walk")

	# Accept on whatever slot the walk landed on.
	var before: StringName = GameState.target_word_id
	await _key(KEY_ENTER)
	var after_enter: StringName = GameState.target_word_id
	await _shot("keyboard_03_enter")

	# Space must work the same way; move one slot first so it is a new word.
	await _key(KEY_LEFT)
	await _key(KEY_SPACE)
	var after_space: StringName = GameState.target_word_id
	await _shot("keyboard_04_space")

	# Tab on to the footer buttons and clear the target with the keyboard.
	var footer := PackedStringArray()
	var cleared_after := -1
	for step in TAB_PROBE_STEPS:
		await _key(KEY_TAB)
		footer.append(_focus_path())
		if _focus_path().ends_with("ClearTargetButton"):
			await _key(KEY_ENTER)
			cleared_after = step + 1
			break
	await _shot("keyboard_05_clear_target")

	var closed_after := -1
	for step in TAB_PROBE_STEPS:
		if _focus_path().ends_with("CloseButton"):
			await _key(KEY_ENTER)
			closed_after = step
			break
		await _key(KEY_TAB)
	await _shot("keyboard_06_closed")

	var result := {
		"focus_on_open": on_open,
		"arrow_walk": walk,
		"target_before_enter": String(before),
		"target_after_enter": String(after_enter),
		"target_after_space": String(after_space),
		"footer_tab_chain": footer,
		"cleared_after_tabs": cleared_after,
		"target_after_clear": String(GameState.target_word_id),
		"closed_after_tabs": closed_after,
		"tree_visible_at_end": _tree.visible,
	}
	_tree.hide()
	GameState.clear_target_word()
	await get_tree().process_frame
	return result


# --- S3 target rules -------------------------------------------------------


## Every refusal path, driven through the slot buttons the player actually
## presses rather than through GameState directly.
func _probe_target_rules() -> Dictionary:
	_reset_progress([])
	_tree.open()
	await get_tree().process_frame

	var result: Dictionary = {}
	result["locked_slot"] = await _press_word(&"fire_002")
	result["craftable_slot"] = await _press_word(&"gold_001")
	await _shot("target_01_set_don")
	result["hud_line_after_set"] = _hud_target_line()

	# Re-pressing a locked word must not steal the target that is already set.
	result["locked_slot_with_target"] = await _press_word(&"fire_002")
	result["target_after_locked_press"] = String(GameState.target_word_id)
	await _shot("target_02_refuse_locked")

	# An already completed word is refused too.
	_reset_progress([&"fire_001"])
	_tree.refresh()
	await get_tree().process_frame
	result["unlocked_slot"] = await _press_word(&"fire_001")
	await _shot("target_03_refuse_unlocked")

	# Completing the target retires it, and the HUD readout follows.
	_reset_progress([])
	_tree.refresh()
	await get_tree().process_frame
	result["retarget_don"] = await _press_word(&"gold_001")
	for jamo: String in ["ㄷ", "ㅗ", "ㄴ"]:
		GameState.add_jamo(jamo)
	result["hud_line_partial_slots"] = _hud_target_line()
	GameState.complete_ready_words()
	await get_tree().process_frame
	result["target_after_completing_it"] = String(GameState.target_word_id)
	result["hud_line_after_completion"] = _hud_target_line()
	_tree.refresh()
	await get_tree().process_frame
	await _shot("target_04_auto_cleared")

	_tree.hide()
	_reset_progress([])
	await get_tree().process_frame
	return result


## Presses the slot button that currently shows `word_id` and reports what the
## panel said back.
func _press_word(word_id: StringName) -> Dictionary:
	var slot := _slot_for(word_id)
	if slot == null:
		return {"error": "no visible slot for %s" % word_id}
	slot.grab_focus()
	await get_tree().process_frame
	await _key(KEY_ENTER)
	return {
		"slot_text": slot.text,
		"status_line": (_tree.get_node("%StatusLabel") as Label).text,
		"target_now": String(GameState.target_word_id),
		"header_line": (_tree.get_node("%TargetLabel") as Label).text,
		"clear_button_visible": (_tree.get_node("%ClearTargetButton") as Button).visible,
	}


func _probe_save_round_trip() -> Dictionary:
	_reset_progress([])
	var accepted: bool = GameState.set_target_word(&"gold_001")
	var saved: Dictionary = GameState.to_dict()
	GameState.target_word_id = &""
	GameState.from_dict(saved)
	var restored: StringName = GameState.target_word_id
	# An old save with no target_word key at all must load as "no target".
	var legacy: Dictionary = GameState.to_dict()
	legacy.erase("target_word")
	GameState.from_dict(legacy)
	var after_legacy: StringName = GameState.target_word_id
	GameState.clear_target_word()
	return {
		"target_accepted": accepted,
		"saved_value": String(saved.get("target_word", "<missing>")),
		"restored": String(restored),
		"legacy_save_without_key": String(after_legacy),
	}


# --- S1 / S2 information consistency ---------------------------------------


func _compare_hud_and_tree() -> Dictionary:
	_reset_progress([])
	_tree.refresh()
	_hud.refresh()
	var craftable := PackedStringArray()
	for word: WordData in GameState.get_craftable_words():
		craftable.append(word.word)
	return {
		"tree_rows": _tree_rows(),
		"hud_rows": _hud_rows(),
		"craftable_from_state": craftable,
	}


# --- 3)-A undiscovered, without touching any .tres --------------------------


## The shipped database is only one prerequisite hop deep, so 미발견 never shows
## on screen. This swaps in a probe database that adds a two-hop word, in
## memory only, and photographs the result. No resource file is written.
func _probe_undiscovered() -> Dictionary:
	var original: GameDatabase = GameState.database
	var probe := GameDatabase.new()
	probe.balance = original.balance
	probe.filler_jamo = original.filler_jamo
	probe.upgrades = original.upgrades
	var deep := WordData.new()
	deep.id = &"fire_probe"
	deep.word = "고열"
	deep.category = &"fire"
	deep.required_jamo = PackedStringArray(["ㄱ", "ㅗ"])
	deep.prerequisites = [&"fire_002"]
	deep.description = "QA probe word, in memory only."
	var words: Array[WordData] = original.words.duplicate()
	words.append(deep)
	probe.words = words
	GameState.database = probe

	_reset_progress([])
	_tree.open()
	await get_tree().process_frame
	var fresh := _tree_rows()
	var detail_undiscovered := _detail_for(&"fire_probe")
	await _shot("undiscovered_01_day1")

	_reset_progress([&"fire_001"])
	_tree.refresh()
	await get_tree().process_frame
	var after_bul := _tree_rows()
	await _shot("undiscovered_02_after_bul")

	_reset_progress([])
	_tree.refresh()
	await get_tree().process_frame
	var refused := await _press_word(&"fire_probe")

	_tree.hide()
	GameState.database = original
	_reset_progress([])
	_tree.refresh()
	await get_tree().process_frame
	return {
		"day1_rows": fresh,
		"detail_line_while_undiscovered": detail_undiscovered,
		"rows_after_unlocking_bul": after_bul,
		"target_refusal": refused,
		"database_restored": GameState.database == original,
	}


# --- H) overflow -----------------------------------------------------------


## Pushes one category past the five slots the scene has and checks the notice
## is actually drawn instead of the extra words vanishing. In memory only.
func _probe_overflow() -> Dictionary:
	var original: GameDatabase = GameState.database
	var probe := GameDatabase.new()
	probe.balance = original.balance
	probe.filler_jamo = original.filler_jamo
	probe.upgrades = original.upgrades
	var words: Array[WordData] = original.words.duplicate()
	for index in 4:
		var filler := WordData.new()
		filler.id = StringName("fire_overflow_%d" % index)
		filler.word = "과열%d" % index
		filler.category = &"fire"
		filler.required_jamo = PackedStringArray(["ㄱ", "ㅗ"])
		filler.description = "QA probe word, in memory only."
		words.append(filler)
	probe.words = words
	GameState.database = probe

	_reset_progress([])
	_tree.open()
	await get_tree().process_frame
	await _shot("overflow_01_fire_column")
	var notices := PackedStringArray()
	for column: Node in _tree.get_node("%Columns").get_children():
		var overflow := column.get_node_or_null("Overflow") as Label
		if overflow != null and overflow.visible:
			notices.append("%s: %s" % [column.name, overflow.text])
	var rows := _tree_rows()

	_tree.hide()
	GameState.database = original
	_reset_progress([])
	_tree.refresh()
	await get_tree().process_frame
	return {
		"fire_words_in_probe": 7,
		"slots_per_column": 5,
		"visible_overflow_notices": notices,
		"rows_drawn": rows,
		"database_restored": GameState.database == original,
	}


# --- S0-1 short window -----------------------------------------------------


func _probe_short_window() -> Dictionary:
	_tree.open()
	await get_tree().process_frame
	DisplayServer.window_set_size(SHORT_WINDOW)
	for _frame in 20:
		await get_tree().process_frame
	await _shot("short_window")

	var viewport_rect := get_viewport().get_visible_rect()
	var close_button: Button = _tree.get_node("%CloseButton")
	var close_rect: Rect2 = close_button.get_global_rect()
	var top_bar: Control = _hud.get_node("TopBar")
	var panel: Control = _tree.get_node("Frame/Panel")
	var result := {
		"window_size": [SHORT_WINDOW.x, SHORT_WINDOW.y],
		"viewport_height": viewport_rect.size.y,
		"close_button_rect": [
			close_rect.position.x, close_rect.position.y,
			close_rect.size.x, close_rect.size.y,
		],
		"close_button_bottom": close_rect.position.y + close_rect.size.y,
		"close_button_fully_on_screen": viewport_rect.encloses(close_rect),
		"panel_top": panel.get_global_rect().position.y,
		"top_bar_bottom": top_bar.get_global_rect().position.y
			+ top_bar.get_global_rect().size.y,
	}
	DisplayServer.window_set_size(_original_window_size)
	for _frame in 20:
		await get_tree().process_frame
	_tree.hide()
	return result


# --- helpers ---------------------------------------------------------------


func _reset_progress(word_ids: Array) -> void:
	GameState.unlocked_word_ids.clear()
	for id: StringName in word_ids:
		GameState.unlocked_word_ids.append(id)
	GameState.jamo_inventory.clear()
	GameState.target_word_id = &""
	GameState._recalculate_word_bonuses()


func _slot_for(word_id: StringName) -> Button:
	var word: WordData = GameState.database.find_word(word_id)
	if word == null:
		return null
	for column: Node in _tree.get_node("%Columns").get_children():
		for child: Node in column.get_children():
			var slot := child as Button
			if slot != null and slot.visible and slot.text.ends_with(word.word):
				return slot
	return null


func _detail_for(word_id: StringName) -> String:
	var slot := _slot_for(word_id)
	return "" if slot == null else slot.tooltip_text


func _tree_rows() -> Array[String]:
	var rows: Array[String] = []
	for column: Node in _tree.get_node("%Columns").get_children():
		for child: Node in column.get_children():
			var slot := child as Button
			if slot != null and slot.visible:
				rows.append(slot.text)
	return rows


func _hud_rows() -> Array[String]:
	var rows: Array[String] = []
	for child: Node in _hud.get_node("WordProgressPanel/WordBox").get_children():
		var label := child as Label
		if label != null and label.visible and not label.text.is_empty():
			rows.append(label.text)
	return rows


func _hud_target_line() -> String:
	var word_label: Label = _hud.get_node("%TargetWordLabel")
	var slots_label: Label = _hud.get_node("%TargetSlotsLabel")
	return "%s | %s" % [word_label.text, slots_label.text if slots_label.visible else ""]


func _focus_path() -> String:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	return "(none)" if owner_control == null else String(owner_control.get_path())


## Real input: a press and a release, both through Input.parse_input_event, so
## the focus system reacts exactly as it does for a player.
func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/tree_%s.png" % [ARTIFACT_DIR, label])


func _write_report() -> void:
	var path := "%s/qa_f5_tree.json" % ARTIFACT_DIR
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f5_tree: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	print(JSON.stringify(_report, "\t"))
	print("OK - F5 tree artifacts written to %s" % ARTIFACT_DIR)
