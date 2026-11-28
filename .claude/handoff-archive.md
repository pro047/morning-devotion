
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

<!-- 2026-11-22 이동 (/done) -->
## 최신 스트림 — 2026-11-20: sap 설치본 판정 → F-1 M4 파이프라인 완주 (resolved)

**요청**: `/next` → 우선순위 1번 완료 조건 2(설치본 판정 + 운용 규칙 지뢰) → "파이프라인 돌리자" → 병합 전 핸드오프 갱신

**결정**: 확정 결정 표의 2026-11-20 행 2개 (M4 [결정] D:405·406 y · `SANDBOX_EXCLUDE` B안). worktree 생성 전 핸드오프 먼저 커밋(진성 선택)

**변경**
- 7ccb2a8 `docs: 핸드오프 갱신 (sap 5c105a7 판정)` — 머신 상태 sap 설치본, 지뢰 "런처 세션 sap run"(390c768 수정)·"red 게이트"(셸 미수정 + 운용 규칙)
- 3246c30 `chore: sap 샌드박스 밖에서 Xcode xcodeproj 실행 허용` — `.sap/config` `SANDBOX_EXCLUDE` 1줄 (`sap doctor` 통과, WARN 1)
- b0c122e (`pipeline/f-1-m4-screen`, AUTO_COMMIT) — 소스 12·테스트 4·`App.xcconfig`·`MorningDevotion-Info.plist`·`project.xcproj`(xcconfig 참조·Debug/Release base configuration·`INFOPLIST_FILE`)

**주행** (실행 ID 3개, 장부·보관 참고)
1. 16:30 설계 → judge 반박 1 → 설계 되감기 1회 → judge 반박 0·미확인 25 → [결정] 2개로 exit 4 → 진성 y 중계 (`sap approve --relayed y`)
2. 16:54 기준선 통과 → verify(테스트 74개 @Test, VERIFY.md) → red 통과 → impl BLOCKED exit 3 (project.xcproj 쓰기 거부)
3. 17:20 `RESUME_FROM=impl` → impl → green 통과 → DONE exit 0 (17:23)

**지뢰**: 신규 3개 (샌드박스 xcodeproj · PATH 의 CocoaPods xcodeproj · sap worktree tty 중단)

**실측**
- sap 설치본 5c105a7 = 스킬 레포 HEAD (`diff` 0). 재시도 재개 `orchestrate.sh:2129-2131,2318`, impl 빌드 오류 BLOCKED `prompts/impl.md:39-42` (코드 확인)
- red_out.txt `error:` 26줄 전부 `cannot find '…' in scope` — 정상 red (지뢰의 운용 규칙 첫 적용)
- 샌드박스 원인 판별: scratchpad 복사본에서 Xcode xcodeproj `group add-file` exit 0, diff `{ "path": "App.xcconfig" }` 1줄
- green: `xcodebuild test … -quiet` 통과, `test_out.txt` `error:` 0줄. 통과·실패 테스트 개수는 미측정(-quiet)
- 재시도 재개(390c768)·impl 빌드 오류 BLOCKED(bc756f1)는 이번 주행에서 발동하지 않음 — 여전히 실주행 미검증

<!-- 2026-11-22 이동 (/done) -->
## 최신 스트림 — 2026-11-20~22: M4 실물 확인 일부 → F-3 메인 화면 PRD·파이프라인·병합 → 디자인 스타일 (resolved)

**요청**: `/next` → M4 실물 확인(Claude 몫 2개) → 수동 확인 중 "메인 페이지가 필요" → 범위 확정 → `/prd` → 파이프라인 → 병합 → 디자인 스타일 → 글꼴 교체 → 커밋·push

**결정**: 확정 결정 표의 2026-11-20 행 2개, 2026-11-22 행 3개

