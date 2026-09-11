# JAMO P1 (Wave 전투) — QA 리포트

**판정: FAIL**

근거: CRITICAL 결함 1건 — 클릭 한 번으로 몬스터가 영구 정지하고, 그 Wave 가 절대
Clear 되지 않아 **RUN 이 승리도 패배도 못 하는 상태로 잠긴다**. 실플레이 중 Wave 5 에서
실제로 걸렸고, 헤드리스에서 결정론적으로 재현했다.

그 1건을 제외한 A~I 26개 검수 항목과 자동 테스트는 전부 통과했다.
DEV 가 제시한 Wave 곡선 근거도 실제 플레이로 성립을 확인했다.

- 검증 환경: Godot 4.7.stable, Windows 11, Intel UHD Graphics 770
- 프로덕션 코드 수정: **없음.** 추가한 것은 `tests/` 아래 신규 하네스 3종뿐이다 (4절).

---

## 0. CRITICAL — 클릭 한 번으로 Wave 가 영구 정지한다

**심각도: CRITICAL (BLOCK).** P1 완료 기준 "Wave 1~5 를 실제로 플레이할 수 있다" 를 깬다.

### 재현

```
godot --headless --path . res://tests/qa_p1_stall.tscn
```

로그: `tests/qa_artifacts/p1/stall_repro.log`

```
-- repro: one non-lethal click delivered during State.TURN
    before: state=3 pos=(-2.46, 0.71) hp=3
    after 600 frames: state=3 anim=idle moved=0.1755 m alive=true
  FROZEN - the clicked monster never moved again.
...
    frame 1500: spawning=true alive=1 exhausted=true core=9989
      giyeok state=3 anim=idle
      giyeok alive=true hp=2 pos=(-2.29, 0.66) d_core=3.82 reach=0.90
    frame 3000: ... giyeok ... pos=(-2.29, 0.66) d_core=3.82
    frame 4500: ... giyeok ... pos=(-2.29, 0.66) d_core=3.82
STALL - Wave 5 never cleared in 6000 frames.
```

손으로 만든 상황이 아니라 **정상 플레이에서 먼저 나왔다.** 첫 실플레이 실행에서 Wave 5 가
`alive=1 / exhausted=true` 로 20000 프레임 동안 Clear 되지 않았고, 그때 남은 개체는
`fast_ieung`, 좌표 `(-2.75, -0.32)` 로 4500 프레임 내내 1mm 도 움직이지 않았다.
증거 스크린샷: `play/50_wave6_start.png` (WAVE 5 / ENERGY 0 / 문장핵 6, 한 마리만 남아 정지).

### 기대

클릭으로 죽지 않은 몬스터는 계속 문장핵으로 걸어가고, 도달하면 사라지며 Wave 가 Clear 된다.

### 실제

`State.TURN` 중에 들어온 **죽이지 못한 클릭 한 번**이 몬스터를 영구히 얼린다.
걷지도, 죽지도, 문장핵에 닿지도 않는다. `SpawnManager._alive` 에 영원히 남아
`field_cleared` 가 발생하지 않는다.

### 근본 원인 (`scripts/monsters/jamo_monster.gd`)

1. `_begin_turn()` (216행) 이 `_state = State.TURN` 으로 두고 `turn` 애니메이션을 재생한다.
   `turn` 이 끝나면 `_on_animation_finished(&"turn")` → `_begin_walk()` 로 걷기가 시작된다.
2. `take_click_damage()` (367행) 이 `_animation.play(&"hit")` 으로 **`turn` 을 덮어쓴다.**
   Godot 의 `AnimationPlayer` 는 `play()` 로 교체된 애니메이션에 대해
   `animation_finished` 를 내지 않는다. 그래서 `_begin_walk()` 는 영원히 호출되지 않는다.
3. `_on_animation_finished(&"hit")` (341~351행) 은 `_state == State.WALK` 일 때만
   `_begin_walk()` 를 부른다. 지금 상태는 `TURN` 이라 `_play_if_not_current(&"idle")` 로
   **애니메이션만** 되돌리고 `_state` 는 `TURN` 그대로 둔다.
4. `_physics_process()` (149~157행) 의 `match _state` 에는 `TURN` 분기가 없다.
   `_:` 가 매 프레임 `velocity = Vector3.ZERO; move_and_slide()` 를 돌린다. 영구 정지.
   (`enum State { SPAWN 0, IDLE 1, WALK 2, TURN 3, DEAD 4 }` — 위 로그의 `state=3` 이 TURN.)

`spawn` 애니메이션도 같은 구멍이다. `spawn` 중에 클릭이 들어오면 `_state` 가 `SPAWN` 에
그대로 남아 동일하게 얼어붙는다.

