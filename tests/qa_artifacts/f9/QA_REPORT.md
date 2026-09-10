# QA 리포트 — F9 (F8 이월 4건 정리)

검수: 2026-09-10 · 대상: `tests/qa_artifacts/f9/DEV_HANDOFF_F9.md` 검수 절차 1~25
검증 수단: Godot 4.7-stable 실기동 (ziva-godot MCP `run_scene` 라이브 조작) + 창 모드 하네스 + 헤드리스
프로덕션 코드 수정: **없음** (임시 negative control, 전부 원복 — 9절)

---

## 판정: **PASS**

| 항목 | 결과 |
|---|---|
| 1. MEDIUM-3 — `BALANCE_NOTES` §42 주장 정정 | **PASS** (LOW 2건 신규 발견, 판정 무관) |
| 2. MEDIUM-4 — 밝은 판때기 1개 | **PASS** (실화면 9종 + 하네스 20조합 + negative control) |
| 3. `focus_ring.png` 이동 | **PASS** (미사용 에셋 2건 독립 확인 완료) |
| 4. v0.4 문서 개정 | **PASS** (diff 5덩어리, 임의 변경 0) |
| 5. 밸런스 무변경 | **PASS** (`.tres` 40개 · sim md5 동일) |
| 6. 전체 회귀 | **PASS** (LOW 1건 — F7 하네스 노후화, F9 무관) |
| 7. 자동 테스트 | **PASS** (지정 7종 전부 통과) |

**신규 결함 0건.** 아래 LOW 3건은 전부 문서/하네스 문제이고 코드·수치·화면에 영향이 없다.

---

## 1. MEDIUM-3 — `BALANCE_NOTES` §42 주장 정정 — **PASS**

### 1-1. 정정 확인 (절차 20)

인계문이 적은 "314행"은 그 뒤 문서가 4행 늘어 **현재 318행**이다. 내용으로 대조했다.

```
docs/BALANCE_NOTES.md:318
| `hp_growth_per_day` | 1.035 | v0.3 §8.1 확정값. 2.5 % 로 낮추면 Day 200 이
  2,820 → 408 HP 가 되어 growth_balance §3 의 후반 고HP 구간 설계가 사라진다 (3-1) |
```

- `§42` 인용 **삭제됨** — F8 QA 가 지시한 교체 문안과 글자 단위로 일치한다.
- 136~137행의 철회문(`"§8.1 과 §42 에서 두 번 못 박았다" 는 사실이 아니다`)과 **모순 없음**.
- 근거 포인터 `(3-1)` 이 가리키는 3-1 절이 이제 318행을 부정하지 않는다.

### 1-2. DEV 판단(§42-4 인용은 사실)을 v0.3 원문과 직접 대조 (절차 21)

`grep -n "§42" docs/BALANCE_NOTES.md` → 4건(136·137·267·319). HP 성장률을 §42 에 귀속시키는 문장 **0건**.

v0.3 §42 **원문 전문**을 읽어 대조했다.

```
# 42. v0.3에서 확정한 통합 수정 사항
1. 게임명: JAMO   2. 2.5D 고정 3/4 뷰   3. 자모 형태별 고유 보행
4. Day 1 일반 몬스터 기본 Gold: 2G      5. 힘: Base Click Damage 덮어쓰기 → Flat +1
6. Critical 시스템 통합   7. Energy Save 합산, 총 상한 20%
8. 자동화   9. 코드 전용 방식 금지   10. 에디터 가시성/수정 가능성 필수
```

10개 항목에 **HP 성장률 없음**, §42-4 는 정확히 `Day 1 기본 Gold 2G`.
→ **DEV 의 판단이 맞다.** 267행·319행은 §42-4 를 골드 2 G 에 대해 인용하므로 원문과 일치한다.

교차 확인한 나머지 구속 근거:

| 상수 | 노트의 귀속 | 원문 | 판정 |
|---|---|---|---|
| `start_max_energy` 20 | v0.3 §2 | §2.2 `기본 에너지: 20` | 일치 |
| `base_monster_hp` 3 | v0.3 §8.1 | §8.1 `Day 1 HP: 3` | 일치 |
| `base_monster_gold` 2 | v0.3 §8.1 · §42-4 | §8.1 `Base Gold: 2G`, §42-4 | 일치 |
| `click_energy_cost` 1 | v0.3 §2.2 | §2.2 `에너지 -1` | 일치 |
| `base_crit_multiplier` 2.0 | growth_balance §8.3 | §8.3 표 `배율 ×2` | 일치 |
| 에너지 상한 30 / 골드보너스 +50 % / 동시 20 | growth_balance §19 | §19 표 그대로 | 일치 |
| `focus_weight_steps` +20 % 상한 | growth_balance §10.4 | §10.4 `최대 +20%` | 일치 |
| Day 200 50,000 G+ 목표 | growth_balance §5 | §5 목표 수입 곡선 표 | 일치 |
| Day 4~10 누적 300~700 G | growth_balance §16 | §16 그대로 | 일치 |
| `day_end_settle_seconds` 0.8 | v0.3 §12 권장 0.5~1.0 | §12 `0.5~1초 정산` | 일치 |

