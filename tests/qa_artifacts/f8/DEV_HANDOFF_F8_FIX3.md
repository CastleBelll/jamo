# F8 DEV 인계문 (4차) — 이어하기 숨김 + 포커스 사각 링 제거

대상: F8-DEV-4 사용자 직접 지시 2건.
밸런스 수치 무변경 — `tests/qa_artifacts/f8/sim_report.md` md5 `2a494b8e7a1c63906e270feba82f4740` 유지.
`art/ui/focus_ring.png` 은 **지우지 않았다** (참조만 끊었다).

---

## 1) 변경 파일 목록

**수정**
- `scripts/ui/title_screen.gd`
  - `refresh()` — `_continue_button.visible` / `_continue_info.visible` 두 줄 추가.
    세이브 없으면 둘 다 `false`. `disabled` / `focus_mode` 기존 로직은 그대로 유지
  - 세이브 없을 때 쓰던 `_continue_info.text = "저장된 게임이 없어\n…"` **삭제**
    (라벨이 화면에 없으므로 표시될 곳이 없다)
  - `_bind_selection_plate()` 문서 주석에서 "링" 언급 제거
- `scenes/ui/title_screen.tscn`
  - `%ContinueButton` / `%ContinueInfoLabel` 에 `visible = false` 추가
    (세이브 없는 상태 = 씬 기본 상태. `_ready()` 의 `refresh()` 가 세이브 있으면 켠다)
  - `%ContinueInfoLabel` 의 디자인타임 `text` 를 `"저장된 게임이 없습니다."` →
    `"저장된 진행 — DAY 1 · 0 G"` 로 교체 (이제 이 라벨은 세이브 있을 때만 그려진다)
  - **앵커·separation·size_flags 는 한 줄도 안 건드렸다**
- `theme/jamo_theme.tres`
  - `SB_title_focus` : `StyleBoxTexture`(2색 링) → **`StyleBoxEmpty`**.
    `content_margin` 16/9/16/9 은 그대로 남겨 버튼 최소 크기 계산이 변하지 않게 했다
  - `[ext_resource] focus_ring.png` 1줄 삭제
  - `Button/styles/focus`(`SB_btn_focus`) · `HudIconButton/styles/focus`(`SB_icon_focus`) ·
    `TreeSlot/styles/focus`(`SB_slot_focus`) **무수정** — 상점/일시정지/자모 선택/단어 트리
    포커스 표시는 그대로다
- `tests/test_game_loop.gd`
  - `_test_title_disables_continue_without_a_save` → **`_test_title_hides_continue_without_a_save`**
    로 이름 변경. 검증을 "비활성 + 사유 문구 있음" → "버튼·라벨 둘 다 `visible == false`" 로 교체
  - `_test_disabled_continue_leaves_the_focus_chain` → **`_test_hidden_continue_leaves_the_focus_chain`**.
    포커스 체인을 끝까지 걸어서 `ContinueButton` 이 **한 번도 안 나오는지** 확인하는 검사 추가
  - 신규 헬퍼 2개: `_walk_focus_chain()`(↓ 로 닿는 노드 이름 수집, 8스텝 상한) /
    `_check_remaining_stack_is_intact()`(남은 행들의 간격 = 테마 separation, 좌표·폭 일치)
- `tests/qa_f8_focus_all.gd` — **무엇을 재는지 바뀌었다. 아래 3절 첫 항목 참조**
  - 측정 영역: 버튼 rect + 바깥 12px → **버튼 rect 자체**(`_search_rect(..., 0.0)`)
  - 신규 `_report_no_outline()` — rect 바깥 2~12px 띠에서 변한 픽셀 수를 세고 **0이 아니면 FAIL**.
    "링이 다시 생기면 테스트가 깨진다" 를 코드로 못박은 것
  - 세이브 없을 때 `ContinueButton` 스킵 조건에 `not button.visible` 추가
    (숨은 컨트롤에 `grab_focus()` 하면 에러)
  - **`REQUIRED_CONTRAST` 3.0 은 그대로다. 기준을 낮추지 않았다**
