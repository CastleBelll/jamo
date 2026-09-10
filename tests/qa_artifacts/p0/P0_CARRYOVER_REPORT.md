# JAMO P0 이월 정리 — DEV 보고

대상: QA 리포트 결함 #1 (HIGH) / #2 / #3 / #4 (MEDIUM). P1 범위(문장핵, Wave 전투)는 손대지 않았다.

---

## 1) 변경 파일 목록

### 신규
```
tests/hub_plates.gd (+ .uid)   허브 판때기 목록을 씬에서 뽑는 공용 헬퍼
```

### 삭제 (허브 판때기 규칙을 4개 버튼으로만 다시 보던 하네스 — 전부 qa_p0_plates_all 로 흡수)
```
tests/qa_f8_hover_focus.gd / .tscn / .gd.uid
tests/qa_f9_hover_focus.gd / .tscn / .gd.uid
tests/qa_f9_verify_real_input.gd / .tscn / .gd.uid
tests/qa_f8_title_shots.gd / .tscn / .gd.uid
```

### 수정
```
theme/jamo_theme.tres            NoticeLabel 타입 변형 신설 (결함 #1)
scenes/ui/title_screen.tscn      MigrationNoteLabel 인라인 색/크기 오버라이드 제거,
                                 theme_type_variation = &"NoticeLabel"
scenes/ui/run_result.tscn        SubtitleLabel 문구 교체 (결함 #4)
scripts/ui/run_result.gd         PHASE 1 REVERT POINT 주석 (결함 #4)
autoload/meta_state.gd           NON_STATE_NAMES 선언 (결함 #3)
autoload/run_state.gd            NON_STATE_NAMES 선언 (결함 #3)
tests/test_state_split.gd        겹침 검사를 이름 denylist → 구조 검증으로 교체 (결함 #3)
tests/qa_p0_flow.gd              안내문 대비를 실제 렌더 픽셀 + WCAG 상대휘도로 측정 (결함 #1)
tests/qa_p0_plates_all.gd        판때기 목록 씬 유래화, "포커스 없음 = 0개" 케이스 추가 (결함 #2)
tests/qa_f7_art.gd               판때기 목록 씬 유래화
tests/qa_f7_title.gd             키보드 도달 검사를 전 판때기로
tests/qa_f8_labels.gd            판때기 목록 씬 유래화
tests/qa_f8_focus_all.gd         판때기 목록 씬 유래화
docs/DEV_ROADMAP.md              P0 이월 4건 완료 처리 + P1 되돌릴 지점
docs/ORCHESTRATION_RULES.md      §7.1 하네스 목록 갱신
```

`art/Untitled.blend*` 는 이전 세션부터 untracked 인 무관 파일이다. 손대지 않았다.
git index 는 비워 뒀다 — 커밋 범위는 총지휘자가 결정.

---

## 2) 검수 절차

### A. 자동 검증

1. `godot --headless --path . --quit`
   → **기대**: `NotoSansKR-Regular.ttf` 누락 에러 2줄만. 그 외 에러 0. exit 0.
2. `godot --headless --path . res://tests/test_state_split.tscn`
   → **기대**: exit 0. 마지막 줄 `OK - meta/run split holds.`
     중간에 `MetaState 10 state fields, RunState 16` 이 찍힌다.
3. `godot --headless --path . res://tests/test_run_flow.tscn`
   → **기대**: exit 0. `OK - Wave 1 started, the run failed, and the hub came back.`
4. 창 모드 하네스 7종 (**헤드리스 금지**):
   ```
   godot --path . res://tests/qa_p0_plates_all.tscn
   godot --path . res://tests/qa_p0_flow.tscn
   godot --path . res://tests/qa_f7_title.tscn
   godot --path . res://tests/qa_f7_art.tscn
   godot --path . res://tests/qa_f8_labels.tscn
   godot --path . res://tests/qa_f8_focus_all.tscn
   godot --path . res://tests/qa_f8_resize.tscn
   ```
   → **기대**: 전부 exit 0, `FAIL` 0건.
   삭제된 `qa_f8_hover_focus` / `qa_f9_hover_focus` / `qa_f9_verify_real_input` /
   `qa_f8_title_shots` 는 더 이상 없다. 없다고 FAIL 로 세지 말 것.

