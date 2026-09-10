# DEV 인계문 — F9 (F8 이월 4건 정리)

작성: 2026-09-10 · 대상: `docs/DEV_ROADMAP.md` "F8 이월" 4건 · 새 기능 없음

---

## 1) 변경 파일 목록

**수정**

- `scripts/ui/title_screen.gd` — 판때기 강조 1개 보장 (MEDIUM-4)
- `tests/test_game_loop.gd` — `_test_title_lights_one_plate_at_a_time()` 신규 검증 추가
- `docs/BALANCE_NOTES.md` — 314행 §42 주장 정정 (MEDIUM-3) / 8행 기준 문서 v0.4 / §8.1 충돌 "해소됨" 한 줄
- `docs/DEV_ROADMAP.md` — 상단 기준 문서 v0.4 / F8 이월 4건 체크 / game_bg·btn_shop 확인 결과 신규 항목
- `docs/ORCHESTRATION_RULES.md` — 3절·4절 기준 문서 v0.3 → v0.4

**신규**

- `docs/JAMO_total_project_development_plan_v0.4.md`
- `tests/qa_f9_hover_focus.gd` / `tests/qa_f9_hover_focus.tscn`
- `tests/qa_artifacts/f9/hover_1..6_*.png` (6장)
- `tests/qa_artifacts/f9/DEV_HANDOFF_F9.md` (이 문서)

**이동 (삭제 아님)**

- `art/ui/focus_ring.png` → `art/_reference/focus_ring.png`
- `art/ui/focus_ring.png.import` 제거 — `art/_reference/.gdignore` 가 익스포트에서 뺀다.
  F8 에서 `title_ex.png` 를 처리한 방식과 동일하다.

**건드리지 않음**: `resources/**` (밸런스 무수정), `theme/jamo_theme.tres`,
`scenes/ui/title_screen.tscn`, `docs/JAMO_total_project_development_plan_v0.3.md` (이력 보존),
`tests/qa_artifacts/f8/**`.

---

## 2) 검수 절차

### A. 자동 — 완료 조건 그대로

| # | 명령 | 기대 결과 |
|---|---|---|
| 1 | `godot --headless --path . --quit` | `NotoSansKR-Regular.ttf` 누락 2줄 외 에러 0, exit 0 |
| 2 | `godot --headless --path . res://tests/test_game_loop.tscn` | `OK - all game loop checks passed.` exit 0 |
| 3 | `godot --headless --path . res://tests/test_day_flow.tscn` | `OK - day flow reached Day 2.` exit 0 |
| 4 | `md5sum tests/qa_artifacts/f8/sim_report.md` → `godot --headless --path . res://tests/sim_balance.tscn` → 다시 `md5sum` | 실행 전후 모두 `2a494b8e7a1c63906e270feba82f4740`. `OK - simulated Day 1..200.` |
| 5 | `godot --path . res://tests/qa_f7_title.tscn` (창 모드) | `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton` / `OK - title screen checks passed.` |
| 6 | `godot --path . res://tests/qa_f8_focus_all.tscn` (창 모드) | `OK - focus indicator meets 3.0:1 ...`, median 9.9~10.2:1, `the focus ring is back` 미출력 |
| 7 | `godot --path . res://tests/qa_f8_title_shots.tscn` (창 모드) | `OK - one selected plate at a time across 4 sizes.` / `plate height:` 4줄 전부 `nosave=67.0 save=67.0` |
| 8 | `godot --path . res://tests/qa_f9_hover_focus.tscn` (창 모드, **신규**) | 6줄 전부 `bright_plates=1`, 마지막 줄 `OK - one selected plate in every pointer/keyboard mix.` exit 0. 스크린샷 6장이 `tests/qa_artifacts/f9/` 에 새로 떨어진다 |

> 3번을 먼저 돌리면 `user://jamo_save.json` 이 남는다. 세이브 없는 화면을 볼 때는
> `%APPDATA%/Godot/app_userdata/JAMO/jamo_save.json` 을 먼저 지울 것.

