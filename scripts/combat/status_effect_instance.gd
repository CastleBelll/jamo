class_name StatusEffectInstance
extends RefCounted

## Runtime state of one status effect on one monster. The tunable numbers come
## from a WordEffectData resource, so adding a new effect means adding data,
## not editing the monster. Doc v0.3 section 16.

var effect_type: WordEffectData.EffectType
var damage_per_tick: float
var tick_interval: float
var max_stack: int

var stacks: int = 1
var time_left: float = 0.0

var _tick_timer: float = 0.0


func _init(effect: WordEffectData) -> void:
	effect_type = effect.effect_type
	damage_per_tick = effect.base_value
	tick_interval = maxf(0.05, effect.tick_interval)
	max_stack = maxi(1, effect.max_stack)
	time_left = effect.duration
	_tick_timer = tick_interval


## Re-applying refreshes the duration and adds a stack up to max_stack.
## Doc word_tree v0.1 section 3: burn does not stack, re-application resets it.
func refresh(effect: WordEffectData) -> void:
	time_left = effect.duration
	stacks = mini(stacks + 1, max_stack)


func is_expired() -> bool:
	return time_left <= 0.0


## Advances the timer and returns the damage owed this frame (0 when no tick
## landed). Ticks still fire after the day ends, and their kills still pay out.
## Doc v0.3 section 12.
func advance(delta: float) -> float:
	if is_expired():
		return 0.0
	time_left -= delta
	_tick_timer -= delta
	var damage := 0.0
	while _tick_timer <= 0.0:
		damage += damage_per_tick * stacks
		_tick_timer += tick_interval
	return damage
