# morning-devotion 핸드오프

최종 갱신: 2026-11-22

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
- **이 Xcode 27.2 에는 Simulator.app 이 없다** (실측 2026-11-20): `open -a Simulator` → "Unable to find application", Xcode.app 안·Spotlight(`com.apple.iphonesimulator`)에도 없음, `idb`·`applesimutils` 미설치. 런처는 `simctl` 로 부팅·설치·실행·스크린숏만 가능하고 탭·스크롤은 못 한다 → 화면 조작이 필요한 확인은 진성이 Xcode ⌘R 로 한다
- **`.pipeline/` 은 gitignore 다** (실측 2026-11-20 `git check-ignore` → `.gitignore:3`): CHECKLIST 체크는 커밋되지 않고 이 맥에만 남는다
- **SwiftUI `.serif` 디자인은 한글에서 궁서처럼 보인다** (2026-11-22 진성 육안): 시뮬레이터 런타임 시스템 폰트 폴더의 한글 글꼴은 `AppleSDGothicNeo.ttc`·`AppleGothic.otf` 뿐(실측 `find`). 명조가 필요하면 폰트 파일을 번들해야 한다
- **카페 등 공용 Wi-Fi 에선 실기기 무선 연결이 안 된다** (2026-11-22 실측): 같은 Wi-Fi 인데 `devicectl` `tunnelState: unavailable`, `_remotepairing._tcp` 0건, ARP 0건 — client isolation 추정. 아이폰 개인용 핫스팟에 맥을 붙이니 `_remotepairing` 1건·`tunnelState: disconnected` 로 설치 성공. 케이블도 된다

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
| 2026-11-20 | F-3 메인 화면: 앱을 열면 메인(구약·신약 두 줄, 날짜·본문 제목). 시간과 관계없이 둘 다 열 수 있다(12시 규칙은 "지금" 배지에만). 읽음은 **표시만**(기존 `finishedDay`), 읽은 줄을 누르면 오늘 읽은 묵상 다시 보기, 한쪽 실패는 그 줄에만 안내+다시 시도 | `docs/prd/f-3-main-page.md` 1~6장, 커밋 f84f455 |
| 2026-11-20 | "오늘 구약(신약) 묵상을 마쳤습니다" 화면을 없앤다 — "다 봤어요" 뒤 바로 메인, 그 줄에 "읽음". 다시 보기 화면엔 "다 봤어요" 숨김. 메인 복귀 때 목록 재검색은 날짜가 바뀌었을 때만 (위 A안 행의 화면 부분을 대체, "그날 다음 묵상을 안 보여줌"은 유지) | `docs/prd/f-3-main-page.md` 9장, `docs/prd/f-1-next-devotion.md` 9장 2번 |
| 2026-11-22 | F-3 설계 [결정] D:378(읽음 날짜 검색 결과 없음 → 인터넷 오류 표시)·D:379(메인이 찾은 글번호를 그대로 열고 묵상 화면은 재검색 안 함)·D:380(화면 위 본문 제목은 목록 항목 값) 에 y. 기존 `DevotionScreenModelTests` @Test 37→30 으로 다시 씀(설계 §6 표) | `.pipeline/f-3-main-page/DESIGN.md:307,378-380`, `APPROVALS.md`, 커밋 f29b2e2 |
| 2026-11-22 | 디자인: 메인 카드·"다 봤어요"는 Liquid Glass(`glassEffect`·`glassProminent`), 묵상 화면은 종이 배경(라이트/다크 두 벌), 글꼴은 시스템 고딕(폰트 파일 안 넣음) | `MorningDevotion/Screen/Theme.swift`, 커밋 9b760d4 |
| 2026-11-22 | 스타일 커밋은 PR 없이 main 에 직접 push (진성 "커밋 푸시") — 파이프라인 결과만 PR 로 병합하는 규칙과 별개 | 커밋 9b760d4 |
| 2026-11-22 | 버전 태그는 앱 `MARKETING_VERSION` 과 맞춘다 (`v0.1.0` ↔ `0.1.0`). 번들 ID `com.pro047.morningdevotion`(테스트 `.tests`), 서명은 Automatic | `project.xcproj`, 커밋 f2fbe54, 태그 `v0.1.0` (push 완료) |
| 2026-11-22 | 실기기 서명은 **무료 Personal Team 유지** — profile 7일 만료라 매주 다시 설치 (유료 연 99달러는 보류). 다시 설치는 덮어쓰기, 앱을 지우지 않는다(지우면 진행 기록 사라짐) | 이 세션 대화 (진성 결정) |

## 머신 상태

기준: 2026-11-22 17:08 KST (브랜치·실기기 줄은 19:40 갱신)

- 브랜치 `main` = `origin/main` = `f2fbe54` = 태그 `v0.1.0` (서명·번들 ID·버전 설정 커밋, main 직접 push). 그 아래 `9b760d4` = 스타일 커밋. 그 앞 `12c3977` = PR #3 병합(F-3). `pipeline/f-3-main-page` 로컬·원격 삭제, worktree 제거 — 실측 `git branch -d`, `git push origin --delete`, `git worktree list` 메인 1개. main 에서 `xcodebuild test`(-quiet 없이) 242 tests / 15 suites 통과 `TEST SUCCEEDED` (실측, 스타일 변경 뒤 마지막 실행)
- 실기기 iPhone 14 Pro / iOS 27.2 (`00008120-000451DC3A98C01E`, 이름 "iPhone (7)", 페어링·개발자 모드 켬): `v0.1.0` 설치, 진성이 메인 두 줄·영상 재생 확인 (2026-11-22). 무료 팀(`KWJ27RTR92`) 서명 → **2026-11-29 무렵 만료 (추정)**. 다시 설치:
  1. `xcodebuild build -project MorningDevotion.xcodeproj -scheme MorningDevotion -destination id=00008120-000451DC3A98C01E -allowProvisioningUpdates -derivedDataPath build-device`
  2. `xcrun devicectl device install app --device 00008120-000451DC3A98C01E build-device/Build/Products/Debug-iphoneos/MorningDevotion.app`
  - `build-device/` 는 gitignore. 연결은 케이블 또는 아이폰 핫스팟 (지뢰 "공용 Wi-Fi")