### 영향 범위

- **Wave 1~2 는 안전하다.** 몬스터 HP 1 이라 모든 클릭이 즉사시켜 `hit` 후 상태가 남지 않는다.
- **Wave 3 부터 상시 발생 가능하다.** HP 2~3 이라 죽지 않는 클릭이 정상적으로 존재하고,
  `turn` 은 걷는 도중 주기적으로 들어오는 상태다.
- 얼어붙은 개체가 하나라도 생기면 그 Wave 는 **영구히 Clear 되지 않는다.** 에너지도 회복되지
  않고(Wave Clear 가 유일한 회복 시점), 에너지 0 이면 그 개체를 클릭해 정리할 수도 없다.
  문장핵도 더 이상 맞지 않으니 패배조차 못 한다. 플레이어는 강제 종료 외에 방법이 없다.
- Wave Clear 가 저장 시점이라(§45) 그 Wave 에서 한 것은 전부 날아간다. 획득 Gold 는 즉시
  `MetaState` 에 적립되므로 Gold 만은 남는다.
- 간헐적이다. 재실행한 플레이스루에서는 걸리지 않고 Wave 6 까지 정상 진행했다.

### 수정 방향 (참고, QA 는 손대지 않음)

`_on_animation_finished(&"hit")` 이 `WALK` 뿐 아니라 `SPAWN` / `TURN` 도 복구하도록 하거나,
더 근본적으로 `_physics_process` 의 `match` 에 `TURN` / `SPAWN` 워치독을 두어 상태 타임아웃
시 `_begin_walk()` 로 빠져나오게 한다. 어느 쪽이든 `take_click_damage` 하나만 고치면 안 된다 —
`hit` 을 재생하는 모든 경로가 같은 구멍을 공유한다.

---

## 1. Wave 1~5 실플레이 (§48 Phase 1 완료 기준)

`godot --path . res://tests/qa_p1_play.tscn` — 창 모드, 실제 마우스 이벤트로 화면에 그려진
몬스터를 클릭한다. 세이브를 지우고 시작하므로 영구 업그레이드 0, 클릭 피해 1, 에너지 10.

| wave | 수 | HP | 에너지 | 클릭 | 처치 | 문장핵 손실 | 문장핵 잔여 | Clear |
|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 1 | 10 | 5 | 5 | 0 | 20 | true |
| 2 | 7 | 1 | 10 | 7 | 7 | 0 | 20 | true |
| 3 | 8 | 2 | 10 | 10 | 5 | 3 | 17 | true |
| 4 | 9 | 2 | 10 | 10 | 5 | 4 | 13 | true |
| 5 | 10 | 3 | 10 | 10 | 1 | 9 | 4 | true |
| 6 | 10 | 3 | 10 | 10 | 3 | 4 | 0 | false (RUN 실패) |

**Wave 1~5 를 실제로 플레이해 통과했다.** Wave 6(= Wave 5 반복)에서 문장핵이 0 이 되어
RUN 이 끝났다. 단, 0절의 정지 결함 때문에 이 플레이가 **매번** 성립하지는 않는다.

스크린샷 (`tests/qa_artifacts/p1/play/`):

| 파일 | 내용 |
|---|---|
| `00_wave1_start.png` | WAVE 1 / 문장핵 20 / ENERGY 10 / 0 G / 처치 0 |
| `10_wave2_start.png` | Wave 1 전멸 후 Wave 2, 에너지 회복 |
| `20_wave3_start.png` | Wave 2 전멸 후 Wave 3 |
| `30_wave3_energy_zero_wave_continues.png` | **에너지 0 이후 Wave 지속 증거** |
| `30_wave4_start.png` | Wave 3 Clear → Wave 4 |
| `40_wave5_start.png` | **Wave 5 도달**, 문장핵 12 / 20, ENERGY 10 / 10 |
| `50_wave6_start.png` | Wave 6 진입 |
| `90_run_result.png` | 결과 화면 |
| `95_full_field_20.png` | 동시 20마리 |

---

## A. P0 이관 사항 — PASS

| # | 항목 | 결과 |
|---|---|---|
| 1 | `end_run_when_energy_depleted` 삭제 | **PASS** |
| 2 | 에너지 0 이 RUN 실패가 아님 | **PASS** |
| 3 | 결과 부제 '문장핵이 무너졌다' 복귀 + 실제 동작 일치 | **PASS** |
| 4 | Day 곡선 잔재 없음 | **PASS** |

