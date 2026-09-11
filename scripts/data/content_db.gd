class_name ContentDB
extends RefCounted
## Loads every content .tres under res://resources and validates cross references.
## Runtime services read words/waves/bosses from here; nothing else scans the folders.

const ROOT := "res://resources/"
const BASE_WORD_COUNT := 22
const COMPOUND_COUNT := 2
const WAVE_COUNT := 20
const BOSS_WAVES := {5: &"B_MIEUM", 10: &"B_SILENCE", 15: &"B_IEUNG", 20: &"B_GREED"}

var balance: BalanceConfig
var words: Dictionary = {}          # id -> WordData (base + compound results)
var waves: Dictionary = {}          # wave:int -> WaveData
var bosses: Dictionary = {}         # id -> BossData
var decks: Dictionary = {}          # id -> DeckData
var synergies: Dictionary = {}      # id -> SynergyData
var compounds: Dictionary = {}      # id -> CompoundData
var research: Dictionary = {}       # id -> ResearchData
var motion_profiles: Dictionary = {}  # id -> MotionProfile
var load_errors: Array[String] = []


static func load_all() -> ContentDB:
	var db := ContentDB.new()
	db.balance = load(ROOT + "balance/balance_config.tres") as BalanceConfig
	if db.balance == null:
		db.load_errors.append("balance/balance_config.tres missing or wrong script")
	for r in db._load_dir("words"):
		db._put(db.words, r, "id")
	for r in db._load_dir("waves"):
		var w := r as WaveData
		if w == null:
			db.load_errors.append("waves: non-WaveData resource")
		elif db.waves.has(w.wave):
			db.load_errors.append("waves: duplicate wave %d" % w.wave)
		else:
			db.waves[w.wave] = w
	for r in db._load_dir("bosses"):
		db._put(db.bosses, r, "id")
	for r in db._load_dir("decks"):
		db._put(db.decks, r, "id")
	for r in db._load_dir("synergies"):
		db._put(db.synergies, r, "id")
	for r in db._load_dir("compounds"):
		db._put(db.compounds, r, "id")
	for r in db._load_dir("research"):
		db._put(db.research, r, "id")
	for r in db._load_dir("motion_profiles"):
		db._put(db.motion_profiles, r, "id")
	return db


func base_words() -> Array[WordData]:
	var out: Array[WordData] = []
	for id in words:
		if not words[id].is_compound:
			out.append(words[id])
	out.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return out


## B5 spawn weights: required-jamo frequency of unlocked base words + bonus; absent when unused.
func spawn_weights(include_after_mieum: bool) -> Dictionary:
	var freq := {}
	for w in base_words():
		if w.unlock == &"after_mieum" and not include_after_mieum:
			continue
		for j in w.required_jamo:
			freq[j] = freq.get(j, 0) + 1
	var weights := {}
	for j in freq:
		weights[j] = freq[j] + balance.spawn_weight_bonus
	return weights


func validate() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(load_errors)
	if balance == null:
		return errors
	errors.append_array(balance.validate())
	errors.append_array(_validate_words())
	errors.append_array(_validate_waves())
	errors.append_array(_validate_bosses())
	errors.append_array(_validate_decks())
	errors.append_array(_validate_synergies_compounds())
	errors.append_array(_validate_research())
	errors.append_array(_validate_motion())
	return errors


func _validate_words() -> Array[String]:
	var errors: Array[String] = []
	var base := base_words()
	if base.size() != BASE_WORD_COUNT:
		errors.append("words: %d base words, expected %d" % [base.size(), BASE_WORD_COUNT])
	for i in base.size():
		var expected := "W%02d" % (i + 1)
		if String(base[i].id) != expected:
			errors.append("words: base id order broken at %s (expected %s)" % [base[i].id, expected])
	var compound_results := 0
	for id in words:
		var w: WordData = words[id]
		errors.append_array(w.validate())
		if w.is_compound:
			compound_results += 1
		if w.related_boss != &"" and not bosses.has(w.related_boss):
			errors.append("word %s: related_boss %s not found" % [id, w.related_boss])
		if w.compound_id != &"" and not compounds.has(w.compound_id):
			errors.append("word %s: compound_id %s not found" % [id, w.compound_id])
		for req in w.requires_any_word:
			if not words.has(req):
				errors.append("word %s: requires_any_word %s not found" % [id, req])
		if w.required_jamo.size() > balance.hand_size:
			errors.append("word %s: needs %d jamo but hand is %d" % [id, w.required_jamo.size(), balance.hand_size])
	if compound_results != COMPOUND_COUNT:
		errors.append("words: %d compound results, expected %d" % [compound_results, COMPOUND_COUNT])
	return errors


