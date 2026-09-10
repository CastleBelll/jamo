# JAMO P0 (v0.4 전환) — QA 리포트

**판정: PASS** — P0 완료 기준(§48 Phase 0)과 FAIL 판정 항목(State 혼용 / `current_day` 잔존 /
F7~F9 확정 사항 파손)에 해당하는 결함은 없다.
다만 **HIGH 1건**(v0.3 마이그레이션 안내문 판독 불가)은 P1 착수 전에 고치기를 권고한다.

- 기준 문서: `docs/JAMO_total_project_development_plan_v0.4.md` (단독 1순위)
- 규칙: `docs/ORCHESTRATION_RULES.md` §4, §7 / `docs/DEV_ROADMAP.md` P0
- DEV 인계문: `tests/qa_artifacts/p0/DEV_HANDOFF.md` (검수 절차 1~31, 주의사항 1~22 전수 확인)
- 검증 수단: `mcp__ziva-godot__start_godot` 로 실제 Godot 을 띄워 눈으로 보고 조작 +
  창 모드 하네스 12종 + 헤드리스 테스트 2종 + negative control 8종
- Godot 4.7.stable / Intel UHD 770 / Windows 11

---

## 0. 요약표

| 항목 | 결과 | 근거 |
|---|---|---|
| A. State 분리 (§3, §44) | **PASS** | 필드 겹침 0, 부정 대조 7/8 검출 |
| B. Wave 전환 (§5) | **PASS** | `current_day` 0건, HUD `WAVE 1` |
| C. P0 완료 기준 (§48 Phase 0) | **PASS** | 실조작 전체 경로 2회 통과, 스크린샷 10장 |
| D. 세이브 (§45) | **PASS** (HIGH 1건) | 마이그레이션 무크래시·Gold 보존·`legacy_v03` 보존 확인 |
| E. Main Hub (§27) | **PASS** | 메뉴 5종 + 성장 4수치, 판때기 규칙 74쌍 전수 통과 |
| F. WordData (§21) | **PASS** | 10개 전부 v0.4 스키마, `prerequisites` 제거 타당 |
| G. 보류 처리 (§46) | **PASS** | 삭제 0건, `.gdignore` 실동작 확인 |
| H. 자동 테스트 | **PASS** | 정적 0에러(폰트 제외), 테스트 12/12 |

### 결함 목록

| # | 등급 | 요약 | 위치 |
|---|---|---|---|
| 1 | **HIGH** | v0.3 마이그레이션 안내문이 명도 대비 **1.04:1** 로 사실상 읽히지 않는다 | `scenes/ui/title_screen.tscn` `MigrationNoteLabel` |
| 2 | MEDIUM | F7~F9 하네스가 허브 7개 판때기 중 4개만 검사한다 (신규 3개 미검증) | `tests/qa_f7_art.gd:99` 외 4파일 |
| 3 | MEDIUM | `test_state_split` 의 겹침 검사가 구조 검증이 아니라 **이름 블랙리스트**다 | `tests/test_state_split.gd:81` |
| 4 | MEDIUM | 결과 화면이 "문장핵이 무너졌다" 라고 하는데 HUD 는 `문장핵 20 / 20` 이다 | `scenes/ui/run_result.tscn` `SubtitleLabel` |
| 5 | LOW | Day 시절 주석 잔존 ("day-scaled base HP") | `scripts/data/jamo_monster_data.gd:17,19` |
| 6 | LOW | 신규 테스트 2종의 `.uid` 가 커밋 대상에 없다 | `tests/test_state_split.gd.uid`, `tests/test_run_flow.gd.uid` |
| 7 | INFO | Wave 곡선이 Day 곡선 1:1 — `ORCHESTRATION_RULES` §7 문구와 정면 충돌 (총지휘자 승인 필요) | `resources/balance/game_balance.tres` |
| 8 | INFO | 보류 씬의 `ext_resource` 경로가 이동 전 경로 그대로다 | `tests/_deferred_v03/*.tscn` |

---

## A. State 분리 (v0.4 §3, §44)

### A-1. 필드 겹침 — PASS

`MetaState` 와 `RunState` 의 스크립트 프로퍼티를 직접 비교했다. 겹치는 이름 0개.

- `MetaState`: `save_version / gold / permanent_upgrade_levels / codex_words /
  codex_mastery_exp / codex_mastery_levels / discovered_compounds /
  discovered_synergies / defeated_word_bosses / highest_wave / statistics`
- `RunState`: `is_active / current_wave / core_hp / core_max_hp / current_energy /
  jamo_draw_bag / jamo_discard_bag / current_slot_jamo / rerolls / locks /
  equipped_words / run_word_ranks / active_synergies / active_compounds /
  risk_words / run_modifiers / run_statistics`

§44 의 두 목록과 1:1 로 일치한다. `core_max_hp` 만 §44 에 없는 추가 필드인데 런 한정이
맞고 `RUN_OWNED_NAMES` 에 등록돼 있어 문제 없다.

### A-2. RUN 실패 시 초기화 범위 — PASS (실플레이 확인)

`tests/qa_p0_flow.tscn` 으로 실제 창에서 실제 마우스 클릭으로 2회 패배시켰다.

```
save[run in progress]:  top=["audio","meta","run","save_version"] run_present=true
save[after the defeat]: top=["audio","meta","save_version"]       run_present=false
growth(패배 후):        GOLD 12 G | 최고 WAVE 1 | 발견 단어 0 / 10 | 처치 보스 0
growth(2회차 패배 후):  GOLD 24 G | ...
```

