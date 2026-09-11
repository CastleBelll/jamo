class_name WaveData
extends Resource
## One Wave row of B2, or a boss Wave pointing at BossData (B9).

@export_range(1, 20) var wave: int = 1
@export var is_boss: bool = false
@export var boss_id: StringName = &""
@export var enemy_count: int = 0
@export var concurrent_max: int = 0
@export var spawn_interval: float = 0.0
@export var base_hp: float = 0.0
@export var travel_time: float = 0.0
@export_range(0.0, 1.0) var variant_chance: float = 0.0


func validate() -> Array[String]:
	var errors: Array[String] = []
	var p := "wave %d" % wave
	if is_boss:
		if boss_id == &"":
			errors.append("%s: boss wave needs boss_id" % p)
		return errors
	if enemy_count <= 0 or concurrent_max <= 0 or spawn_interval <= 0.0 or base_hp <= 0.0 or travel_time <= 0.0:
		errors.append("%s: normal wave needs positive count/concurrent/interval/hp/travel" % p)
	return errors
