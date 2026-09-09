# F5 단어 트리 UI — QA 리포트

판정: **FAIL**

일자: 2026-09-09 / 브랜치 `main` / Godot 4.7.stable
검증 수단: ziva-godot MCP 로 실제 Godot 에디터 + 게임 실행(Game 탭) + QA 하네스 3종.

---

## 0. 요약

| 항목 | 결과 |
|---|---|
| A. 정적/자동 테스트 (1~3) | PASS (단, 신규 경고 1건 — LOW) |
| B. S0-1 트리/상단바 겹침 (4~6) | PASS |
| C. S1/S2 계열·선행·상태 4종 (7~11) | PASS |
| D. S3 Target 지정 (12~19) | PASS |
| E. S4 목표 집중 가중치 (20~22) | PASS |
| F. S5 접근성 (23~27) | **FAIL** — 키보드만으로 트리를 **열 수 없음** |
| G. S0-2 큰 ㅁ 아레나 이탈 (28~30) | **FAIL** — 완화됐을 뿐 해소되지 않음 |
| H. 에디터 가시성/회귀 (31~33) | PASS |

**FAIL 2건**

1. **F5-QA-1 (HIGH)** — S5: Day 1 화면에서 Tab 을 12번 눌러도 포커스가 잡히는 컨트롤이
   하나도 없어, 마우스 없이는 트리를 열 수 없다.
2. **F5-QA-2 (HIGH)** — S0-2: 큰 ㅁ 의 몸통이 여전히 종이 슬래브 밖으로 최대 0.70 m
   튀어나온다. arena_margin 은 이탈량을 줄였을 뿐 없애지 못했다.

임시 데이터 변경: **없음.** `[미발견]` / overflow 확인은 `.tres` 를 고치지 않고 **메모리 상의
probe GameDatabase** 로만 수행했고, 하네스가 `database_restored: true` 로 원복을 자체 확인한다.
`arena_margin` A/B 도 실행 중 개체의 in-memory 값만 덮어썼다. 프로덕션 파일 수정 0건
(`git status` 상 QA 가 추가한 것은 `tests/qa_f5_*.gd|tscn` 과 `tests/qa_artifacts/f5/` 뿐).

---

## 1. DEV 인계문 검수 절차 — 번호별 결과

### A. 정적 / 자동

| # | 결과 | 근거 |
|---|---|---|
| 1 | PASS(주의) | `godot --headless --path . --quit` → 폰트 누락 에러 2줄만, 종료코드 0. 다만 에디터/게임 실행 시 **신규 경고 1건**: `word_tree.gd:191` "The local variable \"hidden\" is shadowing an already-declared signal in the base class \"CanvasItem\"". DEV 기대치 "그 외 경고 0" 에는 미달 (LOW) |
| 2 | PASS | `OK - all game loop checks passed.` |
| 3 | PASS | `OK - day flow reached Day 2.` |

### B. S0-1 — 트리 패널이 HUD 상단바를 가리지 않는다

| # | 결과 | 근거 |
|---|---|---|
| 4 | PASS | 책 아이콘 클릭 → `단어 트리` 패널이 y=88 부터 시작. `DAY 1` / `ENERGY 20 / 20` / `0 G` / `처치 0` 4칸 모두 온전히 읽힘 |
| 5 | PASS | `Scroll` = ScrollContainer 존재(`follow_focus = true`). 창을 1280×460 으로 줄여도 `닫기` 버튼이 화면 안에 완전히 남음 (`close_button_fully_on_screen: true`, `tree_short_window.png`) |
| 6 | PASS | `닫기` → 트리 닫히고 몬스터 클릭 재개 (에너지 소모/처치 확인) |

### C. S1 / S2 — 계열·선행 관계·상태 4종

| # | 결과 | 근거 |
|---|---|---|
| 7 | PASS | 좌→우 `화염 힘 경제 에너지 행운 기타`, `기타` 비어 있음 |
| 8 | PASS | 화염 3줄, 1줄 들여쓰기 없음 + 아래 2줄 `└` 로 들여쓰기 |
| 9 | PASS | Day 1 `[제작 가능]` 5 / `[선행 잠금]` 5, 상단 `완성한 단어  0 / 10`, 범례 4종. 상태는 **대괄호 텍스트 태그**로만 구분(색 의존 없음) |
| 10 | PASS | 실제 플레이로 에너지 20 소진 → `DAY 1 종료` → 자모 선택 진입 확인. 단어 완성 후 상태 전이는 하네스에서 `[완성] 불` / `└ [제작 가능] 화염` / `└ [제작 가능] 불꽃` 로 확인 |
| 11 | PASS(방식 변경) | `.tres` 를 고치는 대신 메모리 probe DB(`고열`, 선행 `불꽃`)로 확인. Day 1 → `    └ [미발견] 고열`, `불` 완성 후 → `    └ [선행 잠금] 고열`. **파일 변경 없음 → 원복 불필요** |

