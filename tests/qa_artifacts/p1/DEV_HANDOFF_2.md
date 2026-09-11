# JAMO P1-DEV-2 (QA FAIL 수정) — DEV 완료 보고

QA 리포트 `QA_REPORT.md` 의 CRITICAL 1 + MEDIUM 3 을 전부 처리했다.
검증 환경: Godot 4.7.stable, Windows 11. 프로덕션 코드 변경은 아래 1) 의 8개 파일뿐이다.

---

## 1) 변경 파일 목록

### 프로덕션 (CRITICAL)
```
scripts/monsters/jamo_monster.gd   상태 전이 소유권을 _state_timer 로 통일. SPAWN/TURN 이
                                   _physics_process 에서 애니메이션 길이만큼 대기 후 스스로
                                   진행. _on_animation_finished 는 hit 복귀·death 정리만 담당.
                                   _begin_spawn() / _process_hold() / _animation_length() /
                                   get_state() 신규
scripts/monsters/spawn_manager.gd  (안전망) Diagnostics/stall_warning_seconds (기본 30초):
                                   스폰 완료 후 생존자가 정리되지 않으면 push_warning 으로
                                   생존자 상태 나열. 복구는 하지 않음.
                                   (MEDIUM 2) configure_wave(wave, already_resolved) —
                                   처리된 수만큼 건너뛰고 스폰. _on_monster_died 가
                                   RunState.wave_resolved_count 를 증가
```

### 프로덕션 (MEDIUM 2 — 이어하기)
```
autoload/run_state.gd              wave_resolved_count 필드 신규 (reset/begin_wave 에서 0,
                                   to_dict/from_dict 저장. 구 세이브는 0 으로 읽어 하위 호환)
autoload/meta_state.gd             RUN_OWNED_NAMES 에 wave_resolved_count 추가 (State 분리 선언)
scripts/wave/wave_controller.gd    _launch() 가 configure_wave(data, RunState.wave_resolved_count)
```

### 프로덕션 (MEDIUM 3 — 무효 업그레이드)
```
scripts/data/upgrade_data.gd       @export var is_retired: bool = false 신규 (Inspector 노출)
scripts/upgrades/upgrade_manager.gd is_visible() 가 retired 트랙을 숨김, purchase() 도 거부
resources/upgrades/monster_capacity.tres  is_retired = true (트랙·값·가격은 그대로, 삭제는 P5)
```

### 테스트
```
tests/test_monster_state.gd / .tscn  신규 헤드리스 테스트 (상태기계 잠김 방지 + negative control)
tests/test_wave_combat.gd            (MEDIUM 1) 173행 `or current_wave > 1` 삭제. 화상 직전
                                     재드레인해 energy==0 을 강하게 단언, 처치 후에도 0 단언.
                                     (MEDIUM 2) 4b 블록 신규: 이어하기 시 남은 몬스터만 스폰
tests/qa_p1_stall.gd                 (QA 하네스, 약화 아님) 걷다 core 도달로 freed 된 몬스터를
                                     역참조하던 137행 가드. FROZEN/STALL 시 exit 1 로 강화
tests/qa_p1_play.gd                  (QA 하네스, 추가만) 클릭이 닿은 몬스터 상태 집계 출력
```

### 문서
```
docs/DEV_ROADMAP.md                  P1 이관 항목 2줄 갱신 (monster_capacity 숨김 / 이어하기 정책)
docs/ORCHESTRATION_RULES.md          §7.1 헤드리스 테스트 4개로, §7.3 P1-DEV-2 QA 유의사항 신설
tests/qa_artifacts/p1/DEV_HANDOFF_2.md  이 보고서
```

---

## 2) 검수 절차

### A. 자동 테스트 (전부 exit 0 이어야 함. **한 번에 하나씩** 돌릴 것 — 3절 11번)

1. `godot --headless --path . --quit`
   → 기대: NotoSansKR 폰트 누락 2줄 외 에러 0.
2. `godot --headless --path . res://tests/qa_p1_stall.tscn` (QA 의 재현 하네스)
   → 기대: exit 0. `after 600 frames: state=2 anim=walk_* moved=3.xx m alive=false` +
     `the clicked monster kept walking.` + `OK - Wave 5 cleared on its own`.
     FROZEN / STALL 이 한 줄이라도 나오면 FAIL (이제 exit 1 로도 잡힌다).
