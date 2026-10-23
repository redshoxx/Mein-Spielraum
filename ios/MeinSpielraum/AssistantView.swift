import SwiftUI
import UIKit
import Combine

private let assistMint = SpielraumTheme.mint
struct AssistantView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Int
    init(initialTab: Int = 0) { _tab = State(initialValue: initialTab) }
    @State private var settingsOpen = false
    @State private var emergencyOpen = false
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
    private var analysis: BudgetAssessment { store.assessment(now: now) }
    var body: some View {
        NavigationStack {
            List {
                Picker("Bereich", selection: $tab) { Text("Überblick").tag(0); Text("Kaufcheck").tag(1); Text("Einträge").tag(2) }.pickerStyle(.segmented)
                if tab == 0 { planSections }
                else if tab == 1 { purchaseSections }
                else { learningSections }
                Section { DisclosureGroup("Was weiß der Assistent?") {
                    Text("Er schätzt anhand deiner Einträge. Er kennt keine Umsätze aus deiner Bank-App und führt keine Überweisungen aus.").font(.body).foregroundStyle(SpielraumTheme.muted).padding(.vertical, 8)
                } }
            }
            .navigationTitle("Budget-Assistent").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Anpassen") { settingsOpen = true }.accessibilityLabel("Assistent anpassen") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .sheet(isPresented: $settingsOpen) { AssistantSettingsView().environmentObject(store) }
            .alert("Hinweis", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
            .onReceive(timer) { now = $0 }
        }.readableScreen()
    }
    @ViewBuilder private var planSections: some View {
        if !store.budget.assistant.usesAutomatic && !store.budget.assistant.configured {
            Section("Zuerst dein Plan") {
                Text("Lege notwendige Alltagskosten, Sicherheitspuffer, zusätzliches Spargeld und den nächsten Gehaltstag fest. Der Assistent verändert diese Vorgaben nie selbst.")
                Button("Jetzt einrichten") { settingsOpen = true }
            }
        } else {
            Section("Richtwert für freie Wünsche") {
                Text(Euro.format(analysis.purchaseLimit)).font(.system(size: 36, weight: .bold)).foregroundStyle(assistMint)
                DisclosureGroup("Warum dieser Betrag?") { Text(analysis.explanation).font(.body).foregroundStyle(SpielraumTheme.muted).padding(.vertical, 10) }
                if let payday = analysis.payday { Text("Planungsende \(payday.formatted(date: .abbreviated, time: .omitted)) · \(analysis.days) Tage") }
                if !analysis.ready { Button("Gehaltstag prüfen") { settingsOpen = true } }
                if analysis.shortfall > 0 { Text("Im Plan fehlen \(Euro.format(analysis.shortfall)). Keine freien Wünsche empfohlen; Plan und Kontostand prüfen.").foregroundStyle(SpielraumTheme.warning) }
            }
            if analysis.ready {
                Section { DisclosureGroup("Zurückgelegtes Geld ansehen") {
                    value("Offene Fixkosten", analysis.fixedReserve)
                    value("Bereits in Spartöpfen", store.budget.reserved)
                    value("Alltag bis Planungsende", analysis.essentialReserve)
                    value("Sicherheitspuffer", analysis.buffer)
                    value("Noch zusätzlich sparen", analysis.extraSavings)
                    Text("Künftiges Gehalt wird nicht als vorhandenes Guthaben gerechnet. Offene Fixkosten werden mindestens bis Monatsende und bis zum Planungsende berücksichtigt. Dein Wochenlimit gilt zusätzlich.").font(.body).foregroundStyle(SpielraumTheme.muted)
                }
                }
                Section("Sparen") {
                    value("Vorsichtiger Zusatzvorschlag", analysis.additionalSavingsSuggestion)
                    Text("Nur ein Vorschlag, keine Überweisung. Unter Spartöpfe kannst du Geld reservieren. Das reduziert den noch zusätzlich geplanten Sparbetrag, damit er nicht doppelt abgezogen wird.").font(.body).foregroundStyle(SpielraumTheme.muted)
                }
            }
        }
        Section {
            DisclosureGroup("Geld im Notfall", isExpanded: $emergencyOpen) { emergencyContent }
        }
        if let message { Section { Text(message).foregroundStyle(assistMint) } }
    }
    private func value(_ title: String, _ cents: Int) -> some View {
        HStack { Text(title); Spacer(); Text(Euro.format(cents)).monospacedDigit() }
    }
    @ViewBuilder private var emergencyContent: some View {
        Group {
            if let id = store.budget.assistant.emergencyPotID, let pot = store.budget.pots.first(where: { $0.id == id }) {
                value(pot.name, pot.cents)
                EntryField(label: "Wofür brauchst du das Geld?", text: $emergencyName)
                EntryField(label: "Betrag in €", text: $emergencyAmount, money: true)
                Button("Notfallausgabe jetzt erfassen") {
                    do {
                        let cents = try Euro.parse(emergencyAmount)
                        apply { try $0.emergencyExpense(cents: cents, title: String(emergencyName.prefix(100))) }
                        if error == nil { emergencyAmount = ""; emergencyName = ""; message = "Notfall erfasst. Die Reserve wurde angepasst; prüfe deinen Sparplan zum Wiederaufbauen." }
                    } catch { self.error = error.localizedDescription }
                }
                Text("Erfasst die Ausgabe sofort aus deinem Notfalltopf. Keine Wartezeit, kein Kredit und keine reale Banküberweisung. Reicht die Reserve nicht, wird die Lücke angezeigt.").font(.body).foregroundStyle(SpielraumTheme.muted)
            } else { Text("Wähle in den Assistent-Einstellungen einen vorhandenen Spartopf als Notfallreserve."); Button("Notfalltopf wählen") { settingsOpen = true } }
        }
    }
    @ViewBuilder private var purchaseSections: some View {
        Section("Vor dem Kauf prüfen") {
            EntryField(label: "Was möchtest du kaufen?", text: $name)
            EntryField(label: "Preis in €", text: $amount, money: true)
            EntryField(label: "Händler (optional)", text: $merchant)
            Picker("Kategorie", selection: $category) { ForEach(["Lebensmittel", "Freizeit", "Mobilität", "Wohnen", "Sonstiges"], id: \.self) { Text($0) } }
            if let cents = try? Euro.parse(amount) {
                if !analysis.ready { Text("Die Berechnung ist noch nicht verfügbar. Prüfe die optionalen Einstellungen und Einnahmetermine.").foregroundStyle(SpielraumTheme.warning) }
                else if cents > analysis.purchaseLimit { Text("Der Kauf liegt \(Euro.format(cents - analysis.purchaseLimit)) über deinem Richtwert. Wünsche verschieben; bei notwendigen Ausgaben den Plan prüfen.").foregroundStyle(SpielraumTheme.warning) }
                else { Text("Nach diesem Kauf blieben nach den erfassten Planwerten \(Euro.format(analysis.purchaseLimit - cents)) für freie Wünsche.").foregroundStyle(assistMint) }
            }
            if let estimate = store.budget.necessityEstimate(merchant: merchant, category: category) {
                Text(estimate.probability >= 0.7 ? "Aus deinen Markierungen eher notwendig – bitte selbst prüfen." : estimate.probability <= 0.3 ? "Aus deinen Markierungen eher ein Wunsch." : "Deine Markierungen sind gemischt; keine klare Einordnung.").font(.subheadline)
                Text("\(estimate.basis) · \(estimate.samples) Beispiele. Der Händler verrät nicht, was du tatsächlich gekauft hast.").font(.body).foregroundStyle(SpielraumTheme.muted)
            }
            Button("Wunsch 48 Stunden vormerken") {
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
            if store.budget.wishes.isEmpty { Text("Noch keine Wünsche. Die Kaufpause gibt dir Zeit, den Kauf zu überdenken.").foregroundStyle(SpielraumTheme.muted) }
            ForEach(store.budget.wishes) { wish in wishRow(wish) }
        }
    }
    private func wishRow(_ wish: PurchaseWish) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Text(wish.name).fontWeight(.semibold); Spacer(); Text(Euro.format(wish.cents)) }
            if wish.readyAt > now { Text("Kaufpause bis \(wish.readyAt.formatted(date: .abbreviated, time: .shortened))").font(.body).foregroundStyle(SpielraumTheme.muted) }
            else { Text("Kaufpause vorbei. Passt der Wunsch noch zu deinem Ziel?").font(.body).foregroundStyle(SpielraumTheme.muted) }
            Button("Gekauft · Ausgabe erfassen") { apply { try $0.buyWish(id: wish.id, now: now) } }.disabled(wish.readyAt > now || !analysis.ready || wish.cents > analysis.purchaseLimit)
            Button("Verzichten / entfernen", role: .destructive) { apply { $0.wishes.removeAll { $0.id == wish.id } } }
        }.padding(.vertical, 5)
    }
    @ViewBuilder private var learningSections: some View {
        Section { DisclosureGroup("Wie lernt der Assistent?") {
            Text("Deine Rückmeldungen verbessern die Einschätzung. Ohne Rückmeldung werden Ausgaben vorsichtig als Alltag berücksichtigt.")

            value("Dein Mindestbedarf / Woche", store.budget.assistant.essentialWeekly)
            value("Aktueller Ansatz / Woche", analysis.essentialWeekly)
            Text("\(analysis.learnedWeeks) vollständige Wochen · \(analysis.learnedSamples) berücksichtigte Ausgaben im Lernfenster. Nicht eingetragene Ausgaben kennt der Assistent nicht.").font(.body).foregroundStyle(SpielraumTheme.muted)
            let withdrawals = store.budget.reserveMovements.filter { $0.cents < 0 && !$0.emergency && $0.date >= now.addingTimeInterval(-30 * 86400) }
            if !withdrawals.isEmpty { Text("\(withdrawals.count) Entnahmen aus Spartöpfen in 30 Tagen. Prüfe vor einer weiteren Entnahme Wunschliste und Sparziel.").foregroundStyle(SpielraumTheme.warning) }
        }
        }
        Section("Ausgaben einordnen · freiwillig") {
            if store.budget.expenses.isEmpty { Text("Erfasse Ausgaben. Eine Einordnung als notwendig, Wunsch oder Notfall ist optional und verbessert die Schätzung.") }
            ForEach(store.budget.expenses.prefix(25)) { expense in
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(expense.title) · \(Euro.format(expense.cents))").fontWeight(.semibold)
                    if let merchant = expense.merchant, !merchant.isEmpty { Text(merchant).font(.body).foregroundStyle(SpielraumTheme.muted) }
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
    @State private var automatic = true
    @State private var essential = ""
    @State private var buffer = ""
    @State private var savings = ""
    @State private var payday = Date().addingTimeInterval(30 * 86400)
    @State private var emergencyID: UUID?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Automatisch aus meinen Einträgen", isOn: $automatic)
                    Text("Kein Plan nötig. Einnahmetermine, Fixkosten, Spartöpfe und Ausgaben werden laufend ausgewertet. Ohne Einnahmetermin gilt ein vorläufiger Zeitraum von 30 Tagen. Mit wenig Historie bleibt das Wochenlimit für Alltag geschützt.").font(.body)
                }
                Section("Optionale Mindestbeträge") {
                    field("Notwendiger Alltag pro Woche in €", $essential)
                    field("Sicherheitspuffer in €", $buffer)
                    field("Zusätzlicher Sparbetrag in €", $savings)
                    if !automatic {
                        DatePicker("Nächster Gehaltstag", selection: $payday, in: Date()...Date().addingTimeInterval(62 * 86400), displayedComponents: .date)
                    }
                    Picker("Notfalltopf", selection: $emergencyID) {
                        Text("Bitte wählen").tag(Optional<UUID>.none)
                        ForEach(store.budget.pots) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section {
                    Text("Alltag umfasst notwendige variable Ausgaben wie Lebensmittel und Fahrtkosten – keine Fixkosten. Bereits reserviertes Geld in Spartöpfen nicht nochmals beim zusätzlichen Sparbetrag eintragen.")
                    Text("Im Automatikmodus aktualisiert sich die Schätzung beim Erfassen oder Ändern von Daten. Optionale Mindestbeträge bleiben geschützt. Im manuellen Modus gilt der gewählte Gehaltstag. Die App verschiebt kein Geld.")
                }
                if let error { Text(error).foregroundStyle(SpielraumTheme.danger) }
                Button("Einstellungen speichern") { save() }.buttonStyle(PrimaryAction()).listRowBackground(Color.clear)
            }.navigationTitle("Assistent anpassen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .onAppear {
                let a = store.budget.assistant
                automatic = a.usesAutomatic
                essential = Euro.editable(a.essentialWeekly); buffer = Euro.editable(a.safetyBuffer); savings = Euro.editable(a.extraSavings)
                payday = max(a.nextPayday ?? Date().addingTimeInterval(30 * 86400), Date().addingTimeInterval(86400))
                emergencyID = a.emergencyPotID
            }
        }.readableScreen()
    }
    private func field(_ text: String, _ value: Binding<String>) -> some View { EntryField(label: text, text: value, money: true) }
    private func save() {
        do {
            let essential = try Euro.parse(essential, allowZero: true)
            let buffer = try Euro.parse(buffer, allowZero: true)
            let savings = try Euro.parse(savings, allowZero: true)
            guard store.change({ b in
                b.assistant.automatic = automatic; b.assistant.configured = true; b.assistant.essentialWeekly = essential; b.assistant.safetyBuffer = buffer
                b.assistant.extraSavings = savings; b.assistant.nextPayday = Calendar.current.startOfDay(for: payday); b.assistant.emergencyPotID = emergencyID
            }) else { error = store.error; store.error = nil; return }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
