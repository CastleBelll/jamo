# JAMO ASSET-03 인계 — 캐릭터형 자모

Blender 5.2.1 라이브 MCP에서 15종을 제작하고 뷰포트와 3/4 직교 렌더를 확인했다. Godot 4.7 독립 import 및 실제 PackedScene 검증은 exit 0 / 오류 0이다. 시작 시 `git merge main`으로 `0a45797`까지 fast-forward했다.

## 1) 변경 파일 목록

- `art/monsters/characters/{giyeok,nieun,digeut,rieul,mieum,bieup,siot,ieung,hieut,eo,yeo,o,u,eu,i}.glb`: 신규 캐릭터 15종.
- `art/monsters/build_characters.py`: 기존 GLB를 읽어 캐릭터, 통계, 비교 렌더를 재생성하는 라이브 Blender 스크립트.
- `art/monsters/characters/lineup_3quarter.png`: 3600×600, 15종 일렬 직교 비교.
- `art/monsters/characters/mcp_viewport.png`: `mcp__blender__get_viewport_screenshot` 반환 PNG 원본 저장.
- `art/monsters/characters/asset_stats.json`: 개체별 삼각형, 증가분, 높이, 다리 피벗 통계.
- `art/monsters/characters/verify_characters.gd`, `validate_isolated.ps1`: Godot 실제 import/파트/피벗/원점/재질 검증 도구.
- `art/monsters/characters/godot_isolated_import.log`, `godot_isolated_verify.log`, `validation_receipt.json`, `godot_project_check.log`: 실행 증거.
- 본 README 및 상위 `art/monsters/README.md`의 신규 인계 링크.

기존 ASSET-02 파일과 `materials/jamo_special_fast.tres`는 작업 시작부터 존재하던 untracked 산출물이며 이번에 삭제하거나 덮어쓰지 않았다. 새 재질 파일은 만들지 않았다. 메인 워크트리, `scenes/`, `scripts/`, `resources/`, `art/ui/**`, `art/Untitled.blend`는 수정하지 않았다.

## 2) 검수 절차

작업 디렉터리는 `C:/Users/sjkim/orca/workspaces/JAMO/blender`이다.

