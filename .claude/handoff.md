# morning-devotion 핸드오프

최종 갱신: 2026-11-20

## 지뢰

- **iOS 시뮬레이터 버전** (실측 2026-11-20): 앱 deployment target 이 iOS 27.0 이다. `name=iPhone 16`(iOS 18.5) 으로 `xcodebuild test` 를 돌리면 exit 70 (incompatible destination). iOS 27.x 런타임 시뮬레이터만 된다
- **시뮬레이터 이름 중복** (실측 2026-11-20): `iPhone 17` 이 iOS 26.5 와 27.2 두 개 있다 — destination 에 `OS=27.2` 까지 적어야 하나로 정해진다
- **`sap config` 자동 감지 불가** (실측 2026-11-20): package.json·pyproject·pubspec·go.mod·Cargo.toml 만 찾아서 `.xcodeproj` 저장소는 exit 2. `.sap/config` 는 수동으로 쓴다

## 확정 결정

| 날짜 | 결정 | 근거 위치 |
|---|---|---|
| 2026-11-20 | F-1 M1 다음 묵상 = 마지막으로 본 날짜 뒤 가장 이른 글, 연도 제한 없음 (설계 [결정] D:277 에 "아니오") | `docs/prd/f-1-m1-next-pick.md` R-4 |
| 2026-11-20 | sap 검증 명령(TEST_CMDS)은 `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -quiet` 한 줄로 수동 설정 | `.sap/config`, 커밋 114993f |

## 머신 상태

기준: 2026-11-20 11:46 KST

- 브랜치 `main`, `origin/main` 보다 1커밋 앞섬 (114993f 미push) — 실측 `git status -sb`
- sap 설치본 엔진 b55f47b — 실측 `sap doctor`
- sap 수정 세션(`documents-86`)에 `sap config --cmd "<명령>"` 추가 제안을 보냄 (msg_id 079fdea6…). 답 대기 — 실측 SendMessage 결과

## 현재 우선순위

1. F-1 M1(다음 묵상 고르기) 파이프라인 주행 — `docs/prd/f-1-m1-next-pick.md`, worktree `../morning-devotion-pipeline-f-1-m1-next-pick`
2. M3 전에 책 이름 표기 전수 조사 — 실측 줄임 사례 `2021/01/08(금) “고린도전 6:12-20”` 1건뿐, 나머지 표기 미측정 (2026-11-20 결정: M3 로 미룸)
3. sap 쪽 `--cmd` 반영되면 `sap config --force --cmd …` 로 `.sap/config` 재생성 검토
4. 미확인: `xcodebuild test` 가 테스트 0개일 때 실패하는지 (sap SKILL.md:219 요구) — 추정만 있음
5. 114993f push 여부 결정

## 최신 스트림 — 2026-11-20: sap 검증 명령 설정 (resolved)

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
