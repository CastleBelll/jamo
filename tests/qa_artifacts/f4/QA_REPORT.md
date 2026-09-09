# F4 특수 몬스터 — QA 리포트

판정: **PASS**

검증 환경: Godot 4.7.stable, Windows 11, Vulkan Forward+ (Intel UHD 770).
`mcp__ziva-godot__start_godot` 으로 띄운 실제 에디터 세션에서 `run_scene` 으로
게임을 렌더링하며 관찰했고, 30초를 넘는 하니스는 같은 프로젝트를 창 모드
(`godot --path .`) 로 실행했다. Godot 프로세스는 종료하지 않았다.

주 증거: `qa_f4_observations.json` (신규 하니스 `tests/qa_f4_special.tscn` 출력),
`play_*.png`, `zoom_golden_hieut_glyph*.png`.

---

## 1. DEV 인계문 검수 절차 (A~G)

| 단계 | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | `--headless --quit` 에러 | PASS | 에러 2줄 = `NotoSansKR-Regular.ttf` 폰트 누락뿐 (`headless_boot.log`) |
| 2 | `test_game_loop.tscn` | PASS | `OK - all game loop checks passed.` (`test_game_loop.log`) |
| 3 | `test_day_flow.tscn` | PASS | `OK - day flow reached Day 2.` (`test_day_flow.log`) |
| 4 | `big_mieum.tres` Inspector | PASS | 그룹 `Combat / Movement / Visual · Click / Spawning` 노출. `Hp Multiplier 3.0`, `Gold Multiplier 3.0`, `Speed Multiplier 0.6`, `Visual Scale 2.7`, `Click Radius 1.2`, `Special Type` = enum hint `Normal:0,Special:1,Golden:2` 값 `Special(1)` |
| 5 | `golden_hieut.tres` Inspector | PASS | `Gold Multiplier 5.0`, `Special Type Golden(2)`, `Lifetime Seconds 8.0` |
| 6 | `fast_ieung.tres` Inspector | PASS | `Hp Multiplier 0.75`, `Gold Multiplier 2.0`, `Speed Multiplier 1.8`, `Motion Profile = roll_fast.tres` |
| 7 | `monster_golden_hieut.tscn` 구조 | PASS | 루트 `MonsterGoldenHieut`(상속: `monster_ieung.tscn`), `VisualRoot/Body/Lean` 아래 `Ring`(상속) + `HatBar` + `HatStroke`. 두 획은 `BoxMesh` 서브리소스라 Inspector 에서 position 조절 가능 |
| 8 | `game_world.tscn` SpawnManager Pools | PASS | `Monster Scenes` 6 / `Special Scenes` 2 / `Golden Scenes` 1 로 분리 배선 |
| 9 | `game_balance.tres` Special Monsters | PASS | `Special Spawn Chance 0.02`, `Golden Spawn Chance 0.02`, hint `0.0,1.0,0.005` (드래그 가능) |
| 10~13 | 특수 몬스터 등장·배율 실측 | PASS | 항목 3 참조 |
| 14 | 확률 원복 | PASS | `.tres` 파일 자체를 건드리지 않았다. 항목 "임시 변경" 참조 |
| 15~16 | 금 미해금 시 황금 미등장 | PASS | 항목 2 참조 |
| 17~20 | 금 해금 후 등장 / 체류 / 처치 보상 | PASS | 항목 2·4 참조 |
| 21 | 확률 원복 | PASS | 상동 |
| 22~24 | 운 배율 | PASS | 항목 5 참조 |
| 25 | 20마리 60 FPS | PASS | 항목 9 참조 |
| 26 | Day 1 → Day 2 | PASS | 항목 11 참조 |

Inspector 값은 에디터 세션에서 `monster_golden_hieut.tscn` 을 열어 루트 노드를
선택한 화면(`Data > Monster Data / Motion Profile` 그룹 노출)과, 각 `.tres` 의
`get_property_list()` 전수 덤프(그룹·range hint·enum hint 포함)로 확인했다.