- `tests/qa_f8_title_shots.gd`
  - `_report_geometry()` 가 숨은 행을 건너뛰고, 남은 행들의 **간격·좌표·폭 일치**를
    4개 해상도 × 세이브 유/무 모두에서 검사하도록 확장

**신규**
- `tests/qa_artifacts/f8/DEV_HANDOFF_F8_FIX3.md` — 이 문서

**갱신된 산출물**
- `tests/qa_artifacts/f8/shots/` PNG 40장 (링 없는 새 프레임으로 덮어씀)
- `tests/qa_artifacts/f8/variants/` PNG (같은 이유)

**무수정 확인**: `resources/**` 전부, `art/**` 전부(`focus_ring.png` 포함 — 파일은 남아 있다),
`docs/**`, `tests/sim_balance.gd`, `tests/qa_f7_title.gd`, 그 외 테마의 모든 스타일박스.

---

## 2) 검수 절차

### A. 정적 로드

1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 누락 2건 **외에 에러 0**, exit 0.
     (링 텍스처 참조를 끊었는데도 테마 파싱이 깨지지 않는다는 뜻)

### B. 자동 테스트 (전부 통과해야 함)

2. `godot --headless --path . res://tests/test_game_loop.tscn`
   → 기대: `OK - all game loop checks passed.`
     (여기에 "세이브 없으면 이어하기 숨김" / "포커스 체인이 숨은 버튼을 안 밟음" /
      "남은 버튼 간격 유지" 검사가 들어 있다)
3. `godot --headless --path . res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
4. `godot --headless --path . res://tests/qa_f7_title.tscn`
   → `OK - title screen checks passed.` /
     `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
5. `godot --headless --path . res://tests/sim_balance.tscn` → `OK - simulated Day 1..200.`
   → `md5sum tests/qa_artifacts/f8/sim_report.md` 가 `2a494b8e7a1c63906e270feba82f4740`
     (밸런스 무변경 증거)
6. `godot --path . res://tests/qa_f8_focus_all.tscn` (**창 모드**)
   → 마지막 줄 `OK - focus indicator meets 3.0:1 and the dialog fits its contents.`
   → 각 줄 median 이 전부 **≥ 3.0:1**. DEV 실측(세이브 없음): 9.91 ~ 10.17
   → `ContinueButton SKIPPED (no save)` 는 세이브 없을 때 **정상**
   → **FAIL 메시지에 `the focus ring is back` 이 뜨면 링이 되살아난 것이다.**
     DEV 실측에서는 버튼 바깥 띠의 변경 픽셀이 **0개**였다
7. **세이브를 만들고 6번을 다시 돌린다** — `이어하기` 까지 4개 전부 재려면 필요하다
   a. `godot --path .` → `새 게임` → 게임 진입 → `ESC` → `타이틀로` → 창 닫기
   b. `godot --path . res://tests/qa_f8_focus_all.tscn`
   → 기대: `ContinueButton` 이 SKIPPED 되지 않고 median 이 찍힌다.
     DEV 실측 12조합(3해상도 × 4버튼) 전부 **9.90 ~ 10.08 : 1**
8. `godot --path . res://tests/qa_f8_title_shots.tscn` (**창 모드**)
   → 마지막 줄 `OK - one selected plate at a time across 4 sizes.`
   → `nosave_*` 줄에는 `selected plate:` 가 `NewGameButton / SettingsButton / QuitButton /
     <none>` **4줄만** (ContinueButton 이 아예 안 나온다),
     `save_*` 줄에는 `ContinueButton` 이 포함된 **5줄**이 찍힌다
   → 간격/정렬이 어긋나면 `gap ...->... is ..., want 10` 또는 `is not aligned with` FAIL 이 뜬다

### C. 【핵심 1】 세이브가 없으면 이어하기가 사라지는가 — 육안 + 조작

9. 세이브 파일을 지운 상태에서 `godot --path .` (창 1280×720).
   → 기대: 판때기가 **3개**다 — `새 게임`(밝은 크림) / `설정`(어두움) / `종료`(어두움).
     `이어하기` 판때기도, 그 아래 `저장된 게임이 없어…` 두 줄도 **화면에 없다.**
     3개가 로고 아래 한 열로 균등 간격으로 서 있다.