- 남은 것: Gold(12 → 24 누적), 도감, 숙련, 최고 Wave, 처치 보스, 통계
- 사라진 것: `run` 블록 전체 — Wave / 문장핵 / 에너지 / 자모 덱 / 장착 단어 /
  Run Rank / 시너지. 허브 복귀 시 `RunState.equipped_words` 와 `run_statistics` 가 비어 있음을
  확인했다.
- 근거: `flow/03_run_result.png`, `flow/04_hub_after_defeat.png`,
  `flow/08_hub_after_second_defeat.png`

### A-3. 도감 등록 ≠ 효과 활성 (§38) — PASS

v0.3 세이브에서 `fire_001`(불) 을 도감으로 이관한 직후를 측정했다.

```
MetaState.has_codex_word("fire_001") == true
RunState.is_word_equipped("fire_001") == false
RunState.get_burn_effect() == null          <- 도감만으로는 화상이 켜지지 않는다
```

`RunState._recalculate_word_bonuses()` 는 `equipped_words` 만 순회하고 `codex_words` 를
읽지 않는다. 부정 대조 NC5 로 이 경계가 실제로 검사되고 있음을 확인했다(아래 A-5).

### A-4. 패배한 런은 복구 불가 (§44) — PASS

3중으로 막혀 있고 3중 다 확인했다.

1. `main.gd::_fail_run()` 이 결과 화면을 띄우기 **전에** `SaveManager.clear_run()` 을 부른다.
   결과 화면에서 강제 종료해도 되살아나지 않는다.
2. `SaveManager.save_run()` 은 `RunState.is_active` 가 false 면 `run` 키를 지운다.
3. `SaveManager.peek_run()` 은 `core_hp <= 0` 인 런을 아예 반환하지 않는다.
   (구버전이 그런 파일을 남겼더라도 `RUN 이어하기` 가 뜨지 않는다)

실조작: 패배 → `메인 허브로` → `RUN 이어하기` 미표시(`flow/04`, `flow/08`).
반대로 `ESC → 저장 후 메인 허브로` 는 `RUN 이어하기` 와
`진행 중인 RUN — WAVE 1 · 문장핵 20` 이 뜨고(`flow/06`), 이어받으면 남은 에너지
14/20 이 그대로 복원됐다(`flow/07`).

### A-5. `test_state_split` negative control — 8종 중 7종 검출, **1종 미검출**

프로덕션을 건드리지 않기 위해 프로젝트를 스크래치에 복제(`config/name` 을 바꿔 user 폴더까지
분리)하고 고의로 망가뜨린 뒤 테스트를 돌렸다.

| # | 주입한 결함 | 기대 | 실제 |
|---|---|---|---|
| NC0 | 없음 (기준선) | PASS | **PASS** |
| NC1 | `MetaState` 에 `current_wave` 추가 | FAIL | **FAIL** `MetaState must not carry the run field current_wave` |
| NC2 | `RunState.reset()` 무력화 | FAIL | **FAIL** 7건 |
| NC3 | `MetaState` 에 `stage_index` / `core_shield` 추가 | FAIL | **PASS ← 미검출** |
| NC4 | `end_run()` 이 `MetaState.gold` 를 0으로 | FAIL | **FAIL** `gold survives the defeat` |
| NC5 | 도감 등록만으로 효과 활성 (§38 위반) | FAIL | **FAIL** 2건 |
| NC6 | 마이그레이션이 Day → `highest_wave` 매핑 | FAIL | **FAIL** `Day 42 must not be handed over as a Wave 42 record` |
| NC7 | `clear_run()` 이 `run` 블록 유지 (패배 후 이어하기 가능) | FAIL | **FAIL** 3건 |
| NC8 | 마이그레이션이 `legacy_v03` 페이로드 폐기 | FAIL | **FAIL** 2건 |

**결론: 동어반복이 아니다.** 실패 시 초기화, Gold 보존, §38 경계, Day→Wave 금지,
패배 후 복구 불가, 원본 세이브 보존 — 전부 실제로 검출한다.

**단, 결함 #3 (MEDIUM)**: 겹침 검사는 `MetaState.RUN_OWNED_NAMES` /
`RunState.META_OWNED_NAMES` 상수 목록에 **이름이 적혀 있는 필드만** 본다.
목록에 없는 이름으로 런 성격 필드를 `MetaState` 에 넣으면(NC3) 그대로 통과한다.
즉 구조적 보증이 아니라 블랙리스트다. 두 상수와 실제 프로퍼티 집합이 **완전히 같은지**
(`RUN_OWNED_NAMES` == RunState 프로퍼티 − 공유 필드) 를 함께 단언하면 목록이 낡는 순간
테스트가 먼저 깨진다. P1 에서 필드가 늘어날 때 실제로 위험한 지점이다.

---

## B. Wave 전환 (§5)

### B-6. `current_day` grep — PASS

```
grep -rn "current_day" --include=*.gd --include=*.tscn --include=*.tres --include=*.godot .
  (보류 폴더 / .godot 캐시 제외)  → 0건
```

살아 있는 `day` 문자열은 (a) `save_manager.gd` 의 v0.3 마이그레이션 처리
(`_is_legacy_v03` / `migrated_from_v03_day`) — 의도된 것, (b) `jamo_monster_data.gd:17,19`
의 낡은 주석 두 줄 — **결함 #5 (LOW)** 뿐이다.

### B-7. HUD — PASS

실플레이 캡처 `flow/02_wave1_start.png`:

```
WAVE 1 | 문장핵 20 / 20 | ENERGY 20 / 20 | 0 G | 처치 0
좌하단: 장착 단어 / 장착한 단어 없음 — 자모 슬롯은 P2
```

`DAY` 표기 0건. 하네스에서도 `WaveLabel.text == "WAVE 1"` 을 단언한다.

### B-8. Wave 곡선 상태 기록 (FAIL 사유 아님)

`resources/balance/game_balance.tres`:
`hp_growth_per_wave = 1.035`, `gold_growth_per_wave = 1.035`,
`base_monster_hp = 3.0`, `base_monster_gold = 2.0` — **F8 Day 튜닝값 그대로**다.
`game_balance.gd:27` 에 `TEMPORARY, Phase 0 only` 주석이 있고 `DEV_ROADMAP.md` 의
"P0 에서 P1 으로 넘긴 임시 처리" 에도 적혀 있다.
§5.2 가 요구하는 이동속도 / 동시 등장 수 / 특수 자모 비율 / 스폰 속도 상승은 **없다**.

**결함 #7 (INFO, 총지휘자 판단 필요)**: `ORCHESTRATION_RULES.md` §7 은
"Day 시절 밸런스 수치를 재사용하지 않는다. Wave 곡선은 새로 산출한다" 라고 못박고 있다.
태스크 지시상 이번 FAIL 사유는 아니나, 규칙 문언과는 정면으로 어긋난다.
P1/P12 로 넘긴다는 명시적 승인을 남겨 두는 편이 좋다.

부수 확인: `start_max_energy = 20` 이지만 §7.1 기본값은 `Max Energy = 10` 이다.
`DEV_ROADMAP` P1 S5 가 이 재설계를 담당하므로 P0 결함으로 보지 않는다.

---

## C. P0 완료 기준 (§48 Phase 0) — 실조작

### C-9. 전체 경로 — PASS

`tests/qa_p0_flow.tscn` (신규, QA 작성) 이 **실제 마우스 이벤트**로 판때기를 그려진 위치에서
클릭하고, **실제 몬스터를 화면 좌표로 클릭**해 에너지를 소진시키며,
`change_scene_to_file()` 씬 전환을 그대로 통과한다.
(DEV 의 `test_run_flow` 는 `pressed.emit()` + `spend_click_energy()` 라 클릭 가능성 자체는
검증하지 못한다.)

```
-- 1. Main Hub, first launch        → flow/01_hub_first_launch.png
-- 2. RUN 시작 (그려진 위치를 클릭)  → flow/02_wave1_start.png   HUD: WAVE 1 ...
-- 3. 실제 몬스터 클릭 20회, ENERGY 20 → 0
-- 4. 결과 화면                      → flow/03_run_result.png
-- 5. 메인 허브로                    → flow/04_hub_after_defeat.png
-- 6. 일시정지 → 저장 후 메인 허브로  → flow/05_pause_menu.png, flow/06_hub_with_continue.png
-- 7. RUN 이어하기 (WAVE 1 / ENERGY 14 복원) → flow/07_resumed_run.png
-- 8. 재패배 → 이어하기 소멸          → flow/08_hub_after_second_defeat.png
-- 9. v0.3 세이브 마이그레이션        → flow/09_hub_v03_migrated.png
-- 10. 마이그레이션 후 상점           → flow/10_shop_after_migration.png
```

"landed 20 monster clicks, energy 20 -> 0" — 클릭이 실제로 몬스터에 맞았다는 뜻이다
(`ClickController` 는 몬스터를 맞혀야만 에너지를 쓴다).

### C-10. 임시 실패 조건 플래그 — 존재하고 분리돼 있음, P1 에서 끌 수 있음

`scripts/main.gd:23`

```gdscript
## TEMPORARY, Phase 0 only. ... Doc v0.4 section 7.1 is explicit that energy 0
## must NOT end a wave once real waves exist, so this has to be turned off in Phase 1.
@export var end_run_when_energy_depleted: bool = true
```

- 소비처는 `_on_energy_depleted()` 단 한 곳. 플래그를 false 로 두면 `_fail_run()` 이
  호출되지 않는다.
- 진짜 경로인 `RunState.damage_core()` → `core_hp <= 0` → `end_run()` 은 **이미 구현돼 있고**
  `core_hp_changed` 로 HUD 게이지까지 연결돼 있다. P1 은 코어를 깎는 주체만 붙이면 된다.
- `@export` 라 Inspector 에서 끌 수 있다(§46).

**결함 #4 (MEDIUM)**: 결과 화면 부제가 `문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다.`
인데, 같은 화면 HUD 는 `문장핵 20 / 20` 을 그대로 표시한다(`flow/03_run_result.png`).
플레이어가 보기에 화면이 자기모순이다. P1 에서 실패 조건을 문장핵으로 옮기면 저절로
해소되지만, 그때까지는 부제를 실제 원인에 맞추거나 P0 임시 문구임을 밝히는 편이 낫다.

### C-11. 결과 화면 표시 — PASS

```
RUN 종료
도달 WAVE  1
처치  6
획득 GOLD  12 G  (유지됨)
GOLD · 단어 도감 · 숙련도 · 보스 기록 · 최고 WAVE 는 그대로 남는다.
신규 단어 / 숙련 상승 / 합성어 / 보스 정산은 이후 Phase 에서 추가된다.
[메인 허브로]
```

도달 Wave / 획득 Gold 모두 표시된다. "(유지됨)" 과 아래 두 줄이 §14 의 "패배해도 Gold 를
빼앗지 않는다" 를 화면에서 명시한다. 미구현 항목을 빈칸으로 두지 않고 어느 Phase 소관인지
적어 둔 점도 적절하다.

