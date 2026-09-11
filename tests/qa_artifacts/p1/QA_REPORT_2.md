# JAMO P1 재검증 (P1-QA-2) — QA 리포트 2

**판정: PASS**

근거: 직전 CRITICAL(클릭 1회로 몬스터 영구 정지 → Wave 영구 미클리어 → RUN 잠김)이
해소됐다. 직전 재현 하네스가 통과하고, QA 가 새로 만든 **더 공격적인 잠금 유발 하네스**
(비치명 클릭 96회, 그중 **TURN 에 52회**)에서도 Wave 1~8 이 전부 스스로 Clear 됐다.
MEDIUM 3건도 모두 처리됐고 negative control 로 단언이 살아 있음을 확인했다.
P1 완료 기준 "Wave 1~5 를 잠김 없이 실제로 플레이할 수 있다" 를 창 모드 실플레이와
에디터 라이브 플레이 양쪽에서 확인했다.

- 검증 환경: Godot 4.7.stable, Windows 11, Intel UHD Graphics 770, Vulkan 1.4.323
- 헤드리스만으로 판정하지 않았다. 창 모드 하네스 9종 + ziva-godot 로 띄운 **에디터
  라이브 플레이 3회**(실제 마우스 이벤트 38 / 14 / 1회)로 교차 확인했다.
- **프로덕션 코드 최종 상태: DEV 가 남긴 그대로다.** mutation 실험을 위해
  `scripts/monsters/jamo_monster.gd` 를 2회 임시 변경했고 **둘 다 백업본으로 원복**했다
  (7절). QA 가 추가한 것은 `tests/` 아래 신규 파일뿐이다.

---

## 0. 요약표

| 구분 | 항목 | 결과 |
|---|---|---|
| **A** | CRITICAL 상태 기계 잠금 해소 | **PASS** |
| **B** | MEDIUM 1 — `test_wave_combat:173` 단언 강화 | **PASS** |
| **C** | MEDIUM 2 — 이어하기 정책 | **PASS** (DEV 판단 타당, C-9 의견) |
| **D** | MEDIUM 3 — 무효 업그레이드 숨김 | **PASS** |
| **E** | P1 본체 회귀 | **PASS** |
| **F** | 전체 회귀 / 자동 테스트 / 창 모드 하네스 | **PASS** |

신규 결함: **CRITICAL 0 / HIGH 0 / MEDIUM 0 / LOW 1**(6절).

---

## A. CRITICAL — 상태 기계 잠금 (최우선)

### A-1. `qa_p1_stall.tscn` 통과 — PASS

직전 FAIL 로그(`stall_repro.log`)와 이번 실행을 나란히 둔다.

```
[직전 = 결함 상태]
    before: state=3 pos=(-2.46, 0.71) hp=3
    after 600 frames: state=3 anim=idle moved=0.1755 m alive=true
  FROZEN - the clicked monster never moved again.
STALL - Wave 5 never cleared in 6000 frames.                      exit 1

[이번 = 수정 후]
    before: state=3 pos=(-3.11, -0.10) hp=3
    after 600 frames: state=2 anim=walk_light_step moved=3.0234 m alive=false
    the clicked monster kept walking.
OK - Wave 5 cleared on its own after 0 frames.                    exit 0
```

`state=3`(TURN)에 갇혀 0.17 m 만 밀리던 개체가 이제 `state=2`(WALK)로 빠져나와 3.02 m 를
걷고 문장핵에 도달해 사라진다(`alive=false`). **해소 확인.**

> **INFO (하네스 품질, 결함 아님):** 마지막 줄이 `cleared on its own after 0 frames` 다.
> 재현 단계(최대 2600프레임, `time_scale 4`)가 도는 사이 Wave 5 가 이미 Clear 돼
> 측정 루프가 0프레임 만에 끝났다는 뜻이라, **이 하네스의 후반부(STALL 감시)는 지금
> 공회전한다.** 전반부 FROZEN 판정은 살아 있다(A-4 mutation 이 증명). 후반부를 다시
> 의미 있게 만들려면 재현 단계 전에 Wave 를 고정하거나, Clear 감시 대상 Wave 를
> `RunState.current_wave` 로 잡아야 한다. P2 하네스 정비 항목으로 남긴다.

### A-2. QA 직접 잠금 유발 — PASS (신규 하네스)

