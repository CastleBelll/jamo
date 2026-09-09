# F3 FAIL 수정 재검증 — QA 리포트 2

- 대상: `QA_REPORT.md` 의 F-1 (HIGH, FAIL 사유) / F-2 (MEDIUM), 및 F3·F1·F2 전체 회귀
- 기준 문서: `DEV_HANDOFF_F1_F2.md` 2절 검수 절차 → `docs/ORCHESTRATION_RULES.md` 4절 공통 항목
- 검증 수단: **ziva-godot MCP 로 실행 중인 Godot Editor 에서 `run_scene` 으로 main.tscn 을
  실제 렌더링 실행하고 실제 마우스 좌표/버튼 클릭으로 조작**. 헤드리스는 정적·자동 테스트와
  장시간 관측 하네스에만 사용.
- **판정: PASS**

---

## 1) 항목별 결과

| # | 항목 | 결과 |
|---|---|---|
| 1 | F-1 해소 (제작 목록 5개 전부) | **PASS** |
| 2 | F-2 해소 (빈 상태 문구) | **PASS** |
| 3 | 잘림 표시 `외 N개 더` | **PASS** |
| 4 | UI 가 코드 생성이 아님 (v0.3 19.1) | **PASS** |
| 5 | HUD 침범 / 몬스터 클릭 (v0.3 23.1) | **PASS** |
| 6 | F3 기능 회귀 | **PASS** |
| 7 | F1/F2 회귀 | **PASS** |
| 8 | 자동 테스트 | **PASS** |
| 9 | F-3 미수정 확인 | **여전히 존재 (F5 로 이월, FAIL 사유 아님)** |

---

## 2) F-1 해소 — 제작 가능 5개 전부 표시

- **재현 절차**: `user://jamo_save.json` 없는 상태(세션 시작 시점에 이미 없었다) → main.tscn 실행.
- **기대**: 좌하단 `제작 가능한 단어` 에 불/힘/돈/밥/운 5줄.
- **실제**: 5줄 전부 표시. 화면 실측 텍스트

  ```
  제작 가능한 단어
  불  ㅂ 0/1  ㅜ 0/1  ㄹ 0/1
  힘  ㅎ 0/1  ㅣ 0/1  ㅁ 0/1
  돈  ㄷ 0/1  ㅗ 0/1  ㄴ 0/1
  밥  ㅂ 0/2  ㅏ 0/1
  운  ㅇ 0/1  ㅜ 0/1  ㄴ 0/1
  ```

- **도감 대조(같은 화면)**: 도감 버튼을 실제로 클릭해 연 뒤 `[제작 가능]` 목록이
  불 / 힘 / 돈 / 밥 / 운 5개로 **HUD 5줄과 완전히 일치**. 두 UI 가 같은 말을 한다.
  한 장의 스크린샷 `play_dex_fresh.png` 에 둘 다 찍혀 있다.
- 하네스 실측(`qa_f4_hud_observations.json`): `rows_in_scene = 10`, `words_in_database = 10`,
  `day1_craftable = [불, 힘, 돈, 밥, 운]`, `day1_visible_rows` 5줄, 빈/잘림 라벨 둘 다 hidden.
- 증거: `play_dex_fresh.png`, `play_hud_day1_rows.png`, `play_day1_fresh.png`

## 3) F-2 해소 — 빈 상태 문구

- **재현 절차**: DEV 인계문 9번 세이브(10개 단어 전부 해금)를 심고 main.tscn 실행.
- **기대**: 빈 상자가 아니라 `완성할 단어가 없습니다` 한 줄.
- **실제**: 제목 아래에 **`완성할 단어가 없습니다`** 표시. 단어 행 0줄. `ENERGY 25 / 25`(체력 반영).
- 하네스 실측: `all_done_empty_label_visible = true`,
  `all_done_empty_label_text = "완성할 단어가 없습니다"`, `all_done_visible_rows` 는 그 한 줄뿐.
- **DEV 보류사항 2 확인**: 패널 최소 높이 116px 때문에 문구 아래 여백이 남는다. 화면에서
  실제로 보이며, DEV 가 범위 밖으로 판단한 그대로다. 기능 결함 아님 → F5 레이아웃 정리 대상.
- 증거: `play_hud_all_done_empty.png`, `play_dex_all.png`

## 4) 잘림 표시 `외 N개 더`

- 현재 database(10단어, 동시 제작 가능 최대 6)로는 플레이만으로 도달할 수 없다.
- **프로덕션 코드/데이터를 건드리지 않고** `tests/qa_f4_hud.gd` 하네스에서 HUD 인스턴스의
  `_word_rows` 를 런타임에 2개로 줄여 재현했다. `.tscn`·`.gd`·`.tres` 는 무수정이다.
- **실제**: 2줄 + `외 3개 더` 표시. 실측 `overflow_label_text = "외 3개 더"`,
  `overflow_visible_rows = [불…, 힘…, "외 3개 더"]`.
- **원복**: 같은 하네스 안에서 `_word_rows` 를 원래 10개로 되돌린 뒤 재확인 —
  `after_restore_visible_rows` 5줄, `after_restore_overflow_visible = false`.