10. `↓` 를 세 번, `↑` 를 세 번 눌러 본다.
    → 기대: 강조가 `새 게임 → 설정 → 종료` 순환. **빈 자리에 멈추는 스텝이 한 번도 없다.**
      강조된 판때기는 언제나 정확히 1개.
11. `Tab` 으로도 같은 순서를 돈다.
    → 기대: 10번과 동일. 안 보이는 곳에 포커스가 가면 FAIL.
12. `새 게임` → 게임 진입 → `ESC` → `타이틀로` 로 타이틀에 돌아온다 (세이브 생성됨).
    → 기대: 판때기가 **4개**로 늘고 `이어하기` 가 두 번째 자리에 나타난다.
      바로 아래 `저장된 진행 — DAY 1 · 0 G` 한 줄이 같이 나타난다.
      진입 포커스가 `이어하기` 에 잡혀 밝은 크림 판때기가 된다.
13. 12번 상태에서 `↓` 를 돌려 본다.
    → 기대: `이어하기` 를 **건너뛰지 않고** 순서대로 밟는다
      (`새 게임 → 이어하기 → 설정 → 종료`).

### D. 【핵심 2】 포커스 사각 박스가 사라졌는가

14. 9번 화면에서 `새 게임` 판때기의 **테두리 바깥**을 본다.
    → 기대: 흰 띠도 검은 띠도 **없다.** 판때기 붓자국 가장자리가 바로 배경과 만난다.
      선택 여부는 판때기 색(크림 ↔ 어두운 회녹)으로만 구분된다.
15. `↓` 로 강조를 옮기며 각 버튼 주변을 본다.
    → 기대: 어느 버튼에서도 사각 테두리가 그려지지 않는다. 색만 바뀐다.
16. `tests/qa_artifacts/f8/variants/on_QuitButton_1280x720.png` 와
    `off_QuitButton_1280x720.png` 를 나란히 본다.
    → 기대: 판때기 안쪽 색만 다르고 **버튼 바깥 영역은 두 이미지가 완전히 동일**하다.
      (6번의 `_report_no_outline` 이 이걸 픽셀 단위로 세서 0을 확인한다)

### E. 【핵심 3】 다른 화면의 포커스 표시가 살아 있는가 — 회귀

17. `새 게임` → 게임 진입 → 상단 `상점` 버튼을 연다. `Tab`/`↓` 로 포커스를 옮긴다.
    → 기대: 상점 버튼·슬롯에 **기존과 똑같은 갈색 사각 테두리**가 그대로 보인다.
      여기는 손대지 않았다.
18. `ESC` 로 일시정지 패널을 연다. `Tab` 으로 버튼을 돈다.
    → 기대: 기존과 동일한 포커스 테두리.
19. 단어 트리(도감) 패널을 열고 슬롯 사이를 키보드로 이동한다.
    → 기대: `TreeSlot` 포커스 테두리 그대로.
20. Day 종료 후 자모 선택 화면에서 키보드로 후보를 옮긴다.
    → 기대: 포커스 테두리 그대로.
    → 17~20 중 **하나라도 포커스 표시가 사라졌으면 FAIL** (그건 타이틀 전용이어야 할
      변경이 새어 나간 것이다).

### F. 회귀 (F1~F8)

21. 세이브가 있는 상태에서 `새 게임` 을 누른다.
    → 기대: 덮어쓰기 확인창이 뜨고 **`취소` 에 포커스**. `ESC` 로 닫으면 타이틀 포커스 복귀.
22. 21번에서 `새로 시작` 을 누른다.
    → 기대: 세이브가 지워지고 게임이 Day 1 로 시작한다. 이후 타이틀로 돌아오면
      `이어하기` 는 다시 나타난다(방금 돌아오면서 저장됐으므로).
23. `설정` 을 열고 슬라이더를 조작한 뒤 `닫기`.
    → 기대: 패널 안에서 포커스가 갇히고(밖으로 안 나감), 닫으면 타이틀 버튼 하나에
      포커스가 돌아온다. 세이브 없으면 `새 게임`, 있으면 `이어하기`.
