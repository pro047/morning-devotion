
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