1. `grep -rn "end_run_when_energy_depleted"` → 프로덕션·테스트 전체 0건. `energy_depleted`
   시그널 자체는 `signal_bus.gd:16` / `run_state.gd:230` 에 남아 있으나 **구독자가 없다**
   (`tests/_deferred_v03/test_game_loop.gd` 만 참조, 격리된 v0.3 보관소). HUD 안내문은
   `energy_changed` 로 갱신되므로 결과 화면 경로와 무관하다.
2. `play/30_wave3_energy_zero_wave_continues.png`: WAVE 3 / `ENERGY 0 / 10` /
   `수동 클릭 불가 — WAVE 는 계속된다` (붉은 글자) / 몬스터가 판 위에 남아 진행 중 /
   **결과 화면 없음**. 이후 Wave 3 이 Clear 되고 Wave 4 로 넘어갔다 (1절 표). `qa_p0_flow`
   도 `energy 0: wave 3 still running, core 20 / 20` 을 출력한다.
3. `scenes/ui/run_result.tscn:43` 부제 = `문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터
   시작한다.` 실제 동작과 일치한다 — `main.gd:32` 는 `SignalBus.run_failed` 만 구독하고,
   그 시그널은 `RunState.damage_core()` 가 `core_hp <= 0` 일 때만 낸다. 다른 진입 경로 없음.
4. `3 x 1.035` / `1.035` / `current_day` / `hp_growth_per_wave` / `gold_growth_per_wave`
   → 활성 코드·데이터 0건. `tests/_deferred_v03/test_game_loop.gd` 에만 남아 있고 그 파일은
   실행 대상이 아니다. `game_balance.tres` 에 `hp_growth_per_wave` / `gold_growth_per_wave`
   / `special_spawn_chance` / `hp_growth_per_day` 프로퍼티가 **존재하지 않음**을 런타임으로도
   확인했다.

---

## B. 문장핵 (§6.1, §35) — PASS (주의 1건)

| # | 항목 | 결과 |
|---|---|---|
| 5 | 맵에 존재 + HUD 상단 중앙 HP | **PASS** |
| 6 | 도달 시 피해 + 소멸 + 카메라 shake | **PASS** |
| 7 | 문장핵 0 이 유일한 실패 조건 | **PASS** |
| 8 | `MetaState` Core HP 업그레이드 읽기 구조 | **PASS** |
| 9 | 물리 충돌 없음 / `reach_radius` 0.9 체감 | **PASS (P2 주의)** |
| 10 | 임시 프리미티브 + `VisualRoot` 교체 가능성 | **PASS (주의)** |

5. 실게임 스크린샷에서 종이 판 후방에 검은 원기둥 + 금색 정육면체가 보이고, HUD 상단 중앙에
   `문장핵 20 / 20` + 게이지가 있다. `game_world.tscn:34` 위치 `(0, 0, -2.4)`.
6. 실제 플레이에서 클릭하지 않은 몬스터가 문장핵에 닿자 사라지고 `문장핵 20 → 17` 로 줄었다
   (라이브 실행 스크린샷). 골드는 오르지 않았다 — `_reach_objective()` 는 `_expire()` 를
   부르고 `_expire()` 는 `register_kill` 을 타지 않는다. shake 는 `sentence_core.gd` 가
   `camera_rig.shake()` 를 호출하고, `game_world.tscn:33` 이 `camera_rig` 를 실제로 연결해
   뒀다. `hit` 애니메이션(`VisualRoot:scale`/`position` 키)이 함께 재생된다.
7. `RunState.damage_core()` 만 `end_run()` 을 부른다. `main.gd` 는 `run_failed` 외에
   결과 화면 진입 경로가 없다. 에너지 0 (2번), Wave 진행, 이어하기 어느 쪽으로도 RUN 이
   끝나지 않는 것을 실플레이·`test_wave_combat`·`qa_p0_flow` 세 경로로 확인했다.
8. `meta_state.gd:25` `UPGRADE_CORE_HP := &"core_hp"`, `:132` `get_core_max_hp()` 가
   `get_upgrade_value(UPGRADE_CORE_HP, balance.base_core_hp)` 를 읽는다. 트랙 `.tres` 는
   없고(P5), 없으면 `base_core_hp = 20`. 구조는 준비돼 있다.
9. 실플레이에서 몬스터가 문장핵을 통과하거나 겹쳐 보이는 장면은 없었다. 현재 임시
   프리미티브 반경이 0.4m 라 0.9m 판정이 자연스럽다.
   **주의:** blender 브랜치의 실제 GLB 는 `dimensions_godot_xyz = [2.54, 1.96, 1.68]` 로
   가로 반경이 1.27m 다. 그대로 넣으면 `reach_radius 0.9` 가 **모델 안쪽**이 되어 몬스터가
   모델을 파고든 뒤에야 사라진다. 애셋 교체 시 `reach_radius` 를 1.4 안팎으로 함께 올려야
   한다. 지금 고칠 문제는 아니고 교체 담당에게 넘길 항목이다.