### 1-3. 신규 발견 — 같은 종류의 귀속 오류 2건 (**LOW**, 판정 무관)

**LOW-1 · `docs/BALANCE_NOTES.md:61` — 문서를 잘못 가리킨다.**

```
`monster_gold_for_day()` 는 소수를 유지한다(v0.3 §4 권장).
```

- **기대**: 소수 유지 권장의 출처.
- **실제**: v0.3 §4 는 `자모 몬스터 — 이동이 아니라 '보행'` 이다. v0.3 전문에 `소수`/`반올림`
  문자열 **0건**. 해당 권장은 **`hangul_idle_growth_balance_v0.2.md` §4** 의
  `소수점 골드는 내부적으로 누적하고 UI에서는 정수 표시를 권장한다.` 다.
- **재현**: `grep -n "소수\|반올림" docs/JAMO_total_project_development_plan_v0.3.md` → 0건.
- **조치(한 줄)**: `(v0.3 §4 권장)` → `(growth_balance v0.2 §4 권장)`.
- **심각도**: LOW. 내용은 맞고 출처 표기만 틀렸다. MEDIUM-3 과 **같은 종류**(절 번호 오귀속)라 기록한다.

**LOW-2 · `docs/BALANCE_NOTES.md:266` — 네 값 중 하나가 인용 범위 밖.**

```
Day 1 은 HP 3 / 클릭 피해 1 / 에너지 20 / 기본 골드 2 G 로 네 값 모두 v0.3 §2·§8.1·§42-4 에 못 박혀 있다.
```

- HP 3(§8.1) · 에너지 20(§2.2) · 골드 2 G(§8.1·§42-4) 는 일치한다.
- **클릭 피해 1 은 §2·§8.1·§42-4 어디에도 없다.** v0.3 에서는 §10.1 의
  `기존 힘: 기본 클릭 피해 1 → 2` 와 §42-5 로만 간접 확인되고, 명시 표는
  growth_balance §2 `기본 클릭 피해 1` 이다.
- **심각도**: LOW. DEV 가 인계문에서 "세 절에 한 묶음으로 귀속시키는 축약 표기" 라고 스스로
  유보한 지점이며, 철회된 주장의 반복이 아니다. 별도 지시가 있을 때 정정하면 된다.

그 외 §/절 인용은 위 표대로 전부 원문과 일치했다.

---

## 2. MEDIUM-4 — 밝은 판때기 1개 — **PASS** (핵심)

DEV 가 **마우스 호버 우선**으로 잡았다고 보고한 대로 동작한다. 세 층으로 검증했다.

### 2-1. 실기동 육안 — 진짜 마우스 이동 + 진짜 화살표 키 (절차 9~18)

ziva-godot MCP `run_scene` 으로 `res://scenes/ui/title_screen.tscn` 을 라이브 실행하고,
`InputEventMouseMotion` 으로 포인터를 옮기고 `ui_up`/`ui_down` **입력 액션**을 눌러 조작했다.

| # | 조작 | 기대 | 실제 | 판정 |
|---|---|---|---|---|
| 9 | 세이브 없이 진입 | 판때기 3개, `새 게임` 만 밝음 | 3개, `새 게임` 만 밝음. 포커스 사각 박스 없음 | PASS |
| 10 | 포인터 화면 구석 + `↓` | `설정` 만 밝음 | `설정` 만 밝음 | PASS |
| 11 | 포인터를 `종료` 로 | 강조가 `종료` 로 **이동** | `종료` 만 밝고 앞 판때기 어두워짐. 총 1개 | PASS |
| 12 | 포인터 `종료` 유지 + `↑` | `설정` 만 밝음, `종료` 어두움 | `설정` 만 밝음. **포인터가 올라가 있는 `종료` 는 어둡다** | PASS |
| 13 | 그 상태에서 포인터만 화면 밖 | 변화 없음 | `설정` 만 밝음 (키보드 포커스 강조 유지) | PASS |
| 14 | 포인터를 `새 게임` 으로 | 강조 이동 | `새 게임` 만 밝음 | PASS |
| 15 | 포인터 `새 게임` 유지 + `↓`×2 | `종료` 만 밝음 | `종료` 만 밝음, `새 게임` 어두움 | PASS |
| 16 | 설정 패널 열고 뒤쪽 `종료` 호버 | 포커스 트랩 유지 | `닫기` 가 포커스 테두리 유지, 뒤쪽 `종료` 어두움 | PASS |
| 17 | 세이브 생성 후 재기동 | 판때기 4개 + `저장된 진행 — DAY 2 · 137 G` | 4개 + 라벨 1줄. 10~15 반복도 항상 1개 | PASS |
| 18 | 덮어쓰기 확인창 + 뒤쪽 판때기 호버 | 포커스가 끌려나가지 않음 | `취소` 가 포커스 테두리 유지, 뒤쪽 `종료` 어두움 | PASS |

11번이 **MEDIUM-4 재현 지점**이고, 이전 버전은 여기서 `설정`+`종료` 2개를 밝혔다. 지금은 1개다.

