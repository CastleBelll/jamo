# F8 QA 재검증 리포트 (2차) — 포커스 대비 + 근거 문서 정정

판정: **FAIL**

FAIL 사유는 **단 하나, 절차 문제**다. 검증 대상 9항목은 **전부 통과**했고 F-1 은 해소됐다.
FAIL 은 **검증 도중 산출물이 바뀌었고 그 변경에 DEV 인계문이 없다**는 데서 나온다 (F-3, 4절).

작성 2026-09-10 · 대상 `DEV_HANDOFF_F8_FIX.md` (F8 2차) · 검증 Godot 4.7.stable
창 모드 실기동 + ziva-godot MCP 실플레이 · 기준 문서 우선순위 v0.3 > growth_balance v0.2 (v0.3 §41)

| # | 심각도 | 내용 |
|---|---|---|
| **F-3** | **HIGH (절차)** | 검증 도중 `theme/jamo_theme.tres`(12:55:49)와 `scripts/ui/title_screen.gd`(13:03:42)가 **DEV 인계문 작성 시각(12:28:08) 이후에** 다시 수정됐다. 인계문에 없는 3차 변경이고, 별도 인계문·근거·주의사항이 없다. `scenes/ui/title_screen.tscn` 도 76줄 축소됐다. QA 는 선언되지 않은 변경을 인증할 수 없다 (ORCHESTRATION_RULES §4-6) |
| MEDIUM-3 | MEDIUM | `BALANCE_NOTES` §6 표의 `hp_growth_per_day` 행이 **3-1 에서 철회한 주장을 그대로 반복**한다. 문서 내부 모순 (5-4절) |

**F-1 (1차 CRITICAL) 은 해소됐다.** 두 트리 상태 모두에서 4개 버튼 × 전 해상도 3.0:1 초과.
**C-1 / C-2 / C-3 은 전부 충족**됐다. **밸런스 수치는 하나도 변하지 않았다** (해시 대조).

---

## 1. DEV 검수 절차 A~E 결과

인계문 2절의 번호를 그대로 따랐다.

| 단계 | 내용 | 결과 |
|---|---|---|
| A-1 | `godot --headless --path . --quit` | **PASS** — `NotoSansKR-Regular.ttf` 누락 2건 외 에러 0, exit 0. 새 `ext_resource` 파싱 문제 없음 |
| B-2 | `test_game_loop.tscn` | **PASS** — `OK - all game loop checks passed.` |
| B-3 | `test_day_flow.tscn` | **PASS** — `OK - day flow reached Day 2.` |
| B-4 | `qa_f7_title.tscn` | **PASS** — `keyboard reachable: NewGameButton, SettingsButton, QuitButton` |
| B-5 | `sim_balance.tscn` | **PASS** — `OK - simulated Day 1..200.` / `sim_report.md` md5 **`2a494b8e7a1c63906e270feba82f4740`** 유지, 실행 전후 **바이트 동일**. `sim_metrics.json` 도 바이트 동일 |
| C-6 | `qa_f8_focus_all.tscn` 창 모드 | **PASS** — `OK - focus indicator meets 3.0:1 and the dialog fits its contents.` 개별값은 DEV 표와 **소수점까지 일치** (2-1절) |
| C-7 | 세이브 만들어 `이어하기` 포함 4개 측정 | **PASS** — 11.24 / 9.27 / 10.82. DEV 실측치와 **완전 일치** |
| C-8 | 해상도 6종 확장 (1024×600 / 1600×900 / 3840×2160 추가) | **PASS** — **24조합 전부 ≥ 3.0:1, 최저 3.51:1**. DEV 주장 그대로 재현 (2-1절) |
| D-9 | `종료` on/off 육안 (밝은 나무 바닥) | **PASS** — 붓자국 바깥에 흰 띠 + 검은 띠, off 프레임엔 없음. 버튼 위치·크기 불변 |
| D-10 | `새 게임` on/off 육안 (어두운 문간) | **PASS** — 검은 띠는 배경에 묻히지만 흰 띠가 살아 있다. 2색 설계 의도대로 동작 |
| E-11 | `BALANCE_NOTES` 3-1 ①~⑥ | **PASS** — 6항목 전부 존재하고 내용도 사실에 맞다 (5절). 단 §6 표에 잔재 1건 (MEDIUM-3) |
| E-12 | `DEV_ROADMAP` F8 후속 절 / v0.3 무수정 | **PASS** — 4개 미체크 항목 신설 확인, `git status` 에 v0.3·growth_balance **안 뜬다** (6절) |
| E-13 | 골드 리터럴 앵커 + 역검증 | **PASS** — 1.025 로 되돌리면 **4개 체크가 FAILED**. 동어반복 아님 (7절) |

