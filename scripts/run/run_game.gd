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
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var banner: Label = %Banner
@onready var input_shield: Control = %InputShield
## Clicks arriving right after a screen change belong to the fight, not the new panel.
const INPUT_SHIELD_SECONDS := 0.45
const SHEET_RECT := Rect2(200, 160, 1500, 810)
var shield_timer: SceneTreeTimer
var last_stability: float = -1.0
var banner_tween: Tween

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
	director.seal_changed.connect(func(): hud.set_build(run.build, db_ref, director.resolver.seal_remaining()))
	clear_panel.finished.connect(func(): run.finish_clear())
	hud.bind(run)
	run.phase_changed.connect(_on_phase_changed)
	%StartWaveButton.pressed.connect(func(): run.begin_combat())
	forge_panel.finished.connect(func(): run.finish_forge())
	%ResultLibraryButton.pressed.connect(_on_return_to_library)
	%RetryButton.pressed.connect(func(): run.retry_run())
	%ResumeButton.pressed.connect(_close_pause)
	%AbandonButton.pressed.connect(_on_abandon)
	%PauseSettingsButton.pressed.connect(_open_settings)
	settings_panel.closed.connect(func(): %ResumeButton.grab_focus())
	pause_panel.visible = false
	settings_panel.visible = false
	SettingsService.apply_all()
	SettingsService.apply_text_scale($UI/Panels, int(Meta.setting("text_scale")))
	run.stability_changed.connect(_on_stability_changed)
	page.get_node("LastSentence/Text").text = LibraryService.sentence_text(db)
	_dress_page()
	page.get_node("Overlays/InkOverlay").visible = false  # edge smears read as stray lines
	page.get_node("LastSentence/Row").visible = not AssetLib.apply(page.get_node("LastSentence/RowArt"), "sentence_row")
	Sfx.play_bgm("combat")
	clear_panel.state_changed.connect(_save_run)
	forge_panel.state_changed.connect(_save_run)
	if Meta.resume_pending and Meta.has_run():
		Meta.resume_pending = false
		run.load_snapshot(Meta.run)
		run_seed = run.run_seed  # same spawn/drop streams as the interrupted RUN
	else:
		Meta.resume_pending = false
		run.open_run_setup()
		run.confirm_setup(Meta.chosen_deck if db.decks.has(Meta.chosen_deck) else &"starter_a")
	RunLog.begin_run(run.run_id, run_seed, Meta.CONTENT_VERSION, Meta.research, String(run.deck_id))


func _physics_process(delta: float) -> void:
	# Root runs always (for Esc); the combat clock only advances while unpaused in COMBAT.
	%Dim.visible = get_tree().paused and not %Banner.visible
	if get_tree().paused:
		return
	var cursor := page.get_global_mouse_position()
	director.tick(delta, cursor)
	hud.set_hover(director.pick_target(cursor) if run.phase == RunController.Phase.COMBAT else null)
	if not director.resolver.sealed.is_empty():
		hud.set_build(run.build, db_ref, director.resolver.seal_remaining())  # countdown while sealed


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the topmost popup first (settings over pause), then opens the pause menu (G10).
	if event.is_action_pressed("pause") and run.phase != RunController.Phase.RESULT:
		if settings_panel.visible:
			settings_panel.visible = false
			%ResumeButton.grab_focus()
		elif pause_panel.visible:
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
	if to in [RunController.Phase.CLEAR, RunController.Phase.FORGE, RunController.Phase.RESULT]:
		_raise_input_shield()
	director.set_hold(false)
	prep_panel.visible = to == RunController.Phase.WAVE_PREP
	clear_panel.visible = to == RunController.Phase.CLEAR
	forge_panel.visible = to == RunController.Phase.FORGE
	result_panel.visible = to == RunController.Phase.RESULT
	# The combat clock only runs during COMBAT (G2); every other phase keeps it paused.
	get_tree().paused = pause_panel.visible or to != RunController.Phase.COMBAT
	match to:
		RunController.Phase.WAVE_PREP:
			_save_run()  # 체크포인트: 전투 시작 직전 상태 (G14)
			hud.set_build(run.build, db_ref)
			prep_label.text = "W%d%s" % [run.wave, " · " + db_ref.bosses[run.wave_data().boss_id].name if run.is_boss_wave() else ""]
			var line := run.take_pending_line()
			%PrepHint.text = _prep_hint() + ("\n" + line if line != "" else "")
			%StartWaveButton.grab_focus()
			_show_banner("Wave %d" % run.wave, 0.6)
			RunLog.event("wave_prep", {"wave": run.wave, "stability": run.stability, "gold": run.gold_run, "deck": run.deck.jamo_list(), "build": run.build.words.duplicate(true)})
		RunController.Phase.COMBAT:
			director.set_hold(false)
			hud.set_temp_drops(0)
			director.pin_lacking = run.pin_lacking()
			director.risk_unlocked = run.risk_unlocked
			director.start_wave(run.wave_data(), hash("spawn:%d:%d" % [run_seed, run.wave]))
			last_stability = run.stability
			Sfx.set_boss_layer(run.is_boss_wave())
			if run.is_boss_wave():
				_show_banner(db_ref.bosses[run.wave_data().boss_id].name, 1.2)
				Sfx.play("boss_intro", CombatDirector.PRIORITY_WARNING, 1.2)
			else:
				_show_banner("", 0.0)
			RunLog.event("wave_start", {"wave": run.wave, "stability": run.stability})
		RunController.Phase.CLEAR:
			Sfx.set_boss_layer(false)
			_show_banner("Wave Clear", 0.8)
			Sfx.play("page_turn", 1, 0.5)
			RunLog.event("wave_clear", {"wave": run.wave, "stability": run.stability, "hits": director.stats["hits"], "misses": director.miss_clicks,
				"purified": director.stats["purified"], "reached": director.stats["reached"], "patterns_failed": director.stats["patterns_failed"],
				"drops": run.drops.drops.duplicate(), "gold": run.gold_run, "wave_gold": director.wave_gold, "damage_taken": run.wave_damage_taken,
				"hold_time": director.stats["hold_time"], "damage_by_source": director.stats["damage_by_source"].duplicate(), "causes": run.damage_causes.duplicate()})
			var line := run.take_pending_line()
			clear_panel.open(run.build_reward(), db_ref, _clear_stats_text() + ("\n" + line if line != "" else ""))
			_save_run()
		RunController.Phase.FORGE:
			forge_panel.open(run, db_ref)
			_save_run()
		RunController.Phase.RESULT:
			Sfx.set_boss_layer(false)
			director.set_hold(false)
			result_label.text = _result_text(run.end_reason)
			var icon_id: String = {RunController.EndReason.COMPLETED: "result_complete", RunController.EndReason.ABANDONED: "result_abandon"}.get(run.end_reason, "result_fail")
			AssetLib.apply(%ResultIcon, icon_id)
			%ResultLibraryButton.grab_focus()
			RunLog.event("result", {"reason": RunController.EndReason.keys()[run.end_reason], "wave": run.wave, "cleared": run.waves_cleared,
				"gold": run.gold_run, "causes": run.damage_causes.duplicate(), "build": run.build.words.duplicate(true), "discovered": run.discovered.duplicate()})
			RunLog.end_run()


