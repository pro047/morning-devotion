# morning-devotion 핸드오프

최종 갱신: 2026-11-27

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다. `simctl list devices available | grep "iPhone 17"` 의 첫 줄은 26.5 쪽이라 거기에 `simctl install` 하면 exit 16 ("Have 26.5; need 27.0") — 27.2 쪽 UDID 는 `62A98FA5-B5D0-46B5-BF44-E675E7507CA3`
- **`xcodebuild test` 는 이미 켜져 있던 시뮬레이터를 끄지 않는다** (실측 2026-11-27): 꺼진 상태에서 시작하면 xcodebuild 가 켰다가 끝나고 스스로 끈다(뒤이은 `simctl shutdown` 이 code=405 "current state: Shutdown"). 켜진 상태에서 시작하면 켜진 채 남는다 → `.sap/config` `TEST_CMDS` 끝에서 끈다(b52b097). 이미 꺼진 기기에 `simctl shutdown` 하면 code=405 오류 문구가 나오므로 출력을 숨긴다
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
- **`xcodebuild test` 출력의 `Executed 0 tests` 는 XCTest 줄이다** (실측 2026-11-22): 테스트가 Swift Testing 이라 개수는 `✔ Test run with 314 tests in 17 suites passed` 줄에 나온다. `-quiet` 를 붙이면 그 줄도 안 나와 개수를 못 본다 — 개수가 필요하면 `-quiet` 없이 `grep -E "Test run with|TEST (SUCCEEDED|FAILED)"`
- **macOS Swift 스크립트에서 `NSGraphicsContext(bitmapImageRep:)` 로 그리면 PNG 가 새까맣게 나온다** (실측 2026-11-22, 아이콘 생성): 알파 없는 `NSBitmapImageRep` 에 그라데이션·SF Symbol 을 그렸는데 전부 검정. `CGContext`(sRGB, `noneSkipLast`) 를 만들고 `NSGraphicsContext(cgContext:flipped:false)` 로 그린 뒤 `makeImage()` 하면 정상
- **2025 묶음 글 페이지에 박힌 영상은 설교가 아니라 새벽예배 생방송(약 90분)이다** (실측 2026-11-23): 글 `no=15160`(2025/09/13 잠언 24:11-22) embed `ut225mKfy2w` 제목 `[ 생방송 | 새벽기도회 | 2025.9.13(토) ] …`·`lengthSeconds 5416`, M3 fixture `cast-body-15155.html` 의 `PR9GK_S83NU` 도 `[ 생방송 …]`(oEmbed). 설교 영상(`[ 설교 | …]`, 약 21분)은 글 페이지에 없고 검색에만 나온다. 반대로 생방송은 `search.list` 에 안 나온다(unlisted). 2022 글의 embed(`UsCVP4y7snI`)는 설교 영상과 같은 id → F-6 으로 영상은 검색만 쓴다
- **2025 설교 영상은 `q=<날짜> <본문>` 으로 검색하면 0건이다** (실측 2026-11-23): `q=2025/09/13 잠언 24:11-22` → items 0, `q=잠언 24:11-22` → `kH2QadelWio` 1건. 제목 날짜가 `2025.9.13` 형식이라 `/` 날짜가 안 걸리는 것으로 추정
- **pipeline worktree 에는 `Secrets.xcconfig` 가 없다** (실측 2026-11-23 f-6): gitignore 라 안 따라온다 → 그대로 실기기 빌드하면 API 키가 비어 모든 글이 "영상을 찾지 못했습니다". worktree 에서 실기기 빌드 전에 `cp Secrets.xcconfig <worktree>/` (gitignore 라 범위 게이트·커밋에 안 섞임 — `git check-ignore` 실측). 파이프라인 실행 중에는 하지 않는다 · 2026-11-26 f-8: `WT_YES=1 EXTRA_FILES=Secrets.xcconfig sap worktree <기능>` 로 만들 때 반입하면 복사 단계가 없다 (`근거 자료 반입: Secrets.xcconfig (읽기 전용)` 실측)
- **실기기가 잠겨 있으면 `xcodebuild build -destination id=…` 가 약 60초 뒤 실패한다** (실측 2026-11-23): `iPhone (7) needs to be unlocked to enable development services` / `Timed out waiting for all destinations`. 진성에게 잠금 해제를 부탁하고 재실행하면 15초 만에 `EXIT=0`
- **카페 등 공용 Wi-Fi 에선 실기기 무선 연결이 안 된다** (2026-11-22 실측): 같은 Wi-Fi 인데 `devicectl` `tunnelState: unavailable`, `_remotepairing._tcp` 0건, ARP 0건 — client isolation 추정. 아이폰 개인용 핫스팟에 맥을 붙이니 `_remotepairing` 1건·`tunnelState: disconnected` 로 설치 성공. 케이블도 된다
- **`xcodebuild … | grep …; echo "EXIT=${PIPESTATUS[0]}"` 는 이 맥 셸에서 `EXIT=` 로 비어 나온다** (실측 2026-11-23 v0.2.0 검증): 셸이 zsh 라 `PIPESTATUS` 가 없는 것으로 추정 (zsh 는 소문자 `pipestatus`). 종료 코드는 `TEST SUCCEEDED` 줄과 명령 자체의 종료 코드로 판정했다 — 파이프 뒤 종료 코드가 필요하면 `set -o pipefail` 또는 `$pipestatus[1]`

