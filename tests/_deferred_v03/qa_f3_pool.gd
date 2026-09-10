extends Node

## F3 QA probe: samples the day-end jamo candidate pool across unlock states and
## checks that an exhausted pool degrades gracefully. Read-only on game state.

const SAMPLES := 2000


func _ready() -> void:
	_sample([], "fresh (no words)")
	_sample([&"fire_001"], "after 불")
	_sample(
		[&"fire_001", &"power_001", &"gold_001", &"energy_001", &"luck_001"],
		"all tier-1 done"
	)

	var everything: Array[StringName] = []
	for word: WordData in GameState.database.words:
		everything.append(word.id)
	_apply(everything)
	print("all 10 unlocked -> craftable = %d" % GameState.get_craftable_words().size())
	var drawn := CandidateGenerator.generate(GameState.get_jamo_candidate_count())
	print("exhausted pool draw = %s (size %d)" % [str(drawn), drawn.size()])
	print("exhausted pool reroll = %s" % str(
		CandidateGenerator.regenerate(GameState.get_jamo_candidate_count(), drawn)
	))
	print("OK - pool probe finished.")
	get_tree().quit()


func _apply(word_ids: Array[StringName]) -> void:
	GameState.unlocked_word_ids = word_ids.duplicate()
	GameState.jamo_inventory.clear()
	GameState._recalculate_word_bonuses()


func _sample(word_ids: Array[StringName], label: String) -> void:
	_apply(word_ids)
	var seen: Dictionary = {}
	for _i in SAMPLES:
		for jamo: String in CandidateGenerator.generate(
			GameState.get_jamo_candidate_count()
		):
			seen[jamo] = true
	var keys: Array = seen.keys()
	keys.sort()
	print("%s -> pool %s" % [label, str(keys)])