24. 4개 해상도 스크린샷을 본다 — `tests/qa_artifacts/f8/shots/`

    | 파일 | 봐야 할 것 |
    |---|---|
    | `idle_nosave_1280x720.png` | 판때기 3개, 링 없음, `새 게임` 만 크림 |
    | `idle_nosave_1920x1080.png` | 위와 배치 동일 |
    | `idle_nosave_720x1280.png` | 세로형. 16:9 안전영역 중앙, 배치 동일 |
    | `idle_nosave_2560x1080.png` | 초광폭. 안전영역 중앙 |
    | `idle_save_*.png` (4장) | 판때기 4개 + 진행 라벨 1줄, `이어하기` 만 크림 |
    | `focus_*_nosave_*.png` | 강조가 옮겨가도 어디에도 사각 테두리 없음 |
    | `nofocus_*.png` | 판때기 전부 어두움 |

---

## 3) 주의 / 보류 사항

- **【필독】 `qa_f8_focus_all` 이 재는 대상이 바뀌었다.** 3차까지는 "버튼 rect + 바깥 12px"
  에서 변한 픽셀을 봤고, 그 변화에는 **링과 판때기 두 채널**이 섞여 있었다(최저 8.92:1).
  링이 없어졌으므로 이제 **판때기 텍스처 교체 하나만** 재도록 측정 영역을 버튼 rect 로
  좁혔다. 기준값 `REQUIRED_CONTRAST = 3.0` 은 **손대지 않았다.**
  실측: 세이브 없음 9.91~10.17:1 / 세이브 있음(4버튼×3해상도) 9.90~10.08:1.
  3차의 8.92 와 직접 비교할 수 없는 값이다 — 재는 영역이 다르기 때문이고, 링이 있던
  바깥 띠(대비가 낮게 깔리던 구간)가 빠져서 오히려 median 이 올라갔다.
  같이 넣은 `_report_no_outline` 이 "바깥에서 변한 픽셀 = 0" 을 **FAIL 조건으로** 감시한다.
- **접근성 — 포커스 표시가 이제 텍스처 교체 하나에만 의존한다.** 이것이 이번 변경의
  유일한 실질적 접근성 후퇴다. 구체적으로:
  - **WCAG 2.2 SC 2.4.11 / 2.4.13** 관점에서 대비 자체는 문제없다. 명도 대비 **9.90:1 이상**
    이고 변화 면적이 버튼 rect 전체라, 2.4.13 의 "2px 두께 외곽선에 상당하는 면적" 요건을
    면적으로는 크게 넘어선다.
  - **다만 정보 채널이 2개(링 + 판때기)에서 1개(판때기)로 줄었다.** 3차 인계문에 적었듯
    링은 "판때기가 이미 밝은 배경 위에 있을 때" 를 대비한 이중화였다. 지금 타이틀 배경은
    사진이고 밝은 나무 바닥 위에도 판때기가 놓인다. **선택 판때기(크림)와 배경이 비슷해
    보이는 지점이 배경 아트를 바꾸면 생길 수 있다.** 단, 선택/비선택 판때기 **서로 간의**
    대비 9.90:1 은 배경과 무관하게 유지된다(둘 다 불투명 텍스처).
  - **색만으로 전달하는가?** 아니다 — 크림↔어두운 회녹은 색상 차이가 아니라 **명도 차**이고
    (9.90:1) 흑백으로 출력해도 구분된다. 색각 이상 사용자에게 문제되지 않는다.
  - **호버와 포커스가 더 이상 구분되지 않는다.** 3차에서는 링 유무로 갈렸는데 링이 없어져,
    마우스를 다른 버튼에 올려두면 **밝은 판때기가 2개 보이고 Enter 가 어디로 갈지 화면상
    구분이 사라진다.** 이번 지시 범위 밖이라 그대로 뒀다. 문제가 되면
    `TitleButton/styles/hover` 를 `SB_title_normal` 계열로 돌리면(테마 한 줄) 호버 강조가
    사라지고 밝은 판때기는 항상 1개가 된다.
  - **되돌리는 법**: `SB_title_focus` 를 `StyleBoxEmpty` → `StyleBoxTexture` 로 되돌리고
    `focus_ring.png` `ext_resource` 를 복구하면 끝이다. 파일은 지우지 않았다.
