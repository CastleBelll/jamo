class_name CombatResolver
extends RefCounted
## Turns the held words (BuildState + B7 EffectData) into combat numbers (G7, B1): manual
## damage, crit, stability formula, statuses, periodic auto hits, counters, clear heal, gold.
## The director calls it in its fixed tick order; this class never touches the scene tree.

const SOURCE_MANUAL := &"manual"
const SOURCE_AUTO := &"auto"
const SOURCE_DERIVED := &"derived"
const SOURCE_STATUS := &"status"

var db: ContentDB
var build: BuildState
var rng := RandomNumberGenerator.new()   # crit stream, independent of spawn/drop

# Aggregated passives (recomputed on refresh)
var manual_pct: float = 0.0
var lowhp_bonuses: Array[EffectData] = []
var near_end_bonuses: Array[EffectData] = []
var crit_chance: float = 0.0
var stability_reduction: float = 0.0
var stability_taken_pct: float = 0.0
var enemy_speed_pct: float = 0.0
var enemy_speed_mult: float = 1.0
var dot_pct: float = 0.0
var clear_heal_bonus: float = 0.0
var gold_pct: float = 0.0
var drop_chance_add: float = 0.0
var input_interval_override: float = 0.0
var auto_period_mult: float = 1.0
var shield_at_start: float = 0.0
var heal_per_gold: Array[EffectData] = []

# Per-Wave runtime
var counters: Dictionary = {}       # effect key -> int
var timers: Dictionary = {}         # effect key -> next fire time
var clock: float = 0.0
var shield: float = 0.0
## 침묵 (G8): sealed word id -> expiry clock. Sealed words stop new triggers, passive
## numbers and synergy tags; statuses already on enemies run out on their own.
var sealed: Dictionary = {}
var last_sealed: StringName = &""


func setup(content: ContentDB, run_build: BuildState, seed: int) -> void:
	db = content
	build = run_build
	rng.seed = seed
	refresh()


## Active effect lines: [{key, word, rank, effect}] for every held word at its Rank, plus the
## effect of every active B8 synergy (G6).
func active_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for held in build.words:
		if is_sealed(held["id"]):
			continue
		var word: WordData = db.words[held["id"]]
		var effects := word.effects_at(held["rank"])
		for i in effects.size():
			var e := effects[i] as EffectData
			if e != null:
				out.append({"key": "%s:%d" % [word.id, i], "word": word, "rank": held["rank"], "effect": e})
	for syn in active_synergies(db, build, sealed_ids()):
		out.append({"key": "SYN:%s" % syn.id, "word": null, "rank": 0, "effect": syn.effect})
	return out


func is_sealed(word_id: StringName) -> bool:
	return sealed.has(word_id) and sealed[word_id] > clock


func sealed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in sealed:
		if sealed[id] > clock:
			out.append(id)
	return out


## Words 침묵 may seal: held, active (not already sealed) and not 위험 (G8). With two or more
## options the previous target is skipped (연속 동일 대상 금지).
func sealable_words() -> Array[StringName]:
	var out: Array[StringName] = []
	for held in build.words:
		var id: StringName = held["id"]
		if db.words[id].is_risk() or is_sealed(id):
			continue
		out.append(id)
	if out.size() >= 2 and last_sealed in out:
		out.erase(last_sealed)
	return out


## Seal one word for `duration`; passives drop immediately, timers restart on release.
func seal(word_id: StringName, duration: float) -> void:
	sealed[word_id] = clock + duration
	last_sealed = word_id
	refresh()


## Releases expired seals; a released periodic word restarts from a fresh period (G8).
func update_seals() -> void:
	var released := false
	for id in sealed.keys():
		if sealed[id] <= clock:
			sealed.erase(id)
			released = true
			for a in effects_with(&"periodic"):
				if a["word"] != null and a["word"].id == id:
					timers[a["key"]] = clock + a["effect"].interval * auto_period_mult
	if released:
		refresh()


