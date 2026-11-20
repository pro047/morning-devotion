# morning-devotion 핸드오프

최종 갱신: 2026-11-20

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다
- **`sap config` 자동 감지 불가** (실측 2026-11-20): package.json·pyproject·pubspec·go.mod·Cargo.toml 만 찾아서 `.xcodeproj` 저장소는 exit 2. `.sap/config` 는 수동으로 쓴다
- **sap 단계 에이전트는 이 저장소를 컴파일 못 한다** (실측 2026-11-20 f-1-m1-next-pick impl 로그): 샌드박스가 컴파일러 모듈 캐시 쓰기·시뮬레이터 접속을 막아 `swiftc -typecheck`·`xcodebuild` 둘 다 실패. 구현은 컴파일 없이 쓰이고, 판정은 셸이 샌드박스 밖에서 돌리는 `TEST_CMDS` 뿐이다
- **런처 세션에서 `sap run` 은 [결정] 게이트에서 exit 4** (실측 2026-11-20): tty 가 없어서. `APPROVAL_VIEW.md` 를 그대로 보여주고 y 를 받은 뒤 `SAP_ROOT=<worktree> sap approve <feature> DESIGN.md --relayed y`, 재실행은 **`FRESH_DESIGN` 없이** (붙이면 승인한 설계를 버린다)
- **CHECKLIST Attention 에 버린 설계·중복이 섞인다** (실측 2026-11-20): FRESH_DESIGN·승인 재실행 뒤 DECISIONS.tsv 가 회차 0 으로 세 번 쌓여 43줄 중 고유 28, 낡은 것 5. 읽을 때 1회차 항목을 걸러낸다 (sap 쪽에 제보함)
- **fixture html 은 테스트 번들 루트에 평탄화된다** (실측 2026-11-20): `MorningDevotionTests/Fixtures/*.html` → `MorningDevotionTests.xctest/*.html` (하위 폴더 없음)

## 확정 결정

| 날짜 | 결정 | 근거 위치 |
|---|---|---|
| 2026-11-20 | 형식이 깨진 날짜 `2009/2/19/(목)` 도 관대하게 파싱 (M1 설계 [결정] D:244 에 y) | `.pipeline/f-1-m1-next-pick/DESIGN.md:244`, 테스트 `ac12_brokenDateParsedLeniently` |
| 2026-11-20 | 책 이름 줄임 표기(`고린도전`) 처리는 M3 로 미룸 — M1 은 날짜만으로 고른다 | `docs/prd/f-1-m1-next-pick.md` 하지 않는 것 |
| 2026-11-20 | F-1 M1 다음 묵상 = 마지막으로 본 날짜 뒤 가장 이른 글, 연도 제한 없음 (설계 [결정] D:277 에 "아니오") | `docs/prd/f-1-m1-next-pick.md` R-4 |
| 2026-11-20 | sap 검증 명령(TEST_CMDS)은 `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -quiet` 한 줄로 수동 설정 | `.sap/config`, 커밋 114993f |

## 머신 상태

기준: 2026-11-20 12:37 KST

- 브랜치 `main`, `origin/main` 보다 4커밋 앞섬 (114993f·a554622·1c8eca7·9971bb0 미push) — 실측 `git status -sb`
- worktree·`pipeline/f-1-m1-next-pick` 브랜치는 정리됨. 산출물은 `.pipeline/f-1-m1-next-pick/` (gitignore, 40파일)에 복사해 둠 — 실측 `git worktree list`
- sap 엔진: M1 주행은 b55f47b. `documents-86` 세션이 `sap config --cmd` 반영본 581e567 을 전역 설치했다고 알려옴 — 그 세션의 메시지가 근거, 이쪽에서 `sap doctor` 로 재확인 안 함
- `documents-86` 에 보낸 것: M1 첫 주행 결과, CHECKLIST 중복·낡은 항목 원인 (msg_id b4914cbe…). 답 대기

## 현재 우선순위

1. F-1 M2(묵상 글 본문 추출 + 진행 위치 저장·"다 봤어요") — 시작 전 PRD `f-1-next-devotion.md` 9장 4번 결정 필요: 처음 진행 위치를 앱에서 입력하나, 미리 넣어 두나
2. M2 범위 후보 — M1 Attention 중 열린 3개: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가, D:249 MainActor 경고 유무(증분 빌드라 미확인)
3. M3 전에 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (2026-11-20 결정: M3 로 미룸)
4. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
5. 미push 4커밋 push 여부 결정

## 최신 스트림 — 2026-11-20: F-1 M1 다음 묵상 고르기 (resolved)

**요청**: F-1 PRD 로 작업 이어가기 → M1(다음 묵상 고르기), 완료 조건 2번(US-1 두 사례 + 표기 차이 + 시간대 경계), 파이프라인 경로

**결정**
- 범위 문서 `docs/prd/f-1-m1-next-pick.md` 를 feature 이름과 맞춰 sap 자동 주입·보호. F-1 원본은 `REQUIRED_DOCS` 로 넘김
- 1회차 설계 [결정] D:277(달력 연도를 묶음 경계로) 에 아니오 → R-4 를 "마지막으로 본 날짜 뒤 가장 이른 글, 연도 무관" 으로 바꾸고 FRESH_DESIGN 재실행
- 2회차 [결정] D:244(깨진 날짜 관대 파싱) 에 y
- 책 이름 줄임 표기는 M3 로

**변경**
- a554622 `docs: F-1 M1 범위 문서와 묵상 목록 fixture 추가` (+ 핸드오프 신규)
- 1c8eca7 `docs: F-1 M1 다음 묵상 규칙을 연도 무관으로 변경` (+ fixture `cast-search-isaiah-19.html`)
- 9971bb0 `feat: f-1-m1-next-pick 파이프라인 구현` — 소스 4 (`MorningDevotion/Devotion/`), 테스트 4. main 에 fast-forward 병합

**지뢰**: 위 지뢰 섹션 신규 4건 (모두 이 스트림에서 실측)

**실측**
- 해 넘김 연속: 2025/12/31 이사야 18:1-7 → 2026/01/02 이사야 19:1-15, 2020/12/31 고린도전서 3:1-9 → 2021/01/02 고린도전서 3:10-23
- 파이프라인: 기준선 통과 → red 확인 → green 통과, attempt 1/3, 되감기 0
- 병합 후 main 에서 `TEST_CMDS` → exit 0, xcresult 39/39 통과, 실패 0
- Attention 28개 분류: 낡음 5 · 풀림·무관·해소 20 · 열림 3 (위 우선순위 2)

## 이전 스트림 — 2026-11-20: sap 검증 명령 설정 (resolved)

**요청**: `sap config` 실패("검증 명령 후보를 못 찾았다") 해결

**결정**
- 근본안: sap 에 사용자 지정 명령 입구(`--cmd`)를 추가해 기존 "돌려서 통과한 것만 기록" 루프를 태우는 쪽. Xcode 자동 감지 분기는 시뮬레이터 이름·OS 가 머신마다 달라 비추천 → `documents-86` 세션에 전달
- 당장은 `.sap/config` 수동 작성으로 진행

**변경**
- 114993f `chore: sap 파이프라인 검증 명령 설정 추가` — `.sap/config` 신규, `.gitignore` 에 `.pipeline/`

**지뢰**: 위 지뢰 섹션 3건 (모두 이 스트림에서 실측)

**실측**
- `xcodebuild test … name=iPhone 17,OS=27.2 -quiet` → exit 0, 약 106초, xcresult `totalTestCount 1 / passed 1 / failed 0`
- `sap doctor` → exit 0, 전 항목 OK
