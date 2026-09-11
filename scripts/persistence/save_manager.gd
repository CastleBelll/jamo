class_name SaveManager
extends RefCounted
## Single-profile JSON persistence (G14): write to a temp file, validate, swap it in, keep
## the previous good file as backup. Loading falls back to the backup and reports corruption
## instead of silently starting over.

const DEFAULT_PATH := "user://jamo_save.json"
const SAVE_VERSION := 1

var path: String = DEFAULT_PATH


func backup_path() -> String:
	return path + ".bak"


func temp_path() -> String:
	return path + ".tmp"


func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(backup_path())


## Atomic replace: temp -> verify -> backup old -> rename. Returns false on any failure.
func save(profile: Dictionary) -> bool:
	profile["save_version"] = SAVE_VERSION
	var text := JSON.stringify(profile, "\t")
	var f := FileAccess.open(temp_path(), FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s (%s)" % [temp_path(), error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	if _read_valid(temp_path()).is_empty():
		push_error("SaveManager: temp file failed verification")
		DirAccess.remove_absolute(temp_path())
		return false
	if FileAccess.file_exists(path):
		var err := DirAccess.rename_absolute(path, backup_path())
		if err != OK:
			push_error("SaveManager: backup failed (%s)" % error_string(err))
			return false
	var err2 := DirAccess.rename_absolute(temp_path(), path)
	if err2 != OK:
		push_error("SaveManager: swap failed (%s)" % error_string(err2))
		return false
	return true


## Returns {"profile": Dictionary, "source": "main"|"backup"|"none", "corrupt": bool}.
func load() -> Dictionary:
	var main := _read_valid(path)
	if not main.is_empty():
		return {"profile": main, "source": "main", "corrupt": false}
	var main_exists := FileAccess.file_exists(path)
	var backup := _read_valid(backup_path())
	if not backup.is_empty():
		return {"profile": backup, "source": "backup", "corrupt": main_exists}
	return {"profile": {}, "source": "none", "corrupt": main_exists or FileAccess.file_exists(backup_path())}


func delete_all() -> void:
	for p in [path, backup_path(), temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read_valid(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not parsed.has("save_version") or not parsed.has("meta"):
		return {}
	return parsed
