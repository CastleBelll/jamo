# JAMO P1 (Wave 전투, v0.4 §48 Phase 1) — DEV 완료 보고

## 1) 변경 파일 목록

### 신규
```
scripts/data/wave_data.gd (+ .uid)            WaveData 스키마 (§25) — S3
resources/waves/wave_01.tres ~ wave_05.tres   Wave 1~5 데이터 — S3
scripts/objective/sentence_core.gd (+ .uid)   문장핵 로직 (take_hit, 피격 연출) — S1
scenes/objective/sentence_core.tscn           문장핵 씬. VisualRoot 아래 임시 프리미티브 — S1
scripts/wave/wave_controller.gd (+ .uid)      Spawn / Clear / 다음 Wave, P2 훅 — S4
scenes/run/wave_controller.tscn               main.tscn 에 인스턴스 — S4
tests/test_wave_combat.gd / .tscn             신규 헤드리스 테스트 (아래 A-4)
tests/qa_artifacts/p1/DEV_HANDOFF.md          이 보고서
tests/qa_artifacts/p1/h_qa_p0_flow.log        창 모드 하네스 마지막 실행 로그
```

### 수정
```
autoload/signal_bus.gd            wave_cleared 신규, run_failed 에 is_record 인자 추가
autoload/run_state.gd             end_run 이 is_record 를 계산해 run_failed 로 전달,
                                  get_current_wave_data() 신규. damage_core 주석 갱신
autoload/meta_state.gd            UPGRADE_CORE_HP id, get_core_max_hp() 가 업그레이드 값을 읽음 (§13.1)
scripts/main.gd                   end_run_when_energy_depleted 플래그·energy_depleted 핸들러 삭제.
                                  SignalBus.run_failed 로만 결과 화면 진입 (§35)
scenes/main/main.tscn             WaveController 인스턴스 추가
scenes/world/game_world.tscn      SentenceCore(0,0,-2.4) + SpawnPoints(Front/Left/Right Marker3D) 추가,
                                  SpawnManager 에 spawn_point_root / objective / spawn_jitter 연결
scripts/monsters/spawn_manager.gd WaveData 기반 스폰(수/간격/동시 수/특수 비율), field_cleared 시그널,
                                  스폰 포인트 + 지터 + 다이아몬드 클램프, stop()/is_spawning()
scripts/monsters/jamo_monster.gd  objective(SentenceCore) 로 이동, 도달 시 core_damage 후 퇴장,
                                  Wave HP/Gold/속도 배율을 WaveData 에서 읽음, clamp_point_to_arena() static
scripts/data/jamo_monster_data.gd core_damage 필드 신규 (기본 1.0)
resources/monsters/big_mieum.tres core_damage = 2.0
resources/monsters/golden_hieut.tres core_damage = 0.0 (황금은 문장핵을 치지 않는다)
scripts/data/game_balance.gd      start_max_energy 10, base_monster_hp 1.0,
                                  hp_growth_per_wave / gold_growth_per_wave / special_spawn_chance 삭제,
                                  monster_hp_for_wave / monster_gold_for_wave 가 WaveData 를 받음
resources/balance/game_balance.tres  위 필드 반영
scripts/data/game_database.gd     waves 배열 + find_wave()
resources/balance/game_database.tres waves 5개 등록
resources/upgrades/max_energy.tres   values 21~30 → 11~20 (기본 10 기준)
scripts/ui/hud.gd, scenes/ui/hud.tscn  §30 배치(좌상 WAVE / 상단 중앙 문장핵 / 하단 중앙 ENERGY /
                                  우상 GOLD), WAVE CLEAR 배너, 문장핵 25% 이하 경고 색,
                                  에너지 0 안내문 "수동 클릭 불가 — WAVE 는 계속된다"
scripts/ui/run_result.gd          PHASE 1 REVERT POINT 주석 제거
scenes/ui/run_result.tscn         부제 "문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다."
tests/test_run_flow.gd            실패 조건을 문장핵으로 갱신 (에너지 0 후 계속됨을 먼저 확인)
tests/qa_p0_flow.gd               같은 갱신 + 에너지 0 이후 Wave 계속 확인 절차·스크린샷 추가
tests/qa_f5_arena.gd / qa_f5_margin_ab.gd / qa_f5_topdown.gd
                                  _free_roam(): 문장핵 없이 무한 Wave 로 스폰 (배회 클램프 관찰용)
docs/DEV_ROADMAP.md               P1 [~] + Wave 곡선 근거 표 + P2 이후 이관 목록
docs/ORCHESTRATION_RULES.md       §7.1 헤드리스 테스트 3개, §7.2 P1 QA 유의사항 신설
```