**변경**
- f84f455 `docs: F-3 메인 화면 PRD 추가` — `docs/prd/f-3-main-page.md` 신규, `00-project.md` 기능 목록 F-3, `f-1-next-devotion.md` 9장 2번 해소 기록, 핸드오프 메모
- f29b2e2 (`pipeline/f-3-main-page`, AUTO_COMMIT) — 소스 8·테스트 4 (`SeenDevotionSearch`, `MainScreen{State,Model,View}`, `DevotionScreen*`, `ContentView`)
- 12c3977 PR #3 병합 (merge commit, `--delete-branch` 없이 → 산출물 복사 뒤 worktree·브랜치 수동 정리)
- 9b760d4 `feat: 메인·묵상 화면 디자인 스타일 적용 (Liquid Glass + 종이 배경)` — `Theme.swift` 신규, `MainScreenView`·`DevotionScreenView`

**주행** (F-3, 엔진 9023b42)
1. 2026-11-22 15:4x 설계 → judge 반박 3(차단 2: 반대쪽 저장 키 기본값 생성, 화면 제목 출처) → 설계 되감기 1회 → judge 반박 0·미확인 9 → [결정] 3개로 exit 4 → 진성 y 중계
2. 16:04 기준선 녹색 → verify(`DevotionScreenModelTests` 37→30 포함) → red(`cannot find 'SeenDevotionSearch' in scope` 20줄 — 정상 red, 운용 규칙 적용) → impl 시도 1 → green → DONE (16:19)

**실측**
- M4 D:414: 실제 키 빌드 `.app/Info.plist` 에 `YouTubeAPIKey`·`UIApplicationSceneManifest`·`UILaunchScreen` 각 1줄, 값 39자가 `Secrets.xcconfig` 와 일치 (값 미출력)
- M4 D:418(부분): `xcodebuild test` 중 0.2초 간격 `lsof -i -a -p` — 앱 프로세스 23회 포착, 소켓 0개. Swift Testing 에서 `XCTestConfigurationFilePath` 설정 여부는 `MyApp.swift:7` 분기와 결과로 본 추정
- M4 D:416(부분)·D:417: 빈 저장소 19:08 실행 스크린숏 — 신약 2020/07/13 플레이어 표시, 영상→날짜·본문·찬송·설교문 순서. "다 봤어요"는 진성 육안
- F-3 D:388·389: `search=2025/09/11&shwhere=subject` HTTP 200, `subjectColor` 1개 `2025/09/11(목) “잠언 23:24-35”` → `no=15155`, 글 15155 `<본문>` `잠언 23:24-35`
- F-3 테스트: worktree·병합 후 main 모두 242 tests / 15 suites 통과 (병합 전 210 / 12)
- 시뮬레이터 상태 표시줄 시각은 Mac 시각을 따른다 (7:08 표시 = 19:08 KST)
- iOS 27.2 SDK 에 `glassEffect(_:in:)`·`GlassEffectContainer(spacing:)`·`Glass.regular/.clear/.interactive()`·버튼 스타일 `.glass`·`.glassProminent` 있음 (swiftinterface grep)

<!-- 2026-11-22 이동 (/done) -->
## 최신 스트림 — 2026-11-22: v0.1.0 태그·실기기 첫 설치 → F-4 이전·다음·F-5 글래스 화살표·스와이프 (resolved)

**요청**: `/next` → "지금 버전을 v0.1.0 으로 태그하고 실제 기기에 받아보자" → 무선 연결 진단 → 영상 출처·할당량 질문 → 유료 가입 보류 → gitignore·핸드오프 반영

**결정**: 확정 결정 표의 2026-11-22 행 2개 (버전 태그 = `MARKETING_VERSION`, 무료 Personal Team 유지·매주 재설치). 유료 Developer Program(연 99달러)은 보류 — 원화 금액은 미확인