10. `scenes/objective/sentence_core.tscn` 의 `VisualRoot` 는 빈 `Node3D` 이고 그 아래
    `Pillar`(CylinderMesh) / `Cap`(BoxMesh) 둘뿐이다. `sentence_core.gd` 는
    `@export var visual_root: Node3D` 너머를 참조하지 않고, `hit` 애니메이션이 `VisualRoot`
    자체의 scale/position 만 키한다. **교체 가능한 구조가 맞다.**
    `CastleBelll/blender` 브랜치에 `art/objective/sentence_core.glb` (2780 삼각형, 9 surface,
    6 머티리얼) 가 실제로 있음을 확인했다. 이번에 교체하지 않았다.

---

## C. 접근 AI (§6, §15) — PASS

| # | 항목 | 결과 |
|---|---|---|
| 11 | 자모별 고유 보행 유지, 목적지만 문장핵 | **PASS** |
| 12 | 아레나 클램프 유지 | **PASS** |
| 13 | 동시 20마리 60 FPS | **PASS** |

11. `resources/motion_profiles/*.tres` 9개는 P1 에서 **한 글자도 수정되지 않았다**
    (`git status` 에 없음). `jamo_monster.gd:100~102` 는
    `base_speed × profile.move_speed_multiplier × data.speed_multiplier × wave.speed_multiplier`
    로 Wave 배율을 **곱하기만** 하고 프로필을 대체하지 않는다. 걷기 애니메이션·`step_frequency`
    도 프로필에서 그대로 온다. 바뀐 것은 `_pick_target()` 의 목적지뿐이다 (배회 랜덤 →
    문장핵). 실플레이 관찰에서 ㄷ 은 무겁게, ㅁ 은 튀며, ㅇ 은 굴러가고 ㅅ 은 잰걸음으로
    움직이며, 걷다 멈추고 방향을 잡는 idle/turn 리듬도 v0.3 그대로다. 걸음 성격이 뭉개지지
    않았다.
12. 동시 20마리를 채운 상태에서 각 개체의 `abs(x)/hx + abs(z)/hz` 를 측정해
    **1.02 를 넘는 개체 0마리**. 몸통 크기를 뺀 `get_walkable_half_extents()` 기준이므로
    F5 에서 잡은 규칙 그대로다. 스크린샷 `play/95_full_field_20.png`.
13. **20마리 동시, avg 60.0 FPS / min 60.0 / 1% low 60.0** (300프레임 표본,
    `Engine.time_scale = 1.0`, 실제 창, Intel UHD 770). 60 FPS 상한에 붙어 있다.

---

## D. Wave 데이터와 곡선 (§25, §53) — PASS

| # | 항목 | 결과 |
|---|---|---|
| 14 | Inspector 스키마 전부 노출·편집 가능 | **PASS** |
| 15 | DEV Wave 곡선 근거 성립 | **PASS** |
| 16 | 수치가 전부 `.tres`, `.gd` 하드코딩 없음 | **PASS** |
| 17 | Wave 6+ 마지막 Wave 반복, 크래시 없음 | **PASS** |

14. `wave_03.tres` 의 `get_property_list()` 를 실제로 덤프해 그룹·타입·힌트·값을 확인했다.

```
[group] Spawn     enemy_pool(PackedScene 배열 6) / enemy_count 8 (1~500)
                  spawn_interval 0.9 (0.05~10, step 0.05) / max_alive 4 (1~20)
[group] Scaling   hp_multiplier 2.0 / speed_multiplier 1.1 / gold_multiplier 1.25
                  special_spawn_rate 0.05
[group] Type      wave_type Normal:0,Elite:1,Mini Boss:2,Word Boss:3 / boss_id "" / reward_tier 2
```

    전부 `PROPERTY_USAGE_EDITOR | STORAGE` 에 range/enum 힌트가 붙어 있다. `WaveData` 는
    `@tool` 이라 에디터에서 바로 편집된다. `game_database.tres` 의 `waves` 배열 = 5.

15. **실제 플레이로 성립을 확인했다.** 1절 표가 DEV 예측과 어떻게 맞는지:

