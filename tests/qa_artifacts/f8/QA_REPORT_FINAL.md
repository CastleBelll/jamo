# F8 최종 QA 리포트 — 타이틀 3차 변경 + 밸런싱 + 전체 회귀

판정: **PASS**

작성 2026-09-10 · 대상 `DEV_HANDOFF_F8_FIX4.md`(5차, 1차 기준) + FIX3 / FIX2 / FIX 누적
검증 Godot 4.7.stable.official.5b4e0cb0f · Intel UHD 770 / Vulkan Forward+
창 모드 CLI 실행 + ziva-godot MCP 실플레이 · 기준 문서 우선순위 v0.3 > growth_balance v0.2 (v0.3 §41)

**기존 `QA_REPORT.md` / `QA_REPORT_2.md` 는 덮어쓰지 않았다.** 이 문서는 신규 파일이다.

| # | 심각도 | 내용 | 상태 |
|---|---|---|---|
| MEDIUM-3 | MEDIUM | `docs/BALANCE_NOTES.md:314` 이 134행에서 철회한 주장을 그대로 반복 | **미해결 — 재확인함 (5-5절)** |
| MEDIUM-4 | MEDIUM | 링 제거로 호버와 키보드 포커스가 구분되지 않는다. 밝은 판때기 2개가 동시에 보인다 | **DEV 선언된 이월 (3-3절)** |
| MEDIUM-2 | LOW 강등 권고 | 가격 천단위 구분자 (1·2차 이월) | **부분 해소 — HUD·보유 골드는 적용, 상점 가격 열은 미적용 (8절)** |
| HIGH-1 | HIGH | 화상(DoT) 사멸 — 누적 피해 0.4 % | 이월. F8 범위 밖 (7절) |

**2차 QA 의 FAIL 사유(F-3, 선언되지 않은 프로덕션 변경)는 해소됐다.** 모든 프로덕션 파일의
mtime 이 자기를 선언한 인계문보다 앞선다(9절). 3·4·5차 변경 전부에 인계문이 있다.

**사용자 직접 지시 3건, 판때기 크기 일관성, 포커스 접근성, 밸런싱 C-1/C-2/C-3, 전체 회귀 —
전부 통과.** 위 MEDIUM 2건은 판정을 막지 않는다: MEDIUM-3 은 문서 한 줄, MEDIUM-4 는
DEV 가 인계문 3절에 범위 밖으로 선언하고 한 줄 되돌리는 법까지 적어 둔 이월 항목이다.

---

## 1. DEV 검수 절차 1~18 — 번호 순 결과

`DEV_HANDOFF_F8_FIX4.md` 2절의 번호를 그대로 따랐다.

| # | 내용 | 결과 |
|---|---|---|
| 1 | `godot --headless --path . --quit` | **PASS** — 로그 6줄, `NotoSansKR-Regular.ttf` 누락 2건 외 에러 0, exit 0 |
| 2 | `test_game_loop.tscn` | **PASS** — `OK - all game loop checks passed.` (52개 검사, 목록 6-1절) |
| 3 | `test_day_flow.tscn` | **PASS** — `OK - day flow reached Day 2.` |
| 4 | `qa_f7_title.tscn` | **PASS** — `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton` / `settings focus ring: SettingsCloseButton, SfxSlider, BgmSlider, MasterSlider, FullscreenCheck` |
| 5 | `sim_balance.tscn` + md5 | **PASS** — `OK - simulated Day 1..200.` / `sim_report.md` md5 **`2a494b8e7a1c63906e270feba82f4740`**, 실행 전후 **바이트 동일**. `sim_metrics.json` 도 바이트 동일 |
| 6 | `qa_f8_title_shots.tscn` 창 모드 | **PASS** — `OK - one selected plate at a time across 4 sizes.` / `---` 8줄 전부 `button=294x67` / `plate height:` 4줄 전부 `nosave=67.0 save=67.0` (표 3-4절) |
| 7 | `qa_f8_focus_all.tscn` 창 모드 (세이브 없음) | **PASS** — `OK - focus indicator meets 3.0:1 ...` / median **9.88 ~ 10.12 : 1**. `the focus ring is back` **미출력** (표 4-1절) |
| 8 | 세이브 만들어 7번 재실행 (`이어하기` 포함 12조합) | **PASS** — median **9.90 ~ 10.08 : 1**. `ContinueButton` SKIPPED 되지 않음 (표 4-1절) |
| 9 | 세이브 없이 실기동 — 판때기 3개, 구멍 없음 | **PASS** — 3-1절 스크린샷. 간격 균등, 세로 가운데 |
| 10 | 세이브 만든 뒤 판때기 4개 + 라벨 1줄, 두께 동일 | **PASS** — 3-4절. 두께 차 0.0px |
| 11 | 9번/10번 `새 게임` 판때기 폭·두께 비교 | **PASS** — 폭·두께 동일, 위치만 55유닛 이동 (3-4절 `box_top` 365 → 310) |
| 12 | `idle_nosave_*` vs `idle_save_*` 4해상도 육안 | **PASS** — 하네스와 별개로 PNG 픽셀 직접 측정, 크림 판때기 세로 픽셀 수 동일 (3-5절) |
| 13 | 창 크기 늘렸다 줄이기 — 비례 확대/축소 | **PASS** — 9단계 스윕 실측. 235×54 → 441×101 px 연속 변화, 되돌아올 때 동일 복귀 (3-6절) |
| 14 | 세이브 없을 때 `↓`×3 / `↑`×3 순환 | **PASS** — `새 게임 → 설정 → 종료`. 빈 자리 정지 0. 강조 항상 1개 (`_test_hidden_continue_leaves_the_focus_chain` + 실화면) |
| 15 | 판때기 바깥 흰 띠·검은 띠 없음 | **PASS** — 2배 확대 육안(3-3절) + 하네스가 바깥 밴드 변경 픽셀 **0** 을 21조합에서 FAIL 조건으로 감시 |
| 16 | 세이브 있을 때 `↓` 가 `이어하기` 를 밟음 | **PASS** — 실화면 `이어하기 → 설정 → 종료` (3-2절) |
| 17 | 상점 / 일시정지 / 단어 트리 / 자모 선택 포커스 테두리 존치 | **PASS** — 6개 화면 전부 실기동 확인 (2-A3절). 정적으로도 `SB_btn_focus` / `SB_icon_focus` / `SB_slot_focus` 무수정 |
| 18 | 덮어쓰기 확인창 `취소` 포커스 · `ESC` 복귀 · 설정 포커스 트랩 | **PASS** — 2-A3절 |

---

## 2. 【A】사용자 직접 지시 3건

### A-1. 버튼 텍스처 의미 — **PASS**

