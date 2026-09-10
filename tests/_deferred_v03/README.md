# v0.3 구조에 묶인 테스트 — 보류 (Deferred, not deleted)

`.gdignore` 가 있어 Godot 은 이 폴더를 로드하지 않는다. **삭제 금지.**

이 파일들은 v0.3 Day 구조·영구 단어 효과·단어 트리를 전제로 쓰였다.
v0.4 P0 에서 `GameState` 가 `MetaState` / `RunState` 로 갈라지고,
`current_day` 가 `current_wave` 로 바뀌고, 단어 효과가 RUN 한정이 되면서
전제 자체가 사라졌다. 단순 rename 으로는 되살아나지 않는다.

기준 문서: `docs/JAMO_total_project_development_plan_v0.4.md`

## 왜 고치지 않고 보류했나

| 파일 | 무엇을 검증했나 | 왜 지금은 못 고치나 | 되살릴 Phase |
|---|---|---|---|
| `test_day_flow.gd` | Day 1 → 결산 → 자모 선택 → 상점 → Day 2 | 그 시퀀스의 모든 화면이 폐기됐다 | **P1** — Wave Clear 루프 테스트로 재작성 |
| `test_game_loop.gd` (2122줄) | 클릭/에너지/골드/단어 완성/선행 잠금/상점 Day 게이트/아레나/오디오 | 절반은 살아 있고 절반은 전제가 사라졌다. 분해가 필요하다 | **P1~P5** — 항목별로 쪼개 재배치 |
| `sim_balance.gd` | Day 1~200 골드/업그레이드 시뮬레이션 | Day 곡선 자체가 폐기 대상 (§52) | **P12** — Wave 곡선으로 재작성 |
| `qa_critical_play.gd` | 치명타 클릭 실플레이 | `GameState.day` / 영구 단어 효과 전제 | **P1** |
| `qa_f3_compat.gd` | v0.2 → v0.3 세이브 호환 | v0.4 세이브 호환은 `tests/test_state_split.gd` 가 대신 검증한다 | 불필요 — 참고용 보존 |
| `qa_f3_play.gd` | 단어 효과 전부 해금 상태 실플레이 | "전부 해금 = 전부 활성" 이 §38 에서 금지됐다 | **P3** — 장착 슬롯 기준으로 재작성 |
| `qa_f3_pool.gd` | Day 종료 자모 후보 추첨 | `CandidateGenerator` 가 보류 폴더로 갔다 | **P2** — 슬롯 Candidate 로 재작성 |
| `qa_f4_hud.gd` | HUD 단어 진행 표시 | HUD 가 "제작 가능한 단어" → "장착 단어" 로 바뀌었다 | **P2/P3** |
| `qa_f4_special.gd` | 특수/황금 몬스터 출현 | 황금 해금이 영구 → RUN 한정으로 바뀌었다 | **P1** |
| `qa_f5_tree.gd` | 단어 트리 UI 4상태 | 단어 트리가 폐기됐다 | **P4** — 도감 UI 테스트로 대체 |
| `qa_f6_juice.gd` (715줄) | 타격감·화상·카메라 연출 | 화상 효과가 RUN 장착 기준으로 바뀌었다 | **P11** |
| `qa_f6_settings.gd` | 설정 패널 + 구버전 세이브 | `GameState.day` 참조 | **P1** |
| `qa_reroll_play.gd` | 리롤 Day 5/25/60 해금 | Day 해금 조건이 제거됐다 | **P2/P5** |
| `qa_shop_gate.gd` | 상점 Day 게이트 | 같은 이유 | **P5** |
| `qa_f8_choice.gd` | 자모 선택 화면 | 화면이 폐기됐다 | 없음 |
| `qa_f8_shop.gd` | 상점 Day 60 스크린샷 | Day 게이트 제거 | **P5** |
| `qa_f8_variant.gd` (640줄) | Day 1~200 밸런스 변형 비교 | Day 곡선 폐기 | **P12** |

## 계속 돌아가는 테스트 (`tests/` 에 남음)

- `test_state_split.gd` — **신규.** 영구/런 경계, RUN 실패 시 초기화 범위, v0.3 세이브 호환
- `test_run_flow.gd` — **신규.** P0 완료 기준 (Wave 1 시작 → 실패 → Main Hub 복귀)
- `qa_f5_arena.gd` / `qa_f5_margin_ab.gd` / `qa_f5_topdown.gd` — 아레나 경계·카메라.
  State 이름만 바꿔 이식했다. 장시간 관찰 하네스라 창 모드로 돌리는 것이 정상이다
- `qa_f7_*` / `qa_f8_*` / `qa_f9_*` 타이틀 계열 — F7~F9 에서 확정한 판때기/포커스 규칙을
  지키는지 본다. 노드 이름(`NewGameButton` 등)을 그대로 두었기 때문에 그대로 동작한다.
  세이브 픽스처만 v0.4 `meta`/`run` 형태로 갱신했다.
  `qa_f7_live.gd` 는 스스로 종료하지 않는 실시간 관찰 하네스다(설계상 정상)
