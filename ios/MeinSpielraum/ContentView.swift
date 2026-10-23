import SwiftUI
import UniformTypeIdentifiers
import UIKit
import Combine

private let mint = SpielraumTheme.mint
private let canvas = SpielraumTheme.canvas
private let secondary = SpielraumTheme.muted
private enum Page: String, CaseIterable { case overview = "Übersicht", household = "Haushalt", pots = "Spartöpfe"
    var icon: String { switch self { case .overview: return "house"; case .household: return "doc.text"; case .pots: return "cylinder.split.1x2" } }
}
private enum HouseholdArea: String, CaseIterable {
    case income = "Einnahmen", fixed = "Fixkosten", expenses = "Ausgaben", backup = "Datensicherung"
}
private enum Editor: Identifiable { case expense, settings, assistant, wishes, notifications, purchaseGuard, pot(UUID), editPot(UUID), editExpense(UUID), newPot, payment(PaymentKind, UUID?)
    var id: String { switch self { case .expense: return "expense"; case .settings: return "settings"; case .assistant: return "assistant"; case .wishes: return "wishes"; case .notifications: return "notifications"; case .purchaseGuard: return "purchaseGuard"; case .pot(let id): return id.uuidString; case .editPot(let id): return "edit-pot-\(id.uuidString)"; case .editExpense(let id): return "edit-expense-\(id.uuidString)"; case .newPot: return "new"; case .payment(let kind, let id): return "payment-\(kind.rawValue)-\(id?.uuidString ?? "new")" } }
}
struct ContentView: View {
    @EnvironmentObject private var store: BudgetStore
    @EnvironmentObject private var notifications: BudgetNotifications
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var deviceTextSize
    @State private var householdArea: HouseholdArea?
    @State private var page = Page.overview
    @State private var editor: Editor?
    @State private var now = Date()
    @State private var importBackup = false
    @State private var pendingImport: Budget?
    @State private var exported: URL?
    @State private var showAllUpcoming = false
    @State private var expenseCount = 30
    @State private var confirmRecovery = false
    @State private var isImporting = false
    @State private var pendingPurchaseGuard = false
    @State private var pendingPayment: RecurringPayment?
    @State private var removingPayment: RecurringPayment?
    private let dayTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }
    private var dashboardAnalysis: BudgetAssessment { store.assessment(now: now) }
    private var dashboardAmount: Int {
        (store.budget.assistant.usesAutomatic || store.budget.assistant.configured) ? dashboardAnalysis.purchaseLimit : store.budget.weeklyRemaining(now: now, calendar: calendar)
    }
    private var weekLabel: String {
        guard let range = calendar.dateInterval(of: .weekOfYear, for: now), let end = calendar.date(byAdding: .day, value: 6, to: range.start) else { return "Diese Woche" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_AT"); f.dateFormat = "d. MMM"
        return "\(f.string(from: range.start))–\(f.string(from: end))"
    }
    private var baseScreen: some View {
        Group {
            if store.isLoading { ProgressView("Daten werden sicher geladen …").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if store.loadFailed { recoveryView }
            else if !store.budget.setupComplete { welcome }
            else { main }
        }
        .background(canvas.ignoresSafeArea()).foregroundStyle(SpielraumTheme.text).tint(mint)
        .dynamicTypeSize(previewTextSize ?? deviceTextSize)
    }
    private var presentedScreen: some View {
        baseScreen
        .sheet(item: $editor) { entry in
            Group {
                switch entry {
                case .payment(let kind, let id): RecurringEditor(kind: kind, existingID: id)
                case .assistant: AssistantView()
                case .wishes: AssistantView(initialTab: 1)
                case .notifications: NotificationSettingsView().environmentObject(notifications)
                case .purchaseGuard: PurchaseGuardView()
                default: EditorView(editor: entry)
                }
            }.environmentObject(store).preferredColorScheme(.dark)
                .disabled(store.isSaving).interactiveDismissDisabled(store.isSaving)
                .overlay { if store.isSaving { ProgressView("Wird gespeichert …").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
        }
    }
    private var lifecycleScreen: some View {
        presentedScreen
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in if store.loadFailed { store.load() } }
        .onChange(of: store.isLoading) { if !store.isLoading && !store.loadFailed { notifications.refresh(budget: store.budget); processPendingRoute() } }
        .onChange(of: store.isSaving) { if !store.isSaving { processPendingRoute() } }
        .confirmationDialog("Gesicherten Stand wiederherstellen?", isPresented: $confirmRecovery, titleVisibility: .visible) {
            Button("Sicherung wiederherstellen") { store.restoreRecovery() }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Es wird der angezeigte frühere Stand geladen. Spätere Änderungen können darin fehlen. Die bisherige Speicherdatei wird zur Sicherheit aufbewahrt.") }
    }
    private var liveScreen: some View {
        lifecycleScreen
        .allowsHitTesting(!isImporting && !store.isSaving)
        .overlay { if isImporting { ProgressView("Backup wird geprüft …").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        .onReceive(dayTimer) { now = $0 }
        .onAppear { if !store.loadFailed && !store.isLoading { notifications.refresh(budget: store.budget) } }
        .onChange(of: store.budget) { if !store.loadFailed && !store.isLoading { notifications.refresh(budget: store.budget) } }
        .onOpenURL { url in
            if url.scheme?.lowercased() == "spielraum", url.host?.lowercased() == "kaufcheck" {
                pendingPurchaseGuard = true; processPendingRoute()
            }
        }
        .onReceive(notifications.$route.compactMap { $0 }) { _ in processPendingRoute() }
    }
    private var paymentScreen: some View {
        liveScreen
        .confirmationDialog("Termin buchen?", isPresented: Binding(get: { pendingPayment != nil }, set: { if !$0 { pendingPayment = nil } }), titleVisibility: .visible) {
            if let p = pendingPayment {
                Button(p.kind == .income ? "Als erhalten buchen" : "Als bezahlt buchen") {
                    store.change { try $0.bookPayment(id: p.id, expectedOccurrence: p.completed, now: now) }
                    pendingPayment = nil
                }
                Button("Abbrechen", role: .cancel) { pendingPayment = nil }
            }
        } message: {
            if let p = pendingPayment { Text("\(p.name) · \(Euro.format(p.cents)) · fällig \(p.nextDue().formatted(date: .abbreviated, time: .omitted)). Nur buchen, wenn die Zahlung noch nicht im eingetragenen Kontostand enthalten ist.") }
        }
        .confirmationDialog("Wiederkehrenden Posten entfernen?", isPresented: Binding(get: { removingPayment != nil }, set: { if !$0 { removingPayment = nil } }), titleVisibility: .visible) {
            if let p = removingPayment {
                Button("Entfernen", role: .destructive) { store.change { $0.payments.removeAll { $0.id == p.id } }; removingPayment = nil }
                Button("Abbrechen", role: .cancel) { removingPayment = nil }
            }
        } message: { Text("Bisherige Buchungen und dein Kontostand bleiben erhalten. Nur die künftigen Termine werden entfernt.") }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: phase) { _, value in if value == .active { now = Date(); if !store.loadFailed && !store.isLoading { notifications.refresh(budget: store.budget) } } }
    }
    var body: some View {
        paymentScreen
        .fileImporter(isPresented: $importBackup, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                isImporting = true
                Task {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() }; isImporting = false }
                    let decoded = await Task.detached(priority: .userInitiated) { () -> Result<Budget, Error> in
                        Result {
                            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                            guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= BudgetDiskStore.maximumBytes else { throw BudgetStorageError.tooLarge }
                            return try JSONDecoder().decode(Budget.self, from: Data(contentsOf: url)).validated()
                        }
                    }.value
                    do { pendingImport = try decoded.get() }
                    catch { store.error = "Backup konnte nicht geöffnet werden: \(error.localizedDescription)" }
                }
            } catch { store.error = error.localizedDescription }
        }
        .confirmationDialog("Aktuelle Daten durch das Backup ersetzen?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
            Button("Backup wiederherstellen", role: .destructive) { if let b = pendingImport { if store.loadFailed { store.restoreImported(b) } else { Task { await store.saveChange { $0 = b } } } }; pendingImport = nil }
            Button("Abbrechen", role: .cancel) { pendingImport = nil }
        }
    }
    private var largeText: Bool { (previewTextSize ?? deviceTextSize).isAccessibilitySize }
    private var previewTextSize: DynamicTypeSize? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--large-text") { return .accessibility2 }
        #endif
        return nil
    }
    private func processPendingRoute() {
        guard !store.isLoading, !store.isSaving, !store.loadFailed else { return }
        if pendingPurchaseGuard {
            pendingPurchaseGuard = false; notifications.route = nil; editor = .purchaseGuard
        } else if let route = notifications.route {
            notifications.route = nil
            if route == "payments" { editor = nil; householdArea = .fixed; page = .household }
            else { editor = route == "wish" ? .wishes : .purchaseGuard }
        }
    }
    private var recoveryView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle).foregroundStyle(SpielraumTheme.warning)
            Text("Deine Daten bleiben erhalten").font(.title.bold())
            Text("Die aktuelle Datei konnte nicht geladen werden. Es werden keine leeren Daten darüber gespeichert.").foregroundStyle(secondary)
            if let recovery = store.recovery {
                Text("Geprüfte Sicherung vom \(recovery.date.formatted(date: .abbreviated, time: .shortened))")
                Button("Diesen Stand wiederherstellen") { confirmRecovery = true }.buttonStyle(MintButton())
            }
            Button("Erneut laden") { store.load() }
            Button("Backup aus Dateien wählen") { importBackup = true }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
            Text("Keine Bankanbindung · Keine Anmeldung").font(.subheadline).foregroundStyle(secondary).frame(maxWidth: .infinity)
        }.padding(24)
    }
    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if page == .household {
                    Button {
                        if householdArea != nil { householdArea = nil }
                        else { page = .overview }
                        now = Date()
                    } label: { Label(householdArea == nil ? "Zur Übersicht" : "Zum Haushalt", systemImage: "chevron.left").font(.headline).frame(minHeight: 48) }
                    .accessibilityIdentifier("backToOverview")
                }
                if page == .overview {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text("Übersicht").font(.largeTitle.bold()); Spacer(); householdButton }
                        VStack(alignment: .leading, spacing: 14) { Text("Übersicht").font(.largeTitle.bold()); householdButton }
                    }
                } else {
                    Text(page == .household ? householdArea?.rawValue ?? "Haushalt" : "Spartöpfe").font(.largeTitle.bold())
                }
                if page == .overview { overview }
                else if page == .household { household }
                else { savings }
            }.padding(20)
        }.background(canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) { if page != .household { footer } }
    }
    private var householdButton: some View {
        Button { householdArea = nil; page = .household; now = Date() } label: {
            Label("Haushalt", systemImage: "gearshape").font(.body.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 50)
                .background(SpielraumTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        }.accessibilityIdentifier("openHousehold")
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Für Wünsche übrig").font(.title3.weight(.semibold))
                Text(Euro.format(dashboardAmount)).font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit().foregroundStyle(mint)
                    .accessibilityIdentifier("availableAmount")
                Text("Nach Alltag, Fixkosten und Sparen.").font(.body).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                if dashboardAnalysis.shortfall > 0 {
                    Label("Aktuell ist kein freier Kauf eingeplant.", systemImage: "exclamationmark.circle").font(.body.weight(.medium)).foregroundStyle(SpielraumTheme.warning)
                }
                DisclosureGroup("Berechnung ansehen") {
                    VStack(alignment: .leading, spacing: 14) {
                        ledger("Kontostand", store.budget.balance)
                        ledger("Spartöpfe", store.budget.reserved)
                        ledger("Offene Fixkosten", dashboardAnalysis.fixedReserve)
                        ledger("Alltag und Puffer", dashboardAnalysis.essentialReserve + dashboardAnalysis.buffer)
                        if dashboardAnalysis.extraSavings > 0 { ledger("Zusätzliches Sparziel", dashboardAnalysis.extraSavings) }
                        Text(dashboardAnalysis.explanation).font(.body).foregroundStyle(secondary)
                    }.padding(.top, 14)
                }.font(.body.weight(.medium))
            }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
            Button { editor = .wishes } label: {
                MenuRow(title: "Kann ich mir das leisten?", detail: "Preis eingeben und vor dem Kauf prüfen", icon: "cart")
            }.buttonStyle(.plain).budgetCard().accessibilityIdentifier("openPurchaseCheck")
            upcomingPayments.budgetCard()
            Button { page = .pots } label: {
                MenuRow(title: "Meine Spartöpfe", detail: "\(Euro.format(store.budget.reserved)) zurückgelegt", icon: "banknote")
            }.buttonStyle(.plain).budgetCard()
            Button { editor = .assistant } label: {
                MenuRow(title: "Budget-Assistent", detail: "Einschätzung, Sparen und Notfallreserve", icon: "chart.bar")
            }.buttonStyle(.plain).budgetCard().accessibilityIdentifier("openAssistant")
        }
    }
    private var upcomingPayments: some View {
        let items = store.budget.upcomingFixedPayments(now: now, calendar: calendar)
        let visible = showAllUpcoming ? items : Array(items.prefix(2))
        return VStack(alignment: .leading, spacing: 17) {
            Text("Nächste Fixkosten").font(.system(size: 23, weight: .bold))
            if items.isEmpty {
                Text("Keine offenen Zahlungstermine. Fixkosten legst du über das Zahnrad im Haushalt an.").font(.subheadline).foregroundStyle(secondary)
            } else {
                Text("Das steht als Nächstes an.").font(.body).foregroundStyle(secondary)
                ForEach(visible) { item in upcomingRow(item) }
                if items.count > 2 {
                    Button(showAllUpcoming ? "Weniger anzeigen" : "Alle \(items.count) anzeigen") { showAllUpcoming.toggle() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
                Button("Alle Fixkosten verwalten") { page = .household; householdArea = .fixed }.font(.body.weight(.semibold)).frame(minHeight: 48)
            }
        }.padding(.vertical, 23).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider() }
    }
    private func upcomingRow(_ item: UpcomingPayment) -> some View {
        let urgent = item.daysUntilDue <= 0
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: urgent ? "exclamationmark.circle" : "calendar").font(.system(size: 20)).foregroundStyle(urgent ? SpielraumTheme.warning : mint).frame(width: 25).padding(.top, 2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.payment.name).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(Euro.format(item.payment.cents)).fontWeight(.semibold).monospacedDigit().fixedSize()
                }
                Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())).font(.subheadline).foregroundStyle(secondary)
                Text(item.timingLabel).font(.body.weight(.semibold)).foregroundStyle(urgent ? SpielraumTheme.warning : mint)
            }
        }.padding(.vertical, 5).accessibilityElement(children: .combine)
    }
    private func ledger(_ title: String, _ amount: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(title).foregroundStyle(secondary); Spacer(minLength: 12)
                Text(Euro.format(amount)).fontWeight(.semibold).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) { Text(title).foregroundStyle(secondary); Text(Euro.format(amount)).fontWeight(.semibold).monospacedDigit() }
        }.font(.body).padding(.vertical, 3)
    }
    private var potRows: some View {
        VStack(spacing: 18) {
            ForEach(store.budget.pots) { pot in
                VStack(alignment: .leading, spacing: 18) {
                    Text(pot.name).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(Euro.format(pot.cents)).font(.title2.bold()).foregroundStyle(mint)
                    Text("Ziel: \(Euro.format(pot.target))").font(.body).foregroundStyle(secondary)
                    ProgressView(value: min(Double(pot.cents), Double(pot.target)), total: Double(pot.target)).tint(mint)
                        .accessibilityLabel("Sparfortschritt \(pot.name)")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { potActions(pot) }
                        VStack(spacing: 12) { potActions(pot) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
            }
        }
    }
    @ViewBuilder private func potActions(_ pot: SavingPot) -> some View {
        Button("Geld verwalten") { editor = .pot(pot.id) }.buttonStyle(PrimaryAction())
        Button("Bearbeiten") { editor = .editPot(pot.id) }.font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 54)
            .background(SpielraumTheme.soft, in: RoundedRectangle(cornerRadius: 12))
    }
    @ViewBuilder private var household: some View {
        if let area = householdArea {
            switch area {
            case .income: recurringSection(.income).budgetCard()
            case .fixed: recurringSection(.fixedCost).budgetCard()
            case .expenses: expenseHistory.budgetCard()
            case .backup: backupSection.budgetCard()
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                Text("Was möchtest du verwalten?").font(.title3).foregroundStyle(secondary)
                VStack(spacing: 0) {
                    householdLink(.income, detail: "\(Euro.format(store.budget.monthlyIncome)) pro Monat", icon: "arrow.down.circle")
                    Divider().padding(.vertical, 8)
                    householdLink(.fixed, detail: "Zahlungstermine und laufende Kosten", icon: "calendar")
                    Divider().padding(.vertical, 8)
                    householdLink(.expenses, detail: "Einträge ansehen und bearbeiten", icon: "list.bullet.rectangle")
                }.budgetCard()
                VStack(spacing: 0) {
                    Button { editor = .settings } label: { MenuRow(title: "Budget bearbeiten", detail: "Kontostand und Wochenlimit", icon: "slider.horizontal.3") }.buttonStyle(.plain).accessibilityIdentifier("editBudget")
                    Divider().padding(.vertical, 8)
                    Button { editor = .notifications } label: { MenuRow(title: "Benachrichtigungen", detail: "Erinnerungen ein- und ausschalten", icon: "bell") }.buttonStyle(.plain).accessibilityIdentifier("openNotifications")
                    Divider().padding(.vertical, 8)
                    householdLink(.backup, detail: "Backup erstellen oder zurückholen", icon: "externaldrive")
                }.budgetCard()
                DisclosureGroup("Monatliche Zusammenfassung") { monthlyPlan.padding(.top, 16) }.font(.body.weight(.medium)).budgetCard()
                Button { editor = .purchaseGuard } label: { MenuRow(title: "Kaufbremse einrichten", detail: "Hilfe für Shopping-Apps", icon: "hand.raised") }.buttonStyle(.plain).budgetCard()
            }
        }
    }
    private func householdLink(_ area: HouseholdArea, detail: String, icon: String) -> some View {
        Button { householdArea = area } label: { MenuRow(title: area.rawValue, detail: detail, icon: icon) }.buttonStyle(.plain).accessibilityIdentifier("household-\(area.rawValue)")
    }
    private var expenseHistory: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button("Neue Ausgabe") { editor = .expense }.buttonStyle(PrimaryAction())
            if store.budget.expenses.isEmpty { Text("Noch keine Ausgaben eingetragen.").foregroundStyle(secondary) }
            ForEach(Array(store.budget.expenses.prefix(expenseCount))) { expense in
                VStack(alignment: .leading, spacing: 12) {
                    Text(expense.title).font(.headline)
                    Text("\(expense.category) · \(expense.date.formatted(date: .abbreviated, time: .omitted))").font(.body).foregroundStyle(secondary)
                    Text("−\(Euro.format(expense.cents))").font(.title3.bold())
                    HStack(spacing: 20) {
                        Button("Bearbeiten") { editor = .editExpense(expense.id) }.frame(minHeight: 48)
                        Menu("Weitere Aktionen") { Button("Ausgabe rückgängig machen", systemImage: "arrow.uturn.backward") { store.change { $0.undoExpense(id: expense.id) } } }.frame(minHeight: 48)
                    }.font(.body.weight(.semibold))
                }
                Divider()
            }
            if store.budget.expenses.count > expenseCount { Button("Weitere 30 anzeigen") { expenseCount += 30 }.frame(minHeight: 50) }
            if !store.budget.recurringRecords.isEmpty { DisclosureGroup("Gebuchte Einnahmen und Fixkosten") { recurringHistory.padding(.top, 16) } }
        }
    }
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Deine Einträge werden automatisch auf diesem iPhone gespeichert. Zwei vorherige Stände bleiben als lokale Sicherung erhalten.").font(.body)
            Button("Backup erstellen") { do { exported = try store.exportURL() } catch { store.error = error.localizedDescription } }.buttonStyle(PrimaryAction())
            if let exported { ShareLink("Backup teilen oder in Dateien speichern", item: exported).font(.headline).frame(minHeight: 52) }
            Button("Backup aus Dateien wiederherstellen") { importBackup = true }.font(.headline).frame(minHeight: 52)
            Text("Ein externes Backup hilft auch bei Verlust oder Löschen der App. Geteilte JSON-Dateien enthalten deine Finanzdaten.").font(.body).foregroundStyle(secondary)
            if let lastSaved = store.lastSaved { Text("Zuletzt gespeichert: \(lastSaved.formatted(date: .omitted, time: .shortened))").font(.body).foregroundStyle(secondary) }
        }
    }
    private var monthlyPlan: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Monatliche Planung").font(.title2.bold())
            ledger("Einnahmen / Monat", store.budget.monthlyIncome)
            ledger("Fixkosten / Monat ca.", store.budget.monthlyFixedEquivalent)
            ledger("Nach Fixkosten ca.", store.budget.monthlyIncome - store.budget.monthlyFixedEquivalent)
            Text("Planwerte ohne variable Ausgaben. Vierteljährliche Kosten ÷ 3, jährliche ÷ 12. Die zusätzliche Reserve ist hier nicht enthalten.").font(.subheadline).foregroundStyle(secondary)
        }
    }
    private func recurringSection(_ kind: PaymentKind) -> some View {
        let entries = store.budget.payments.filter { $0.kind == kind }.sorted { $0.nextDue() < $1.nextDue() }
        return VStack(alignment: .leading, spacing: 18) {
            Text(kind == .income ? "Monatliche Einnahmen" : "Fixkosten mit Termin").font(.title2.bold())
            Button(kind == .income ? "Einnahme hinzufügen" : "Fixkosten hinzufügen", systemImage: "plus") { editor = .payment(kind, nil) }.buttonStyle(PrimaryAction())
            if entries.isEmpty { Text(kind == .income ? "Trage zum Beispiel Gehalt oder eine monatliche Unterstützung ein." : "Zum Beispiel Miete, Strom oder eine Jahresversicherung.").font(.subheadline).foregroundStyle(secondary) }
            ForEach(entries) { p in
                VStack(alignment: .leading, spacing: 9) {
                    Text(p.name).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(Euro.format(p.cents)).font(.title2.bold()).foregroundStyle(mint)
                    Text(p.hasPendingOccurrence() ? "\(p.cadence.title) · \(p.nextDue().formatted(date: .abbreviated, time: .omitted))" : "Abgeschlossen · alle Termine gebucht").font(.body).foregroundStyle(secondary)
                    if let end = p.endDate { Text("Letzte Zahlung bis \(end.formatted(date: .abbreviated, time: .omitted))").font(.body).foregroundStyle(secondary) }
                    HStack(spacing: 20) {
                        Button("Bearbeiten") { editor = .payment(kind, p.id) }.frame(minHeight: 52)
                        Menu("Weitere Aktionen") { Button("Entfernen", systemImage: "trash", role: .destructive) { removingPayment = p } }.frame(minHeight: 52)
                    }.font(.body.weight(.semibold))
                    if p.isDue(now: now) {
                        Button(p.kind == .income ? "Als erhalten buchen" : "Als bezahlt buchen") { pendingPayment = p }.font(.body.weight(.semibold)).frame(minHeight: 54)
                        Text("Termin fällig oder überfällig").font(.subheadline).foregroundStyle(SpielraumTheme.warning)
                    }
                }
                Divider()
            }
        }
    }
    private var recurringHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.budget.recurringRecords.isEmpty {
                Text("Gebuchte Einnahmen & Fixkosten").font(.headline)
                ForEach(store.budget.recurringRecords.prefix(30)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.name)
                            Text("Gebucht \(record.bookedAt.formatted(date: .abbreviated, time: .omitted))").font(.subheadline).foregroundStyle(secondary)
                        }
                        Spacer()
                        Text((record.kind == .income ? "+" : "−") + Euro.format(record.cents)).foregroundStyle(record.kind == .income ? SpielraumTheme.positive : SpielraumTheme.text)
                        if store.budget.payments.contains(where: { $0.id == record.paymentID && $0.completed == record.occurrence + 1 }) {
                            Menu {
                                Button("Buchung rückgängig machen", systemImage: "arrow.uturn.backward") { store.change { try $0.undoPayment(recordID: record.id) } }
                            } label: { Label("Ändern", systemImage: "ellipsis").font(.body).frame(minHeight: 48) }.accessibilityLabel("Buchung verwalten")
                        }
                    }
                }
            }
        }
    }
    private var savings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(Euro.format(store.budget.reserved)) zurückgelegt").font(.title2.bold()).foregroundStyle(mint)
            Text("Wähle einen Topf, um Geld zurückzulegen oder freizugeben.").font(.body).foregroundStyle(secondary)
            Button("Neuer Spartopf", systemImage: "plus") { editor = .newPot }.buttonStyle(PrimaryAction()).accessibilityIdentifier("addPot")
            potRows
        }
    }
    private var footer: some View {
        VStack(spacing: 10) {
            Button(largeText ? "Ausgabe" : "Ausgabe eintragen", systemImage: "plus") { editor = .expense }.buttonStyle(PrimaryAction()).accessibilityIdentifier("addExpense").accessibilityLabel("Ausgabe eintragen")
            HStack(spacing: 12) {
                ForEach([Page.overview, Page.pots], id: \.self) { item in
                    Button { page = item; now = Date() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                            Text(largeText ? (item == .overview ? "Start" : "Sparen") : item.rawValue).fixedSize(horizontal: false, vertical: true)
                        }.font(.body.weight(page == item ? .bold : .medium))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(page == item ? mint : secondary)
                            .padding(.vertical, 6)
                            .background(page == item ? SpielraumTheme.soft : SpielraumTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }.accessibilityIdentifier("tab-\(item.rawValue)").accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 6)
            .background(SpielraumTheme.surface).overlay(alignment: .top) { Divider() }
    }
}
private struct MintButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.buttonStyle(PrimaryAction())
        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54).padding(.horizontal, 12)
        .background(SpielraumTheme.primary, in: RoundedRectangle(cornerRadius: 12)) }
}