DEV 는 비치명 클릭 18회로 잠김 0 이라고 보고했다. 더 공격적으로 다시 했다.

신규 `tests/qa_p1_lockhunt.tscn`. 실제 `main.tscn` 에서 **WaveController 가 직접 Wave 를
몰게 두고**(테스트가 `begin_wave` 를 부르지 않는다), 몬스터가 SPAWN / IDLE / TURN 에
**진입할 때마다** 비치명 클릭을 넣고, **다음 프레임에 한 번 더**(hit 반응 안쪽에 떨어지게)
넣는다. HP 1 남은 개체는 절대 클릭하지 않는다 — 클릭이 Wave 를 해소하는 수단이 될 수
없게 만들어, **Wave 는 오직 몬스터가 스스로 걸어 문장핵에 닿아야만 Clear 된다.**

2~3 HP 짜리가 평생 감당하는 비치명 클릭은 1~2회뿐이고 모든 개체가 SPAWN 을 먼저
지나므로, 클릭을 도착 순서대로 쓰면 정작 버그가 살던 TURN 에 거의 닿지 않는다.
그래서 개체마다 **어느 상태에서 클릭을 쓸지 미리 배정**해 세 상태를 고루 덮었다.

```
-- overlap: clicks colliding with a DoT death, a death animation, an arrival
    a monster clicked on all 157 frames of its walk still left the field (3.94 m)
-- hammer: a non-lethal click on every SPAWN / IDLE / TURN entry, up to Wave 8
    Wave 1 cleared after 157 frames, 0 alive at the clear
    Wave 2 cleared after 508 frames, 0 alive at the clear
    Wave 3 cleared after 471 frames, 0 alive at the clear
    Wave 4 cleared after 437 frames, 0 alive at the clear
    Wave 5 cleared after 556 frames, 0 alive at the clear
    Wave 6 cleared after 493 frames, 0 alive at the clear
    Wave 7 cleared after 463 frames, 0 alive at the clear
    Wave 8 cleared after 553 frames, 0 alive at the clear
    non-lethal clicks by state: { "SPAWN": 24, "IDLE": 20, "TURN": 52 } (total 96)
OK - no click in any state parked a monster; every wave cleared itself.        exit 0
```

**비치명 클릭 96회 (DEV 18회의 5.3배), 그중 TURN 52회.** Wave 1~8 전부 스스로 Clear 됐고,
`wave_cleared` 가 뜬 순간 필드 생존자는 매번 0 이었다. `SpawnManager` stall 경고 0건.

### A-3. 다른 상태도 잠기지 않는지 — PASS

같은 하네스 overlap arm + `test_monster_state` treated arm 이 덮는다.

| 상황 | 결과 |
|---|---|
| SPAWN 중 클릭 | `_begin_spawn: left after 17 frames, moved 0.57 m, alive=true` |
| IDLE 중 클릭 | `_begin_idle: left after 10 frames, moved 0.60 m, alive=true` |
| TURN 중 클릭 | `_begin_turn: left after 12 frames, moved 0.55 m, alive=true` |
| WALK 중 클릭 | `_begin_walk: moved 0.58 m, alive=true` |
| hit 반응 안쪽에 2번째 클릭 | 위 4종 전부 4프레임 뒤 추가 클릭 포함 |
| **상태이상(화상) 사망과 클릭이 겹침** | 매 프레임 클릭을 넣어도 화상 틱이 정상 처치 |
| **death 애니메이션 중 클릭** | `take_click_damage` 가 `false` 반환, 되살아나지 않음 |
| **문장핵 도달과 클릭이 겹침** | 157프레임 내내 클릭당하며 3.94 m 걸어 정상 소멸 |
| 도달 반경 근처 전원 클릭 | hammer arm 이 매 프레임 `reach_radius + 0.3` 안쪽을 클릭 |

코드 경로로도 확인했다. `_physics_process` 의 `match _state` 는 이제 SPAWN / IDLE / WALK /
TURN 네 분기를 모두 갖고, 시간이 정해진 세 상태는 `_state_timer` 가 끝낸다
(`jamo_monster.gd:154~176`). `_on_animation_finished` 는 상태를 바꾸지 않는다
(`:377~388`). DEAD 는 `is_alive()` 가드로 `hit`/status 가 death 를 덮을 수 없고,
설령 death 가 끝나지 않아도 `died` 는 이미 발신돼 `_alive` 에서 빠지므로 Wave Clear 를
막지 못한다.

