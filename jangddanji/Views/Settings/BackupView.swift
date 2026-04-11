import SwiftUI
import SwiftData

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var viewModel = BackupViewModel()
    @State private var showRestoreConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showExitConfirm = false

    private var isWorking: Bool {
        viewModel.isBackingUp || viewModel.isRestoring || viewModel.isDeleting
    }

    private var workingLabel: String {
        if viewModel.isBackingUp { return "백업" }
        if viewModel.isRestoring { return "복원" }
        if viewModel.isDeleting { return "삭제" }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    if isWorking {
                        showExitConfirm = true
                    } else {
                        router.pop()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.appRegular(size: 13))
                        Text("돌아가기")
                            .font(.appRegular(size: 14))
                    }
                    .foregroundStyle(AppColors.primaryBlueDark)
                }

                Text("iCloud 백업")
                    .font(.appBold(size: 22))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // iCloud 상태
                    iCloudStatusCard

                    if viewModel.iCloudAvailable {
                        // 백업 카드
                        backupCard

                        // 복원 카드
                        restoreCard

                        // 삭제 카드
                        if viewModel.cloudJourneyCount > 0 {
                            deleteCard
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .task {
            await viewModel.checkBackupStatus()
        }
        .alert("iCloud 백업 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                viewModel.currentTask = Task { await viewModel.deleteAllCloudData() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("iCloud에 저장된 모든 백업 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("작업 진행 중", isPresented: $showExitConfirm) {
            Button("나가기", role: .destructive) {
                viewModel.cancelCurrentTask()
                router.pop()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 \(workingLabel)이(가) 진행 중입니다.\n작업을 중단하고 나가시겠습니까?")
        }
        .alert("데이터 복원", isPresented: $showRestoreConfirm) {
            Button("복원", role: .destructive) {
                viewModel.currentTask = Task { await viewModel.restoreAllData(context: modelContext) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 여정을 모두 백업 하셨나요?\n백업 없이 복원할 경우 현재 기기 데이터가 모두 지워질 수 있습니다.")
        }
    }

    // MARK: - iCloud Status

    private var iCloudStatusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.iCloudAvailable ? "icloud.fill" : "icloud.slash.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.iCloudAvailable ? AppColors.primaryBlue : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.iCloudAvailable ? "iCloud 연결됨" : "iCloud 미연결")
                        .font(.appBold(size: 16))
                        .foregroundStyle(AppColors.textPrimary)

                    if !viewModel.iCloudAvailable {
                        Text("설정 > Apple ID > iCloud에서 로그인해주세요")
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                if viewModel.isCheckingStatus {
                    ProgressView()
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Backup Card

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("백업")
                    .font(.appBold(size: 18))
                    .foregroundStyle(AppColors.textPrimary)
            }

            if let lastDate = viewModel.lastBackupDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("마지막 백업: \(lastDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.appRegular(size: 13))
                }
                .foregroundStyle(AppColors.textSecondary)
            }

            if viewModel.cloudJourneyCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                    Text("클라우드에 \(viewModel.cloudJourneyCount)개의 여정 저장됨")
                        .font(.appRegular(size: 13))
                }
                .foregroundStyle(AppColors.textSecondary)
            }

            if viewModel.isBackingUp {
                progressSection
            }

            Button {
                viewModel.currentTask = Task { await viewModel.backupAllData(context: modelContext) }
            } label: {
                HStack {
                    if viewModel.isBackingUp {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                    Text(viewModel.isBackingUp ? "백업 중..." : "지금 백업하기")
                        .font(.appBold(size: 16))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isBackingUp ? AppColors.primaryBlue.opacity(0.6) : AppColors.primaryBlueDark)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isWorking)

            if let success = viewModel.successMessage, !viewModel.isBackingUp, !viewModel.isRestoring {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(success)
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let error = viewModel.errorMessage, !viewModel.isBackingUp, !viewModel.isRestoring {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.appRegular(size: 13))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Restore Card

    private var restoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("복원")
                    .font(.appBold(size: 18))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text("iCloud에 저장된 백업에서 모든 여정 데이터를 복원합니다.")
                .font(.appRegular(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            if viewModel.isRestoring {
                progressSection
            }

            Button {
                showRestoreConfirm = true
            } label: {
                HStack {
                    if viewModel.isRestoring {
                        ProgressView()
                            .tint(AppColors.primaryBlueDark)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(viewModel.isRestoring ? "복원 중..." : "iCloud에서 복원하기")
                        .font(.appBold(size: 16))
                }
                .foregroundStyle(AppColors.primaryBlueDark)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.primaryBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isWorking || viewModel.cloudJourneyCount == 0)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Delete Card

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text("백업 삭제")
                    .font(.appBold(size: 18))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text("iCloud에 저장된 모든 백업 데이터를 삭제합니다. 기기의 데이터는 영향을 받지 않습니다.")
                .font(.appRegular(size: 13))
                .foregroundStyle(AppColors.textSecondary)

            if viewModel.isDeleting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("삭제 중...")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("iCloud 백업 모두 삭제")
                        .font(.appBold(size: 16))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isWorking)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: viewModel.progress)
                .tint(AppColors.primaryBlue)

            Text(viewModel.progressMessage)
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
