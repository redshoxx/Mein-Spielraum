import XCTest
@testable import SpielraumCore
final class StorageTests: XCTestCase {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func testFreshInstallAndRestartKeepLatestAndTwoPreviousStates() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url)
        XCTAssertNil(try disk.load())
        var b = Budget.demo(); let first = b
        try disk.save(b); b.balance += 100; let second = b
        try disk.save(b); b.balance += 100; try disk.save(b)
        XCTAssertEqual(try BudgetDiskStore(folder: url).load(), b)
        XCTAssertEqual(disk.latestRecovery()?.budget, second)
        let oldest = try JSONDecoder().decode(Budget.self, from: Data(contentsOf: url.appendingPathComponent("spielraum-recovery.json")))
        XCTAssertEqual(oldest, first)
    }
    func testCorruptPrimaryIsNotOverwrittenAndRecoveryPreservesIt() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url)
        var b = Budget.demo(); try disk.save(b); let before = b
        b.balance += 100; try disk.save(b)
        let broken = Data("damaged-data".utf8); let primary = url.appendingPathComponent("spielraum-v1.json")
        try broken.write(to: primary)
        let restarted = BudgetDiskStore(folder: url)
        XCTAssertThrowsError(try restarted.load())
        XCTAssertThrowsError(try restarted.save(Budget()))
        XCTAssertEqual(try Data(contentsOf: primary), broken)
        let recovery = try XCTUnwrap(restarted.latestRecovery())
        XCTAssertEqual(try restarted.restore(recovery), before)
        XCTAssertEqual(try restarted.load(), before)
        let preserved = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("spielraum-before-recovery-") }
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try Data(contentsOf: preserved[0]), broken)
    }
    func testCorruptNewestRecoveryFallsBackToOlderAndMissingPrimaryNeedsConfirmation() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url)
        var b = Budget.demo(); let first = b
        try disk.save(b); b.balance += 100; try disk.save(b); b.balance += 100; try disk.save(b)
        try Data("bad".utf8).write(to: url.appendingPathComponent("spielraum-previous.json"))
        try FileManager.default.removeItem(at: url.appendingPathComponent("spielraum-v1.json"))
        let restarted = BudgetDiskStore(folder: url)
        XCTAssertThrowsError(try restarted.load())
        let recovery = try XCTUnwrap(restarted.latestRecovery())
        XCTAssertEqual(recovery.budget, first)
        XCTAssertEqual(try restarted.restore(recovery), first)
    }
    func testInvalidSaveAndUnavailableDiskDoNotReplaceGoodData() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url); let good = Budget.demo()
        try disk.save(good)
        var invalid = good; invalid.balance = -1
        XCTAssertThrowsError(try disk.save(invalid))
        XCTAssertEqual(try BudgetDiskStore(folder: url).load(), good)
        let blocker = url.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: blocker)
        let unavailable = BudgetDiskStore(folder: blocker)
        XCTAssertThrowsError(try unavailable.save(good))
        XCTAssertEqual(try Data(contentsOf: blocker), Data("file".utf8))
    }
    func testExplicitExternalBackupCanRecoverUnreadablePrimary() throws {
        let url = try folder(); let primary = url.appendingPathComponent("spielraum-v1.json")
        try Data("broken".utf8).write(to: primary)
        let disk = BudgetDiskStore(folder: url)
        XCTAssertThrowsError(try disk.load())
        let imported = Budget.demo()
        try disk.replaceWithBackup(imported)
        XCTAssertEqual(try disk.load(), imported)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).contains { $0.hasPrefix("spielraum-before-recovery-") })
    }
    func testNoOpSaveDoesNotDiscardUsefulRecovery() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url)
        var b = Budget.demo(); let original = b
        try disk.save(b); b.balance += 100; try disk.save(b)
        try disk.save(b)
        XCTAssertEqual(disk.latestRecovery()?.budget, original)
    }
    func testOversizedPrimaryIsRejectedBeforeReadingAndRecoveryRemainsValid() throws {
        let url = try folder(); let disk = BudgetDiskStore(folder: url)
        var b = Budget.demo(); let first = b
        try disk.save(b); b.balance += 100; try disk.save(b)
        let handle = try FileHandle(forWritingTo: url.appendingPathComponent("spielraum-v1.json"))
        try handle.truncate(atOffset: UInt64(BudgetDiskStore.maximumBytes + 1)); try handle.close()
        let restarted = BudgetDiskStore(folder: url)
        XCTAssertThrowsError(try restarted.load())
        XCTAssertEqual(restarted.latestRecovery()?.budget, first)
    }

}