`_on_button_mouse_entered()` 의 `if _settings.visible or _overwrite_confirm.visible: return`
가드가 16·18 을 성립시킨다 — 패널/다이얼로그가 열려 있으면 호버가 포커스를 뺏지 않는다.

### 2-2. 독립 하네스 — 20조합 전수 + 대비 측정 (신규)

DEV 하네스 `qa_f9_hover_focus.gd` 의 `_press_arrow_to()` 는 실제로는 `grab_focus()` 를 부른다.
**포커스 체인 자체는 검증되지 않는다.** 그래서 QA 가 별도 하네스를 만들었다
(`tests/qa_f9_verify_real_input.gd` — tests/ 아래 신규, 프로덕션 무수정).

- 키보드를 **진짜 `InputEventKey`(KEY_UP/KEY_DOWN)** 로 한 칸씩 걷게 한다.
- 포인터 × 키보드가 **서로 다른 두 판때기를 가리키는 순서쌍 전부**(세이브 없음 6 + 있음 12)
  \+ 포인터 이탈 2 = **20조합**.
- 저장된 PNG 를 되읽어 판때기 중심 휘도를 재고, 선택 판때기 : 가장 어두운 판때기의
  **WCAG 대비비**를 계산한다.

`godot --path . res://tests/qa_f9_verify_real_input.tscn` → exit 0

```
OK - real arrow keys keep exactly one selected plate in 20 pointer/keyboard pairs.
```

#### 대비 측정표 (1280x720, 20조합 전수)

| state | pointer on | keyboard on | bright | selected luma | plain luma | contrast |
|---|---|---|---|---|---|---|
| nosave | NewGameButton | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| nosave | NewGameButton | QuitButton | 1 | 0.918 | 0.197 | 3.91:1 |
| nosave | SettingsButton | NewGameButton | 1 | 0.914 | 0.197 | 3.90:1 |
| nosave | SettingsButton | QuitButton | 1 | 0.918 | 0.197 | 3.91:1 |
| nosave | QuitButton | NewGameButton | 1 | 0.914 | 0.197 | 3.90:1 |
| nosave | QuitButton | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| nosave | (없음) | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | NewGameButton | ContinueButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | NewGameButton | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | NewGameButton | QuitButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | ContinueButton | NewGameButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | ContinueButton | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | ContinueButton | QuitButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | SettingsButton | NewGameButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | SettingsButton | ContinueButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | SettingsButton | QuitButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | QuitButton | NewGameButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | QuitButton | ContinueButton | 1 | 0.914 | 0.197 | 3.90:1 |
| save | QuitButton | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |
| save | (없음) | SettingsButton | 1 | 0.918 | 0.197 | 3.91:1 |

**`bright` 열이 20/20 전부 1**, 그리고 밝은 판때기는 **항상 키보드가 있는 판때기**다.
최저 대비 **3.90:1 ≥ 3.0:1** 충족. 프레임 20장은 `tests/qa_artifacts/f9/verify/` 에 남겼다.

> 이 표는 "판때기 vs 판때기" 대비다. F8 이 쓰는 "포커스 전후 변경 픽셀" 대비는 2-4절.

### 2-3. 마우스 ↔ 키보드 전환, 호버 없음 상태

- **마우스 → 키보드**: 12·15번. 포인터가 남아 있어도 그 자리는 어두워지고 강조는 키보드를 따라간다.
- **키보드 → 마우스**: 11·14번. 강조가 포인터 쪽으로 **이동**하고 원래 자리는 어두워진다. 추가되지 않는다.
- **호버 없음**: 13번 + 측정표의 `(없음)` 2행. 포인터를 판때기 밖으로 빼면
  **키보드 포커스가 계속 강조된다** (강조가 사라지거나 0개가 되지 않는다).
- **세이브 유/무 두 상태 모두** 위와 같다 (측정표 nosave 7행 / save 13행, 실화면 9~15 및 17).

### 2-4. 포커스 사각 박스 미부활 · 명도 대비 재측정

- `theme/jamo_theme.tres:197` `SB_title_focus` = **`StyleBoxEmpty`**, `TitleButton/styles/focus` 가 이를 가리킨다.
  테마 파일은 F9 에서 **한 글자도 바뀌지 않았다** (`git status --porcelain theme/` 공백).
- 프로젝트 전체 `focus_ring` 참조 **0건** (절차 25).
- `qa_f8_focus_all` 이 감시하는 `the focus ring is back` 문자열 **미출력**.
- 실화면 9~18 전부에서 타이틀 판때기 주위 갈색 사각 테두리 **없음**.
- **명도 대비 재측정** (`qa_f8_focus_all`, 창 모드):

| 상태 | 해상도 | median 대비 범위 | 3.0:1 미달 |
|---|---|---|---|
| 세이브 없음 | 1280x720 / 1920x1080 / 2560x1080 | **9.88 ~ 10.12 : 1** | 0 |
| 세이브 있음 | 1280x720 / 1920x1080 / 2560x1080 | **9.90 ~ 10.08 : 1** | 0 |