private struct EditorView: View {
    let editor: Editor
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var category = "Lebensmittel"
    @State private var merchant = ""
    @State private var purpose: ExpensePurpose? = nil
    @State private var fixed = ""
    @State private var weekly = ""
    @State private var loaded = false
    @State private var originalExpense: Expense?
    @State private var confirmDelete = false
    @State private var release = false
    @State private var validation: String?
    private var heading: String { switch editor { case .expense: return "Ausgabe erfassen"; case .settings: return "Budget bearbeiten"; case .newPot: return "Neuer Spartopf"; case .editPot: return "Spartopf bearbeiten"; case .editExpense: return "Ausgabe bearbeiten"; case .payment: return "Zahlung"; case .assistant, .wishes: return "Assistent"; case .notifications: return "Benachrichtigungen"; case .purchaseGuard: return "Kaufbremse"; case .pot(let id): return store.budget.pots.first { $0.id == id }?.name ?? "Spartopf" } }
    var body: some View {
        NavigationStack {
            Form {
                if case .editPot(let id) = editor {
                    Section("Name und Sparziel") {
                        EntryField(label: "Name des Spartopfs", text: $title)
                        field("Sparziel in €", text: $amount)
                    }
                    if let pot = store.budget.pots.first(where: { $0.id == id }) {
                        Section {
                            LabeledContent("Bereits reserviert", value: Euro.format(pot.cents))
                            Text("Name und Sparziel ändern den reservierten Betrag nicht. Ein Ziel unter dem bereits gesparten Betrag ist möglich.").font(.subheadline).foregroundStyle(secondary)
                        }
                        Section {
                            Button("Spartopf löschen", role: .destructive) { confirmDelete = true }
                        }
                    }
                } else if case .settings = editor {
                    Section("Aktuelle Beträge") {
                        field("Kontostand in €", text: $amount)
                        field("Zusätzliche Fixkostenreserve in €", text: $fixed)
                        field("Wochenlimit in €", text: $weekly)
                    }
                    Section { Text("Alle Spartöpfe sind Teil dieses Kontostands. Änderungen gleichen deinen aktuellen Stand ab. Einzelne Fixkosten mit Termin werden zusätzlich reserviert. Bereits darin enthaltene Beträge aus der zusätzlichen Reserve herausnehmen.").foregroundStyle(secondary) }
                } else {
                    if case .pot = editor { Picker("Aktion", selection: $release) { Text("Reservieren").tag(false); Text("Freigeben").tag(true) }.pickerStyle(.menu) }
                    Section { field(editorIsNewPot ? "Sparziel in €" : "Betrag in €", text: $amount) }
                    if editorIsExpense {
                        Section {
                            EntryField(label: "Wofür? (optional)", text: $title)
                            EntryField(label: "Händler (optional)", text: $merchant)
                            Picker("Einordnung fürs Lernen", selection: $purpose) {
                                Text("Noch offen").tag(Optional<ExpensePurpose>.none)
                                ForEach(ExpensePurpose.allCases) { Text($0.title).tag(Optional($0)) }
                            }
                            .disabled(originalExpense?.fundingPotID != nil)
                            Picker("Kategorie", selection: $category) { ForEach(expenseCategories, id: \.self) { Text($0) } }
                        }
                        if originalExpense?.fundingPotID != nil { Text("Notfallausgabe: Eine Betragskorrektur gleicht Kontostand und die noch vorhandene Notfallreserve gemeinsam ab.").font(.subheadline).foregroundStyle(secondary) }
                        Text("Die Ausgabe reduziert deinen Kontostand. Fixkosten mit Termin bitte im Haushalt als bezahlt buchen, damit die Reserve gleichzeitig freigegeben wird.").font(.subheadline).foregroundStyle(secondary)
                    }
                    if case .newPot = editor { EntryField(label: "Name des Spartopfs", text: $title) }
                    if case .pot = editor { Text("Frei verfügbar: \(Euro.format(store.budget.available)). Reservieren verschiebt kein Geld auf ein anderes Bankkonto.").font(.subheadline).foregroundStyle(secondary) }
                }
                if let validation { Text(validation).foregroundStyle(SpielraumTheme.danger).accessibilityAddTraits(.isStaticText) }
                Button("Speichern") { Task { await save() } }.buttonStyle(PrimaryAction()).listRowBackground(Color.clear).accessibilityIdentifier("saveEntry")
            }
            .navigationTitle(heading).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
            .confirmationDialog("Spartopf endgültig löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                if case .editPot(let id) = editor {
                    Button("Spartopf löschen", role: .destructive) {
                        if store.change({ try $0.deletePot(id: id) }) { dismiss() }
                        else { validation = store.error }
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                if case .editPot(let id) = editor, let pot = store.budget.pots.first(where: { $0.id == id }) {
                    Text("\(pot.name) wird gelöscht. \(Euro.format(pot.cents)) werden aus der Reservierung freigegeben. Dein Kontostand bleibt unverändert.\(store.budget.assistant.emergencyPotID == id ? " Dieser Topf ist deine Notfallreserve. Wähle anschließend im Assistenten einen neuen Notfalltopf." : "")")
                }
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                if case .editExpense(let id) = editor, let expense = store.budget.expenses.first(where: { $0.id == id }) {
                    originalExpense = expense; amount = Euro.editable(expense.cents); title = expense.title
                    category = expense.category; merchant = expense.merchant ?? ""; purpose = expense.purpose
                }
                if case .editPot(let id) = editor, let pot = store.budget.pots.first(where: { $0.id == id }) {
                    title = pot.name; amount = Euro.editable(pot.target)
                }
                if case .settings = editor { amount = Euro.editable(store.budget.balance); fixed = Euro.editable(store.budget.fixedCosts); weekly = Euro.editable(store.budget.weeklyLimit) } }
        }.readableScreen()
    }
    private var expenseCategories: [String] {
        let categories = ["Lebensmittel", "Freizeit", "Mobilität", "Wohnen", "Sonstiges"]
        return categories.contains(category) ? categories : categories + [category]
    }
    private var editorIsExpense: Bool { switch editor { case .expense, .editExpense: return true; default: return false } }
    private var editorIsNewPot: Bool { if case .newPot = editor { return true }; return false }
    private func field(_ label: String, text: Binding<String>) -> some View { EntryField(label: label, text: text, money: true) }
    private func save() async {
        do {
            let cents = try Euro.parse(amount, allowZero: { if case .settings = editor { return true }; return false }())
            switch editor {
            case .settings:
                let f = try Euro.parse(fixed, allowZero: true); let w = try Euro.parse(weekly)
                if await store.saveChange({ $0.balance = cents; $0.fixedCosts = f; $0.weeklyLimit = w; $0.setupComplete = true }) { dismiss() }
            case .expense:
                if await store.saveChange({ try $0.addExpense(cents: cents, title: String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)), category: category, merchant: String(merchant.prefix(100)), purpose: purpose) }) { dismiss() }
            case .editExpense(let id):
                guard let originalExpense else { validation = BudgetError.missingExpense.localizedDescription; return }
                if await store.saveChange({ try $0.updateExpense(id: id, cents: cents, title: title, category: category, merchant: merchant, purpose: purpose, expected: originalExpense) }) { dismiss() }
                else { validation = store.error; store.error = nil }
            case .pot(let id):
                if await store.saveChange({ b in if release { try b.release(cents: cents, potID: id) } else { try b.allocate(cents: cents, potID: id) } }) { dismiss() }
            case .editPot(let id):
                if await store.saveChange({ try $0.updatePot(id: id, name: title, target: cents) }) { dismiss() }
                else { validation = store.error }
            case .payment, .assistant, .wishes, .notifications, .purchaseGuard: return
            case .newPot:
                let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                guard !name.isEmpty else { validation = "Bitte einen Namen eingeben."; return }
                if await store.saveChange({ $0.pots.append(.init(name: name, target: cents)) }) { dismiss() }
            }
        } catch { validation = error.localizedDescription }
    }
}