`art/Untitled.blend*` 은 이번 작업과 무관한 기존 untracked 파일이다. 건드리지 않았고
스테이징도 하지 않았다. git index 는 비워 뒀다.

---

## 2) 검수 절차 (QA 가 그대로 따라 할 것)

### A. 정적 / 자동 테스트

1. `godot --headless --path . --quit`
   → **기대**: `NotoSansKR-Regular.ttf` 폰트 누락 에러만. 그 외 에러 0.
2. `godot --headless --path . res://tests/test_state_split.tscn`
   → **기대**: exit 0, 마지막 줄 `OK - meta/run split holds.`
3. `godot --headless --path . res://tests/test_run_flow.tscn`
   → **기대**: exit 0, 마지막 줄 `OK - Wave 1 started, the core fell, and the hub came back.`
4. `godot --headless --path . res://tests/test_wave_combat.tscn` (약 20초)
   → **기대**: exit 0, 마지막 줄
     `OK - waves run on data, energy 0 ends nothing, the core is the only failure.`
     중간 출력에 `core 20 -> 19` (몬스터가 문장핵에 도달), `DoT kill: gold 0.00 -> 2.00`
     (에너지 0 에서 화상 처치 골드), `Wave 1 -> 2 ... energy 10 / 10` (Clear 시 회복) 이 보인다.
5. 창 모드 하네스 (**헤드리스 금지**):
   ```
   godot --path . res://tests/qa_p0_flow.tscn
   godot --path . res://tests/qa_p0_plates_all.tscn
   godot --path . res://tests/qa_f7_title.tscn
   godot --path . res://tests/qa_f7_art.tscn
   godot --path . res://tests/qa_f8_labels.tscn
   godot --path . res://tests/qa_f8_focus_all.tscn
   godot --path . res://tests/qa_f8_resize.tscn
   ```
   → **기대**: 전부 exit 0, `FAIL` 0건. `qa_p0_flow` 3단계에
     `landed 22 monster clicks, energy 10 -> 0` 와 `energy 0: wave 3 still running` 이 나온다
     (Wave 1·2 는 클릭으로 전멸 가능하고 Wave 3 에서 에너지가 바닥나는 것이 곡선 의도다).
     `qa_f7_art` 의 `WARN: ... letterbox` 6줄은 P1 이전부터 있던 것이다 (원본 트리에서 동일).

### B. Wave 1~5 실플레이 (§48 Phase 1 완료 기준) — ziva-godot 으로 직접

6. 세이브를 백업 후 삭제하고 게임 실행, `RUN 시작`.
   → **기대**: HUD 가 **좌상단 `WAVE 1`** / **상단 중앙 `문장핵 20 / 20`** 게이지 /
     **하단 중앙 `ENERGY 10 / 10`** / **우상단 `0 G` · `처치 0`** 이다. 화면을 덮는 카드 UI 없음.
     종이 판 **위쪽(후방)** 에 검은 원기둥 + 금색 정육면체(문장핵 임시 프리미티브)가 있다.