### B. 결함 #1 — 안내문 대비를 **실제 렌더 픽셀로** 측정

5. 게임을 끄고 `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 을 아래로 덮어쓴다.
   ```json
   {"save_version":1,"day":42,"gold":1234.5,"upgrade_levels":{"click_damage":3},
    "unlocked_words":["fire_001"],"jamo_inventory":{"ㅂ":2},"target_word":"fire_002"}
   ```
6. `godot --path .` 로 실행하고 우상단 `영구 성장` 패널 하단을 본다.
   → **기대**: 크림 패널 위에 **짙은 적갈색** 안내문이 또렷하게 읽힌다.
     `v0.3 세이브를 불러왔다. GOLD·업그레이드·단어는 유지, DAY 기록은 WAVE 로 옮길 수 없어 제외됐다.`
     GOLD 는 `1234 G`, 발견 단어 `1 / 10`, 최고 WAVE 는 `1`.
7. 측정: `godot --path . res://tests/qa_p0_flow.tscn` 을 돌리고 로그에서
   `notice contrast:` 줄을 찾는다. (이 하네스는 세이브를 스스로 백업/복원한다.)
   → **기대**: 아래 형태의 줄이 나오고 비율이 **4.5:1 이상**.
   ```
   notice contrast: ink=(0.2784, 0.0745, 0.0431, 1.0) L=0.0183
                    behind=(0.949, 0.902, 0.8078, 1.0) L=0.7993 -> 12.44:1 (13776 px)
   ```
   - `ink` / `behind` 는 **화면에서 읽은 픽셀**이다 (선언 색이 아니다).
     `L` 은 WCAG 2.x 상대휘도(sRGB 역감마 적용). 이전 측정값 1.04:1 → **12.44:1**.
   - `behind` 가 크림 아웃라인 색이라는 것이 **배경 비의존**의 증거다. 안내문은
     반투명 패널 위에 있고 그 뒤는 타이틀 사진인데, 글자 둘레에 크림 아웃라인 6px 이
     깔려 있어 사진이 무엇이든 대비가 변하지 않는다 (F8 `ContinueInfoLabel` 과 같은 방식).
   - 하네스는 추가로 "가장 어두운 픽셀 == 테마 `font_color`" 도 단언한다. 배경 어딘가의
     어두운 픽셀로 비율을 벌 수 없게 막는 장치다.
8. 스크린샷: `tests/qa_artifacts/p0/flow/09_hub_v03_migrated.png` (7번이 갱신한다).
9. 판때기/포커스 규칙이 안 깨졌는지: 4번의 창 모드 7종이 전부 통과해야 한다.
   특히 `qa_p0_plates_all` 이 `bright=1` 74쌍 + 대비 >= 3.0:1 을 유지해야 한다.

### C. 결함 #2 — 허브 판때기 하네스

10. `godot --path . res://tests/qa_p0_plates_all.tscn`
    → **기대**: 첫 줄에
      `hub plates: NewGameButton, ContinueButton, UpgradeButton, CodexButton, RecordsButton, SettingsButton, QuitButton`
      마지막 줄 `OK - one bright plate across all 7 hub plates, 74 pointer/keyboard pairs.`
      중간에 `--- nosave nothing focused: bright=[]` 가 나온다(신규 케이스).
11. `godot --path . res://tests/qa_f7_title.tscn` 로그의 `keyboard reachable:` 줄
    → **기대**: `NewGameButton, UpgradeButton, CodexButton, RecordsButton, SettingsButton, QuitButton`
      (6개. `ContinueButton` 은 세이브 없을 때 포커스 체인에서 빠져야 하므로 없어야 정상.)
12. `godot --path . res://tests/qa_f8_focus_all.tscn` 로그
    → **기대**: `--- 1280x720 <버튼> changed=... median=...:1` 행이 **7개 버튼 전부** 나온다
      (`ContinueButton` 만 `SKIPPED (no save)`). 이전에는 4개만 나왔다.
13. **하네스가 실제로 7개를 보는지 부정 대조** (선택):
    `scenes/ui/title_screen.tscn` 의 `CodexButton` 노드 이름을 `CodexButtonX` 로 바꿔도
    10~12 가 그대로 통과해야 한다(목록이 이름 하드코딩이 아니라는 증거). 확인 후 되돌릴 것.

