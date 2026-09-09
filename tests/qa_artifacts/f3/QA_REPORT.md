# F3 단어 확장 tier-2 — QA 리포트

- 대상: DEV_ROADMAP F3 / S1~S8, 브랜치 `main`
- 검증 수단: **ziva-godot MCP 로 Godot Editor 를 띄우고 `run_scene` 으로 실제 게임을 실행/조작**
  (실렌더링 화면 + 실제 마우스 좌표 클릭). 헤드리스는 정적/자동 테스트 보조로만 사용.
- 예외 1건: 장시간 캡처 하네스 `tests/qa_f3_play.tscn` 은 MCP `run_scene` 의 30초 상한을
  넘겨 **windowed CLI (`godot --path . tests/qa_f3_play.tscn`)** 로 실행했다. 헤드리스가 아니라
  실제 렌더링 창이며, 기존 F1/F2 QA 하네스와 동일한 실행 방식이다.
- 판정: **FAIL** (F3 기능 자체는 전부 정상. 아래 F-1 (HIGH) 때문에 FAIL)

---

## 1) DEV 인계문 검수 절차 — 번호별 결과

| # | 절차 | 결과 | 관측 내용 |
|---|---|---|---|
| 1 | `godot --headless --path . --quit` | PASS | 폰트 누락 2줄 외 에러/경고 0 |
| 2 | `test_game_loop.tscn` | PASS | `OK - all game loop checks passed.` |
| 3 | `test_day_flow.tscn` | PASS | `OK - day flow reached Day 2.` |
| 4 | `bulkkot.tres` Inspector 필드 | PASS | `Id/Word/Category/Required Jamo/Prerequisites/Effects/Tier/Description` 전부 노출. `Word=불꽃`, `Prerequisites=[fire_001]` 1개 |
| 5 | `Effects[0]` 의 Spread 그룹 | PASS | `Effect Type = Burn Spread(5)`, `[group] Spread` 아래 `Radius=1.07`(range 0~10), `Chain Count=1`(0~8), `Max Chain Depth=1`(1~8) 전부 편집 가능 |
| 6 | `game_database.tres` Words 10개 순서 | PASS | 불 / 화염 / 불꽃 / 힘 / 강타 / 돈 / 금 / 밥 / 체력 / 운 — 정확히 10개, 순서 일치 |
| 7 | `word_dex.tscn` 에 DexRow0~9 | PASS | Scene 트리에 Label 10개 확인, 구성 경고 0. 코드 생성이 아니라 `.tscn` 노드 |
| 8 | Day 1 도감 10줄 / 0 / 10 | PASS | `완성한 단어 0 / 10`, `[제작 가능]` 불·힘·돈·밥·운 5줄, `[선행 잠금]` 화염·불꽃·강타·금·체력 5줄 (`play_dex_fresh.png`) |
| 9 | 도감 닫기 → 에너지 소진 → Day 종료 → 자모 카드 | PASS | 실제 클릭으로 에너지 20 소진, DayEnd → JamoChoice 카드 2장 정상 |
| 10 | 자모 후보에 ㅕ/ㅊ/ㅌ/ㅡ 미등장 | PASS | 후보 풀 실측: `[ㄴ ㄷ ㄹ ㅁ ㅂ ㅇ ㅎ ㅏ ㅗ ㅜ ㅣ]` — DEV 가 적은 11자와 정확히 일치 |
| 11 | `불` 완성 → 화염/불꽃 해금, ㅕ·ㅊ 등장 | PASS | 불 해금 시 HUD 제작 목록에 화염/불꽃 등장, 후보 풀에 ㅕ·ㅊ 추가 (ㅌ·ㅡ 는 여전히 없음) |
| 12 | 화상 틱 `1` × 3 | PASS | 화면에 틱 숫자 `1` 관측. 하네스 실측 `[1.0, 1.0]` — Day 1 몬스터 HP 3 이라 클릭 1 + 틱 2 로 **2틱째에 사망**한다. 3틱을 다 못 보는 것은 사망 때문이며 지속시간 3초 자체는 정상 |
| 13 | `화염` 완성 패널 / 도감 | PASS | `단어 완성 화염`, 자모 분해 `ㅎ+ㅗ+ㅏ+ㅇ+ㅕ+ㅁ`, 설명 정상. 도감 `[완성] 화염` |
| 14 | 틱이 `1` → `2`, 지속 3초 유지 | PASS | 화면 틱 숫자 `2` 관측, 하네스 실측 `[2.0]`. 동일 클릭 패턴에서 처치 2 → 4 로 증가 |
| 15 | 재시작 후에도 틱 `2` (원본 오염 없음) | PASS | 재실행 실측 `[2.0]`. 추가로 `_recalculate` 8회 + 세이브 왕복 3회 후에도 `2.0` 고정, 원본 `.tres` `base_value` 는 `1.0` 유지, 반환 인스턴스는 원본과 별개 |
| 16 | `불꽃` 완성 | PASS | 해금 후 `get_burn_spread_effect()` 노출 |
| 17 | 화상 사망 시 옆 몬스터로 전이 | PASS | 20마리 필드에서 **클릭 1회 → 처치 2**. 불꽃 미해금 대조군은 **클릭 1회 → 처치 1** |
| 18 | 전이받은 화상은 재전이 안 됨 | PASS | 14초 관찰에도 3번째 사망 없음. 클릭 5회 → 처치 정확히 10 (클릭당 2, 초과 없음) |
| 19 | 멀리 있으면 전이 안 됨 | PASS | 반경 1.07m, 이웃을 1.57m 에 두고 화상 사망 → `burning = false` |
| 20 | 20마리에서 프레임 저하 없음 | PASS | 20마리 + 반복 화상 사망 20초 구간 1195프레임 = **59.7 FPS**, 14초 구간 59.9 FPS |
| 21 | `힘` → `강타` 완성 | PASS | 도감/효과 정상 |
| 22 | Critical 약 10%, 클릭당 판정 1회 | PASS | 200,000 롤 실측 **0.0991~0.1012**. `click_controller.gd` 가 `roll_critical()` 을 클릭당 1회만 호출해 그 결과를 피해·표기에 함께 전달 |
| 23 | 치명 클릭 Lv.5 시 약 20%, 판정은 여전히 1회 | PASS | 실측 **0.1994~0.2008**. 독립 2회 판정이면 0.19 가 나와야 하므로 **단일 합산 판정 확정**. 게이트도 `unlock_day=25`, `required_upgrade=click_damage`, `required_level=3` 로 스펙대로 |
| 24 | `돈` → `금`, 황금은 아직 안 나옴 | PASS | 도감 설명 "황금 몬스터 출현을 해금한다. 실제 스폰은 특수 몬스터 기능에서 이 해금 상태를 읽어간다." / 스폰 없음 |
| 25 | 껐다 켠 뒤에도 `[완성] 금` 유지 | PASS | 실제 플레이로 단어 완성 후 세이브에 `"unlocked_words": ["fire_001","fire_002"]` 기록 확인, 재실행 시 유지 |
| 26 | `밥` 완성 시 최대 에너지 22 | PASS | 실측 22 |
| 27 | `체력` 완성 시 25, 25회 클릭 가능 | PASS | 실제 실행 HUD `ENERGY 25 / 25` (`play_dex_all.png`) |
| 28 | `운` 완성, 즉시 변화 없음 | PASS | 도감 `[완성] 운`, `get_special_spawn_multiplier() = 1.05`, 소비처 없음 |
| 29 | Day 루프 한 바퀴 (F1/F2 회귀) | PASS | 클릭 → 에너지 0 → DayEnd → 자모 선택 → **리롤** → 상점 → Day 7 진행. 리롤 잔여 표기/충전 정상 |
| 30 | 10개 전부 완성 후 자모 선택 화면 | PASS | 후보 `[]` 반환, 멈춤/크래시 없음. `건너뛰기` 버튼이 후보가 빌 때만 표시되도록 되어 있어 진행 가능 |

