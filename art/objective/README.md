# JAMO ASSET-01 — 문장핵 인계

## 1) 변경 파일 목록

모든 산출물은 `art/objective/` 아래에 있다. 메인 워크트리 및 게임 씬·로직은 수정하지 않았다.

- `sentence_core.glb`: Godot에 배치할 모델, **189,728 bytes (185.3 KiB), 2,780 triangles, 7 mesh nodes, 9 surfaces, 6 materials**.
- `sentence_core.glb.import`: Godot 4.7에서 생성한 기본 import 메타데이터.
- `sentence_core_preview.png`: **1,205,261 bytes**, 1100×1000, Blender 직교 3/4 미리보기. 배경·조명은 GLB에 포함되지 않는다.
- `sentence_core_preview.png.import`: 미리보기 import 메타데이터. 게임에서 미리보기 이미지를 참조할 필요는 없다.
- `build_sentence_core.py`: 재현 가능한 Blender 제작·GLB export·렌더 스크립트.
- `verify_sentence_core.gd`, `verify_sentence_core.gd.uid`: 애셋 import와 재질 제어 계약 검증용 도구. 게임 로직에 연결하지 않는다.
- `asset_stats.json`: 메쉬·크기·재질·출처 통계.
- `build.log`: Blender 제작 기록; Blender 6.0 예정 API 폐기 경고 포함.
- `godot_import.log`, `godot_verify.log`, `godot_project_check.log`: 실제 Godot 실행 기록.
- `README.md`: 본 인계문.

펼친 목제 표지 고서와 접힌 종이, 먹으로 구성한 `문 = ㅁ + ㅜ + ㄴ`을 중심 실루엣으로 삼았다. 작은 본문 무늬는 자모 획 장식이며 읽을 수 있는 문장을 의도하지 않았다. 외부 이미지·폰트·유료 생성 서비스는 사용하지 않았고, 모든 형상과 단색 재질은 이 작업에서 직접 제작했다. GLB는 내장 버퍼만 사용하며 외부 텍스처 의존성이 없다.

## 2) 검수 절차

작업 폴더: `C:/Users/sjkim/orca/workspaces/JAMO/blender`.
Windows에서는 `godot` 대신 설치 폴더의 `Godot_v4.7-stable_win64_console.exe`를 사용하면 종료 코드와 로그를 확실하게 받을 수 있다.

1. `art/objective/sentence_core_preview.png`를 이미지 뷰어로 연다. 기대: 어두운 책 표지, 겹친 종이 가장자리, 중앙의 수직 접힌 종이와 닫힌 `ㅁ`, 그 아래 `ㅜ`·`ㄴ`이 보인다. 오른쪽 앞에는 붉은 인장이 있고, 책 실루엣과 중앙 표적이 분리되어 읽힌다.
2. Godot 4.7에서 이 워크트리의 `project.godot`를 열고 FileSystem에서 `art/objective/sentence_core.glb`를 더블클릭한다. Advanced Import 미리보기에서 확대·회전하여 앞면과 양옆을 본다. 기대: 모델 누락·분홍 재질·외부 텍스처 요청이 없고, 7개 이름 있는 메쉬가 나온다. Import 설정은 기본값으로 두어도 동작한다.
3. 에디터에서 임시 3D 씬에 GLB를 드래그하고 Editable Children을 활성화한다. 저장하지 않아도 된다. `CorePaper`와 `CoreInk`를 선택해 각각 GeometryInstance3D의 Material Override에 새 StandardMaterial3D를 넣고 붉게 바꾼다. 기대: 해당 파츠만 변하고 나머지 책은 유지된다. Override를 비우면 원래 색으로 돌아온다. `CoreInk`의 Visible을 끄면 먹 글씨만 사라진다.
4. 임시 씬의 카메라를 Orthogonal, 위치 `(0, 9.19, 7.71)`, X 회전 `-50°`, Size `9.6`으로 설정해 기존 게임 카메라와 비슷한 거리에서 확인한다. 기대: 앞면 글씨와 책의 실루엣이 보인다. 미리보기 PNG는 형태 확인을 위한 더 가까운 3/4 시점이며 최종 게임 배치 크기는 DEV에서 조정한다.
5. 터미널에서 `godot --headless --editor --path . --import`를 실행한다. 기대: GLB import 완료, 애셋 관련 오류 없음. 현재 저장소의 기존 `NotoSansKR-Regular.ttf` 누락 오류 2개는 아래 보류 사항과 대조한다.
6. `godot --headless --path . --script art/objective/verify_sentence_core.gd`를 실행한다. 기대: 7개 `PART` 출력과 `ASSET_PASS triangles=2780 surfaces=9 bounds=[P: (-1.27, 0.0, -0.84), S: (2.54, 1.96, 1.68)]`, 종료 코드 0. 이 검사는 실제 import된 PackedScene 인스턴스, 파츠 이름, 재질 교체·복원, 가시성 제어를 확인한다.
7. `godot --headless --path . --quit`를 실행한다. 기대: 종료 코드 0이며 애셋 관련 오류 없음. 기존 폰트 누락 때문에 프로젝트 전체 오류 0은 현재 달성되지 않는다.
8. 재생성이 필요하면 `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/objective/build_sentence_core.py`를 실행한다. PowerShell에서는 실행 파일 앞에 `&`를 붙인다. 기대: 같은 폴더의 GLB·PNG·통계가 재작성된다. Blender 5.2.1에서 제작했고 `--factory-startup`은 사용자 애드온에 의존하지 않도록 한다. 실행 후 5~6단계를 다시 수행한다.

