import XCTest
@testable import SpielraumCore
final class AutomaticAssistantTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ y: Int = 2026, _ m: Int = 10, _ d: Int = 19) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    func testAutomaticStartWithoutPlanProtectsEssentialsAndUsesExplicitFallback() {
        let b = Budget.demo(); let a = b.assessment(now: day(), calendar: calendar)
        XCTAssertTrue(a.ready); XCTAssertFalse(b.assistant.configured)
        XCTAssertEqual(a.days, 30); XCTAssertEqual(a.essentialWeekly, b.weeklyLimit)
        XCTAssertEqual(a.buffer, b.weeklyLimit); XCTAssertEqual(a.purchaseLimit, 0)
        XCTAssertTrue(a.explanation.contains("30 Tage"))
    }
    func testIncomeDateRollsForwardWithoutBookingOrCountingFutureMoney() throws {
        var b = Budget.demo()
        try b.savePayment(.init(name: "Gehalt", cents: 250000, kind: .income, cadence: .monthly, firstDue: day(2026, 9, 28)))
        let before = b
        let a = b.assessment(now: day(), calendar: calendar)
        XCTAssertEqual(a.days, 9)
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(a.payday)), 28)
        XCTAssertEqual(b, before)
        b.payments[0].cents = 900000
        XCTAssertEqual(b.assessment(now: day(), calendar: calendar).purchaseLimit, a.purchaseLimit)
    }
    func testAutomaticLearningNeedsNoLabelsAndIgnoresFutureEntries() throws {
        var b = Budget(); b.balance = Euro.limit
        for offset in 1...35 {
            let date = calendar.date(byAdding: .day, value: -offset, to: day())!
            try b.addExpense(cents: 500, title: "Alltag", category: "Sonstiges", date: date)
        }
        let before = b.assessment(now: day(), calendar: calendar)
        XCTAssertGreaterThanOrEqual(before.learnedSamples, 8)
        XCTAssertEqual(before.essentialWeekly, 3500)
        try b.addExpense(cents: 100000, title: "Zukunft", category: "Sonstiges", date: day(2026, 12, 1))
        XCTAssertEqual(b.assessment(now: day(), calendar: calendar).essentialWeekly, before.essentialWeekly)
        XCTAssertEqual(b.weeklyLimit, 14500)
    }
    func testOptionalMinimumsAndFixedCostsCannotBeLearnedAway() throws {
        var b = Budget.demo(); b.assistant.essentialWeekly = 20000; b.assistant.safetyBuffer = 30000
        b.assistant.nextPayday = day(2020, 1, 1) // An old manual date must not stop automatic mode.
        try b.savePayment(.init(name: "Miete", cents: 50000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 11, 2)))
        let a = b.assessment(now: day(), calendar: calendar)
        XCTAssertTrue(a.ready); XCTAssertEqual(a.fixedReserve, 87000)
        XCTAssertGreaterThanOrEqual(a.essentialWeekly, 20000)
        XCTAssertEqual(a.buffer, 30000); XCTAssertEqual(a.purchaseLimit, 0)
    }
    func testExpiredIncomeDoesNotInventAnotherPaymentAfterEndDate() throws {
        var b = Budget.demo()
        try b.savePayment(.init(name: "Alt", cents: 100000, kind: .income, cadence: .monthly, firstDue: day(2026, 9, 1), endDate: day(2026, 9, 1)))
        XCTAssertEqual(b.assessment(now: day(), calendar: calendar).days, 30)
    }
    func testOlderBackupsDefaultToAutomaticAndExplicitManualChoiceRoundTrips() throws {
        var b = Budget.demo(); b.assistant.configured = true
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as? [String: Any])
        var settings = try XCTUnwrap(json["assistant"] as? [String: Any]); settings.removeValue(forKey: "automatic"); json["assistant"] = settings
        var restored = try JSONDecoder().decode(Budget.self, from: JSONSerialization.data(withJSONObject: json)).validated()
        XCTAssertTrue(restored.assistant.usesAutomatic)
        restored.assistant.automatic = false
        let copy = try JSONDecoder().decode(Budget.self, from: JSONEncoder().encode(restored)).validated()
        XCTAssertFalse(copy.assistant.usesAutomatic)
        XCTAssertEqual(restored, copy)
    }
}