private struct RecurringEditor: View {
    let kind: PaymentKind
    let existingID: UUID?
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var cadence = PaymentCadence.monthly
    @State private var dueDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var loaded = false
    @State private var validation: String?
    private var dateRange: ClosedRange<Date> {
        let c = Calendar(identifier: .gregorian)
        return c.date(from: DateComponents(year: 2000, month: 1, day: 1))!...c.date(from: DateComponents(year: 2100, month: 12, day: 31))!
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("\(kind == .income ? "Einnahme" : "Fixkosten")") {
                    EntryField(label: "Name", text: $name)
                    EntryField(label: "Betrag je Zahlung in €", text: $amount, money: true)
                    if kind == .fixedCost {
                        Picker("Rhythmus", selection: $cadence) { ForEach(PaymentCadence.allCases) { Text($0.title).tag($0) } }
                    } else { LabeledContent("Rhythmus", value: "Monatlich") }
                    DatePicker("Nächste Fälligkeit", selection: $dueDate, in: dateRange, displayedComponents: .date)
                    if kind == .fixedCost {
                        Toggle("Letzte Zahlung festlegen", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Letzte Zahlung spätestens", selection: $endDate, in: dateRange, displayedComponents: .date)
                            Text("Es zählen die regulären Fälligkeiten bis einschließlich dieses Datums. Danach werden keine weiteren Zahlungen eingeplant. Bereits offene Termine bleiben erhalten.").font(.subheadline).foregroundStyle(secondary)
                        }
                    }
                }
                Section {
                    Text("Wähle den nächsten noch nicht gebuchten Termin. Der Folgetermin wird nach jeder Buchung automatisch berechnet. Am 29., 30. oder 31. wird in kürzeren Monaten der letzte Tag verwendet.").font(.subheadline).foregroundStyle(secondary)
                    if kind == .income { Text("Der Kontostand steigt erst durch ‚Als erhalten buchen‘.").font(.subheadline).foregroundStyle(secondary) }
                    else { Text("Offene Termine bis Monatsende werden reserviert. ‚Als bezahlt buchen‘ verringert Kontostand und offene Reserve gleichzeitig. Nicht nochmals als normale Ausgabe erfassen.").font(.subheadline).foregroundStyle(secondary) }
                    if existingID != nil { Text("Änderungen gelten ab dem gewählten nächsten Termin. Frühere Buchungen bleiben erhalten.").font(.subheadline).foregroundStyle(secondary) }
                }
                if let validation { Text(validation).foregroundStyle(SpielraumTheme.danger) }
                Button("Speichern") { Task { await save() } }.buttonStyle(PrimaryAction()).listRowBackground(Color.clear).accessibilityIdentifier("saveEntry")
            }
            .navigationTitle(kind == .income ? "Monatliche Einnahme" : "Fixkosten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                if let id = existingID, let p = store.budget.payments.first(where: { $0.id == id }) {
                    name = p.name; amount = Euro.editable(p.cents); cadence = p.cadence; dueDate = p.nextDue()
                    hasEndDate = p.endDate != nil; endDate = p.endDate ?? max(Date(), p.nextDue())
                }
            }
        }.readableScreen()
    }
    private func save() async {
        do {
            let cents = try Euro.parse(amount)
            let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
            guard !cleanName.isEmpty else { validation = "Bitte einen Namen eingeben."; return }
            var p = RecurringPayment(name: cleanName, cents: cents, kind: kind, cadence: kind == .income ? .monthly : cadence, firstDue: Calendar.current.startOfDay(for: dueDate), endDate: hasEndDate ? Calendar.current.startOfDay(for: endDate) : nil)
            if let id = existingID, let old = store.budget.payments.first(where: { $0.id == id }),
               old.cadence == p.cadence, Calendar.current.isDate(old.nextDue(), inSameDayAs: dueDate) {
                // Keep the original anchor, including month-end and leap-day rules.
                p.firstDue = old.firstDue; p.completed = old.completed
            }
            _ = try p.validated()
            let success = await store.saveChange { budget in
                if let id = existingID { try budget.replacePayment(id: id, with: p) }
                else { try budget.savePayment(p) }
            }
            if success { dismiss() } else { validation = store.error; store.error = nil }
        } catch { validation = error.localizedDescription }
    }
}