- 증거: `play_hud_overflow.png`

## 5) UI 가 코드 생성이 아님 (v0.3 19.1)

- 에디터에서 `scenes/ui/hud.tscn` 을 열어 확인. `WordProgressPanel/WordBox` 자식 13개:

  ```
  TitleLabel
  WordRow0 … WordRow9        (Label 10개)
  WordOverflowLabel  (visible = false)
  WordEmptyLabel     (visible = false)
  ```

- 전부 `.tscn` 노드다. GDScript 생성 노드 없음. **구성 경고 0건.**
- `hud.gd` 는 `@onready` 로 참조만 하고 `show/hide/text` 만 건드린다 (코드 리딩으로도 확인).

## 6) HUD 침범 / 몬스터 클릭 (v0.3 23.1)

- 1280x720, 5줄 상태에서 패널 rect ≈ x 18~298 / y 533~703. 상단바는 y 14~76 → **겹침 없음**.
- 경기장(플레이트) 좌측 꼭짓점이 x≈310 이라 패널 우측 끝(298)과도 겹치지 않는다.
  행이 10줄까지 늘어도 패널은 위로만 자라고 x 범위가 그대로여서 경기장을 가리지 않는다.
- **실제 클릭 검증**: 새 세이브 Day 1 에서 경기장 좌표로 마우스 클릭 26회 →
  `ENERGY 20/20 → 1/20`, `처치 4`. 클릭이 HUD 에 막히지 않는다.
  (`click_controller.gd` 는 몬스터를 실제로 맞혔을 때만 에너지를 쓰므로, 에너지 감소가
  곧 몬스터 히트 증거다.)
- 하네스 실측: 오버레이 8종(`Dim/DayEnd/JamoChoice/WordComplete/UpgradeShop/WordDex/
  PauseMenu/Settings`) 전부 `visible = false`, 클릭 전후 에너지 20 → 19.

## 7) F3 기능 회귀

| 항목 | 결과 | 실측 |
|---|---|---|
| 선행 잠금 | PASS | Day 1 도감 `[선행 잠금]` 화염·불꽃·강타·금·체력 5개, `[제작 가능]` 5개 |
| 화염 틱 2 | PASS | 불만 해금 `[1.0, 1.0]` → 화염 해금 `[2.0]`, 재실행에도 `[2.0]` (원본 오염 없음) |
| 불꽃 전이 1홉 | PASS | 불꽃 미해금 클릭 1회 → 처치 1 / 해금 → 처치 2 |
| 전이 반경 게이트 | PASS | 반경 1.07m, 이웃 1.57m → `burning = false` |
| 강타 CritChance | PASS | 200,000 롤 실측 0.0989 (선언 0.100) |
| 금 | PASS | 도감 `[완성] 금`, 황금 스폰 없음 (해금 플래그만) |
| 체력 | PASS | 10개 완성 상태 `ENERGY 25 / 25`, `get_max_energy() = 25` |
| 운 | PASS | 도감 `[완성] 운`, `get_special_spawn_multiplier() = 1.05`, 즉시 변화 없음 |
| 도감 10행 | PASS | 도감 12줄 = 제목 + `완성한 단어 0 / 10` + 단어 10줄 |

## 8) F1/F2 회귀

| 항목 | 결과 | 실측 |
|---|---|---|
| 치명 클릭 — 클릭당 판정 1회 | PASS | 강타만 0.0989 / 강타+치명Lv.5 **0.2002** / 치명Lv.5만 0.1001. 독립 2회 판정이면 0.19 가 나와야 하므로 **단일 합산 판정** 확정 |
| 치명 클릭 게이트 | PASS | `unlock_day = 25`, `required_upgrade = click_damage`, `required_level = 3` (자동 테스트 `_test_critical_click`) |
| 리롤 충전 | PASS | 실제 플레이로 자모 선택 화면 도달 → `리롤 2/2` 표시 |
| 리롤 소모 | PASS | `리롤` 버튼 실제 클릭 → `리롤 1/2`, 후보가 ㅏ/ㅣ → ㄴ/ㅜ 로 재추첨 |
| 리롤 저장 | PASS | Day 2 진입 후 세이브 실측 `"rerolls_left": 2` (새 Day 시작 시 max 로 재충전됨), `"upgrade_levels": {"reroll": 2}` |
| Day 1 → Day 2 루프 | PASS | 클릭으로 에너지 0 → `자모 선택으로` → 자모 카드 선택 → `확인` → 상점 → `다음 DAY 시작` → **`DAY 2` / `ENERGY 20 / 20` / `처치 0`**. 획득한 ㄴ 이 HUD 제작 목록(돈 ㄴ 1/1, 운 ㄴ 1/1)과 세이브 `jamo_inventory` 양쪽에 반영됨 |
| 옛 세이브 호환 | PASS | F3 키 없는 세이브 → day 12 / gold 400 / burn 활성 정상 로드. 존재하지 않는 word id 섞인 세이브 → 크래시 없이 조용히 제외 |

