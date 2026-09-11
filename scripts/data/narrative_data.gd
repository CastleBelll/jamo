class_name NarrativeData
extends Resource
## S5 event lines and the original-sentence stages (S3/S5). Ids are the S5 record ids.

## event id -> player-facing line(s), in the order they are shown.
@export var events: Dictionary = {}
## Original sentence as shown on the page, by stage 0..2 (첫 진입 / 침묵 정화 후 / 탐욕 정화 후).
@export var sentence_stages: Array[String] = []
## Boss id -> {"intro": String, "after": String} (S6).
@export var boss_lines: Dictionary = {}


func line(id: String) -> String:
	var v = events.get(id, "")
	if v is Array:
		return "\n".join(v)
	return String(v)


func validate() -> Array[String]:
	var errors: Array[String] = []
	for id in ["S_OPEN", "S_WORD", "S_M", "S_SILENCE", "S_RETURN", "S_GREED", "S_SLICE_END"]:
		if not events.has(id):
			errors.append("narrative: missing event %s" % id)
	if sentence_stages.size() != 3:
		errors.append("narrative: need 3 sentence stages")
	return errors
