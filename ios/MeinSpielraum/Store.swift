import Foundation
import SwiftUI

@MainActor final class BudgetStore: ObservableObject {
    @Published private(set) var budget = Budget()
    @Published var error: String?
    @Published private(set) var loadFailed = false
    private let fileURL: URL
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("spielraum-v1.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do { budget = try JSONDecoder().decode(Budget.self, from: Data(contentsOf: fileURL)).validated() }
        catch { loadFailed = true; self.error = "Deine gespeicherten Daten konnten nicht geladen werden. Sie werden nicht überschrieben. Bitte starte die App erneut. Details: \(error.localizedDescription)" }
    }
    @discardableResult func change(_ operation: (inout Budget) throws -> Void) -> Bool {
        guard !loadFailed else { error = "Gespeicherte Daten sind gesperrt, weil sie nicht geladen werden konnten."; return false }
        do {
            var next = budget
            try operation(&next)
            _ = try next.validated()
            let data = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            budget = next
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func exportURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mein-Spielraum-Backup.json")
        try JSONEncoder().encode(budget).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}
