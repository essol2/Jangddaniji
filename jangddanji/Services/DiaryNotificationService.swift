import Foundation
import UserNotifications

final class DiaryNotificationService {
    static let shared = DiaryNotificationService()
    private init() {}

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - 권한 요청

    func requestAuthorization() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }

    // MARK: - 알림 등록

    /// startHour ~ endHour 범위의 정시마다 알림 등록 (현재 시각 이후만)
    func scheduleHourlyNotifications(
        for dayRouteID: UUID,
        startHour: Int,
        endHour: Int
    ) {
        cancelNotifications(for: dayRouteID)

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // 현재 시각의 다음 정시부터 시작
        let firstHour = currentMinute == 0 ? currentHour : currentHour + 1

        for hour in firstHour...max(firstHour, endHour) {
            guard hour >= startHour, hour <= endHour else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = 0
            components.second = 0

            guard let triggerDate = calendar.date(from: components),
                  triggerDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "여정 기록 시간이에요 📹"
            content.body = "\(hour)시 클립을 촬영해보세요!"
            content.sound = .default
            content.userInfo = ["dayRouteID": dayRouteID.uuidString]

            let triggerComponents = calendar.dateComponents([.hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let identifier = notificationIdentifier(dayRouteID: dayRouteID, hour: hour)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request)
        }
    }

    // MARK: - 알림 해제

    func cancelNotifications(for dayRouteID: UUID) {
        let prefix = "diary-\(dayRouteID.uuidString)-"
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Private

    private func notificationIdentifier(dayRouteID: UUID, hour: Int) -> String {
        "diary-\(dayRouteID.uuidString)-\(hour)"
    }
}
