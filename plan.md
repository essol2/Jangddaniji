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

---

## Phase 8 — 이전 발걸음 날짜별 기록 표시

아카이브 상세 화면(`JourneyArchiveDetailView`)에 전체 여정 통계뿐 아니라 날짜별(DayRoute별) 실제 걸음수·이동거리를 표시한다.

### 현재 상태

| 레벨 | 걸음수 | 이동거리 | 비고 |
|------|--------|---------|------|
| Journey (전체) | `totalSteps` | `totalDistanceWalked` | 저장됨 |
| DayRoute (날짜별) | 없음 | `distance` (계획 거리만) | **실제 데이터 없음** |

현재 `DayDetailViewModel.markCompleted()`에서 Pedometer 데이터를 받아 Journey 전체 합산에만 더하고, DayRoute에는 저장하지 않는다.

### 변경 사항

**8-1. `DayRoute` 모델 필드 추가 (`Models/DayRoute.swift`)**
- `var actualSteps: Int = 0` — 해당 일자 실제 걸음수
- `var actualDistanceWalked: Double = 0` — 해당 일자 실제 이동거리 (km)

**8-2. `DayDetailViewModel.markCompleted()` 수정**
- 완료 시 Pedometer에서 받은 걸음수·거리를 `dayRoute.actualSteps`, `dayRoute.actualDistanceWalked`에도 저장
- 기존 Journey 합산 로직은 유지

**8-3. `JourneyArchiveDetailView` — ArchiveDayCard 펼침 영역에 통계 행 추가**

카드를 펼쳤을 때 Divider 아래, 사진/메모 위에 걸음수·이동거리 한 줄을 표시한다.

```
[Day 1] [4/11 · 출발지 → 도착지]     [12.3km 📝] [^]
─────────────────────────────────────────────
 🚶 3,421걸음  ·  📏 2.1km 이동          ← 신규
[사진들...]
[메모 텍스트]
```

구현:
- 펼침 영역(`isExpanded`) 진입 직후, Divider 아래에 `HStack` 추가
- 왼쪽: `shoeprints.fill` 아이콘 + 걸음수 (`.appRegular(size: 13)`, `.purple`)
- 가운데: `·` 구분자
- 오른쪽: `figure.walk` 아이콘 + 이동거리 km (`.appRegular(size: 13)`, `.blue`)
- `actualSteps == 0 && actualDistanceWalked == 0`이면 통계 행 자체를 숨김 (기존 데이터 호환)

**8-4. `CloudKitBackupService` 백업/복원 필드 추가**
- `actualSteps`, `actualDistanceWalked` 필드를 백업/복원 대상에 포함

### 기존 데이터 호환성

이미 완료된 여정의 DayRoute에는 `actualSteps = 0`, `actualDistanceWalked = 0` (기본값)이 들어가므로, 아카이브 카드에서 0인 경우 해당 항목을 숨기거나 "-"로 표시하여 자연스럽게 처리한다.

---

## Phase 9 — 이전 발걸음 여정 삭제 기능

아카이브 상세 화면(`JourneyArchiveDetailView`)에서 개별 여정을 삭제할 수 있도록 한다.

### UX 플로우

```
아카이브 상세 화면 (스크롤 최하단)
  └─ "여정 삭제하기" 버튼 (빨간색 텍스트, 배경 없음)
        ↓ 탭
  Alert: "여정을 삭제하시겠습니까?"
  메시지: "'{여정 타이틀}'의 모든 기록이 영구적으로 삭제됩니다."
  [삭제] [취소]
        ↓ 삭제 탭
  SwiftData에서 Journey 삭제 (cascade로 DayRoute, JournalEntry, JournalPhoto 연쇄 삭제)
  → router.pop()으로 목록 화면 복귀
```

### 변경 사항

**9-1. `JourneyArchiveDetailView.swift` (`ArchiveDetailContentView`)**
- `@Environment(\.modelContext) private var modelContext` 추가
- `@State private var showDeleteConfirm = false` 추가
- 스크롤 최하단 (dayRoute ForEach 아래)에 삭제 버튼 배치:
  - `trash` 아이콘 + "여정 삭제하기" 텍스트
  - `.foregroundStyle(.red)`, `.font(.appRegular(size: 15))`
  - 배경 없는 텍스트 버튼 스타일