### A-4. negative control — PASS (QA 가 직접 재현)

**Mutation A.** `jamo_monster.gd:161-162` 의 `State.TURN: _process_hold(delta, _begin_walk)`
두 줄을 삭제하고 (= P1 결함 형태 복원) 세 하네스를 돌렸다.

```
test_monster_state  →  FAIL 6건, exit 1
      _begin_turn: left after -1 frames, moved 0.03 m, alive=true
      FAIL: _begin_turn: the monster left the state it was clicked in
      FAIL: Wave 5 cleared ... (waited 6000 frames, 6 still alive)
      survivor i / fast_ieung / ieung / siot / giyeok / fast_ieung  state=TURN

qa_p1_stall         →  FROZEN + STALL, exit 1
      STALL - Wave 5 never cleared in 6000 frames.

qa_p1_lockhunt      →  FAIL 2건, exit 1  (QA 신규 하네스도 이 버그를 잡는다)
      FAIL: the run reached Wave Clear 8 ... (24000 frames, 3 alive)
      survivor siot / digeut / giyeok  state=TURN
```

복원 후 셋 다 exit 0. **DEV 의 주장 그대로 재현됐고, `test_monster_state` 는 동어반복이
아니다.** control arm 도 실제로 살아 있다 — TURN 타이머를 `INF` 로 고정한 개체를 프로브가
`pinned TURN: left after -1 frames, moved 0.07 m` 로 **frozen 판정**해야만 통과한다.

### A-5. stall watchdog 이 경고 전용인지 — PASS

- `stall_warning_seconds` 는 `@export_range(0.0, 120.0, 1.0)`, `@export_group("Diagnostics")`
  아래에 있어 **Inspector 에 노출된다**(`spawn_manager.gd:56~62`). 어떤 씬도 이 값을
  덮어쓰지 않아 기본 30초가 그대로 쓰인다(`grep stall_warning_seconds scenes/*/*.tscn` 0건).
- Mutation A 실행 중 실제로 발화했다:
  ```
  WARNING: SpawnManager: wave 1 finished spawning 30s ago and 3 enemy(ies) never resolved:
           siot state=TURN hp=1 pos=(2.67, -0.34), digeut state=TURN hp=1 ...
  ```
- **경고 후에도 그 3마리는 계속 TURN 에 박혀 있었고 Wave 는 끝내 Clear 되지 않았다.**
  즉 자동 복구를 하지 않는다 = 게임 동작을 바꾸지 않는다. `_watch_for_stall` 은
  `_stall_reported` 로 1회만 찍고 끝난다. 정상 상태의 모든 실행(하네스 9종 + 라이브 3회)에서
  이 경고 0건.

### A-6. 보행 성격 6종 — PASS (신규 하네스 + 캡처)

`resources/motion_profiles/*.tres`, `resources/animations/`, `scenes/monsters/` 는
`git status` 상 **이번 사이클에 한 글자도 바뀌지 않았다.** 다만 "파일이 안 바뀌었다" 는
"플레이어에게 닿는 값이 안 바뀌었다" 와 다르므로, 신규 `tests/qa_p1_gait.tscn` 으로
실제 게임 월드에서 **눈에 보이는 값을 직접 쟀다**. 프로필 6종을 각각 대표하는 자모 6마리를
문장핵을 향해 걷게 하고 900프레임 측정했다.

```
    jamo         profile      walk animation    scale      m/s    bob m  idles  turns
    digeut       heavy_step   walk_heavy_step    0.75     0.95    0.036      1      1
    mieum        bounce       walk_bounce        0.90     0.89    0.062      1      1
    ieung        roll         walk_roll          1.10     1.42    0.018      1      1
    siot         light_step   walk_light_step    1.50     1.55    0.014      1      1
    giyeok       sway         walk_sway          1.00     1.19    0.030      1      1
    i            upright      walk_upright       1.60     1.49    0.016      1      1
    6 distinct walk animations, speed spread 0.65 m/s, bob spread 0.048 m
OK - the six gaits are still six different gaits.                              exit 0
```

- **서로 다른 walk 애니메이션 6종**이 각기 다른 `speed_scale` 로 재생된다.
- 실측 속도가 설계대로 갈린다: ㄷ 무겁게(0.95) / ㅁ 튀며 느리게(0.89) / ㅇ 굴러가며
  빠르게(1.42) / ㅅ 잰걸음 최속(1.55) / ㄱ 흔들대며 중간(1.19) / ㅣ 꼿꼿하게 빠르게(1.49).