`title_active_button.png` = 선택된 버튼, `title_inactive_button.png` = 선택 안 된 버튼.

- **진입 시 강조 정확히 1개**: 4해상도 × 2세이브상태 = 8조합 전부에서
  `qa_f8_title_shots` 가 `selected plate:` 를 **매번 1개만** 출력. 실화면으로도 확인
  (세이브 없음 → `새 게임`, 세이브 있음 → `이어하기`).
- **키보드로 강조가 따라 이동**: `↓`×2 → `이어하기` → `설정` → `종료` 로 이동, 항상 1개.
- **마우스로도 따라 이동**: `qa_f8_hover_focus` 의 `keyboard_and_hover_quit` 조합에서
  `bright_plates=1 ["QuitButton(0.98)"]`.
- **강조 없음 상태**: `nofocus_*` 4조합에서 `selected plate: <none>` — 전부 어두운 판때기.

판때기 중앙 휘도 실측: 선택 **0.92 ~ 0.98** / 비선택 **≈0.05**. 매핑이 뒤집혀 있지 않다.

> 단, 키보드 포커스와 마우스 호버가 **다른 버튼에 동시에** 걸리면 밝은 판때기가 2개다.
> MEDIUM-4 (3-3절). DEV 가 선언한 이월 항목이다.

### A-2. 세이브 없으면 이어하기 숨김 — **PASS**

| 확인 | 방법 | 결과 |
|---|---|---|
| 버튼·라벨 **둘 다** 안 보임 | `test_game_loop::_test_title_hides_continue_without_a_save` + 실화면 | **PASS** — 판때기 3개, 진행 라벨 없음 |
| 포커스 순서가 건너뜀 | `_test_hidden_continue_leaves_the_focus_chain` (체인 끝까지 걸어 `ContinueButton` 미등장 확인) + `qa_f7_title` 의 `keyboard reachable: NewGameButton, SettingsButton, QuitButton` | **PASS** |
| 세이브 있으면 나타남 | 실화면 — `이어하기` 판때기 + `저장된 진행 — DAY 2 · 137 G` 한 줄, 진입 포커스가 `이어하기` | **PASS** |
| 남은 3행 간격·정렬 유지 | `qa_f8_title_shots` 의 gap/align 검사 (4해상도) | **PASS** — FAIL 0 |

### A-3. 포커스 사각 박스 제거 + 타이틀 외 화면 존치 — **PASS**

**타이틀: 링 없음.**
- 정적: `theme/jamo_theme.tres:197` `SB_title_focus` 가 `StyleBoxEmpty`.
  `focus_ring` 문자열이 `theme/` `scenes/` `scripts/` 전체에서 **0회** 등장.
- 동적: `qa_f8_focus_all::_report_no_outline` 이 버튼 rect 바깥 12px 밴드의
  변경 픽셀 수를 세어 **>0 이면 FAIL**. 3해상도 × 4버튼 × 2세이브상태 = **21조합
  (세이브 없음 3조합은 `ContinueButton` SKIP) 전부 0픽셀.**
- 육안: 2배 확대 크롭(`verify_final/final_onoff_Quit_1280x720.png`)에서 붓자국 가장자리가
  배경과 바로 만난다. 흰 띠·검은 띠 없음.

**타이틀 외: 링 존치 — 6개 화면 전부 실기동으로 확인.**

| 화면 | 포커스 대상 | 결과 |
|---|---|---|
| 상점 (`qa_f8_shop.tscn`, Day 60) | `다음 DAY 시작` | **PASS** — 갈색 3px 사각 테두리 그대로 |
| 일시정지 (`main.tscn` → ‖) | `설정` | **PASS** — 동일 |
| 단어 트리 (`main.tscn` → 책 아이콘) | `[선행 잠금] 강타` 슬롯 | **PASS** — `TreeSlot` 테두리 그대로. HUD 아이콘 버튼도 유지 |
| 자모 선택 (`qa_f8_choice.tscn`) | `ㅏ` 카드 | **PASS** — 두꺼운 포커스 테두리, 비포커스 카드는 얇은 기본선 |
| 설정 패널 (타이틀 내부) | `닫기` | **PASS** — 갈색 테두리. `↓` 4회에도 패널 밖으로 안 나감 (포커스 트랩 정상) |
| 덮어쓰기 확인창 | `취소` | **PASS** — `취소` 에 테두리, `새로 시작` 에는 없음. 진입 포커스가 `취소` |

정적 확인: `Button/styles/focus`(`SB_btn_focus`) / `HudIconButton/styles/focus`(`SB_icon_focus`) /
`TreeSlot/styles/focus`(`SB_slot_focus`) 3개 전부 `border_width 3` 유지. 무수정.
**하나도 사라지지 않았다.**

---

## 3. 【B】버튼 크기 일관성

### 3-1. 세이브 없는 화면 (검수 9번)

`tests/qa_artifacts/f8/shots/idle_nosave_1280x720.png` — 판때기 **3개**
(`새 게임` 크림 / `설정` / `종료` 어두움), 로고 아래 세로 가운데. **중간 구멍 없음.**
`이어하기` 판때기도 진행 라벨도 화면에 없다.

### 3-2. 세이브 있는 화면 (검수 10·16번)

판때기 **4개** + `저장된 진행 — DAY 2 · 137 G` 1줄. 진입 포커스 `이어하기`.
`↓` 순환이 `이어하기` 를 건너뛰지 않는다 (실기동 확인).

### 3-3. 링 제거 육안 + 【MEDIUM-4】

`verify_final/final_onoff_Quit_1280x720.png` (2배 확대, 밝은 나무 바닥 위 `종료`):
포커스 시 크림 판때기 + 잉크 글자, 비포커스 시 어두운 판때기 + 크림 글자.
**어느 쪽에도 테두리가 없다.**

**MEDIUM-4 — 호버와 포커스가 구분되지 않는다.** `qa_f8_hover_focus` 실측:

```
--- keyboard_only_settings          focus=SettingsButton bright_plates=1 ["SettingsButton(0.92)"]
--- keyboard_settings_hover_quit    focus=SettingsButton bright_plates=2 ["SettingsButton(0.92)", "QuitButton(0.98)"]
--- hover_released                  focus=SettingsButton bright_plates=1 ["SettingsButton(0.92)"]
--- keyboard_and_hover_quit         focus=QuitButton     bright_plates=1 ["QuitButton(0.98)"]
```

- **기대**: Enter 가 어디로 갈지 화면에서 구분된다.
- **실제**: 키보드 포커스가 `설정`, 마우스가 `종료` 위에 있으면 밝은 판때기가 **2개**이고
  둘을 구분할 표식이 없다. 3차까지는 링이 그 역할을 했다.
