# JAMO P1-DEV-4 — 캐릭터 자모 15종 연결 + 맵 재설계 — DEV 완료 보고

검증 환경: Godot 4.7.stable, Windows 11, Intel UHD Graphics 770 / Vulkan Forward+, 1280×720.
`art/` 아래 GLB·PNG 는 읽기만 했다. Godot 이 `art/monsters/characters/*.glb` 를 처음
import 하며 `.glb.import` 15개를 새로 만들었고(메타데이터, 이전 ASSET-02 GLB 와 같은 방식으로
추적), 기존 `.import` 의 줄바꿈 변경은 체크아웃 상태로 되돌렸다.

---

## 1) 변경 파일 목록

### 프로덕션 — 자모 캐릭터
```
scenes/monsters/monster_{giyeok,digeut,mieum,siot,ieung,i}.tscn   BoxMesh 획 전부 삭제 →
                                      VisualRoot/Body/Lean/Model = art/monsters/characters/<id>.glb
                                      (position (0, 0.0201, 0), rotation 0, scale 1)
scenes/monsters/monster_{nieun,rieul,bieup,hieut,eo,yeo,o,u,eu}.tscn   신규 9종, 같은 구조
resources/monsters/{nieun,rieul,bieup,hieut,eo,yeo,o,u,eu}.tres       신규 9종 JamoMonsterData
                                      (권장 프로필: ㄴ/ㅂ HEAVY_STEP, ㄹ/ㅓ/ㅕ SWAY, ㅎ BOUNCE, ㅗ/ㅜ/ㅡ GLIDE)
resources/monsters/fast_ieung.tres    glyph_material = materials/jamo_special_fast.tres
resources/monsters/golden_hieut.tres  glyph_material = materials/jamo_gold.tres
scenes/monsters/special/monster_golden_hieut.tscn   base 를 monster_ieung → monster_hieut 로.
                                      Ring/HatBar/HatStroke 프리미티브 삭제, GoldSparkle 만 유지
scripts/data/jamo_monster_data.gd     @export glyph_material: Material 추가 (Glyph 표면 0 전용)
scripts/monsters/jamo_monster.gd      _bind_character_parts(): Leg_L/Leg_R/Glyph 를 이름으로 찾고
                                      glyph_material 적용. @export leg_swing / leg_tuck (setter 가
                                      두 다리 피벗 local rotation.x 에 반대/동일 위상으로 적용).
                                      아레나 수식을 마름모 → 직사각형으로 (아래).
resources/animations/walk_library.tres   idle / spawn / walk_* 8개 애니메이션에
                                      `.:leg_swing`, `.:leg_tuck` value 트랙 추가 (기존 트랙 불변)
resources/waves/wave_01~05.tres       enemy_pool 6종 → 15종 (수/간격/동시/배율은 그대로)
art/monsters/characters/*.glb.import  신규 15개 (Godot import 메타데이터)
```

### 프로덕션 — 맵
```
scenes/world/arena.tscn               45° 회전 5.6×5.6 슬랩 → 회전 없는 12×7.5 종이 한 장.
                                      Desk 26×18 (배경 전체가 나무), 벽 4면 = 종이 가장자리,
                                      Decor 슬롯 5개 (BookStackLeft / BookStackRight / Lantern /
                                      Inkstone / Brush, 프리미티브 임시물)
scripts/world/arena_decor.gd          신규. Decor 의 @export replacements: Dictionary[StringName,
                                      PackedScene] — 슬롯 이름 → 실제 애셋 씬 교체 지점
scenes/world/game_world.tscn          SentenceCore z -2.2 → -2.5. 스폰 마커 3 → 7. SpawnManager
                                      monster_scenes 15종, arena_half_extents (6, 3.75)
scripts/monsters/spawn_manager.gd     기본 arena_half_extents (6, 3.75), 주석
scripts/monsters/jamo_monster.gd      clamp_point_to_arena / random_point_in_arena 직사각형,
                                      get_walkable_half_extents 축별 inset, static arena_spill() 추가
```

