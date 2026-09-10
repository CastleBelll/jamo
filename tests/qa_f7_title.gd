extends Node

## Boots the title exactly as the project does, then walks it with the keyboard
## only. Run: godot --headless --path . res://tests/qa_f7_title.tscn
## Doc v0.3 section 30 and DEV_ROADMAP F7 S1-S6.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
## The run this test throws away is moved aside instead of deleted, so running
## it locally does not cost the developer their own progress.
const BACKUP_PATH := "user://jamo_save.json.testbak"

var _failures: int = 0


func _ready() -> void:
	_stash_real_save()
	SaveManager.delete_save()
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame

	var focus_owner: Control = title.get_viewport().gui_get_focus_owner()
	_check(focus_owner != null, "the title must have a focus owner on entry")
	print("  entry focus: %s" % (focus_owner.name if focus_owner else "<none>"))

	# Every button has to be reachable by keyboard alone.
	var seen: Array[String] = []
	var cursor: Control = focus_owner
	for _step in 8:
		if cursor == null:
			break
		if not seen.has(String(cursor.name)):
			seen.append(String(cursor.name))
		var next: Control = cursor.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null or next == cursor:
			break
		next.grab_focus()
		cursor = title.get_viewport().gui_get_focus_owner()
	print("  keyboard reachable: %s" % ", ".join(seen))
	for required: String in ["NewGameButton", "SettingsButton", "QuitButton"]:
		_check(seen.has(required), "%s should be reachable with the keyboard" % required)
	_check(
		not seen.has("ContinueButton"),
		"the disabled 이어하기 must not sit in the focus chain"
	)

	# The settings panel is the shared one, minus the in-game only row.
	var settings: Control = title.get_node("%Settings")
	_check(not settings.run_in_progress, "the title settings panel is not a running run")
	settings.open()
	await get_tree().process_frame
	_check(settings.visible, "설정 should open the shared panel")
	_check(
		not settings.get_node("%DeleteSaveButton").visible,
		"저장 데이터 삭제 should stay hidden at the title"
	)
	_check(
		settings.get_node("%MasterSlider").visible,
		"the volume sliders should be available at the title"
	)
	# With the panel up, the keyboard must stay inside it: every slider has to be
	# reachable and no title button behind the panel may take focus, or Enter
	# would fire 새 게임 through an open modal.
	var panel_seen: Array[String] = []
	var escaped: Array[String] = []
	var walker: Control = settings.get_node("%SettingsCloseButton")
	for _step in 12:
		if walker == null:
			break
		if not panel_seen.has(String(walker.name)):
			panel_seen.append(String(walker.name))
		if not settings.is_ancestor_of(walker) and not escaped.has(String(walker.name)):
			escaped.append(String(walker.name))
		var up: Control = walker.find_valid_focus_neighbor(SIDE_TOP)
		if up == null:
			break
		walker = up
	print("  settings focus ring: %s" % ", ".join(panel_seen))
	_check(
		escaped.is_empty(),
		"focus escaped the open settings panel to: %s" % ", ".join(escaped)
	)
	for required: String in ["MasterSlider", "BgmSlider", "SfxSlider", "SettingsCloseButton"]:
		_check(
			panel_seen.has(required),
			"%s should be reachable with the keyboard while settings are open" % required
		)

	settings.get_node("%SfxSlider").value = 0.35
	settings.get_node("%SettingsCloseButton").pressed.emit()
	await get_tree().process_frame
	_check(
		title.get_viewport().gui_get_focus_owner() != null,
		"closing settings should hand focus back to the title"
	)
	_check(
		not SaveManager.has_save(),
		"changing volumes at the title must not create fake progress"
	)
	AudioManager.set_volume(AudioManager.BUS_SFX, 1.0)
	SaveManager.load_audio_settings()
	_check(
		absf(AudioManager.get_volume(AudioManager.BUS_SFX) - 0.35) < 0.001,
		"the volume set at the title should survive a reload, got %f"
		% AudioManager.get_volume(AudioManager.BUS_SFX)
	)

	_restore_real_save()
	if _failures == 0:
		print("OK - title screen checks passed.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % message)


## Moves any real save out of the way so the walk below starts from "no run".
func _stash_real_save() -> void:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return
	var error: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH),
		ProjectSettings.globalize_path(BACKUP_PATH)
	)
	if error != OK:
		printerr("  could not back up the save (error %d); aborting." % error)
		get_tree().quit(1)


func _restore_real_save() -> void:
	SaveManager.delete_save()
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	var error: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	)
	if error != OK:
		printerr("  could not restore the save from %s (error %d)." % [BACKUP_PATH, error])
		_failures += 1
