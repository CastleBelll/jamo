# F8 DEV 인계문 (3차) — 타이틀 버튼 의미 정정 + 크기 축소

대상: F8-DEV-3 요구사항 1(텍스처 매핑 정정) / 2(크기 축소) / 3(포커스 대비 유지).
밸런스 수치는 하나도 건드리지 않았다. `sim_report.md` md5 `2a494b8e7a1c63906e270feba82f4740` 유지.
에셋 원본 `.png` 4장은 리사이즈·재저장하지 않았다 (`git status` 에 `art/ui/title/*.png` 없음).

---

## 1) 변경 파일 목록

**수정**
- `theme/jamo_theme.tres`
  - `[ext_resource]` 2줄 추가 — `title_active_button.png`(id `2_btn_selected`),
    `title_inactive_button.png`(id `3_btn_plain`)
  - `StyleBoxTexture` 5개 신규: `SB_title_normal` / `SB_title_selected` /
    `SB_title_hover` / `SB_title_pressed` / `SB_title_disabled`
    (전부 `content_margin` 28/8/28/8 — 씬에 있던 값 그대로 옮긴 것)
  - `TitleButton` 변형에 `styles/normal|hover|pressed|disabled|selected` 5개와
    `colors/font_color|font_hover_color|font_pressed_color|font_focus_color|font_disabled_color` 5개 추가
  - `TitleButton/font_sizes/font_size` **26 → 22**
  - `SB_title_focus`(2차 사이클의 2색 링)는 **한 줄도 건드리지 않았다**
  - 그 외 스타일박스(`SB_btn_*`, `SB_slot_*`, `SB_icon_*` 등) 무수정
- `scenes/ui/title_screen.tscn`
  - 버튼 4개의 `theme_override_styles/*` 16줄과 `SB_plate_*` 서브리소스 4개,
    버튼 텍스처 `ext_resource` 2개 **삭제** (전부 테마로 이동). `load_steps` 11 → 5
  - `%ContinueButton` 의 `theme_override_colors/font_disabled_color` 삭제 → 테마 변형이 담당
  - `Safe/Content/Logo` 앵커 `0.20/0.05/0.80/0.32` → **`0.22/0.07/0.78/0.31`**
  - `Safe/Content/Box` 앵커 `0.345/0.37/0.655/0.95` → **`0.385/0.43/0.615/0.89`**
  - `Box` 의 `separation` **6 → 10**
  - `%ContinueInfoLabel` 의 `autowrap_mode` 3(WORD_SMART) → 2(WORD)
- `scripts/ui/title_screen.gd`
  - `_bind_selection_plate()` / `_on_button_focus_entered()` / `_on_button_focus_exited()` 3개 추가
    (4장 첫 항목에 왜 스크립트가 필요했는지 적어 뒀다)
  - `_ready()` 에 버튼 4개를 도는 바인딩 루프 3줄
  - 세이브 없을 때의 안내 문구에 `\n` 1개 삽입 (문구 자체는 그대로)

**신규**
- `tests/qa_f8_title_shots.gd` / `.tscn` / `.gd.uid` — 4개 창 크기 스크린샷 + "강조는 항상 1개" 자동 검사
- `tests/qa_artifacts/f8/shots/` — PNG 44장
- `tests/qa_artifacts/f8/DEV_HANDOFF_F8_FIX2.md` — 이 문서

**무수정 확인**: `resources/**` 전부, `art/ui/title/*.png` 원본 4장, `art/ui/focus_ring.png`,
`tests/qa_f8_focus_all.gd`(6해상도 측정을 위해 `SIZES` 를 잠시 늘렸다가 **원본 그대로 복원**),
`tests/test_game_loop.gd`, `docs/**`.

---

## 2) 무엇을 어떤 비율로 바꿨나

### 매핑 (요구사항 1)

