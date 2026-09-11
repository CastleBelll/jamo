# JAMO ASSET-04 — 책상 세계 전투 환경 인계

Blender 5.2.1 라이브 MCP에서 바닥 3개 크기, 장식 4개, 책상 배경을 제작했다. Godot **4.7.stable.official.5b4e0cb0f** 독립 import 및 실제 PackedScene 검증은 exit 0 / 오류 0이다. 시작 시 `git merge main`으로 `4d1ca57 → b21382e` fast-forward했다. 기존 자모와 문장핵은 합성 렌더에만 읽어 사용했다.

## 1) 변경 파일 목록

모든 신규 파일은 `art/arena/` 아래에 있다. `materials/` 신규 파일은 없으며 PBR 재질·색 텍스처는 각 GLB에 내장했다.

- `arena_square_8.glb`, `arena_wide_10x8.glb`, `arena_large_12x9.glb`: 각각 종이 전투 면적 8×8, 10×8, 12×9의 바닥. **셋 중 하나만 사용**한다.
- `prop_book_stack.glb`, `prop_lantern.glb`, `prop_brush_inkstone.glb`, `prop_potted_plant.glb`: 개별 배치 가능한 장식 4종.
- `desk_background.glb`: 32×17.993의 이어진 목제 책상 상판. 원점에서 윗면 높이 0, 두께 0.24.
- `hanji_color.png`, `walnut_color.png`: 직접 계산한 512×512 반복 가능 색상 텍스처 원본. GLB를 배치할 때 PNG를 별도로 복사할 필요는 없다.
- `desk_world_3quarter.png`: 1600×1000, 50° 하향 직교 합성. 바닥·장식 4종·기존 자모 8마리·0.75배 문장핵이 함께 보인다. 게임 실행 화면이 아니라 Blender 구성 검토 렌더다.
- `mcp_viewport_initial.png`, `mcp_viewport_final.png`: `mcp__blender__get_viewport_screenshot`이 반환한 이미지 원본. 초기 및 책 표지 라벨/종이 모서리 수정 후 라이브 뷰포트 증거다.
- `build_desk_world.py`: 형상, 색상 텍스처, GLB, 통계, 합성 렌더 재생성 스크립트.
- `asset_stats.json`: GLB별 SHA-256, 바이트 크기, Godot 좌표 범위, 메시/표면/삼각형 수 및 예산.
- `verify_arena.gd`, `validate_isolated.ps1`: 게임에 연결하지 않는 독립 검증 도구.
- `godot_version.log`, `godot_isolated_import.log`, `godot_isolated_verify.log`, `validation_receipt.json`, `godot_project_check.log`: 실행 증거.
- `README.md`: 본 인계문.

기존 `art/ui/**`, `art/objective/**`, `art/monsters/**`, `art/Untitled.blend`, 게임 `scenes/`, `scripts/`, `resources/`는 수정하지 않았다. 사용자 Blender 파일을 저장하지 않았으며 새 메모리 씬 `JAMO_ASSET04*`에서 작업했다. 커밋·푸시는 하지 않았다.

## 2) 검수 절차

작업 폴더는 `C:/Users/sjkim/orca/workspaces/JAMO/blender`다.

