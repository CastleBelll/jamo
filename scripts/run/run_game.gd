extends Node
## Run screen root: wires RunController, CombatDirector, the page, HUD and per-phase panels
## (G2/G3/G10). Screen flow lives here; combat rules live in CombatDirector.

const LIBRARY_SCENE := "res://scenes/hub/last_library.tscn"

@onready var run: RunController = $RunController
@onready var director: CombatDirector = $CombatDirector
@onready var page: Node2D = $CorruptedPage
@onready var hud: CanvasLayer = $HUD
@onready var prep_panel: PanelContainer = %PrepPanel
@onready var prep_label: Label = %PrepLabel
@onready var clear_panel: PanelContainer = %ClearPanel
@onready var forge_panel: PanelContainer = %ForgePanel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var pause_panel: PanelContainer = %PausePanel

## Spawn/drop RNG seed per run; tests override it for reproducible waves.
var run_seed: int = 0
var db_ref: ContentDB


func _ready() -> void:
	var db := ContentDB.load_all()
	var errors := db.validate()
	if not errors.is_empty():
		push_error("content invalid: %s" % errors[0])
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	run.run_seed = run_seed
	run.setup(db)
	db_ref = db
	director.setup(run, db, page)
	director.enemies_changed.connect(hud.set_enemies_left)
	director.enemy_purified.connect(_on_enemy_purified)
	clear_panel.finished.connect(func(): run.finish_clear())
	hud.bind(run)
	run.phase_changed.connect(_on_phase_changed)
	%StartWaveButton.pressed.connect(func(): run.begin_combat())
	forge_panel.finished.connect(func(): run.finish_forge())
	%ResultLibraryButton.pressed.connect(_on_return_to_library)
	%RetryButton.pressed.connect(func(): run.retry_run())
	%ResumeButton.pressed.connect(_close_pause)
	%AbandonButton.pressed.connect(_on_abandon)
	pause_panel.visible = false
	run.open_run_setup()
	run.confirm_setup(&"starter_a")


