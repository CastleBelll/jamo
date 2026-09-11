@tool
class_name JamoMonsterData
extends Resource

## Per-jamo stats. One .tres per jamo under res://resources/monsters/.
## Doc v0.3 section 22.1.

## What the spawn pool treats this monster as. Doc v0.3 section 28: the
## SpawnManager keeps one pool per kind.
enum SpecialType { NORMAL, SPECIAL, GOLDEN }

@export var id: StringName = &"giyeok"
## The character itself, used by UI and word logic.
@export var jamo: String = "ㄱ"

@export_group("Combat")
## Multiplies the wave-scaled base HP. 1.0 = normal monster.
@export_range(0.1, 10.0, 0.05) var hp_multiplier: float = 1.0
## Multiplies the wave-scaled base gold. 1.0 = normal monster.
@export_range(0.1, 20.0, 0.05) var gold_multiplier: float = 1.0
## 문장핵 HP taken off when this monster reaches it. 0 for a monster that only
## ever leaves on its own, like the golden individual. Doc v0.4 section 6.1.
@export_range(0.0, 20.0, 0.5) var core_damage: float = 1.0

@export_group("Movement")
## Metres per second before the motion profile multiplier is applied.
@export_range(0.1, 6.0, 0.05) var base_speed: float = 1.2
## Extra multiplier on top of the motion profile, so a special variant can be
## slower or faster than the jamo it inherits from without needing its own
## profile. Doc v0.3 section 9.
@export_range(0.1, 4.0, 0.05) var speed_multiplier: float = 1.0
@export var motion_profile: MotionProfile
## Extra breathing room between the glyph and the slab edge, in metres of
## half-diagonal. The body footprint itself is measured from the meshes and
## taken off automatically, so 0 already keeps the whole letter on the paper;
## raise this only to make a monster turn around further in. Doc v0.3 §27.
@export_range(0.0, 3.0, 0.05) var arena_margin: float = 0.0

@export_group("Visual / Click")
## Uniform scale applied to the glyph. Smaller jamo are harder to click.
@export_range(0.2, 3.0, 0.05) var visual_scale: float = 1.0
## Radius of the click Area3D. Doc v0.3 section 8.3: keep it slightly larger
## than the visual so small jamo stay fair to click.
@export_range(0.1, 3.0, 0.05) var click_radius: float = 0.45

@export_group("Spawning")
## Which pool this monster is drawn from. Doc v0.3 section 28.
@export var special_type: SpecialType = SpecialType.NORMAL
## Relative weight inside its own pool. Doc v0.3 section 28.
@export_range(0.0, 20.0, 0.1) var spawn_weight: float = 1.0
## Seconds the monster stays on the field before leaving on its own, paying no
## gold. 0 means it waits to be killed. The golden individual uses it to stay
## shorter than a normal one. Doc v0.3 section 9.3.
@export_range(0.0, 60.0, 0.5) var lifetime_seconds: float = 0.0