---

## 2. 【핵심】F-1 포커스 대비 재측정

### 2-1. DEV 선언 상태(2차)에서의 측정 — 24조합 전부 통과

측정 시각 12:38~12:50. 창 모드(`--headless` 아님), Intel UHD 770 / Vulkan Forward+.
하네스는 QA 자산 `tests/qa_f8_focus_all.gd` 로, **DEV 의 판정식·임계값(3.0:1)·
CHANGE_THRESHOLD(12) 를 그대로 쓴다.** `SIZES` 만 3종 → 6종으로 임시 확장했고 **원복했다**
(원본과 `diff` 무차이 확인 완료).

| 해상도 | 새 게임 | 이어하기 | 설정 | 종료 |
|---|---:|---:|---:|---:|
| 1280×720 | 18.20 | 11.24 | 5.44 | 4.12 |
| 1920×1080 | 12.91 | 9.27 | 4.02 | 3.69 |
| 2560×1080 | 12.97 | 10.82 | 3.53 | **3.51** ← 최저 |
| 1024×600 | 7.82 | 7.12 | 4.11 | 3.70 |
| 1600×900 | 12.14 | 8.54 | 4.19 | 3.62 |
| 3840×2160 | 14.00 | 8.77 | 4.29 | 3.72 |

**DEV 가 `BALANCE_NOTES` 8-1 에 올린 24개 숫자와 소수점까지 전부 일치한다.**
DEV 의 보고는 정확했다. 3해상도 구간은 4회 연속 실행에서 동일값이 나왔다(결정적).

### 2-2. 현재 트리(3차 변경 포함)에서의 재측정 — 여유가 더 커졌다

측정 시각 13:05~13:12. `이어하기` 활성(세이브 존재) 상태.

| 해상도 | 새 게임 | 이어하기 | 설정 | 종료 |
|---|---:|---:|---:|---:|
| 1280×720 | 10.22 | 10.10 | 9.24 | 9.08 |
| 1920×1080 | 10.15 | 9.92 | 9.25 | 9.20 |
| 2560×1080 | 10.15 | 10.03 | 9.60 | **9.13** ← 최저 |

세이브 없는 상태(`이어하기` SKIPPED)도 8.94~10.21 로 동일 경향.
3차 변경이 **선택 상태에서 밝은 붓자국판(`SB_title_selected`)으로 바뀌는 판 교체**를
추가했기 때문에, 포커스 변화가 링뿐 아니라 판 전체로 커졌다.

**두 상태 모두 SC 2.4.11 의 3.0:1 을 만족한다. F-1 은 닫혔다.**

### 2-3. 육안 확인 (하네스와 별개로 실제 화면)

- `tests/qa_artifacts/f8/final_onoff_QuitButton_1280x720.png` — **밝은 나무 바닥 위 `종료`**.
  포커스 시 밝은 판 + 검정/흰색 2색 링, 비포커스 시 어두운 판. 링이 붓자국 **바깥**에만
  그려져 아트 자체를 덮지 않는다.
- `tests/qa_artifacts/f8/crop2_NewGameButton_1280x720_on_vs_off.png` — **어두운 문간 위 `새 게임`**.
  검은 띠가 배경에 묻히는 구간에서도 흰 띠가 또렷하다. 2색으로 만든 이유가 실측으로 확인된다.
- `tests/qa_artifacts/f8/final_zoom_pristine_1280x720.png` — 포커스를 전혀 건드리지 않은
  **최초 진입 프레임**. 링·판·라벨·세이브 안내(`저장된 진행 — DAY 25 · 94500 G`) 전부 정상.
- ziva-godot MCP 실기동 화면에서도 동일 (`res://scenes/ui/title_screen.tscn` 라이브 실행).

**라벨 가독성 실측** (`labels/pristine_1280x720.png`, 상대휘도 계산):

| 버튼 | 상태 | 라벨 대비 |
|---|---|---:|
| 새 게임 / 설정 / 종료 | 비선택(어두운 판 + 크림 글자) | **8.2 ~ 10.4 : 1** |
| 포커스 버튼 | 선택(밝은 판 + 갈색 글자) | **11.4 : 1** |

WCAG 1.4.3(4.5:1) 을 양쪽 다 넘는다. **색만으로 정보를 전달하지 않는다** — 링(형태) +
판 교체(명도) + `이어하기` 비활성 사유가 문장으로 표시된다.

### 2-4. 아트 훼손 여부 — **없음**