**변경**
- f2fbe54 `chore: v0.1.0 실기기 설치용 서명·번들 ID·버전 설정` — `project.xcproj` 1파일 (+5 −4): `DEVELOPMENT_TEAM`(Xcode UI 가 기록), 번들 ID 2개, `MARKETING_VERSION` 0.1.0 ×2. main push, 태그 `v0.1.0`(annotated) push — 실측 `git ls-remote --tags origin`
- 미커밋: `.gitignore` `build-device/` 추가, 이 핸드오프·아카이브

**지뢰**: 지뢰 섹션 "공용 Wi-Fi 에선 실기기 무선 연결이 안 된다" (이번에 밟음)

**실측**
- 회귀: `xcodebuild test -scheme MorningDevotion -destination id=62A98FA5…` → `242 tests in 15 suites passed`, `TEST SUCCEEDED` (`| tail` 파이프라 종료 코드는 문구로 판단)
- 기기 빌드: `xcodebuild build … -allowProvisioningUpdates` exit 0, `BUILD SUCCEEDED`, 서명 `Apple Development: pro047@naver.com` (인증서는 이 빌드 중 자동 생성 — 직전 `find-identity` 0개)
- 설치: `devicectl device install app` → `App installed`, `bundleID: com.pro047.morningdevotion`. 진성이 실기기에서 메인 두 줄·묵상 화면 영상 재생 확인 (완료 조건 b)
- 영상 ID 저장 없음 — `UserDefaults` 사용처는 `ReadingProgressStore.swift` 뿐(실측 grep). 검색 경로 묵상은 화면을 열 때마다 `search.list` 1회
- 할당량: Google 문서 기본 10,000 단위/일, `search.list` 비용은 판본마다 100 단위 또는 별도 하루 100회 — 어느 쪽이든 약 100회/일, 태평양 자정(11월 = KST 17:00) 초기화. 이 키의 콘솔 값은 미확인
- 범위 밖 관찰(안 고침): `DevotionScreenModel.swift:91` 키가 비면 글 페이지 iframe 이 있어도 영상 없음 — 키 검사가 R-1 보다 먼저. PRD 의도인지 미확인 (확정 결정 표 "API 키 없음은 검색 없이 '영상을 찾지 못했습니다'" 행과 관련)
- `rm -rf build-device` 는 권한 거부 — 폴더는 남아 있고 gitignore 로 처리

**요청 (이어서)**: "하루에 묵상 하나씩이 강제되는데 유연하게" → (b) 제한 해제 + 이전·다음 → `/prd` F-4 → `sap run` → D:413 확인·원격 설치 → "더 이쁜 버튼" → A안(원형 글래스) + 스와이프 → `/prd` F-5 → `sap run` → 실기기 전부 통과 → PR 하나 → 병합·정리

**결정 (이어서)**: 확정 결정 표의 2026-11-22 F-4·F-5 행 5개. 설계 게이트 두 번 모두 승인 뷰 그대로 보이고 y 중계

**변경 (이어서)**
- a29a2d2 `docs: F-4 이전·다음 묵상 이동 PRD 추가`, 43123e7 `chore: build-device 빌드 산출물 gitignore 추가`, b066cdf `docs: 핸드오프 갱신 (2026-11-22)` — main push
- 233fca8 (`pipeline/f-4-prev-next`, AUTO_COMMIT) — 14파일 +1755 −402 (`AdjacentDevotionSearch` 신규, `ReadingProgressStore` finishedDay 제거, Main/Devotion Screen*)
- 5d47244 `docs: F-5 … PRD 추가` — F-4 브랜치에 커밋
- f8dff06 (`pipeline/f-5-glass-nav-swipe`, AUTO_COMMIT) — 11파일 +1091 −55 (`NavigationRules` 신규, Theme 글래스 버튼)
- 512df03 PR #4 병합 (`gh pr merge --merge`, `--delete-branch` 안 씀 — 지뢰 "gh pr merge --delete-branch")

