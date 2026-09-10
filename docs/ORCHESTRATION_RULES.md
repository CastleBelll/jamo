# JAMO 개발 오케스트레이션 규칙 v1.0

총지휘자(Coordinator)는 메인 Claude 세션이다. 기능 단위로 개발 에이전트와 QA 에이전트를
Orca orchestration으로 생성하고, 사이클이 끝나면 두 에이전트 세션을 모두 파기한다.

## 1. 사이클 구조

한 기능(Feature) = 한 사이클. 사이클 순서는 고정이다.

```text
1. Coordinator: task-create (DEV)
2. Coordinator: worker-start --agent claude --worktree current   (개발 에이전트 생성)
3. DEV: 구현 -> worker_done
4. Coordinator: worker-release                                   (개발 세션 파기)
5. Coordinator: task-create (QA)
6. Coordinator: worker-start --agent claude --worktree current   (QA 에이전트 신규 생성)
7. QA: 직접 실행/검증 -> worker_done (PASS 또는 FAIL)
8. Coordinator: worker-release                                   (QA 세션 파기)
9. PASS -> Coordinator가 commit + push -> 다음 기능
   FAIL -> 새 DEV 에이전트를 새로 생성해 수정 (1번으로 복귀, 재사용 금지)
```

세션 재사용 금지: DEV와 QA는 절대 같은 터미널을 공유하지 않는다. 사이클마다 신규 생성한다.

## 2. Coordinator 규칙

- 코드를 직접 수정하지 않는다. 계획, 태스크 정의, 검수 판정, commit/push만 한다.
- 워커 대기는 `check --wait --types worker_done,escalation,question`로 한다. sleep/poll 금지.
- `question` 메시지는 `reply`로 즉시 답한다.
- `worker_done` 처리 후 반드시 `worker-release`로 터미널을 정리한다.
- QA PASS 없이는 commit하지 않는다.
- **인계 의무**: QA 태스크 스펙에 DEV 의 `worker_done` 에서 다음 세 가지를
  **원문 그대로** 붙여넣는다. 요약하거나 자기 체크리스트로 대체하지 않는다.
  1) 변경 파일 목록  2) DEV 가 적은 검수(QA) 조작 절차  3) DEV 가 남긴 주의/보류 사항
  총지휘자가 추가로 요구할 항목은 그 아래에 별도 섹션으로 덧붙인다.

## 3. DEV 에이전트 규칙

계획서 v0.4 §47 고정 문구를 항상 준수한다.

- 코드 전용(code-only) 구현 금지. `.tscn` = 구조, `.tres` = 데이터, `.gd` = 로직.
- 메인 UI를 GDScript로 전부 생성하지 않는다.
- 밸런스/단어/몬스터/업그레이드 값을 스크립트에 하드코딩하지 않는다. Resource로 뺀다.
- 새 노드/프로퍼티는 Inspector에서 보이고 수정 가능해야 한다(`@export`, 명확한 이름).
- 요청 범위만 수정한다(surgical diff). 요청하지 않은 리팩터링/파일/의존성 추가 금지.
- 주석은 영어. 코딩 컨벤션은 주변 코드를 따른다.
- 구현 후 `godot --headless --path . --quit` 로 파싱/로드 에러 0 확인 후 완료 보고.
- 완료 보고는 `worker_done` 1회. 다음 세 가지를 **반드시 분리된 항목으로** 포함한다.
  이 내용은 총지휘자가 QA 에이전트에게 원문 그대로 전달한다.
  1) **변경 파일 목록**
  2) **검수 절차**: QA 가 따라 할 수 있는 번호 매긴 조작 순서. 각 단계에 기대 결과를 적는다.
     "코드 확인" 같은 문장 금지. 화면에서 무엇을 보고 무엇을 눌러야 하는지 쓴다.
  3) **주의/보류 사항**: 스펙과 다르게 처리한 부분, 하위 호환 위험, 사전 존재 이슈,
     다음 사이클로 미룬 것.

## 4. QA 에이전트 규칙

문서 기준 우선순위: **v0.4 가 단독 1순위**다. v0.3 / growth_balance v0.2 / word_tree v0.1 은
장르 전환 이전 문서이므로 v0.4 와 충돌하면 무조건 v0.4 를 따른다. 참고용 이력으로만 본다.