| 상태 | 텍스처 | 글자색 |
|---|---|---|
| `normal` (선택 안 됨) | `title_inactive_button.png` | 크림 `#F2E6CE` |
| `hover` (선택됨) | `title_active_button.png` (밝기 1.12) | 잉크 `#332921` |
| `focus` (선택됨) | `title_active_button.png` + 2색 링 | 잉크 |
| `pressed` (선택됨) | `title_active_button.png` (밝기 0.84) | 잉크 |
| `disabled` | `title_inactive_button.png` × `modulate 0.46/0.47/0.50` | 크림 |

실측 픽셀(1280×720, 판때기 중앙):
선택 `(247,223,192)` / 평상시 `(61,53,48)` / 비활성 `(26,23,22)`.

| 대비 | 값 |
|---|---:|
| 평상시 판때기 ↔ 선택 판때기 | **9.30 : 1** |
| 선택 판때기 위 잉크 글자 | 11.02 : 1 |
| 평상시 판때기 위 크림 글자 | 9.70 : 1 |
| 비활성 판때기 위 크림 글자 | 14.42 : 1 |
| 평상시 판때기 ↔ 비활성 판때기 | 1.49 : 1 (4장 참조) |

### 크기 (요구사항 2) — 전부 앵커 비율, 픽셀 하드코딩 없음

| 항목 | 이전 | 이후 | 변화 |
|---|---|---|---|
| `Box` 가로 앵커 폭 | 0.310 | **0.230** | −25.8 % |
| `Box` 세로 앵커 높이 | 0.580 | **0.460** | −20.7 % |
| `Logo` 앵커 폭 / 높이 | 0.60 / 0.27 | **0.56 / 0.24** | −6.7 % / −11.1 % |
| `separation` | 6 | **10** | +4 |
| `TitleButton` 글자 크기 | 26 | **22** | −15.4 % |

실측 버튼 1개(1280×720 캔버스 단위):

| | 이전 | 이후(세이브 없음) | 이후(세이브 있음) |
|---|---:|---:|---:|
| 크기 | 397 × 93 | **294 × 61** | **294 × 67** |
| 뷰포트 대비 | 31.0 % × 12.9 % | 23.0 % × 8.5 % | 23.0 % × 9.3 % |
| 면적 | 100 % | **49 %** | 54 % |

이전 높이 93은 F7 스크린샷 `tests/qa_artifacts/f7/title_1280x720.png` 에서 버튼 피치
99 px − separation 6 으로 실측한 값이다.

여백 균형(1280×720, 16:9 안전영역 720 기준): 위 여백 0.07 → 로고 → 간격 0.12 →
버튼 스택 → 아래 여백 0.11. 이전에는 아래 여백이 0.05 밖에 없어 스택이 바닥에 붙어 있었다.

### 포커스 대비 (요구사항 3) — 4버튼 × 6해상도 = 24조합 전부 통과

median, 단위 `:1`. 최저 **8.92** (이전 사이클 최저 3.51 → 2.5배 개선).

| 해상도 | 새 게임 | 이어하기 | 설정 | 종료 |
|---|---:|---:|---:|---:|
| 1280×720 | 10.22 | 10.10 | 9.24 | 9.08 |
| 1920×1080 | 10.15 | 9.92 | 9.25 | 9.20 |
| 2560×1080 | 10.15 | 10.03 | 9.60 | 9.13 |
| 1024×600 | 9.93 | 9.65 | 9.06 | **8.92** |
| 1600×900 | 9.93 | 9.84 | 9.14 | 9.05 |
| 3840×2160 | 10.23 | 10.13 | 9.43 | 9.32 |

값이 올라간 이유: 포커스가 링만이 아니라 **판때기 자체를 어두운 것에서 밝은 것으로 바꾸기**
때문이다. 선택 상태가 텍스처와 링 **두 채널**로 전달된다.

---

## 3) 검수 절차

### A. 정적 로드

1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 누락 **2건 외에 에러 0**, exit 0.

### B. 자동 테스트 5종 (전부 통과해야 함)

