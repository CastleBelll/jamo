# JAMO 개발 로드맵 — 단계별 체크리스트 v1.0

`docs/ORCHESTRATION_RULES.md` 의 사이클 규칙에 따라 **위에서 아래로 한 칸씩** 진행한다.
한 Feature 의 모든 Step 이 체크되고 QA PASS 를 받아야 다음 Feature 로 넘어간다.

기준 문서 우선순위: `JAMO_total_project_development_plan_v0.3.md` > `hangul_idle_growth_balance_v0.2.md` > `hangul_idle_word_tree_v0.1.md`

범례: `[ ]` 미착수 · `[~]` 진행중 · `[x]` QA PASS 후 커밋 완료

---

## 완료된 기반 (커밋 b6169ca)

- [x] Phase 0 프로젝트 기반 — main.tscn / GameWorld / Camera / Arena / HUD / GameState / SaveManager
- [x] Phase 1 자모 보행 — 자모 6종(ㄱㄷㅁㅅㅇㅣ) + MotionProfile 6종 .tres
- [x] Phase 2 클릭 루프 — Raycast 클릭 / HP / Damage Number / Death / Gold / Energy / Day End
- [x] Phase 3 자모 선택·단어 — CandidateGenerator / JamoChoice / WordData / WordComplete (불 힘 돈 밥)
- [x] Phase 4 Gold Upgrade — 최대 에너지 / 클릭 피해 / 골드 증가 / 몬스터 수 + 저장 유지

---

## F1. Critical 시스템  `[x]`

근거: v0.3 §10.1 §10.2 §23.2 / growth_balance v0.2 §8.3

- [x] S1 `GameBalance` 에 `base_crit_multiplier = 2.0` export 추가 (.tres 반영)
- [x] S2 `UpgradeData` 에 `required_upgrade` / `required_level` 해금 조건 추가
- [x] S3 `resources/upgrades/critical_click.tres` 생성 — 확률 2/4/6/8/10%, 가격 1.5k~60k, 클릭 피해 Lv3 게이트
- [x] S4 `game_database.tres` upgrades 배열 등록 + 상점 행 표시("2%" 포맷)
- [x] S5 클릭당 Critical 판정 **1회**로 통합 — `GameState.roll_critical()`, 단어 보너스 합산 지점 확보
- [x] S6 피드백 — Damage Number 크기 증가 + 색(둘 다, 색 단독 금지), CameraRig shake (@export 강도/시간)
- [x] S7 세이브/로드 후 치명 레벨 유지
- [x] QA 확인: 상점 게이트 동작 / 크리 발생 시 숫자·shake / 헤드리스 테스트 통과 / Day1→Day2 회귀

## F2. Reroll 시스템  `[x]`

근거: v0.3 §13.1 §13.2 / growth_balance v0.2 자모 연구

- [x] S1 `resources/upgrades/reroll.tres` — Lv1 1회/Day5/1,000G, Lv2 2회/Day25/7,500G, Lv3 3회/Day60/50,000G
- [x] S2 `GameState` 에 Day 당 리롤 잔여 횟수 (Day Start 시 충전)
- [x] S3 `CandidateGenerator` 재추출 API — 직전 후보 제외 가중 처리
- [x] S4 `jamo_choice.tscn` 에 리롤 버튼 노드 추가 (코드 생성 금지, 씬 편집) + 잔여 횟수 표시
- [x] S5 잔여 0 / 미해금 시 버튼 disabled 상태 처리 (loading·empty·disabled 상태 누락 금지)
- [x] S6 리롤 잔여 횟수 세이브 포함
- [x] QA 확인: Day5 이전 미노출 / 구매 후 노출 / 리롤 시 후보 변경 / 횟수 소진 후 disabled

## F3. 단어 확장 tier-2  `[x]`

근거: v0.3 §14 §15 §33 / word_tree v0.1

- [x] S1 `WordData` prerequisites 체인 검증 — 선행 단어 미완성 시 후보/제작 불가
- [x] S2 `화염` (불 선행, burn 틱 피해 2) `.tres`
- [x] S3 `불꽃` (불 선행, 사망 시 80px 1명 전이) — 전이 로직은 StatusEffectContainer 확장
- [x] S4 `강타` (힘 선행, CritChance +10%p) — F1 의 단어 보너스 합산 지점에 연결
- [x] S5 `금` (돈 선행, 황금 개체 출현 해금 플래그) `.tres`
- [x] S6 `체력` (밥 선행, 최대 에너지 추가) `.tres`
- [x] S7 `운` (신규 루트, 특수 개체 확률 보정) `.tres`
- [x] S8 `WordEffectData.EffectType` 신규 타입 추가 (BURN_TICK_BONUS / BURN_SPREAD / CRIT_CHANCE / UNLOCK_GOLDEN / LUCK)
- [x] QA 확인: 선행 잠금 동작 / 각 단어 완성 시 실제 규칙 변화 관측 / 총 단어 10개