### D. 결함 #3 — `test_state_split` negative control (동어반복 아님을 증명)

14. 기준선: `godot --headless --path . res://tests/test_state_split.tscn`
    → **기대**: exit 0, `OK - meta/run split holds.`
15. **NC3 재주입** (이전에 놓쳤던 결함). `autoload/meta_state.gd` 의 `var gold: float = 0.0`
    바로 아래에 두 줄을 넣는다.
    ```gdscript
    var stage_index: int = 0
    var core_shield: float = 0.0
    ```
    다시 14번을 돌린다.
    → **기대**: exit 1, 아래 2건 FAIL. (이전 구현에서는 **PASS 로 통과했다.**)
    ```
    FAIL: MetaState carries the undeclared field stage_index: add it to the ownership list for the state it belongs to (doc v0.4 section 44)
    FAIL: MetaState carries the undeclared field core_shield: add it to the ownership list for the state it belongs to (doc v0.4 section 44)
    ```
    두 줄을 지워 되돌린다.
16. **NC1 재주입** (등록된 이름). 같은 자리에 `var current_wave: int = 1` 을 넣고 14번.
    → **기대**: exit 1.
    ```
    FAIL: MetaState carries the undeclared field current_wave: ...
    FAIL: current_wave is declared on both MetaState and RunState
    ```
    되돌린다.
17. **NC4 재주입** (나머지 7종이 여전히 동작하는지 표본). `autoload/run_state.gd` 의
    `func end_run()` 첫 줄에 `MetaState.gold = 0.0` 을 넣고 14번.
    → **기대**: exit 1, `FAIL: gold survives the defeat`. 되돌린다.
18. NC2 / NC5 / NC6 / NC7 / NC8 은 `_test_failed_run_clears_only_run_state` /
    `_test_run_word_effects_are_not_permanent` / `_test_legacy_v03_save_opens` /
    `_test_failed_run_is_not_resumable` 을 본다. **이 4개 함수는 한 글자도 고치지 않았다.**
    (`git diff tests/test_state_split.gd` 로 확인 가능 — 변경은 `_test_no_field_overlap`
    과 새 헬퍼 2개뿐이다.)

### E. 결함 #4 — 결과 화면 문구

19. 세이브를 지우고 게임 실행 → `RUN 시작` → 에너지를 0까지 전부 쓴다.
    → **기대**: 결과 화면 부제가
      **`에너지가 바닥나 RUN 이 끝났다. 다음 RUN 은 WAVE 1 부터 시작한다.`**
      HUD 의 `문장핵 20 / 20` 과 모순되지 않는다. `문장핵이 무너졌다` 문구는 없다.
20. 나머지 줄(`도달 WAVE` / `처치` / `획득 GOLD … (유지됨)`)은 그대로다.

---

## 3) 주의 / 보류 사항

### P1 에서 되돌릴 지점

1. **결과 화면 부제** — `scenes/ui/run_result.tscn` 의 `SubtitleLabel`.
   되돌릴 지점은 `scripts/ui/run_result.gd` 헤더의 `PHASE 1 REVERT POINT` 주석과
   `docs/DEV_ROADMAP.md` "P0 에서 P1 으로 넘긴 임시 처리" 절에 둘 다 적어 뒀다.
   P1 에서 `Main.end_run_when_energy_depleted` 를 끄고 문장핵이 실패 주체가 되면
   `"문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다."` 로 되돌린다.
   **문장핵 자체는 구현하지 않았다.**

### 판단이 갈릴 수 있는 것

2. **하네스는 "QA 것으로 대체" 를 택했다** (기존 것을 7개로 넓히지 않았다). 이유:
   `qa_f9_verify_real_input` / `qa_f9_hover_focus` / `qa_f8_hover_focus` /
   `qa_f8_title_shots` 의 단언은 전부 `qa_p0_plates_all` 이 이미 하는 것의 부분집합이었다
   (같은 sweep, 같은 4해상도, 같은 판때기 높이 검사, 같은 픽셀 휘도 임계값 — `_measure` /
   `_plate_luma` / `_contrast` 는 코드까지 동일했다). 4개를 7개로 넓히면 같은 단언이
   5벌 남아 "중복 없이 하나로" 가 안 된다. 그래서 4개를 지우고 잃는 것만 흡수했다.
   - `qa_f8_title_shots` 만 있던 **"포커스가 아무 데도 없으면 밝은 판때기 0개"** 케이스는
     `qa_p0_plates_all._measure_nothing_focused()` 로 옮겼다.
   - 잃은 것: `qa_f8_title_shots` 가 4해상도마다 찍던 버튼별 포커스 PNG.
     `qa_p0_plates_all` 은 4해상도 레이아웃 PNG + 1280x720 의 74쌍 PNG 를 찍는다.
     검증 커버리지 손실은 없고 스크린샷 장수만 줄었다.
