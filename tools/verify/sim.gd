class_name B12Sim
extends RefCounted
## B12 model-only simulations (no combat scene): first Forge draw, the late-game Forge loop
## and jamo supply. Everything goes through the real RunController/ForgeService/DropService
## state machine so the numbers reflect shipped rules, not a copy of them.

const NORMAL_WAVES := 19  # W1..W19 have a Forge; W20 ends the RUN


static func start_pool(db: ContentDB) -> Array[WordData]:
	var out: Array[WordData] = []
	for w in db.base_words():
		if w.unlock == &"start":
			out.append(w)
	return out


## 추첨: first Forge of a fresh deck. Returns {first_fail, after_reroll_fail} rates.
static func first_draw(db: ContentDB, deck_id: StringName, runs: int) -> Dictionary:
	var first_fail := 0
	var after_fail := 0
	var pool := start_pool(db)
	for i in runs:
		var deck := DeckService.from_deck_data(db.decks[deck_id], db.balance)
		var build := BuildState.new()
		build.setup(db.balance)
		var forge := ForgeService.new()
		forge.start(deck, db, build, pool, hash("b12:first:%s:%d" % [deck_id, i]), 0)
		if forge.candidates().is_empty():
			first_fail += 1
			b6_reroll(forge)
			if forge.candidates().is_empty():
				after_fail += 1
	return {"first_fail": float(first_fail) / runs, "after_reroll_fail": float(after_fail) / runs, "runs": runs}


## B6 정본 policy: stop as soon as a candidate exists; otherwise Lock the hand tokens the word
## with the fewest lacking jamo still needs (up to lock_max) and Reroll.
static func b6_reroll(forge: ForgeService) -> void:
	while forge.candidates().is_empty() and forge.can_reroll():
		var target := _fewest_lacking(forge)
		for id in forge.locked.duplicate():
			forge.toggle_lock(id)
		if target != null:
			var need := ForgeService.required_counts(target)
			for t in forge.hand:
				if need.get(t["jamo"], 0) > 0 and forge.toggle_lock(t["id"]):
					need[t["jamo"]] -= 1
		forge.reroll()


static func _fewest_lacking(forge: ForgeService) -> WordData:
	var counts := forge.hand_counts()
	var best: WordData = null
	var best_lack := 99
	for w in forge.pool:
		if forge.build.has(w.id) and forge.build.rank_of(w.id) >= w.max_rank():
			continue
		var lack := 0
		for j in ForgeService.required_counts(w):
			lack += maxi(ForgeService.required_counts(w)[j] - counts.get(j, 0), 0)
		if lack < best_lack:
			best = w
			best_lack = lack
	return best


## A RunController driven without a scene: real deck, drops, rewards and Forge.
static func new_run(db: ContentDB, seed: int, deck_id: StringName = &"starter_a") -> RunController:
	var run := RunController.new()
	run.run_seed = seed
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(deck_id)
	return run


## Spawn stream of one normal Wave through the director's real B5 weights.
static func wave_jamo(db: ContentDB, run: RunController, wave: int, seed: int) -> Array[String]:
	var d := CombatDirector.new()
	d.run = run
	d.db = db
	d.risk_unlocked = run.risk_unlocked
	d.pin_lacking = run.pin_lacking()
	d.rng_spawn.seed = hash("spawn:%d:%d" % [seed, wave])
	var out: Array[String] = []
	var data: WaveData = db.waves[wave]
	if data.is_boss:
		# B9: minions with a fixed jamo keep it; the rest draw from the B5 weights like normal spawns.
		for entry in db.bosses[data.boss_id].minion_schedule:
			for k in int(entry["count"]):
				var fixed := String(entry.get("jamo", ""))
				out.append(fixed if fixed != "" else d._draw_jamo())
	else:
		for i in data.enemy_count:
			out.append(d._draw_jamo())
	d.free()
	return out