7. 몬스터를 관찰한다.
   → **기대**: 판 앞쪽·좌·우 꼭짓점 근처에서 나타나 **문장핵 쪽으로 걸어간다.** ㄷ 은 무겁게,
     ㅁ 은 튀며, ㅇ 은 굴러가고, ㅅ 은 잰걸음 — 보행 성격은 v0.3 그대로이고 방향만 문장핵이다.
     걷다가 잠깐 멈추고 방향을 잡는 것도 그대로다. 판 밖으로 나가는 개체 없음.
8. 한 마리를 일부러 두고 본다.
   → **기대**: 문장핵에 닿으면 사라지고 **`문장핵 19 / 20`** 으로 줄며 화면이 짧게 흔들리고
     문장핵이 눌리는 연출이 나온다. 골드는 오르지 않는다(도달은 처치가 아니다).
9. 나머지를 클릭해서 잡는다.
   → **기대**: 클릭마다 `ENERGY` 가 1 씩 줄고 GOLD 가 2 씩 오른다. Wave 1 은 5마리라 5 클릭이면
     전멸. 전멸 직후 화면 중앙에 **`WAVE 1 CLEAR`** 가 떴다 사라지고, **`WAVE 2`** 로 바뀌며
     **`ENERGY 10 / 10`** 으로 회복된다.
10. Wave 2 (7마리, HP 1) 도 같은 식으로 처리한다.
    → **기대**: 7 클릭이면 전멸, `WAVE 3` 진입 + 에너지 회복. HUD `처치 12`.

### C. 에너지 0 이후에도 Wave 가 계속되는지 (§7.1) — **반드시 확인**

11. Wave 3 (8마리, HP 2 = 2클릭) 에서 클릭을 계속해 에너지를 **0** 까지 쓴다.
    → **기대**: 마지막 3 부터 `⚠ 에너지 부족` 점멸. 0 이 되면 하단에
      **`수동 클릭 불가 — WAVE 는 계속된다`** 로 바뀐다. **결과 화면이 뜨지 않는다.**
12. 그 상태에서 몬스터를 클릭한다.
    → **기대**: 아무 일도 없다 (피해·에너지 변화 없음).
13. 그대로 기다린다.
    → **기대**: 남은 몬스터가 **계속 스폰되고 계속 걸어와** 문장핵을 하나씩 깎는다
      (Wave 3 은 총 16 HP 라 10 에너지로 5마리, 3마리 누수 → `문장핵 17 / 20` 안팎).
      8마리가 전부 처리(처치 또는 도달)되면 **`WAVE 3 CLEAR`** → `WAVE 4` + `ENERGY 10 / 10`.
      즉 **에너지 0 은 RUN 실패가 아니다.**
14. Wave 4 (9마리, HP 2), Wave 5 (10마리, HP 3) 를 같은 식으로 진행한다.
    → **기대**: `WAVE 5` 까지 도달한다. 누수 합계가 14 안팎이라 문장핵이 6 정도 남는다.
      문장핵 25% 이하(5 이하)가 되면 상단 중앙 글자가 붉게 바뀐다.
      ← **6~14 가 P1 완료 기준("Wave 1~5 를 플레이할 수 있다")이다.**
15. Wave 6 이후.
    → **기대**: Wave 5 의 구성(10마리, HP 3)이 반복된다(작성된 마지막 Wave 재사용, P9/P12 범위).
      문장핵이 0 이 되는 순간 **0.8초 뒤 화면이 어두워지고 `RUN 종료`** 결과 화면.
      부제 **`문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다.`**,
      `도달 WAVE 6~7` / `처치 N` / `획득 GOLD N G (유지됨)` / `★ 최고 WAVE 기록 갱신`.
16. `메인 허브로`.
    → **기대**: Main Hub. `RUN 이어하기` 없음. 우상단 GOLD 가 결과 화면의 획득 GOLD 만큼
      남아 있다(§14). `최고 WAVE` 가 도달 Wave.

### D. DoT 처치 골드가 에너지 0 에서도 지급되는지 (§7.1)

