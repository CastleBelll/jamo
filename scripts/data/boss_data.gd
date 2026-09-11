class_name BossData
extends Resource
## Full boss sheet (B9). Phase 2 values apply from the next scheduled pattern after the threshold.

@export var id: StringName = &""
@export var name: String = ""
@export var wave: int = 5
@export var hp: float = 0.0
@export_range(0.0, 1.0) var phase2_hp_ratio: float = 0.5
@export var pattern_first_at: float = 0.0
@export var pattern_period: float = 0.0
@export var pattern_period_p2: float = 0.0
@export var warn_time: float = 0.0
@export var warn_time_p2: float = 0.0
@export var respond_count: int = 0
@export var respond_count_p2: int = 0
@export var fail_damage: float = 0.0
## 침묵: seal duration when a sealable word exists; fail_damage applies otherwise.
@export var seal_duration: float = 0.0
@export var gold: int = 0
## G10 보스 등장: the single response line shown before combat.
@export var response_hint: String = ""
@export var boss_position: Vector2 = Vector2(960, 260)
## PatternTarget positions; W15 lists one per lane (좌/중/우).
@export var marker_positions: Array[Vector2] = []
## Each entry: {"t": float, "count": int, "jamo": String} ("" = B5 weighted draw).
@export var minion_schedule: Array[Dictionary] = []
@export var minion_hp: float = 0.0
@export var minion_travel_time: float = 0.0
@export var minion_concurrent_max: int = 4
@export var minion_gold: int = 1
## Guaranteed body drop tokens (W5 ㅁ×2, W15 ㅇ×2), outside the normal drop cap.
@export var body_drop: Array[String] = []
## 탐욕: shield per designated minion purify, cap, and lockout after a broken ring.
@export var shield_per_minion: float = 0.0
@export var shield_cap: float = 0.0
@export var shield_lockout: float = 0.0

## Boss click capsule covers the 360x100 glyph area; a 90px marker must clear it.
const MARKER_CLEARANCE := 230.0


func validate() -> Array[String]:
	var errors: Array[String] = []
	var p := "boss %s" % id
	if id == &"" or hp <= 0.0 or pattern_period <= 0.0 or warn_time <= 0.0 or respond_count <= 0:
		errors.append("%s: id/hp/period/warn/respond required" % p)
	if marker_positions.is_empty():
		errors.append("%s: needs at least one marker position" % p)
	for m in marker_positions:
		if m.distance_to(boss_position) < MARKER_CLEARANCE:
			errors.append("%s: marker %s overlaps boss click area" % [p, m])
	for entry in minion_schedule:
		if not entry.has("t") or not entry.has("count"):
			errors.append("%s: minion entry %s needs t and count" % [p, entry])
	return errors
