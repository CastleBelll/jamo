# JAMO P0 하네스 커버리지 복구 — QA 재검증 리포트 (3차)

**판정: PASS** — QA_REPORT_2 의 FAIL 사유였던 MEDIUM #2(하네스 커버리지 후퇴)가 실제로 복구됐다.
`qa_p0_plates_all` 이 **4해상도 × 세이브 유/무 2상태**에서 "선택 판때기 정확히 1개"와
"포커스 해제 = 강조 0개"를 다시 단언하고, 삭제된 `qa_f8_title_shots` 가 단언하던 항목이
**빠짐없이** 통합 하네스에 들어와 있음을 git 이력과 한 줄씩 대조해 확인했다.
기준(대비 3.0:1 / 밝기 임계 0.35)은 낮추지 않았고, negative control 로 하네스가
결함을 실제로 잡는다는 것을 **QA 가 직접 주입해** 확인했다. 회귀 전항목 통과.

- 기준 문서: `docs/JAMO_total_project_development_plan_v0.4.md` §27 / §35 / §44 (단독 1순위)
- 규칙: `docs/ORCHESTRATION_RULES.md` §4, §7, §7.1
- DEV 인계문: `tests/qa_artifacts/p0/P0_DEV3_REPORT.md` — §2 검수 절차 1~12 를 번호 순서대로 수행
- 앞 리포트: `QA_REPORT.md` / `QA_REPORT_2.md` — **둘 다 덮어쓰지 않았다**
- 검증 수단: `mcp__ziva-godot__start_godot` 실제 Godot 조작 + 창 모드 하네스 7종 +
  헤드리스 테스트 2종 + negative control 2종(DEV 스크립트 재현 1 + QA 자작 1)
- Godot 4.7.stable / Intel UHD 770 / Windows 11

---

## 0. 요약표

| # | 태스크 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 커버리지 복구 (FAIL 사유였던 항목) | **PASS** | `nothing_focused` 8/8, 표 178행, 삭제분 대조표 누락 0 (1절) |
| 2 | 기준을 낮춰 통과시킨 것인지 | **PASS** | `REQUIRED_CONTRAST = 3.0` / `BRIGHT_LUMA = 0.35` 무변경. sweep 축소는 실질 손실 아님 (2절) |
| 3 | negative control | **PASS** | DEV 스크립트 재현 21건 정확 일치 + QA 자작 base 주입 82건 검출 (3절) |
| 4 | 실행 시간 154초 | **감당 가능** | 조건부 의견 (4절) |
| 5 | 회귀 | **PASS** | 정적 0에러, 헤드리스 2/2, 창 모드 7/7, 실조작 §35 경로 (5절) |
| 6 | DEV 가 남긴 판단 대상 | **의견 제시** | 결함 #3 유예 타당 / `qa2_plates_4res` 존치 권고 (6절) |

### 이번 사이클 신규 결함

| # | 등급 | 요약 | 위치 |
|---|---|---|---|
| 1 | LOW | 숨겨진 판때기가 선택 아트를 달고 있어도 검출되지 않는다 (삭제된 stylebox 구조 검사는 잡았다) | `tests/qa_p0_plates_all.gd:340` `_bright_plates()` |
| 2 | INFO | DEV 리포트 §2-7 이 720x1280 최저 대비를 4.18:1 로 적었으나 실제 최저는 3.91:1 (둘 다 기준 초과) | `P0_DEV3_REPORT.md` §2-7 |
| 3 | INFO | QA 가 만든 negative control 파일 4개가 `tests/` 에 남아 있다. 삭제 금지 지시 때문에 지우지 못했다 | `tests/_nc_qa3_*.gd/.tscn` |

**FAIL 사유 없음.** 위 3건 모두 제품 동작과 무관하다.

---

## 1. 커버리지 복구 확인 (FAIL 사유였던 항목)

### 1-1. 직접 실행 — 창 모드, 2회 반복

```
godot --path . res://tests/qa_p0_plates_all.tscn      # 1회차 exit 0
godot --path . res://tests/qa_p0_plates_all.tscn      # 2회차 exit 0, 154초
```

두 실행의 결과가 **행 수·최저 대비까지 완전히 동일**했다. 결정적(deterministic)이다.

마지막 줄:

```
OK - one bright plate across all 7 hub plates, 178 pointer/keyboard frames
     at 4 sizes x 2 save states, focus released -> 0 lit in 8/8.
```

`FAIL:` 0건, exit 0.

### 1-2. `nothing_focused` 8줄 — 검수 절차 5 (기대: 8줄, 전부 `bright=[]`)

```
--- 1280x720_nosave_nothing_focused nothing focused: bright=[]
--- 1920x1080_nosave_nothing_focused nothing focused: bright=[]
--- 720x1280_nosave_nothing_focused nothing focused: bright=[]
--- 2560x1080_nosave_nothing_focused nothing focused: bright=[]
--- 1280x720_save_nothing_focused nothing focused: bright=[]
--- 1920x1080_save_nothing_focused nothing focused: bright=[]
--- 720x1280_save_nothing_focused nothing focused: bright=[]
--- 2560x1080_save_nothing_focused nothing focused: bright=[]
```