- 링은 `expand_margin 6` 으로 버튼 **바깥**에 그려진다. `content_margin` 16/9/16/9 유지라
  **버튼 크기·위치가 on/off 프레임에서 동일**하다. 레이아웃을 밀어내지 않는다.
  (측정: on/off 픽셀 차이 영역이 버튼 rect + 링 두께 안에만 존재)
- 4종 창 크기(1280×720 / 1920×1080 / 2560×1080 / 1024×600) + 1600×900 / 3840×2160
  전부에서 띠 두께가 일정하다. 9-patch 라 창 크기와 무관하다는 DEV 설명이 맞다.
- `art/ui/focus_ring.png` **직접 디코딩 검증**: 32×32 RGBA8, 바깥 `#000000` 2 px +
  안쪽 `#FFFFFF` 4 px, 가운데 `alpha=0` 완전 투명, corner radius 7. `.import` 는
  `compress/mode=0`(무손실) + `mipmaps/generate=false`. **인계문 설명과 정확히 일치.**
  파일 크기 198 byte — 리포에 부담 없다. 적절한 에셋이다.

### 2-5. 포커스 링 전역 영향 — **없음**

정적 확인: 링은 `TitleButton/styles/focus` **한 곳**에만 걸려 있다.
`Button`(게임 화면) → `SB_btn_focus`, `HudIconButton` → `SB_icon_focus`,
`TreeSlot`(단어 트리) → `SB_slot_focus` 는 **무수정**이다.
`theme_type_variation = &"TitleButton"` 을 쓰는 노드는 `scenes/ui/title_screen.tscn` 의
**4개 버튼뿐**이다. (`scenes/ui/pause_menu.tscn:51` 의 노드는 *이름*만 `TitleButton` 이고
`type="Button"` 에 variation 지정이 없어 해당 없음.)

실화면 확인: `tests/qa_f8_shop.tscn` 라이브 실행에서 상점 `다음 DAY 시작` 버튼의 포커스는
**기존 단색 테두리 그대로**다. 흰/검 링이 새지 않는다.

---

## 3. 밸런스 무변경 확인 — **PASS**

QA 세션 시작 시점과 종료 시점의 해시가 **전부 동일**하다.

| 파일 | md5 |
|---|---|
| `resources/balance/game_balance.tres` | `a680addd9bbbe90641b444b8a7ddbce0` |
| `resources/upgrades/click_damage.tres` | `110cd1112157fd907e43d4675d95262b` |
| `resources/upgrades/critical_click.tres` | `764ad1833b3d6bd3861c93b7bb610b3d` |
| `resources/upgrades/gold_bonus.tres` | `03a036a770dc61da5fbe020014164c27` |
| `resources/upgrades/max_energy.tres` | `eb4f1eece1c05100a59e36d3bab1c4bd` |
| `resources/upgrades/monster_capacity.tres` | `595f96a36ff3afe2aeb8be939fc90daa` |
| `resources/upgrades/reroll.tres` | `e41e2eea0d7c943001de0b166866b957` |

`sim_balance.tscn` 을 3차 변경 **이전과 이후 양쪽에서** 돌렸고, 두 번 다
`sim_report.md` md5 = `2a494b8e7a1c63906e270feba82f4740` (1차 QA 값과 동일),
`sim_metrics.json` 도 **바이트 단위로 동일**했다.
`gold_growth_per_day = 1.035` 유지. **DEV 주장 그대로다.**

---

## 4. 【FAIL F-3】검증 도중 산출물이 바뀌었다

### 사실

| 파일 | mtime | 인계문에 선언됐나 |
|---|---|---|
| `tests/qa_artifacts/f8/DEV_HANDOFF_F8_FIX.md` | 12:28:08 | (기준 시각) |
| `art/ui/focus_ring.png` | 12:18:51 | O |
| `docs/BALANCE_NOTES.md` | 12:24:02 | O |
| **`theme/jamo_theme.tres`** | **12:55:49** | **부분만** |
| **`scripts/ui/title_screen.gd`** | **13:03:42** | **X — 목록에 없음** |

인계문 1절은 `theme/jamo_theme.tres` 변경을 "`SB_title_focus` 를 `StyleBoxTexture` 로 교체 +
`ext_resource` 1줄 추가, **그 외 스타일박스는 무수정**" 이라고 명시했고,
`scripts/**` 는 변경 목록에도 무수정 목록에도 없다.

내가 12:35 에 뜬 `git diff theme/jamo_theme.tres` 는 실제로 그 설명과 일치했다.
그러나 현재 트리의 diff 는 이렇다.

```
 scenes/ui/title_screen.tscn | 76 +++++-----------------------
 scripts/ui/title_screen.gd  | 28 ++++++++++++-
 theme/jamo_theme.tres       | 80 +++++++++++++++++++++++++++-------
```

