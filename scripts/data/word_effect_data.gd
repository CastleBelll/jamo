@tool
class_name WordEffectData
extends Resource

## A single rule change granted by a completed word.
## Doc v0.3 section 22.4 / word_tree v0.1 section 18.

enum EffectType {
	## Adds to FlatWordBonus in the click damage formula. Word: 힘.
	FLAT_CLICK_DAMAGE,
	## Adds to WordGoldMultiplier as a fraction, e.g. 0.10 = +10%. Word: 돈.
	GOLD_MULTIPLIER,
	## Adds flat max energy. Word: 밥.
	MAX_ENERGY,
	## Unlocks the burn status effect on click. Word: 불.
	UNLOCK_BURN,
}

@export var effect_type: EffectType = EffectType.FLAT_CLICK_DAMAGE
## Meaning depends on effect_type. For UNLOCK_BURN this is per-tick damage.
@export var base_value: float = 1.0

@export_group("Status Effect")
## Total lifetime of the applied status, in seconds. Unused by stat effects.
@export_range(0.0, 60.0, 0.05) var duration: float = 0.0
## Seconds between damage ticks.
@export_range(0.05, 10.0, 0.05) var tick_interval: float = 1.0
## 0.0 to 1.0 chance to trigger on click.
@export_range(0.0, 1.0, 0.01) var proc_chance: float = 1.0
@export_range(1, 20) var max_stack: int = 1
