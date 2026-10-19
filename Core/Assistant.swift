import Foundation

public enum ExpensePurpose: String, Codable, CaseIterable, Identifiable {
    case necessary, wish, emergency
    public var id: String { rawValue }
    public var title: String { switch self { case .necessary: return "Notwendig"; case .wish: return "Wunsch"; case .emergency: return "Notfall" } }
}
public struct AssistantSettings: Codable, Equatable {
    public var automatic: Bool? = nil
    public var usesAutomatic: Bool { automatic != false }
    public var configured = false
    public var essentialWeekly = 0
    public var safetyBuffer = 0
    public var extraSavings = 0
    public var nextPayday: Date? = nil
    public var emergencyPotID: UUID? = nil
    public init() {}
}
public struct PurchaseWish: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var name: String
    public var cents: Int
    public var merchant: String
    public var category: String
    public var createdAt: Date
    public var readyAt: Date { createdAt.addingTimeInterval(48 * 60 * 60) }
    public init(name: String, cents: Int, merchant: String, category: String, createdAt: Date = Date()) {
        self.name = name; self.cents = cents; self.merchant = merchant; self.category = category; self.createdAt = createdAt
    }
}
public struct ReserveMovement: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var cents: Int
    public var date: Date
    public var emergency: Bool
}
public struct NecessityEstimate: Equatable {
    public let probability: Double
    public let samples: Int
    public let basis: String
}
public struct BudgetAssessment {
    public var payday: Date?
    public var days = 0
    public var fixedReserve = 0
    public var essentialReserve = 0
    public var essentialWeekly = 0
    public var learnedWeeks = 0
    public var learnedSamples = 0
    public var extraSavings = 0
    public var buffer = 0
    public var shortfall = 0
    public var purchaseLimit = 0
    public var additionalSavingsSuggestion = 0
    public var ready = false
    public var explanation = "Noch keine ausreichenden Daten vorhanden."
}