추가된 것:
- `SB_title_normal` / `SB_title_selected` / `SB_title_hover` / `SB_title_pressed` /
  `SB_title_disabled` **스타일박스 5개 신설**
- `ext_resource` 2개 추가 (`title_active_button.png`, `title_inactive_button.png`)
- `TitleButton/colors/*` **5개 신설**, `TitleButton/font_sizes/font_size` **26 → 22**
- `scripts/ui/title_screen.gd` 에 `_bind_selection_plate()` / `_on_button_focus_entered()` /
  `_on_button_focus_exited()` **신설**, `_continue_info` 문구에 개행 삽입
- `scenes/ui/title_screen.tscn` **76줄 축소**

### 왜 FAIL 인가

1. **인증 대상이 검증 중에 바뀌었다.** 2-1절 표(최저 3.51:1)는 12:38~12:50 상태의 측정이고,
   2-2절 표(최저 9.08:1)는 13:05 이후 상태의 측정이다. 같은 명령을 돌렸는데 결과 체계가
   달라진 원인이 이것이다. 재현 가능한 단일 인증 대상이 존재하지 않는다.
2. **ORCHESTRATION_RULES §4-6("DEV 주의사항 검증")을 수행할 수 없다.** 3차 변경에는
   인계문이 없으므로 하위 호환 위험·보류 사항·근거가 아예 존재하지 않는다. 검증할 대상이 없다.
3. **QA 는 선언되지 않은 프로덕션 변경을 통과시킬 수 없다.** 특히
   `scenes/ui/title_screen.tscn` 76줄 축소는 이번 태스크의 검증 범위 밖이고 리뷰되지 않았다.

### 덧붙임 — 3차 변경 자체는 결과가 더 낫다

내가 실제로 잰 범위 안에서는, 3차 변경 후 상태가 2차보다 **모든 지표에서 낫거나 같다**:
포커스 대비 최저 3.51 → 9.08, 헤드리스 테스트 4종 전부 통과, `sim_report.md` 바이트 동일,
Day 1 → Day 2 실플레이 정상, 60 FPS 유지, 라벨 대비 8.2:1 이상.
**되돌리라는 뜻이 아니다.** 3차 인계문을 받아 검증 범위를 다시 잡으면 곧바로 닫힐 항목이다.

**재현**: `ls -l --time-style=+%H:%M:%S theme/jamo_theme.tres scripts/ui/title_screen.gd` 로
mtime 을 보고, `git diff --stat` 으로 인계문 1절의 목록과 대조하면 된다.

---

## 5. C-1 검증 — `BALANCE_NOTES` 3-1 근거 재작성

### 5-1. 요구 6항목 존재 여부 — 전부 있다

| # | 요구 내용 | 위치 | 판정 |
|---|---|---|---|
| ① | 붕괴의 **직접 원인 = 클릭 피해 Lv9 상한** | 3-1 "**직접 원인은 이 상수가 아니다.** 붕괴를 만든 것은 `클릭 피해` Lv9 상한(3-2)이다" | **PASS** |
| ② | QA 반례 표 (골드 1.025 유지 시 Day 200 **3,921 G/일**) | 3-1 변형 (가)/(다)/(나) 3행 표 | **PASS** |
| ③ | "가격 곡선으로는 못 고친다" 초판 주장을 **틀렸다고 명시** | 3-1 "즉 **'가격 곡선으로는 고칠 수 없다' 는 초판의 주장은 틀렸다.**" | **PASS** |
| ④ | 사실관계 오류 2건 정정 | 3-1 §42 건 / 56 HP 건 둘 다 정정 | **PASS** (단 5-4 참조) |
| ⑤ | v0.3 §8.1 충돌 + §41 우선순위상 1순위를 2순위에 맞춘 선택임을 정면 기술 | 3-1 "**기준 문서와 충돌한다 — 숨기지 않고 기록한다**" 항 | **PASS** |
| ⑥ | growth_balance §5 를 **정본**으로 선언 | 3-1 "**이번 사이클은 §5(목표 수입곡선)를 정본으로 삼고, §4 표를 정오표 대상으로 둔다**" | **PASS** |

### 5-2. 내용이 실제로 맞는지 — 원문 대조로 검증했다

문장 존재만 본 것이 아니라 주장 자체를 검산했다.