## 후반 추첨: N RUNs through W1..W19 at a fixed purification rate with a greedy Forge policy.
## Returns per-wave valid-zero counts (candidates empty after every Reroll) and RUN count.
static func late_loop(db: ContentDB, runs: int, purify_rate: float, direction: StringName = &"") -> Dictionary:
	var out := {"zero_by_wave": {}, "candidates_by_wave": {}, "runs": runs, "forges": 0, "final_candidates": 0,
		"stopped_with_rerolls": 0, "supply_waves": 0, "supply_delivered": 0}
	var rng := RandomNumberGenerator.new()
	for i in runs:
		var seed := hash("b12:late:%d:%f" % [i, purify_rate])
		rng.seed = seed
		var run := new_run(db, seed)
		for wave in range(1, NORMAL_WAVES + 1):
			_repin(db, run)
			var lacking := run.pin_lacking()
			run.begin_combat()
			var delivered := _play_wave_drops(db, run, wave, seed, purify_rate, rng, lacking)
			if not lacking.is_empty():
				out["supply_waves"] += 1
				out["supply_delivered"] += 1 if delivered else 0
			run.on_wave_cleared()
			reward_policy(db, run, run.build_reward(), direction)
			run.finish_clear()
			var forge := run.start_forge()
			b6_reroll(forge)
			# 최종 후보 = candidates on the hand the player stops at, counted before the restore (B6 종료 시 평균 후보).
			var final := forge.candidates().size()
			var rerolls_used := db.balance.reroll_base + run.forge_fail_bonus - forge.rerolls_left
			var picked := forge_policy(db, forge, direction)
			out["forges"] += 1
			out["final_candidates"] += final
			out["candidates_by_wave"][wave] = out["candidates_by_wave"].get(wave, 0) + final
			if rerolls_used >= 1 and forge.rerolls_left > 0:
				out["stopped_with_rerolls"] += 1  # used some Rerolls and stopped with one left
			if picked == &"" and forge.candidates().is_empty():
				out["zero_by_wave"][wave] = out["zero_by_wave"].get(wave, 0) + 1
			run.finish_forge()
		run.free()
	Meta.pinned_word = ""  # pin_word writes the profile field; never leak it into later checks
	return out


## One Wave of purification at `rate`: normal spawns, or the boss minions plus the B4 body
## tokens (W5 ㅁ×2, W15 ㅇ×2). Returns true when a recovered jamo was one the pin lacked.
static func _play_wave_drops(db: ContentDB, run: RunController, wave: int, seed: int, rate: float, rng: RandomNumberGenerator, lacking: Array[String]) -> bool:
	var delivered := false
	var data: WaveData = db.waves[wave]
	for j in wave_jamo(db, run, wave, seed):
		if rng.randf() < rate and run.on_purified(j) and j in lacking:
			delivered = true
	if data.is_boss:
		for j in db.bosses[data.boss_id].body_drop:
			run.drops.add_guaranteed(j)
			if j in lacking:
				delivered = true
	return delivered


## Keeps a goal pinned like a player would: the pool word with the fewest missing tokens (>0),
## counted with multiplicity like _fewest_lacking.
static func _repin(db: ContentDB, run: RunController) -> void:
	if not run.pin_lacking().is_empty():
		return
	var best: StringName = &""
	var best_missing := 99
	for w in run.word_pool():
		var missing := 0
		for n in run.deck.missing_for(w).values():
			missing += n
		if missing > 0 and missing < best_missing:
			best = w.id
			best_missing = missing
	run.pin_word(best)


## Reward policy: add every drop that a pool word still lacks (direction words first),
## otherwise add the first drop while the deck has room, then finish.
static func reward_policy(db: ContentDB, run: RunController, reward: RewardService, direction: StringName) -> void:
	while reward.can_pick() and not reward.candidates.is_empty():
		var index := _best_drop(db, run, reward.candidates, direction)
		if index < 0 or not reward.can_add(index):
			break
		reward.add(index)
	reward.finish()


static func _best_drop(db: ContentDB, run: RunController, drops: Array[String], direction: StringName) -> int:
	var lacking := {}
	for w in run.word_pool():
		var weight := 2 if direction != &"" and direction in w.tags else 1
		for j in run.deck.missing_for(w):
			lacking[j] = maxi(lacking.get(j, 0), weight)
	var best := -1
	var best_w := 0
	for i in drops.size():
		if lacking.get(drops[i], 0) > best_w:
			best = i
			best_w = lacking[drops[i]]
	return best if best >= 0 else (0 if run.deck.can_add() else -1)


## Forge policy: Reroll while nothing is craftable, then restore the best candidate:
## direction-tagged words first, rank-ups over new words when the build is full.
## Returns the restored word id or &"".
static func forge_policy(db: ContentDB, forge: ForgeService, direction: StringName) -> StringName:
	b6_reroll(forge)
	var list := forge.candidates()
	if list.is_empty():
		return &""
	list.sort_custom(func(a, b): return _score(a, direction) > _score(b, direction))
	for c in list:
		var w: WordData = c["word"]
		var replace_id: StringName = &""
		if c["needs_replace"] or c["replace_risk"]:
			replace_id = _lowest_rank(forge.build, db, c["replace_risk"])
			if replace_id == &"":
				continue
		if forge.restore(w.id, replace_id):
			return w.id
	return &""


static func _score(c: Dictionary, direction: StringName) -> int:
	var w: WordData = c["word"]
	var s := 0
	if direction != &"" and direction in w.tags:
		s += 10
	if c["kind"] == ForgeService.KIND_RANK_UP:
		s += 3
	if c["needs_replace"] or c["replace_risk"]:
		s -= 5
	return s


static func _lowest_rank(build: BuildState, db: ContentDB, risk_only: bool) -> StringName:
	var best: StringName = &""
	var best_rank := 99
	for held in build.words:
		if risk_only and not db.words[held["id"]].is_risk():
			continue
		if held["rank"] < best_rank:
			best = held["id"]
			best_rank = held["rank"]
	return best
