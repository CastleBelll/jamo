<!-- ASSET03 handoff -->
최신 캐릭터형 자모 인계: [characters/README.md](characters/README.md). 기존 15종은 보존하며 새 GLB는 characters/ 아래에 병존한다.

# JAMO ASSET-02 — 자모 몬스터 15종 / v0.4

기본 자모 15종을 Blender 5.2.1에서 절차적으로 제작했다. Godot 4.7 실제 import와 메시·원점·재질 교체 검증을 통과했다. 작업 시작 시 `git merge main`으로 `3b7a45d`를 fast-forward 반영했다. 게임 연결·커밋·푸시는 하지 않았다.

## 1) 변경 파일 목록

신규 파일만 있다. 기존 문장핵, 사용자 이미지, `art/Untitled.blend`, 게임 씬·스크립트·Resource는 수정하지 않았다.

- `art/monsters/{giyeok,nieun,digeut,rieul,mieum,bieup,siot,ieung,hieut,eo,yeo,o,u,eu,i}.glb`: 기본 자모 15종. 각 1 mesh / 2 surfaces, 내장 단색 재질. 각각의 `.glb.import`는 Godot 기본 import 메타데이터다.
- `art/monsters/build_jamo.py`: 전체 GLB와 미리보기, 통계를 재생성하는 Blender 스크립트.
- `art/monsters/jamo_lineup_3quarter.png` 및 `.import`: 1500×1200, 15종 동시 배열. Orthographic, 카메라 하향각 50°, 기존 Lean -20° 적용. 바닥·조명·배치는 렌더 전용이며 GLB에는 없다.
- `art/monsters/asset_stats.json`: 자모별 삼각형·바이트·치수·권장 보행 및 예산.
- `art/monsters/verify_jamo.gd` 및 `.uid`: 실제 Godot PackedScene, 바닥 원점, 축, 메시 이름, 삼각형, 재질 슬롯, 특수 재질 교체/복원 검증.
- `art/monsters/validate_isolated.ps1`: 임시 독립 프로젝트에 새 GLB와 필요한 재질만 복사해 import/검증. 설치·다운로드 없음.
- `art/monsters/build.log`, `godot_import.log`, `godot_verify.log`, `godot_project_check.log`: 제작과 워크트리 검증 로그.
- `art/monsters/godot_isolated_import.log`, `godot_isolated_verify.log`, `validation_receipt.json`: 폰트 설정 없는 독립 프로젝트에서 import exit 0, verify exit 0, error count 0.
- `art/monsters/README.md`: 본 인계문.
- `materials/jamo_special_fast.tres`: 빠른 ㅇ용 무광 쪽빛 먹. 황금 재질은 기존 `materials/jamo_gold.tres`를 재사용하므로 새로 추가하지 않았다.

최초 단어의 분해는 다음과 같다. 필요한 서로 다른 자모는 **13종**이며 기존 ㅅ과 GLIDE용 ㅡ를 추가해 **15종**이다.

| 단어 | 구성 자모 |
|---|---|
| 검 | ㄱ + ㅓ + ㅁ |
| 불 | ㅂ + ㅜ + ㄹ |
| 돈 | ㄷ + ㅗ + ㄴ |
| 운 | ㅇ + ㅜ + ㄴ |
| 벽 | ㅂ + ㅕ + ㄱ |
| 힘 | ㅎ + ㅣ + ㅁ |

## 2) 검수 절차

작업 위치는 `C:/Users/sjkim/orca/workspaces/JAMO/blender`이다. 아래 수동 Editor 확인은 QA가 수행할 절차이며 제작자가 직접 플레이까지 검증했다는 뜻은 아니다.