### 테스트 / 문서
```
tests/qa_p1_map.gd / .tscn            신규 창 모드 하네스 (약 3분). 18 씬 파츠·특수 재질·다리 스윙·
                                      문장핵 안착·스폰 방향·HUD 값·Wave 1~5 실클릭·종이 이탈·20마리 FPS
tests/qa_artifacts/p1/map/*.png       00 arena / 01 lineup / 02 gaits / N0 wave start /
                                      N2 wave incoming(동시 수 가득) / N5 core hit / 95 full field
tests/qa_f5_arena.gd, qa_f5_margin_ab.gd   슬랩 반치수를 상수 대신 PaperTop 메시에서 읽고
                                      축별 overhang 측정. 최악 코너 = (+x, +z)
tests/qa_f5_arena.gd, qa_f5_topdown.gd     NORMAL_SCENES 6 → 15
tests/qa_p1_core_asset.gd             책 footprint 검사를 |x|+|z| → arena_spill (직사각형)
tests/qa_p1_play.gd                   이탈 검사를 arena_spill 로
docs/ORCHESTRATION_RULES.md           §7.4 신설 (QA 가 알아야 할 것)
docs/DEV_ROADMAP.md                   P1-DEV-4 항목, 문장핵 z 갱신
tests/qa_artifacts/p1/DEV_HANDOFF_4.md   이 보고서
```

---

## 2) 검수 절차

### A. 자동 (전부 exit 0. **한 번에 하나씩** 돌릴 것 — 세이브 파일 공유)

1. `godot --headless --path . --quit` → NotoSansKR 폰트 누락 2줄 외 에러 0.
2. `godot --path . res://tests/qa_p1_map.tscn` (창 모드, 약 3분) → 기대:
   - `-- field: paper half extents (6.0, 3.75), spawner (6.0, 3.75)`
   - `문장핵 seat … paper margin x 5.05 z 0.62`
   - 스폰 마커 7줄, 각도 -81 ~ +81°, `FAIL` 없음
   - `HUD core readout: 문장핵 20 / 20`
   - lineup 18줄 (giyeok 340 … big_mieum 360 / visual_scale 2.70, fast_ieung, golden_hieut)
   - `legs while walking` 7줄: Leg_L range ≥ 0.29 rad (GLIDE 0.29, 나머지 0.64~1.00),
     `pose matches 60`
   - `spawn sectors used … 5 sectors`, `worst body overhang … 0.000 m`
   - `20 alive: avg 60.0 FPS, min 60.0`
   - wave log: 1·2 `core lost 0 cleared true`, 3~5 누수 있으나 `cleared true`, 5 `core left > 0`,
     6 `cleared false` (문장핵 0)
   - 마지막 줄 `OK - character jamo walk in from all sides of the wide sheet and Wave 1~5 play through.`
3. 헤드리스 7종 `test_state_split` / `test_run_flow` / `test_wave_combat` / `test_monster_state` /
   `qa_p1_stall` / `qa_p1_negctl` / `qa_p1_lockhunt` → 전부 exit 0, 마지막 줄 `OK - …`.
   어느 로그에도 `SpawnManager: wave N finished spawning … never resolved` 없음.
4. 창 모드 `qa_p0_flow` / `qa_f7_title` / `qa_f7_art` / `qa_f8_labels` / `qa_f8_focus_all` /
   `qa_f8_resize` / `qa_p0_plates_all` / `qa_p1_core_asset` / `qa_p1_gait` / `qa_p1_play` → exit 0.
   `qa_p1_core_asset` 은 `footprint corner spill max 0.83 of 1.00`.
5. `qa_f5_arena` / `qa_f5_margin_ab` / `qa_f5_topdown` (창 모드, 각 2~3분, 스스로 종료) →
   `qa_f5_arena.json` 의 `worst_body_overhang_m` 이 세 풀 모두 0, `worst_case_corner` 의
   `body_overhang_m` 0. `margin_ab` 는 `margin=0.00 worst_overhang=0.000`.

