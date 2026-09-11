class_name EffectData
extends Resource
## One effect line of a word at one Rank (B7). Each Rank stores its full effect;
## ranks are never accumulated at runtime.

## Where the effect can be sourced from. Manual == click/hold/accessibility input.
const TRIGGERS: Array[StringName] = [
	&"passive",      # always-on stat modifier
	&"manual_hit",   # a manual input dealt real damage
	&"manual_kill",  # final blow source was manual
	&"kill",         # purify from any source
	&"periodic",     # every `interval` seconds, timer restarts each Wave
	&"wave_start",
	&"wave_clear",
]

const KINDS: Array[StringName] = [
	&"manual_damage_pct",          # value: additive to the manual damage sum (cap +100%)
	&"manual_damage_pct_lowhp",    # value: extra pct when target HP <= value2 ratio
	&"manual_damage_pct_near_end", # value: extra pct when remaining path <= value2 ratio
	&"crit_chance",                # value: additive crit chance (cap 0.35)
	&"apply_burn",                 # value: dps, duration
	&"burn_spread",                # value: dps, duration, radius_px, target_count
	&"apply_poison",               # value: dps per stack, duration, max_stacks
	&"apply_slow",                 # value: slow ratio, duration
	&"stability_damage_pct",       # value: negative = reduction (sum cap 0.35)
	&"stability_taken_pct",        # value: risk penalty, applied once
	&"damage_front",               # value: damage, target_count foremost enemies
	&"damage_lane_front_other",    # value: damage to the other foremost enemy in the lane
	&"damage_near_other",          # value: damage, radius_px
	&"heal_stability",             # value: amount
	&"clear_heal_bonus",           # value: added to Wave clear heal
	&"gold_pct",                   # value: additive gold multiplier
	&"heal_per_gold",              # value: heal per value2 gold, cap
	&"drop_chance_add",            # value: additive drop chance (cap 0.40 total)
	&"extra_remove_every_n",       # every_n: normal Wave multiple that grants one remove
	&"enemy_speed_pct",            # value: additive to enemy speed multiplier
	&"enemy_speed_mult",           # value: multiplied after slows/길 (폭주)
	&"shield",                     # value: shield at Wave start (total cap 20)
	&"dot_damage_pct",             # value: burn/poison damage bonus
	&"input_interval",             # value: replaces manual input interval seconds
	&"auto_period_mult",           # value: multiplies every periodic interval
	&"reward_pick_add",            # value: extra 자모 picks on normal Wave rewards (SY_ECON)
]

@export var kind: StringName = &""
@export var trigger: StringName = &"passive"
@export var value: float = 0.0
@export var value2: float = 0.0
@export var duration: float = 0.0
@export var interval: float = 0.0
## For counter triggers: fire once every N qualifying events (0 = every event).
@export var every_n: int = 0
@export var max_stacks: int = 0
@export var target_count: int = 1
@export var radius_px: float = 0.0
## Upper bound for capped values (e.g. 돈 heal per Wave). 0 = no cap.
@export var cap: float = 0.0


func validate(prefix: String) -> Array[String]:
	var errors: Array[String] = []
	if kind not in KINDS:
		errors.append("%s: unknown effect kind '%s'" % [prefix, kind])
	if trigger not in TRIGGERS:
		errors.append("%s: unknown trigger '%s'" % [prefix, trigger])
	if trigger == &"periodic" and interval <= 0.0:
		errors.append("%s: periodic effect needs interval > 0" % prefix)
	if kind in [&"apply_burn", &"apply_poison", &"apply_slow", &"burn_spread"] and duration <= 0.0:
		errors.append("%s: status effect needs duration > 0" % prefix)
	if kind == &"apply_poison" and max_stacks <= 0:
		errors.append("%s: poison needs max_stacks > 0" % prefix)
	if kind in [&"damage_near_other", &"burn_spread"] and radius_px <= 0.0:
		errors.append("%s: radius effect needs radius_px > 0" % prefix)
	return errors
