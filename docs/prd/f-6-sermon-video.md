# PRD: F-6 묵상 영상을 설교 영상으로 찾기

작성일: 2026-11-23 · 프로젝트 PRD: [00-project.md](00-project.md) · 대체하는 문서: [f-1-m3-video.md](f-1-m3-video.md) R-1·R-2·R-3·R-5

## 1. 개요
2026-11-23 아침 진성이 2025/09/13(토) 잠언 24:11-22 묵상을 열었는데, 앱에 새벽예배 전체 생방송(약 90분)이 나왔다. 유튜브에서 직접 검색하면 설교만 있는 영상(약 21분)이 나온다. 다른 글에서도 같은 일이 있었다 (진성).

원인 (2026-11-23 실측):
1. 글 `no=15160` 의 HTML 에 `youtube.com/embed/` 는 1개뿐이고 `ut225mKfy2w` 다 — 제목 `[ 생방송 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은`, `lengthSeconds 5416`, `isLiveContent true`
2. 앱은 글 HTML 의 첫 embed 를 쓰고 검색을 부르지 않는다 (M3 R-1·R-5, 코드 확인 `DevotionVideoFinder.swift:134`)
3. 설교 영상은 `kH2QadelWio` — 제목 `[ 설교 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은`, `lengthSeconds 1276`, `isLiveContent false`, 같은 채널
4. M3 R-1 예시 `cast-body-15155.html` → `PR9GK_S83NU` 도 제목이 `[ 생방송 | 새벽기도회 | 2025.9.11(목) ] …` 다 (oEmbed 실측). M3 때부터 2025 글은 생방송을 집고 있었다

이 기능은 영상을 **글 페이지 embed 가 아니라 유튜브 검색으로만** 찾고, 2025 형식의 설교 영상 제목을 읽게 한다.

## 2. 목표
- 2025 구약 묵상을 열면 생방송이 아니라 설교 영상이 나온다
- 2020 신약 묵상은 지금처럼 그날 영상이 나온다

## 3. 사용자 스토리

### US-1: 2025 묵상에서 설교 영상 보기
**설명:** 진성으로서, 2025 묵상을 열면 예배 전체가 아니라 설교만 보고 싶다. 유튜브에서 찾아 보던 영상이 그것이기 때문이다.
**수용 기준:**
- [ ] 2025/09/13(토) 잠언 24:11-22 묵상의 영상이 `kH2QadelWio` 다 (글 HTML 에 `ut225mKfy2w` embed 가 있어도)
- [ ] 제목이 `[ 생방송 | …` 인 영상은 날짜·본문이 같아도 고르지 않는다
- [ ] 설교 영상을 못 찾으면 생방송으로 대신하지 않고 "영상 없음"이다

### US-2: 다른 해 묵상은 그대로
**설명:** 진성으로서, 2020 신약 묵상은 지금처럼 그날 영상을 보고 싶다.
**수용 기준:**
- [ ] 2020/07/13(월) 요한복음 5:30-47 묵상 → `M5VtIg1WAic` (지금 M3 완료 조건 4 와 같은 결과)
- [ ] 2020 형식 제목(`2020/07/13(월) “요한복음 5:30-47” / 박성호`, 엔티티 `&quot;` 포함)을 지금처럼 읽는다

## 4. 기능 요구사항
- FR-1: 영상은 YouTube Data API `search.list` 로만 찾는다. 글 HTML 의 `youtube.com/embed/` 는 영상 결정에 쓰지 않는다 (M3 R-1·R-5 폐기). 글 HTML 은 본문 표시에만 쓴다
- FR-2: 검색어 `q` 는 **본문만** 쓴다 (예: `잠언 24:11-22`). 날짜를 넣지 않는다 (M3 R-2 의 `q=<날짜> <본문>` 폐기). 나머지 파라미터(`part=snippet`·`channelId=UCSkjujMSzrh6nghHWTSvIJg`·`type=video`·`maxResults=5`·`key`)는 그대로
  - 근거 (2026-11-23 실측): `q=2025/09/13 잠언 24:11-22` → items 0개, `q=잠언 24:11-22` → `kH2QadelWio` 1개