**8줄, 4해상도 × 2상태 전부. 전부 `bright=[]`.** QA_REPORT_2 §8 재현 절차 2~3 이 지목했던
"1줄뿐이고 나머지 3해상도에는 없다"는 상태가 해소됐다. 항목 (b) **복구 확인**.

### 1-3. 표 178행 — 검수 절차 6 (기대: 43 / 57 / 나머지 12·14)

```
     43  1280x720  nosave      12  1920x1080 nosave      12  720x1280 nosave      12  2560x1080 nosave
     57  1280x720  save        14  1920x1080 save        14  720x1280 save        14  2560x1080 save
                                                                        합계 178
```

DEV 기대값과 **정확히 일치**. 내역: 1280x720 은 판때기별 검사(nosave 12 / save 14) +
순서쌍 전수 sweep(31 / 43). 나머지 3해상도는 판때기별 2N+1 (N=6 → 12, N=7 → 14).

`bright` 열은 **178행 전부 `1`** (다른 값 0건). 항목 (a) **복구 확인**.

발췌 (해상도마다 판때기별 검사가 실제로 돈다는 증거):

```
| 720x1280  | nosave | NewGameButton  | NewGameButton  | 1 | 0.980 | 0.197 | 4.18:1 |
| 720x1280  | nosave | UpgradeButton  | UpgradeButton  | 1 | 0.980 | 0.197 | 4.18:1 |
| 2560x1080 | save   | ContinueButton | ContinueButton | 1 | 0.977 | 0.200 | 4.11:1 |
| 1280x720  | save   | QuitButton     | NewGameButton  | 1 | 0.914 | 0.200 | 3.85:1 |
```

`<none>`(포인터를 메뉴 밖에 뺀 케이스)도 8조합 전부에 존재한다:

```
| 1280x720  | nosave | <none> | NewGameButton | 1 | 0.914 | 0.200 | 3.85:1 |
| 1920x1080 | nosave | <none> | NewGameButton | 1 | 0.914 | 0.200 | 3.85:1 |
| 720x1280  | nosave | <none> | NewGameButton | 1 | 0.917 | 0.197 | 3.92:1 |
| 2560x1080 | nosave | <none> | NewGameButton | 1 | 0.914 | 0.200 | 3.85:1 |
| ... save 4줄 동일 ...
```

### 1-4. 레이아웃·판때기 높이 — 4해상도 × 2상태 유지

```
--- nosave_1280x720  viewport=1280x720  rows_drawn=6 plate=371x49 (6.8% tall)
--- nosave_1920x1080 viewport=1280x720  rows_drawn=6 plate=371x49 (6.8% tall)
--- nosave_720x1280  viewport=1280x2275 rows_drawn=6 plate=371x49 (2.2% tall)
--- nosave_2560x1080 viewport=1706x720  rows_drawn=6 plate=371x49 (6.8% tall)
--- save_*           rows_drawn=8 (동일)
    1280x720 plate height: nosave=49.0 save=49.0
    1920x1080 plate height: nosave=49.0 save=49.0
    720x1280 plate height: nosave=49.0 save=49.0
    2560x1080 plate height: nosave=49.0 save=49.0
```

### 1-5. 삭제된 `qa_f8_title_shots` 전수 대조 — **누락 0**

`git show HEAD:tests/qa_f8_title_shots.gd` (200줄) 을 꺼내 **단언문 한 줄씩** 현재 하네스와 대조했다.
삭제 전 파일에서 `_failures += 1` 이 걸리는 지점은 총 6종이다.

| # | 삭제 전 단언 (`qa_f8_title_shots.gd`) | 삭제 전 범위 | 지금 (`qa_p0_plates_all.gd`) | 지금 범위 | 판정 |
|---|---|---|---|---|---|
| 1 | `_check_single_selection(name)` — 버튼별 focus 후 선택 판때기 정확히 1개 (`:89`) | 4해상도 × 2상태, 버튼 4개 | `_sweep_each_plate` → `_measure` 의 `bright.size() != 1` + `bright[0] != focused` | **4해상도 × 2상태, 판때기 7개, 포인터·키보드 양 경로** | **흡수(상위집합)** |
| 2 | `_check_single_selection("")` — 포커스 해제 후 0개 (`:79`) | 4해상도 × 2상태 | `_measure_nothing_focused` (`:126`) | **4해상도 × 2상태 (8/8)** | **흡수** |
| 3 | 뷰포트 이탈 없음 (`:128`) | 4해상도 × 2상태 | `_measure_layout` — 코드 동일 | 4해상도 × 2상태 | 흡수 |
| 4 | 행 간격 == `separation` (`:133`) | 4해상도 × 2상태 | `_measure_layout` — 코드 동일 | 4해상도 × 2상태 | 흡수 |
| 5 | 열 정렬 x·width (`:139`) | 4해상도 × 2상태 | `_measure_layout` — 코드 동일 | 4해상도 × 2상태 | 흡수 |
| 6 | 세이브 유무로 판때기 높이 불변 (`:154`) | 4해상도 | `_check_plate_height_ignores_the_save` — 코드 동일 | 4해상도 | 흡수 |
| — | 버튼 폭 % / `logo_bottom` / `box_top` 출력 (`:110`) | 출력만, `_failures` 안 걸림 | 높이 %만 출력 | — | 단언 아님 (QA_REPORT_2 §2-1 과 같은 분류) |

