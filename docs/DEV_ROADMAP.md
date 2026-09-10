# JAMO 개발 로드맵 v0.4 — 단계별 체크리스트

기준 문서: `JAMO_total_project_development_plan_v0.4.md` (1순위)
v0.3 기반으로 완료했던 작업 이력은 `DEV_ROADMAP_v03_archive.md` 에 보존한다.

사이클 규칙은 `ORCHESTRATION_RULES.md` 를 따른다.
한 Phase 의 모든 Step 이 체크되고 QA PASS 를 받아야 다음 Phase 로 넘어간다.

범례: `[ ]` 미착수 · `[~]` 진행중 · `[x]` QA PASS 후 커밋 완료

---

## v0.3 자산 처분 방침

v0.4 는 장르 전환이다. 기존 코드를 전부 버리지 않고 다음과 같이 처리한다.

**유지 (마이그레이션)**
- 자모 몬스터 6종 + MotionProfile 7종 + 보행 (v0.4 §15)
- 특수 자모 3종 — 큰 ㅁ / 빠른 ㅇ / 황금 ㅎ (§16)
- 클릭 전투·타격감·Damage Number·CameraRig shake (§40)
- StatusEffect Resource 구조 (§38)
- 2.5D 고정 3/4 직교 카메라, Arena 맵 (§39, §40)
- 타이틀 화면 → Main Hub 로 확장 (§27)
- Settings / AudioManager / Theme / 타이틀 아트
- `WordData` — 필드 대폭 확장 (§21)

**폐기**
- Day 시스템 전체 (`current_day`, Day End, 자모 선택 화면)
- 영구 단어 효과 (단어는 이제 RUN 한정)
- 단어 트리 UI (→ 단어 도감으로 대체)
- F8 Day 1~200 밸런싱 결과 (→ Wave 곡선으로 재산출)
- Day 기반 업그레이드 해금 (Day 5/25/60 게이트 등)

**분리**
- `GameState` → `MetaState`(영구) + `RunState`(런 한정) (§44)

---

## P0. 프로젝트 정리 및 State 분리  `[~]`

근거: v0.4 §0, §3, §43, §44, §48 Phase 0

- [~] S1 `autoload/meta_state.gd` 신규 — Gold / 영구 업그레이드 / 도감 / 숙련 / 보스 / 최고 Wave / 통계
- [~] S2 `autoload/run_state.gd` 신규 — Wave / 문장핵 HP / 에너지 / 자모 덱 / 슬롯 / 장착 단어 / Run Rank / 시너지
- [~] S3 `GameState` 해체 — 두 State 로 이관, 영구/런 경계를 코드로 강제
- [~] S4 `current_day` → `current_wave` 전면 교체
- [~] S5 Day End / JamoChoice / 단어 트리 씬·스크립트 제거 또는 보류 폴더로 이동
- [~] S6 기존 단어 4~10개를 v0.4 `WordData` 스키마로 마이그레이션 (§21)
- [~] S7 `SaveManager` 재설계 — MetaState 영구 저장 / RunState 임시 저장 (§45)
- [~] S8 타이틀 → Main Hub 로 전환, RUN 진입/복귀 경로
- [~] 완료 기준: **Wave 1 을 시작하고 실패 후 Main Hub 로 돌아올 수 있다**

### P0 에서 P1 으로 넘긴 임시 처리

- **Wave 곡선**: HP `3 × 1.035^(Wave-1)`, Gold `2 × 1.035^(Wave-1)` — Day 곡선을
  Wave 에 1:1 로 임시 매핑한 값이다. §5.2 가 요구하는 속도·동시 수·특수 비율·스폰 속도
  상승은 아직 없다. P1 / P12 에서 재산출한다.
- **RUN 실패 조건**: 문장핵은 P1 이라서, 지금은 **에너지 0 = RUN 실패** 로 대체돼 있다
  (`scripts/main.gd`의 `end_run_when_energy_depleted`). §7.1 은 에너지 0 이 Wave 를
  끝내면 안 된다고 명시하므로, P1 에서 이 플래그를 끄고 문장핵 HP 0 으로 옮겨야 한다.
- **Wave Clear 없음**: Wave 2 이상으로 진행하는 경로는 P1 이다. `RunState.advance_wave()`
  는 있지만 아직 호출하는 곳이 없다.
- **Day 기반 업그레이드 해금 제거됨**: `critical_click` Day 25 게이트, `reroll` Day 5/25/60
  게이트가 사라졌다. Gold 가격 곡선만 남았으므로 `reroll` 은 첫 Hub 방문부터 구매 가능하다.
  P5 에서 가격 재산출 대상.

