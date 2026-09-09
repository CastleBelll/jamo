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

## 3. DEV 에이전트 규칙

계획서 v0.3 §38 고정 문구를 항상 준수한다.

- 코드 전용(code-only) 구현 금지. `.tscn` = 구조, `.tres` = 데이터, `.gd` = 로직.
- 메인 UI를 GDScript로 전부 생성하지 않는다.
- 밸런스/단어/몬스터/업그레이드 값을 스크립트에 하드코딩하지 않는다. Resource로 뺀다.
- 새 노드/프로퍼티는 Inspector에서 보이고 수정 가능해야 한다(`@export`, 명확한 이름).
- 요청 범위만 수정한다(surgical diff). 요청하지 않은 리팩터링/파일/의존성 추가 금지.
- 주석은 영어. 코딩 컨벤션은 주변 코드를 따른다.
- 구현 후 `godot --headless --path . --quit` 로 파싱/로드 에러 0 확인 후 완료 보고.
- 완료 보고는 `worker_done` 1회. 변경 파일 목록과 QA가 확인해야 할 항목을 반드시 포함한다.

## 4. QA 에이전트 규칙

문서 기준 우선순위: v0.3 > growth_balance v0.2 > word_tree v0.1.

검증 항목(전부 통과해야 PASS):

1. **정적**: `godot --headless --path . --quit` 에러/경고 없음.
2. **자동 테스트**: `tests/` 의 기존 헤드리스 테스트 전부 통과. 신규 기능은 신규 헤드리스
   테스트를 `tests/test_<feature>.tscn` 으로 추가하고 통과시킨다.
3. **직접 플레이**: 게임을 실제로 실행해 해당 기능을 조작하고, 스크린샷 또는 로그로
   동작을 증거로 남긴다. "코드를 읽어보니 될 것 같다"는 PASS 사유가 될 수 없다.
4. **에디터 가시성**: 새 씬/리소스를 Godot Editor에서 열어 구조와 Inspector 값이
   노출되는지 확인한다(v0.3 §37).
5. **회귀**: Day 1 -> Day 2 기본 루프가 여전히 동작한다.

판정 보고는 `worker_done`으로 하며 본문 첫 줄에 `PASS` 또는 `FAIL`을 쓴다.
FAIL이면 재현 절차와 기대/실제를 명시한다. QA는 코드를 수정하지 않는다(테스트 파일 제외).

## 5. Commit 규칙

- Conventional Commits, 영어.
- 한 사이클 = 한 커밋. QA PASS 직후 Coordinator가 commit + push.
- 커밋 본문에 QA 검증 요약 한 줄 포함.

## 6. 기능 백로그 (Vertical Slice, v0.3 §32)

| # | Feature | 근거 |
|---|---------|------|
| 1 | Critical 시스템 (Gold 치명 클릭 + Critical 계산/피드백) | §10.2, §18 |
| 2 | Reroll (Gold 업그레이드 + Day-end 리롤 UI) | §13.1, §32 |
| 3 | 단어 확장 tier-2 (화염, 불꽃, 강타, 금, 체력, 운) | §33 |
| 4 | 특수 몬스터 (황금 ㅎ, 큰 ㅁ, 빠른 ㅇ) | §9, §32 |
| 5 | 단어 트리 UI | §15, Phase 6 |
| 6 | Juice / Polish (VFX, SFX, Camera Shake) | §24, §25, Phase 9 |

백로그는 순서대로 진행한다. 사이클 종료마다 이 표의 진행 상황을 갱신한다.
