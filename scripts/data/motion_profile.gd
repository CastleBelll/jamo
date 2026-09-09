@tool
class_name MotionProfile
extends Resource

## One of the six walk personalities from doc v0.3 section 7.2.
## The visual shape of the walk lives in the shared AnimationLibrary at
## res://resources/animations/walk_library.tres - open any monster scene and
## scrub the AnimationPlayer to tune the bounce, squash and tilt curves.
## This resource only carries the numbers the movement code needs.

@export var profile_name: StringName = &"HEAVY_STEP"
## Animation name inside the shared AnimationLibrary, e.g. "walk_heavy_step".
@export var walk_animation: StringName = &"walk_heavy_step"

@export_group("Movement")
## Multiplied into JamoMonsterData.base_speed. Doc v0.3 section 5.
@export_range(0.1, 3.0, 0.01) var move_speed_multiplier: float = 1.0
## AnimationPlayer speed_scale for the walk clip - the step frequency.
@export_range(0.1, 3.0, 0.01) var step_frequency: float = 1.0
## How sharply the monster turns its heading toward a new target.
@export_range(0.5, 20.0, 0.1) var turn_speed: float = 6.0

@export_group("Idle")
## Random pause between walks, in seconds.
@export_range(0.0, 10.0, 0.05) var idle_min: float = 0.6
@export_range(0.0, 10.0, 0.05) var idle_max: float = 1.8

@export_group("Spacing")
## Monsters closer than this nudge away from each other. Doc v0.3 section 4.1.
@export_range(0.0, 3.0, 0.05) var avoidance_radius: float = 0.55
