# F5 단어 트리 UI — DEV 인계문

대상: DEV_ROADMAP F5 / S0~S5, 브랜치 `main`.

---

## 1) 변경 파일 목록

### 신규
- `scenes/ui/word_tree.tscn` — 단어 트리 씬 (계열 6열 × 슬롯 5개 + 열별 overflow 라벨)
- `scripts/ui/word_tree.gd`
- `tests/qa_artifacts/f5/DEV_HANDOFF.md` (이 문서)

### 삭제 (트리로 대체)
- `scenes/ui/word_dex.tscn`
- `scripts/ui/word_dex.gd`
- `scripts/ui/word_dex.gd.uid`

### 수정
- `autoload/game_state.gd` — `WordState` enum 4종, `get_word_state()`, `target_word_id`,
  `get_target_word()` / `set_target_word()` / `clear_target_word()` / `_validate_target()`,
  `get_focus_weight_bonus()`, 세이브 키 `target_word`
- `autoload/signal_bus.gd` — `target_word_changed(word)` 시그널
- `scripts/data/game_balance.gd` — `focus_weight_steps`, `base_focus_level`, `focus_weight_bonus_at()`
- `resources/balance/game_balance.tres` — `focus_weight_steps = (0.05, 0.1, 0.15, 0.2)`, `base_focus_level = 1`
- `scripts/word_system/candidate_generator.gd` — `_build_weights()` → `build_weights()` (public),
  `_apply_focus_bonus()` 추가
- `scripts/data/jamo_monster_data.gd` — `arena_margin` export 추가 (기본 0.35)
- `resources/monsters/big_mieum.tres` — `arena_margin = 0.55`
- `scripts/monsters/jamo_monster.gd` — `get_walkable_half_extents()`, `_clamp_to_arena()`,
  `MIN_WALKABLE_HALF_EXTENT`
- `scripts/monsters/spawn_manager.gd` — `_random_spawn_point(half_extents)` 로 변경, 스폰 시
  개체별 walkable 다이아몬드 사용
- `scenes/ui/hud.tscn` — 하단 중앙 `TargetPanel` (`TargetWordLabel`, `TargetSlotsLabel`)
- `scripts/ui/hud.gd` — `_refresh_target()`, `_target_slot_text()`, `target_word_changed` 연결
- `scenes/main/main.tscn` — `WordDex` → `WordTree` 노드 교체
- `scripts/main.gd` — `_word_dex` → `_word_tree`
- `theme/jamo_theme.tres` — `TreeSlot` theme type variation (normal + 3px focus 아웃라인)
- `tests/test_game_loop.gd` — F5 검증 4종 추가
- `tests/qa_f3_play.gd` — `UI/WordDex` → `UI/WordTree`, 슬롯 버튼에서 행 텍스트 읽도록 수정

---

## 2) 검수 절차

전제: `godot --path . scenes/main/main.tscn` 로 실행 (또는 ziva-godot MCP `run_scene`).
세이브 파일을 지우고 Day 1 부터 시작할 것.

### A. 정적 / 자동
1. `godot --headless --path . --quit` 실행.
   → 기대: 에러 2줄(`NotoSansKR-Regular.ttf` 폰트 누락)만 나오고 그 외 에러/경고 0.
2. `godot --headless --path . tests/test_game_loop.tscn` 실행.
   → 기대: `OK - all game loop checks passed.`
3. `godot --headless --path . tests/test_day_flow.tscn` 실행.
   → 기대: `OK - day flow reached Day 2.`

### B. S0-1 — 트리 패널이 HUD 상단바를 가리지 않는다
4. 게임 실행 후 Day 1 화면 우측 상단의 **책 아이콘(단어 도감 버튼)** 을 클릭한다.
   → 기대: 화면에 `단어 트리` 패널이 열린다. 패널 위쪽 테두리가 `DAY 1` / `ENERGY 20 / 20` /
     `0 G` / `처치 0` 이 있는 **상단바보다 아래**에서 시작하고, 상단바 4칸이 전부 가려지지 않고
     읽힌다.
5. 트리 패널 안에서 마우스 휠을 위/아래로 굴린다.
   → 기대: 컬럼 영역이 스크롤된다(스크롤 컨테이너 존재). 창을 세로로 작게 줄여도 아래쪽
     `닫기` 버튼이 화면 밖으로 잘려 사라지지 않는다.
