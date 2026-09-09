# F4 특수 몬스터 — DEV 인계문

대상: v0.3 §9 §28 §32 / growth_balance v0.2 §2 §9.2 §9.3 / DEV_ROADMAP F4 S1~S6

---

## 1) 변경 파일 목록

### 수정

| 파일 | 내용 |
|---|---|
| `scripts/data/jamo_monster_data.gd` | S1. `SpecialType` enum(NORMAL/SPECIAL/GOLDEN), `special_type`, `speed_multiplier`, `lifetime_seconds` export 추가 |
| `scripts/data/game_balance.gd` | `special_spawn_chance` / `golden_spawn_chance` export 추가 (Special Monsters 그룹) |
| `resources/balance/game_balance.tres` | 위 두 값 = 0.02 (2%) |
| `scripts/monsters/jamo_monster.gd` | `speed_multiplier` 를 실제 이동속도에 반영. `lifetime_seconds` 만료 시 `_expire()` — 골드 미지급·화상 전이 없음. `_die()` / `_expire()` 공통 정리를 `_leave_field()` 로 묶음 |
| `scripts/monsters/spawn_manager.gd` | S5. Normal / Special / Golden 3 pool 분리, `get_golden_spawn_chance()` / `get_special_spawn_chance()`, `_pick_pool()`, pool 별 가중 추첨, PackedScene→Data 캐시, pool 오배치 경고 |
| `scenes/world/game_world.tscn` | SpawnManager 에 `special_scenes` / `golden_scenes` 배선 |
| `tests/test_game_loop.gd` | F4 테스트 4종 추가 |

### 신규

| 파일 | 내용 |
|---|---|
| `resources/motion_profiles/heavy_bounce.tres` | 큰 ㅁ 전용 — step_frequency 0.55 (강한 착지), 긴 idle, 넓은 avoidance |
| `resources/motion_profiles/roll_fast.tres` | 빠른 ㅇ 전용 — idle 0.12~0.4 (방향 전환 빈도 ↑), turn_speed 13 |
| `materials/jamo_gold.tres` | 금속 재질 + emission_energy 0.35 (약한 Glow) |
| `resources/monsters/big_mieum.tres` | HP ×3 / Gold ×3 / speed ×0.6 / scale 2.7 / click_radius 1.2 |
| `resources/monsters/fast_ieung.tres` | HP ×0.75 / Gold ×2 / speed ×1.8 / scale 1.5 |
| `resources/monsters/golden_hieut.tres` | Gold ×5 / lifetime 8초 / special_type = GOLDEN |
| `scenes/monsters/special/monster_big_mieum.tscn` | `monster_mieum.tscn` 상속 |
| `scenes/monsters/special/monster_fast_ieung.tscn` | `monster_ieung.tscn` 상속 |
| `scenes/monsters/special/monster_golden_hieut.tscn` | `monster_ieung.tscn` 상속 + 금 재질 + ㅎ 획 2개 |

---

## 2) 검수 절차

준비: Godot Editor 로 프로젝트를 열고, 별도 지시가 없으면 `scenes/main/main.tscn` 을 F5 로 실행한다.

### A. 헤드리스 (보조)

1. 터미널에서 `godot --headless --path . --quit` 을 실행한다.
   기대: 출력에 `NotoSansKR-Regular.ttf` 폰트 누락 2줄 **외에** 에러가 없다. (폰트는 기존 이슈)
2. `godot --headless --path . res://tests/test_game_loop.tscn` 을 실행한다.
   기대: 마지막 줄 `OK - all game loop checks passed.` / exit code 0.
3. `godot --headless --path . res://tests/test_day_flow.tscn` 을 실행한다.
   기대: 마지막 줄 `OK - day flow reached Day 2.`

### B. 에디터 가시성 (§37)

4. FileSystem 독에서 `resources/monsters/big_mieum.tres` 를 클릭한다.
   기대: Inspector 에 Combat / Movement / Visual Click / Spawning 그룹이 보이고
   `Hp Multiplier 3`, `Gold Multiplier 3`, `Speed Multiplier 0.6`,
   `Visual Scale 2.7`, `Special Type` 이 드롭다운(Normal/Special/Golden)으로 보인다.
   `Special Type` 값은 `Special` 이다.
5. `resources/monsters/golden_hieut.tres` 를 클릭한다.
   기대: `Gold Multiplier 5`, `Special Type = Golden`, `Lifetime Seconds 8`.
6. `resources/monsters/fast_ieung.tres` 를 클릭한다.
   기대: `Hp Multiplier 0.75`, `Gold Multiplier 2`, `Speed Multiplier 1.8`,
   `Motion Profile` 이 `roll_fast.tres`.
7. `scenes/monsters/special/monster_golden_hieut.tscn` 을 더블클릭해 연다.
   기대: 씬 트리 루트가 `MonsterGoldenHieut`, 그 아래 상속받은 `VisualRoot/Body/Lean` 에
   `Ring`(상속) + `HatBar` + `HatStroke` 3개가 보인다. 3D 뷰포트에 **금색 ㅎ**(고리 위에
   가로 획과 세로 꼭지)가 보인다. `HatBar` 를 선택해 Transform 의 position 을 드래그하면
   에디터에서 바로 위치가 움직인다.