세이브 있음에서 `ContinueButton` 이 SKIPPED 되지 않고 4버튼 전부 측정됐다.
`REQUIRED_CONTRAST = 3.0` 무수정.

### 2-5. Negative control — 테스트가 동어반복이 아님을 직접 재현

`scripts/ui/title_screen.gd` 의 `_mute_hover()` 첫 줄에 `return` 을 넣어 무력화하고 3개 하네스를 돌렸다.

| 하네스 | 정상 | `_mute_hover` 무력화 |
|---|---|---|
| `qa_f9_hover_focus` (DEV) | exit 0, 6줄 전부 `bright_plates=1` | **exit 1**, 3·6번이 `bright_plates=2`, FAIL 2건 |
| `test_game_loop` (DEV) | exit 0, `OK - all game loop checks passed.` | **exit 1**, `FAILED - 18 check(s) failed.` |
| `qa_f9_verify_real_input` (QA 신규) | exit 0, 20/20 `bright=1` | **exit 1**, FAIL 17건, 혼합 조합이 `bright=2` |

무력화 시 실제 출력:

```
--- 3_keyboard_settings_pointer_left_on_quit focus=SettingsButton bright_plates=2
    ["SettingsButton(0.92)", "QuitButton(0.98)"]
FAIL: without a save: focus on NewGameButton with the pointer on SettingsButton
      should light NewGameButton alone, lit ["NewGameButton", "SettingsButton"]
```

**MEDIUM-4 원래 증상(밝은 판때기 2개)이 정확히 재현된다.** 테스트는 동어반복이 아니다.

> DEV 는 `test_game_loop` 가 **6건** FAIL 한다고 적었으나 실제로는 **18건**이다
> (세이브 없음 6 + 세이브 있음 12 = focus × hover 전 조합). DEV 가 과소 보고한 것이고
> 실제 검증 범위는 보고보다 **넓다**. 결함 아님.

원복 확인: `scripts/ui/title_screen.gd` md5 `f32c45422b9a2d0c4c06ddc319c60eab` — 패치 전과 동일.

---

## 3. `focus_ring.png` 이동 — **PASS**

### 3-1. 이동·참조·익스포트 (절차 24·25)

```
art/_reference/  →  .gdignore (0 B) · focus_ring.png (198 B) · title_ex.png
art/ui/          →  focus_ring* 없음 (btn_* 4종 + game_bg 만 남음)
```

- `git status`: `R  art/ui/focus_ring.png -> art/_reference/focus_ring.png` — **삭제가 아니라 rename**,
  내용 보존. `art/ui/focus_ring.png.import` 는 `D`.
- 엔진이 못 보는지 에디터에서 실제 확인:

```
res://art/ui/focus_ring.png          ResourceLoader.exists=false  file=false
res://art/_reference/focus_ring.png  ResourceLoader.exists=false  file=true
res://art/_reference/title_ex.png    ResourceLoader.exists=false  file=true   ← F8 선례와 동일
```

  → 파일은 남아 있고 **`ResourceLoader` 는 못 본다.** F8 의 `title_ex.png` 처리와 정확히 같은 방식.
- 참조 깨짐 없음: `grep -rn "focus_ring" --include=*.tscn --include=*.tres --include=*.gd .`
  (qa_artifacts 제외) → **0건**. 전체 하네스 27종에서 로드 에러 0.
- 익스포트: `.gdignore` 가 폴더 전체를 스캔 대상에서 빼므로 임포트되지 않고 따라서 팩에도 안 들어간다.
  (`export_presets.cfg` 는 `.gitignore` 대상이라 저장소에 없어 실제 익스포트로는 확인 불가.
  `.gdignore` 가 유일한 기전이고 `title_ex.png` 로 F8 에서 같은 방식이 이미 채택됐다.)
- 참고(무해): `.godot/imported/focus_ring.png-*.ctex` 잔재가 로컬 캐시에 남아 있다.
  `title_ex.png` 도 같은 잔재가 있고, `.godot/` 는 `.gitignore` 대상이라 저장소·익스포트와 무관하다.

### 3-2. `game_bg.png` / `btn_shop.png` 미사용 — **독립 확인 결과 DEV 판단이 맞다**

DEV 와 별개로 다시 세었다. 경로 문자열과 `.import` 의 `uid=` 값을 각각 전 저장소에서 grep 하고,
**사용 중인 형제 파일을 대조군으로 함께** 셌다.

| 파일 | 크기 | uid | 경로 참조 | uid 참조 | 판정 |
|---|---|---|---|---|---|
| `art/ui/game_bg.png` | 2.3 MB | `x2p0p7hi2ogn` | **0** | **0** | 미사용 |
| `art/ui/btn_shop.png` | 483 KB | `geblijk0xnnu` | **0** | **0** | 미사용 |
| `art/ui/btn_pause.png` | — | `dst3nu6iq2dla` | 1 | — | 사용 중 (대조군) |
| `art/ui/btn_settings.png` | — | `bqpceedfwa0km` | 1 | — | 사용 중 (대조군) |
| `art/ui/btn_dictionary.png` | — | `jao4vtc10ip7` | 1 | — | 사용 중 (대조군) |