1. `characters/lineup_3quarter.png`를 열어 100% 배율로 좌우 이동한다. 기대: 왼쪽부터 ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ ㅅ ㅇ ㅎ ㅓ ㅕ ㅗ ㅜ ㅡ ㅣ이며, 각 몸체에 먹색 눈 두 개와 다리 두 개가 보인다. ㅁ/ㅇ/ㅎ/ㅂ 구멍, ㅓ/ㅕ 획 개수, ㅗ/ㅜ 방향을 구분한다. 타이틀 배경과 같이 밝은 종이 몸체와 먹색 작은 파츠를 확인한다.
2. `characters/mcp_viewport.png`를 연다. 기대: 라이브 Blender에서 동일 자모들이 별도 파츠로 줄지어 있는 작업 과정 증거가 보인다. 상세 판독은 1번의 고해상도 렌더를 함께 사용한다.
3. PowerShell에서 `& art/monsters/characters/validate_isolated.ps1`를 실행한다. 기대: `ISOLATED_IMPORT_PASS`, receipt의 import_exit=0, verify_exit=0, error_count=0, 로그의 CHARACTER_CHECK 15줄 및 `CHARACTERS_PASS failures=0`. 임시 프로젝트는 보존된다. 다른 Godot 경로는 `-Godot '절대경로'`로 지정한다.
4. Godot 4.7 Editor에서 3번 receipt의 `validation_project/project.godot`를 연다. FileSystem에서 `art/monsters/mieum.glb`를 더블클릭해 Advanced Import 미리보기를 회전한다. 기대: 종이 몸체, 눈 2개, 발이 달린 다리 2개, 실제 구멍이 있고 누락 텍스처가 없다. ㅇ, ㅎ, ㅓ, ㅕ, ㅡ도 확인한다.
5. 저장하지 않을 임시 3D 씬에 GLB를 드래그하고 Editable Children을 활성화한다. `Leg_L`의 Rotation X를 -20°와 +20°로 바꾼다. 기대: 왼쪽 다리와 발만 엉덩이 피벗을 중심으로 움직이며 오른쪽 다리·눈·몸체는 고정된다. `Leg_R`도 반복하고 양쪽 X를 0으로 복원한다. `Eye_L`의 Visible을 끄면 왼쪽 눈만 사라져야 한다.
6. 같은 임시 씬에서 `Glyph`의 Surface Material Override 0에 `jamo_special_fast.tres`, 이어 `jamo_gold.tres`를 넣는다. 기대: 몸체 정면만 쪽빛/황금으로 바뀌고 측면과 눈·다리는 유지된다. Override를 비우면 밝은 종이 몸체로 복귀한다. ㅁ 루트를 1.5배 키우면 구멍과 파츠 비율을 유지한다.
7. 메인 DEV 연결 QA에서는 기존 `VisualRoot/Body/Lean` 아래 새 GLB를 Position `(0,0.0201,0)`, Rotation 0, Scale 1로 배치한다. Lean X=-20°, 카메라 Orthogonal X=-50°를 유지한다. 기대: 전체 높이·바닥 기준이 이전 자모와 맞고 눈이 카메라를 향한다. HEAVY_STEP, BOUNCE, ROLL, LIGHT_STEP, SWAY, GLIDE마다 다리 트랙 연결 후 타임라인 0/25/50/75%를 스크럽해 좌우 다리 교대와 발 관통 여부를 확인한다. 이 작업은 게임 씬이나 기존 애니메이션 트랙을 수정하지 않았다.
8. 재생성은 MCP `execute_blender_code` 또는 Blender Python Console에서 아래 코드를 실행한다. 기대: 새 `JAMO_ASSET03` 씬과 characters GLB 15개·통계가 만들어지고 타이머로 비교 PNG 렌더가 완료된다. 기존 GLB와 열린 사용자 blend 파일은 저장하지 않는다. MCP viewport screenshot을 다시 확인하고 3번 검증을 반복한다.

```python
p = 'C:/Users/sjkim/orca/workspaces/JAMO/blender/art/monsters/build_characters.py'
exec(compile(open(p, encoding='utf-8-sig').read(), p, 'exec'), {'__file__': p})
```

실행 완료: 라이브 MCP 생성·반복 수정·뷰포트 캡처, 최종 렌더 육안 확인, 독립 Godot import, 15개 실제 PackedScene의 이름/원점/높이/삼각형/재질 교체/다리 피벗 검증, 워크트리 `--headless --path . --quit` (exit 0). 4~7번 Editor 수동 조작 및 최종 플레이는 QA 절차이며 제작자가 실행했다고 주장하지 않는다.

## 3) 주의/보류 사항

### 기존 파일과 계약