- **재현**: `godot --path . res://tests/qa_f8_hover_focus.tscn` → 2번째 줄.
- **판정**: DEV 가 `DEV_HANDOFF_F8_FIX3.md` 3절에 "이번 지시 범위 밖이라 그대로 뒀다" 로
  선언했고 되돌리는 법(`TitleButton/styles/hover` 를 `SB_title_normal` 계열로, 테마 한 줄)까지
  적어 뒀다. **선언된 이월이므로 FAIL 사유로 삼지 않는다.** 다만 이 상태는 지시 3
  (링 제거)의 직접적 부작용이므로 사용자 판단이 필요하다.

### 3-4. 【필수】8조합 판때기 크기표 — **전부 294×67, 차 0.0px**

`godot --path . res://tests/qa_f8_title_shots.tscn` 원문 출력.

| 창 크기 | 세이브 | 뷰포트(유닛) | 판때기(유닛) | 뷰포트 대비 | logo_bottom | box_top |
|---|---|---|---|---|---:|---:|
| 1280×720 | 없음 | 1280×720 | **294×67** | 23.0 % × 9.3 % | 223 | 365 |
| 1280×720 | 있음 | 1280×720 | **294×67** | 23.0 % × 9.3 % | 223 | 310 |
| 1920×1080 | 없음 | 1280×720 | **294×67** | 23.0 % × 9.3 % | 223 | 365 |
| 1920×1080 | 있음 | 1280×720 | **294×67** | 23.0 % × 9.3 % | 223 | 310 |
| 720×1280 | 없음 | 1280×2275 | **294×67** | 23.0 % × 2.9 % | 1001 | 1142 |
| 720×1280 | 있음 | 1280×2275 | **294×67** | 23.0 % × 2.9 % | 1001 | 1087 |
| 2560×1080 | 없음 | 1706×720 | **294×67** | 17.2 % × 9.3 % | 223 | 365 |
| 2560×1080 | 있음 | 1706×720 | **294×67** | 17.2 % × 9.3 % | 223 | 310 |

```
    1280x720  plate height: nosave=67.0 save=67.0
    1920x1080 plate height: nosave=67.0 save=67.0
    720x1280  plate height: nosave=67.0 save=67.0
    2560x1080 plate height: nosave=67.0 save=67.0
```

**DEV 가 4절에 올린 표와 8칸 전부 일치한다.** 2560×1080 의 폭 비율이 17.2 % 인 것은
뷰포트가 1706 유닛으로 넓어지기 때문이고, 실제 화면 픽셀 폭은 1920×1080 과 동일한 441 px 다.

### 3-5. 하네스와 별개로 — PNG 픽셀 직접 측정 (검수 12번)

`shots/*.png` 를 열어 판때기 중앙 열에서 크림 픽셀의 세로 연속 구간을 직접 셌다
(하네스의 `get_global_rect()` 를 쓰지 않는 독립 측정).

| 해상도 | 세이브 없음 (px) | 세이브 있음 (px) | 차 |
|---|---:|---:|---:|
| 1280×720 | 55 | 55 | 0 |
| 1920×1080 | 82 | 82 | 0 |
| 2560×1080 | 82 | 82 | 0 |
| 720×1280 | 30 | 31 | 1 (안티에일리어싱) |

붓자국 텍스처가 rect 전체를 채우지 않으므로 절대값은 67 유닛보다 작지만,
**두 상태의 값이 같다**는 것이 확인 대상이고 그것이 성립한다.

### 3-6. 창 크기 비례 확대/축소 (검수 13번) — **PASS**

`tests/qa_f8_resize.tscn` (이번 QA 신규 자산) 으로 9단계 스윕.

| 창 크기 | 판때기(유닛) | 판때기(화면 px) |
|---|---|---:|
| 1024×576 | 294×67 | 235×54 |
| 1280×720 | 294×67 | 294×67 |
| 1440×810 | 294×67 | 331×75 |
| 1600×900 | 294×67 | 368×84 |
| 1760×990 | 294×67 | 404×92 |
| 1920×1080 | 294×67 | **441×101** |
| 1600×900 (축소) | 294×67 | 368×84 |
| 1280×720 (축소) | 294×67 | 294×67 |
| 1024×576 (축소) | 294×67 | 235×54 |

화면 픽셀이 **연속적으로 커지고 작아지며 되돌아올 때 같은 값으로 복귀**한다.
특정 픽셀에 고정돼 있지 않다. 유닛 값이 전 구간 294×67 인 것은
`canvas_items` 스트레치 + 안전영역 비율 계산의 정상 동작이다.

### 3-7. 화면 대비 크기 · 로고 여백 균형 (검수 6번) — **적정**

- 판때기는 뷰포트 폭의 **23.0 %**, 높이의 **9.3 %**. 3개 스택 합계가 세로 27.8 % + 간격.
  16:9 에서 과하지 않다. 2560×1080 에서는 폭 17.2 % 로 더 얌전하다.
- 로고는 화면 상단 1/3 을 차지하고 그 아래 여백 → 메뉴 → 아래 여백 순으로 열린다.
  1280×720 에서 로고 하단 223, 메뉴 시작 310(세이브)/365(없음), 바닥 여백 충분.
- 720×1280 세로 화면에서는 16:9 안전영역 규칙대로 메뉴가 화면 위쪽 절반에 모이고
  아래 절반이 배경만 남는다. 의도된 안전영역 동작이며 잘림·겹침은 없다. (INFO)

### 3-8. 【검수 7번】세이브 없을 때 스택이 55유닛 내려간다 — **어색하지 않음**

`verify_final/nosave_vs_save_1280x720.png` 로 두 상태를 나란히 놓고 판정했다.

- 세이브 없음: 로고 하단 223 → 첫 판때기 365. 간격 **142 유닛**
- 세이브 있음: 로고 하단 223 → 첫 판때기 310. 간격 **87 유닛**

3개 스택이 `Box` 칸 안에서 세로 가운데 정렬돼 위아래로 여백을 반씩 남긴 결과다.
**시각적으로 어색하지 않다** — 스택이 로고 밑에 균형 있게 떠 있고, 중간에 구멍이 없으며,
3개 판때기가 균등 간격으로 붙어 있다. 오히려 3행일 때 로고와의 숨통이 더 트인다.
DEV 설명대로 스택의 세로 중심이 두 상태에서 동일하므로 화면을 오갈 때 메뉴가 튀지 않는다.
(INFO: 첫 판때기의 y 좌표는 55유닛 움직인다. 위쪽 정렬을 원하면
`Box.alignment` 을 `1` → `0` 으로 바꾸면 되지만, 현재 상태로 지시 위반은 없다.)

---

## 4. 【C】포커스 표시 접근성