### B. 눈으로 — 맵 (`godot --path .` → RUN 시작)

6. RUN 시작 직후 화면. → 기대: **가로로 긴 직사각형 종이** 가 나무 책상 위에 놓여 있고, 배경은
   단색 갈색이 아니라 **책상 나무색** 이다. 종이 위쪽 가운데에 펼친 책(문장핵)이 **종이 안쪽에
   여유를 두고** 앉아 있다 — 꼭짓점에 걸치거나 허공에 뜬 느낌이 없어야 한다. 종이 밖 책상에
   왼쪽 책 더미·왼쪽 위 등롱·오른쪽 책 더미·오른쪽 벼루+먹·아래 오른쪽 붓 이 보인다
   (`map/00_arena_empty.png`).
7. 에디터에서 `scenes/world/arena.tscn` 을 연다. → 기대: `Decor` 노드 Inspector 에
   `Replacements` (Dictionary) 가 비어 있고, 자식 슬롯 5개 (`BookStackLeft` 등) 아래 프리미티브
   MeshInstance3D 들이 있다. 슬롯을 움직이면 임시물이 같이 움직인다.
   `scenes/world/game_world.tscn` 의 `SpawnPoints` 아래 Marker3D 7개, `SpawnManager` 의
   `Arena Half Extents (6, 3.75)`, `SentenceCore` position `(0, 0, -2.5)`.

### C. 눈으로 — 캐릭터 자모 (반드시)

8. Wave 1 을 클릭하지 않고 지켜본다. → 기대: 자모마다 **먹색 눈 두 개와 다리 두 개** 가 있고
   (`map/02_gaits_walking.png` 처럼), 옛 상자 획 조합이 아니다. **걸을 때 두 다리가 번갈아
   앞뒤로 움직인다** — 멈춰 있는 다리로 미끄러져 오면 FAIL. ㅁ 계열(BOUNCE)은 착지 순간 양 다리가
   함께 굽는다. ㅡ(GLIDE) 는 진폭이 작다(의도).
9. 15종 확인: Wave 1~3 을 여러 번 돌리며 ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ ㅅ ㅇ ㅎ ㅓ ㅕ ㅗ ㅜ ㅡ ㅣ 가 모두
   나오는지 본다 (`map/01_lineup_15_plus_specials.png` 가 18종 한 줄 정렬 증거). ㅁ/ㅇ/ㅎ/ㅂ 의
   구멍, ㅓ/ㅕ 획 수, ㅗ/ㅜ 방향이 구분된다.
10. Wave 3~5 에서 특수종. → 기대: **큰 ㅁ** 은 일반 ㅁ 의 1.4배 크기(2.7/1.9) 로 같은 모델·같은
    종이색. **빠른 ㅇ** 은 몸통 정면만 쪽빛(진한 청록)이고 **눈·다리·측면은 그대로** 먹색/종이색.
    (황금 ㅎ 은 단어 `금` 이 P2 라 실플레이에선 안 나온다 — 하네스 lineup 으로 대체: 정면만 금색
    + 반짝임.) 특수 재질이 눈이나 측면까지 덮으면 FAIL.

### D. 눈으로 — "공격하러 온다" 판정 (반드시)

11. Wave 3 이후 에너지가 0 이 된 뒤 화면을 10초 이상 본다. → 기대:
    (a) 자모가 **한 줄로 오지 않는다.** 화면 왼쪽 가장자리, 오른쪽 가장자리, 아래쪽 세 지점,
    그리고 책 좌우 뒤편에서도 나타난다 (`map/52_wave5_incoming.png`: 좌·우·우상·우하에서
    동시에 6마리).
    (b) 어느 방향에서 나오든 **모두 책을 향해 방향을 잡고** 걸어 들어와 책 가장자리에서 사라지며
    문장핵이 번쩍인다. 책을 지나쳐 뒤로 돌아가는 개체 없음.
    (c) 나타난 뒤 책에 닿기까지 **대략 5~7초** 걸린다 (옛 맵 3~4초). 이 사이에 다리가 계속 움직인다.
    (d) 자모가 종이 밖 책상으로 나가는 일이 없다 — 종이 가장자리에 부딪히면 안쪽으로 밀린다.
    이 네 가지가 보이면 "몰려와서 공격한다" 로 판정한다. (a)~(c) 중 하나라도 아니면 FAIL.