**실측 (이어서)**
- F-4 주행: 설계 → [결정] 4개 y → baseline·verify·impl·green, 시도 1/3, 되감기 0. 체크리스트 Attention 9 · [사실] 7
- F-5 주행: 설계 → judge 반박으로 설계 되감기 1회 → [결정] 5개 y → green, 시도 1/3. Attention 10 · [사실] 13
- D:413: `curl` 날짜 검색 32페이지(2025/09/04~18·2020/07/04~20) — 페이지당 글 0~1개, 날짜 불일치 0. 빈 날은 일요일 5개. 2025/09 글 13개 전부 잠언
- 실기기 무선 설치: 아이폰 핫스팟에서 `devicectl` `available (paired)` → F-4 빌드·F-5 빌드 차례로 `App installed`
- 병합 전 `xcodebuild test` 314 tests / 17 suites 통과 (242 → 314)

<!-- 2026-11-23 이동 (/done) -->
## 최신 스트림 — 2026-11-22: 메인 이동 로딩 스피너 제거·앱 아이콘 (resolved)

**요청**: "메인에서는 이전 다음 시 로딩 이미지를 안 보여주는 게 낫겠다" (이상한 점 = 스피너 자체 + 카드 높이 변화 둘 다) → 커밋 → 실기기 설치 → "기본 아이콘 말고 다른 걸로" → "지금 메인에 맞춰서" → 커밋·푸시 → PR → 병합 → 브랜치 삭제

**결정**: 확정 결정 표의 2026-11-22 "메인 줄 … 로딩 스피너 없음"·"앱 아이콘" 행. main 에서 시작해 `fix/main-nav-no-spinner` 브랜치로 커밋 → PR #5 → merge commit 병합 (PR #4 와 같은 방식)

**변경**
- 1c54421 `fix: 메인 이전·다음 이동 중 로딩 스피너 제거` — `MainScreenView.swift` `movingAndNotice` 에서 `ProgressView` 3줄 삭제. 함수 이름은 그대로(이제 알림 문구만 — 범위 밖이라 안 바꿈)
- a327a31 `feat: 메인 화면 톤의 앱 아이콘 추가` — `AppIcon.appiconset`(PNG + Contents.json, universal/ios 1024), `project.xcproj` 앱 타깃에 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. 그 전엔 AppIcon 세트·설정 둘 다 없어서 기본 아이콘이었다(실측 `ls`·`rg` 0건)
- PR #5 병합 3ffd61f, 브랜치 로컬·원격 삭제

**지뢰**: 지뢰 섹션 "`Executed 0 tests` 는 XCTest 줄"·"NSGraphicsContext(bitmapImageRep:) 새까만 PNG" (이번에 밟음)

**실측**
- 실기기 설치 두 번(21:53 1c54421, 21:59 a327a31) 모두 Wi-Fi 로 `App installed`. 이 Wi-Fi 가 공용인지는 미확인 — 지뢰 "공용 Wi-Fi" 와 모순 아님
- 빌드된 앱 `Info.plist` `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName = "AppIcon"`, 번들에 `AppIcon60x60@2x.png`·`AppIcon76x76@2x~ipad.png`
- `sun.horizon.fill` 팔레트 순서: `paletteColors: [a, b]` 에서 a = 지평선, b = 해·햇살 (`[주황, 잉크]` 은 반대로 나옴). `sunrise.fill` 은 화살표가 붙어 버림
- 실기기 눈 확인 (2026-11-23, 진성): 이전·다음 때 스피너 없음·카드 높이 그대로, 홈 화면 아이콘은 설치 직후 바로 새 것 (재부팅 불필요 — "아이콘 캐시" 추정은 해당 없었음)

<!-- 2026-11-23 이동 (/done) -->
## 최신 스트림 — 2026-11-23: 2025 묵상 영상이 생방송으로 나오는 버그 → F-6 설교 영상 검색 (resolved)

