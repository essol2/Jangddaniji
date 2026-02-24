import Foundation
import SwiftUI

enum AppDestination: Hashable {
    case planning
    case dashboard
    case dayDetail(dayRouteID: UUID)
    case routeModify(dayRouteID: UUID)
    case archiveList
    case archiveDetail(journeyID: UUID)
    case journeyComplete(journeyID: UUID)
}

@Observable
final class AppRouter {
    var path = NavigationPath()

    func navigateTo(_ destination: AppDestination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
