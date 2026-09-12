extends Node
## MetaStore (G13/G14): profile facts that outlive a RUN plus the suspended RUN snapshot.
## Autoloaded as `Meta`; SaveManager does the file work. Every mutation goes through save().

const CONTENT_VERSION := "planning-v0.7"

var saver := SaveManager.new()
var loaded: bool = false
var load_source: String = "none"
var corrupt: bool = false

var gold: int = 0
var research: Array = []            # purchased research ids (String)
var codex: Dictionary = {}          # word id -> {"mastery": int, "best_rank": int, "first_at": String}
var boss_records: Dictionary = {}   # boss id -> purify count
var best_reached: int = 0
var best_cleared: int = 0
var events: Array = []              # S5 record ids in unlock order
var settled_results: Array = []     # result ids already paid (G14)
var mieum_purified: bool = false
var first_run_done: bool = false
## Goal pin survives RUNs (G2 재도전은 목표 핀을 유지한다).
var pinned_word: String = ""
## G10 설정 row: volumes 0-100 per bus, display, text scale, motion/flash accessibility.
var settings: Dictionary = default_settings()
var run: Dictionary = {}            # suspended RUN snapshot, empty when none
## Session-only handoff from the library: resume the suspended RUN / which starter to use.
var resume_pending: bool = false
var chosen_deck: StringName = &"starter_a"


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var result := saver.load()
	load_source = result["source"]
	corrupt = result["corrupt"]
	if not result["profile"].is_empty():
		from_dict(result["profile"]["meta"])
		run = result["profile"].get("run", {})
	loaded = true


func save() -> bool:
	return saver.save({"meta": to_dict(), "run": run, "content_version": CONTENT_VERSION})


## Discards everything on disk and in memory (only after the user agreed, G14).
func new_profile() -> void:
	saver.delete_all()
	from_dict({})
	run = {}
	corrupt = false
	load_source = "none"
	save()


func has_run() -> bool:
	return not run.is_empty()


func risk_unlocked_for_new_run() -> bool:
	return mieum_purified


func has_research(id: StringName) -> bool:
	return String(id) in research


## B10 research: max stability from the purchased R_SAFE levels.
func stability_max(db: ContentDB) -> float:
	var value := db.balance.stability_max
	for id in research:
		var r: ResearchData = db.research.get(StringName(id))
		if r != null and r.effect.has("max_stability"):
			value = maxf(value, float(r.effect["max_stability"]))
	return minf(value, db.balance.stability_max_cap)


func deck_unlocked(deck: DeckData) -> bool:
	return deck.unlock_research == &"" or has_research(deck.unlock_research)


static func default_settings() -> Dictionary:
	return {"master": 80, "bgm": 70, "sfx": 80, "ui": 80, "fullscreen": false, "text_scale": 100,
		"shake": 50, "flash": true, "keyboard_mode": false}


func setting(key: String):
	return settings.get(key, default_settings().get(key))


func to_dict() -> Dictionary:
	return {"gold": gold, "research": research.duplicate(), "codex": codex.duplicate(true),
		"boss_records": boss_records.duplicate(), "best_reached": best_reached, "best_cleared": best_cleared,
		"events": events.duplicate(), "settled_results": settled_results.duplicate(),
		"mieum_purified": mieum_purified, "first_run_done": first_run_done, "pinned_word": pinned_word, "settings": settings.duplicate()}


func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	research = Array(d.get("research", []))
	codex = Dictionary(d.get("codex", {}))
	boss_records = Dictionary(d.get("boss_records", {}))
	best_reached = int(d.get("best_reached", 0))
	best_cleared = int(d.get("best_cleared", 0))
	events = Array(d.get("events", []))
	settled_results = Array(d.get("settled_results", []))
	mieum_purified = bool(d.get("mieum_purified", false))
	first_run_done = bool(d.get("first_run_done", false))
	pinned_word = String(d.get("pinned_word", ""))
	settings = default_settings()
	for key in d.get("settings", {}):
		if settings.has(key):
			settings[key] = d["settings"][key]