**요청**: `/next` → PR #5 실기기 눈 확인 통과 반영 → "묵상 영상 어떻게 가져오나" → "2025/09/13(토) 잠언 24:11-22 에서 20분 설교가 아니라 새벽예배 생방송이 나온다, 다른 영상도" 원인 찾기(완료 조건 b: 원인 + 수정안) → "R-2·R-1 순서 바꾸기는?" → 생방송 대체 안 됨·캐시는 나중 → (b) 검색만 + PRD 먼저 + 파이프라인 → 실기기 설치 → D:165·166·167 통과 → `/done` → 핸드오프 커밋 → "F-6 마무리, PR 만들고 병합까지" → 원격 브랜치 삭제 → `/done`

**결정**: 확정 결정 표 2026-11-23 행 3개. PRD 는 M3 직접 수정 대신 새 F-6(`sap run` 이 `docs/prd/<feature>.md` 를 자동 주입하므로 이름을 맞춤, `.pipeline/f-1-m3-video/` 복원본과 이름 겹침 회피). PRD·fixture 는 main 에 직접 커밋(F-5 PRD 와 같은 방식, 진성 결정)

**변경**
- 689063d `docs: F-6 설교 영상 찾기 PRD와 2025 검색 fixture 추가` (main) — `docs/prd/f-6-sermon-video.md`(신규), `00-project.md` F-6 행, `f-1-m3-video.md` "F-6 이 대체" 머리 줄, `MorningDevotionTests/Fixtures/yt-search-20250913.json`(`q=잠언 24:11-22` 응답 원문, 키 문자열 grep 0건)
- 04ca7ec `feat: f-6-sermon-video 파이프라인 구현` (`pipeline/f-6-sermon-video`, sap 자동 커밋) — `DevotionVideoFinder.swift` +58, `DevotionScreenModel.swift` 8줄, 테스트 2파일 (실측 `git diff --stat main..HEAD`)
- 핸드오프: PR #5 눈 확인 반영(머신 상태 실기기 줄·우선순위 1 삭제), 이번 /done
- f757c9f `docs: 핸드오프 갱신 (2026-11-23)` · a630f21 `docs: F-6 PRD에 설계 결정 D:160·D:161 반영` (PRD 6-1절) — 둘 다 main
- main push(3ffd61f..a630f21) → PR #6 (https://github.com/pro047/morning-devotion/pull/6) → merge commit 병합 f907863 → 로컬 main ff → `sap clean` → 원격 브랜치 삭제

**지뢰**: 지뢰 섹션 "2025 묶음 글 페이지 embed 는 생방송"·"`q=<날짜> <본문>` 0건"·"worktree 에는 Secrets.xcconfig 없음"·"실기기 잠금" (이번에 밟음)

**실측**
- 원인 재현: 글 `no=15160` embed 1개 `ut225mKfy2w`(생방송, 5416초) ← 코드 `DevotionVideoFinder.swift:134`(F-6 전) 이 첫 embed 를 쓰고 검색 생략. 설교 `kH2QadelWio`(1276초, `isLiveContent false`)
- 본문만 검색 첫 결과: 2020 `M5VtIg1WAic`·2022 `UsCVP4y7snI`·2023 `BCN20b7Yuk0`·2025 `T8fZYU9Pd0E`/`kH2QadelWio` — 전부 1번째 (PRD 7장)
- 파이프라인: 설계 → judge(미확인 8·반박 0) → [결정] D:160·D:161 y(`sap answer`) → 기준선 통과 → red 확인 → impl → green 통과 → DONE (시도 1/3, 되감기 0). 엔진 `9023b42`
- 검증: 셸 `TEST_CMDS`(`xcodebuild test … -quiet`) green 통과 — 런처가 PR 전에 worktree 에서 `-quiet` 없이 다시 돌려 `331 tests in 17 suites passed`, `TEST SUCCEEDED`, `EXIT=0`
- 실기기: 04ca7ec 빌드 `EXIT=0`·`App installed` 2026-11-23 15:11. 진성 확인: D:165 2025/09/13 설교 영상(약 21분), D:166 신약 2020 재생, D:167 구약 3~4일 이동해도 "영상 없음" 아님 — 전부 통과
- PR #5 실기기 눈 확인(2026-11-23 진성): 스피너 없음·카드 높이 그대로·아이콘은 설치 직후 바로 새 것

