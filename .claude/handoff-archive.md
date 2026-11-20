
<!-- 2026-11-20 이동 (/done) -->
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

<!-- 2026-11-20 이동 (/done) -->
## 최신 스트림 — 2026-11-20: F-1 M2 묵상 글 읽기와 진행 위치 저장 (resolved)

**요청**: `/next` → F-1 PRD 9장 4번 결정 + M2 범위 문서(완료 조건 2번) → 커밋 → `sap run` → 병합·정리 → push

**결정**
- 처음 진행 위치는 미리 넣어 둔다(B), 저장값이 없을 때만. "다 봤어요" 뒤 화면(9장 1번)은 M4 로
- M2 범위: 글번호 추출·글 주소·가져오기 프로토콜·글 파싱·진행 위치 저장. 실제 네트워크 테스트·굵은 글씨·2009년 형식은 제외
- 설계 [결정] D:290·D:291 둘 다 y
- 1회차 실패 뒤 B(worktree 를 52bef49 로 되돌리고 처음부터). 되돌리기는 권한 거부로 사용자가 `!` 로 직접 실행

**변경**
- 52bef49 `docs: F-1 M2 범위 문서와 묵상 글 fixture 추가` — `docs/prd/f-1-m2-read-and-progress.md` 신규, F-1 PRD 9장 1·4번 기록, fixture `cast-body-15155.html`·`cast-body-11480.html`
- c4e0b12 `feat: f-1-m2-read-and-progress 파이프라인 구현` — 소스 6, 테스트 5. main 에 fast-forward 병합, push

**지뢰**: 위 지뢰 섹션 신규 4건 (모두 이 스트림에서 실측)

**실측**
- 글 형식(2020·2025): `<TITLE>` 에 제목, 본문 `margin:60px` div 안에 굵은 `본문`·`찬송가` 라벨, 날짜 줄 없음. 2025 글에만 유튜브 iframe
- 파이프라인 1차: verify 테스트 193줄 문법 오류 → attempt 1 exit 65 → 재시도 승인 후 재실행이 기준선 빨강으로 DIED
- 파이프라인 2차: 기준선 통과 → red(새 타입 없음 빌드 실패) → green 통과, attempt 1/3, 자동 커밋 c4e0b12. Attention 9개(중복 없음), [사실] 5개
- 병합 후 main 에서 `TEST_CMDS` → xcresult `Passed` 100/0/0 (종료 코드는 zsh `PIPESTATUS` 빈칸으로 못 잡음)


<!-- 2026-11-20 이동 (/done) -->
## 최신 스트림 — 2026-11-20: F-1 M2 실물 확인 D:294~296 (resolved)

**요청**: `/next` → 우선순위 1번(M2 실물 확인 3개), 완료 조건 "3개를 증거와 함께 채우고, 틀리면 기록만"

**결정**
- D:295 는 실기기 대신 시뮬레이터로 대체 (확정 결정 표)
- 확인 방법: 테스트 타깃이 아니라 `MyApp.init` 에 launch arg(`-probeFetch`·`-probeMark`·`-probeRead`) 임시 코드 — 앱 프로세스의 기본 User-Agent 를 그대로 쓰려고. 확인 뒤 `git checkout` 으로 되돌림

**변경**: 커밋 없음. `.pipeline/f-1-m2-read-and-progress/CHECKLIST.md`(gitignore) 의 D:294~296 에 결과·출력 원문 기록

**지뢰**: 위 지뢰 섹션 신규 2건(`project.xcproj`, `--console-pty` kill), 시뮬레이터 이름 중복 항목에 install 사례 추가

**실측**
- D:294 통과: `PROBE fetch ok bytes=19489`, `ac6 passage=true hymn=true prefix=true suffix=true noTag=true`. 2xx 범위만 검사하므로 정확한 200 은 출력에 없음
- D:295 시뮬레이터 통과: 재설치 직후 `old=2025/09/10` → `markSeen` `old=2025/09/11` → 2초 뒤 종료 → 재실행 `old=2025/09/11`. 종료는 console 세션 kill 로 일어남 — 사용자 스와이프 종료와 같은 경로인지는 추정
- D:296 통과: `-quiet` 없는 `build`·`build-for-testing` exit 0, `warning:` 은 appintentsmetadataprocessor 1종뿐
- 되돌린 뒤 `xcodebuild test … OS=27.2 -quiet -resultBundlePath …` → exit 0, xcresult `Passed` 100/0/0, `git status -sb` clean

<!-- 2026-11-20 이동 (/done) -->
## 최신 스트림 — 2026-11-20: F-1 M3 묵상 영상 찾기 (resolved)

**요청**: `/next` → 우선순위 1번(글 페이지 영상 조사) → PRD 반영 → M3 범위 문서 → `sap run` → PR 병합·정리