| Wave | DEV 예측 | 실측 | 판정 |
|---|---|---|---|
| 1 | 전멸 (5 클릭) | 5 클릭 5 처치, 누수 0 | 일치 |
| 2 | 전멸 (7 클릭) | 7 클릭 7 처치, 누수 0 | 일치 |
| 3 | 5 처치, 3 누수 | 5 처치, 3 누수 | 정확히 일치 |
| 4 | 5 처치, 4 누수 | 5 처치, 4 누수 | 정확히 일치 |
| 5 | 3 처치, 7 누수 | 1 처치, 9 누수 | 어긋남 (아래) |
| 누적 | 누수 14 < 20, Wave 5 생존 | 누수 16, 문장핵 4 잔여, 생존 | 성립 |
| 6~7 | 실패 | Wave 6 에서 실패 | 성립 |

    Wave 5 가 예측(3 처치)보다 나쁜 이유는 설계가 아니라 **플레이 방식** 때문이다. 하네스는
    "문장핵에 가장 가까운 개체"를 클릭하는데, HP 3 짜리를 2대 때린 상태에서 더 가까운 개체가
    새로 생기면 대상을 바꿔 피해가 분산된다. 사람이 한 마리를 끝까지 때리면 DEV 예측(3 처치)에
    수렴한다. 어느 쪽이든 §7.1 이 요구한 "무엇을 클릭할지 고르게 되는 압박"이 Wave 3부터
    실제로 발생하고, 단어 없이 Wave 5 까지 생존하고 Wave 6 에서 실패하는 §53 루프가 성립한다.
    `base_monster_hp 1 × wave.hp_multiplier × JamoMonsterData.hp_multiplier` 에서 일반 풀 6종의
    `hp_multiplier` 는 전부 기본 1.0 이므로 DEV 표의 HP 전제도 맞다.

16. Wave 수치를 만드는 코드 경로는 `GameBalance.monster_hp_for_wave(wave, mult)` /
    `monster_gold_for_wave(wave, mult)` 둘뿐이고 둘 다 `WaveData` 를 인자로 받는다.
    `SpawnManager` 는 `_wave.enemy_count / spawn_interval / max_alive / special_spawn_rate`
    를, `JamoMonster` 는 `wave.speed_multiplier` 를 읽는다. 스크립트에 Wave 별 상수·공식 없음.
17. `GameDatabase.find_wave(45)` 가 Wave 5 데이터를 그대로 돌려주는 것을 `test_wave_combat`
    가 검사하고, 실플레이도 Wave 6 를 Wave 5 구성(10마리, HP 3)으로 돌린 뒤 정상적으로 RUN
    실패까지 갔다. 크래시·에러 0.

---

## E. 에너지 (§7) — PASS

| # | 항목 | 결과 |
|---|---|---|
| 18 | Max 10 / 클릭 1 소모 / Wave Clear 시 최대 회복 | **PASS** |
| 19 | 에너지 0 이후 DoT 계속 작동 + negative control | **PASS** |
| 20 | 에너지 0 DoT 처치 골드 지급 | **PASS** |

18. `game_balance.tres`: `start_max_energy = 10`, `click_energy_cost = 1`.
    실플레이 1절 표에서 매 Wave 시작 에너지가 10 이고, Wave 1 은 5클릭·Wave 2 는 7클릭에
    전멸했다(클릭 1당 1 소모). Wave Clear 마다 `ENERGY 10 / 10` 으로 회복되는 것을
    스크린샷 `10/20/30/40_wave*_start.png` 로 확인했다.

19. **DEV 의 `test_wave_combat` DoT 검사는 동어반복이 아니다.** negative control 을 새로
    만들어 직접 검증했다 (`tests/qa_p1_negctl.tscn`):

```
    control: gold 0.00 -> 0.00, kills 0 -> 0 over 600 frames
    treated: gold 0.00 -> 2.20 after 37 frames, energy at burn 0
OK - the DoT-at-energy-0 claim survives its negative control.
```

    - control arm: 에너지 0, 화상 없음, 클릭 없음 → 600프레임 동안 Gold·처치수 **불변**.
      즉 "에너지 0 에서 Gold 가 저절로 오른다" 는 교란 요인이 없다.
    - treated arm: 같은 상태에서 화상 1개만 적용 → Gold 0 → 2.20, 처치 +1.

    코드 경로로도 확인했다: `_on_status_tick_damage → take_status_damage → _apply_damage →
    _die → RunState.register_kill → add_gold` 어디에도 에너지 참조가 없다.

    **다만 `tests/test_wave_combat.gd:173` 의 단언은 약하다.**
    `_check(RunState.current_energy == 0 or RunState.current_wave > 1, ...)` 의 `or` 절
    때문에, 화상을 붙이기 전에 Wave 가 Clear 돼 에너지가 10 으로 회복된 경우에도 통과한다.
    negative control 초안이 정확히 그 상태에 걸려 `energy at burn 10` 으로 측정됐다
    (재확인 후 재드레인해 0 으로 고정). Gold 단언(175~181행)은 영향을 받지 않으므로 결과가
    틀린 것은 아니지만, 그 `or` 절은 언젠가 "에너지 0 에서" 라는 전제를 조용히 잃는다.
    **MEDIUM: `or RunState.current_wave > 1` 을 빼고, 화상 직전에 에너지를 다시 0 으로
    만드는 편이 낫다.**