func _physics_process(delta: float) -> void:
	# Root runs always (for Esc); the combat clock only advances while unpaused in COMBAT.
	if get_tree().paused:
		return
	director.tick(delta, page.get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and run.phase != RunController.Phase.RESULT:
		if pause_panel.visible:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	# Battlefield input only reaches here when no Control consumed it (G3) and combat runs.
	if run.phase != RunController.Phase.COMBAT or get_tree().paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		director.set_hold(event.pressed)
		if event.pressed:
			director.request_click(page.get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_target"):
		director.cycle_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack_key"):
		director.request_keyboard_attack()
		get_viewport().set_input_as_handled()


func _on_phase_changed(_from: RunController.Phase, to: RunController.Phase) -> void:
	prep_panel.visible = to == RunController.Phase.WAVE_PREP
	clear_panel.visible = to == RunController.Phase.CLEAR
	forge_panel.visible = to == RunController.Phase.FORGE
	result_panel.visible = to == RunController.Phase.RESULT
	# The combat clock only runs during COMBAT (G2); every other phase keeps it paused.
	get_tree().paused = pause_panel.visible or to != RunController.Phase.COMBAT
	match to:
		RunController.Phase.WAVE_PREP:
			hud.set_build(run.build, db_ref)
			prep_label.text = "Wave %d%s" % [run.wave, " 보스" if run.is_boss_wave() else ""]
			%PrepHint.text = _prep_hint()
			%StartWaveButton.grab_focus()
		RunController.Phase.COMBAT:
			director.set_hold(false)
			hud.set_temp_drops(0)
			director.pin_lacking = run.pin_lacking()
			director.start_wave(run.wave_data(), hash("spawn:%d:%d" % [run_seed, run.wave]))
		RunController.Phase.CLEAR:
			clear_panel.open(run.build_reward(), db_ref, _clear_stats_text())
		RunController.Phase.FORGE:
			forge_panel.open(run, db_ref)
		RunController.Phase.RESULT:
			director.set_hold(false)
			result_label.text = _result_text(run.end_reason)
			%ResultLibraryButton.grab_focus()


## G10 Wave Clear row: 정화/놓침, 안정도 손실, 회수 수.
func _clear_stats_text() -> String:
	return "정화 %d · 놓침 %d · 안정도 손실 %.1f · 회수 %d" % [director.stats["purified"], director.stats["reached"], run.wave_damage_taken, run.drops.drops.size()]


## Data first, then the 회수 feedback (G12): the drop is counted before the glyph floats.
func _on_enemy_purified(monster: JamoMonster, _source: StringName) -> void:
	if monster is Boss:
		return  # boss bodies only give their guaranteed B9 drops, handled by the director
	if run.on_purified(monster.jamo):
		hud.set_temp_drops(run.drops.drops.size())
		director.spawn_text(monster.global_position, "+" + monster.jamo, Color(0.95, 0.75, 0.2))


## 보스 등장 (G10): name plus the one response line, shown only before combat starts.
func _prep_hint() -> String:
	if not run.is_boss_wave():
		return "자모를 눌러 마지막 문장을 지키세요" if run.wave == 1 else ""
	var b: BossData = db_ref.bosses[run.wave_data().boss_id]
	return "%s 등장. 표식이 나타나면 %d번 눌러 대응하세요." % [b.name, b.respond_count]


## RUN Result (G9): reason, reached/cleared Wave, top loss causes, build, discoveries, Gold,
## and exactly one next goal. Gold shows the integer part that would be settled.
func _result_text(reason: RunController.EndReason) -> String:
	var head := ""
	match reason:
		RunController.EndReason.COMPLETED:
			head = "첫 문서 복원 완료."
		RunController.EndReason.ABANDONED:
			head = "귀환."
		_:
			head = "이번 페이지의 연결이 끊어졌다. 서고의 기록은 남아 있다."
	var lines: Array[String] = [head, "도달 Wave %d · 클리어 Wave %d" % [run.wave, run.waves_cleared]]
	var causes: Array[String] = []
	var keys := run.damage_causes.keys()
	keys.sort_custom(func(a, b): return run.damage_causes[a] > run.damage_causes[b])
	for k in keys.slice(0, 2):
		causes.append("%s %.1f" % [_cause_name(k), run.damage_causes[k]])
	lines.append("안정도 피해 원인: %s" % (", ".join(causes) if not causes.is_empty() else "없음"))
	var build_parts: Array[String] = []
	for held in run.build.words:
		build_parts.append("%s R%d" % [db_ref.words[held["id"]].name, held["rank"]])
	lines.append("대표 빌드: %s" % (", ".join(build_parts) if not build_parts.is_empty() else "없음"))
	var found: Array[String] = []
	for id in run.discovered:
		found.append(db_ref.words[id].name)
	lines.append("신규 복원: %s" % (", ".join(found) if not found.is_empty() else "없음"))
	lines.append("획득 Gold: %d G" % int(run.gold_run))
	lines.append("다음 목표: %s" % _next_goal())
	return "\n".join(lines)


func _cause_name(cause: StringName) -> String:
	match cause:
		&"reach": return "적 도달"
		&"pattern": return "보스 패턴"
	return String(cause)


## One suggestion (G9): the pinned word if it still lacks jamo, else the first compound recipe
## whose materials are not both held, else W5.
func _next_goal() -> String:
	if run.pinned_word != &"":
		var lacking := run.pin_lacking()
		if not lacking.is_empty():
			return "%s에 부족한 자모 %s 회수" % [db_ref.words[run.pinned_word].name, ", ".join(lacking)]
	var ids := db_ref.compounds.keys()
	ids.sort()
	for id in ids:
		var c: CompoundData = db_ref.compounds[id]
		if not (run.build.has(c.material_a) and run.build.has(c.material_b)):
			return "%s과 %s을 함께 복원하면 새로운 뜻을 엮을 수 있다" % [db_ref.words[c.material_a].name, db_ref.words[c.material_b].name]
	return "거대한 ㅁ에 도전하기"


func _open_pause() -> void:
	pause_panel.visible = true
	director.set_hold(false)
	get_tree().paused = true
	%ResumeButton.grab_focus()


func _close_pause() -> void:
	pause_panel.visible = false
	get_tree().paused = run.phase != RunController.Phase.COMBAT


func _on_abandon() -> void:
	pause_panel.visible = false
	run.abandon()


func _on_return_to_library() -> void:
	if run.return_to_library():
		get_tree().paused = false
		get_tree().change_scene_to_file(LIBRARY_SCENE)
