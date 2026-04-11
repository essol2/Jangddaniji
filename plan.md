# dev_home 작업 계획

---

## Phase 6 — 기본 Back 버튼 → 커스텀 "돌아가기" 버튼 통일

기본 iOS `< Back` 버튼이 노출되는 화면을 `PlanningContainerView`의 커스텀 돌아가기 버튼과 동일한 스타일로 교체한다.

### 참조 — 커스텀 돌아가기 버튼 (PlanningContainerView.swift)

```swift
Button {
    router.pop()
} label: {
    HStack(spacing: 4) {
        Image(systemName: "chevron.left")
            .font(.appRegular(size: 13))
        Text("돌아가기")
            .font(.appRegular(size: 14))
    }
    .foregroundStyle(AppColors.primaryBlueDark)
}
```

### 변경 대상 화면

| 화면 | 파일 | 현재 상태 |
|------|------|----------|
| iCloud 백업 | `Views/Settings/BackupView.swift` | `.navigationTitle("iCloud 백업")` + 기본 Back 버튼 |
| 등산 기록 (산 검색) | `Views/Hiking/HikingSetupView.swift` | `.navigationTitle("등산 기록")` + 기본 Back 버튼 |

### 화면별 변경 사항

**6-1. `BackupView.swift`**
- `@Environment(AppRouter.self) private var router` 추가
- `.navigationTitle("iCloud 백업")`, `.navigationBarTitleDisplayMode(.large)` 제거
- `.navigationBarHidden(true)` 추가
- `ScrollView` 상단에 커스텀 헤더 삽입:
  - 돌아가기 버튼 (PlanningContainerView와 동일 스타일)
  - 타이틀 "iCloud 백업" (`.appBold(size: 22)`)

**6-2. `HikingSetupView.swift`** (dev_home에는 없으므로 dev_mountain에서 별도 작업)
- `.navigationTitle("등산 기록")`, `.navigationBarTitleDisplayMode(.large)` 제거
- `.navigationBarHidden(true)` 추가
- `ScrollView` 상단에 커스텀 헤더 삽입:
  - 돌아가기 버튼 (PlanningContainerView와 동일 스타일)
  - 타이틀 "등산 기록" (`.appBold(size: 22)`)

---

## Phase 7 — BackupView 작업 중 이탈 방어

백업/복원/삭제 진행 중에 사용자가 화면을 나가면 데이터 유실 위험이 있으므로 방어 처리한다.

### 현재 문제점

| 작업 | 이탈 시 위험 |
|------|-------------|
| 백업 | Task 취소로 일부만 업로드될 수 있음 |
| 복원 | 기존 데이터 삭제 후 삽입 전에 끊기면 데이터 유실 |
| 삭제 | 일부만 삭제된 상태로 남을 수 있음 |

### 변경 사항

**`BackupViewModel.swift`**
- `currentTask: Task<Void, Never>?` 프로퍼티 추가 — 현재 실행 중인 작업 참조 보관
- `backupAllData`, `restoreAllData`, `deleteAllCloudData` 호출 시 `currentTask`에 Task 저장
- `cancelCurrentTask()` 메서드 추가 — `currentTask?.cancel()` 후 상태 초기화 (`isBackingUp`/`isRestoring`/`isDeleting` = false)
- 각 async 메서드 내부에 `Task.isCancelled` 체크 포인트 삽입 (특히 복원의 삭제↔삽입 사이)

**`BackupView.swift`**
- `isWorking` 계산 프로퍼티 추가: `isBackingUp || isRestoring || isDeleting`
- `workingLabel` 계산 프로퍼티 추가: 현재 진행 중인 작업명 반환 ("백업"/"복원"/"삭제")
- 돌아가기 버튼: `isWorking` 시 `router.pop()` 대신 확인 alert 표시
  - 메시지: "현재 {작업명}이(가) 진행 중입니다.\n작업을 중단하고 나가시겠습니까?"
  - "나가기" → `viewModel.cancelCurrentTask()` 후 `router.pop()`
  - "취소" → 유지
- 백업/복원/삭제 버튼: 다른 작업 진행 중이면 disabled (기존 로직에 `isDeleting` 조건 보강)
