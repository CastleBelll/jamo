extends Node
## B12 verification runner. Headless: `godot --headless --path . tools/verify/verify.tscn -- --runs=2000`.
## Add `--perf` (needs a window) to measure frame time on this PC. Writes docs/JAMO_B12_REPORT.md.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const REPORT_PATH := "res://docs/JAMO_B12_REPORT.md"
const DIRECTIONS := {"공격": &"무기", "지속": &"지속", "자동": &"자동", "방어": &"방어"}
const BUILD_SEEDS := [11, 22, 23]
const MAX_RESEARCH := ["R_SAFE_1", "R_SAFE_2", "R_DECK_B"]
const PERF_WAVES := 3

var db: ContentDB
var runs: int = 2000
var perf: bool = false
var rows: Array[Dictionary] = []     # {check, n, measured, target, verdict}
var details: Array[String] = []
var late: Dictionary = {}            # late_loop at 75%, shared by 후반 추첨 / 선택 / 공급


func _ready() -> void:
	_parse_args()
	Meta.saver.path = "user://b12_verify.json"
	Meta.new_profile()
	Meta.first_run_done = true  # B3/B6: the tutorial hand is excluded from every statistic
	RunLog.enabled = false
	db = ContentDB.load_all()
	var errors := db.validate()
	_row("데이터", 1, "오류 %d" % errors.size(), "0", errors.is_empty())
	_check_first_draw()
	_check_late_draw()
	_check_choice()
	_check_supply()
	_check_build_directions()
	_check_meta()
	if perf:
		await _check_perf()
	else:
		_row("성능", 0, "미측정 (--perf 창 모드 필요)", "60fps p95", false)
	_write_report()
	Meta.saver.delete_all()
	get_tree().quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = maxi(int(arg.trim_prefix("--runs=")), 10)
		elif arg == "--perf":
			perf = true


## `verdict`: "PASS" / "FAIL", or "기록" for rows B12 only asks to observe.
func _row(check: String, n: int, measured: String, target: String, verdict: Variant) -> void:
	var text: String = verdict if verdict is String else ("PASS" if verdict else "FAIL")
	rows.append({"check": check, "n": n, "measured": measured, "target": target, "verdict": text})
	print("%s | N=%d | %s | 목표 %s | %s" % [check, n, measured, target, text])


# --- 추첨 (B12 row 2): first hand failure 15~40%, empty build after rerolls <= 10% -----------

func _check_first_draw() -> void:
	for deck_id in db.decks:
		var r := B12Sim.first_draw(db, deck_id, runs)
		var ok: bool = r["first_fail"] >= 0.15 and r["first_fail"] <= 0.40 and r["after_reroll_fail"] <= 0.10
		_row("추첨 %s" % db.decks[deck_id].name, runs, "첫 손패 실패 %.1f%% · Reroll 후 %.1f%%" % [r["first_fail"] * 100, r["after_reroll_fail"] * 100], "15~40% · ≤10%", ok)


# --- 후반 추첨 (B12 row 3): valid-zero ratio per Wave <= 15% at 75% purification --------------

func _check_late_draw() -> void:
	late = B12Sim.late_loop(db, runs, 0.75)
	var worst := 0.0
	var worst_wave := 0
	var lines: Array[String] = []
	for wave in range(1, B12Sim.NORMAL_WAVES + 1):
		var zero: float = float(late["zero_by_wave"].get(wave, 0)) / runs
		var avg: float = float(late["candidates_by_wave"].get(wave, 0)) / runs
		lines.append("W%d 유효0 %.1f%% · 최종 후보 %.2f" % [wave, zero * 100, avg])
		if zero > worst:
			worst = zero
			worst_wave = wave
	details.append("후반 추첨 (정화율 75%%, B6 Lock 정책, RUN %d): " % runs + " / ".join(lines))
	_row("후반 추첨", runs, "최악 W%d 유효0 %.1f%%" % [worst_wave, worst * 100], "≤15%", worst <= 0.15)


# --- 선택 (B12 row 6): final candidates 1.5~3 on average, some Rerolls left unused ------------

func _check_choice() -> void:
	var forges: int = late["forges"]
	var mean: float = float(late["final_candidates"]) / maxi(forges, 1)
	var stopped: float = float(late["stopped_with_rerolls"]) / maxi(forges, 1)
	details.append("선택: 최종 후보 = B6 정책으로 멈춘 손패의 후보 수(복원 직전에 셈, 복원 단어 포함·중복 없음). 'Reroll 남기고 종료' = Reroll을 1회 이상 쓰고도 남긴 채 멈춘 Forge 비율.")
	_row("선택", forges, "최종 후보 평균 %.2f · Reroll 남기고 종료 %.1f%%" % [mean, stopped * 100], "1.5~3 · 존재", mean >= 1.5 and mean <= 3.0 and stopped > 0.0)


# --- 공급 (B12 row 4): pinned-lacking jamo delivered per Wave at 50/75/100% purification ------

func _check_supply() -> void:
	var parts: Array[String] = []
	var total_waves := 0
	for rate in [0.5, 0.75, 1.0]:
		var r: Dictionary = late if is_equal_approx(rate, 0.75) else B12Sim.late_loop(db, runs, rate)
		total_waves += r["supply_waves"]
		parts.append("%.0f%% → %.1f%% (Wave %d)" % [rate * 100, 100.0 * r["supply_delivered"] / maxi(r["supply_waves"], 1), r["supply_waves"]])
	details.append("공급: RUN 진행 중 실제 덱에서 목표(부족 자모가 가장 적은 단어)를 핀하고, 그 Wave의 회수에 부족 자모가 하나라도 들어온 비율.")
	_row("공급", total_waves, "부족 자모 도착률 " + " · ".join(parts), "기록 (조정 기준은 관찰)", "기록")


