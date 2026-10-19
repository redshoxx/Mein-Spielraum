import XCTest
@testable import SpielraumCore
final class UpcomingPaymentTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: d))! }
    func testSortedFixedBillsIncludeOverdueButExcludeIncomeAndCompleted() throws {
        var b = Budget.demo()
        let late = RecurringPayment(name: "Später", cents: 5000, kind: .fixedCost, cadence: .yearly, firstDue: day(28))
        let overdue = RecurringPayment(name: "Überfällig", cents: 2000, kind: .fixedCost, cadence: .monthly, firstDue: day(15), endDate: day(15))
        var finished = RecurringPayment(name: "Abgeschlossen", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(1), endDate: day(1)); finished.completed = 1
        for p in [late, overdue, finished, .init(name: "Gehalt", cents: 100000, kind: .income, cadence: .monthly, firstDue: day(20))] { try b.savePayment(p) }
        let list = b.upcomingFixedPayments(now: day(19), calendar: calendar)
        XCTAssertEqual(list.map { $0.payment.name }, ["Überfällig", "Später"])
        XCTAssertEqual(list.map(\.daysUntilDue), [-4, 9])
        XCTAssertEqual(list[0].timingLabel, "4 Tage überfällig")
    }
    func testRelativeDatesRespectCalendarDaysAndDaylightSaving() throws {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let now = c.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 23))!
        let tomorrow = c.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 1))!
        let afterDST = c.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 0))!
        var b = Budget.demo()
        try b.savePayment(.init(name: "Morgen", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: tomorrow))
        try b.savePayment(.init(name: "Danach", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: afterDST))
        let rows = b.upcomingFixedPayments(now: now, calendar: c)
        XCTAssertEqual(rows.map(\.daysUntilDue), [1, 2])
        XCTAssertEqual(rows[0].timingLabel, "Morgen fällig")
    }
    func testBookedPaymentShowsNextDateAndUndoRestoresOriginal() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Strom", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: day(19))
        try b.savePayment(p)
        XCTAssertEqual(b.upcomingFixedPayments(now: day(19), calendar: calendar)[0].timingLabel, "Heute fällig")
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: day(19), calendar: calendar)
        let next = b.upcomingFixedPayments(now: day(19), calendar: calendar)[0]
        XCTAssertEqual(calendar.component(.month, from: next.date), 11)
        try b.undoPayment(recordID: b.recurringRecords[0].id)
        XCTAssertEqual(b.upcomingFixedPayments(now: day(19), calendar: calendar)[0].date, day(19))
    }
}
