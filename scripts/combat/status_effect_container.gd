class_name StatusEffectContainer
extends Node

## Holds every status effect currently on a monster and reports the damage they
## deal. Keeping this in its own node means a new word only needs new data plus
## a case in the apply switch, never a rewrite of JamoMonster.

## Damage produced by a tick. The owning monster decides how to apply it.
signal tick_damage(amount: float)
## Fired when the set of active effects changes, for status icons and VFX.
signal effects_changed()

var _instances: Dictionary = {}


func _process(delta: float) -> void:
	if _instances.is_empty():
		return
	var total := 0.0
	var expired: Array = []
	for key: int in _instances:
		var instance: StatusEffectInstance = _instances[key]
		total += instance.advance(delta)
		if instance.is_expired():
			expired.append(key)
	for key: int in expired:
		_instances.erase(key)
	if total > 0.0:
		tick_damage.emit(total)
	if not expired.is_empty():
		effects_changed.emit()


## Applies or refreshes an effect. Passing null is a no-op so callers can hand
## over RunState.get_burn_effect() without checking it first.
func apply(effect: WordEffectData) -> void:
	if effect == null or effect.duration <= 0.0:
		return
	if effect.proc_chance < 1.0 and randf() > effect.proc_chance:
		return
	var key: int = int(effect.effect_type)
	if _instances.has(key):
		(_instances[key] as StatusEffectInstance).refresh(effect)
	else:
		_instances[key] = StatusEffectInstance.new(effect)
	effects_changed.emit()


func has(effect_type: WordEffectData.EffectType) -> bool:
	return _instances.has(int(effect_type))


func is_empty() -> bool:
	return _instances.is_empty()


func clear() -> void:
	if _instances.is_empty():
		return
	_instances.clear()
	effects_changed.emit()
