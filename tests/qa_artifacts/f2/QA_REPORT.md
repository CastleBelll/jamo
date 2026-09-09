# F2 Reroll 시스템 QA 리포트

- 판정: **PASS**
- 일자: 2026-09-09
- 대상: `6cb72a0` + F2 DEV 작업 트리 (uncommitted)
- Godot: v4.7.stable.official (Vulkan / Forward+, Intel UHD 770)

## 0. 검증 수단에 관한 고지 (중요)

`mcp__ziva-godot__start_godot` 로 실제 Godot Editor 를 띄워 프로젝트를 열고
로드 에러 0 확인 + `jamo_choice.tscn` 씬 트리/에디터 화면 캡처까지 마쳤으나,
그 직후 **ziva MCP 브리지가 끊겼다** (`Unable to connect`, `start_godot` 도구도
목록에서 사라짐, Godot 프로세스는 계속 살아 있음). 3회 재시도 + 대기 후에도
복구되지 않았다.

총지휘자에게 `ask` 로 escalate 했고 **옵션 (A) 채택** 답변을 받았다:
이후 검증은 **headless 가 아니라 windowed CLI 실행**
(`godot --path . tests/qa_reroll_play.tscn`, Vulkan/Forward+ 렌더링)으로 수행했다.
따라서 이 리포트의 스크린샷은 전부 **실제 렌더링된 게임 화면**이며,
버튼 조작도 `InputEventMouseButton` 실제 클릭으로 수행했다.
총지휘자 지시에 따라 Godot 프로세스는 죽이지 않았다.

## 1. 정적 / 로드 에러

| 수단 | 결과 |
|---|---|
| ziva MCP `get_godot_errors` (에디터) | `Session has no errors` |
| ziva MCP 에디터 화면 (에러 카운터) | 오류 0 / 경고 0 |
| `godot --headless --path . --quit` | 폰트 누락 2건만 |

남은 에러는 기존 알려진 이슈뿐이다:

```
ERROR: Resource file not found: res://art/fonts/NotoSansKR-Regular.ttf
ERROR: Error loading custom project font 'res://art/fonts/NotoSansKR-Regular.ttf'
```

FAIL 사유 아님. → **PASS**

## 2. 에디터 가시성 (v0.3 §19, §37)

### 2.1 `scenes/ui/jamo_choice.tscn` 씬 트리 — ziva MCP `get_scene_tree` 실측

```
Box (VBoxContainer)
├── TitleLabel (Label)
├── EmptyLabel (Label, visible=false)
├── CardRow (HBoxContainer) → Card0..Card3
├── RerollRow (HBoxContainer, visible=false)   ← 에디터 노드로 존재
│   ├── RerollButton (Button)
│   └── RerollCountLabel (Label)
└── SkipButton (Button, visible=false)
```

`.tscn` 에 실제 `[node name="RerollRow" type="HBoxContainer" ...]` 로 저장돼 있고,
`jamo_choice.gd` 에는 `Button.new()` / `Label.new()` 가 전혀 없다.
**코드 생성이 아니다.** → **PASS**

### 2.2 `resources/upgrades/reroll.tres` Inspector 노출

`get_property_list()` 에서 `PROPERTY_USAGE_EDITOR` 가 켜진 프로퍼티 실측:

```
id, display_name, category, description, costs, values,
value_display_scale, value_suffix, unlock_day, level_unlock_days,
required_word, required_upgrade, required_level
```

값 실측:

| 항목 | 기대 (v0.3 §13.1) | 실제 |
|---|---|---|
| `costs` | 1000 / 7500 / 50000 | `[1000, 7500, 50000]` |
| `values` | 1 / 2 / 3 회 | `[1.0, 2.0, 3.0]` |
| `level_unlock_days` | Day 5 / 25 / 60 | `[5, 25, 60]` |
| `unlock_day` | 5 | `5` |

→ **PASS**

## 3. 실제 플레이 (windowed 렌더링, 실제 클릭)