- **아이폰 Wi-Fi 가 꺼져 있으면 무선 설치가 `unavailable` 로 막힌다** (실측 2026-11-26): 맥과 같은 망이라도 `devicectl list devices` 4회(10초 간격) `unavailable`, 상세 `Pairing State: paired` 인데 `tunnelState: unavailable`. 아이폰 Wi-Fi 를 켜자 바로 `available (paired)` → 빌드·`devicectl device install app` 성공. 공용 Wi-Fi 지뢰보다 먼저 아이폰 Wi-Fi 켜짐을 확인한다
- **`.confirmationDialog` 를 화면 전체(`body`)에 붙이면 iOS 27.2 에서 화면 위쪽 말풍선으로 뜬다** (실측 2026-11-26 F-7 시뮬레이터 스크린숏): 꼬리가 화면 위쪽 가운데를 가리킨다. 띄우는 버튼에 붙이면 그 버튼 위에 뜬다(a196b55). 두 경우 모두 `role: .cancel` 버튼은 보이지 않고 1개 선택지만 — 취소는 바깥 탭 (Apple 문서로는 미확인)
- **커밋 안 된 PRD 는 `sap worktree` 로 따라가지 않는다** (코드 확인 `~/.local/share/sap/9e9eb46/pipeline-worktree.sh:133-151`, 2026-11-26 F-9): `EXTRA_FILES` 는 gitignore 대상만 반입하고, 손으로 복사하면 범위 게이트가 미추적 파일로 죽인다. PRD 없이 돌면 `⚠ … PRD 없이 설계한다` (`orchestrate.sh:1874`). → worktree 를 만든 뒤 PRD 를 `pipeline/<기능>` 브랜치에 커밋하고 `sap run` (F-8 09aa283·F-9 9b1439d 와 같은 방식). 시작 로그 `PRD 자동 주입:` 줄 확인
- **sap 단계 샌드박스는 `www.bskorea.or.kr` 접속을 막는다** (실측 2026-11-26 F-9 설계 로그): `curl … bible.list.js` → `exit=56`, `deny network-outbound www.bskorea.or.kr:443 (user denied)`. 단계 에이전트는 외부 사이트 확인을 못 하고 `미확인` 으로 남긴다 → 런처 세션(샌드박스 밖)에서 대신 확인한다 (F-9 책 코드 66개는 런처가 대조)
- **설계 에이전트가 API 오류로 죽으면 `DESIGN.md.crashed` 게이트에서 exit 4** (실측 2026-11-26 F-9, `ENOTFOUND`·`terminal_reason=api_error`, 턴 13): 산출물이 `STATUS: DONE` 이면 `.crashed` 로 파킹하고 "신뢰할까?" 를 묻는다. 전문을 보여주고 정확히 y 를 받은 뒤 `mv DESIGN.md.crashed DESIGN.md` → 같은 `sap run` 재실행이면 그 설계를 재사용하고 judge 부터 돈다
- **`set -o pipefail` 에 `grep -v` 를 끼우면 출력이 비었을 때 exit 1 로 뒤 명령이 건너뛴다** (실측 2026-11-27): `xcodebuild build -quiet | grep -v IDERunDestination | tail && devicectl … install` → 빌드는 됐는데 설치가 안 돎. `-quiet` 빌드 출력은 `IDERunDestination` 경고 1줄뿐이라 다 걸러진다. 빌드와 설치를 파이프 없이 따로 돌린다

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
| 2026-11-22 | **F-4: 하루 하나 제한 해제** — "다 봤어요" 뒤 메인 줄이 바로 다음 글. 읽음 = 글 날짜 ≤ 진행 위치, `finishedDay{Old,New}` 키 제거. 읽은 글에선 "다 봤어요" 숨김(진행 위치는 뒤로 안 감, M2 D:291 을 화면 쪽에서 막음). 이전·다음은 메인 줄·묵상 화면 둘 다, "다음"은 제한 없음, 이동은 진행 위치 불변, 앞뒤 ±7일 날짜 검색. F-2 는 그대로 남김. **위 "A안"·F-3 9장 1번 "그날 다음 묵상 안 보여줌"·F-3 US-3·US-4 를 대체** | `docs/prd/f-4-prev-next.md`, 커밋 233fca8 |
| 2026-11-22 | F-4 설계 [결정] D:404(메인 줄 넘겨 둔 상태는 앱 새로 열 때·진행 위치 바뀔 때만 되돌림)·D:405(건너뛴 안 읽은 글에서도 "다 봤어요" 보임)·D:406(묵상 화면 이동은 제자리 교체)·D:407(이동 중 로딩 표시·버튼 잠금) 에 y | F-4 `DESIGN.md:404-407` (아카이브, 머신 상태 "산출물") |
| 2026-11-22 | **F-5: 이전·다음 = 원형 글래스 화살표(메인 제목 양옆)·떠 있는 글래스 캡슐(묵상 화면) + 좌우 스와이프(왼쪽=다음)**, 밀려나는 전환, 성공·실패 다른 햅틱, "다음 묵상을 찾지 못했습니다" 줄에도 `‹`(진행 위치 글을 "읽음"으로) | `docs/prd/f-5-glass-nav-swipe.md`, 커밋 f8dff06 |
| 2026-11-22 | F-5 설계 [결정] D:259(왼쪽 끝 24pt 스와이프는 iOS 뒤로 가기)·D:260(스와이프는 영상 아래 글 영역만)·D:261(로딩 표시 지연 없음)·D:262(새 글·영상 다 받은 뒤 한 번에 교체)·D:263(가로 60pt 이상·가로≥세로×2·가장자리 24pt) 에 y | F-5 `DESIGN.md:259-263` (아카이브) |
| 2026-11-22 | F-4·F-5 는 F-5 브랜치(base F-4) PR 하나(#4)로 병합. 실물 확인은 병합 전 실기기에서 진성이 전부 통과 | PR #4, 병합 512df03 |
| 2026-11-22 | **메인 줄 이전·다음 이동 중 로딩 스피너 없음** (진성 "로딩 스타일 이상" — 스피너 자체와 카드 높이 변화 둘 다). F-4 D:407 의 "로딩 표시"를 메인에서만 대체, 버튼 잠금(`.disabled(isMoving)`)은 유지. 첫 로딩 스피너·묵상 화면은 그대로 | `MainScreenView.swift` `movingAndNotice`, 커밋 1c54421, PR #5 |
| 2026-11-22 | **앱 아이콘** = 메인 배경 라이트 그라데이션(살구 0.99/0.90/0.78 → 하늘 0.84/0.89/0.97, 45°) + SF Symbol `sun.horizon.fill`(해 주황 0.96/0.58/0.20, 지평선 `Theme.ink` 라이트). 1024 PNG 1장, 알파 없음, 라이트만 | `AppIcon.appiconset`, `project.xcproj` `ASSETCATALOG_COMPILER_APPICON_NAME`, 커밋 a327a31, PR #5 |
| 2026-11-23 | **F-6: 묵상 영상은 `search.list` 로만 찾는다** — 글 페이지 embed(M3 R-1·R-5) 폐기, 검색어 `q` 는 본문만(날짜 없음), 제목은 2020 형식 + 2025 `[ 설교 | 새벽기도회 | YYYY.M.D(요일) ] 본문 | 인도 이름` 형식(대괄호 첫 칸 `설교` 만 후보). M3 R-1·R-2 검색어·R-3 형식·R-5 를 대체 | `docs/prd/f-6-sermon-video.md`, 커밋 689063d, 구현 04ca7ec |
| 2026-11-23 | F-6: 설교 영상을 못 찾으면 생방송(글 embed)으로 대신하지 않고 "영상 없음" · 찾은 영상 id 캐시는 "나중에"(하루 약 5회 → 500 단위, 추정) · 생방송 판별은 oEmbed·`videos.list` 없이 제목 `[ 설교` 로 | `docs/prd/f-6-sermon-video.md` 5장 (진성 결정) |
| 2026-11-23 | F-6 설계 [결정] D:160(`ac18_refreshAcrossNoonIsNoOp` 유튜브 0회 → load 1회)·D:161(`findVideo` 의 `articleHTML` 인자 제거, 목록 밖 테스트는 인자 줄만 삭제) 에 y. PRD 6장 "바뀌는 기존 테스트" 목록 승인으로 기대값 변경 승인을 갈음 | F-6 `DESIGN.md:160-161` (worktree `.pipeline/f-6-sermon-video/`) · PRD 6-1절 (a630f21) |
| 2026-11-23 | F-6 은 `pipeline/f-6-sermon-video` PR 하나(#6)로 merge commit 병합(PR #4·#5 와 같은 방식). 실물 확인 D:165~167 은 병합 전 실기기에서 진성 통과. D:168·169 는 열린 채 병합 | PR #6, 병합 f907863 |
| 2026-11-23 | 원격에 push 된 `v0.1.0`(f2fbe54) 은 옮기지 않고, 그 뒤 작업(F-4·F-5·PR #5·F-6)을 **`v0.2.0`** 으로 새로 태그. `MARKETING_VERSION 0.2.0`·`CURRENT_PROJECT_VERSION 2`(빌드 번호도 버전마다 올림). 릴리즈 노트는 `docs/release-notes/v<버전>.md`. 릴리즈는 `release/v<버전>` 브랜치 → main `--no-ff` 병합 → 병합 커밋에 annotated tag (진성 결정) | `docs/release-notes/v0.2.0.md`, 커밋 b373126·병합 98e8024, 태그 `v0.2.0` (push 완료) |
| 2026-11-24 | **F-7: "다 봤어요"를 묵상 화면 하단 이전·다음 캡슐 가운데로** (안 읽은 글이면 버튼, 읽은 글은 점, 이동 중은 불러오는 중). 본문 끝 버튼 삭제. 스크롤해야 보이는 조건은 넣지 않음(진성: 영상만 보고 바로 누르고 싶다). 실수 방지는 확인 창, 되돌리기 토스트는 안 함(F-4 FR-5 와 부딪힘) | `docs/prd/f-7-finish-in-capsule.md`, PR #7 |
| 2026-11-26 | F-7 확인 창: 문구 "다 봤어요로 표시할까요?"(설계 D:165 y), "다 봤어요" 버튼에 붙여 캡슐 위에 뜸, 선택지 1개·취소는 바깥 탭(PRD US-2 수정). 캡슐 "다 봤어요" 글자색은 화살표와 같은 `.primary`(라이트 검정·다크 흰색) | PRD US-1·US-2·9장, 커밋 a196b55·fee52ab·5086360 |
| 2026-11-26 | F-7 은 `pipeline/f-7-finish-in-capsule` PR 하나(#7)로 merge commit 병합. 실물 확인 D:172~175 는 병합 전 실기기에서 진성 통과 | PR #7, 병합 18c343c |
| 2026-11-26 | **실기기 업데이트는 무선(같은 Wi-Fi)으로 한다** (진성) | 메모리 `device-update-wireless.md` |
| 2026-11-26 | **F-8: 묵상 화면 하단 캡슐은 글이 보일 때(`.showing`)만** — 불러오는 중·네트워크 오류 화면에선 숨김(오류 화면에선 "다시 시도"만), 나타날 때 애니메이션 없음, 이동 중엔 유지. F-7 US-1 "불러오는 중·오류 화면에서 가운데 점" 기준을 대체 | `docs/prd/f-8-capsule-after-load.md`, 커밋 09aa283·8cb5bc3 |
| 2026-11-26 | F-8 은 `pipeline/f-8-capsule-after-load` PR 하나(#8)로 merge commit 병합. 실물 확인 [사실] 6개는 병합 전 실기기에서 진성 통과 | PR #8, 병합 a1ba5d2 |
| 2026-11-26 | 본문 스크롤 가끔 씹힘은 재현 안 돼 **보류·기록만** (코드 수정 없음) | 현재 우선순위 15번 |
| 2026-11-26 | **성경 본문 번역은 개역개정** — 교회 묵상 글이 개역개정을 인용한다(잠언 23장 2곳·요한복음 5장 6곳이 개역개정과 일치, 개역한글과 불일치 — 대한성서공회 GAE·HAN 페이지 대조 실측). 대한성서공회 저작물이라 **개인 기기 전용 전제** (이용 허락 안 받음, 법적 필요 여부 미확인) — 배포하게 되면 이 결정부터 다시 본다 | `docs/prd/f-9-bible-passage.md` 5장 |
| 2026-11-26 | **F-9: 구절은 대한성서공회 장 페이지(`korbibReadpage.php?version=GAE&book=<코드>&chap=<장>`)에서 버튼 누를 때 받는다** (B안 — 성경 전체 번들 A안 기각: 묵상 글도 네트워크가 있어야 보여 얻는 게 적다). 플로팅 버튼 → 바텀시트, 묵상 범위 절만, 실패는 시트 안 "인터넷 연결을 확인해 주세요"(다시 시도 없음), 본문을 장·절로 못 읽거나 책 코드가 없으면 버튼 숨김 | `docs/prd/f-9-bible-passage.md`, 커밋 9b1439d |
| 2026-11-26 | F-9 설계 [결정] D:302~308·D:310 y (추정 63권 코드 사용·버튼 캡슐 오른쪽 위·누를 때만 받기·보충어 같은 크기·시트 절반→전체·같은 묵상 1칸 캐시·각주 제외·소제목 제외), **D:309 n — 세 장 이상 걸친 본문도 가운데 장까지 받아 보인다** (되감기 3회째 반영) | worktree `.pipeline/f-9-bible-passage/DESIGN.md`(메인에 복사본), `sap answer` 출력 |
| 2026-11-27 | 바텀시트 상단 여백 `.padding(.top, 16)` 추가 (진성). F-9 는 `pipeline/f-9-bible-passage` PR 하나(#9)로 merge commit 병합 | 커밋 12daaf1, PR #9, 병합 103d546 |
| 2026-11-27 | **sap 검증 뒤 시뮬레이터 자동 종료** — `TEST_CMDS` 를 `xcodebuild test … -quiet; rc=$?; xcrun simctl shutdown 62A98FA5-… >/dev/null 2>&1; exit $rc` 로 (진성 A안 선택, B안 "메모리 규칙" 기각). sap 가 한 줄씩 `bash -c` 로 돌려서 가능(코드 확인 `orchestrate.sh:1523-1529`). 한계: `VERIFY_TIMEOUT` 초과로 죽으면 shutdown 안 돎(코드 확인 `orchestrate.sh:1524`) | `.sap/config`, 커밋 c09a9e6, PR #10, 병합 b52b097 |

## 머신 상태

기준: 2026-11-27 14:42 KST (브랜치·시뮬레이터·sap 엔진 줄). 맥 메모리·documents-86 줄은 2026-11-22 17:08 기준

- 브랜치 `main` = `origin/main` = `b52b097` (PR #10 시뮬레이터 자동 종료 병합, merge commit — 그 아래 c09a9e6). 작업 worktree `sim-shutdown-after-test`·로컬/원격 브랜치 `worktree-sim-shutdown-after-test` 삭제, `git worktree list` 메인 1개 (실측 2026-11-27 14:40). 마지막 검증: 새 `TEST_CMDS` 줄을 `bash -c` 로 2회 실행 exit 0 (시작 전 Shutdown·Booted 각 1회, 둘 다 끝난 뒤 Shutdown — 테스트 개수는 -quiet 라 미출력), `sap doctor` 통과 (실측 2026-11-27). 그 아래 `103d546` (PR #9 F-9 병합, merge commit — 그 아래 12daaf1 여백·7a3c15f 구현·9b1439d PRD). 그 아래 `a1ba5d2` PR #8 F-8 병합, `18c343c` PR #7 F-7 병합, `98e8024` = `v0.2.0` 태그(`release/v0.2.0` 병합), `f907863` PR #6 병합, `3ffd61f` PR #5 병합. 태그 `v0.1.0` = `f2fbe54`. F-9 worktree 는 `gh pr merge --delete-branch` 가 지움, `git worktree prune` 뒤 `git worktree list` 메인 1개, 로컬 `pipeline/f-9*` 없음 — 실측 2026-11-27 09:05. **`remotes/origin/pipeline/f-9-bible-passage` 가 `git branch -a` 에 남아 있음** (원격 삭제 여부 미확인 — `git fetch --prune` 안 함). sap 보관 폴더 `~/.local/state/sap/archive/morning-devotion-pipeline-f-9-bible-passage` 가 있음(언제 생겼는지 미확인). 마지막 검증: worktree(12daaf1 커밋 직전 같은 트리)에서 `xcodebuild test`(-quiet 없이) **413 tests / 20 suites** 통과 `TEST SUCCEEDED` (실측 2026-11-27 09:01). 미커밋: `.claude/handoff.md`·`handoff-archive.md`(이 갱신)
- 아이콘 생성 스크립트 `icon.swift` 는 세션 scratchpad(`/private/tmp/claude-501/-Users-ijinseong-Documents-morning-devotion/269000b7-…/scratchpad/`)에만 있다 — 재부팅·정리로 사라질 수 있음. 다시 만들 때 색·심벌은 확정 결정 표 "앱 아이콘" 행, 그리기 방법은 지뢰 "NSGraphicsContext"
- 실기기 iPhone 14 Pro / iOS 27.2 (`00008120-000451DC3A98C01E`, 이름 "iPhone (7)", 페어링·개발자 모드 켬): **F-9 빌드 설치 — 앱 코드는 main 103d546 와 같음**(worktree 12daaf1 트리에서 빌드), 버전 `0.2.0`(빌드 2). **무선 설치** 2026-11-27 09:01 KST (`devicectl` `App installed`, `installationURL …/4E8D7BF5-…` 실측, 앱 Info.plist `YouTubeAPIKey` 길이 39). F-9 실기기 확인은 진성 "조아조아" 응답만 있고 [사실] 항목별 답은 없음. 무료 팀(`KWJ27RTR92`) 서명 → **2026-11-29 무렵 만료 (추정 — 재설치가 만료를 늦추는지 미확인)**. 다시 설치:
  1. `xcodebuild build -project MorningDevotion.xcodeproj -scheme MorningDevotion -destination id=00008120-000451DC3A98C01E -allowProvisioningUpdates -derivedDataPath build-device`
  2. `xcrun devicectl device install app --device 00008120-000451DC3A98C01E build-device/Build/Products/Debug-iphoneos/MorningDevotion.app`
  - `build-device/` 는 gitignore. 연결은 **무선(같은 Wi-Fi) 기본** — 아이폰 Wi-Fi 켜짐 먼저 확인 (지뢰 "아이폰 Wi-Fi"·"공용 Wi-Fi"). worktree 에서 빌드하면 `Secrets.xcconfig` 를 먼저 복사
- 시뮬레이터 iPhone 17 / iOS 27.2 (`62A98FA5…`): **꺼져 있음** (실측 2026-11-27 14:42). 설치본은 main 103d546 빌드(2026-11-27 14:26 `simctl install` 덮어쓰기, uninstall 안 함 — 이전 F-7 빌드의 진행 데이터는 남아 있을 것, 추정). 실행 48초간 프로세스 유지·크래시 리포트 없음·메인 화면(구약 2025/09/11, 신약 2020/07/13 "지금") 스크린숏 확인 (실측). API 키 포함 여부 미확인
- 맥 메모리 (실측 2026-11-22 17:03): RAM 16GB, 스왑 11.0GB 중 10.0GB 사용, Claude 프로세스 11개 합 3.2GB, Xcode 0.5GB(빌드 전). 빌드·시뮬레이터가 붙으면 맥이 멈추다시피 한다(진성 체감). 빌드·시뮬레이터 자체 사용량은 미측정
- 산출물: `.pipeline/f-1-m1-next-pick/`(40파일)·`f-1-m2-read-and-progress/`(51파일)·`f-1-m3-video/`(10파일, **복원본** — `RESTORED.md`)·`f-1-m4-screen/`(47파일)·`f-3-main-page/`(54파일, worktree 에서 복사 — `diff -rq` 동일 실측). `.pipeline/` 은 gitignore 라 체크리스트 체크는 이 맥에만 있다. **F-4·F-5 는 메인에 복사하지 않았고 `sap clean` 이 아카이브로 옮겼다**: `~/.local/state/sap/archive/morning-devotion-pipeline-f-4-prev-next/f-4-prev-next/clean-20261122T213358`, `…-f-5-glass-nav-swipe/f-5-glass-nav-swipe/clean-20261122T213358` (체크박스는 체크 안 됨 — 통과는 진성 구두 확인) · `f-6-sermon-video/`(38파일, 병합 전 worktree 에서 복사 — `diff -rq` 동일 실측, 체크박스는 체크 안 됨 — D:165~167 통과는 진성 구두 확인). `sap clean` 보관본: `~/.local/state/sap/archive/morning-devotion-pipeline-f-6-sermon-video/f-6-sermon-video/clean-20261123T152428` · `f-7-finish-in-capsule/`(38파일, 병합 전 worktree 에서 복사 — `diff -rq` 동일 실측, 체크박스는 체크 안 됨 — D:172~175 통과는 진성 구두 확인). `sap clean` 보관본: `~/.local/state/sap/archive/morning-devotion-pipeline-f-7-finish-in-capsule/f-7-finish-in-capsule/clean-20261126T093315` · `f-8-capsule-after-load/`(35파일, 병합 뒤 worktree 에서 복사 — `diff -rq` 동일 실측, 체크박스는 체크 안 됨 — [사실] 6개 통과는 진성 구두 확인). `sap clean` 보관본: `~/.local/state/sap/archive/morning-devotion-pipeline-f-8-capsule-after-load/f-8-capsule-after-load/clean-20261126T142827` · `f-9-bible-passage/`(65파일, **병합 전** worktree 에서 복사 — `diff -rq` 동일 실측 2026-11-27 09:04, 체크박스는 체크 안 됨)
- F-7 스크린숏 5장·디버그 훅 사본(`f7copy-1795651565980`, `MainScreenView.swift` 에 `SCENE` 환경변수 훅)은 세션 scratchpad(`/private/tmp/claude-501/-Users-ijinseong-Documents-morning-devotion/e7686f17-…/scratchpad/`)에만 있다 — 재부팅·정리로 사라질 수 있음
- YouTube 할당량: 2026-11-23 런처가 조사로 `search.list` 10회(약 1,000 단위, 추정 단가) + 실기기 확인 중 앱 호출(횟수 미측정)
- sap 엔진: 지금 설치본 **`6f861ff`** (2026-11-27T11:09:34+09:00) — 실측 2026-11-27 `sap version`, `readlink ~/.local/share/sap/current`. 이전 기록 `9023b42`·`5c105a7` 에서 무엇이 바뀌었는지는 미확인. F-3 주행은 이 엔진으로 완주(재시도 재개·impl BLOCKED 경로는 발동 안 함 — 여전히 실주행 미검증)
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. F-9 CHECKLIST 남은 [사실] (`.pipeline/f-9-bible-passage/CHECKLIST.md`): D:326 각주·소제목 많은 다른 장도 같은 마크업, D:327 구약·신약 시트 범위 절·`너를 낳은`·`증언하면`, D:328 비행기 모드 시트 안 안내, D:329 닫은 뒤 스크롤 위치, D:330 시트 스크롤·절반→전체, D:331 버튼 겹침·로딩/오류 화면 숨김, D:332 장 넘김(두 장·세 장 이상 — D:309 n) 실제 묵상. 진성 항목별 확인 없음 (2026-11-27 "조아조아"뿐). D:324(63권 코드 66개 전부 `bible.list.js` 와 일치)·D:325(새 테스트 실행됨)는 런처가 실측으로 풀었으나 체크는 안 함. 앱 이름 표는 교회 제목 표기 `요한일서`(사이트는 `요한1서`) — 교회 검색 `요한일서` 5건·`요한1서` 0건 실측
2. F-6 CHECKLIST 남은 [사실]: D:168 본문만 검색할 때 다른 해 같은 본문 영상이 섞여 그날 영상이 5개 밖으로 밀리는지 (미측정 — 2020·2025 표본은 전부 1번째), D:169 Google Cloud 콘솔 YouTube Data API 할당량 실제 한도·사용량 (미확인). 밀리는 사례가 나오면 캐시·`maxResults` 를 다시 정한다
3. 실기기 다시 설치 — 무료 팀 profile 7일 만료, 다음은 **2026-11-29 무렵** (추정, 2026-11-22 첫 설치 기준 — 2026-11-26·27 재설치가 늦췄는지 미확인). 앱을 지우지 말고 **무선으로** 덮어쓴다. 명령은 머신 상태 "실기기" 줄 · 지금 설치본은 main 103d546 와 같은 앱 코드(0.2.0, 2026-11-27 09:01 설치)
4. F-7 CHECKLIST 남은 [사실] (`.pipeline/f-7-finish-in-capsule/CHECKLIST.md`): D:171 캡슐 "다 봤어요" 누르는 높이 44pt 이상(Accessibility Inspector), D:169 후반 본문 끝에 버튼 없음(실기기 스크롤 — diff 로는 삭제 확인), D:174 네트워크 오류 화면에서 점 — **F-8 로 무효**(오류 화면에 캡슐 자체가 없음, `docs/prd/f-8-capsule-after-load.md` 7장). D:172~175 의 나머지는 2026-11-26 진성 통과
5. 오전 실물 확인 (M4 `.pipeline/f-1-m4-screen/CHECKLIST.md`): D:415 2025/09/11 영상 앱 안 재생(오류 153 없음 — **F-6 으로 이 영상이 생방송 `PR9GK_S83NU` → 설교 `T8fZYU9Pd0E` 로 바뀜, 항목 유효성 먼저 본다**), D:416 2020/07/13 영상 **재생 버튼**(플레이어 표시까지는 2026-11-20 실측), D:419 빈 저장소 오전 실행 시 구약 2025/09/11. 직전에 `simctl uninstall`. F-3 뒤로는 메인 줄을 눌러 들어간다. 화면은 Xcode ⌘R 로만 볼 수 있다 (지뢰 "Simulator.app 없음")
6. F-3 남은 실물 확인 — **F-4 로 읽음 줄·다시 보기 동작이 바뀌어 항목마다 유효한지 먼저 본다** (`.pipeline/f-3-main-page/CHECKLIST.md`): D:387 정오 경계에서 "지금" 이동, D:391 자정 넘겨 복귀 시 두 줄 재로딩, D:390 늘어난 suite 3개의 이름(개수 12→15 는 실측). D:383~386·388·389 는 2026-11-22 확인
7. M3 실물 확인 (`.pipeline/f-1-m3-video/CHECKLIST.md`): D:212 실제 `search.list` 가 이 URL·키로 fixture 같은 JSON 을 주나, D:213 틀린 키·할당량 초과가 non-2xx 인가, D:214 2020 신약 다른 날 영상 제목도 같은 형식인가 — 키 연결 완료라 지금 가능 · 2026-11-23: D:212 실제 `search.list` 가 정상 JSON(items·snippet.title) 을 줌(실측, 런처 10회), D:214 `q=요한복음 5:30-47` 응답 8건 중 2020 묵상 제목 5건이 같은 형식(실측, 나머지는 수요성경공부 2건·2023 1건) — 체크는 아직. R-1 관련 항목은 F-6 으로 무효
8. 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (대체 영상 검색이 줄임 표기에 걸리면 그때) · F-9 도 줄임 표기 묵상에선 성경 버튼이 숨는다 (FR-7, 코드 확인 `BibleBookCode.code(for:)` 정확 일치)
9. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가 (날짜 검색 페이지 3개에서 `subjectColor` 1개씩 실측 — 부분 근거), D:249 MainActor 경고 (사라진 이유 미확인)
10. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
11. 미확인: 새 fixture 3개(`cast-search-date-*.html`) CRLF·LF 차이가 파서 결과를 바꾸는지 — 새로 clone 한 곳에서 테스트가 다르게 나오면 여기부터
12. 보류: 글꼴 — 지금 시스템 고딕. Pretendard·명조(Noto Serif KR 등) 번들은 파일 추가·Info.plist `UIAppFonts`·라이선스 확인이 필요해 미룸(진성 "일단 시스템 고딕"). 파일 크기·라이선스 미확인
13. F-2 지난 묵상 목록 — PRD 미작성 (`docs/prd/00-project.md` 기능 목록)
14. 보류: 아이콘 생성 스크립트 리포 보관 여부 (진성 답 대기, 후보 `scripts/`) · 다크·틴트 아이콘 변형 (지금 라이트 1장뿐, 미요청)
15. 보류(미재현): 묵상 화면 본문에서 아래로 스크롤할 때 가끔 스크롤이 잘 안 됨 (진성 2026-11-26, "너무 가끔이라 재현 안 됨"). 코드로만 본 의심 지점: `DevotionScreenView.swift:153` 본문 `simultaneousGesture(DragGesture(minimumDistance: 20))` 가 ScrollView 스크롤과 같은 터치를 받음 — 원인 여부는 추정(SwiftUI 런타임 동작, 실측 없음). 배제: 세로 스크롤이 이동으로 오인식(`NavigationRules.swift:19-20` 가 nil), 스크롤 중 상태 변경(모델에 없음). 다시 겪으면 시작점이 본문 글자인지 날짜 줄·영상 아래인지 기억 → 본문에서만 나면 가설 유지. 다음 확인 수단 후보: 제스처를 뺀 비교 빌드(그동안 본문 스와이프 이동 불가) · 고치면 F-5 스와이프 동작이 함께 바뀐다

## 최신 스트림 — 2026-11-27: sap 검증 뒤 시뮬레이터 자동 종료 (resolved)

- **요청**: "앱 구현하고 시뮬레이터 바로 종료 안하는지 확인해줘" → 처음엔 "앱이 바로 꺼지지 않는지"로 잘못 읽고 앱 실행 확인 → 진성 정정 "시뮬레이터를 바로 종료시키는지" → 지금 끄기 + 자동 종료(A안) → 커밋·PR·병합·pull·worktree/브랜치 삭제
- **결정**: 확정 결정 표 2026-11-27 "sap 검증 뒤 시뮬레이터 자동 종료" 행
- **변경**: c09a9e6 `.sap/config` (`TEST_CMDS` 에 shutdown, 출력 숨김) · PR #10 병합 b52b097 · 메인 checkout `git pull --ff-only` (103d546..b52b097)
- **지뢰**: 지뢰 절 "`xcodebuild test` 는 이미 켜져 있던 시뮬레이터를 끄지 않는다" (이번에 추가)
- **실측**:
  - 앱 실행: main 103d546 빌드 exit 0 → iOS 27.2 시뮬레이터 설치·실행 exit 0, PID 87421 이 48초 유지, 크래시 리포트 없음
  - sap 는 `TEST_CMDS` 를 줄마다 `bash -c` 로 실행 (코드 확인 `orchestrate.sh:1523-1529`), 설치본·스킬 폴더에 `simctl`·`shutdown` 0건 (실측 grep)
  - 새 줄: 시작 전 Shutdown → exit 0·끝난 뒤 Shutdown(이때 붙인 shutdown 은 code=405) / 시작 전 Booted → exit 0·끝난 뒤 Shutdown·SimError 0줄 / `false` 대체 → exit 1 유지 / `sap doctor` 통과
  - 미확인: `VERIFY_TIMEOUT` 초과 시 시뮬레이터가 남는 경우는 코드로만 확인