20. 19번 treated arm 이 그대로 증거다. 에너지 0 에서 화상 처치가 `MetaState.gold` 를
    올리고 `run_statistics.kills` / `gold_earned` 에도 반영된다.

**주의:** 화면에서 화상을 켜는 UI 는 P2 라, 이 항목은 눈으로 본 것이 아니라 실제 씬에서
Resource 를 몬스터에 적용해 잰 것이다. 검증 자체는 실제 `main.tscn` 에서 돌았다.

---

## F. 실패와 Gold (§14, §35) — PASS

| # | 항목 | 결과 |
|---|---|---|
| 21 | 실패 시 `RunState` 비워짐, `MetaState` 유지 | **PASS** |
| 22 | 실패해도 RUN Gold 가 영구 Gold 에 남음 | **PASS** |
| 23 | 결과 화면에 도달 Wave / 처치 / Gold | **PASS** |

21. 세이브 파일 관찰(`qa_p0_flow`):
    - RUN 진행 중: `top=["audio","meta","run","save_version"] meta_keys=10 run_present=true`
    - 패배 후: `top=["audio","meta","save_version"] run_present=false`

    `meta` 에 런 필드 없음, `run` 에 `gold`/`highest_wave` 없음 — `test_state_split`
    (`MetaState 10 / RunState 16` 필드, 겹침 0) 이 별도로 단언한다. 셋 다 통과.
22. **v0.4 의 핵심이 지켜진다.** `RunState.add_gold()` 가 획득 즉시
    `MetaState.add_gold()` 로 적립하고, `end_run()` 은 아무것도 회수하지 않는다.
    실플레이: 패배 직후 `banked gold after the defeat: 73.90, highest wave 6`,
    결과 화면 `획득 GOLD 73 G (유지됨)`. `qa_p0_flow` 도 패배 2회 후 허브 GOLD 가
    37 → 77 로 누적되는 것을 보여준다.
23. `play/90_run_result.png`: `RUN 종료` / `문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터
    시작한다.` / `도달 WAVE 6` / `처치 26` / `획득 GOLD 73 G (유지됨)` /
    `★ 최고 WAVE 기록 갱신`.

---

## G. HUD (§30) — PASS

| # | 항목 | 결과 |
|---|---|---|
| 24 | 좌상 WAVE / 상중 문장핵 / 하중 ENERGY / 우상 GOLD | **PASS** |
| 25 | 카드 UI 로 덮지 않음, 클릭 방해 없음 | **PASS** |
| 26 | HUD 가 씬 노드, 코드 생성 아님 | **PASS** |

24. 실게임 스크린샷 그대로다. `hud.tscn` 앵커도 일치한다 — `TopBar` preset 10 (상단 가로),
    `CorePanel` preset 5 (상단 중앙), `EnergyPanel` preset 7 (하단 중앙),
    `WaveClearLabel` preset 8 (화면 중앙). §30 "하단 또는 좌하단 ENERGY" 는 하단 중앙으로
    충족. 좌하단 `장착 단어` 패널은 §30 의 "접이식 현재 단어 영역" 자리다.
25. 화면을 덮는 카드 UI 없음. 판 전체가 비어 있고 HUD 는 가장자리에만 있다.
    `hud.tscn` 의 `HUD` 루트 / `Spacer` / `WaveClearLabel` 이 모두 `mouse_filter = 2`
    (IGNORE) 라 몬스터 클릭을 막지 않는다. 실제로 `qa_p1_play` 가 화면 좌표로 쏜 클릭이
    전부 몬스터에 닿아 에너지를 소모했고 (Wave 1 에서 5/5, Wave 2 에서 7/7),
    `qa_p0_flow` 도 `landed 22 monster clicks` 를 기록한다.
26. `TopBar`(Wave/Gold/Kills/Buttons), `CorePanel`(CoreLabel/CoreBar),
    `EnergyPanel`(EnergyLabel/EnergyBar/EnergyWarnLabel), `WaveClearLabel`, `WaveClearAnim`
    이 전부 `hud.tscn` 의 노드다. `hud.gd` 는 `%UniqueName` 으로 찾아 쓰기만 하고
    노드를 만들지 않는다.