## 9) 자동 테스트 (DEV 절차 A)

| 절차 | 결과 |
|---|---|
| A.1 `godot --headless --path . --quit` | PASS — `NotoSansKR-Regular.ttf` 누락 2줄 외 에러/경고 0 |
| A.2 `test_game_loop.tscn` | PASS — `OK - all game loop checks passed.` |
| A.3 `test_day_flow.tscn` | PASS — `OK - day flow reached Day 2.` |
| A.4 회귀 테스트 음성 검증 | PASS — 아래 참조 |

**A.4 상세(임시 변경 + 원복).** `scripts/ui/hud.gd` 의 `_word_rows` 를 임시로 `%WordRow0~3`
4개로 되돌리고 A.2 를 재실행했다. 결과:

```
  FAIL: the HUD should show 5 rows on Day 1 (got 10)
  FAIL: nothing is truncated while rows outnumber words
  FAIL: no rows should remain visible
FAILED - 3 check(s) failed.
```

DEV 가 예고한 3건이 그대로 실패한다 → 재발 방지 가드가 실제로 동작한다.
**확인 즉시 `scripts/ui/hud.gd` 를 원복했고, `git diff` 가 DEV 원본과 동일함을 확인한 뒤
A.2 를 다시 돌려 `OK - all game loop checks passed.` 를 받았다.**

(참고, LOW) `rows.size() >= words.size()` 가드는 씬 노드를 세므로 `_word_rows` 배열만 줄어든
경우는 잡지 못한다. 그 경우는 나머지 두 가드(표시 행 수 / 잘림)가 잡는다. 실제로 3건이
모두 실패했으므로 방어는 충분하다.

## 10) F-3 상태 (미수정 확인 — FAIL 사유 아님)

10개 전부 완성 상태에서 도감을 열면 패널이 y≈45 부터 시작해 `DAY 12` / `ENERGY 25 / 25` /
`500 G` / `처치 0` 상단바와 **여전히 겹친다**. 스크롤 컨테이너도 없다.
DEV 인계문 3절 1번대로 `word_dex.tscn` / `word_dex.gd` 는 이번 수정에서 한 줄도 바뀌지 않았고,
F5 단어 트리 UI 사이클로 이월된 상태 그대로다. 지시에 따라 상태만 기록한다.

---

## 11) 증거 파일 (`tests/qa_artifacts/f3/`)

| 파일 | 내용 |
|---|---|
| `play_dex_fresh.png` | **F-1 해소 핵심 증거** — 한 화면에 HUD 5줄 + 도감 `[제작 가능]` 5개 일치 |
| `play_hud_day1_rows.png` | Day 1 제작 목록 5줄 (하네스 렌더) |
| `play_hud_all_done_empty.png` | **F-2 해소 증거** — `완성할 단어가 없습니다` |
| `play_hud_overflow.png` | **잘림 표시 증거** — 2줄 + `외 3개 더` |
| `play_dex_all.png` | 도감 10/10, `ENERGY 25 / 25` (+ F-3 겹침 상태) |
| `play_day1_fresh.png` | 새 세이브 Day 1, 오버레이 없음 |
| `play_burn_*.png` / `play_spread_*.png` | 화상 틱 1→2, 전이 처치 1 vs 2 |
| `qa_f4_hud_observations.json` | 행 수 / 제작 목록 텍스트 / 빈·잘림 라벨 상태 / 원복 후 상태 |
| `qa_f3_observations.json` | 오버레이 / 클릭 전후 에너지 / 화상 틱 / 전이 처치 / 도감 행 / 최대 에너지 |

## 12) QA 가 추가한 파일 (tests/ 한정)

- `tests/qa_f4_hud.gd` / `.tscn` — HUD 제작 목록 관측 하네스 (신규, 이번 사이클)
- `tests/qa_f3_play.gd` / `.tscn`, `tests/qa_f3_pool.gd` / `.tscn`,
  `tests/qa_f3_compat.gd` / `.tscn` — 직전 사이클 하네스, 이번에 재실행만 했다

## 13) 임시 변경 원복

1. **세이브 파일**: 세션 시작 시점에 `user://jamo_save.json` 이 **없었다**. 검증을 위해
   (a) 10개 전부 완성 세이브, (b) `reroll` Lv.2 세이브를 심었다.
   **검증 종료 후 삭제했고, 파일이 존재하지 않는 원래 상태로 복구했다.**
2. **`scripts/ui/hud.gd`**: A.4 음성 검증을 위해 `_word_rows` 를 4개로 임시 축소했다가
   **즉시 원복했다.** `git diff` 가 DEV 원본과 동일(14 insertions / 1 deletion)하고
   `test_game_loop` 가 다시 통과함을 확인했다.
3. **그 외 프로덕션 코드/데이터**(`scripts/`, `scenes/`, `resources/`, `autoload/`):
   한 줄도 수정하지 않았다. `git status` 가 세션 시작 시점과 동일하며, 추가된 것은
   `tests/qa_f4_hud.*` 와 `tests/qa_artifacts/f3/` 산출물뿐이다.