## 2) DEV 주의/보류 사항 검증 (7~10번 하위 호환 위험)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 7 | `EffectType` 끝에만 추가 | PASS | 실측 enum: `FLAT_CLICK_DAMAGE=0 … UNLOCK_BURN=3` 불변, 신규 `4~8`. 기존 `bul/him/don/bap.tres` 미변경 |
| 8 | 옛 세이브 로드 / 신규 세이브를 옛 빌드에서 | PASS | F3 키가 전혀 없는 옛 세이브 → 정상 로드(day 12, gold 400, burn 활성). 존재하지 않는 word id 가 섞인 세이브 → 크래시 없이 해당 효과만 조용히 제외 |
| 9 | `apply_status_effect()` 인자 1개 증가 | PASS | 기본값 `chain_depth = 0`. 기존 호출부 `click_controller.gd` 무수정 동작 확인(실제 클릭 정상) |
| 10 | `get_burn_effect()` 사본 반환 (원본 오염 방지) | PASS | 위 15번 참조. 누적 없음, 원본 불변 |
| 11 | 폰트 누락은 기존 이슈 | 확인 | F3 이전부터 존재. 이번 사이클과 무관 |
| 12 | 도감 4행 → 10행 확장 | 부분 PASS | 도감은 고쳐졌으나 **HUD 진행 패널은 4행 그대로** → F-1 |
| 13 | 기존 테스트 2개 자모 하드코딩 제거 | PASS | 전체 테스트 통과 |