대조군 3개가 1건씩 잡히므로 **grep 자체가 동작한다.** 그 조건에서 두 파일만 0건이다.
실기동으로도 확인: 게임 화면 배경은 3D 씬(6-3절)이고 상점 진입은 Day End 패널 버튼이라
두 텍스처가 그려지는 화면이 없다.

- **지시대로 옮기지 않았다.** `art/ui/` 그대로다.
- **QA 의견**: 합계 2.8 MB 가 익스포트 팩에 실린다. `art/_reference/` 로 옮기는 편이 맞다고 본다.
  다만 `game_bg.png` 는 타이틀 배경과 같은 계열의 완성 아트라 **나중에 게임 화면 배경으로 쓸 여지**가
  있어, 삭제가 아닌 이동(`title_ex.png`·`focus_ring.png` 와 동일 방식)을 권한다. 총지휘자 판단 사항.

---

## 4. v0.4 문서 개정 — **PASS**

### 4-1. §8.1 Gold 공식

```
docs/JAMO_total_project_development_plan_v0.4.md §8.1
BaseGold = 2 × 1.035^(Day - 1)
> v0.4 개정. v0.3 은 `2 × 1.025^(Day - 1)` 이었다. 근거는 §43.
```
→ 요구 그대로. HP 공식 `3 × 1.035^(Day-1)`, Day 1 HP 3, Base Gold 2 G 는 **불변**.

### 4-2. 신설 §43 과 근거

`# 43. v0.4에서 확정한 변경 사항` 신설. 43.1 변경 내역 표 / 43.2 근거 3항 / 43.3 §41 규칙과의 관계.
근거 3항이 전부 **`docs/BALANCE_NOTES.md` 를 명시 참조**한다 (`BALANCE_NOTES` 3-1 · 3-2).
`resources/balance/game_balance.tres` 의 `gold_growth_per_day = 1.035` 와 문서가 일치함을 적어 뒀다.
반례("골드 1.025 로 되돌려도 붕괴하지 않는다 — Day 200 3,921 G/일")까지 남겨 개정 사유를 과장하지 않았다.

### 4-3. §41 기준 문서 우선순위

```
1. JAMO_total_project_development_plan_v0.4.md
2. hangul_idle_growth_balance_v0.2.md
3. hangul_idle_word_tree_v0.1.md
```
1순위 v0.4 ✔ + v0.3 은 이력 전용이라는 안내 2줄.

### 4-4. v0.3 무수정 (git)

```
git status --porcelain docs/JAMO_total_project_development_plan_v0.3.md  →  (공백)
git log --oneline -1 -- ...v0.3.md  →  b6169ca (최초 커밋)
```
→ **작업 트리에서 한 글자도 바뀌지 않았다.**

### 4-5. v0.3 ↔ v0.4 diff — 임의 변경 0 (절차 22)

`diff -u` 결과 hunk **5개뿐**, 인계문 예고와 정확히 일치:

| # | 위치 | 내용 |
|---|---|---|
| a | 1행 | 제목 `v0.3` → `v0.4` |
| b | 상단 | 개정 안내 2줄 + 구분선 |
| c | §8.1 | Gold `1.025` → `1.035` + 주석 1줄 |
| d | §41 | 1순위 v0.4 + 안내 2줄 |
| e | §42 앞 / 문서 끝 | §42 안내 문단 + 신규 §43 + 문서 버전 표기 |

**본문 그 외 차이 0.** 수치·표·절 번호 변경 없음 → 임의 변경이 섞이지 않았다.

### 4-6. 기준 문서 표기 갱신 (절차 23)

| 파일 | 행 | 내용 | 판정 |
|---|---|---|---|
| `DEV_ROADMAP.md` | 6 | 우선순위 1순위 `..._v0.4.md` | PASS |
| `DEV_ROADMAP.md` | 7 | v0.3 이력 보존 + 변경 내역은 v0.4 §43 | PASS |
| `DEV_ROADMAP.md` | 147 | F8 이월 체크 `[x]` + §8.1·§43 링크 | PASS |
| `ORCHESTRATION_RULES.md` | 39 | `계획서 v0.4 §38 고정 문구` | PASS |
| `ORCHESTRATION_RULES.md` | 58 | `v0.4 > growth_balance v0.2 > word_tree v0.1` | PASS |
| `BALANCE_NOTES.md` | 8~10 | 1순위 v0.4 + §8.1 충돌 "§43 에서 닫혔다" | PASS |
| `BALANCE_NOTES.md` | 147~148 | 3-1 충돌 절에 `해소됨 (F9)` 한 줄 | PASS |

`docs/*.md` 의 남은 v0.3 언급을 훑은 결과 전부 **(a) 이력 보존 안내**이거나
**(b) "v0.3 §8.1 확정값" 처럼 v0.4 가 계승한 값의 출처**다. **누락된 갱신 없음.**

---

## 5. 밸런스 무변경 — **PASS**