## G10 Wave Clear row: 정화/놓침, 안정도 손실, 회수 수.
func _clear_stats_text() -> String:
	return "정화 %d · 놓침 %d · 손실 %.0f · 회수 %d" % [director.stats["purified"], director.stats["reached"], run.wave_damage_taken, run.drops.drops.size()]


## Data first, then the 회수 feedback (G12): the drop is counted before the glyph floats.
func _on_enemy_purified(monster: JamoMonster, _source: StringName) -> void:
	if monster is Boss:
		Sfx.play("boss_purified", CombatDirector.PRIORITY_WARNING, 1.0)
		return  # boss bodies only give their guaranteed B9 drops, handled by the director
	if run.on_purified(monster.jamo):
		hud.set_temp_drops(run.drops.drops.size())
		director.spawn_text(monster.global_position, "+" + monster.jamo, Color(0.95, 0.75, 0.2))


## 보스 등장 (G10): name plus the one response line, shown only before combat starts.
func _prep_hint() -> String:
	if not run.is_boss_wave():
		# The W1 guidance belongs to the first RUN only (G2: 재도전은 안내를 다시 보이지 않는다).
		return "자모를 눌러 문장을 지켜요" if run.wave == 1 and run.first_run else ""
	var b: BossData = db_ref.bosses[run.wave_data().boss_id]
	return b.response_hint if b.response_hint != "" else "표식 %d번 → 대응" % b.respond_count


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
	var lines: Array[String] = [head, "W%d 도달 · W%d 클리어" % [run.wave, run.waves_cleared]]
	var causes: Array[String] = []
	var keys := run.damage_causes.keys()
	keys.sort_custom(func(a, b): return run.damage_causes[a] > run.damage_causes[b])
	for k in keys.slice(0, 2):
		causes.append("%s %.0f" % [_cause_name(k), run.damage_causes[k]])
	lines.append("손실 · %s" % (" · ".join(causes) if not causes.is_empty() else "없음"))
	var build_parts: Array[String] = []
	for held in run.build.words:
		build_parts.append("%s R%d" % [db_ref.words[held["id"]].name, held["rank"]])
	lines.append("빌드 · %s" % (", ".join(build_parts) if not build_parts.is_empty() else "없음"))
	var found: Array[String] = []
	for id in run.discovered:
		found.append(db_ref.words[id].name)
	lines.append("신규 · %s" % (", ".join(found) if not found.is_empty() else "없음"))
	lines.append("%dG" % int(run.gold_run))
	lines.append("다음 · %s" % _next_goal())
	return "\n".join(lines)