### P0 이월 (P1 착수 전 처리)
- [ ] HIGH: v0.3 세이브 마이그레이션 안내문이 크림 배경에 노란 글씨 — 측정 대비 1.04:1 로 안 읽힘
- [ ] MEDIUM: F7~F9 하네스가 허브 판때기 7개 중 4개만 검사 (QA 가 `qa_p0_plates_all` 로 보완)
- [ ] MEDIUM: `test_state_split` 의 필드 겹침 검사가 이름 denylist 라 미등록 이름은 놓침
- [ ] MEDIUM: 결과 화면이 '문장핵이 무너졌다' 인데 HUD 는 문장핵 20/20 — 문장핵 미구현(P1) 탓
- [x] 총지휘자 승인: Wave 곡선을 Day 곡선 1:1 임시 매핑한 것은 P0 한정으로 허용. P1/P12 에서 재산출

## P1. Wave 전투  `[~]`

근거: §5, §6, §7, §25, §48 Phase 1

- [ ] S1 `scenes/objective/sentence_core.tscn` — 문장핵, HP, 피격 연출
- [ ] S2 자모 적이 문장핵으로 접근하는 AI (기존 보행 프로필 유지, 목적지만 변경)
- [ ] S3 `WaveData.tres` 스키마 + Wave 1~5 데이터 (§25)
- [ ] S4 `wave_controller` — Spawn / Clear / Fail 판정
- [ ] S5 Wave Energy 재설계 — Max 10, Wave Clear 시 회복, 0 이어도 DoT·자동공격 계속 (§7)
- [ ] S6 문장핵 HP 0 → RUN 종료 → 결과 화면 → Main Hub (§35)
- [ ] S7 RUN Gold 는 실패해도 영구 Gold 에 가산 (§14)
- [ ] 완료 기준: **Wave 1~5 를 플레이할 수 있다**

## P2. 자모 슬롯 보드 (Word Forge)  `[ ]`

근거: §2.1, §2.4, §9, §32, §48 Phase 2

- [ ] S1 `Run Jamo Deck` — Draw Bag / Discard Bag / Shuffle (§2.4)
- [ ] S2 스타터 덱 데이터 — 초기 제작 가능 단어가 실제로 나오도록 의도 설계
- [ ] S3 슬롯 보드 4칸 + Draw
- [ ] S4 Lock / Reroll (기본 0, 해금으로 증가)
- [ ] S5 Candidate 계산 — 현재 덱·장착 단어·시너지 참조, 완전 꽝 방지 (§9.2)
- [ ] S6 `scenes/ui/word_forge.tscn` — 슬롯·리롤·잠금·가능 단어·Hover 정보 (§32)
- [ ] S7 최초 단어 6개: 검 / 불 / 돈 / 운 / 벽 / 힘
- [ ] 완료 기준: 슬롯에서 단어를 만들어 빌드가 시작된다

## P3. RUN 단어 슬롯  `[ ]`

근거: §2.2, §2.6, §10, §11, §24, §48 Phase 3

- [ ] S1 `WordData.slot_type` — 장비 4 / 유물 3 / 특수효과 2 / 위험 2 (§10)
- [ ] S2 슬롯 초과 시 교체 또는 포기 선택 UI
- [ ] S3 동일 단어 재제작 → `Run Rank` 상승 (§11)
- [ ] S4 `run_word_inventory.tscn` — 현재 장착 단어 표시
- [ ] S5 위험 단어 3종: 욕심 / 광기 / 폭주 — 장단점 **동시 표기 필수** (§24)
- [ ] 완료 기준: 슬롯 제한이 효과 무한 누적을 막는다

## P4. 단어 도감  `[ ]`

근거: §2.7, §12, §29, §48 Phase 4

- [ ] S1 첫 발견 시 도감 등록
- [ ] S2 숙련 EXP — 런별 감소 보정 (100% / 50% / 20%) (§12.1)
- [ ] S3 숙련 Lv1~5 효과 — 자동 지급·항상 활성 **금지** (§12.2)
- [ ] S4 `scenes/ui/codex.tscn` — 미발견은 `???`, 힌트로 일부 공개 (§29)
- [ ] S5 합성/시너지 힌트 해금
- [ ] 완료 기준: 실패해도 도감이 남아 재도전 동기가 생긴다

## P5. Gold 영구 업그레이드  `[ ]`

근거: §13, §28, §48 Phase 5