### D. S3 — Target 지정

| # | 결과 | 근거 |
|---|---|---|
| 12 | PASS | 슬롯 → `[제작 가능] 돈  ← 목표`, 상단 `목표 단어: 돈`, 상태줄 `돈 을(를) 목표로 지정했습니다.`, `목표 해제` 버튼 표시 |
| 13 | PASS | 트리 닫은 뒤 하단 중앙 `TARGET: 돈` / `[ ][ ][ ]`. 자모 3종 획득 후 `[ㄷ][ㅗ][ㄴ]` 로 채워짐 |
| 14 | PASS | `[선행 잠금] 화염` 클릭 → 목표 유지(`gold_001`), 상태줄 `화염 은(는) 선행 단어가 잠겨 있어…` |
| 15 | PASS | probe `[미발견] 고열` 클릭 → 지정 거부, `고열 은(는) 아직 발견하지 못해…` |
| 16 | PASS | `[완성] 불` 클릭 → `불 은(는) 이미 완성한 단어입니다.`, 목표 불변 |
| 17 | PASS | `목표 해제` → `목표 단어: 없음`, HUD `TARGET: 없음  (트리에서 지정)`, 버튼 숨김 |
| 18 | PASS | 목표 `돈` 완성 직후 `target_word_id == ""`, HUD `TARGET: 없음`, 슬롯에서 `← 목표` 사라짐 |
| 19 | PASS | `to_dict`/`from_dict` 왕복 후 `gold_001` 복원. `target_word` 키 없는 구(舊) 세이브는 "목표 없음" 으로 로드 |

### E. S4 — 목표 집중 가중치

| # | 결과 | 근거 |
|---|---|---|
| 20 | PASS | `game_balance.tres` 에 `focus_weight_steps = (0.05, 0.1, 0.15, 0.2)`, `base_focus_level = 1`. `@export_range(0, 8)` 로 인스펙터 조절 가능 |
| 21 | PASS | `test_game_loop` 통과. 목표 자모 ×1.05 정확, 무관 자모 불변, 200회 중 목표 자모 미출현 케이스 존재(확정 출현 없음) |
| 22 | PASS | `_apply_focus_bonus()` 는 기존 가중치에 `×(1+bonus)` 만 곱하고, 목표 없으면 풀이 이전과 동일. 화면상 체감은 미세(설계대로) |

### F. S5 — 접근성

| # | 결과 | 근거 |
|---|---|---|
| 23 | **부분 FAIL** | 트리가 **열린 뒤**는 정상: 첫 슬롯 `Col0/Slot0` 에 포커스가 잡히고 굵은 진갈색 테두리가 보임(`tree_keyboard_01_open.png`, `tree_keyboard_02_walk.png`). 방향키로 컬럼 안/사이 이동 확인. **그러나 트리를 여는 단계가 키보드로 불가능** → F5-QA-1 |
| 24 | 확인 불가 | `follow_focus = true` 는 씬에 설정돼 있으나, 현재 데이터(컬럼당 최대 3줄, 6컬럼 ≈ 1170px)로는 스크롤이 발생하지 않아 재현 불가. overflow probe(화염 7단어)에서도 슬롯 5개까지만 그려져 세로 스크롤이 생기지 않음 |
| 25 | PASS | Enter → `gold_001` 지정, Space → `power_001` 지정. 둘 다 마우스 클릭과 동일 |
| 26 | PASS | 포커스 이동 시 하단 상세줄이 `[제작 가능] 돈` / `필요 자모  ㄷ 0/1  ㅗ 0/1  ㄴ 0/1` / 설명 으로 갱신. `[미발견]` 슬롯은 재료 대신 `선행 단어를 먼저 완성해야 재료가 보입니다.` |
| 27 | **FAIL** | 트리 안에서는 Tab 7회로 `목표 해제`, 10회로 `닫기` 도달 후 Enter 로 닫힘(PASS). **열기가 불가** → 전 과정 완결 실패 |