func _cause_name(cause: StringName) -> String:
	match cause:
		&"reach": return "도달"
		&"pattern": return "패턴"
	return String(cause)


## One suggestion (G9): the pinned word if it still lacks jamo, else the first compound recipe
## whose materials are not both held, else W5.
func _next_goal() -> String:
	if run.pinned_word != &"":
		var lacking := run.pin_lacking()
		if not lacking.is_empty():
			return "%s: %s 회수" % [db_ref.words[run.pinned_word].name, " ".join(lacking)]
	var ids := db_ref.compounds.keys()
	ids.sort()
	for id in ids:
		var c: CompoundData = db_ref.compounds[id]
		if not (run.build.has(c.material_a) and run.build.has(c.material_b)):
			return "%s+%s 합성" % [db_ref.words[c.material_a].name, db_ref.words[c.material_b].name]
	return "거대한 ㅁ 도전"


## Atomic save of the whole logical RUN state (G14). Never called during COMBAT.
func _save_run() -> void:
	if run.phase == RunController.Phase.COMBAT or run.phase == RunController.Phase.RESULT:
		return
	Meta.run = run.snapshot()
	Meta.save()


## Page art (S8): a dedicated desk painting when present; otherwise the library painting,
## dimmed, under a paper sheet clipped to the play area (B11 sheet rect).
func _dress_page() -> void:
	var art: Sprite2D = page.get_node("Paper/PaperArt")
	if AssetLib.apply(art, "combat_desk"):
		page.get_node("Paper/Sheet").visible = false
		return
	var desk: Sprite2D = page.get_node("Paper/DeskArt")
	if AssetLib.apply(desk, "lib_bg"):
		desk.scale = Vector2(1920.0 / desk.texture.get_width(), 1080.0 / desk.texture.get_height())
	if AssetLib.apply(art, "paper_bg"):
		art.position = SHEET_RECT.get_center()
		art.scale = SHEET_RECT.size / Vector2(art.texture.get_size())
		page.get_node("Paper/Sheet/SheetPaper").visible = false


## Wave/boss banners (G12): 0.6s prep, 0.8s clear, 1.2s boss name; empty text hides it.
func _show_banner(text: String, seconds: float) -> void:
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	banner.text = text
	banner.visible = text != ""
	banner.modulate.a = 1.0
	if text == "" or seconds <= 0.0:
		return
	banner_tween = create_tween()
	banner_tween.set_ignore_time_scale(true)
	banner_tween.tween_interval(seconds)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.15)
	banner_tween.tween_callback(func(): banner.visible = false)


## 문장 피격 (G12): border flash (unless 섬광 off), loss number, shake at most 3px for 0.12s
## scaled by the 흔들림 setting; the sentence has no click area, so nothing moves for input.
func _on_stability_changed(current: float, _maximum: float) -> void:
	if last_stability >= 0.0 and current < last_stability and run.phase == RunController.Phase.COMBAT:
		_sentence_hit(last_stability - current)
	last_stability = current


func _sentence_hit(loss: float) -> void:
	var sentence: Node2D = page.get_node("LastSentence")
	var row: Line2D = sentence.get_node("Row")
	director.spawn_text(Vector2(960, 900), "-%.1f" % loss, Color(0.75, 0.15, 0.1))
	if SettingsService.flash_enabled():
		row.default_color = Color(0.9, 0.2, 0.1, 1)
		var t := create_tween()
		t.tween_property(row, "default_color", Color(0.2, 0.18, 0.15, 1), 0.2)
		var art: Sprite2D = sentence.get_node("RowArt")
		if art.texture != null and AssetLib.tex("sentence_row_hit") != null:
			art.texture = AssetLib.tex("sentence_row_hit")
			t.tween_callback(func(): art.texture = AssetLib.tex("sentence_row"))
	var amp := 3.0 * SettingsService.shake_factor()
	if amp <= 0.0:
		return
	var origin := Vector2(0, 910)
	var shake := create_tween()
	shake.tween_property(sentence, "position", origin + Vector2(amp, 0), 0.04)
	shake.tween_property(sentence, "position", origin - Vector2(amp, 0), 0.04)
	shake.tween_property(sentence, "position", origin, 0.04)


## 포커스 상실·최소화는 자동 정지 (G10).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_node_ready() and run != null and run.phase == RunController.Phase.COMBAT and not get_tree().paused:
			_open_pause()


## A transparent full-screen Control eats mouse input for a moment after a panel opens, so the
## clicks (and a held button) aimed at the last enemy never land on 자모/단어 buttons (G10).
func _raise_input_shield() -> void:
	input_shield.visible = true
	shield_timer = get_tree().create_timer(INPUT_SHIELD_SECONDS, true, false, true)
	shield_timer.timeout.connect(_drop_input_shield)


func _drop_input_shield() -> void:
	input_shield.visible = false
	shield_timer = null


func _open_settings() -> void:
	settings_panel.open($UI/Panels)


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