실행 완료: Blender 렌더 육안 확인, GLB 바이너리 헤더·내장 버퍼·무텍스처 확인, Godot 4.7 import 및 6·7단계. 2~4단계의 에디터 수동 조작은 QA가 수행할 절차이며 워커가 수행했다고 주장하지 않는다.

## 3) 주의/보류 사항

- **연결 계약:** GLB 원점은 바닥 중앙, 단위는 Godot 1 unit, Y-up, 정면은 **+Z**다. 기본 범위는 X `-1.27..1.27`, Y `0..1.96`, Z `-0.84..0.84`. 기존 카메라가 +Z에서 보므로 기본 회전에서 정면이 보인다. 큰 실루엣이 필요해 몬스터보다 크게 제작했다. 약 5.6단위 경기장에서는 DEV가 루트 균일 스케일 `0.65~0.8`부터 조정할 수 있으며 이는 제안값이다.
- **파츠 이름:** `Binding`, `BookPages`, `BindingThread`, `SentenceInk`, `CorePaper`, `CoreInk`, `Seal`. 실제 import 인스턴스에서 이름으로 검색 가능함을 확인했다. GLB 루트 이름에 의존하지 말고 예를 들어 `find_child("CorePaper", true, false)`로 연결한다.
- **피격 방식:** `CorePaper`의 `material_override`로 피격 색을 적용하고 해제한다. 원본 `get_active_material(0)`를 `duplicate()`하여 인스턴스 전용 재질을 만든 뒤 override로 사용한다. 공유 원본 재질을 직접 수정하면 `BookPages`의 같은 종이 색까지 바뀔 수 있다. `CoreInk`도 별도 override 또는 visible 제어 가능하다. 파츠 회전·이동 원점은 바닥 중앙이므로 흔들기는 DEV의 VisualRoot에서 수행하는 편이 자연스럽다.
- 기본 상태는 정적이며 애니메이션·스크립트가 없어도 완성된 형태다. HP 단계별 균열 모델, 파괴 애니메이션, VFX, 충돌체, HitFXAnchor, 게임 HP 연결은 포함하지 않는다. 도달 판정·충돌 반경은 DEV의 문장핵 로직이 소유해야 한다. 책 위의 종이는 약간 떠 있는 상징적 형상이며 물리 시뮬레이션용 모델이 아니다.
- 텍스처·투명도·파티클·실시간 광원을 GLB에 넣지 않았다. 삼각형 수는 낮지만 **몬스터 20마리+파티클 동시 60 FPS는 아직 실측하지 않았다**. QA/DEV가 실제 최종 씬에서 측정해야 한다. 표면 9개와 그림자의 렌더 비용도 존재한다.
- Godot import, 검증, 프로젝트 시작 모두 종료 코드 0. 다만 기존 `res://art/fonts/NotoSansKR-Regular.ttf` 부재로 프로젝트 폰트 로딩 오류가 발생한다(`docs/ORCHESTRATION_RULES.md` §7.1의 기존 이슈). 애셋은 폰트를 사용하지 않으며 이 범위에서 복구하지 않았다. 따라서 프로젝트 전체 오류 0이라고 보고하지 않는다.
- `game-dev` CLI가 미설치여서 총지휘자의 명시적 예외 승인 후 Blender/Godot 직접 검증 경로를 사용했다. 새 도구를 설치하지 않았다. 요청된 `$code-review` 스킬은 설치 경로에서 찾지 못해 자동 스킬 검토는 실행하지 못했고, 직접 형상·파일 범위·import·연결 계약을 검토했다.
- 기존 이미지 파일은 수정하지 않았다. Godot이 생성한 기존 이미지 `.import` 파일의 줄바꿈 변동은 원래 Git 체크아웃 형식으로 복원했다. 커밋·푸시는 하지 않았으며 QA 후 총지휘자가 진행한다.