12. Wave 5 까지 진행 → 기대: 어느 Wave 도 생존자가 남아 멈추지 않고 `WAVE N CLEAR` → 다음 Wave.
    문장핵 0 이면 결과 화면 → 메인 허브. HUD 문장핵 값은 `20 / 20` 에서 시작해 정수로 줄어든다.
    `999998 / 20` 같은 값은 하네스가 HP 를 고정했을 때만 나오며 실플레이에선 없다 (2번 4단계).

---

## 3) 주의 / 보류 사항

1. **맵 치수 근거 — 12 × 7.5 m 직사각형, 회전 없음.**
   옛 마름모(5.6×5.6, 45°)는 면적 31 m², 1280×720 화면에서 폭 594 px 만 썼다(화면 46%).
   카메라(Orthogonal size 9.6, -50°)는 바닥 폭 17.1 × 깊이 12.5 m 를 보이므로 종이 12 m (900 px,
   화면 70%) 가 좌우 장식 자리 2.5 m 를 남기는 최대치다. 깊이 7.5 m 는 화면 세로에서 HUD(70 px)
   와 에너지 패널(638 px) 사이 555 px 안에 종이(431 px) + 슬랩 두께 + 책 높이가 들어가는 최대치다.
   면적 90 m² (2.9배): 동시 20마리가 회피 반경 1~1.75 m 로 서도 남는다. 보행 거리는 정면
   4.7 m / 측면 5.6 m / 코너 6.7 m (옛 3.0~4.2 m, 약 +50%). **카메라는 손대지 않았다** —
   size 9.6 에 정확히 들어와 몬스터 화면 크기(클릭 난이도)도 그대로다.
   직사각형을 택한 이유: 타이틀 배경의 종이가 직사각형이고, 16:9 화면에서 마름모는 세로가 먼저
   막혀 좌우를 버린다. 클램프는 **몸통 크기 inset 원칙을 그대로 두고 축별로만 바꿨다**
   (`arena_half_extents.x − body.x`, `.y − body.y`). `qa_f5_*` 가 실측했다.
2. **문장핵 (0, 0, −2.5).** 책 뒷모서리가 종이 뒤쪽 가장자리에서 0.62 m 안쪽, 좌우 5 m 여유.
   `reach_radius 1.1` 유지. 모든 스폰 마커에서 5.7~7.1 m.
3. **Wave 곡선은 건드리지 않았다.** 걷는 거리가 늘어 몬스터가 오래 살지만 누수 수는 에너지
   (클릭 10회) 가 결정하므로 P1 QA 가 검증한 표가 유지된다. 하네스 실측 3회:
   W1 5/0, W2 7/0, W3 5처치/3~5누수, W4 3~5/4~7, W5 3/7~8, W6 실패 (처치/누수).
   달라진 것은 Wave 소요 시간(약 +30%) 뿐이다. §5.2 가 원하는 "속도 상승" 압박이 약해졌다고
   느끼면 `wave_0N.tres` 의 `speed_multiplier` 만 올리면 된다 (스크립트 수치 없음).
