# F3 QA FAIL 수정 — HUD 제작 목록 행 고정 회귀 (F-1 / F-2) — DEV 인계문

대상: QA_REPORT.md 4절 F-1 (HIGH), F-2 (MEDIUM)
브랜치: main

---

## 1) 변경 파일 목록

### 수정

| 파일 | 내용 |
|---|---|
| `scenes/ui/hud.tscn` | `WordProgressPanel/WordBox` 에 `WordRow4`~`WordRow9` 라벨 6개 추가 (총 10행 = database 단어 수). 잘림 표시용 `WordOverflowLabel`, 빈 상태용 `WordEmptyLabel` 추가 (둘 다 씬에서 `visible = false`) |
| `scripts/ui/hud.gd` | `_word_rows` 에 신규 6행 연결. `_word_overflow_label` / `_word_empty_label` `@onready` 추가. `_refresh_word_progress()` 가 craftable 0개면 빈 문구를, 행보다 단어가 많으면 `외 N개 더` 를 표시 |
| `tests/test_game_loop.gd` | `_test_hud_lists_every_craftable_word()` 추가 (+ 헬퍼 `_hud_word_rows()` / `_visible_word_texts()`, `HUD_SCENE` 상수). `_ready()` 실행 목록에 등록 |

신규 파일 없음. UI 노드는 전부 `.tscn` 노드이며 GDScript 로 생성하지 않는다 (v0.3 19.1).

### 재발 방지 구조

- 행 개수를 코드에 다시 하드코딩하지 않았다. 테스트가
  `rows.size() >= GameState.database.words.size()` 를 database 에서 파생시켜 검증하므로,
  단어를 11개로 늘리면 씬에 행을 추가하기 전까지 테스트가 **빨간 상태로 실패**한다.
- 표시 행 수 검증도 하드코딩된 5가 아니라 `GameState.get_craftable_words()` 에서 파생한다.
- 그래도 단어가 행보다 많아진 채 실행되면 `WordOverflowLabel` 이 `외 N개 더` 로
  잘림을 화면에 드러낸다 (조용히 사라지지 않는다).

---

## 2) 검수 절차

### A. 정적 / 자동 테스트

1. `godot --headless --path . --quit` 실행.
   기대: `NotoSansKR-Regular.ttf` 폰트 누락 2줄 외에 에러/경고 없음.
2. `godot --headless --path . res://tests/test_game_loop.tscn` 실행.
   기대: 마지막 줄 `OK - all game loop checks passed.`
3. `godot --headless --path . res://tests/test_day_flow.tscn` 실행.
   기대: 마지막 줄 `OK - day flow reached Day 2.`
4. 회귀 테스트가 실제로 문제를 잡는지 확인하려면 `scripts/ui/hud.gd` 의 `_word_rows` 를
   임시로 `%WordRow0 ~ %WordRow3` 4개로 되돌리고 2번을 다시 실행한다.
   기대: `FAIL: the HUD should show 5 rows on Day 1 (got 10)` 등 3건 실패 후
   `FAILED - 3 check(s) failed.` (확인 후 원복할 것)

### B. 에디터 가시성

5. `scenes/ui/hud.tscn` 을 에디터에서 연다.
   기대: Scene 독의 `WordProgressPanel/WordBox` 아래에 `WordRow0` ~ `WordRow9` 라벨 10개,
   그 뒤에 `WordOverflowLabel` 과 `WordEmptyLabel` 이 있고 뒤 두 개는 눈 아이콘이 꺼진
   (`visible = false`) 상태다. 구성 경고 0.

### C. 직접 플레이 — F-1 (제작 가능 5개 전부 표시)

6. `user://jamo_save.json` 이 없는 상태(새 게임)로 게임을 실행한다.
   기대: 좌하단 `제작 가능한 단어` 패널에 **5줄**이 보인다 —
   `불 ㅂ 0/1 ㅜ 0/1 ㄹ 0/1` / `힘 ㅎ 0/1 ㅣ 0/1 ㅁ 0/1` / `돈 ㄷ 0/1 ㅗ 0/1 ㄴ 0/1` /
   `밥 ㅂ 0/2 ㅏ 0/1` / `운 ㅇ 0/1 ㅜ 0/1 ㄴ 0/1`.
   **`운` 이 반드시 포함**되어야 한다 (F-1 의 직접 재현 지점).
