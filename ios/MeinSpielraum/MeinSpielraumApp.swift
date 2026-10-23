import SwiftUI
@main struct MeinSpielraumApp: App {
    @StateObject private var store = BudgetStore()
    @StateObject private var notifications = BudgetNotifications()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).environmentObject(notifications).preferredColorScheme(.light)
        }
    }
}
