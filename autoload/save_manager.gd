extends Node

## JSON save file in the user data folder. Doc v0.4 section 45.
##
## The file holds three independent blocks:
##   meta   - permanent progress, written at every settle point.
##   run    - the run in progress, written only so an interrupted session can be
##            resumed. Cleared the moment a run fails; a defeat is not
##            recoverable. Doc v0.4 section 44.
##   audio  - the volume mixer, which is neither meta nor run.
##
## Only ids, levels and values are persisted, never Resources, so rebalancing a
## .tres never invalidates an existing save.

const SAVE_PATH := "user://jamo_save.json"
## 1 = v0.3 Day save. 2 = v0.4 meta/run split.
const SAVE_VERSION := 2
const LEGACY_V03_VERSION := 1

## True once a meta block has been read, so callers know whether this is a
## first launch.
var loaded_existing_save: bool = false
## True when the last load_game() upgraded a v0.3 file. The hub reports it so a
## returning player is told what happened to the old run.
var migrated_from_v03: bool = false


# --- Writing ----------------------------------------------------------------

## Writes permanent progress. The run block on disk is left untouched.
func save_meta() -> bool:
	var payload: Dictionary = peek_save()
	payload["save_version"] = SAVE_VERSION
	payload["meta"] = MetaState.to_dict()
	payload["audio"] = AudioManager.to_dict()
	return _write(payload)


## Writes permanent progress and the run in progress together. A run that has
## already ended is dropped instead of stored. Doc v0.4 section 44.
func save_run() -> bool:
	var payload: Dictionary = peek_save()
	payload["save_version"] = SAVE_VERSION
	payload["meta"] = MetaState.to_dict()
	payload["audio"] = AudioManager.to_dict()
	if RunState.is_active:
		payload["run"] = RunState.to_dict()
	else:
		payload.erase("run")
	return _write(payload)


## Drops the run in progress, keeping every permanent record. This is the only
## thing a failed run erases. Doc v0.4 section 35.
func clear_run() -> bool:
	var payload: Dictionary = peek_save()
	payload["save_version"] = SAVE_VERSION
	payload["meta"] = MetaState.to_dict()
	payload["audio"] = AudioManager.to_dict()
	payload.erase("run")
	return _write(payload)


## Merges the volume sliders into the file without writing progress. Used when
## the settings panel is opened from the hub before anything has been loaded.
func save_settings() -> bool:
	var payload: Dictionary = peek_save()
	payload["save_version"] = SAVE_VERSION
	payload["audio"] = AudioManager.to_dict()
	return _write(payload)


## Wipes permanent progress and the run, keeping the mixer. Only the explicit
## "start over" path calls this. Doc v0.4 section 3.1.
func clear_progress() -> bool:
	loaded_existing_save = false
	MetaState.reset()
	RunState.reset()
	return _write({
		"save_version": SAVE_VERSION,
		"audio": AudioManager.to_dict(),
	})


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


# --- Reading ----------------------------------------------------------------

## Raw contents of the save file, or an empty dictionary when there is no file
## or it cannot be parsed. Never touches the state singletons.
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


## The permanent block as it sits on disk, already migrated when the file is
## still a v0.3 save. Empty when there is no progress at all.
func peek_meta() -> Dictionary:
	var data: Dictionary = peek_save()
	if data.has("meta"):
		var meta: Variant = data["meta"]
		return meta if meta is Dictionary else {}
	if _is_legacy_v03(data):
		return _migrate_v03(data)
	return {}


## The run block as it sits on disk. Empty when no run is waiting.
func peek_run() -> Dictionary:
	var run: Variant = peek_save().get("run", {})
	if not (run is Dictionary) or run.is_empty():
		return {}
	# A core at zero is a run that already failed, so it is not offered back.
	if float(run.get("core_hp", 0.0)) <= 0.0:
		return {}
	return run


## True when the file holds permanent progress worth continuing from.
func has_save() -> bool:
	return not peek_meta().is_empty()