- **병존**: 이전 `art/monsters/*.glb`는 그대로 보존하고 신규 기본 자모는 `art/monsters/characters/*.glb`를 사용한다. 이전 재생성·검증 스크립트도 보존했다.
- 루트 단위 1, Godot Y-up, 정면 +Z, 루트 바닥 중앙 origin 0, 높이와 폭은 이전 기준을 유지한다. `Glyph` 자체 origin도 0이나 몸체 최저점은 이제 다리 위다. 다리 높이만큼 몸체의 세로 형상을 내부 압축했다. ㅡ는 전체 높이 0.092를 유지해 다리도 매우 짧다.
- **외곽 깊이만 증가**: 눈이 돌출되어 기존 0.110에서 0.122가 됨 (Godot Z=-0.055..+0.067). Lean -20°와 보정 +0.0201은 유지한다. 메시 수는 1→5, 표면 수는 2→6이므로 단일 mesh를 가정하는 연결 코드는 변경해야 한다.
- `Glyph` 표면 0=`Jamo_Ink`, 1=`Jamo_Pressed_Hanji_Edge`의 이름·순서·override 계약을 유지한다. 단, **표면 0의 기본색은 타이틀 기준 밝은 종이색으로 변경**했다. 이름은 호환성을 위해 유지한다. 눈·다리는 별도 먹색 재질이다.
- `find_child("Glyph", true, false)`로 몸체를 찾는다. `Eye_L`, `Eye_R`, `Leg_L`, `Leg_R`도 같은 방식으로 접근한다. 다리는 각 엉덩이에 피벗이 있으므로 local Rotation X를 반대 위상으로 움직인다. 기존 6종 보행 프로필은 전체 몸체 모션으로 유지하고 DEV에서 이 두 다리 트랙을 추가한다. BOUNCE는 착지 때 양쪽을 함께 굽히고 GLIDE는 작은 진폭을 사용한다. 리그·클립은 GLB에 포함하지 않았다.
- 모든 메시를 일괄 재색칠하는 기존 피격/특수 처리에서는 눈도 덮일 수 있으므로 특수 재질은 `Glyph` 표면 0만 대상으로 한다. 다리 제어의 새 노드 경로 연결은 메인 DEV 범위다.

### 특수 3종 — 전용 GLB 없음

| 종류 | 기본 파일 | 차별화 방법 |
|---|---|---|
| 큰 ㅁ | characters/mieum.glb | 일반 대비 루트 scale 1.5배, 기존 heavy_bounce 및 HP 데이터 유지 |
| 빠른 ㅇ | characters/ieung.glb | Glyph 표면 0에 기존 jamo_special_fast.tres, roll_fast 및 기존 이동속도 데이터 유지; 짧은 먹 꼬리는 DEV 선택 |
| 황금 ㅎ | characters/hieut.glb | Glyph 표면 0에 기존 jamo_gold.tres, 기존 gold_sparkle.tres 사용 가능; 희귀도/보상은 Resource가 소유 |

### 정량 예산과 검증 한계

각 개체 **+272 triangles**. 전체 15종 합계 **2,184→6,264 (+4,080)**. 개체 최대 ㅇ **512→784**, 20마리+문장핵 최대 **13,020→18,460 (+5,440, 약 41.8%)**. 표면 합계는 20마리+문장핵 **49→129**, 메시 노드는 **27→107**로 늘어난다. 그림자 패스·파티클 비용은 별도다. 개체별 수치는 asset_stats.json과 Godot 로그에 있다.

**60 FPS는 실측하지 않았다.** 실제 Wave의 20마리·문장핵·파티클·그림자·목표 해상도에서 QA가 CPU/GPU 프레임 시간을 측정해야 한다. 삼각형 수만으로 FPS를 보장하지 않는다.

프로젝트 시작은 exit 0이나 기존 `art/fonts/NotoSansKR-Regular.ttf` 누락 오류 2개가 유지된다. 신규 애셋만 복사한 독립 프로젝트는 import/verify 모두 오류 0이다. 도구 신규 설치·외부 생성 서비스·유료 애셋은 사용하지 않았다. game-dev CLI와 code-review 스킬은 발견되지 않아 지정된 Blender MCP/Godot 경로 및 직접 계약 검토로 진행했다.

MCP 사용: get_scene_info 연결 확인, execute_blender_code로 라이브 씬 생성/수정/렌더, get_viewport_screenshot 반복 확인. 한국어 Blender 노드 이름 때문에 최초 재질 생성에서 실패한 뒤 노드 타입 조회로 수정했다. 초기 export에서 다른 씬의 선택 오브젝트가 포함되는 문제도 active-scene 제한으로 수정했고 최종 Godot 검증에서 정확히 5개 메시를 확인했다. 열린 `C:/project/JAMO/art/Untitled.blend`는 저장하지 않았으며 제작은 새 메모리 씬에서만 했다.