8. `scenes/world/game_world.tscn` 을 열고 `SpawnManager` 노드를 선택한다.
   기대: Inspector 의 `Pools` 그룹에 `Monster Scenes`(6개), `Special Scenes`(2개),
   `Golden Scenes`(1개) 배열이 각각 따로 보인다.
9. `resources/balance/game_balance.tres` 를 클릭한다.
   기대: `Special Monsters` 그룹에 `Special Spawn Chance 0.02`,
   `Golden Spawn Chance 0.02` 가 보이고 값을 드래그로 바꿀 수 있다.

### C. 직접 플레이 — 특수 몬스터 등장 (S3 / S4)

확률 2% 는 눈으로 세기 어렵다. **9번의 `.tres` 값을 임시로 올려서 관측한 뒤 되돌린다.**

10. `resources/balance/game_balance.tres` 의 `Special Spawn Chance` 를 `0.6` 으로 바꾸고
    Ctrl+S 로 저장한다. `main.tscn` 을 F5 로 실행한다.
    기대: 필드 8마리 중 대다수가 **평소보다 훨씬 큰 ㅁ** 또는 **작고 빠른 ㅇ** 이다.
11. 큰 ㅁ 한 마리를 눈으로 따라간다.
    기대: 일반 ㅁ 보다 눈에 띄게 크고, 확실히 느리게 통통 뛰며, 착지 간격이 길다.
    클릭 판정이 넓어 쉽게 맞는다.
12. 큰 ㅁ 를 죽을 때까지 클릭한다. 클릭 횟수를 센다.
    기대: 같은 Day 의 일반 ㅁ 보다 **약 3배** 더 많이 클릭해야 죽는다.
    죽는 순간 HUD 의 Gold 증가폭이 일반 ㅁ 의 **약 3배**다.
13. 빠른 ㅇ 한 마리를 따라간다.
    기대: 일반 ㅇ 보다 확연히 빠르게 굴러다니고, 방향을 자주 홱홱 바꾼다.
    클릭 1~2회 덜 맞아도 죽는다(HP ×0.75). Gold 증가폭은 일반의 약 2배.
14. `Special Spawn Chance` 를 `0.02` 로 되돌리고 저장한다.

### D. 직접 플레이 — 황금 ㅎ 잠금 (S2, 금 미해금)

15. 게임을 새로 시작한다(세이브 파일이 있으면 지운다). HUD 도감에서 `금` 이
    아직 완성되지 않았음을 확인한다.
16. `resources/balance/game_balance.tres` 의 `Golden Spawn Chance` 를 `0.9` 로 바꾸고 저장한 뒤
    `main.tscn` 을 F5 로 실행한다. 2~3 Day 를 진행하며 필드를 관찰한다.
    기대: **금색 ㅎ 가 한 마리도 나오지 않는다.** 확률을 90% 로 올려도 마찬가지다.
    (이것이 `금` 게이트의 핵심 검증이다)

### E. 직접 플레이 — 황금 ㅎ 등장 (S2, 금 해금)

17. `금`(gold_002) 을 해금한다. 둘 중 하나로 한다.
    - 플레이 경로: Day End 자모 선택에서 `ㄷ ㅗ ㄴ` 을 모아 `돈` 을 완성하고,
      이어서 `ㄱ ㅡ ㅁ` 을 모아 `금` 을 완성한다. HUD 도감에 `[완성] 금` 이 뜬다.
    - 단축 경로: ziva-godot MCP `execute_script` 로
      `GameState.unlocked_word_ids.append(&"gold_001")`,
      `GameState.unlocked_word_ids.append(&"gold_002")`,
      `GameState.from_dict(GameState.to_dict())` 를 실행한다.
18. `Golden Spawn Chance` 가 `0.9` 인 상태로 게임을 계속 본다.
    기대: **금속 광택이 나는 금색 ㅎ** 가 필드에 나타난다. 잉크색 자모들과 확실히 구분된다.
    화면 전체가 뿌옇게 번지는 Bloom 은 없어야 한다(§24).
19. 금색 ㅎ 를 클릭하지 말고 그냥 지켜본다. 초를 센다.
    기대: **약 8초 뒤 스스로 사라진다.** 사라질 때 HUD 의 Gold 는 **오르지 않는다.**
    사라진 자리는 곧 다른 몬스터로 채워진다.
20. 이번엔 금색 ㅎ 가 사라지기 전에 클릭해서 죽인다.
    기대: HUD Gold 증가폭이 같은 Day 일반 몬스터의 **약 5배**다.
21. `Golden Spawn Chance` 를 `0.02` 로 되돌리고 저장한다.

### F. 직접 플레이 — 운 배율 (S2 확률 보정)

