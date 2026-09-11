class_name LibraryService
extends RefCounted
## Pure logic behind the 마지막 서고 screens (G9/G10, B10, S5/S7): research rows, codex rows,
## starter deck rows, records/badges, library layer states, and the original sentence stage.

const MASTERY_TIERS := ["", "I", "II", "III"]


## Research row: {research, purchased, affordable, allowed, reason, current, after}.
static func research_rows(db: ContentDB) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids := db.research.keys()
	ids.sort_custom(func(a, b): return db.research[a].price < db.research[b].price)
	for id in ids:
		var r: ResearchData = db.research[id]
		var purchased := Meta.has_research(r.id)
		var reasons: Array[String] = []
		if r.requires_research != &"" and not Meta.has_research(r.requires_research):
			reasons.append("선행 연구: %s" % db.research[r.requires_research].name)
		if r.requires_reach_wave > 0 and Meta.best_reached < r.requires_reach_wave:
			reasons.append("W%d 도달 필요 (최고 W%d)" % [r.requires_reach_wave, Meta.best_reached])
		var allowed := reasons.is_empty()
		var affordable := Meta.gold >= r.price
		if allowed and not affordable and not purchased:
			reasons.append("Gold 부족 (%d / %d)" % [Meta.gold, r.price])
		out.append({"research": r, "purchased": purchased, "affordable": affordable, "allowed": allowed,
			"reason": ", ".join(reasons), "current": _research_current(db, r), "after": _research_after(db, r)})
	return out


static func _research_current(db: ContentDB, r: ResearchData) -> String:
	if r.effect.has("max_stability"):
		return "최대 안정도 %.0f" % Meta.stability_max(db)
	if r.effect.has("unlock_deck"):
		return "Starter B 잠김" if not Meta.has_research(r.id) else "Starter B 선택 가능"
	return ""


static func _research_after(db: ContentDB, r: ResearchData) -> String:
	if r.effect.has("max_stability"):
		return "최대 안정도 %d" % int(r.effect["max_stability"])
	if r.effect.has("unlock_deck"):
		return "Starter B 선택 가능"
	return ""


## Buys when allowed and affordable; saves immediately (G10 구매 확인과 즉시 저장).
static func buy_research(db: ContentDB, id: StringName) -> bool:
	for row in research_rows(db):
		if row["research"].id != id:
			continue
		if row["purchased"] or not row["allowed"] or not row["affordable"]:
			return false
		Meta.gold -= row["research"].price
		Meta.research.append(String(id))
		Meta.save()
		return true
	return false


static func mastery_tier(db: ContentDB, mastery: int) -> String:
	var tier := 0
	for i in db.balance.mastery_thresholds.size():
		if mastery >= db.balance.mastery_thresholds[i]:
			tier = i + 1
	return MASTERY_TIERS[tier]


## Codex row for a word: unlocked (craftable in a new RUN), discovered, mastery/tier, texts.
static func codex_row(db: ContentDB, word: WordData) -> Dictionary:
	var entry: Dictionary = Meta.codex.get(String(word.id), {})
	var unlocked := word.unlock == &"start" or (word.unlock == &"after_mieum" and Meta.mieum_purified) or word.is_compound
	var condition := ""
	if word.unlock == &"after_mieum" and not Meta.mieum_purified:
		condition = "거대한 ㅁ을 처음 정화한 뒤 다음 RUN부터"
	if word.is_compound:
		var recipe: CompoundData = db.compounds.get(word.id)
		if recipe != null:
			condition = "%s Rank %d + %s Rank %d 합성" % [db.words[recipe.material_a].name, recipe.material_a_min_rank, db.words[recipe.material_b].name, recipe.material_b_min_rank]
	var effects: Array[String] = []
	for rank in range(1, word.max_rank() + 1):
		effects.append("R%d: %s" % [rank, EffectText.describe_rank(word, rank)])
	var mastery := int(entry.get("mastery", 0))
	return {"word": word, "unlocked": unlocked, "discovered": not entry.is_empty(), "mastery": mastery,
		"tier": mastery_tier(db, mastery), "best_rank": int(entry.get("best_rank", 0)), "first_at": String(entry.get("first_at", "")),
		"materials": "".join(word.required_jamo), "effects": effects, "condition": condition,
		"boss": db.bosses[word.related_boss].name if db.bosses.has(word.related_boss) else "없음"}


static func boss_row(db: ContentDB, boss: BossData) -> Dictionary:
	var count := int(Meta.boss_records.get(String(boss.id), 0))
	var lines: Dictionary = db.narrative.boss_lines.get(String(boss.id), {})
	return {"boss": boss, "purified": count, "intro": String(lines.get("intro", "")),
		"after": String(lines.get("after", "")) if count > 0 else "", "hint": boss.response_hint}


## Starter deck row: tokens, per-jamo counts, craftable start words, unlock state.
static func deck_row(db: ContentDB, deck: DeckData) -> Dictionary:
	var counts := deck.counts()
	var craftable: Array[String] = []
	var blocked: Array[String] = []
	for w in db.base_words():
		if w.unlock != &"start":
			continue
		var need := ForgeService.required_counts(w)
		var ok := true
		for j in need:
			if counts.get(j, 0) < need[j]:
				ok = false
		if ok:
			craftable.append(w.name)
		else:
			blocked.append(w.name)
	return {"deck": deck, "size": deck.tokens.size(), "counts": counts, "craftable": craftable,
		"blocked": blocked, "unlocked": Meta.deck_unlocked(deck)}


## Distinct base words discovered (compounds/bosses never count, B10).
static func base_discovered(db: ContentDB) -> int:
	var n := 0
	for key in Meta.codex:
		var w: WordData = db.words.get(StringName(key))
		if w != null and not w.is_compound:
			n += 1
	return n


## S7/B10 library layers: which visual states are on.
static func layers(db: ContentDB) -> Dictionary:
	var found := base_discovered(db)
	return {"title_lamp": found >= 1, "spines": found >= 6, "lines": found >= 12,
		"handwriting": int(Meta.boss_records.get("B_SILENCE", 0)) > 0, "open_book": int(Meta.boss_records.get("B_GREED", 0)) > 0}


## Three badges (B10): 첫 합성 / 첫 완주 / 기본 12종 발견.
static func badges(db: ContentDB) -> Dictionary:
	var compound_found := false
	for key in Meta.codex:
		var w: WordData = db.words.get(StringName(key))
		if w != null and w.is_compound:
			compound_found = true
	return {"first_compound": compound_found, "first_clear": "S_SLICE_END" in Meta.events, "twelve_words": base_discovered(db) >= 12}


## Original sentence stage (S5): 0 at first, 1 after 침묵, 2 after 탐욕.
static func sentence_stage() -> int:
	if "S_GREED" in Meta.events:
		return 2
	if "S_SILENCE" in Meta.events:
		return 1
	return 0


static func sentence_text(db: ContentDB) -> String:
	return db.narrative.sentence_stages[sentence_stage()]


## S5 S_RETURN: the first library visit after 침묵 was purified records the line. Returns
## the line to show once, or "" when nothing new happened.
static func record_return(db: ContentDB) -> String:
	if "S_SILENCE" in Meta.events and "S_RETURN" not in Meta.events:
		Meta.events.append("S_RETURN")
		Meta.save()
		return db.narrative.line("S_RETURN")
	return ""


## Event lines in unlock order for the 기록 tab.
static func event_lines(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for id in Meta.events:
		out.append(db.narrative.line(String(id)))
	return out
