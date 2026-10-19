import Foundation

public enum BudgetError: LocalizedError {
    case missingExpense, changedEntry, invalidPotName, invalidAmount, insufficientFunds, missingPot, invalidBackup, alreadyBooked, notDue, invalidEndDate, purchasePause, budgetProtected, emergencyFunds
    public var errorDescription: String? {
        switch self {
        case .missingExpense: return "Diese Ausgabe ist nicht mehr vorhanden."
        case .changedEntry: return "Der Eintrag wurde inzwischen geändert. Bitte neu öffnen."
        case .invalidPotName: return "Bitte einen Namen mit 1 bis 40 Zeichen eingeben."
        case .invalidAmount: return "Bitte einen gültigen Betrag eingeben (höchstens zwei Nachkommastellen)."
        case .insufficientFunds: return "Dafür ist nicht genug Geld verfügbar."
        case .missingPot: return "Dieser Spartopf ist nicht mehr vorhanden."
        case .alreadyBooked: return "Dieser Termin wurde bereits gebucht oder inzwischen geändert."
        case .purchasePause: return "Die Kaufpause von 48 Stunden ist noch nicht abgelaufen."
        case .budgetProtected: return "Dieser Wunsch passt derzeit nicht in deinen geschützten Plan."
        case .emergencyFunds: return "Bitte Notfalltopf und Guthaben prüfen. Der Betrag übersteigt die verfügbare Notfallreserve."
        case .invalidEndDate: return "Die letzte Zahlung darf nicht vor dem ersten Zahlungstermin liegen."
        case .notDue: return "Dieser Termin liegt noch in der Zukunft."
        case .invalidBackup: return "Die gespeicherten Daten haben ein unbekanntes Format."
        }
    }
}

public enum Euro {
    public static let limit = 100_000_000 // €1 million in cents
    public static func parse(_ text: String, allowZero: Bool = false) throws -> Int {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard value.range(of: #"^[0-9]{1,7}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { throw BudgetError.invalidAmount }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int(parts[0]) ?? -1
        let fraction = parts.count > 1 ? String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0) : "00"
        let cents = whole * 100 + (Int(fraction) ?? 0)
        guard cents >= (allowZero ? 0 : 1), cents <= limit else { throw BudgetError.invalidAmount }
        return cents
    }
    private static let formatterLock = NSLock()
    private static let wholeFormatter = currencyFormatter(digits: 0)
    private static let fractionFormatter = currencyFormatter(digits: 2)
    private static func currencyFormatter(digits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.numberStyle = .currency; formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = digits; formatter.maximumFractionDigits = digits
        return formatter
    }
    public static func format(_ cents: Int) -> String {
        formatterLock.lock(); defer { formatterLock.unlock() }
        let formatter = cents % 100 == 0 ? wholeFormatter : fractionFormatter
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "0 €"
    }
    public static func editable(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100).replacingOccurrences(of: ".", with: ",")
    }
}

