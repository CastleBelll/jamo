extends Node

## QA harness for the F6 settings / AudioManager round trip. Runs the real
## main.tscn and drives the real settings panel, then writes what it saw.
##
## Run windowed, in three phases, in this order:
##   godot --path . tests/qa_f6_settings.tscn -- write
##   godot --path . tests/qa_f6_settings.tscn -- read
##   godot --path . tests/qa_f6_settings.tscn -- legacy
##
## Doc v0.3 sections 25, 30.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ARTIFACT_DIR := "res://tests/qa_artifacts/f6"
## The positions the write phase leaves behind for the read phase to find.
const WRITTEN_SFX := 0.5
const WRITTEN_BGM := 0.25
const WRITTEN_MASTER := 0.0
## A save from before the volume sliders existed: no "audio" key at all.
const LEGACY_SAVE := {
	"day": 3,
	"gold": 120.0,
	"jamo_inventory": {},
	"rerolls_left": 0,
	"save_version": 1,
	"unlocked_words": [],
	"upgrade_levels": {"click_damage": 2},
}

var _main: Node
var _settings: Control
var _report: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var phase: String = "read"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		phase = args[0]

	if phase == "legacy":
		_write_legacy_save()

	_main = load(MAIN_SCENE).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_settings = _main.get_node("UI/Settings")

	_report["phase"] = phase
	_report["save_path"] = SaveManager.SAVE_PATH
	match phase:
		"write":
			await _phase_write()
		"legacy":
			await _phase_legacy()
		_:
			await _phase_read()

	_write_report(phase)
	get_tree().quit()


## Moves the three sliders through their real signals and closes the panel,
## which is the code path that writes the save.
func _phase_write() -> void:
	_settings.open()
	await get_tree().process_frame
	_report["before"] = _slider_state()
	await _shot("settings_default")

	(_settings.get_node("%SfxSlider") as HSlider).value = WRITTEN_SFX
	(_settings.get_node("%BgmSlider") as HSlider).value = WRITTEN_BGM
	await get_tree().process_frame
	_report["after_sfx_and_bgm"] = _slider_state()
	await _shot("settings_sfx_50")

	(_settings.get_node("%MasterSlider") as HSlider).value = WRITTEN_MASTER
	await get_tree().process_frame
	_report["after_master_zero"] = _slider_state()
	await _shot("settings_master_0")

	(_settings.get_node("%SettingsCloseButton") as Button).pressed.emit()
	await get_tree().process_frame
	_report["panel_closed"] = not _settings.visible
	_report["saved_file"] = _read_save_file()


## Fresh process: the volumes have to come back from the save file, and the
## panel has to show them rather than the values baked into the scene.
func _phase_read() -> void:
	_report["restored_before_opening_panel"] = {
		"master": AudioManager.get_volume(AudioManager.BUS_MASTER),
		"bgm": AudioManager.get_volume(AudioManager.BUS_BGM),
		"sfx": AudioManager.get_volume(AudioManager.BUS_SFX),
	}
	_settings.open()
	await get_tree().process_frame
	_report["sliders"] = _slider_state()
	_report["saved_file"] = _read_save_file()
	await _shot("settings_restored")


## A save written before this cycle has no "audio" key; it must load, keep the
## rest of the progress and fall back to full volume.
func _phase_legacy() -> void:
	_report["legacy_loaded"] = SaveManager.loaded_existing_save
	_report["legacy_day"] = GameState.day
	_report["legacy_gold"] = GameState.gold
	_report["legacy_click_damage_level"] = GameState.get_upgrade_level(&"click_damage")
	_settings.open()
	await get_tree().process_frame
	_report["sliders"] = _slider_state()
	await _shot("settings_legacy_save")


func _slider_state() -> Dictionary:
	var state := {}
	for row: Array in [
		["master", "%MasterSlider", "%MasterValueLabel", AudioManager.BUS_MASTER],
		["bgm", "%BgmSlider", "%BgmValueLabel", AudioManager.BUS_BGM],
		["sfx", "%SfxSlider", "%SfxValueLabel", AudioManager.BUS_SFX],
	]:
		var bus: StringName = row[3]
		var index := AudioServer.get_bus_index(String(bus))
		state[row[0]] = {
			"slider": (_settings.get_node(row[1]) as HSlider).value,
			"label": (_settings.get_node(row[2]) as Label).text,
			"manager_volume": AudioManager.get_volume(bus),
			"bus_muted": index >= 0 and AudioServer.is_bus_mute(index),
			"bus_volume_db": -999.0 if index < 0 else AudioServer.get_bus_volume_db(index),
		}
	return state


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {"exists": false}
	var text := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var keys: Array = []
	if parsed is Dictionary:
		keys = (parsed as Dictionary).keys()
	return {"exists": true, "keys": keys, "content": parsed}


func _write_legacy_save() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("qa_f6_settings: cannot write the legacy save")
		return
	file.store_string(JSON.stringify(LEGACY_SAVE, "\t"))
	file.close()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [ARTIFACT_DIR, label])


func _write_report(phase: String) -> void:
	var path := "%s/qa_f6_settings_%s.json" % [ARTIFACT_DIR, phase]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("qa_f6_settings: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	print(JSON.stringify(_report, "\t"))
	print("OK - F6 settings phase %s written to %s" % [phase, path])
