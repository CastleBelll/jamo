@tool
class_name UpgradeData
extends Resource

## One permanent gold upgrade track. Doc v0.4 sections 13 and 28.
##
## costs[i] and values[i] describe level i+1. Level 0 is the base game value,
## so costs and values must always have the same length.
##
## v0.4 dropped the Day unlock gates: the gold price curve is the only pacing
## left. Doc v0.4 section 13.

@export var id: StringName = &"max_energy"
@export var display_name: String = "최대 에너지"
@export var category: StringName = &"activity"
@export_multiline var description: String = ""

## Gold price of each level, ascending. Length defines the max level.
@export var costs: PackedInt64Array = PackedInt64Array()
## Resulting value at each level, ascending. Must match costs in length.
@export var values: PackedFloat32Array = PackedFloat32Array()

@export_group("Display")
## Multiplies the raw value before display, e.g. 100 to show 0.05 as "5".
@export var value_display_scale: float = 1.0
## Appended after the scaled value, e.g. "%" or " 마리".
@export var value_suffix: String = ""

## True for a track no rule reads any more. The shop neither lists nor sells it;
## levels already bought stay in the save. monster_capacity is retired since
## v0.4 P1 (WaveData.max_alive owns the field size) and is removed in P5.
@export var is_retired: bool = false

@export_group("Unlock Conditions")
## Locked until this word is registered in the codex. Empty means no
## requirement. The codex is permanent, so this is a permanent gate; a word
## merely equipped in the current run does not open it. Doc v0.4 section 38.
@export var required_word: StringName = &""
## Locked until another upgrade track reaches required_level. Empty means no
## requirement.
@export var required_upgrade: StringName = &""
@export_range(0, 20, 1) var required_level: int = 0


func max_level() -> int:
	return costs.size()


## Gold price to go from level to level + 1. Returns -1 when already maxed.
func cost_for_next(level: int) -> int:
	if level < 0 or level >= costs.size():
		return -1
	return costs[level]


## Upgrade-provided value at the given level. Level 0 returns base_value
## because the first entry of values describes level 1.
func value_at(level: int, base_value: float) -> float:
	if level <= 0:
		return base_value
	var index: int = mini(level, values.size()) - 1
	if index < 0:
		return base_value
	return values[index]


## Human-readable form of the value at the given level, for the shop row.
func format_value(level: int, base_value: float) -> String:
	var scaled: float = value_at(level, base_value) * value_display_scale
	var rounded: float = snappedf(scaled, 0.01)
	var text: String = str(rounded) if rounded != floorf(rounded) else str(int(rounded))
	return text + value_suffix