| 주장 | 검증 방법 | 결과 |
|---|---|---|
| "§42 의 확정 항목에 HP 성장률은 없다. §42-4 가 고정한 것은 `Day 1 기본 Gold 2 G` 뿐" | v0.3 §42 전문 확인 — 10개 항목: 게임명 / 2.5D / 자모 보행 / **Day 1 기본 Gold 2G** / 힘 / 강타 / 절약 / 자동화 / 코드전용금지 / 에디터 가시성 | **사실이다** |
| "HP 1.035 와 Gold 1.025 는 둘 다 §8.1 한 곳에만 나온다" | v0.3 §8.1 원문: `HP = 3 × 1.035^(Day-1)` / `BaseGold = 2 × 1.025^(Day-1)` | **사실이다** |
| "2.5 % 면 Day 200 은 56 이 아니라 **408 HP**" | `3 × 1.025^199 = 408.3` | **사실이다** (초판 56 은 계산 착오가 맞다) |
| "§41 우선순위는 v0.3 > growth_balance" | v0.3 §41 원문 확인 | **사실이다** |
| "§5 목표 Day 200 50,000 G+" | growth_balance §5 목표 수입 곡선 표 확인 | **사실이다** |
| "(다) 골드 1.025 유지 시 Day 200 3,921 G/일" | 1차 QA 가 `qa_f8_variant.tscn` 으로 낸 값과 일치 | **일치** |
| Day 200 골드 1.035 = 1,880.0076 / 1.025 = 272.32 | 역검증 실행 로그가 `got 272.319793` 을 출력 | **일치** |

### 5-3. 판정 — **C-1 충족**

1차 QA 가 "재현 못 하는 주장이 문서에 남는 것을 막으라"고 단 조건은 달성됐다.
3-1 은 이제 **인과(피해 상한)와 설계 판단(§5 목표·Day 201+ 발산 방지)을 분리**해 쓰고 있고,
자기 초판의 오류를 명시적으로 취소한다.

### 5-4. 【MEDIUM-3】다만 §6 표에 철회한 주장이 그대로 남아 있다

```
docs/BALANCE_NOTES.md:134  초판이 든 "HP 식은 §8.1 과 §42 에서 두 번 못 박았다" 는 **사실이 아니다.**
docs/BALANCE_NOTES.md:135  §42 의 확정 항목에 HP 성장률은 없고, ...
...
docs/BALANCE_NOTES.md:314  | `hp_growth_per_day` | 1.035 | v0.3 §8.1 + §42 에서 두 번 확정. ... (3-1) |
```

- **기대**: 314행이 3-1 의 정정된 근거를 따른다.
- **실제**: 134행이 "사실이 아니다"라고 취소한 문장을 314행이 **그대로 반복**한다.
  더구나 314행은 `(3-1)` 을 근거로 가리키는데, 가리킨 곳이 그 문장을 부정하고 있다.
- **영향**: §6("바꾸지 않기로 한 항목") 표만 읽는 사람은 취소된 오류를 사실로 받는다.
  C-1 이 없애려 한 상태가 문서 한 곳에 남아 있다.
- **조치**: 314행 사유를 "v0.3 §8.1 확정값. 2.5 % 로 낮추면 Day 200 이 2,820 → 408 HP 가 되어
  growth_balance §3 의 후반 고HP 구간 설계가 사라진다 (3-1)" 정도로 한 줄 고치면 끝난다.
- **재현**: `grep -n "§42" docs/BALANCE_NOTES.md`

---

## 6. C-2 검증 — 정본 선언 · v0.4 후속 · v0.3 무수정

| 요구 | 확인 | 판정 |
|---|---|---|
| growth_balance §5 를 정본으로 선언 | `BALANCE_NOTES` 3-1 "이번 사이클은 §5 를 정본으로 삼고, §4 표를 정오표 대상으로 둔다. 어느 쪽이 최종 정본인지는 v0.4 개정에서 확정해야 한다" | **PASS** |
| v0.4 개정이 `DEV_ROADMAP` 후속 항목 | `### F8 후속 — 기준 문서 개정 (v0.4, 총지휘자·사용자 판단 사항)` 절 신설, 미체크 4항목 (§8.1 골드식 개정 / §4·§5 정본 확정 / §8.1 클릭 피해 표 / §3 HP 표 반올림) | **PASS** |
| **v0.3 문서 자체 무수정** | `git status --short docs/JAMO_total_project_development_plan_v0.3.md docs/hangul_idle_growth_balance_v0.2.md` → **출력 없음** | **PASS** |

`DEV_ROADMAP` 의 S0 포커스 항목 표기도 정정됐다: 1차의 `1.34:1 -> 15.32:1`(한 버튼 값)이
`**4 개 버튼 전부** 최저 3.51:1` 로 바뀌고 1차 크림 단색이 `종료` 에서 FAIL 했던 사실까지 적혀 있다.
1차 QA 가 지적한 "한 버튼 값을 전체 결과처럼 읽히게 한다" 는 문제가 해소됐다.