2. `godot --headless --path . res://tests/test_game_loop.tscn` → `OK - all game loop checks passed.`
3. `godot --headless --path . res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
4. `godot --headless --path . res://tests/qa_f7_title.tscn`
   → `OK - title screen checks passed.` /
     `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
5. `godot --headless --path . res://tests/sim_balance.tscn` → `OK - simulated Day 1..200.`
   → `md5sum tests/qa_artifacts/f8/sim_report.md` 가 `2a494b8e7a1c63906e270feba82f4740` 여야 한다
     (밸런스 무변경 증거).
6. `godot --path . res://tests/qa_f8_focus_all.tscn` (**창 모드**)
   → 마지막 줄 `OK - focus indicator meets 3.0:1 and the dialog fits its contents.`
   → 개별 median 이 전부 **≥ 3.0:1** (실측 최저 8.92). 세이브가 없으면
     `ContinueButton SKIPPED (disabled)` 가 뜨는 것이 정상이다.
7. `godot --path . res://tests/qa_f8_title_shots.tscn` (**창 모드**)
   → 마지막 줄 `OK - one selected plate at a time across 4 sizes.`
   → 중간 출력에 `selected plate: <버튼 이름>` 이 **매번 하나만** 찍히고,
     `nofocus_*` 줄에서는 `selected plate: <none>` 이 찍힌다.
     이것이 "강조된 버튼은 한 번에 하나" 를 코드로 못박은 검사다.
   → `tests/qa_artifacts/f8/shots/` 에 PNG 44장을 새로 쓴다.

### C. 【핵심】 선택 상태가 하나만 강조되는지 — 육안 + 조작

8. `godot --path .` 로 게임을 띄운다 (창 1280×720).
   → 기대: 판때기 4개 중 **`새 게임` 하나만** 밝은 크림 붓자국이고 흰+검은 링이 둘러져 있다.
     `이어하기` · `설정` · `종료` 는 **어두운 붓자국 + 크림 글자**다.
     (이전 빌드에서는 4개가 전부 밝은 붓자국이었다 — 그게 이번에 고친 버그다)
9. 키보드 **↓** 를 한 번 누른다.
   → 기대: `새 게임` 이 어두운 붓자국으로 **돌아가고**, `설정` 이 밝은 붓자국 + 링이 된다.
     동시에 밝은 판때기가 2개 보이면 **FAIL**이다.
10. **↓** 를 한 번 더, 그리고 **↑** 로 되돌린다.
    → 기대: 강조가 `종료` 로, 다시 `설정` 로 따라 움직인다. 항상 정확히 1개.
11. 마우스를 `종료` 위에 올린다 (키보드 포커스는 `설정` 에 둔 채).
    → 기대: `종료` 도 밝은 붓자국이 된다. **다만 링은 `설정` 에만 있다.**
      포인터 강조와 키보드 강조는 서로 다른 채널이고, Enter 가 눌리는 쪽은 **링이 있는 쪽**이다.
      (4장 세 번째 항목 참조 — 의도된 동작이다)
12. 마우스를 판때기 밖으로 뺀다.
    → 기대: `종료` 가 즉시 어두운 붓자국으로 돌아간다. 남는 강조 없음.
13. `설정` 을 마우스로 누른 채 유지한다.
    → 기대: 누르고 있는 동안 판때기가 약간 어두운 크림(pressed)으로 바뀌고, 떼면 패널이 열린다.
14. 패널을 닫는다(`닫기`).
    → 기대: 포커스가 타이틀로 돌아오고 `새 게임`(세이브 없음) 또는 `이어하기`(세이브 있음)
      **한 개만** 강조된다.

### D. 비활성 `이어하기`

15. 세이브가 없는 상태에서 타이틀을 본다.
    → 기대: `이어하기` 판때기가 나머지 셋보다 **눈에 띄게 더 어둡고 채도가 낮다**.
      글자는 크림색으로 또렷하게 읽힌다(14.42:1).
      바로 아래에 **`저장된 게임이 없어` / `이어하기를 할 수 없습니다.` 두 줄**이 그대로 있다.
      → 상태가 색만으로 전달되지 않는다는 근거가 이 문구다.
