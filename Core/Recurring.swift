import Foundation

public enum PaymentCadence: Int, Codable, CaseIterable, Identifiable {
    case monthly = 1, quarterly = 3, yearly = 12
    public var id: Int { rawValue }
    public var title: String {
        switch self { case .monthly: return "Monatlich"; case .quarterly: return "Vierteljährlich"; case .yearly: return "Jährlich" }
    }
}
public enum PaymentKind: String, Codable { case income, fixedCost }

public struct RecurringPayment: Codable, Equatable, Identifiable {
    public var id: UUID = UUID()
    public var name: String
    public var cents: Int
    public var kind: PaymentKind
    public var cadence: PaymentCadence
    public var firstDue: Date
    public var completed: Int = 0
    public init(name: String, cents: Int, kind: PaymentKind, cadence: PaymentCadence, firstDue: Date) {
        self.name = name; self.cents = cents; self.kind = kind; self.cadence = cadence; self.firstDue = firstDue
    }
    public func dueDate(at index: Int, calendar: Calendar = .current) -> Date {
        // Always use the original date: 31 Jan -> 28 Feb -> 31 Mar, without date drift.
        calendar.date(byAdding: .month, value: index * cadence.rawValue, to: firstDue) ?? firstDue
    }
    public func nextDue(calendar: Calendar = .current) -> Date { dueDate(at: completed, calendar: calendar) }
    public var monthlyEquivalent: Int { (cents + cadence.rawValue - 1) / cadence.rawValue }
    public func isDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: nextDue(calendar: calendar)) <= calendar.startOfDay(for: now)
    }
    public func outstandingThroughMonth(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        var total = 0
        var index = completed
        while index < 12_000, dueDate(at: index, calendar: calendar) < month.end {
            total += cents
            index += 1
        }
        return total
    }
    public func validated() throws -> RecurringPayment {
        let year = Calendar(identifier: .gregorian).component(.year, from: firstDue)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
              cents > 0, cents <= Euro.limit, (2000...2100).contains(year),
              (0..<12_000).contains(completed), kind != .income || cadence == .monthly else { throw BudgetError.invalidBackup }
        return self
    }
}
public struct RecurringRecord: Codable, Equatable, Identifiable {
    public var id: UUID = UUID()
    public var paymentID: UUID
    public var occurrence: Int
    public var name: String
    public var cents: Int
    public var kind: PaymentKind
    public var dueDate: Date
    public var bookedAt: Date
}

extension Budget {
    public func fixedReserve(now: Date = Date(), calendar: Calendar = .current) -> Int {
        fixedCosts + payments.filter { $0.kind == .fixedCost }.reduce(0) { $0 + $1.outstandingThroughMonth(now: now, calendar: calendar) }
    }
    public func available(now: Date, calendar: Calendar = .current) -> Int {
        balance - fixedReserve(now: now, calendar: calendar) - reserved
    }
    public var monthlyIncome: Int { payments.filter { $0.kind == .income }.reduce(0) { $0 + $1.cents } }
    public var monthlyFixedEquivalent: Int { payments.filter { $0.kind == .fixedCost }.reduce(0) { $0 + $1.monthlyEquivalent } }
    public mutating func savePayment(_ payment: RecurringPayment) throws {
        _ = try payment.validated()
        guard !payments.contains(where: { $0.id == payment.id }), payments.count < 1000 else { throw BudgetError.invalidBackup }
        payments.append(payment)
    }
    public mutating func replacePayment(id: UUID, with payment: RecurringPayment) throws {
        _ = try payment.validated()
        guard let index = payments.firstIndex(where: { $0.id == id }), payment.id != id,
              !payments.contains(where: { $0.id == payment.id }) else { throw BudgetError.invalidBackup }
        payments[index] = payment
    }
    public mutating func bookPayment(id: UUID, expectedOccurrence: Int, now: Date = Date(), calendar: Calendar = .current) throws {
        guard let i = payments.firstIndex(where: { $0.id == id }), payments[i].completed == expectedOccurrence else { throw BudgetError.alreadyBooked }
        let payment = payments[i]
        guard payment.isDue(now: now, calendar: calendar) else { throw BudgetError.notDue }
        guard payment.completed < 11_999 else { throw BudgetError.invalidBackup }
        if payment.kind == .income {
            guard balance <= Euro.limit - payment.cents else { throw BudgetError.invalidAmount }
            balance += payment.cents
        } else {
            guard balance >= payment.cents else { throw BudgetError.insufficientFunds }
            balance -= payment.cents
        }
        recurringRecords.insert(.init(paymentID: id, occurrence: payment.completed, name: payment.name, cents: payment.cents, kind: payment.kind, dueDate: payment.nextDue(calendar: calendar), bookedAt: now), at: 0)
        payments[i].completed += 1
    }
    public mutating func undoPayment(recordID: UUID) throws {
        guard let r = recurringRecords.firstIndex(where: { $0.id == recordID }),
              let i = payments.firstIndex(where: { $0.id == recurringRecords[r].paymentID }),
              payments[i].completed == recurringRecords[r].occurrence + 1 else { throw BudgetError.alreadyBooked }
        let record = recurringRecords[r]
        // Editing a payment creates a new ID so old records cannot undo a changed schedule.
        if record.kind == .income {
            guard balance >= record.cents else { throw BudgetError.insufficientFunds }
            balance -= record.cents
        } else {
            guard balance <= Euro.limit - record.cents else { throw BudgetError.invalidAmount }
            balance += record.cents
        }
        payments[i].completed -= 1
        recurringRecords.remove(at: r)
    }
}