### B. 실기동 — 호버와 포커스를 **서로 다른 버튼**에 두는 절차

9. 세이브 파일을 지우고 타이틀을 띄운다: `godot --path . res://scenes/ui/title_screen.tscn`
   → **기대**: 판때기 3개(`새 게임` / `설정` / `종료`), `새 게임` 하나만 크림색으로 밝다.
10. **마우스를 화면 구석(판때기 밖)으로 치우고** 키보드 `↓` 1회.
    → **기대**: `설정` 만 밝다. 밝은 판때기 총 **1개**.
11. **키보드에 손대지 말고** 포인터를 `종료` 판때기 위로 옮긴다.
    → **기대**: 강조가 `종료` 로 **옮겨간다**. `설정` 은 어두워진다. 총 **1개**.
    (이전 버전은 여기서 `설정`+`종료` **2개**가 밝았다 — MEDIUM-4 재현 지점)
12. **포인터를 `종료` 위에 그대로 둔 채** 키보드 `↑` 1회로 `설정` 으로 올라간다.
    → **기대**: `설정` 만 밝고, `종료` 는 마우스가 올라가 있는데도 **어둡다**. 총 **1개**.
    → 대조: `tests/qa_artifacts/f9/hover_3_keyboard_settings_pointer_left_on_quit.png`
13. 그 상태에서 포인터만 판때기 밖으로 뺀다.
    → **기대**: 변화 없음. `설정` 만 밝다.
14. 반대 방향 — 포인터를 `새 게임` 위로 올린다.
    → **기대**: 강조가 `새 게임` 으로 이동. 총 **1개**. 대조: `hover_5_pointer_moves_to_new_game.png`
15. `새 게임` 위에 포인터를 둔 채 키보드 `↓` 로 `종료` 까지 내려간다.
    → **기대**: `종료` 만 밝다. `새 게임` 은 포인터가 올라가 있어도 어둡다.
    → 대조: `hover_6_keyboard_quit_pointer_left_on_new_game.png`
16. 마우스로 `설정` 을 눌러 설정 패널을 연다. 패널이 열린 채로 포인터를 화면 아래쪽
    (패널 밖, 원래 `종료` 판때기 자리)으로 움직인다.
    → **기대**: 포커스가 패널 밖으로 끌려나가지 않는다(포커스 트랩 유지). `ESC` 또는 `닫기` 로
    나오면 `새 게임`(세이브 없음)에 포커스가 돌아온다.
17. 세이브를 만든다(`godot --headless --path . res://tests/test_day_flow.tscn`) → 타이틀 재기동.
    → **기대**: 판때기 4개 + `저장된 진행 — DAY n · m G` 한 줄, 진입 포커스 `이어하기`.
    10~15번을 `이어하기` 포함해 한 번 더 반복 — 어느 조합에서도 밝은 판때기는 **1개**.
18. `새 게임` 을 눌러 덮어쓰기 확인창을 띄운다. 창이 뜬 상태에서 포인터를 뒤쪽 타이틀 판때기 위로 옮긴다.
    → **기대**: `취소` 에 있던 포커스가 뒤쪽 판때기로 끌려가지 않는다. `ESC` 로 닫으면 타이틀로 포커스 복귀.
19. 상점 / 일시정지 / 단어 트리 / 자모 선택 화면의 갈색 사각 포커스 테두리를 본다.
    → **기대**: 타이틀 외 화면은 F8 그대로. 이번 변경은 `TitleButton` 변형만 건드린다.

### C. 문서

20. `sed -n '134,136p;314p' docs/BALANCE_NOTES.md`
    → **기대**: 314행에 `§42` 가 없다. `v0.3 §8.1 확정값. 2.5 % 로 낮추면 Day 200 이 2,820 → 408 HP …`
    로 바뀌어 134행의 철회 내용과 모순되지 않는다.