<!-- 2026-11-26 이동 (/done) -->
## 최신 스트림 — 2026-11-23: v0.2.0 태그와 릴리즈 노트 (resolved)

**요청**: `/next` → "지금까지 작업된 걸 v0.1.0 으로 하고 릴리즈 노트 작성" → v0.1.0 이미 원격에 있음 확인 → (b) 새 `v0.2.0` → 빌드 번호도 올림·노트는 `docs/` 하위·`release/` 브랜치로 나눠 main 병합 → push·로컬 브랜치 삭제 → `/done`

**결정**: 확정 결정 표 2026-11-23 "`v0.2.0`" 행 (태그 안 옮김 — 원격 태그를 옮기면 같은 이름이 두 커밋을 가리키게 돼서)

**변경**
- b373126 `chore: v0.2.0 버전 올림과 릴리즈 노트 추가` (`release/v0.2.0`) — `project.xcproj` `MARKETING_VERSION` 0.1.0→0.2.0·`CURRENT_PROJECT_VERSION` 1→2 (각 2곳, :44·:63·:94·:96), `docs/release-notes/v0.2.0.md`(신규 46줄, 범위 `v0.1.0..f907863`)
- 98e8024 `Merge branch 'release/v0.2.0'` (main, `--no-ff`) · annotated tag `v0.2.0` → 98e8024
- `git push origin main`·`git push origin v0.2.0` · `git branch -d release/v0.2.0`
- 핸드오프: 이전 스트림(F-6) 아카이브 이동, 이번 /done

**지뢰**: 지뢰 섹션 "`PIPESTATUS` … `EXIT=` 로 비어" (이번에 밟음)

**실측**
- `git ls-remote --tags origin` 에 `v0.1.0^{}` = f2fbe54 (세션 시작 시 이미 push 돼 있었음), 이후 `v0.2.0^{}` = 98e8024
- 검증: `xcodebuild test -project MorningDevotion.xcodeproj -scheme MorningDevotion -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2'` → `331 tests in 17 suites passed`, `** TEST SUCCEEDED **`, 셸 종료 코드 0
- 미검증: 노트 첫 줄 v0.1.0 링크(`…/releases/tag/v0.1.0`, GitHub 릴리즈 없음)가 열리는지 · 버전 0.2.0 빌드의 실기기 표시

<!-- 2026-11-26 이동 (/done) -->
## 최신 스트림 — 2026-11-26: F-7 "다 봤어요"를 이전·다음 캡슐로 (resolved)

**요청**: "다 읽었어요"(실제 이름 "다 봤어요") 버튼을 본문 끝에서 이전·다음 캡슐 가운데로 → 파이프라인·완료 조건 (b) 빌드·테스트 + 시뮬레이터 스크린숏·글자 버튼 → 실수 방지안 (스크롤 조건 추천했으나 진성은 영상만 보고 바로 누르고 싶음 → 확인 창) → PRD → 커밋·`sap run` → 스크린숏 → 확인 창 위치 수정 → 취소는 바깥 탭으로 PRD 수정 → 실기기 무선 설치 → 글자색 `.primary` → 커밋·push·PR 병합·산출물 복사·정리 → `/done`

**결정**: 확정 결정 표 2026-11-24 "F-7" 행, 2026-11-26 "F-7 확인 창"·"PR #7"·"무선" 행