## B8 synergies whose tag thresholds the build meets. Tags are counted per distinct word id;
## Rank never adds tags (G6). Sealed words will be excluded here when 침묵 lands (P3).
static func active_synergies(content: ContentDB, run_build: BuildState, excluded: Array[StringName] = []) -> Array[SynergyData]:
	var tag_counts := {}
	for held in run_build.words:
		if held["id"] in excluded:
			continue
		for t in content.words[held["id"]].tags:
			tag_counts[t] = tag_counts.get(t, 0) + 1
	var out: Array[SynergyData] = []
	var ids := content.synergies.keys()
	ids.sort()
	for id in ids:
		var syn: SynergyData = content.synergies[id]
		var met := true
		for c in syn.conditions:
			if tag_counts.get(StringName(c["tag"]), 0) < int(c["min"]):
				met = false
		if met:
			out.append(syn)
	return out


## 복 (B7): one extra remove on normal Waves whose number is a multiple of every_n. Boss
## Waves keep their own remove instead (no stacking).
static func extra_removes(content: ContentDB, run_build: BuildState, wave: int) -> int:
	var removes := 0
	for held in run_build.words:
		var word: WordData = content.words[held["id"]]
		for e in word.effects_at(held["rank"]):
			if e is EffectData and e.kind == &"extra_remove_every_n" and e.every_n > 0 and wave % e.every_n == 0:
				removes += 1
	return removes


## Extra 자모 picks on normal Wave rewards from active synergies (SY_ECON).
static func reward_pick_bonus(content: ContentDB, run_build: BuildState) -> int:
	var bonus := 0
	for syn in active_synergies(content, run_build):
		if syn.effect != null and syn.effect.kind == &"reward_pick_add":
			bonus += int(syn.effect.value)
	return bonus


