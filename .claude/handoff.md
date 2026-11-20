# morning-devotion 핸드오프

최종 갱신: 2026-11-20

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다. `simctl list devices available | grep "iPhone 17"` 의 첫 줄은 26.5 쪽이라 거기에 `simctl install` 하면 exit 16 ("Have 26.5; need 27.0") — 27.2 쪽 UDID 는 `62A98FA5-B5D0-46B5-BF44-E675E7507CA3`
- **`sap config` 자동 감지 불가** (실측 2026-11-20): package.json·pyproject·pubspec·go.mod·Cargo.toml 만 찾아서 `.xcodeproj` 저장소는 exit 2. `.sap/config` 는 수동으로 쓴다
- **sap 단계 에이전트는 이 저장소를 컴파일 못 한다** (실측 2026-11-20 f-1-m1-next-pick impl 로그): 샌드박스가 컴파일러 모듈 캐시 쓰기·시뮬레이터 접속을 막아 `swiftc -typecheck`·`xcodebuild` 둘 다 실패. 구현은 컴파일 없이 쓰이고, 판정은 셸이 샌드박스 밖에서 돌리는 `TEST_CMDS` 뿐이다
- **런처 세션에서 `sap run` 은 [결정] 게이트·재시도 게이트에서 exit 4** (실측 2026-11-20): tty 가 없어서. 재시도 게이트(FAIL_LOG.md)를 y 로 승인하고 재실행하면 attempt 2 가 아니라 **기준선부터** 돈다 — attempt 1 의 미커밋 파일이 남은 worktree 라 "기준선이 이미 빨갛다" 로 DIED (엔진 9671033, sap 쪽에 제보함). `APPROVAL_VIEW.md` 를 그대로 보여주고 y 를 받은 뒤 `SAP_ROOT=<worktree> sap approve <feature> DESIGN.md --relayed y`, 재실행은 **`FRESH_DESIGN` 없이** (붙이면 승인한 설계를 버린다)
- **CHECKLIST Attention 에 버린 설계·중복이 섞인다** (실측 2026-11-20, 엔진 b55f47b): FRESH_DESIGN·승인 재실행 뒤 DECISIONS.tsv 가 회차 0 으로 세 번 쌓여 43줄 중 고유 28, 낡은 것 5. 9671033 에서 고쳤다고 sap 쪽이 알려옴 — M2 주행(9671033) Attention 9개에는 중복 없음 (실측)
- **red 게이트는 테스트 빌드 실패도 red 로 친다** (실측 2026-11-20 M2 1차): verify 가 쓴 테스트의 문법 오류로 red 통과 → impl 은 테스트를 못 고쳐 green 불가. red_out.txt 에 `build failed` 가 있으면 의심한다
- **Swift raw string 안의 `"#`** (실측 2026-11-20): `#"... href="#" ..."#` 는 `"#` 에서 문자열이 닫혀 컴파일 오류. HTML fixture 조각엔 `##"…"##`
- **worktree 의 `git clean -fd` 는 `MorningDevotion.xcodeproj/project.xcworkspace/xcshareddata/` 도 지운다** (실측 2026-11-20): 빌드가 만드는 미추적 폴더. 지워도 빌드 통과
- **zsh 에서 `PIPESTATUS` 는 비어 있다** (실측 2026-11-20): `xcodebuild … | tail` 의 종료 코드는 xcresult `result` 로 대신 본다
- **프로젝트 파일 이름이 `project.xcproj`** (실측 2026-11-20): `MorningDevotion.xcodeproj/project.pbxproj` 는 없다. 빌드 설정(번들 ID 등)은 `xcodebuild -showBuildSettings` 로 본다 — 번들 ID `devplaceholder.NX9W6E9P.MorningDevotion`
- **`simctl launch --console-pty` 프로세스를 kill 하면 앱도 같이 종료된다** (실측 2026-11-20 D:295): 뒤이은 `simctl terminate` 는 exit 3 "found nothing to terminate"
- **`gh pr merge --delete-branch` 가 그 브랜치의 worktree 를 폴더째 지운다** (실측 2026-11-20 PR #1, gh 2.100.0): 06:59 에 테스트가 돈 worktree 가 07:01 병합 직후 `No such file`. gitignore 대상인 `.pipeline/<f>/` 산출물이 같이 사라졌다. 순서는 **① 산출물 복사 → ② PR 병합 → ③ worktree 정리**. 잃었으면 `~/.claude/projects/-Users-ijinseong-Documents-morning-devotion-pipeline-<f>/*.jsonl` 의 Write 입력으로 DESIGN·JUDGE·VERIFY·IMPL 을 되살릴 수 있다 (M3 에서 DESIGN·JUDGE 바이트 수 일치 실측, `.pipeline/f-1-m3-video/RESTORED.md`)
- **fixture html 은 테스트 번들 루트에 평탄화된다** (실측 2026-11-20): `MorningDevotionTests/Fixtures/*.html` → `MorningDevotionTests.xctest/*.html` (하위 폴더 없음)

## 확정 결정

| 날짜 | 결정 | 근거 위치 |
|---|---|---|
| 2026-11-20 | 형식이 깨진 날짜 `2009/2/19/(목)` 도 관대하게 파싱 (M1 설계 [결정] D:244 에 y) | `.pipeline/f-1-m1-next-pick/DESIGN.md:244`, 테스트 `ac12_brokenDateParsedLeniently` |
| 2026-11-20 | 책 이름 줄임 표기(`고린도전`) 처리는 M3 로 미룸 — M1 은 날짜만으로 고른다 | `docs/prd/f-1-m1-next-pick.md` 하지 않는 것 |
| 2026-11-20 | F-1 M1 다음 묵상 = 마지막으로 본 날짜 뒤 가장 이른 글, 연도 제한 없음 (설계 [결정] D:277 에 "아니오") | `docs/prd/f-1-m1-next-pick.md` R-4 |
| 2026-11-20 | 처음 진행 위치는 앱에 미리 넣어 둔다(구약 2025/09/10, 신약 2020/07/11), 저장값이 없을 때만 | `docs/prd/f-1-next-devotion.md` 9장 4번 |
| 2026-11-20 | "다 봤어요" 뒤 같은 시간대에 다음 묵상을 보여줄지는 M4 에서 정한다 | `docs/prd/f-1-next-devotion.md` 9장 1번 |
| 2026-11-20 | 저장 날짜 형식이 깨지면 저장값 없음으로 보고 기본값을 써 넣는다 (M2 설계 [결정] D:290 에 y) | `.pipeline/f-1-m2-read-and-progress/DESIGN.md:290`, AC-20 |
| 2026-11-20 | "다 봤어요" 날짜가 지금 위치보다 이르거나 같아도 덮어쓴다 (M2 설계 [결정] D:291 에 y) | `.pipeline/f-1-m2-read-and-progress/DESIGN.md:291`, AC-21 |
| 2026-11-20 | M3 부터 파이프라인 결과는 `pipeline/<기능>` 브랜치를 push 하고 PR 로 병합한다 (M1·M2 는 main 에 직접 fast-forward 병합했음) | 이 세션 대화 (2026-11-20 진성 결정) |
| 2026-11-20 | M2 D:295(종료 뒤 진행 위치 유지)는 실기기 대신 시뮬레이터 결과로 대체 — 체크리스트엔 "실기기 미확인" 으로 표시 | 이 세션 대화 (2026-11-20 진성 승인), `.pipeline/f-1-m2-read-and-progress/CHECKLIST.md` D:295 |
| 2026-11-20 | M3 영상은 C안: 글 페이지의 `youtube.com/embed/<id>` 를 먼저 쓰고, 없을 때만 YouTube Data API 로 찾는다 | `docs/prd/f-1-next-devotion.md` FR-5·7장 |
| 2026-11-20 | 2025 영상은 설교 편집본이 아니라 글 페이지에 걸린 생방송 영상이어도 된다 (재생 위치는 진성이 조절) | `docs/prd/f-1-next-devotion.md` US-2 수용 기준 1 |
| 2026-11-20 | M3 는 글 페이지 추출과 API 대체 경로를 한 마일스톤으로 (나누지 않음, API 키 발급 완료) | `docs/prd/f-1-m3-video.md` |
| 2026-11-20 | 본문을 장·절로 못 읽은 묵상(passage nil)은 본문 글자가 영상 제목과 정확히 같을 때만 그 영상을 고른다 (M3 설계 [결정] D:207 에 y) | `.pipeline/f-1-m3-video/DESIGN.md:207` (복원본) |
| 2026-11-20 | sap 검증 명령(TEST_CMDS)은 `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -quiet` 한 줄로 수동 설정 | `.sap/config`, 커밋 114993f |

## 머신 상태

기준: 2026-11-20 16:07 KST

- 브랜치 `main` = `origin/main` (53ad3f1 = PR #1 병합, 미커밋 없음) — 실측 `git status -sb`
- 시뮬레이터 iPhone 17 / iOS 27.2 (`62A98FA5…`): 꺼 둠. 확인용 빌드 앱이 설치돼 있고 UserDefaults 에 `readingProgress.lastSeenOld = 2025/09/11` 이 남아 있다 (D:295 확인 흔적, 기본값 아님) — 실측 `-probeRead` 출력. 수동 확인 전에 `simctl uninstall` 로 지운다
- worktree 없음, `pipeline/*` 브랜치 로컬·원격 모두 없음 — 실측 `git worktree list` · `git fetch --prune`. 산출물: `.pipeline/f-1-m1-next-pick/`(40파일)·`f-1-m2-read-and-progress/`(51파일)·`f-1-m3-video/`(10파일, **복원본** — 목록·출처는 그 안 `RESTORED.md`. STATE·FAIL_LOG·DECISIONS·MODEL_LOG·result·stream 은 유실)
- sap 엔진: M2 주행 9671033, M3 주행 b2d94d0, 지금 설치본 `bc756f1` (2026-11-20 15:56 설치, M3 주행 도중) — 실측 `sap version`. bc756f1 에 red 게이트·재시도 수정이 들었는지는 미확인
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. F-1 M4(화면) 범위 문서 — 다음 묵상 화면·글 표시·영상 앱 안 재생·"다 봤어요"·안내 문구, API 키를 `Secrets.xcconfig` → Info.plist 로 연결 (M3 범위 문서 6장이 M4 로 넘긴 것). M4 에서 정할 것: F-1 PRD 9장 1번("다 봤어요" 뒤 화면)
2. M3 실물 확인 (`.pipeline/f-1-m3-video/CHECKLIST.md`): D:212 실제 `search.list` 가 이 URL·키로 fixture 같은 JSON 을 주나, D:213 틀린 키·할당량 초과가 non-2xx 인가, D:214 2020 신약 다른 날 영상 제목도 같은 형식인가 — 키 연결(M4) 뒤. D:215·D:216 은 해소(2026-11-20 표본 20건 영상 id 1개씩 실측, green 에서 JSON fixture 테스트 통과)
3. 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (M3 범위에서도 뺌 — 신약 2020 묶음에 사례 없음. 대체 영상 검색이 줄임 표기에 걸리면 그때)
4. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가, D:249 MainActor 경고 (M2 attempt 1 빌드에 `DevotionModels.swift:58` 경고 4건 실측 → 2026-11-20 새 derivedData `build`·`build-for-testing` 에선 Swift 경고 0건 실측. 사라진 이유 미확인)
5. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
6. sap 설치본이 bc756f1 로 바뀌었다 — 다음 주행 전에 red 게이트·재시도 수정이 들었는지 sap 쪽 기록으로 확인

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