1. `desk_world_3quarter.png`를 이미지 뷰어에서 연다. 기대: 밝은 종이 바닥 아래에 연속된 나무 책상이 보이고, 왼쪽 책더미와 등잔, 오른쪽 화분과 벼루가 종이 전투 영역 밖에 있다. 후방 문장핵과 자모 8마리가 분리되어 읽힌다. 종이 접힘 선은 희미하고, 커다란 먹 글자나 장식이 이동 경로를 덮지 않는다.
2. `mcp_viewport_initial.png`와 `mcp_viewport_final.png`를 비교한다. 기대: 같은 라이브 Blender 구성에서 최종 책더미의 윗표지 라벨이 보인다. 뷰포트는 형상 확인용 solid shading이며 최종 조명·텍스처 판단은 1번 렌더로 한다.
3. PowerShell에서 `& art/arena/validate_isolated.ps1`를 실행한다. 다른 Godot 설치 위치는 `-Godot '절대경로'`로 지정한다. 기대: `ISOLATED_IMPORT_PASS`, receipt의 import_exit=0 / verify_exit=0 / error_count=0, 로그에 `ARENA_CHECK` 8줄과 `ARENA_PASS failures=0 active_triangles=2885`. 검사는 내장 텍스처, 불투명 재질, 원점, 실제 import 경계, 삼각형/표면 수, 실시간 광원·충돌체 부재를 확인한다.
4. Godot 4.7 Editor에서 3번 receipt의 `validation_project/project.godot`를 연다. FileSystem의 `art/arena/arena_wide_10x8.glb`를 더블클릭하여 Advanced Import 미리보기에서 확대·회전한다. 기대: 종이 윗면, 어두운 얇은 목제 테두리, 우측 후방의 작은 접힌 모서리가 있고 누락 텍스처가 없다. 나머지 GLB 7개도 열어 통계 표의 메시 1개씩을 확인한다.
5. 저장하지 않을 임시 3D 씬에 `arena_wide_10x8.glb`를 드래그한다. Transform Scale을 `(1.2,1,1.1)`로 바꾼다. 기대: 바닥이 12×8.8로 넓어지고 두께는 그대로다. 책상·장식은 바닥의 자식으로 묶어 함께 늘리지 않는다. Scale을 `(1,1,1)`로 복원한다.
6. 같은 임시 씬에 아래 배치 표대로 책상과 장식 4개를 드래그한다. 카메라는 Orthogonal, 위치 `(0,15.49,13)`, 회전 X `-50°`, Keep Aspect `Keep Width`, Size `15.6`부터 맞춘다. 기존 문장핵을 `(0,0,-2.55)` / Scale 0.75, 자모를 종이 위 여러 위치에 놓고 게임의 Lean X=-20° 및 높이 보정 +0.0201을 사용한다. 기대: 장식 경계가 종이에 들어오지 않고 카메라에서 자모를 가리지 않는다. 최종 HUD·해상도에서 카메라 크기는 DEV가 조정한다.
7. 재생성 확인은 **라이브 Blender MCP** `execute_blender_code` 또는 Blender Python Console에서 아래 코드를 실행한다. 기대: 새 `JAMO_ASSET04*` 메모리 씬이 생기고 GLB 8개, 텍스처 2개, 통계가 재작성되며 타이머 렌더가 끝나면 PNG가 갱신된다. MCP `get_viewport_screenshot`으로 다시 눈으로 확인하고 3번을 재실행한다. 기존 `.blend`는 저장하지 않는다.
8. `godot --headless --path . --quit`를 실행한다. 기대: 종료 코드 0. 현재 저장소의 기존 NotoSansKR-Regular.ttf 누락 오류 2건은 아래 보류 사항과 일치해야 한다. 이 작업의 독립 애셋 import에는 오류가 없어야 한다.
9. 메인 DEV 연결 후 실제 RUN의 20마리·문장핵·VFX·그림자·HUD를 켜고 목표 해상도에서 Godot Profiler의 CPU/GPU 프레임 시간을 측정한다. 기대 목표: 16.67 ms 이하/60 FPS 및 플레이 영역을 가리는 장식 없음. 이는 최종 게임 연결 QA이며 이번 애셋 제작에서 실측했다고 주장하지 않는다.

```python
p = 'C:/Users/sjkim/orca/workspaces/JAMO/blender/art/arena/build_desk_world.py'
exec(compile(open(p, encoding='utf-8').read(), p, 'exec'), {'__file__': p})
```

