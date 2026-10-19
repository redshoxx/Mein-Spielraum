import Foundation

public struct UpcomingPayment: Identifiable, Equatable {
    public var id: UUID { payment.id }
    public let payment: RecurringPayment
    public let date: Date
    public let daysUntilDue: Int
    public var timingLabel: String {
        switch daysUntilDue {
        case ..<(-1): return "\(-daysUntilDue) Tage überfällig"
        case -1: return "1 Tag überfällig"
        case 0: return "Heute fällig"
        case 1: return "Morgen fällig"
        default: return "In \(daysUntilDue) Tagen"
        }
    }
}
extension Budget {
    /// The next unbooked occurrence per fixed-cost item, including overdue final bills.
    public func upcomingFixedPayments(now: Date = Date(), calendar: Calendar = .current) -> [UpcomingPayment] {
        payments.filter { $0.kind == .fixedCost && $0.hasPendingOccurrence(calendar: calendar) }.map { p in
            let date = p.nextDue(calendar: calendar)
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
            return UpcomingPayment(payment: p, date: date, daysUntilDue: days)
        }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.payment.name != $1.payment.name { return $0.payment.name < $1.payment.name }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