### 4-1. 【필수】4버튼 × 3해상도 대비 측정표

측정 도구: `tests/qa_f8_focus_all.gd`. 포커스 프레임과 비포커스 프레임을 실제로 렌더해
**버튼 rect 안의 픽셀을 하나씩 비교**하고, `CHANGE_THRESHOLD = 12`(채널 최대 변화 12 이상)
를 넘은 픽셀만 WCAG 상대휘도식으로 대비를 낸 뒤 **median** 을 쓴다. 임계값 `3.0:1` 무수정.

**세이브 없음** (`ContinueButton` 은 화면에 없으므로 SKIPPED)

| 해상도 | 새 게임 | 이어하기 | 설정 | 종료 |
|---|---:|---:|---:|---:|
| 1280×720 | 9.99 | (숨김) | 10.06 | **9.88** ← 최저 |
| 1920×1080 | 10.06 | (숨김) | 10.09 | 9.94 |
| 2560×1080 | 10.02 | (숨김) | **10.12** ← 최고 | 10.04 |

**세이브 있음** (4버튼 × 3해상도 = 12조합)

| 해상도 | 새 게임 | 이어하기 | 설정 | 종료 |
|---|---:|---:|---:|---:|
| 1280×720 | 9.96 | 10.00 | **9.90** ← 최저 | 9.94 |
| 1920×1080 | 10.05 | 10.06 | 9.96 | 9.99 |
| 2560×1080 | 10.04 | 10.05 | **10.08** ← 최고 | 9.95 |

- 전 조합 **3.0:1 기준을 3배 이상 초과**. 최저 9.88:1.
- 변화 픽셀 중 3.0:1 을 넘는 비율 **87.4 % ~ 89.2 %** (나머지는 글자·붓자국 가장자리).
- **DEV 보고(9.88~10.12 / 9.90~10.08)와 소수점까지 일치한다.**
- `the focus ring is back` FAIL 은 21조합 어디에서도 뜨지 않았다.
- 덮어쓰기 확인창도 4해상도 전부 `size=(622, 104) contents_minimum=(622.0, 104.0)` — 잘림 없음.

### 4-2. 하네스를 신뢰하지 않은 육안 확인

지시대로 하네스 값만 믿지 않고 실제 스크린샷을 직접 열어 확인했다.

| 증거 | 확인 내용 |
|---|---|
| `shots/idle_nosave_1280x720.png` | `새 게임` 만 크림, 나머지 어두움. 링 없음 |
| `shots/idle_save_1280x720.png` | `이어하기` 만 크림. 진행 라벨 존재 |
| `shots/idle_nosave_720x1280.png` | 세로 화면, 안전영역 중앙. 배치 동일 |
| `shots/idle_nosave_2560x1080.png` | 초광폭, 배치 동일 |
| `verify_final/final_onoff_Quit_1280x720.png` | **2배 확대** on/off. 밝은 나무 바닥 위에서도 크림 판때기가 배경과 확연히 분리된다 |
| `verify_final/nosave_vs_save_1280x720.png` | 두 상태 나란히. 두께 동일, 위치만 이동 |
| ziva-godot MCP 실기동 7회 | 타이틀(키보드/확인창/구버전 세이브/설정) / 상점 / 일시정지 / 단어 트리 / 자모 선택 / 아레나 |

**육안 판정: 하네스 수치와 화면이 일치한다.** 선택 판때기는 어떤 배경 위에서도 눈에 띈다.

### 4-3. 색만으로 전달하는가 — **아니다**

- 크림 `≈(247,223,192)` ↔ 어두운 회녹 `≈(61,53,48)` 은 색상차가 아니라 **명도차 9.9:1** 이다.
  흑백 출력해도 구분된다. 색각 이상 사용자에게 문제되지 않는다.
- 변화 면적이 버튼 rect 전체(1280×720 에서 약 17,500 px)라 WCAG 2.2 SC 2.4.13 의
  "2px 외곽선 상당 면적" 요건을 면적으로 크게 넘는다.
- **비활성/숨김**: `이어하기` 는 세이브 없을 때 **숨는다** — 색으로 전달할 상태 자체가 없다.
  해당 없음.
- 참고로 타이틀 밖에서는 상태가 문자로도 나온다. 상점 만렙 행이 `최대` / `완료` 로 표시된다.

---

## 5. 【D】밸런싱

### 5-1. `gold_growth_per_day` 1.035 — 조건부 승인. 값 재논의 없음 ✔

### 5-2. C-1 — `BALANCE_NOTES` 3-1 근거 — **충족**

문장이 있는지만이 아니라 **주장 자체를 검산**했다.

| 요구 | 위치 | 내용 검증 | 판정 |
|---|---|---|---|
| (a) 붕괴 직접 원인 = 클릭 피해 Lv9 상한 | 3-1 "**직접 원인은 이 상수가 아니다.** 붕괴를 만든 것은 `클릭 피해` Lv9 상한(3-2)이다" | `click_damage.tres` 실측 26레벨, 문서 상한 Lv9=10. HP Day200=2820 → 282클릭. 인과 성립 | **PASS** |
| (b) QA 반례: 골드 1.025 유지 시 Day 200 3,921 G/일 | 3-1 변형 (가)/(다)/(나) 3행 표 | 표에 `(다) 골드만 1.025 로 복귀 … Day 200 **3,921**` 존재. 1차 QA `qa_f8_variant` 값과 일치 | **PASS** |
| (c-1) "가격 곡선으로는 못 고친다" 초판 주장 철회 | 3-1 "즉 **'가격 곡선으로는 고칠 수 없다' 는 초판의 주장은 틀렸다.**" | 명시적 취소 | **PASS** |
| (c-2) §42 에 HP 성장률 확정 없음 | 3-1 134~135행 | **v0.3 §42 원문 직접 확인**: 10개 항목 중 HP 성장률 없음. §42-4 는 `Day 1 기본 Gold 2G` 뿐 | **사실 확인** |
| (c-3) 1.5 % / Day 200 56 HP 는 계산 착오, 2.5 % 면 408 HP | 3-1 | `3 × 1.025^199 = 408.3` 검산 일치 | **사실 확인** |
| (d-1) v0.3 §8.1 충돌 정면 기술 | 3-1 "**기준 문서와 충돌한다 — 숨기지 않고 기록한다**" | `BaseGold = 2 × 1.025^(Day-1)` 을 어긴다고 명시 | **PASS** |
| (d-2) §41 우선순위 문제 기술 | 3-1 | "1 순위 문서(v0.3 §8.1)를 2 순위 문서(growth_balance §5)에 맞춘 것", "규칙을 문자 그대로 적용하면 반대" 까지 적음 | **PASS** |