- `git status --porcelain resources/` → **공백**. `.tres` diff 0.
- `resources/**/*.tres` 40개 md5 전량 대조. 밸런스 관련 발췌:

```
a680addd9bbbe90641b444b8a7ddbce0  resources/balance/game_balance.tres
d4989a4800b87b2238a7409751270371  resources/balance/game_database.tres
110cd1112157fd907e43d4675d95262b  resources/upgrades/click_damage.tres
764ad1833b3d6bd3861c93b7bb610b3d  resources/upgrades/critical_click.tres
03a036a770dc61da5fbe020014164c27  resources/upgrades/gold_bonus.tres
eb4f1eece1c05100a59e36d3bab1c4bd  resources/upgrades/max_energy.tres
595f96a36ff3afe2aeb8be939fc90daa  resources/upgrades/monster_capacity.tres
e41e2eea0d7c943001de0b166866b957  resources/upgrades/reroll.tres
```

- `sim_balance` 실행 **전후** `md5sum`:

```
before  2a494b8e7a1c63906e270feba82f4740  tests/qa_artifacts/f8/sim_report.md
after   2a494b8e7a1c63906e270feba82f4740  tests/qa_artifacts/f8/sim_report.md
before  ce72e75d073baec6e48a5f1bd27592ad  tests/qa_artifacts/f8/sim_metrics.json
after   ce72e75d073baec6e48a5f1bd27592ad  tests/qa_artifacts/f8/sim_metrics.json
```

**지정 해시 `2a494b8e7a1c63906e270feba82f4740` 유지.** `OK - simulated Day 1..200.`

---

## 6. 전체 회귀 — **PASS**

### 6-1. 하네스 (자체 종료형 27종 전부)

| 하네스 | exit | 결과 |
|---|---|---|
| `qa_critical_play` (F1 치명 클릭) | 0 | 통과 |
| `qa_reroll_play` (F2 리롤) | 0 | 통과 |
| `qa_f3_compat` / `qa_f3_play` / `qa_f3_pool` (F3 단어·화염·불꽃) | 0 | 통과 |
| `qa_f4_hud` / `qa_f4_special` (F4 특수 3종·황금 게이트) | 0 | 통과 |
| `qa_f5_arena` / `qa_f5_margin_ab` / `qa_f5_topdown` / `qa_f5_tree` (F5 트리·Target·키보드·아레나 이탈) | 0 | 통과. 아레나 이탈 0 |
| `qa_f6_juice` / `qa_f6_settings` (F6 연출·에너지 경고·볼륨) | 0 | 통과 |
| `qa_f7_title` (F7 타이틀 포커스) | 0 | `entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton, QuitButton` |
| `qa_f7_art` | 0 | **LOW-3 참조** (F9 무관, 사전 존재) |
| `qa_f8_focus` / `qa_f8_focus_all` (세이브 유·무) | 0 | 대비 9.88~10.12:1 |
| `qa_f8_labels` / `qa_f8_resize` / `qa_f8_variant` | 0 | 통과 |
| `qa_f8_title_shots` (판때기 크기 8조합) | 0 | 4해상도 × 2상태 전부 `button=294x67`, `plate height: nosave=67.0 save=67.0` |
| `qa_shop_gate` (F8 상점) | 0 | 통과 |
| `test_game_loop` / `test_day_flow` / `sim_balance` | 0 | 7절 |
| `qa_f9_hover_focus` / `qa_f9_verify_real_input` | 0 | 2절 |

**미실행 4종과 사유**

- `qa_f8_hover_focus` — DEV 인계문 지시대로 실행하지 않았다. F8 당시 상태를 기록한 하네스이고
  돌리면 `tests/qa_artifacts/f8/verify3/` 를 덮어써 F8 증거가 훼손된다.
- `qa_f7_live` / `qa_f8_choice` / `qa_f8_shop` — `get_tree().quit()` 이 **없는 관찰용 뷰어**로
  자체 종료하지 않는다. 합격/불합격 하네스가 아니므로 MCP 라이브 실행으로 화면만 확인했다(6-3절).
  창 모드로 띄운 `qa_f7_live` 는 무한 대기하므로 **그 게임 프로세스만** 종료했다.
  **Godot 에디터 프로세스(PID 26540)는 건드리지 않았다.**

### 6-2. 실기동 회귀

- **Day 1 → Day 2**: `test_day_flow` → `OK - day flow reached Day 2.` exit 0.
  MCP 라이브에서도 `새 게임` → 게임 화면 `DAY 1 / ENERGY 20 / 20 / 0 G / 처치 0` 정상 진입 확인.
- **구버전 세이브**: `qa_f3_compat` (compat probe) 통과. `qa_f5_tree` 의
  `target_save_round_trip.legacy_save_without_key` 가 빈 값으로 정상 복원됨을 확인.
- **60 FPS**: MCP 라이브 실행의 프레임/경과 실측 —
  타이틀 155f/2511ms = **61.7**, 221f/3614ms = **61.1**, 305f/5014ms = **60.8**,
  게임 화면(3D 아레나 + HUD + 일시정지) 401f/7016ms = **57.2**, 425f/7513ms = **56.6**.
  뒤 두 값은 씬 전환·에디터 임베드 오버헤드 포함. **60 FPS 대 유지.**