- `.alert` 추가:
  - 타이틀: "여정을 삭제하시겠습니까?"
  - 메시지: "'{journey.title}'의 모든 기록이 영구적으로 삭제됩니다."
  - "삭제" (destructive) → `context.delete(journey)` + `context.save()` + `router.pop()`
  - "취소" (cancel)

---

## Phase 10 — 구간 완료 축하 화면 캡처 및 이미지 저장

현재 `CelebrationOverlayView`는 3초 후 자동으로 사라지는데, 사용자가 수동 스크린샷을 찍는 경우가 많다. 자동 dismiss를 제거하고 캡처 이미지 저장 기능을 추가한다.

### 현재 상태

- `CelebrationOverlayView` — 구간 완료 시 오버레이 (걸음수/이동거리 표시, 3초 후 auto dismiss)
- `DayDetailView`, `DashboardView` 두 곳에서 사용
- `JourneyCompleteView` — 전체 여정 완료 시 별도 전체 화면 (이건 이번 범위 아님)

### UX 플로우

```
구간 완료 버튼 탭
    ↓
CelebrationOverlayView 등장 (컨페티 + 축하 카드)
    ↓ 3초 auto dismiss 제거, 버튼으로 제어
카드 하단에 두 개 버튼:
  [이미지 저장] — 축하 카드 영역을 렌더링하여 사진 앨범에 저장
  [닫기]       — 기존 dismiss 동작
    ↓ 이미지 저장 탭
카드 영역을 `ImageRenderer`로 렌더링 → `UIImageWriteToSavedPhotosAlbum`으로 저장
저장 완료 시 "저장되었습니다" 토스트 또는 버튼 텍스트 변경으로 피드백
```

### 변경 사항

**10-1. `CelebrationOverlayView.swift` 수정**
- 3초 auto dismiss (`DispatchQueue.main.asyncAfter`) 제거
- 배경 탭 dismiss 제거 (실수로 닫히는 것 방지)
- 카드 하단에 버튼 2개 추가:
  - "이미지 저장" 버튼: `AppColors.primaryBlueDark` 배경, 흰 텍스트
  - "닫기" 버튼: 텍스트만, `AppColors.textSecondary`
- 축하 카드 콘텐츠(🎉 + 축하합니다 + 걸음수/거리)를 별도 `@ViewBuilder` 변수로 분리
- `ImageRenderer`로 카드 영역만 캡처 → `UIImageWriteToSavedPhotosAlbum`으로 저장

**캡처 피드백 연출 (3단계):**

1단계 — 플래시 효과:
- "이미지 저장" 버튼 탭 시 `ImageRenderer`로 카드 캡처
- 전체 화면에 `Color.white` 오버레이를 `opacity 0 → 1 → 0` 으로 0.3초간 애니메이션
- 카메라 셔터 느낌의 순간 번쩍임

2단계 — 캡처 프리뷰:
- 플래시 후 축하 카드가 축소되면서 흰색 배경 위에 렌더링된 미리보기 이미지로 전환
- 미리보기 아래에 "이미지 저장" 버튼과 "닫기" 버튼

3단계 — 저장:
- "이미지 저장" 탭 → `UIImageWriteToSavedPhotosAlbum`으로 사진 앨범 저장
- 저장 완료 시 "사진 앨범에 저장되었습니다" 텍스트로 버튼 영역 대체
- "닫기" 버튼은 유지

```
[이미지 저장] 탭 (축하 카드 위)
    ↓
전체 화면 흰색 플래시 (0.3초) + ImageRenderer 캡처
    ↓
축하 카드 → 축소 + 그림자가 있는 미리보기 이미지로 전환
흰색 배경 위 중앙에 캡처된 이미지 (~70% 크기)
[이미지 저장] [닫기]
    ↓ 이미지 저장 탭
사진 앨범 저장 → "사진 앨범에 저장되었습니다" + [닫기]
```

**10-2. `Info.plist`**
- `NSPhotoLibraryAddUsageDescription` 권한 추가 (사진 앨범 저장용) — 이미 있으면 스킵

