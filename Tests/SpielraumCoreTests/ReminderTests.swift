import XCTest
@testable import SpielraumCore
final class ReminderTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Vienna")!; return c }
    private func date(_ day: Int, hour: Int = 12) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! }
    func testBillRemindersAreFutureGenericAndStable() throws {
        var b = Budget.demo()
        try b.savePayment(.init(name: "PRIVATE Miete", cents: 12345, kind: .fixedCost, cadence: .monthly, firstDue: date(23)))
        let reminders = b.reminders(now: date(19), calendar: calendar)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.map { calendar.component(.day, from: $0.date) }, [22, 23])
        XCTAssertTrue(reminders.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
        XCTAssertEqual(reminders, b.reminders(now: date(19), calendar: calendar))
        XCTAssertFalse(reminders.contains { $0.body.contains("PRIVATE") || $0.body.contains("12345") })
    }
    func testPaidRemovedAndEndedBillsDoNotLeaveReminders() throws {
        var b = Budget.demo()
        let p = RecurringPayment(name: "Letzte Rate", cents: 1000, kind: .fixedCost, cadence: .monthly, firstDue: date(19), endDate: date(19))
        try b.savePayment(p)
        XCTAssertEqual(b.reminders(now: date(18, hour: 8), calendar: calendar).count, 2)
        try b.bookPayment(id: p.id, expectedOccurrence: 0, now: date(19), calendar: calendar)
        XCTAssertTrue(b.reminders(now: date(19), calendar: calendar).isEmpty)
        b.payments.removeAll()
        XCTAssertTrue(b.reminders(now: date(18), calendar: calendar).isEmpty)
    }
    func testOverdueIsOneDigestAndIncomeDoesNotBecomeBill() throws {
        var b = Budget.demo()
        for d in [2, 5, 6] { try b.savePayment(.init(name: "Alt", cents: 100, kind: .fixedCost, cadence: .monthly, firstDue: date(d))) }
        try b.savePayment(.init(name: "Gehalt", cents: 100, kind: .income, cadence: .monthly, firstDue: date(25)))
        let reminders = b.reminders(now: date(19), calendar: calendar)
        XCTAssertEqual(reminders.count, 1); XCTAssertEqual(reminders[0].id, "overdue")
        XCTAssertEqual(calendar.component(.day, from: reminders[0].date), 20)
    }
    func testWishReadyUses48HoursAndDoesNotRealertOldWishes() {
        var b = Budget.demo()
        b.wishes = [.init(name: "Privater Wunsch", cents: 100, merchant: "Privat", category: "Freizeit", createdAt: date(18))]
        let reminders = b.reminders(now: date(19), calendar: calendar)
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders[0].date.timeIntervalSince(b.wishes[0].createdAt), 48 * 3600)
        XCTAssertEqual(reminders[0].route, "wish")
        XCTAssertFalse(reminders[0].body.contains("Privat"))
        XCTAssertTrue(b.reminders(now: date(21), calendar: calendar).isEmpty)
    }
    func testOptOutHorizonAndRequestCap() throws {
        var b = Budget.demo()
        for _ in 0..<70 { try b.savePayment(.init(name: "Termin", cents: 100, kind: .fixedCost, cadence: .monthly, firstDue: date(25))) }
        XCTAssertEqual(b.reminders(now: date(19), calendar: calendar).count, 58)
        XCTAssertTrue(b.reminders(now: date(19), calendar: calendar, paymentsEnabled: false, wishesEnabled: false).isEmpty)
        b.payments = [.init(name: "Später", cents: 100, kind: .fixedCost, cadence: .yearly, firstDue: calendar.date(byAdding: .day, value: 90, to: date(19))!)]
        XCTAssertTrue(b.reminders(now: date(19), calendar: calendar).isEmpty)
    }
    func testDaylightSavingKeepsLocalReminderAtNine() throws {
        var b = Budget.demo()
        try b.savePayment(.init(name: "Termin", cents: 100, kind: .fixedCost, cadence: .monthly, firstDue: date(26)))
        let reminders = b.reminders(now: date(24, hour: 8), calendar: calendar)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertTrue(reminders.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
        XCTAssertTrue(reminders.allSatisfy { $0.date > date(24, hour: 8) })
    }
}