func _validate_waves() -> Array[String]:
	var errors: Array[String] = []
	for n in range(1, WAVE_COUNT + 1):
		if not waves.has(n):
			errors.append("waves: wave %d missing" % n)
			continue
		var w: WaveData = waves[n]
		errors.append_array(w.validate())
		if BOSS_WAVES.has(n):
			if not w.is_boss or w.boss_id != BOSS_WAVES[n]:
				errors.append("wave %d: must be boss %s" % [n, BOSS_WAVES[n]])
		elif w.is_boss:
			errors.append("wave %d: unexpected boss wave" % n)
		if w.is_boss and not bosses.has(w.boss_id):
			errors.append("wave %d: boss_id %s has no BossData" % [n, w.boss_id])
		if not w.is_boss and w.concurrent_max > balance.max_normal_enemies:
			errors.append("wave %d: concurrent %d exceeds screen cap %d" % [n, w.concurrent_max, balance.max_normal_enemies])
	return errors


func _validate_bosses() -> Array[String]:
	var errors: Array[String] = []
	for id in bosses:
		var b: BossData = bosses[id]
		errors.append_array(b.validate())
		if not waves.has(b.wave) or waves[b.wave].boss_id != id:
			errors.append("boss %s: wave %d does not point back at it" % [id, b.wave])
		if b.minion_concurrent_max > balance.max_boss_minions:
			errors.append("boss %s: minion cap above screen cap" % id)
	return errors


func _validate_decks() -> Array[String]:
	var errors: Array[String] = []
	var live := spawn_weights(true)
	for id in decks:
		var d: DeckData = decks[id]
		errors.append_array(d.validate(balance.starter_size))
		for j in d.counts():
			if not live.has(j):
				errors.append("deck %s: token %s is never required by any word" % [id, j])
		if d.unlock_research != &"" and not research.has(d.unlock_research):
			errors.append("deck %s: unlock_research %s not found" % [id, d.unlock_research])
	return errors


func _validate_synergies_compounds() -> Array[String]:
	var errors: Array[String] = []
	for id in synergies:
		errors.append_array(synergies[id].validate())
	for id in compounds:
		var c: CompoundData = compounds[id]
		errors.append_array(c.validate())
		for mat in [c.material_a, c.material_b]:
			if not words.has(mat):
				errors.append("compound %s: material %s not found" % [id, mat])
			elif words[mat].is_compound:
				errors.append("compound %s: material %s is itself a compound" % [id, mat])
			elif words[mat].compound_id != id:
				errors.append("compound %s: material %s does not link back" % [id, mat])
		if not words.has(c.result):
			errors.append("compound %s: result %s not found" % [id, c.result])
		elif not words[c.result].is_compound:
			errors.append("compound %s: result %s is not flagged is_compound" % [id, c.result])
	return errors


func _validate_research() -> Array[String]:
	var errors: Array[String] = []
	for id in research:
		var r: ResearchData = research[id]
		if r.price <= 0:
			errors.append("research %s: price must be positive" % id)
		if r.requires_research != &"" and not research.has(r.requires_research):
			errors.append("research %s: requires %s not found" % [id, r.requires_research])
		if r.effect.has("unlock_deck") and not decks.has(StringName(r.effect["unlock_deck"])):
			errors.append("research %s: unlock_deck target missing" % id)
	return errors


func _validate_motion() -> Array[String]:
	var errors: Array[String] = []
	var covered := {}
	for id in motion_profiles:
		for j in motion_profiles[id].jamo:
			if covered.has(j):
				errors.append("motion: jamo %s in both %s and %s" % [j, covered[j], id])
			covered[j] = id
	for j in spawn_weights(true):
		if not covered.has(j):
			errors.append("motion: jamo %s has no motion profile" % j)
	return errors


func _put(dict: Dictionary, r: Resource, key: String) -> void:
	if r == null or not (key in r):
		load_errors.append("resource without %s" % key)
		return
	var id = r.get(key)
	if dict.has(id):
		load_errors.append("duplicate id %s" % id)
		return
	dict[id] = r


func _load_dir(sub: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(ROOT + sub)
	if dir == null:
		load_errors.append("missing folder %s" % sub)
		return out
	var names := dir.get_files()
	names.sort()
	for f in names:
		# Exported builds list "*.tres.remap"; strip it so load() resolves the resource.
		var name := f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var r := load(ROOT + sub + "/" + name)
		if r == null:
			load_errors.append("failed to load %s/%s" % [sub, name])
		else:
			out.append(r)
	return out