---

## 7. C-3 검증 — 골드 리터럴 앵커의 **역검증(negative control)**

### 앵커 존재 확인

`tests/test_game_loop.gd::_test_day_200_curve_comes_from_the_balance_resource()`:

```gdscript
_close(balance.gold_growth_per_day, 1.035, "BALANCE_NOTES 3-1 gold growth")
...
_close(gold_200, 1880.0076, "Day 200 gold from the tuned gold curve")
```

### 실제로 깨지는가 — **깨진다**

`resources/balance/game_balance.tres` 의 `gold_growth_per_day` 를 **1.025 로 임시 변경**하고
`test_game_loop.tscn` 재실행:

```
  FAIL: Day 10 gold should be about 2.73
  FAIL: BALANCE_NOTES 3-1 gold growth (got 1.025000, want 1.035000)
  FAIL: Day 200 gold from the tuned gold curve (got 272.319793, want 1880.007600)
  FAIL: gold growth has to track HP growth (got 1.025000, want 1.035000)
FAILED - 4 check(s) failed.
```

- **동어반복 아님이 증명됐다.** 1차 QA 가 지적한 "기대값을 검증 대상과 같은 필드에서
  만들어 비교" 하던 비대칭이 해소됐다. 이제 HP(1.035 / 2820.0)와 골드(1.035 / 1880.0076)가
  **대칭으로** 리터럴에 묶인다.
- 부수 확인: `got 272.319793` 은 v0.3 §8.1 의 `2 × 1.025^199 = 272.32` 와 일치한다.
  문서 이탈 폭이 코드에서 그대로 재현된다.
- **원복 완료**: 백업본으로 되돌린 뒤 md5 `a680addd9bbbe90641b444b8a7ddbce0` 재확인,
  `test_game_loop.tscn` 재실행하여 `OK - all game loop checks passed.` 복귀 확인.

1차 QA 가 지적한 `_test_tuned_values_come_from_resources()` 의 잘못된 인과 주석도 정정됐다
("The Day 110 collapse itself came from the click damage Lv9 cap, not from this gap.").

---

## 8. 회귀 — F1~F8 · 하위 호환 · 성능

### 자동 테스트 (3차 변경 포함 현재 트리)

| 대상 | 결과 |
|---|---|
| `godot --headless --path . --quit` | 폰트 누락 2건 외 에러 0, exit 0 |
| `tests/test_game_loop.tscn` | `OK - all game loop checks passed.` |
| `tests/test_day_flow.tscn` | `OK - day flow reached Day 2.` |
| `tests/qa_f7_title.tscn` | `OK - title screen checks passed.` |
| `tests/sim_balance.tscn` | `OK - simulated Day 1..200.` (출력 바이트 동일) |
| `tests/qa_f8_focus_all.tscn` | `OK - focus indicator meets 3.0:1 ...` |

`test_game_loop.gd` 는 F1~F6 로직 전반(치명 클릭 게이트, 리롤 Day 게이트, 단어 완성·자모
공유 소비, 단어 효과, 업그레이드 구매/거절, 세이브 왕복, 일시정지 메뉴)을 덮는다.
1차 QA 가 확인한 항목 중 이번 diff 가 닿을 수 있는 것은 타이틀 화면뿐이고, 그쪽은 아래에서
실화면으로 다시 확인했다.

### 실플레이 (ziva-godot MCP, 창 1280×720)