- 시뮬레이터 iPhone 17 / iOS 27.2 (`62A98FA5…`): 꺼 둠 (실측 `simctl shutdown`). 스타일 빌드 앱이 설치돼 있고 데이터는 남아 있다 — 2026-11-20 에 지운 뒤 진성이 신약 "다 봤어요"를 눌러 2026-11-22 메인 신약 줄이 `2020/07/14 요한복음 6:1-21` (실측 스크린숏, 저장값 자체는 추정 `lastSeenNew = 2020/07/13`). 오전 실물 확인 전에 `simctl uninstall` 로 지운다
- 맥 메모리 (실측 2026-11-22 17:03): RAM 16GB, 스왑 11.0GB 중 10.0GB 사용, Claude 프로세스 11개 합 3.2GB, Xcode 0.5GB(빌드 전). 빌드·시뮬레이터가 붙으면 맥이 멈추다시피 한다(진성 체감). 빌드·시뮬레이터 자체 사용량은 미측정
- 미커밋 (2026-11-22 19:40 실측 `git status`): `.gitignore`(`build-device/`), `.claude/handoff.md`·`handoff-archive.md`. 커밋 여부 진성 결정 대기
- 산출물: `.pipeline/f-1-m1-next-pick/`(40파일)·`f-1-m2-read-and-progress/`(51파일)·`f-1-m3-video/`(10파일, **복원본** — `RESTORED.md`)·`f-1-m4-screen/`(47파일)·`f-3-main-page/`(54파일, worktree 에서 복사 — `diff -rq` 동일 실측). `.pipeline/` 은 gitignore 라 체크리스트 체크는 이 맥에만 있다
- sap 엔진: 지금 설치본 **`9023b42`** (2026-11-20 21:51 설치) — 실측 `sap version`, `readlink ~/.local/share/sap/current`. 이전 기록 `5c105a7` 과 다르고, 스킬 레포 HEAD 와 같은지·무엇이 바뀌었는지는 미확인. F-3 주행은 이 엔진으로 완주(재시도 재개·impl BLOCKED 경로는 발동 안 함 — 여전히 실주행 미검증)
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. 실기기 다시 설치 — 무료 팀 profile 7일 만료, 다음은 **2026-11-29 무렵** (추정, 2026-11-22 설치 기준). 앱을 지우지 말고 덮어쓴다. 명령은 머신 상태 "실기기" 줄
2. 오전 실물 확인 (M4 `.pipeline/f-1-m4-screen/CHECKLIST.md`): D:415 2025/09/11 영상 앱 안 재생(오류 153 없음), D:416 2020/07/13 영상 **재생 버튼**(플레이어 표시까지는 2026-11-20 실측), D:419 빈 저장소 오전 실행 시 구약 2025/09/11. 직전에 `simctl uninstall`. F-3 뒤로는 메인 줄을 눌러 들어간다. 화면은 Xcode ⌘R 로만 볼 수 있다 (지뢰 "Simulator.app 없음")
3. F-3 남은 실물 확인 (`.pipeline/f-3-main-page/CHECKLIST.md`): D:387 정오 경계에서 "지금" 이동, D:391 자정 넘겨 복귀 시 두 줄 재로딩, D:390 늘어난 suite 3개의 이름(개수 12→15 는 실측). D:383~386·388·389 는 2026-11-22 확인
4. M3 실물 확인 (`.pipeline/f-1-m3-video/CHECKLIST.md`): D:212 실제 `search.list` 가 이 URL·키로 fixture 같은 JSON 을 주나, D:213 틀린 키·할당량 초과가 non-2xx 인가, D:214 2020 신약 다른 날 영상 제목도 같은 형식인가 — 키 연결 완료라 지금 가능
5. 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (대체 영상 검색이 줄임 표기에 걸리면 그때)
6. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가 (날짜 검색 페이지 3개에서 `subjectColor` 1개씩 실측 — 부분 근거), D:249 MainActor 경고 (사라진 이유 미확인)
7. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
8. 미확인: 새 fixture 3개(`cast-search-date-*.html`) CRLF·LF 차이가 파서 결과를 바꾸는지 — 새로 clone 한 곳에서 테스트가 다르게 나오면 여기부터
9. 보류: 글꼴 — 지금 시스템 고딕. Pretendard·명조(Noto Serif KR 등) 번들은 파일 추가·Info.plist `UIAppFonts`·라이선스 확인이 필요해 미룸(진성 "일단 시스템 고딕"). 파일 크기·라이선스 미확인
10. F-2 지난 묵상 목록 — PRD 미작성 (`docs/prd/00-project.md` 기능 목록)

## 최신 스트림 — 2026-11-22: v0.1.0 태그·실기기 첫 설치 (resolved)

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