## 3) 추가 확인 A~E

### A. 사용자 보고 이슈 (마우스 클릭 안 됨 / 오버레이 보임) — **재현되지 않음**
- 새 세이브 Day 1 시작 화면: `Dim / DayEnd / JamoChoice / WordComplete / UpgradeShop / WordDex /
  PauseMenu / Settings` **전부 `visible = false`** (하네스 실측, `qa_f3_observations.json`).
- 같은 화면에서 몬스터 클릭 → 에너지 20 → 19 로 실제 감소.
- Day 종료 → `자모 선택으로` → 자모 카드 → (리롤) → `확인` → `다음 DAY 시작` 까지 각 버튼이
  실제 클릭으로 동작하고, 마지막에 오버레이가 전부 닫히며 몬스터 클릭이 다시 됨 (Day 2 에서
  8회 클릭에 에너지 20 → 15).
- 기존 세이브 로드 시에도 오버레이 잔존 없음.
- 참고: `건너뛰기` 버튼은 후보가 비어 있을 때만 보이도록 설계돼 있다(`jamo_choice.gd`).
  후보가 있는데 이 버튼 자리를 누르면 반응이 없는 것이 정상이며, 사용자가 "막혔다"고 느낀
  지점이 여기일 가능성은 있으나 결함은 아니다.

### B. 성능 (v0.3 §36) — PASS
- 불꽃 탐색은 `SpawnManager._on_monster_died()` 에서만 돌고, 캐시된 `_alive` 배열을 쓴다.
  매 프레임 전체 탐색 없음(코드 + 실측 모두 확인).
- 몬스터 20마리 + 반복 화상 사망: 20초 1195프레임(59.7 FPS), 14초 839프레임(59.9 FPS). 저하 없음.

### C. 무한 연쇄 안전장치 — PASS
- 클릭 5회 → 처치 정확히 10. 클릭당 최대 2마리(원본 + 전이 1)로 고정.
- 전이 화상은 `burn_chain_depth = 1`, `next_depth 2 > max_chain_depth 1` 에서 차단.
- 필드 전멸/도미노 없음.
- (참고, LOW) 전이로 화상 중인 몬스터를 플레이어가 다시 클릭하면 depth 가 0 으로 리셋돼 다시
  전이할 수 있다. 코드 주석에 의도로 명시돼 있고 에너지를 소모하므로 폭주 경로는 아니다.

### D. 회귀 — PASS
- F1 치명 클릭: 클릭당 판정 1회, Lv.5 합산 20% 실측, Day25 + 클릭 피해 Lv.3 게이트 유지.
- F2 리롤: 충전(Day 시작 시 max 로 리필) / 소모 / 세이브(`rerolls_left`) 정상.
- Day 1 → Day 2 루프 정상, `test_day_flow` 통과.

### E. 접근성 — PASS
- 도감 상태 표기가 색이 아니라 **텍스트 태그** `[제작 가능] / [선행 잠금] / [완성]` 로 구분됨.
- HUD 에너지 경고도 숫자 + 색 병행(색 단독 아님).

---

## 4) 결함

