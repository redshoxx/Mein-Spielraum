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
private enum Editor: Identifiable { case expense, settings, assistant, wishes, notifications, purchaseGuard, pot(UUID), editPot(UUID), editExpense(UUID), newPot, payment(PaymentKind, UUID?)
    var id: String { switch self { case .expense: return "expense"; case .settings: return "settings"; case .assistant: return "assistant"; case .wishes: return "wishes"; case .notifications: return "notifications"; case .purchaseGuard: return "purchaseGuard"; case .pot(let id): return id.uuidString; case .editPot(let id): return "edit-pot-\(id.uuidString)"; case .editExpense(let id): return "edit-expense-\(id.uuidString)"; case .newPot: return "new"; case .payment(let kind, let id): return "payment-\(kind.rawValue)-\(id?.uuidString ?? "new")" } }
}
struct ContentView: View {
    @EnvironmentObject private var store: BudgetStore
    @EnvironmentObject private var notifications: BudgetNotifications
    @Environment(\.scenePhase) private var phase
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
    var body: some View {
        Group {
            if store.isLoading { ProgressView("Daten werden sicher geladen …").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if store.loadFailed { recoveryView }
            else if !store.budget.setupComplete { welcome }
            else { main }
        }
        .background(canvas.ignoresSafeArea()).tint(mint)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in if store.loadFailed { store.load() } }
        .onChange(of: store.isLoading) { if !store.isLoading && !store.loadFailed { notifications.refresh(budget: store.budget); processPendingRoute() } }
        .onChange(of: store.isSaving) { if !store.isSaving { processPendingRoute() } }
        .confirmationDialog("Gesicherten Stand wiederherstellen?", isPresented: $confirmRecovery, titleVisibility: .visible) {
            Button("Sicherung wiederherstellen") { store.restoreRecovery() }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Es wird der angezeigte frühere Stand geladen. Spätere Änderungen können darin fehlen. Die bisherige Speicherdatei wird zur Sicherheit aufbewahrt.") }
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
    private func processPendingRoute() {
        guard !store.isLoading, !store.isSaving, !store.loadFailed else { return }
        if pendingPurchaseGuard {
            pendingPurchaseGuard = false; notifications.route = nil; editor = .purchaseGuard
        } else if let route = notifications.route {
            notifications.route = nil
            if route == "payments" { editor = nil; page = .household }
            else { editor = route == "wish" ? .wishes : .purchaseGuard }
        }
    }
    private var recoveryView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle).foregroundStyle(.orange)
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
            Text("Keine Bankanbindung · Keine Anmeldung").font(.caption).foregroundStyle(secondary).frame(maxWidth: .infinity)
        }.padding(24)
    }
    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if page == .household {
                    Button { page = .overview; now = Date() } label: { Label("Übersicht", systemImage: "chevron.left").frame(minHeight: 44) }.accessibilityLabel("Zurück zur Übersicht")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MEIN SPIELRAUM").font(.system(size: 10, weight: .bold)).tracking(2.6).foregroundStyle(mint)
                        Text(page == .overview ? "Dein Überblick" : page.rawValue).font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.7)
                    }
                    Spacer(minLength: 0)
                    if page == .overview {
                        Button { editor = .notifications } label: { Image(systemName: "bell").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Benachrichtigungen öffnen")
                        Button { page = .household; now = Date() } label: { Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Haushalt und Einstellungen öffnen")
                    }
                    if page == .household { Button { editor = .settings } label: { Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Budget bearbeiten") }
                }.padding(.bottom, 14)
                if page == .overview { overview }
                else if page == .household { household }
                else { savings }
            }.padding(.horizontal, 22).padding(.top, 15).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if page != .household { footer }
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("DEIN SPIELRAUM", systemImage: "sparkle").font(.caption.weight(.bold)).tracking(1.3)
                    Spacer()
                    Text(weekLabel).font(.caption.weight(.medium))
                }
                Text(Euro.format(dashboardAmount)).font(.system(size: 58, weight: .bold, design: .rounded)).tracking(-2).minimumScaleFactor(0.4).lineLimit(1)
                Text("Richtwert für freie Wünsche").font(.headline)
                Text(dashboardAnalysis.ready ? "Alltag, Fixkosten, Sparreserve und Puffer berücksichtigt. Eine Schätzung aus deinen Einträgen." : dashboardAnalysis.explanation).font(.caption).lineSpacing(3).opacity(0.8)
                HStack(spacing: 6) { Image(systemName: "lock.shield"); Text("Deine Reserven bleiben geschützt") }.font(.caption.weight(.semibold))
            }.foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.12)).padding(23).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [mint, Color(red: 0.74, green: 0.98, blue: 0.79)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23))
            HStack(alignment: .top, spacing: 12) {
                metric("Kontostand", amount: store.budget.balance, icon: "creditcard")
                metric("In Spartöpfen", amount: store.budget.reserved, icon: "leaf")
            }
            Button { editor = .purchaseGuard } label: {
                HStack(spacing: 14) {
                    Image(systemName: "hand.raised.fill").font(.title2).foregroundStyle(mint).frame(width: 42, height: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vor dem Kaufen kurz stoppen").font(.headline).foregroundStyle(.white)
                        Text("Preis prüfen. Wunsch vormerken. Abstand gewinnen.").font(.caption).foregroundStyle(secondary)
                    }
                    Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(mint)
                }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 14) {
                Text("Dein Geld, aufgeteilt").font(.headline)
                ledger("Fixkosten bis Monatsende", store.budget.fixedReserve(now: now))
                ledger("Vor Alltag und Puffer verfügbar", store.budget.available)
                Text("Wochenlimit: \(Euro.format(store.budget.weeklyLimit)) · Wird durch Lernen nicht angehoben.").font(.caption).foregroundStyle(secondary)
            }.budgetCard()
            Button { editor = .assistant } label: {
                HStack(spacing: 14) {
                    Image(systemName: "brain.head.profile").font(.title2).foregroundStyle(mint)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Dein Budget denkt mit").font(.headline).foregroundStyle(.white)
                        Text("Automatische Einschätzung & Kaufcheck").font(.caption).foregroundStyle(secondary)
                    }
                    Spacer(minLength: 0); Image(systemName: "arrow.up.right").foregroundStyle(mint)
                }.frame(maxWidth: .infinity).budgetCard()
            }.buttonStyle(.plain)
            upcomingPayments.budgetCard()
            HStack { Text("Deine Spartöpfe").font(.title2.bold()); Spacer(); Button { editor = .newPot } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("Spartopf hinzufügen") }
            potRows
        }.padding(.top, 8)
    }
    private func metric(_ title: String, amount: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(mint)
            Text(title).font(.caption).foregroundStyle(secondary)
            Text(Euro.format(amount)).font(.system(size: 22, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
    }
    private var upcomingPayments: some View {
        let items = store.budget.upcomingFixedPayments(now: now, calendar: calendar)
        let visible = showAllUpcoming ? items : Array(items.prefix(4))
        return VStack(alignment: .leading, spacing: 17) {
            Text("Nächste Fixkosten").font(.system(size: 23, weight: .bold))
            if items.isEmpty {
                Text("Keine offenen Zahlungstermine. Fixkosten legst du über das Zahnrad im Haushalt an.").font(.subheadline).foregroundStyle(secondary)
            } else {
                Text("Je Posten der nächste offene Termin").font(.caption).foregroundStyle(secondary)
                ForEach(visible) { item in upcomingRow(item) }
                if items.count > 4 {
                    Button(showAllUpcoming ? "Weniger anzeigen" : "Alle \(items.count) anzeigen") { showAllUpcoming.toggle() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
                Text("Bearbeiten und als bezahlt buchen: Zahnrad → Haushalt.").font(.caption).foregroundStyle(secondary)
            }
        }.padding(.vertical, 23).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider() }
    }
    private func upcomingRow(_ item: UpcomingPayment) -> some View {
        let urgent = item.daysUntilDue <= 0
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: urgent ? "exclamationmark.circle" : "calendar").font(.system(size: 20)).foregroundStyle(urgent ? Color.orange : mint).frame(width: 25).padding(.top, 2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.payment.name).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(Euro.format(item.payment.cents)).fontWeight(.semibold).monospacedDigit().fixedSize()
                }
                Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())).font(.subheadline).foregroundStyle(secondary)
                Text(item.timingLabel).font(.caption.weight(.semibold)).foregroundStyle(urgent ? Color.orange : mint)
            }
        }.padding(.vertical, 5).accessibilityElement(children: .combine)
    }
    private func ledger(_ title: String, _ amount: Int) -> some View {
        HStack { Text(title).foregroundStyle(secondary); Spacer(); Text(Euro.format(amount)).monospacedDigit() }.font(.body)
    }
    private var potRows: some View {
        VStack(spacing: 14) {
            ForEach(store.budget.pots) { p in
                HStack(spacing: 8) {
                Button { editor = .pot(p.id) } label: {
                    VStack(spacing: 11) {
                        HStack { Text(p.name).fontWeight(.semibold).lineLimit(1); Spacer(); Text(Euro.format(p.cents)).fontWeight(.semibold) + Text(" / \(Euro.format(p.target))").foregroundColor(secondary) }.font(.subheadline)
                        ProgressView(value: min(Double(p.cents), Double(p.target)), total: Double(p.target)).tint(mint).scaleEffect(x: 1, y: 1.8, anchor: .center)
                    }.padding(.vertical, 3).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("\(p.name), \(Euro.format(p.cents)) von \(Euro.format(p.target)). Geld verwalten.")
                    Button { editor = .editPot(p.id) } label: {
                        Image(systemName: "pencil").frame(width: 44, height: 44)
                    }.accessibilityLabel("\(p.name) bearbeiten oder löschen")
                }.budgetCard()
            }
        }
    }
    private var household: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Dein Geld. Klar im Blick.").foregroundStyle(secondary)
            Text(Euro.format(store.budget.available)).font(.system(size: 48, weight: .bold)).foregroundStyle(mint)
            VStack(spacing: 14) { ledger("Kontostand", store.budget.balance); ledger("Fixkosten bis Monatsende", store.budget.fixedReserve(now: now)); ledger("Diese Woche ausgegeben", store.budget.weeklySpent(now: now, calendar: calendar)) }
            Text("Offene Fixkosten bis Monatsende inklusive überfälliger Termine werden reserviert. Künftige Einnahmen sind noch nicht als verfügbares Geld gezählt.").font(.caption).foregroundStyle(secondary)
            monthlyPlan
            recurringSection(.income)
            recurringSection(.fixedCost)
            if store.budget.fixedCosts > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ledger("Zusätzliche Fixkostenreserve", store.budget.fixedCosts)
                    Text("Dein bisheriger Pauschalbetrag bleibt zusätzlich erhalten. Passe ihn unter Budget bearbeiten an, wenn neue Einzelposten darin bereits enthalten sind.").font(.caption).foregroundStyle(secondary)
                    Button("Reserve anpassen") { editor = .settings }
                }
            }
            recurringHistory
            Divider()
            Text("Ausgaben").font(.title2.bold())
            Button("Ausgabe erfassen", systemImage: "plus") { editor = .expense }
            if store.budget.expenses.isEmpty { Text("Eine frische Woche. Erfasse deine erste Ausgabe.").foregroundStyle(secondary).padding(.vertical, 25) }
            ForEach(Array(store.budget.expenses.prefix(expenseCount))) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 5) { Text(e.title); Text("\(e.category) · \(e.date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(secondary) }
                    Spacer(); Text("−\(Euro.format(e.cents))").fontWeight(.semibold)
                    Menu { Button("Bearbeiten", systemImage: "pencil") { editor = .editExpense(e.id) }; Button("Rückgängig machen", systemImage: "arrow.uturn.backward") { store.change { $0.undoExpense(id: e.id) } } } label: { Image(systemName: "ellipsis").frame(width: 38, height: 44) }.accessibilityLabel("Ausgabe verwalten")
                }
                Divider()
            }
            if store.budget.expenses.count > expenseCount {
                Button("Weitere 30 Ausgaben anzeigen") { expenseCount += 30 }
                Text("\(min(expenseCount, store.budget.expenses.count)) von \(store.budget.expenses.count) Ausgaben geladen. Alle Einträge bleiben gespeichert.").font(.caption).foregroundStyle(secondary)
            }
            Button("Benachrichtigungen", systemImage: "bell.badge") { editor = .notifications }
            Button("Kaufbremse & Amazon einrichten", systemImage: "hand.raised") { editor = .purchaseGuard }
            Text("Datensicherung").font(.headline).padding(.top, 10)
            Text("Zwei vorherige Speicherstände werden beim Ändern automatisch auf diesem iPhone gesichert. Bei einem Ladefehler kannst du einen geprüften Stand wiederherstellen. Ein externes Backup schützt zusätzlich bei Verlust oder Löschen der App.").font(.caption).foregroundStyle(secondary)
            if let lastSaved = store.lastSaved { Text("Zuletzt gespeichert: \(lastSaved.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(mint) }
            Button("Backup erstellen", systemImage: "square.and.arrow.up") {
                do { exported = try store.exportURL() } catch { store.error = error.localizedDescription }
            }
            if let exported { ShareLink("Backup teilen oder in Dateien sichern", item: exported).font(.subheadline) }
            Button("Backup wiederherstellen", systemImage: "arrow.down.doc") { importBackup = true }
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0") · Daten nur auf deinem Gerät").font(.caption).foregroundStyle(secondary)
        }
    }
    private var monthlyPlan: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Monatliche Planung").font(.title2.bold())
            ledger("Einnahmen / Monat", store.budget.monthlyIncome)
            ledger("Fixkosten / Monat ca.", store.budget.monthlyFixedEquivalent)
            ledger("Nach Fixkosten ca.", store.budget.monthlyIncome - store.budget.monthlyFixedEquivalent)
            Text("Planwerte ohne variable Ausgaben. Vierteljährliche Kosten ÷ 3, jährliche ÷ 12. Die zusätzliche Reserve ist hier nicht enthalten.").font(.caption).foregroundStyle(secondary)
        }
    }
    private func recurringSection(_ kind: PaymentKind) -> some View {
        let entries = store.budget.payments.filter { $0.kind == kind }.sorted { $0.nextDue() < $1.nextDue() }
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(kind == .income ? "Monatliche Einnahmen" : "Fixkosten mit Termin").font(.title2.bold())
                Spacer()
                Button { editor = .payment(kind, nil) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel(kind == .income ? "Einnahme hinzufügen" : "Fixkosten hinzufügen")
            }
            if entries.isEmpty { Text(kind == .income ? "Trage zum Beispiel Gehalt oder eine monatliche Unterstützung ein." : "Zum Beispiel Miete, Strom oder eine Jahresversicherung.").font(.subheadline).foregroundStyle(secondary) }
            ForEach(entries) { p in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.name).fontWeight(.semibold)
                            Text(p.hasPendingOccurrence() ? "\(p.cadence.title) · \(p.nextDue().formatted(date: .abbreviated, time: .omitted))" : "Abgeschlossen · alle Termine gebucht").font(.caption).foregroundStyle(secondary)
                            if let end = p.endDate { Text("Zahlungen bis \(end.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(secondary) }
                            if p.kind == .fixedCost && p.cadence != .monthly && p.isActiveForPlanning(now: now) { Text("Ca. \(Euro.format(p.monthlyEquivalent)) / Monat").font(.caption).foregroundStyle(secondary) }
                        }
                        Spacer(minLength: 5)
                        Text(Euro.format(p.cents)).fontWeight(.semibold).monospacedDigit()
                        Menu {
                            Button("Bearbeiten", systemImage: "pencil") { editor = .payment(kind, p.id) }
                            Button("Entfernen", systemImage: "trash", role: .destructive) { removingPayment = p }
                        } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }.accessibilityLabel("\(p.name) verwalten")
                    }
                    if p.isDue(now: now) {
                        Button(p.kind == .income ? "Als erhalten buchen" : "Als bezahlt buchen") { pendingPayment = p }.font(.subheadline.weight(.semibold)).frame(minHeight: 36)
                        Text("Termin fällig oder überfällig").font(.caption).foregroundStyle(.orange)
                    }
                }
                Divider()
            }
            Button(kind == .income ? "Einnahme hinzufügen" : "Fixkosten hinzufügen", systemImage: "plus") { editor = .payment(kind, nil) }
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
                            Text("Gebucht \(record.bookedAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(secondary)
                        }
                        Spacer()
                        Text((record.kind == .income ? "+" : "−") + Euro.format(record.cents)).foregroundStyle(record.kind == .income ? mint : .white)
                        if store.budget.payments.contains(where: { $0.id == record.paymentID && $0.completed == record.occurrence + 1 }) {
                            Menu {
                                Button("Buchung rückgängig machen", systemImage: "arrow.uturn.backward") { store.change { try $0.undoPayment(recordID: record.id) } }
                            } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }.accessibilityLabel("Buchung verwalten")
                        }
                    }
                }
            }
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
                ForEach([Page.overview, Page.pots], id: \.self) { p in
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
        configuration.label.font(.system(size: 17, weight: .bold)).foregroundStyle(Color.black.opacity(0.9)).frame(maxWidth: .infinity).padding(.vertical, 15).background(mint.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
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
                        TextField("Name des Spartopfs", text: $title).accessibilityLabel("Name des Spartopfs")
                        field("Sparziel in €", text: $amount)
                    }
                    if let pot = store.budget.pots.first(where: { $0.id == id }) {
                        Section {
                            LabeledContent("Bereits reserviert", value: Euro.format(pot.cents))
                            Text("Name und Sparziel ändern den reservierten Betrag nicht. Ein Ziel unter dem bereits gesparten Betrag ist möglich.").font(.caption).foregroundStyle(secondary)
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
                    if case .pot = editor { Picker("Aktion", selection: $release) { Text("Reservieren").tag(false); Text("Freigeben").tag(true) }.pickerStyle(.segmented) }
                    Section { field(editorIsNewPot ? "Sparziel in €" : "Betrag in €", text: $amount) }
                    if editorIsExpense {
                        Section {
                            TextField("Bezeichnung (optional)", text: $title)
                            TextField("Händler (optional)", text: $merchant)
                            Picker("Einordnung fürs Lernen", selection: $purpose) {
                                Text("Noch offen").tag(Optional<ExpensePurpose>.none)
                                ForEach(ExpensePurpose.allCases) { Text($0.title).tag(Optional($0)) }
                            }
                            .disabled(originalExpense?.fundingPotID != nil)
                            Picker("Kategorie", selection: $category) { ForEach(expenseCategories, id: \.self) { Text($0) } }
                        }
                        if originalExpense?.fundingPotID != nil { Text("Notfallausgabe: Eine Betragskorrektur gleicht Kontostand und die noch vorhandene Notfallreserve gemeinsam ab.").font(.caption).foregroundStyle(secondary) }
                        Text("Die Ausgabe reduziert deinen Kontostand. Fixkosten mit Termin bitte im Haushalt als bezahlt buchen, damit die Reserve gleichzeitig freigegeben wird.").font(.caption).foregroundStyle(secondary)
                    }
                    if case .newPot = editor { TextField("Name des Spartopfs", text: $title) }
                    if case .pot = editor { Text("Frei verfügbar: \(Euro.format(store.budget.available)). Reservieren verschiebt kein Geld auf ein anderes Bankkonto.").font(.subheadline).foregroundStyle(secondary) }
                }
                if let validation { Text(validation).foregroundStyle(.red).accessibilityAddTraits(.isStaticText) }
                Button("Speichern") { Task { await save() } }.fontWeight(.bold)
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
        }.tint(mint)
    }
    private var expenseCategories: [String] {
        let categories = ["Lebensmittel", "Freizeit", "Mobilität", "Wohnen", "Sonstiges"]
        return categories.contains(category) ? categories : categories + [category]
    }
    private var editorIsExpense: Bool { switch editor { case .expense, .editExpense: return true; default: return false } }
    private var editorIsNewPot: Bool { if case .newPot = editor { return true }; return false }
    private func field(_ label: String, text: Binding<String>) -> some View { TextField(label, text: text).keyboardType(.decimalPad).accessibilityLabel(label) }
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
                    TextField("Name, z. B. \(kind == .income ? "Gehalt" : "Versicherung")", text: $name).accessibilityLabel("Name")
                    TextField("Betrag je Zahlung in €", text: $amount).keyboardType(.decimalPad).accessibilityLabel("Betrag je Zahlung in Euro")
                    if kind == .fixedCost {
                        Picker("Rhythmus", selection: $cadence) { ForEach(PaymentCadence.allCases) { Text($0.title).tag($0) } }
                    } else { LabeledContent("Rhythmus", value: "Monatlich") }
                    DatePicker("Nächste Fälligkeit", selection: $dueDate, in: dateRange, displayedComponents: .date)
                    if kind == .fixedCost {
                        Toggle("Letzte Zahlung festlegen", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Letzte Zahlung spätestens", selection: $endDate, in: dateRange, displayedComponents: .date)
                            Text("Es zählen die regulären Fälligkeiten bis einschließlich dieses Datums. Danach werden keine weiteren Zahlungen eingeplant. Bereits offene Termine bleiben erhalten.").font(.caption).foregroundStyle(secondary)
                        }
                    }
                }
                Section {
                    Text("Wähle den nächsten noch nicht gebuchten Termin. Der Folgetermin wird nach jeder Buchung automatisch berechnet. Am 29., 30. oder 31. wird in kürzeren Monaten der letzte Tag verwendet.").font(.subheadline).foregroundStyle(secondary)
                    if kind == .income { Text("Der Kontostand steigt erst durch ‚Als erhalten buchen‘.").font(.subheadline).foregroundStyle(secondary) }
                    else { Text("Offene Termine bis Monatsende werden reserviert. ‚Als bezahlt buchen‘ verringert Kontostand und offene Reserve gleichzeitig. Nicht nochmals als normale Ausgabe erfassen.").font(.subheadline).foregroundStyle(secondary) }
                    if existingID != nil { Text("Änderungen gelten ab dem gewählten nächsten Termin. Frühere Buchungen bleiben erhalten.").font(.caption).foregroundStyle(secondary) }
                }
                if let validation { Text(validation).foregroundStyle(.red) }
                Button("Speichern") { Task { await save() } }.fontWeight(.bold)
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
        }.tint(mint)
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