**DEV 인계문 우선**: 태스크 스펙에 실린 DEV 의 검수 절차를 먼저 그대로 수행한다.
그 다음에 아래 공통 항목을 수행한다. DEV 절차와 공통 항목이 충돌하면 공통 항목이 이긴다.

검증 항목(전부 통과해야 PASS):

1. **정적**: `godot --headless --path . --quit` 에러/경고 없음.
2. **자동 테스트**: `tests/` 의 기존 헤드리스 테스트 전부 통과. 신규 기능은 신규 헤드리스
   테스트를 `tests/test_<feature>.tscn` 으로 추가하고 통과시킨다.
3. **직접 플레이 — ziva-godot MCP 필수**: `mcp__ziva-godot__start_godot` 으로 실제
   Godot 을 띄워 게임을 눈으로 보고 직접 조작한다. 이것이 QA 의 기본 검증 수단이다.
   헤드리스 스크립트는 3번을 대체할 수 없고, 1·2번 보조 수단으로만 쓴다.
   "코드를 읽어보니 될 것 같다"는 PASS 사유가 될 수 없다.
   증거(스크린샷/로그)를 `tests/qa_artifacts/<feature>/` 에 남긴다.
4. **에디터 가시성**: 같은 ziva-godot MCP 세션에서 새 씬/리소스를 Godot Editor 로 열어
   구조와 Inspector 값이 노출되는지 눈으로 확인한다(v0.4 §46).
5. **회귀**: Main Hub -> RUN 시작 -> Wave 1 -> 실패 -> 결과 화면 -> Main Hub 경로가
   실제 씬 전환까지 포함해 동작한다. (v0.3 의 "Day 1 -> Day 2" 를 대체한다)
6. **DEV 주의사항 검증**: DEV 가 적은 하위 호환 위험·보류 사항이 실제로 문제를
   일으키지 않는지 확인하고, 항목별로 결과를 보고한다.

ziva-godot MCP 를 쓸 수 없는 상황이면 PASS 를 내지 말고 `escalation` 으로 총지휘자에게
보고한다. 헤드리스만으로 통과 판정하는 것을 금지한다.

판정 보고는 `worker_done`으로 하며 본문 첫 줄에 `PASS` 또는 `FAIL`을 쓴다.
FAIL이면 재현 절차와 기대/실제를 명시한다. QA는 코드를 수정하지 않는다(테스트 파일 제외).

## 5. Commit 규칙

- Conventional Commits, 영어.
- 한 사이클 = 한 커밋. QA PASS 직후 Coordinator가 commit + push.
- 커밋 본문에 QA 검증 요약 한 줄 포함.

## 6. 기능 백로그

백로그는 `docs/DEV_ROADMAP.md` 가 단일 출처다. v0.4 §48 의 Phase 0~12 순서를 따른다.
v0.3 기반으로 완료했던 F1~F9 이력은 `docs/DEV_ROADMAP_v03_archive.md` 에 보존한다.

사이클 종료마다 `DEV_ROADMAP.md` 의 체크박스를 갱신한다.

## 7. v0.4 전환 시 추가 규칙

- **State 경계를 코드로 강제한다**: 영구 데이터는 `MetaState`, 런 한정 데이터는 `RunState`.
  RUN 실패 시 `RunState` 는 전부 사라져야 하고 `MetaState` 는 남아야 한다 (v0.4 §3, §44).
  두 State 를 섞어 쓰는 구현은 QA FAIL 사유다.
- **단어는 더 이상 영구 효과가 아니다**: 도감에 등록돼 있다는 것과 현재 RUN 에서
  효과가 활성이라는 것은 다르다 (§38).
- **Wave 기준**: `current_day` 를 쓰는 신규 코드는 금지한다.
- **Day 시절 밸런스 수치를 재사용하지 않는다**: Wave 곡선은 새로 산출한다.

### 7.1 P0 이후 QA 가 알아야 할 것 (P0 사이클에서 확정)

- **회귀 항목 4번이 바뀌었다**: "Day 1 → Day 2 기본 루프" 는 더 이상 존재하지 않는다.
  대신 **Main Hub → RUN 시작 → Wave 1 → 실패 → 결과 화면 → Main Hub** 를 확인한다.
