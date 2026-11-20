# morning-devotion 핸드오프

최종 갱신: 2026-11-20

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다. `simctl list devices available | grep "iPhone 17"` 의 첫 줄은 26.5 쪽이라 거기에 `simctl install` 하면 exit 16 ("Have 26.5; need 27.0") — 27.2 쪽 UDID 는 `62A98FA5-B5D0-46B5-BF44-E675E7507CA3`
- **`sap config` 자동 감지 불가** (실측 2026-11-20): package.json·pyproject·pubspec·go.mod·Cargo.toml 만 찾아서 `.xcodeproj` 저장소는 exit 2. `.sap/config` 는 수동으로 쓴다
- **sap 단계 에이전트는 이 저장소를 컴파일 못 한다** (실측 2026-11-20 f-1-m1-next-pick impl 로그): 샌드박스가 컴파일러 모듈 캐시 쓰기·시뮬레이터 접속을 막아 `swiftc -typecheck`·`xcodebuild` 둘 다 실패. 구현은 컴파일 없이 쓰이고, 판정은 셸이 샌드박스 밖에서 돌리는 `TEST_CMDS` 뿐이다
- **런처 세션에서 `sap run` 은 [결정] 게이트·재시도 게이트에서 exit 4** (실측 2026-11-20): tty 가 없어서. 재시도 게이트(FAIL_LOG.md)를 y 로 승인하고 재실행하면 attempt 2 가 아니라 **기준선부터** 돈다 — attempt 1 의 미커밋 파일이 남은 worktree 라 "기준선이 이미 빨갛다" 로 DIED (엔진 9671033, sap 쪽에 제보함). **→ `390c768` 에서 수정** (설치본 5c105a7 포함, 코드 확인 `orchestrate.sh:2129-2131` — `$WORK/retry.pending` 의 시도 번호로 impl 부터 이어감). 가짜 claude 테스트로만 확인, 실주행 미검증 — 승인 재실행 로그에 `↺ 재시도 재개` 와 `── 시도 2/` 가 안 찍히면 이 지뢰가 살아 있는 것 `APPROVAL_VIEW.md` 를 그대로 보여주고 y 를 받은 뒤 `SAP_ROOT=<worktree> sap approve <feature> DESIGN.md --relayed y`, 재실행은 **`FRESH_DESIGN` 없이** (붙이면 승인한 설계를 버린다)
- **CHECKLIST Attention 에 버린 설계·중복이 섞인다** (실측 2026-11-20, 엔진 b55f47b): FRESH_DESIGN·승인 재실행 뒤 DECISIONS.tsv 가 회차 0 으로 세 번 쌓여 43줄 중 고유 28, 낡은 것 5. 9671033 에서 고쳤다고 sap 쪽이 알려옴 — M2 주행(9671033) Attention 9개에는 중복 없음 (실측)
- **red 게이트는 테스트 빌드 실패도 red 로 친다** (실측 2026-11-20 M2 1차): verify 가 쓴 테스트의 문법 오류로 red 통과 → impl 은 테스트를 못 고쳐 green 불가. red_out.txt 에 `build failed` 가 있으면 의심한다. **설치본 5c105a7 에서도 셸 게이트는 미수정** — 패턴 판정은 넣었다 되돌림(`fb3698c`: Swift 는 정상 red 도 `Testing cancelled because the build failed`). 대신 impl 이 테스트 파일 자체의 빌드 오류면 구현 전 BLOCKED 로 verify 재실행을 타게 했다(코드 확인 `prompts/impl.md:39-42`, 모델이 따르는지 미검증). **운용 규칙: red 통과 직후 `red_out.txt` 의 오류 줄이 테스트 파일(`*Tests.swift`) 안의 문법 오류인지, 아직 없는 타입(`cannot find … in scope`)인지 사람이 한 번 본다**
- **Swift raw string 안의 `"#`** (실측 2026-11-20): `#"... href="#" ..."#` 는 `"#` 에서 문자열이 닫혀 컴파일 오류. HTML fixture 조각엔 `##"…"##`
- **worktree 의 `git clean -fd` 는 `MorningDevotion.xcodeproj/project.xcworkspace/xcshareddata/` 도 지운다** (실측 2026-11-20): 빌드가 만드는 미추적 폴더. 지워도 빌드 통과
- **zsh 에서 `PIPESTATUS` 는 비어 있다** (실측 2026-11-20): `xcodebuild … | tail` 의 종료 코드는 xcresult `result` 로 대신 본다
- **프로젝트 파일 이름이 `project.xcproj`** (실측 2026-11-20): `MorningDevotion.xcodeproj/project.pbxproj` 는 없다. 빌드 설정(번들 ID 등)은 `xcodebuild -showBuildSettings` 로 본다 — 번들 ID `devplaceholder.NX9W6E9P.MorningDevotion`
- **`simctl launch --console-pty` 프로세스를 kill 하면 앱도 같이 종료된다** (실측 2026-11-20 D:295): 뒤이은 `simctl terminate` 는 exit 3 "found nothing to terminate"
- **`gh pr merge --delete-branch` 가 그 브랜치의 worktree 를 폴더째 지운다** (실측 2026-11-20 PR #1, gh 2.100.0): 06:59 에 테스트가 돈 worktree 가 07:01 병합 직후 `No such file`. gitignore 대상인 `.pipeline/<f>/` 산출물이 같이 사라졌다. 순서는 **① 산출물 복사 → ② PR 병합 → ③ worktree 정리**. 잃었으면 `~/.claude/projects/-Users-ijinseong-Documents-morning-devotion-pipeline-<f>/*.jsonl` 의 Write 입력으로 DESIGN·JUDGE·VERIFY·IMPL 을 되살릴 수 있다 (M3 에서 DESIGN·JUDGE 바이트 수 일치 실측, `.pipeline/f-1-m3-video/RESTORED.md`)
- **fixture html 은 테스트 번들 루트에 평탄화된다** (실측 2026-11-20): `MorningDevotionTests/Fixtures/*.html` → `MorningDevotionTests.xctest/*.html` (하위 폴더 없음)
- **sap 단계 샌드박스 안에서 Xcode `xcodeproj` 는 `project.xcproj` 를 저장하지 못한다** (실측 2026-11-20 M4 impl): `Failed to write project file: You don’t have permission to save the file “project.xcproj”` exit 1 → impl BLOCKED. 같은 명령을 샌드박스 밖(scratchpad 복사본)에서 돌리면 exit 0. 같은 폴더에 `cp`·`printf` 쓰기는 샌드박스 안에서도 성공(DESIGN.md:55). `.sap/config` 의 `SANDBOX_EXCLUDE=/Applications/Xcode.app/Contents/Developer/usr/bin/xcodeproj:*` (3246c30) 뒤 재실행에서 통과
- **PATH 의 `xcodeproj` 는 Homebrew CocoaPods 도구다** (실측 2026-11-20): `/opt/homebrew/bin/xcodeproj group …` → `Unknown command: group`. Xcode 의 프로젝트 편집 CLI 는 `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodeproj` — 전체 경로로 부른다. `SANDBOX_EXCLUDE` 패턴도 전체 경로라 `xcodeproj …` 로 부르면 안 걸린다 (추정)
- **`sap worktree` 는 메인에 미커밋 변경이 있으면 런처 세션에서 중단된다** (실측 2026-11-20): `이대로 계속? (y/N)` 을 `/dev/tty` 로 읽어 tty 없음 → 중단. 커밋하거나 사람 확인 뒤 `WT_YES=1`

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
| 2026-11-20 | "다 봤어요" 뒤에는 다음 묵상이 아니라 "오늘 구약(신약) 묵상을 마쳤습니다"를 보인다 (A안). 구분마다 누른 날(기기 로컬 날짜)을 저장 키로 추가, 날짜 경계 00:00 | `docs/prd/f-1-next-devotion.md` 9장 1번, `docs/prd/f-1-m4-screen.md` R-5·R-6 |
| 2026-11-20 | 다음 묵상 목록은 날짜 검색(`search=<yyyy/MM/dd>&shwhere=subject`)으로 가져온다. 마지막으로 본 날짜 + 1일부터 하루씩, 최대 7일 | `docs/prd/f-1-m4-screen.md` R-1·7장 1번 |
| 2026-11-20 | 영상 검색 실패(`searchFailed`)는 영상 자리만 "인터넷 연결을 확인해 주세요"로 바꾼다 (화면 전체 오류 아님). API 키 없음은 검색 없이 "영상을 찾지 못했습니다" (이쪽은 Claude 제안, 진성 이의 없음) | `docs/prd/f-1-m4-screen.md` R-4·7장 2번 |
| 2026-11-20 | M4 범위 밖: 시간대 전환 버튼(9장 2번)·다른 해 영상(9장 5번)·임베드 거부 시 유튜브 앱(9장 3번)·설교문 굵은 글씨 | `docs/prd/f-1-m4-screen.md` 6장 |
| 2026-11-20 | M4 설계 [결정] D:405 "글은 받았지만 읽지 못한 경우(파싱 실패·글번호 없음·HTTP 오류)도 '인터넷 연결을 확인해 주세요'+'다시 시도'" 에 y, D:406 "백그라운드 복귀 때 시간대·날짜가 바뀌었으면 다시 불러온다(`refreshIfStale`)" 에 y | `.pipeline/f-1-m4-screen/DESIGN.md:405-406`, `APPROVALS.md`, AC-19·AC-21 |
| 2026-11-20 | sap 단계 에이전트가 Xcode `xcodeproj` 를 샌드박스 밖에서 돌리게 한다 (`SANDBOX_EXCLUDE`, 이번 주행만 런처가 대신 돌리는 A안 대신 B안) | 커밋 3246c30, `.sap/config` |

## 머신 상태

기준: 2026-11-20 18:45 KST

- 브랜치 `main` = `origin/main` = `22d1aad` (PR #2 병합 — M4). `pipeline/f-1-m4-screen` 로컬·원격 삭제 — 실측 `git push origin --delete`, `git branch -d`. 병합 후 main 에서 `xcodebuild test`(TEST_CMDS, -quiet 없이) 210 tests / 12 suites 통과 `TEST SUCCEEDED` (실측)
- 시뮬레이터 iPhone 17 / iOS 27.2 (`62A98FA5…`): 꺼 둠. 확인용 빌드 앱이 설치돼 있고 UserDefaults 에 `readingProgress.lastSeenOld = 2025/09/11` 이 남아 있다 (D:295 확인 흔적, 기본값 아님) — 실측 `-probeRead` 출력. 수동 확인 전에 `simctl uninstall` 로 지운다
- worktree 없음 (`git worktree remove` 실측, `git worktree list` 메인 1개). 산출물: `.pipeline/f-1-m1-next-pick/`(40파일)·`f-1-m2-read-and-progress/`(51파일)·`f-1-m3-video/`(10파일, **복원본** — 목록·출처는 그 안 `RESTORED.md`)·`f-1-m4-screen/`(47파일, worktree 에서 메인으로 복사 — 파일 수 일치 실측). M4 실행 보관 3개: `~/.local/state/sap/archive/morning-devotion-pipeline-f-1-m4-screen/f-1-m4-screen/` (실측 `ls`)
- sap 엔진: M2 주행 9671033, M3 주행 b2d94d0, 지금 설치본 **`5c105a7`** (2026-11-20 16:15 설치, 스킬 레포 `main` HEAD 와 같음) — 실측 `sap version`, `readlink ~/.local/share/sap/current`, `diff` 설치본↔레포 `orchestrate.sh`·`prompts/impl.md` 차이 0. 재시도 재개(`390c768`)·impl 빌드 오류 BLOCKED(`bc756f1`)·die 시 검증 직전 복원(`5c105a7`) 포함, red 게이트 셸 판정은 그대로 (지뢰 두 항목 참고)
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. F-1 M4 실물 확인 (`.pipeline/f-1-m4-screen/CHECKLIST.md`): [사실] 9개 — 실제 키를 `Secrets.xcconfig` 에 넣고 D:414 Info.plist 키, D:415·416 영상 재생, D:417 화면 배치, D:418 테스트 중 네트워크 없음, D:419 실제 날짜 검색. Attention 33개 중 #36(any→some 컴파일)·D:413(Secrets 없이 빌드)은 green 빌드 통과로 사실상 해소 (추정 — 체크는 사람이)
2. M3 실물 확인 (`.pipeline/f-1-m3-video/CHECKLIST.md`): D:212 실제 `search.list` 가 이 URL·키로 fixture 같은 JSON 을 주나, D:213 틀린 키·할당량 초과가 non-2xx 인가, D:214 2020 신약 다른 날 영상 제목도 같은 형식인가 — M4 키 연결 완료 — 지금 가능. D:215·D:216 은 해소(2026-11-20 표본 20건 영상 id 1개씩 실측, green 에서 JSON fixture 테스트 통과)
3. 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (M3 범위에서도 뺌 — 신약 2020 묶음에 사례 없음. 대체 영상 검색이 줄임 표기에 걸리면 그때)
4. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가 (2026-11-20 날짜 검색 페이지 2개에서 `subjectColor` 1개씩 실측 — 부분 근거), D:249 MainActor 경고 (M2 attempt 1 빌드에 `DevotionModels.swift:58` 경고 4건 실측 → 2026-11-20 새 derivedData `build`·`build-for-testing` 에선 Swift 경고 0건 실측. 사라진 이유 미확인)
5. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
6. 미확인: 새 fixture 3개(`cast-search-date-*.html`)는 작업 폴더에 CRLF 로 있고 git 이 LF 로 저장한다는 경고가 나왔다 (실측 `git add` 경고). 파서가 CRLF·LF 에서 같은 결과인지, 기존 fixture 도 같은지 미확인 — 새로 clone 한 곳에서 테스트가 다르게 나오면 여기부터

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