22. 17번과 같은 방법으로 `운`(luck_001, `ㅇ ㅜ ㄴ`) 을 추가로 해금한다.
23. ziva-godot MCP `execute_script` 로 다음을 출력한다.
    `print(GameState.get_special_spawn_multiplier())`
    기대: `1.05` (운 미해금 시 `1.0`).
24. 같은 방식으로 SpawnManager 의 실제 확률을 출력한다.
    `print(get_node("/root/Main/GameWorld/SpawnManager").get_golden_spawn_chance())`
    기대: `0.021` (= 0.02 × 1.05). 운 해금 전에는 `0.02`.
    `get_special_spawn_chance()` 도 같은 비율로 오른다.

### G. 성능 / 회귀

25. 상점에서 `몬스터 수` 업그레이드를 최대(20)까지 산다. Godot 실행 창에서
    좌상단 FPS(또는 에디터 Debug > Monitors) 를 본다.
    기대: 동시 20마리(특수 개체 포함)에서 60 FPS 유지, 끊김 없음.
26. Day 1 에서 에너지를 모두 소모해 Day End 로 넘어가고 Day 2 를 시작한다.
    기대: 필드가 비워졌다가 다시 채워지고, 특수/황금도 정상적으로 섞여 나온다.
    (Day 전환 시 남아 있던 황금이 골드를 지급하지 않는다)

---

## 3) 주의/보류 사항

1. **황금 ㅎ 의 글리프 처리 (판단 필요)** — v0.3 §9.3 은 `황금 ㅎ` 라고 적혀 있지만
   프로젝트에 ㅎ 자모 씬이 없고, S6 은 "새 메시를 만들지 않는다"를 못 박고 있다.
   두 조건을 모두 지키기 위해 `monster_ieung.tscn`(ㅇ 고리) 을 **상속**하고,
   씬 안에서 `BoxMesh` 프리미티브 2개(`HatBar`, `HatStroke`) 를 고리 위에 얹어 ㅎ 를 만들었다.
   새 메시 애셋 파일은 만들지 않았고, 두 획은 에디터에서 자유롭게 옮길 수 있다.
   데이터상 `jamo = "ㅎ"` 이다. 이 절충이 부적절하면 F5 에서 정식 ㅎ 자모 씬을 만들고
   황금 개체가 그것을 상속하도록 바꾸면 된다.
2. **`scale` export 이름** — S1 은 `scale` 을 요구하지만 기존 `visual_scale` 을 그대로 썼다.
   이름을 바꾸면 기존 자모 6종 `.tres` 가 전부 깨진다. Inspector 에는
   `Visual / Click > Visual Scale` 로 노출된다.
3. **§22.1 의 `material` 필드는 데이터에 넣지 않았다.** 기존 자모 6종과 동일하게
   머티리얼은 씬의 `MeshInstance3D > surface_material_override` 로 지정한다
   (황금 ㅎ 는 `materials/jamo_gold.tres`). 데이터에 넣으면 씬 쪽 지정과 이중 소스가 된다.
4. **골드 업그레이드 트랙 미구현** — growth_balance §9.2 `특수 몬스터 발견`(+1~5%),
   §9.3 `황금 보정`(+0.5~2.5%p) 은 Gold Upgrade 라 S1~S6 범위 밖이다. 다음 사이클 후보.
   현재 확률은 `game_balance.tres` 의 두 값 × `운` 배율만으로 결정된다.
5. **`황금` 단어(Gold ×8) 미구현** — 해당 WordData 가 아직 없다. 현재 황금은 항상 ×5.
6. **분열 ㅂ(§9.4) / 점멸 ㅅ(§9.5) 미구현** — 이번 사이클 범위(3종)에 없다.
7. **황금 소멸 연출 없음** — 수명이 끝나면 일반 death 애니메이션으로 사라진다.
   전용 이탈 VFX/SFX 는 F6 Juice 범위.
8. **하위 호환** — `SpawnManager.monster_scenes` 이름은 유지했다(Normal Pool).
   기존 세이브 파일에는 영향 없다. 새 export 는 전부 기본값이 있어
   기존 자모 6종 `.tres` 는 수정 없이 그대로 동작한다(`speed_multiplier` 1.0,
   `special_type` Normal, `lifetime_seconds` 0).
9. **기존 QA 하니스는 헤드리스로 돌리면 안 된다** — `qa_f3_play.tscn`, `qa_f4_hud.tscn`,
   `qa_critical_play.tscn` 은 파일 주석대로 창 모드가 필요하다. 헤드리스로 실행하면
   `_click_until_hit` 에서 멈춘다. 이번 변경과 무관한 기존 조건이다.
10. **큰 ㅁ 크기** — `visual_scale 2.7` 은 아레나에서 눈에 띄게 크다. 카메라 프레임이나
    아레나 가장자리와 부딪히면 `big_mieum.tres` 의 `Visual Scale` / `Click Radius` 만
    낮추면 되고 코드 수정은 필요 없다.
