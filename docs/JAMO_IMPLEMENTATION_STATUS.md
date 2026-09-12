# JAMO 구현 현황 (2026-09-12)

기준 문서: [게임 기획 v0.7](JAMO_02_game_design_v0.7.md), [밸런스 v0.3](JAMO_03_balance_detail_v0.3.md), [세계관 v0.3](JAMO_01_story_world_v0.3.md), [변경 기록](JAMO_PLANNING_CHANGELOG.md). Godot 4.7.stable, 2D, 논리 화면 1920×1080. 기존 구현은 8abcf76에서 전부 제거하고 위 세 문서만으로 다시 만들었다.

## 1. 진행 방식

기능 하나마다 Orca 워크트리를 만들고, 구현 + 헤드리스 테스트 → Claude Opus 검수(읽기 전용) → 통과 시 main 머지·푸시. 검수 실패는 같은 워크트리에서 수정 후 재검수. P0~P5 총 12개 기능, 검수 실패 10건은 모두 수정·재검수 통과. 테스트는 `tests/README.md`의 순서대로 한 번에 하나씩 실행한다(저장 파일 공유 때문).

## 2. 구조 (G13)

| 영역 | 파일 | 책임 |
|---|---|---|
| 데이터 | `scripts/data/*.gd`, `resources/**/*.tres` | WordData/EffectData/WaveData/BossData/DeckData/Synergy/Compound/Research/MotionProfile/BalanceConfig/NarrativeData. `ContentDB`가 전부 로드·교차 검증. 수치는 .tres가 정본 |
| RUN 상태 | `scripts/run/run_controller.gd` | G2 상태기계(LIBRARY→RUN_SETUP→WAVE_PREP→COMBAT→CLEAR→FORGE→…→RESULT), 안정도, Gold, 덱/빌드/핀, 정산, 스냅샷 |
| 화면 | `scripts/run/run_game.gd`, `scenes/run/*.tscn`, `scenes/ui/*.tscn` | 단계별 패널, HUD, 배너, 문장 피격, Esc/포커스 정지, 입력 실드, 저장 시점 |
| 전투 | `scripts/combat/combat_director.gd` | G7 틱 순서, 스폰(통로/하위경로/간격/보류), 클릭·홀드·키보드 입력, 정화/도달 1회 처리, 보스 패턴·부하, 변형 GUARD 감소, Gold 지급 단일 소유자 |
| 효과 | `scripts/combat/combat_resolver.gd` | B1 수식, 시너지, 상태이상 틱, 자동 타격, 카운터, 봉인, 보호막 |
| 개체 | `jamo_monster.gd`, `boss.gd`, `pattern_target.gd` | 경로 이동, 76px 클릭 원, 상태이상 상태, 모션, 보스 캡슐/보호막, 대응물 |
| 덱·Forge | `scripts/deck/*.gd`, `scripts/forge/*.gd` | 토큰 덱, 회수 피티/상한, 정리 예산, Forge 셔플/Lock/Reroll/후보/복원/실패/합성 |
| 서고 | `scripts/hub/*.gd` | 연구·사전·기록·RUN 시작·오프닝·서고 레이어 |
| 저장 | `scripts/persistence/*.gd` | `SaveManager`(temp→검증→교체·백업 복구), `Meta` 오토로드(프로필+중단 RUN) |
| 기타 | `scripts/settings`, `scripts/audio`, `scripts/log` | 설정 적용, SFX 보이스 규칙(`Sfx`), 로컬 JSONL 로그(`RunLog`) |

## 3. 단계별 완료 내용

- **P0** 데이터 스키마·65개 .tres·B6 빈도 검증 / 화면 골격·RunController / W1 적·입력·정화·도달(좌표·겹침·중복 검사).
- **P1** 회수(25%, 4연속 피티, Wave 6개 상한)·덱(14/26)·자모 정리(추가/교체/건너뛰기/제거, 첫 W1 교체 금지) / Forge(전체 셔플, 비복원 추첨, 손패 7, Lock 3, Reroll 2, 최대 Rank 제외, 슬롯·위험 교체, 복원 실패 +8/다음 Reroll +1, 튜토리얼 손패 ㄱㅓㅁㅂㅜㄹㅣ, 목표 핀·부족 자모·스폰 ×1.15) / 22단어 효과 전부·시너지 3종·상태이상 / W5 거대한 ㅁ·결과 화면·재도전.
- **P2** 변형 LIGHT/HEAVY/GUARD(W6~), 합성 C01/C02(복원 후 빌드 확정에서 1회, 미리보기·시너지 손실 표시), 위험 단어 풀 스냅샷(ㅁ 첫 정화 이후 다음 RUN), Hover 정보.
- **P3** 침묵(봉인 4초, 연속 동일 대상 금지, 대상 없으면 10), 질주 ㅇ(통로 표식 순환·예고선, 후반 4타), 탐욕(부하당 보호막 +3/최대 24, 고리 끊기 시 0 + 4초 잠금, 보호막 UI). W20 정화 → RUN 완료.
- **P4** 저장(원자 교체·백업·손상 안내·새 프로필 동의), 전투 직전 체크포인트·전투 중 저장 없음·재개, Forge/정리 행동마다 저장, 종료 정산 1회(result_id), 서고 연구(30/45/90G·조건·즉시 저장), 사전(기본/합성/보스, 복원도 I/II/III), 기록(S5 사건·배지 3종), RUN 시작 구성(덱별 자모 수·제작 가능 단어), 첫 RUN 오프닝, 원본 문장 3단계.
- **P5** 설정(버스 4종 음량, 전체화면, 텍스트 100/125/150, 흔들림 0/50/100, 섬광, 키보드 모드; 즉시 적용·저장), SFX 8보이스·0.05초 간격·경고 우선, G11 모션 프로필(VisualPivot만, 줄이기 시 0), G12 피드백(배너, 문장 피격, 상태 텍스트, 피해 숫자, 정화 fade), 포커스 손실 자동 정지, Esc 최상위 팝업 우선, 로컬 RUN 로그(B12 필드).

## 4. 테스트 (12개, 전부 PASS)

`test_content`(데이터·빈도표·한글 분해), `test_run_controller`(G2·화면 골격), `test_combat`(W1 스폰·입력·정화·도달), `test_deck`, `test_forge`, `test_effects`(B1/B7 전 효과), `test_boss`(W5), `test_variants`(변형·합성·위험 풀), `test_bosses_late`(W10/15/20), `test_save`(저장·재개·정산), `test_library`, `test_settings`. 테스트는 `Meta.saver.path`를 테스트별 파일로 돌리고 로그를 끈다.

## 5. 남은 일 (사람·에셋)

1. **아트**: 자모 글리프 20종(56×56, 현재 Label 텍스트), 종이 배경·외곽 먹 Overlay, 서고 배경·상태 레이어 5종, 보스 글자 4종, 공통 표식, 상태 아이콘 3종, 단어 카드·분류 아이콘 4종, 버튼/패널 Theme, **타이틀 화면**(참고: `art/_reference/title_ex.png`). AI 생성 가능하되 실제 한글은 검수된 폰트로.
2. **음향**: `Sfx.streams`에 id별 AudioStream 등록(hit_ink, purify, sentence_hit, boss_warning, boss_intro, page_turn 등), BGM 2루프+보스 레이어, UI 버스.
3. **검증**: B12 사용자 5명 첫 5분 관찰, 기준 PC 60fps 실측, 클릭 피로 척도.
4. **알려진 미세 이슈**: 합성 사전 항목 표기·설정 탭 문구 등 검수 비차단 지적은 각 검수 보고서 참조.