7. 같은 화면에서 도감(책 버튼)을 열어 `[제작 가능]` 목록과 대조한다.
   기대: 도감의 `[제작 가능]` 5개와 HUD 5줄이 **완전히 일치**한다 (두 UI 가 같은 말을 한다).
8. 6번 화면에서 HUD 패널 상단 y 좌표를 본다.
   기대: 패널이 화면 아래쪽에 머물고 상단바(`DAY` / `ENERGY` / `처치`)와 **겹치지 않는다**.
   실측: 1280x720 에서 5줄일 때 패널이 y≈533 에서 시작 (상단바는 y 14~76). 여유 충분.

### D. 직접 플레이 — F-2 (빈 상태 문구)

9. 10개 단어를 전부 완성한 상태를 만든다. 빠른 방법: 다음 세이브를 심는다.
   ```
   {"day":12,"gold":500,"upgrade_levels":{},
    "unlocked_words":["fire_001","fire_002","fire_003","power_001","power_002",
                      "gold_001","gold_002","energy_001","energy_002","luck_001"],
    "jamo_inventory":{},"rerolls_left":0}
   ```
   (`user://jamo_save.json`. 검수 후 삭제할 것)
10. 게임을 실행하고 좌하단 패널을 본다.
    기대: 빈 상자가 아니라 제목 아래에 **`완성할 단어가 없습니다`** 한 줄이 보인다.
    단어 행은 한 줄도 보이지 않는다.

### E. 잘림 표시 (선택)

11. 행보다 단어가 많은 상황은 현재 database(10단어, 동시 제작가능 최대 6)에서는 만들 수 없다.
    구조만 확인하려면 `scripts/ui/hud.gd` 의 `_word_rows` 를 임시로 2개로 줄이고 6번을 실행한다.
    기대: 2줄 + `외 3개 더` 가 보인다. (확인 후 원복)

---

## 3) 주의 / 보류 사항

1. **F-3 은 손대지 않았다.** 도감 패널이 HUD 상단바와 겹치는 문제는 지시대로 F5 단어 트리 UI
   사이클로 미뤘다. `scenes/ui/word_dex.tscn` / `scripts/ui/word_dex.gd` 는 이번 수정에서
   한 줄도 바뀌지 않았다. QA 리포트에 남은 상태로 두면 된다.
2. **HUD 패널 최소 높이.** `WordProgressPanel` 의 `offset_top = -132` 는 그대로 뒀다.
   행이 늘면 PanelContainer 가 위로 자라고(`grow_vertical = 0`), 빈 상태에서는 최소 높이
   116px 이 남아 문구 아래에 약간의 여백이 보인다. 기능 결함은 아니라 범위 밖으로 판단했다.
   레이아웃을 다시 손대는 F5 에서 정리하는 편이 낫다.
3. **동시 제작 가능 단어의 실제 상한은 6이다** (불만 해금 시 힘/돈/밥/운 + 화염/불꽃).
   행은 10개를 뒀으므로 여유가 있지만, 6이라는 수를 코드나 테스트에 못박지 않았다.
   database 단어 수를 기준으로만 검증한다.
4. **`hidden` 변수명 회피.** `CanvasItem` 에 `hidden` 시그널이 있어 지역 변수명으로 쓰면
   shadowing 경고가 난다. `overflow` 로 명명했다.
5. **검수용 세이브 원복.** 이번 작업 중 F-2 확인을 위해 `user://jamo_save.json` 을 심었다가
   삭제했다. 세션 시작 시점과 동일하게 세이브 파일이 없는 상태다.
6. 폰트 누락(`NotoSansKR-Regular.ttf`)과 `signal_bus.gd` 의 "declared but never explicitly
   used" 경고는 이번 변경 이전부터 있던 기존 이슈다.
