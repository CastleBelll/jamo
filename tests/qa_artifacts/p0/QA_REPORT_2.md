# JAMO P0 이월 4건 — QA 재검증 리포트 (2차)

**판정: FAIL** — 이월 4건 중 3건(HIGH #1 / MEDIUM #3 / MEDIUM #4)은 고쳐졌고 재현으로 확인했다.
**MEDIUM #2 (하네스 통합)은 커버리지 후퇴가 실재하므로 FAIL 이다.**

삭제된 `qa_f8_title_shots` 가 **4해상도 × 2세이브상태**에서 단언하던
"선택된 판때기 1개" / "포커스 해제 시 0개" 두 규칙이, 통합 하네스
`qa_p0_plates_all` 에서는 **1280x720 1해상도**(포커스 해제는 `nosave` 1케이스)로 줄었다.
DEV 인계문은 "검증 커버리지 손실은 없고 스크린샷 장수만 줄었다"고 적었으나 사실과 다르고,
그 문장이 `docs/ORCHESTRATION_RULES.md` §7.1 에 그대로 반영돼 있다.

**단, 제품 동작 자체는 정상이다.** QA 가 직접 만든 `tests/qa2_plates_4res.tscn` 으로
4해상도 × 2상태 × 판때기 7개 × 포인터/키보드 **296쌍**을 재측정한 결과 위반 0건,
최저 선택 대비 3.85:1 (기준 3.0:1)이다. 즉 고칠 것은 **하네스 한 곳**이고 제품이 아니다.

- 기준 문서: `docs/JAMO_total_project_development_plan_v0.4.md` §27 / §35 / §44 (단독 1순위)
- 규칙: `docs/ORCHESTRATION_RULES.md` §4, §7, §7.1
- DEV 인계문: `tests/qa_artifacts/p0/P0_CARRYOVER_REPORT.md` — 검수 절차 1~20 전수 수행
- 1차 리포트: `tests/qa_artifacts/p0/QA_REPORT.md` (덮어쓰지 않았다)
- 검증 수단: `mcp__ziva-godot__start_godot` 실제 Godot 조작 + 창 모드 하네스 9종 +
  헤드리스 테스트 3종 + 스크래치 사본 negative control 9종
- Godot 4.7.stable / Intel UHD 770 / Windows 11

---

## 0. 요약표

| # | 이월 항목 | 등급 | 결과 | 근거 |
|---|---|---|---|---|
| 1 | v0.3 마이그레이션 안내문 대비 | HIGH | **PASS** | 독립 측정 최저 **8.27:1** (기준 4.5:1), 배경 5종 무의존 |
| 2 | 허브 판때기 하네스 통합 | MEDIUM | **FAIL** | 4해상도 단언 2종이 1해상도로 축소 (아래 대조표) |
| 3 | State 겹침 구조 검증 | MEDIUM | **PASS** | negative control **9/9** 검출 (NC0 기준선 + NC1~NC8) |
| 4 | 결과 화면 문구 | MEDIUM | **PASS** | 실제 RUN 실패로 확인, HUD 와 모순 없음, 되돌릴 지점 2곳 명시 |
| 5 | 회귀 (§35 전체 경로 / F7~F9 확정 사항) | — | **PASS** | 실조작 + 하네스 |
| 6 | 자동 테스트 | — | **PASS** | 정적 0에러(폰트 제외), 테스트 3/3, 창 모드 하네스 9/9 |

### 신규 결함 목록

| # | 등급 | 요약 | 위치 |
|---|---|---|---|
| 1 | **MEDIUM** | "선택 판때기 1개" / "포커스 해제 시 0개"가 1280x720 에서만 단언된다 (이전 4해상도) | `tests/qa_p0_plates_all.gd:80,87` |
| 2 | MEDIUM | DEV 인계문·`ORCHESTRATION_RULES` §7.1 이 커버리지 손실을 "없다"고 기술 | `P0_CARRYOVER_REPORT.md` §3-2, `ORCHESTRATION_RULES.md` §7.1 |
| 3 | LOW | `qa_f7_art` / `qa_f7_title` 이 `HubPlates.problem()` 를 부르지 않아, 유래가 깨져도 조용히 부분집합을 검사한다 | `tests/qa_f7_art.gd:99`, `tests/qa_f7_title.gd:41` |
| 4 | LOW | 안내문이 제외 항목으로 DAY 만 말한다. 자모 인벤토리·목표 단어도 폐기되는데 언급이 없다 | `scenes/ui/title_screen.tscn:160` |
| 5 | INFO | `_deferred_v03/test_day_flow.tscn` 을 도는 Godot 프로세스(PID 40896)가 이전 세션부터 매달려 있다 | 환경 |

---

## 1. HIGH — v0.3 마이그레이션 안내문 (PASS)

### 1-1. 재현

DEV 절차 5~8 을 그대로 수행했다. `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 에
v0.3 형식 파일을 직접 써 넣고 마이그레이션을 발생시켰다.

```json
{"save_version":1,"day":42,"gold":1234.5,"upgrade_levels":{"click_damage":3},
 "unlocked_words":["fire_001"],"jamo_inventory":{"ㅂ":2},"target_word":"fire_002"}
```

실제 Godot(ziva-godot MCP)에서 허브를 띄워 눈으로 확인했다. 크림 패널 위 짙은 적갈색으로
또렷하게 읽힌다. `GOLD 1234 G` / `최고 WAVE 1` / `발견 단어 1 / 10` — DEV 기대값과 일치.

### 1-2. DEV 측정값 재현

`godot --path . res://tests/qa_p0_flow.tscn`:

```
notice contrast: ink=(0.2784, 0.0745, 0.0431, 1.0) L=0.0183
                 behind=(0.949, 0.902, 0.8078, 1.0) L=0.7993 -> 12.44:1 (13776 px)
```

DEV 보고와 동일하다. **다만 이 수치는 그대로 받지 않았다.** `qa_p0_flow` 의 방식은
"안내문 사각형 안에서 가장 어두운 픽셀 ÷ 가장 밝은 픽셀"이라, 글자가 자기 아웃라인에 대해
읽히는 경우와 사각형 어딘가의 밝은 픽셀로 비율을 번 경우를 구분하지 못한다.
(글자색이 테마 `font_color` 와 같은지는 별도로 단언하고 있어 절반은 막혀 있다.)

### 1-3. QA 독립 측정 — `tests/qa2_notice_contrast.tscn` (신규)

**잉크 픽셀 하나하나가 자기 주변에 대해** 갖는 대비의 **최악값**을 잰다.
안티에일리어싱 경사면은 글자의 일부이지 배경이 아니므로, 8이웃과의 채널 차가 6 이하인
"평탄(settled)" 픽셀만 배경 후보로 본다. WCAG 2.x 상대휘도(sRGB 역감마 적용) 사용.

배경 의존성을 보기 위해 `Scrim`(사진 위 전면 ColorRect)을 불투명 색으로 바꿔 5종,
`GrowthPanel` 앵커를 옮겨 사진 위 4위치에서 각각 측정했다.

| 케이스 | 잉크 px | **최악 대비** | 중앙값 | 사각형 내 최암 평탄색 대비 |
|---|---|---|---|---|
| photo (원본 사진) | 992 | **8.37:1** | 9.15:1 | 1.35:1 |
| white | 992 | **11.31:1** | 11.31:1 | 11.31:1 |
| **bright_wood (0.80,0.64,0.45)** | 992 | **10.24:1** | 10.24:1 | 6.61:1 |
| outline_cream (아웃라인과 같은 색) | 992 | **10.99:1** | 10.99:1 | 10.99:1 |
| black | 992 | **8.27:1** | 8.27:1 | 1.37:1 |
| photo_topright (원 위치) | 992 | **8.37:1** | 9.15:1 | 1.35:1 |
| photo_topleft | 992 | **8.29:1** | 8.49:1 | 2.22:1 |
| photo_bottomright | 992 | **8.46:1** | 9.11:1 | 2.17:1 |
| photo_bottomleft | 992 | **8.29:1** | 8.44:1 | 1.35:1 |

- **9/9 케이스 전부 4.5:1 이상.** 최저 8.27:1 (검은 배경), 최고 11.31:1 (흰 배경).
- **배경 의존성 없음**: 흰색 ~ 검은색까지 극단을 갈라도 8.27~11.31 범위, 기준선 4.5 에
  근접조차 하지 않는다. 요구된 **밝은 나무 바닥(0.80,0.64,0.45) 위에서 10.24:1**.
- 원인은 크림 아웃라인 6px 이 맞다. 글자 둘레가 항상 크림이라 뒤가 무엇이든 대비가 유지된다.
- 마지막 열(사각형 내 최암 평탄색)이 1.35:1 로 낮은 것은, 측정 상자를 링 탐색용으로
  16px 패딩해 **패널 바깥의 사진/검은 배경까지 포함**하기 때문이다. 글자 배경이 아니다.
- 증거: `tests/qa_artifacts/p0/notice/notice_*.png` (9종 크롭), `flow/09_hub_v03_migrated.png`

> 측정 방법 주석: 첫 시도는 잉크 픽셀에서 고정 반경(3/6/9px) 링의 최암 픽셀을 배경으로 삼았고
> 전 배경에서 동일하게 2.22:1 이 나왔다. 전 배경 동일값 자체가 "잰 것이 배경이 아니라
> 글자 내부 AA 경사면"이라는 증거였다. 위 표는 평탄 픽셀만 배경으로 보도록 고친 뒤의 값이다.

### 1-4. 문구 정확성 — LOW 결함 #4

현재 문구:
`v0.3 세이브를 불러왔다. GOLD·업그레이드·단어는 유지, DAY 기록은 WAVE 로 옮길 수 없어 제외됐다.`

- **보존된 것을 정확히 전달하는가**: 그렇다. `_migrate_v03()` 가 실제로 넘기는 것은
  `gold` / `permanent_upgrade_levels` / `codex_words` 3종이고 문구와 1:1 이다.
- **LOW**: 제외 항목으로 DAY 만 말한다. `autoload/save_manager.gd:246~250` 주석대로
  `jamo_inventory` / `target_word` / `rerolls_left` 도 폐기된다(원본은 `legacy_v03` 에 보존).
  "DAY 기록" 만 읽은 플레이어는 자모 인벤토리가 남았다고 오해할 수 있다.
- 참고: "단어는 유지"가 §38(도감 등록 ≠ 효과 활성)과 충돌하지는 않는다. 실제로
  `RunState.is_word_equipped("fire_001") == false`, `get_burn_effect() == null` 을 확인했고
  negative control NC5 가 이 경계를 지키고 있다(3장).

---

## 2. MEDIUM — 하네스 통합 (**FAIL**)

### 2-1. 삭제된 4개 vs 통합 하네스 — 커버리지 대조표

삭제 전 파일은 `git show HEAD:tests/<name>.gd` 로 꺼내 한 줄씩 대조했다.

#### `qa_f8_hover_focus.gd` (101줄) — 손실 없음

| 검사 항목 | 단언? | `qa_p0_plates_all` 에서 | 판정 |
|---|---|---|---|
| 키보드만 / 혼합 / 호버 해제 / 일치 4장면의 밝은 판때기 수 출력 | **단언 없음**(출력만, 항상 `quit(0)`) | 순서쌍 sweep 이 포함 | 흡수 |

> 이 하네스는 `_failures` 자체가 없어 실패할 수 없었다. 잃은 단언 0개.

#### `qa_f9_hover_focus.gd` (127줄) — 손실 없음

| 검사 항목 | 통합 하네스 | 판정 |
|---|---|---|
| 밝은 판때기 정확히 1개 | `_measure()` `bright.size() != 1` | 흡수 |
| 밝은 것이 기대 판때기인가 | `bright[0] != focused` | 흡수 |
| 키보드 포커스가 기대 판때기인가 | `_walk_to()` 실패 시 FAIL | 흡수(더 강함) |
| 6장면 (키보드→포인터→키보드 되돌아오기 등) | 순서쌍 전수 sweep | 흡수(상위집합) |
| 포커스 이동 수단 | `grab_focus()` | 실제 방향키 → **강화** |
| 판때기 4개 | 7개 | **강화** |

#### `qa_f9_verify_real_input.gd` (233줄) — 손실 없음

| 검사 항목 | 통합 하네스 | 판정 |
|---|---|---|
| 실제 방향키로 포커스 이동, 도달 실패 시 FAIL | `_walk_to()` 동일 | 흡수 |
| 호버가 포커스를 가져가는가 | `hovering %s did not take the focus` 동일 | 흡수 |
| 순서쌍 전수 × 2세이브상태 | 동일 | 흡수 |
| 선택 대비 ≥ 3.0:1 | `REQUIRED_CONTRAST` 동일 | 흡수 |
| 포인터를 판때기 밖에 둔 케이스 | `_measure(state,"<none>",…)` 동일 | 흡수 |
| 판때기 4개 | 7개 | **강화** |

> `_measure` / `_plate_luma` / `_contrast` 는 코드까지 동일하다. DEV 의 "부분집합" 주장 맞다.

#### `qa_f8_title_shots.gd` (200줄) — **손실 있음**

| 검사 항목 | 삭제 전 범위 | 통합 하네스 범위 | 판정 |
|---|---|---|---|
| 뷰포트 이탈 없음 | 4해상도 × 2상태 | `_measure_layout()` 4해상도 × 2상태 | 흡수 |
| 행 간격 == `separation` | 4해상도 × 2상태 | 동일 | 흡수 |
| 열 정렬 (x, width) | 4해상도 × 2상태 | 동일 | 흡수 |
| 세이브 유무로 판때기 높이 불변 | 4해상도 | `_check_plate_height_ignores_the_save()` 4해상도 | 흡수 |
| **선택된 판때기 1개 (버튼별 포커스)** | **4해상도 × 2상태**, `has_theme_stylebox_override("normal")` 구조 검사 | **1280x720 only**, 픽셀 휘도 | **후퇴** |
| **포커스 해제 = 선택 0개** | **4해상도 × 2상태** | **1280x720 `nosave` 1케이스** (`qa_p0_plates_all.gd:87`) | **후퇴** |
| 버튼 폭의 화면 대비 % 출력 | 있음 | 높이 %만 출력 | 출력만, 단언 아님 |
| 로고 하단 / 박스 상단 y 출력 | 있음 | 없음 | 출력만, 단언 아님 |

**후퇴 원인**: `tests/qa_p0_plates_all.gd:80` 이 sweep 직전 창을 1280x720 으로 되돌린다.
레이아웃은 4해상도를 돌지만, 선택 규칙 sweep 과 포커스 해제 케이스는 그 뒤에 1회만 돈다.

**FAIL 사유**: 태스크 지시 "삭제된 4개가 검사하던 항목이 통합 하네스에서 전부 커버되는지
확인하라. 누락이 있으면 커버리지 후퇴이므로 FAIL 이다."에 정확히 해당한다.

**부수 결함 #2**: `P0_CARRYOVER_REPORT.md` §3-2 는 "잃은 것: … 버튼별 포커스 PNG.
검증 커버리지 손실은 없고 스크린샷 장수만 줄었다"고 적었다. 위 표대로 사실이 아니다.
같은 문장이 `ORCHESTRATION_RULES.md` §7.1 "밝은 판때기 항상 1개 / 포커스 해제 시 0개 /
선택 대비 ≥ 3.0:1 / 4해상도 레이아웃" 으로 옮겨져, 4해상도가 레이아웃에만 걸린다는 것이
읽는 사람에게 드러나지 않는다.

**수정 제안(작음)**: `qa_p0_plates_all` 의 sweep 을 `SIZES` 로 감싸거나, 최소한
"선택 1개 + 포커스 해제 0개"만 `qa_f8_title_shots` 식 stylebox override 검사로
4해상도 × 2상태에서 다시 단언하면 된다(후자는 픽셀을 읽지 않아 수 초면 끝난다).

### 2-2. 판때기 목록이 씬 유래인지 — PASS

DEV 절차 13(선택)을 프로덕션 수정 없이 대체했다. `tests/qa2_hub_plates_derivation.tscn`(신규)이
런타임으로 허브를 바꾸고 답이 따라 바뀌는지 본다.

```
authored plates: NewGameButton, ContinueButton, UpgradeButton, CodexButton,
                 RecordsButton, SettingsButton, QuitButton
after adding one row: … , QuitButton, QaFuturePhaseButton
with 1 plate(s) removed: found only 6 hub plates under Safe/Content/Box (…), want at least 7
OK - the plate list follows the scene, and a short list fails loudly.
```

- 새 Button 을 `Safe/Content/Box` 에 넣으면 **즉시 목록에 들어온다** → 하드코딩 아님.
- 열 순서 유지, 숨김/`FOCUS_NONE` 행은 `all()` 에는 남고 `interactive()` 에서 빠진다.
- 판때기가 7개 미만이면 `HubPlates.problem()` 이 사유를 문자열로 돌려준다 → 가드 동작.
- **결함 #3 (LOW)**: 그 가드를 부르는 하네스는 5개 중 3개뿐이다.
  `qa_p0_plates_all.gd:63`, `qa_f8_focus_all.gd:44`, `qa_f8_labels.gd:21` 만 호출한다.
  `qa_f7_art.gd:99` 와 `qa_f7_title.gd:41` 은 `all()` / `interactive()` 결과를 그대로 쓴다.
  유래 로직이 깨지면 이 둘은 조용히 부분집합을 검사한다 — 이번 결함의 재발 경로 그대로다.
  DEV 인계문 §3-3 의 "목록이 7개 미만이면 하네스가 FAIL 한다"는 3/5 에만 해당한다.

### 2-3. 판때기 7개 × 포인터/키보드 × 4해상도 재측정 — PASS (제품)

`tests/qa2_plates_4res.tscn`(신규). 4해상도 × 2세이브상태 × 순서쌍 전수 = **296쌍**.

| 창 | 상태 | 판때기 | 최저 선택 대비 | 최악 조합 |
|---|---|---|---|---|
| 1280x720 | nosave | 6 | 3.85:1 | NewGame 호버 / Upgrade 키 |
| 1920x1080 | nosave | 6 | 3.85:1 | NewGame 호버 / Upgrade 키 |
| 720x1280 | nosave | 6 | 3.92:1 | NewGame 호버 / Upgrade 키 |
| 2560x1080 | nosave | 6 | 3.85:1 | NewGame 호버 / Upgrade 키 |
| 1280x720 | save | 7 | 3.85:1 | NewGame 호버 / Continue 키 |
| 1920x1080 | save | 7 | 3.85:1 | NewGame 호버 / Upgrade 키 |
| 720x1280 | save | 7 | 3.91:1 | NewGame 호버 / Quit 키 |
| 2560x1080 | save | 7 | 3.85:1 | NewGame 호버 / Upgrade 키 |

```
OK - one bright plate and >= 3.0:1 across 296 pointer/keyboard pairs at 4 sizes.
```

- 밝은 판때기 항상 정확히 1개, 항상 키보드가 있는 판때기. 위반 0건.
- **'포커스 없음 = 강조 0개'**: 8개 조합(4해상도 × 2상태) 전부 `bright=[]`.
  통합 하네스는 이 중 1개만 검사한다(위 대조표).
- 최저 3.85:1 ≥ 3.0:1.
- 증거: `tests/qa_artifacts/p0/plates4res/*.png`, 로그 296행.

> 하네스 작성 주석: 이 프로젝트는 캔버스를 늘리므로 1280x720 을 넘어가면 창 좌표와 뷰포트
> 좌표가 다르다. (a) `Input.warp_mouse` 와 밀어 넣는 `InputEventMouseMotion.position` 은
> 창 좌표, (b) `Control.get_global_rect()` 는 뷰포트 좌표, (c) 캡처한 프레임은 창 크기다.
> 셋을 맞추지 않으면 호버가 판때기를 빗나가고(1920/2560) 판때기 아닌 픽셀을 읽는다(720x1280).
> **DEV 하네스가 1280x720 에서만 sweep 하는 한 이 문제를 만나지 않는다** — 4해상도로 넓힐 때
> 반드시 처리해야 하는 지점이라 여기 남긴다.

---

## 3. MEDIUM — State 겹침 구조 검증 (PASS)

### 3-1. 기준선

```
godot --headless --path . res://tests/test_state_split.tscn
-- field overlap
    MetaState 10 state fields, RunState 16
OK - meta/run split holds.                                            exit 0
```

DEV 기대값(`MetaState 10 / RunState 16`)과 일치.

### 3-2. Negative control 9종 — **9/9 검출**

프로덕션 파일은 건드리지 않았다. 프로젝트를 스크래치로 복제하고
`config/name` 을 `JAMO_QA2_SANDBOX` 로 바꿔 `user://` 까지 분리한 사본에서 주입했다.
주입은 매 케이스 전 원본 복원 → 1건 주입 → 실행 순서다. 파일 삭제 명령은 쓰지 않았다.

| # | 주입한 결함 | 기대 | exit | 검출 | 첫 메시지 |
|---|---|---|---|---|---|
| NC0 | 없음 (기준선) | PASS | 0 | **OK** (0건) | — |
| NC1 | `MetaState` 에 등록된 런 필드 `current_wave` 추가 | FAIL | 1 | **OK** (2건) | `MetaState carries the undeclared field current_wave: add it to the ownership list…` |
| NC2 | `RunState.reset()` 무력화 | FAIL | 1 | **OK** (7건) | `the next run starts at Wave 1` |
| NC3 | **`MetaState` 에 미등록 `stage_index` / `core_shield` 추가** | FAIL | 1 | **OK** (2건) | `MetaState carries the undeclared field stage_index: …` |
| NC4 | `end_run()` 이 `MetaState.gold` 를 0으로 | FAIL | 1 | **OK** (1건) | `gold survives the defeat` |
| NC5 | 도감 등록만으로 효과 활성 (§38 위반) | FAIL | 1 | **OK** (1건) | `the same word equipped in a run does change click damage` |
| NC6 | 마이그레이션이 Day 42 → Wave 42 | FAIL | 1 | **OK** (1건) | `Day 42 must not be handed over as a Wave 42 record` |
| NC7 | `clear_run()` 이 `run` 블록 유지 | FAIL | 1 | **OK** (3건) | `a defeated run leaves nothing to resume` |
| NC8 | 마이그레이션이 `legacy_v03` 페이로드 폐기 | FAIL | 1 | **OK** (2건) | `the original v0.3 payload is kept rather than discarded` |

**핵심: NC3 가 이번에 잡힌다.** 1차 QA 에서 유일하게 새어 나간 케이스였고, 이름 denylist 를
소속 선언 구조 검증으로 바꾼 것이 실제로 효과가 있음을 확인했다.
기존 7종(NC1·NC2·NC4~NC8)도 전부 그대로 검출된다 — 회귀 없음.

DEV 인계문 §3-4 의 계약도 확인했다: `MetaState.NON_STATE_NAMES = ["database","balance",
"save_version"]`, `RunState.NON_STATE_NAMES = ["is_active"]` 를 제외한 실제 프로퍼티 집합이
상대편 `*_OWNED_NAMES` 와 **양방향으로** 같아야 한다. 미등록 추가는 `undeclared field`,
목록만 남고 필드가 없으면 `declared to own … but has no such property` 로 잡힌다.
`git diff tests/test_state_split.gd` 확인: 바뀐 것은 `_test_no_field_overlap` 과 새 헬퍼
2개뿐이고 NC2/NC5/NC6/NC7/NC8 을 보는 4개 함수는 한 글자도 바뀌지 않았다 (DEV 절차 18 일치).

> 주입 주석: NC7 을 처음 넣을 때 앵커 `\tpayload.erase("run")\n\treturn _write(payload)` 가
> `clear_run()` 이 아니라 `save_run()` 안쪽(들여쓰기 2단)에 먼저 걸려 스크립트가 파싱 실패했고,
> 그러면 `SaveManager` autoload 가 뜨지 않아 테스트가 `quit()` 에 도달하지 못해 **무한 대기**한다.
> 앵커를 `clear_run()` 으로 한정해 다시 돌린 결과가 위 표다. 하네스 쪽 함정이니 기록해 둔다.

**정리 상태**: 스크래치 사본의 세 파일을 프로덕션과 `diff` 로 대조해 동일함을 확인했다.
프로덕션 트리에는 주입 흔적이 없다(7절).

---

## 4. MEDIUM — 결과 화면 문구 (PASS)

### 4-1. 실제 RUN 실패로 확인

세이브를 지우고 `RUN 시작` → 실제 마우스로 몬스터를 클릭해 에너지를 0까지 소진시켰다
(`qa_p0_flow` 는 화면 좌표로 진짜 몬스터를 클릭한다). ziva-godot 실행에서도 같은 경로를
직접 조작해 `WAVE 1 / 문장핵 20 / 20 / ENERGY 2 / 20 · ⚠ 에너지 부족` 까지 눈으로 봤다.

결과 화면(`flow/03_run_result.png`):

```
RUN 종료
에너지가 바닥나 RUN 이 끝났다. 다음 RUN 은 WAVE 1 부터 시작한다.
도달 WAVE 1 / 처치 6 / 획득 GOLD 12 G (유지됨)
GOLD · 단어 도감 · 숙련도 · 보스 기록 · 최고 WAVE 는 그대로 남는다.
신규 단어 / 숙련 상승 / 합성어 / 보스 정산은 이후 Phase 에서 추가된다.
[메인 허브로]
```

- 현재 동작(`Main.end_run_when_energy_depleted`)과 문구가 일치한다.
- **HUD 와 모순 없음**: 같은 프레임 HUD 가 `문장핵 20 / 20`, `ENERGY 0 / 20`.
  문장핵은 멀쩡한데 에너지가 0 이고, 문구가 말하는 실패 원인도 에너지다.
- `문장핵이 무너졌다` 문구는 화면 어디에도 없다.
- 나머지 줄(도달 WAVE / 처치 / 획득 GOLD (유지됨))은 그대로다.

### 4-2. P1 되돌릴 지점 — 코드·문서 양쪽에 있다

- `scripts/ui/run_result.gd:9~16` 헤더 `PHASE 1 REVERT POINT` 주석. 되돌릴 문자열
  `"문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다."` 를 원문 그대로 적어 뒀다.
- `docs/DEV_ROADMAP.md` "P0 에서 P1 으로 넘긴 임시 처리" 절에 같은 내용 + 주석 위치.
- 조건도 명시돼 있다: `Main.end_run_when_energy_depleted` 를 끄고 문장핵이 실패 주체가 될 때.
- 문장핵 자체는 구현하지 않았다(P1 범위) — 확인했고 스펙과 일치한다.

---

## 5. 회귀 (PASS)

### 5-1. §35 전체 경로 — 실조작

`Main Hub → RUN 시작 → Wave 1 → 실패 → 결과 → Hub`. `qa_p0_flow` 실행(exit 0) +
ziva-godot 실제 조작 3회. 스크린샷 `tests/qa_artifacts/p0/flow/01~10`.

실조작 중 부수 확인: 진행 중인 RUN 이 있을 때 `RUN 시작` 을 누르면
`새 RUN 시작 — 진행 중인 RUN 이 사라지고 WAVE 1 부터 다시 시작합니다. GOLD 와 단어 도감은
그대로 남습니다.` 확인 대화상자가 뜬다. 덮어쓰기 보호가 살아 있다.
마이그레이션된 GOLD 1234 가 새 RUN 안에서 `1,270 G` 로 이어졌다 — 영구 재화 보존 확인.

### 5-2. F7~F9 확정 사항

| 확정 사항 | 결과 | 근거 |
|---|---|---|
| 선택된 판때기 1개 | PASS | 296쌍 × 4해상도 위반 0 (2-3절) |
| 포커스 사각 박스 없음 (허브) | PASS | `theme/jamo_theme.tres:330` `TitleButton/styles/focus = StyleBoxEmpty` |
| 타이틀 외 화면 포커스 테두리 존치 | PASS | `Button/styles/focus = SB_btn_focus`(StyleBoxFlat). `qa_f8_focus_all` 중앙값 9.7~10.1:1, `above_3.0` 85~89%. `qa_f7_title` 설정 패널 포커스 링 5개 도달 |
| 마우스 호버 우선 | PASS | sweep 이 매 쌍마다 `hovering X did not take the focus` 를 단언, 296쌍 위반 0 |
| 버튼 크기 화면 비율 기준 | PASS | `plate_height_ratio = 0.068` `@export`. 측정 6.8% (1280x720 / 1920x1080 / 2560x1080), 2.2% (720x1280 — 뷰포트가 1280x2275 로 길어져서) |
| 4해상도 레이아웃 | PASS | `qa_p0_plates_all` 8조합, 뷰포트 이탈·간격·정렬 위반 0 |
| 세이브 유무로 판때기 높이 불변 | PASS | 4해상도 전부 `nosave=49.0 save=49.0` |

### 5-3. MetaState / RunState 분리, 마이그레이션, §38

3장 negative control 로 전수 확인. 추가로 `qa_p0_flow` 가 실플레이 중
`run` 블록 소멸 / `meta` 잔존 / `RUN 이어하기` 미표시를 파일 단위로 확인한다(exit 0).

### 5-4. 테마 변경의 파급 — PASS

`git diff theme/jamo_theme.tres` 는 **추가 5줄뿐이고 기존 항목 변경 0**이다.

```
NoticeLabel/base_type = &"Label"
NoticeLabel/colors/font_color = Color(0.28, 0.075, 0.043, 1)
NoticeLabel/colors/font_outline_color = Color(0.949, 0.902, 0.808, 1)
NoticeLabel/constants/outline_size = 6
NoticeLabel/font_sizes/font_size = 13
```

`grep -rn "NoticeLabel" scenes/ scripts/` 결과 사용처는
`scenes/ui/title_screen.tscn:159` **한 곳뿐**이다. `Label/colors/*` 기본값은 그대로이므로
변형을 가리키지 않는 다른 화면 텍스트는 영향을 받지 않는다.
`qa_f8_labels` / `qa_f7_art` / `qa_f8_resize` 전부 통과해 실제 렌더에서도 확인했다.
씬은 인라인 색/크기 오버라이드를 지우고 `theme_type_variation` 만 가리킨다 —
GDScript 로 만든 StyleBox/Color 없음(v0.4 §46, ORCHESTRATION_RULES §3 준수).

---

## 6. 자동 테스트 / 정적 (PASS)

| 항목 | 결과 |
|---|---|
| `godot --headless --path . --quit` | exit 0. 에러는 `NotoSansKR-Regular.ttf` 누락 2줄뿐 (사전 존재 이슈) |
| `test_state_split.tscn` | exit 0 · `OK - meta/run split holds.` |
| `test_run_flow.tscn` | exit 0 · `OK - Wave 1 started, the run failed, and the hub came back.` |
| `qa2_hub_plates_derivation.tscn` (QA 신규) | exit 0 |
| `qa_p0_plates_all.tscn` | exit 0 · `OK - one bright plate across all 7 hub plates, 74 pointer/keyboard pairs.` FAIL 0 |
| `qa_p0_flow.tscn` | exit 0 · `OK - the Phase 0 path, the resume rules and the v0.3 migration all held.` |
| `qa_f7_title.tscn` | exit 0 · `keyboard reachable: NewGame, Upgrade, Codex, Records, Settings, Quit` (6개, Continue 제외 — 정상) |
| `qa_f7_art.tscn` | exit 0 · FAIL 0 |
| `qa_f8_labels.tscn` | exit 0 · FAIL 0 |
| `qa_f8_focus_all.tscn` | exit 0 · **버튼 7개 전부 출력**(Continue 는 `SKIPPED (no save)`), 이전 4개에서 개선 |
| `qa_f8_resize.tscn` | exit 0 · FAIL 0 |
| `qa2_notice_contrast.tscn` (QA 신규) | exit 0 · 9케이스 |
| `qa2_plates_4res.tscn` (QA 신규) | exit 0 · 296쌍 |

DEV 절차 4의 "삭제된 4개가 없다고 FAIL 로 세지 말 것" 준수 — 없음을 확인하고 세지 않았다.

**결함 #5 (INFO)**: 이 세션 이전부터 `godot.exe --headless --path .
res://tests/_deferred_v03/test_day_flow.tscn` 프로세스(PID 40896)가 매달려 있다.
보류 폴더의 v0.3 테스트라 P0 범위 밖이고 검증에 영향을 주지 않았다. 지시대로 kill 하지 않았다.

---

## 7. QA 가 추가/변경한 파일 · 임시 변경 원복

### 추가 (전부 `tests/` 아래, 프로덕션 무수정)

```
tests/qa2_notice_contrast.gd / .tscn        안내문 대비 독립 측정 (1장)
tests/qa2_hub_plates_derivation.gd / .tscn  판때기 목록 씬 유래 negative control (2-2절)
tests/qa2_plates_4res.gd / .tscn            4해상도 × 2상태 × 296쌍 재측정 (2-3절)
tests/qa_artifacts/p0/QA_REPORT_2.md        이 문서
tests/qa_artifacts/p0/notice/*.png          안내문 크롭 9종 + 첫 실행 잔여 1종
tests/qa_artifacts/p0/plates4res/*.png      4해상도 증거
```

`plates4res/` 에는 좌표 매핑을 고치기 전 실행이 남긴 실패 프레임 PNG 도 섞여 있다
(파일명에 `1920x1080_nosave_pointer_*` 형태로 다수). 최종 통과 실행이 남기는 것은
`*_nothing_focused.png` 8장과 `*_pointer_off_*.png` 8장, 그리고 재사용 버퍼 `_frame.png`
뿐이다. 나머지는 하네스 개발 중 잔여물이라 판정 근거가 아니다. 삭제 명령을 쓰지 않기로 해
그대로 두었으니, 커밋 범위를 정할 때 정리 여부를 판단해 달라.

`tests/qa_artifacts/p0/QA_REPORT.md` 는 **덮어쓰지 않았다.**

### 원복 상태

- **프로덕션 파일 수정 0.** `git status --short` 에 DEV 변경분 외 신규 `M`/`D` 없음.
  QA 추가분은 전부 `tests/` 아래 `??` 다.
- **negative control 주입 전부 원복.** 스크래치 사본
  (`…\scratchpad\nc1`, `config/name="JAMO_QA2_SANDBOX"`)에서만 주입했고,
  `autoload/meta_state.gd` / `run_state.gd` / `save_manager.gd` 를 프로덕션과 `diff` 해
  동일함을 확인했다. 프로덕션 경로에는 애초에 주입하지 않았다.
- **`qa2_notice_contrast` / `qa2_plates_4res` 의 런타임 변경은 프로세스 수명 한정**이다.
  `Scrim.color` 와 `GrowthPanel` 앵커는 인스턴스에만 쓰고 원값으로 되돌린 뒤 종료하며,
  `.tscn` 은 저장하지 않는다.
- **플레이어 세이브**: QA 시작 시 `jamo_save.json` 은 **없었다**(`.qabak` 만 존재).
  HIGH 재현을 위해 직접 써 넣은 v0.3 파일은 검증 후
  `jamo_save.json.qa2manualbak` 으로 옮겨 시작 상태(세이브 없음)로 되돌렸다.
  하네스들은 각자 `_stash_save()` / `_restore_save()` 로 스스로 되돌린다.
- 파일 삭제 계열 명령은 사용하지 않았다.

---

## 8. FAIL 재현 절차 (결함 #1)

1. `godot --path . res://tests/qa_p0_plates_all.tscn` 실행.
2. 로그에서 `--- nosave nothing focused: bright=[]` 를 찾는다. **1줄뿐이다.**
3. `1920x1080` / `720x1280` / `2560x1080` 에서 같은 줄을 찾는다. **없다.**
4. `| state | pointer on | keyboard on | …` 표의 74행이 전부 1280x720 에서 나온 것임을 확인한다
   (`tests/qa_p0_plates_all.gd:80` 이 sweep 직전 창을 1280x720 으로 고정).
5. 대조: `git show HEAD:tests/qa_f8_title_shots.gd` 의 `_capture_size()` 는
   `SIZES` 4종 × `nosave`/`save` 각각에서 버튼별 `_check_single_selection()` 과
   `nofocus_*` 케이스를 단언했다.

- **기대**: 삭제된 하네스가 단언하던 항목이 통합 하네스에서 전부 커버된다.
- **실제**: "선택된 판때기 1개"와 "포커스 해제 = 0개"가 1해상도(후자는 1상태)로 축소됐다.
- **영향 범위**: 하네스만. 제품 동작은 2-3절에서 4해상도 × 2상태 296쌍 전수 통과.
- **재검증 방법**: 수정 후 `godot --path . res://tests/qa2_plates_4res.tscn` 가 exit 0 이면 된다
  (QA 하네스를 그대로 흡수해도 되고, stylebox override 검사만 4해상도로 넓혀도 된다).