## True when a run was interrupted and can be resumed. Doc v0.4 section 44.
func has_run_save() -> bool:
	return not peek_run().is_empty()


## Applies the stored volumes only. The hub runs before any progress is loaded,
## but its settings panel still has to show what was set before.
func load_audio_settings() -> void:
	var audio: Variant = peek_save().get("audio", {})
	# Saves written before the volume sliders existed have no "audio" key; those
	# keep the defaults instead of dropping to silence.
	AudioManager.from_dict(audio if audio is Dictionary else {})


## Reads permanent progress into MetaState. Returns false when there is nothing
## to load, in which case MetaState is left at its defaults. The run block is
## not touched here; the hub decides whether to resume it.
func load_game() -> bool:
	loaded_existing_save = false
	migrated_from_v03 = false
	var data: Dictionary = peek_save()
	load_audio_settings()

	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning(
			"SaveManager: save version %d is newer than %d; loading anyway."
			% [version, SAVE_VERSION]
		)

	var meta: Dictionary = {}
	if data.has("meta") and data["meta"] is Dictionary:
		meta = data["meta"]
	elif _is_legacy_v03(data):
		meta = _migrate_v03(data)
		migrated_from_v03 = true
	if meta.is_empty():
		MetaState.reset()
		return false

	MetaState.from_dict(meta)
	MetaState.save_version = maxi(version, LEGACY_V03_VERSION)
	loaded_existing_save = true
	if migrated_from_v03:
		# Rewrite the file in the new shape straight away, keeping the original
		# payload under legacy_v03 so nothing that was earned is thrown away
		# even though v0.4 has no place left for most of it.
		_write({
			"save_version": SAVE_VERSION,
			"meta": MetaState.to_dict(),
			"audio": AudioManager.to_dict(),
			"legacy_v03": data,
		})
	return true


## Reads the interrupted run into RunState. Returns false when there is nothing
## to resume, leaving RunState cleared.
func load_run() -> bool:
	var run: Dictionary = peek_run()
	if run.is_empty():
		RunState.reset()
		return false
	RunState.from_dict(run)
	return RunState.is_active


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


# --- v0.3 compatibility -----------------------------------------------------

## A v0.3 save is any file that carries the old top-level "day" counter.
func _is_legacy_v03(data: Dictionary) -> bool:
	return not data.has("meta") and data.has("day")


## Turns a v0.3 payload into a v0.4 meta block.
##
## Gold and the upgrade levels carry over untouched. Words that were unlocked
## become codex entries, because in v0.4 a crafted word is permanently *known*
## even though its effect is no longer permanently *active*
## (doc v0.4 section 38).
##
## What cannot carry over, and why:
##   day             - Day and Wave are different axes; a Day 40 clicker run is
##                     not a Wave 40 roguelite run, so mapping it would hand out
##                     a record that was never earned. Doc v0.4 section 5.
##   jamo_inventory  - the jamo pool is now a per-run bag. Doc v0.4 section 2.4.
##   target_word     - the target-word focus no longer exists.
##   rerolls_left    - run-scoped, and there is no run to resume.
##
## Those are dropped from the live state, but the whole original payload is kept
## in the rewritten file under "legacy_v03", so nothing is destroyed silently.
func _migrate_v03(data: Dictionary) -> Dictionary:
	var upgrades: Dictionary = {}
	var stored_upgrades: Variant = data.get("upgrade_levels", {})
	if stored_upgrades is Dictionary:
		for key: String in stored_upgrades:
			upgrades[key] = int(stored_upgrades[key])

	var codex: Array[String] = []
	var stored_words: Variant = data.get("unlocked_words", [])
	if stored_words is Array:
		for word_id: Variant in stored_words:
			codex.append(String(word_id))

	return {
		"gold": maxf(0.0, float(data.get("gold", 0.0))),
		"permanent_upgrade_levels": upgrades,
		"codex_words": codex,
		"highest_wave": 1,
		"statistics": {"migrated_from_v03_day": float(data.get("day", 1))},
	}
