import Foundation

public enum BudgetError: LocalizedError {
    case invalidAmount, insufficientFunds, missingPot, invalidBackup
    public var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Bitte einen gültigen Betrag eingeben (höchstens zwei Nachkommastellen)."
        case .insufficientFunds: return "Dafür ist nicht genug Geld verfügbar."
        case .missingPot: return "Dieser Spartopf ist nicht mehr vorhanden."
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
    public static func format(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = cents % 100 == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
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
}
public struct Budget: Codable, Equatable {
    public var schema = 1
    public var setupComplete = false
    public var balance = 0
    public var fixedCosts = 0
    public var weeklyLimit = 14_500
    public var pots: [SavingPot] = [.init(name: "Urlaub", target: 80_000), .init(name: "Notgroschen", target: 100_000)]
    public var expenses: [Expense] = []
    public init() {}
    public var reserved: Int { pots.reduce(0) { $0 + $1.cents } }
    public var available: Int { balance - fixedCosts - reserved }
    public func weeklySpent(now: Date = Date(), calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return expenses.filter { $0.date >= interval.start && $0.date < interval.end }.reduce(0) { $0 + $1.cents }
    }
    public func weeklyRemaining(now: Date = Date(), calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        min(weeklyLimit - weeklySpent(now: now, calendar: calendar), available)
    }
    public mutating func addExpense(cents: Int, title: String, category: String, date: Date = Date()) throws {
        guard cents > 0, cents <= Euro.limit else { throw BudgetError.invalidAmount }
        guard cents <= balance else { throw BudgetError.insufficientFunds }
        balance -= cents
        expenses.insert(.init(title: title.isEmpty ? category : title, cents: cents, category: category, date: date), at: 0)
    }
    public mutating func undoExpense(id: UUID) {
        guard let i = expenses.firstIndex(where: { $0.id == id }) else { return }
        balance += expenses.remove(at: i).cents
    }
    public mutating func allocate(cents: Int, potID: UUID) throws {
        guard cents > 0 else { throw BudgetError.invalidAmount }
        guard cents <= available else { throw BudgetError.insufficientFunds }
        guard let i = pots.firstIndex(where: { $0.id == potID }) else { throw BudgetError.missingPot }
        pots[i].cents += cents
    }
    public mutating func release(cents: Int, potID: UUID) throws {
        guard cents > 0 else { throw BudgetError.invalidAmount }
        guard let i = pots.firstIndex(where: { $0.id == potID }) else { throw BudgetError.missingPot }
        guard cents <= pots[i].cents else { throw BudgetError.insufficientFunds }
        pots[i].cents -= cents
    }
    public static func demo() -> Budget {
        var b = Budget(); b.setupComplete = true; b.balance = 218_000; b.fixedCosts = 37_000
        b.pots = [.init(name: "Urlaub", cents: 48_000, target: 80_000), .init(name: "Notgroschen", cents: 75_000, target: 100_000)]
        return b
    }
    public func validated() throws -> Budget {
        guard schema == 1, balance >= 0, balance <= Euro.limit, fixedCosts >= 0, fixedCosts <= Euro.limit,
              weeklyLimit > 0, weeklyLimit <= Euro.limit,
              pots.count <= 100, Set(pots.map(\.id)).count == pots.count,
              Set(expenses.map(\.id)).count == expenses.count,
              pots.allSatisfy({ !$0.name.isEmpty && $0.cents >= 0 && $0.cents <= Euro.limit && $0.target > 0 && $0.target <= Euro.limit }),
              expenses.allSatisfy({ $0.cents > 0 && $0.cents <= Euro.limit }) else { throw BudgetError.invalidBackup }
        return self
    }
}