---

## 2. 황금 ㅎ 게이트 (`금` 미해금 / 해금)

`golden_spawn_chance` 를 **런타임 메모리에서만** 0.9 로 올린 뒤 관찰했다.

| 상태 | `is_golden_monster_unlocked()` | `get_golden_spawn_chance()` | 풀 추첨 2000회 | 실제 필드 8마리 |
|---|---|---|---|---|
| `금` 미해금 | `false` | **0.0** | golden **0** / normal 2000 | golden **0** (`play_gate_locked_field.png`) |
| `금` 해금 | `true` | 0.9 | golden 1800~1811 / normal 189~200 | golden 5~8 (`play_gate_unlocked_field.png`) |

확률을 90% 로 올려도 미해금 상태에서 황금이 한 마리도 나오지 않는다. 게이트는
`SpawnManager.get_golden_spawn_chance()` 가 `GameState.is_golden_monster_unlocked()`
를 먼저 보고 0.0 을 반환하는 구조라 확률과 무관하게 닫힌다.

`금` 은 `geum.tres` 의 `effect_type = 7 (UNLOCK_GOLDEN)` 으로 열린다.

---

## 3. 배율 실측

살아 있는 인스턴스가 스스로 계산한 값(`max_hp`, `_speed`, `_calculate_gold_reward()`)과,
게임의 실제 입력 경로로 죽을 때까지 클릭한 횟수를 함께 쟀다. Day 1 기준.

| | 일반 ㅁ | 큰 ㅁ | 비율 | 기대 |
|---|---|---|---|---|
| max_hp | 3.0 | 9.0 | **×3.0** | ×3 |
| speed | 0.90 | 0.54 | **×0.6** | ×0.6 |
| gold | 2.0 | 6.0 | **×3.0** | ×3 |
| 죽을 때까지 클릭 | 3회 | **9회** | ×3.0 | 약 3배 |
| visual_scale / click_radius | 1.9 / 0.83 | 2.7 / 1.2 | ×1.42 / ×1.45 | 크고 클릭 쉬움 |

| | 일반 ㅇ | 빠른 ㅇ | 비율 | 기대 |
|---|---|---|---|---|
| max_hp | 3.0 | 2.25 | **×0.75** | ×0.75 |
| speed | 1.44 | 2.592 | **×1.8** | ×1.8 |
| gold | 2.0 | 4.0 | **×2.0** | ×2 |
| 죽을 때까지 클릭 | 3회 | **3회** | — | HP 2.25 라 최소 클릭 수는 3회로 같다 |
| motion profile | `roll.tres` | `roll_fast.tres` (idle 0.12~0.4, turn 13) | | 턴 빈도 ↑ |

| | 일반 몬스터 | 황금 ㅎ | 비율 |
|---|---|---|---|
| gold | 2.0 | 10.0 | **×5.0** |

처치 실측: 황금 ㅎ 를 죽였을 때 골드 +11.0. 같은 상태(`돈` 해금 = 골드 +10%)의
일반 몬스터가 2.2 이므로 정확히 5배다.

미스 클릭 0회. 큰 ㅁ 의 넓어진 `click_radius 1.2` 가 실제로 반영된다.

---

## 4. 황금 체류시간

| 항목 | 결과 |
|---|---|
| 선언값 `lifetime_seconds` | 8.0 |
| 스스로 사라짐 | **true** |
| 실측 체류 | **7.96 ~ 7.99 초** |
| 사라질 때 골드 | 0 → 0 (**미지급**) |
| 사라질 때 처치 수 | 0 → 0 (**미집계**) |
| 일반 개체 `lifetime_seconds` | 0.0 (수명 없음) |

`_expire()` 는 `register_kill()` 을 부르지 않고 `died_burning = false` 로 두므로
골드도 화상 전이도 발생하지 않는다. `died` 시그널은 그대로 쏘기 때문에
`SpawnManager._alive` 에서 정상적으로 빠지고 자리는 곧 다시 채워진다
(수용 인원 누수 없음).