- FR-3: 검색 결과 제목에서 날짜·본문을 읽는 형식을 하나 더 받는다
  - 2025 형식: `[ 설교 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은` — 날짜 `2025.9.13`(구분 `.`, 0 채움 없음), 본문은 `]` 뒤부터 다음 ` | ` 앞까지, 따옴표 없음
  - 대괄호 안 첫 칸이 `설교` 인 것만 후보로 본다. `생방송` 등 다른 값은 고르지 않는다
  - 2020 형식(`YYYY/MM/DD(요일) “본문” / 이름`)은 지금처럼 읽는다
- FR-4: 후보 중 날짜와 본문이 묵상과 같은 첫 영상을 고른다 (M3 R-3 의 비교 규칙·표기 차이 처리 그대로)
- FR-5: 결과 세 가지(찾음 / 영상 없음 / 검색 실패)와 화면 처리는 M3 R-4·M4 그대로. API 키가 없으면 지금처럼 "영상 없음"

## 5. 하지 않는 것
- 찾은 영상 id 저장(캐시): 진성 결정 2026-11-23 "나중에". 할당량 계산은 7장
- 설교 영상이 없을 때 생방송(글 embed)으로 대신하기: 진성 결정 2026-11-23 "안 됨"
- oEmbed·`videos.list` 로 영상 길이·생방송 여부 확인: 제목의 `[ 설교` 로 판정한다
- 검색 결과 다음 페이지(`pageToken`), 실제 네트워크 요청 테스트
- 2021~2024 묶음의 제목 형식 전수 조사 (7장 실측 외)

## 6. 바뀌는 기존 테스트 (진성 승인 2026-11-23 — 이 PRD 승인으로 갈음)
FR-1·FR-2 로 아래 테스트의 기대가 바뀐다. 바꾸거나 지워도 된다. **이 목록 밖의 기존 테스트 기대값은 바꾸지 않는다.**
- `MorningDevotionTests/DevotionVideoFinderTests.swift`
  - 글 embed 추출(M3 R-1): `ac1_videoIDFromIframe15155`·`ac2_videoIDFromLink12602`·`ac3_noVideoIn11480`·`ac12_videoIDCharset`·`ac12_videoIDBoundaries`·`ac12_videoIDFirstMatchWins` — R-1 을 지우면 함께 지운다
  - 글 embed 우선·검색 생략(M3 R-5): `ac9_findVideoPrefersArticleVideoWithoutSearching`·`ac9_emptyArticleHTMLFallsBackToSearch`·`ac4_findVideoSearchesWhenArticleHasNoVideo`·`ac5_findVideoSearchesWhenArticleHTMLIsNil` — "글에 embed 가 있어도 검색한다"로 바뀌거나, 글 HTML 인자가 없어지면 지운다
  - 검색어(M3 R-2): `ac11_searchQuery`·`ac11_searchQueryZeroPads`·`ac11_searchURLParameters`·`ac11_findVideoSendsDesignedURL` — `q` 기대값이 본문만으로 바뀐다. 0 채움 테스트는 날짜가 빠지면 지운다
- `MorningDevotionTests/DevotionScreenModelTests.swift`
  - 구약(2025/09/11) 묵상의 영상을 글 embed `PR9GK_S83NU` 로 기대하는 것: `expectOld` 기본값과 그것을 쓰는 테스트, `ac13_oldEntryLoadsArticleOnly`(유튜브를 부르지 않음 기대), `ac20_noAPIKeyIgnoresArticleEmbed` — 영상 기대값과 유튜브 호출 여부가 바뀐다. 그 외 기대(글·진행 위치·이동·문구)는 그대로 둔다

