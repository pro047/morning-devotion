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
| 2026-11-20 | sap 검증 명령(TEST_CMDS)은 `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -quiet` 한 줄로 수동 설정 | `.sap/config`, 커밋 114993f |

## 머신 상태

기준: 2026-11-20 15:25 KST

- 브랜치 `main` = `origin/main` (e1ecf47, 미커밋 없음) — 실측 `git status -sb`
- 시뮬레이터 iPhone 17 / iOS 27.2 (`62A98FA5…`): 꺼 둠. 확인용 빌드 앱이 설치돼 있고 UserDefaults 에 `readingProgress.lastSeenOld = 2025/09/11` 이 남아 있다 (D:295 확인 흔적, 기본값 아님) — 실측 `-probeRead` 출력. 수동 확인 전에 `simctl uninstall` 로 지운다
- worktree·`pipeline/f-1-m2-read-and-progress` 브랜치는 정리됨. 산출물은 `.pipeline/f-1-m1-next-pick/`(40파일)·`.pipeline/f-1-m2-read-and-progress/`(51파일, gitignore)에 복사해 둠 — 실측 `git worktree list`
- sap 엔진: M2 주행은 9671033 (orch 로그 경로 `~/.local/share/sap/9671033/`) — 실측
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. **조사·결정 완료, PRD 반영 미커밋 (2026-11-20)** — 다음은 M3 범위 문서. 원래 항목: F-1 M3(유튜브 영상) 시작 전: 2025 글 페이지에 `youtube.com/embed/<id>` iframe 이 있다 (실측 1건, `cast-body-15155.html`). F-1 PRD 7장 "글 페이지에 영상 없다" 와 충돌 — 다른 2025 글도 그런지 보고 YouTube API 가 필요한 범위부터 다시 정한다 — 완료 조건: ① 2025 월별 12건 + 2024 3건의 iframe 유무·영상 id 표와 PRD 7장 전제 판정(PRD 수정 없음) ② 그 결과로 M3 범위 A(글 페이지 파싱만)/B(YouTube API) 선택지 정리
2. M3 전에 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (2026-11-20 결정: M3 로 미룸)
3. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가, D:249 MainActor 경고 (M2 attempt 1 빌드에 `DevotionModels.swift:58` 경고 4건 실측 → 2026-11-20 새 derivedData `build`·`build-for-testing` 에선 Swift 경고 0건 실측. 사라진 이유 미확인)
4. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
5. sap 엔진 수정(red 게이트·재시도 경로)이 설치되면 다음 주행 전에 `sap version` 확인

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
