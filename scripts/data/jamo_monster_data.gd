@tool
class_name JamoMonsterData
extends Resource

## Per-jamo stats. One .tres per jamo under res://resources/monsters/.
## Doc v0.3 section 22.1.

@export var id: StringName = &"giyeok"
## The character itself, used by UI and word logic.
@export var jamo: String = "ㄱ"

@export_group("Combat")
## Multiplies the day-scaled base HP. 1.0 = normal monster.
@export_range(0.1, 10.0, 0.05) var hp_multiplier: float = 1.0
## Multiplies the day-scaled base gold. 1.0 = normal monster.
@export_range(0.1, 20.0, 0.05) var gold_multiplier: float = 1.0

@export_group("Movement")
## Metres per second before the motion profile multiplier is applied.
@export_range(0.1, 6.0, 0.05) var base_speed: float = 1.2
@export var motion_profile: MotionProfile

@export_group("Visual / Click")
## Uniform scale applied to the glyph. Smaller jamo are harder to click.
@export_range(0.2, 3.0, 0.05) var visual_scale: float = 1.0
## Radius of the click Area3D. Doc v0.3 section 8.3: keep it slightly larger
## than the visual so small jamo stay fair to click.
@export_range(0.1, 3.0, 0.05) var click_radius: float = 0.45

@export_group("Spawning")
## Relative weight in the spawn pool. Doc v0.3 section 28.
@export_range(0.0, 20.0, 0.1) var spawn_weight: float = 1.0
