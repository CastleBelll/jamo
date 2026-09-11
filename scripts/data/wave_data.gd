@tool
class_name WaveData
extends Resource

## One wave of the run. One .tres per wave under res://resources/waves/, listed
## in GameDatabase.waves. Doc v0.4 section 25: every number that shapes a wave
## lives here, never in a gameplay script (section 46).
##
## Doc v0.4 section 5.2 asks the curve to raise several axes at once - count,
## spawn rate, simultaneous enemies, speed, special ratio - rather than HP
## alone. Each wave sets those axes independently for that reason.

## What kind of wave this is. Only NORMAL is played before Phase 9 / 10.
enum WaveType { NORMAL, ELITE, MINI_BOSS, WORD_BOSS }

## 1-based wave index this data describes. GameDatabase.find_wave matches it.
@export_range(1, 999) var wave_number: int = 1

@export_group("Spawn")
## Monster scenes this wave draws its normal spawns from. Weighted by each
## scene's JamoMonsterData.spawn_weight, like the v0.3 pool.
@export var enemy_pool: Array[PackedScene] = []
## Total monsters the wave spawns. The wave is cleared once every one of them
## has been killed or has reached the 문장핵.
@export_range(1, 500) var enemy_count: int = 5
## Seconds between spawns while the field has room.
@export_range(0.05, 10.0, 0.05) var spawn_interval: float = 1.0
## Simultaneous monsters on the field. Doc v0.4 section 36 keeps 20 the ceiling.
@export_range(1, 20) var max_alive: int = 3

@export_group("Scaling")
## Multiplies GameBalance.base_monster_hp before the monster's own multiplier.
@export_range(0.1, 100.0, 0.05) var hp_multiplier: float = 1.0
## Multiplies every monster's walk speed this wave. Doc v0.4 section 5.2.
@export_range(0.1, 5.0, 0.01) var speed_multiplier: float = 1.0
## Multiplies GameBalance.base_monster_gold before the monster's own multiplier.
@export_range(0.1, 100.0, 0.05) var gold_multiplier: float = 1.0
## Chance one spawn is drawn from the SpawnManager special pool instead of
## enemy_pool, before the 운 luck multiplier. Doc v0.4 section 16.
@export_range(0.0, 1.0, 0.005) var special_spawn_rate: float = 0.0

@export_group("Type")
@export var wave_type: WaveType = WaveType.NORMAL
## Boss data id for MINI_BOSS / WORD_BOSS waves. Empty for a normal wave.
@export var boss_id: StringName = &""
## Reward tier handed to the Wave Clear screen. The reward tables are Phase 2.
@export_range(0, 10) var reward_tier: int = 1