---

## H. 회귀 — PASS (주의 1건)

| # | 항목 | 결과 |
|---|---|---|
| 27 | 허브 판때기 9항목 / State 분리 / v0.3 마이그레이션 / 안내문 대비 / 클램프 | **PASS** |
| 28 | `qa_f5_*` 의 `_free_roam()` 이 검증을 약화시키지 않았는지 | **PASS (주의)** |
| 29 | 이어하기 동작이 사용자에게 손해인지 | **PASS (MEDIUM 주의)** |

27. 창 모드 7종 전부 exit 0 / FAIL 0:
    - `qa_p0_plates_all`: 7개 판 전부 단일 하이라이트, 4해상도 × 2세이브 상태 178프레임,
      포커스 해제 시 8/8 에서 0개 점등.
    - `qa_p0_flow`: 허브 → RUN → 결과 → 허브, 이어하기 규칙, v0.3 세이브 마이그레이션,
      마이그레이션 안내문 대비 **12.44:1** (WCAG AA 4.5:1 여유 통과), 상점에 DAY 문구 0.
    - `qa_f8_focus_all`: 포커스 인디케이터 3.0:1 충족.
    - `qa_f7_art`: `WARN: 1 edge sample(s) look like letterbox at save_1920x720` 1건.
      WARN 이고 exit 0 이며 P1 이전부터 있던 항목이다 (DEV 는 6건으로 보고; 실행마다 개수가
      흔들리는 샘플링 경고다). P1 결함 아님.
    - 아레나 클램프는 C-12 에서 별도로 실측했다 (20마리 동시, 이탈 0).
28. `_free_roam()` 은 **추가**일 뿐 측정 코드를 건드리지 않았다. `git diff` 상 세 파일 모두
    `start_run()` 뒤 한 줄 호출 + 함수 정의가 전부이고, 클램프/마진/스필 계산 로직은 그대로다.
    채우기 목표도 `MetaState.get_monster_capacity()` = 20 으로 유지된다. F5 가 재는 대상은
    "배회 시 클램프" 이고, P1 에서 `objective` 가 생기면 그 전제가 깨지므로 전제를 복원한
    것이 맞다.
    **주의:** 그 결과 `qa_f5_*` 는 이제 **실제 플레이 구성(문장핵으로 수렴하는 상태)의
    클램프를 재지 않는다.** 이 공백은 이번 QA 가 `qa_p1_play` 의 20마리 실측(이탈 0)으로
    메웠다. P2 이후에도 F5 만 믿으면 안 되고, 목적지가 있는 상태의 클램프를 재는 항목을
    상시 하네스에 남겨야 한다.
29. DEV 보고대로 동작한다 (`qa_p0_flow` 7·8단계 통과): 이어하기 시 에너지는 저장값 유지
    (회복 없음), Wave 번호·문장핵 HP 유지, 그 Wave 의 몬스터는 처음부터 재스폰,
    Wave Clear 가 저장 시점.
    **MEDIUM — 사용자가 손해를 본다.** 에너지 7/10 로 중단했다가 이어하면 에너지 7 로
    Wave 전체(예: Wave 5 = 10마리 × HP 3 = 30 HP)를 다시 받는다. 이미 처리한 몬스터가 되살아
    나는데 에너지는 회복되지 않으므로, 중단 시점이 Wave 후반일수록 손해가 커지고 에너지가
    0~2 남은 상태로 중단하면 그 Wave 는 사실상 문장핵으로 전부 흘려보내야 한다.
    악용 여지는 없다(플레이어에게만 불리). P1 범위로는 허용 가능하지만, P2 에서
    "이어하기 시 에너지도 최대로 회복" 하거나 "스폰 카운트를 저장" 하는 쪽으로 정리해야 한다.

---

## I. 자동 테스트 — PASS

| # | 항목 | 결과 |
|---|---|---|
| 30 | `godot --headless --path . --quit` 에러 0 | **PASS** |
| 31 | `test_state_split` / `test_run_flow` / `test_wave_combat` | **PASS** |
| 32 | 창 모드 하네스 7종 | **PASS** |