6. 하단의 `닫기` 를 누른다.
   → 기대: 트리가 닫히고 몬스터 클릭이 다시 된다.

### C. S1 / S2 — 계열·선행 관계·상태 4종
7. 다시 트리를 열고 컬럼 제목을 읽는다.
   → 기대: 왼쪽부터 `화염` `힘` `경제` `에너지` `행운` `기타` 6개 컬럼.
     `기타` 컬럼은 비어 있다(현재 DB에 미분류 단어 없음).
8. `화염` 컬럼을 읽는다.
   → 기대: 3줄. 첫 줄 `[제작 가능] 불` 은 들여쓰기 없음, 그 아래 두 줄은
     `└ [선행 잠금] 화염`, `└ [선행 잠금] 불꽃` 처럼 `└` 로 한 칸 들여써져 있다.
     즉 선행 관계가 들여쓰기로 보인다.
9. 상태 태그를 확인한다.
   → 기대: Day 1 에 `[제작 가능]` 5개(불/힘/돈/밥/운), `[선행 잠금]` 5개
     (화염/불꽃/강타/금/체력). 색이 아니라 **대괄호 텍스트 태그**로 구분된다.
     상단 `완성한 단어  0 / 10`, 그 아래 범례 줄에 4종 태그 설명이 보인다.
10. 트리를 닫고, 몬스터를 클릭해 에너지 20 을 모두 쓴 뒤 Day End → 자모 선택 → 상점을
    거쳐 Day 를 넘긴다. `ㅂ` `ㅜ` `ㄹ` 을 모아 `불` 을 완성시킨다.
    → 기대: `단어 완성` 패널이 뜬다. 이후 트리를 열면 `화염` 컬럼이
      `[완성] 불` / `└ [제작 가능] 화염` / `└ [제작 가능] 불꽃` 로 바뀌고
      `완성한 단어  1 / 10` 이 된다.
11. **`[미발견]` 확인 (데이터 조작 필요, 아래 3)-A 참조)**: Godot Editor 에서
    `resources/words/bulkkot.tres` 를 선택하고 Inspector 의 `Prerequisites` 배열
    0번 값을 `fire_001` → `fire_002` 로 바꾸고 저장한 뒤 게임을 새로 실행한다.
    → 기대: 새 세이브 Day 1 트리에서 `불꽃` 이 `[미발견]` 으로 표시된다
      (불꽃의 선행 `화염` 자체가 아직 제작 불가이므로 두 단계 뒤). `불` 을 완성하면
      `불꽃` 이 `[선행 잠금]` 으로 바뀐다. **확인 후 `fire_001` 로 되돌릴 것.**

### D. S3 — Target 지정
12. 트리에서 `[제작 가능] 돈` 슬롯을 클릭한다.
    → 기대: 슬롯 텍스트가 `[제작 가능] 돈  ← 목표` 로 바뀌고, 패널 상단이
      `목표 단어: 돈`, 하단 상태줄에 `돈 을(를) 목표로 지정했습니다.` 가 뜬다.
      하단 왼쪽에 `목표 해제` 버튼이 새로 나타난다.
13. `닫기` 를 눌러 트리를 닫고 화면 **하단 중앙**을 본다.
    → 기대: `TARGET: 돈` 과 그 아래 `[ ][ ][ ]` (아직 자모 없음).
      자모를 모으면 `[ㄷ][ ][ ]` 처럼 모은 자모부터 칸이 채워진다.
14. 트리를 다시 열고 `[선행 잠금] 화염` 슬롯을 클릭한다.
    → 기대: 목표가 **바뀌지 않는다**. 상단은 계속 `목표 단어: 돈`, 하단 상태줄에
      `화염 은(는) 선행 단어가 잠겨 있어 목표로 지정할 수 없습니다.` 가 뜬다.
15. (11번을 수행했다면) `[미발견]` 슬롯을 클릭한다.
    → 기대: 역시 지정되지 않고 `아직 발견하지 못해 목표로 지정할 수 없습니다.` 가 뜬다.
16. 이미 완성한 `[완성] 불` 슬롯을 클릭한다.
    → 기대: `이미 완성한 단어입니다.` 가 뜨고 목표는 그대로다.
