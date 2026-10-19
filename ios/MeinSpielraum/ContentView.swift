import SwiftUI
import UniformTypeIdentifiers
import UIKit

private let mint = Color(red: 0.39, green: 0.95, blue: 0.77)
private let canvas = Color(red: 0.063, green: 0.071, blue: 0.082)
private let secondary = Color(red: 0.68, green: 0.70, blue: 0.75)
private enum Page: String, CaseIterable { case overview = "Übersicht", household = "Haushalt", pots = "Spartöpfe"
    var icon: String { switch self { case .overview: return "house"; case .household: return "doc.text"; case .pots: return "cylinder.split.1x2" } }
}
private enum Editor: Identifiable { case expense, settings, pot(UUID), newPot
    var id: String { switch self { case .expense: return "expense"; case .settings: return "settings"; case .pot(let id): return id.uuidString; case .newPot: return "new" } }
}
struct ContentView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.scenePhase) private var phase
    @State private var page = Page.overview
    @State private var editor: Editor?
    @State private var now = Date()
    @State private var importBackup = false
    @State private var pendingImport: Budget?
    @State private var exported: URL?
    private var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }
    private var weekLabel: String {
        guard let range = calendar.dateInterval(of: .weekOfYear, for: now), let end = calendar.date(byAdding: .day, value: 6, to: range.start) else { return "Diese Woche" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_AT"); f.dateFormat = "d. MMM"
        return "\(f.string(from: range.start))–\(f.string(from: end))"
    }
    var body: some View {
        Group {
            if !store.budget.setupComplete && !store.loadFailed { welcome }
            else { main }
        }
        .background(canvas.ignoresSafeArea()).tint(mint)
        .sheet(item: $editor) { entry in EditorView(editor: entry).environmentObject(store).preferredColorScheme(.dark) }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: phase) { value in if value == .active { now = Date() } }
        .fileImporter(isPresented: $importBackup, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 5_000_000 else { throw BudgetError.invalidBackup }
                pendingImport = try JSONDecoder().decode(Budget.self, from: Data(contentsOf: url)).validated()
            } catch { store.error = "Backup konnte nicht geöffnet werden: \(error.localizedDescription)" }
        }
        .confirmationDialog("Aktuelle Daten durch das Backup ersetzen?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
            Button("Backup wiederherstellen", role: .destructive) { if let b = pendingImport { store.change { $0 = b } }; pendingImport = nil }
            Button("Abbrechen", role: .cancel) { pendingImport = nil }
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "chart.bar.xaxis").font(.system(size: 44)).foregroundStyle(mint)
            Text("Mein\nSpielraum").font(.system(size: 46, weight: .bold)).tracking(-1.5)
            Text("Dein Haushalt. Deine Ziele.\nMehr Überblick für dein Geld.").font(.title3).foregroundStyle(secondary)
            Text("Deine Einträge bleiben auf diesem iPhone. Du kannst sie als Backup exportieren.").font(.subheadline).foregroundStyle(secondary)
            Spacer()
            Button("Mit eigenen Zahlen starten") { editor = .settings }.buttonStyle(MintButton())
            Button("Mit Beispieldaten testen") { store.change { $0 = .demo() } }.frame(maxWidth: .infinity).padding(.vertical, 10)
            Text("Keine Bankanbindung · Keine Anmeldung").font(.caption).foregroundStyle(secondary).frame(maxWidth: .infinity)
        }.padding(24)
    }
    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(page == .overview ? "Mein Spielraum" : page.rawValue).font(.system(size: 29, weight: .bold)).tracking(-0.8)
                    Spacer(minLength: 0)
                    if page == .household { Button { editor = .settings } label: { Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Budget bearbeiten") }
                }.padding(.bottom, 14)
                if page == .overview { overview }
                else if page == .household { household }
                else { savings }
            }.padding(.horizontal, 22).padding(.top, 15).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(weekLabel, systemImage: "calendar").font(.subheadline).foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 12).padding(.vertical, 9).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15)))
            Text("Diese Woche verfügbar").font(.system(size: 21, weight: .semibold)).padding(.top, 25)
            Text(Euro.format(store.budget.weeklyRemaining(now: now, calendar: calendar))).font(.system(size: 65, weight: .bold)).tracking(-2).minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(store.budget.weeklyRemaining(now: now, calendar: calendar) < 0 ? Color.red : mint).padding(.top, 3).padding(.bottom, 20)
            Divider().overlay(Color.white.opacity(0.12))
            Text("Frei verfügbar").foregroundStyle(secondary).padding(.top, 20)
            Text(Euro.format(store.budget.available)).font(.system(size: 37, weight: .bold)).tracking(-1).padding(.top, 3)
            VStack(spacing: 13) {
                ledger("Kontostand", store.budget.balance)
                ledger("Kommende Fixkosten", -store.budget.fixedCosts)
                ledger("Sparreserve", -store.budget.reserved)
            }.padding(.top, 22).padding(.bottom, 15)
            Divider()
            HStack { Text("Frei verfügbar"); Spacer(); Text(Euro.format(store.budget.available)) }.font(.subheadline.weight(.semibold)).padding(.vertical, 14)
            Divider()
            Text("Spartöpfe").font(.system(size: 23, weight: .bold)).padding(.top, 23).padding(.bottom, 20)
            potRows
            Text("Wochenlimit: \(Euro.format(store.budget.weeklyLimit)). Maximal das frei verfügbare Geld.").font(.caption).foregroundStyle(secondary).padding(.top, 20)
        }
    }
    private func ledger(_ title: String, _ amount: Int) -> some View {
        HStack { Text(title).foregroundStyle(secondary); Spacer(); Text(Euro.format(amount)).monospacedDigit() }.font(.body)
    }
    private var potRows: some View {
        VStack(spacing: 24) {
            ForEach(store.budget.pots) { p in
                Button { editor = .pot(p.id) } label: {
                    VStack(spacing: 11) {
                        HStack { Text(p.name).fontWeight(.semibold).lineLimit(1); Spacer(); Text(Euro.format(p.cents)).fontWeight(.semibold) + Text(" / \(Euro.format(p.target))").foregroundColor(secondary) }.font(.subheadline)
                        ProgressView(value: min(Double(p.cents), Double(p.target)), total: Double(p.target)).tint(mint).scaleEffect(x: 1, y: 1.8, anchor: .center)
                    }.padding(.vertical, 3).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("\(p.name), \(Euro.format(p.cents)) von \(Euro.format(p.target)). Geld verwalten.")
            }
        }
    }
    private var household: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Dein Geld. Klar im Blick.").foregroundStyle(secondary)
            Text(Euro.format(store.budget.available)).font(.system(size: 48, weight: .bold)).foregroundStyle(mint)
            VStack(spacing: 14) { ledger("Kontostand", store.budget.balance); ledger("Kommende Fixkosten", store.budget.fixedCosts); ledger("Diese Woche ausgegeben", store.budget.weeklySpent(now: now, calendar: calendar)) }
            Text("Fixkosten sind eine aktuelle Reserve. Nach einer Abbuchung Kontostand und verbleibende Reserve unter Budget bearbeiten abgleichen.").font(.caption).foregroundStyle(secondary)
            Divider()
            Text("Ausgaben").font(.title2.bold())
            if store.budget.expenses.isEmpty { Text("Eine frische Woche. Erfasse deine erste Ausgabe.").foregroundStyle(secondary).padding(.vertical, 25) }
            ForEach(store.budget.expenses) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 5) { Text(e.title); Text("\(e.category) · \(e.date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(secondary) }
                    Spacer(); Text("−\(Euro.format(e.cents))").fontWeight(.semibold)
                    Menu { Button("Rückgängig machen", systemImage: "arrow.uturn.backward") { store.change { $0.undoExpense(id: e.id) } } } label: { Image(systemName: "ellipsis").frame(width: 38, height: 44) }.accessibilityLabel("Ausgabe verwalten")
                }
                Divider()
            }
            Text("Datensicherung").font(.headline).padding(.top, 10)
            Button("Backup erstellen", systemImage: "square.and.arrow.up") {
                do { exported = try store.exportURL() } catch { store.error = error.localizedDescription }
            }
            if let exported { ShareLink("Backup teilen oder in Dateien sichern", item: exported).font(.subheadline) }
            Button("Backup wiederherstellen", systemImage: "arrow.down.doc") { importBackup = true }
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0") · Daten nur auf deinem Gerät").font(.caption).foregroundStyle(secondary)
        }
    }
    private var savings: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Ein kleiner Beitrag heute.\nMehr Möglichkeiten morgen.").font(.title3).foregroundStyle(secondary)
            potRows
            Button("Spartopf hinzufügen", systemImage: "plus") { editor = .newPot }.padding(.vertical, 6)
            Divider()
            Text("\(Euro.format(store.budget.reserved)) reserviert").font(.title3.bold()).foregroundStyle(mint)
            Text("Das Geld bleibt auf deinem Konto. Es wird einmal vom frei verfügbaren Betrag abgezogen. Tippe auf einen Topf, um Geld zu reservieren oder wieder freizugeben.").foregroundStyle(secondary).font(.subheadline)
        }
    }
    private var footer: some View {
        VStack(spacing: 15) {
            Button("Ausgabe erfassen") { editor = .expense }.buttonStyle(MintButton())
            HStack {
                ForEach(Page.allCases, id: \.self) { p in
                    Button { page = p; now = Date() } label: {
                        VStack(spacing: 6) { Image(systemName: p.icon).font(.system(size: 23)); Text(p.rawValue).font(.caption) }.frame(maxWidth: .infinity).frame(minHeight: 48)
                    }.foregroundStyle(page == p ? mint : secondary).accessibilityAddTraits(page == p ? .isSelected : [])
                }
            }
        }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 4).background(canvas)
    }
}
private struct MintButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .bold)).foregroundStyle(Color.black.opacity(0.9)).frame(maxWidth: .infinity).padding(.vertical, 15).background(mint.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 5))
    }
}
private struct EditorView: View {
    let editor: Editor
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var category = "Lebensmittel"
    @State private var fixed = ""
    @State private var weekly = ""
    @State private var release = false
    @State private var validation: String?
    private var heading: String { switch editor { case .expense: return "Ausgabe erfassen"; case .settings: return "Budget bearbeiten"; case .newPot: return "Neuer Spartopf"; case .pot(let id): return store.budget.pots.first { $0.id == id }?.name ?? "Spartopf" } }
    var body: some View {
        NavigationStack {
            Form {
                if case .settings = editor {
                    Section("Aktuelle Beträge") {
                        field("Kontostand in €", text: $amount)
                        field("Kommende Fixkosten in €", text: $fixed)
                        field("Wochenlimit in €", text: $weekly)
                    }
                    Section { Text("Alle Spartöpfe sind Teil dieses Kontostands. Änderungen gleichen deinen aktuellen Stand ab. Es werden keine Einnahmen oder Abbuchungen automatisch gebucht.").foregroundStyle(secondary) }
                } else {
                    if case .pot = editor { Picker("Aktion", selection: $release) { Text("Reservieren").tag(false); Text("Freigeben").tag(true) }.pickerStyle(.segmented) }
                    Section { field(editorIsNewPot ? "Sparziel in €" : "Betrag in €", text: $amount) }
                    if case .expense = editor {
                        Section {
                            TextField("Bezeichnung (optional)", text: $title)
                            Picker("Kategorie", selection: $category) { ForEach(["Lebensmittel", "Freizeit", "Mobilität", "Wohnen", "Sonstiges"], id: \.self) { Text($0) } }
                        }
                        Text("Die Ausgabe reduziert deinen Kontostand. Fixkosten-Abbuchungen bitte anschließend auch aus der Reserve herausnehmen.").font(.caption).foregroundStyle(secondary)
                    }
                    if case .newPot = editor { TextField("Name des Spartopfs", text: $title) }
                    if case .pot = editor { Text("Frei verfügbar: \(Euro.format(store.budget.available)). Reservieren verschiebt kein Geld auf ein anderes Bankkonto.").font(.subheadline).foregroundStyle(secondary) }
                }
                if let validation { Text(validation).foregroundStyle(.red).accessibilityAddTraits(.isStaticText) }
                Button("Speichern") { save() }.fontWeight(.bold)
            }
            .navigationTitle(heading).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
            .onAppear { if case .settings = editor { amount = Euro.editable(store.budget.balance); fixed = Euro.editable(store.budget.fixedCosts); weekly = Euro.editable(store.budget.weeklyLimit) } }
        }.tint(mint)
    }
    private var editorIsNewPot: Bool { if case .newPot = editor { return true }; return false }
    private func field(_ label: String, text: Binding<String>) -> some View { TextField(label, text: text).keyboardType(.decimalPad).accessibilityLabel(label) }
    private func save() {
        do {
            let cents = try Euro.parse(amount, allowZero: { if case .settings = editor { return true }; return false }())
            switch editor {
            case .settings:
                let f = try Euro.parse(fixed, allowZero: true); let w = try Euro.parse(weekly)
                if store.change({ $0.balance = cents; $0.fixedCosts = f; $0.weeklyLimit = w; $0.setupComplete = true }) { dismiss() }
            case .expense:
                if store.change({ try $0.addExpense(cents: cents, title: String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)), category: category) }) { dismiss() }
            case .pot(let id):
                if store.change({ b in if release { try b.release(cents: cents, potID: id) } else { try b.allocate(cents: cents, potID: id) } }) { dismiss() }
            case .newPot:
                let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                guard !name.isEmpty else { validation = "Bitte einen Namen eingeben."; return }
                if store.change({ $0.pots.append(.init(name: name, target: cents)) }) { dismiss() }
            }
        } catch { validation = error.localizedDescription }
    }
}