21. `grep -n "§42" docs/BALANCE_NOTES.md`
    → **기대**: 남은 인용이 전부 `Day 1 기본 Gold 2 G` 를 가리킨다. HP 성장률을 §42 에 귀속시키는 문장 **0건**.
22. `diff docs/JAMO_total_project_development_plan_v0.3.md docs/JAMO_total_project_development_plan_v0.4.md`
    → **기대**: 차이가 5덩어리뿐 — (a) 제목 v0.3→v0.4, (b) 상단 개정 안내 2줄, (c) §8.1 Gold `1.025`→`1.035`
    + 주석 1줄, (d) §41 1순위 v0.4 + 안내 2줄, (e) §42 앞 안내 문단 + 신규 §43 + 문서 버전 표기.
    **본문 그 외 차이 0.**
23. `grep -n "v0\.4" docs/DEV_ROADMAP.md docs/ORCHESTRATION_RULES.md`
    → **기대**: 로드맵 6행, 규칙 39행(§38)·58행(우선순위)이 v0.4 를 가리킨다.
24. `ls art/_reference/ art/ui/`
    → **기대**: `_reference/` 에 `.gdignore`, `focus_ring.png`, `title_ex.png`. `art/ui/` 에 `focus_ring*` 없음.
25. `grep -rn "focus_ring" --include=*.tscn --include=*.tres --include=*.gd . | grep -v qa_artifacts`
    → **기대**: **0건**.

---

## 3) 주의 / 보류 사항

- **MEDIUM-4 를 어느 쪽 우선으로 잡았는가 — 마우스 호버 우선.** 근거 둘. (1) 포인터를 판때기 위로
  옮기는 것은 의도적인 위치 지정이고, Enter/클릭이 가리키는 곳으로 가는 것이 사용자의 기대다.
  (2) 강조가 "가장 마지막에 쓴 입력장치" 를 따라가므로 두 장치를 섞어 써도 상태가 한 곳뿐이다.
  구현은 두 규칙이다 — 호버하면 그 버튼이 키보드 포커스를 가져가고(`_on_button_mouse_entered`),
  포커스가 없는 버튼은 호버 스타일을 평범한 판때기로 눌러 둔다(`_mute_hover`). 그래서 키보드가
  다른 버튼으로 걸어가면 포인터가 남아 있어도 그 자리는 어두워진다.
- **인계문(FIX3 3절)이 적은 "테마 한 줄" 은 채택하지 않았다.** `TitleButton/styles/hover` 를 평범한
  판때기로 돌리면 판때기 2개 문제는 없어지지만 **마우스 호버 피드백이 완전히 사라진다**(클릭 전까지
  아무 반응 없음). 위 방식은 호버 피드백을 유지하면서 강조를 1개로 만든다. 대가는 테마 0줄 /
  스크립트 약 25줄. **테마 파일(`theme/jamo_theme.tres`)은 한 글자도 바꾸지 않았고**, 스타일박스는
  전부 테마에서 읽어 쓴다(v0.3 §38).
- **링은 복원하지 않았다.** `SB_title_focus` 는 `StyleBoxEmpty` 그대로, `focus_ring` 참조 0건.
- **명도 대비 3.0:1 유지 확인.** `qa_f8_focus_all` median 9.94~10.12:1
  (기준값 `REQUIRED_CONTRAST = 3.0` 무수정). 포커스와 호버가 겹친 판때기는 테마 hover 의
  `modulate 1.12` 때문에 휘도가 0.92 → 0.98 로 살짝 더 밝다. 같은 크림 판때기의 밝기 차라
  "강조 2개" 로 보이지 않고, 포인터가 그 위에 있다는 추가 단서가 된다.
