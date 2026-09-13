# JAMO P6 제작 완료 보고

브랜치: `codex/p6-3d`, 기준 main: `a38597f`. Pull/push/merge 없이 로컬 그룹별 커밋으로 전달한다.

## 결과

| 그룹 | 요청 | 완료 | 커밋 |
|---|---|---:|---|
| A | 자모 20종 + 보스 4종, 리깅 GLB | 24/24 | `a918166` |
| B | 기본 단어 22종 + 합성 2종, 투명 아이콘 | 24/24 | `41bb808` |
| C | 최소 먹 선 HUD 참고 + 정돈된 전투 책상 | 2/2 | 이 보고서가 포함된 P6 C 커밋 |

핵심 결과물 **50개**, 미제작 **0개**. 별도로 편집 가능한 Blender 원본 24개, 검수 이미지/JSON, 원본 생성 이미지와 전체 프롬프트, 재제작 스크립트 및 라이선스 기록을 포함한다. 코드·씬·resources·tests·project.godot은 수정하지 않았다. 기존 untracked 파일과 자동 import 파일은 보존하고 커밋에서 제외했다.

## A — 리깅된 3D 자모·보스

Blender MCP 도구는 있었으나 addon 상태 조회에서 연결에 실패했다. 지시된 대안대로 **Blender 5.2.1 LTS의 bpy/background Python**으로 제작했으며, MCP로 제작했다고 주장하지 않는다. 유료 3D 제공업체나 다운로드 모델은 사용하지 않았다.

- 파일: `art/models/char_*.glb` 20개, `boss_*.glb` 4개.
- 실제 삼각형 수: **612~1,396**, 전 모델 3,000 이하.
- 본 4개: `root`, `body`, `leg.L`, `leg.R`. 눈은 body에 스킨, 다리·발은 각각의 다리 본에 스킨.
- 클립: `idle`, `walk`, `hit`, `purify`. hit 0.16초, purify 0.45초, walk 주기는 실제 motion profile의 period 사용.
- GLB +Y 위 / 정면 -Z / 발 바닥 Y=0 / 정지 포즈 키 1.0, 보스 2.0.
- PNG glaze base-color 텍스처 임베드 + metallic/roughness PBR. 도자기·검은 금 균열·회색·금박 재질.
- 정면에서 ㄱ/ㄴ 등 비대칭 글자가 반전되지 않도록 윤곽을 보정하고, 반전으로 바뀐 면 방향을 다시 교정했다. 내향 면이 없는지 GLB primitive의 양의 signed volume 검사.
- ㅇ은 몸통 중앙을 축으로 굴림. 굴림 도중 바닥 아래로 내려가지 않는 9개 샘플 포즈 검사.
- purify는 붕괴 + terminal root scale 0.001로 사라짐을 표현한다. **재질 알파 애니메이션은 아니다**.
- 침묵 보스는 컨셉에 맞춰 눈 없는 회색 빈 실루엣과 9개 먹 조각. 나머지 모델은 점 눈 2개.

자모 형태는 OFL Noto Sans KR weight 900의 정확한 폰트 윤곽을 입체화했으며 AI가 그린 글자에서 추출하지 않았다. 수정된 정적 subset 폰트는 JAMOShapeGuide로 이름을 변경하고 원본 Adobe/SIL OFL 전문을 동봉했다. 재질·기하 제작 및 애니메이션 스크립트는 JAMO용 로컬 제작물이다.

실제 데이터의 그룹은 브리프 예시와 다르다: ㄱ=HEAVY_STEP, ㄴ/ㄹ=SWAY, ㅈ/ㅊ=LIGHT_STEP. `resources/motion_profiles/*.tres`를 기준으로 제작했다.

상세 표/출처: [MODELS.md](models/MODELS.md), [GLB 검사 JSON](models/inspection/GLB_VALIDATION.json), [24종 검수 이미지](models/previews/MODELS_CONTACT.jpg). Blender 원본/검수/텍스처 폴더는 `.gdignore`로 중복 runtime import를 차단하고 루트 GLB는 임포트 가능하게 두었다.

## B — 단어 아이콘

Built-in ImageGen으로 단어별 각각 생성했다. 먹 붓 질감 + 한 가지 포인트색, **글자 없는** 256×256 straight-alpha PNG 24개. 원본을 그대로 보관하고 canvas crop/resize만 적용했다.

`resources/words/*.tres`의 ID 24개와 결과 목록의 완전 일치를 검사했다. 눈은 냉기 태그에 맞춰 눈결정, 눈물은 우는 눈 아래 물방울이다. 검/칼/창/활, 불/불길, 물/눈물은 서로 다른 실루엣으로 제작하고 한 화면에서 시각 검수했다.

[단어별 표·제작 기록](words/README.md), [아이콘 검수 이미지](_source_p6/words/WORDS_CONTACT.jpg), [프롬프트](_source_p6/words/prompts.json), [크기/알파/해시 검사](_source_p6/words/WORD_VALIDATION.json). 외부 stock 이미지나 별도 폰트 렌더링은 사용하지 않았다. AI 생성 그림은 JAMO용 제작물이며 프로젝트 배포 정책에 따른다; 임의로 CC0 stock 라이선스를 주장하지 않는다.

## C — HUD·책상 배경

- `art/_reference/hud_concept.png`: 1920×1080, 얇은 먹 선 + 아이콘·숫자. 참고용 예시 숫자이며 gameplay 데이터나 통짜 runtime HUD로 쓰는 이미지가 아니다.
- `art/backgrounds/combat_desk_v2.png`: 1920×1080, 기존보다 넓은 빈 한지 영역, 소품을 우측 붓·벼루 두 개로 제한, 부드러운 따뜻한 외부 조명. 글자·몬스터·HUD 없음.
- Built-in ImageGen, 원본/프롬프트/해시는 `art/_source_p6/references/`. 정확한 크기로 canvas-only fit. 두 장 모두 시각 검수 완료. 기존 combat_desk/HUD 이미지는 교체하지 않았다.

## 검증과 인계

실행 완료:

```text
python art/models/validate_models.py
GLB_PASS 24 triangles 612 1396

python art/words/normalize_words.py
WORDS_PASS 24 256x256 RGBA

python art/_source_p6/references/normalize_references.py
REFERENCE_PASS 2 1920x1080
```

GLB binary의 skin/inverse-bind 및 clip sampler를 직접 읽어 본·이름·길이·발 바닥·키·임베드 PNG/PBR·hit squash·purify shrink·idle/walk loop seam·BOUNCE lift·ROLL floor를 검사했다. Blender에서는 실제 mesh 삼각형/본 수를 산출하고 전 모델 정지 포즈를 렌더링했다.

**남은 제작 항목은 없다.** Godot 씬 연결, AnimationPlayer 임포트 결과·재생 및 실제 UI 크기의 대비/게임 플레이 확인은 코디네이터의 연결 작업에 포함된다. 본 작업에서는 Godot 임포트/플레이/headless 12개 스위트를 실행하지 않았으며 PASS로 주장하지 않는다. 사용자의 실제 저장 파일은 건드리지 않았다.
