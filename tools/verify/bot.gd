class_name B12Bot
extends RefCounted
## Drives a real run_game scene through combat without rendering: every tick it clicks the
## enemy nearest the sentence (a live 대응물 first), and answers CLEAR/FORGE with B12Sim's
## greedy policies. Used for the 빌드 방향 / 메타 동일성 / 성능 checks.

const TICK := 0.1
const MAX_WAVE_SECONDS := 240.0

var game: Node
var run: RunController
var director: CombatDirector
var db: ContentDB
var direction: StringName = &""
var wave_seconds: Dictionary = {}   # wave -> combat seconds
var w1_hits: int = 0
var w1_purified: int = 0


func boot(scene: PackedScene, content: ContentDB, seed: int, parent: Node) -> void:
	db = content
	game = scene.instantiate()
	game.run_seed = seed
	game.set_physics_process(false)
	parent.add_child(game)
	run = game.get_node("RunController")
	director = game.get_node("CombatDirector")


func free_game() -> void:
	if game != null:
		game.free()
		game = null


## One Wave: start combat, tick until the phase leaves COMBAT. Returns false on defeat.
func play_wave() -> bool:
	run.begin_combat()
	var seconds := 0.0
	while run.phase == RunController.Phase.COMBAT and seconds < MAX_WAVE_SECONDS:
		click_best()
		director.tick(TICK)
		seconds += TICK
	wave_seconds[run.wave] = seconds
	if run.wave == 1:
		w1_hits = director.stats["hits"]
		w1_purified = director.stats["purified"]
	var completed := run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.COMPLETED
	return run.phase == RunController.Phase.CLEAR or completed


## After CLEAR: reward + Forge with the greedy policies, back to WAVE_PREP.
func settle_wave() -> void:
	if run.phase != RunController.Phase.CLEAR:
		return
	B12Sim.reward_policy(db, run, run.build_reward(), direction)
	run.finish_clear()
	B12Sim.forge_policy(db, run.start_forge(), direction)
	run.finish_forge()


## Plays until defeat, completion or `until_wave` is passed. Returns the last Wave cleared.
func play_run(until_wave: int = RunController.LAST_WAVE) -> int:
	while run.phase == RunController.Phase.WAVE_PREP and run.wave <= until_wave:
		if not play_wave():
			break
		settle_wave()
	return run.waves_cleared


## Clicks a live 대응물 first, else the enemy with the least path left; the boss last.
func click_best() -> void:
	if not director.can_attack():
		return
	for p in director.pattern_targets:
		if not p.done:
			director.request_click(p.global_position)
			return
	var best: JamoMonster = null
	var best_left := INF
	for e in director.enemies:
		if not e.alive:
			continue
		var left: float = 1.0e9 if e is Boss else e.remaining_path()
		if left < best_left:
			best = e
			best_left = left
	if best != null:
		director.request_click(best.global_position)