16. `↓` 로 포커스를 훑는다.
    → 기대: `이어하기` 는 **건너뛴다** (`새 게임` → `설정` → `종료`). 4번 테스트가 같은 것을 본다.
17. `새 게임` 으로 게임에 들어갔다 타이틀로 돌아온다(세이브 생성) → 다시 타이틀.
    → 기대: `이어하기` 가 평상시(어두운) 붓자국이 되고 **진입 포커스를 가져가** 밝은 붓자국 + 링이 된다.
      안내 문구가 `저장된 진행 — DAY n · m G` 한 줄로 바뀐다.

### E. 4개 창 크기 스크린샷 육안

18. 7번이 남긴 아래 파일들을 본다 (`tests/qa_artifacts/f8/shots/`).

    | 파일 | 봐야 할 것 |
    |---|---|
    | `idle_nosave_1280x720.png` | 평상시 화면. 밝은 판때기 1개(`새 게임`) |
    | `idle_nosave_1920x1080.png` | 위와 배치 동일 |
    | `idle_nosave_720x1280.png` | 세로형. 16:9 안전영역 중앙, 배치 동일 |
    | `idle_nosave_2560x1080.png` | 초광폭. 안전영역 중앙, 가로만 배경 확장 |
    | `focus_SettingsButton_nosave_*.png` | 강조가 `설정` 으로 이동, 나머지 3개 어두움 |
    | `focus_QuitButton_nosave_*.png` | 강조가 `종료` 로 이동 |
    | `focus_ContinueButton_save_*.png` | 세이브 있을 때 `이어하기` 강조 |
    | `nofocus_*.png` | 포커스 없음 — 판때기 4개가 **전부** 어두움 |

19. `variants/on_QuitButton_1280x720.png` 와 `off_QuitButton_1280x720.png` 를 나란히 본다
    (6번이 남긴다).
    → 기대: on 프레임에서 판때기가 밝아지고 **그 바깥에** 흰 띠 + 검은 띠가 한 겹씩.
      링과 밝은 판때기가 서로 덮지 않는다 — 링은 `expand_margin` 으로 버튼 rect **바깥**에만 그려진다.

### F. 회귀 (F1~F8 이 안 깨졌는지)

20. `새 게임` → 게임 진입 → `ESC` 일시정지 → `타이틀로` → 타이틀 복귀.
    → 기대: 게임 화면 버튼·단어 트리·상점 버튼의 모양이 **이전과 똑같다**
      (테마의 `Button` / `TreeSlot` / `HudIconButton` 은 손대지 않았다).
21. 세이브가 있는 상태에서 `새 게임` 을 누른다.
    → 기대: 덮어쓰기 확인창이 뜨고 **`취소` 에 포커스**가 잡혀 있다. `ESC` 로 닫으면
      타이틀 포커스가 돌아온다.

---

## 4) 주의 / 보류 사항

- **포커스에 스크립트를 한 조각 썼다.** Godot 의 `Button` 에는 "focused" 드로 모드가 없다
  (`BaseButton::get_draw_mode()` 는 disabled/pressed/hover/normal 만 돌려주고, `focus` 스타일박스는
  그 위에 덧그려진다). 그래서 `theme_override` 만으로는 **키보드 포커스에 선택 텍스처를 붙일 수 없다.**
  `title_screen.gd` 는 `focus_entered` 에서 테마에 이미 있는 `TitleButton/styles/selected` 를
  `normal` 슬롯에 얹고 `focus_exited` 에서 벗긴다. **StyleBox 를 GDScript 로 만들지 않는다** —
  5개 전부 `theme/jamo_theme.tres` 에 있고 Inspector 에서 수정 가능하다.
  "focus 도 선택 텍스처" 요구를 포기하면 이 3개 함수를 지우고 끝낼 수 있다. 그 경우 키보드
  포커스는 링만으로 전달되고 대비는 이전 사이클 수준(최저 3.51:1)으로 돌아간다.