- **헤드리스로 돌 수 있는 테스트는 2개다**: `tests/test_state_split.tscn`,
  `tests/test_run_flow.tscn`. 둘 다 `godot --headless --path . res://tests/<x>.tscn` 로
  돌리고 exit 0 이어야 한다.
- **스크린샷 하네스는 헤드리스에서 돌지 않는다**: `qa_f7_art` / `qa_f8_*` / `qa_f9_*` 는
  `await RenderingServer.frame_post_draw` 를 쓰기 때문에 `--headless` 에서 영원히 멈춘다.
  창 모드(`godot --path . res://tests/<x>.tscn`)로 돌려야 한다. 이는 P0 이전부터 그랬다.
- **`qa_f7_live` / `qa_f5_*` 는 스스로 종료하지 않거나 수천 프레임을 관찰한다.**
  타임아웃은 실패가 아니다.
- **보류 테스트**: `tests/_deferred_v03/` 에 `.gdignore` 와 함께 있고, 무엇을 왜 보류했는지
  같은 폴더 `README.md` 에 Phase 별로 적혀 있다. 삭제하지 말 것.
- **폰트 누락 에러는 기존 이슈다**: `res://art/fonts/NotoSansKR-Regular.ttf` 없음.
  P0 범위가 아니다.

## 8. 애셋 작업 — 별도 워크트리

애셋(3D 모델 / 텍스처 / 아이콘 / 오디오 등) 및 그에 준하는 제작 작업은
메인 워크트리에서 하지 않는다. 전용 워크트리와 전용 에이전트를 쓴다.

```text
워크트리 : C:/Users/sjkim/orca/workspaces/JAMO/blender
브랜치   : CastleBelll/blender
에이전트 : codex-astra
```

디스패치 예:

```bash
orca orchestration worker-start --task <task_id>   --worktree b9ec09f0-b3f0-4d4a-94da-5ebb9a8b1616::C:/Users/sjkim/orca/workspaces/JAMO/blender   --agent codex-astra --json
```

### 규칙

- **코드 작업은 메인 워크트리, 애셋 작업은 blender 워크트리.** 섞지 않는다.
- 애셋 워커는 `art/`, `materials/`, `audio/` 등 애셋 경로만 건드린다.
  게임 로직·씬 구조를 고쳐야 하면 그건 애셋 작업이 아니므로 메인 워크트리 태스크로 분리한다.
- 애셋 워커도 DEV 규칙(3절)과 worker_done 3항목 보고 형식을 동일하게 따른다.
- 애셋 결과물을 게임에 연결(씬 배치 / import 설정 / 테마 반영)하는 작업은
  **메인 워크트리의 DEV 사이클**에서 한다. 애셋 워커는 파일을 만들어 브랜치에 남긴다.
- **사용자 자산을 지우거나 리사이즈·재저장하지 않는다.** F7~F9 에서 확정한 원칙이다.
- 애셋 브랜치가 main 보다 뒤처져 있으면, 애셋 태스크를 내기 전에 최신 main 을 반영할지
  총지휘자가 먼저 판단한다. 뒤처진 브랜치에서 만든 결과물이 병합 충돌을 만들 수 있다.

## 9. 모델 라우팅

에이전트 역할별로 모델을 고정한다. `worker-start --model` 로 지정한다.

| 역할 | 에이전트 | 모델 |
|---|---|---|
| DEV (구현/수정) | claude | **fable** |
| QA (검증) | claude | **opus** |
| 애셋 | codex-astra | 해당 에이전트 기본값 |

디스패치 예:

```bash
# DEV
orca orchestration worker-start --task <id> --worktree current --agent claude --model fable --json

# QA
orca orchestration worker-start --task <id> --worktree current --agent claude --model opus --json
```

### 규칙

- `--model` 은 새 에이전트 터미널에만 적용된다. `--terminal` 재사용과 함께 쓸 수 없다.
- `--effort` 는 `--model` 과 함께만 쓴다. 필요할 때만 지정한다.
- 애셋 에이전트(codex-astra)는 Codex 계열이라 Claude 모델 id 를 넘기지 않는다.
- 재시도(`--retry-of`) 시에도 같은 모델을 유지한다.
- 검증(QA)은 판정 품질이 결과를 좌우하므로 모델을 낮추지 않는다.
