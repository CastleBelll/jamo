# JAMO P1-DEV-3 — 문장핵 애셋 연결 + P1 LOW 이월 정리 — DEV 완료 보고

검증 환경: Godot 4.7.stable, Windows 11, Intel UHD Graphics 770 / Vulkan.
`art/` 아래 파일은 읽기만 했다 (Godot 이 재실행마다 `.import` 두 개의 줄바꿈을 바꾸는데,
원래 체크아웃 형식으로 되돌려 두었다).

---

## 1) 변경 파일 목록

### 프로덕션
```
scenes/objective/sentence_core.tscn   VisualRoot 아래 Pillar/Cap 프리미티브 삭제 →
                                      VisualRoot/Model = art/objective/sentence_core.glb 인스턴스
                                      (scale 0.75, editable children). hit 애니메이션에 트랙 2 추가:
                                      VisualRoot/Model/CorePaper:material_override 를 0s 에
                                      core_hit.tres, 0.18s 에 null (discrete). reach_radius 0.9 → 1.1.
                                      jamo_ink/jamo_gold ext_resource 제거 (다른 씬은 그대로 씀).
materials/core_hit.tres               신규. 피격 플래시 재질 (진사홍 + 약한 emission).
scenes/world/game_world.tscn          SentenceCore.position z -2.4 → -2.2 (책 뒷모서리를 종이 위에 두려고).
scripts/objective/sentence_core.gd    주석 2줄만 갱신 (로직 변경 없음. visual_root 너머를 여전히 참조 안 함).
scripts/monsters/spawn_manager.gd     :358 String(monster.monster_data.id) — 삼항 타입 불일치 경고 제거.
```

### 테스트 / 문서
```
tests/qa_p1_core_asset.gd / .tscn     신규 창 모드 하네스 (모델 파츠·슬랩 안 배치·피격 override·
                                      카메라 shake·Wave 1~5 실클릭 플레이·20마리 FPS). 스크린샷 14장.
tests/qa_artifacts/p1/core_asset/*.png  00 idle / 01 hit flash / 02 recovered / 10~60 wave start /
                                      35~65 wave core hit / 95 full field
docs/DEV_ROADMAP.md                   P1 S1 문구, "P1 에서 P2 이후로 넘긴 것" 문장핵 항목,
                                      이월 LOW 체크 갱신
tests/qa_artifacts/p1/DEV_HANDOFF_3.md  이 보고서
```

`resources/upgrades/max_energy.tres` — 3절 4번 참조.

---

## 2) 검수 절차

### A. 자동 (전부 exit 0. **한 번에 하나씩** 돌릴 것 — 세이브 파일 공유)

1. `godot --headless --path . --quit` → NotoSansKR 폰트 누락 2줄 외 에러 0.
2. `godot --path . res://tests/qa_p1_core_asset.tscn` (창 모드, 약 2분) → 기대:
   - `world bounds: pos=(-0.95, 0.0, -2.83) size=(1.905, 1.47, 1.26)`,
     `footprint corner |x|+|z| max 3.78 of 3.96` (책이 종이 슬랩 안).
   - `-- one hit on the core` 블록 FAIL 0: override 가 붙고, 애니메이션 끝에 풀리고,
     BookPages 공유 재질은 그대로, 카메라 pivot 이 움직였고, HP 20 → 19.
   - wave log 1~5 전부 `cleared true`, 6 에서 `false` (문장핵 0).
   - `20 alive: avg 60.0 FPS, min 60.0`.
   - 마지막 줄 `OK - the 문장핵 model is in play, flashes on a hit, and Wave 1~5 clear around it.`
3. 헤드리스 7종 `test_state_split` / `test_run_flow` / `test_wave_combat` / `test_monster_state` /
   `qa_p1_stall` / `qa_p1_negctl` / `qa_p1_lockhunt` → 전부 exit 0, 마지막 줄 `OK - ...`.
   어느 로그에도 `SpawnManager: wave N finished spawning ... never resolved` 없음.
4. 창 모드 7종 `qa_p0_flow` / `qa_f7_title` / `qa_f7_art` / `qa_f8_labels` / `qa_f8_focus_all` /
   `qa_f8_resize` / `qa_p0_plates_all` → 전부 exit 0. `qa_f7_art` letterbox WARN 은 기존 항목.

### B. 눈으로 — 문장핵 모습 (ziva-godot 또는 `godot --path .`)

5. 세이브 삭제 후 `RUN 시작`. → 기대: 슬랩 **위쪽 꼭짓점 안쪽**에 펼친 고서가 놓이고 그 위에
   세로로 선 종이에 `문`(ㅁ+ㅜ+ㄴ) 먹 글씨, 오른쪽 앞에 붉은 인장. 책 뒷모서리가 종이 밖으로
   나가지 않는다. 실린더+큐브는 없다. (`core_asset/00_core_idle.png` 와 같은 모습)