---

## 5. 운 배율

| | `운` 미해금 | `운` 해금 |
|---|---|---|
| `get_special_spawn_multiplier()` | **1.0** | **1.05** |
| `get_golden_spawn_chance()` | **0.02** | **0.021** |
| `get_special_spawn_chance()` | **0.02** | **0.021** |

`un.tres` 의 `effect_type = 8 (SPECIAL_LUCK) / base_value 0.05` 가 특수·황금 양쪽에
곱해진다.

---

## 6. 시각 (v0.3 §24)

`play_gate_unlocked_field.png`, `play_day2_field.png`, `zoom_golden_hieut_glyph*.png`.

- 금속 재질: `materials/jamo_gold.tres` = `metallic 1.0 / roughness 0.25 /
  metallic_specular 0.75`. 화면에서 고리 상단에 하이라이트가 돌아 금속으로 읽힌다.
- 약한 Glow: `emission_energy_multiplier 0.35`.
- **과도한 Bloom 없음**: `resources/environment/jamo_env.tres` 에 `glow_*` 키가
  아예 없다. 즉 post-process glow 패스가 꺼져 있어 번짐이 생길 수 없다.
- 구분성: 잉크색(거의 검정) 자모들 사이에서 금색 개체가 한눈에 구분된다
  (`play_day2_field.png` 에서 ㄷ·ㅁ·ㅣ·ㅇ 사이의 금색 ㅎ 1마리).

INFO — §9.3 이 말하는 "작은 Glow" 는 현재 emission 만으로 구현돼 있고 실제 발광
패스는 없다. 과도한 Bloom 금지 조건은 확실히 지켜지지만, 눈에 띄는 빛번짐을
원한다면 F6 Juice 에서 glow 를 약하게 켜는 판단이 필요하다.

---

## 7. DEV 판단 사항 — 황금 ㅎ 글리프 (INFO, 총지휘자 판단 요청)

DEV 는 ㅎ 자모 씬이 없어 `monster_ieung.tscn`(고리)을 상속하고 `BoxMesh` 2개
(`HatBar`, `HatStroke`)를 얹어 ㅎ 를 구성했다고 보고했다.

**판정: 화면에서 한글 ㅎ 으로 읽힌다.** 근거 스크린샷
`zoom_golden_hieut_glyph.png`, `zoom_golden_hieut_glyph2.png` (게임 화면 확대).

- 고리(ㅇ) 위에 가로 획, 그 위에 세로 꼭지 — ㅎ 의 3요소가 모두 있고 위치 관계도
  맞다. 인게임 아이소메트릭 뷰에서 한 번에 ㅎ 으로 읽힌다.
- 다만 가로 획이 고리에서 살짝 떠 있고 세로 꼭지가 고리 중심선보다 왼쪽으로
  보인다(아이소메트릭 투영 때문). 손글씨 ㅎ 만큼 붙어 있지는 않다.
- 새 메시 애셋 파일은 만들지 않았다(§9.6 준수). 두 획은 씬 안의 `BoxMesh`
  서브리소스라 에디터에서 자유롭게 옮길 수 있다.

FAIL 사유는 아니다. 정식 ㅎ 자모 씬으로 승격할지는 F5 이후 판단 사항.

---

## 8. 에디터 가시성 (v0.3 §37) / 신규 메시 금지 (§9.6)

- `scenes/monsters/special/` 3종 모두 기존 자모 씬 **상속**이며 데이터만 갈아끼운다.
  `monster_big_mieum.tscn` ← `monster_mieum.tscn`,
  `monster_fast_ieung.tscn` ← `monster_ieung.tscn`,
  `monster_golden_hieut.tscn` ← `monster_ieung.tscn`.
- 신규 메시 애셋 파일 **없음**. 황금 ㅎ 의 두 획은 씬 내부 `BoxMesh` 프리미티브,
  재질은 `surface_material_override/0` 로 지정(데이터 이중 소스 없음).