3. **판때기 목록을 하네스에 적지 않는다.** `tests/hub_plates.gd` 가 허브 씬의
   `Safe/Content/Box` 에서 Button 을 직접 뽑는다. 이번 결함의 근본 원인이 "목록을 손으로
   적어 둔 것" 이라, 목록을 4에서 7로 고치기만 하면 P1 에서 메뉴가 늘 때 같은 구멍이 다시
   생긴다. 대신 목록이 7개 미만이면 **하네스가 FAIL 한다**(`HubPlates.problem()`) —
   유래 로직이 깨져서 조용히 부분집합을 검사하는 상황을 막는다. 허브 행이 실제로 줄어들면
   `hub_plates.gd` 의 `EXPECTED_MINIMUM` 을 고쳐야 한다. 이 숫자 하나가 유일한 하드코딩이다.
4. **`test_state_split` 은 "선언 검증" 방식을 택했다.** 두 State 에 각각
   `NON_STATE_NAMES`(상태가 아닌 프로퍼티: MetaState 는 `database` / `balance` /
   `save_version`, RunState 는 `is_active`)를 선언하게 하고,
   `실제 프로퍼티 집합 − NON_STATE_NAMES == 상대편의 *_OWNED_NAMES` 를 **양방향으로**
   단언한다. 미등록 이름으로 필드를 추가하면 "undeclared field" 로, 목록만 남고 필드가
   사라지면 "declared but has no such property" 로 잡힌다. 교집합 0 도 별도로 단언한다.
   → **P1 에서 `RunState` 에 필드를 추가하면 `MetaState.RUN_OWNED_NAMES` 에도 같이
   적어야 테스트가 통과한다.** 이게 의도다.
5. **`qa_p0_flow` 의 대비 측정을 WCAG 상대휘도로 바꿨다.** 기존 측정은 Godot
   `Color.get_luminance()` (sRGB 값을 역감마 없이 가중합)를 썼는데 이는 WCAG 수치가
   아니다. 새 `_relative_luminance()` 는 sRGB 역감마를 적용한다. 판때기 대비를 재는
   `qa_p0_plates_all` / `qa_f7_art` 의 3.0:1 기준은 **손대지 않았다** — 그 임계값은
   F7~F9 에서 이 측정 방식으로 확정된 값이라, 지금 공식을 바꾸면 확정 사항을 흔든다.
   본문 텍스트 4.5:1 만 정식 WCAG 로 잰다.

### 손대지 않은 것

6. **P1 이후 범위**: 문장핵, Wave 전투 본체, 슬롯 보드 — 전부 미착수.
7. **프로덕션 밸런스 수치**: `resources/balance/*.tres`, `resources/upgrades/*.tres`,
   `resources/words/*.tres` 무수정.
8. **UI 를 GDScript 로 생성하지 않았다.** 안내문 색은 `theme/jamo_theme.tres` 의
   `NoticeLabel` 변형이고, 씬은 `theme_type_variation` 만 가리킨다. 코드에서 만든
   StyleBox / Color 는 없다.
9. **QA 리포트의 LOW #5 / #6 / INFO #7 / #8 은 범위 밖이라 두었다.** (Day 시절 주석 잔존,
   신규 테스트 .uid, Wave 곡선 승인, 기타) — 다만 이번에 만든 `tests/hub_plates.gd.uid` 는
   생성해서 함께 넘긴다.

### 사전 존재 이슈

10. `res://art/fonts/NotoSansKR-Regular.ttf` 누락 — 기존 이슈. P0 이전부터.
11. 창 모드 하네스는 `--headless` 에서 멈춘다 — P0 이전부터. `docs/ORCHESTRATION_RULES.md`
    §7.1 참조(이번에 목록을 갱신했다).
