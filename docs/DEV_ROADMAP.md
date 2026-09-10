# JAMO 개발 로드맵 — 단계별 체크리스트 v1.0

`docs/ORCHESTRATION_RULES.md` 의 사이클 규칙에 따라 **위에서 아래로 한 칸씩** 진행한다.
한 Feature 의 모든 Step 이 체크되고 QA PASS 를 받아야 다음 Feature 로 넘어간다.

기준 문서 우선순위: `JAMO_total_project_development_plan_v0.4.md` > `hangul_idle_growth_balance_v0.2.md` > `hangul_idle_word_tree_v0.1.md`
(`..._v0.3.md` 는 이력으로만 보존한다. v0.3 → v0.4 변경 내역은 v0.4 §43.)

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

## F7. 메인화면 (타이틀)  `[x]`

근거: v0.3 §31 Phase 11, §30 저장 시점 / 계획서에 명시 누락된 항목을 보완

- [x] S1 `scenes/ui/title_screen.tscn` 신규 — 타이틀 + 새 게임 / 이어하기 / 설정 / 종료
- [x] S2 `run/main_scene` 을 타이틀로 변경, 게임 씬 진입 경로 정리
- [x] S3 세이브 유무 분기 — 세이브 없으면 이어하기 비활성 + 사유 텍스트, 새 게임은 덮어쓰기 확인
- [x] S4 설정 화면 재사용 (현재 인게임 전용으로 붙어 있음). 중복 구현 금지
- [x] S5 pause_menu 에 타이틀 복귀 경로 추가 — 복귀 전 저장
- [x] S6 키보드 전용 조작 + 포커스 표시 (F5 에서 만든 테마 패턴 재사용)
- [x] S7 타이틀 아트 적용 (title_bg / title / active·inactive button, 5개 해상도 검증)
- [x] QA 확인: 첫 실행 / 세이브 있음 / 새 게임 덮어쓰기 / 타이틀 복귀 후 재진입 / 키보드 완결

## F8. 밸런싱 (Phase 10)  `[x]`

근거: v0.3 §31 Phase 10, §34, §35 / growth_balance v0.2 전체

- [x] S0 F7 이월: 타이틀 포커스 테두리 대비 — **4 개 버튼 전부** 최저 3.51:1 (1 차 크림 단색은 `종료` 에서 2.73:1 FAIL. `SB_title_focus` 를 2 색 링 9-patch `art/ui/focus_ring.png` 로 교체, 검정 2px + 흰색 4px). 측정 `tests/qa_f8_focus_all.tscn`
- [x] S0 F7 이월: title_ex.png 를 `art/_reference/` + `.gdignore` 로 이동 (파일 보존, 익스포트 제외)
- [x] S0 F7 이월: 타이틀 텍스처 4장 BC7 VRAM 압축 — 약 33MB -> 8.1MB (원본 .png 무수정)
- [x] S0 F7 이월: OverwriteConfirm 픽셀 size 제거, 내용 크기로 자동 (622x104)
- [x] S1 Day 1~200 곡선 검증 — 런타임이 v0.3 8.1 식과 일치. growth_balance 3절 표가 Day 100/150/200 에서 반올림 오차
- [x] S2 계측 지표 수집 — `tests/sim_balance.tscn` 헤드리스 하네스, 결과 `tests/qa_artifacts/f8/`
- [x] S3 밸런스 경고 조건 점검 — 에너지/DoT/RNG 정상, Gold 는 역방향 실패(Day 107 부터 94일 무구매)
- [x] S4 경제 튜닝 — 무구매 최장 94일 -> 16일, Day 1~30 중 25일 구매. `docs/BALANCE_NOTES.md`
- [x] S5 특수 개체 확률 튜닝 — A/B 결과 문서값(2%) 유지가 맞아 변경 없음. 근거는 BALANCE_NOTES 5장
- [x] S6 조정값 전부 `.tres`, 근거는 `docs/BALANCE_NOTES.md`
- [x] QA 확인: 30분 이상 장시간 플레이 세션 실시, 진행 막힘 없음 확인

### F8 후속 — 기준 문서 개정 (v0.4, 총지휘자·사용자 판단 사항)

F8 은 코드가 기준 문서를 앞서간 상태로 끝났다. 아래는 **DEV 가 임의로 고치지 않는다.**

- [ ] v0.3 §8.1 개정: `BaseGold = 2 × 1.025^(Day-1)` 를 `2 × 1.035^(Day-1)` 로.
      F8 이 이 식을 어기고 있고, §41 우선순위상 1 순위 문서다. 근거 `docs/BALANCE_NOTES.md` 3-1
- [ ] growth_balance v0.2 내부 모순 확정: §4 표(골드 1.025)와 §5 목표 수입곡선
      (Day 200 50,000 G+)이 서로 모순이다. F8 은 **§5 를 정본**으로 삼고 §4 를 정오표 대상으로
      뒀다. 어느 쪽이 최종 정본인지 결정 필요
- [ ] growth_balance v0.2 §8.1 클릭 피해 표를 Lv26 값으로 교체 (BALANCE_NOTES 3-2)
- [ ] growth_balance v0.2 §3 HP 표의 Day 100/150/200 반올림 오차 정정 (BALANCE_NOTES 1장)

### F8 이월 (F9 에서 정리 완료)
- [x] MEDIUM-3: `docs/BALANCE_NOTES.md:314` 가 134행에서 철회한 §42 주장을 반복 (한 줄 정정)
- [x] MEDIUM-4: 포커스 링 제거 부작용 — 키보드 포커스와 마우스 호버가 다른 버튼이면 밝은 판때기 2개
- [x] `art/ui/focus_ring.png` 미참조 에셋 → `art/_reference/` 로 이동 (`.gdignore`, 파일 보존)
- [x] v0.3 §8.1 골드 상수 v0.4 개정 — `JAMO_total_project_development_plan_v0.4.md` §8.1 · §43

### F9 에서 확인만 하고 남긴 것 (사용자 판단 대상)
- [ ] `art/ui/game_bg.png` 미참조 확인됨 (2.3 MB). 이동 여부는 사용자 판단
- [ ] `art/ui/btn_shop.png` 미참조 확인됨 (483 KB). 이동 여부는 사용자 판단

---

## Vertical Slice 게이트 (v0.3 §32 §39)

F1~F6 완료 후 아래를 일괄 점검하고 통과해야 Phase 10(밸런싱) 으로 넘어간다.

- [x] 맵 1개 / 자모 6종 / 특수 3종 / Day 1~20 진행 가능
- [x] 단어 10개 이상, 3개 이상 계열
- [x] Gold Upgrade 5종 이상
- [x] Burn / Critical / Gold Word / Energy Word 동작
- [x] Jamo Choice + Reroll
- [x] Save / Load / Settings
- [ ] 30분 이상 진행 시 심각한 막힘 없음 (Day 1~200 시뮬레이션은 완주, 실플레이 세션 미실시)

### 남은 LOW 이슈 (F6 QA)
- [ ] `word_revealed` unused-signal 에디터 경고
- [ ] 단어 완성 시 집결 자모 시인성
- [ ] burn ember / gold sparkle 가독성 하한

### 오디오 애셋
- [ ] `art/audio/sfx/` 가 비어 있다. 경로 export 와 재생 구조만 존재하며 소리는 나지 않는다
