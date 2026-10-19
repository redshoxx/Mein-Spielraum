import XCTest
@testable import SpielraumCore
final class EditingTests: XCTestCase {
    func testAmountCorrectionAppliesOnlyDifferenceAndKeepsIdentityDate() throws {
        var b = Budget.demo(); let initial = b.balance
        try b.addExpense(cents: 1000, title: "Alt", category: "Freizeit")
        let old = b.expenses[0]
        try b.updateExpense(id: old.id, cents: 1500, title: "Neu", category: "Mobilität", merchant: "Shop", purpose: .necessary, expected: old)
        XCTAssertEqual(b.balance, initial - 1500); XCTAssertEqual(b.expenses.count, 1)
        XCTAssertEqual(b.expenses[0].id, old.id); XCTAssertEqual(b.expenses[0].date, old.date)
        XCTAssertEqual(b.expenses[0].title, "Neu")
        try b.updateExpense(id: old.id, cents: 500, title: "Neu", category: "Mobilität", merchant: nil, purpose: nil)
        XCTAssertEqual(b.balance, initial - 500)
        b.undoExpense(id: old.id); XCTAssertEqual(b.balance, initial)
    }
    func testInvalidOrStaleCorrectionsDoNotChangeMoney() throws {
        var b = Budget.demo(); try b.addExpense(cents: 100, title: "Alt", category: "Freizeit")
        let old = b.expenses[0]
        b.labelExpense(id: old.id, purpose: .necessary); let before = b
        XCTAssertThrowsError(try b.updateExpense(id: old.id, cents: 200, title: "", category: "", merchant: nil, purpose: nil, expected: old))
        XCTAssertThrowsError(try b.updateExpense(id: old.id, cents: 0, title: "", category: "", merchant: nil, purpose: nil))
        XCTAssertThrowsError(try b.updateExpense(id: old.id, cents: b.balance + 101, title: "", category: "", merchant: nil, purpose: nil))
        XCTAssertThrowsError(try b.updateExpense(id: UUID(), cents: 100, title: "", category: "", merchant: nil, purpose: nil))
        XCTAssertEqual(b, before)
    }
    func testEmergencyCorrectionUpdatesBothAccountAndPotAndUndo() throws {
        var b = Budget.demo(); b.assistant.emergencyPotID = b.pots[1].id
        let initial = b
        try b.emergencyExpense(cents: 1000, title: "Reparatur")
        let id = b.expenses[0].id
        try b.updateExpense(id: id, cents: 3000, title: "Reparatur", category: "Notfall", merchant: "Werkstatt", purpose: .necessary)
        XCTAssertEqual(b.balance, initial.balance - 3000)
        XCTAssertEqual(b.pots[1].cents, initial.pots[1].cents - 3000)
        XCTAssertEqual(b.expenses[0].purpose, .emergency)
        XCTAssertEqual(b.available, initial.available)
        XCTAssertEqual(b.weeklySpent(), 0)
        b.undoExpense(id: id)
        XCTAssertEqual(b.balance, initial.balance); XCTAssertEqual(b.pots, initial.pots)
    }
    func testDeletedEmergencyPotAllowsRefundButNotFurtherWithdrawal() throws {
        var b = Budget.demo(); b.assistant.emergencyPotID = b.pots[1].id
        try b.emergencyExpense(cents: 1000, title: "Reparatur")
        let id = b.expenses[0].id; try b.deletePot(id: b.pots[1].id)
        let before = b
        XCTAssertThrowsError(try b.updateExpense(id: id, cents: 1001, title: "", category: "Notfall", merchant: nil, purpose: nil))
        XCTAssertEqual(b, before)
        try b.updateExpense(id: id, cents: 500, title: "", category: "Notfall", merchant: nil, purpose: nil)
        XCTAssertEqual(b.balance, before.balance + 500); XCTAssertEqual(b.reserved, before.reserved)
    }
    func testMalformedImportedDatesAreRejected() throws {
        var b = Budget.demo()
        b.expenses = [.init(title: "Bad", cents: 100, category: "Test", date: Date(timeIntervalSince1970: 1e100))]
        XCTAssertThrowsError(try b.validated())
        b.expenses = []; b.assistant.nextPayday = Date(timeIntervalSince1970: 1e100)
        XCTAssertThrowsError(try b.validated())
    }

}