**변경**
- d940903 `docs: F-7 "다 봤어요" 캡슐 이동 PRD 추가` (main) — `docs/prd/f-7-finish-in-capsule.md` 신규, `00-project.md` 기능 목록 F-7 행
- eddce28 `feat: f-7-finish-in-capsule 파이프라인 구현` (sap 자동 커밋) — `DevotionScreenView/Model/State.swift`, `DevotionScreenModelTests.swift` +419
- a196b55 `fix: "다 봤어요" 확인 창을 캡슐 버튼에 붙여 아래에 뜨게 함` — `.confirmationDialog` 를 body → 캡슐 버튼
- fee52ab `docs: F-7 PRD 확인 창 취소를 바깥 탭으로 고침` — US-2·6장·9장(D:165 결정)
- 5086360 `fix: "다 봤어요" 글자색을 화살표와 같은 기본색으로 변경` — `.tint` → `.primary`, PRD US-1 기준 2
- PR #7 → 병합 18c343c (merge commit), 브랜치 로컬·원격 삭제, `.pipeline/f-7-finish-in-capsule/` 메인 복사
- 메모리 `device-update-wireless.md` 신규

**지뢰**: 지뢰 섹션 "아이폰 Wi-Fi"·"`.confirmationDialog` 를 화면 전체에" (이번에 밟음). 기존 "Simulator.app 없음"·"`sap worktree` 미커밋 중단"(`WT_YES=1` 로 진행)·"worktree `Secrets.xcconfig`" 도 다시 밟음

**실측**
- 파이프라인: 설계 게이트 [결정] 1개(D:165 y) → 기준선 통과 → red 확인 → green 통과 → 자동 커밋 eddce28 (`sap run` exit 0)
- 시뮬레이터(디버그 훅 사본, worktree 코드 무변경) 스크린숏: 안 읽은 글 캡슐 `‹ 다 봤어요 ›` 라이트·다크, 읽은 글 점, 확인 창 수정 전 위쪽 말풍선 → 수정 후 캡슐 위
- 검증: `xcodebuild test -project MorningDevotion.xcodeproj -scheme MorningDevotion -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2'` → `346 tests in 17 suites passed`, `** TEST SUCCEEDED **` (글자색 변경 후)
- 미검증: 이동 중 로딩 표시·네트워크 오류 화면의 스크린숏 · D:171 44pt

<!-- 2026-11-27 이동 (/done) -->
## 최신 스트림 — 2026-11-26: F-8 글을 다 불러온 뒤에 캡슐 보이기 (resolved)

**요청**: 묵상 화면 진입 시 이전·다봤어요·다음 캡슐이 화면 가운데에 뜸 → 로딩 뒤에 보이게 → (곁가지) 본문 스크롤이 가끔 잘 안 됨 확인 → 재현 안 됨, 코드로만 → 보류·기록 → 캡슐: 오류 화면도 숨김·완료 조건(실기기+TEST_CMDS)·파이프라인 → PRD → 커밋 → `sap run` → 실기기 무선 설치 → [사실] 6개 확인 → PR → 병합 → 정리 → `/done`

**결정**: 확정 결정 표 2026-11-26 "F-8"·"PR #8"·"본문 스크롤 보류" 행

**변경**
- 09aa283 `docs: F-8 캡슐 로딩 후 표시 PRD 추가` (main) — `docs/prd/f-8-capsule-after-load.md` 신규, `00-project.md` 기능 목록 F-8 행
- 8cb5bc3 `feat: f-8-capsule-after-load 파이프라인 구현` (sap 자동 커밋) — `DevotionScreenModel.swift` `showsCapsule` +7, `DevotionScreenView.swift` `safeAreaInset` 안 `if model.showsCapsule`, `DevotionScreenModelTests.swift` +280
- PR #8 → 병합 a1ba5d2 (merge commit), 브랜치 로컬·원격 삭제, `.pipeline/f-8-capsule-after-load/` 메인 복사
- 현재 우선순위 14번(스크롤 보류) 추가

**지뢰**: 기존 "`sap worktree` 미커밋 중단" 다시 밟음 (`WT_YES=1` 로 진행), "worktree `Secrets.xcconfig`" 는 `EXTRA_FILES` 로 피함 (지뢰 줄에 덧붙임)