### 6-3. 타이틀 **외** 화면의 포커스 테두리 — 전부 존치

실기동 스크린샷으로 확인했다.

| 화면 | 확인 방법 | 포커스 테두리 |
|---|---|---|
| 설정 패널 | 타이틀에서 `설정` 클릭 | `닫기` 에 갈색 사각 테두리 **있음** |
| 덮어쓰기 확인창 | 세이브 있는 상태에서 `새 게임` | `취소` 에 갈색 사각 테두리 **있음** |
| 상점 | `qa_f8_shop` 라이브 (Day 60 / 5,000,000 G) | `다음 DAY 시작` 에 테두리 **있음**. `클릭 피해 Lv.25` 표시 정상 |
| 일시정지 | 실제 플레이 → `ESC` → `↓` | `설정` 에 테두리 **있음** |
| 자모 선택 | `qa_f8_choice` 라이브 → `→` | `ㅂ` 카드에 슬롯 테두리 **있음** |
| 단어 트리 / HUD 아이콘 | 실제 플레이 → HUD 사전 아이콘 클릭 | 아이콘에 포커스 테두리 **있음**. `qa_f5_tree` 통과 |

정적으로도 확인: `theme/jamo_theme.tres` 무수정이고
`Button/styles/focus = SB_btn_focus`(StyleBoxFlat) / `HudIconButton → SB_icon_focus` /
`TreeSlot → SB_slot_focus` 그대로다. `StyleBoxEmpty` 로 비운 것은
`TitleButton/styles/focus` **하나뿐**이다.

### 6-4. 신규 LOW 1건

**LOW-3 · `tests/qa_f7_art.gd` 가 숨은 노드를 겹침으로 센다 — F9 무관, 사전 존재.**

```
FAIL: NewGameButton overlaps ContinueInfoLabel at nosave_1280x720
FAIL: ContinueButton overlaps ContinueInfoLabel at nosave_1280x720
FAIL: ContinueInfoLabel overlaps SettingsButton at nosave_1280x720
```

- **원인**: `tests/qa_f7_art.gd:119-122` 의 겹침 루프가 `visible` 을 보지 않는다. 세이브 없음 상태에서
  `ContinueButton` / `ContinueInfoLabel` 은 숨겨져 있지만 **마지막 rect 를 그대로 들고 있어**
  보이는 판때기들과 겹친 것으로 계산된다. F8 이 만든 `qa_f8_title_shots.gd` 는
  같은 문제를 `if not child.visible: continue` 로 이미 막아 뒀다.
- **F9 무관 증명**: `git show HEAD:scripts/ui/title_screen.gd` 로 **F9 이전 코드**를 되돌려
  같은 하네스를 돌렸더니 **동일한 FAIL 이 동일한 수로** 나온다.
- **영향 없음**: stderr 출력일 뿐 `_failures` 를 올리지 않아 exit 0 이고 화면은 정상이다
  (2-1절 9번 + `qa_f8_title_shots` 의 "구멍 없음"·간격 검사 통과).
- **심각도**: LOW. `qa_f8_hover_focus` 와 같은 **하네스 노후화**다. 고치려면 tests/ 한 줄
  (`if not node.visible: continue`) 이지만 F7 당시 기록물이라 이번 사이클에서는 손대지 않았다.

---

## 7. 자동 테스트 — **PASS** (지정 7종 + α)

| # | 명령 | 기대 | 실제 |
|---|---|---|---|
| 1 | `godot --headless --path . --quit` | 폰트 2줄 외 에러 0, exit 0 | **일치.** `NotoSansKR-Regular.ttf` 2줄만, exit 0 |
| 2 | `test_game_loop.tscn` | `OK - all game loop checks passed.` | **일치**, exit 0 |
| 3 | `test_day_flow.tscn` | `OK - day flow reached Day 2.` | **일치**, exit 0 |
| 4 | `sim_balance.tscn` + md5 | 전후 `2a494b8e...`, `OK - simulated Day 1..200.` | **일치** (5절) |
| 5 | `qa_f7_title.tscn` 창 모드 | entry / reachable / OK 3줄 | **일치**, exit 0 |
| 6 | `qa_f8_focus_all.tscn` 창 모드 | `OK - focus indicator meets 3.0:1 ...`, median 9.9~10.2:1, `the focus ring is back` 미출력 | **일치.** 세이브 유·무 양쪽 실행 |
| 7 | `qa_f8_title_shots.tscn` 창 모드 | `OK - one selected plate at a time across 4 sizes.`, `plate height:` 4줄 `nosave=67.0 save=67.0` | **일치**, exit 0 |
| 8 | `qa_f9_hover_focus.tscn` 창 모드 | 6줄 `bright_plates=1`, `OK - one selected plate in every pointer/keyboard mix.` | **일치**, exit 0. 스크린샷 6장 재생성 |
| + | `qa_f9_verify_real_input.tscn` (QA 신규) | — | `OK - ... 20 pointer/keyboard pairs.` exit 0 |