- `.tres` 3종 + `game_balance.tres` 전부 그룹·range·enum 드롭다운이 Inspector 에
  노출된다(§37 "자모 리소스에서 HP/Gold/Speed/Motion Profile/Scale/Click Radius/
  Spawn Weight 를 볼 수 있어야 한다" 항목 전부 충족).

INFO — `art/Untitled.blend` / `.blend.import` 이 untracked 로 남아 있다. 어떤
씬·리소스도 참조하지 않는 잔여 파일이며 F4 변경 목록에도 없다. 커밋에 포함하지
않기를 권한다.

---

## 9. 성능 (v0.3 §36)

동시 20마리(특수 6~7 / 황금 3~7 / 일반 8~11 혼재) 상태에서 240프레임 측정.

| 항목 | 값 |
|---|---|
| 필드 개체 수 | 20 |
| 평균 FPS | **60.0** |
| 최저 FPS | **60.0** |

vsync 상한이 60 이라 그 이상은 측정되지 않지만, 240프레임 동안 단 한 번도 60 을
밑돌지 않았다(스터터 없음). 스크린샷 `play_perf_20_monsters.png`.

매 프레임 전체 탐색 여부:

- `SpawnManager._process()` 는 타이머 감산과 `_alive.size()` 비교만 한다
  (`scripts/monsters/spawn_manager.gd:75`). 필드 순회 없음.
- 배치 시의 `_clearance_at()` 순회는 스폰 순간에만, 최대 12회 시도로 제한
  (`scripts/monsters/spawn_manager.gd:114`).
- 풀의 `spawn_weight` 를 읽기 위해 PackedScene 을 인스턴스화하지 않는다.
  `_data_cache` 로 한 번만 읽는다 (`scripts/monsters/spawn_manager.gd:199`).
- `불꽃` 전이는 사망 시에만 캐시된 `_alive` 를 본다
  (`scripts/monsters/spawn_manager.gd:229`).
- 몬스터 간 회피 탐색은 0.25초 주기
  (`scripts/monsters/jamo_monster.gd` `AVOIDANCE_SCAN_INTERVAL`).

§36 이 금지한 "몬스터마다 매 프레임 전체 탐색" 패턴은 없다.

INFO — `play_perf_20_monsters.png` 에서 20마리가 아레나 중앙~상단에 몰리고, 큰 ㅁ
일부가 슬랩 가장자리 밖으로 시각적으로 넘친다. `min_spawn_distance 1.3` 과
`visual_scale 2.7` 조합의 결과이며 DEV 주의사항 10번이 미리 지적한 항목이다.
동작 버그는 아니고 `big_mieum.tres` 의 값 조정으로 해결 가능하다.

---

## 10. 스폰 다양성 (v0.3 §28)

일반 풀에서 200회 연속 추첨한 실제 순서를 기록했다.

| 항목 | 값 | 균등 추첨이라면 |
|---|---|---|
| 같은 자모 최장 연속 | **2** | 이론상 3~4 흔함 |
| 직전과 같은 자모가 나온 비율 | **3.5% ~ 5.0%** | 16.7% (1/6) |
| 자모별 분포 (6종) | 27 ~ 39 | 33.3 |

`REPEAT_WEIGHT_PENALTY 0.25` 가 실제로 걸린다. 연속 등장을 금지하지 않으면서
빈도를 1/3 이하로 눌러 §28 의 "작은 패널티 가중치" 의도와 일치한다.

---

## 11. 회귀

| 대상 | 결과 | 근거 |
|---|---|---|
| F1 치명 클릭 게이트 | PASS | `qa_shop_gate` — Day24 행 숨김 / Day25 `클릭 데미지 Lv.3 필요` 비활성 / 조건 충족 시 `1500 G` 활성. 세이브 왕복 후 crit 0.04 복원 |
| F1 치명 클릭 연출 | PASS | `qa_critical_play` — hits 82 / crits 1, 일반 4 vs 치명 8 데미지, 라벨 색·크기·셰이크 분기 |
| F2 리롤 | PASS | `qa_reroll_play` — 13개 관측 항목 전부 기록(게이트/빈 풀/저장 왕복/접근성/다음날 충전) |
| F3 단어 10개·선행 잠금 | PASS | `qa_f3_pool` — 미해금 풀 11종 → `불` 해금 시 ㅕ·ㅊ 추가 → 전부 해금 시 15종, 10개 완성 시 craftable 0 |
| F3 화염 틱 | PASS | `불`만 `[1.0, 1.0]` → `화염` 해금 `[2.0]`, 재실행에도 `[2.0]` (원본 미오염) |
| F3 불꽃 전이 | PASS | 불꽃 미해금 처치 1 / 해금 처치 2 |
| F3 하위 호환 | PASS | `qa_f3_compat` — 레거시 세이브 로드, 미지의 word id 무시, 강타+치명 확률 합산 0.1987/0.2 선언치 |
| HUD 제작 목록 | PASS | `qa_f4_hud` — Day1 5행, 전부 완성 시 빈 라벨, 2행 축소 시 `외 3개 더` 오버플로 라벨, 복구 후 5행 |
| Day 1 → Day 2 | PASS | `test_day_flow` OK. 하니스에서도 Day 2 진입, 에너지 20/20 재충전, 필드 8마리 재충전 (`play_day2_field.png`) |
| Day 전환 시 잔류 황금 | PASS | 황금 1마리를 필드에 둔 채 Day 전환 → 골드 11.0 → 11.0 (변동 없음) |
| 기존 자모 6종 하위 호환 | PASS | `.tres` 6종 무수정. 새 export 는 전부 기본값(`speed_multiplier 1.0`, `special_type Normal`, `lifetime_seconds 0`) |

**회귀 조사 기록 (중요)** — F3 하니스를 처음 돌렸을 때 `burn_tick_bul = []`,
`kills_with_bulkkot = 1` 로 기준치(`[1.0, 1.0]`, 2)와 어긋났다. 원인은 F4 가 아니라
**직전에 돌린 F1 하니스(`qa_shop_gate`)가 남긴 세이브 파일**이었다.
`jamo_save.json` 에 `click_damage: 3` 이 들어 있었고 `scripts/main.gd:38` 이 부팅 시
`SaveManager.load_game()` 을 부르기 때문에, 클릭 1회로 몬스터가 즉사해 화상이
붙기 전에 죽었다. 세이브를 치운 뒤 재실행하니 기준치와 정확히 일치했다.
F4 코드 결함 아님. (QA 하니스 실행 순서 의존성이므로 다음 사이클에 참고할 것.)

---

## 12. 자동 테스트

| 명령 | 결과 |
|---|---|
| `godot --headless --path . --quit` | 에러 2건 = 폰트 누락뿐, exit 0 |
| `godot --headless --path . res://tests/test_game_loop.tscn` | `OK - all game loop checks passed.` |
| `godot --headless --path . res://tests/test_day_flow.tscn` | `OK - day flow reached Day 2.` |
| `res://tests/qa_f4_special.tscn` (신규, 창 모드) | 완주, 경고 0, 관측 JSON + 스크린샷 5장 출력 |

---

## DEV 주의/보류 사항 검증

| # | DEV 가 적은 내용 | QA 결과 |
|---|---|---|
| 1 | ㅎ 글리프를 ㅇ 상속 + BoxMesh 2개로 구성 | **INFO** — 화면에서 ㅎ 으로 읽힌다. 항목 7 참조 |
| 2 | `scale` 대신 `visual_scale` 유지 | OK — Inspector `Visual / Click > Visual Scale` 로 노출. 기존 6종 무손상 |
| 3 | `material` 을 데이터에 안 넣고 씬에서 지정 | OK — `surface_material_override/0` 로만 지정, 이중 소스 없음 |
| 4 | 골드 업그레이드 트랙(특수 발견/황금 보정) 미구현 | OK — S1~S6 범위 밖. 현재 확률 = `.tres` 두 값 × `운` 배율뿐임을 실측으로 확인 |
| 5 | `황금` 단어(×8) 미구현 | OK — DB 단어 10개에 `황금` 없음. 현재 항상 ×5 |
| 6 | 분열 ㅂ / 점멸 ㅅ 미구현 | OK — 이번 범위 밖 |
| 7 | 황금 소멸 전용 연출 없음 | OK — 일반 death 애니메이션으로 사라진다. F6 범위 |
| 8 | 하위 호환 (`monster_scenes` 이름 유지, 새 export 기본값) | OK — 기존 자모 6종 `.tres` 무수정 동작, 레거시 세이브 로드 정상 |
| 9 | 기존 QA 하니스는 창 모드 필요 | OK — `qa_shop_gate` / `qa_f3_play` / `qa_f4_hud` / `qa_critical_play` 창 모드로 실행. 신규 `qa_f4_special` 도 동일 |
| 10 | 큰 ㅁ 가 아레나에서 매우 큼 | **INFO** — 20마리 밀집 시 슬랩 가장자리를 시각적으로 넘는 개체가 보인다. 항목 9 INFO 참조 |

---

## 임시 변경 / 원복

- **프로덕션 파일 수정 0건.** `game_balance.tres` 의 `special_spawn_chance` /
  `golden_spawn_chance` 는 파일을 건드리지 않고 실행 중 메모리에서만 덮어썼다.
  현재 파일 값은 둘 다 `0.02` 그대로다(DEV 커밋값). `git status` 상 이 파일의
  변경분은 전부 DEV 의 것이다.
- **추가한 파일 (tests/ 한정)**
  - `tests/qa_f4_special.gd` / `.tscn` / `.gd.uid` — F4 관측 하니스
  - `tests/qa_artifacts/f4/` — 본 리포트, 관측 JSON, 스크린샷, 로그
- **갱신된 파일 (tests/ 한정)** — 회귀 하니스를 재실행하면서
  `tests/qa_artifacts/f1/gate_report.json`, `f1/play_report.json`,
  `f2/reroll_report.json`, `f1`·`f2`·`f3` 스크린샷이 새 실행 결과로 덮어써졌다.
  내용은 모두 PASS 값이다.
- **세이브 파일** — 회귀 조사를 위해
  `%APPDATA%/Godot/app_userdata/JAMO/jamo_save.json` 을 `jamo_save.json.qabak` 로
  옮겨두었고 현재 세이브는 없는(새 게임) 상태다. 원본 자체가 이번 QA 의
  `qa_shop_gate` 실행이 만든 값(day 25 / 94500 G)이라 복원하지 않았다.
  필요하면 `.qabak` 을 되돌리면 된다. 리포지토리 밖 경로이므로 커밋에 영향 없음.
- Godot 프로세스는 종료하지 않았다.

---

## 첨부

| 파일 | 내용 |
|---|---|
| `qa_f4_observations.json` | 전 항목 수치 원본 |
| `play_gate_locked_field.png` | `금` 미해금 + 황금 확률 90% — 황금 0마리 |
| `play_gate_unlocked_field.png` | `금` 해금 + 황금 확률 90% — 필드가 금색 ㅎ 로 채워짐 |
| `play_special_field.png` | 특수 확률 90% — 큰 ㅁ / 빠른 ㅇ 혼재, 크기 대비 확인 |
| `play_perf_20_monsters.png` | 20마리 혼재, 60 FPS |
| `play_day2_field.png` | Day 2 재충전, 잉크 자모 사이의 금색 ㅎ |
| `zoom_golden_hieut_glyph.png` / `_glyph2.png` | ㅎ 글리프 판독 근거 (게임 화면 확대) |
| `headless_boot.log` / `test_game_loop.log` / `test_day_flow.log` / `regression_headless.log` | 자동 테스트 로그 |
