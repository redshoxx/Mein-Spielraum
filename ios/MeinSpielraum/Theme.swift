import SwiftUI

enum SpielraumTheme {
    static let mint = Color(hex: 0x154C96) // Kept as an alias for existing call sites.
    static let canvas = Color(hex: 0xF3F5F8)
    static let surface = Color(hex: 0xFFFFFF)
    static let text = Color(hex: 0x172B40)
    static let muted = Color(hex: 0x46576D)
    static let soft = Color(hex: 0xE9F0FB)
    static let border = Color(hex: 0xCFD8E4)
    static let positive = Color(hex: 0x166534)
    static let warning = Color(hex: 0x873600)
    static let danger = Color(hex: 0xB42318)
}
private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}
extension View {
    func budgetCard() -> some View {
        self.padding(20).background(SpielraumTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SpielraumTheme.border, lineWidth: 1))
    }
    func readableScreen() -> some View {
        self.foregroundStyle(SpielraumTheme.text).tint(SpielraumTheme.mint)
            .preferredColorScheme(.light)
            .scrollContentBackground(.hidden).background(SpielraumTheme.canvas)
            .environment(\.defaultMinListRowHeight, 56)
    }
}
struct PrimaryAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).multilineTextAlignment(.center)
            .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(configuration.isPressed ? SpielraumTheme.text : SpielraumTheme.mint, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct MenuRow: View {
    let title: String
    let detail: String
    let icon: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(SpielraumTheme.mint)
                .frame(width: 42, height: 46).background(SpielraumTheme.soft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(SpielraumTheme.text)
                if !detail.isEmpty { Text(detail).font(.subheadline).foregroundStyle(SpielraumTheme.muted) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(SpielraumTheme.muted)
        }.frame(maxWidth: .infinity, minHeight: 58, alignment: .leading).contentShape(Rectangle())
    }
}
struct EntryField: View {
    let label: String
    @Binding var text: String
    var money = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.body.weight(.medium)).foregroundStyle(SpielraumTheme.text)
            TextField(money ? "0,00" : "Hier eingeben", text: $text)
                .keyboardType(money ? .decimalPad : .default)
                .font(.body).padding(14).frame(minHeight: 52)
                .background(SpielraumTheme.canvas, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SpielraumTheme.border))
                .accessibilityLabel(label)
        }.padding(.vertical, 5)
    }
}