4. **다리 애니메이션 방식.** GLB 내부 계층이 파일마다 다르다(`JamoCharacter_030/Leg_L` 처럼
   중간 노드 이름이 15개 전부 다름). 그래서 walk_library 트랙이 다리 노드를 직접 가리키지 않고
   **`JamoMonster` 의 `leg_swing` / `leg_tuck` 프로퍼티** 를 키하고, 스크립트가 README 계약대로
   `find_child("Leg_L")` 로 찾은 피벗에 적용한다. 진폭·타이밍은 전부 `walk_library.tres` 의
   트랙(에디터 타임라인)에 있다: HEAVY_STEP ±0.45, LIGHT_STEP ±0.5, UPRIGHT ±0.45, SWAY ±0.4,
   ROLL ±0.35, GLIDE ±0.15, BOUNCE 는 착지 키에서 leg_tuck 0.55. 기존 6종 몸통 모션 트랙은
   한 키도 바꾸지 않았다 (`qa_p1_gait` 통과). 발견한 함정: **float 프로퍼티 트랙에 정수 키
   (`0`) 를 넣으면 Godot 4.7 AnimationMixer 가 트랙을 통째로 무시한다** — 새 트랙은 전부 `0.0`.
   다리는 스케일 1 기준 0.1 m 라 720p 에서 한 걸음이 ~7 px 이다. 더 크게 보이길 원하면 트랙 진폭
   또는 애셋 다리 길이가 조정 지점이다.
5. **특수 3종.** 전용 GLB 없음(애셋 인계문대로). 큰 ㅁ = `visual_scale 2.7`(기존), 빠른 ㅇ =
   `glyph_material jamo_special_fast`, 황금 ㅎ = `glyph_material jamo_gold` + 기존 `GoldSparkle`.
   `glyph_material` 은 `Glyph` 표면 0 에만 `set_surface_override_material` 하므로 눈·다리·
   종이 측면은 안 바뀐다. 빠른 ㅇ 의 먹 꼬리 파티클(선택)은 넣지 않았다.
   황금 ㅎ 씬은 이제 `monster_hieut.tscn` 을 상속한다 (옛 Ring+모자 프리미티브 삭제).
6. **환경 장식 교체 지점.** `Arena/Decor` (`ArenaDecor`) 의 `replacements` 에
   `{&"Lantern": <scene>}` 처럼 넣으면 로드 시 슬롯의 프리미티브를 지우고 씬을 슬롯 transform 에
   인스턴스한다. 슬롯 위치는 책상 면 y = −0.6 기준. 프리미티브는 기존 재질 4종만 썼다
   (`arena_paper / arena_wood / arena_edge / jamo_ink`); 새 재질·애셋 없음.
7. **투명 벽.** 4면 벽을 종이 가장자리(±6 / ±3.75) 로 옮겼다. 역할은 프레임 사이 밀림 방지이고
   실제 경계는 여전히 `JamoMonster._clamp_to_arena()` 다. 벽 스폰 위치는 벽 안쪽이라 벽에
   끼는 일 없음 (`qa_p1_map` 49 스폰 + 20마리 필드 overhang 0.000).
8. **15종 밸런스.** 새 9종 visual_scale 1.7~1.9 / click_radius 0.72~0.83 로 기존 6종 범위 안.
   ㅡ 는 높이 0.16 m 로 납작하지만 click_radius 0.72 (구 sphere y=0.4) 가 덮는다. 15종 풀에서
   가중치는 전부 1.0. 모음 4종(ㅓ ㅕ ㅗ ㅜ ㅡ 중 GLIDE 3, SWAY 2)이 늘어 평균 속도는 거의 같다.
9. **몸통 대비.** 캐릭터 GLB 정면이 밝은 종이색(애셋 결정)이라 종이 위에서 눈·다리·측면 그림자로
   읽힌다. 더 진한 대비를 원하면 `arena_paper.tres` 색 또는 애셋 표면 0 색이 조정 지점이다
   (이번 범위 밖).
10. **하네스 `.import` 부수효과.** Godot 실행이 `art/**/*.import` 줄바꿈을 바꾸는 기존 현상은
    되돌렸다. `art/monsters/characters/*.glb.import` 15개는 신규 추적한다 (없으면 매 실행 재생성).
11. **`qa_f5_*` 상수 제거.** `SLAB_HALF` 를 씬의 `PaperTop` 메시에서 읽는다. 맵을 또 바꿔도 이
    세 하네스는 수정 불필요. `qa_p1_core_asset` 만 `SLAB_HALF_EXTENTS (6, 3.75)` 상수를 가진다.
