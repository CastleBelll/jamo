extends Node

## QA harness for the 리롤 (reroll) feature. Runs the real main.tscn and reads
## the rendered day-end panel and shop rows, so every verdict comes from what a
## player would actually see on screen.
##
##   godot --path . tests/qa_reroll_play.tscn
##
## Doc v0.3 sections 13.1, 13.4, 19, 23.4 and 37; growth_balance v0.2 section 13.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f2"
const REROLL_ID := &"reroll"

var _choice: Control
var _shop: Control
var _shop_row: UpgradeRow
var _reroll_row: HBoxContainer
var _reroll_button: Button
var _reroll_label: Label
var _cards: Array = []
var _report: Dictionary = {}
var _saved_backup: String = ""
var _had_backup: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_backup_save()

	var main: Node = load(MAIN_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_choice = main.get_node("UI/JamoChoice")
	_shop = main.get_node("UI/UpgradeShop")
	_shop_row = _shop.get_node("Center/Panel/Box/RowReroll")
	_reroll_row = _choice.get_node("Center/Panel/Box/RerollRow")
	_reroll_button = _reroll_row.get_node("RerollButton")
	_reroll_label = _reroll_row.get_node("RerollCountLabel")
	for i in 4:
		_cards.append(_choice.get_node("Center/Panel/Box/CardRow/Card%d" % i))

	await _case_day4_hidden()
	await _case_day5_shop_and_buy()
	await _case_reroll_changes_candidates()
	await _case_exhausted_disabled()
	await _case_pick_is_final()
	await _case_next_day_refill()
	await _case_level2_day_gate()
	_case_save_round_trip()
	_case_legacy_save()
	_case_small_pool()
	_case_candidate_quality()
	await _case_empty_pool_panel()
	await _case_accessibility()
	_case_inspector_visibility()

	_restore_save()
	_write_report()
	print("QA reroll harness finished.")
	get_tree().quit(0)


# --- Cases -----------------------------------------------------------------

## Day 4: below unlock_day 5, so the shop row is not listed and the day-end
## panel shows no reroll row at all.
func _case_day4_hidden() -> void:
	GameState.day = 4
	GameState.gold = 100000.0
	GameState.upgrade_levels.erase(REROLL_ID)
	GameState.rerolls_left = GameState.get_max_rerolls()
	var shop_state := await _shop_snapshot("01_shop_day4")
	var choice_state := await _choice_snapshot("02_choice_day4")
	_report["day4_hidden"] = {"shop": shop_state, "choice": choice_state}


## Day 5: the row appears at 1,000 G, and the purchase goes through the real
## BuyButton rather than the manager API.
func _case_day5_shop_and_buy() -> void:
	GameState.day = 5
	GameState.gold = 100000.0
	var before := await _shop_snapshot("03_shop_day5_available")
	_shop.open()
	await get_tree().process_frame
	_shop_row.get_node("Row/BuyButton").pressed.emit()
	await get_tree().process_frame
	var after := await _shop_snapshot("04_shop_day5_after_buy")
	_shop.hide()
	await get_tree().process_frame

	GameState.begin_day()
	var choice_state := await _choice_snapshot("05_choice_day5_lv1")
	_report["day5_buy"] = {
		"shop_before": before,
		"shop_after": after,
		"level": GameState.get_upgrade_level(REROLL_ID),
		"gold_after": GameState.gold,
		"max_rerolls": GameState.get_max_rerolls(),
		"choice": choice_state,
	}


## Pressing the button redraws the hand. Recorded over several attempts so a
## coincidental repeat cannot be mistaken for a broken reroll.
func _case_reroll_changes_candidates() -> void:
	var trials: Array = []
	var worst_overlap := 0
	for _i in 20:
		GameState.rerolls_left = 1
		_choice.open()
		await get_tree().process_frame
		var before := _card_texts()
		_reroll_button.pressed.emit()
		await get_tree().process_frame
		var after := _card_texts()
		var overlap := _overlap(before, after)
		worst_overlap = maxi(worst_overlap, overlap)
		trials.append({"before": before, "after": after, "overlap": overlap})

	GameState.rerolls_left = 1
	_choice.open()
	await get_tree().process_frame
	var before_shot := _card_texts()
	await _shot("06_choice_before_reroll")
	await _click(_reroll_button)
	var after_shot := _card_texts()
	await _shot("07_choice_after_reroll")
	_report["reroll_changes"] = {
		"real_click_used_for_screenshot_pair": true,
		"trials": trials,
		"max_overlap": worst_overlap,
		"screenshot_before": before_shot,
		"screenshot_after": after_shot,
	}


## Spending the last reroll must disable the button and say so in words.
func _case_exhausted_disabled() -> void:
	_report["exhausted"] = {
		"rerolls_left": GameState.rerolls_left,
		"button_disabled": _reroll_button.disabled,
		"label_text": _reroll_label.text,
		"row_visible": _reroll_row.visible,
		"focus_moved_off_button": get_viewport().gui_get_focus_owner() != _reroll_button,
	}
	await _shot("08_choice_exhausted")


## After a card is picked the panel is hidden, so a reroll can no longer fire.
func _case_pick_is_final() -> void:
	GameState.rerolls_left = 1
	_choice.open()
	await get_tree().process_frame
	var before := _card_texts()
	_cards[0].get_node("CardButton").pressed.emit()
	await get_tree().process_frame
	var hidden_after_pick := not _choice.visible
	_reroll_button.pressed.emit()
	await get_tree().process_frame
	_report["pick_final"] = {
		"panel_hidden_after_pick": hidden_after_pick,
		"candidates_at_pick": before,
		"candidates_after_late_reroll": _card_texts(),
		"rerolls_left_after_late_reroll": GameState.rerolls_left,
	}
	await _shot("09_after_pick_hidden")


## begin_day() recharges the counter every morning.
func _case_next_day_refill() -> void:
	GameState.rerolls_left = 0
	GameState.advance_day()
	await get_tree().process_frame
	var choice_state := await _choice_snapshot("10_choice_next_day_refilled")
	_report["next_day_refill"] = {
		"day": GameState.day,
		"rerolls_left": GameState.rerolls_left,
		"choice": choice_state,
	}


## Lv.2 waits for Day 25 even when the player can afford it.
func _case_level2_day_gate() -> void:
	GameState.day = 10
	GameState.gold = 100000.0
	var locked := await _shop_snapshot("11_shop_lv2_day_locked")
	GameState.day = 25
	var open_state := await _shop_snapshot("12_shop_lv2_day25")
	_report["level2_gate"] = {"day10": locked, "day25": open_state}


## One reroll spent, saved, wiped and loaded back from the real save file.
func _case_save_round_trip() -> void:
	GameState.day = 6
	GameState.begin_day()
	GameState.consume_reroll()
	var spent := GameState.rerolls_left
	SaveManager.save_game()
	var text: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var raw: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	GameState.rerolls_left = 999
	GameState.upgrade_levels.clear()
	GameState.day = 1
	SaveManager.load_game()
	_report["save_round_trip"] = {
		"path": ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		"spent_before_save": spent,
		"raw_rerolls_left": raw.get("rerolls_left", "<missing>"),
		"restored_rerolls_left": GameState.rerolls_left,
		"restored_level": GameState.get_upgrade_level(REROLL_ID),
		"restored_day": GameState.day,
	}


## A save written before the track existed has no key, so the day starts full.
func _case_legacy_save() -> void:
	var legacy := GameState.to_dict()
	legacy.erase("rerolls_left")
	GameState.rerolls_left = 999
	GameState.from_dict(legacy)
	var full := GameState.rerolls_left
	var over := GameState.to_dict()
	over["rerolls_left"] = 99
	GameState.from_dict(over)
	_report["legacy_save"] = {
		"level": GameState.get_upgrade_level(REROLL_ID),
		"max": GameState.get_max_rerolls(),
		"restored_from_missing_key": full,
		"clamped_from_absurd_value": GameState.rerolls_left,
	}


## A pool smaller than the hand must still return something and never crash.
func _case_small_pool() -> void:
	var saved_inventory: Dictionary = GameState.jamo_inventory.duplicate()
	var results: Array = []

	for word: WordData in GameState.database.words:
		for jamo: String in word.required_counts():
			GameState.jamo_inventory[jamo] = 99
	var empty_hand := CandidateGenerator.generate(2)
	var empty_reroll := CandidateGenerator.regenerate(2, empty_hand)
	results.append({"case": "pool_empty", "hand": empty_hand, "reroll": empty_reroll})

	var first: WordData = GameState.database.words[0]
	var single: String = first.required_counts().keys()[0]
	GameState.jamo_inventory[single] = 0
	var one_hand := CandidateGenerator.generate(2)
	var one_reroll := CandidateGenerator.regenerate(2, one_hand)
	results.append({"case": "pool_one", "hand": one_hand, "reroll": one_reroll})

	GameState.jamo_inventory = saved_inventory
	_report["small_pool"] = results


## Doc v0.3 13.4: rerolled candidates stay inside the useful pool, they are not
## drawn uniformly from the whole alphabet.
func _case_candidate_quality() -> void:
	var needed: Dictionary = {}
	for word: WordData in GameState.get_craftable_words():
		var counts: Dictionary = word.required_counts()
		for jamo: String in counts:
			if int(counts[jamo]) - GameState.get_jamo_count(jamo) > 0:
				needed[jamo] = true
	var off_pool: Array = []
	var overlaps: Array = []
	var worst := 0
	for _i in 50:
		var hand := CandidateGenerator.generate(2)
		var again := CandidateGenerator.regenerate(2, hand)
		var overlap := _overlap(hand, again)
		worst = maxi(worst, overlap)
		overlaps.append(overlap)
		for jamo: String in again:
			if not needed.has(jamo) and not GameState.database.filler_jamo.has(jamo):
				off_pool.append(jamo)
	_report["candidate_quality"] = {
		"needed_pool": needed.keys(),
		"pool_size": needed.size(),
		"filler_jamo": GameState.database.filler_jamo,
		"off_pool_draws": off_pool,
		"overlap_counts": overlaps,
		"max_overlap": worst,
	}


## Nothing left to draw: the panel falls back to its empty state and the reroll
## button says in words that there is no hand to redraw.
func _case_empty_pool_panel() -> void:
	var saved_inventory: Dictionary = GameState.jamo_inventory.duplicate()
	for word: WordData in GameState.database.words:
		for jamo: String in word.required_counts():
			GameState.jamo_inventory[jamo] = 99
	GameState.day = 6
	GameState.begin_day()
	_choice.open()
	await get_tree().process_frame
	_report["empty_pool_panel"] = {
		"candidates": _card_texts(),
		"row_visible": _reroll_row.visible,
		"button_disabled": _reroll_button.disabled,
		"label_text": _reroll_label.text,
		"empty_label_visible": _choice.get_node("Center/Panel/Box/EmptyLabel").visible,
		"skip_visible": _choice.get_node("Center/Panel/Box/SkipButton").visible,
	}
	await _shot("14_choice_empty_pool")
	# A real click on the disabled button must not crash or spend a reroll.
	await _click(_reroll_button)
	_report["empty_pool_panel"]["rerolls_left_after_real_click"] = GameState.rerolls_left
	# Bypassing the disabled state entirely, to show where the guard sits.
	_reroll_button.pressed.emit()
	await get_tree().process_frame
	_report["empty_pool_panel"]["rerolls_left_after_forced_signal"] = GameState.rerolls_left
	_choice.hide()
	await get_tree().process_frame
	GameState.jamo_inventory = saved_inventory


## The reroll button must be reachable and operable from the keyboard.
func _case_accessibility() -> void:
	GameState.day = 6
	GameState.begin_day()
	_choice.open()
	await get_tree().process_frame
	_reroll_button.grab_focus()
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner() == _reroll_button
	_report["accessibility"] = {
		"focus_mode": _reroll_button.focus_mode,
		"grab_focus_works": focused,
		"button_text": _reroll_button.text,
		"label_text": _reroll_label.text,
	}
	await _shot("13_choice_button_focused")
	_choice.hide()
	await get_tree().process_frame


## Doc v0.3 section 37: the .tres must expose its numbers in the Inspector.
func _case_inspector_visibility() -> void:
	var reroll: UpgradeData = GameState.database.find_upgrade(REROLL_ID)
	_report["inspector"] = {
		"in_database": reroll != null,
		"editor_properties": _editor_properties(reroll),
		"costs": reroll.costs if reroll != null else PackedInt64Array(),
		"values": reroll.values if reroll != null else PackedFloat32Array(),
		"level_unlock_days": reroll.level_unlock_days if reroll != null else PackedInt32Array(),
		"unlock_day": reroll.unlock_day if reroll != null else -1,
	}


# --- Helpers ---------------------------------------------------------------

## Sends a real left click at the control's on-screen centre, so the GUI layer
## decides whether the press is delivered at all.
func _click(control: Control) -> void:
	var centre: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = centre
		event.global_position = centre
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _card_texts() -> Array:
	var texts: Array = []
	for card: JamoCard in _cards:
		if card.visible:
			texts.append(card.get_node("CardButton").text)
	return texts


func _overlap(a: Variant, b: Variant) -> int:
	var count := 0
	for item: String in a:
		if b.has(item):
			count += 1
	return count


func _choice_snapshot(name: String) -> Dictionary:
	_choice.open()
	await get_tree().process_frame
	var state := {
		"row_visible": _reroll_row.visible,
		"button_disabled": _reroll_button.disabled,
		"label_text": _reroll_label.text,
		"candidates": _card_texts(),
		"rerolls_left": GameState.rerolls_left,
		"max_rerolls": GameState.get_max_rerolls(),
	}
	await _shot(name)
	_choice.hide()
	await get_tree().process_frame
	return state


func _shop_snapshot(name: String) -> Dictionary:
	_shop.open()
	await get_tree().process_frame
	var state := {"row_visible": _shop_row.visible, "day": GameState.day}
	if _shop_row.visible:
		state["name_text"] = _shop_row.get_node("Row/TextBox/NameLabel").text
		state["value_text"] = _shop_row.get_node("Row/TextBox/ValueLabel").text
		state["cost_text"] = _shop_row.get_node("Row/CostLabel").text
		state["button_text"] = _shop_row.get_node("Row/BuyButton").text
		state["button_disabled"] = _shop_row.get_node("Row/BuyButton").disabled
	await _shot(name)
	_shop.hide()
	await get_tree().process_frame
	return state


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [ARTIFACT_DIR, name])


func _editor_properties(resource: Resource) -> Array:
	var names: Array = []
	if resource == null:
		return names
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_EDITOR:
			names.append(property["name"])
	return names


func _backup_save() -> void:
	_had_backup = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_backup:
		_saved_backup = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


## The harness writes to the real save file, so it puts the original back.
func _restore_save() -> void:
	if _had_backup:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if file == null:
			push_error("QA reroll harness: cannot restore the save backup.")
			return
		file.store_string(_saved_backup)
		file.close()
	else:
		SaveManager.delete_save()


func _write_report() -> void:
	var file := FileAccess.open("%s/reroll_report.json" % ARTIFACT_DIR, FileAccess.WRITE)
	if file == null:
		push_error("QA reroll harness: cannot write the report.")
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
