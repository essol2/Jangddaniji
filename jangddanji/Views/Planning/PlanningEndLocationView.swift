import SwiftUI

struct PlanningEndLocationView: View {
    @Bindable var viewModel: PlanningViewModel

    @State private var waypointSearchIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("목적지")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)

                // 원점회귀 토글
                roundTripToggle

                if viewModel.isRoundTrip {
                    roundTripLocationList
                } else {
                    normalDestination
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 원점회귀 토글

    private var roundTripToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.isRoundTrip.toggle()
                if viewModel.isRoundTrip {
                    // 기존 도착지가 있으면 경유지로 이동
                    if let existingEnd = viewModel.endLocation,
                       existingEnd.latitude != viewModel.startLocation?.latitude
                        || existingEnd.longitude != viewModel.startLocation?.longitude {
                        viewModel.waypoints.append(existingEnd)
                    }
                    // 도착지를 출발지와 동일하게 설정
                    viewModel.endLocation = viewModel.startLocation
                } else {
                    // 원점회귀 해제 시 도착지 초기화
                    viewModel.endLocation = nil
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isRoundTrip ? "checkmark.circle.fill" : "circle")
                    .font(.appRegular(size: 22))
                    .foregroundStyle(viewModel.isRoundTrip ? AppColors.primaryBlueDark : AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("출발지로 돌아오기")
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("출발지와 도착지가 같은 순환 경로")
                        .font(.appRegular(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isRoundTrip ? AppColors.primaryBlueDark : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 일반 도착지 (기존 방식 + 경유지)

    private var normalDestination: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 경유지 목록
            ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, waypoint in
                waypointRow(waypoint: waypoint, index: index)
            }

            // 경유지 추가 버튼
            if waypointSearchIndex == (viewModel.waypoints.isEmpty ? 0 : viewModel.waypoints.count) && waypointSearchIndex != nil {
                waypointSearchBar(insertIndex: waypointSearchIndex!)
            } else {
                addWaypointButton {
                    waypointSearchIndex = viewModel.waypoints.count
                }
            }

            // 도착지
            LocationSearchBar(
                placeholder: "목적지를 입력하세요",
                selectedLocation: $viewModel.endLocation
            )
        }
    }

    // MARK: - 원점회귀 장소 리스트

    private var roundTripLocationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 출발지 (잠금)
            lockedLocationRow(
                icon: "flag.fill",
                label: "출발",
                name: viewModel.startLocation?.name ?? ""
            )

            // 경유지 목록
            ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, waypoint in
                waypointRow(waypoint: waypoint, index: index)

                // 경유지 사이 추가 버튼
                if waypointSearchIndex == index + 1 {
                    waypointSearchBar(insertIndex: index + 1)
                }
            }

            // 경유지 추가 버튼
            if waypointSearchIndex == nil || waypointSearchIndex == viewModel.waypoints.count {
                if waypointSearchIndex == viewModel.waypoints.count {
                    waypointSearchBar(insertIndex: viewModel.waypoints.count)
                } else {
                    addWaypointButton {
                        waypointSearchIndex = viewModel.waypoints.count
                    }
                }
            }

            // 도착지 (잠금 - 출발지와 동일)
            lockedLocationRow(
                icon: "flag.checkered",
                label: "도착",
                name: viewModel.startLocation?.name ?? ""
            )

            if viewModel.isRoundTrip && viewModel.waypoints.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("경유지를 1개 이상 추가해주세요")
                }
                .font(.appRegular(size: 13))
                .foregroundStyle(.orange)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 컴포넌트

    private func lockedLocationRow(icon: String, label: String, name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primaryBlueDark)
                .font(.appRegular(size: 16))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appRegular(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                Text(name)
                    .font(.appRegular(size: 15))
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func waypointRow(waypoint: LocationResult, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(AppColors.primaryBlueDark)
                .font(.appRegular(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("경유지 \(index + 1)")
                    .font(.appRegular(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                Text(waypoint.name)
                    .font(.appRegular(size: 15))
                if !waypoint.subtitle.isEmpty {
                    Text(waypoint.subtitle)
                        .font(.appRegular(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = viewModel.waypoints.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func addWaypointButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("경유지 추가")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.primaryBlueDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.primaryBlueDark.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func waypointSearchBar(insertIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("경유지 검색")
                    .font(.appRegular(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button {
                    withAnimation { waypointSearchIndex = nil }
                } label: {
                    Text("취소")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            WaypointSearchBar(placeholder: "경유할 장소를 입력하세요") { result in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.waypoints.insert(result, at: insertIndex)
                    waypointSearchIndex = nil
                }
            }
        }
    }
}

// MARK: - 경유지 전용 검색바 (선택 시 바인딩 대신 콜백 사용)

private struct WaypointSearchBar: View {
    let placeholder: String
    let onSelect: (LocationResult) -> Void

    @State private var searchText = ""
    @State private var results: [LocationResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let searchService: LocationSearchServiceProtocol = NaverLocationSearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.primaryBlueDark)
                    .font(.appRegular(size: 16))

                TextField(placeholder, text: $searchText)
                    .font(.appRegular(size: 16))
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            onSelect(result)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .foregroundStyle(AppColors.primaryBlueDark)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(.appRegular(size: 15))
                                        .foregroundStyle(AppColors.textPrimary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.appRegular(size: 12))
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        if result.id != results.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }

            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                isSearching = true
                do {
                    let searchResults = try await searchService.search(query: newValue)
                    if !Task.isCancelled {
                        results = searchResults
                    }
                } catch {}
                isSearching = false
            }
        }
    }
}
