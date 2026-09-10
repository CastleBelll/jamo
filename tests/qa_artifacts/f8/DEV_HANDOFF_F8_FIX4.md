# F8 DEV 인계문 (5차) — 타이틀 판때기 높이 고정

대상: F8-DEV-5. 세이브 유무로 판때기 크기가 변하던 문제 1건.
밸런스 수치 무변경 — `tests/qa_artifacts/f8/sim_report.md` md5 `2a494b8e7a1c63906e270feba82f4740` 유지 (실측 확인).
포커스 사각 링은 되살리지 않았다. `이어하기` 는 세이브 없을 때 여전히 숨는다.

---

## 0) 무엇이 문제였고 무엇을 바꿨나

`Box`(VBoxContainer) 는 앵커로 높이가 고정돼 있고, 판때기 4개가 전부
`size_flags_vertical = 3`(EXPAND_FILL) 이었다. 즉 **판때기 높이 = (칸 높이 − 간격 − 라벨) ÷ 보이는 행 수**.
`이어하기` + 진행 라벨 2행이 빠지면 남은 3개가 그 공간을 나눠 가져 67 → 103 으로 커졌다.

바꾼 방식: 판때기를 **EXPAND 에서 빼고**, 높이를 **세이프에어리어 높이 × 비율**로 준다.
남는 공간은 `Box.alignment = 1`(가운데)이 위아래로 반씩 나눠 여백으로 남긴다.

- 나눗셈에 "보이는 행 수" 가 더 이상 들어가지 않으므로 **세이브 유무와 무관하게 같은 높이**다.
- 비율은 세이프에어리어(16:9 안전영역) 기준이라 **픽셀 하드코딩이 아니다.**
  프로젝트가 `canvas_items` 스트레치를 쓰므로 안전영역은 항상 1280×720 유닛이고,
  실제 화면 픽셀은 창 크기에 비례해 스케일된다. 기준 해상도를 바꾸면 판때기도 따라간다.
- 비율 `0.093` 은 **직전 '세이브 있음' 상태의 크기 그대로**다 (67 / 720 = 0.0931 → 67px).

---

## 1) 변경 파일 목록

**수정**
- `scenes/ui/title_screen.tscn`
  - `Box` 에 `alignment = 1` (BoxContainer 세로 가운데 정렬) 추가 — 남는 공간을 위아래로 반씩
  - `NewGameButton` / `ContinueButton` / `SettingsButton` / `QuitButton` 4개에서
    `size_flags_vertical = 3` **삭제** (기본값 FILL 로 복귀 = 최소 높이만 차지)
  - **앵커·separation·visible·텍스트·테마 변형은 한 줄도 안 건드렸다**
- `scripts/ui/title_screen.gd`
  - 신규 `@export_range(0.03, 0.25, 0.001) var plate_height_ratio: float = 0.093`
    — Inspector 에서 보이고 조정 가능. 판때기 높이 / 안전영역 높이
  - 신규 `@onready var _safe_area: Control = $Safe/Content`, `var _plates: Array[Button]`
  - 신규 `_apply_plate_height()` — `custom_minimum_size.y = roundf(안전영역 높이 × 비율)` 를 4개에 적용
  - `_ready()` — 기존 인라인 배열을 `_plates` 로 빼서 재사용, `_safe_area.resized` 에 연결 후 1회 호출
  - **`refresh()` / 포커스 / 판때기 텍스처 교체 로직은 무수정**
- `tests/test_game_loop.gd`
  - 신규 `_test_title_plates_keep_one_size_without_a_save()` — 실행 목록 마지막에 등록.
    세이브 없을 때 3개 높이 == 비율 계산값, 세이브 생성 후 4개 높이 == 세이브 없을 때 높이
  - 신규 헬퍼 `_settle_layout()` (4프레임 대기 — 최소 크기 변경은 다음 프레임에 재정렬된다)
- `tests/qa_f8_title_shots.gd`
  - `_report_geometry()` 가 창 크기별·상태별 판때기 높이를 `_plate_heights` 에 적재
  - 신규 `_check_plate_height_ignores_the_save()` — 해상도마다 nosave vs save 높이 차 > 1px 이면 **FAIL**

**갱신된 산출물**
- `tests/qa_artifacts/f8/shots/` PNG 44장 (8장의 `idle_*` 포함, 새 배치로 덮어씀)

**신규**
- `tests/qa_artifacts/f8/DEV_HANDOFF_F8_FIX4.md` — 이 문서

**무수정 확인**: `theme/jamo_theme.tres`(이번 사이클 diff 없음), `resources/**` 전부, `art/**` 전부,
`docs/**`, `tests/sim_balance.gd`, `tests/qa_f7_title.gd`, `tests/qa_f8_focus_all.gd`.

