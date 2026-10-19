import XCTest
@testable import SpielraumCore
final class AssistantTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ d: Int) -> Date { day(2026, 10, d) }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    private func configured() -> Budget {
        var b = Budget.demo()
        b.assistant.automatic = false
        b.assistant.configured = true
        b.assistant.essentialWeekly = 7000
        b.assistant.safetyBuffer = 5000
        b.assistant.extraSavings = 5000
        b.assistant.nextPayday = day(2026, 11, 1)
        return b
    }
    func testNoPlanOrExpiredPaydayNeverProducesPurchasePermission() {
        var manual = Budget.demo(); manual.assistant.automatic = false
        XCTAssertFalse(manual.assessment(now: day(19), calendar: calendar).ready)
        var b = configured(); b.assistant.nextPayday = day(19)
        XCTAssertFalse(b.assessment(now: day(19), calendar: calendar).ready)
        XCTAssertEqual(b.assessment(now: day(19), calendar: calendar).purchaseLimit, 0)
    }
    func testProtectionUsesActualFundsAndOriginalWeeklyLimit() throws {
        var b = configured()
        let originalLimit = b.weeklyLimit
        let a = b.assessment(now: day(19), calendar: calendar)
        XCTAssertTrue(a.ready)
        XCTAssertEqual(a.essentialReserve, 13_000)
        XCTAssertEqual(a.purchaseLimit, 7500) // original €145 weekly less €70 essentials
        try b.savePayment(.init(name: "Future income", cents: 200000, kind: .income, cadence: .monthly, firstDue: day(28)))
        XCTAssertEqual(b.assessment(now: day(19), calendar: calendar).purchaseLimit, a.purchaseLimit)
        XCTAssertEqual(b.weeklyLimit, originalLimit)
    }
    func testFixedCostsAcrossMonthBoundaryAreProtected() throws {
        var b = configured(); b.assistant.nextPayday = day(2026, 11, 5)
        try b.savePayment(.init(name: "Miete", cents: 50000, kind: .fixedCost, cadence: .monthly, firstDue: day(2026, 11, 2)))
        let a = b.assessment(now: day(19), calendar: calendar)
        XCTAssertEqual(a.fixedReserve, 87000)
        XCTAssertGreaterThan(a.shortfall, 0)
        XCTAssertEqual(a.purchaseLimit, 0)
    }
    func testFeedbackChangesBayesianEstimateWithoutChangingBudget() throws {
        var b = configured()
        for _ in 0..<4 { try b.addExpense(cents: 100, title: "Einkauf", category: "Freizeit", date: day(19), merchant: "Shop", purpose: .wish) }
        let before = try XCTUnwrap(b.necessityEstimate(merchant: " shop ", category: "Freizeit"))
        XCTAssertLessThan(before.probability, 0.3)
        let balance = b.balance; let limit = b.weeklyLimit
        for e in b.expenses { b.labelExpense(id: e.id, purpose: .necessary) }
        let after = try XCTUnwrap(b.necessityEstimate(merchant: "SHOP", category: "Freizeit"))
        XCTAssertGreaterThan(after.probability, 0.7)
        XCTAssertEqual(b.balance, balance); XCTAssertEqual(b.weeklyLimit, limit)
        XCTAssertEqual(b.necessityEstimate(merchant: "Unknown", category: "Freizeit"), nil)
    }
    func testLearnedEssentialsCanOnlyRaiseProtectionAndNeverRaiseWeeklyLimit() throws {
        var b = configured(); b.balance = Euro.limit
        for week in 0..<5 {
            for offset in 0..<2 {
                let date = calendar.date(byAdding: .day, value: -(week * 7 + offset + 8), to: day(19))!
                try b.addExpense(cents: 6000, title: "Notwendig", category: "Lebensmittel", date: date, purpose: .necessary)
            }
        }
        let a = b.assessment(now: day(19), calendar: calendar)
        XCTAssertGreaterThanOrEqual(a.learnedSamples, 8)
        XCTAssertGreaterThan(a.essentialWeekly, b.assistant.essentialWeekly)
        XCTAssertEqual(b.weeklyLimit, 14500)
        b.assistant.essentialWeekly = 50000
        XCTAssertGreaterThanOrEqual(b.assessment(now: day(19), calendar: calendar).essentialWeekly, 50000)
    }
    func testWishlistPauseAndReassessment() throws {
        var b = configured()
        let now = day(19)
        let w = PurchaseWish(name: "Kopfhörer", cents: 1000, merchant: "Shop", category: "Freizeit", createdAt: now)
        b.wishes = [w]
        let before = b
        XCTAssertThrowsError(try b.buyWish(id: w.id, now: now, calendar: calendar))
        XCTAssertEqual(b, before)
        try b.buyWish(id: w.id, now: now.addingTimeInterval(48 * 3600), calendar: calendar)
        XCTAssertEqual(b.wishes.count, 0)
        XCTAssertEqual(b.expenses.first?.purpose, .wish)
        XCTAssertEqual(b.expenses.first?.merchant, "Shop")
    }
    func testWishlistCannotBypassProtectedFundsEvenAfterPause() {
        var b = configured(); b.balance = 1000
        let w = PurchaseWish(name: "Wunsch", cents: 100, merchant: "", category: "Freizeit", createdAt: day(15))
        b.wishes = [w]; let before = b
        XCTAssertThrowsError(try b.buyWish(id: w.id, now: day(19), calendar: calendar))
        XCTAssertEqual(b, before)
    }
    func testEmergencyHasNoPauseAndUndoRestoresReserve() throws {
        var b = configured(); b.assistant.emergencyPotID = b.pots[1].id
        let available = b.available; let balance = b.balance; let pot = b.pots[1].cents
        try b.emergencyExpense(cents: 10000, title: "Reparatur", date: day(19))
        XCTAssertEqual(b.balance, balance - 10000)
        XCTAssertEqual(b.pots[1].cents, pot - 10000)
        XCTAssertEqual(b.available, available)
        XCTAssertEqual(b.expenses.first?.purpose, .emergency)
        XCTAssertEqual(b.weeklySpent(now: day(19), calendar: calendar), 0)
        b.undoExpense(id: b.expenses[0].id)
        XCTAssertEqual(b.balance, balance); XCTAssertEqual(b.pots[1].cents, pot)
    }
    func testEmergencyCannotUseOtherPotsOrInventFunds() {
        var b = configured(); b.assistant.emergencyPotID = b.pots[1].id
        let before = b
        XCTAssertThrowsError(try b.emergencyExpense(cents: b.pots[1].cents + 1, title: ""))
        XCTAssertEqual(b, before)
    }
    func testAllocatingPlannedSavingsDoesNotDoubleProtectAmount() throws {
        var b = configured()
        let before = b.assessment(now: day(19), calendar: calendar)
        try b.allocate(cents: 3000, potID: b.pots[0].id)
        XCTAssertEqual(b.assistant.extraSavings, 2000)
        XCTAssertEqual(b.assessment(now: day(19), calendar: calendar).purchaseLimit, before.purchaseLimit)
        XCTAssertEqual(b.reserveMovements.first?.cents, 3000)
    }
    func testV2MigrationAndNewStateRoundTrip() throws {
        var old = Budget.demo()
        try old.addExpense(cents: 100, title: "Alt", category: "Freizeit")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json["schema"] = 2; json.removeValue(forKey: "assistant"); json.removeValue(forKey: "wishes"); json.removeValue(forKey: "reserveMovements")
        var migrated = try JSONDecoder().decode(Budget.self, from: JSONSerialization.data(withJSONObject: json)).validated()
        XCTAssertEqual(migrated.balance, old.balance); XCTAssertEqual(migrated.expenses, old.expenses)
        XCTAssertFalse(migrated.assistant.configured)
        migrated.assistant = configured().assistant
        migrated.wishes = [.init(name: "Test", cents: 100, merchant: "Shop", category: "Freizeit")]
        let copy = try JSONDecoder().decode(Budget.self, from: JSONEncoder().encode(migrated)).validated()
        XCTAssertEqual(copy, migrated)
    }
    func testRemovingFeedbackStopsUsingThatTrainingExample() throws {
        var b = configured()
        for _ in 0..<3 { try b.addExpense(cents: 100, title: "Test", category: "Freizeit", merchant: "Shop", purpose: .wish) }
        XCTAssertNotNil(b.necessityEstimate(merchant: "Shop", category: "Freizeit"))
        let balance = b.balance
        b.labelExpense(id: b.expenses[0].id, purpose: nil)
        XCTAssertNil(b.expenses[0].purpose)
        XCTAssertNil(b.necessityEstimate(merchant: "Shop", category: "Freizeit"))
        XCTAssertEqual(b.balance, balance)
    }
}