현재 단어 장착 UI 는 P2 라 화면에서 화상을 켤 수 없다. 이 항목은 A-4 의
`test_wave_combat` 3번째 블록 (`DoT kill: gold 0.00 -> 2.00, kills 1`) 이 실제 씬에서 화상
Resource 를 몬스터에 적용해 잰다. 창 모드에서 눈으로 보고 싶으면 `godot --path .
res://tests/test_wave_combat.tscn` 으로 돌리면 4배속으로 같은 흐름이 재생된다.

### E. 이어하기 / State 분리 회귀 (P0 규칙 유지)

17. 새 RUN → Wave 1 에서 3마리 잡고 `ESC` → `저장 후 메인 허브로`.
    → **기대**: `RUN 이어하기` + `진행 중인 RUN — WAVE 1 · 문장핵 20`.
18. `RUN 이어하기`.
    → **기대**: `WAVE 1`, **`ENERGY 7 / 10`** (저장값 유지, 회복되지 않는다). Wave 1 의
      5마리가 처음부터 다시 스폰된다 (스폰 카운트는 저장하지 않는다 — 3절 참조).
19. Wave 를 하나 클리어한 뒤 게임을 강제 종료(창 닫기)하고 다시 실행.
    → **기대**: `RUN 이어하기` 가 `WAVE 2` 를 가리킨다 (Wave Clear 가 저장 시점, §45).
