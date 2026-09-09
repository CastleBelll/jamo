@tool
class_name UpgradeData
extends Resource

## One gold upgrade track. Doc v0.3 section 22.5; prices come from
## growth_balance v0.2 sections 7-11.
##
## costs[i] and values[i] describe level i+1. Level 0 is the base game value,
## so costs and values must always have the same length.

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

@export_group("Unlock Conditions")
## Hidden until this day. Doc growth_balance v0.2 section 13.
@export var unlock_day: int = 1
## Day requirement of each level, ascending; entry i gates level i+1. Leave it
## empty when every level shares unlock_day, which is the case for all tracks
## except 리롤. Doc growth_balance v0.2 section 10.2.
@export var level_unlock_days: PackedInt32Array = PackedInt32Array()
## Hidden until this word is completed. Empty means no requirement.
@export var required_word: StringName = &""
## Hidden until another upgrade track reaches required_level. Empty means no
## requirement. growth_balance v0.2 section 8.3 gates 치명 클릭 behind 클릭 피해 Lv.3.
@export var required_upgrade: StringName = &""
@export_range(0, 20, 1) var required_level: int = 0


func max_level() -> int:
	return costs.size()


## Day the given 1-based level becomes purchasable. Falls back to unlock_day
## whenever the track has no per-level table.
func unlock_day_for_level(level: int) -> int:
	if level >= 1 and level <= level_unlock_days.size():
		return level_unlock_days[level - 1]
	return unlock_day


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