---

## Phase 11 — 개발자에게 의견 보내기

### 개요

`EntryView` 하단에 작은 밑줄 텍스트 버튼을 추가하고, 누르면 Google Form을 앱 내 WebView(SFSafariViewController)로 띄운다.
별도 서버/API 없이 Google Form 응답이 연결된 Google Sheets에 자동 기록된다.

- Google Form URL: `https://forms.gle/bHJhScdEYwkaYfc67`

---

### 11-1. `EntryView.swift` 수정

버튼 위치: iCloud 백업 버튼 아래 `Spacer(height: 40)` 구간, copyright 텍스트 바로 위

```
[iCloud 백업 버튼]
Spacer (height: 40)
개발자에게 의견 보내기   ← 신규 (밑줄, 작은 텍스트)
© 2026 Jangddanji...
```

디자인:
- `Text("개발자에게 의견 보내기")`
- `.font(.appRegular(size: 13))`
- `.foregroundStyle(.white.opacity(0.75))`
- `.underline()`
- `.padding(.bottom, 8)`

탭 시: `isFeedbackPresented = true` → `FeedbackWebView` sheet 표시

상태값 추가:
```swift
@State private var isFeedbackPresented = false
```

`.sheet` 연결:
```swift
.sheet(isPresented: $isFeedbackPresented) {
    FeedbackWebView()
}
```

---

### 11-2. `Views/Feedback/FeedbackWebView.swift` (신규)

`SFSafariViewController`를 SwiftUI sheet로 표시하는 `UIViewControllerRepresentable` 래퍼.

- URL: `https://forms.gle/bHJhScdEYwkaYfc67`
- `SFSafariViewController` 사용 → JS 완전 지원, 쿠키 처리, Done 버튼으로 sheet 닫기 내장
- `AppRouter` / `AppDestination` 변경 불필요 (sheet 방식)

```swift
struct FeedbackWebView: UIViewControllerRepresentable {
    let url = URL(string: "https://forms.gle/bHJhScdEYwkaYfc67")!

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

---

### 변경 파일 목록

| 파일 | 신규/수정 |
|------|---------|
| `Views/Entry/EntryView.swift` | 수정 |
| `Views/Feedback/FeedbackWebView.swift` | 신규 |

---

## Phase 12 — 여정 다이어리 영상

### 개요

매 정시마다 로컬 알림을 발송하고, 사용자가 알림을 탭하면 카메라 화면이 열린다. 촬영 버튼을 누르면 2초간 자동 녹화되며 클립이 저장된다. 하루 여정 완료 시 저장된 클립들을 하나의 영상으로 합산하고, `DayDetailView`에서 영상을 확인·다운로드할 수 있다.

---

### 12-1. 데이터 모델 변경 (`DayRoute.swift`)

기존 `waypointsData: Data?` 패턴과 동일하게 JSON 인코딩 방식으로 추가.

```swift
/// 촬영된 클립 파일 경로 목록 (JSON: ["path1", "path2", ...])
var diaryClipsData: Data?

/// 합산 완료된 최종 영상 파일 경로
var diaryVideoPath: String?

/// 다이어리 알림 시작 시각 (기본값 8 = 오전 8시)
var diaryNotificationStartHour: Int = 8