- **`art/ui/focus_ring.png` 은 이제 어디서도 참조되지 않는다.** 지시대로 파일과 `.import` 은
  그대로 뒀다. 리포에 남은 미사용 에셋이므로 "왜 있는지" 를 아는 사람이 없어지기 전에
  이 문단을 근거로 남긴다. 되살릴 파라미터는 2차 인계문과 `docs/BALANCE_NOTES.md` 8장에 있다.
- **세이브 없을 때 버튼이 커진다 — 103px vs 67px (1280×720 기준).** `Box` 는 앵커로 높이가
  고정돼 있고 버튼이 `size_flags_vertical = 3`(EXPAND_FILL) 이라, 행이 2개(버튼+라벨)
  빠지면 남은 3개가 그 공간을 나눠 갖는다. 실측:
  세이브 없음 **294×103**(뷰포트의 23.0% × 14.3%) / 세이브 있음 **294×67**(23.0% × 9.3%).
  간격·좌우 정렬·중앙 배치는 4개 해상도 전부에서 유지된다(8번 테스트가 검사한다).
  **다만 3차에서 "버튼이 크다" 는 지시로 93 → 61 까지 줄였는데, 세이브 없는 화면에서는
  103 으로 그때보다 커졌다.** 두 상태를 동시에 볼 일은 없어 보기에 어색하지는 않지만
  (24번 스크린샷 참조), 크기를 두 상태에서 똑같이 맞추라는 지시가 나오면 그건 레이아웃
  모델 변경이라 이번 범위에 넣지 않았다. 그때는 `Box` 를 `alignment = 1`(가운데)로 두고
  버튼의 `size_flags_vertical` 을 EXPAND 에서 빼고, 높이를 `SB_title_*` 의
  `content_margin_top/bottom`(현재 8)으로 주는 방식이 맞다 — 전부 씬/테마 값이고
  스크립트 픽셀 하드코딩이 아니다.
- **`SB_title_focus` 를 지우지 않고 `StyleBoxEmpty` 로 바꾼 이유.** 항목을 통째로 지우면
  `TitleButton` 이 `base_type = Button` 을 타고 `Button/styles/focus`(`SB_btn_focus`,
  갈색 사각 테두리)로 **떨어져서 오히려 다른 사각 박스가 그려진다.** 빈 스타일박스로
  덮어써야 아무것도 안 그려진다. `content_margin` 16/9/16/9 을 그대로 남긴 것은
  이 값이 버튼 최소 크기 계산에 들어갈 경우를 대비해 기하를 고정하기 위해서다.
- **씬의 기본 상태가 "세이브 없음" 이다.** `%ContinueButton` / `%ContinueInfoLabel` 이
  `visible = false` 로 저장돼 있어 **Godot Editor 에서 타이틀 씬을 열면 두 노드가 안 보인다.**
  Scene 독의 눈 아이콘으로 켜서 편집하면 되고, 런타임에는 `refresh()` 가 세이브를 보고
  다시 결정하므로 에디터에서 켜 둔 채 저장해도 게임 동작은 바뀌지 않는다.
- **`disabled` 플래그를 남겨 뒀다.** 숨긴 이상 중복이지만 `focus_default_button()` 과
  `_test_returning_to_the_title_saves` 가 `disabled` 를 읽는다. 지우면 그쪽까지 건드려야
  해서 범위를 넘는다고 판단했다.
- **`test_day_flow` 는 실행 후 `user://jamo_save.json` 을 남길 수 있다** (기존 동작).
  이 테스트 뒤에 타이틀을 띄우면 `이어하기` 가 보이는 것이 정상이다. 9번(세이브 없는
  화면) 을 검수할 때는 그 파일을 먼저 지울 것.
- **밸런스·업그레이드·단어 리소스 전부 무수정.** `resources/**` 에 diff 없음.