### F-1 (HIGH, FAIL 사유) — HUD 제작 목록이 4행 고정이라 `운` 이 표시되지 않는다
- **파일**: `scenes/ui/hud.tscn` (WordRow0~3), `scripts/ui/hud.gd:20`
- **재현**: 세이브 삭제 → 게임 실행 → Day 1 화면 좌하단 `제작 가능한 단어` 패널을 본다.
- **기대**: 제작 가능한 단어 5개(불/힘/돈/밥/운)가 모두 보인다.
- **실제**: 불/힘/돈/밥 4개만 보이고 **`운` 이 누락된다**. 도감에는 `[제작 가능] 운` 이 있어
  같은 화면 안에서 두 UI 가 서로 다른 말을 한다 (`play_dex_fresh.png` 한 장에 둘 다 찍혀 있음).
- **원인**: F3 가 선행 없는 단어 `운` 을 추가해 Day 1 제작 가능 단어가 4개 → 5개가 되었는데
  `_word_rows` 는 여전히 4개다. DEV 인계문 12번이 도감에서 고쳤다고 적은 것과 **정확히 같은 종류의
  버그가 HUD 쪽에 남아 있다.**
- **F3 이전에는 발생하지 않았다** (제작 가능 단어가 항상 4개 이하였음) → 이번 사이클 회귀.
- **수정 방향**: `word_dex.tscn` 과 동일하게 `hud.tscn` 에 WordRow4~9 를 노드로 추가하고
  `hud.gd` 의 `_word_rows` 에 연결. (코드 생성 금지 규칙 유지)

### F-2 (MEDIUM) — HUD 제작 목록에 empty 상태가 없다
- 10개를 모두 완성하면 좌하단 패널이 제목만 남고 **빈 상자**가 된다 (`play_dex_all.png`).
- 전역 규칙("loading/empty/error 상태 누락 금지") 위반. "완성할 단어가 없습니다" 같은 문구 필요.

### F-3 (MEDIUM) — 도감 패널이 10행이 되면서 화면을 거의 꽉 채우고 HUD 상단바와 겹친다
- 전부 완성 상태에서 패널이 y≈45 부터 시작해 `DAY 30` / `ENERGY` 표시와 겹친다
  (`play_dex_all.png`). 스크롤 컨테이너가 없어 단어가 더 늘거나 설명이 길어지면 잘린다.
- F5 단어 트리 UI 에서 어차피 다시 손댈 영역이라 그 사이클에 묶어도 된다.

---

## 5) 증거 파일 (`tests/qa_artifacts/f3/`)

| 파일 | 내용 |
|---|---|
| `qa_f3_observations.json` | 오버레이 가시성 / 클릭 전후 에너지 / 화상 틱 / 전이 처치 수 / 도감 행 원문 / 최대 에너지 |
| `play_day1_fresh.png` | 새 세이브 Day 1 — 오버레이 없음 |
| `play_dex_fresh.png` | 도감 0/10, 제작가능 5 · 선행잠금 5 (+ F-1 증거) |
| `play_dex_all.png` | 도감 10/10, ENERGY 25/25 (+ F-2, F-3 증거) |
| `play_burn_bul.png` | 불만 해금한 화상 |
| `play_burn_hwayeom.png` / `play_burn_hwayeom_again.png` | 화염 해금 후 틱 2, 재실행에도 2 |
| `play_spread_off.png` / `play_spread_on.png` | 불꽃 미해금 처치 1 vs 해금 처치 2 |

## 6) QA 가 추가한 파일 (tests/ 한정, 프로덕션 코드 무수정)

- `tests/qa_f3_play.gd` / `.tscn` — 실렌더링 관측 하네스 (스크린샷 + JSON)
- `tests/qa_f3_pool.gd` / `.tscn` — 자모 후보 풀 / 고갈 상태 프로브
- `tests/qa_f3_compat.gd` / `.tscn` — 옛 세이브 호환 / Critical 확률 / 전이 반경 게이트 프로브

## 7) 임시 변경 원복

- 검증용으로 `user://jamo_save.json` 을 여러 상태로 시드했다. **세션 시작 시점에 세이브 파일이
  존재하지 않았으므로, 검증 종료 후 삭제하여 원상 복구 완료.**
- 프로덕션 코드(`scripts/`, `scenes/`, `resources/`, `autoload/`)는 **한 줄도 수정하지 않았다.**
