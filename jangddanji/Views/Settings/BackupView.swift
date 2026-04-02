import SwiftUI
import SwiftData

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BackupViewModel()
    @State private var showRestoreConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // iCloud 상태
                iCloudStatusCard

                if viewModel.iCloudAvailable {
                    // 백업 카드
                    backupCard

                    // 복원 카드
                    restoreCard
                }
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("iCloud 백업")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.checkBackupStatus()
        }
        .alert("데이터 복원", isPresented: $showRestoreConfirm) {
            Button("복원", role: .destructive) {
                Task { await viewModel.restoreAllData(context: modelContext) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("iCloud에서 데이터를 복원하면 현재 기기의 모든 여정 데이터가 삭제되고 백업 데이터로 교체됩니다.")
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
                Task { await viewModel.backupAllData(context: modelContext) }
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
            .disabled(viewModel.isBackingUp || viewModel.isRestoring)

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

            Text("iCloud에 저장된 백업에서 모든 여정 데이터를 복원합니다. 현재 기기의 데이터는 삭제됩니다.")
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
            .disabled(viewModel.isBackingUp || viewModel.isRestoring || viewModel.cloudJourneyCount == 0)
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