---

## 2) 검수 절차

### A. 정적 로드

1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 누락 2건 **외에 에러 0**, exit 0.

### B. 자동 테스트 (전부 통과해야 함)

2. `godot --headless --path . res://tests/test_game_loop.tscn` → `OK - all game loop checks passed.`
   (여기에 신규 "세이브 유무로 판때기 높이가 안 변한다" 검사가 들어 있다)
3. `godot --headless --path . res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
4. `godot --headless --path . res://tests/qa_f7_title.tscn` → `OK - title screen checks passed.`
   / `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
5. `godot --headless --path . res://tests/sim_balance.tscn` → `OK - simulated Day 1..200.`
   → `md5sum tests/qa_artifacts/f8/sim_report.md` 가 `2a494b8e7a1c63906e270feba82f4740`
6. `godot --path . res://tests/qa_f8_title_shots.tscn` (**창 모드**)
   → 마지막 줄 `OK - one selected plate at a time across 4 sizes.`
   → **`--- ` 줄 8개의 `button=` 이 전부 `294x67`** (아래 5절 표와 대조)
   → **`plate height:` 줄 4개가 전부 `nosave=67.0 save=67.0`**
     (다르면 `FAIL: <크기> plate is ... tall without a save and ... with one` 이 뜬다)
7. `godot --path . res://tests/qa_f8_focus_all.tscn` (**창 모드**, 세이브 없는 상태)
   → 마지막 줄 `OK - focus indicator meets 3.0:1 and the dialog fits its contents.`
   → 각 줄 median **≥ 3.0:1**. DEV 실측 9.88 ~ 10.12
   → `the focus ring is back` 가 뜨면 링이 되살아난 것 (DEV 실측: 안 뜬다)
8. **세이브를 만들고 7번을 다시 돌린다** (`이어하기` 까지 4개 재려면 필요)
   → DEV 실측 12조합 전부 **9.90 ~ 10.08 : 1**, `ContinueButton` 도 SKIPPED 되지 않는다

### C. 【핵심】 세이브 유무로 판때기가 안 커지는가 — 육안

9. 세이브 파일을 지운 상태에서 `godot --path .` (창 1280×720).
   → 기대: 판때기 3개(`새 게임` 크림 / `설정` / `종료`)가 **로고 아래 세로 가운데**에 모여 있다.
     3개가 서로 붙어 있고 **중간에 빈 구멍이 없다.** 위아래로만 여백이 남는다.
10. `새 게임` → 게임 진입 → `ESC` → `타이틀로` (세이브 생성).
    → 기대: 판때기가 4개 + 진행 라벨 1줄로 늘어난다.
      **9번에서 본 판때기와 세로 두께가 똑같다.** 커지거나 작아지면 FAIL.
11. 9번과 10번 화면을 번갈아 보며 `새 게임` 판때기 하나만 비교한다.
    → 기대: 폭도 두께도 동일. 위치만 조금 위로 올라간다(행이 늘었으므로).
12. `tests/qa_artifacts/f8/shots/idle_nosave_1920x1080.png` 와 `idle_save_1920x1080.png`
    를 나란히 놓고 `설정` 판때기 두께를 비교한다.
    → 기대: 두께 동일. 1280x720 / 720x1280 / 2560x1080 의 같은 쌍도 마찬가지.
13. 창을 마우스로 잡아 늘렸다 줄였다 해 본다.
    → 기대: 판때기가 창에 비례해 커지고 작아진다. 특정 픽셀에 고정돼 있지 않다.

### D. 회귀 — 직전 사이클(F8-4)에서 지킨 것들이 그대로인가

14. 9번 화면에서 `↓` 3번, `↑` 3번.
    → 기대: `새 게임 → 설정 → 종료` 순환. 빈 자리에 멈추는 스텝 없음. 강조 판때기는 항상 1개.
15. 판때기 테두리 바깥을 본다.
    → 기대: 흰 띠·검은 띠 **없음**. 선택은 판때기 색(크림 ↔ 어두운 회녹)으로만 구분된다.
16. 10번 상태에서 `↓` 를 돌린다.
    → 기대: `새 게임 → 이어하기 → 설정 → 종료` 를 건너뛰지 않고 밟는다.
17. 상점 / 일시정지 / 단어 트리 / 자모 선택 화면에서 `Tab`·화살표로 포커스를 옮긴다.
    → 기대: **기존 갈색 사각 테두리 그대로.** 하나라도 사라졌으면 FAIL.
