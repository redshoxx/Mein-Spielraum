import SwiftUI
import UIKit

struct PurchaseGuardView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var checkOpen = false
    @State private var pauseUntil = Date().addingTimeInterval(15)
    @State private var copied = false
    private var analysis: BudgetAssessment { store.assessment() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 34)).foregroundStyle(SpielraumTheme.mint).padding(18).background(SpielraumTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    Text("Vor dem Kauf").font(.largeTitle.bold())
                    Text("Prüfe kurz dein Budget, bevor du etwas bestellst.").foregroundStyle(SpielraumTheme.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Für Wünsche übrig").font(.title3.weight(.semibold))
                        Text(Euro.format(analysis.purchaseLimit)).font(.largeTitle.bold()).foregroundStyle(SpielraumTheme.mint).minimumScaleFactor(0.5).lineLimit(1)
                        Text(analysis.ready ? "Schätzung nach eingetragenem Alltag, Fixkosten, Sparreserve und Puffer." : analysis.explanation).font(.body).foregroundStyle(SpielraumTheme.muted)
                        Text("Kennst du den Preis? Im Kaufcheck siehst du, wie er sich auf deinen Spielraum auswirkt.").font(.subheadline)
                    }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(pauseUntil.timeIntervalSince(context.date))))
                        Button { checkOpen = true } label: {
                            Label(remaining > 0 ? "\(remaining) Sekunden Abstand" : "Preis prüfen & Wunsch vormerken", systemImage: remaining > 0 ? "hourglass" : "checkmark.shield")
                                .font(.headline).foregroundStyle(remaining > 0 ? SpielraumTheme.text : Color.white).frame(maxWidth: .infinity).padding(18)
                                .background(remaining > 0 ? SpielraumTheme.soft : SpielraumTheme.mint, in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(remaining > 0)
                    }
                    Text("Wünsche bleiben 48 Stunden auf deiner Liste. Notfälle kannst du im Assistenten direkt erfassen.").font(.subheadline).foregroundStyle(SpielraumTheme.muted)
                    DisclosureGroup("Amazon-Kaufbremse einrichten") { setupSection.padding(.top, 14) }.font(.headline).budgetCard()
                }.padding(22)
            }.background(SpielraumTheme.canvas)
            .navigationTitle("Kaufbremse").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .sheet(isPresented: $checkOpen) { AssistantView(initialTab: 1).environmentObject(store) }
        }.readableScreen()
    }
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Vor Amazon kurz anhalten", systemImage: "arrow.triangle.branch").font(.headline)
            Text("Einmal in Apples Kurzbefehle-App einrichten:").font(.subheadline)
            Text("1. Automation → Neue Automation → App.\n2. Amazon wählen → Wird geöffnet → Sofort ausführen.\n3. Aktion „URLs öffnen“ mit der folgenden Adresse ergänzen.").font(.subheadline).lineSpacing(5)
            Text("spielraum://kaufcheck").font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
            Button(copied ? "Adresse kopiert" : "Adresse kopieren", systemImage: copied ? "checkmark" : "doc.on.doc") { UIPasteboard.general.string = "spielraum://kaufcheck"; copied = true }
            Text("Die Automation öffnet diese freiwillige Kaufbremse beim App-Start. Sie wird nicht automatisch eingerichtet und erkennt keine Warenkorb-Aktion, Artikel oder Preise. Die App kann Amazon weder überwachen noch Zahlungen sperren.").font(.body).foregroundStyle(SpielraumTheme.muted)
            Divider()
            Text("Stärker begrenzen").font(.subheadline.bold())
            Text("Für eine zusätzliche Zeitgrenze kannst du unter iPhone-Einstellungen → Bildschirmzeit → App-Limits ein Limit für Shopping-Apps setzen und die verfügbaren Sperroptionen aktivieren. Das wird direkt in iOS eingerichtet, nicht von Mein Spielraum.").font(.body).foregroundStyle(SpielraumTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