- **수직 bob 진폭**이 살아 있고 서로 다르다 — ㅁ 이 0.062 m 로 가장 크게 튀고 ㅅ 이
  0.014 m 로 가장 밋밋하다. 상태 기계가 걸음을 뭉갰다면 여기가 0 이 되거나 균일해진다.
- **걷다 서서 방향 잡는 리듬**도 남아 있다(모든 개체 idle 1회 + turn 1회 관측, 이후
  문장핵 도달로 퇴장).

비교 캡처: `tests/qa_artifacts/p1/gait/00_walk.png` ~ `04_walk.png` (5장, 220프레임 간격).
6마리가 각기 다른 자세로 문장핵을 향해 수렴하는 장면이 담긴다.

---

## B. MEDIUM 1 — `test_wave_combat` DoT 단언 — PASS

`or RunState.current_wave > 1` 이 삭제됐고, 화상 직전에 에너지를 다시 0 으로 만든 뒤
`current_energy == 0` 을 단언한다. 처치 **후에도** 0 인지, 그리고 그 사이 Wave 가 넘어가지
않았는지(`current_wave == wave_at_burn`)까지 추가로 단언한다.

**일부러 깨뜨렸을 때 FAIL 하는지 재현했다 (Mutation B).** 화상 적용 직전에
`RunState.current_energy = RunState.get_max_energy()` 한 줄을 끼워 넣었다.

```
-- energy 0 keeps the wave going, DoT still pays
  FAIL: the energy is 0 at the moment the burn lands
  FAIL: the energy is still 0 after the DoT kill, got 10
FAILED - 2 check(s) failed.                                                    exit 1
```

DEV 가 보고한 2건과 정확히 일치한다. 원복 후 exit 0. 구 단언은 `or current_wave > 1` 이
있어 **Wave Clear 로 에너지가 10 으로 회복된 상황을 그대로 통과시켰고**, 그 `or` 절이
참이 되는 시점이 바로 에너지가 회복되는 시점이라 전제를 조용히 잃는 구조였다. 해소됐다.

---

## C. MEDIUM 2 — 이어하기 정책 — PASS

신규 `tests/qa_p1_resume_econ.tscn` 으로 판정했다.

### C-8. 남은 적만 재스폰 — PASS

씬을 완전히 떠났다가 `SaveManager.load_run()` + 새 `main.tscn` 으로 돌아오는,
허브의 `RUN 이어하기` 와 같은 경로로 확인했다.

```
-- resume: a suspended wave brings back only what it still owed
    Wave 1: 3 of 5 resolved before the suspend, 2 spawned after it, energy 7
```

5마리 중 3마리 처리 후 중단 → 재개하면 **정확히 2마리만** 나온다. 에너지는 저장값 7 그대로.
세이브의 `run` 블록에 `"wave_resolved_count": 3` 이 있고 `meta` 에는 없다(둘 다 단언).

### C-9. 골드 파밍 우려 검증 — **DEV 의 판단이 타당하다 (수치로 확인)**

같은 Wave 1 을 상대로 **중단/재개를 5회 반복**하며, 채택안과 기각안을 각각 돌렸다.
기각안은 프로덕션을 고치지 않고 테스트 쪽에서 재현했다(재개 시
`wave_resolved_count = 0` + 에너지 최대 회복). Wave 가 Clear 되지 않도록 라운드당
`enemy_count - 1` 마리만 잡아 두 정책을 같은 Wave 1 위에서 비교했다.

```
    shipped policy  : Wave 1 paid  5 kills / 10.00 gold from  5 spawns (wave owes 5),
                      2 of 5 rounds before it had to move on, energy 10
    rejected policy : Wave 1 paid 20 kills / 40.00 gold from 25 spawns (wave owes 5),
                      5 of 5 rounds still on Wave 1, energy 10
```

- **기각안은 실제로 무한 채굴이 된다.** Wave 1 이 5마리짜리인데 25마리가 스폰됐고,
  골드가 4배 나왔으며, **5라운드 내내 Wave 1 을 벗어나지 않았다.** 라운드를 늘리면
  그대로 비례해서 늘어난다 — 난이도는 그대로인데 골드만 무한. §14(획득 즉시 `MetaState`
  적립)와 맞물려 영구 업그레이드를 공짜로 사는 경로가 열린다. **DEV 의 기각 사유는 타당하다.**
