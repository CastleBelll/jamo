# v0.3 보류 자산 (Deprecated, not deleted)

`.gdignore` 가 있어 Godot 은 이 폴더를 로드하지 않는다.
`art/_reference/` 와 같은 방식이다. **삭제 금지** — 아래 Phase 에서 참고/재작성 대상이다.

기준 문서: `docs/JAMO_total_project_development_plan_v0.4.md`

| 파일 | v0.3 역할 | v0.4 처분 | 되살아나는 시점 |
|---|---|---|---|
| `scenes/ui/day_end.tscn`, `scripts/ui/day_end.gd` | Day 결산 화면 | 폐기 (Day 시스템 자체가 없음) | 없음. Wave Clear 화면(§31)은 P1 에서 신규 작성 |
| `scenes/ui/jamo_choice.tscn`, `scripts/ui/jamo_choice.gd` | Day 종료 자모 1개 선택 | 폐기 | 없음. 자모는 P2 슬롯 보드(§9)에서 뽑는다 |
| `scenes/ui/jamo_card.tscn`, `scripts/ui/jamo_card.gd` | 자모 선택 카드 | 보류 | P2 슬롯 칸 UI 레이아웃 참고 |
| `scenes/ui/word_tree.tscn`, `scripts/ui/word_tree.gd` | 단어 트리(선행 잠금) | 폐기 | P4 단어 도감(§29)으로 **대체**. 4상태 표시/컬럼 배치는 참고 가치 있음 |
| `scripts/word_system/candidate_generator.gd` | Day 종료 자모 후보 추첨 | 보류 | P2 슬롯 Candidate 계산(§9.2 완전 꽝 방지)으로 **재작성** |

## 왜 이 코드가 그대로는 못 쓰이나

- `GameState` 가 해체됐다. 이 스크립트들은 `GameState.unlocked_word_ids` /
  `GameState.jamo_inventory` / `GameState.day` 를 직접 읽는다. v0.4 에서는
  각각 `MetaState.codex_words` / `RunState.jamo_draw_bag` / `RunState.current_wave` 다.
- `WordData.prerequisites` 가 없어졌다. 단어 간 선행 관계는 합성어(§22)와
  보스 해금(§20)으로 대체됐다. 단어 트리 UI 의 전제가 사라진 것이다.
- 단어 효과가 영구가 아니라 RUN 한정이 됐다(§38). 도감 등록 ≠ 효과 활성.