extension Budget {
    /// Local Bayesian estimate from user-labelled purchases. Unknown and emergency entries are excluded.
    public func necessityEstimate(merchant: String, category: String) -> NecessityEstimate? {
        let labelled = expenses.filter { $0.purpose == .necessary || $0.purpose == .wish }
        let key = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sameMerchant = key.isEmpty ? [] : labelled.filter { ($0.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
        let rows: [Expense]
        let basis: String
        if sameMerchant.count >= 3 { rows = sameMerchant; basis = "Deine Rückmeldungen zu diesem Händler" }
        else {
            let sameCategory = labelled.filter { $0.category == category }
            guard sameCategory.count >= 5 else { return nil }
            rows = sameCategory; basis = "Deine Rückmeldungen in dieser Kategorie"
        }
        let necessary = rows.filter { $0.purpose == .necessary }.count
        // Beta(1,1) prior avoids false certainty from a small sample. Suggestions never change hard limits.
        return NecessityEstimate(probability: Double(necessary + 1) / Double(rows.count + 2), samples: rows.count, basis: basis)
    }
    public func assessment(now: Date = Date(), calendar: Calendar = .current) -> BudgetAssessment {
        var a = BudgetAssessment()
        let automatic = assistant.usesAutomatic
        guard automatic || assistant.configured else { return a }
        a.buffer = assistant.safetyBuffer; a.extraSavings = assistant.extraSavings
        let today = calendar.startOfDay(for: now)
        let manual = assistant.nextPayday.map { calendar.startOfDay(for: $0) }
        let scheduled = payments.filter { $0.kind == .income && $0.hasPendingOccurrence(calendar: calendar) }
            .map { calendar.startOfDay(for: $0.nextDue(calendar: calendar)) }.filter { $0 > today }.min()
        // Advance only the forecast date, never book or invent an income.
        let automaticPayday = payments.filter { $0.kind == .income }.compactMap { p -> Date? in
            var index = p.completed
            while index < 12_000 && p.includesOccurrence(index, calendar: calendar) {
                let date = calendar.startOfDay(for: p.dueDate(at: index, calendar: calendar))
                if date > today { return date }
                index += 1
            }
            return nil
        }.min()
        let fallback = calendar.date(byAdding: .day, value: 30, to: today)!
        let horizon = automatic ? (automaticPayday ?? fallback) : (manual ?? scheduled)
        guard let payday = horizon,
              let days = calendar.dateComponents([.day], from: today, to: payday).day, days > 0, days <= 62 else {
            a.explanation = "Bitte den nächsten Gehaltstag prüfen. Überfälliges Gehalt zählt nicht als Guthaben."
            return a
        }
        a.payday = payday; a.days = days
        var iso = Calendar(identifier: .iso8601); iso.timeZone = calendar.timeZone
        let weekStart = iso.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let earliest = expenses.map(\.date).filter { $0 <= now }.min()
        let observedWeeks = earliest.flatMap { iso.dateInterval(of: .weekOfYear, for: $0) }.flatMap { iso.dateComponents([.weekOfYear], from: $0.end, to: weekStart).weekOfYear } ?? 0
        let weeks = max(0, min(8, observedWeeks))
        let start = iso.date(byAdding: .weekOfYear, value: -weeks, to: weekStart) ?? weekStart
        let necessary = expenses.filter {
            let protect = $0.purpose == .necessary || (automatic && $0.purpose == nil && $0.fundingPotID == nil)
            return protect && $0.date >= start && $0.date < weekStart
        }
        a.learnedSamples = necessary.count
        a.learnedWeeks = weeks
        var learned = 0
        if weeks >= 3 && necessary.count >= 8 {
            var totals: [Int] = []
            for i in 0..<weeks {
                let s = iso.date(byAdding: .weekOfYear, value: i, to: start)!
                let e = iso.date(byAdding: .weekOfYear, value: 1, to: s)!
                totals.append(necessary.filter { $0.date >= s && $0.date < e }.reduce(0) { $0 + $1.cents })
            }
            let sorted = totals.sorted()
            learned = sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.8)) - 1)]
        }
        // Learning may raise the protective essential reserve, never silently lower the user's baseline.
        a.essentialWeekly = max(assistant.essentialWeekly, automatic && learned == 0 ? weeklyLimit : learned)
        if automatic { a.buffer = max(a.buffer, a.essentialWeekly) }
        a.essentialReserve = Int(ceil(Double(a.essentialWeekly) * Double(days) / 7))
        var untilPayday = fixedCosts
        for p in payments where p.kind == .fixedCost {
            var index = p.completed
            while index < 12_000 && p.includesOccurrence(index, calendar: calendar) && calendar.startOfDay(for: p.dueDate(at: index, calendar: calendar)) <= payday {
                untilPayday += p.cents; index += 1
            }
        }
        a.fixedReserve = max(fixedReserve(now: now, calendar: calendar), untilPayday)
        let afterProtection = balance - reserved - a.fixedReserve - a.buffer - a.extraSavings - a.essentialReserve
        a.shortfall = max(0, -afterProtection)
        let endOfWeek = iso.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? payday
        let weekDays = max(0, min(days, iso.dateComponents([.day], from: today, to: endOfWeek).day ?? 7))
        let essentialThisWeek = Int(ceil(Double(a.essentialWeekly) * Double(weekDays) / 7))
        let remainingWeekly = weeklyLimit - weeklySpent(now: now, calendar: iso)
        a.purchaseLimit = max(0, min(afterProtection, remainingWeekly - essentialThisWeek))
        // Additional saving is only suggested beyond full remaining weekly allowances; no money is moved.
        a.additionalSavingsSuggestion = max(0, afterProtection - weeklyLimit * Int(ceil(Double(days) / 7)))
        a.ready = true
        a.explanation = learned > 0 ? "Aus deinen markierten Ausgaben gelernt; dein eigener Mindestbetrag und dein Wochenlimit bleiben bestehen." : "Noch wenig Lerndaten: Es gelten deine eigenen Planwerte. Für eine Ausgabenprognose werden mindestens 3 vollständige Wochen und 8 notwendige Ausgaben benötigt."
        if automatic {
            a.explanation = learned > 0
                ? "Automatisch aus eingetragenen Ausgaben geschätzt. Unmarkierte Ausgaben werden vorsichtshalber als Alltag geschützt; Rückmeldungen sind optional."
                : "Automatischer Start: Noch keine belastbare Historie. Dein Wochenlimit wird vorläufig vollständig für Alltag geschützt, zusätzlich eine Woche als Puffer. Mit mindestens 3 vollständigen Wochen und 8 Ausgaben passt sich die Schätzung an."
            if automaticPayday == nil { a.explanation += " Kein künftiger Einnahmetermin vorhanden: vorläufige Planung für 30 Tage, kein erkannter Gehaltstag." }
            else { a.explanation += " Planung bis zum nächsten Einnahmetermin; künftiges Einkommen zählt nicht zum Guthaben." }
        }
        return a
    }
    public mutating func labelExpense(id: UUID, purpose: ExpensePurpose?) {
        guard let i = expenses.firstIndex(where: { $0.id == id }) else { return }
        expenses[i].purpose = purpose
    }
    public mutating func buyWish(id: UUID, now: Date = Date(), calendar: Calendar = .current) throws {
        guard let i = wishes.firstIndex(where: { $0.id == id }), wishes[i].readyAt <= now else { throw BudgetError.purchasePause }
        let a = assessment(now: now, calendar: calendar)
        let w = wishes[i]
        guard a.ready, w.cents <= a.purchaseLimit else { throw BudgetError.budgetProtected }
        try addExpense(cents: w.cents, title: w.name, category: w.category, date: now, merchant: w.merchant, purpose: .wish)
        wishes.remove(at: i)
    }
    public mutating func emergencyExpense(cents: Int, title: String, date: Date = Date()) throws {
        guard cents > 0, cents <= Euro.limit, let id = assistant.emergencyPotID,
              let i = pots.firstIndex(where: { $0.id == id }), cents <= pots[i].cents, cents <= balance else { throw BudgetError.emergencyFunds }
        pots[i].cents -= cents
        balance -= cents
        expenses.insert(.init(title: title.isEmpty ? "Notfall" : title, cents: cents, category: "Notfall", date: date, merchant: nil, purpose: .emergency, fundingPotID: id), at: 0)
        reserveMovements.insert(.init(cents: -cents, date: date, emergency: true), at: 0)
    }
}