- **채택안에서는 파밍이 불가능하다.** Wave 1 이 스폰한 총량은 정확히 5마리, 지급 골드는
  5처치분이 상한이고, 더 벌려면 다음 Wave 로 나아가야 한다(= 난이도를 감수해야 한다).
  재개가 에너지를 되돌려 주지도 않는다.

**두 질문에 대한 QA 판정:**

1. **에너지를 회복시키면 악용 가능한가 — 그렇다.** 위 실측대로다. 단, **에너지 회복
   단독이 문제의 핵심은 아니다.** 진짜 구멍은 "진행도를 잊는 것"이다. 진행도를 저장한
   채 에너지만 회복시키면 몬스터를 더 만들어 내지는 못하지만, **에너지가 무한 공급**되어
   (중단 → 재개 → 에너지 10) 사실상 모든 Wave 를 전멸시킬 수 있게 된다. 이것도 악용이다.
   따라서 DEV 가 두 조합을 모두 기각한 것이 맞다.
2. **지금 정책이 사용자에게 부당한 손해인가 — 아니다.** 직전 QA 가 지적한 손해
   ("에너지 7로 Wave 전체를 다시 받는다")가 정확히 해소됐다. 남은 에너지가 상대하는
   물량이 남은 적 수에 비례해 줄어들므로 **에너지와 남은 물량의 비율이 보존된다.**
   중단이 이득도 손해도 아닌 상태에 가깝다.

**남은 잔여 손해/이득 (둘 다 LOW, P1 허용):**

- *손해*: 중단 시점에 살아 있던 개체는 스폰 지점에서 **풀 HP** 로 다시 나오므로 그
  개체에 넣은 부분 피해가 사라진다. Wave 5 기준 최악의 경우 개체당 2피해(= 클릭 2회)다.
- *이득*: 문장핵에 거의 닿은 개체를 중단으로 **스폰 지점까지 되돌릴 수 있다.** 문장핵
  피해를 면하고 그 개체를 잡아 골드로 바꿀 여지가 생긴다. 다만 재개가 에너지를 주지
  않으므로 **남은 에너지가 상한**이라 반복 착취는 불가능하다.
- 둘 다 "개체별 HP/위치까지 저장" 하면 사라진다. §44 의 "임시 저장" 범위를 넘는다는
  DEV 판단에 동의한다. P2~P4 에서 개체 상태 저장을 다룰 때 함께 정리하면 된다.

### C-10. 패배 후 이어하기 불가 — PASS

