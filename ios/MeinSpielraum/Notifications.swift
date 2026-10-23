import SwiftUI
import UserNotifications
import UIKit

@MainActor final class BudgetNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var authorized = false
    @Published private(set) var status = "Noch nicht aktiviert"
    @Published var error: String?
    @Published var route: String?
    @Published var enabled = UserDefaults.standard.bool(forKey: "reminders.enabled")
    @Published var paymentsEnabled = UserDefaults.standard.object(forKey: "reminders.payments") as? Bool ?? true
    @Published var wishesEnabled = UserDefaults.standard.object(forKey: "reminders.wishes") as? Bool ?? true
    @Published var dailyEnabled = UserDefaults.standard.object(forKey: "reminders.daily") as? Bool ?? true
    private let center = UNUserNotificationCenter.current()
    private var refreshTask: Task<Void, Never>?
    override init() { super.init(); center.delegate = self }
    func activate(budget: Budget) async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            enabled = granted
            refresh(budget: budget)
        } catch { self.error = "Benachrichtigungen konnten nicht aktiviert werden: \(error.localizedDescription)" }
    }
    func refresh(budget: Budget) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "reminders.enabled"); defaults.set(paymentsEnabled, forKey: "reminders.payments")
        defaults.set(wishesEnabled, forKey: "reminders.wishes"); defaults.set(dailyEnabled, forKey: "reminders.daily")
        let previous = refreshTask
        previous?.cancel()
        refreshTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let settings = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
            status = authorized ? (enabled ? "Aktiv" : "Pausiert") : (settings.authorizationStatus == .denied ? "In iOS deaktiviert" : "Noch nicht erlaubt")
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            // Only this app feature's requests are reconciled; never touch unrelated requests.
            let old = pending.filter { $0.identifier.hasPrefix("spielraum.") }.map(\.identifier)
            var requests: [UNNotificationRequest] = []
            if enabled && authorized {
                for reminder in budget.reminders(paymentsEnabled: paymentsEnabled, wishesEnabled: wishesEnabled) {
                    let content = UNMutableNotificationContent()
                    content.title = reminder.title; content.body = reminder.body; content.sound = .default
                    content.userInfo = ["route": reminder.route]
                    let date = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.date)
                    requests.append(.init(identifier: "spielraum.\(reminder.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false)))
                }
                if dailyEnabled {
                    let content = UNMutableNotificationContent()
                    content.title = "Kurz innehalten. Mehr Spielraum."
                    content.body = "Prüfe dein Budget und die nächsten Zahlungen, bevor du heute noch etwas kaufst."
                    content.sound = .default; content.userInfo = ["route": "check"]
                    requests.append(.init(identifier: "spielraum.daily", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 18, minute: 0), repeats: true)))
                }
            }
            let desired = Set(requests.map(\.identifier))
            center.removePendingNotificationRequests(withIdentifiers: old.filter { !desired.contains($0) })
            for request in requests {
                guard !Task.isCancelled else { return }
                do { try await center.add(request) }
                catch { self.error = "Eine Erinnerung konnte nicht geplant werden: \(error.localizedDescription)" }
            }
        }
    }
    func test() async {
        guard authorized && enabled else { return }
        let c = UNMutableNotificationContent(); c.title = "Dein Spielraum ist dabei"
        c.body = "So erinnern wir dich an deinen Budgetcheck. Beträge bleiben auf dem Sperrbildschirm verborgen."
        c.sound = .default; c.userInfo = ["route": "check"]
        do { try await center.add(.init(identifier: "spielraum.test", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))) }
        catch { self.error = error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let destination = response.notification.request.content.userInfo["route"] as? String
        Task { @MainActor in route = destination }
        completionHandler()
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @EnvironmentObject private var notifications: BudgetNotifications
    @Environment(\.dismiss) private var dismiss
    @State private var testing = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Dein Budget denkt mit", systemImage: "bell.badge.fill").font(.title3.bold())
                    Text("Rechtzeitig an Zahlungen denken und vor spontanen Käufen kurz innehalten.")
                    LabeledContent("Mitteilungen", value: notifications.status)
                    if notifications.authorized {
                        Toggle("Benachrichtigungen aktiv", isOn: $notifications.enabled)
                    } else {
                        Button("Benachrichtigungen erlauben") { Task { await notifications.activate(budget: store.budget) } }
                        Button("iPhone-Einstellungen öffnen") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    }
                }
                Section("Woran wir dich erinnern") {
                    Toggle("Fixkosten um 9 Uhr", isOn: $notifications.paymentsEnabled)
                    Toggle("Ende der Kaufpause", isOn: $notifications.wishesEnabled)
                    Toggle("Budgetcheck um 18 Uhr", isOn: $notifications.dailyEnabled)
                }
                Section {
                    Button("Testmitteilung in 5 Sekunden") { testing = true; Task { await notifications.test() } }.disabled(!notifications.authorized || !notifications.enabled)
                    if testing { Text("Test geplant. Du kannst die App kurz in den Hintergrund legen.").font(.body) }
                    DisclosureGroup("Zustellung und Datenschutz") { Text("Ohne Kontostände, Händlernamen oder Beträge auf dem Sperrbildschirm. Zahlungen werden für die nächsten 45 Tage geplant, maximal 58 Einzelhinweise. Öffne die App regelmäßig, damit Änderungen berücksichtigt werden. Fokus und iOS-Einstellungen können Hinweise stummschalten.").font(.body).foregroundStyle(SpielraumTheme.muted).padding(.vertical, 10) }
                }
                if let error = notifications.error { Section { Text(error).foregroundStyle(SpielraumTheme.warning) } }
            }.navigationTitle("Benachrichtigungen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .onChange(of: notifications.enabled) { notifications.refresh(budget: store.budget) }
            .onChange(of: notifications.paymentsEnabled) { notifications.refresh(budget: store.budget) }
            .onChange(of: notifications.wishesEnabled) { notifications.refresh(budget: store.budget) }
            .onChange(of: notifications.dailyEnabled) { notifications.refresh(budget: store.budget) }
        }.readableScreen()
    }
}
