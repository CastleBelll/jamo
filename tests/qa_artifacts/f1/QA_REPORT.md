# F1 Critical 시스템 QA 리포트

판정: **PASS**

환경: Godot 4.7.stable, Windows 11, Vulkan Forward+ (Intel UHD 770)
검증 시각: 2026-09-09
QA 에이전트는 프로덕션 코드를 수정하지 않았다. 추가 파일은 tests/ 아래 하네스뿐이다.

---

## 1. 정적 검사

`godot --headless --path . --quit` -> exit 0.
출력 에러는 `res://art/fonts/NotoSansKR-Regular.ttf` 누락 1건뿐이며 이는 사전 존재 이슈다.
F1 변경으로 새로 생긴 에러/경고는 0건.

로그: `01_static_check.log`, `04_static_check_final.log`

## 2. 자동 테스트

- `tests/test_game_loop.tscn` -> `OK - all game loop checks passed.` exit 0
- `tests/test_day_flow.tscn` -> `OK - day flow reached Day 2.` exit 0

로그: `02_test_game_loop.log`, `03_test_day_flow.log`

## 3. 수치 검증

`resources/upgrades/critical_click.tres`
- costs = 1500 / 4000 / 10000 / 25000 / 60000  (growth_balance v0.2 8.3 일치)
- values = 0.02 / 0.04 / 0.06 / 0.08 / 0.10    (2/4/6/8/10% 일치)
- 표시 포맷: `value_display_scale = 100.0`, `value_suffix = "%"` -> 상점 실측 "0% -> 2%"

`base_crit_multiplier = 2.0`
- `resources/balance/game_balance.tres:10` 에 존재
- 로직 참조는 `autoload/game_state.gd:105` 의 `balance.base_crit_multiplier` 단 한 곳
- 코드 내 하드코딩된 2.0 크리 배율 없음 (grep 확인)

클릭당 Critical 판정 1회
- `roll_critical()` 호출 지점은 `scripts/combat/click_controller.gd:34` 뿐이다.
- 그 결과 1개 bool 이 `get_click_damage(is_critical)` 와 `take_click_damage(.., is_critical)` 양쪽에 전달된다.
- 즉 피해 계산과 연출이 같은 롤을 공유하며, 2회 RNG 는 존재하지 않는다. (v0.3 10.2 요구 충족)

단어 보너스 합산 지점
- `_word_crit_chance` / `_word_crit_multiplier` (game_state.gd:40-41)
- `_recalculate_word_bonuses()` 에서 초기화 (271-272), `get_crit_chance()` / `get_crit_multiplier()` 에서 합산
- 현재 이 값을 채우는 WordEffectData 타입은 없다 (강타/괴력은 F3 범위). 합산 지점 확보 요구는 충족.

## 4. 해금 게이트 (AND 조건)

실제 런타임 상태를 만들어 상점 UI 로 확인. 하네스: `tests/qa_shop_gate.tscn`

| 상태 | 행 노출 | 값 | 사유/가격 | 버튼 |
|---|---|---|---|---|
| Day 24 + 클릭 피해 Lv.3 | **미노출** | - | - | - |
| Day 25 + 클릭 피해 Lv.2 | 노출 | `잠김` | `클릭 피해 Lv.3 필요` | `잠김` (disabled) |
| Day 25 + 클릭 피해 Lv.3 | 노출 | `0% -> 2%` | `1500 G` | `구매` (enabled) |

AND 조건 성립. 사유는 색이 아니라 텍스트로 표기된다.
증거: `shop_day24.png`, `shop_day25_locked.png`, `shop_day25_unlocked.png`, `gate_report.json`

## 5. 직접 플레이

하네스: `tests/qa_critical_play.tscn` — 실제 `main.tscn` 을 띄우고 `Input.parse_input_event` 로
실제 마우스 입력을 흘려 `ClickController` 의 raycast 경로를 그대로 태웠다.

Day 25 / 클릭 피해 Lv.3 / 치명 클릭 Lv.1 (2%) 상태에서 57 히트 중 1 크리 관측
(관측 크리율 1.75%, 기대 2%).