| 항목 | 기대 | 실제 | 증거 |
|---|---|---|---|
| Day 5 미만 상점 미노출 | 행 없음 | `row_visible=false` | `01_shop_day4.png` |
| Day 5 미만 리롤 버튼 숨김 | 행 숨김 | `row_visible=false` | `02_choice_day4.png` |
| Day 5 상점 노출 | 1,000 G 구매 | `"1000 G" / "구매"`, `0 회 → 1 회` | `03_shop_day5_available.png` |
| Lv1 구매 후 표기 | `리롤 1/1` | `리롤 1/1`, 골드 100000 → 99000 | `05_choice_day5_lv1.png` |
| 리롤 클릭 시 후보 변경 | 후보 바뀜 | 실제 마우스 클릭으로 `[ㄷ,ㅗ] → [ㄹ,ㅂ]` | `06_`, `07_` |
| 겹침 최소화 | 가급적 0 | 20회 시행 **전부 overlap 0** | `reroll_report.json` |
| 잔여 0 → disabled + 텍스트 사유 | 텍스트로 사유 | disabled + `리롤 0/1 · 오늘 리롤을 모두 썼습니다` | `08_choice_exhausted.png` |
| 자모 확정 후 리롤 불가 | 불가 | 패널 hide, 이후 입력으로 후보/잔여 변화 없음 | `09_after_pick_hidden.png` |
| 다음 Day 재충전 | 1/1 복귀 | `advance_day()` 후 `rerolls_left=1`, `리롤 1/1` | `10_choice_next_day_refilled.png` |
| Day 25 이전 Lv2 잠금 + 사유 Day 텍스트 | 텍스트 표기 | Day 10: `Day 25 필요` / `잠김` (현재 `1 회` 유지) | `11_shop_lv2_day_locked.png` |
| Day 25 도달 시 해금 | 구매 가능 | `7500 G` / `구매`, `1 회 → 2 회` | `12_shop_lv2_day25.png` |

색만으로 상태를 구분하는 곳은 없다. 잠금·소진 사유가 전부 문자열로 나온다. → **PASS**

> 참고: 스크린샷 HUD 의 `DAY n` 숫자는 하네스가 `GameState.day` 를 직접 세팅하고
> `HUD.refresh()` 를 부르지 않아 갱신되지 않은 것이다. 하네스 아티팩트이며
> 패널 판정에 쓰인 실제 day 값은 JSON 리포트에 기록돼 있다.

## 4. 후보 품질 (v0.3 §13.4)

- 후보 풀(제작 가능 단어가 아직 필요로 하는 자모): `ㅂ ㅜ ㄹ ㅎ ㅣ ㅁ ㄷ ㅗ ㄴ ㅏ` (10종)
- 리롤 50회 × 2장 = 100장 중 **풀 밖 자모 0장**. 완전 무작위가 아니다.
- 리롤 전/후 겹침: 70회 시행 전부 **overlap 0**.
- 작은 풀 크래시 없음:
  - 풀 0 (모든 단어 자모 충족): `generate → []`, `regenerate → []`, 크래시 없음.
  - 풀 1: `generate → [ㅂ]`, `regenerate → [ㅂ]`. 제외 후 뽑을 게 없으면 직전
    후보를 되돌려 넣는 설계대로 동작(코드 주석에 명시).
- UI 빈 상태: 후보 0일 때 `지금 제작할 수 있는 단어가 없습니다` + `건너뛰기` 노출,
  리롤 버튼 disabled + `리롤 1/1 · 다시 뽑을 후보가 없습니다`
  (`14_choice_empty_pool.png`). disabled 버튼 실제 클릭 시 잔여 소모 없음(1 → 1).

→ **PASS**

## 5. 저장 / 복원

| 케이스 | 기대 | 실제 |
|---|---|---|
| 리롤 1회 사용 후 저장 → 재로드 | 잔여 유지 | 세이브 파일 `"rerolls_left": 0` → 복원 `0` (레벨 1, Day 6 유지) |
| 구버전 세이브(키 없음) | 최대치 충전 | `rerolls_left = 1` (= max), 크래시 없음 |
| 비정상 값(99) | 최대치로 clamp | `1` |

세이브 경로: `<user data>/JAMO/jamo_save.json`.
하네스가 시작 시 원본을 백업하고 종료 시 되돌린다. → **PASS**

## 6. 접근성

- `RerollButton.focus_mode = 2` (FOCUS_ALL) — `.tscn` 에 저장된 값.
- `grab_focus()` 후 `gui_get_focus_owner()` 가 버튼과 일치 → 키보드 도달 가능
  (`13_choice_button_focused.png`).
- 리롤 소진으로 버튼이 disabled 되면 포커스를 카드로 넘겨 키보드 조작이 막히지 않는다
  (`focus_moved_off_button = true`).
- 상태 전달이 색 단독이 아니라 텍스트 병행.

→ **PASS**

## 7. 회귀