17. `목표 해제` 를 누른다.
    → 기대: `목표 단어: 없음`, HUD 하단이 `TARGET: 없음  (트리에서 지정)` 로 돌아가고
      `목표 해제` 버튼이 사라진다.
18. 목표를 `돈` 으로 다시 지정한 뒤 `ㄷ` `ㅗ` `ㄴ` 을 모아 `돈` 을 완성시킨다.
    → 기대: 완성 직후 목표가 자동 해제되어 `TARGET: 없음` 이 되고, 트리에서 `돈` 은
      `[완성] 돈` 이며 `← 목표` 표시가 없다.
19. 목표를 지정한 상태로 게임을 껐다가 다시 켠다.
    → 기대: 지정했던 목표가 유지되어 HUD 하단에 그대로 보인다.

### E. S4 — 목표 집중 가중치
20. Godot Editor 에서 `resources/balance/game_balance.tres` 를 선택한다.
    → 기대: Inspector 에 `Target Focus` 그룹이 있고 `Focus Weight Steps`
      (0.05 / 0.1 / 0.15 / 0.2 4칸), `Base Focus Level` (0~8 슬라이더, 값 1) 이 보이고
      수정 가능하다.
21. 자동 테스트 2번(`test_game_loop`)이 이 항목을 수치로 검증한다:
    목표 지정 시 해당 자모 가중치가 정확히 ×1.05 가 되고, 목표와 무관한 자모 가중치는
    변하지 않으며, 200회 추첨 중 목표 자모가 안 나오는 경우가 반드시 존재한다(확정 출현 없음).
    → 기대: `OK - all game loop checks passed.`
22. 화면에서 체감 확인: 목표를 `돈` 으로 지정한 뒤 Day 를 여러 번 넘기며 자모 후보를 본다.
    → 기대: `ㄷ` `ㅗ` `ㄴ` 이 조금 더 자주 나오지만 **매번 나오지는 않는다**.
      (+5% 라 눈으로는 미세하다. 수치 판정은 21번으로 한다.)

### F. S5 — 접근성
23. 트리를 연 직후 마우스를 쓰지 않고 **Tab / 방향키**만 누른다.
    → 기대: 트리를 열면 첫 슬롯에 이미 포커스가 잡혀 있고, 포커스된 슬롯 둘레에
      **굵은 진갈색 사각 테두리**가 보인다. 방향키로 컬럼 안/컬럼 사이를 이동할 수 있다.
24. 포커스를 아래로 계속 내려 화면 밖 슬롯까지 이동한다.
    → 기대: 스크롤이 자동으로 따라가 포커스된 슬롯이 항상 화면 안에 보인다.
25. 아무 `[제작 가능]` 슬롯에 포커스를 두고 **Enter 또는 Space** 를 누른다.
    → 기대: 마우스 클릭과 똑같이 목표가 지정된다.
26. 슬롯에 포커스를 옮기며 패널 아래쪽 설명 줄을 본다.
    → 기대: `[제작 가능] 돈` / `필요 자모  ㄷ 0/1  ㅗ 0/1  ㄴ 0/1` / 설명 이 표시된다.
      `[미발견]` 슬롯에서는 재료 대신 `선행 단어를 먼저 완성해야 재료가 보입니다.` 가 나온다.
27. Tab 으로 계속 이동해 `목표 해제` / `닫기` 까지 도달한 뒤 Enter 로 닫는다.
    → 기대: 키보드만으로 트리를 열고 목표를 지정하고 닫는 전 과정이 가능하다.

### G. S0-2 — 큰 ㅁ 가 아레나를 넘지 않는다
28. Godot Editor 에서 `resources/monsters/big_mieum.tres` 를 선택한다.
    → 기대: Inspector `Movement` 그룹에 `Arena Margin` = **0.55** 이 보이고 슬라이더로
      조절 가능하다. 다른 자모 `.tres` 는 기본값 0.35 로 보인다.
29. 게임에서 몬스터 수용 인원을 최대로 올린다(상점에서 `동시 등장` 업그레이드 구매, 또는
    F4 QA 하네스처럼 20마리 상태를 만든다). 큰 ㅁ 가 여러 마리 섞인 밀집 상태로 30초 이상
    관찰한다.
    → 기대: 큰 ㅁ 의 몸통이 종이 슬래브(밝은 사각 판) **가장자리 밖으로 튀어나오지 않는다.**
      밀집해서 서로 밀어내는 순간에도 판 밖으로 넘어가지 않는다.