실행 완료: 1~2번 육안 확인, 3번 실제 Godot import/계약 검증, 7번 MCP 제작·수정·렌더 반복, 8번 프로젝트 시작. 4~6번 수동 에디터 조작과 9번 실제 전투 성능은 QA 절차다.

## 3) 주의/보류 사항

### 크기와 게임 연결 계약

단위는 Godot 1 unit, Y-up, 정면 +Z. 각 GLB는 루트 원점 0, 메시 1개이고 충돌체·라이트·스크립트·애니메이션을 포함하지 않는다. 파일별 하위 노드 이름의 `.001` 같은 Blender 중복 접미사는 API가 아니다. 루트 전체를 배치하고 필요하면 `MeshInstance3D` 타입으로 메시를 찾는다.

| 바닥 | 종이 전투 면적 | 목제 외곽 | 기존 5.6×5.6 대비 면적 |
|---|---|---|---|
| arena_square_8 | 8×8 | 8.24×8.24 | 2.04배 |
| arena_wide_10x8 | 10×8 | 10.24×8.24 | 2.55배 |
| arena_large_12x9 | 12×9 | 12.24×9.24 | 3.44배 |

- **기본 추천은 10×8, Y 회전 0**이며 합성 렌더도 이 구성이다. 기존 Arena의 Y=45° 회전을 그대로 부모에 두면 바닥도 회전한다. 기존 마름모 이동 클램프를 유지하려면 square_8에 회전 45°를 적용하고 카메라·문장핵·스폰·장식을 새 외곽 기준으로 다시 배치한다. 직사각형 바닥과 기존 마름모 이동 로직이 자동으로 일치하는 것은 아니다.
- 종이 평면 Y=0, 목제 밑면 Y=-0.25. 희미한 괘선 최고 Y=0.0015, 우측 후방 0.23×0.23 영역의 접힌 모서리 최고 Y=0.047이다. 이동 가능 영역은 종이 외곽에서 최소 0.3 단위 안쪽을 권장하며 충돌과 스폰 클램프는 DEV가 정한다.
- 폭·깊이 독립 스케일 `(목표폭/기준폭, 1, 목표깊이/기준깊이)`를 사용한다. 0.8~1.25배 범위는 디테일 왜곡이 작다. 그 이상은 재생성 스크립트 상단 입력 `ARENA_SIZES`에 새 `(파일명, 폭, 깊이)`를 추가해 만든다. 반복 가능한 색 텍스처이지만 **바닥 GLB 자체를 여러 개 타일 배치하는 방식은 아니다**.
- 커스텀 크기 재생성 시 기본 10×8 항목을 남기면 기본 합성 구도가 유지된다. 커스텀 크기의 장식 배치와 합성 구도는 별도로 조정한다. 생성 함수는 새 메모리 씬을 만들며 이전 제작 씬을 삭제하지 않는다. 형상과 픽셀 생성은 고정 입력에 대해 재현되지만 Blender 데이터 이름 접미사 때문에 GLB 바이트 해시는 재실행마다 달라질 수 있다.

### 10×8 바닥 기준 권장 배치 — Godot 좌표

| 파일 | 위치 (X,Y,Z) | Y 회전 | 역할 |
|---|---|---|---|
| arena_wide_10x8 | (0,0,0) | 0 | 플레이 면 |
| desk_background | (0,-0.255,0) | 0 | 연속 책상 |
| prop_book_stack | (-6.12,-0.255,-3.10) | -5.73° | 후방 왼쪽 |
| prop_lantern | (-5.90,-0.255,-0.88) | 0 | 왼쪽 가장자리 |
| prop_potted_plant | (6.02,-0.255,-3.50) | 0 | 후방 오른쪽 |
| prop_brush_inkstone | (6.15,-0.255,0.10) | -5.73° | 오른쪽 가장자리 |