### 5-3. C-2 — 정본 선언 / v0.4 후속 / v0.3 무수정 — **충족**

| 요구 | 확인 | 판정 |
|---|---|---|
| growth_balance §5 정본 선언 | `BALANCE_NOTES` 3-1 "**이번 사이클은 §5(목표 수입곡선)를 정본으로 삼고, §4 표를 정오표 대상으로 둔다.**" | **PASS** |
| v0.4 개정이 `DEV_ROADMAP` 후속 항목 | `docs/DEV_ROADMAP.md:130` `### F8 후속 — 기준 문서 개정 (v0.4, 총지휘자·사용자 판단 사항)` + **미체크 4항목** (§8.1 골드식 / §4·§5 정본 확정 / §8.1 클릭 피해 표 / §3 HP 표 반올림) | **PASS** |
| **v0.3 문서 무수정** | `git status --short docs/JAMO_total_project_development_plan_v0.3.md docs/hangul_idle_growth_balance_v0.2.md` → **출력 없음** | **PASS** |

### 5-4. C-3 — 골드 앵커 negative control — **실제로 깨진다**

`resources/balance/game_balance.tres` 를 백업 후 `gold_growth_per_day` 1.035 → **1.025** 로
바꾸고 `test_game_loop.tscn` 재실행:

```
  FAIL: Day 10 gold should be about 2.73
  FAIL: BALANCE_NOTES 3-1 gold growth (got 1.025000, want 1.035000)
  FAIL: Day 200 gold from the tuned gold curve (got 272.319793, want 1880.007600)
  FAIL: gold growth has to track HP growth (got 1.025000, want 1.035000)
FAILED - 4 check(s) failed.        exit=1
```

- **동어반복이 아니다.** 기대값이 리터럴로 박혀 있어 리소스를 되돌리면 4개가 빨개진다.
- `got 272.319793` 이 v0.3 §8.1 의 `2 × 1.025^199 = 272.32` 와 일치 — 문서 이탈 폭이
  코드에서 그대로 재현된다.
- **원복 완료**: 백업본과 `diff` 무차이, md5 **`a680addd9bbbe90641b444b8a7ddbce0`** 재확인,
  `test_game_loop.tscn` 재실행 `OK - all game loop checks passed.` 복귀 (10절).

### 5-5. 【MEDIUM-3】`BALANCE_NOTES:314` — **정정 필요. 미해결.**

직접 확인해 판정하라는 지시에 따라 원문 대조로 검증했다.

```
docs/BALANCE_NOTES.md:134  초판이 든 "HP 식은 §8.1 과 §42 에서 두 번 못 박았다" 는 **사실이 아니다.**
docs/BALANCE_NOTES.md:135  §42 의 확정 항목에 HP 성장률은 없고, §42-4 가 고정한 것은 `Day 1 기본 Gold 2 G` 뿐이다.
docs/BALANCE_NOTES.md:314  | `hp_growth_per_day` | 1.035 | v0.3 §8.1 + §42 에서 두 번 확정. 낮추면 후반 고HP 설계가 사라진다 (3-1) |
```

- **기대**: 314행이 3-1 의 정정된 근거를 따른다.
- **실제**: 134행이 "사실이 아니다" 로 취소한 문장을 314행이 그대로 반복한다.
  더구나 314행은 근거로 `(3-1)` 을 가리키는데, 가리킨 곳이 그 문장을 부정한다.
- **1차 검증 (사실관계)**: `docs/JAMO_total_project_development_plan_v0.3.md` 의
  `# 42. v0.3에서 확정한 통합 수정 사항` 전문을 읽었다. 10개 항목은
  게임명 / 2.5D / 자모 보행 / **Day 1 기본 Gold 2G** / 힘 / 강타 / 절약 / 자동화 /
  코드전용금지 / 에디터 가시성 이다. **HP 성장률은 없다.** 314행은 사실과 다르다.
- **영향**: §6("바꾸지 않기로 한 항목") 표만 읽는 사람은 취소된 오류를 사실로 받는다.
  C-1 이 없애려 한 상태가 문서 한 곳에 남아 있다.
- **조치(한 줄)**: 314행 사유를
  `v0.3 §8.1 확정값. 2.5 % 로 낮추면 Day 200 이 2,820 → 408 HP 가 되어 growth_balance §3 의
  후반 고HP 구간 설계가 사라진다 (3-1)` 로 교체.
- **재현**: `grep -n "§42" docs/BALANCE_NOTES.md`
- **심각도**: MEDIUM. 문서 내부 모순이고 코드·수치에는 영향이 없다. 2차 QA 의 지적이
  이번 사이클에서 반영되지 않았다.

### 5-6. 밸런스 해시 대조 — 타이틀 수정으로 **하나도 변하지 않았다**

세션 시작·종료 두 시점 모두 동일하고, 1·2차 QA 값과도 같다.

| 파일 | md5 |
|---|---|
| `resources/balance/game_balance.tres` | `a680addd9bbbe90641b444b8a7ddbce0` |
| `resources/upgrades/click_damage.tres` | `110cd1112157fd907e43d4675d95262b` |
| `resources/upgrades/critical_click.tres` | `764ad1833b3d6bd3861c93b7bb610b3d` |
| `resources/upgrades/gold_bonus.tres` | `03a036a770dc61da5fbe020014164c27` |
| `resources/upgrades/max_energy.tres` | `eb4f1eece1c05100a59e36d3bab1c4bd` |
| `resources/upgrades/monster_capacity.tres` | `595f96a36ff3afe2aeb8be939fc90daa` |
| `resources/upgrades/reroll.tres` | `e41e2eea0d7c943001de0b166866b957` |
| **`tests/qa_artifacts/f8/sim_report.md`** | **`2a494b8e7a1c63906e270feba82f4740`** ← 요구값 일치 |
| `tests/qa_artifacts/f8/sim_metrics.json` | `ce72e75d073baec6e48a5f1bd27592ad` |

`sim_balance.tscn` 을 이번 세션에서 재실행했고 실행 전후 두 산출물이 **바이트 동일**했다.

### 5-7. 상점 Lv26 표시·구매 + 치명 클릭 게이트 — **PASS** (검수 16번)

ziva-godot 실기동 `res://tests/qa_f8_shop.tscn` (Day 60, 골드 5,000,000).