- **`TitleButton/styles/selected` 는 Godot 표준 슬롯 이름이 아니다.** 엔진은 이 이름을 스스로
  그리지 않는다. 위 스크립트만 읽는다. 테마에서 이 항목을 지우면
  `get_theme_stylebox()` 가 에러를 찍고 기본 스타일로 떨어진다.
- **마우스 호버와 키보드 포커스가 다른 버튼에 있으면 밝은 판때기가 2개 보인다.** 요구사항의
  "한 번에 하나" 는 **링 기준으로** 지켰다 — 링은 언제나 1개다. 호버는 포인터를 따라가는
  일시적 채널이고 Enter 가 눌리는 쪽은 링이 있는 쪽이다. 이게 문제가 된다고 판단되면
  `TitleButton/styles/hover` 를 `SB_title_normal` 계열로 바꾸면 호버 강조가 사라진다
  (요구사항 1의 `hover = active` 와는 어긋난다).
- **평상시 ↔ 비활성 판때기 대비는 1.49:1 이다.** 원본 비활성 텍스처가 이미 거의 검정
  (평균 RGB 50,44,41)이라 더 어둡게 해도 대비가 늘지 않는다. WCAG 1.4.11 은 비활성
  컴포넌트를 대상에서 제외하고 있고, 상태는 **글자색(크림 14.42:1)과 아래 두 줄짜리 사유 문구**
  로 별도 전달된다. 색만으로 전달하지 않는다는 조건은 그 문구가 담당한다.
  더 벌리려면 비활성 판때기에 알파를 넣어 배경이 비치게 해야 하는데, 그러면 대비가
  배경 사진에 따라 달라져 결정론적으로 보장할 수 없다. 그래서 불투명하게 두었다.
- **안내 문구에 줄바꿈을 손으로 넣었다.** 스택이 좁아지면서(397 → 294) 한글이 음절 단위로
  꺾여 `…할 수 없습니 / 다.` 로 잘렸다. `autowrap_mode` 를 WORD 로 바꿔도 CJK 는 음절 사이가
  줄바꿈 지점이라 해결되지 않는다. 문구 자체는 한 글자도 바꾸지 않고 `\n` 하나만 넣었다.
- **글자 크기를 26 → 22 로 줄였다.** 판때기가 작아진 만큼 줄인 것이다. 1280×720 가상 좌표
  기준이고 창이 커지면 `canvas_items` 스트레치로 같이 커진다. 더 키우고 싶으면
  `TitleButton/font_sizes/font_size` 한 줄이다.
- **세로형(720×1280)에서는 버튼이 화면 높이의 2.9 % 밖에 안 된다.** 16:9 안전영역을
  화면 중앙에 맞추는 F7 설계 때문이고 이번 변경과 무관하다. 세로형을 실제로 지원할
  계획이 생기면 안전영역 정책부터 다시 잡아야 한다.
- **`tests/qa_f8_focus_all.gd` 는 원본 그대로 복원해 두었다** (`SIZES` 3개).
  위 24조합 표는 `SIZES` 에 `1024x600 / 1600x900 / 3840x2160` 을 임시로 더해 측정한 값이다.
  재현하려면 같은 3줄을 임시로 넣었다가 빼면 된다.
- **`test_day_flow` 는 실행 후 `user://jamo_save.json` 을 남긴다** (Day 2 · 8 G). 이번 변경과
  무관한 기존 동작이지만, 이 테스트 뒤에 타이틀을 띄우면 `이어하기` 가 활성으로 보인다.
  검수 중 헷갈리면 그 파일을 지우면 된다.
- **밸런스·업그레이드·단어 리소스는 전부 무수정.** `resources/**` 에 diff 없음.
