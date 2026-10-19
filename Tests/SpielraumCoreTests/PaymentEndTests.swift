import XCTest
@testable import SpielraumCore
final class PaymentEndTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }
    func testFinalPaymentIsIncludedAndNoLaterPaymentCanBeBooked() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Rate", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 10, 28), endDate: day(2026, 11, 28))
        try b.savePayment(p)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: day(2026, 10, 28), calendar: calendar)
        try b.bookPayment(id: p.id, expectedOccurrence: 1, now: day(2026, 11, 28), calendar: calendar)
        XCTAssertFalse(b.payments[0].hasPendingOccurrence(calendar: calendar))
        XCTAssertEqual(b.fixedReserve(now: day(2026, 12, 1), calendar: calendar), b.fixedCosts)
        let before = b
        XCTAssertThrowsError(try b.bookPayment(id: p.id, expectedOccurrence: 2, now: day(2026, 12, 28), calendar: calendar))
        XCTAssertEqual(b, before)
        try b.undoPayment(recordID: b.recurringRecords[0].id)
        XCTAssertTrue(b.payments[0].hasPendingOccurrence(calendar: calendar))
        XCTAssertEqual(b.fixedReserve(now: day(2026, 12, 1), calendar: calendar), b.fixedCosts + 1000)
    }
    func testOverdueFinalPaymentRemainsReservedButNoNewMonthsAppear() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Rate", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 10, 1), endDate: day(2026, 10, 1))
        try b.savePayment(p)
        XCTAssertEqual(b.fixedReserve(now: day(2027, 5, 1), calendar: calendar), b.fixedCosts + 1000)
        XCTAssertEqual(b.monthlyFixedEquivalent(now: day(2027, 5, 1), calendar: calendar), 0)
        XCTAssertTrue(p.isDue(now: day(2027, 5, 1), calendar: calendar))
    }
    func testQuarterlyAndYearlyEndBetweenRegularDates() {
        let q = RecurringPayment(name: "Quartal", cents: 3000, kind: .fixedCost, cadence: .quarterly, firstDue: day(2026, 1, 31), endDate: day(2026, 5, 10))
        XCTAssertEqual(q.outstandingThroughMonth(now: day(2027, 1, 1), calendar: calendar), 6000)
        let y = RecurringPayment(name: "Jahr", cents: 12000, kind: .fixedCost, cadence: .yearly, firstDue: day(2024, 2, 29), endDate: day(2025, 2, 28))
        XCTAssertEqual(y.outstandingThroughMonth(now: day(2028, 1, 1), calendar: calendar), 24000)
    }
    func testOldPaymentWithoutEndDateDecodesAsUnlimited() throws {
        let p = RecurringPayment(name: "Strom", cents: 5000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 10, 1))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
        json.removeValue(forKey: "endDate")
        let decoded = try JSONDecoder().decode(RecurringPayment.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.endDate)
        XCTAssertTrue(decoded.includesOccurrence(100, calendar: calendar))
    }
    func testInvalidEndDateRejectedAndEndDateRoundTrip() throws {
        let invalid = RecurringPayment(name: "Rate", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 10, 28), endDate: day(2026, 10, 27))
        XCTAssertThrowsError(try invalid.validated())
        let valid = RecurringPayment(name: "Rate", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 10, 28), endDate: day(2026, 10, 28))
        XCTAssertEqual(try JSONDecoder().decode(RecurringPayment.self, from: JSONEncoder().encode(valid)).validated(), valid)
    }
}
