import SwiftUI
@main struct MeinSpielraumApp: App {
    @StateObject private var store = BudgetStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.dark)
        }
    }
}