1. `art/monsters/jamo_lineup_3quarter.png`를 연다. 기대: 아래 행 왼쪽부터 **ㄱ ㄴ ㄷ ㄹ ㅁ**, 중간 행 **ㅂ ㅅ ㅇ ㅎ ㅓ**, 위 행 **ㅕ ㅗ ㅜ ㅡ ㅣ**가 보인다. ㅂ의 위로 솟은 두 기둥, ㅕ의 두 가로획, ㅎ의 원 위 두 획이 구분되어야 한다. ㅇ·ㅁ·ㅂ·ㅎ의 구멍으로 배경이 보이고, 먹 정면과 갈색 종이 측면이 구분되어야 한다. 미리보기 축소 시 ㅓ/ㅕ, ㅇ/ㅎ를 우선 대조한다.
2. PowerShell에서 `& art/monsters/validate_isolated.ps1`를 실행한다. 다른 설치 위치면 `-Godot '절대경로/Godot_v4.7-stable_win64_console.exe'`를 지정한다. 기대: `ISOLATED_IMPORT_PASS`, receipt의 두 exit 0 및 error_count 0. `godot_isolated_verify.log`에는 `GLYPH_PASS` 15줄과 `JAMO_ASSET_PASS count=15 catalog_triangles=2184 worst_20_plus_core=13020`가 나온다. 이것이 새 애셋에 한정한 오류 0 검증이다.
3. Godot 4.7 Editor에서 이 워크트리의 `project.godot`를 연다. FileSystem의 `art/monsters/bieup.glb`를 더블클릭해 Advanced Import 미리보기를 회전한다. 같은 방법으로 `ieung.glb`, `hieut.glb`, `yeo.glb`를 연다. 기대: 글자 형태가 실제 입체 메시이고 구멍이 뚫려 있으며 누락 텍스처가 없다. `Glyph` 메시 1개와 표면 2개가 있다.
4. **저장하지 않을 임시 씬**에서 기존 몬스터 씬을 인스턴스화하고 Editable Children을 켠다. `VisualRoot/Body/Lean` 아래 기존 BoxMesh 노드들을 임시로 숨기고 해당 GLB를 자식으로 드래그한다. GLB Scale `(1,1,1)`, Rotation `(0,0,0)`, Position `(0,0.0201,0)`으로 놓는다. 기존 Lean X=-20°를 유지한다. 카메라를 Orthogonal, X=-50°로 두고 +Z에서 본다. 기대: 정면 자모가 읽히고 정지 상태 바닥에 대체로 닿는다. 이는 연결 QA 절차이며 이 작업은 게임 씬을 수정하지 않았다.
5. 위 임시 씬에서 AnimationPlayer를 선택하고 자모 권장 `walk_*` 클립을 선택해 타임라인을 스크럽한다. 0%, 25%, 50%, 75%에서 확인한다. 기대: `VisualRoot`의 이동과 `Body`의 squash/기울기가 GLB 전체에 적용되고 획끼리 따로 떨어지지 않는다. ㄷ heavy_step, ㅁ bounce, ㅇ roll, ㅅ light_step, ㄹ sway, ㅡ glide를 각각 확인한다. ROLL은 기존 클립의 좌우 흔들림이며 바퀴처럼 360° 회전하는 애셋 리그는 없다.
6. 같은 임시 씬에서 ㅁ의 VisualRoot 스케일을 일반 대비 1.5배로 바꾼다. ㅇ의 `Glyph` Surface Material Override 슬롯 0에 `jamo_special_fast.tres`를 드래그한다. ㅎ의 슬롯 0에는 기존 `jamo_gold.tres`를 드래그한다. 기대: 큰 ㅁ은 구멍과 획 비율을 유지하고, 빠른 ㅇ은 쪽빛, 황금 ㅎ은 금색으로 보인다. 슬롯 1의 종이 측면은 유지된다. Override를 비우면 기본 먹으로 돌아온다. 임시 씬은 저장하지 않는다.
7. 워크트리에서 Godot console 실행 파일로 `--headless --path . --script art/monsters/verify_jamo.gd`, 이어 `--headless --path . --quit`를 실행한다. 기대: 각각 exit 0, 전자는 15종 PASS. 기존 `res://art/fonts/NotoSansKR-Regular.ttf` 누락 오류는 아래 주의사항과 대조한다. 프로젝트 전체 오류 0이라고 판정하지 않는다.
8. 재생성 검증이 필요하면 `& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art/monsters/build_jamo.py`를 실행한다. 기대: 같은 폴더 GLB 15개·PNG·통계 재생성, `JAMO_BUILD_PASS`. 2번을 다시 실행한다. GLB의 바이너리 바이트 순서는 Blender exporter에 따라 달라질 수 있으나 자모·치수·삼각형·재질 계약은 같아야 한다.

