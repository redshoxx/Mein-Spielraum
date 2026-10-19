import XCTest
@testable import SpielraumCore

final class PotEditingTests: XCTestCase {
    func testEditingPreservesMoneyIdentityAndEmergencyAssignment() throws {
        var b = Budget.demo()
        let id = b.pots[0].id
        b.assistant.emergencyPotID = id
        let before = b
        try b.updatePot(id: id, name: "  Meine Reserve  ", target: 1000)
        XCTAssertEqual(b.pots[0].name, "Meine Reserve")
        XCTAssertEqual(b.pots[0].target, 1000) // A fulfilled goal is allowed.
        XCTAssertEqual(b.pots[0].id, id)
        XCTAssertEqual(b.pots[0].cents, before.pots[0].cents)
        XCTAssertEqual(b.balance, before.balance)
        XCTAssertEqual(b.available, before.available)
        XCTAssertEqual(b.assistant.emergencyPotID, id)
        XCTAssertEqual(try JSONDecoder().decode(Budget.self, from: JSONEncoder().encode(b)).validated(), b)
    }
    func testInvalidEditsLeaveBudgetUnchanged() {
        var b = Budget.demo(); let before = b; let id = b.pots[0].id
        for name in [" \n ", String(repeating: "a", count: 41)] {
            XCTAssertThrowsError(try b.updatePot(id: id, name: name, target: 1000))
        }
        for target in [0, -1, Euro.limit + 1] {
            XCTAssertThrowsError(try b.updatePot(id: id, name: "Valid", target: target))
        }
        XCTAssertThrowsError(try b.updatePot(id: UUID(), name: "Valid", target: 1000))
        XCTAssertThrowsError(try b.deletePot(id: UUID()))
        XCTAssertEqual(b, before)
    }
    func testDeletionFreesReserveAndClearsOnlySelectedEmergencyPot() throws {
        var b = Budget.demo(); let before = b
        b.assistant.emergencyPotID = b.pots[1].id
        try b.deletePot(id: b.pots[0].id)
        XCTAssertEqual(b.balance, before.balance)
        XCTAssertEqual(b.available, before.available + 48000)
        XCTAssertEqual(b.assistant.emergencyPotID, before.pots[1].id)
        XCTAssertEqual(b.reserveMovements.first?.cents, -48000)
        try b.deletePot(id: b.pots[0].id)
        XCTAssertNil(b.assistant.emergencyPotID)
        XCTAssertTrue(b.pots.isEmpty)
        XCTAssertEqual(b.balance, before.balance)
        _ = try b.validated()
    }
    func testDeletedEmergencyPotDoesNotChangeSpendingHistoryOrUndo() throws {
        var b = Budget.demo(); let initialBalance = b.balance
        b.assistant.emergencyPotID = b.pots[1].id
        try b.emergencyExpense(cents: 10000, title: "Reparatur")
        let expense = b.expenses[0]
        try b.deletePot(id: b.pots[1].id)
        XCTAssertEqual(b.weeklySpent(), 0)
        XCTAssertEqual(b.expenses[0].fundingPotID, expense.fundingPotID)
        let remainingReserve = b.reserved
        b.undoExpense(id: expense.id)
        XCTAssertEqual(b.balance, initialBalance)
        XCTAssertEqual(b.reserved, remainingReserve)
        XCTAssertTrue(b.expenses.isEmpty)
        _ = try b.validated()
    }
    func testEmptyPotDeletionCreatesNoMoneyMovement() throws {
        var b = Budget(); let balance = b.balance
        try b.deletePot(id: b.pots[0].id)
        XCTAssertEqual(b.balance, balance)
        XCTAssertEqual(b.reserved, 0)
        XCTAssertTrue(b.reserveMovements.isEmpty)
    }
}