### G. S0-2 — 큰 ㅁ 가 아레나를 넘지 않는다

| # | 결과 | 근거 |
|---|---|---|
| 28 | PASS | `big_mieum.tres` `arena_margin = 0.55`, 다른 자모는 기본 0.35. `@export_range(0.0, 3.0, 0.05)` 로 인스펙터 조절 가능 |
| 29 | **FAIL** | 20마리 밀집 35초 관찰: 큰 ㅁ 몸통이 슬래브 밖으로 최대 **0.70 m** 이탈. 단독 최악 케이스 재현 시 **0.61 m** |
| 30 | PASS | `SpawnManager.arena_half_extents` (3.4, 3.4) 가 `game_world.tscn` 에서 조절 가능. 다만 이 값과 슬래브 형상이 어긋난 것이 F5-QA-2 의 원인 |

### H. 에디터 가시성 / 회귀

| # | 결과 | 근거 |
|---|---|---|
| 31 | PASS | 에디터에서 `word_tree.tscn` 열림. `WordTree > Frame > Panel > Box > TitleLabel / SummaryLabel / TargetLabel / LegendLabel / Scroll > Columns > Col0..Col5 / DetailLabel / StatusLabel / Footer` 구조 확인, **구성 경고 0**. 루트에 `column_categories = [fire, power, gold, energy, luck, ""]` export |
| 32 | PASS | `hud.tscn` 에 `TargetPanel > TargetBox > TargetWordLabel / TargetSlotsLabel` 존재(코드 생성 아님) |
| 33 | PASS | 클릭 → 에너지 0 → `DAY 1 종료` → `자모 선택으로` → 자모 후보 2장 표시까지 실제 플레이로 확인. `test_day_flow` 도 Day 2 도달 |

---

## 2. 태스크 지시 1~10 결과

**1. 삭제된 도감 잔여 참조** — PASS.
`grep -rn "WordDex\|word_dex"` 결과 프로덕션 코드/씬/리소스에 잔여 참조 0.
`main.tscn` 은 `WordTree` 인스턴스, `main.gd` 는 `_word_tree`, `hud.gd` 의 책 버튼은
`dictionary_pressed → _word_tree.open`. `tests/qa_f3_play.gd` 도 `UI/WordTree` 로 갱신됨.
유일한 잔재는 `.godot/editor/editor_layout.cfg` 의 `open_scenes` 에 남은
`res://scenes/ui/word_dex.tscn` 항목(에디터 캐시, 버전관리 대상 아님). 에디터를 실제로 열어도
에러 없이 시작됨(에러 0). **INFO 수준.**

**2. 정보 일관성 (F3 FAIL 재발 방지)** — PASS.
HUD 제작 목록과 트리가 모두 `GameState.get_word_state()` / `get_craftable_words()` 하나에서
파생된다. 하네스 `hud_vs_tree` 에서 HUD 5행 = `제작 가능` 5단어 = 트리의 `[제작 가능]` 태그
5개로 일치. `test_game_loop._test_hud_and_tree_show_the_same_words()` 가 이를 자동 검증.

**3. 잘림 재발 방지 (overflow)** — PASS.
메모리 probe 로 화염 계열을 7단어로 늘림 → 슬롯 5개까지만 그려지고 컬럼 아래에
`Col0: 칸이 모자라 2개를 감췄습니다` 라벨이 **실제로 보임**(`tree_overflow_01_fire_column.png`).
**프로덕션 `.tres` 는 건드리지 않았으므로 원복 대상 없음**, 하네스가 `database_restored: true` 확인.

**4. S0-1 겹침 해소** — PASS. (위 4~6번)

**5. S0-2 아레나 이탈 해소** — **FAIL.** (아래 F5-QA-2)
일반 자모 이동 범위 부작용: 큰 ㅁ 는 중심 최대 반경 3.40 m → 2.84 m 로 줄었고, 일반 자모는
diamond 3.40 → 3.05 로 줄어 실측 최대 2.85 m. 게임플레이상 체감할 만한 위축은 관찰되지 않음
(20마리가 여전히 판 전체에 퍼짐, `arena_normal_jamo_final.png`). **부작용은 허용 범위.**

**6. S3 Target 규칙** — PASS. (12~19번, 저장/복원·자동 해제 포함)

