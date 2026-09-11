class_name DeckData
extends Resource
## Starter deck (B6): 20 tokens as a multiset of jamo strings.

@export var id: StringName = &""
@export var name: String = ""
@export var tokens: Array[String] = []
## Research id that unlocks this deck; empty = available from the start.
@export var unlock_research: StringName = &""


func counts() -> Dictionary:
	var out := {}
	for j in tokens:
		out[j] = out.get(j, 0) + 1
	return out


func validate(expected_size: int) -> Array[String]:
	var errors: Array[String] = []
	if tokens.size() != expected_size:
		errors.append("deck %s: %d tokens, expected %d" % [id, tokens.size(), expected_size])
	return errors