**실측**
- 파이프라인: design DONE(계약 3파일·기준 8개·[결정] 0개 → 설계 게이트 생략) → judge: codex `gpt-6-astra` 리밋으로 claude-opus 폴백, 미확인 4·반박 1(비차단 — 테스트 도우미 좌표 `Env` :80·`old0912` :815)·차단 0 → 기준선 통과 → red 확인 → green 통과 → 자동 커밋 8cb5bc3 (`sap run` exit 0). 비용 design $1.15·judge $1.11·impl $0.30 (로그)
- impl 에이전트는 샌드박스에서 시뮬레이터를 못 찾아 테스트를 못 돌렸고(`Unable to find a device`), 셸 게이트가 밖에서 돌려 green
- 검증: `xcodebuild test -project MorningDevotion.xcodeproj -scheme MorningDevotion -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2'` → `359 tests in 17 suites passed`, `** TEST SUCCEEDED **` (PR 직전)
- 미검증: 캡슐이 가운데 뜨던 원인(`safeAreaInset` 이 작은 content 에 붙음)은 코드 기준 추정 — 수정이 상태로 숨기는 것이라 결과는 같음 · 스크린숏 없음(실기기 육안만)



<!-- 2026-11-27 이동 (/done) -->
## 최신 스트림 — 2026-11-26~27: F-9 성경 본문 바텀시트 (resolved)

- **요청**: "성경 전체를 가져올 수 있음?" → 묵상 본문을 앱에서 같이 보기. 번역 차이 설명·교회가 쓰는 번역 대조 → 개역개정 결정 → F-9 PRD → 파이프라인 → 실기기 → 여백 → PR 병합
- **결정**: 확정 결정 표 2026-11-26 "개역개정"·"F-9 B안"·"F-9 설계 [결정]", 2026-11-27 "여백·PR #9" 행. 바텀시트·플로팅 버튼은 진성 직접 입력("플로팅 버튼을 두고 눌렀을 때 바텀시트")
- **변경**: 9b1439d PRD(`docs/prd/f-9-bible-passage.md`, `00-project.md` F-9 행) · 7a3c15f sap 구현(12파일, 2,202줄 추가) · 12daaf1 `.padding(.top, 16)` · PR #9 병합 103d546
- **지뢰**: 지뢰 절 "커밋 안 된 PRD", "샌드박스 bskorea 차단", "DESIGN.md.crashed", "pipefail grep -v" (이번에 추가)
- **실측**:
  - 번역 대조: 잠언 23:25 `너를 낳은`(개역개정)·23:27 `구덩이`, 요한복음 5:30·31-32·36·39-40·41·45-46 개역개정과 일치·개역한글과 불일치 (대한성서공회 `version=GAE/HAN` 페이지)
  - sap 주행: 설계 → judge 반박(차단 1, 63권 코드) 되감기 1 → judge 차단 1(AC-1 의 mal·mat 단언) 되감기 2 → 설계 에이전트 `ENOTFOUND` 사망 → crashed 승인 → judge 반박 0 → [결정] 9개(D:309 n) → 되감기 3 → judge 차단 0 → verify → red(오류 줄 전부 `cannot find 'Bible…' in scope` 와 그 연쇄 — 테스트 문법 오류 아님) → impl 1차 green → 자동 커밋. judge 의 gpt-6-astra 는 2회 리밋 → claude-opus-5-5 로 대체
  - 검증: `xcodebuild test … OS=27.2` 413 tests / 20 suites 통과 (2026-11-27 09:01)
  - 책 코드: `bible.list.js` 66개 코드 = 앱 표 66개 코드 전부 일치, 이름은 요한1·2·3서(사이트) ↔ 요한일·이·삼서(앱·교회 제목) 3개만 다름
  - 기록 안 된 확인: F-9 [사실] 실기기 항목별 결과 (진성 "조아조아"만)