**7. S4 확정 출현 금지** — PASS.
`get_focus_weight_bonus()` = +0.05, `weights[jamo] *= 1.05` 만 적용. 200회 추첨 중 목표 자모
미출현 케이스가 반드시 존재함을 `test_game_loop` 가 수치로 확인.

**8. S5 접근성** — **FAIL.** (아래 F5-QA-1)
- 트리 내부 키보드 조작: 완결됨(슬롯 이동/Enter·Space 지정/Tab 으로 해제·닫기).
- 포커스 표시: 보임(굵은 진갈색 3px 아웃라인).
- 스크롤 추종: `follow_focus = true` 설정돼 있으나 현 데이터로 스크롤 자체가 발생하지 않아 재현 불가.
- 상태 4종 텍스트 구분: PASS(`[완성] [제작 가능] [선행 잠금] [미발견]`).
- **트리 열기: 불가.**
단계별 스크린샷: `tree_keyboard_01_open.png` ~ `tree_keyboard_06_closed.png`,
열기 시도 실패 증거 `tree_keyboard_open_attempt.png`.

**9. 회귀** — PASS.
`test_game_loop.tscn` 이 F1 치명 클릭, F2 리롤(게이트/차감/재추첨/저장), F3 단어 10개·화염 burn·
불꽃 확산, F4 특수 3종 배율·황금 게이트, 세이브 왕복을 모두 통과. `test_day_flow.tscn` Day 2 도달.
실제 플레이로 Day 1 클릭 → 에너지 0 → Day End → 자모 선택까지 확인.

**10. 자동 테스트** — PASS. (1~3번)

---

## 3. FAIL 상세

### F5-QA-1 (HIGH) — 키보드만으로 트리를 열 수 없다

재현
1. `godot --path . scenes/main/main.tscn` 로 Day 1 진입.
2. 마우스를 쓰지 않고 Tab 을 12번 누른다(사이사이 Enter).

기대 — 어느 시점에 HUD 책 버튼에 포커스가 잡히고, Enter 로 `단어 트리` 가 열린다.
(DEV 인계문 27번, 태스크 지시 8번)

실제 — 12번 모두 `get_viewport().gui_get_focus_owner()` 가 `(none)`. 트리는 열리지 않는다.
`qa_f5_tree.json > keyboard_open.tab_focus_chain` 전 항목 `(none)`,
`tree_opened_after_tabs: -1`. 증거 `tree_keyboard_open_attempt.png`.

원인 — 게임 시작 시 어떤 Control 도 포커스를 잡지 않는다. Godot 의 `ui_focus_next` 는
현재 포커스 오너가 없으면 아무 것도 하지 않으므로 Tab 체인 자체가 시작되지 않는다.
덧붙여 `hud.tscn` 의 `DictionaryButton` 은 TextureButton 이고 focus 용 텍스처/스타일이
지정돼 있지 않아, 설사 포커스가 가더라도 **포커스 표시가 화면에 전혀 보이지 않는다.**

영향 — S5 "키보드만으로 조작 가능" 이 성립하지 않는다. 마우스 없이는 트리 진입 자체가 불가.

### F5-QA-2 (HIGH) — 큰 ㅁ 가 여전히 아레나 가장자리를 넘는다

재현
1. `godot --path . tests/qa_f5_arena.tscn` (동시 등장 20, 큰 ㅁ 전용 풀, 35초 관찰)
2. 또는 게임에서 상점 `동시 등장` 을 올리고 큰 ㅁ 가 섞인 밀집 상태를 30초 이상 본다.

기대 — 큰 ㅁ 의 몸통이 종이 슬래브 가장자리 밖으로 나오지 않는다. (DEV 29번)

실제 — 슬래브 반경 2.8 m 기준 몸통 최대 이탈:

| 조건 | 최악 이탈 | 이탈 프레임 비율 | 중심 최대 |
|---|---|---|---|
| `arena_margin = 0` (F5 이전 거동) | 0.869 m | 12.2 % | 3.400 m |
| `arena_margin = 0.55` (현재) | 0.638 m | 3.6 % | 2.838 m |

단독 최악 케이스(걷기 가능 다이아몬드의 +X 꼭짓점 = x 2.85 m)에서 몸통 이탈 **0.611 m**
(`arena_worst_case_corner.png`, `qa_f5_arena.json > worst_case_corner`).
밀집 20마리 관찰에서는 최대 **0.700 m** (`arena_big_mieum_1400.png`).
→ 완화는 됐으나 **해소되지 않음.**