30. `game_world.tscn` 의 `SpawnManager` 를 선택한다.
    → 기대: `Field > Arena Half Extents` (3.4, 3.4) 가 씬에서 조절 가능하다.
      이 값과 각 `.tres` 의 `Arena Margin` 두 개로 수치 조절이 된다(코드 수정 불필요).

### H. 에디터 가시성 / 회귀
31. Godot Editor 에서 `scenes/ui/word_tree.tscn` 을 연다.
    → 기대: `WordTree > Frame > Panel > Box` 아래 `TitleLabel / SummaryLabel / TargetLabel /
      LegendLabel / Scroll > Columns > Col0..Col5 / DetailLabel / StatusLabel / Footer` 가
      트리에 보이고, 각 컬럼 안에 `Title`, `Slot0..Slot4`(Button), `Overflow`(Label) 가 있다.
      구성 경고 0. 루트 노드를 선택하면 Inspector 에 `Column Categories` 배열
      (`fire / power / gold / energy / luck / ""`) 이 보이고 수정 가능하다.
32. `scenes/ui/hud.tscn` 을 연다.
    → 기대: `TargetPanel > TargetBox > TargetWordLabel / TargetSlotsLabel` 이 씬에 존재한다
      (코드 생성 아님).
33. Day 1 → Day 2 기본 루프를 한 바퀴 돈다(클릭 → 에너지 0 → Day End → 자모 선택 →
    (리롤) → 상점 → 다음 Day).
    → 기대: F1~F4 동작 그대로. 자모 선택/리롤/상점/저장 모두 정상.

---

## 3) 주의 / 보류 사항

### A. `[미발견]` 상태는 현재 데이터로는 화면에 나오지 않는다 (중요)
- 상태 판정 규칙: 선행이 전부 충족 → `제작 가능`. 미충족이지만 **모든 미충족 선행이
  지금 당장 제작 가능** → `선행 잠금`. 그보다 더 깊으면 → `미발견`.
- 현재 DB 10개 단어의 선행 사슬은 **최대 1단계**(tier-1 → tier-2)뿐이라, `미발견` 이 되는
  단어가 존재하지 않는다. 3단계 단어(예: 불→화염→고열)가 들어오는 순간 자동으로 나타난다.
- UI 결함이 아니라 데이터 깊이의 문제다. 규칙 자체는 `test_game_loop.gd` 의
  `_test_word_states_come_from_the_database()` 가 임시 probe 데이터베이스로 검증한다
  (프로덕션 `.tres` 는 건드리지 않음).
- 화면에서 눈으로 보고 싶으면 검수 절차 11번(불꽃의 선행을 `fire_002` 로 임시 변경)을 쓰고
  반드시 원복할 것.

### B. word_dex 를 병존시키지 않고 삭제했다
- F3 QA 의 FAIL 사유가 "HUD 와 도감이 서로 다른 말을 함" 이었으므로, 같은 정보를 보여주는
  UI 를 두 개 두지 않았다. 트리가 도감의 정보(완성 수, 상태, 필요 자모, 설명)를 전부 포함한다.
- HUD 의 책 아이콘(툴팁 `단어 도감`)이 이제 트리를 연다. **툴팁 문구는 바꾸지 않았다** —
  아이콘/문구 변경은 요청 범위 밖이라 판단했다. 필요하면 다음 사이클에서 `단어 트리` 로.
- `tests/qa_f3_play.gd` 가 `UI/WordDex` 와 도감 내부 노드 경로를 직접 참조하고 있어서
  트리 기준으로 고쳤다. F3 하네스를 다시 돌리면 `dex_fresh` / `dex_all` 항목의 행 텍스트가
  도감 형식이 아니라 트리 슬롯 형식으로 기록된다(정상).

### C. 힌트 업그레이드는 없다 — Target 노출량을 제한하지 않았다
- v0.3 §23.1 "힌트 업그레이드가 없으면 Target 정보 노출량을 제한한다" 단서 관련.
- 현재 힌트 업그레이드 트랙이 프로젝트에 존재하지 않고, 기존 HUD 는 이미 제작 가능한 모든
  단어의 필요 자모를 `ㅂ 0/1` 형태로 전부 보여주고 있다. 그래서 **현재 노출 수준을 유지**했다
  (TARGET 줄도 같은 수준으로 `[ㅂ][ㅜ][ ]` 만 보여준다).