| 확인 | 결과 |
|---|---|
| 클릭 피해 Lv26 표시 | **PASS** — `클릭 피해 Lv.25 / 2672 → 3607 / 1650000 G` |
| **실제 구매** | **PASS** — `구매` 클릭 후 `클릭 피해 Lv.26 / 3607 / 최대 / 완료(비활성)`. 보유 골드 `5000000 G` → **`3350000 G`** (정확히 −1,650,000) |
| 만렙 상태가 색만으로 전달되나 | **아니다** — `최대` / `완료` 문자 병행 |
| 치명 클릭 게이트 | **PASS** — `critical_click.tres`: `unlock_day = 25`, `required_upgrade = &"click_damage"`, `required_level = 3` 무수정. Day 60 화면에 `치명 클릭 Lv.4 / 8% → 10% / 7500 G` 정상 노출 |
| 행 레이아웃 | **PASS** — 6개 행 잘림·겹침 없음 |
| 클릭 피해 사다리 | `values` 26개 (마지막 3607), `costs` 26개 (마지막 1,650,000) — `BALANCE_NOTES` 3-2 와 일치 |

---

## 6. 【E】전체 회귀 (Vertical Slice)

### 6-1. `test_game_loop` 52개 검사 전부 통과 — F1~F8 매핑

`OK - all game loop checks passed.`

| F | 커버하는 검사 |
|---|---|
| **F1 치명 클릭** | `_test_critical_click`, `_test_day_scaling`, `_test_starting_stats` |
| **F2 리롤** | `_test_reroll_charges_and_blocks`, `_test_reroll_panel_states`, `_test_reroll_redraws_candidates`, `_test_reroll_save_round_trip`, `_test_reroll_upgrade_gates` |
| **F3 단어 10개 · 선행 잠금 · 화염 · 불꽃** | `_test_database_holds_ten_words`, `_test_prerequisites_gate_words`, `_test_hwayeom_raises_burn_tick`, `_test_bulkkot_spread_data`, `_test_bulkkot_spreads_burn_on_death`, `_test_word_completes_and_consumes_jamo`, `_test_shared_jamo_is_not_double_spent`, `_test_bap_needs_two_bieup`, `_test_word_effects_apply` |
| **F4 특수 3종 · 황금 게이트 · 체류시간** | `_test_special_multipliers_reach_the_monster`, `_test_geum_unlocks_golden`, `_test_golden_pool_waits_for_geum`, `_test_golden_leaves_without_paying_gold`(체류시간 만료), `_test_un_boosts_special_spawn`, `_test_un_multiplies_special_spawn_chance` |
| **F5 트리 4상태 · Target 규칙 · 키보드 · 아레나 이탈 0** | `_test_word_states_come_from_the_database`, `_test_hud_and_tree_show_the_same_words`, `_test_hud_lists_every_craftable_word`, `_test_target_focus_raises_candidate_weight`, `_test_target_refuses_uncraftable_words`, `_test_hud_buttons_take_keyboard_focus`, `_test_no_monster_size_leaves_the_slab` |
| **F6 연출 · 에너지 경고 · 단어 완성 · 볼륨** | `_test_burn_vfx_follows_effects_changed`, `_test_energy_warning_threshold_comes_from_balance`, `_test_energy_ends_the_day`, `_test_word_completion_can_be_skipped`, `_test_settings_sliders_drive_the_buses`, `_test_volume_settings_survive_a_save`, `_test_missing_audio_files_are_skipped`, `_test_step_sfx_paths_differ_per_motion_profile` |
| **F7 새 게임 덮어쓰기 · 설정 · 타이틀 복귀** | `_test_new_game_asks_before_overwriting`, `_test_new_game_keeps_the_volume_settings`, `_test_returning_to_the_title_saves`, `_test_save_round_trip` |
| **F8 타이틀 3차 수정 + 밸런스** | `_test_title_hides_continue_without_a_save`, `_test_hidden_continue_leaves_the_focus_chain`, `_test_title_plates_keep_one_size_without_a_save`, `_test_day_200_curve_comes_from_the_balance_resource`, `_test_tuned_values_come_from_resources`, `_test_upgrade_purchase`, `_test_upgrade_blocked_when_poor`, `_test_candidates_are_useful` |

트리 4상태는 실화면에서도 확인했다 — 단어 트리 범례
`[완성] / [제작 가능] / [선행 잠금] / [미발견]` 4종이 표시되고, 상태가 **색이 아니라
문자 접두어**로 전달된다. `목표 단어: 없음` + `TARGET: 없음 (트리에서 지정)` 규칙 문구 정상.

### 6-2. 보조 QA 자산 재실행

| 대상 | 결과 |
|---|---|
| `qa_f3_pool.tscn` | **PASS** — 자모 풀 전이 정상, 10단어 완성 후 `craftable = 0`, 고갈 풀 draw/reroll 이 빈 배열 반환(크래시 없음) |
| `qa_f3_compat.tscn` | **PASS** — 미지 단어 id 로드 시 크래시 없음. `강타` 선언 0.100 vs 실측 0.1017 / `강타+치명 Lv5` 0.200 vs 0.2004 / `치명 Lv5` 0.100 vs 0.0996 (각 200,000 롤). `불꽃` 반경 게이트 정상 (1.07 m 반경, 1.57 m 이웃 미점화) |
| `qa_critical_play.tscn` | 완료 (exit 0) |
| `qa_shop_gate` / `qa_reroll_play` / `qa_f5_arena` | **미판정** — 헤드리스에서 종료하지 않는 대화형 프로브다. 90초 타임아웃 후 종료시켰다. **DEV 요구 목록(검수 18번)에 없다.** 해당 커버리지는 `test_game_loop` 의 리롤 5종·업그레이드 2종·`_test_no_monster_size_leaves_the_slab` 로 대체 확인했다 |

### 6-3. Day 1 → Day 2 — **PASS**

`test_day_flow.tscn` — `OK - day flow reached Day 2.`
Day 1 시작 에너지 20 확인 → 에너지 소진 → 종료 요약 → 자모 선택 → 상점 → Day 2 리필까지
실제 씬 그래프로 통과. 실화면에서도 Day 1 진입 시 `DAY 1 / ENERGY 20 / 20 / 0 G / 처치 0`
HUD, 제작 가능한 단어 5줄, `TARGET: 없음 (트리에서 지정)` 확인.

### 6-4. 구버전 세이브 호환 — **PASS**

`save_version 1`, `day 25`, `gold 94500`, `click_damage 3`, `critical_click 2`,
에너지·단어 필드 없음인 세이브를 로드:
타이틀이 `저장된 진행 — DAY 25 · 94500 G` 로 정상 표시. 크래시·경고 없음.
`이어하기` 판때기 + 진입 포커스 정상.

### 6-5. 60 FPS (v0.3 §36) — **PASS**

전부 **에디터 디버거 부착 상태**의 ziva-godot 실기동 측정.

