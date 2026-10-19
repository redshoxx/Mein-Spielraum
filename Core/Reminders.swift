import Foundation

public struct BudgetReminder: Identifiable, Equatable {
    public let id: String
    public let date: Date
    public let title: String
    public let body: String
    public let route: String
}
extension Budget {
    /// Generic lock-screen text deliberately avoids balances, amounts and merchant names.
    /// Only the next unbooked bill is scheduled. Reopening or editing refreshes the plan.
    public func reminders(now: Date = Date(), calendar: Calendar = .current, paymentsEnabled: Bool = true, wishesEnabled: Bool = true) -> [BudgetReminder] {
        var result: [BudgetReminder] = []
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: 45, to: today)!
        if paymentsEnabled {
            for item in upcomingFixedPayments(now: now, calendar: calendar) {
                let day = calendar.startOfDay(for: item.date)
                if day < today {
                    // A single daily overdue digest is added below, not one alert per old bill.
                    continue
                }
                for lead in [1, 0] {
                    guard let date = calendar.date(byAdding: .day, value: -lead, to: day).flatMap({ calendar.date(bySettingHour: 9, minute: 0, second: 0, of: $0) }), date > now, date <= horizon else { continue }
                    result.append(.init(id: "bill-\(item.id)-\(item.payment.completed)-\(lead)", date: date, title: lead == 1 ? "Morgen steht eine Zahlung an" : "Heute steht eine Zahlung an", body: "Prüfe deine offenen Fixkosten in Mein Spielraum. Bereits bezahlt? Buche den Termin als bezahlt.", route: "payments"))
                }
            }
            if upcomingFixedPayments(now: now, calendar: calendar).contains(where: { $0.daysUntilDue < 0 }) {
                let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
                let date = morning > now ? morning : calendar.date(byAdding: .day, value: 1, to: morning)!
                result.append(.init(id: "overdue", date: date, title: "Offene Zahlungen prüfen", body: "Mindestens ein eingetragener Zahlungstermin liegt zurück. Prüfe den Haushalt, bevor du Geld ausgibst.", route: "payments"))
            }
        }
        if wishesEnabled {
            for wish in wishes where wish.readyAt > now && wish.readyAt <= horizon {
                result.append(.init(id: "wish-\(wish.id)", date: wish.readyAt, title: "Deine Kaufpause ist vorbei", body: "Brauchst du den Wunsch noch? Prüfe zuerst deinen aktuellen Spielraum. Das ist keine Kaufempfehlung.", route: "wish"))
            }
        }
        return Array(result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }.prefix(58))
    }
}
