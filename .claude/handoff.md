# morning-devotion 핸드오프

최종 갱신: 2026-11-20

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다
- **`sap config` 자동 감지 불가** (실측 2026-11-20): package.json·pyproject·pubspec·go.mod·Cargo.toml 만 찾아서 `.xcodeproj` 저장소는 exit 2. `.sap/config` 는 수동으로 쓴다
- **sap 단계 에이전트는 이 저장소를 컴파일 못 한다** (실측 2026-11-20 f-1-m1-next-pick impl 로그): 샌드박스가 컴파일러 모듈 캐시 쓰기·시뮬레이터 접속을 막아 `swiftc -typecheck`·`xcodebuild` 둘 다 실패. 구현은 컴파일 없이 쓰이고, 판정은 셸이 샌드박스 밖에서 돌리는 `TEST_CMDS` 뿐이다
- **런처 세션에서 `sap run` 은 [결정] 게이트·재시도 게이트에서 exit 4** (실측 2026-11-20): tty 가 없어서. 재시도 게이트(FAIL_LOG.md)를 y 로 승인하고 재실행하면 attempt 2 가 아니라 **기준선부터** 돈다 — attempt 1 의 미커밋 파일이 남은 worktree 라 "기준선이 이미 빨갛다" 로 DIED (엔진 9671033, sap 쪽에 제보함). `APPROVAL_VIEW.md` 를 그대로 보여주고 y 를 받은 뒤 `SAP_ROOT=<worktree> sap approve <feature> DESIGN.md --relayed y`, 재실행은 **`FRESH_DESIGN` 없이** (붙이면 승인한 설계를 버린다)
- **CHECKLIST Attention 에 버린 설계·중복이 섞인다** (실측 2026-11-20, 엔진 b55f47b): FRESH_DESIGN·승인 재실행 뒤 DECISIONS.tsv 가 회차 0 으로 세 번 쌓여 43줄 중 고유 28, 낡은 것 5. 9671033 에서 고쳤다고 sap 쪽이 알려옴 — M2 주행(9671033) Attention 9개에는 중복 없음 (실측)
- **red 게이트는 테스트 빌드 실패도 red 로 친다** (실측 2026-11-20 M2 1차): verify 가 쓴 테스트의 문법 오류로 red 통과 → impl 은 테스트를 못 고쳐 green 불가. red_out.txt 에 `build failed` 가 있으면 의심한다
- **Swift raw string 안의 `"#`** (실측 2026-11-20): `#"... href="#" ..."#` 는 `"#` 에서 문자열이 닫혀 컴파일 오류. HTML fixture 조각엔 `##"…"##`
- **worktree 의 `git clean -fd` 는 `MorningDevotion.xcodeproj/project.xcworkspace/xcshareddata/` 도 지운다** (실측 2026-11-20): 빌드가 만드는 미추적 폴더. 지워도 빌드 통과
- **zsh 에서 `PIPESTATUS` 는 비어 있다** (실측 2026-11-20): `xcodebuild … | tail` 의 종료 코드는 xcresult `result` 로 대신 본다
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
| 2026-11-20 | sap 검증 명령(TEST_CMDS)은 `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -quiet` 한 줄로 수동 설정 | `.sap/config`, 커밋 114993f |

## 머신 상태

기준: 2026-11-20 14:51 KST

- 브랜치 `main` = `origin/main` (c4e0b12 까지 push) — 실측 `git push` · `git status -sb`
- worktree·`pipeline/f-1-m2-read-and-progress` 브랜치는 정리됨. 산출물은 `.pipeline/f-1-m1-next-pick/`(40파일)·`.pipeline/f-1-m2-read-and-progress/`(51파일, gitignore)에 복사해 둠 — 실측 `git worktree list`
- sap 엔진: M2 주행은 9671033 (orch 로그 경로 `~/.local/share/sap/9671033/`) — 실측
- `documents-86` 에 보낸 것: red 게이트가 빌드 실패로 통과·재시도 승인 뒤 기준선부터 도는 문제 (msg_id 8324a7c9…). 답: 둘 다 코드 확인(orchestrate.sh:2059-2079, :2253), 수정은 그쪽 사용자 결정 대기 — 그 세션의 메시지가 근거

## 현재 우선순위

1. M2 실물 확인 3개 (`.pipeline/f-1-m2-read-and-progress/CHECKLIST.md`): D:294 실제 URLSession 으로 글 15155 를 받아 파싱 결과가 같은가(기본 User-Agent 미확인), D:295 앱 완전 종료 뒤 진행 위치 유지, D:296 빌드 경고 목록 — 전부 미확인
2. F-1 M3(유튜브 영상) 시작 전: 2025 글 페이지에 `youtube.com/embed/<id>` iframe 이 있다 (실측 1건, `cast-body-15155.html`). F-1 PRD 7장 "글 페이지에 영상 없다" 와 충돌 — 다른 2025 글도 그런지 보고 YouTube API 가 필요한 범위부터 다시 정한다
3. M3 전에 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (2026-11-20 결정: M3 로 미룸)
4. M1 Attention 중 열린 것: D:282 다른 연도·책 제목도 같은 문법인가, D:250 다른 목록 페이지도 `class=subjectColor>` 마크업인가, D:249 MainActor 경고 (M2 attempt 1 빌드에 `DevotionModels.swift:58` 경고 4건 실측, 최종본은 `-quiet` 라 미확인)
5. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
6. sap 엔진 수정(red 게이트·재시도 경로)이 설치되면 다음 주행 전에 `sap version` 확인

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