| 장면 | 프레임 / 시간 | FPS |
|---|---|---:|
| 타이틀 (키보드 조작) | 185 / 3.013 s | **61.4** |
| 타이틀 (덮어쓰기 확인창) | 184 / 3.009 s | 61.1 |
| 타이틀 (구버전 세이브) | 155 / 2.513 s | 61.7 |
| 타이틀 (설정 패널) | 304 / 5.006 s | 60.7 |
| 상점 Day 60 | 214 / 3.506 s | 61.0 |
| 단어 트리 | 272 / 4.506 s | 60.4 |
| 아레나 Day 60 | 356 / 6.014 s | 59.2 |
| 아레나 Day 1 (12 초 장시간) | 722 / 12.000 s | **60.2** |

### 6-6. 헤드리스 정적 로드 — **PASS**

`godot --headless --path . --quit` 출력 6줄, exit 0.
`NotoSansKR-Regular.ttf` 누락 2건 외 **에러·경고 0**.

---

## 7. 사전 존재 이슈 · 이월 (이번 사이클 무관)

- **HIGH-1 (1·2차 이월, 미해결)**: 화상(DoT) 사멸. `sim_report.md` 실측 누적 피해 중
  화상 **0.4 %**, 화상 킬 **2 마리 / 6,286 킬**. `불`·`화염`·`불꽃` 계열이 함정 선택지.
  고정 피해가 HP 복리를 못 따라간다. 효과 타입 변경이 필요해 F8 범위 밖. **차기 사이클 권고.**
- **`NotoSansKR-Regular.ttf` 누락 2건.** `project.godot` 의 `gui/theme/custom_font` 가
  없는 파일을 가리킨다. F7 부터 존재. **`DEV_ROADMAP` 에 아직 안 올라와 있다.**
- **`signal_bus.gd` unused-signal 경고 12건** (에디터 실행 시). `DEV_ROADMAP` LOW 목록엔
  `word_revealed` 1건만 — 1·2차 지적 그대로 미갱신.
- **LOW-1 (이월)**: `sim_report.md` 는 `Day 181 부터 15 일`, `BALANCE_NOTES` 4장은 `16 일`.
- **LOW-2 (이월)**: `BALANCE_NOTES` 3-2 는 "Day 194 에 Lv26", 실측 마지막 구매는 Day 196.
- **LOW-4 (이월, QA 자산)**: `qa_f8_focus_all` 콜드런 오탐. 이번 세션에서는 **재현되지 않았다**
  (2회 실행 전부 정상). 하네스 임포트 안정화 가드는 여전히 권고.
- **LOW-5 (신규, 환경)**: `qa_f8_title_shots` 실행 중 창이 **최소화되면** Godot 이 렌더를
  멈춰 `await RenderingServer.frame_post_draw` 가 영원히 반환하지 않는다. 이번 세션에서
  1920×1080 리사이즈 직후 실제로 걸렸고(약 10분 정지), 창을 복원하자 즉시 진행됐다.
  **제품 결함이 아니라 창 모드 하네스의 실행 조건**이다. 무인 CI 에서 돌릴 계획이면
  `DisplayServer.window_is_minimized()` 가드나 헤드리스 대체 경로가 필요하다.
- `art/Untitled.blend`, `art/Untitled.blend.import` untracked — DEV 산출물 아님.
- `user://jamo_save.json.qabak` 은 이전 QA 사이클 잔여물. 그대로 뒀다.
- 이전 세션이 남긴 헤드리스 Godot 좀비 3개(PID 54352 / 61120 / 22464)가 떠 있다.
  이번 세션이 만든 것이 아니고, 지시대로 kill 하지 않았다.

---

## 8. 2차 QA 지적 사항의 처리 현황

| 2차 지적 | 이번 확인 |
|---|---|
| **F-3 (FAIL 사유)** 선언되지 않은 프로덕션 변경 | **해소** — 9절. 3·4·5차 변경 전부 인계문 있음, mtime 순서 정합 |
| **MEDIUM-3** `BALANCE_NOTES:314` | **미해결** — 5-5절. 한 줄 정정 필요 |
| MEDIUM-2 천단위 구분자 | **부분 해소** — HUD 보유 골드가 `3,350,000 G` 로 구분자 적용. 상점 **가격 열**은 아직 `1650000 G` / `보유 골드 5000000 G` 형식. **LOW 로 강등 권고** |
| LOW-1 / LOW-2 | 미해결. 이월 |
| LOW-4 하네스 오탐 | 이번 세션 미재현 |
| HIGH-1 DoT | 미해결. 차기 사이클 |

---

## 9. 선언 대조 — 검증 도중 산출물이 바뀌지 않았다

2차 QA 를 FAIL 시킨 항목이므로 이번에는 처음부터 mtime 순서를 확인했다.

| 파일 | mtime | 선언 인계문 | 순서 |
|---|---|---|---|
| `art/ui/focus_ring.png` | 12:18:51 | FIX (12:28:08) | ✔ 선행 |
| `docs/BALANCE_NOTES.md` | 12:24:02 | FIX (12:28:08) | ✔ 선행 |
| `docs/DEV_ROADMAP.md` | 12:24:25 | FIX (12:28:08) | ✔ 선행 |
| `theme/jamo_theme.tres` | 13:33:43 | **FIX3 (13:49:40)** | ✔ 선행 |
| `scenes/ui/title_screen.tscn` | 14:07:06 | **FIX4 (14:17:37)** | ✔ 선행 |
| `scripts/ui/title_screen.gd` | 14:08:56 | **FIX4 (14:17:37)** | ✔ 선행 |
| `tests/test_game_loop.gd` | 14:09:48 | FIX4 (14:17:37) | ✔ 선행 |
| `tests/qa_f8_title_shots.gd` | 14:10:08 | FIX4 (14:17:37) | ✔ 선행 |
| `resources/balance/game_balance.tres` | 14:49:38 | — | **QA 자신의 5-4절 원복** (md5 동일) |

`git status --short` 의 프로덕션 변경 목록이 FIX2~FIX4 인계문 1절의 합집합과 일치한다.
**QA 세션 중 DEV 가 트리를 건드린 흔적이 없다.** ORCHESTRATION_RULES §4-6 수행 가능.

---

## 10. 임시 변경 원복 · QA 신규 파일

### 임시 변경 원복 — **완료**

| 임시 변경 | 원복 |
|---|---|
| `resources/balance/game_balance.tres` `gold_growth_per_day` 1.035 → 1.025 (5-4절 역검증) | **원복 완료.** 백업본과 `diff` 무차이, md5 `a680addd9bbbe90641b444b8a7ddbce0` 재확인, `test_game_loop` 재통과 확인 |
| `user://jamo_save.json` 프로브 세이브 3회 생성 (4-1절 세이브 있음 측정 / 구버전 호환 / 덮어쓰기 확인창) | **삭제 완료.** 세션 시작 상태(`jamo_save.json.qabak` 만 존재)로 복귀 |
| `user://jamo_save.json.shotbak` (하네스 임시본) | **삭제 완료** |
| 하네스 상수 변경 | **없음.** `qa_f8_focus_all.gd` 의 `SIZES` / `REQUIRED_CONTRAST` / `CHANGE_THRESHOLD` 를 손대지 않았다 |