| 항목 | 결과 |
|---|---|
| 타이틀 진입 · 포커스 링 | **PASS** — 2-3절 |
| 타이틀 세이브 분기 | **PASS** — 세이브 없음 → `이어하기` 비활성 + `저장된 게임이 없어 / 이어하기를 할 수 없습니다.` / 세이브 있음 → `저장된 진행 — DAY 25 · 94500 G` + `이어하기` 에 진입 포커스 |
| 덮어쓰기 확인 창 | **PASS** — 4종 창 크기 전부 `size=(622, 104) contents_minimum=(622.0, 104.0)`, 잘림 없음 |
| Day 1 클릭 → 에너지 소모 → 킬 → 골드 | **PASS** — `ENERGY 0/20 · 10 G · 처치 5`. Day 1 기본 골드 2G × 5킬 = 10G, 정확 |
| Day 1 종료 패널 | **PASS** — `DAY 1 종료 / 처치한 자모 5 / 획득한 골드 10 G / [자모 선택으로]` |
| 자모 선택 → 상점 → **Day 2** | **PASS** — `DAY 2 · ENERGY 20/20 · 8 G`. 획득한 `ㅂ` 이 단어 패널에 반영 (`불 ㅂ1/1`, `밥 ㅂ1/2`) |
| 상점 클릭 피해 **Lv26 표시** | **PASS** — `클릭 피해 Lv.25 / 2672 → 3607 / 1650000 G`, 6개 행 전부 잘림·겹침 없음 |
| 치명 클릭 게이트 · 리롤 | **PASS** — 상점에 `치명 클릭 Lv.4`, `리롤 Lv.2` 정상 노출 |
| 단어 트리 / TARGET / 키보드 | **PASS** — `TARGET: 없음 (트리에서 지정)` 표시, 상점 방향키 순회 정상, 포커스 링 전역 유출 없음 (2-5절) |
| 구버전 세이브 호환 | **PASS** — `save_version 1` / `day 25` / `gold 94500` / `click_damage 3` 세이브를 로드해 타이틀이 `DAY 25 · 94500 G` 로 정상 표시 |
| 60 FPS (v0.3 §36) | **PASS** — 962 frames / 16.0 s = **60.1 FPS**, 1561 frames / 26.0 s = **60.0 FPS**, 1430 / 24.0 s = 59.6 FPS (전부 에디터 디버거 부착 상태) |

---

## 9. 사전 존재 이슈 · 이월 (F8 2차 무관)

- `NotoSansKR-Regular.ttf` 누락 에러 2건. `project.godot` 의 `gui/theme/custom_font` 가
  없는 파일을 가리킨다. F7 부터 존재. **DEV_ROADMAP 에 안 올라와 있다.**
- `signal_bus.gd` unused-signal 경고 **12건** (에디터 실행 시). `DEV_ROADMAP` LOW 목록엔
  `word_revealed` 1건만 있다 — 1차 QA 지적 그대로 미갱신.
- **MEDIUM-2 (1차 이월, 미해결)**: 가격 천단위 구분자 없음. 실화면 `1650000 G` /
  `보유 골드 5000000 G`. `upgrade_row.gd` 의 `"%d G"`. growth_balance §17 표기 예시는 `25,000 G`.
- **LOW-1 (1차 이월, 미해결)**: `sim_report.md` 는 `Day 181 부터 15 일`, `BALANCE_NOTES` 4장은
  `16 일`. 표기 통일 필요.
- **LOW-2 (1차 이월, 미해결)**: `BALANCE_NOTES` 3-2 는 "Day 194 에 Lv26", 실측 마지막 구매는 Day 196.
- **HIGH-1 (1차 이월, 차기 사이클 권고)**: 화상(DoT) 사멸 — 200일 화상 킬 2마리 / 누적 피해 0.4 %.
  `불`·`화염`·`불꽃` 계열이 함정 선택지. 효과 타입 변경이 필요해 F8 범위 밖.
- **LOW-4 (신규, QA 자산 문제)**: `qa_f8_focus_all.tscn` 이 이번 세션 첫 콜드런에서
  `1920x1080 QuitButton median=1.15:1 (changed=79863)` 로 **1회 오탐 FAIL** 했다.
  직후 6회 연속 재실행에서는 전부 정상값. 원인은 Godot 에디터가 텍스처를 재임포트하는
  중에 CLI 프로세스가 프레임을 찍었기 때문으로 보인다. 하네스에 임포트 안정화 대기나
  `changed` 픽셀 수 이상치 가드를 넣는 편이 좋다. **판정에는 영향 없음** (오탐 방향).
- `user://jamo_save.json.qabak` 은 이전 QA 사이클 잔여물. 이번 세션이 만든 것이 아니며 그대로 뒀다.
- `art/Untitled.blend`, `art/Untitled.blend.import` untracked — DEV 산출물 아님.

---

## 10. QA 가 만든 파일 · 임시 변경 원복

### 임시 변경 원복 — **완료**

| 임시 변경 | 원복 |
|---|---|
| `tests/qa_f8_focus_all.gd` 의 `SIZES` 3종 → 6종 확장 | **원복 완료.** 백업본과 `diff` 무차이 |
| `tests/qa_f8_focus_all.gd` 의 `OUT_DIR` → `verify2` | **원복 완료.** 백업본과 `diff` 무차이 |
| `resources/balance/game_balance.tres` `gold_growth_per_day` 1.035 → 1.025 (7절 역검증) | **원복 완료.** md5 `a680addd9bbbe90641b444b8a7ddbce0` 재확인 + 테스트 재통과 확인 |
| `user://jamo_save.json` 프로브 세이브 생성 (C-7 측정용) | **삭제 완료.** 세션 시작 상태(`jamo_save.json.qabak` 만 존재)로 복귀 |

