class_name JamoMonster
extends Node2D
## One corrupted jamo walking a Path2D sub lane (G3/G11). Drawing, clicking and moving are
## separate nodes: VisualPivot animates, ClickArea is the fixed 76px circle, the root follows
## the path. The director owns purify/reach bookkeeping; this node only reports.

enum Variant { NORMAL, LIGHT, HEAVY, GUARD }

signal hp_changed(current: float, maximum: float)

var entity_id: int = 0
var jamo: String = ""
var variant: Variant = Variant.NORMAL
var hp: float = 1.0
var hp_max: float = 1.0
var path: Path2D
var lane: int = 0
var sub_lane: int = 0
## Distance travelled along the path in px.
var progress: float = 0.0
var path_length: float = 1.0
## Base px/s before slow/speed multipliers (B2 travel time).
var base_speed: float = 0.0
var speed_mult: float = 1.0
## B2 variant speed factor (LIGHT 1.25, HEAVY 0.8), applied under the resolver multiplier.
var variant_speed_mult: float = 1.0
## Alive == still a valid target. Purified or reached enemies flip this once, so bookkeeping
## can never run twice for the same entity (G7).
var alive: bool = true
const STATUS_ICON_START_X := -30.0
const STATUS_ICON_STEP := 26.0
var focused: bool = false:
	set(value):
		focused = value
		if is_node_ready():
			$FocusRing.visible = value

@onready var visual_pivot: Node2D = $VisualPivot
## G11 idle motion: shared MotionProfile, applied only to VisualPivot; a 0 shake setting
## zeroes the displacement while the click circle on the root stays identical.
var motion: MotionProfile
var motion_time: float = 0.0
var motion_scale: float = 1.0
@onready var glyph: Label = $VisualPivot/Glyph
@onready var anim: AnimationPlayer = $AnimationPlayer


func setup(id: int, jamo_char: String, max_hp: float, on_path: Path2D, travel_time: float, lane_index: int, sub_index: int) -> void:
	entity_id = id
	jamo = jamo_char
	hp_max = max_hp
	hp = max_hp
	path = on_path
	lane = lane_index
	sub_lane = sub_index
	path_length = maxf(on_path.curve.get_baked_length(), 1.0)
	base_speed = path_length / maxf(travel_time, 0.01)
	progress = 0.0
	position = on_path.to_global(on_path.curve.sample_baked(0.0))
	if is_node_ready():
		glyph.text = jamo
		_apply_glyph_texture()


func _ready() -> void:
	glyph.text = jamo
	$FocusRing.visible = focused
	_apply_glyph_texture()
	_refresh_variant_mark()
	for key in ["burn", "poison", "slow"]:
		var icon := get_node_or_null("StatusAnchor/Icon_%s" % key) as Sprite2D
		if icon != null:
			icon.texture = AssetLib.tex("status_%s" % key)


## Real glyph sprite when the art exists; the Label stays as fallback (G11).
func _apply_glyph_texture() -> void:
	var sprite := $VisualPivot/Sprite2D as Sprite2D
	var t := AssetLib.glyph(jamo)
	sprite.texture = t
	glyph.visible = t == null


func _process(delta: float) -> void:
	if motion == null or not alive:
		return
	motion_time += delta
	var phase := TAU * motion_time / maxf(motion.period, 0.05)
	visual_pivot.rotation = deg_to_rad(motion.rotation_deg) * sin(phase) * motion_scale
	visual_pivot.position.y = -absf(motion.bob_px * sin(phase)) * motion_scale


func set_motion(profile: MotionProfile, scale: float) -> void:
	motion = profile
	motion_scale = scale
	if profile == null or scale <= 0.0:
		visual_pivot.rotation = 0.0
		visual_pivot.position = Vector2.ZERO