30. 폰트 누락 2줄(`res://art/fonts/NotoSansKR-Regular.ttf`, 기존 이슈) 외 에러 0, exit 0.
31. 3개 전부 exit 0.
    - `test_state_split` → `OK - meta/run split holds.` (MetaState 10 / RunState 16)
    - `test_run_flow` → `OK - Wave 1 started, the core fell, and the hub came back.`
    - `test_wave_combat` → `OK - waves run on data, energy 0 ends nothing, the core is the
      only failure.` 중간 출력 `core 20 -> 19` / `DoT kill: gold 0.00 -> 2.00, kills 1` /
      `Wave 1 -> 2 ... energy 10 / 10` / `result: 도달 WAVE 2 | 처치 3 | 획득 GOLD 6 G (유지됨)`
      전부 DEV 보고와 일치.
32. `qa_p0_flow` / `qa_p0_plates_all` / `qa_f7_title` / `qa_f7_art` / `qa_f8_labels` /
    `qa_f8_focus_all` / `qa_f8_resize` — 전부 exit 0, `FAIL` 0건.

**에디터 경고 (LOW, 신규):** `wave_controller.gd:59` 에서
`"await" keyword is unnecessary because the expression isn't a coroutine nor a signal`.
`_between_waves()` 가 P2 훅용 빈 함수라 생기는 경고로, 동작에는 영향이 없고 P2 가 그 안에
`await` 를 넣으면 사라진다. 에러가 아니라 경고이며 헤드리스 import 에서는 나오지 않는다.

---

## 2. 스펙 대비 이관 항목 (P1 FAIL 아님, 총지휘자 확인용)

- **§5.1 은 Wave 5 를 중간보스로 규정한다.** `wave_05.tres` 는 `wave_type = NORMAL` 이다.
  DEV 는 P9 로 넘긴다고 명시했고 로드맵도 그렇게 적혀 있다. 의도된 이관으로 본다.
- **§35 결과 화면의 신규 단어 / 숙련 상승 / 합성어 / 처치 보스** 는 아직 없다. 결과 화면에
  "이후 Phase 에서 추가된다" 고 적혀 있다. P2 이후 범위.
- **`monster_capacity` 업그레이드가 게임에 영향을 주지 않는다** (동시 수는 `WaveData.max_alive`).
  상점에는 여전히 노출된다. DEV 가 P5 정리 대상으로 선언했다. 플레이어에게 "돈 주고 산 것이
  아무 효과가 없는" 상태이므로 P5 까지 미루지 말고 상점에서 숨기는 편이 낫다 (MEDIUM).

---

## 3. 결함 요약

| 심각도 | 항목 | 위치 |
|---|---|---|
| **CRITICAL** | 클릭이 `State.TURN`/`SPAWN` 중 들어오면 몬스터 영구 정지 → Wave 영구 미클리어 → RUN 잠김 | `scripts/monsters/jamo_monster.gd` 149·216·341·367행 |
| MEDIUM | `test_wave_combat:173` 의 `or current_wave > 1` 이 "에너지 0" 전제를 잃게 한다 | `tests/test_wave_combat.gd:173` |
| MEDIUM | 이어하기 시 에너지 미회복 + Wave 전체 재스폰 = 플레이어 손해 | `wave_controller.gd:_ready`, `RunState` 저장 범위 |
| MEDIUM | `monster_capacity` 업그레이드가 무효인 채 상점에 노출 | 상점 / `MetaState.get_monster_capacity()` |
| LOW (P2) | 실제 GLB(가로 2.54m) 교체 시 `reach_radius 0.9` 가 모델 안쪽이 된다 | `scenes/objective/sentence_core.tscn` |
| LOW | `wave_controller.gd:59` 불필요한 `await` 경고 (P2 가 채우면 해소) | `scripts/wave/wave_controller.gd:59` |
| LOW | `qa_f5_*` 가 더 이상 "목적지 있는 상태"의 클램프를 재지 않는다 | `tests/qa_f5_*.gd` |

---

## 4. 임시 변경 원복

**프로덕션 코드·씬·리소스는 한 줄도 수정하지 않았다.** `git status` 기준으로 QA 가 추가한
것은 `tests/` 아래 신규 파일뿐이며, 원복할 임시 변경은 없다.

새로 추가한 하네스 (증거 자산이므로 남겨 둔다):

| 파일 | 목적 |
|---|---|
| `tests/qa_p1_play.gd` / `.tscn` | 창 모드 Wave 1~5 실플레이, Wave 별 스크린샷, 20마리 FPS 측정, 아레나 이탈 측정 |
| `tests/qa_p1_negctl.gd` / `.tscn` | `test_wave_combat` DoT 주장의 negative control (control/treated 2 arm) |
| `tests/qa_p1_stall.gd` / `.tscn` | 0절 CRITICAL 결함의 결정론적 재현 + 상태 덤프 |

산출물: `tests/qa_artifacts/p1/play/*.png` (9장), `tests/qa_artifacts/p1/stall_repro.log`.
