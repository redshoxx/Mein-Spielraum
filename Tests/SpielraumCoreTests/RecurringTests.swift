import XCTest
@testable import SpielraumCore

final class RecurringTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    func testMonthlyEndOfMonthDoesNotDrift() {
        let p = RecurringPayment(name: "Gehalt", cents: 200_000, kind: .income, cadence: .monthly, firstDue: date(2026, 1, 31))
        XCTAssertEqual(p.dueDate(at: 1, calendar: calendar), date(2026, 2, 28))
        XCTAssertEqual(p.dueDate(at: 2, calendar: calendar), date(2026, 3, 31))
    }
    func testQuarterlyAndYearlyDatesIncludingLeapYear() {
        let quarterly = RecurringPayment(name: "Versicherung", cents: 30_000, kind: .fixedCost, cadence: .quarterly, firstDue: date(2024, 1, 31))
        XCTAssertEqual(quarterly.dueDate(at: 1, calendar: calendar), date(2024, 4, 30))
        XCTAssertEqual(quarterly.dueDate(at: 2, calendar: calendar), date(2024, 7, 31))
        let yearly = RecurringPayment(name: "Jahreskarte", cents: 120_000, kind: .fixedCost, cadence: .yearly, firstDue: date(2024, 2, 29))
        XCTAssertEqual(yearly.dueDate(at: 1, calendar: calendar), date(2025, 2, 28))
        XCTAssertEqual(yearly.dueDate(at: 4, calendar: calendar), date(2028, 2, 29))
        XCTAssertEqual(quarterly.monthlyEquivalent, 10_000)
        XCTAssertEqual(yearly.monthlyEquivalent, 10_000)
    }
    func testFutureIncomeIsOnlyPlanAndCannotBeBookedEarly() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Gehalt", cents: 200_000, kind: .income, cadence: .monthly, firstDue: date(2026, 11, 1))
        try b.savePayment(p)
        XCTAssertEqual(b.monthlyIncome, 200_000)
        XCTAssertEqual(b.balance, 218_000)
        XCTAssertEqual(b.available(now: date(2026, 10, 19), calendar: calendar), 58_000)
        let before = b
        XCTAssertThrowsError(try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(2026, 10, 19), calendar: calendar))
        XCTAssertEqual(b, before)
    }
    func testIncomeBookingAdvancesAndRejectsDuplicate() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Gehalt", cents: 200_000, kind: .income, cadence: .monthly, firstDue: date(2026, 10, 15))
        try b.savePayment(p)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(2026, 10, 19), calendar: calendar)
        XCTAssertEqual(b.balance, 418_000)
        XCTAssertEqual(b.payments[0].nextDue(calendar: calendar), date(2026, 11, 15))
        XCTAssertEqual(b.recurringRecords.count, 1)
        XCTAssertThrowsError(try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(2026, 10, 19), calendar: calendar))
        try b.undoPayment(recordID: b.recurringRecords[0].id)
        XCTAssertEqual(b.balance, 218_000)
        XCTAssertEqual(b.payments[0].completed, 0)
    }
    func testPaidFixedCostsDoNotDoubleReduceAvailableOrWeeklyLimit() throws {
        let today = date(2026, 10, 19)
        var b = Budget.demo()
        let p = RecurringPayment(name: "Miete", cents: 20_000, kind: .fixedCost, cadence: .monthly, firstDue: date(2026, 10, 15))
        try b.savePayment(p)
        XCTAssertEqual(b.available(now: today, calendar: calendar), 38_000)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: today, calendar: calendar)
        XCTAssertEqual(b.balance, 198_000)
        XCTAssertEqual(b.fixedReserve(now: today, calendar: calendar), 37_000)
        XCTAssertEqual(b.available(now: today, calendar: calendar), 38_000)
        XCTAssertEqual(b.weeklySpent(now: today, calendar: calendar), 0)
        try b.undoPayment(recordID: b.recurringRecords[0].id)
        XCTAssertEqual(b.balance, 218_000)
        XCTAssertEqual(b.available(now: today, calendar: calendar), 38_000)
    }
    func testFutureAnnualCostOnlyReservesInDueMonth() throws {
        var b = Budget.demo()
        try b.savePayment(.init(name: "Jahresgebühr", cents: 12_000, kind: .fixedCost, cadence: .yearly, firstDue: date(2026, 12, 5)))
        XCTAssertEqual(b.monthlyFixedEquivalent, 1000)
        XCTAssertEqual(b.fixedReserve(now: date(2026, 10, 19), calendar: calendar), 37_000)
        XCTAssertEqual(b.fixedReserve(now: date(2026, 12, 1), calendar: calendar), 49_000)
        XCTAssertEqual(b.fixedReserve(now: date(2027, 1, 1), calendar: calendar), 49_000)
    }
    func testMultipleOverdueOccurrencesAreReserved() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Internet", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: date(2026, 8, 20))
        try b.savePayment(p)
        XCTAssertEqual(b.fixedReserve(now: date(2026, 10, 19), calendar: calendar), 40_000)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(2026, 10, 19), calendar: calendar)
        XCTAssertEqual(b.fixedReserve(now: date(2026, 10, 19), calendar: calendar), 39_000)
    }
    func testV1MigrationKeepsExistingMoneyAndHistory() throws {
        var original = Budget.demo()
        try original.addExpense(cents: 1234, title: "Einkauf", category: "Lebensmittel")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["schema"] = 1; json.removeValue(forKey: "payments"); json.removeValue(forKey: "recurringRecords")
        let migrated = try JSONDecoder().decode(Budget.self, from: JSONSerialization.data(withJSONObject: json)).validated()
        XCTAssertEqual(migrated.balance, original.balance)
        XCTAssertEqual(migrated.pots, original.pots)
        XCTAssertEqual(migrated.expenses, original.expenses)
        XCTAssertEqual(migrated.fixedCosts, original.fixedCosts)
        XCTAssertEqual(migrated.payments, [])
        XCTAssertEqual(migrated.schema, 2)
        XCTAssertEqual(try JSONDecoder().decode(Budget.self, from: JSONEncoder().encode(migrated)), migrated)
    }
    func testV2MissingFieldsAndInvalidSchedulesAreRejected() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Budget.demo())) as? [String: Any])
        json.removeValue(forKey: "payments")
        XCTAssertThrowsError(try JSONDecoder().decode(Budget.self, from: JSONSerialization.data(withJSONObject: json)))
        var b = Budget.demo()
        XCTAssertThrowsError(try b.savePayment(.init(name: "Gehalt", cents: 1000, kind: .income, cadence: .yearly, firstDue: date(2026, 10, 1))))
        XCTAssertThrowsError(try b.savePayment(.init(name: "", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: date(2026, 10, 1))))
    }
    func testEditingPreservesHistoryAndInvalidatesStaleBooking() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Gehalt", cents: 1000, kind: .income, cadence: .monthly, firstDue: date(2026, 10, 1))
        try b.savePayment(p)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(2026, 10, 19), calendar: calendar)
        let balance = b.balance
        let edited = RecurringPayment(name: "Neues Gehalt", cents: 2000, kind: .income, cadence: .monthly, firstDue: date(2026, 11, 1))
        try b.replacePayment(id: p.id, with: edited)
        XCTAssertEqual(b.balance, balance)
        XCTAssertEqual(b.recurringRecords.count, 1)
        XCTAssertThrowsError(try b.bookPayment(id: p.id, expectedOccurrence: 1, now: date(2026, 12, 1), calendar: calendar))
        XCTAssertThrowsError(try b.undoPayment(recordID: b.recurringRecords[0].id))
    }
}