## 상태 표시 (G12): icon text + stacks/remaining time, readable without colour.
func refresh_status_label(now: float) -> void:
	var label := get_node_or_null("StatusAnchor/StatusLabel") as Label
	if label == null:
		return
	var active := {"burn": burn_active(now), "poison": poison_count(now) > 0, "slow": strongest_slow(now) > 0.0}
	var has_icons := _layout_status_icons(active)
	var parts: Array[String] = []
	if active["burn"]:
		parts.append(("%.0f" if has_icons else "불 %.1fs") % (burn["until"] - now))
	var stacks := poison_count(now)
	if stacks > 0:
		parts.append(("x%d" if has_icons else "독 x%d") % stacks)
	if active["slow"]:
		parts.append(("%.0f" if has_icons else "둔 %.1fs") % (slow["until"] - now))
	label.text = " ".join(parts)


## Packs the active status icons left to right; returns false when no icon art is loaded.
func _layout_status_icons(active: Dictionary) -> bool:
	var has_icons := false
	var x := STATUS_ICON_START_X
	for key in ["burn", "poison", "slow"]:
		var icon := get_node_or_null("StatusAnchor/Icon_%s" % key) as Sprite2D
		if icon == null or icon.texture == null:
			continue
		has_icons = true
		icon.visible = active[key]
		if active[key]:
			icon.position.x = x
			x += STATUS_ICON_STEP
	return has_icons


func speed() -> float:
	return base_speed * speed_mult * variant_speed_mult


## B2/G3 variants: HP and speed factors plus the visible cue (잔상 화살표 / 이중 외곽선 /
## 끊어진 사각 테두리). GUARD has no stat change; its effect lives in the director.
func apply_variant(v: Variant, balance: BalanceConfig) -> void:
	variant = v
	match v:
		Variant.LIGHT:
			hp_max *= balance.light_hp_mult
			variant_speed_mult = balance.light_speed_mult
		Variant.HEAVY:
			hp_max *= balance.heavy_hp_mult
			variant_speed_mult = balance.heavy_speed_mult
		_:
			pass
	hp = hp_max
	if is_node_ready():
		_refresh_variant_mark()


func variant_name() -> String:
	return Variant.keys()[variant]


func _refresh_variant_mark() -> void:
	var mark := get_node_or_null("VisualPivot/VariantMark") as Label
	if mark == null:
		return
	match variant:
		Variant.LIGHT: mark.text = "▲"
		Variant.HEAVY: mark.text = "▣"
		Variant.GUARD: mark.text = "⌐"
		_: mark.text = ""
	var icon := get_node_or_null("VisualPivot/VariantIcon") as Sprite2D
	if icon == null:
		return
	var id: String = {Variant.LIGHT: "variant_light", Variant.HEAVY: "variant_heavy", Variant.GUARD: "variant_guard"}.get(variant, "")
	icon.texture = AssetLib.tex(id) if id != "" else null
	mark.visible = icon.texture == null


func remaining_path() -> float:
	return maxf(path_length - progress, 0.0)


## Seconds until the enemy reaches the sentence at its current speed (도달 예상시간).
func eta() -> float:
	return remaining_path() / maxf(speed(), 0.001)


## Advance along the path, never past max_progress (the follower spacing limit) or the end.
## Returns true when the end was reached this call.
func advance(delta: float, max_progress: float) -> bool:
	if not alive:
		return false
	# Never move backwards when the leader is closer than the spacing limit.
	progress = maxf(progress, minf(progress + speed() * delta, minf(max_progress, path_length)))
	position = path.to_global(path.curve.sample_baked(progress))
	return progress >= path_length


## Applies raw damage. Returns the amount actually removed from HP. Does not decide death;
## the director resolves purify in its own tick step so rewards happen exactly once.
func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, hp)
	hp -= dealt
	hp_changed.emit(hp, hp_max)
	if anim.has_animation("hit"):
		anim.stop()
		anim.play("hit")
	return dealt


