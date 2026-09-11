class_name SynergyData
extends Resource
## Tag-threshold synergy (B8). Counts distinct active word IDs per tag.

@export var id: StringName = &""
## Each entry: {"tag": StringName, "min": int}. All must be met.
@export var conditions: Array[Dictionary] = []
@export var effect: Resource
@export var description: String = ""


func validate() -> Array[String]:
	var errors: Array[String] = []
	if conditions.is_empty():
		errors.append("synergy %s: no conditions" % id)
	for c in conditions:
		if StringName(c.get("tag", "")) not in WordData.TAGS or int(c.get("min", 0)) <= 0:
			errors.append("synergy %s: bad condition %s" % [id, c])
	var e := effect as EffectData
	if e == null:
		errors.append("synergy %s: effect is not EffectData" % id)
	else:
		errors.append_array(e.validate("synergy %s" % id))
	return errors
