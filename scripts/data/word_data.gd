@tool
class_name WordData
extends Resource

## One craftable word. Doc v0.4 section 21.
##
## A word is a RUN item, not a permanent unlock: crafting it registers the word
## in MetaState.codex_words forever, but its effects only apply while it sits in
## RunState.equipped_words. Doc v0.4 section 38.
##
## Deviation from section 21, deliberate: the spec lists `base_effect_ids` and
## `risk_effect_ids` as ids. Effects are stored here as direct WordEffectData
## resource references instead, because section 46 wants tunable data to live in
## .tres files the Inspector can open rather than behind a string lookup table.
## Ids remain for cross-resource links (compounds, synergies, bosses), which do
## point at resources this one must not own.

## Which RUN slot the word occupies. Doc v0.4 section 10.
enum SlotType {
	## 장비 - direct combat stats. 4 slots.
	EQUIPMENT,
	## 유물 - passive rule changes. 3 slots.
	RELIC,
	## 특수효과 - triggered effects. 2 slots.
	SPECIAL,
	## 위험 단어 - upside with a stated downside. 2 slots. Doc v0.4 section 2.6.
	RISK,
}

@export var id: StringName = &"fire_001"
## The word itself, e.g. "불".
@export var word: String = "불"
## Name shown in the UI when it should differ from `word`. Empty falls back to
## `word`, which is the normal case for a single-word item.
@export var display_name: String = ""

@export var slot_type: SlotType = SlotType.EQUIPMENT
## Meaning tags the synergy system groups on, e.g. &"fire", &"weapon".
## Doc v0.4 section 2.5: tags are a meaning link, not a colour.
@export var tags: Array[StringName] = []

## Every jamo needed, duplicates included. "밥" is ["ㅂ", "ㅏ", "ㅂ"].
@export var required_jamo: PackedStringArray = PackedStringArray()
## Highest rank this word can reach by being re-crafted in one run.
## Doc v0.4 section 11.
@export_range(1, 5) var run_max_rank: int = 3

## Effects granted at rank 1. See the deviation note above.
@export var base_effects: Array[WordEffectData] = []
## Multiplier applied to the base effect values at each rank, entry i for
## rank i + 1. Empty means every rank behaves like rank 1 for now; the real
## curve is Phase 3 work. Doc v0.4 section 11.
@export var rank_effect_values: PackedFloat32Array = PackedFloat32Array()

## Compound recipes this word takes part in. Doc v0.4 section 22.
@export var compound_recipe_ids: Array[StringName] = []
## Synergy lines this word counts towards. Doc v0.4 section 23.
@export var synergy_ids: Array[StringName] = []

@export_group("Risk")
## Doc v0.4 section 2.6: the downside must be visible before the choice, so it
## is data on the word rather than a surprise applied at runtime.
@export var is_risk_word: bool = false
@export var risk_effect_ids: Array[StringName] = []

@export_group("Codex")
## Mastery experience needed for each level, entry i for level i + 1.
## Doc v0.4 section 12.
@export var codex_mastery_curve: PackedFloat32Array = PackedFloat32Array()
## Shown as ??? until the word is discovered. Doc v0.4 section 29.
@export var codex_hidden_before_discovery: bool = true

@export_group("Unlock")
## Free-form condition id evaluated by the codex. Empty means the word is in the
## pool from the first run. Replaces v0.3's `prerequisites`, which no longer
## exists: word-to-word chains are now compounds (section 22), and gated words
## come from beating a boss (section 20).
@export var unlock_condition: StringName = &""
## Word boss that must be defeated before this word can be crafted.
@export var required_boss_id: StringName = &""

@export_group("Presentation")
@export var icon: Texture2D
@export var vfx_id: StringName = &""
@export var sfx_id: StringName = &""
@export_multiline var description: String = ""


## What the UI should call this word.
func get_display_name() -> String:
	return display_name if not display_name.is_empty() else word


## required_jamo folded into {jamo: count}.
func required_counts() -> Dictionary:
	var counts: Dictionary = {}
	for jamo: String in required_jamo:
		counts[jamo] = int(counts.get(jamo, 0)) + 1
	return counts


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Multiplier on the base effect values at the given 1-based run rank. Ranks
## past the defined curve stay on its last entry rather than growing forever.
func rank_multiplier(rank: int) -> float:
	if rank <= 1 or rank_effect_values.is_empty():
		return 1.0
	return rank_effect_values[mini(rank, rank_effect_values.size()) - 1]