func is_hit_by(world_pos: Vector2, radius: float) -> bool:
	return alive and global_position.distance_to(world_pos) <= radius


func play_purify() -> void:
	if anim.has_animation("purify"):
		anim.play("purify")


# --- statuses (B1): burn, poison stacks, slow. Times are wave-clock seconds. -----------------

var burn := {}            # {"dps": float, "until": float, "next_tick": float}
var poison_stacks: Array[float] = []   # expiry times
var poison_dps: float = 0.0
var poison_next_tick: float = -1.0
var slow := {}            # {"ratio": float, "until": float}
## Source of the most recent damage, so purify can tell a manual kill from a status tick.
var last_source: StringName = &""


## Burn re-application keeps the larger dps and the longer remaining time; the tick clock
## is never delayed (first tick 1s after the first application).
## `generation` 0 = from a direct hit, 1 = spread copy (B7); a direct hit resets it to 0.
func apply_burn(dps: float, duration: float, now: float, generation: int = 0) -> void:
	if burn.is_empty() or burn["until"] < now:
		burn = {"dps": dps, "until": now + duration, "next_tick": now + 1.0, "generation": generation}
		return
	burn["dps"] = maxf(burn["dps"], dps)
	burn["until"] = maxf(burn["until"], now + duration)
	burn["generation"] = mini(int(burn.get("generation", 0)), generation)


func burn_generation() -> int:
	return int(burn.get("generation", 0)) if not burn.is_empty() else 0


## Each stack has its own life; ticks share one clock from the first application. At max
## stacks the shortest remaining stack is refreshed instead of adding one.
func apply_poison(duration: float, max_stacks: int, dps_per_stack: float, now: float) -> void:
	poison_dps = dps_per_stack
	_expire_poison(now)
	if poison_stacks.is_empty():
		poison_next_tick = now + 1.0
	if poison_stacks.size() >= max_stacks:
		var shortest := 0
		for i in poison_stacks.size():
			if poison_stacks[i] < poison_stacks[shortest]:
				shortest = i
		poison_stacks[shortest] = now + duration
	else:
		poison_stacks.append(now + duration)


## Strongest ratio wins; the duration refreshes only when the same strength re-applies.
func apply_slow(ratio: float, duration: float, now: float) -> void:
	if slow.is_empty() or slow["until"] < now or ratio > slow["ratio"]:
		slow = {"ratio": ratio, "until": now + duration}
	elif is_equal_approx(ratio, slow["ratio"]):
		slow["until"] = maxf(slow["until"], now + duration)


func strongest_slow(now: float) -> float:
	if slow.is_empty() or slow["until"] < now:
		return 0.0
	return slow["ratio"]


func burn_active(now: float) -> bool:
	return not burn.is_empty() and burn["until"] >= now


func poison_count(now: float) -> int:
	_expire_poison(now)
	return poison_stacks.size()


## Status damage due at `now`. A stack whose expiry equals the tick time still pays that tick.
func tick_statuses(now: float) -> float:
	var total := 0.0
	if not burn.is_empty():
		while burn["next_tick"] <= now and burn["next_tick"] <= burn["until"] + 0.0001:
			total += burn["dps"]
			burn["next_tick"] += 1.0
		if burn["until"] < now and burn["next_tick"] > burn["until"]:
			burn = {}
	if not poison_stacks.is_empty() and poison_next_tick >= 0.0:
		while poison_next_tick <= now and not poison_stacks.is_empty():
			var live := 0
			for until in poison_stacks:
				if until >= poison_next_tick - 0.0001:
					live += 1
			total += poison_dps * live
			poison_next_tick += 1.0
			_expire_poison(poison_next_tick - 1.0 + 0.0001)
		if poison_stacks.is_empty():
			poison_next_tick = -1.0
	return total


func _expire_poison(now: float) -> void:
	var kept: Array[float] = []
	for until in poison_stacks:
		if until >= now:
			kept.append(until)
	poison_stacks = kept
