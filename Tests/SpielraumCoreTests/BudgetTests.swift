import XCTest
@testable import SpielraumCore
final class BudgetTests: XCTestCase {
    func testMoneyParsingWithoutFloatingPointRounding() throws {
        XCTAssertEqual(try Euro.parse("12,34"), 1234)
        XCTAssertEqual(try Euro.parse("0.01"), 1)
        XCTAssertEqual(try Euro.parse("12,3"), 1230)
        XCTAssertEqual(try Euro.parse("0", allowZero: true), 0)
        for bad in ["-1", "1,234", "1.000,00", "NaN", "1e2", "", "1000001"] { XCTAssertThrowsError(try Euro.parse(bad)) }
    }
    func testReserveDoesNotDoubleSubtractFromAccount() throws {
        var b = Budget.demo()
        XCTAssertEqual(b.available, 58_000)
        try b.allocate(cents: 1000, potID: b.pots[0].id)
        XCTAssertEqual(b.balance, 218_000)
        XCTAssertEqual(b.available, 57_000)
        try b.release(cents: 1000, potID: b.pots[0].id)
        XCTAssertEqual(b.available, 58_000)
    }
    func testExpenseUndoAndPersistenceRoundTrip() throws {
        var b = Budget.demo()
        try b.addExpense(cents: 4280, title: "Einkauf", category: "Lebensmittel")
        XCTAssertEqual(b.available, 53_720)
        let restored = try JSONDecoder().decode(Budget.self, from: JSONEncoder().encode(b)).validated()
        XCTAssertEqual(restored, b)
        b.undoExpense(id: b.expenses[0].id)
        XCTAssertEqual(b.available, 58_000)
    }
    func testNoFundsAndZeroAreRejectedWithoutMutation() {
        var b = Budget.demo(); let before = b
        XCTAssertThrowsError(try b.allocate(cents: 58_001, potID: b.pots[0].id))
        XCTAssertThrowsError(try b.addExpense(cents: 0, title: "", category: ""))
        XCTAssertThrowsError(try b.release(cents: 48_001, potID: b.pots[0].id))
        XCTAssertEqual(b, before)
    }
    func testWeekRollsOverWithoutResettingAccountOrHistory() throws {
        var b = Budget.demo()
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = Date(timeIntervalSince1970: 1_792_368_000) // fixed date; use calendar start below
        let start = calendar.dateInterval(of: .weekOfYear, for: monday)!.start
        try b.addExpense(cents: 1000, title: "", category: "Test", date: start)
        XCTAssertEqual(b.weeklySpent(now: start, calendar: calendar), 1000)
        let next = calendar.date(byAdding: .day, value: 7, to: start)!
        XCTAssertEqual(b.weeklySpent(now: next, calendar: calendar), 0)
        XCTAssertEqual(b.weeklyRemaining(now: next, calendar: calendar), 14_500)
        XCTAssertEqual(b.balance, 217_000)
        XCTAssertEqual(b.expenses.count, 1)
    }
}