```
-- defeat: a lost run leaves nothing to resume
```
문장핵을 0 으로 만든 뒤 `RunState.is_active == false`, `SaveManager.has_run_save() == false`,
`SaveManager.load_run() == false` 세 가지를 모두 단언해 통과. `main.gd:79` 가
`SaveManager.clear_run()` 을 부른다. `qa_p0_flow` 8단계("lose the resumed run: it must not
be resumable again")도 통과했고, 세이브 파일이
`top=["audio","meta","save_version"] run_present=false` 로 남는 것을 확인했다.

---

## D. MEDIUM 3 — 무효 업그레이드 숨김 — PASS

### D-11. 상점에서 안 보이고 트랙은 남아 있는지 — PASS

**에디터 라이브로 상점을 열어 눈으로 확인했다** (ziva-godot `run_scene`,
`title_screen.tscn` → `영구 업그레이드` 클릭). 행은 정확히 5개다:

```
최대 에너지 Lv.0   10 → 11      6 G   [구매]
클릭 피해   Lv.0    1 → 2      12 G   [구매]
치명 클릭   Lv.0   잠김   클릭 피해 Lv.3 필요   [잠김]
골드 획득량 Lv.0   0% → 5%    12 G   [구매]
리롤       Lv.0   0 회 → 1 회  보유 16 G / 필요 125 G  [구매]
```

`동시 몬스터 수` 행이 **없다.** 동시에 트랙은 살아 있다:
`game_database.tres` 의 `upgrades` 배열에 여전히 6개가 등록돼 있고
(`ExtResource("10_capacity")` 포함), `monster_capacity.tres` 의
`costs = PackedInt64Array(25, 60, 150, 375, 940, 2250)` /
`values = PackedFloat32Array(10, 12, 14, 16, 18, 20)` 이 그대로다. `is_retired = true`
한 줄만 추가됐다. 삭제가 아니라 숨김이 맞다.

자동 단언(`qa_p1_resume_econ`):
```
    5 of 6 tracks listed
```
- `UpgradeManager.is_visible(monster_capacity) == false`
- `UpgradeManager.purchase(monster_capacity) == false` (골드 100000 을 쥐어 주고 시도) —
  숨기기만 하고 구매 경로는 열어 두는 사고를 막았다. 거절 후 레벨도 0 그대로.
- 구현은 `upgrade_row.gd:27` 한 곳(`visible = UpgradeManager.is_visible(upgrade)`)이라
  숨김 경로가 분산돼 있지 않다.

### D-12. `is_retired` 가 다른 업그레이드에 영향을 주는지 — PASS

데이터베이스의 6개 트랙을 전부 돌며 **"보이는 트랙은 retired 가 아니고, 안 보이는 트랙은
retired 라서다"** 를 양방향으로 단언했다. 숨겨진 트랙은 정확히 1개다.
`is_retired` 는 `@export var ... = false` 기본값이라 나머지 5개 `.tres` 는 손대지 않아도
그대로 노출된다. `is_visible()` 이전 동작(`upgrade != null`)에서 바뀐 것은 retired 판정
한 항뿐이고, 잠금 표시(`Availability.LOCKED`)는 예전처럼 행을 숨기지 않고 사유를 적는다
— 라이브 상점의 `치명 클릭 ... 클릭 피해 Lv.3 필요 [잠김]` 행이 그 증거다.

### D-13. 기존 세이브에 레벨이 있던 경우 — PASS

```
    a save with monster_capacity level 3 loads and keeps it
```
`monster_capacity = 3`, `max_energy = 2` 를 적은 세이브를 쓰고 `MetaState.reset()` 후
`load_game()` 했다. 크래시·에러 0, `get_upgrade_level("monster_capacity") == 3` 유지,
옆 트랙 `max_energy == 2` 무영향, `get_monster_capacity()` 도 정상 응답.
플레이어가 이미 산 레벨은 **사라지지 않고 세이브에 남는다.**

---

## E. P1 본체 재검증 (회귀) — PASS

창 모드 실플레이 `qa_p1_play`(실제 마우스 이벤트) 결과:

```
    wave | count | hp | energy | clicks | kills | core lost | core left | cleared
       1 |     5 |  1 |     10 |      5 |     5 |         0 |        20 | true
       2 |     7 |  1 |     10 |      7 |     7 |         0 |        20 | true
       3 |     8 |  2 |     10 |     10 |     5 |         3 |        17 | true
       4 |     9 |  2 |     10 |     10 |     5 |         4 |        13 | true
       5 |    10 |  3 |     10 |     10 |     3 |         8 |         5 | true
       6 |    10 |  3 |     10 |     10 |     3 |         5 |         0 | false
    clicks landed by state: { "IDLE": 10, "SPAWN": 41, "TURN": 1 }
    non-lethal clicks by state: { "IDLE": 5, "SPAWN": 19 }
OK - Wave 1~5 play through, the core is the only failure.                      exit 0
```

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 14 | 에너지 0 이어도 Wave 계속, 결과 화면 안 뜸 | **PASS** | Wave 3·4·5 에서 클릭 10 = 에너지 소진 후에도 Clear 까지 진행. `play/30_wave3_energy_zero_wave_continues.png`. `test_wave_combat` 의 `-- energy 0 keeps the wave going` 블록 FAIL 0 |
| 15 | 문장핵 0 이 유일한 실패, 부제 문구 | **PASS** | Wave 6 에서 `core left 0` 일 때만 `cleared false`. `subtitle: 문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다.` |
| 16 | 실패해도 RUN Gold 가 MetaState 에 남음 | **PASS** | `result: 도달 WAVE 6 / 처치 28 / 획득 GOLD 74 G (유지됨)` · `banked gold after the defeat: 74.30, highest wave 6` |
| 17 | Wave 곡선 설계 의도 | **PASS** | W1~2 전멸·누수 0 / W3 부터 누수 발생 / W5 생존(문장핵 5) / W6 실패. §53 루프 성립 |
| 18 | Day 곡선 잔재 없음 | **PASS** | `current_day` / `hp_growth_per_wave` / `gold_growth_per_wave` / `end_run_when_energy_depleted` → 활성 코드·데이터 **0건**(`_deferred_v03` 제외) |
| 19 | HUD 배치, 20마리 60 FPS | **PASS** | `20 alive: avg 60.0 FPS, min 60.0, low 1 pct 60.0` · `monsters outside their walkable diamond: 0` · 라이브 스크린샷의 좌상 WAVE·상중 문장핵·하중 ENERGY·우상 GOLD |
| 20 | 문장핵 `VisualRoot` 교체 지점 유지 | **PASS** | `sentence_core.tscn:52 visual_root = NodePath("VisualRoot")`, 하위는 `Pillar`/`Cap` 프리미티브 둘뿐, hit 애니메이션은 `VisualRoot:scale` / `VisualRoot:position` 만 키한다. 교체 구조 그대로 |

**에디터 라이브 플레이(ziva-godot)로 교차 확인:** 실제 마우스 클릭 38회를 25초간 넣어
`WAVE 3 / 문장핵 13 / 20 / 27 G / 처치 5 / ENERGY 10 / 10` 까지 진행했다. Wave 1·2 가
스스로 Clear 돼 에너지가 매번 10 으로 회복됐고, 화면에 멈춰 선 개체는 없었으며
stall 경고도 없었다.

---

## F. 전체 회귀 — PASS

### F-21 / F-24. 창 모드 하네스 (7종 + P1 2종) — 전부 exit 0

| 하네스 | 결과 |
|---|---|
| `qa_p0_flow` | exit 0. 허브→RUN→결과→허브, 이어하기 규칙, v0.3 마이그레이션, 안내문 대비 **12.44:1**, 상점 DAY 문구 0 |
| `qa_p0_plates_all` | exit 0. `OK - one bright plate across all 7 hub plates, 178 pointer/keyboard frames at 4 sizes x 2 save states, focus released -> 0 lit in 8/8` |
| `qa_f7_title` | exit 0. 진입 포커스·키보드 순회 정상 |
| `qa_f7_art` | exit 0. `WARN: 1 edge sample(s) look like letterbox at save_1920x720` — 기존 항목, P1 결함 아님 |
| `qa_f8_labels` | exit 0 |
| `qa_f8_focus_all` | exit 0. `OK - focus indicator meets 3.0:1 and the dialog fits its contents.` |
| `qa_f8_resize` | exit 0 |
| `qa_p1_play` | exit 0 (E절) |
| `qa_p1_gait` | exit 0 (A-6) |

아레나 클램프는 `qa_p1_play` 의 20마리 동시 실측(이탈 0)으로 확인했다.
State 분리는 `test_state_split` 의 `MetaState 10 state fields, RunState 17` + 겹침 0.

### F-22. `godot --headless --path . --quit` — PASS

```
ERROR: Resource file not found: res://art/fonts/NotoSansKR-Regular.ttf
ERROR: Error loading custom project font 'res://art/fonts/NotoSansKR-Regular.ttf'
EXIT=0
```
폰트 누락 2줄 외 에러 0.

### F-23. 헤드리스 테스트 — 전부 exit 0

| 테스트 | 마지막 줄 |
|---|---|
| `test_state_split` | `OK - meta/run split holds.` (MetaState 10 / RunState 17) |
| `test_run_flow` | `OK - Wave 1 started, the core fell, and the hub came back.` |
| `test_wave_combat` | `OK - waves run on data, energy 0 ends nothing, the core is the only failure.` + `Wave 2 resumed with 1 / 7 enemies already resolved, energy 10` |
| `test_monster_state` | `OK - no state parks a clicked monster, and the probe can tell a parked one.` |
| `qa_p1_stall` | `OK - Wave 5 cleared on its own` |
| `qa_p1_negctl` | `OK - the DoT-at-energy-0 claim survives its negative control.` |
| `qa_p1_lockhunt` (신규) | `OK - no click in any state parked a monster; every wave cleared itself.` |
| `qa_p1_resume_econ` (신규) | `OK - resume returns only what the wave owed, the farm is closed, ...` |

**주의:** 전부 한 번에 하나씩 돌렸다. DEV 지적대로 모든 하네스가 같은
`user://jamo_save.json` 을 공유하므로 병행 실행은 레이스를 낸다. 09-10 자 헤드리스
godot 프로세스 3개(PID 40896 / 47052 / 53240)는 **건드리지 않았다.**

---

## 6. 결함 요약 (신규)

| 심각도 | 항목 | 위치 |
|---|---|---|
| LOW (신규) | `Values of the ternary operator are not mutually compatible` — 에디터 경고. `monster.monster_data.id`(StringName) 와 `"?"`(String) 를 같은 삼항에 둔다. 경고일 뿐 동작에 영향 없고 헤드리스 import 에는 안 나온다. `"?"` 를 `&"?"` 로 두거나 `String(...)` 로 감싸면 해소 | `scripts/monsters/spawn_manager.gd:358` |
| LOW (기존) | `"await" keyword is unnecessary` — P2 가 `_between_waves()` 를 채우면 해소 | `scripts/wave/wave_controller.gd:60` |
| LOW (기존) | NotoSansKR 폰트 누락 2줄 | `project.godot` `gui/theme/custom_font` |
| LOW (기존) | `qa_f7_art` letterbox WARN (샘플링 경고, exit 0) | `tests/qa_f7_art.gd` |
| INFO | `qa_p1_stall` 후반 STALL 감시가 공회전한다(A-1). 전반 FROZEN 판정은 유효 | `tests/qa_p1_stall.gd` |
| INFO | 실제 마우스 클릭은 TURN 에 거의 닿지 않는다(`qa_p1_play` 41 SPAWN / 10 IDLE / 1 TURN). TURN 커버리지는 `qa_p1_lockhunt`(52회)·`test_monster_state`·`qa_p1_stall` 가 `take_click_damage()` 직접 호출로 메운다 — 실제 클릭이 최종적으로 도달하는 함수와 같은 경로다 | — |

직전 리포트의 LOW 3건(GLB 교체 시 `reach_radius`, `qa_f5_*` 의 목적지 있는 클램프 미측정,
§5.1 Wave 5 중간보스 이관)은 이번 범위 밖이며 그대로 남아 있다.

---

## 7. 임시 변경 원복

**프로덕션 코드는 DEV 가 남긴 상태 그대로다.** mutation 검증을 위해 아래 2건을 임시로
바꿨고, 둘 다 백업본에서 복원했다.

| 임시 변경 | 목적 | 원복 |
|---|---|---|
| `scripts/monsters/jamo_monster.gd` — `_physics_process` 의 `State.TURN` 분기 2줄 삭제 (2회 적용) | Mutation A: 하네스 3종이 P1 결함을 실제로 잡는지 | **원복 완료.** 사전 백업본으로 복사 복원, `git diff --stat` = `145 +++--` (DEV 원본과 동일), `grep State.TURN:` → `161:` 존재 |
| `tests/test_wave_combat.gd` — 화상 직전 에너지 최대 회복 1줄 삽입 | Mutation B: 강화된 단언이 살아 있는지 | **원복 완료.** `grep -c "MUTATION B"` → 0 |

> `git checkout --` 은 쓰지 않았다. 두 파일 모두 커밋되지 않은 DEV 변경을 담고 있어
> HEAD 로 되돌리면 수정본이 통째로 날아간다. 변경 전에 뜬 백업본으로만 복원했다.

QA 가 추가한 신규 하네스 (증거 자산이므로 남겨 둔다):

| 파일 | 목적 |
|---|---|
| `tests/qa_p1_lockhunt.gd` / `.tscn` | 잠금 유발 하네스. 상태 진입마다 비치명 클릭 + hit 안쪽 2타, DoT 사망·death 애니·문장핵 도달과의 충돌, Wave 1~8 자력 Clear 단언 |
| `tests/qa_p1_resume_econ.gd` / `.tscn` | 이어하기 재스폰 수, 채택안 vs 기각안 골드 파밍 비교, 패배 후 이어하기 차단, retired 트랙 숨김/구매거부/구세이브 호환 |
| `tests/qa_p1_gait.gd` / `.tscn` | 보행 성격 6종 실측(애니메이션·speed_scale·실속도·bob 진폭·idle/turn 리듬) + 비교 캡처 5장 |

기존 자산(`qa_p1_play` / `qa_p1_negctl` / `qa_p1_stall`)은 직전 사이클 QA 산출물이다.

산출물: `tests/qa_artifacts/p1/play/*.png` (9장, 갱신됨),
`tests/qa_artifacts/p1/gait/*.png` (5장, 신규), `tests/qa_artifacts/p1/stall_repro.log`
(직전 결함 로그, 비교용으로 보존).
