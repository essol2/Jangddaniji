# 등산 기록 기능 구현 계획

## 브랜치 전략

- 작업 브랜치: `dev_mountain`
- 베이스: `main`
- 이 브랜치를 독립 버전으로 별도 배포

---

## 개요

기존 장거리 도보 여정 구조를 최대한 재활용하여 등산 기록 기능을 추가한다.
산 선택 → 실시간 GPS 트래킹 (백그라운드 포함) → HealthKit 실시간 연동 → 기록 저장의 흐름으로 구성한다.

---

## 사용자 플로우

```
EntryView
  └─ "등산 기록하기" 버튼 (진행 중인 등산 없을 때 항상 표시)
  └─ "이어서 등산하기" 버튼 (진행 중인 등산 있을 때 표시)
        ↓
  HikingSetupView
    - Naver API로 산 이름 검색 및 선택
    - "등산 시작" 버튼
        ↓
  HikingTrackingView
    - MapKit MapPolyline으로 실시간 경로 선 표시
    - HealthKit 실시간 폴링: 걸음수 · 거리 · 칼로리
    - 경과 시간 표시
    - 백그라운드에서도 GPS 계속 기록
    - 10초마다 트래킹 데이터 로컬 임시 저장 (강제 종료 복구용)
    - "등산 완료" 버튼
        ↓
  HikingResultView
    - 걸은 경로 지도 (MapKit 스냅샷)
    - 총 거리 · 걸음수 · 칼로리 · 소요 시간 요약
    - 사진 추가 / 메모 입력
    - 저장 → EntryView로 복귀
```

---

## 기술 결정사항

| 항목 | 결정 | 이유 |
|---|---|---|
| 지도 | MapKit | 완전 무료, 추가 SDK 불필요, iOS 17+ `MapPolyline` gradient 지원 |
| 위치 검색 | Naver Local Search API (기존) | 이미 연동됨 |
| HealthKit 수집 | 실시간 폴링 (30초 간격) | 트래킹 화면에 실시간 통계 표시 |
| 강제 종료 복구 | 10초마다 UserDefaults에 임시 저장 | 리소스 부담 거의 없음 |
| 일시정지 기능 | 미지원 | 미이동 시 GPS·걸음수 자연히 증가 안 함 |

---

## 데이터 저장 전략

기존 `Journey` + `DayRoute` 모델을 재활용한다.

```
Journey (journeyType = "hiking")
  - title: "북한산"           ← 산 이름
  - startDate = endDate       ← 당일 등산
  - totalSteps                ← HealthKit 걸음수
  - totalDistanceWalked       ← HealthKit 거리 (km)
  - statusRawValue: "completed" (완료 즉시 저장)
  └─ DayRoute (1개)
       - waypointsData: GPS 좌표 배열 (폴리라인)  ← 기존 필드 재활용
       - journalEntry: 사진 · 메모
```

---

## 구현 단계

### Phase 1 — 모델 및 기반 작업

**1-1. `Journey` 모델에 `journeyType` 추가**
- `var journeyType: String = "longDistance"` 필드 추가
- SwiftData 마이그레이션 플랜 작성 (`VersionedSchema`)

**1-2. `AppDestination` 및 `AppRouter` 확장**
- `.hikingSetup`, `.hikingTracking`, `.hikingResult(journeyID:)` destination 추가