- 단, `[미발견]` 단어의 재료는 상세 줄에서 숨긴다.
- 힌트 업그레이드가 생기면 그때 TARGET 슬롯 표기를 게이팅해야 한다. **보류.**

### D. 목표 집중(Focus) 업그레이드 트랙은 만들지 않았다
- 지시대로 트랙 신설 없이 가중치 계산 구조와 단계 데이터만 노출했다.
- `GameBalance.focus_weight_steps` (0.05/0.1/0.15/0.2) + `base_focus_level` (기본 1) 이
  `.tres` 에서 조절 가능하다. 현재 항상 +5% 다.
- 골드 업그레이드 연결(`UpgradeData` 트랙 추가 + `base_focus_level` 대신 업그레이드 레벨 사용)
  은 **다음 사이클로 미룸.**

### E. Pool A/B/C 는 그대로다
- `CandidateGenerator` 의 기존 가중치 로직은 손대지 않았고, 마지막에 목표 자모의 가중치에만
  `× (1 + bonus)` 를 곱한다. 목표가 없으면 이전과 **완전히 동일한** 풀이 나온다.
- `_build_weights()` 를 `build_weights()` 로 이름만 바꿨다(테스트에서 추첨 없이 풀을 읽기
  위해). 외부 호출부는 없었다.

### F. 하위 호환
- 세이브에 `target_word` 키가 추가됐다. **옛 세이브에는 이 키가 없으며 "목표 없음"으로 읽힌다.**
  신규 세이브를 옛 빌드에서 읽어도 모르는 키는 무시된다.
- 로드 시 저장된 목표가 더 이상 제작 가능하지 않으면(이미 완성됐거나 DB 에서 사라졌으면)
  조용히 해제한다. 잘못된 목표가 남지 않는다.
- `SignalBus.target_word_changed` 는 신규 시그널이라 기존 구독자에 영향 없다.

### G. 아레나 여백 기본값이 모든 자모에 적용된다
- `JamoMonsterData.arena_margin` 기본값 0.35 는 기존 6종 자모에도 적용되므로, 이동 가능
  다이아몬드가 half-diagonal 3.4 → 3.05 로 **약간 줄어든다.** 슬래브 안쪽으로 조금 더
  들어와 걷게 되는 것이며 게임플레이 영향은 미미하다고 판단했다.
- 큰 ㅁ 만 0.55 로 명시했다. 다른 특수 개체(`fast_ieung`, `golden_hieut`)는 visual_scale 이
  1.5~1.6 으로 일반 자모보다 작아 기본값으로 충분하다.
- 벽 콜라이더(`arena.tscn` 의 `Walls`)는 **건드리지 않았다.** 백스톱으로 그대로 두고,
  실제 억제는 개체별 walkable 다이아몬드 + `_clamp_to_arena()` 로 한다.

### H. 슬롯 수 / overflow
- 컬럼당 슬롯 5개, 컬럼 6개 = 최대 30개 단어. 현재 10개라 여유가 있다.
- 한 계열의 단어가 5개를 넘으면 잘리지 않고 그 컬럼 아래에
  `칸이 모자라 N개를 감췄습니다` 가 **보이게** 표시된다(F3 의 조용한 잘림 재발 방지).
- 알 수 없는 category 는 마지막 `기타` 컬럼으로 모인다.

### I. 기타
- `scripts/ui/word_tree.gd.uid` 파일은 아직 없다. Godot Editor 로 프로젝트를 한 번 열면
  자동 생성된다. `git status` 에 새 untracked 파일로 뜰 수 있다.
- `art/Untitled.blend` / `.blend.import` 은 F4 QA 가 지적한 기존 잔여 untracked 파일이다.
  이번 변경과 무관하며 손대지 않았다.
- `NotoSansKR-Regular.ttf` 폰트 누락 에러 2줄은 F3 이전부터 있던 기존 이슈다.
- `docs/DEV_ROADMAP.md` 의 F5 체크박스는 **갱신하지 않았다.** QA PASS 후 총지휘자가
  갱신하는 항목으로 판단했다.
