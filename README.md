# 장딴지 (Jangddanji)

> 당신의 장거리 단짝 지도

장거리 도보 여행자와 등산 애호가를 위한 경로 기록·관리 iOS 앱입니다.

---

## 주요 기능

### 장거리 도보 여정
- 출발지·도착지·경유지 설정 및 경로 계산
- 일별 구간 자동 분할 (기간 기준 / 일일 거리 기준)
- 일별 진행 현황 대시보드
- 날짜별 일지 및 사진 기록
- 완료된 여정 아카이브

### 등산 기록 *(예정)*
- 산 이름 검색으로 간편 시작
- 실시간 GPS 트래킹 (백그라운드 포함)
- 지도 위 실제 이동 경로 시각화
- HealthKit 연동으로 걸음수·거리·칼로리 자동 기록
- 등산 완료 후 사진·메모 기록

### 공통
- iCloud 백업 및 복원 (CloudKit)

---

## 기술 스택

| 분류 | 기술 |
|---|---|
| UI | SwiftUI |
| 데이터 | SwiftData |
| 상태 관리 | `@Observable` (iOS 17+) |
| 지도 | MapKit |
| 위치 검색 | Naver Local Search API (Apple MapKit 폴백) |
| 위치 추적 | CoreLocation |
| 건강 데이터 | HealthKit |
| 백업 | CloudKit (Private Database) |

---

## 타겟 환경

- iOS 26.0+
- iPhone

---

## 프로젝트 구조

```
jangddanji/
├── Models/              # SwiftData 모델 (Journey, DayRoute, JournalEntry 등)
├── Services/            # 외부 연동 (위치 검색, 경로 계산, CloudKit 백업 등)
├── ViewModels/          # @Observable ViewModel
├── Views/
│   ├── Entry/           # 첫 진입 화면
│   ├── Planning/        # 장거리 여정 계획
│   ├── Dashboard/       # 진행 중 여정 현황
│   ├── DayDetail/       # 일별 상세
│   ├── RouteModify/     # 경로 수정
│   ├── Archive/         # 완료 여정 보관함
│   ├── Hiking/          # 등산 기록 (예정)
│   └── Settings/        # iCloud 백업
├── Components/          # 재사용 UI 컴포넌트
├── Navigation/          # AppRouter
├── Theme/               # AppColors
└── Utilities/           # 포맷터 유틸리티
```
