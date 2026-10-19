import SwiftUI
import UIKit
import Combine

private let assistMint = Color(red: 0.39, green: 0.95, blue: 0.77)
struct AssistantView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var settingsOpen = false
    @State private var amount = ""
    @State private var name = ""
    @State private var merchant = ""
    @State private var category = "Freizeit"
    @State private var emergencyName = ""
    @State private var emergencyAmount = ""
    @State private var error: String?
    @State private var message: String?
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var analysis: BudgetAssessment { store.budget.assessment(now: now) }
    var body: some View {
        NavigationStack {
            List {
                Picker("Bereich", selection: $tab) { Text("Mein Plan").tag(0); Text("Kaufcheck").tag(1); Text("Lernen").tag(2) }.pickerStyle(.segmented)
                if tab == 0 { planSections }
                else if tab == 1 { purchaseSections }
                else { learningSections }
                Section { Text("Lokal lernender Algorithmus, kein Chatbot. Er nutzt ausschließlich deine Einträge und Markierungen. Keine Verbindung zu George, keine Banksperre und keine automatischen Überweisungen. Prognosen sind Schätzungen.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Budget-Assistent").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { settingsOpen = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Assistent einrichten") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .sheet(isPresented: $settingsOpen) { AssistantSettingsView().environmentObject(store) }
            .alert("Hinweis", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
            .onReceive(timer) { now = $0 }
        }.tint(assistMint).preferredColorScheme(.dark)
    }
    @ViewBuilder private var planSections: some View {
        if !store.budget.assistant.configured {
            Section("Zuerst dein Plan") {
                Text("Lege notwendige Alltagskosten, Sicherheitspuffer, zusätzliches Spargeld und den nächsten Gehaltstag fest. Der Assistent verändert diese Vorgaben nie selbst.")
                Button("Jetzt einrichten") { settingsOpen = true }
            }
        } else {
            Section("Richtwert für freie Wünsche") {
                Text(Euro.format(analysis.purchaseLimit)).font(.system(size: 36, weight: .bold)).foregroundStyle(assistMint)
                Text(analysis.explanation).font(.subheadline)
                if let payday = analysis.payday { Text("Bis \(payday.formatted(date: .abbreviated, time: .omitted)) · \(analysis.days) Tage") }
                if !analysis.ready { Button("Gehaltstag prüfen") { settingsOpen = true } }
                if analysis.shortfall > 0 { Text("Im Plan fehlen \(Euro.format(analysis.shortfall)). Keine freien Wünsche empfohlen; Plan und Kontostand prüfen.").foregroundStyle(.orange) }
            }
            if analysis.ready {
                Section("Was vorher geschützt bleibt") {
                    value("Offene Fixkosten", analysis.fixedReserve)
                    value("Bereits in Spartöpfen", store.budget.reserved)
                    value("Notwendiger Alltag bis Gehalt", analysis.essentialReserve)
                    value("Sicherheitspuffer", analysis.buffer)
                    value("Noch zusätzlich sparen", analysis.extraSavings)
                    Text("Künftiges Gehalt wird nicht als vorhandenes Guthaben gerechnet. Offene Fixkosten werden mindestens bis Monatsende und bis zum Gehaltstag berücksichtigt. Dein Wochenlimit gilt zusätzlich.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Sparen") {
                    value("Vorsichtiger Zusatzvorschlag", analysis.additionalSavingsSuggestion)
                    Text("Nur ein Vorschlag, keine Überweisung. Unter Spartöpfe kannst du Geld reservieren. Das reduziert den noch zusätzlich geplanten Sparbetrag, damit er nicht doppelt abgezogen wird.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        emergencySection
        if let message { Section { Text(message).foregroundStyle(assistMint) } }
    }
    private func value(_ title: String, _ cents: Int) -> some View {
        HStack { Text(title); Spacer(); Text(Euro.format(cents)).monospacedDigit() }
    }
    private var emergencySection: some View {
        Section("Notfall · ohne Kaufpause") {
            if let id = store.budget.assistant.emergencyPotID, let pot = store.budget.pots.first(where: { $0.id == id }) {
                value(pot.name, pot.cents)
                TextField("Wofür brauchst du das Geld?", text: $emergencyName)
                TextField("Betrag in €", text: $emergencyAmount).keyboardType(.decimalPad)
                Button("Notfallausgabe jetzt erfassen") {
                    do {
                        let cents = try Euro.parse(emergencyAmount)
                        apply { try $0.emergencyExpense(cents: cents, title: String(emergencyName.prefix(100))) }
                        if error == nil { emergencyAmount = ""; emergencyName = ""; message = "Notfall erfasst. Die Reserve wurde angepasst; prüfe deinen Sparplan zum Wiederaufbauen." }
                    } catch { self.error = error.localizedDescription }
                }
                Text("Erfasst die Ausgabe sofort aus deinem Notfalltopf. Keine Wartezeit, kein Kredit und keine reale Banküberweisung. Reicht die Reserve nicht, wird die Lücke angezeigt.").font(.caption).foregroundStyle(.secondary)
            } else { Text("Wähle in den Assistent-Einstellungen einen vorhandenen Spartopf als Notfallreserve."); Button("Notfalltopf wählen") { settingsOpen = true } }
        }
    }
    @ViewBuilder private var purchaseSections: some View {
        Section("Vor dem Kauf prüfen") {
            TextField("Was möchtest du kaufen?", text: $name)
            TextField("Preis in €", text: $amount).keyboardType(.decimalPad)
            TextField("Händler (optional)", text: $merchant)
            Picker("Kategorie", selection: $category) { ForEach(["Lebensmittel", "Freizeit", "Mobilität", "Wohnen", "Sonstiges"], id: \.self) { Text($0) } }
            if let cents = try? Euro.parse(amount) {
                if !analysis.ready { Text("Bitte zuerst den Assistenten einrichten und den Gehaltstag prüfen.").foregroundStyle(.orange) }
                else if cents > analysis.purchaseLimit { Text("Der Kauf liegt \(Euro.format(cents - analysis.purchaseLimit)) über deinem Richtwert. Wünsche verschieben; bei notwendigen Ausgaben den Plan prüfen.").foregroundStyle(.orange) }
                else { Text("Nach diesem Kauf blieben nach den erfassten Planwerten \(Euro.format(analysis.purchaseLimit - cents)) für freie Wünsche.").foregroundStyle(assistMint) }
            }
            if let estimate = store.budget.necessityEstimate(merchant: merchant, category: category) {
                Text(estimate.probability >= 0.7 ? "Aus deinen Markierungen eher notwendig – bitte selbst prüfen." : estimate.probability <= 0.3 ? "Aus deinen Markierungen eher ein Wunsch." : "Deine Markierungen sind gemischt; keine klare Einordnung.").font(.subheadline)
                Text("\(estimate.basis) · \(estimate.samples) Beispiele. Der Händler verrät nicht, was du tatsächlich gekauft hast.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Auf Wunschliste · 48 Stunden Kaufpause") {
                do {
                    let cents = try Euro.parse(amount)
                    let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
                    guard !title.isEmpty else { error = "Bitte einen Namen eingeben."; return }
                    apply { $0.wishes.insert(.init(name: title, cents: cents, merchant: String(merchant.prefix(100)), category: category, createdAt: now), at: 0) }
                    if error == nil { name = ""; amount = ""; merchant = "" }
                } catch { self.error = error.localizedDescription }
            }
        }
        Section("Deine Wunschliste") {
            if store.budget.wishes.isEmpty { Text("Noch keine Wünsche. Die Kaufpause gibt dir Zeit, den Kauf zu überdenken.").foregroundStyle(.secondary) }
            ForEach(store.budget.wishes) { wish in wishRow(wish) }
        }
    }
    private func wishRow(_ wish: PurchaseWish) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Text(wish.name).fontWeight(.semibold); Spacer(); Text(Euro.format(wish.cents)) }
            if wish.readyAt > now { Text("Kaufpause bis \(wish.readyAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            else { Text("Kaufpause vorbei. Passt der Wunsch noch zu deinem Ziel?").font(.caption).foregroundStyle(.secondary) }
            Button("Gekauft · Ausgabe erfassen") { apply { try $0.buyWish(id: wish.id, now: now) } }.disabled(wish.readyAt > now || !analysis.ready || wish.cents > analysis.purchaseLimit)
            Button("Verzichten / entfernen", role: .destructive) { apply { $0.wishes.removeAll { $0.id == wish.id } } }
        }.padding(.vertical, 5)
    }
    @ViewBuilder private var learningSections: some View {
        Section("Was sich anpasst") {
            Text("Deine Markierungen ändern die Einschätzung bei Händlern und Kategorien. Ab 3 Händler-Beispielen oder 5 Kategorie-Beispielen wird eine vorsichtige Wahrscheinlichkeit berechnet.")
            Text("Für Alltagskosten nutzt der Assistent die teureren deiner vollständig beobachteten Wochen. Er unterschreitet deinen selbst festgelegten Mindestbedarf nie und erhöht nie automatisch dein Wochenlimit.")
            value("Dein Mindestbedarf / Woche", store.budget.assistant.essentialWeekly)
            value("Aktueller Ansatz / Woche", analysis.essentialWeekly)
            Text("\(analysis.learnedWeeks) vollständige Wochen · \(analysis.learnedSamples) notwendige Ausgaben im Lernfenster. Nicht eingetragene Ausgaben kennt der Assistent nicht.").font(.caption).foregroundStyle(.secondary)
            let withdrawals = store.budget.reserveMovements.filter { $0.cents < 0 && !$0.emergency && $0.date >= now.addingTimeInterval(-30 * 86400) }
            if !withdrawals.isEmpty { Text("\(withdrawals.count) Entnahmen aus Spartöpfen in 30 Tagen. Prüfe vor einer weiteren Entnahme Wunschliste und Sparziel.").foregroundStyle(.orange) }
        }
        Section("Deine Rückmeldung trainiert die Einordnung") {
            if store.budget.expenses.isEmpty { Text("Erfasse Ausgaben und markiere sie als notwendig, Wunsch oder Notfall.") }
            ForEach(store.budget.expenses.prefix(25)) { expense in
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(expense.title) · \(Euro.format(expense.cents))").fontWeight(.semibold)
                    if let merchant = expense.merchant, !merchant.isEmpty { Text(merchant).font(.caption).foregroundStyle(.secondary) }
                    Picker("Einordnung", selection: Binding<ExpensePurpose?>(get: { expense.purpose }, set: { purpose in
                        apply { $0.labelExpense(id: expense.id, purpose: purpose) }
                    })) {
                        Text("Noch offen").tag(Optional<ExpensePurpose>.none)
                        ForEach(ExpensePurpose.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                }
            }
        }
    }
    private func apply(_ operation: (inout Budget) throws -> Void) {
        error = nil
        if !store.change(operation) { error = store.error; store.error = nil }
        now = Date()
    }
}

private struct AssistantSettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var essential = ""
    @State private var buffer = ""
    @State private var savings = ""
    @State private var payday = Date().addingTimeInterval(30 * 86400)
    @State private var emergencyID: UUID?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Deine festen Vorgaben") {
                    field("Notwendiger Alltag pro Woche in €", $essential)
                    field("Sicherheitspuffer in €", $buffer)
                    field("Noch zusätzlich sparen bis Gehalt in €", $savings)
                    DatePicker("Nächster Gehaltstag", selection: $payday, in: Date()...Date().addingTimeInterval(62 * 86400), displayedComponents: .date)
                    Picker("Notfalltopf", selection: $emergencyID) {
                        Text("Bitte wählen").tag(Optional<UUID>.none)
                        ForEach(store.budget.pots) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section {
                    Text("Alltag umfasst notwendige variable Ausgaben wie Lebensmittel und Fahrtkosten – keine Fixkosten. Bereits reserviertes Geld in Spartöpfen nicht nochmals beim zusätzlichen Sparbetrag eintragen.")
                    Text("Der Plan gilt bis zum gewählten Gehaltstag und wird dann neu von dir bestätigt. Die App verschiebt kein Geld. Änderungen an diesen Grenzen entscheidest du selbst.")
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Plan speichern") { save() }.fontWeight(.semibold)
            }.navigationTitle("Assistent einrichten").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .onAppear {
                let a = store.budget.assistant
                essential = Euro.editable(a.essentialWeekly); buffer = Euro.editable(a.safetyBuffer); savings = Euro.editable(a.extraSavings)
                payday = max(a.nextPayday ?? Date().addingTimeInterval(30 * 86400), Date().addingTimeInterval(86400))
                emergencyID = a.emergencyPotID
            }
        }.tint(assistMint)
    }
    private func field(_ text: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(text).font(.subheadline)
            TextField("0,00", text: value).keyboardType(.decimalPad).accessibilityLabel(text)
        }
    }
    private func save() {
        do {
            let essential = try Euro.parse(essential, allowZero: true)
            let buffer = try Euro.parse(buffer, allowZero: true)
            let savings = try Euro.parse(savings, allowZero: true)
            guard store.change({ b in
                b.assistant.configured = true; b.assistant.essentialWeekly = essential; b.assistant.safetyBuffer = buffer
                b.assistant.extraSavings = savings; b.assistant.nextPayday = Calendar.current.startOfDay(for: payday); b.assistant.emergencyPotID = emergencyID
            }) else { error = store.error; store.error = nil; return }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