| 항목 | 결과 |
|---|---|
| Day 1 → Day 2 루프 | `tests/test_day_flow.tscn` → `OK - day flow reached Day 2.` |
| F1 치명 클릭 게이트 | `tests/qa_shop_gate.tscn` windowed 재실행 통과. Day 24 미노출 / Day 25 + 클릭 피해 Lv.2 → `클릭 피해 Lv.3 필요` / Lv.3 → `1500 G 구매` |
| 기존 업그레이드 4종 | 최대 에너지 `50 G`, 클릭 피해 `100 G`, 골드 획득량 `100 G`, 동시 몬스터 수 `200 G` — 이전과 동일 (`12_shop_lv2_day25.png`) |

**DEV 인계 사항 회귀 확인:** `UpgradeData.level_unlock_days` 는 `reroll.tres` 에만
채워져 있고(`PackedInt32Array(5,25,60)`), 기존 4종 + `critical_click.tres` 에는
해당 라인이 없어 빈 배열이다. `unlock_day_for_level()` 이 `unlock_day` 로 폴백하므로
`Availability.LOCKED_BY_NEXT_DAY` 는 기존 트랙에서 발생할 수 없다.
화면 실측으로도 5종 표기·가격·게이트가 그대로다. → **PASS**

## 8. 보조 증거 (헤드리스)

```
godot --headless --path . tests/test_game_loop.tscn  → OK - all game loop checks passed.  (exit 0)
godot --headless --path . tests/test_day_flow.tscn   → OK - day flow reached Day 2.       (exit 0)
```

## 관찰 사항 (FAIL 아님)

1. **INFO** — `jamo_choice.gd::_on_reroll_pressed()` 는 `visible` 과 `consume_reroll()`
   만 확인하고 버튼 disabled 여부/후보 유무는 보지 않는다. 후보가 없는 상태에서
   `pressed` 시그널을 강제로 emit 하면 리롤 1회가 빈 재추첨에 소모된다(1 → 0).
   **실제 마우스 클릭으로는 재현되지 않는다** (Godot 의 disabled Button 은 `pressed`
   를 발생시키지 않음, 실측 1 → 1). 플레이어가 도달할 수 없는 경로라 PASS 를 막지 않는다.
2. **INFO** — 풀이 1개뿐일 때 리롤 결과가 직전과 동일해질 수 있다(`regenerate` 의
   되돌려 넣기 규칙). 코드 주석에 의도로 명시돼 있다.
3. **INFO** — untracked `addons/ziva_agent/` 는 `start_godot` 가 설치한 것이며
   `project.godot` 는 변경되지 않았다. 커밋 대상에서 제외 필요.
   `tests/qa_shop_gate.gd.uid` 도 Godot 생성 부산물이다.

## 임시 변경 / 원복

- 프로덕션 코드 수정 **없음**. 추가 파일은 `tests/` 하위뿐:
  `tests/qa_reroll_play.gd`, `tests/qa_reroll_play.tscn` (+ Godot 생성 `.uid`).
- 세이브 파일은 하네스가 백업 → 복원한다.
- `tests/qa_artifacts/f1/gate_report.json` 은 F1 회귀 재실행으로 갱신됐다.
  변경분은 `level_unlock_days` 1줄 추가뿐이며, F2 신규 export 가 Inspector 에
  노출된다는 사실을 반영한 정상 결과다.
- Godot 프로세스는 종료하지 않았다.

## 아티팩트

```
tests/qa_artifacts/f2/
├── 01_shop_day4.png              Day 4 상점 — 리롤 행 없음
├── 02_choice_day4.png            Day 4 자모 선택 — 리롤 행 없음
├── 03_shop_day5_available.png    Day 5 상점 — 1,000 G 구매 가능
├── 04_shop_day5_after_buy.png    구매 직후 Lv.1
├── 05_choice_day5_lv1.png        자모 선택 — "리롤 1/1"
├── 06_choice_before_reroll.png   리롤 전 후보
├── 07_choice_after_reroll.png    실제 클릭 후 후보 변경
├── 08_choice_exhausted.png       잔여 0 — disabled + 텍스트 사유
├── 09_after_pick_hidden.png      자모 확정 후 패널 종료
├── 10_choice_next_day_refilled.png  다음 Day 재충전
├── 11_shop_lv2_day_locked.png    Day 10 — "Day 25 필요"
├── 12_shop_lv2_day25.png         Day 25 — 7,500 G 구매 가능
├── 13_choice_button_focused.png  키보드 포커스
├── 14_choice_empty_pool.png      후보 0 — 빈 상태 + 리롤 사유
└── reroll_report.json            전 항목 수치 실측 로그
```