18. 세이브가 있는 상태에서 `새 게임` → 덮어쓰기 확인창, **`취소` 에 포커스**. `ESC` 로 닫으면
    타이틀 포커스 복귀. `설정` 열고 닫으면 포커스가 타이틀 버튼으로 돌아온다.

---

## 3) 주의 / 보류 사항

- **세이브가 없을 때 판때기 스택이 55px(1280×720 유닛 기준) 아래로 내려간다.**
  `box_top` 실측: 세이브 있음 310 / 없음 365. 남는 공간을 위아래로 반씩 나눠 가운데 정렬한
  결과이고 의도한 동작이다. 즉 **로고~첫 판때기 간격이 세이브 없을 때 더 넓다**(223→365, 142px
  vs 87px). 스택의 세로 중심은 두 상태 모두 `Box` 중심(안전영역 높이의 66%)으로 동일해서
  화면을 오갈 때 메뉴가 튀지 않는다. 위쪽에 붙이고 아래로만 여백을 남기길 원하면
  씬에서 `Box.alignment` 을 `1` → `0` 으로 바꾸면 된다(한 줄, 스크립트 무관).
- **높이가 이제 스크립트에서 계산된다.** `.tscn` 에 픽셀을 적을 수단이 없어서
  (`custom_minimum_size` 는 상수 픽셀이라 비율 요구를 못 지킨다) `_apply_plate_height()` 가
  `안전영역 높이 × plate_height_ratio` 를 넣는다. **노드를 만들지는 않는다** — 씬에 이미 있는
  4개 버튼의 최소 높이만 넣는다. 비율은 `@export_range` 라 Inspector 에서 조정 가능하다.
  크기를 다시 줄이라는 지시가 오면 **이 값 하나만** 바꾸면 된다.
- **최소 높이 하한은 테마가 정한다.** 판때기 최소 높이는 폰트(22) + `SB_title_*` 의
  `content_margin_top/bottom`(8/8) 로 약 48px 이다. 안전영역이 아주 작아져 비율 계산값이
  48 아래로 내려가면 그 아래로는 안 줄어든다. 4개 검수 해상도는 전부 67 이라 해당 없다.
- **`Box` 의 앵커 높이(0.43~0.89)는 그대로 뒀다.** 세이브 있음 상태의 내용 높이
  (4×67 + 라벨 23 + 간격 40 = 331) 가 칸 높이(0.46×720 = 331) 와 거의 정확히 같아서
  여유가 사실상 0 이다. **판때기를 지금보다 키우면 `Box` 가 앵커 아래로 넘친다**(뷰포트 안에는
  남지만 0.89 선을 넘는다). 키우는 지시가 오면 `anchor_bottom` 도 같이 손봐야 한다.
- **`plate_height_ratio` 의 기준은 뷰포트가 아니라 안전영역이다.** 세로 창(720×1280)에서
  뷰포트는 1280×2275 로 늘어나지만 16:9 안전영역은 1280×720 유닛으로 유지되므로,
  세로 화면에서도 판때기는 67 이다. 뷰포트 기준으로 재면 세로에서 판때기가 3배로 커진다.
- **접근성 상태는 직전 사이클과 동일하다.** 선택 표시는 여전히 판때기 텍스처 교체 하나이고
  명도 대비 재측정 결과 **세이브 없음 9.88~10.12:1 / 세이브 있음 9.90~10.08:1** 로
  전 조합 3.0:1 기준을 만족한다. 호버와 포커스가 구분되지 않는 문제(4차 인계문 참조)는
  이번 범위 밖이라 그대로 남아 있다.
- **`test_day_flow` 는 실행 후 `user://jamo_save.json` 을 남길 수 있다**(기존 동작).
  9번(세이브 없는 화면) 검수 전에는 그 파일을 먼저 지울 것.
- **밸런스·업그레이드·단어 리소스 전부 무수정.** `resources/**` 에 이번 사이클 diff 없음.

---

## 4) 실측치 (변경 후)

`godot --path . res://tests/qa_f8_title_shots.tscn` 출력.

| 창 크기 | 뷰포트(유닛) | 판때기 (세이브 없음) | 판때기 (세이브 있음) | box_top 없음/있음 |
|---|---|---|---|---|
| 1280×720 | 1280×720 | **294×67** | **294×67** | 365 / 310 |
| 1920×1080 | 1280×720 | **294×67** | **294×67** | 365 / 310 |
| 720×1280 | 1280×2275 | **294×67** | **294×67** | 1142 / 1087 |
| 2560×1080 | 1706×720 | **294×67** | **294×67** | 365 / 310 |

변경 전에는 세이브 없음이 전부 `294×103` 이었다. 8장 전부에서 높이 차 **0.0px**.