**QA 가 수정한 프로덕션 파일은 0개다.** `resources/**` 7개 해시 전부 세션 시작과 동일(5-6절).
`docs/**`, `scenes/**`, `scripts/**`, `theme/**`, `art/**` 중 QA 가 건드린 파일 없음.

### QA 신규 파일 (전부 `tests/` 아래)

| 파일 | 용도 |
|---|---|
| `tests/qa_artifacts/f8/QA_REPORT_FINAL.md` | 이 문서 |
| `tests/qa_f8_choice.gd` / `.tscn` | 실제 `jamo_choice.tscn` 을 후보와 함께 띄우는 QA 뷰어. 2-A3 자모 선택 포커스 테두리 근거 |
| `tests/qa_f8_resize.gd` / `.tscn` | 창 크기 9단계 스윕 프로브. 3-6 비례 확대/축소 근거 |
| `tests/qa_artifacts/f8/verify_final/final_onoff_Quit_1280x720.png` | 2배 확대 on/off 육안 증거 |
| `tests/qa_artifacts/f8/verify_final/nosave_vs_save_1280x720.png` | 세이브 유무 나란히 비교 |

### DEV 하네스가 덮어쓴 산출물 (정상 동작)

`tests/qa_artifacts/f8/shots/` PNG 44장, `tests/qa_artifacts/f8/variants/` PNG —
각 하네스가 실행마다 새로 쓴다. 실행 전 백업본을 떠 두고 재실행 결과가 DEV 표와
일치함을 확인했다.

### 재현 명령

```
godot --headless --path . --quit
godot --headless --path . res://tests/test_game_loop.tscn
godot --headless --path . res://tests/test_day_flow.tscn
godot --headless --path . res://tests/qa_f7_title.tscn
godot --headless --path . res://tests/sim_balance.tscn
md5sum tests/qa_artifacts/f8/sim_report.md      # 2a494b8e7a1c63906e270feba82f4740
godot --path . res://tests/qa_f8_title_shots.tscn   # 창 모드
godot --path . res://tests/qa_f8_focus_all.tscn     # 창 모드 (세이브 유/무 2회)
godot --path . res://tests/qa_f8_hover_focus.tscn   # 창 모드 (MEDIUM-4)
godot --path . res://tests/qa_f8_resize.tscn        # 창 모드 (신규)
godot --path . res://tests/qa_f8_choice.tscn        # 창 모드 (신규)
```

> 창 모드 하네스는 실행 중 창이 최소화되면 멈춘다 (LOW-5). 창을 보이는 상태로 둘 것.

---

## 11. 결론

**PASS.**

**사용자 직접 지시 3건 전부 충족됐다.** 버튼 텍스처 매핑이 바로 서서 강조된 판때기가
언제나 정확히 하나이고 키보드·마우스를 따라 움직인다. 세이브가 없으면 `이어하기` 버튼과
진행 라벨이 둘 다 사라지고 포커스 체인도 그 자리를 건너뛴다. 흰 띠·검은 띠 사각 테두리는
타이틀에서 완전히 사라졌고(21조합 0픽셀), **상점·일시정지·단어 트리·자모 선택·설정 패널·
확인창의 기존 테두리는 6개 화면 전부에서 살아 있다.**

**판때기 크기가 세이브 유무와 무관해졌다.** 4해상도 × 2상태 8조합 전부 294×67,
높이 차 0.0px. 하네스와 별개로 PNG 픽셀을 직접 세어 같은 결론을 얻었다.
창 크기 9단계 스윕에서 235×54 ↔ 441×101 px 로 연속 변화하고 되돌아온다 — 픽셀 고정이 아니다.
세이브 없을 때 스택이 55유닛 내려가는 것은 가운데 정렬의 결과이고 시각적으로 어색하지 않다.

**포커스 대비는 링 없이도 충분하다.** 4버튼 × 3해상도 × 2세이브상태에서 median
**9.88 ~ 10.12 : 1**, 기준 3.0:1 의 3배 이상. 하네스 수치를 스크린샷 육안으로 교차 확인했고,
선택 표시는 색상이 아니라 명도차라 색각 이상 사용자에게도 유효하다.

**밸런스는 하나도 변하지 않았다.** 7개 `.tres` + `sim_report.md`(md5 `2a494b8e…f4740`) +
`sim_metrics.json` 전부 1·2차 QA 값과 동일. C-1 은 원문 대조로 사실관계까지 검산해 충족,
C-2 는 v0.3 무수정 + v0.4 후속 4항목으로 충족, C-3 은 골드 앵커를 실제로 깨뜨려
4개 체크가 빨개지는 것을 확인하고 원복했다.

**전체 회귀 통과.** 요구된 6개 테스트가 전부 통과하고 정적 로드 에러 0(폰트 제외),
Day 1 → Day 2, 구버전 세이브 호환, 상점 Lv26 실구매(−1,650,000 G), 치명 클릭 게이트,
60 FPS(59.2~61.7) 전부 실화면에서 확인했다.

**2차 QA 의 FAIL 사유였던 미선언 변경은 해소됐다.** 모든 프로덕션 파일이 자기를 선언한
인계문보다 앞선 시각에 바뀌었고, QA 세션 중 트리가 바뀌지 않았다.

### 다음 사이클로 넘기며 사용자 판단이 필요한 것

1. **MEDIUM-4 (권고 우선)** — 링을 없앤 대가로 호버와 키보드 포커스가 구분되지 않는다.
   마우스를 다른 버튼에 올려두면 밝은 판때기가 2개다. 지시 3(링 제거)을 유지하면서
   고치려면 `TitleButton/styles/hover` 를 `SB_title_normal` 로 되돌리면 된다
   (테마 한 줄, 호버 강조가 사라지고 밝은 판때기가 항상 1개가 된다).
2. **MEDIUM-3** — `docs/BALANCE_NOTES.md:314` 한 줄 정정 (5-5절에 교체 문구 있음).
3. **HIGH-1** — 화상(DoT) 사멸. `불` 계열 전체가 함정 선택지. 효과 타입 변경이 필요하다.
4. `NotoSansKR-Regular.ttf` 누락 · `signal_bus` unused-signal 12건을 `DEV_ROADMAP` 에 등재.
5. LOW-5 — 창 모드 QA 하네스에 최소화 가드. 무인 실행 계획이 있다면 필요하다.