6. `scenes/objective/sentence_core.tscn` 을 에디터로 연다. → 기대: `VisualRoot/Model` 아래
   `Binding / BookPages / BindingThread / SentenceInk / CorePaper / CoreInk / Seal` 7개
   MeshInstance3D 가 보인다(editable children). `SentenceCore` Inspector 에 `Reach Radius 1.1`,
   `Hit Shake Strength 0.06` 등 export 가 그대로. `AnimationPlayer` → `hit` 를 열면 트랙 3개
   (`VisualRoot:scale`, `VisualRoot:position`, `VisualRoot/Model/CorePaper:material_override`).
   재생 버튼을 누르면 뷰포트에서 종이가 **붉게 번쩍이며 책이 납작해졌다 돌아온다**.

### C. 눈으로 — 피격 표현 (반드시)

7. RUN 시작 후 Wave 1 은 클릭하지 않고 몬스터 5마리를 그대로 둔다. 첫 몬스터가 책에 닿는
   순간을 본다. → 기대: **(a)** 서 있는 종이 `문` 부분이 진사홍으로 0.2초 번쩍, **(b)** 책 전체가
   옆으로 넓어지며 납작해졌다가 0.3초 안에 원형 복귀, **(c)** 화면이 짧게 흔들림(카메라 shake),
   **(d)** 상단 `문장핵 20 / 20` → `19 / 20`. 번쩍임이 끝나면 종이는 원래 미색으로 돌아오고
   **책의 펼친 페이지 색은 번쩍이는 동안에도 바뀌지 않는다**(공유 재질 미오염).
   (`core_asset/01_core_hit_flash.png` = 번쩍이는 순간, `02_core_hit_recovered.png` = 복귀)
8. 연달아 두 마리가 거의 동시에 닿을 때 → 기대: 두 번째 hit 이 첫 번째를 끊고 다시 번쩍인다.
   끝난 뒤 override 가 남아 붉게 고정되는 일 없음 (7과 같은 미색).
9. Wave 3~5 에서 에너지 0 이 된 뒤 누수가 들어올 때마다 7 이 반복된다.
   (`core_asset/35_wave3_core_hit.png` / `45_` / `55_`)

### D. 눈으로 — 접근 경로 / 도달 판정

10. Wave 1~2 를 클릭으로 전멸시키며 본다. → 기대: 앞·좌·우 스폰 지점에서 오는 몬스터가 책을
    돌아가거나 책 위로 겹쳐 서지 않고, **책 앞·옆 가장자리에 닿는 위치**에서 사라진다
    (`reach_radius 1.1` = 책 반폭 0.95 + 0.15). 책 뒤로 파고드는 개체 없음.
11. Wave 5 까지 진행 → 기대: 어느 Wave 도 생존자가 남아 멈추지 않고 `WAVE N CLEAR` → 다음 Wave.
    잠김 0. 문장핵 0 이 되면 결과 화면 → 메인 허브.

### E. 이월 정리

12. 에디터에서 `scripts/monsters/spawn_manager.gd` 를 연다. → 기대: 358행 근처
    `Values of the ternary operator are not mutually compatible` 경고 없음.
13. 상점 `영구 업그레이드` → 기대: `최대 에너지 Lv.0 10 → 11 6 G` (값 미변경, 3절 4번).
    `문장핵` 행은 **없다** (Core HP 트랙은 P5).

---

## 3) 주의 / 보류 사항

1. **스케일·위치 근거.** GLB 는 2.54 × 1.96 × 1.68 (원점 바닥 중앙, 정면 +Z). 0.65 로 두면
   기존 z = -2.4 에서 슬랩 안에 들어가지만 화면에서 몬스터(ㅇ 지름 ~1.0 unit)와 비슷한 크기라
   "지켜야 할 것" 으로 읽히지 않았다. 0.75 + z = -2.2 로 하면 책 뒷모서리 |x|+|z| = 3.78
   (슬랩 3.96) 로 여유 0.18 을 유지하면서 책 폭 1.9 / 높이 1.47 이 된다. 0.8 이상은 -2.2 에서도
   모서리가 종이 밖으로 나간다. z 를 0.2 앞당긴 만큼 몬스터 보행 거리가 ~0.2 m 줄지만 Wave 곡선
   (수/간격/HP) 은 손대지 않았고 실플레이 표는 이전 QA 와 같은 모양이다
   (W1~2 전멸, W3 부터 누수, W5 생존, W6 실패). 스케일은 `VisualRoot` 가 아니라 `Model` 에
   두었다 — `hit` 애니메이션이 `VisualRoot:scale` 을 절대값(1 → 1.18/0.82 → 1)으로 키하기 때문.
