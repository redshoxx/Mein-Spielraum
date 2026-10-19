import Foundation

public enum BudgetStorageError: LocalizedError {
    case tooLarge, recoveryRequired, loadRequired
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "Die Datei ist zu groß. Bitte eine gültige Sicherung wählen."
        case .recoveryRequired: return "Der aktuelle Datenstand fehlt. Eine vorhandene Sicherung kann wiederhergestellt werden."
        case .loadRequired: return "Die vorhandenen Daten müssen zuerst erfolgreich geladen oder wiederhergestellt werden."
        }
    }
}
public struct BudgetRecovery: Equatable {
    public let budget: Budget
    public let date: Date
    public let filename: String
}
/// Serializes disk transactions and keeps two previous, validated snapshots.
/// Budget is published by the UI only after the atomic primary write succeeds.
public final class BudgetDiskStore: @unchecked Sendable {
    public static let maximumBytes = 32_000_000
    private let lock = NSLock()
    private let folder: URL
    private let manager = FileManager.default
    private var lastBudget: Budget?
    private var lastData: Data?
    private var previousData: Data?
    public init(folder: URL) { self.folder = folder }
    private var primary: URL { folder.appendingPathComponent("spielraum-v1.json") }
    private var previous: URL { folder.appendingPathComponent("spielraum-previous.json") }
    private var older: URL { folder.appendingPathComponent("spielraum-recovery.json") }
    private func read(_ url: URL) throws -> Data {
        let size = try manager.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        guard let size, size.intValue <= Self.maximumBytes else { throw BudgetStorageError.tooLarge }
        return try Data(contentsOf: url)
    }
    private func decode(_ data: Data) throws -> Budget {
        guard data.count <= Self.maximumBytes else { throw BudgetStorageError.tooLarge }
        return try JSONDecoder().decode(Budget.self, from: data).validated()
    }
    private func write(_ data: Data, to url: URL) throws {
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtection)
        #endif
        try data.write(to: url, options: options)
    }
    public func load() throws -> Budget? {
        lock.lock(); defer { lock.unlock() }
        guard manager.fileExists(atPath: primary.path) else {
            if manager.fileExists(atPath: previous.path) || manager.fileExists(atPath: older.path) { throw BudgetStorageError.recoveryRequired }
            lastBudget = nil; lastData = nil; previousData = nil
            return nil
        }
        let data = try read(primary)
        let budget = try decode(data)
        lastData = data; lastBudget = budget
        previousData = try? read(previous)
        if let data = previousData, (try? decode(data)) == nil { previousData = nil }
        return budget
    }
    public func latestRecovery() -> BudgetRecovery? {
        lock.lock(); defer { lock.unlock() }
        for url in [previous, older] {
            guard let data = try? read(url), let budget = try? decode(data) else { continue }
            let date = (try? manager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date ?? .distantPast
            return BudgetRecovery(budget: budget, date: date, filename: url.lastPathComponent)
        }
        return nil
    }
    public func save(_ budget: Budget) throws {
        lock.lock(); defer { lock.unlock() }
        _ = try budget.validated()
        let exists = [primary, previous, older].contains { manager.fileExists(atPath: $0.path) }
        guard lastData != nil || !exists else { throw BudgetStorageError.loadRequired }
        if lastBudget == budget { return }
        let data = try JSONEncoder().encode(budget)
        guard data.count <= Self.maximumBytes else { throw BudgetStorageError.tooLarge }
        if data == lastData { return }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        if let previousData { try write(previousData, to: older) }
        if let lastData { try write(lastData, to: previous) }
        try write(data, to: primary)
        previousData = lastData; lastData = data; lastBudget = budget
    }
    /// Recovery is explicit. Preserve the damaged primary before replacing anything.
    public func restore(_ recovery: BudgetRecovery) throws -> Budget {
        lock.lock(); defer { lock.unlock() }
        guard [previous.lastPathComponent, older.lastPathComponent].contains(recovery.filename) else { throw BudgetError.invalidBackup }
        let data = try read(folder.appendingPathComponent(recovery.filename))
        let budget = try decode(data)
        guard budget == recovery.budget else { throw BudgetError.alreadyBooked }
        try preservePrimary()
        try write(data, to: primary)
        lastData = data; lastBudget = budget
        previousData = data
        return budget
    }
    public func replaceWithBackup(_ budget: Budget) throws {
        lock.lock(); defer { lock.unlock() }
        _ = try budget.validated()
        let data = try JSONEncoder().encode(budget)
        guard data.count <= Self.maximumBytes else { throw BudgetStorageError.tooLarge }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try preservePrimary()
        try write(data, to: primary)
        lastData = data; lastBudget = budget; previousData = nil
    }
    private func preservePrimary() throws {
        guard manager.fileExists(atPath: primary.path) else { return }
        let preserved = folder.appendingPathComponent("spielraum-before-recovery-\(UUID().uuidString).json")
        try manager.copyItem(at: primary, to: preserved)
        #if os(iOS)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: preserved.path)
        #endif
    }

}