**QA 가 수정한 프로덕션 파일은 0개다.** `resources/**` 7개 해시 전부 세션 시작과 동일(3절).
`docs/**`, `scenes/**`, `scripts/**`, `theme/**` 중 QA 가 건드린 파일 없음.

### 신규 파일 (전부 `tests/` 아래)

| 파일 | 용도 |
|---|---|
| `tests/qa_f8_labels.gd` / `.tscn` | 포커스를 전혀 건드리지 않은 **최초 진입 프레임** 캡처 + 버튼 rect·font_color 덤프. 2-3절 라벨 대비 실측 근거 |
| `tests/qa_artifacts/f8/QA_REPORT_2.md` | 이 문서 |
| `tests/qa_artifacts/f8/verify2/` | 3차 변경 직후 상태의 24프레임 (2-2절 중간 측정) |
| `tests/qa_artifacts/f8/labels/pristine_*.png` | 최초 진입 프레임 |
| `tests/qa_artifacts/f8/final_onoff_*.png`, `final_zoom_pristine_*.png` | **현재 트리** 육안 증거 (권장 참조본) |
| `tests/qa_artifacts/f8/crop2_*.png`, `crop3_*.png`, `v2_*.png`, `full_*.png`, `zoom_*.png` | 측정 과정 증거. `crop2_*` 는 **2차 상태**, 나머지는 3차 상태 |
| `tests/qa_artifacts/f8/plate_active.png`, `plate_inactive.png` | 판 아트 원본 대조 (평균 휘도 234 vs 48) |

주의: `tests/qa_artifacts/f8/variants/` 안의 **1024×600 `ContinueButton` 프레임 2장은
이전 QA 사이클 잔여물**이다(mtime 12:35). Godot 에디터가 파일을 잡고 있어 삭제가 실패했고,
해당 조합의 `save_png` 도 실패했다. **측정값 자체는 메모리 이미지에서 계산되므로 영향 없다.**

재현 명령:
```
godot --headless --path . --quit
godot --headless --path . res://tests/test_game_loop.tscn
godot --headless --path . res://tests/test_day_flow.tscn
godot --headless --path . res://tests/qa_f7_title.tscn
godot --headless --path . res://tests/sim_balance.tscn
godot --path . res://tests/qa_f8_focus_all.tscn      # 창 모드
godot --path . res://tests/qa_f8_labels.tscn         # 창 모드
```

---

## 11. 결론

**F-1 (1차 CRITICAL) 은 해소됐다.** 2색 링 9-patch 는 밝은 나무 바닥 위 `종료` 를 포함해
4개 버튼 × 6해상도 24조합 전부에서 3.0:1 을 넘고, DEV 가 보고한 24개 숫자가 소수점까지
재현된다. 아트를 덮지도, 레이아웃을 밀지도 않고, 타이틀 외 화면에 새지도 않는다.

**C-1 / C-2 / C-3 도 충족됐다.** 근거 문서는 인과와 설계 판단을 분리해 다시 쓰였고,
사실관계는 v0.3 원문과 대조해 검증했으며, 골드 앵커는 역검증으로 실제 깨짐을 확인했다.
v0.3 문서 자체는 손대지 않았고 v0.4 개정이 후속 항목으로 올라가 있다.

**밸런스는 하나도 변하지 않았다.** 7개 `.tres` 해시 동일, `sim_report.md` 바이트 동일.

**그럼에도 FAIL 이다.** 검증 도중 `theme/jamo_theme.tres`(12:55)와
`scripts/ui/title_screen.gd`(13:03)가 인계문 없이 다시 바뀌었고,
`scenes/ui/title_screen.tscn` 76줄 축소를 포함한 3차 변경이 리뷰되지 않은 채 트리에 있다.
QA 는 선언되지 않은 프로덕션 변경을 인증할 수 없다.

### 닫기 위해 필요한 것

1. **3차 변경 인계문** (`SB_title_normal/selected/hover/pressed/disabled`, `TitleButton/colors/*`,
   `font_size 26 → 22`, `_bind_selection_plate()` 계열 3함수, `title_screen.tscn` 76줄 축소).
   변경 이유·하위 호환 위험·보류 사항을 적을 것. 그 뒤 재검증은 타이틀 화면에 한정된다.
2. **MEDIUM-3** — `BALANCE_NOTES` 314행 한 줄 정정.

권고하되 이번 FAIL 사유가 아닌 항목: MEDIUM-2(천단위 표기), LOW-1/2(수치 표기),
LOW-4(하네스 오탐 가드), HIGH-1(DoT 사멸, 차기 사이클).