원인 — 걷기 영역 모델이 슬래브 형상과 다르다.
`JamoMonster.random_point_in_arena()` / `_clamp_to_arena()` 는
`|x|/h + |z|/h ≤ 1` 인 **마름모**를 쓰지만(주석도 "diamond footprint of the rotated arena
slab"), `scenes/world/arena.tscn` 의 `PaperTop` 은 5.6×5.6 **축정렬 정사각형**(반경 2.8)이고
`game_world.tscn` 의 `Arena` 노드에는 회전이 없다. 화면이 마름모로 보이는 것은 카메라가
아이소메트릭이기 때문일 뿐이다.
그 결과 `h = 3.4 - 0.55 = 2.85` 인 마름모는 **축 방향에서 x = 2.85 > 2.8** 까지 허용하고
(즉 중심부터 이미 판 밖), 정작 실제 판의 네 모서리는 못 가게 막는다.

수정 방향(참고) — 사각형으로 클램프하거나(`|x| ≤ 2.8 - margin`, `|z| ≤ 2.8 - margin`),
`arena_half_extents` 를 슬래브 사각형에 맞춰 다시 정의할 것. 마름모를 유지하려면
`h ≤ 2.8 - (개체 반폭)` 이어야 한다.

관련 INFO — 일반 자모도 몸통 이탈이 최대 0.60 m 관측된다(digeut/mieum). 같은 원인이며
F5 이전부터 있던 거동이라 S0-2 범위 밖으로 본다. 위 수정으로 함께 해결된다.

---

## 4. INFO / LOW

- **L1** `scripts/ui/word_tree.gd:191` 지역 변수 `hidden` 이 `CanvasItem.hidden` 시그널을 가린다.
  에디터/게임 실행 시 경고 1줄. 동작 문제는 없으나 DEV 기대치("경고 0")와 어긋남.
  변수명만 바꾸면 해소(예: `hidden_count`).
- **L2** `.godot/editor/editor_layout.cfg` 의 `open_scenes` 에 삭제된 `word_dex.tscn` 이 남아 있다.
  에디터 캐시라 버전관리 영향 없음, 에디터 기동 에러도 없음.
- **L3** HUD 책 아이콘 툴팁이 여전히 `단어 도감` 이다(DEV 3)-B 에서 의도적으로 보류한 항목).
- **L4** `follow_focus` 동작은 현재 데이터로 스크롤이 발생하지 않아 실측 불가.
  단어가 늘거나 컬럼당 슬롯이 늘면 재검증 필요.
- **L5** DEV 3)-C(힌트 업그레이드 미도입으로 Target 노출 제한 보류), 3)-D(Focus 골드 업그레이드
  트랙 보류)는 실제로 문제를 일으키지 않음을 확인. 3)-F 하위 호환(구 세이브 로드, 유효하지 않은
  목표 자동 해제)도 확인 완료.

---

## 5. 산출물

QA 하네스 (신규, `tests/` 하위만 추가)
- `tests/qa_f5_tree.gd` / `.tscn` — 트리 UI: 키보드 전용 조작, Target 규칙, 미발견/overflow
  probe, 창 축소, 세이브 왕복
- `tests/qa_f5_arena.gd` / `.tscn` — 큰 ㅁ / 일반 자모 / 혼합 밀집 관찰 + 최악 케이스 촬영
- `tests/qa_f5_margin_ab.gd` / `.tscn` — `arena_margin` 0 vs 0.55 A/B 실측

증거 (`tests/qa_artifacts/f5/`)
- `qa_f5_tree.json`, `qa_f5_arena.json`
- 키보드 단계별: `tree_keyboard_open_attempt.png`, `tree_keyboard_01_open.png`,
  `tree_keyboard_02_walk.png`, `tree_keyboard_03_enter.png`, `tree_keyboard_04_space.png`,
  `tree_keyboard_05_clear_target.png`, `tree_keyboard_06_closed.png`
- Target: `tree_target_01_set_don.png` ~ `tree_target_04_auto_cleared.png`
- 상태/레이아웃: `tree_undiscovered_01_day1.png`, `tree_undiscovered_02_after_bul.png`,
  `tree_overflow_01_fire_column.png`, `tree_short_window.png`
- 아레나: `arena_big_mieum_*.png`, `arena_normal_jamo_*.png`, `arena_mixed_*.png`,
  `arena_worst_case_corner.png`