- **`qa_f8_hover_focus.tscn` 은 실행하지 말 것.** F8 당시 상태를 기록한 하네스이고
  `tests/qa_artifacts/f8/verify3/` 에 덮어쓴다. 지금 돌리면 2번째 줄이 `bright_plates=1` 로 나와
  F8 증거가 훼손된다. 후속 검증은 신규 `qa_f9_hover_focus.tscn` 을 쓴다.
  (F8 하네스는 이력이라 수정하지 않고 그대로 뒀다)
- **`tests/qa_f9_hover_focus.gd.uid` 가 아직 없다.** Godot Editor 로 프로젝트를 한 번 열면 자동
  생성된다. 손으로 만들면 UID 충돌 위험이 있어 만들지 않았다. 헤드리스/창 모드 실행에는 지장 없다
  (실측 통과).
- **미사용 에셋 확인 결과 — 이동하지 않음 (사용자 판단 대상).**
  - `art/ui/game_bg.png` (2.3 MB, uid `x2p0p7hi2ogn`) — **실제 미사용 확인.**
    `scenes/`·`theme/`·`resources/`·`scripts/` 전체에서 경로 참조 0건, uid 참조 0건.
    게임 화면 배경은 3D 씬이라 이 텍스처를 쓰지 않는다.
  - `art/ui/btn_shop.png` (483 KB, uid `geblijk0xnnu`) — **실제 미사용 확인.** 같은 방법으로 0건.
    상점 진입은 Day End 패널 버튼이고 아이콘 텍스처를 쓰지 않는다.
    (같은 폴더의 `btn_dictionary` / `btn_pause` / `btn_settings` 는 사용 중이다)
  - 확인 방법: 경로 grep + 각 `.import` 의 `uid=` 값을 `scenes|theme|resources|scripts` 의
    `uid://` 전체 목록과 대조.
  - 지시대로 **이번에는 옮기지 않았다.** `DEV_ROADMAP.md` 에 "F9 에서 확인만 하고 남긴 것" 으로 올려 뒀다.
- **BALANCE_NOTES 의 나머지 §42 인용은 정정하지 않았다.** 263행("네 값 모두 v0.3 §2·§8.1·§42-4 에
  못 박혀 있다")과 315행(`base_monster_hp` / `base_monster_gold` / `start_max_energy`)은 §42-4 를
  **`Day 1 기본 Gold 2 G`** 에 대해 인용하고 있어 v0.3 원문과 일치한다. 철회된 주장(HP 성장률을
  §42 에 귀속)의 반복이 아니므로 최소 범위 원칙에 따라 손대지 않았다. 다만 두 곳 다 세 상수를 한 묶음으로
  세 절에 귀속시키는 축약 표기라, 엄밀히 하려면 별도 지시가 필요하다.
- **v0.3 은 그대로 보존했다.** 삭제·수정 없음. v0.4 와의 차이는 §8.1 · 헤더 · §41 · §42 앞 안내 ·
  신규 §43 뿐이고 22번 절차로 기계적으로 확인할 수 있다.
- **밸런스 수치 무변경 증명.** `resources/**` diff 0. `sim_report.md` / `sim_metrics.json` md5 실행 전후 동일
  (`2a494b8e7a1c63906e270feba82f4740`).
- **신규 검증이 실제로 회귀를 잡는지 확인했다.** `_mute_hover` 를 일시적으로 무력화하고 돌리면
  `test_game_loop` 가 `lit ["NewGameButton", "SettingsButton"]` 식으로 6건 FAIL 하고 exit 1 이 된다.
  확인 후 되돌렸다.
- **이번 사이클 범위 밖 (그대로 이월):** HIGH-1 화상(DoT) 사멸, MEDIUM-2 상점 가격 열 천단위 구분자,
  F6 LOW 3건(`word_revealed` 미사용 시그널 경고 / 단어 완성 시 집결 자모 시인성 / burn ember·gold sparkle
  가독성 하한), `art/audio/sfx/` 빈 폴더, 30분 이상 실플레이 세션 미실시.
