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
	## Adds to the per-tick damage of the burn unlocked by 불. Word: 화염.
	## New types go at the end: the stored .tres files hold the integer value.
	BURN_TICK_BONUS,
	## A monster that dies burning passes its burn on. Word: 불꽃.
	BURN_SPREAD,
	## Adds to CritChance as a fraction, e.g. 0.10 = +10%p. Word: 강타.
	CRIT_CHANCE,
	## Unlocks golden monster spawns. Word: 금.
	UNLOCK_GOLDEN,
	## Multiplies the special monster spawn chance, as a fraction. Word: 운.
	SPECIAL_LUCK,
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

@export_group("Spread")
## Search radius for a spread or chain effect, in metres. The word tree quotes
## pixels; the arena camera is orthographic with size 9.6 over a 720 px tall
## viewport, so 75 px is one metre.
@export_range(0.0, 10.0, 0.01) var radius: float = 0.0
## How many neighbours one spread reaches.
@export_range(0, 8) var chain_count: int = 0
## How many times a spread may hop before it stops. 1 means a burn passed on by
## a death cannot pass itself on again, which is what keeps 불꽃 from chaining
## across the whole field.
@export_range(1, 8) var max_chain_depth: int = 1