# --- 빌드 (B12 row 8): all 4 directions reach W10, 3 of them reach W20 ------------------------

func _check_build_directions() -> void:
	var reach10 := 0
	var reach20 := 0
	var lines: Array[String] = []
	for label in DIRECTIONS:
		var best := 0
		var per_seed: Array[String] = []
		for seed in BUILD_SEEDS:
			var bot := B12Bot.new()
			bot.direction = DIRECTIONS[label]
			bot.boot(RUN_GAME, db, seed, self)
			var cleared := bot.play_run()
			best = maxi(best, cleared)
			per_seed.append("seed %d: W%d, 평균 전투 %ds" % [seed, cleared, int(_avg(bot.wave_seconds))])
			bot.free_game()
		lines.append("%s → %s" % [label, "; ".join(per_seed)])
		if best >= 10:
			reach10 += 1
		if best >= 20:
			reach20 += 1
	details.append("빌드 방향 (봇은 B1 입력 간격마다 빠짐없이 최적 대상을 누르는 실력 상한이므로 도달 Wave는 상한값; 사람은 더 낮게 나온다): " + " / ".join(lines))
	_row("빌드", DIRECTIONS.size() * BUILD_SEEDS.size(), "W10 도달 %d/4 · W20 %d/4" % [reach10, reach20], "4/4 · ≥3/4", reach10 == 4 and reach20 >= 3)


# --- 메타 (B12 row 9): same seed/input, no research vs max research -> same W1 clicks ---------

func _check_meta() -> void:
	var a := _play_w1(false)
	var b := _play_w1(true)
	Meta.research = []
	var applied: bool = b["stability_max"] > a["stability_max"]
	_row("메타", 2, "안정도 상한 %.0f/%.0f · W1 적중 %d/%d · 정화 %d/%d" % [a["stability_max"], b["stability_max"], a["hits"], b["hits"], a["purified"], b["purified"]],
		"연구 적용 · 적중/정화 동일", applied and a["hits"] == b["hits"] and a["purified"] == b["purified"])


func _play_w1(max_research: bool) -> Dictionary:
	Meta.research = MAX_RESEARCH.duplicate() if max_research else []
	var bot := B12Bot.new()
	bot.boot(RUN_GAME, db, 77, self)
	bot.play_wave()
	var out := {"hits": bot.w1_hits, "purified": bot.w1_purified, "stability_max": bot.run.stability_max}
	bot.free_game()
	return out


# --- 성능 (B11): real-time W1..W3 with the bot, frame time p95 on this PC ---------------------

func _check_perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # measure headroom, not the monitor
	var bot := B12Bot.new()
	bot.boot(RUN_GAME, db, 5, self)
	var samples: Array[float] = []
	var deadline := Time.get_ticks_msec() + int(B12Bot.MAX_WAVE_SECONDS * PERF_WAVES * 1000)
	while bot.run.phase == RunController.Phase.WAVE_PREP and bot.run.wave <= PERF_WAVES and Time.get_ticks_msec() < deadline:
		bot.run.begin_combat()
		while bot.run.phase == RunController.Phase.COMBAT and Time.get_ticks_msec() < deadline:
			bot.click_best()
			var dt := get_process_delta_time()
			bot.director.tick(dt)
			samples.append(dt * 1000.0)
			await get_tree().process_frame
		bot.settle_wave()
	bot.free_game()
	samples.sort()
	var p95: float = samples[int(samples.size() * 0.95)] if not samples.is_empty() else 0.0
	var worst: float = samples[-1] if not samples.is_empty() else 0.0
	var slow := 0
	for s in samples:
		if s > 16.7:
			slow += 1
	details.append("성능 (vsync 끔): %s / %s, 프레임 %d개, p95 %.1fms, 16.7ms 초과 %d개, 최악 %.1fms" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), samples.size(), p95, slow, worst])
	_row("성능", samples.size(), "p95 %.1fms (%.0ffps) · 16.7ms 초과 %d · 최악 %.1fms" % [p95, 1000.0 / maxf(p95, 0.001), slow, worst], "p95 ≤16.7ms", p95 <= 16.7)


func _avg(d: Dictionary) -> float:
	if d.is_empty():
		return 0.0
	var total := 0.0
	for v in d.values():
		total += v
	return total / d.size()


func _write_report() -> void:
	var lines: Array[String] = ["# JAMO B12 검증 보고서", "", "생성 %s · 기준 runs=%d · content %s" % [Time.get_date_string_from_system(), runs, Meta.CONTENT_VERSION], "",
		"사람 관찰 항목(첫 경험·클릭 피로·보스 설명·재도전)은 이 보고서에 없다. 여기 통과는 계산/봇 검사 통과일 뿐 플레이테스트 통과가 아니다.", "",
		"| 검사 | N | 측정 | 목표 | 판정 |", "|---|---:|---|---|---|"]
	for r in rows:
		lines.append("| %s | %d | %s | %s | %s |" % [r["check"], r["n"], r["measured"], r["target"], r["verdict"]])
	lines.append("")
	lines.append("## 상세")
	lines.append("")
	for d in details:
		lines.append("- " + d)
	lines.append("")
	lines.append("## 재현")
	lines.append("")
	lines.append("```")
	lines.append("godot %s--path . tools/verify/verify.tscn -- --runs=%d%s" % ["" if perf else "--headless ", runs, " --perf" if perf else ""])
	lines.append("```")
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		printerr("cannot write " + REPORT_PATH)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("report written: " + REPORT_PATH)