**결정**
- 2025 영상은 글 페이지의 생방송 영상이어도 된다, M3 는 C안(글 페이지 먼저, 없으면 API) — 확정 결정 표
- PRD 는 고친다(조사 결과가 PRD 7장 전제를 반증) — 사용자 판단
- M3 를 나누지 않음, 설계 [결정] D:207 y — 확정 결정 표
- 커밋 B안(핸드오프·PRD 분리), PR #1 `--merge` 병합

**변경**
- cbbadf0 `docs: 핸드오프 갱신 (2026-11-20)` · 993c818 `docs: F-1 PRD에 글 페이지 영상 실측과 C안 반영`(US-2 기준 1·FR-5·7장·9장)
- fd2d3f4 `docs: F-1 M3 범위 문서와 영상 fixture 추가` — `docs/prd/f-1-m3-video.md`, `cast-body-12602.html`, `yt-search-20200713.json`·`yt-search-20200714.json` (키 문자열 grep 0건)
- 0782bdf `feat: f-1-m3-video 파이프라인 구현` (DevotionVideoFinder·테스트·FixtureLoader, +575 −9) → 53ad3f1 PR #1 병합

**지뢰**: 위 지뢰 섹션 신규 1건(`gh pr merge --delete-branch` 가 worktree 삭제)

**실측**
- 글 페이지 영상(그 달 마지막 글 표본): 2023~2025 18/18 iframe, 2022 2/2 `<a href>`, 2020~2021 0/4. 2025 영상 제목은 `[ 생방송 | 새벽기도회 | … ]`
- YouTube API: 채널 `UCSkjujMSzrh6nghHWTSvIJg`. `q=2020/07/13 요한복음 5:30-47` 첫 결과 `M5VtIg1WAic`. 2020 영상 publishedAt 2020-09-13(일괄 업로드). 영상 4개 `embeddable=true`. 호출 6회
- 할당량: search.list 100 단위, 하루 약 100회 (Google 문서 — 콘솔 미확인)
- 파이프라인(엔진 b2d94d0): judge 는 codex `gpt-6-astra` 리밋·사용 불가로 `claude-opus-5-5` 로 갈아탐(orch-run1.log:34-35) — 같은 회사 모델이 감사. 판정 미확인 6·반박 1(비차단). [결정] 게이트 1회(y 중계) → 기준선·red·green, attempt 1/3, 되감기 0, 자동 커밋 0782bdf
- worktree 에서 `xcodebuild test … OS=27.2 -quiet -resultBundlePath …` → exit 0, 136/0/0. `git diff 0782bdf 53ad3f1` 비어 있음

<!-- 2026-11-20 이동 (/done) -->
## 최신 스트림 — 2026-11-20: F-1 M4 범위 문서 (resolved)

**요청**: `/next` → 우선순위 1번(M4 범위 문서), 완료 조건 2번(범위 문서 + PRD 9장 1번 결정·반영) → 나눠서 커밋 → push

**결정**: 확정 결정 표의 2026-11-20 M4 행 4개 (9장 1번 A안 · 날짜 검색 최대 7일 · 영상 실패는 영상 자리만 · M4 범위 밖 4개). 커밋은 핸드오프·문서 분리, 문서 커밋은 PR 없이 main 에 직접 push (파이프라인 결과만 PR)

**변경**
- 4fe4c63 `docs: 핸드오프 갱신 (F-1 M3 마무리)` — 이전 세션 미커밋분
- 01313b1 `docs: F-1 M4 범위 문서와 날짜 검색 fixture 추가` — `docs/prd/f-1-m4-screen.md`(새 파일, 1~7장), `docs/prd/f-1-next-devotion.md`(US-3 기준 1개 추가·FR-1·6장 3단계·9장 1번 결정), fixture `cast-search-date-20250912.html`·`-20250914.html`·`-20200714.html`
- push `53ad3f1..01313b1 main -> main`

**지뢰**: 신규 없음

**실측**
- 빈틈 발견: 다음 묵상 목록을 어느 주소에서 가져올지가 M1~M3 에 없었다 — M1 은 목록 HTML 을 받기만, M2 는 글 주소만 만든다 (코드 확인 `DevotionArticleURL.swift:9`) → M4 R-1 로 넣음
- 날짜 검색(`shwhere=subject`, 아이폰 Safari UA) 3회 HTTP 200: `2025/09/12` → 1건 `잠언 24:1-10` 글번호 15157, `2025/09/14`(일) → 0건, `2020/07/14` → 1건 `요한복음 6:1-21` 글번호 11481
- 저장 키는 지금 `readingProgress.lastSeenOld/New` 2개뿐, 묵상 날짜만 저장 (코드 확인 `ReadingProgressStore.swift:13-14,35`) — A안이 저장 키를 늘리는 근거
- 문서·fixture 에 API 키 문자열(`AIza`) grep 0건
- 검증: 코드 변경 없음 — 테스트 미실행