**1-3. `Info.plist` 권한 추가**
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSHealthShareUsageDescription`
- Background Modes: `location`

---

### Phase 2 — 서비스 레이어

**2-1. `HikingTrackingService.swift` (신규)**
- `CLLocationManager` 래핑
- `allowsBackgroundLocationUpdates = true`
- 좌표 배열 누적 → 폴리라인 데이터 생성
- 거리 계산 (연속 좌표 간 `CLLocation.distance` 합산)
- 10초마다 누적 좌표를 `UserDefaults`에 임시 저장
- 앱 시작 시 미완료 세션 감지 → 복구 제안
- 시작 / 종료 제어

**2-2. `HealthKitService.swift` (신규)**
- 걸음수 / 거리 / 칼로리 쿼리
- `HKObserverQuery` 또는 30초 폴링으로 실시간 갱신
- 특정 시간 범위(등산 시작~현재/종료) 기준으로 집계

---

### Phase 3 — ViewModel

**3-1. `HikingSetupViewModel.swift` (신규)**
- Naver API로 산 이름 검색 (기존 `NaverLocationSearchService` 재활용)
- 선택된 산 이름 · 좌표 보관

**3-2. `HikingTrackingViewModel.swift` (신규)**
- `HikingTrackingService` 보유 및 제어
- `HealthKitService` 보유 및 실시간 폴링 관리
- 실시간 경과 시간 타이머
- 폴리라인 좌표 배열, 걸음수, 거리, 칼로리 → View에 노출
- 등산 완료 시 `Journey` + `DayRoute` SwiftData insert

---

### Phase 4 — View

**4-1. `HikingSetupView.swift` (신규)**
- 산 이름 검색창 (기존 `LocationSearchBar` 컴포넌트 재활용)
- 검색 결과 리스트
- 선택된 산 표시
- "등산 시작" 버튼

**4-2. `HikingTrackingView.swift` (신규)**
- MapKit `Map` + `MapPolyline` (gradient stroke)
- 현재 위치 마커 자동 추적
- 실시간 통계 카드: 걸음수 · 거리 · 칼로리 · 경과 시간
- 백그라운드 전환 시 안내 배너
- "등산 완료" 버튼

**4-3. `HikingResultView.swift` (신규)**
- 걸은 경로 지도 (MapKit 스냅샷, 인터랙션 없음)
- 통계 요약 (거리 · 걸음수 · 칼로리 · 소요 시간)
- 사진 추가 / 메모 입력
- "저장" 버튼 → SwiftData insert 후 EntryView로

---

### Phase 5 — 기존 화면 수정

**5-1. `EntryView.swift`**
- 진행 중인 등산(`journeyType == "hiking"` + `status == "active"`) 여부 쿼리 추가
- 진행 중인 등산 없으면 "등산 기록하기" 버튼 항상 표시
- 진행 중인 등산 있으면 "이어서 등산하기" 버튼 표시

**5-2. `CloudKitBackupService.swift`**
- `journeyType` 필드 백업/복원에 추가

**5-3. `JourneyArchiveListView` / `JourneyArchiveDetailView`**
- `journeyType`에 따라 등산 / 장거리 도보 배지 표시

---

## iCloud 기반 PC 간 동기화 설정

GitHub(origin) 외에 iCloud bare repo를 추가 remote로 사용하여 두 PC 간 코드를 동기화한다.
원격 저장소(GitHub) 없이 iCloud만으로 변경사항(델타)을 주고받는 구조다.

### Remote 구조

| remote | 용도 | 주소 |
|--------|------|------|
| `origin` | GitHub 백업/배포 (기존 유지) | https://github.com/essol2/Jangddaniji.git |
| `icloud` | PC 간 일상 동기화 (신규) | ~/Library/Mobile Documents/com~apple~CloudDocs/GitRepos/jangddanji.git |

---

### PC A 초기 설정 (1회)

```bash
# iCloud에 bare repo 생성
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/GitRepos
git init --bare ~/Library/Mobile\ Documents/com~apple~CloudDocs/GitRepos/jangddanji.git

# icloud remote 추가
cd ~/Documents/project/jangddanji
git remote add icloud ~/Library/Mobile\ Documents/com~apple~CloudDocs/GitRepos/jangddanji.git

# 전체 브랜치 iCloud에 push
git push icloud main
git push icloud dev_mountain
git push icloud dev_home
```

---

### PC B 초기 설정 (1회)

> iCloud 동기화가 완료된 후 실행할 것 (메뉴바 iCloud 아이콘 업로드 표시 없어야 함)

```bash
# iCloud bare repo에서 clone
git clone ~/Library/Mobile\ Documents/com~apple~CloudDocs/GitRepos/jangddanji.git ~/Documents/project/jangddanji

cd ~/Documents/project/jangddanji

# GitHub remote 추가 (origin)
git remote add origin https://github.com/essol2/Jangddaniji.git

# 브랜치 확인
git branch -a

# 작업 브랜치로 전환
git checkout dev_mountain
```

---

### 일상 사용법

**작업 시작 전 (어느 PC든)**
```bash
git pull icloud dev_mountain
```

**작업 완료 후 자리 뜨기 전**
```bash
git add .
git commit -m "작업 내용"
git push icloud dev_mountain
```

**GitHub에 올릴 때 (배포/백업 시)**
```bash
git push origin dev_mountain
```

---

### 주의사항

- `git push icloud` 후 **메뉴바 iCloud 아이콘의 업로드 표시가 사라진 것을 확인**하고 PC를 전환할 것
- `icloud`와 `origin`은 자동으로 동기화되지 않으므로 GitHub에 올리려면 별도로 `git push origin` 실행
- `.gitignore`에 `DerivedData/`, `xcuserdata/` 포함 여부 확인 (현재 포함됨 ✅)

---

## 변경 파일 목록 요약

| 파일 | 신규/수정 |
|---|---|
| `Models/Journey.swift` | 수정 |
| `Navigation/AppRouter.swift` | 수정 |
| `Views/Entry/EntryView.swift` | 수정 |
| `Services/CloudKitBackupService.swift` | 수정 |
| `Views/Archive/JourneyArchiveListView.swift` | 수정 |
| `Views/Archive/JourneyArchiveDetailView.swift` | 수정 |
| `Services/HikingTrackingService.swift` | 신규 |
| `Services/HealthKitService.swift` | 신규 |
| `ViewModels/HikingSetupViewModel.swift` | 신규 |
| `ViewModels/HikingTrackingViewModel.swift` | 신규 |
| `Views/Hiking/HikingSetupView.swift` | 신규 |
| `Views/Hiking/HikingTrackingView.swift` | 신규 |
| `Views/Hiking/HikingResultView.swift` | 신규 |
| `Info.plist` | 수정 |