3. `godot --headless --path . res://tests/test_monster_state.tscn` (신규)
   → 기대: exit 0. 세 arm 이 순서대로 보인다.
     - `treated`: `_begin_spawn / _begin_idle / _begin_turn` 이 `left after N frames`
       (N ≥ 0), 네 상태 모두 `moved ≥ 0.50 m`, `alive=true`.
     - `control`: `pinned TURN: left after -1 frames, moved 0.0x m` — 전이 주체를 INF 로
       고정한 몬스터를 프로브가 **frozen 으로 판정**해야 통과. 이것이 negative control.
     - `chaos`: `N clicks landed, 5 of them on a forced SPAWN/TURN` 뒤 `Wave N cleared after M frames`.
     마지막 줄 `OK - no state parks a clicked monster, and the probe can tell a parked one.`
4. `godot --headless --path . res://tests/test_wave_combat.tscn`
   → 기대: exit 0. `-- energy 0 keeps the wave going` 블록에 FAIL 없음,
     신규 `-- a resumed wave spawns only what is left of it` 블록에
     `Wave 2 resumed with 1 / 7 enemies already resolved, energy 10`.
5. `test_state_split` → `MetaState 10 state fields, RunState 17` + `OK - meta/run split holds.`
   `test_run_flow` → `OK - Wave 1 started, the core fell, and the hub came back.`
   `qa_p1_negctl` → `OK - the DoT-at-energy-0 claim survives its negative control.`
6. 창 모드 7종 (`qa_p0_flow` / `qa_p0_plates_all` / `qa_f7_title` / `qa_f7_art` /
   `qa_f8_labels` / `qa_f8_focus_all` / `qa_f8_resize`) → 전부 exit 0, FAIL 0.
   `qa_p0_plates_all` 은 8분 이상 걸린다. `qa_f7_art` 의 letterbox WARN 은 기존 항목.
7. `godot --path . res://tests/qa_p1_play.tscn` (창 모드, Wave 1~5 실플레이)
   → 기대: `OK - Wave 1~5 play through`, wave log 에 1~5 `cleared true`, 6 에서 RUN 실패.
     마지막에 `non-lethal clicks by state: { ..., "SPAWN": N }` 의 N 이 두 자리 — 실제 마우스
     클릭이 SPAWN 중에 죽이지 못한 채 N 번 닿았고 그럼에도 Wave 가 전부 Clear 됐다는 증거.
   → 위 어느 로그에도 `SpawnManager: wave N finished spawning ... never resolved` 경고가
     없어야 한다 (있으면 정지 재발).

### B. 잠금 유발 시도 — 손으로 (ziva-godot 또는 실행)

8. 세이브 삭제 후 `RUN 시작`. Wave 1·2 는 클릭으로 전멸시켜 **Wave 3** 까지 간다 (HP 2).
9. Wave 3 에서 몬스터가 **막 나타나는 순간**(스폰 시 작게 튀어오르는 0.4초) 을 노려 한 번만
   클릭한다. → 기대: `ENERGY 9`, 몬스터는 hit 반응 뒤 그대로 idle → 방향 잡기 → 문장핵으로 걷는다.
10. 걷던 몬스터가 **멈춰서 몸을 기울이는 순간**(turn, 0.35초) 을 노려 한 번만 클릭한다.
    → 기대: hit 반응 뒤 곧바로 걷기 시작. 제자리에 남는 개체 없음.
11. 9~10 을 에너지가 0 이 될 때까지 반복하되 같은 몬스터를 두 번 클릭하지 않는다
    (전부 죽지 않은 클릭이 되게). → 기대: `수동 클릭 불가 — WAVE 는 계속된다` 표시 후
    남은 몬스터 전원이 문장핵에 도달해 사라지고 **`WAVE 3 CLEAR` → `WAVE 4`**.
    (QA 가 걸린 상황: 이 단계에서 1마리가 남아 영원히 서 있었다.)
12. Wave 4·5 에서도 10~11 을 반복한다. → 기대: `WAVE 5` 를 지나 Wave 6 에서 문장핵 0 으로
    결과 화면. 어느 Wave 도 생존자 1 로 멈추지 않는다.
13. 위 어느 시점이든 몬스터를 30초 이상 두고 본다. → 기대: 출력 로그에
    `SpawnManager: wave ...` 경고 없음.

### C. 이어하기 (MEDIUM 2)

14. 새 RUN, Wave 1 에서 5마리 중 **3마리를 잡고**(ENERGY 7) `ESC` → `저장 후 메인 허브로`.
    → 기대: `RUN 이어하기` + `진행 중인 RUN — WAVE 1 · 문장핵 20`.
15. `RUN 이어하기`. → 기대: `WAVE 1`, `ENERGY 7 / 10`, 그리고 **몬스터가 2마리만 더 나온다**
    (5 − 3). 2마리를 잡으면 `WAVE 1 CLEAR` → `WAVE 2` + `ENERGY 10 / 10`.
