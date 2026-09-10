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
	return _write(payload)


func _write(payload: Dictionary) -> bool:
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


## True when the file on disk holds an actual run. A file that only carries the
## volume sliders (changed at the title before any run started) does not count.
func has_save() -> bool:
	return peek_save().has("day")


## Reads the save file without touching GameState, so the title screen can show
## the day and gold of the run waiting to be continued. Empty when there is no
## file or the file cannot be parsed.
func peek_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"SaveManager: cannot read %s (error %d)"
			% [SAVE_PATH, FileAccess.get_open_error()]
		)
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not valid JSON, ignoring it." % SAVE_PATH)
		return {}
	return parsed


## Applies the stored volumes only. The title screen runs before any progress is
## loaded, but its settings panel still has to show what the player set before.
func load_audio_settings() -> void:
	var audio: Variant = peek_save().get("audio", {})
	# Saves written before the volume sliders existed have no "audio" key; those
	# keep the defaults instead of dropping to silence.
	AudioManager.from_dict(audio if audio is Dictionary else {})


## Merges the volume sliders into the file without writing progress. Used when
## the settings panel is opened from the title, where there is no run yet and a
## full save would look like progress waiting to be continued.
func save_settings() -> bool:
	var payload: Dictionary = peek_save()
	payload["save_version"] = SAVE_VERSION
	payload["audio"] = AudioManager.to_dict()
	return _write(payload)


## Drops the run from the save file while keeping the player's settings. The
## volume sliders are the player's environment, not run data, so 새 게임 and
## 저장 데이터 삭제 reset the progress without resetting the mixer.
## Older saves always carry "day", so a rewritten file reads as "no progress".
func clear_progress() -> bool:
	loaded_existing_save = false
	return _write({
		"save_version": SAVE_VERSION,
		"audio": AudioManager.to_dict(),
	})


## Reads the save file into GameState. Returns false when there is nothing to
## load or the file is unusable; the caller then starts a fresh Day 1.
func load_game() -> bool:
	loaded_existing_save = false
	var data: Dictionary = peek_save()
	load_audio_settings()
	if not data.has("day"):
		return false

	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning(
			"SaveManager: save version %d is newer than %d; loading anyway."
			% [version, SAVE_VERSION]
		)

	GameState.from_dict(data)
	loaded_existing_save = true
	return true


## Removes the save file outright, settings included. Progress resets go
## through clear_progress() instead; this is for tests that need a clean slate.
func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var error: int = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(SAVE_PATH)
	)
	if error != OK:
		push_error("SaveManager: could not delete %s (error %d)" % [SAVE_PATH, error])
