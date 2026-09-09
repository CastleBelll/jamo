@tool
class_name WordData
extends Resource

## One craftable word. Doc v0.3 section 22.3.
##
## Jamo are collected into an unordered inventory. A word completes as soon as
## the inventory holds every required jamo (duplicates counted), and completing
## it consumes exactly those jamo. Leftover jamo stay in the inventory, so no
## day-end pick is ever wasted.

@export var id: StringName = &"fire_001"
## Displayed word, e.g. "불".
@export var word: String = "불"
## Tree branch this word belongs to: fire / gold / energy / power / ...
@export var category: StringName = &"fire"

## Every jamo needed, duplicates included. "밥" is ["ㅂ", "ㅏ", "ㅂ"].
@export var required_jamo: PackedStringArray = PackedStringArray()
## Word ids that must already be unlocked. Doc word_tree v0.1 section 15.
@export var prerequisites: Array[StringName] = []

@export var effects: Array[WordEffectData] = []
@export_range(1, 6) var tier: int = 1
@export_multiline var description: String = ""


## required_jamo folded into {jamo: count}.
func required_counts() -> Dictionary:
	var counts: Dictionary = {}
	for jamo: String in required_jamo:
		counts[jamo] = int(counts.get(jamo, 0)) + 1
	return counts