장식의 바닥 원점은 Y=0이므로 책상 위에 놓을 때만 Y=-0.255를 적용한다. 폭이 W로 바뀌면 좌우 위치 X에 각각 ±(W-10)/2를 더하고 종이 경계와 0.3단위 이상 여백을 확인한다. 깊이·회전 변경 시 표를 고정값으로 재사용하지 말고 화면 가림을 재검사한다. 바닥/책상/장식은 별도 형제 노드로 두어 스케일을 분리한다. 등잔은 발광 재질만 있고 실시간 조명이나 그림자 투사를 추가하는 노드가 없다.

### 배경, 성능 예산, 출처

기존 `art/ui/game_bg.png`(1672×941)는 석조 공중 성곽 그림이므로 책상 세계에 사용하지 않았다. `title_bg.png`의 갈색 책 표지·황동 등잔·화분·종이·나무 색을 참고해 직접 제작했다. 외부 다운로드, 폰트, PolyHaven, Sketchfab, Hyper3D, 유료 생성 서비스를 쓰지 않았다.

| 활성 구성 | 삼각형 | 메시 | 표면 |
|---|---:|---:|---:|
| 선택한 바닥 1개 | 233 | 1 | 4 |
| 책더미 | 988 | 1 | 5 |
| 등잔 | 564 | 1 | 3 |
| 붓과 벼루 | 432 | 1 | 4 |
| 화분 | 272 | 1 | 3 |
| 책상 배경 | 396 | 1 | 1 |
| **환경 합계** | **2,885** | **6** | **20** |

환경 예산은 **4,000삼각형 이하**로 잡았다. 기존 최대 전투 18,460삼각형에 약 22% 이내만 더하는 배경을 목표로 했으며, 실제 증가는 **15.63%**, 합계 **21,345삼각형**이다. 기존 기록의 최대 20마리 기준은 가장 무거운 ㅇ 784삼각형×20+문장핵 2,780이며, 개체마다 실제 수치가 다르다. 환경 표면 20개는 추가 드로우 비용이며 자동으로 한 번에 배칭된다고 가정하지 않는다.

책상은 396삼각형/1표면, 불투명 재질 1개로 공간을 채운다. 모든 색상 맵은 512²이며 고해상도 배경 이미지·투명 레이어·파티클·실시간 라이트는 없다. GLB에 내장된 텍스처는 파일 간 중복될 수 있다. 활성 구성의 색상 맵 참조 5개를 각자 RGBA8+밉으로 잡으면 약 6.7 MiB이며 엔진 압축/공유 방식에 따라 달라진다. 최적화가 필요하면 DEV에서 공유 재질을 추출하고 배경 및 장식의 그림자를 먼저 끈다. **60 FPS 보장은 하지 않으며 최종 전투에서 실측해야 한다.**

### 검증 한계와 도구

- 독립 프로젝트는 Godot 4.7 import/verify 오류 0이다. 원래 프로젝트 시작은 exit 0이나 기존 `res://art/fonts/NotoSansKR-Regular.ttf` 누락 오류 2건이 남는다. 신규 애셋은 폰트를 사용하지 않는다.
- `game-dev` CLI는 미설치여서 태스크에 명시된 Blender MCP/Godot 직접 검증을 사용했다. 설치된 `$code-review` 스킬은 검색에서 찾지 못했으며 파일 범위·원점·경계·예산·재질·재생성·게임 연결 계약을 직접 검토했다.
- 첫 라이브 실행에서 한국어 Blender의 World 노드 표시명 때문에 오류가 발생했으며 노드 타입으로 찾도록 수정했다. 뷰포트 카메라 전환 시 다른 screen의 area를 참조한 오류도 현재 window로 제한하여 해결했다. MCP 연결 자체는 정상 유지됐다.
- 합성 렌더의 조명은 제작용이다. 최종 게임 라이팅·카메라/HUD·그림자·스폰·충돌·문장핵 배치·VFX 연결은 메인 DEV 사이클 범위다.