실행한 검증: Blender 생성 및 최종 PNG 육안 판독, 워크트리 Godot import, 15개 PackedScene 검증, 프로젝트 시작, 독립 Godot 프로젝트 import/검증. 독립 검증은 오류 0이다. 보행 타임라인 수동 스크럽·최종 Wave 플레이·FPS 측정은 DEV 연결 이후 QA가 수행한다.

## 3) 주의/보류 사항

### 자모별 권장 MotionProfile와 예산

| 자모 | GLB 이름 | 삼각형 | 권장 MotionProfile |
|---|---|---:|---|
| ㄱ | giyeok | 68 | SWAY (기존 데이터 유지) |
| ㄴ | nieun | 68 | HEAVY_STEP |
| ㄷ | digeut | 92 | HEAVY_STEP |
| ㄹ | rieul | 140 | SWAY |
| ㅁ | mieum | 88 | BOUNCE |
| ㅂ | bieup | 180 | HEAVY_STEP |
| ㅅ | siot | 80 | LIGHT_STEP |
| ㅇ | ieung | 512 | ROLL |
| ㅎ | hieut | 472 | BOUNCE |
| ㅓ | eo | 88 | SWAY |
| ㅕ | yeo | 132 | SWAY |
| ㅗ | o | 88 | GLIDE |
| ㅜ | u | 88 | GLIDE |
| ㅡ | eu | 44 | GLIDE |
| ㅣ | i | 44 | SWAY (기존 upright를 유지해도 메시 호환) |

- 예산은 **1개당 최대 1,000삼각형, 메시 1개, 표면 2개**로 잡았다. 20마리 기준 최대 20,000삼각형 + 문장핵 2,780으로 기하 비용을 제한하고 파티클에 여유를 남기는 기준이다. 실제 최댓값은 ㅇ의 512이며, **20×512+2,780=13,020삼각형**, 몬스터 40표면 + 문장핵 9표면 = 49표면이다. 모든 15종을 한 번씩 쓰면 총 2,184삼각형이다. 그림자·패스별 추가 draw 및 파티클 비용은 이 수에 포함하지 않았다.
- 모델에는 실시간 광원·리그·텍스처·투명도·애니메이션이 없다. 저폴리곤의 두꺼운 먹 획과 눌린 한지 측면으로 문장핵의 먹·종이·책상 톤을 맞췄다. 외부 애셋·폰트·생성 서비스는 사용하지 않았다.
- **60 FPS는 아직 실측하지 않았다.** 최종 Wave 씬의 20마리, 문장핵, 실제 파티클, 그림자, 목표 기기 해상도에서 CPU/GPU 프레임 시간을 측정해야 한다. 삼각형 예산 통과가 FPS 보장은 아니다.

### 연결 계약

- GLB를 **`VisualRoot/Body/Lean`의 자식**으로 꽂는다. 기존 BoxMesh 획들을 대체하되 AnimationPlayer 경로는 보존한다. 메시 이름은 모든 파일에서 **`Glyph`**이며 루트 이름에 의존하지 말고 `find_child("Glyph", true, false)`를 사용한다. `_collect_body_meshes()`의 재귀 탐색과 호환되는 MeshInstance3D다.
- Godot 단위 1, Y-up, **정면 +Z**, X 좌우. GLB local scale 1, rotation 0, 메시 origin은 **바닥/가로 중심 `(0,0,0)`**이다. 바닥 최저 Y는 전종 0, 두께는 0.11 (Z=-0.055..0.055). 일반 자음 높이 0.6, ㅎ 0.6225, 세로 모음 약 0.508~0.554이며 **ㅡ는 본래 납작한 0.092**다. 모음별 원점은 외곽 폭의 중심이며 획 무게 중심은 아니다. 정확한 폭·높이는 JSON 참고.
- 기존 `Lean.rotation.x=-20°`가 두께 때문에 정지 시 약 0.019만큼 바닥을 파고들게 하므로 **GLB 자식 local position.y=0.0201**을 출발값으로 권장한다. 이 값은 애니메이션 없는 정지 상태 기준이며 보행/hit 클립의 기존 수직 이동·squash는 따로 존재한다. Lean 자체를 수정하거나 원점을 글자 중앙으로 옮기지 않는다.
- 기존 `monster_data.visual_scale`이 VisualRoot에 적용되므로 GLB에 다시 배율을 굽지 않는다. 일반 1.6~1.8배에서 높이 약 0.8~1.12로 문장핵 1.96보다 작다. 좁은 ㅣ·납작한 ㅡ도 클릭 영역을 메시 외곽과 동일하게 줄이지 말고 게임의 click_radius를 유지·검수한다. ㅓ/ㅕ/ㅣ의 보행 성격과 최종 클릭 난이도는 DEV에서 조정한다.
- 슬롯 **0=`Jamo_Ink`** (정면·뒷면), **1=`Jamo_Pressed_Hanji_Edge`** (측면·베벨). 두 슬롯 모두 GLB에 내장된 StandardMaterial3D로 실제 import 확인했다. 특별 색상은 `set_surface_override_material(0, material)`로 지정한다. 인스턴스 피격색은 공유 원본을 바꾸지 말고 override 또는 duplicate를 쓴다. `material_override`는 두 표면을 모두 덮으므로 종이 측면까지 동일색이 되는 동작이다.
- 문장핵으로 이동할 때 메시를 이동 방향으로 yaw 회전시키지 않는다. 현재 게임은 고정 카메라에서 정면을 유지하는 보행 구조이며, 이 자모도 +Z 정면으로 읽히도록 제작했다. 완전 옆면/뒷면에서 글자를 읽게 만드는 billboard나 별도 리그는 제공하지 않는다.