20. 세이브 파일 `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 을 연다.
    → **기대**: P0 과 동일. `meta` 에 런 필드 없음, `run` 에 `gold`/`highest_wave` 없음.

### F. 에디터 가시성 (§46)

21. `scenes/objective/sentence_core.tscn` 열기
    → **기대**: `SentenceCore` 루트 Inspector 에 `Visual Root`(NodePath) / `Reach Radius` /
      `Hit Feedback` 그룹(`Camera Rig`, `Hit Shake Strength`, `Hit Shake Duration`,
      `Hit Animation`). 트리에 `VisualRoot/Pillar`, `VisualRoot/Cap`, `HitAnchor`,
      `AnimationPlayer`(`hit` 애니메이션 스크럽 가능).
22. `scenes/world/game_world.tscn` 열기
    → **기대**: `SentenceCore` 가 (0, 0, -2.4) 에, `SpawnPoints/Front·Left·Right` Marker3D 가
      보인다. `SpawnManager` Inspector 에 `Spawn Point Root` / `Objective` / `Spawn Jitter`.
23. `scenes/run/wave_controller.tscn` 열기 → **기대**: `Wave Clear Delay` 노출.
    `scenes/main/main.tscn` 의 `WaveController` 에 `Spawn Manager` 가 연결돼 있다.
24. `resources/waves/wave_03.tres` 열기
    → **기대**: `Wave Number 3`, `Spawn` 그룹(`Enemy Pool` 6개 씬, `Enemy Count 8`,
      `Spawn Interval 0.9`, `Max Alive 4`), `Scaling` 그룹(`Hp Multiplier 2`,
      `Speed Multiplier 1.1`, `Gold Multiplier 1.25`, `Special Spawn Rate 0.05`),
      `Type` 그룹(`Wave Type NORMAL`, `Boss Id` 비어 있음, `Reward Tier 2`).
25. `resources/balance/game_database.tres` 열기 → **기대**: `Waves` 배열 5개.
    `resources/balance/game_balance.tres` → `Start Max Energy 10`, `Base Monster Hp 1`,
    `Hp Growth Per Wave` 류 필드 **없음**.
26. `scenes/ui/hud.tscn` 열기 → **기대**: `TopBar`(Wave/Gold/Kills/Buttons), `CorePanel`,
    `EnergyPanel`, `WaveClearLabel`, `WaveClearAnim` 이 전부 노드. 스크립트가 만드는 노드 없음.

---

## 3) 주의 / 보류 사항

### 임시 프리미티브 / 애셋 교체 지점

1. **문장핵 비주얼은 임시다.** `scenes/objective/sentence_core.tscn` 의 `VisualRoot` 아래
   `Pillar`(CylinderMesh, jamo_ink) + `Cap`(BoxMesh, jamo_gold) 두 개가 전부다. blender
   워크트리 애셋이 오면 **그 두 자식만 지우고 모델을 `VisualRoot` 아래에 넣는다.** 스크립트는
   `visual_root` export 너머를 참조하지 않는다. `hit` 애니메이션이 `VisualRoot` 의 scale/position
   을 키하므로 모델을 그 아래에 두면 연출도 그대로 붙는다. `HitAnchor`(y 1.1) 는 향후 VFX 용.
2. 새 애셋 파일은 만들지 않았다. 기존 `materials/jamo_ink.tres` / `jamo_gold.tres` 재사용.

### Wave 곡선 근거 (수치는 전부 `resources/waves/*.tres`)

3. 전제: Energy 10 / 클릭 피해 1 / 문장핵 20 / 몬스터 HP = `base_monster_hp(1) × WaveData.hp_multiplier × JamoMonsterData.hp_multiplier`.

   | Wave | 수 | 간격 | 동시 | HP× | 속도× | Gold× | 특수 | 클릭만으로 |
   |---|---|---|---|---|---|---|---|---|
   | 1 | 5 | 1.2s | 3 | 1 | 1.00 | 1.00 | 0 | 전멸 (5 클릭) |
   | 2 | 7 | 1.0s | 4 | 1 | 1.05 | 1.10 | 0 | 전멸 (7 클릭) |
   | 3 | 8 | 0.9s | 4 | 2 | 1.10 | 1.25 | 5% | 5 처치, 3 누수 |
   | 4 | 9 | 0.8s | 5 | 2 | 1.15 | 1.40 | 8% | 5 처치, 4 누수 |
   | 5 | 10 | 0.7s | 6 | 3 | 1.20 | 1.60 | 10% | 3 처치, 7 누수 |

   - §53 "초반은 빠르게 감을 잡는다": Wave 1~2 는 에너지만으로 전멸 가능.
   - §7.1 "같은 에너지로 더 많은 압박": Wave 3 부터 총 HP > 10 이라 무엇을 클릭할지 고르게 된다.
     단어 없이 Wave 5 까지 누수 합계 14 < 20 이라 **Wave 1~5 는 클릭만으로 플레이 가능**하고,
     Wave 6~7 에서 실패한다. §53 의 "실패 → 영구 성장 → 재도전" 루프가 성립한다.
   - §5.2: HP 만 올리지 않는다 — 수·간격·동시 수·속도·특수 비율이 같이 오른다.
   - Day 곡선(`3 × 1.035^n`)은 코드·데이터 어디에도 남지 않았다. `test_wave_combat` 가
     Wave 1 과 5 의 수/간격/동시/속도/특수가 모두 다름을 검사한다.
   - 실제 하네스 결과: `qa_p0_flow` 에서 22 클릭에 에너지 0 (Wave 1 전멸 5 + Wave 2 전멸 7 + Wave 3 에서 10).
4. **Wave 6 이상은 Wave 5 를 반복한다.** `GameDatabase.find_wave()` 가 작성된 마지막 Wave 를
   돌려준다. P9 가 Wave 5 를 중간보스로, P12 가 곡선을 확장한다. 스크립트에 공식은 없다.
5. **`base_monster_hp` 3 → 1, `start_max_energy` 20 → 10.** 둘 다 `game_balance.tres`.
   `max_energy.tres` 의 values 를 21~30 → 11~20 으로 옮겼다 (레벨 1 이 기본값보다 낮아지는
   것을 막기 위한 데이터 정정). 가격은 손대지 않았다 — P5.

### 스펙과 다르게 처리한 것 / 판단

6. **실패 규칙의 위치**: `RunState.damage_core()` 가 HP 0 에서 즉시 `end_run()` 을 부르고
   `run_failed(wave, kills, gold_earned, is_record)` 를 낸다. `main.gd` 는 그 시그널만 받아
   0.8초(`run_end_settle_seconds`) 기다린 뒤 결과 화면을 연다. 그 사이 화상 틱 처치는 여전히
   MetaState 로 골드가 들어가고 결과 화면 수치에도 반영된다 (`_on_run_failed` 가 대기 후
   RunState 통계를 다시 읽는다). 단, `MetaState.statistics.total_kills` 는 `end_run` 시점 값이라
   대기 중 처치 1~2 건이 누락될 수 있다. 결과 화면·GOLD 에는 영향 없음.
7. **`run_failed` 시그널 인자가 3개 → 4개.** 구독자는 `main.gd`, `wave_controller.gd`,
   테스트뿐이라 전부 갱신했다. 외부 구독자가 있으면 인자 수 불일치 에러가 난다.
8. **문장핵 위치는 후방(-Z, 화면 위쪽)** 으로 잡았다 (§6.1 "중앙 또는 후방"). 접근이
   아래→위로 읽혀 클릭 대상이 카메라 쪽에 몰린다. 중앙이 낫다고 판단되면
   `game_world.tscn` 의 `SentenceCore.position` 만 옮기면 된다. 스폰 포인트 3개도 같은 씬의
   Marker3D 라 에디터에서 옮긴다.
9. **문장핵에 물리 충돌을 주지 않았다.** 몬스터는 `reach_radius`(0.9m) 안에 들어오면 사라진다.
   충돌체를 주면 몬스터가 문장핵 주위에서 미끄러지며 도달 판정이 흔들리기 때문이다.
10. **`core_damage` 는 `JamoMonsterData` 필드다** (기본 1, 큰 ㅁ 2, 황금 ㅎ 0). §25 WaveData 에는
    없는 값이라 몬스터 쪽에 뒀다. 황금 ㅎ 은 8초 후 스스로 사라지고 문장핵을 치지 않는다.
11. **`special_spawn_chance` 를 `GameBalance` 에서 삭제**하고 `WaveData.special_spawn_rate` 로
    옮겼다 (§5.2 "특수 자모 비율 상승"). 운(`SPECIAL_LUCK`) 배율은 그대로 곱한다.
    `golden_spawn_chance` 는 단어 게이트라 `GameBalance` 에 남겼다.
12. **`monster_capacity` 업그레이드가 게임에 영향을 주지 않게 됐다.** 동시 수는
    `WaveData.max_alive`. `MetaState.get_monster_capacity()` 는 F5 하네스 fill 목표로만 쓴다.
    상점에는 여전히 보인다 — P5 업그레이드 5종 정리 때 삭제 대상 (P0 보고 9번과 동일 맥락).
13. **Core HP 업그레이드 트랙 `.tres` 는 없다.** `MetaState.get_core_max_hp()` 가
    `UPGRADE_CORE_HP = &"core_hp"` 를 `get_upgrade_value` 로 읽는 구조만 만들었다. 트랙이
    없으면 `base_core_hp` 20. P5 가 `resources/upgrades/core_hp.tres` 를 추가하고
    `game_database.tres` 에 등록하면 바로 붙는다.
14. **RUN 이어하기는 Wave 를 처음부터 다시 스폰한다.** 에너지·문장핵 HP·Wave 번호는
    저장값이고, 그 Wave 의 스폰 카운트는 저장하지 않는다. `RunState` 에 필드를 더하면
    `test_state_split` 의 소유 선언도 함께 바꿔야 해서 P1 에선 넣지 않았다. 악용 여지는
    "Wave 중간에 나갔다 들어오면 이미 처리한 몬스터가 다시 온다" 뿐이라 플레이어에게 손해다.
15. **Wave Clear 사이에 아무것도 없다.** `WaveController._between_waves()` 가 빈 `await` 훅이다.
    P2 는 여기서 보상 선택 / Word Forge 를 `await` 하고 돌아오면 `advance_wave()` 가 이어진다.
    Clear 배너(`WAVE n CLEAR`, 1.4초) 와 `wave_clear_delay`(1.4초) 는 §31 "짧은 정산".
16. **HUD 배치를 §30 대로 바꿨다**: `EnergyPanel` 이 하단 중앙, `CorePanel` 이 상단 중앙으로
    갔다. 노드 unique name 은 전부 유지해서 `hud.gd` 와 하네스는 이름으로 찾는다.
    애니메이션 NodePath 만 옮겼다.
17. **에너지 0 안내문**: 하단 경고 라벨이 0 에서 `수동 클릭 불가 — WAVE 는 계속된다` 로 바뀐다.
    §7.1 규칙을 화면에 적어 "게임이 멈춘 것 아니냐"는 오해를 막기 위한 것.

### 테스트 처리

18. **`test_run_flow`** — 에너지를 0 까지 쓴 뒤 30프레임 동안 RUN 이 살아 있고 결과 화면이
    없음을 먼저 확인하고, `SentenceCore.take_hit()` 로 문장핵을 떨어뜨려 실패 경로를 탄다.
    약화하지 않았다: 검사 항목이 늘었다.
19. **`qa_p0_flow`** — 3·8단계가 실제 클릭으로 에너지 0 을 만든 뒤 `_check_energy_zero_keeps_the_wave_going()`
    (RUN 활성 / 결과 화면 없음 / 스폰 계속 / 클릭 거부) 를 잰 다음 `_fell_the_core()` 로 실패시킨다.
    스크린샷 `03_energy_zero_wave_continues.png` 가 추가됐다. 다른 단계는 그대로다.
20. **`test_wave_combat` 신규** (4배속, 약 20초): Wave 1~5 데이터 존재·§5.2 다축 상승 /
    몬스터 도달로 문장핵 감소 / 에너지 0 에서 RUN·스폰 지속 + 화상 처치 골드·처치 수 증가 /
    Wave Clear 시 에너지 회복·`current_wave` 증가·저장 / 문장핵 0 만 실패·`run_failed` 인자·
    GOLD 유지·결과 부제. `tests/test_wave_combat.gd.uid` 는 헤드리스 실행이 만들지 않았다 —
    에디터가 프로젝트를 열면 생성된다. 에러 아님.
21. **`qa_f5_arena` / `qa_f5_margin_ab` / `qa_f5_topdown`** — `start_run()` 뒤에
    `_free_roam(pool)` 을 붙였다. WaveController 가 `wave_started` 마다 스포너를 Wave 1 데이터로
    재설정하므로, 하네스는 그 다음에 `objective = null` + 무한 Wave(500마리, 동시
    `get_monster_capacity()`) 로 덮어쓴다. 배회 클램프를 재는 하네스라 문장핵 접근은 끈다.
    `qa_f5_margin_ab` 를 창 모드로 끝까지 돌려 exit 0 · 스크립트 에러 0 확인.
22. 창 모드 7종 전부 exit 0, FAIL 0. `qa_f7_art` 의 letterbox WARN 6건은 `git stash` 한 원본
    트리에서도 6건이라 P1 과 무관하다.

### 사전 존재 이슈 / 환경

23. `res://art/fonts/NotoSansKR-Regular.ttf` 누락 — 기존 이슈.
24. `git status` 가 LF→CRLF 경고를 내지만 파일은 LF 로 썼다(기존 파일과 동일).
25. `tests/_deferred_v03/README.md` 가 P1 로 표시한 `test_day_flow` / `qa_critical_play` /
    `qa_f4_special` / `qa_f6_settings` 는 되살리지 않았다. 각각 Day 시퀀스 / 치명타 / 특수 몬스터
    출현 / 설정+구세이브인데, 치명타·특수·설정은 P1 범위 밖이고 Day 시퀀스는 `test_wave_combat`
    가 Wave Clear 루프로 대신한다. README 의 Phase 표기는 총지휘자가 갱신 판단.
