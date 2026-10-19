import Foundation
import SwiftUI

@MainActor final class BudgetStore: ObservableObject {
    @Published private(set) var budget = Budget()
    @Published var error: String?
    @Published private(set) var loadFailed = false
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var recovery: BudgetRecovery?
    @Published private(set) var lastSaved: Date?
    private var loadingInFlight = false
    private let disk: BudgetDiskStore
    private var cachedAssessment: (minute: Int, zone: String, value: BudgetAssessment)?
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        disk = BudgetDiskStore(folder: folder)
        load()
    }
    func load() {
        guard !loadingInFlight, isLoading || loadFailed else { return }
        loadingInFlight = true; isLoading = true
        let disk = self.disk
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Budget?, BudgetRecovery?, String?) in
                do { return (try disk.load(), nil, nil) }
                catch { return (nil, disk.latestRecovery(), error.localizedDescription) }
            }.value
            if let failure = result.2 {
                loadFailed = true; recovery = result.1
                error = "Deine Daten konnten nicht geladen werden und werden nicht überschrieben. \(failure)"
            } else {
                if let loaded = result.0 { budget = loaded }
                loadFailed = false; recovery = nil; error = nil; cachedAssessment = nil
            }
            loadingInFlight = false; isLoading = false
        }
    }
    @discardableResult func change(_ operation: (inout Budget) throws -> Void) -> Bool {
        guard !isLoading, !isSaving, !loadFailed else { error = "Bitte zuerst die Daten laden oder eine Sicherung wiederherstellen."; return false }
        do {
            var next = budget
            try operation(&next)
            guard next != budget else { return true }
            try disk.save(next)
            cachedAssessment = nil; lastSaved = Date(); budget = next
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func saveChange(_ operation: (inout Budget) throws -> Void) async -> Bool {
        guard !isLoading, !isSaving, !loadFailed else { error = "Bitte warten, bis Laden oder Speichern abgeschlossen ist."; return false }
        do {
            var next = budget
            try operation(&next)
            if next == budget { return true }
            isSaving = true
            defer { isSaving = false }
            let snapshot = next
            let disk = self.disk
            let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, Error> in
                Result { try disk.save(snapshot) }
            }.value
            try result.get()
            cachedAssessment = nil; lastSaved = Date(); budget = next
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func restoreRecovery() {
        guard !isLoading, let recovery else { return }
        isLoading = true
        let disk = self.disk
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<Budget, Error> in
                Result { try disk.restore(recovery) }
            }.value
            switch result {
            case .success(let loaded):
                cachedAssessment = nil; budget = loaded; self.recovery = nil; loadFailed = false; error = nil; lastSaved = Date()
            case .failure(let failure): error = "Wiederherstellung fehlgeschlagen. \(failure.localizedDescription)"
            }
            isLoading = false
        }
    }
    func restoreImported(_ imported: Budget) {
        guard !isLoading, loadFailed else { return }
        isLoading = true
        let disk = self.disk
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<Budget, Error> in
                Result { try disk.replaceWithBackup(imported); return imported }
            }.value
            switch result {
            case .success(let loaded):
                cachedAssessment = nil; budget = loaded; recovery = nil; loadFailed = false; error = nil; lastSaved = Date()
            case .failure(let failure): error = "Backup konnte nicht wiederhergestellt werden. \(failure.localizedDescription)"
            }
            isLoading = false
        }
    }
    func assessment(now: Date = Date()) -> BudgetAssessment {
        let minute = Int(now.timeIntervalSince1970 / 60)
        let zone = TimeZone.current.identifier
        if let cachedAssessment, cachedAssessment.minute == minute, cachedAssessment.zone == zone { return cachedAssessment.value }
        let value = budget.assessment(now: now)
        cachedAssessment = (minute, zone, value)
        return value
    }
    func exportURL() throws -> URL {
        guard !isLoading, !loadFailed else { throw BudgetStorageError.loadRequired }
        let filename = "Mein-Spielraum-Backup-\(UUID().uuidString.prefix(8)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try JSONEncoder().encode(budget).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
