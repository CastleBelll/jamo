extends Node
## Local RUN log (B12 최소 필드): one JSON line per event under user://logs/, never sent
## anywhere. Autoloaded as `RunLog`. The game calls `event()`; tests read the file back.

const DIR := "user://logs"

var run_id: String = ""
var path: String = ""
var enabled: bool = true
var lines_written: int = 0


func begin_run(id: String, seed: int, content_version: String, research: Array, deck_id: String) -> void:
	run_id = id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	path = "%s/run_%s.jsonl" % [DIR, id.replace(":", "-")]
	lines_written = 0
	event("run_start", {"seed": seed, "content_version": content_version, "research": research, "deck": deck_id})


func event(kind: String, data: Dictionary = {}) -> void:
	if not enabled or path == "":
		return
	var record := {"t": Time.get_ticks_msec(), "run_id": run_id, "kind": kind}
	record.merge(data)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		push_warning("RunLog: cannot open %s" % path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(record))
	f.close()
	lines_written += 1


func read_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if path == "" or not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	f.close()
	return out


func end_run() -> void:
	path = ""
	run_id = ""