public struct SavingPot: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var cents: Int
    public var target: Int
    public init(name: String, cents: Int = 0, target: Int) { self.name = name; self.cents = cents; self.target = target }
}
public struct Expense: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var cents: Int
    public var category: String
    public var date: Date
    public var merchant: String? = nil
    public var purpose: ExpensePurpose? = nil
    public var fundingPotID: UUID? = nil
}
public struct Budget: Codable, Equatable {
    public var schema = 3
    public var setupComplete = false
    public var balance = 0
    public var fixedCosts = 0
    public var weeklyLimit = 14_500
    public var pots: [SavingPot] = [.init(name: "Urlaub", target: 80_000), .init(name: "Notgroschen", target: 100_000)]
    public var expenses: [Expense] = []
    public var payments: [RecurringPayment] = []
    public var recurringRecords: [RecurringRecord] = []
    public var assistant = AssistantSettings()
    public var wishes: [PurchaseWish] = []
    public var reserveMovements: [ReserveMovement] = []
    public init() {}
    enum CodingKeys: String, CodingKey { case schema, setupComplete, balance, fixedCosts, weeklyLimit, pots, expenses, payments, recurringRecords, assistant, wishes, reserveMovements }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let oldSchema = try c.decode(Int.self, forKey: .schema)
        guard (1...3).contains(oldSchema) else { throw BudgetError.invalidBackup }
        schema = 3
        setupComplete = try c.decode(Bool.self, forKey: .setupComplete)
        balance = try c.decode(Int.self, forKey: .balance)
        fixedCosts = try c.decode(Int.self, forKey: .fixedCosts)
        weeklyLimit = try c.decode(Int.self, forKey: .weeklyLimit)
        pots = try c.decode([SavingPot].self, forKey: .pots)
        expenses = try c.decode([Expense].self, forKey: .expenses)
        if oldSchema >= 2 {
            payments = try c.decode([RecurringPayment].self, forKey: .payments)
            recurringRecords = try c.decode([RecurringRecord].self, forKey: .recurringRecords)
        }
        if oldSchema == 3 {
            assistant = try c.decode(AssistantSettings.self, forKey: .assistant)
            wishes = try c.decode([PurchaseWish].self, forKey: .wishes)
            reserveMovements = try c.decode([ReserveMovement].self, forKey: .reserveMovements)
        }
    }
    public var reserved: Int { pots.reduce(0) { $0 + $1.cents } }
    public var available: Int { available(now: Date()) }
    public func weeklySpent(now: Date = Date(), calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return expenses.filter { $0.date >= interval.start && $0.date < interval.end && $0.fundingPotID == nil }.reduce(0) { $0 + $1.cents }
    }
    public func weeklyRemaining(now: Date = Date(), calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        min(weeklyLimit - weeklySpent(now: now, calendar: calendar), available(now: now, calendar: calendar))
    }
    public mutating func addExpense(cents: Int, title: String, category: String, date: Date = Date(), merchant: String? = nil, purpose: ExpensePurpose? = nil) throws {
        guard cents > 0, cents <= Euro.limit else { throw BudgetError.invalidAmount }
        guard cents <= balance else { throw BudgetError.insufficientFunds }
        balance -= cents
        expenses.insert(.init(title: title.isEmpty ? category : title, cents: cents, category: category, date: date, merchant: merchant, purpose: purpose), at: 0)
    }
    public mutating func updateExpense(id: UUID, cents: Int, title: String, category: String, merchant: String?, purpose: ExpensePurpose?, expected: Expense? = nil) throws {
        guard let i = expenses.firstIndex(where: { $0.id == id }) else { throw BudgetError.missingExpense }
        let old = expenses[i]
        guard expected == nil || expected == old else { throw BudgetError.changedEntry }
        guard cents > 0, cents <= Euro.limit else { throw BudgetError.invalidAmount }
        let delta = cents - old.cents
        guard balance >= delta, balance - delta <= Euro.limit else { throw BudgetError.insufficientFunds }
        var potIndex: Int?
        if let funding = old.fundingPotID {
            potIndex = pots.firstIndex { $0.id == funding }
            if let p = potIndex {
                guard pots[p].cents >= delta, pots[p].cents - delta <= Euro.limit else { throw BudgetError.emergencyFunds }
            } else if delta > 0 { throw BudgetError.missingPot }
        }
        balance -= delta
        if let p = potIndex, delta != 0 {
            pots[p].cents -= delta
            reserveMovements.insert(.init(cents: -delta, date: Date(), emergency: true), at: 0)
        }
        expenses[i].cents = cents
        expenses[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? category : String(title.prefix(100))
        expenses[i].category = String(category.prefix(100))
        expenses[i].merchant = merchant.map { String($0.prefix(100)) }
        expenses[i].purpose = old.fundingPotID == nil ? purpose : .emergency
    }
    public mutating func undoExpense(id: UUID) {
        guard let i = expenses.firstIndex(where: { $0.id == id }) else { return }
        let e = expenses.remove(at: i)
        balance += e.cents
        if let id = e.fundingPotID, let p = pots.firstIndex(where: { $0.id == id }) {
            pots[p].cents += e.cents
            reserveMovements.insert(.init(cents: e.cents, date: Date(), emergency: true), at: 0)
        }
    }
    public mutating func allocate(cents: Int, potID: UUID) throws {
        guard cents > 0 else { throw BudgetError.invalidAmount }
        guard cents <= available else { throw BudgetError.insufficientFunds }
        guard let i = pots.firstIndex(where: { $0.id == potID }) else { throw BudgetError.missingPot }
        pots[i].cents += cents
        assistant.extraSavings = max(0, assistant.extraSavings - cents)
        reserveMovements.insert(.init(cents: cents, date: Date(), emergency: false), at: 0)
    }
    public mutating func release(cents: Int, potID: UUID) throws {
        guard cents > 0 else { throw BudgetError.invalidAmount }
        guard let i = pots.firstIndex(where: { $0.id == potID }) else { throw BudgetError.missingPot }
        guard cents <= pots[i].cents else { throw BudgetError.insufficientFunds }
        pots[i].cents -= cents
        reserveMovements.insert(.init(cents: -cents, date: Date(), emergency: false), at: 0)
    }
    public mutating func updatePot(id: UUID, name: String, target: Int) throws {
        guard let i = pots.firstIndex(where: { $0.id == id }) else { throw BudgetError.missingPot }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 40 else { throw BudgetError.invalidPotName }
        guard target > 0, target <= Euro.limit else { throw BudgetError.invalidAmount }
        pots[i].name = cleanName
        pots[i].target = target
    }
    public mutating func deletePot(id: UUID) throws {
        guard let i = pots.firstIndex(where: { $0.id == id }) else { throw BudgetError.missingPot }
        let removed = pots.remove(at: i)
        if removed.cents > 0 {
            reserveMovements.insert(.init(cents: -removed.cents, date: Date(), emergency: false), at: 0)
        }
        if assistant.emergencyPotID == id { assistant.emergencyPotID = nil }
        // Historical expense references stay intact: emergency spending must not
        // become ordinary weekly spending when its former pot is deleted.
    }
    public static func demo() -> Budget {
        var b = Budget(); b.setupComplete = true; b.balance = 218_000; b.fixedCosts = 37_000
        b.pots = [.init(name: "Urlaub", cents: 48_000, target: 80_000), .init(name: "Notgroschen", cents: 75_000, target: 100_000)]
        return b
    }
    private func validDate(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        return seconds.isFinite && (-2_208_988_800.0...7_258_118_400.0).contains(seconds)
    }
    public func validated() throws -> Budget {
        guard schema == 3, balance >= 0, balance <= Euro.limit, fixedCosts >= 0, fixedCosts <= Euro.limit,
              weeklyLimit > 0, weeklyLimit <= Euro.limit,
              pots.count <= 100, Set(pots.map(\.id)).count == pots.count,
              expenses.count <= 100_000, Set(expenses.map(\.id)).count == expenses.count,
              pots.allSatisfy({ !$0.name.isEmpty && $0.cents >= 0 && $0.cents <= Euro.limit && $0.target > 0 && $0.target <= Euro.limit }),
              expenses.allSatisfy({ $0.cents > 0 && $0.cents <= Euro.limit && validDate($0.date) && $0.title.count <= 1000 && $0.category.count <= 1000 && ($0.merchant?.count ?? 0) <= 1000 }),
              payments.count <= 1000, Set(payments.map(\.id)).count == payments.count,
              recurringRecords.count <= 100_000, Set(recurringRecords.map(\.id)).count == recurringRecords.count,
              recurringRecords.allSatisfy({ $0.cents > 0 && $0.cents <= Euro.limit && validDate($0.dueDate) && validDate($0.bookedAt) && (0..<12_000).contains($0.occurrence) }) else { throw BudgetError.invalidBackup }
        guard assistant.nextPayday.map(validDate) ?? true, assistant.essentialWeekly >= 0, assistant.essentialWeekly <= Euro.limit,
              assistant.safetyBuffer >= 0, assistant.safetyBuffer <= Euro.limit,
              assistant.extraSavings >= 0, assistant.extraSavings <= Euro.limit,
              wishes.count <= 1000, Set(wishes.map(\.id)).count == wishes.count,
              wishes.allSatisfy({ !$0.name.isEmpty && $0.name.count <= 100 && $0.cents > 0 && $0.cents <= Euro.limit && validDate($0.createdAt) }),
              reserveMovements.count <= 100_000, reserveMovements.allSatisfy({ (-Euro.limit...Euro.limit).contains($0.cents) && validDate($0.date) }) else { throw BudgetError.invalidBackup }
        for payment in payments { _ = try payment.validated() }
        return self
    }
}