| 항목 | 일반 히트 | 크리티컬 |
|---|---|---|
| 피해 | 4.0 | 8.0 (정확히 x2) |
| Damage Number 텍스트 | "4" | "8" |
| Label3D pixel_size | 0.0028 | 0.00448 (**1.6배**) |
| 글자 색 | (0.22, 0.16, 0.10) | (0.86, 0.24, 0.16) |
| 외곽선 색 | (0.95, 0.90, 0.81) | (1.00, 0.94, 0.78) |
| 카메라 shake 최대 변위 | 0.0205 | 0.0435 (약 2.1배) |

크기와 색이 **둘 다** 다르고, shake 도 일반 히트보다 강하다.
확률이 낮았지만 실제 2% 로 관측에 성공했으므로 **`critical_click.tres` 를 임시로 수정한 적이 없다.
따라서 원복할 임시 변경도 없다.**

증거: `play_normal.png`, `play_critical.png`, `play_report.json`

## 6. 에디터 가시성 (v0.3 37절)

`PROPERTY_USAGE_EDITOR` 가 붙은 프로퍼티 목록을 런타임에서 덤프해 확인 (Inspector 표시 조건과 동일).

- `game_balance.tres`: start_max_energy, click_energy_cost, base_click_damage,
  **base_crit_multiplier**, base_monster_hp, hp_growth_per_day, base_monster_gold,
  gold_growth_per_day, base_monster_capacity, base_jamo_candidates, day_end_settle_seconds
- `critical_click.tres`: id, display_name, category, description, costs, values,
  value_display_scale, value_suffix, unlock_day, required_word,
  **required_upgrade**, **required_level**

필요한 값이 전부 노출된다. CameraRig / DamageNumber 의 신규 값도 `@export_group` +
`@export_range` 로 선언되어 있다 (Hit Shake / Critical Shake / Critical 그룹).

## 7. 접근성

크리티컬은 색 없이도 구분된다:
- 글자 크기 1.6배 (형태 단서)
- 숫자 자체가 2배 값 (8 vs 4)
`play_critical_greyscale.png` / `play_normal_greyscale.png` 로 흑백 확인 완료.
색은 보조 단서로만 쓰이며 단독 신호가 아니다.

INFO(비차단): 크리 외곽선 (1.0, 0.94, 0.78) 은 종이 아레나 배경과 명도가 가까워
외곽선 자체의 대비 기여는 낮다. 본문 색(진한 빨강)과 크기가 대비를 담당한다.

## 8. 회귀

- Day 1 -> Day 2 루프: `test_day_flow.tscn` 통과
- 일반 클릭 피해 / 골드 / 에너지: 실플레이 스크린샷에서 ENERGY 19/20, 104 G, 처치 29 정상 증가 확인
- 상점 기존 4행(최대 에너지 / 클릭 피해 / 골드 획득량 / 동시 몬스터 수) 정상 표시 및 구매 가능
- `UpgradeManager.is_visible()` 의미 변경(LOCKED_BY_WORD 도 노출)은 현재 `required_word` 를 쓰는
  업그레이드가 하나도 없으므로 실제 회귀 영향 0

## 9. 세이브 / 로드

실제 세이브 파일 `%APPDATA%/Godot/app_userdata/JAMO/jamo_save.json` 로 확인.
치명 클릭 Lv.2 구매 -> save -> 런타임 상태 초기화 -> load:

- 파일 내용: `"upgrade_levels": {"click_damage": 3.0, "critical_click": 2.0}`
- 복원 결과: `get_upgrade_level("critical_click") == 2`, `get_crit_chance() == 0.04`

증거: `gate_report.json` 의 `save` 블록

주의(사전 존재 사항, F1 무관): `tests/test_game_loop.gd:289` 가 마지막에
`SaveManager.delete_save()` 를 호출하므로 헤드리스 테스트를 돌리면 로컬 세이브가 삭제된다.
QA 실행 후 현재 로컬 세이브는 없는 상태이며, 다음 실행은 Day 1 신규 시작이다.

---

## 남은 관찰 (비차단)

1. `camera_rig.gd` 의 `shake()` 는 진행 중 shake 를 `maxf` 로만 갱신하므로, 강한 shake 직후의
   약한 히트는 감쇠 곡선을 재시작하지 못한다. 의도된 "약한 히트가 강한 연출을 끊지 않는다" 설계와
   일치하며 F1 요구사항 위반 아님.
2. 강타/괴력 단어가 아직 없어 `_word_crit_chance` 는 항상 0 이다. F3 에서 연결 예정.