/// 다이어리 알림 종료 시각 (기본값 23 = 오후 11시)
var diaryNotificationEndHour: Int = 23
```

헬퍼 프로퍼티:
```swift
var diaryClipPaths: [String] {
    get {
        guard let data = diaryClipsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    set {
        diaryClipsData = try? JSONEncoder().encode(newValue)
    }
}
```

**SwiftData 마이그레이션:**
- `VersionedSchema` V1 (기존) → V2 (신규 필드 추가)
- `MigrationPlan`에서 `willMigrate` 단계 처리
- 신규 필드는 옵셔널/기본값이므로 경량 마이그레이션(lightweight migration) 적용 가능

---

### 12-2. `DiaryNotificationService.swift` (신규)

**역할:** 여정 시작 시 매 정시 알림 등록, 완료 시 해제

```swift
// 알림 등록 (DayDetailView 진입 시 또는 시간 설정 변경 시 호출)
func scheduleHourlyNotifications(
    for dayRouteID: UUID,
    startHour: Int,   // DayRoute.diaryNotificationStartHour
    endHour: Int      // DayRoute.diaryNotificationEndHour
)

// 알림 해제 (완료 버튼 탭 시 또는 시간 재설정 시 호출)
func cancelNotifications(for dayRouteID: UUID)
```

- `UNUserNotificationCenter`로 `startHour ~ endHour` 범위 내 정시마다 알림 등록
- 현재 시각보다 이미 지난 정시는 건너뜀
- 알림 `userInfo`에 `dayRouteID` 포함 → 탭 시 해당 DayRoute로 이동
- 알림 identifier 패턴: `"diary-\(dayRouteID.uuidString)-\(hour)"`
- 시간 설정 변경 시: 기존 알림 전체 해제 후 새 범위로 재등록

---

### 12-3. `DiaryRecordingService.swift` (신규)

**역할:** AVCaptureSession 관리 + 2초 클립 저장

```swift
// 세션 시작 (카메라 프리뷰용)
func startSession()

// 녹화 시작 → 2초 후 자동 완료
func startRecording(hour: Int, dayRouteID: UUID) async throws -> String  // 클립 파일 경로 반환

// 세션 종료
func stopSession()
```

- `AVCaptureSession` + `AVCaptureMovieFileOutput`
- 저장 경로: `Documents/DiaryClips/{dayRouteID}/{hour}.mov`
- 2초 후 `AVCaptureMovieFileOutput.stopRecording()` 자동 호출 (`Task.sleep`)
- `AVCaptureDevice.default(.builtInWideAngleCamera)` 후면 카메라 사용

---

### 12-4. `DiaryVideoService.swift` (신규)

**역할:** 클립에 시각 오버레이 합성 + 전체 클립 합산 내보내기

```swift
// 클립 합산 + 오버레이 내보내기 (비동기, 진행률 반환)
func exportDiaryVideo(
    clipPaths: [String],
    dayRouteID: UUID
) async throws -> String  // 최종 영상 파일 경로 반환
```

**합산 과정:**
1. `AVMutableComposition`에 클립들을 시간순으로 추가
2. 각 클립 구간에 `CATextLayer`(시각 텍스트)를 `AVVideoCompositionCoreAnimationTool`로 합성
   - 텍스트: 파일명에서 hour 추출 (ex. `11.mov` → `"11:00"`)
   - 폰트: 시스템 Bold, size 72, 흰색, 중앙 정렬
   - 배경: 반투명 검정 레이어 (가독성)
3. `AVAssetExportSession`으로 MP4 내보내기
4. 저장 경로: `Documents/DiaryVideos/{dayRouteID}/diary.mp4`

---

### 12-5. `DiaryRecordingView.swift` (신규)

**역할:** 카메라 프리뷰 + 촬영 버튼 UX

```
┌─────────────────────┐
│                     │
│   카메라 프리뷰      │
│   (전체화면)        │
│                     │
│  ← 닫기   11:00 촬영│  ← 상단 오버레이
│                     │
│                     │
│       [ ● ]         │  ← 촬영 버튼
│    탭하여 촬영       │
└─────────────────────┘
```

**상태:**
- `@State private var isRecording: Bool`
- `@State private var remainingTime: Double = 2.0`
- `@State private var showCompletionToast: Bool`

**촬영 버튼 탭 동작:**
1. `isRecording = true` → 버튼 비활성화 + 원형 타이머 표시
2. `DiaryRecordingService.startRecording()` 호출
3. 2초 후 완료 → 클립 경로를 `DayRoute.diaryClipPaths`에 append + SwiftData save
4. `showCompletionToast = true` → "11시 클립이 저장됐습니다" 토스트 1.5초 표시
5. 토스트 완료 후 `router.pop()`

**카메라 프리뷰:**
- `AVCaptureVideoPreviewLayer`를 `UIViewRepresentable`로 래핑한 `CameraPreviewView` 사용

---

### 12-6. `DiaryVideoPlayerView.swift` (신규)

**역할:** 합산 영상 재생 + 다운로드

```
┌─────────────────────┐
│  ← 닫기             │
│                     │
│   VideoPlayer       │
│   (AVPlayer)        │
│                     │
└─────────────────────┘
      [사진 앨범에 저장]
```

- `VideoPlayer(player:)` (SwiftUI AVKit)
- 다운로드 버튼 → `PHPhotoLibrary.shared().performChanges` 로 사진 앨범 저장
- 저장 완료 시 "저장됐습니다" 토스트

---

### 12-7. `AppRouter.swift` / `jangddanjiApp.swift` 수정

`AppDestination`에 케이스 추가:
```swift
case diaryRecording(dayRouteID: UUID)
case diaryPlayer(dayRouteID: UUID)
```

`destinationView(for:)` switch 추가:
```swift
case .diaryRecording(let id):
    DiaryRecordingView(dayRouteID: id)
case .diaryPlayer(let id):
    DiaryVideoPlayerView(dayRouteID: id)
```

**알림 탭 처리 (`jangddanjiApp.swift`):**
- `UNUserNotificationCenterDelegate` 채택
- `userNotificationCenter(_:didReceive:)` 에서 `userInfo["dayRouteID"]` 파싱
- `router.navigateTo(.diaryRecording(dayRouteID:))` 호출

---

### 12-8. `DayDetailView.swift` 수정

`journalTextSection` 아래에 `diarySection`, `diaryNotificationSettingSection` 순서로 추가:

#### diarySection — 영상 카드

```
┌─────────────────────────────┐
│ 오늘의 영상                  │
│ ┌───┐ ┌───┐ ┌───┐           │  ← 클립 썸네일 가로 스크롤
│ │11 │ │13 │ │15 │           │    클립 0개면 "아직 촬영된 클립이 없습니다" 안내
│ └───┘ └───┘ └───┘           │
│                             │
│ ▶ 영상 보러가기              │  ← diaryVideoPath != nil 일 때
│ ◌ 영상 생성 중...  [진행률]  │  ← 생성 중일 때
└─────────────────────────────┘
```

#### diaryNotificationSettingSection — 알림 시간 설정 카드

```
┌─────────────────────────────┐
│ 영상 촬영 알림               │
│                             │
│ 시작  [오전 8시  ▾]          │  ← Picker (0~23시)
│ 종료  [오후 11시 ▾]          │  ← Picker (0~23시, startHour보다 커야 함)
│                             │
│ 매 정시마다 알림을 보내드려요  │  ← 안내 문구 (textSecondary, small)
└─────────────────────────────┘
```

- Picker 변경 시: `dayRoute.diaryNotificationStartHour` / `diaryNotificationEndHour` 즉시 저장
- 이어서 `DiaryNotificationService.cancelNotifications` → `scheduleHourlyNotifications` 재등록
- 여정 완료(`isCompleted`) 상태이면 섹션 전체 미표시

**완료 버튼 탭 시 추가 동작:**
- `DiaryNotificationService.cancelNotifications(for: dayRoute.id)` 호출
- `diaryClipPaths.count > 0` 이면 `DiaryVideoService.exportDiaryVideo()` 비동기 호출
- 완료되면 `dayRoute.diaryVideoPath` 업데이트

---

### 12-9. `Info.plist` 권한 추가

| 키 | 용도 |
|----|------|
| `NSCameraUsageDescription` | 여정 클립 촬영 |
| `NSMicrophoneUsageDescription` | 영상 오디오 녹음 |

(`NSPhotoLibraryAddUsageDescription`은 Phase 10에서 추가 예정)

---

### 변경/신규 파일 목록

| 파일 | 신규/수정 |
|------|---------|
| `Models/DayRoute.swift` | 수정 |
| `Navigation/AppRouter.swift` | 수정 |
| `jangddanjiApp.swift` | 수정 |
| `Views/DayDetail/DayDetailView.swift` | 수정 |
| `Info.plist` | 수정 |
| `Services/DiaryNotificationService.swift` | 신규 |
| `Services/DiaryRecordingService.swift` | 신규 |
| `Services/DiaryVideoService.swift` | 신규 |
| `Views/Diary/DiaryRecordingView.swift` | 신규 |
| `Views/Diary/DiaryVideoPlayerView.swift` | 신규 |