16. 세이브 파일 `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 의 `run` 블록에
    `"wave_resolved_count": 3` 이 있다. `meta` 에는 없다.
17. Wave 중간에 몬스터 2마리가 살아 있는 상태로 저장 → 이어하기.
    → 기대: 그 2마리는 스폰 지점에서 풀 HP 로 다시 나온다(부분 피해 유실, 3절 7번).
    처치했던 몬스터는 다시 나오지 않는다.

### D. 상점 (MEDIUM 3)

18. Main Hub → `영구 업그레이드`. → 기대: 행이 **5개** (최대 에너지 / 클릭 피해 / 치명타 /
    골드 보너스 / 리롤). `동시 몬스터 수` 행이 없다.
19. `resources/upgrades/monster_capacity.tres` 를 Inspector 로 열면 `Is Retired` 체크가
    켜져 있고 costs/values 는 그대로다. 끄면 행이 다시 나타난다(삭제 아님을 확인).
20. QA 세이브에 `monster_capacity` 레벨이 있어도 로드 에러 없고 그 레벨은 세이브에 남는다.

### E. 보행 성격 회귀

21. 8~12 를 하는 동안 관찰: ㄷ 은 무겁게, ㅁ 은 튀며, ㅇ 은 굴러가고, ㅅ 은 잰걸음.
    걷다 잠깐 서서 방향을 잡는 idle/turn 리듬이 v0.3 그대로.
    → `resources/motion_profiles/*.tres`, `resources/animations/walk_library.tres` 는 이번에
    한 글자도 바뀌지 않았고, 걷기 애니메이션·speed_scale·`_speed` 계산도 손대지 않았다.
    바뀐 것은 SPAWN/TURN 이 "애니메이션 끝 신호" 대신 "애니메이션 길이 타이머" 로 끝난다는
    것뿐이라 체감 타이밍이 같다.

---

## 3) 주의 / 보류 사항

### 상태 기계를 어떻게 바꿨는가 (CRITICAL)

1. **원인**: SPAWN→IDLE, TURN→WALK 전이가 `AnimationPlayer.animation_finished` 하나에 매달려
   있었다. `take_click_damage()` 가 `play("hit")` 로 그 애니메이션을 대체하면 Godot 은 대체된
   애니메이션의 finished 를 내지 않아 전이가 영영 오지 않았고, `_physics_process` 에 TURN/SPAWN
   분기가 없어 제자리에 섰다.
2. **수정 원칙 — 상태 소유권 단일화**: 시간이 정해진 상태(SPAWN / IDLE / TURN)는 전부
   `_state_timer` 가 `_physics_process` 에서 끝낸다. SPAWN·TURN 의 타이머 값은 해당
   애니메이션 길이(`_animation_length()`) 라서 타이밍이 이전과 같다. 애니메이션이 없으면 0 이
   되어 다음 물리 프레임에 바로 진행한다(신호를 기다리다 잠기는 일이 구조적으로 없다).
   `_on_animation_finished` 는 상태를 바꾸지 않는다 — `hit` 이 끝나면 현재 상태의 모습(idle
   또는 걷기)만 되돌리고, `death` 가 끝나면 `queue_free` 한다.
3. **다른 상태 점검 결과**
   - SPAWN: 같은 구멍이었다(QA 지적대로). 위 방식으로 함께 고침. 테스트 treated arm 이 검증.
   - IDLE: 원래 타이머 기반이라 잠기지 않았다. hit 이 idle 을 덮어도 타이머는 돈다.
   - WALK: 물리가 애니메이션과 무관하게 움직인다. hit 후 `_begin_walk()` 로 걷기 애니메이션 복귀.
   - DEAD: `_leave_field()` 이후 `hit`/status 는 `is_alive()` 가드로 막혀 death 를 덮어쓸 경로가
     없다. 만약 death 가 끝나지 않더라도 `died` 는 이미 발신됐고 `_alive` 에서 빠졌으므로
     Wave Clear 를 막지 못한다(잠김 아님, 시각 잔재만). 별도 타이머는 넣지 않았다.
4. **안전망**: `SpawnManager.stall_warning_seconds`(Inspector, 기본 30초). 스폰이 끝난 뒤
   생존자 수가 30초 동안 줄지 않으면 `push_warning` 으로 각 생존자의 id/state/hp/pos 를 남긴다.
   **자동 복구는 넣지 않았다** — 강제 퇴장은 문장핵을 부당하게 깎거나 공짜 처치를 주고, 무엇보다
   버그를 숨긴다. 이번 사이클의 모든 테스트·플레이 로그에 이 경고는 0건이다.
5. **negative control 증거**
   - `test_monster_state` control arm: TURN 타이머를 INF 로 고정한 몬스터를 프로브가 frozen 으로
     판정해야 통과(통과함).
   - Mutation A: `_physics_process` 의 TURN 분기를 지운 상태로 돌리면 `test_monster_state` 가
     5건 FAIL(exit 1), `qa_p1_stall` 이 FROZEN + STALL(exit 1). 복원 후 둘 다 exit 0.
   - Mutation B (MEDIUM 1): 화상 직전에 에너지를 10 으로 채우면 `test_wave_combat` 이
     `the energy is 0 at the moment the burn lands` / `still 0 after the DoT kill, got 10`
     두 건 FAIL(exit 1). 구 단언(`or current_wave > 1`)은 이 상황을 통과시켰다. 복원 후 exit 0.
6. **실플레이의 TURN 클릭**: `qa_p1_play` 는 문장핵에 가장 가까운 개체를 스폰 직후 클릭하므로
   실제 마우스 클릭은 SPAWN(비치명 18회)·IDLE 에 집중되고 TURN 에는 닿지 않았다. TURN 은
   `qa_p1_stall`(QA 재현) 과 `test_monster_state`(treated/control/chaos) 가 `take_click_damage()`
   직접 호출로 덮는다 — 실제 클릭이 도달하는 함수와 같은 경로다. 손 검수 절차 B-10 이 실제 입력으로
   TURN 을 찌른다.

### 이어하기 정책 (MEDIUM 2)

7. **채택: Wave 진행 상태 저장** (`wave_resolved_count`). 에너지는 저장값 그대로.
   - 기각한 대안 "재스폰 + 에너지 최대 회복": 처치 골드가 즉시 `MetaState` 에 적립되는 §14 와
     맞물려 *잡고 → 저장 → 이어하기 → 다시 잡고* 로 골드를 무한 채굴할 수 있다. 에너지만
     회복하고 진행을 저장하는 조합도 에너지 무한 공급이라 기각.
   - 채택안의 잔여 손해: 중단 시점에 살아 있던 개체는 스폰 지점에서 풀 HP 로 다시 나오므로
     그 개체에 넣은 부분 피해만 유실된다(처치·도달·골드는 전부 보존). 개체별 HP/위치까지
     저장하는 것은 §44 "임시 저장" 범위를 넘는다고 판단해 P1 에선 넣지 않았다.
   - 악용 여지: 문장핵 근처의 개체가 스폰 지점으로 되돌아가는 만큼의 시간 이득뿐.
8. 마지막 처치와 Clear 연출(1.4초) 사이에 저장한 세이브는 `resolved == enemy_count` 로 남는다.
   `configure_wave()` 가 그 경우 `field_cleared` 를 deferred 로 발신해 다음 Wave 로 넘긴다.
9. `RUN_OWNED_NAMES` 가 17 로 늘었다. `test_state_split` 은 목록 길이를 하드코딩하지 않아
   자동으로 따라온다. 구 세이브(키 없음)는 0 으로 읽어 이전과 같이 처음부터 스폰.

### 무효 업그레이드 (MEDIUM 3)

10. `UpgradeData.is_retired` 로 숨겼다. 트랙 파일·`game_database.tres` 등록·기존 세이브의 레벨은
    그대로다. P5 가 트랙을 지울 때 이 플래그도 함께 없어진다. 로드맵에 명시했다.

### 사전 존재 이슈 / 환경

11. **테스트는 한 번에 하나씩 돌려야 한다.** 모든 하네스가 같은 `user://jamo_save.json` 을
    지우고 쓴다. 이번에 헤드리스 스위트와 창 모드 `qa_p0_flow` 를 동시에 돌리자 후자가
    "suspended run: run block present=false" 로 13건 FAIL 했고, 단독 재실행에서 전부 통과했다.
    코드 문제가 아니라 파일 레이스다.
12. 헤드리스 테스트 씬의 스크립트에 파싱 에러가 있으면 `_ready` 가 안 돌아 godot 이 영원히
    안 끝난다. 이 머신에 어제(09-10) 이전 세션이 남긴 헤드리스 godot 프로세스 3개
    (`test_day_flow`, 임시 폴더의 `test_state_split` ×2) 가 아직 떠 있다. 내가 띄운 것이 아니라
    건드리지 않았다. 총지휘자 판단으로 정리 바람.
13. `art/Untitled.blend*` 는 여전히 무관한 untracked 파일. git index 는 비워 뒀다(커밋 안 함).
14. NotoSansKR 폰트 누락, `qa_f7_art` letterbox WARN 6건, `wave_controller.gd:59` 불필요한
    `await` 경고 — 전부 기존 항목, 손대지 않았다.
15. QA LOW 항목(문장핵 GLB 교체 시 `reach_radius`, `qa_f5_*` 의 목적지 있는 클램프 미측정)은
    이번 범위 밖이라 그대로다.