**단언 6종 전부 복구됐고, 범위가 삭제 전보다 넓어졌다.**
QA_REPORT_2 §2-1 에서 "후퇴"로 표시했던 두 행(#1, #2)이 이번에 4해상도 × 2상태로 돌아왔다.

추가로 `qa_f8_hover_focus` / `qa_f9_hover_focus` / `qa_f9_verify_real_input` 3종은
QA_REPORT_2 §2-1 에서 이미 "손실 없음"으로 확인했고, 이번 변경으로 좁아진 곳이 없는지
다시 봤다 — `_measure` / `_plate_luma` / `_contrast` / `_walk_to` / `_sweep` 의 단언은
그대로이고 `_bright_plates()` 추출과 좌표 스케일 보정만 더해졌다.

#### 다만 한 가지 방식 차이 — 신규 결함 #1 (LOW)

삭제 전 #1·#2 는 **stylebox override 구조 검사**였고, 지금은 **픽셀 휘도**다.
렌더 결과를 직접 읽으므로 대개 더 강하지만, 한 곳이 좁다:

- `_bright_plates()` (`tests/qa_p0_plates_all.gd:340`) 는 `not button.visible` 인 판때기를 건너뛴다.
- 삭제 전 `_check_single_selection()` 은 `BUTTONS` 를 가시성과 무관하게 돌았으므로,
  세이브가 없어 숨겨진 `ContinueButton` 이 선택 아트를 달고 있으면 잡았다.

숨은 판때기는 화면에 아무것도 그리지 않으므로 플레이어가 볼 수 있는 결함은 아니다.
등급 LOW, FAIL 사유 아님. 고치려면 `_bright_plates` 옆에 "숨은 판때기는 `normal` override 를
갖지 않는다" 한 줄을 더하면 된다.

### 1-6. 씬 유래 유지 — 하드코딩 회귀 없음

```
hub plates: NewGameButton, ContinueButton, UpgradeButton, CodexButton,
            RecordsButton, SettingsButton, QuitButton
```

- `git diff` 확인: `const ALL_PLATES` 하드코딩 배열이 삭제되고 `HubPlates.all()` 로 대체됐다.
- `HubPlates.problem()` 가드는 `_ready()` 초반에 그대로 호출된다 (`tests/qa_p0_plates_all.gd:76`).
- `tests/hub_plates.gd` 는 이번 사이클에 **무변경**(`git status` 상 `??` 그대로, 내용 동일).
- 유래 negative control 은 QA_REPORT_2 §2-2 에서 이미 통과했고 이번에 코드가 안 바뀌었다.

---

## 2. 기준을 낮춰 통과시킨 것인지

### 2-1. 임계값 무변경 — 확인

```
$ git diff tests/qa_p0_plates_all.gd | grep -E "REQUIRED_CONTRAST|BRIGHT_LUMA|MAX_ARROW"
(출력 없음 — 세 상수 모두 diff 에 나타나지 않는다)

const BRIGHT_LUMA := 0.35
const REQUIRED_CONTRAST := 3.0
const MAX_ARROW_PRESSES := 12
```

- **대비 임계값 3.0:1 그대로.** 완화 없음.
- 밝기 임계 `0.35`, 방향키 최대 횟수 `12` 도 그대로.
- `_contrast()` / `_plate_luma()` 의 **계산식**도 안 바뀌었다. 바뀐 것은 `_plate_luma` 가
  캡처 프레임 크기에 맞춰 샘플 좌표를 스케일하는 부분뿐인데, 이것은 기준 완화가 아니라
  **1280x720 밖에서 판때기가 아닌 픽셀을 읽던 버그의 수정**이다. (보정 전에는 720x1280 에서
  배경을 읽어 "안 밝음"으로 통과했다 — 완화가 아니라 강화다.)

실측 최저 대비:

| 창 | 최저 대비 (1회차 = 2회차) |
|---|---|
| 1280x720 | 3.85:1 |
| 1920x1080 | 3.85:1 |
| 720x1280 | **3.91:1** |
| 2560x1080 | 3.85:1 |

전체 최저 **3.85:1 ≥ 3.0:1**. DEV 보고(3.85)와 일치.
DEV 가 720x1280 을 4.18:1 로 적은 것은 포인터 패스 행의 값이고, 그 해상도의 **최저**는
키보드 패스의 3.91:1 이다 (신규 결함 #2, INFO — 둘 다 기준 초과라 판정에 영향 없음).

### 2-2. sweep 축소가 실질 커버리지 손실인가 — **손실 아님으로 판정**

DEV 는 "순서쌍 전수 sweep 은 1280x720 1회 유지, 나머지 3해상도는 판때기별 검사로 대체" 했다.
잃은 것은 **(순서쌍, 해상도) 조합**이다. 그것이 실제 결함을 놓칠 수 있는지 따졌다.

**(1) 어떤 판때기가 밝은지는 해상도와 무관하다.**
선택 아트는 `Control` 의 focus/hover 상태 기계가 붙였다 떼는 `normal` stylebox override 다.
여기에 창 크기가 들어오는 경로는 없다. 순서쌍 (h, f) 가 만드는 "두 개 밝음"은 상태 기계
결함이고, 그것은 1280x720 의 전수 sweep 74쌍이 잡는다.

**(2) 해상도가 실제로 바꾸는 것 두 가지는 모든 해상도에서 검사된다.**

| 해상도가 바꾸는 것 | 4해상도에서 검사되는가 |
|---|---|
| 히트테스트 (호버가 판때기에 맞는가) | **예** — 판때기별 패스가 해상도마다 **판때기 N개 전부**를 호버하고 `hovering %s did not take the focus` 를 단언한다 |
| 프레임 안의 판때기 위치 (어느 픽셀을 읽는가) | **예** — `_measure` 는 매 프레임 `_all_plates` **전부**를 샘플한다. 해상도당 12~14프레임 × 7판때기 = 84~98회 샘플 |
| 레이아웃(이탈·간격·정렬·높이) | **예** — `_measure_layout`, 4해상도 × 2상태 |

**(3) 남는 잔여 위험**: "특정 순서쌍 **그리고** 특정 해상도" 두 조건이 동시에 필요한 결함.
이런 결함이 성립하려면 그 해상도에서만 판때기 rect 가 겹치거나 엇나가야 하는데,
그 상태 자체를 `_measure_layout` 의 이탈·간격·정렬 단언이 먼저 잡는다. 또 호버가 다른
판때기로 새면 판때기별 패스의 포커스 단언이 그 해상도에서 바로 FAIL 한다.
**따라서 축소로 새로 뚫린 구멍은 없다.** 이론적 잔여분도 3절 negative control 에서
실제로 잡힌다는 것을 확인했다 (1920x1080 의 대비 결함이 판때기별 패스만으로 13건 검출).

**(4) 그래도 남겨 둘 것**: `qa2_plates_4res` 가 4해상도 × 순서쌍 전수(296쌍)를 도는
유일한 하네스다. 위 잔여 위험의 실증 수단이므로 지우지 말 것을 권고한다 (6절).

---

## 3. Negative control — QA 가 직접 주입

프로덕션 코드는 건드리지 않았다. `qa_p0_plates_all.gd` 를 **상속**해 `_settle()` 앞뒤에
결함을 심는 서브클래스 두 개를 `tests/` 아래에 만들어 돌렸다.

### 3-A. DEV §4 스크립트 재현 — DEV 보고와 **완전 일치**

`tests/_nc_qa3_dev.gd` / `.tscn` (DEV 리포트 §4 원문 그대로 재입력)

```
godot --path . res://tests/_nc_qa3_dev.tscn      exit 1
FAILED - 21 check(s) failed.
```

| 주입한 결함 | 대상 조합 | 기대 | 실제 검출 |
|---|---|---|---|
| 포커스 판때기를 흐린 회색으로 (대비 미달) | 1920x1080 nosave / save | FAIL | **6 + 7 = 13건**, 전부 `selection cue is only 2.00:1, want >= 3.0:1` |
| `QuitButton` 을 남의 포커스 중에도 켜 둠 (두 판때기 동시 강조) | 2560x1080 save | FAIL | **7건**, `lit 2 plates [..., "QuitButton"]` |
| 포커스 해제 후 `NewGameButton` 강조 잔류 | 720x1280 nosave | FAIL | **1건**, `["NewGameButton"] stayed lit with nothing focused` |
| (주입 없음) | 1280x720 전부 | 통과 | **FAIL 0건** |

합계 21건 — DEV 보고 "1920x1080 nosave 6 + save 7, 2560x1080 save 7, 720x1280 nosave 1,
1280x720 0" 과 **건수·조합·메시지까지 동일**하다. 세 결함 유형 모두 하네스가 잡는다.

발췌:

```
  FAIL: 1920x1080_nosave_pointer_QuitButton_keyboard_SettingsButton selection cue is only 2.00:1, want >= 3.0:1
  FAIL: 2560x1080_save_... lit 2 plates [..., "QuitButton"], want exactly 1
  FAIL: 720x1280_nosave_nothing_focused: ["NewGameButton"] stayed lit with nothing focused
--- 720x1280_nosave_nothing_focused nothing focused: bright=["NewGameButton"]
```

### 3-B. **1280x720 이 0 인 것이 정상인지** — QA 자작 대조군으로 판정

DEV 스크립트는 `_window_tag() == "1280x720"` 을 명시적으로 비켜 간다. 따라서 그 0 은
"기저 해상도 패스가 살아 있다"는 증거가 **아니라** 오탐(false positive)이 없다는 증거일 뿐이다.
기저 패스가 죽어 있어도 똑같이 0 이 나온다. 그래서 **같은 세 결함을 1280x720 에만** 주입했다.

`tests/_nc_qa3_base.gd` / `.tscn` (QA 작성)

```
godot --path . res://tests/_nc_qa3_base.tscn      exit 1
FAILED - 82 check(s) failed.

  FAIL: 1280x720_nosave_pointer_QuitButton_keyboard_SettingsButton selection cue is only 2.00:1, want >= 3.0:1
  FAIL: 1280x720_save_... lit 2 plates [..., "QuitButton"], want exactly 1
  FAIL: 1280x720_nosave_nothing_focused: ["NewGameButton"] stayed lit with nothing focused
```

| 조합 | 검출 |
|---|---|
| 1280x720 nosave | 38건 (대비 미달 37 + 해제 후 잔류 1) |
| 1280x720 save | 38건 (두 판때기 동시 강조) |
| 1920x1080 save | 6건 — 아래 주 |

> 1920x1080 의 6건은 QA 주입기의 정리 누락이다. 1280x720 에서 붙인 `QuitButton` override 를
> 창이 바뀔 때 떼지 않아 다음 해상도로 흘러갔다. 결과적으로 **"이전 해상도에서 흘러든 잔류
> 강조"까지 다음 해상도 패스가 잡는다**는 것을 덤으로 보여 준다.

**판정: 1280x720 이 0 인 것은 정상이다.** DEV 스크립트가 그 해상도를 의도적으로 건드리지
않았기 때문이며, 실제로 주입하면 기저 패스는 82건을 잡는다. 기저 패스는 죽어 있지 않다.

### 3-C. 대조 기준선

같은 파일들이 트리에 있는 상태로 프로덕션 하네스를 다시 돌려 exit 0 / FAIL 0 / 178행을
재확인했다(1-1 의 2회차). 서브클래스는 프로덕션 하네스의 동작을 바꾸지 않는다.

---

## 4. 실행 시간 — 154초

측정: **154초** (실측, DEV 보고 160초와 부합). 이전 86초 대비 +68초.

**판정: 매 사이클 돌리기에 감당 가능하다.** 근거와 조건:

- 창 모드 하네스 전체 1회분이 **154 + 13 + 4 + 11 + 3 + 30 + 3 = 218초 (약 3분 40초)** 다.
  헤드리스 2종과 정적 로드를 더해도 4분을 넘지 않는다. 사람이 기다릴 수 있는 범위다.
- 늘어난 시간의 정체는 프레임 대기(`_settle()` 8프레임 × 측정 횟수)이지 연산이 아니다.
  74프레임 → 178프레임으로 2.4배 늘었는데 시간은 1.8배다.
- 대안(순서쌍 sweep 을 4해상도로 복제)은 DEV 추산 5분 30초였다. 지금 선택이 더 싸다.
- 두 번 돌려 결과가 **완전히 동일**했다. 시간을 들여도 흔들리는 값이 아니므로 실패 시
  재현 비용이 낮다. 이것이 "감당 가능"의 실질 근거다.

**단서 하나**: 판때기별 패스는 판때기 수 N 에 선형(2N+1)이고 해상도 수에 선형이다.
허브 메뉴는 Phase 마다 늘어난다(§27). 판때기가 12개가 되면 이 하네스는 대략 **240초** 가 된다.
그 시점에는 (a) `_settle()` 프레임 수를 8 → 4 로 줄이거나, (b) 판때기별 패스를 2해상도로 줄이고
`qa2_plates_4res` 를 사전-머지 전용으로 돌리는 식의 재조정이 필요하다.
**지금 손댈 일은 아니다** — 지금은 커버리지가 더 값지다.

---

## 5. 회귀

### 5-1. 정적 / 헤드리스 — 검수 절차 1~3

| 항목 | 결과 |
|---|---|
| `godot --headless --path . --quit` | **exit 0**, 에러 2줄 = `NotoSansKR-Regular.ttf` 누락뿐 (기존 이슈, §7.1) |
| `test_state_split.tscn` | **exit 0** · `MetaState 10 state fields, RunState 16` · `OK - meta/run split holds.` |
| `test_run_flow.tscn` | **exit 0** · `OK - Wave 1 started, the run failed, and the hub came back.` |

### 5-2. 창 모드 하네스 — 검수 절차 4, 11

| 하네스 | exit | 시간 | 마지막 줄 |
|---|---|---|---|
| `qa_p0_plates_all` | 0 | 154s | `OK - ... 178 pointer/keyboard frames ... focus released -> 0 lit in 8/8.` |
| `qa_p0_flow` | 0 | 13s | `OK - the Phase 0 path, the resume rules and the v0.3 migration all held.` |
| `qa_f7_title` | 0 | 4s | `OK - title screen checks passed.` |
| `qa_f7_art` | 0 | 11s | `DONE` (FAIL 0) |
| `qa_f8_labels` | 0 | 3s | `OK - pristine title frames written.` |
| `qa_f8_focus_all` | 0 | 30s | `OK - focus indicator meets 3.0:1 and the dialog fits its contents.` |
| `qa_f8_resize` | 0 | 3s | FAIL 0 |

7/7 통과. 태스크가 지정한 6종 + 대상 하네스 전부다.

### 5-3. §35 전체 경로 — 실제 Godot 조작 (ziva-godot MCP)

`mcp__ziva-godot__start_godot` 으로 에디터를 띄우고 `res://scenes/ui/title_screen.tscn` 을
실행해 **마우스로 직접** 조작했다. 헤드리스 대체 없음.

| 단계 | 확인한 것 |
|---|---|
| Main Hub | 판때기 6개(세이브 없음), **크림색 선택 아트가 `RUN 시작` 하나에만**. 우상단 영구 성장 패널 `GOLD 0 G / 최고 WAVE 1 / 발견 단어 0 / 10 / 처치 보스 0` |
| RUN 시작 | `WAVE 1` 전환. HUD `문장핵 20 / 20`, `ENERGY 20 / 20`, `0 G`, `처치 0`, 좌하단 `장착한 단어 없음 — 자모 슬롯은 P2` |
| Wave 1 | 몬스터를 실제로 클릭 → `ENERGY 17 / 20` 으로 감소(3히트 1미스). 클릭이 **맞았을 때만** 에너지가 준다 |
| 실패 | 20에너지 소진 시점에 결과 화면 출현. HUD 는 같은 프레임에 `문장핵 20 / 20`, `ENERGY 0 / 20`, `12 G`, `처치 4` |
| 결과 화면 | `RUN 종료` / `에너지가 바닥나 RUN 이 끝났다. 다음 RUN 은 WAVE 1 부터 시작한다.` / `도달 WAVE 1` / `처치 4` / `획득 GOLD 12 G (유지됨)` / `GOLD · 단어 도감 · 숙련도 · 보스 기록 · 최고 WAVE 는 그대로 남는다.` / `신규 단어 / 숙련 상승 / 합성어 / 보스 정산은 이후 Phase 에서 추가된다.` / `[메인 허브로]` |
| Hub 복귀 | 결과 화면 이후 허브 복귀 확인. 이어서 `영구 업그레이드` 패널까지 열어 값 확인 (`최대 에너지 Lv.0 20 → 21`, `클릭 피해 Lv.0 1 → 2`, `치명 클릭 잠김`, ...) |

부수 확인:

- **RUN 덮어쓰기 보호 동작**: 진행 중인 RUN 이 있을 때 `RUN 시작` 을 누르면
  `새 RUN 시작 — 진행 중인 RUN 이 사라지고 WAVE 1 부터 다시 시작합니다. GOLD 와 단어 도감은
  그대로 남습니다.` 대화상자가 뜨고 `새로 시작` / `취소` 가 동작한다.
- **결과 화면 문구는 HUD 와 모순 없다**: 문장핵 20/20 (멀쩡) + 에너지 0/20 (고갈)인데
  문구가 말하는 실패 원인도 에너지다. `문장핵이 무너졌다` 는 화면 어디에도 없다.
  QA_REPORT_2 §4 의 PASS 가 이번에도 유효하다.
- **24초간 아무것도 클릭하지 않고 방치**했을 때 `문장핵 20 / 20` 이 그대로였다.
  문장핵은 P0 에 구현돼 있지 않고(DEV 인계문과 일치), 유일한 실패 경로는 에너지다.
- **State 경계가 실제 저장 파일에서 확인됐다**: 실패 후 `jamo_save.json` 에
  `meta` 블록만 있고 `run` 블록이 **없다**. `gold: 12.0`, `highest_wave: 1`,
  `statistics.runs_finished: 1` 는 남았다. §7 / v0.4 §44 준수.

### 5-4. 직전 사이클 PASS 3건 재확인

| 항목 | 이번 결과 | 근거 |
|---|---|---|
| v0.3 마이그레이션 안내문 대비 (HIGH) | **유효** | `qa_p0_flow` exit 0 이 안내문 대비와 `font_color` 일치를 단언한다. `git diff theme/jamo_theme.tres` 는 QA_REPORT_2 확인 시점과 동일(추가 5줄, 변경 0). `scenes/ui/title_screen.tscn` 도 이번 사이클 무변경 |
| State 겹침 검사 9/9 (MEDIUM) | **유효** | `git diff tests/test_state_split.gd` 가 QA_REPORT_2 확인 시점과 동일(이번 사이클에서 안 건드림). `test_state_split` exit 0, `MetaState 10 / RunState 16` 동일 |
| 결과 화면 문구 (MEDIUM) | **유효** | 5-3 에서 실제 RUN 실패로 직접 재확인. `scripts/ui/run_result.gd` / `scenes/ui/run_result.tscn` 이번 사이클 무변경 |

> 이번 사이클의 변경 파일은 `tests/qa_p0_plates_all.gd`, `docs/ORCHESTRATION_RULES.md`,
> `tests/qa_artifacts/p0/P0_DEV3_REPORT.md` 셋뿐이다(DEV 리포트 §1 과 `git diff` 일치).
> 제품 코드 변경 0 이므로 위 3건이 깨질 경로가 없고, 그래도 각각 실행으로 확인했다.

### 5-5. F7~F9 확정 사항 유지

| 확정 사항 | 결과 | 근거 |
|---|---|---|
| 선택된 판때기 1개 | PASS | 178프레임 × 4해상도 × 2상태, `bright` 열 전부 1 |
| 포커스 해제 시 0개 | PASS | 8/8 `bright=[]` |
| 선택 대비 ≥ 3.0:1 | PASS | 최저 3.85:1 |
| 포커스 사각 박스 없음 (허브) | PASS | `theme/jamo_theme.tres` `TitleButton/styles/focus = StyleBoxEmpty` 무변경, `qa_f7_title` exit 0 |
| 타이틀 외 화면 포커스 테두리 존치 | PASS | `qa_f8_focus_all` exit 0 · `median=9.84:1 above_3.0=87.0%` (2560x1080 QuitButton), 설정 패널 포커스 링 5개 도달 |
| 마우스 호버 우선 | PASS | 판때기별 패스와 sweep 이 매 호버마다 `hovering %s did not take the focus` 를 단언, 위반 0 |
| 버튼 크기 화면 비율 기준 | PASS | 6.8% (1280x720 / 1920x1080 / 2560x1080), 2.2% (720x1280 — 뷰포트가 1280x2275) |
| 4해상도 레이아웃 | PASS | 8조합, 이탈·간격·정렬 위반 0 |
| 세이브 유무로 판때기 높이 불변 | PASS | 4해상도 전부 `nosave=49.0 save=49.0` |

### 5-6. 에디터 가시성 (ORCH §4-4)

이번 사이클은 **새 씬/리소스를 추가하지 않았다**(변경 3파일: 하네스 1, 문서 2).
검사 대상이 없어 해당 없음. 대신 같은 ziva-godot 세션에서 `title_screen.tscn` 을 실제로
실행해 허브·RUN·결과 화면을 눈으로 확인했다(5-3).

---

## 6. DEV 가 남긴 판단 대상

### 6-1. QA 결함 #3 (`qa_f7_art` / `qa_f7_title` 의 `HubPlates.problem()` 미호출) — **유예 타당**

현재 상태 확인:

```
tests/qa_p0_plates_all.gd:76   HubPlates.problem(_title)     <- 호출
tests/qa_f8_focus_all.gd:44    HubPlates.problem(_title)     <- 호출
tests/qa_f8_labels.gd:21       HubPlates.problem(title)      <- 호출
tests/qa2_plates_4res.gd:47    HubPlates.problem(_title)     <- 호출
tests/qa_f7_art.gd:99          HubPlates.all(_title)         <- 가드 없음
tests/qa_f7_title.gd:41        HubPlates.interactive(title)  <- 가드 없음
```

**유예에 동의한다.** 근거:

1. 유래가 깨지면 같은 사이클에서 `qa_p0_plates_all` / `qa_f8_focus_all` / `qa_f8_labels`
   **셋이 동시에 FAIL** 한다. 검수 절차는 이들을 전부 돌리게 돼 있으므로(§7.1),
   사이클 전체가 조용히 통과할 수는 없다. 위험은 "이 두 하네스만 단독으로 돌린 경우"로 좁다.
2. `qa_f7_art` / `qa_f7_title` 은 **판때기 개수**가 아니라 판때기 **각각의 성질**
   (아트 대비, 키보드 도달)을 본다. 목록이 짧아져도 거짓 PASS 는 나오지만 거짓 FAIL 은 안 난다.
3. 이번 태스크는 커버리지 복구 1건이었고, 무관한 파일을 건드리지 않은 것이 §3 최소 변경에 맞다.

**권고**: 다음에 허브 메뉴나 `hub_plates.gd` 를 건드리는 사이클에서 2줄씩 넣어 닫는다.
LOW 유지, FAIL 사유 아님.

### 6-2. `qa2_plates_4res` 처리 — **존치 권고, 다만 위치를 명시할 것**

중복 정도를 실측 기준으로 따졌다.

| 검사 | `qa_p0_plates_all` (지금) | `qa2_plates_4res` |
|---|---|---|
| 선택 판때기 1개 · 대비 ≥ 3.0:1 | 4해상도 × 2상태, 178프레임 | 4해상도 × 2상태, **296쌍** |
| 순서쌍 (호버, 포커스) 전수 | **1280x720 만** | **4해상도 전부** |
| 포커스 해제 = 0개 | 8/8 | 8/8 |
| 레이아웃 / 판때기 높이 | 있음 | 없음 |

**겹치지 않는 부분이 정확히 하나 있다**: 2-2 (3) 에서 "잔여 위험"으로 남긴
(순서쌍 × 해상도) 조합을 실제로 도는 것은 `qa2_plates_4res` 뿐이다.
지금은 그 위험이 이론적이라고 판정했지만, 판정의 **실증 수단 자체를 지우는 것**은
다음에 같은 논쟁이 생겼을 때 하네스를 다시 짜야 한다는 뜻이다 (이번 사이클이 그랬다).

**권고**:

1. `qa2_plates_4res` 를 **지우지 말고 존치**한다.
2. 다만 **매 사이클 필수 목록에는 넣지 않는다.** `docs/ORCHESTRATION_RULES.md` §7.1 의
   창 모드 하네스 목록에 한 줄을 더해 성격을 명시할 것을 제안한다:
   > `qa2_plates_4res` 는 4해상도 × 순서쌍 전수(296쌍) 광역 sweep 이다. 매 사이클 필수는
   > 아니고, 허브 메뉴·테마·레이아웃을 건드린 사이클에서만 추가로 돌린다.
3. `tests/qa_artifacts/p0/plates4res/` 에 남은 하네스 개발 중 실패 프레임 PNG 들은
   `.gitignore` 로 커밋에서 빠지므로 방치해도 커밋에 영향이 없다 (QA_REPORT_2 §7 의 요청 유지).

---

## 7. QA 가 추가/변경한 파일 · 임시 변경 원복

### 추가 (전부 `tests/` 아래, 프로덕션 무수정)

```
tests/_nc_qa3_dev.gd / .tscn           negative control A — DEV §4 스크립트 재현 (3-A)
tests/_nc_qa3_base.gd / .tscn          negative control B — 1280x720 주입 (3-B)
tests/qa_artifacts/p0/QA_REPORT_3.md   이 문서
tests/qa_artifacts/p0/plates/*.png     하네스가 생성 (.gitignore 대상)
```

### 원복 상태

- **프로덕션 파일 수정 0.** 두 negative control 은 `qa_p0_plates_all.gd` 를 **상속**만 하고
  원본을 고치지 않는다. `git diff` 상 DEV 변경분 외 새 `M` 없음.
- **주입은 프로세스 수명 한정**이다. `add_theme_stylebox_override` 를 실행 중 인스턴스에만
  걸고 `.tscn` / `.tres` 를 저장하지 않는다. 주입 후 프로덕션 하네스를 다시 돌려
  exit 0 / 178행 / FAIL 0 을 확인했다 (3-C).
- **`tests/_nc_qa3_*` 4개 파일은 트리에 남아 있다.** 태스크의 "파일 삭제 계열 명령 금지"
  때문에 지우지 못했다 (신규 결함 #3, INFO). `??` 상태이므로 커밋 범위에서 제외하거나
  Coordinator 가 정리해 달라. 남아 있어도 프로덕션 하네스 동작에는 영향이 없다.
- **플레이어 세이브**: QA 시작 시 `jamo_save.json` 은 **없었다**(`.qabak` / `.qa2manualbak` 만 존재).
  ziva-godot 실조작이 만든 세이브는 검증 후 `jamo_save.json.qa3playtestbak` 으로 옮겨
  **시작 상태(세이브 없음)로 되돌렸다**. 하네스들은 각자 `_stash_save()` / `_restore_save()` 로
  스스로 되돌리며, 검수 절차 12 대로 실행 전후가 같음을 확인했다.
- Godot 프로세스를 kill 하지 않았다. 파일 삭제 계열 명령을 쓰지 않았다.
- `QA_REPORT.md` / `QA_REPORT_2.md` 를 **덮어쓰지 않았다**.

---

## 8. 판정

**PASS.**

QA_REPORT_2 의 FAIL 사유(MEDIUM #2)는 해소됐다. 삭제된 `qa_f8_title_shots` 의 단언 6종이
전부, 삭제 전과 같거나 넓은 범위로 `qa_p0_plates_all` 에 들어와 있고, 로그가 그것을 증명한다
(`nothing_focused` 8/8, 표 178행, `bright` 전부 1, 최저 3.85:1). 기준은 낮추지 않았다.
sweep 축소는 실질 커버리지 손실이 아니며, negative control 로 세 결함 유형이 4해상도 전부와
기저 해상도에서 검출됨을 QA 가 직접 주입해 확인했다. 회귀 전항목 통과.

남은 3건(LOW 1 / INFO 2)은 제품 동작과 무관하고 다음 사이클 후보다.