---

## D. 세이브 (§45)

### D-12. v0.3 세이브 마이그레이션 — 기능 PASS / 안내문 HIGH

실제 v0.3 파일을 만들어 게임을 띄웠다.

```json
{"save_version":1,"day":42,"gold":1234.5,"upgrade_levels":{"click_damage":3},
 "unlocked_words":["fire_001"],"jamo_inventory":{"ㅂ":2},"target_word":"fire_002"}
```

| 확인 항목 | 결과 |
|---|---|
| (a) 크래시 없음 | **PASS** — 에러 0, 허브 정상 진입 |
| (b) Gold 보존 | **PASS** — `GOLD 1234 G`, 업그레이드 `클릭 피해 Lv.3`, 도감 `1 / 10` |
| (c) 원본 `legacy_v03` 보존 | **PASS** — 재작성 파일 키 `["audio","legacy_v03","meta","save_version"]`, `legacy_v03.day == 42`, v0.4 에 쓸모없는 `target_word == "fire_002"` 까지 통째로 남음 |
| (d) 허브 안내문 | **표시됨 — 단, 판독 불가 (결함 #1 HIGH)** |
| 추가 | `최고 WAVE 1` — Day 42 를 Wave 42 로 주지 않음. `RUN 이어하기` 없음. 재기동 시 재마이그레이션 없음 |

#### 결함 #1 (HIGH) — 마이그레이션 안내문 명도 대비 1.04:1

- **재현**: `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 에 위 v0.3 페이로드를 넣고
  게임 실행 → 우상단 `영구 성장` 패널 하단을 본다.
- **기대**: 안내문을 읽을 수 있다. WCAG AA (본문 4.5:1) 충족.
- **실제**: 노란 글자(휘도 0.824)가 크림색 패널(휘도 0.745~0.787) 위에 그려져
  **대비 1.04:1**. 사실상 배경과 같은 밝기라 읽히지 않는다.
- **측정**: `tests/qa_p0_flow.tscn` 출력
  `notice contrast: text=0.824 background 0.745..0.787 worst=1.04:1`
- **캡처**: `flow/09_hub_v03_migrated.png`
- **레이아웃은 정상**: 글자 rect `P(910,169.4) S(336,39)`, 패널이 그리는 크림 배경은
  y=213 까지 → **패널 밖으로 넘치지는 않는다.** 순수하게 색상 문제다.
- **왜 HIGH 인가**: 이 문장이 "당신의 v0.3 진행도는 버려지지 않았다" 를 알리는 **유일한**
  수단이다. 읽히지 않으면 사용자는 Day 42 기록이 증발했다고 판단한다. 프로젝트 규칙
  (WCAG AA 필수, 색만으로 정보 전달 금지) 위반이기도 하다.
- **권고**: 패널 배경 대비 어두운 색(예: 경고용 짙은 갈색/적갈색)으로 바꾸거나,
  안내문 뒤에 별도 강조 배경을 깐다.

DEV 인계문 절차 12번은 "안내문이 뜨는지" 만 요구하고 실제로 뜨므로 이번 FAIL 사유로는
잡지 않았다. 그러나 P1 착수 전 수정을 권고한다.

### D-13. MetaState 영구 / RunState 임시 — PASS

- `save_meta()` — 영구만 기록, 디스크의 `run` 블록은 건드리지 않음
- `save_run()` — `RunState.is_active` 일 때만 `run` 기록, 아니면 `run` 키 삭제
- `clear_run()` — `run` 만 삭제, 영구 전부 유지
- 강제 종료 대비: `main.gd::_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → `save_run()`
- 패배 후 이어하기 불가는 A-4 에서 3중 확인

### D-14. `id / level / value` 기반 저장 — PASS

RUN 시작 직후 실제 파일 (`tests/qa_artifacts/p0/save_after_run_start.json`):

```json
{
  "audio": {"bgm":1.0,"master":1.0,"sfx":1.0},
  "meta": {"codex_mastery_exp":{}, "codex_mastery_levels":{}, "codex_words":[],
           "defeated_word_bosses":[], "discovered_compounds":[], "discovered_synergies":[],
           "gold":0.0, "highest_wave":1, "permanent_upgrade_levels":{},
           "statistics":{"runs_started":1.0}},
  "run":  {"active_compounds":[], "active_synergies":[], "core_hp":20.0, "core_max_hp":20.0,
           "current_energy":20, "current_slot_jamo":[], "current_wave":1, "equipped_words":[],
           "jamo_discard_bag":[], "jamo_draw_bag":[], "locks":[], "rerolls":0,
           "risk_words":[], "run_modifiers":{}, "run_statistics":{}, "run_word_ranks":{}},
  "save_version": 2
}
```

- `res://` 경로가 단 한 개도 없다 (하네스가 두 블록의 모든 값을 훑어 단언한다).
- `meta` 안에 런 필드 0개, `run` 안에 영구 필드 0개 — 매 단계마다 자동 검사.
- 단어는 `equipped_words` 의 id 배열, 업그레이드는 `permanent_upgrade_levels` 의 id→level.

---

## E. Main Hub (§27)

### E-15. 메뉴 5종 — PASS, 자리표시 양호

세이브 없음: `RUN 시작 / 영구 업그레이드 / 단어 도감 / 기록 / 설정 / 종료` (6행).
세이브 있음: `RUN 시작 / RUN 이어하기 (+ 상태줄) / 영구 업그레이드 / 단어 도감 / 기록 /
설정 / 종료` (7행 + 라벨 1행).

- **영구 업그레이드**: 실제 상점이 열린다. `Day N 필요` 문구 0건(라벨 전수 스캔으로 자동 확인).
  `리롤 Lv.0 · 125 G` 가 Day 게이트 없이 처음부터 보이고, `치명 클릭` 은
  `클릭 피해 Lv.3 필요` 로만 잠긴다.
- **단어 도감**: 빈 화면 아님. `아직 등록된 단어가 없다.` +
  `단어 목록 · 숙련도 · 합성/시너지 힌트는 P4 단어 도감에서 채워진다.`
- **기록**: `최고 WAVE 1 · 발견 단어 0 / 10 · 처치 보스 0` + 이후 Phase 안내.
- **설정**: 전체 화면 토글 + 마스터/음악/효과음 슬라이더 동작. 닫으면 포커스가 허브로 복귀.

**고장으로 오해할 여지 없음.** 두 자리표시 모두 "무엇이 언제 채워지는지" 를 명시한다.
자리표시 문구는 `PlaceholderPanel` 의 `@export title_text / body_text` 라 Inspector 에서
편집 가능하고, 하나의 씬을 두 번 인스턴스해 쓴다(§46 부합).

### E-16. 성장 수치 4종 — PASS

`영구 성장` 패널: `GOLD 0 G` / `최고 WAVE 1` / `발견 단어 0 / 10` / `처치 보스 0`.
전부 `MetaState` 에서만 읽는다. 마이그레이션 후 `GOLD 1234 G` / `발견 단어 1 / 10` 로 갱신됨을
실제로 확인했다.

### E-17. F7~F9 확정 사항 — 전부 유지 (PASS)

DEV 가 넘긴 창 모드 하네스 10종은 **1회차 전부 exit 0, FAIL 0건**
(`qa_f9_verify_real_input` 재실행 불필요).

그런데 **결함 #2 (MEDIUM)** 를 발견했다: 그 10종은 노드 이름을
`NewGameButton / ContinueButton / SettingsButton / QuitButton` 4개로 하드코딩하고 있어,
P0 에서 새로 생긴 `UpgradeButton / CodexButton / RecordsButton` 을 **한 번도 보지 않는다.**
즉 `bright_plates=1` 은 7개 중 4개만 세고 나온 값이었다. 신규 3행에 두 번째 밝은 판때기가
생겨도 통과했을 것이다. (`tests/qa_f7_art.gd:99`, `qa_f8_labels.gd:26`,
`qa_f8_focus_all.gd:67`, `qa_f8_hover_focus.gd:81`, `qa_f9_verify_real_input.gd:138`)

이 구멍을 QA 하네스 `tests/qa_p0_plates_all.tscn` (신규) 로 메워 **7개 판때기 전수**로
재측정했다. 결과:

| 확정 사항 | 측정 결과 |
|---|---|
| 선택된 버튼만 밝은 판때기 (강조 항상 1개) | **74쌍 전부 `bright=1`**, 그리고 항상 키보드 쪽 판때기 |
| 포커스 사각 박스 없음 | 없음 — 선택 표현은 `normal` 스타일박스 교체뿐 (`flow/01`, `flow/06`) |
| 마우스 호버 우선 | 호버가 포커스를 가져가고, 키보드로 걸어 나가면 남겨진 판때기는 즉시 어두워진다. 신규 3버튼 포함 전 조합 확인 |
| 버튼 크기가 화면 비율 기준 | 1280x720 에서 371x49 (뷰포트 높이의 6.8%), 창 확대·축소에 따라 화면 픽셀이 297x39 → 557x74 로 변한다 |
| 세이브 유무로 크기 불변 | 4해상도 전부 `nosave=49.0 save=49.0` |
| 4해상도 레이아웃 | 1280x720 / 1920x1080 / 720x1280 / 2560x1080 전부 뷰포트 안, 열 정렬·간격 균일 (`plates/*.png`) |
| 판때기 명도 대비 ≥ 3.0:1 | 최저 **3.84:1** (선택 0.914~0.918 vs 평상 0.200) |
| 타이틀 외 화면의 포커스 테두리 유지 | 상점 `닫기`, 일시정지 `계속하기`, 설정 `닫기` 모두 테두리 유지 (`flow/05_pause_menu.png`, `flow/10_shop_after_migration.png`) |

```
OK - one bright plate across all 7 hub plates, 74 pointer/keyboard pairs.
```

권고: DEV 가 기존 5개 하네스의 버튼 목록을 7개로 넓히거나 `qa_p0_plates_all` 을 회귀에 편입할 것.
Phase 마다 허브 메뉴가 늘어나면 같은 구멍이 반복된다.

---

## F. WordData 마이그레이션 (§21)

### F-18. 10개 전부 v0.4 스키마 — PASS

`scripts/data/word_data.gd` 는 `@tool class_name WordData` 이고 §21 권장 필드를
`slot_type` / `tags` / `run_max_rank` / `rank_effect_values` / `compound_recipe_ids` /
`synergy_ids` / `is_risk_word` / `risk_effect_ids` / `codex_mastery_curve` /
`codex_hidden_before_discovery` / `unlock_condition` / `required_boss_id` /
`icon` / `vfx_id` / `sfx_id` 로 모두 갖췄다.
`Risk` / `Codex` / `Unlock` / `Presentation` `@export_group` 으로 Inspector 에서 분류돼 보인다.

10개 실측:

| 파일 | slot_type | tags | run_max_rank |
|---|---|---|---|
| him (힘) | 0 EQUIPMENT | weapon, power | 3 |
| gangta (강타) | 0 EQUIPMENT | weapon, power | 3 |
| bap (밥) | 0 EQUIPMENT | sustain | 3 |
| chelyeok (체력) | 0 EQUIPMENT | sustain | 3 |
| bul (불) | 2 SPECIAL | fire | 3 |
| hwayeom (화염) | 1 RELIC | fire | 3 |
| bulkkot (불꽃) | 1 RELIC | fire | 3 |
| don (돈) | 1 RELIC | economy | 3 |
| geum (금) | 1 RELIC | economy, luck | 3 |
| un (운) | 1 RELIC | luck | 3 |

전부 `is_risk_word = false`, `codex_mastery_curve` 채워짐, `rank_effect_values` 채워짐.

`base_effect_ids` 를 `base_effects: Array[WordEffectData]` 로 바꾼 §21 이탈은 **타당**하다.
§21 은 "권장 필드" 이고, id 룩업 테이블을 새로 만들면 §46 의 "데이터는 Inspector 에서 보이는
.tres" 원칙과 정면으로 충돌한다. 판단 근거가 `word_data.gd` 헤더 주석에 남아 있다.
소비처가 없는 `risk_effect_ids` 는 §21 대로 StringName 배열로 둔 것도 일관적이다.

### F-19. `prerequisites` 처리 — 타당 (PASS)

- 필드 자체가 삭제됐고, 프로젝트 전체에 잔존 참조 0건 (주석 1줄 제외).
- 대체 필드: `unlock_condition`(조건 id) / `required_boss_id`(§20 보스 해금) /
  `compound_recipe_ids`(§22 합성어).
- **v0.4 에 선행 단어 개념이 없다는 판단이 문서와 일치한다.** §21 필드 목록에도
  `prerequisites` 가 없고, §22/§20 이 그 자리를 대신한다.
- 실효: 강타/화염/불꽃/금/체력의 선행 관계가 사라져 첫 RUN 부터 후보에 오를 수 있다.
  P2 단어 후보 로직에서 밸런스로 다뤄야 하는 사안이며 P0 결함은 아니다.
- `category` → `tags` 이관, `tier` 삭제도 §21 과 일치한다.

---

## G. 보류 처리 (§46, 규칙 7절)

### G-20. 삭제 0건 — PASS

- `_deprecated_v03/` : Day 결산 / 자모 선택 / 자모 카드 / 단어 트리 / CandidateGenerator
  (씬·스크립트·.uid 동반). `README.md` 에 파일별 "v0.3 역할 / v0.4 처분 / 되살아나는 시점"
  표가 있다.
- `tests/_deferred_v03/` : 17개 파일군. `README.md` 에 파일별
  "무엇을 검증했나 / 왜 지금 못 고치나 / 되살릴 Phase" 표가 있다
  (P1/P2/P2·P3/P4/P5/P11/P12 및 "되살릴 Phase 없음" 까지 명시).
- 두 폴더 모두 빈 `.gdignore` 존재.
- `git status` 상 전부 `R`(rename) 이며 `D`(delete) 는 `autoload/game_state.gd` 뿐이다
  (MetaState/RunState 로 완전 이관된 것이므로 정상).

### G-21. `.gdignore` 실동작 — PASS (강한 증거)

`godot --headless --editor --quit --path .` 로 프로젝트 전체를 **재스캔**한 뒤
`.godot/editor/filesystem_cache10` 을 검사했다.

```
_deferred_v03 / _deprecated_v03 항목 수 : 0
qa_f7_art (살아 있는 테스트) 항목 수    : 3
```

즉 재스캔 후에도 보류 폴더는 파일시스템에 등록되지 않는다.
보류 씬을 강제로 실행하면 스크립트를 찾지 못하고 로드에 실패한다(= 로드되지 않았다는 증거).

**결함 #8 (INFO)**: 보류 `.tscn` 의 `ext_resource` 경로가 이동 전 경로
(`res://tests/test_day_flow.gd`) 그대로다. `.gdignore` 때문에 Godot 이 경로를 고쳐 주지
않았기 때문이다. 되살릴 때 `.gdignore` 제거만으로는 안 되고 경로도 함께 고쳐야 한다.
또 그 상태로 실행하면 종료하지 않고 매달린다. 각 README 에 한 줄 적어 두면 좋다.

### G-22. `qa_f7_art` 겹침 오탐 수정 검토 — 결함을 가리지 않는다 (PASS)

수정 내용은 `control.is_visible_in_tree()` 가 false 인 노드를 뷰포트/겹침 검사에서
건너뛰는 것이다.

- 숨은 Control 은 마지막 레이아웃 당시의 rect 를 그대로 들고 있으므로, 화면에 아무것도
  그려지지 않는데 겹침으로 잡히는 것이 맞다. **오탐이 맞다.**
- **가리지 않는다는 증거**: 로그에서 `shown=false` 는 `nosave_*` 5케이스의
  `ContinueButton` / `ContinueInfoLabel` 에만 붙는다. `RUN 이어하기` 가 실제로 보이는
  `save_*` 5케이스에서는 두 노드 모두 검사 대상에 남아 겹침·뷰포트 검사를 전부 통과한다.
- 로그가 `shown=` 을 항상 출력하므로 "왜 건너뛰었는지" 가 사람 눈에 남는다.
- F9 QA 가 지적했던 "숨은 노드 rect 로 인한 오탐" 은 해소됐고, 실제 결함 경로는 그대로다.

다만 이 하네스는 "보여야 할 버튼이 실제로 보이는가" 를 단언하지는 않는다.
`save_*` 케이스에서 `ContinueButton.shown == true` 를 단언해 두면 스킵 로직이
장래에 진짜 결함을 삼키는 것을 막을 수 있다(권고, 결함 아님).

---

## H. 자동 테스트

### H-23. 정적 — PASS

```
godot --headless --path . --quit   → exit 0, ERROR 2줄
  ERROR: Resource file not found: res://art/fonts/NotoSansKR-Regular.ttf
  ERROR: Error loading custom project font '...'
```

폰트 누락 외 에러 0. `ORCHESTRATION_RULES` §7.1 이 기존 이슈로 명시한 항목이다.

참고: 에디터에서 실행하면 `signal_bus.gd` 의 signal 12개에 대해
`The signal "..." is declared but never explicitly used in the class` 경고가 뜬다.
이는 autoload signal hub 의 구조상 발생하는 것으로 **P0 이전부터 동일**했고
(HEAD 의 `signal_bus.gd` 도 같은 형태), 헤드리스 `--quit` 에서는 나오지 않는다.
규칙 §4.1 의 "경고 없음" 을 엄격히 보면 걸리지만 신규 회귀는 아니다.

### H-24. 신규 헤드리스 테스트 — PASS

```
godot --headless --path . res://tests/test_state_split.tscn
  exit 0   OK - meta/run split holds.
godot --headless --path . res://tests/test_run_flow.tscn
  exit 0   OK - Wave 1 started, the run failed, and the hub came back.
```

두 테스트 모두 negative control 로 실효성을 확인했다(A-5). 다만 겹침 검사의 한계는 결함 #3.

**결함 #6 (LOW)**: `tests/test_state_split.gd.uid` / `tests/test_run_flow.gd.uid` 가
untracked 다. 다른 모든 `.gd` 는 `.uid` 가 함께 커밋돼 있으므로 커밋 범위에 넣어야 한다.

### H-25. 창 모드 하네스 — PASS (10/10, 1회차)

`godot --path . res://tests/<x>.tscn` (창 모드). 전부 exit 0, `FAIL` 0건,
`bright_plates=1` 아닌 행 0건.

```
qa_f7_title exit=0      qa_f8_labels exit=0      qa_f8_focus exit=0
qa_f8_focus_all exit=0  qa_f8_hover_focus exit=0 qa_f8_resize exit=0
qa_f9_hover_focus exit=0 qa_f7_art exit=0        qa_f8_title_shots exit=0
qa_f9_verify_real_input exit=0   ← 1회차 통과, 재실행 불필요
```

QA 추가 하네스 2종도 통과:

```
qa_p0_plates_all  exit=0  OK - one bright plate across all 7 hub plates, 74 pairs.
qa_p0_flow        (결함 #1 을 검출해 exit 1 — 안내문 대비 1.04:1. 그 외 전 항목 통과)
```

로그: `tests/qa_artifacts/p0/harness/*.log`

---

## 에디터 가시성 (§46, 규칙 4절 4번)

같은 ziva-godot 세션에서 Godot Editor 로 직접 열어 확인했다.

- `scenes/ui/title_screen.tscn` — 버튼 7개(`NewGameButton / ContinueButton /
  UpgradeButton / CodexButton / RecordsButton / SettingsButton / QuitButton`),
  `GrowthPanel` 하위 라벨 전부, `MigrationNoteLabel` 이 노드로 보인다.
  `Settings` / `UpgradeShop` / `Codex` / `Records` 는 인스턴스로 붙어 있고
  `Codex` / `Records` 는 `title_text` / `body_text` 를 `.tscn` 에서 오버라이드한다.
  **Configuration warning 0건.**
- `scenes/ui/run_result.tscn` — 라벨 6개 + 버튼 1개 전부 노드. **warning 0건.**
- `resources/words/*.tres` / `resources/balance/game_balance.tres` —
  `@export_group` 으로 `Wave / Energy`, `Run`, `Risk`, `Codex`, `Unlock`,
  `Presentation` 그룹이 정의돼 있고 `base_core_hp = 20.0`,
  `hp_growth_per_wave = 1.035` 값이 `.tres` 텍스트에 그대로 들어 있다.
- GDScript 로 UI 를 만들어 내는 코드 없음, 단어/업그레이드/밸런스 하드코딩 없음.

---

## DEV 주의사항 22개 전수 확인

| # | DEV 주장 | QA 확인 |
|---|---|---|
| 1 | Wave 곡선은 Day 곡선 1:1 임시 매핑 | **사실.** `.tres` 값 확인, TEMPORARY 주석 확인. 결함 #7 로 기록 |
| 2 | `base_core_hp = 20` 은 근거 없는 임시값 | 사실. `.tres` 20.0, P1/P5 소관 |
| 3 | RUN 실패 = 에너지 0 (임시), P1 에서 끌 것 | 사실. 플래그 분리·Inspector 노출 확인. 결함 #4 동반 |
| 4 | Wave 2 경로 없음, `advance_wave()` 호출부 없음 | 사실. 정의 1건, 호출 0건 |
| 5 | `base_effects` 를 Resource 참조로 구현 | 타당. §46 과의 충돌 회피가 근거로 성립 (F-18) |
| 6 | `prerequisites` 제거, 대체 필드 도입 | 타당. v0.4 에 선행 개념 없음 (F-19) |
| 7 | 씬 경로를 `title_screen.tscn` 로 유지 | 타당. 옮기면 F7~F9 10종이 전부 깨진다. §43 이탈이므로 씬 재편 Phase 에 남길 것 |
| 8 | `required_word` 를 "도감 등록 필요" 로 재해석 | 확인. 현재 사용하는 `.tres` 0개라 실효 없음 |
| 9 | `monster_capacity` / `critical_click` 유지 | 확인. §13 P5 목록과 다르지만 정리는 P5 범위 |
| 10 | Day → `highest_wave` 매핑 안 함 | 확인. `highest_wave 1`, `statistics.migrated_from_v03_day = 42` |
| 11 | 원본을 `legacy_v03` 에 보존 + 안내문 | 보존 확인. **안내문은 뜨지만 읽히지 않는다 → 결함 #1** |
| 12 | Day 기반 업그레이드 해금 제거됨 | 확인. 상점 라벨 전수 스캔 `DAY` 0건, `리롤` 처음부터 구매 가능 |
| 13 | 삭제한 테스트 0개, 17개 보류 + README | 확인 (G-20) |
| 14 | `qa_f5_*` 3종 State 이름만 이식 | 확인. 장시간 관찰 하네스라 이번 회귀 세트에서는 제외 |
| 15 | 픽스처만 고친 테스트 3종 | 확인. `qa_f7_art` 오탐 수정은 결함을 가리지 않음 (G-22) |
| 16 | 신규 테스트 2종 통과 | 확인 + negative control 로 실효성 검증 (A-5). 겹침 검사 한계는 결함 #3 |
| 17 | `qa_f9_verify_real_input` 플레이크 | 이번 실행에서는 1회차 통과. 재실행 불필요했다 |
| 18 | 폰트 누락은 기존 이슈 | 확인 |
| 19 | `qa_f7/f8/f9` 는 헤드리스에서 멈춤 | 확인. 창 모드로 전부 실행함 |
| 20 | 규칙 §4 검증항목 5번이 성립하지 않음 | 확인. §7.1 대체 경로대로 검증했다. **§4 본문은 이미 "Main Hub → … → Main Hub" 로 갱신돼 있다** (총지휘자 조치 완료) |
| 21 | `word_complete` 는 남았지만 인스턴스 없음 | 확인. 휴면 상태이며 P0 결함 아님 |
| 22 | `art/Untitled.blend*` untracked, 손대지 않음 | 확인. 여전히 untracked, QA 도 손대지 않았다 |

---

## 세이브 파일 원복

- 세션 시작 시점: `%APPDATA%\Godot\app_userdata\JAMO\` 에 **`jamo_save.json` 없음**,
  `jamo_save.json.qabak` 만 존재.
- QA 중 조작: 폴더 전체를 스크래치에 백업 → 하네스들이 자체 stash/restore 로 임시 세이브
  생성·복원 → 검증용으로 RUN 을 시작해 실제 세이브 1개 생성(사본을
  `tests/qa_artifacts/p0/save_after_run_start.json` 에 증거로 보관).
- **원복 완료**: QA 가 만든 `jamo_save.json` 을 삭제했다. 현재 폴더 상태는
  `jamo_save.json.qabak` 만 남은 **세션 시작 시점과 동일**하다.
- negative control 은 프로젝트를 스크래치에 복제하고 `config/name` 을 `JAMO_QA_NEG` 로
  바꿔 **user 데이터 폴더까지 분리**해 돌렸다. 프로덕션 세이브에 닿지 않았다.

## QA 가 추가한 파일 (프로덕션 코드 무수정)

```
tests/qa_p0_plates_all.gd / .tscn   허브 7개 판때기 전수 F7~F9 규칙 재측정
tests/qa_p0_flow.gd / .tscn         실입력 전체 경로 + 세이브 블록 + v0.3 마이그레이션
tests/qa_artifacts/p0/flow/*.png    단계별 스크린샷 10장
tests/qa_artifacts/p0/plates/*.png  4해상도 + 74쌍 판때기 캡처
tests/qa_artifacts/p0/harness/*.log 창 모드 하네스 12종 로그
tests/qa_artifacts/p0/h0*.log       헤드리스 3종 로그
tests/qa_artifacts/p0/save_after_run_start.json  세이브 형식 증거
tests/qa_artifacts/p0/QA_REPORT.md  이 문서
```

`autoload/`, `scripts/`, `scenes/`, `resources/`, `project.godot` 는 **한 글자도 고치지 않았다.**

---

## 권고 (우선순위 순)

1. **결함 #1 (HIGH)** — 마이그레이션 안내문 색을 패널 대비 4.5:1 이상으로. P1 착수 전.
2. **결함 #2 (MEDIUM)** — F7~F9 하네스의 버튼 목록을 허브 전 버튼으로 넓히거나
   `qa_p0_plates_all` 을 회귀 세트에 편입. 허브 메뉴는 Phase 마다 늘어난다.
3. **결함 #3 (MEDIUM)** — `test_state_split` 에 "상수 목록 == 실제 프로퍼티 집합" 단언 추가.
   P1 에서 `RunState` 필드가 늘어날 때 실제로 위험하다.
4. **결함 #4 (MEDIUM)** — 결과 화면 부제를 실제 실패 원인과 맞추거나 P0 임시임을 밝힐 것.
5. **결함 #7 (INFO)** — Wave 곡선 재산출을 P1/P12 로 넘긴다는 총지휘자 승인을 명시적으로 남길 것
   (`ORCHESTRATION_RULES` §7 문언과 충돌).
6. 결함 #5 / #6 / #8 은 다음 사이클에 묶어서 처리.