### 특수 3종 — 별도 메시 없음

| 특수종 | 재사용 기본 GLB | 차별화 / DEV 연결 |
|---|---|---|
| 큰 ㅁ | mieum.glb | 일반 visual_scale 1.8 대비 기존 2.7(1.5배), 기존 heavy_bounce 프로필. 기본 두 재질 유지. HP·판정 반경은 기존 Resource가 소유하며 애셋에서 변경하지 않음. |
| 빠른 ㅇ | ieung.glb | 기존 visual_scale 1.5, roll_fast 프로필. 슬롯 0에 신규 jamo_special_fast.tres. 선택적으로 작고 짧은 먹 꼬리 입자 4~6개/수명 약 0.2초를 DEV에서 추가할 수 있으나 필수 아트나 이번 납품 파티클은 아님. |
| 황금 ㅎ | hieut.glb | 기존 visual_scale 1.6, 기존 golden_hieut의 GLIDE 유지. 슬롯 0에 기존 jamo_gold.tres, 기존 gold_sparkle.tres로 작은 반짝임 재사용 가능. 강한 bloom/새 조명 불필요. 희귀도·보상은 게임 Resource가 소유. |

- 신규 특수 재질은 빠른 ㅇ 한 개뿐이다. Scale/Material만으로 이미 구분되며 파티클은 연결 측 선택 사항이다. 특수 전용 GLB·별도 아트를 만들지 않았다.
- 기존 `NotoSansKR-Regular.ttf` 누락으로 **워크트리 import는 exit 1**이며 폰트 오류 두 개가 나온다. 새 15종 import 자체는 완료되었고 워크트리 메시 검증/프로젝트 시작은 exit 0이다. 독립 프로젝트에서는 **import exit 0 + verify exit 0 + ERROR 0**으로 새 애셋 오류와 기존 설정 오류를 분리했다. 누락 폰트는 규칙 §7.1의 기존 이슈이며 수정 범위 밖이다.
- `game-dev` CLI와 `$code-review` 스킬은 설치 경로에서 발견되지 않았다. 도구 설치 없이 사용자가 지정한 Blender/Godot 직접 경로를 사용했고, 다중 관점 자동 리뷰 대신 직접 실루엣·규모·재질·원점·범위·import 계약을 검토했다.
- Godot가 기존 사용자 이미지 `.import`의 줄바꿈을 바꾼 부수 효과는 원래 CRLF로 되돌렸다. 원본 이미지 바이트는 건드리지 않았다. `validate_isolated.ps1`는 임시 프로젝트를 고유 이름으로 생성해 보존하고 삭제하지 않는다.

최종 메인 워크트리 DEV 작업: GLB 연결, 신규 자모 데이터/스폰 등록, 클릭/충돌 범위와 시각 크기 확인, 특수 재질 적용, 전체 Wave에서 보행 판독성 및 60 FPS 검증.
