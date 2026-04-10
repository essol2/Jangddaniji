# 등산 기록 기능 구현 계획

## 브랜치 전략

- 작업 브랜치: `dev_mountain`
- 베이스: `main`
- 이 브랜치를 독립 버전으로 별도 배포

---

## 개요

기존 장거리 도보 여정 구조를 최대한 재활용하여 등산 기록 기능을 추가한다.
산 선택 → 실시간 GPS 트래킹 (백그라운드 포함) → HealthKit 연동 → 기록 저장의 흐름으로 구성한다.

---

## 사용자 플로우

```
EntryView
  └─ "등산 기록하기" 버튼 (진행 중인 등산 없을 때 항상 표시)
        ↓
  HikingSetupView
    - Naver API로 산 이름 검색 및 선택
    - "등산 시작" 버튼
        ↓
  HikingTrackingView
    - 지도 + 실시간 경로 선 표시
    - 걸음수 · 거리 · 경과 시간 표시
    - 백그라운드에서도 GPS 계속 기록
    - "등산 완료" 버튼
        ↓
  HikingResultView
    - 총 거리 · 걸음수 · 소요 시간 요약
    - 걸은 경로 지도
    - 사진 · 메모 기록
    - 저장 → EntryView로 복귀
```

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
- 거리 계산 (연속 좌표 간 CLLocation.distance 합산)
- 시작 / 일시정지 / 재개 / 종료 제어

**2-2. `HealthKitService.swift` (신규)**
- 걸음수 / 거리 / 칼로리 쿼리
- 특정 시간 범위(등산 시작~종료) 기준으로 집계

---

### Phase 3 — ViewModel

**3-1. `HikingSetupViewModel.swift` (신규)**
- Naver API로 산 이름 검색 (기존 `NaverLocationSearchService` 재활용)
- 선택된 산 이름 · 좌표 보관

**3-2. `HikingTrackingViewModel.swift` (신규)**
- `HikingTrackingService` 보유 및 제어
- 실시간 경과 시간 타이머
- 폴리라인 좌표 배열 → View에 노출
- 현재 거리 (서비스에서 계산된 값 표시)
- 등산 완료 시 임시 `Journey` + `DayRoute` 객체 생성하여 다음 화면으로 전달

---

### Phase 4 — View

**4-1. `HikingSetupView.swift` (신규)**
- 산 이름 검색창 (기존 `LocationSearchBar` 컴포넌트 재활용 검토)
- 검색 결과 리스트
- 선택된 산 표시
- "등산 시작" 버튼

**4-2. `HikingTrackingView.swift` (신규)**
- MapKit Map + 폴리라인 오버레이
- 현재 위치 마커
- 걸음수 / 거리 / 경과 시간 카드
- "등산 완료" 버튼
- 백그라운드 전환 시 상태 유지 안내 배너

**4-3. `HikingResultView.swift` (신규)**
- 걸은 경로 지도 (인터랙션 없는 스냅샷)
- 통계 요약 (거리 · 걸음수 · 소요 시간)
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

## 미결 사항 (검토 필요)

1. **등산 중 앱 강제 종료 시 복구** — 트래킹 데이터를 중간중간 로컬에 저장해야 하는지
2. **지도 뷰 선택** — MapKit 기본 Map 뷰 사용 vs NMapsMap (Naver Maps SDK) 도입
3. **HealthKit 수집 타이밍** — 등산 종료 시점에 전체 집계 vs 실시간 폴링
4. **일시정지 기능** — 트래킹 중 일시정지/재개 지원 여부

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