**폰트 누락 2줄 외 에러 0.** 하네스 27종에서 로드 에러·파싱 에러 0.

> 참고(무해): 에디터 디버거가 `autoload/signal_bus.gd` 의
> `"... is declared but never explicitly used"` 경고 12건을 띄운다.
> F6 LOW 로 이미 이월된 항목(`word_revealed` 미사용 시그널)의 확장이고
> 헤드리스 실행에서는 에러로 잡히지 않는다. 이번 변경과 무관.

---

## 8. 증거

| 경로 | 내용 |
|---|---|
| `tests/qa_artifacts/f9/hover_1..6_*.png` | DEV 하네스 재실행본 (세이브 없음). 6장 전부 `bright_plates=1` |
| `tests/qa_artifacts/f9/verify/*.png` (20장) | QA 신규 하네스. 포인터×키보드 20조합 전수 프레임 |
| `tests/qa_f9_verify_real_input.gd` / `.tscn` | QA 신규 하네스 (tests/ 아래, 프로덕션 무수정) |
| 본 문서 2-2절 | 대비 측정표 20행 |
| 본 문서 2-4절 | `qa_f8_focus_all` 명도 대비 재측정 (세이브 유·무) |

DEV 원본 6장과 재실행본 대조: **4장 바이트 동일**, 2장 상이.
상이한 2장은 `hover_2` / `hover_5` 로 **포인터가 포커스 판때기 위에 얹힌 프레임**이다.
테마 hover 의 `modulate 1.12` 가 캡처 시점에 반영됐는지에 따라 **같은 한 장의 판때기**가
휘도 0.92 ↔ 0.98 로 갈린다. 두 경우 모두 `bright_plates=1` 이고 육안 차이는 없다. 결함 아님.

---

## 9. 임시 변경과 원복

프로덕션 파일 수정은 **negative control / 사전존재 증명 목적의 임시 변경뿐**이고 전부 원복했다.

| 대상 | 변경 | 원복 확인 |
|---|---|---|
| `scripts/ui/title_screen.gd` `_mute_hover()` | 첫 줄 `return` 삽입 (1회차: DEV 하네스 + `test_game_loop`) | 백업본 복사 → md5 `f32c45422b9a2d0c4c06ddc319c60eab` |
| `scripts/ui/title_screen.gd` `_mute_hover()` | 첫 줄 `return` 삽입 (2회차: QA 신규 하네스) | 동일 md5 |
| `scripts/ui/title_screen.gd` | `git show HEAD:` 판으로 교체 (LOW-3 사전존재 증명) | 동일 md5 |

**최종 상태: 프로덕션 코드·테마·씬·`resources/**` 전부 DEV 인계 시점 그대로.**
`git status` 의 `M scripts/ui/title_screen.gd` 는 DEV 의 F9 변경(+50/-9)이고 QA 가 더한 것은 없다.

QA 가 저장소에 더한 것:

- `tests/qa_f9_verify_real_input.gd` / `.tscn` (신규 하네스)
- `tests/qa_artifacts/f9/verify/*.png` (20장) · `tests/qa_artifacts/f9/QA_REPORT.md` (본 문서)
- 하네스 재실행으로 갱신된 기존 QA 산출물 JSON/PNG (`f1`~`f6`, `f8/variants/`, `f9/hover_*.png`)
- `tests/qa_f9_hover_focus.gd.uid` — 에디터가 프로젝트를 열면서 자동 생성했다 (DEV 인계문 예고대로)

세이브 파일: 검수 중 만든 `user://jamo_save.json` 은 **삭제했다**. 세션 시작 시점과 동일하게
`jamo_save.json` 없음 / `jamo_save.json.qabak` 만 존재한다.

---

## 10. 이번 사이클 범위 밖 — 그대로 이월

DEV 인계문 3절의 이월 목록을 확인했고 새로 닫힌 것은 없다.

- HIGH-1 화상(DoT) 사멸 — `sim_balance` 실측 여전히 `화상 (DoT) 17568 (0.4%)`
- MEDIUM-2 상점 가격 열 천단위 구분자 — 6-3절 상점 화면에서 `1650000 G` 로 미적용 확인
- F6 LOW 3건 (`word_revealed` 미사용 시그널 / 단어 완성 시 집결 자모 시인성 / burn ember·gold sparkle 가독성 하한)
- `art/audio/sfx/` 빈 폴더
- 30분 이상 실플레이 세션 미실시

신규 이월 후보 (전부 LOW, 판정 무관):

- **LOW-1** `BALANCE_NOTES:61` 출처 표기 `v0.3 §4` → `growth_balance v0.2 §4` (1-3절)
- **LOW-2** `BALANCE_NOTES:266` `클릭 피해 1` 의 절 귀속 (1-3절)
- **LOW-3** `tests/qa_f7_art.gd` 숨은 노드 겹침 오탐 (6-4절)
- `art/ui/game_bg.png` 2.3 MB · `art/ui/btn_shop.png` 483 KB 미사용 확정 — 이동 여부는 총지휘자 판단 (3-2절)