## F4. 특수 몬스터  `[x]`

근거: v0.3 §9 §28 §32

- [x] S1 `JamoMonsterData` 에 special_type / spawn_weight / 배율 export 정리
- [x] S2 `황금 ㅎ` — 단어 `금` 해금 후 등장, 확률 2%, Gold ×5, 체류시간 단축, 금속 머티리얼
- [x] S3 `큰 ㅁ` — HP ×3, 속도 ×0.6, Gold ×3, 강한 착지
- [x] S4 `빠른 ㅇ` — HP ×0.75, 속도 ×1.8, Gold ×2, 턴 빈도 증가
- [x] S5 `SpawnManager` Pool 분리 (Normal / Special / Golden) + 동일 자모 연속 패널티
- [x] S6 특수 개체 전용 씬 상속 (.tscn) — 신규 메시 제작 금지, Scale/Material/Profile 로 차별화
- [x] QA 확인: 금 미해금 시 황금 미등장 / 해금 후 등장 / 각 배율 실측 / 20마리 60FPS

## F5. 단어 트리 UI  `[x]`

근거: v0.3 §15 §23.5 / Phase 6

- [x] S0 이월: 큰 ㅁ 가 20마리 밀집 시 아레나 가장자리를 시각적으로 넘음 (F4 QA INFO)
- [x] S0 F3 이월: 도감 패널이 HUD 상단바와 겹침 (스크롤 컨테이너 없음)
- [x] S1 `scenes/ui/word_tree.tscn` 신규 (Control 기반, 에디터 편집 가능 구조)
- [x] S2 노드 상태 4종 표시 — 해금 / 제작 가능 / 선행 잠금 / 미발견
- [x] S3 노드 클릭 → 목표 단어(Target) 지정, HUD 하단 `TARGET: 불 [ㅂ][ㅜ][ ]` 연동
- [x] S4 목표 집중(Focus) 가중치 적용 — 확정 출현 금지, +5~20%
- [x] S5 키보드 네비게이션 / 포커스 표시 / 색 대비 WCAG AA
- [x] QA 확인: 4상태 시각 구분 / Target 지정 후 후보 가중 변화 / 키보드만으로 조작 가능

## F6. Juice / Polish  `[x]`

근거: v0.3 §23 §24 §25 / Phase 9

- [x] S0 이월: word_tree.gd:191 shadowing 경고, 책 아이콘 툴팁이 아직 "단어 도감"
- [x] S1 클릭 피드백 4종 완비 — squash / 파티클 / Damage Number / SFX
- [x] S2 상태이상 VFX — burn ember, golden sparkle (과도한 Bloom 금지)
- [x] S3 에너지 피드백 — 게이지 pulse, 잔여 3 이하 경고, 0 에서 Day End 트랜지션
- [x] S4 단어 완성 연출 — 자모 중앙 집결 → 음절 합성 → Glyph 등장 → Zoom + Sting
- [x] S5 MotionProfile 별 Step SFX 분기 (HEAVY/LIGHT/BOUNCE/ROLL/GLIDE)
- [x] S6 `AudioManager` autoload 추가 + 설정 화면 볼륨 연동
- [x] QA 확인: 무음/무연출 구간 없음 / 60FPS 유지 / 설정에서 볼륨 조절 반영

---

## Vertical Slice 게이트 (v0.3 §32 §39)

F1~F6 완료 후 아래를 일괄 점검하고 통과해야 Phase 10(밸런싱) 으로 넘어간다.

- [x] 맵 1개 / 자모 6종 / 특수 3종 / Day 1~20 진행 가능
- [x] 단어 10개 이상, 3개 이상 계열
- [x] Gold Upgrade 5종 이상
- [x] Burn / Critical / Gold Word / Energy Word 동작
- [x] Jamo Choice + Reroll
- [x] Save / Load / Settings
- [ ] 30분 이상 진행 시 심각한 막힘 없음 (장시간 플레이 세션 미실시)

### 남은 LOW 이슈 (F6 QA)
- [ ] `word_revealed` unused-signal 에디터 경고
- [ ] 단어 완성 시 집결 자모 시인성
- [ ] burn ember / gold sparkle 가독성 하한

### 오디오 애셋
- [ ] `art/audio/sfx/` 가 비어 있다. 경로 export 와 재생 구조만 존재하며 소리는 나지 않는다