### 6-1. 설계 게이트에서 추가로 승인한 것 (F-6 설계 [결정], 2026-11-23 진성 y)
- D:160: 6장 목록 밖인 `ac18_refreshAcrossNoonIsNoOp`(`DevotionScreenModelTests.swift:437`)의 유튜브 0회 기대를 1회로 바꾼다 (load 때 1회, refresh 는 추가 호출 0회) — FR-1(구약도 항상 검색)과 함께 통과하려면 필요
- D:161: `findVideo` 의 `articleHTML` 인자를 없앤다. 6장 목록 밖 테스트(`ac6`·`ac7`·`ac8_findVideoIgnoresDateOnlyMatch`·`ac10a~d`·`ac10_emptyItemsIsNotFound`)는 기대값은 그대로 두고 `articleHTML: nil,` 인자 줄만 지운다

## 7. 기술적 고려
- 테스트 입력: `MorningDevotionTests/Fixtures/yt-search-20250913.json` — `q=잠언 24:11-22`·maxResults=5 응답 원문 (2026-11-23 수집, UTF-8). items 1개 `kH2QadelWio` `[ 설교 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은`. API 키 문자열 없음 (grep 0건)
- 생방송 영상은 검색에 나오지 않는다 (2026-11-23 실측: 위 두 검색 모두 생방송 `ut225mKfy2w` 없음. M3 5장 실측 메모의 "2025 생방송 `unlisted`"와 맞음). FR-3 의 `생방송` 거르기는 안전장치다 — 테스트는 fixture 제목을 바꾼 JSON 문자열로 만든다
- 본문만 검색 실측 (2026-11-23, 각 1건, 첫 일치 결과):
  - 2020 `q=요한복음 5:30-47` → `M5VtIg1WAic` `2020/07/13(월) “요한복음 5:30-47” / 박성호` (1번째)
  - 2022 `q=창세기 32:1-20` → `UsCVP4y7snI` `2022/01/31(월) &quot;창세기 32:1-20&quot; / 김남빈` (1번째, 글 embed 와 같은 id)
  - 2023 `q=여호수아 10:16-28` → `BCN20b7Yuk0` `2023/03/14(화) &quot;여호수아 10:16-28&quot; / 이대은` (1번째)
  - 2025 `q=잠언 23:24-35` → `T8fZYU9Pd0E` `[ 설교 | 새벽기도회 | 2025.9.11(목) ] 잠언 23:24-35 | 인도 김광욱` (1번째)
- 본문만 검색하면 다른 해의 같은 본문 영상이 섞일 수 있다. 날짜 비교(FR-4)로 거른다. 섞여서 그날 영상이 5개 밖으로 밀리는 경우는 미측정
- 할당량: `search.list` 1회 100 단위, 하루 약 100회 (M3 5장). 이제 구약·신약 모두 글을 열 때·이전·다음으로 옮길 때마다 1회 검색한다 (`DevotionScreenModel.swift:89` `buildState`). 진성 하루 약 5회 → 500 단위 = 한도의 5% (추정, 콘솔 값 미확인)
- 바뀌는 곳 (코드 확인): `DevotionVideoFinder.swift` (`findVideo`·`searchQuery`·`videoTitleEntry`·`videoID(inArticleHTML:)`), 부르는 쪽 `DevotionScreenModel.swift:117-121`

## 8. 성공 지표
- 실기기(iPhone 14 Pro, iOS 27.2)에서 2025/09/13 잠언 24:11-22 묵상 영상이 약 21분 설교 영상임을 진성이 확인
- 신약 2020 묵상 하나에서 영상이 나오는 것을 진성이 확인
- `.sap/config` 의 `TEST_CMDS` exit 0

## 9. 결정 필요
- (없음 — 캐시·생방송 대체·판별 방법은 5장에 진성 결정으로 적음)
