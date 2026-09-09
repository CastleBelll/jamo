@tool
class_name AudioLibrary
extends Resource

## File paths of the one-shot sounds the game plays, one slot per named cue in
## doc v0.3 section 25. Paths rather than AudioStream references on purpose:
## the audio assets are not in the repository yet, and a missing ext_resource
## would stop the whole .tres from loading. AudioManager resolves a path when
## the file exists and stays silent when it does not.
##
## Edit res://resources/audio/sfx_library.tres in the Inspector to point a cue
## at a file; no code change is needed.

@export_group("Click")
## Ordinary click on a monster.
@export_file("*.ogg", "*.wav", "*.mp3") var click: String = ""
## Critical click. Doc v0.3 section 10.2.
@export_file("*.ogg", "*.wav", "*.mp3") var click_critical: String = ""
## Click that lands on a golden individual. Doc v0.3 section 9.3.
@export_file("*.ogg", "*.wav", "*.mp3") var click_golden: String = ""
## A monster died.
@export_file("*.ogg", "*.wav", "*.mp3") var kill: String = ""

@export_group("UI")
## The word completion sting. Doc v0.3 section 14.2.
@export_file("*.ogg", "*.wav", "*.mp3") var word_complete: String = ""

@export_group("Music")
## Looping background track, started by AudioManager on the BGM bus.
@export_file("*.ogg", "*.wav", "*.mp3") var bgm: String = ""


## Path registered for a cue, or "" when the slot is empty or the key is not a
## cue at all. The keys are the property names above, so adding a cue is one
## exported line and no lookup table.
func path_for(key: StringName) -> String:
	var value: Variant = get(String(key))
	return value if value is String else ""
