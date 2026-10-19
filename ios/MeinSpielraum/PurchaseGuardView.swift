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
                    Text("Kurz warten.\nBewusst entscheiden.").font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-0.8)
                    Text("Ein voller Warenkorb ist noch kein guter Kauf. Lass deinem Sparziel einen Moment Vorsprung.").foregroundStyle(SpielraumTheme.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DEIN AKTUELLER KAUF-RICHTWERT").font(.caption.weight(.semibold)).tracking(1)
                        Text(Euro.format(analysis.purchaseLimit)).font(.system(size: 43, weight: .bold, design: .rounded)).foregroundStyle(SpielraumTheme.mint).minimumScaleFactor(0.5).lineLimit(1)
                        Text(analysis.ready ? "Schätzung nach eingetragenem Alltag, Fixkosten, Sparreserve und Puffer." : analysis.explanation).font(.caption).foregroundStyle(SpielraumTheme.muted)
                        Text("Kennst du den Preis? Im Kaufcheck siehst du, wie er sich auf deinen Spielraum auswirkt.").font(.subheadline)
                    }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(pauseUntil.timeIntervalSince(context.date))))
                        Button { checkOpen = true } label: {
                            Label(remaining > 0 ? "\(remaining) Sekunden Abstand" : "Preis prüfen & Wunsch vormerken", systemImage: remaining > 0 ? "hourglass" : "checkmark.shield")
                                .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(18)
                                .background(SpielraumTheme.mint.opacity(remaining > 0 ? 0.45 : 1), in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(remaining > 0)
                    }
                    Text("Wünsche bleiben 48 Stunden auf deiner Liste. Notfälle kannst du im Assistenten direkt erfassen.").font(.subheadline).foregroundStyle(SpielraumTheme.muted)
                    setupSection
                }.padding(22)
            }.background(SpielraumTheme.canvas)
            .navigationTitle("Kaufbremse").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .sheet(isPresented: $checkOpen) { AssistantView(initialTab: 1).environmentObject(store) }
        }.tint(SpielraumTheme.mint).preferredColorScheme(.dark)
    }
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Vor Amazon kurz anhalten", systemImage: "arrow.triangle.branch").font(.headline)
            Text("Einmal in Apples Kurzbefehle-App einrichten:").font(.subheadline)
            Text("1. Automation → Neue Automation → App.\n2. Amazon wählen → Wird geöffnet → Sofort ausführen.\n3. Aktion „URLs öffnen“ mit der folgenden Adresse ergänzen.").font(.subheadline).lineSpacing(5)
            Text("spielraum://kaufcheck").font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
            Button(copied ? "Adresse kopiert" : "Adresse kopieren", systemImage: copied ? "checkmark" : "doc.on.doc") { UIPasteboard.general.string = "spielraum://kaufcheck"; copied = true }
            Text("Die Automation öffnet diese freiwillige Kaufbremse beim App-Start. Sie wird nicht automatisch eingerichtet und erkennt keine Warenkorb-Aktion, Artikel oder Preise. Die App kann Amazon weder überwachen noch Zahlungen sperren.").font(.caption).foregroundStyle(SpielraumTheme.muted)
            Divider()
            Text("Stärker begrenzen").font(.subheadline.bold())
            Text("Für eine zusätzliche Zeitgrenze kannst du unter iPhone-Einstellungen → Bildschirmzeit → App-Limits ein Limit für Shopping-Apps setzen und die verfügbaren Sperroptionen aktivieren. Das wird direkt in iOS eingerichtet, nicht von Mein Spielraum.").font(.caption).foregroundStyle(SpielraumTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).budgetCard()
    }
}