- [ ] S1 `permanent_upgrade.tscn` — **Main Hub 전용**, 전투 중 구매 불가 (§13)
- [ ] S2 5종: Click Damage / Max Energy / Core HP / Gold Bonus / Base Reroll
- [ ] S3 Day 기반 해금 조건 제거 → Gold 가격 곡선만
- [ ] S4 Gold 로 특정 단어를 직접 구매하지 않는다 (§13.3)
- [ ] 완료 기준: 실패 후 업그레이드 → 재도전 루프가 성립한다

## P6. 단어 시너지  `[ ]`

근거: §2.5, §23, §48 Phase 6

- [ ] S1 `WordSynergyData.tres` 스키마 (§23)
- [ ] S2 최초 3계열: 무기 / 불 / 행운·경제
- [ ] S3 `synergy_panel.tscn` — `무기 2 / 4` 형태로 보유 수 명시
- [ ] S4 태그는 색 아이콘이 아니라 **의미 연결**이 보이게 (§2.5)

## P7. 합성어  `[ ]`

근거: §2.3, §22, §48 Phase 7

- [ ] S1 `CompoundRecipeData.tres` 스키마 (§22)
- [ ] S2 합체형(재료 소비) / 공존형(세트 효과) 둘 다 구현
- [ ] S3 최초 5~8 레시피
- [ ] S4 발견 전 은닉 / 발견 후 도감 기록

## P8. 위험 단어  `[ ]`

근거: §2.6, §24, §48 Phase 8

- [ ] S1 욕심 / 광기 / 폭주 실제 효과 구현
- [ ] S2 단점을 모른 채 선택하는 구조 **금지** — UI 동시 표기
- [ ] S3 별도 슬롯 최대 2칸

## P9. 중간보스  `[ ]`

근거: §17, §48 Phase 9

- [ ] S1 Wave 5 / Wave 15 최소 2종
- [ ] S2 거대한 ㅁ (착지 충격 + 소형 ㅁ 생성), 질주 ㅇ (돌진)
- [ ] S3 보상 강화 — 희귀 Word Forge / 덱 압축 / 유물 후보

## P10. 단어 보스  `[ ]`

근거: §18, §19, §20, §26, §48 Phase 10

- [ ] S1 `WordBossData.tres` 스키마 (§26)
- [ ] S2 Wave 10 **침묵** — 장착 단어 하나를 주기적으로 임시 비활성화
- [ ] S3 Wave 20 **탐욕** — Gold 획득 시 보스에게 보호막 (영구 Gold 는 뺏지 않음)
- [ ] S4 보스 처치 → 도감 등록 → 이후 RUN 에서 해당 단어 제작 가능 (§20)
- [ ] S5 보스 사망 연출 — 단어가 자모 단위로 분리 (§41)

## P11. Juice  `[ ]`

근거: §40, §41, §42, §48 Phase 11

- [ ] S1 단어 제작 연출 — 자모 정렬 → 획 맞물림 → 완성 → 슬롯 이동
- [ ] S2 보스 등장 Zoom / 사망 연출
- [ ] S3 문장핵 피격 Shake, Core Hit 피드백
- [ ] S4 신규 SFX 이벤트 (§42) — Wave Start/Clear, Boss Alert/Intro, Synergy, Risk, Run Failed, Codex New

## P12. Content / Balance  `[ ]`

근거: §49, §51, §52, §53, §48 Phase 12

- [ ] S1 단어 20~30개까지 확대
- [ ] S2 Wave 곡선 산출 (Day 곡선 폐기 후 재설계)
- [ ] S3 §51 지표 계측 하네스를 Wave 기준으로 재작성
- [ ] S4 §52 밸런스 경고 7종 판정
- [ ] S5 숙련 곡선 / 골드 경제 튜닝

---

## Vertical Slice 게이트 (v0.4 §49)

- [ ] 맵 1개 / 기본 자모 12종 이상 / 특수 자모 3종
- [ ] Wave 1~20 진행 가능
- [ ] 중간보스 Wave 5 · 15
- [ ] 단어 보스 Wave 10 침묵 · Wave 20 탐욕
- [ ] 단어 20~30개 (장비 / 유물 / 특수효과)
- [ ] 위험 단어 3개 / 합성어 5개 이상 / 시너지 3계열 이상
- [ ] 자모 슬롯 + 자모 덱 압축
- [ ] Gold 영구 업그레이드 5종
- [ ] 단어 도감 + 숙련 Lv
- [ ] Run Result / Save / Load