func effects_with(trigger: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in active_effects():
		if a["effect"].trigger == trigger:
			out.append(a)
	return out


## Rebuild the passive sums after the build changes (Forge). Caps follow B1.
func refresh() -> void:
	manual_pct = 0.0
	lowhp_bonuses.clear()
	near_end_bonuses.clear()
	crit_chance = db.balance.crit_chance_base
	stability_reduction = 0.0
	stability_taken_pct = 0.0
	enemy_speed_pct = 0.0
	enemy_speed_mult = 1.0
	dot_pct = 0.0
	clear_heal_bonus = 0.0
	gold_pct = 0.0
	drop_chance_add = 0.0
	input_interval_override = 0.0
	auto_period_mult = 1.0
	shield_at_start = 0.0
	heal_per_gold.clear()
	if build == null:
		return
	for a in active_effects():
		var e: EffectData = a["effect"]
		match e.kind:
			&"manual_damage_pct": manual_pct += e.value
			&"manual_damage_pct_lowhp": lowhp_bonuses.append(e)
			&"manual_damage_pct_near_end": near_end_bonuses.append(e)
			&"crit_chance": crit_chance += e.value
			&"stability_damage_pct": stability_reduction += -e.value
			&"stability_taken_pct": stability_taken_pct += e.value
			&"enemy_speed_pct": enemy_speed_pct += e.value
			&"enemy_speed_mult": enemy_speed_mult *= e.value
			&"dot_damage_pct": dot_pct += e.value
			&"clear_heal_bonus": clear_heal_bonus += e.value
			&"gold_pct": gold_pct += e.value
			&"drop_chance_add": drop_chance_add += e.value
			&"input_interval": input_interval_override = e.value if input_interval_override == 0.0 else minf(input_interval_override, e.value)
			&"auto_period_mult": auto_period_mult *= e.value
			&"shield": shield_at_start += e.value
			&"heal_per_gold": heal_per_gold.append(e)
	crit_chance = minf(crit_chance, db.balance.crit_chance_cap)
	stability_reduction = minf(stability_reduction, db.balance.damage_reduction_cap)


func start_wave() -> void:
	sealed.clear()
	last_sealed = &""
	refresh()
	clock = 0.0
	counters.clear()
	timers.clear()
	for a in effects_with(&"periodic"):
		timers[a["key"]] = a["effect"].interval * auto_period_mult
	shield = minf(shield_at_start, db.balance.shield_cap)


func end_wave() -> void:
	shield = 0.0


func input_interval() -> float:
	return input_interval_override if input_interval_override > 0.0 else db.balance.manual_interval


## B1 manual damage: 1.0 x (1 + capped bonus sum) x crit. Conditional bonuses (검 R3, 돌)
## join the same capped sum. Returns {"damage": float, "crit": bool}.
func manual_damage(target: JamoMonster) -> Dictionary:
	var bonus := manual_pct
	for e in lowhp_bonuses:
		if target.hp <= target.hp_max * e.value2:
			bonus += e.value
	# 돌: the boss never satisfies the remaining-path condition (G7).
	if not (target is Boss):
		for e in near_end_bonuses:
			if target.remaining_path() <= target.path_length * e.value2:
				bonus += e.value
	bonus = minf(bonus, db.balance.manual_damage_bonus_cap)
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	var damage := db.balance.manual_base_damage * (1.0 + bonus) * (db.balance.crit_multiplier if crit else 1.0)
	return {"damage": damage, "crit": crit}


## B1 stability formula with the shield absorbing first. Returns the amount to subtract.
func stability_damage(raw: float) -> float:
	var final := raw * (1.0 - stability_reduction) * (1.0 + stability_taken_pct)
	if shield > 0.0:
		var absorbed := minf(shield, final)
		shield -= absorbed
		final -= absorbed
	return maxf(final, 0.0)


## Enemy speed multiplier: (1 + 길 sum) x strongest slow, floored at B1 min, then 폭주.
func speed_mult_for(enemy: JamoMonster) -> float:
	var slow := enemy.strongest_slow(clock)
	var base := (1.0 + enemy_speed_pct) * (1.0 - slow)
	return maxf(base, db.balance.min_speed_ratio) * enemy_speed_mult


func gold_for_kill(base_gold: int) -> float:
	return base_gold * (1.0 + gold_pct)


## Clear heal (B1/B7): base + 숨 + 돈 (per 12G of this Wave, capped per Rank).
func clear_heal(wave_gold: float) -> float:
	var total := db.balance.clear_heal + clear_heal_bonus
	for e in heal_per_gold:
		total += minf(e.cap, floorf(wave_gold / e.value2) * e.value)
	return total


# --- hit / kill triggers (G7: only real manual damage procs; derived hits never do) -------

## Called after every manual hit that dealt real damage (B7 counts each 적중, including the
## killing blow). Statuses only land on a target that survived (G7). Returns derived hits:
## [{"target": JamoMonster, "damage": float, "source": StringName}].
func on_manual_hit(target: JamoMonster, enemies: Array[JamoMonster]) -> Array[Dictionary]:
	var derived: Array[Dictionary] = []
	var survived := target.hp > 0.0
	for a in effects_with(&"manual_hit"):
		var e: EffectData = a["effect"]
		if e.every_n > 0:
			counters[a["key"]] = counters.get(a["key"], 0) + 1
			if counters[a["key"]] % e.every_n != 0:
				continue
		match e.kind:
			&"apply_burn":
				if survived:
					target.apply_burn(e.value, e.duration, clock, 0)
			&"apply_poison":
				if survived:
					target.apply_poison(e.duration, e.max_stacks, e.value, clock)
			&"apply_slow":
				if survived:
					target.apply_slow(e.value, e.duration, clock)
			&"damage_lane_front_other":
				var other := _lane_front_other(target, enemies)
				if other != null:
					derived.append({"target": other, "damage": e.value, "source": SOURCE_DERIVED})
			&"damage_near_other":
				var near := _nearest_other(target, enemies, e.radius_px)
				if near != null:
					derived.append({"target": near, "damage": e.value, "source": SOURCE_DERIVED})
	return derived


## Called once per purified enemy with the final-blow source. Returns {"heal": float,
## "derived": [...]} so the director stays the single owner of stability/gold changes.
func on_kill(victim: JamoMonster, source: StringName, enemies: Array[JamoMonster]) -> Dictionary:
	var result := {"heal": 0.0, "derived": []}
	if source == SOURCE_MANUAL:
		for a in effects_with(&"manual_kill"):
			var e: EffectData = a["effect"]
			if e.every_n > 0:
				counters[a["key"]] = counters.get(a["key"], 0) + 1
				if counters[a["key"]] % e.every_n != 0:
					continue
			match e.kind:
				&"heal_stability":
					result["heal"] += e.value
				&"damage_near_other":
					var near := _nearest_other(victim, enemies, e.radius_px)
					if near != null:
						result["derived"].append({"target": near, "damage": e.value, "source": SOURCE_DERIVED})
	for a in effects_with(&"kill"):
		var e: EffectData = a["effect"]
		if e.kind == &"burn_spread":
			# 같은 화상 전이: only a burning victim spreads, and a spread copy (generation 1)
			# never spreads again (B7 spread_generation=1).
			if not victim.burn_active(clock) or victim.burn_generation() > 0:
				continue
			var near := _nearest_other(victim, enemies, e.radius_px)
			if near != null:
				near.apply_burn(e.value, e.duration, clock, 1)
	return result


# --- scheduled damage (periodic auto hits + status ticks) ----------------------------------

## Advances the wave clock and returns every scheduled hit due in this tick, in entity order.
func scheduled_damage(delta: float, enemies: Array[JamoMonster]) -> Array[Dictionary]:
	clock += delta
	update_seals()
	var hits: Array[Dictionary] = []
	for a in effects_with(&"periodic"):
		var e: EffectData = a["effect"]
		var key: String = a["key"]
		if not timers.has(key):
			timers[key] = clock + e.interval * auto_period_mult
		while clock >= timers[key]:
			timers[key] += e.interval * auto_period_mult
			if e.kind == &"damage_front":
				for t in _front_enemies(enemies, e.target_count):
					hits.append({"target": t, "damage": e.value, "source": SOURCE_AUTO})
	var dot_mult := 1.0 + dot_pct
	for m in enemies:
		var status_damage := m.tick_statuses(clock) * dot_mult
		if status_damage > 0.0:
			hits.append({"target": m, "damage": status_damage, "source": SOURCE_STATUS})
	return hits


# --- targeting helpers (G7) ------------------------------------------------------------

## 앞선 적: smallest remaining path; ties by entity_id.
func _front_enemies(enemies: Array[JamoMonster], count: int) -> Array[JamoMonster]:
	var order := enemies.duplicate()
	order.sort_custom(func(a, b):
		var ra: float = a.remaining_path()
		var rb: float = b.remaining_path()
		return ra < rb or (is_equal_approx(ra, rb) and a.entity_id < b.entity_id))
	var out: Array[JamoMonster] = []
	for i in mini(count, order.size()):
		if order[i].alive:
			out.append(order[i])
	return out


func _lane_front_other(target: JamoMonster, enemies: Array[JamoMonster]) -> JamoMonster:
	var same: Array[JamoMonster] = []
	for m in enemies:
		if m != target and m.alive and m.lane == target.lane:
			same.append(m)
	var front := _front_enemies(same, 1)
	return front[0] if not front.is_empty() else null


func _nearest_other(target: JamoMonster, enemies: Array[JamoMonster], radius: float) -> JamoMonster:
	var best: JamoMonster = null
	var best_d := INF
	for m in enemies:
		if m == target or not m.alive:
			continue
		var d := m.global_position.distance_to(target.global_position)
		if d <= radius and (d < best_d or (is_equal_approx(d, best_d) and m.entity_id < best.entity_id)):
			best = m
			best_d = d
	return best
