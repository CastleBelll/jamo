extends Node

## JSON save file in the user data folder. Doc v0.3 section 30.
##
## Save points: day end, word completion, upgrade purchase, quit request.
## Only ids and levels are persisted so rebalancing a .tres never invalidates
## an existing save.

const SAVE_PATH := "user://jamo_save.json"
const SAVE_VERSION := 1

## True once a save file has been read, so callers know whether Day 1 is fresh.
var loaded_existing_save: bool = false


func save_game() -> bool:
	var payload: Dictionary = GameState.to_dict()
	payload["save_version"] = SAVE_VERSION
	# Volume sliders live in the same file as the rest of the progress rather
	# than a second settings file. Doc v0.3 section 30.
	payload["audio"] = AudioManager.to_dict()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error(
			"SaveManager: cannot write %s (error %d)"
			% [SAVE_PATH, FileAccess.get_open_error()]
		)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Reads the save file into GameState. Returns false when there is nothing to
## load or the file is unusable; the caller then starts a fresh Day 1.
func load_game() -> bool:
	loaded_existing_save = false
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"SaveManager: cannot read %s (error %d)"
			% [SAVE_PATH, FileAccess.get_open_error()]
		)
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not valid JSON, ignoring it." % SAVE_PATH)
		return false

	var data: Dictionary = parsed
	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning(
			"SaveManager: save version %d is newer than %d; loading anyway."
			% [version, SAVE_VERSION]
		)

	GameState.from_dict(data)
	# Saves written before the volume sliders existed have no "audio" key; those
	# keep the defaults instead of dropping to silence.
	var audio: Variant = data.get("audio", {})
	AudioManager.from_dict(audio if audio is Dictionary else {})
	loaded_existing_save = true
	return true


## Deletes the save file. Used by the settings panel.
func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var error: int = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(SAVE_PATH)
	)
	if error != OK:
		push_error("SaveManager: could not delete %s (error %d)" % [SAVE_PATH, error])