2. **피격 표현은 씬 데이터로만 연결했다.** README 3절의 "material_override 교체" 를 그대로
   따르되, 스크립트가 `find_child("CorePaper")` 를 하는 대신 `hit` 애니메이션의 discrete value
   트랙이 `VisualRoot/Model/CorePaper:material_override` 를 씌우고(0s) 벗긴다(0.18s).
   원본 재질을 `duplicate()` 해 색을 바꾸는 대신 별도 재질 `core_hit.tres` 를 올리므로 공유 재질
   오염이 구조적으로 없다. **대가**: 애셋 워커가 GLB 를 다른 계층/이름으로 재수출하면 트랙 경로가
   끊긴다 (에디터가 경고). 그 경우 `sentence_core.tscn` 의 트랙 경로만 고치면 된다.
   `CoreInk` 는 건드리지 않았다 — 종이만 붉어지고 먹 글씨는 남아야 `문` 이 계속 읽힌다.
3. **HP 구간별 손상 표현은 넣지 않았다.** 애셋에 균열/파손 단계 모델이 없고(README 3절),
   지금 할 수 있는 것은 `CoreInk` 숨김이나 종이 색 어둡히기 정도인데 어느 쪽도 "손상" 으로 읽히기
   보다 애셋 결함처럼 보일 위험이 있어 §41 VFX 와 함께 다루는 편이 맞다고 판단했다.
   구조는 열려 있다: HUD 처럼 `SignalBus.core_hp_changed` 를 받아 단계별 애니메이션을 재생하면 된다.
4. **`max_energy.tres`**: 현재 값은 이미 11~20 (P1 커밋 4397951 에서 v0.3 의 21~30 을 기본 10
   기준으로 옮긴 것, 레벨당 +1). v0.4 에는 이 트랙의 값 표가 없다(§7.1 Max Energy 10, §13.1 트랙
   이름만). 총지휘자에게 `ask`(msg_3bbb63f76993) 로 물었으나 25분간 답이 없어 **기본안 A: 값 유지**로
   마감했다 — 이미 "Max Energy 10 기준" 을 만족하며, 다른 곡선(예: v0.3 의 +50% 비율)을 원하면
   10개 값만 바꾸면 되고 가격은 P5 에서 같이 본다. 로드맵 이월 항목은 이 근거로 닫았다.
   **`resources/upgrades/max_energy.tres` 는 이번에 수정하지 않았다.**
5. **`reach_radius` 0.9 → 1.1.** 책 반폭 0.95 / 반깊이 0.63 이라 0.9 는 옆에서 오는 개체가 책
   안으로 파고든 뒤에야 도달 판정이 났다. 1.1 이면 옆에서 0.15, 앞에서 0.47 여유. 반경을 키우는
   방향은 안전하다 — 모든 몬스터의 walkable diamond 가 이미 0.9 안쪽까지 닿는 것이 P1 QA 에서
   확인됐고, 반경이 커지면 더 일찍 닿을 뿐이다. `qa_p1_lockhunt` 는 `core.reach_radius + 0.3`
   을 동적으로 읽어 그대로 통과한다. `@export_range(0.1, 3.0, 0.05)` 노출 유지.
6. **FPS**: 20마리 + 새 모델(2780 삼각형, 9 surface, 그림자 포함) 에서
   `avg 60.0 / min 60.0 / low 1 pct 60.0` (Intel UHD 770, Forward+). 두 번 측정 모두 같음.
   `core_asset/95_full_field_20.png`. 결과 카드는 숨겼지만 RUN 종료 뒤의 어둡힘 레이어는 남아
   있다(증거 목적엔 지장 없음).
7. **카메라 shake 유지.** `take_hit()` 는 그대로다: `RunState.damage_core` → `hit` 재생 →
   `camera_rig.shake(0.06, 0.2)`. 하네스가 hit 직후 `ShakePivot.position != 0` 을 단언한다.
8. **`HitAnchor`(0, 1.1, 0)** 는 참조하는 코드가 없어 그대로 두었다. 새 모델의 `문` 종이 중심은
   y ≈ 0.95 (scale 0.75) 라 나중에 VFX 앵커로 쓰려면 위치를 맞추면 된다.
9. `art/objective/*.import` 두 파일은 Godot 이 실행마다 LF 로 재저장한다. 내용 변화 없음,
   `git checkout -- art/objective/*.import` 로 되돌려 두었다. `art/Untitled.blend*` 는 여전히
   무관한 untracked 파일.
10. 기존 항목 그대로: NotoSansKR 폰트 누락 2줄, `wave_controller.gd:60` 불필요한 `await`,
    `qa_f7_art` letterbox WARN. `godot --headless --editor --path . --quit` (uid 생성용 1회) 에서
    `addons/ziva_agent` GDExtension DLL 복사 실패 에러 4줄이 났다 — ziva 애드온 환경 이슈로
    이번 변경과 무관하며 `--headless --path . --quit` 에는 나오지 않는다.
11. 이번 사이클 자동 실행 결과 (전부 한 번에 하나씩): `qa_p1_core_asset` + 헤드리스 7종 + 창 모드
    7종 = 15개 전부 exit 0 / FAIL 0, `SpawnManager: wave ... never resolved` 0건.
